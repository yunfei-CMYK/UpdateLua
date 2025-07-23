#!/usr/bin/env lua
-- ULC 固件更新启动脚本
-- 提供简单的命令行界面来执行固件更新

-- 加载必要模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path
local config = require("config")
local ulc_update = require("ulc_firmware_update_complete")


-- 显示帮助信息
local function show_help()
    print("ULC 固件更新工具 v1.0.0")
    print("=" .. string.rep("=", 40))
    print("")
    print("用法:")
    print("  lua start.lua <命令> [选项]")
    print("")
    print("命令:")
    print("  update <固件路径>     - 执行固件更新")
    print("  test                 - 运行测试")
    print("  config               - 显示配置")
    print("  help                 - 显示帮助")
    print("")
    print("选项:")
    print("  --type <0|1|2>       - 更新类型 (0:ULC直连324, 1:BLE芯片, 2:扩展324)")
    print("  --env <环境>         - 环境配置 (production|testing|development)")
    print("  --device <设备>      - 设备配置 (ulc_direct_324|ble_chip|extend_324)")
    print("  --packet-size <大小> - 数据包大小")
    print("  --test-mode          - 启用测试模式")
    print("  --simulate-errors    - 启用错误模拟")
    print("  --error-rate <比率>  - 错误率 (0.0-1.0)")
    print("  --max-retries <次数> - 最大重试次数")
    print("  --verbose            - 详细输出")
    print("")
    print("示例:")
    print("  lua start.lua update firmware/DBCos324.bin --type 0")
    print("  lua start.lua update test_firmware/DBCos324.bin --env testing")
    print("  lua start.lua test")
    print("  lua start.lua config")
end

-- 解析命令行参数
local function parse_args(args)
    local parsed = {
        command = nil,
        firmware_path = nil,
        options = {}
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if not parsed.command then
            parsed.command = arg
        elseif parsed.command == "update" and not parsed.firmware_path then
            parsed.firmware_path = arg
        elseif arg == "--type" then
            i = i + 1
            parsed.options.type = tonumber(args[i])
        elseif arg == "--env" then
            i = i + 1
            parsed.options.env = args[i]
        elseif arg == "--device" then
            i = i + 1
            parsed.options.device = args[i]
        elseif arg == "--packet-size" then
            i = i + 1
            parsed.options.packet_size = tonumber(args[i])
        elseif arg == "--test-mode" then
            parsed.options.test_mode = true
        elseif arg == "--simulate-errors" then
            parsed.options.simulate_errors = true
        elseif arg == "--error-rate" then
            i = i + 1
            parsed.options.error_rate = tonumber(args[i])
        elseif arg == "--max-retries" then
            i = i + 1
            parsed.options.max_retries = tonumber(args[i])
        elseif arg == "--verbose" then
            parsed.options.verbose = true
        end
        
        i = i + 1
    end
    
    return parsed
end

-- 应用配置选项
local function apply_config(options)
    -- 应用环境配置
    if options.env then
        local env_config = config.get_config(options.env)
        for key, value in pairs(env_config) do
            ulc_update.set_config(key, value)
        end
        print("✅ 已应用环境配置: " .. options.env)
    end
    
    -- 应用设备配置
    if options.device then
        local device_config = config.get_device_config(options.device)
        for key, value in pairs(device_config) do
            ulc_update.set_config(key, value)
        end
        print("✅ 已应用设备配置: " .. options.device)
    end
    
    -- 应用其他选项
    if options.type then
        ulc_update.set_config("UPDATE_TYPE_FLAG", options.type)
    end
    
    if options.packet_size then
        ulc_update.set_config("PACKET_SIZE", options.packet_size)
    end
    
    if options.test_mode then
        ulc_update.set_config("TEST_MODE", true)
    end
    
    if options.simulate_errors then
        ulc_update.set_config("SIMULATE_ERRORS", true)
    end
    
    if options.error_rate then
        ulc_update.set_config("ERROR_RATE", options.error_rate)
    end
    
    if options.max_retries then
        ulc_update.set_config("MAX_RETRIES", options.max_retries)
    end
    
    if options.verbose then
        ulc_update.set_config("VERBOSE_OUTPUT", true)
    end
end

-- 执行固件更新
local function execute_update(firmware_path, options)
    print("🚀 开始固件更新")
    print("📁 固件路径: " .. firmware_path)
    print("")
    
    -- 应用配置
    apply_config(options)
    
    -- 显示当前配置
    print("⚙️  当前配置:")
    local update_type = ulc_update.get_config("UPDATE_TYPE_FLAG")
    local type_names = {[0] = "ULC直连324", [1] = "BLE芯片", [2] = "扩展324"}
    print("  更新类型: " .. (type_names[update_type] or "未知"))
    print("  数据包大小: " .. ulc_update.get_config("PACKET_SIZE"))
    print("  测试模式: " .. (ulc_update.get_config("TEST_MODE") and "启用" or "禁用"))
    print("  错误模拟: " .. (ulc_update.get_config("SIMULATE_ERRORS") and "启用" or "禁用"))
    print("  最大重试: " .. ulc_update.get_config("MAX_RETRIES"))
    print("")
    
    -- 检查固件文件
    local file = io.open(firmware_path, "rb")
    if not file then
        print("❌ 固件文件不存在: " .. firmware_path)
        print("💡 提示: 运行 'lua test_ulc_update.lua create' 创建测试固件")
        return false
    end
    file:close()
    
    -- 执行更新
    local start_time = os.time()
    local success = ulc_update.update_firmware(firmware_path)
    local duration = os.time() - start_time
    
    -- 显示结果
    print("")
    print("=" .. string.rep("=", 50))
    if success then
        print("🎉 固件更新成功完成！")
    else
        print("❌ 固件更新失败！")
    end
    print("⏱️  总耗时: " .. duration .. " 秒")
    print("🕒 完成时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    
    return success
end

-- 运行测试
local function execute_test()
    print("🧪 运行测试...")
    os.execute("lua test_ulc_update.lua all")
end

-- 显示配置
local function show_config()
    print("⚙️  当前配置:")
    ulc_update.show_config()
    
    print("🌍 可用环境配置:")
    local environments = {"production", "testing", "development", "performance", "stress"}
    for _, env in ipairs(environments) do
        print("  " .. env)
    end
    
    print("")
    print("📱 可用设备配置:")
    local devices = {"ulc_direct_324", "ble_chip", "extend_324"}
    for _, device in ipairs(devices) do
        print("  " .. device)
    end
end

-- 主函数
local function main(...)
    local args = {...}
    
    if #args == 0 then
        show_help()
        return
    end
    
    local parsed = parse_args(args)
    
    if parsed.command == "help" or parsed.command == "--help" or parsed.command == "-h" then
        show_help()
    elseif parsed.command == "update" then
        if not parsed.firmware_path then
            print("❌ 错误: 缺少固件路径")
            print("用法: lua start.lua update <固件路径> [选项]")
            return
        end
        execute_update(parsed.firmware_path, parsed.options)
    elseif parsed.command == "test" then
        execute_test()
    elseif parsed.command == "config" then
        show_config()
    else
        print("❌ 未知命令: " .. (parsed.command or ""))
        print("运行 'lua start.lua help' 查看帮助")
    end
end

-- 运行主函数
main(...)