#!/usr/bin/env lua
-- ULC 固件更新测试脚本
-- 用于测试和演示 ulc_firmware_update_complete.lua 模块的功能

-- 加载固件更新模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path
local ulc_update_module = require("ulc_firmware_update_complete")

-- 获取测试固件目录路径
local test_firmware_dir = this_dir .. "test_firmware/"

-- 测试配置
local TEST_CONFIG = {
    -- 测试固件文件路径（绝对路径）
    TEST_FIRMWARE_PATHS = {
        [0] = test_firmware_dir .. "DBCos324.bin",
        [1] = test_firmware_dir .. "TDR_Ble_Slave_V1.0.25.bin", 
        [2] = test_firmware_dir .. "DBCos324_LoopExtend.bin"
    },
    
    -- 测试模式配置
    ENABLE_ERROR_SIMULATION = true,  -- 是否启用错误模拟
    ERROR_RATE = 0.1,               -- 错误率 (10%)
    VERBOSE_OUTPUT = true,          -- 是否显示详细输出
}

-- 创建测试固件文件（如果不存在）
local function create_test_firmware()
    print("=== 📁 创建测试固件文件 ===")
    
    -- 创建测试固件目录
    local lfs = require("lfs")
    lfs.mkdir(test_firmware_dir)
    
    -- 创建模拟固件文件
    local test_firmwares = {
        {
            name = "DBCos324.bin",
            size = 64 * 1024,  -- 64KB
            description = "ULC直连324固件"
        },
        {
            name = "TDR_Ble_Slave_V1.0.25.bin", 
            size = 32 * 1024,  -- 32KB
            description = "BLE芯片固件"
        },
        {
            name = "DBCos324_LoopExtend.bin",
            size = 48 * 1024,  -- 48KB
            description = "扩展324固件"
        }
    }
    
    for _, firmware in ipairs(test_firmwares) do
        local file_path = test_firmware_dir .. firmware.name
        local file = io.open(file_path, "rb")
        
        if not file then
            print("📝 创建测试固件: " .. firmware.name)
            file = io.open(file_path, "wb")
            
            if file then
                -- 创建模拟固件数据
                local pattern = string.rep("\x55\xAA\xFF\x00", 64)  -- 256字节模式
                local written = 0
                
                while written < firmware.size do
                    local to_write = math.min(#pattern, firmware.size - written)
                    file:write(pattern:sub(1, to_write))
                    written = written + to_write
                end
                
                file:close()
                print(string.format("✅ %s 已创建 (%.1f KB)", firmware.name, firmware.size / 1024))
            else
                print("❌ 创建固件文件失败: " .. firmware.name)
            end
        else
            file:close()
            print("ℹ️  固件文件已存在: " .. firmware.name)
        end
    end
    
    print("")
end

-- 测试单个更新类型
local function test_update_type(update_type)
    print(string.format("=== 🧪 测试更新类型 %d ===", update_type))
    
    local type_names = {
        [0] = "ULC直连324",
        [1] = "BLE芯片", 
        [2] = "扩展324"
    }
    
    print("📋 更新类型: " .. (type_names[update_type] or "未知"))
    
    -- 配置更新类型
    ulc_update_module.set_config("UPDATE_TYPE_FLAG", update_type)
    ulc_update_module.set_config("TEST_MODE", true)
    ulc_update_module.set_config("SIMULATE_ERRORS", TEST_CONFIG.ENABLE_ERROR_SIMULATION)
    ulc_update_module.set_config("ERROR_RATE", TEST_CONFIG.ERROR_RATE)
    
    -- 获取对应的固件路径
    local firmware_path = TEST_CONFIG.TEST_FIRMWARE_PATHS[update_type]
    
    if not firmware_path then
        print("❌ 未找到对应的固件路径")
        return false
    end
    
    -- 检查固件文件是否存在
    local file = io.open(firmware_path, "rb")
    if not file then
        print("❌ 固件文件不存在: " .. firmware_path)
        return false
    end
    file:close()
    
    print("📁 固件路径: " .. firmware_path)
    print("")
    
    -- 执行固件更新
    local success = ulc_update_module.update_firmware(firmware_path)
    
    print("")
    print("📊 测试结果: " .. (success and "✅ 成功" or "❌ 失败"))
    print("")
    
    return success
end

-- 测试配置功能
local function test_configuration()
    print("=== ⚙️  测试配置功能 ===")
    
    -- 显示当前配置
    ulc_update_module.show_config()
    print("")
    
    -- 测试配置修改
    print("🔧 测试配置修改:")
    ulc_update_module.set_config("PACKET_SIZE", 512)
    ulc_update_module.set_config("MAX_RETRIES", 3)
    ulc_update_module.set_config("TEST_MODE", false)
    print("")
    
    -- 测试配置获取
    print("📖 测试配置获取:")
    print("  PACKET_SIZE: " .. tostring(ulc_update_module.get_config("PACKET_SIZE")))
    print("  MAX_RETRIES: " .. tostring(ulc_update_module.get_config("MAX_RETRIES")))
    print("  TEST_MODE: " .. tostring(ulc_update_module.get_config("TEST_MODE")))
    print("")
    
    -- 恢复默认配置
    print("🔄 恢复默认配置:")
    ulc_update_module.set_config("PACKET_SIZE", 256)
    ulc_update_module.set_config("MAX_RETRIES", 5)
    ulc_update_module.set_config("TEST_MODE", true)
    print("")
end

-- 测试工具函数
local function test_utility_functions()
    print("=== 🔧 测试工具函数 ===")
    
    local utils = ulc_update_module.utils
    
    -- 测试数值转换
    print("🔢 数值转换测试:")
    print("  int_to_hex(255, 4): " .. utils.int_to_hex(255, 4))
    print("  hex_to_int('FF'): " .. utils.hex_to_int('FF'))
    print("")
    
    -- 测试字符串操作
    print("📝 字符串操作测试:")
    print("  pad_string('ABC', '0', 8): " .. utils.pad_string('ABC', '0', 8))
    print("  str_mid('ABCDEFGH', 3, 4): " .. utils.str_mid('ABCDEFGH', 3, 4))
    print("")
    
    -- 测试CRC计算
    print("🔍 CRC计算测试:")
    local test_data = "48656C6C6F"  -- "Hello" 的十六进制
    local crc_result = utils.crc16c(test_data, 0)
    print("  crc16c('" .. test_data .. "'): " .. utils.int_to_hex(crc_result, 4))
    print("")
    
    -- 测试随机数生成
    print("🎲 随机数生成测试:")
    print("  generate_random_hex(16): " .. utils.generate_random_hex(16))
    print("")
end

-- 测试bitmap功能
local function test_bitmap_functions()
    print("=== 📊 测试 Bitmap 功能 ===")
    
    local bitmap = ulc_update_module.bitmap
    local utils = ulc_update_module.utils
    
    -- 清空bitmap信息
    bitmap.clear_block_info()
    
    -- 添加一些测试数据块
    print("📦 添加测试数据块:")
    for i = 0, 9 do
        bitmap.add_block_info(i, i * 256, 0x5000 + i * 256, 256)
    end
    print("")
    
    -- 测试获取数据块信息
    print("📋 获取数据块信息:")
    for i = 0, 4 do
        local info = bitmap.get_block_info(i)
        if info then
            print(string.format("  块 %d: 偏移=%d, Flash地址=0x%X, 长度=%d", 
                               i, info.file_offset, info.spi_flash_addr, info.block_len))
        end
    end
    print("")
    
    -- 测试bitmap位操作
    print("🔢 Bitmap 位操作测试:")
    local test_bitmap = {}
    
    -- 设置一些位
    utils.set_bit(test_bitmap, 0)
    utils.set_bit(test_bitmap, 3)
    utils.set_bit(test_bitmap, 7)
    utils.set_bit(test_bitmap, 15)
    
    -- 检查位状态
    for i = 0, 15 do
        local is_set = utils.is_bit_set(test_bitmap, i)
        if is_set then
            print(string.format("  位 %d: 已设置", i))
        end
    end
    
    -- 检查bitmap是否完整
    local is_complete = utils.is_bitmap_complete(test_bitmap, 16)
    print("  Bitmap 完整性: " .. (is_complete and "完整" or "不完整"))
    print("")
end

-- 主测试函数
local function run_all_tests()
    print("🚀 ULC 固件更新模块测试开始")
    print("=" .. string.rep("=", 50))
    print("")
    
    local start_time = os.time()
    local test_results = {}
    
    -- 创建测试固件文件
    create_test_firmware()
    
    -- 测试配置功能
    local success = pcall(test_configuration)
    test_results["配置功能"] = success
    
    -- 测试工具函数
    success = pcall(test_utility_functions)
    test_results["工具函数"] = success
    
    -- 测试bitmap功能
    success = pcall(test_bitmap_functions)
    test_results["Bitmap功能"] = success
    
    -- 测试各种更新类型
    for update_type = 0, 2 do
        local test_name = string.format("更新类型%d", update_type)
        success = pcall(test_update_type, update_type)
        test_results[test_name] = success
    end
    
    -- 显示测试结果汇总
    local end_time = os.time()
    local duration = end_time - start_time
    
    print("=" .. string.rep("=", 50))
    print("📊 测试结果汇总")
    print("=" .. string.rep("=", 50))
    
    local passed = 0
    local total = 0
    
    for test_name, result in pairs(test_results) do
        total = total + 1
        if result then
            passed = passed + 1
            print(string.format("✅ %s: 通过", test_name))
        else
            print(string.format("❌ %s: 失败", test_name))
        end
    end
    
    print("")
    print(string.format("📈 总计: %d/%d 测试通过 (%.1f%%)", passed, total, (passed * 100.0) / total))
    print(string.format("⏱️  总耗时: %d 秒", duration))
    print(string.format("🕒 完成时间: %s", os.date("%Y-%m-%d %H:%M:%S", end_time)))
    
    if passed == total then
        print("🎉 所有测试都通过了！")
    else
        print("⚠️  有测试失败，请检查输出信息")
    end
end

-- 交互式测试菜单
local function interactive_menu()
    while true do
        print("\n=== 🎮 ULC 固件更新测试菜单 ===")
        print("1. 运行所有测试")
        print("2. 测试 ULC直连324 更新")
        print("3. 测试 BLE芯片 更新")
        print("4. 测试 扩展324 更新")
        print("5. 测试配置功能")
        print("6. 测试工具函数")
        print("7. 测试 Bitmap 功能")
        print("8. 显示当前配置")
        print("9. 创建测试固件")
        print("0. 退出")
        print("")
        
        io.write("请选择操作 (0-9): ")
        local choice = io.read()
        
        if choice == "1" then
            run_all_tests()
        elseif choice == "2" then
            test_update_type(0)
        elseif choice == "3" then
            test_update_type(1)
        elseif choice == "4" then
            test_update_type(2)
        elseif choice == "5" then
            test_configuration()
        elseif choice == "6" then
            test_utility_functions()
        elseif choice == "7" then
            test_bitmap_functions()
        elseif choice == "8" then
            ulc_update_module.show_config()
        elseif choice == "9" then
            create_test_firmware()
        elseif choice == "0" then
            print("👋 再见！")
            break
        else
            print("❌ 无效选择，请重试")
        end
    end
end

-- 检查命令行参数
local function main(...)
    local args = {...}
    
    if #args == 0 then
        -- 没有参数，显示交互式菜单
        interactive_menu()
    elseif args[1] == "all" then
        -- 运行所有测试
        run_all_tests()
    elseif args[1] == "type" and args[2] then
        -- 测试特定更新类型
        local update_type = tonumber(args[2])
        if update_type and update_type >= 0 and update_type <= 2 then
            test_update_type(update_type)
        else
            print("❌ 无效的更新类型，请使用 0、1 或 2")
        end
    elseif args[1] == "config" then
        -- 测试配置功能
        test_configuration()
    elseif args[1] == "utils" then
        -- 测试工具函数
        test_utility_functions()
    elseif args[1] == "bitmap" then
        -- 测试bitmap功能
        test_bitmap_functions()
    elseif args[1] == "create" then
        -- 创建测试固件
        create_test_firmware()
    else
        print("用法:")
        print("  lua test_ulc_update.lua              # 交互式菜单")
        print("  lua test_ulc_update.lua all          # 运行所有测试")
        print("  lua test_ulc_update.lua type <0-2>   # 测试特定更新类型")
        print("  lua test_ulc_update.lua config       # 测试配置功能")
        print("  lua test_ulc_update.lua utils        # 测试工具函数")
        print("  lua test_ulc_update.lua bitmap       # 测试bitmap功能")
        print("  lua test_ulc_update.lua create       # 创建测试固件")
    end
end

-- 运行主函数
main(...)