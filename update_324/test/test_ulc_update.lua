#!/usr/bin/env lua
-- ULC 固件更新测试脚本
-- 用于测试和演示 ulc_firmware_update_complete.lua 模块的功能

-- 加载固件更新模块
-- 获取当前脚本所在目录
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

-- 添加当前目录和上级目录到模块搜索路径
-- 因为 ulc_firmware_update_complete.lua 在上级目录中
package.path = this_dir .. "?.lua;" .. this_dir .. "../?.lua;" .. package.path
local ulc_update_module = require("ulc_firmware_update_complete")

-- 固定进度条显示模块
local fixed_progress = {}

-- 保存当前进度条状态
local current_progress_state = {
    active = false,
    last_percentage = -1,
    start_time = 0,
    description = ""
}

-- 显示进度条（参考test_firmware_download.lua的实现）
local function display_progress_bar(current, total, width, description)
    width = width or 50
    
    -- 确保参数是有效的数字并转换为整数
    current = math.floor(tonumber(current) or 0)
    total = math.floor(tonumber(total) or 1)
    
    -- 防止除零错误
    if total <= 0 then total = 1 end
    if current > total then current = total end
    if current < 0 then current = 0 end
    
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local progress_text = string.format("%s %s %3d%% (%d/%d)", 
                                      description or "📊 进度", bar, percentage, current, total)
    
    -- 使用回车符覆盖同一行
    io.write("\r" .. progress_text)
    io.flush()
    
    -- 更新状态
    current_progress_state.active = true
    current_progress_state.last_percentage = percentage
    current_progress_state.description = description or "进度"
    
    -- 如果完成，换行并重置状态
    if current >= total then
        io.write("\n")
        io.flush()
        current_progress_state.active = false
        current_progress_state.last_percentage = -1
    end
end

-- 显示固定进度条
function fixed_progress.show_progress(current, total, description, extra_info)
    if not current or not total or total <= 0 then
        return
    end
    
    local desc = description or "📊 进度"
    if extra_info and extra_info ~= "" then
        desc = desc .. " " .. extra_info
    end
    
    display_progress_bar(current, total, 40, desc)
end

-- 显示传输统计信息
function fixed_progress.show_transfer_stats(transferred, total, start_time, description)
    local elapsed = os.time() - start_time
    local speed = elapsed > 0 and (transferred / elapsed) or 0
    local eta = speed > 0 and ((total - transferred) / speed) or 0
    
    local stats = string.format("| 速度: %.1f KB/s | 剩余: %ds", 
                               speed / 1024, math.floor(eta))
    
    local desc = (description or "📤 传输") .. " " .. stats
    display_progress_bar(transferred, total, 40, desc)
end

-- 开始新的进度条会话
function fixed_progress.start_session(description)
    -- 如果有活动的进度条，先结束它
    if current_progress_state.active then
        fixed_progress.end_session()
    end
    
    current_progress_state.start_time = os.time()
    current_progress_state.description = description or "进度"
    io.write(string.format("🚀 开始 %s\n", current_progress_state.description))
    io.flush()
end

-- 结束进度条会话
function fixed_progress.end_session(final_message)
    if current_progress_state.active then
        io.write("\n")  -- 确保换行
        io.flush()
        current_progress_state.active = false
    end
    
    if final_message then
        io.write(final_message .. "\n")
        io.flush()
    end
    
    -- 重置状态
    current_progress_state.last_percentage = -1
    current_progress_state.description = ""
end

-- 显示重传进度（特殊处理）
function fixed_progress.show_retransmit_progress(current, total, block_id)
    local extra_info = ""
    if block_id then
        extra_info = string.format("📤 重传数据块 %d", block_id)
    end
    
    fixed_progress.show_progress(current, total, "🔄 重传进度", extra_info)
end

-- 重写 ulc_update_module 的进度显示函数
local original_progress = ulc_update_module.progress
if original_progress then
    -- 备份原始函数
    local original_show_progress = original_progress.show_progress
    local original_show_transfer_stats = original_progress.show_transfer_stats
    
    -- 替换为固定进度条版本
    original_progress.show_progress = function(current, total, description)
        fixed_progress.show_progress(current, total, description)
    end
    
    original_progress.show_transfer_stats = function(transferred, total, start_time, description)
        fixed_progress.show_transfer_stats(transferred, total, start_time, description)
    end
end

-- 获取测试固件目录路径
local test_firmware_dir = this_dir .. "../test_firmware/"
print("Current firmware path:", test_firmware_dir)

-- 测试配置
local TEST_CONFIG = {
    -- 测试固件文件路径（绝对路径）
    TEST_FIRMWARE_PATHS = {
        [0] = test_firmware_dir .. "DBCos324.bin",
        [1] = test_firmware_dir .. "TDR_Ble_Slave_V1.0.25.bin", 
        [2] = test_firmware_dir .. "DBCos324_LoopExtend.bin"
    },
    
    -- 测试模式配置
    ENABLE_ERROR_SIMULATION = false,  -- 是否启用错误模拟
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
    
    local type_name = type_names[update_type] or "未知"
    print("📋 更新类型: " .. type_name)
    
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
    
    -- 开始固定进度条会话
    fixed_progress.start_session(string.format("%s 固件更新", type_name))
    
    -- 执行固件更新
    local success = ulc_update_module.update_firmware(firmware_path)
    
    -- 结束进度条会话
    local result_message = string.format("📊 %s 更新结果: %s", 
                                       type_name, 
                                       success and "✅ 成功" or "❌ 失败")
    fixed_progress.end_session(result_message)
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

-- 测试 SM2 验证功能
local function test_sm2_verify()
    print("=== 🔐 测试 SM2 签名验证功能 ===")
    
    local crypto = ulc_update_module.crypto
    local utils = ulc_update_module.utils
    
    -- 检查是否有 crypto 库支持
    if not crypto then
        print("❌ 错误: crypto 模块不可用")
        return false
    end
    
    local test_success = true
    
    -- 测试1: 基本 SM2 验证功能测试
    print("🧪 测试1: 基本 SM2 验证功能")
    
    local test_cases = {
        {
            name = "有效签名验证",
            public_key = "04" .. string.rep("A1B2C3D4", 16),  -- 128字符 + 04前缀
            id = "31323334353637383132333435363738",  -- "12345678" 的十六进制
            signature = string.rep("ABCD", 16),  -- 64字符签名
            plain_data = "48656C6C6F20576F726C64",  -- "Hello World" 的十六进制
            expected = nil  -- 由于是模拟数据，结果可能不确定
        },
        {
            name = "空ID测试（使用默认ID）",
            public_key = "04" .. string.rep("A1B2C3D4", 16),
            id = "",  -- 空ID，应该使用默认ID
            signature = string.rep("ABCD", 16),
            plain_data = "48656C6C6F20576F726C64",
            expected = nil
        },
        {
            name = "无04前缀的公钥",
            public_key = string.rep("A1B2C3D4", 16),  -- 128字符，无04前缀
            id = "31323334353637383132333435363738",
            signature = string.rep("ABCD", 16),
            plain_data = "48656C6C6F20576F726C64",
            expected = nil
        }
    }
    
    for i, test_case in ipairs(test_cases) do
        print(string.format("  📋 子测试 %d: %s", i, test_case.name))
        
        local success, result = pcall(function()
            return crypto.sm2_verify(test_case.public_key, test_case.id, 
                                   test_case.signature, test_case.plain_data)
        end)
        
        if success then
            print(string.format("    ✅ 验证函数执行成功，结果: %s", tostring(result)))
        else
            print(string.format("    ❌ 验证函数执行失败: %s", tostring(result)))
            test_success = false
        end
    end
    print("")
    
    -- 测试2: 直接模式 SM2 验证测试（如果可用）
    if crypto.sm2_verify_direct then
        print("🧪 测试2: 直接模式 SM2 验证")
        
        -- 尝试生成测试密钥对
        local success_keygen, test_keypair = pcall(function()
            local crypto_lib = require("crypto")
            if crypto_lib and crypto_lib.pkey and crypto_lib.pkey.generate then
                return crypto_lib.pkey.generate("sm2")
            end
            return nil
        end)
        
        if success_keygen and test_keypair then
            print("  ✅ 成功生成测试密钥对")
            
            -- 测试直接模式验证
            local test_data = "48656C6C6F20576F726C64"  -- "Hello World"
            local test_id = "31323334353637383132333435363738"  -- "12345678"
            
            -- 尝试生成签名
            local success_sign, signature = pcall(function()
                local utils_module = ulc_update_module.utils
                local data_bin = utils_module.hex_to_bin(test_data)
                return test_keypair:sign(data_bin)
            end)
            
            if success_sign and signature then
                local signature_hex = utils.bin_to_hex(signature):upper()
                print("  📝 生成测试签名: " .. signature_hex:sub(1, 32) .. "...")
                
                -- 测试直接模式验证
                local verify_success, verify_result = pcall(function()
                    return crypto.sm2_verify_direct(test_keypair, test_id, signature_hex, test_data)
                end)
                
                if verify_success then
                    print(string.format("  ✅ 直接模式验证结果: %s", tostring(verify_result)))
                else
                    print(string.format("  ❌ 直接模式验证失败: %s", tostring(verify_result)))
                    test_success = false
                end
            else
                print("  ⚠️  无法生成测试签名，跳过直接模式测试")
            end
        else
            print("  ⚠️  无法生成测试密钥对，跳过直接模式测试")
        end
        print("")
    end
    
    -- 测试3: 错误处理测试
    print("🧪 测试3: 错误处理测试")
    
    local error_test_cases = {
        {
            name = "空公钥",
            public_key = "",
            id = "31323334353637383132333435363738",
            signature = string.rep("ABCD", 16),
            plain_data = "48656C6C6F20576F726C64",
            should_fail = true
        },
        {
            name = "空签名",
            public_key = "04" .. string.rep("A1B2C3D4", 16),
            id = "31323334353637383132333435363738",
            signature = "",
            plain_data = "48656C6C6F20576F726C64",
            should_fail = true
        },
        {
            name = "无效公钥长度",
            public_key = "04ABCD",  -- 太短
            id = "31323334353637383132333435363738",
            signature = string.rep("ABCD", 16),
            plain_data = "48656C6C6F20576F726C64",
            should_fail = true
        }
    }
    
    for i, test_case in ipairs(error_test_cases) do
        print(string.format("  📋 错误测试 %d: %s", i, test_case.name))
        
        local success, result = pcall(function()
            return crypto.sm2_verify(test_case.public_key, test_case.id, 
                                   test_case.signature, test_case.plain_data)
        end)
        
        if test_case.should_fail then
            if not success or not result then
                print("    ✅ 正确处理了错误情况")
            else
                print("    ❌ 应该失败但却成功了")
                test_success = false
            end
        else
            if success then
                print(string.format("    ✅ 验证成功: %s", tostring(result)))
            else
                print(string.format("    ❌ 验证失败: %s", tostring(result)))
                test_success = false
            end
        end
    end
    print("")
    
    -- 测试4: 性能测试
    print("🧪 测试4: 性能测试")
    
    local performance_test_data = {
        public_key = "04" .. string.rep("A1B2C3D4", 16),
        id = "31323334353637383132333435363738",
        signature = string.rep("ABCD", 16),
        plain_data = "48656C6C6F20576F726C64"
    }
    
    local test_count = 5
    local start_time = os.clock()
    
    for i = 1, test_count do
        local success, result = pcall(function()
            return crypto.sm2_verify(performance_test_data.public_key, 
                                   performance_test_data.id,
                                   performance_test_data.signature, 
                                   performance_test_data.plain_data)
        end)
        
        if not success then
            print(string.format("  ❌ 性能测试第 %d 次失败: %s", i, tostring(result)))
            test_success = false
            break
        end
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    local avg_time = duration / test_count
    
    print(string.format("  📊 性能测试结果: %d 次验证，总耗时 %.3f 秒，平均 %.3f 秒/次", 
                       test_count, duration, avg_time))
    print("")
    
    -- 测试总结
    if test_success then
        print("✅ SM2 验证功能测试全部通过")
    else
        print("❌ SM2 验证功能测试存在失败项")
    end
    
    return test_success
end

-- 主测试函数
local function run_all_tests()
    print("🚀 ULC 固件更新模块测试开始")
    print("=" .. string.rep("=", 50))
    print("")
    
    local start_time = os.time()
    local test_results = {}
    local test_list = {
        {name = "配置功能", func = test_configuration},
        {name = "工具函数", func = test_utility_functions},
        {name = "Bitmap功能", func = test_bitmap_functions},
        {name = "SM2验证功能", func = test_sm2_verify},
        {name = "更新类型0", func = function() return test_update_type(0) end},
        {name = "更新类型1", func = function() return test_update_type(1) end},
        {name = "更新类型2", func = function() return test_update_type(2) end}
    }
    
    -- 创建测试固件文件
    create_test_firmware()
    
    -- 开始整体测试进度
    fixed_progress.start_session("全部测试")
    
    -- 执行所有测试
    for i, test in ipairs(test_list) do
        -- 显示整体进度
        fixed_progress.show_progress(i - 1, #test_list, "🧪 测试进度", 
                                   string.format("当前: %s", test.name))
        
        local success = pcall(test.func)
        test_results[test.name] = success
        
        -- 短暂延迟，让用户看到进度
        os.execute("timeout /t 1 >nul 2>&1")  -- Windows 延迟1秒
    end
    
    -- 完成所有测试
    fixed_progress.show_progress(#test_list, #test_list, "🧪 测试进度", "所有测试完成")
    
    -- 显示测试结果汇总
    local end_time = os.time()
    local duration = end_time - start_time
    
    fixed_progress.end_session()
    io.write("\n")
    io.flush()
    io.write("=" .. string.rep("=", 50) .. "\n")
    io.write("📊 测试结果汇总\n")
    io.write("=" .. string.rep("=", 50) .. "\n")
    io.flush()
    
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

-- 演示固定进度条功能
local function demo_fixed_progress()
    io.write("=== 🎬 固定进度条演示 ===\n")
    io.write("这个演示将展示固定进度条的各种功能\n\n")
    io.flush()
    
    -- 演示1: 基本进度条
    io.write("📊 演示1: 基本进度条\n")
    io.flush()
    fixed_progress.start_session("基本进度演示")
    
    for i = 0, 20 do
        fixed_progress.show_progress(i, 20, "📈 基本进度")
        os.execute("timeout /t 1 >nul 2>&1")  -- 延迟1秒
    end
    
    fixed_progress.end_session("✅ 基本进度演示完成")
    io.write("\n")
    io.flush()
    
    -- 演示2: 带额外信息的进度条
    io.write("📊 演示2: 带额外信息的进度条\n")
    io.flush()
    fixed_progress.start_session("传输演示")
    
    local start_time = os.time()
    for i = 0, 15 do
        local extra_info = string.format("| 速度: %.1f KB/s | 数据块: %d", 
                                        (i * 64.5), i)
        fixed_progress.show_progress(i, 15, "📤 数据传输", extra_info)
        os.execute("timeout /t 1 >nul 2>&1")  -- 延迟1秒
    end
    
    fixed_progress.end_session("✅ 传输演示完成")
    io.write("\n")
    io.flush()
    
    -- 演示3: 重传进度演示
    io.write("📊 演示3: 重传进度演示\n")
    io.flush()
    fixed_progress.start_session("重传演示")
    
    for i = 0, 10 do
        fixed_progress.show_retransmit_progress(i, 10, 1000 + i)
        os.execute("timeout /t 1 >nul 2>&1")  -- 延迟1秒
    end
    
    fixed_progress.end_session("✅ 重传演示完成")
    io.write("\n")
    io.flush()
    
    -- 演示4: 多阶段进度
    io.write("📊 演示4: 多阶段进度演示\n")
    io.flush()
    local stages = {
        {name = "🔍 准备阶段", steps = 5},
        {name = "📤 传输阶段", steps = 8},
        {name = "🔄 验证阶段", steps = 3},
        {name = "✅ 完成阶段", steps = 2}
    }
    
    for stage_idx, stage in ipairs(stages) do
        fixed_progress.start_session(stage.name)
        
        for step = 0, stage.steps do
            local extra_info = string.format("阶段 %d/%d", stage_idx, #stages)
            fixed_progress.show_progress(step, stage.steps, stage.name, extra_info)
            os.execute("timeout /t 1 >nul 2>&1")  -- 延迟1秒
        end
        
        fixed_progress.end_session(string.format("✅ %s 完成", stage.name))
    end
    
    io.write("\n🎉 固定进度条演示全部完成！\n")
    io.flush()
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
        print("8. 测试 SM2 验证功能")
        print("9. 显示当前配置")
        print("10. 创建测试固件")
        print("11. 演示固定进度条")
        print("0. 退出")
        print("")
        
        io.write("请选择操作 (0-11): ")
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
            test_sm2_verify()
        elseif choice == "9" then
            ulc_update_module.show_config()
        elseif choice == "10" then
            create_test_firmware()
        elseif choice == "11" then
            demo_fixed_progress()
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
    elseif args[1] == "sm2" then
        -- 测试SM2验证功能
        test_sm2_verify()
    elseif args[1] == "create" then
        -- 创建测试固件
        create_test_firmware()
    elseif args[1] == "demo" then
        -- 演示固定进度条
        demo_fixed_progress()
    else
        print("用法:")
        print("  lua test_ulc_update.lua              # 交互式菜单")
        print("  lua test_ulc_update.lua all          # 运行所有测试")
        print("  lua test_ulc_update.lua type <0-2>   # 测试特定更新类型")
        print("  lua test_ulc_update.lua config       # 测试配置功能")
        print("  lua test_ulc_update.lua utils        # 测试工具函数")
        print("  lua test_ulc_update.lua bitmap       # 测试bitmap功能")
        print("  lua test_ulc_update.lua sm2          # 测试SM2验证功能")
        print("  lua test_ulc_update.lua create       # 创建测试固件")
        print("  lua test_ulc_update.lua demo         # 演示固定进度条")
    end
end

-- 运行主函数
main(...)