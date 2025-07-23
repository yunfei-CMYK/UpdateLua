#!/usr/bin/env lua
-- ULC 固件更新 Bitmap 功能测试演示
-- 演示如何使用bitmap来检查固件包传输的完整性

-- 加载ULC固件更新模块 (测试版本)
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])")
package.path = this_dir .. "?.lua;" .. package.path
local ulc_firmware = require("ulc_firmware_update_test")

-- 测试配置
local TEST_CONFIG = {
    FIRMWARE_PATH = "e:\\Dev\\Lua\\firmware\\test3.bin",  -- 测试固件文件路径
    SIMULATE_PACKET_LOSS = true,  -- 是否模拟数据包丢失
}

-- 打印分隔线
local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    if title then
        print("  " .. title)
        print(string.rep("=", 60))
    end
end

-- 演示bitmap功能
local function demo_bitmap_functionality()
    print_separator("ULC 固件更新 Bitmap 功能演示")
    
    print("本演示将展示以下bitmap功能:")
    print("1. 数据块信息管理")
    print("2. 传输完整性检查")
    print("3. 丢失数据包的自动重传")
    print("4. Bitmap验证机制")
    
    print_separator("开始固件更新测试")
    
    -- 检查测试固件文件是否存在
    local file = io.open(TEST_CONFIG.FIRMWARE_PATH, "rb")
    if not file then
        print("错误: 测试固件文件不存在: " .. TEST_CONFIG.FIRMWARE_PATH)
        print("请确保固件文件存在，或修改 TEST_CONFIG.FIRMWARE_PATH")
        return false
    end
    file:close()
    
    -- 执行固件更新（包含bitmap功能）
    local success = ulc_firmware.update_firmware(TEST_CONFIG.FIRMWARE_PATH)
    
    print_separator("测试结果")
    
    if success then
        print("✓ 固件更新成功完成")
        print("✓ Bitmap 完整性验证通过")
        print("✓ 所有数据包传输完整")
    else
        print("✗ 固件更新失败")
        print("✗ 可能存在数据包丢失或传输错误")
        
        -- 获取最终的bitmap状态来分析丢失的数据包
        print_separator("📊 传输失败分析")
        
        -- 尝试获取最终的bitmap状态
        local bitmap_module = ulc_firmware.bitmap
        local final_bitmap = bitmap_module.get_device_bitmap()
        
        if final_bitmap then
            -- 获取总块数（从全局变量）
            local total_blocks = _G.total_blocks or 0
            
            if total_blocks > 0 then
                local missing_packets = {}
                local received_packets = {}
                
                -- 分析bitmap，找出丢失和接收的数据包
                for block_index = 0, total_blocks - 1 do
                    if ulc_firmware.utils.is_bit_set(final_bitmap, block_index) then
                        table.insert(received_packets, block_index)
                    else
                        table.insert(missing_packets, block_index)
                    end
                end
                
                print(string.format("📈 传输统计: 总计 %d 个数据包", total_blocks))
                print(string.format("  ✅ 成功接收: %d 个 (%.2f%%)", 
                                   #received_packets, (#received_packets * 100.0) / total_blocks))
                print(string.format("  ❌ 丢失数据包: %d 个 (%.2f%%)", 
                                   #missing_packets, (#missing_packets * 100.0) / total_blocks))
                
                if #missing_packets > 0 then
                    print("\n" .. string.rep("=", 50))
                    print("🔍 丢失数据包详细分析")
                    print(string.rep("=", 50))
                    print(string.format("丢失数据包总数: %d 个", #missing_packets))
                    print(string.format("丢失率: %.2f%%", (#missing_packets * 100.0) / total_blocks))
                    
                    -- 按行显示丢失的数据包，每行10个
                    print("\n丢失数据包序号列表:")
                    local line_count = 0
                    local packets_per_line = 10
                    
                    for i, packet_id in ipairs(missing_packets) do
                        if (i - 1) % packets_per_line == 0 then
                            line_count = line_count + 1
                            io.write(string.format("  第%2d行: ", line_count))
                        end
                        
                        io.write(string.format("%3d", packet_id))
                        
                        if i % packets_per_line == 0 or i == #missing_packets then
                            print("")  -- 换行
                        else
                            io.write(", ")
                        end
                    end
                    
                    -- 显示丢失数据包的范围分析
                    print("\n📊 丢失数据包范围分析:")
                    local ranges = {}
                    local start_range = missing_packets[1]
                    local end_range = missing_packets[1]
                    
                    for i = 2, #missing_packets do
                        if missing_packets[i] == end_range + 1 then
                            -- 连续的数据包
                            end_range = missing_packets[i]
                        else
                            -- 不连续，保存当前范围
                            if start_range == end_range then
                                table.insert(ranges, string.format("  单个包: %d", start_range))
                            else
                                table.insert(ranges, string.format("  连续包: %d-%d (共%d个)", 
                                                                 start_range, end_range, end_range - start_range + 1))
                            end
                            start_range = missing_packets[i]
                            end_range = missing_packets[i]
                        end
                    end
                    
                    -- 添加最后一个范围
                    if start_range == end_range then
                        table.insert(ranges, string.format("  单个包: %d", start_range))
                    else
                        table.insert(ranges, string.format("  连续包: %d-%d (共%d个)", 
                                                         start_range, end_range, end_range - start_range + 1))
                    end
                    
                    for _, range_info in ipairs(ranges) do
                        print(range_info)
                    end
                    
                    print(string.rep("=", 50))
                end
                
                if #received_packets > 0 and #received_packets <= 20 then
                    print("\n成功接收的数据包:")
                    local received_str = ""
                    for i, packet_id in ipairs(received_packets) do
                        if i > 1 then
                            received_str = received_str .. ", "
                        end
                        received_str = received_str .. tostring(packet_id)
                        
                        -- 每行最多显示15个包号
                        if i % 15 == 0 and i < #received_packets then
                            print("  " .. received_str)
                            received_str = ""
                        end
                    end
                    
                    if received_str ~= "" then
                        print("  " .. received_str)
                    end
                elseif #received_packets > 20 then
                    print(string.format("\n成功接收的数据包: %d 个 (数量较多，不详细列出)", #received_packets))
                end
            else
                print("无法获取总块数信息")
            end
        else
            print("无法获取最终bitmap状态")
        end
    end
    
    return success
end

-- 演示bitmap工具函数
local function demo_bitmap_utils()
    print_separator("Bitmap 工具函数演示")
    
    local utils = ulc_firmware.utils
    
    -- 创建一个测试bitmap
    local test_bitmap = {}
    local total_bits = 16
    
    print("创建测试bitmap，总位数: " .. total_bits)
    
    -- 设置一些位
    print("\n设置位操作:")
    for i = 0, total_bits - 1, 2 do
        utils.set_bit(test_bitmap, i)
        print(string.format("  设置位 %d", i))
    end
    
    -- 检查位状态
    print("\n检查位状态:")
    for i = 0, total_bits - 1 do
        local is_set = utils.is_bit_set(test_bitmap, i)
        print(string.format("  位 %d: %s", i, is_set and "已设置" or "未设置"))
    end
    
    -- 检查完整性
    local is_complete = utils.is_bitmap_complete(test_bitmap, total_bits)
    print(string.format("\nBitmap 完整性: %s", is_complete and "完整" or "不完整"))
    
    -- 设置所有位
    print("\n设置所有位...")
    for i = 0, total_bits - 1 do
        utils.set_bit(test_bitmap, i)
    end
    
    is_complete = utils.is_bitmap_complete(test_bitmap, total_bits)
    print(string.format("Bitmap 完整性: %s", is_complete and "完整" or "不完整"))
end

-- 演示数据块管理
local function demo_block_management()
    print_separator("数据块管理演示")
    
    local bitmap_module = ulc_firmware.bitmap
    
    -- 清空之前的数据
    bitmap_module.clear_block_info()
    
    -- 添加一些测试数据块
    print("添加测试数据块:")
    for i = 0, 4 do
        local file_offset = i * 256
        local spi_flash_addr = 0x5000 + file_offset
        local block_len = 256
        
        bitmap_module.add_block_info(i, file_offset, spi_flash_addr, block_len)
    end
    
    -- 获取数据块信息
    print("\n获取数据块信息:")
    for i = 0, 4 do
        local block_info = bitmap_module.get_block_info(i)
        if block_info then
            print(string.format("  块 %d: 偏移=%d, Flash地址=0x%X, 长度=%d", 
                               i, block_info.file_offset, block_info.spi_flash_addr, block_info.block_len))
        end
    end
    
    -- 清空数据块信息
    print("\n清空数据块信息...")
    bitmap_module.clear_block_info()
end

-- 主函数
local function main()
    print("ULC 固件更新 Bitmap 功能测试")
    print("作者: Lua 实现团队")
    print("日期: " .. os.date("%Y-%m-%d %H:%M:%S"))
    
    -- 演示bitmap工具函数
    demo_bitmap_utils()
    
    -- 演示数据块管理
    demo_block_management()
    
    -- 演示完整的bitmap功能
    local success = demo_bitmap_functionality()
    
    print_separator("测试总结")
    
    print("Bitmap 功能特性:")
    print("• 数据包传输状态跟踪")
    print("• 自动检测丢失的数据包")
    print("• 智能重传机制")
    print("• 传输完整性验证")
    print("• 支持多轮重传尝试")
    
    print("\n测试完成，状态: " .. (success and "成功" or "失败"))
    
    return success
end

-- 运行测试
if arg and arg[0] and arg[0]:match("test_bitmap_demo%.lua$") then
    main()
end

-- 导出测试函数
return {
    main = main,
    demo_bitmap_functionality = demo_bitmap_functionality,
    demo_bitmap_utils = demo_bitmap_utils,
    demo_block_management = demo_block_management
}