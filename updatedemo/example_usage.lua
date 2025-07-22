#!/usr/bin/env lua
-- ULC 固件更新使用示例
-- 如何使用 ULC 固件更新模块的简单演示
-- 作者: Lua 实现团队
-- 日期: 2024
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path
-- 加载所需模块
local ulc_update = require("ulc_firmware_update")

-- 示例配置
local EXAMPLE_CONFIG = {
    firmware_file = "example_firmware.bin",
    firmware_size = 65536,  -- 64KB 示例固件
    update_type = 0,        -- ULC 直接 324
    comm_type = 1,          -- ULC 通信
    device_id = 2           -- 目标设备 ID
}

-- 创建示例固件的实用函数
local function create_example_firmware()
    print("创建示例固件文件...")
    
    local file, err = io.open(EXAMPLE_CONFIG.firmware_file, "wb")
    if not file then
        error("创建示例固件失败: " .. (err or "未知错误"))
    end
    
    -- 生成示例固件数据
    math.randomseed(os.time())
    for i = 1, EXAMPLE_CONFIG.firmware_size do
        local byte_val = math.random(0, 255)
        file:write(string.char(byte_val))
    end
    
    file:close()
    print("示例固件已创建: " .. EXAMPLE_CONFIG.firmware_file)
end

-- 主示例函数
local function run_example()
    print("=== ULC 固件更新示例 ===")
    print("此示例演示如何使用 ULC 固件更新模块")
    print("")
    
    -- 检查示例固件是否存在，如果不存在则创建
    local file = io.open(EXAMPLE_CONFIG.firmware_file, "rb")
    if not file then
        create_example_firmware()
    else
        file:close()
        print("使用现有固件文件: " .. EXAMPLE_CONFIG.firmware_file)
    end
    
    -- 配置更新模块
    ulc_update.config.UPDATE_TYPE_FLAG = EXAMPLE_CONFIG.update_type
    ulc_update.config.COMM_TYPE = EXAMPLE_CONFIG.comm_type
    ulc_update.config.DEVICE_ID = EXAMPLE_CONFIG.device_id
    
    print("配置:")
    print("  更新类型: " .. EXAMPLE_CONFIG.update_type .. " (ULC 直接 324)")
    print("  通信方式: " .. EXAMPLE_CONFIG.comm_type .. " (ULC)")
    print("  设备 ID: " .. EXAMPLE_CONFIG.device_id)
    print("")
    
    -- 询问用户是否要继续
    io.write("您想开始固件更新模拟吗? (y/n): ")
    local response = io.read()
    
    if response:lower() == "y" or response:lower() == "yes" then
        print("")
        print("开始固件更新模拟...")
        print("注意: 这是一个带有模拟响应的模拟演示")
        print("")
        
        -- 运行固件更新
        local success, err = pcall(function()
            ulc_update.update_firmware(EXAMPLE_CONFIG.firmware_file)
        end)
        
        if success then
            print("")
            print("=== 示例成功完成 ===")
            print("固件更新模拟已完成，没有错误。")
            print("在实际场景中，这将更新 ULC 设备固件。")
        else
            print("")
            print("=== 示例失败 ===")
            print("错误: " .. (err or "未知错误"))
        end
    else
        print("示例被用户取消。")
    end
end

-- 不同示例的交互式菜单
local function interactive_menu()
    print("\n=== ULC 固件更新示例 ===")
    print("1. 基本固件更新模拟")
    print("2. 显示模块配置")
    print("3. 测试实用函数")
    print("4. 测试文件操作")
    print("5. 测试通信函数")
    print("6. 创建示例固件文件")
    print("0. 退出")
    print("")
    
    io.write("选择示例 (0-6): ")
    local choice = io.read()
    
    if choice == "1" then
        run_example()
    elseif choice == "2" then
        print("\n=== 模块配置 ===")
        print("UPDATE_TYPE_FLAG: " .. ulc_update.config.UPDATE_TYPE_FLAG)
        print("COMM_TYPE: " .. ulc_update.config.COMM_TYPE)
        print("DEVICE_ID: " .. ulc_update.config.DEVICE_ID)
        print("PACKET_SIZE: " .. ulc_update.config.PACKET_SIZE)
        print("LOADER_SIZE: " .. ulc_update.config.LOADER_SIZE)
        print("PUB_KEY_X: " .. ulc_update.config.PUB_KEY_X)
        print("PUB_KEY_Y: " .. ulc_update.config.PUB_KEY_Y)
    elseif choice == "3" then
        print("\n=== 测试实用函数 ===")
        print("int_to_hex(255, 2): " .. ulc_update.utils.int_to_hex(255, 2))
        print("hex_to_int('FF'): " .. ulc_update.utils.hex_to_int("FF"))
        print("str_to_hex('Hello'): " .. ulc_update.utils.str_to_hex("Hello"))
        print("crc16c('1234', 0): " .. ulc_update.utils.crc16c("1234", 0))
    elseif choice == "4" then
        print("\n=== 测试文件操作 ===")
        if not io.open(EXAMPLE_CONFIG.firmware_file, "rb") then
            create_example_firmware()
        end
        local hex_data, length = ulc_update.file_ops.read_firmware(EXAMPLE_CONFIG.firmware_file)
        print("文件读取成功: " .. length .. " 字节")
        print("前 32 个十六进制字符: " .. hex_data:sub(1, 32))
    elseif choice == "5" then
        print("\n=== 测试通信函数 ===")
        local commands = {
            "00A4000002DF20",
            "E0B4011C022000",
            "80DB001C081122334455667788"
        }
        for _, cmd in ipairs(commands) do
            print("命令: " .. cmd)
            local response = ulc_update.comm.ulc_send_apdu(cmd)
            print("响应: " .. response:sub(1, 32) .. (#response > 32 and "..." or ""))
            print("")
        end
    elseif choice == "6" then
        create_example_firmware()
    elseif choice == "0" then
        print("再见!")
        return
    else
        print("无效选择!")
    end
    
    print("\n按回车键继续...")
    io.read()
    interactive_menu()
end

-- 如果直接运行此脚本，启动交互式菜单
if arg and arg[0] and arg[0]:match("example") then
    interactive_menu()
else
    -- 导出函数以用作模块
    return {
        run_example = run_example,
        create_example_firmware = create_example_firmware,
        interactive_menu = interactive_menu,
        config = EXAMPLE_CONFIG
    }
end