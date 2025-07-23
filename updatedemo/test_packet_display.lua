#!/usr/bin/env lua

-- 测试丢失数据包显示功能的演示脚本
-- 模拟不同的丢失数据包场景来展示显示效果

print("🧪 丢失数据包显示功能测试")
print(string.rep("=", 60))

-- 模拟函数：分析bitmap并显示丢失数据包
local function analyze_and_display_missing_packets(missing_list, total_blocks, scenario_name)
    print(string.format("\n📋 场景: %s", scenario_name))
    print(string.rep("-", 40))
    
    if #missing_list > 0 then
        print("\n" .. string.rep("=", 50))
        print("🔍 丢失数据包详细分析")
        print(string.rep("=", 50))
        print(string.format("丢失数据包总数: %d 个", #missing_list))
        print(string.format("丢失率: %.2f%%", (#missing_list * 100.0) / total_blocks))
        
        -- 按行显示丢失的数据包，每行10个
        print("\n丢失数据包序号列表:")
        local line_count = 0
        local packets_per_line = 10
        
        for i, packet_id in ipairs(missing_list) do
            if (i - 1) % packets_per_line == 0 then
                line_count = line_count + 1
                io.write(string.format("  第%2d行: ", line_count))
            end
            
            io.write(string.format("%3d", packet_id))
            
            if i % packets_per_line == 0 or i == #missing_list then
                print("")  -- 换行
            else
                io.write(", ")
            end
        end
        
        -- 显示丢失数据包的范围分析
        print("\n📊 丢失数据包范围分析:")
        local ranges = {}
        local start_range = missing_list[1]
        local end_range = missing_list[1]
        
        for i = 2, #missing_list do
            if missing_list[i] == end_range + 1 then
                -- 连续的数据包
                end_range = missing_list[i]
            else
                -- 不连续，保存当前范围
                if start_range == end_range then
                    table.insert(ranges, string.format("  单个包: %d", start_range))
                else
                    table.insert(ranges, string.format("  连续包: %d-%d (共%d个)", 
                                                     start_range, end_range, end_range - start_range + 1))
                end
                start_range = missing_list[i]
                end_range = missing_list[i]
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
    else
        print("✅ 所有数据包都已成功接收！")
    end
end

-- 测试场景1：模拟当前测试中的丢失情况（数据包7和15）
print("\n🎯 测试场景1：当前测试配置")
analyze_and_display_missing_packets({7, 15}, 32, "模拟数据包7和15丢失")

-- 测试场景2：连续丢失数据包
print("\n🎯 测试场景2：连续丢失")
analyze_and_display_missing_packets({5, 6, 7, 8, 9}, 32, "连续丢失数据包5-9")

-- 测试场景3：多个不连续范围
print("\n🎯 测试场景3：多个不连续范围")
analyze_and_display_missing_packets({2, 3, 7, 12, 13, 14, 20, 25, 26, 27, 28}, 32, "多个不连续丢失范围")

-- 测试场景4：大量丢失数据包
print("\n🎯 测试场景4：大量丢失")
local large_missing = {}
for i = 1, 32 do
    if i % 3 == 0 then  -- 每3个包丢失1个
        table.insert(large_missing, i)
    end
end
analyze_and_display_missing_packets(large_missing, 32, "每3个包丢失1个")

-- 测试场景5：无丢失数据包
print("\n🎯 测试场景5：完美传输")
analyze_and_display_missing_packets({}, 32, "所有数据包都成功传输")

print("\n" .. string.rep("=", 60))
print("✅ 丢失数据包显示功能测试完成")
print("💡 现在 test_bitmap_demo.lua 将以更清晰的方式显示丢失数据包信息")