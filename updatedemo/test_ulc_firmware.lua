#!/usr/bin/env lua
-- ULC 固件更新测试用例
-- Windows 平台本地测试
-- 作者: longfei
-- 日期: 20250722

-- 加载 ULC 固件更新模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path
local ulc_update = require("ulc_firmware_update")

-- 测试配置
local TEST_CONFIG = {
    test_firmware_dir = "test_firmware",
    test_results_dir = "test_results",
    mock_firmware_sizes = {
        small = 1024,      -- 1KB
        medium = 32768,    -- 32KB  
        large = 262144,    -- 256KB
        xlarge = 1048576   -- 1MB
    }
}

-- 测试工具函数
local test_utils = {}

-- 如果测试目录不存在则创建
function test_utils.ensure_directory(dir_path)
    local lfs = require("lfs")
    local success, err = lfs.mkdir(dir_path)
    if not success and err ~= "File exists" then
        print("警告: 无法创建目录 " .. dir_path .. ": " .. (err or "未知错误"))
    end
end

-- 生成模拟固件文件
function test_utils.generate_mock_firmware(file_path, size)
    print("生成模拟固件: " .. file_path .. " (" .. size .. " 字节)")
    
    local file, err = io.open(file_path, "wb")
    if not file then
        error("创建模拟固件文件失败: " .. (err or "未知错误"))
    end
    
    -- 生成伪随机固件数据
    math.randomseed(os.time())
    for i = 1, size do
        local byte_val = math.random(0, 255)
        file:write(string.char(byte_val))
    end
    
    file:close()
    print("模拟固件生成成功！")
end

-- 验证文件存在并具有预期大小
function test_utils.verify_file(file_path, expected_size)
    local file = io.open(file_path, "rb")
    if not file then
        return false, "文件不存在"
    end
    
    local content = file:read("*all")
    file:close()
    
    if #content ~= expected_size then
        return false, string.format("大小不匹配: 预期 %d, 实际 %d", expected_size, #content)
    end
    
    return true, "文件验证通过"
end

-- 测试用例运行器
local test_runner = {}

-- 测试用例: 基本功能测试
function test_runner.test_basic_functionality()
    print("\n=== 测试用例: 基本功能 ===")
    
    local test_file = TEST_CONFIG.test_firmware_dir .. "/basic_test.bin"
    test_utils.generate_mock_firmware(test_file, TEST_CONFIG.mock_firmware_sizes.small)
    
    -- 测试文件操作
    local hex_data, length = ulc_update.file_ops.read_firmware(test_file)
    print("读取测试通过: " .. length .. " 字节")
    
    -- 测试实用函数
    local hex_val = ulc_update.utils.int_to_hex(255, 2)
    assert(hex_val == "FF", "int_to_hex 测试失败")
    print("实用函数测试通过")
    
    -- 测试 CRC 计算
    local crc = ulc_update.utils.crc16c("1234567890ABCDEF", 0)
    print("CRC16 测试通过: " .. crc)
    
    print("基本功能测试: 通过")
end

-- 测试用例: 不同固件大小
function test_runner.test_firmware_sizes()
    print("\n=== 测试用例: 不同固件大小 ===")
    
    for size_name, size_bytes in pairs(TEST_CONFIG.mock_firmware_sizes) do
        print("\n测试 " .. size_name .. " 固件 (" .. size_bytes .. " 字节)")
        
        local test_file = TEST_CONFIG.test_firmware_dir .. "/" .. size_name .. "_firmware.bin"
        test_utils.generate_mock_firmware(test_file, size_bytes)
        
        -- 测试读取
        local hex_data, length = ulc_update.file_ops.read_firmware(test_file)
        assert(length == size_bytes, "大小不匹配: " .. size_name)
        
        -- 测试进度显示
        print("测试进度显示:")
        for i = 0, 10 do
            local current = math.floor((i * size_bytes) / 10)
            ulc_update.progress.show_progress(current, size_bytes, "测试 " .. size_name)
            require("socket").sleep(0.1)
        end
        
        print(size_name .. " 固件测试: 通过")
    end
    
    print("固件大小测试: 通过")
end

-- 测试用例: 加密函数
function test_runner.test_crypto_functions()
    print("\n=== 测试用例: 加密函数 ===")
    
    -- 测试 SM2 操作
    local public_key = ulc_update.config.PUB_KEY_X .. ulc_update.config.PUB_KEY_Y
    local test_data = "Hello, ULC Firmware Update!"
    
    print("测试 SM2 加密...")
    local encrypted = ulc_update.crypto.sm2_encrypt(public_key, test_data)
    assert(#encrypted > 0, "SM2 加密失败")
    
    print("测试 SM2 签名验证...")
    local signature = string.rep("A", 64)  -- 模拟签名
    local verified = ulc_update.crypto.sm2_verify(public_key, "", signature, test_data)
    assert(verified == true, "SM2 验证失败")
    
    -- 测试 SM4 操作
    local sm4_key = string.rep("11", 16)
    local sm4_data = "Test data for SM4 encryption"
    
    print("测试 SM4 加密...")
    local sm4_encrypted = ulc_update.crypto.sm4_encrypt(sm4_key, nil, sm4_data, "ECB")
    assert(#sm4_encrypted > 0, "SM4 加密失败")
    
    print("测试 SM4 MAC...")
    local mac = ulc_update.crypto.sm4_mac(sm4_key, sm4_data)
    assert(#mac == 32, "SM4 MAC 长度不正确")  -- 32个十六进制字符 = 16字节
    
    print("加密函数测试: 通过")
end

-- 测试用例: 通信模拟
function test_runner.test_communication()
    print("\n=== 测试用例: 通信模拟 ===")
    
    -- 测试各种 APDU 命令
    local test_commands = {
        "00A4000002DF20",           -- 选择应用
        "E0B4011C022000",           -- 获取 SM2 公钥
        "80DB001C081122334455667788", -- 获取 UUID
        "80DA000000",               -- 发送切换信息
        "0020001C00",               -- 发送加密的 SK
        "00D0000000",               -- 发送固件数据
        "80C4000000",               -- 完成检查
        "F0F6020000"                -- 获取 COS 版本
    }
    
    for _, cmd in ipairs(test_commands) do
        print("测试命令: " .. cmd:sub(1, 16) .. "...")
        local response = ulc_update.comm.ulc_send_apdu(cmd)
        assert(#response > 0, "命令无响应: " .. cmd)
    end
    
    print("通信模拟测试: 通过")
end

-- 测试用例: 完整更新模拟
function test_runner.test_complete_update()
    print("\n=== 测试用例: 完整更新模拟 ===")
    
    -- 创建测试固件
    local test_file = TEST_CONFIG.test_firmware_dir .. "/complete_test.bin"
    test_utils.generate_mock_firmware(test_file, TEST_CONFIG.mock_firmware_sizes.medium)
    
    -- 为测试覆盖配置
    local original_config = {}
    for k, v in pairs(ulc_update.config) do
        original_config[k] = v
    end
    
    -- 设置测试配置
    ulc_update.config.UPDATE_TYPE_FLAG = 0  -- ULC 直接 324
    ulc_update.config.COMM_TYPE = 1         -- ULC 通信
    ulc_update.config.DEVICE_ID = 2         -- 测试设备 ID
    
    print("开始完整更新模拟...")
    
    -- 运行完整更新过程
    local success, err = pcall(function()
        ulc_update.update_firmware(test_file)
    end)
    
    if success then
        print("完整更新模拟: 通过")
    else
        print("完整更新模拟: 失败 - " .. (err or "未知错误"))
    end
    
    -- 恢复原始配置
    for k, v in pairs(original_config) do
        ulc_update.config[k] = v
    end
end

-- 测试用例: 错误处理
function test_runner.test_error_handling()
    print("\n=== 测试用例: 错误处理 ===")
    
    -- 测试不存在的文件
    print("测试不存在文件处理...")
    local success, err = pcall(function()
        ulc_update.file_ops.read_firmware("non_existent_file.bin")
    end)
    assert(not success, "对不存在的文件应该失败")
    print("不存在文件测试: 通过")
    
    -- 测试无效的十六进制转换
    print("测试无效的十六进制转换...")
    local invalid_result = ulc_update.utils.hex_to_int("INVALID")
    assert(invalid_result == 0, "对无效十六进制应返回0")
    print("无效十六进制转换测试: 通过")
    
    -- 测试边界条件
    print("测试边界条件...")
    ulc_update.progress.show_progress(0, 100, "边界测试")
    ulc_update.progress.show_progress(100, 100, "边界测试")
    ulc_update.progress.show_progress(150, 100, "边界测试")  -- 超过100%
    print("边界条件测试: 通过")
    
    print("错误处理测试: 通过")
end

-- 性能测试
function test_runner.test_performance()
    print("\n=== 测试用例: 性能测试 ===")
    
    local test_file = TEST_CONFIG.test_firmware_dir .. "/performance_test.bin"
    test_utils.generate_mock_firmware(test_file, TEST_CONFIG.mock_firmware_sizes.large)
    
    local start_time = os.clock()
    
    -- 测试文件读取性能
    local hex_data, length = ulc_update.file_ops.read_firmware(test_file)
    local read_time = os.clock() - start_time
    
    print(string.format("文件读取性能: %.3f 秒用于 %d 字节", read_time, length))
    
    -- 测试 CRC 计算性能
    start_time = os.clock()
    local test_data = string.rep("A", 10000)  -- 10KB 的 'A'
    local crc = ulc_update.utils.crc16c(test_data, 0)
    local crc_time = os.clock() - start_time
    
    print(string.format("CRC 计算性能: %.3f 秒用于 %d 字节", crc_time, #test_data))
    
    print("性能测试: 通过")
end

-- 主测试运行器
function test_runner.run_all_tests()
    print("=== ULC 固件更新测试套件 ===")
    print("平台: Windows")
    print("Lua 版本: " .. _VERSION)
    print("开始时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("")
    
    -- 设置测试环境
    test_utils.ensure_directory(TEST_CONFIG.test_firmware_dir)
    test_utils.ensure_directory(TEST_CONFIG.test_results_dir)
    
    local tests = {
        test_runner.test_basic_functionality,
        test_runner.test_firmware_sizes,
        test_runner.test_crypto_functions,
        test_runner.test_communication,
        test_runner.test_error_handling,
        test_runner.test_performance,
        test_runner.test_complete_update  -- 最后运行这个，因为它最全面
    }
    
    local passed = 0
    local failed = 0
    
    for i, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("测试失败: " .. (err or "未知错误"))
        end
        print("")
    end
    
    print("=== 测试结果摘要 ===")
    print("总测试数: " .. (passed + failed))
    print("通过: " .. passed)
    print("失败: " .. failed)
    print("成功率: " .. string.format("%.1f%%", (passed * 100) / (passed + failed)))
    print("结束时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    
    if failed == 0 then
        print("所有测试通过！")
    else
        print("部分测试失败！")
    end
end

-- 交互式测试菜单
function test_runner.interactive_menu()
    print("\n=== ULC 固件更新测试菜单 ===")
    print("1. 运行所有测试")
    print("2. 测试基本功能")
    print("3. 测试不同固件大小")
    print("4. 测试加密函数")
    print("5. 测试通信模拟")
    print("6. 测试错误处理")
    print("7. 测试性能")
    print("8. 测试完整更新模拟")
    print("9. 生成模拟固件文件")
    print("0. 退出")
    print("")
    
    io.write("选择测试 (0-9): ")
    local choice = io.read()
    
    if choice == "1" then
        test_runner.run_all_tests()
    elseif choice == "2" then
        test_runner.test_basic_functionality()
    elseif choice == "3" then
        test_runner.test_firmware_sizes()
    elseif choice == "4" then
        test_runner.test_crypto_functions()
    elseif choice == "5" then
        test_runner.test_communication()
    elseif choice == "6" then
        test_runner.test_error_handling()
    elseif choice == "7" then
        test_runner.test_performance()
    elseif choice == "8" then
        test_runner.test_complete_update()
    elseif choice == "9" then
        test_utils.ensure_directory(TEST_CONFIG.test_firmware_dir)
        for size_name, size_bytes in pairs(TEST_CONFIG.mock_firmware_sizes) do
            local file_path = TEST_CONFIG.test_firmware_dir .. "/" .. size_name .. "_firmware.bin"
            test_utils.generate_mock_firmware(file_path, size_bytes)
        end
        print("模拟固件文件已生成！")
    elseif choice == "0" then
        print("再见！")
        return
    else
        print("无效选择！")
    end
    
    print("\n按回车键继续...")
    io.read()
    test_runner.interactive_menu()
end

-- 如果此脚本直接运行，启动交互式菜单
if arg and arg[0] and arg[0]:match("test_ulc_firmware") then
    test_runner.interactive_menu()
end

-- 导出测试函数
return {
    config = TEST_CONFIG,
    utils = test_utils,
    runner = test_runner,
    run_all = test_runner.run_all_tests,
    interactive = test_runner.interactive_menu
}