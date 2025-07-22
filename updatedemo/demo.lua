#!/usr/bin/env lua
-- ULC 固件更新演示脚本
-- 全面演示所有功能
-- 作者: Lua 实现团队
-- 日期: 2024

-- 加载所需模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path
local ulc_update = require("ulc_firmware_update")

-- 确保能正确找到config模块
package.path = this_dir .. "?.lua;" .. this_dir .. "../?.lua;" .. package.path
local config_mgr = require("config")

-- 演示配置
local DEMO_CONFIG = {
    demo_firmware_file = "demo_firmware.bin",
    demo_firmware_size = 32768,  -- 32KB
    demo_delay = 0.5,            -- 步骤之间的延迟，以提高可见性
}

-- 演示工具函数
local demo_utils = {}

-- 打印章节标题
function demo_utils.print_header(title)
    local line = string.rep("=", #title + 4)
    print("\n" .. line)
    print("  " .. title)
    print(line)
end

-- 打印步骤
function demo_utils.print_step(step_num, description)
    print(string.format("\nStep %d: %s", step_num, description))
    print(string.rep("-", #description + 10))
end

-- 等待并显示消息
function demo_utils.wait(message, seconds)
    if message then
        print(message)
    end
    if seconds and seconds > 0 then
        require("socket").sleep(seconds)
    end
end

-- 创建演示固件
function demo_utils.create_demo_firmware()
    print("正在创建演示固件文件...")
    
    local file, err = io.open(DEMO_CONFIG.demo_firmware_file, "wb")
    if not file then
        error("创建演示固件失败: " .. (err or "未知错误"))
    end
    
    -- 创建具有可识别模式的固件
    local pattern = "ULC_DEMO_FIRMWARE_"
    local pattern_len = #pattern
    
    for i = 1, DEMO_CONFIG.demo_firmware_size do
        local char_index = ((i - 1) % pattern_len) + 1
        local char = pattern:sub(char_index, char_index)
        file:write(char)
    end
    
    file:close()
    print(string.format("演示固件已创建: %s (%d 字节)", 
                       DEMO_CONFIG.demo_firmware_file, DEMO_CONFIG.demo_firmware_size))
end

-- 演示函数
local demo = {}

-- 演示 1: 配置管理
function demo.configuration_demo()
    demo_utils.print_header("Configuration Management Demo")
    
    demo_utils.print_step(1, "列出可用的配置预设")
    config_mgr.list()
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(2, "应用 ULC Direct 324 配置")
    local preset = config_mgr.apply(ulc_update, "ulc_direct_324")
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(3, "显示当前配置")
    print("当前配置:")
    local config_items = {
        "UPDATE_TYPE_FLAG", "COMM_TYPE", "DEVICE_ID", 
        "PACKET_SIZE", "LOADER_SIZE"
    }
    for _, key in ipairs(config_items) do
        print(string.format("  %-20s: %s", key, tostring(ulc_update.config[key])))
    end
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(4, "验证配置")
    local valid, errors = config_mgr.validate(ulc_update.config)
    if valid then
        print(" 配置有效")
    else
        print(" 配置错误:")
        for _, error in ipairs(errors) do
            print("  - " .. error)
        end
    end
    
    print("\n配置演示已完成！")
end

-- 演示 2: 文件操作
function demo.file_operations_demo()
    demo_utils.print_header("File Operations Demo")
    
    demo_utils.print_step(1, "创建演示固件文件")
    demo_utils.create_demo_firmware()
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(2, "读取固件文件")
    local hex_data, length = ulc_update.file_ops.read_firmware(DEMO_CONFIG.demo_firmware_file)
    print(string.format("已读取固件: %d 字节", length))
    print("前 64 个十六进制字符: " .. hex_data:sub(1, 64))
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(3, "测试工具函数")
    print("工具函数测试:")
    print("  int_to_hex(255, 4): " .. ulc_update.utils.int_to_hex(255, 4))
    print("  hex_to_int('00FF'): " .. ulc_update.utils.hex_to_int("00FF"))
    print("  str_to_hex('DEMO'): " .. ulc_update.utils.str_to_hex("DEMO"))
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(4, "计算 CRC16")
    local test_data = "ULC_FIRMWARE_UPDATE_DEMO"
    local crc = ulc_update.utils.crc16c(test_data, 0)
    print(string.format("'%s' 的 CRC16: 0x%04X", test_data, crc))
    
    print("\n文件操作演示已完成！")
end

-- 演示 3: 加密函数
function demo.crypto_demo()
    demo_utils.print_header("Cryptographic Functions Demo")
    
    demo_utils.print_step(1, "SM2 公钥操作")
    local public_key = ulc_update.config.PUB_KEY_X .. ulc_update.config.PUB_KEY_Y
    print("SM2 公钥 (前 32 个字符): " .. public_key:sub(1, 32) .. "...")
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(2, "SM2 加密")
    local test_data = "Hello ULC Firmware Update!"
    local encrypted = ulc_update.crypto.sm2_encrypt(public_key, test_data)
    print("原始数据: " .. test_data)
    print("加密后 (前 32 个字符): " .. encrypted:sub(1, 32) .. "...")
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(3, "SM2 签名验证")
    local signature = string.rep("A", 64)  -- 模拟签名
    local verified = ulc_update.crypto.sm2_verify(public_key, "", signature, test_data)
    print("签名验证: " .. (verified and "通过" or "失败"))
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(4, "SM4 操作")
    local sm4_key = string.rep("11", 16)
    local sm4_data = "SM4 加密测试数据"
    local sm4_encrypted = ulc_update.crypto.sm4_encrypt(sm4_key, nil, sm4_data, "ECB")
    local sm4_mac = ulc_update.crypto.sm4_mac(sm4_key, sm4_data)
    print("SM4 密钥: " .. sm4_key)
    print("SM4 加密后长度: " .. #sm4_encrypted)
    print("SM4 MAC: " .. sm4_mac)
    
    print("\n加密函数演示已完成！")
end

-- 演示 4: 通信模拟
function demo.communication_demo()
    demo_utils.print_header("Communication Simulation Demo")
    
    demo_utils.print_step(1, "APDU 命令测试")
    local test_commands = {
        {cmd = "00A4000002DF20", desc = "选择应用"},
        {cmd = "E0B4011C022000", desc = "获取 SM2 公钥"},
        {cmd = "80DB001C081122334455667788", desc = "获取 UUID 和签名"},
        {cmd = "F0F6020000", desc = "获取 COS 版本"}
    }
    
    for i, test in ipairs(test_commands) do
        print(string.format("\n命令 %d: %s", i, test.desc))
        print("APDU: " .. test.cmd)
        local response = ulc_update.comm.ulc_send_apdu(test.cmd)
        print("响应: " .. response:sub(1, 32) .. (#response > 32 and "..." or ""))
        demo_utils.wait("", DEMO_CONFIG.demo_delay * 0.5)
    end
    
    demo_utils.print_step(2, "进度显示测试")
    print("模拟固件传输进度:")
    local total_size = 1000
    for i = 0, 20 do
        local current = math.floor((i * total_size) / 20)
        ulc_update.progress.show_progress(current, total_size, "演示传输")
        demo_utils.wait("", 0.1)
    end
    
    print("\n通信模拟演示已完成！")
end

-- 演示 5: 完整更新流程
function demo.complete_update_demo()
    demo_utils.print_header("Complete Update Process Demo")
    
    demo_utils.print_step(1, "准备演示环境")
    if not io.open(DEMO_CONFIG.demo_firmware_file, "rb") then
        demo_utils.create_demo_firmware()
    end
    
    -- 应用开发配置以加快演示速度
    config_mgr.apply(ulc_update, "development")
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(2, "开始完整固件更新模拟")
    print("这将演示整个固件更新过程...")
    print("注意: 这是一个带有模拟响应的模拟演示")
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    local start_time = os.time()
    
    -- Run the complete update
    local success, err = pcall(function()
        ulc_update.update_firmware(DEMO_CONFIG.demo_firmware_file)
    end)
    
    local end_time = os.time()
    local duration = end_time - start_time
    
    demo_utils.print_step(3, "更新结果")
    if success then
        print("✓ 固件更新模拟成功完成！")
        print(string.format("总时间: %d 秒", duration))
        print("状态: 成功")
    else
        print("✗ 固件更新模拟失败！")
        print("错误: " .. (err or "未知错误"))
        print("状态: 失败")
    end
    
    print("\n完整更新流程演示已完成！")
end

-- 演示 6: 错误处理
function demo.error_handling_demo()
    demo_utils.print_header("Error Handling Demo")
    
    demo_utils.print_step(1, "测试文件未找到错误")
    local success, err = pcall(function()
        ulc_update.file_ops.read_firmware("nonexistent_file.bin")
    end)
    print("预期错误被捕获: " .. (err and "是" or "否"))
    if err then
        print("错误信息: " .. err)
    end
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(2, "测试无效配置")
    local invalid_config = {
        UPDATE_TYPE_FLAG = 99,  -- 无效值
        COMM_TYPE = -1,         -- 无效值
        PACKET_SIZE = 10        -- 太小
    }
    local valid, errors = config_mgr.validate(invalid_config)
    print("配置验证: " .. (valid and "通过" or "失败"))
    if not valid then
        print("验证错误:")
        for _, error in ipairs(errors) do
            print("  - " .. error)
        end
    end
    demo_utils.wait("", DEMO_CONFIG.demo_delay)
    
    demo_utils.print_step(3, "测试边界条件")
    print("使用边界值测试进度显示:")
    ulc_update.progress.show_progress(0, 100, "边界测试")
    ulc_update.progress.show_progress(50, 100, "边界测试")
    ulc_update.progress.show_progress(100, 100, "边界测试")
    ulc_update.progress.show_progress(150, 100, "边界测试")  -- 超过 100%
    
    print("\n错误处理演示已完成！")
end

-- 主演示运行器
function demo.run_all_demos()
    demo_utils.print_header("ULC 固件更新 - 完整演示")
    print("此演示展示了 ULC 固件更新系统的所有功能")
    print("平台: Windows")
    print("Lua 版本: " .. _VERSION)
    print("开始时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    
    local demos = {
        {func = demo.configuration_demo, name = "配置管理"},
        {func = demo.file_operations_demo, name = "文件操作"},
        {func = demo.crypto_demo, name = "加密函数"},
        {func = demo.communication_demo, name = "通信模拟"},
        {func = demo.error_handling_demo, name = "错误处理"},
        {func = demo.complete_update_demo, name = "完整更新流程"}
    }
    
    for i, demo_item in ipairs(demos) do
        print(string.format("\n\n>>> 运行演示 %d/%d: %s <<<", i, #demos, demo_item.name))
        demo_utils.wait("按回车键继续...", 0)
        io.read()
        
        local success, err = pcall(demo_item.func)
        if not success then
            print("演示失败: " .. (err or "未知错误"))
        end
        
        demo_utils.wait("演示完成。", 1)
    end
    
    demo_utils.print_header("所有演示已完成")
    print("总结:")
    print("- 配置管理和验证")
    print("- 文件操作和实用函数")
    print("- 加密操作 (SM2/SM4)")
    print("- 通信模拟")
    print("- 错误处理和边界条件")
    print("- 完整固件更新流程")
    print("")
    print("结束时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("感谢您尝试 ULC 固件更新系统！")
    
    -- 清理
    if io.open(DEMO_CONFIG.demo_firmware_file, "rb") then
        os.remove(DEMO_CONFIG.demo_firmware_file)
        print("\n演示文件已清理。")
    end
end

-- 交互式演示菜单
function demo.interactive_menu()
    print("\n=== ULC 固件更新演示菜单 ===")
    print("1. 运行所有演示")
    print("2. 配置管理演示")
    print("3. 文件操作演示")
    print("4. 加密函数演示")
    print("5. 通信模拟演示")
    print("6. 错误处理演示")
    print("7. 完整更新流程演示")
    print("8. 快速概览")
    print("0. 退出")
    print("")
    
    io.write("选择演示 (0-8): ")
    local choice = io.read()
    
    if choice == "1" then
        demo.run_all_demos()
    elseif choice == "2" then
        demo.configuration_demo()
    elseif choice == "3" then
        demo.file_operations_demo()
    elseif choice == "4" then
        demo.crypto_demo()
    elseif choice == "5" then
        demo.communication_demo()
    elseif choice == "6" then
        demo.error_handling_demo()
    elseif choice == "7" then
        demo.complete_update_demo()
    elseif choice == "8" then
        demo_utils.print_header("ULC 固件更新 - 快速概览")
        print("本系统提供:")
        print("• ULC 设备的安全固件更新")
        print("• SM2/SM4 加密保护")
        print("• 多种通信方式 (ULC/USB)")
        print("• 全面的测试框架")
        print("• Windows 平台优化")
        print("• 用于开发的模拟仿真")
        print("\n要查看完整演示，请选择选项 1。")
    elseif choice == "0" then
        print("再见!")
        return
    else
        print("无效选择!")
    end
    
    print("\n按回车键继续...")
    io.read()
    demo.interactive_menu()
end

-- 如果直接运行此脚本，启动交互式菜单
if arg and arg[0] and arg[0]:match("demo") then
    demo.interactive_menu()
end

-- 导出演示函数
return {
    config = DEMO_CONFIG,
    utils = demo_utils,
    demos = demo,
    run_all = demo.run_all_demos,
    interactive = demo.interactive_menu
}