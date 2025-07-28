#!/usr/bin/env lua
-- ULC 固件更新使用示例
-- 演示如何使用 ulc_firmware_update_complete.lua 模块进行固件更新

-- 加载固件更新模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path
local ulc_update = require("ulc_firmware_update_complete")

-- 获取测试固件目录路径
local test_firmware_dir = this_dir .. "test_firmware/"

-- 示例1: 基本固件更新
local function example_basic_update()
    print("=== 📱 示例1: 基本固件更新 ===")
    
    -- 配置更新参数
    ulc_update.set_config("UPDATE_TYPE_FLAG", 0)  -- ULC直连324
    ulc_update.set_config("COMM_TYPE", 1)         -- ULC通信
    ulc_update.set_config("TEST_MODE", true)      -- 启用测试模式
    
    -- 执行固件更新
    local firmware_path = test_firmware_dir .. "DBCos324.bin"
    local success = ulc_update.update_firmware(firmware_path)
    
    if success then
        print("🎉 固件更新成功！")
    else
        print("❌ 固件更新失败！")
    end
    
    return success
end

-- 示例2: 带错误模拟的更新
local function example_error_simulation()
    print("=== ⚠️  示例2: 带错误模拟的更新 ===")
    
    -- 配置错误模拟
    ulc_update.set_config("UPDATE_TYPE_FLAG", 1)     -- BLE芯片
    ulc_update.set_config("TEST_MODE", true)         -- 启用测试模式
    ulc_update.set_config("SIMULATE_ERRORS", true)   -- 启用错误模拟
    ulc_update.set_config("ERROR_RATE", 0.15)        -- 15%错误率
    ulc_update.set_config("MAX_RETRIES", 3)          -- 最大重试3次
    
    -- 执行固件更新
    local firmware_path = test_firmware_dir .. "TDR_Ble_Slave_V1.0.25.bin"
    local success = ulc_update.update_firmware(firmware_path)
    
    if success then
        print("🎉 在有错误的情况下，固件更新仍然成功！")
    else
        print("❌ 固件更新失败，可能是错误率太高")
    end
    
    return success
end

-- 示例3: 自定义配置更新
local function example_custom_config()
    print("=== ⚙️  示例3: 自定义配置更新 ===")
    
    -- 显示当前配置
    print("📋 当前配置:")
    ulc_update.show_config()
    print("")
    
    -- 自定义配置
    ulc_update.set_config("UPDATE_TYPE_FLAG", 2)     -- 扩展324
    ulc_update.set_config("PACKET_SIZE", 512)        -- 增大数据包大小
    ulc_update.set_config("TEST_MODE", true)         -- 启用测试模式
    ulc_update.set_config("SIMULATE_ERRORS", false)  -- 禁用错误模拟
    
    print("🔧 配置已更新")
    print("")
    
    -- 执行固件更新
    local firmware_path = test_firmware_dir .. "DBCos324_LoopExtend.bin"
    local success = ulc_update.update_firmware(firmware_path)
    
    -- 恢复默认配置
    ulc_update.set_config("PACKET_SIZE", 256)
    
    return success
end

-- 示例4: 批量更新不同类型固件
local function example_batch_update()
    print("=== 📦 示例4: 批量更新不同类型固件 ===")
    
    local firmware_configs = {
        {
            type = 0,
            path = test_firmware_dir .. "DBCos324.bin",
            name = "ULC直连324固件"
        },
        {
            type = 1, 
            path = test_firmware_dir .. "TDR_Ble_Slave_V1.0.25.bin",
            name = "BLE芯片固件"
        },
        {
            type = 2,
            path = test_firmware_dir .. "DBCos324_LoopExtend.bin", 
            name = "扩展324固件"
        }
    }
    
    local results = {}
    
    for i, config in ipairs(firmware_configs) do
        print(string.format("\n📱 更新 %d/3: %s", i, config.name))
        
        -- 配置更新类型
        ulc_update.set_config("UPDATE_TYPE_FLAG", config.type)
        ulc_update.set_config("TEST_MODE", true)
        ulc_update.set_config("SIMULATE_ERRORS", false)
        
        -- 执行更新
        local success = ulc_update.update_firmware(config.path)
        results[config.name] = success
        
        if success then
            print("✅ " .. config.name .. " 更新成功")
        else
            print("❌ " .. config.name .. " 更新失败")
        end
    end
    
    -- 显示批量更新结果
    print("\n📊 批量更新结果汇总:")
    local success_count = 0
    for name, success in pairs(results) do
        print(string.format("  %s: %s", success and "✅" or "❌", name))
        if success then
            success_count = success_count + 1
        end
    end
    
    print(string.format("\n📈 成功率: %d/%d (%.1f%%)", 
                       success_count, #firmware_configs, 
                       (success_count * 100.0) / #firmware_configs))
    
    return success_count == #firmware_configs
end

-- 示例5: 性能测试
local function example_performance_test()
    print("=== ⚡ 示例5: 性能测试 ===")
    
    -- 配置高性能模式
    ulc_update.set_config("UPDATE_TYPE_FLAG", 0)
    ulc_update.set_config("PACKET_SIZE", 1024)       -- 使用更大的数据包
    ulc_update.set_config("TEST_MODE", true)
    ulc_update.set_config("SIMULATE_ERRORS", false)  -- 禁用错误模拟以获得最佳性能
    ulc_update.set_config("MAX_RETRIES", 1)          -- 减少重试次数
    
    local start_time = os.time()
    
    -- 执行固件更新
    local firmware_path = test_firmware_dir .. "DBCos324.bin"
    local success = ulc_update.update_firmware(firmware_path)
    
    local end_time = os.time()
    local duration = end_time - start_time
    
    print(string.format("⏱️  性能测试结果: %d 秒", duration))
    print(string.format("📊 更新状态: %s", success and "成功" or "失败"))
    
    -- 恢复默认配置
    ulc_update.set_config("PACKET_SIZE", 256)
    ulc_update.set_config("MAX_RETRIES", 5)
    
    return success
end

-- 创建测试固件文件（如果需要）
local function create_test_files()
    print("=== 📁 创建测试文件 ===")
    
    -- 创建测试目录
    local lfs = require("lfs")
    lfs.mkdir(test_firmware_dir)
    
    -- 创建简单的测试固件文件
    local test_files = {
        test_firmware_dir .. "DBCos324.bin",
        test_firmware_dir .. "TDR_Ble_Slave_V1.0.25.bin",
        test_firmware_dir .. "DBCos324_LoopExtend.bin"
    }
    
    for _, file_path in ipairs(test_files) do
        local file = io.open(file_path, "rb")
        if not file then
            print("📝 创建测试文件: " .. file_path)
            file = io.open(file_path, "wb")
            if file then
                -- 写入一些测试数据 (16KB)
                local test_data = string.rep("\x55\xAA\xFF\x00", 4096)
                file:write(test_data)
                file:close()
            end
        else
            file:close()
        end
    end
    
    print("✅ 测试文件准备完成")
end

-- 主函数
local function main()
    print("🚀 ULC 固件更新使用示例")
    print("=" .. string.rep("=", 50))
    
    -- 创建测试文件
    create_test_files()
    print("")
    
    local examples = {
        {name = "基本固件更新", func = example_basic_update},
        {name = "带错误模拟的更新", func = example_error_simulation},
        {name = "自定义配置更新", func = example_custom_config},
        {name = "批量更新不同类型固件", func = example_batch_update},
        {name = "性能测试", func = example_performance_test}
    }
    
    local results = {}
    
    for i, example in ipairs(examples) do
        print(string.format("\n🎯 运行示例 %d: %s", i, example.name))
        print("-" .. string.rep("-", 40))
        
        local start_time = os.time()
        local success = pcall(example.func)
        local duration = os.time() - start_time
        
        results[example.name] = {
            success = success,
            duration = duration
        }
        
        print(string.format("⏱️  耗时: %d 秒", duration))
        print(string.format("📊 结果: %s", success and "✅ 成功" or "❌ 失败"))
    end
    
    -- 显示总结
    print("\n" .. "=" .. string.rep("=", 50))
    print("📊 示例运行结果汇总")
    print("=" .. string.rep("=", 50))
    
    local success_count = 0
    local total_time = 0
    
    for name, result in pairs(results) do
        print(string.format("%s %s (耗时: %ds)", 
                           result.success and "✅" or "❌", 
                           name, 
                           result.duration))
        if result.success then
            success_count = success_count + 1
        end
        total_time = total_time + result.duration
    end
    
    print("")
    print(string.format("📈 成功率: %d/%d (%.1f%%)", 
                       success_count, #examples, 
                       (success_count * 100.0) / #examples))
    print(string.format("⏱️  总耗时: %d 秒", total_time))
    print(string.format("🕒 完成时间: %s", os.date("%Y-%m-%d %H:%M:%S")))
    
    if success_count == #examples then
        print("🎉 所有示例都运行成功！")
    else
        print("⚠️  有示例运行失败，请检查配置和环境")
    end
end

-- 运行示例
main()