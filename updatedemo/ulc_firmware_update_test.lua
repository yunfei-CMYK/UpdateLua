#!/usr/bin/env lua
-- ULC 固件更新脚本 (测试版本 - 包含数据包丢失模拟)
-- 专门用于 test_bitmap_demo.lua
-- 作者: Lua 实现团队
-- 日期: 2024

-- 加载基础模块
require("ldconfig")("socket")
local socket = require("socket")
local lfs = require("lfs")

-- 导入基础的 ULC 固件更新模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path
local base_ulc = require("ulc_firmware_update")

-- 测试专用的全局变量
local test_retry_count = 0  -- 重传计数器
local test_missing_packets = {7, 15}  -- 模拟丢失的数据包

-- 创建测试版本的模块
local test_ulc = {}

-- 复制基础模块的所有功能
for k, v in pairs(base_ulc) do
    test_ulc[k] = v
end

-- 重写通信模块以支持测试场景
local test_comm = {}

-- 复制基础通信功能
for k, v in pairs(base_ulc.comm) do
    test_comm[k] = v
end

-- 重写 APDU 发送函数，添加数据包丢失模拟
function test_comm.ulc_send_apdu(apdu)
    print("发送 APDU: " .. apdu)
    
    -- 处理获取 bitmap 的特殊情况
    if apdu == "FCDF000000" then
        -- 获取 bitmap（模拟数据包丢失和重传成功）
        local total_blocks = _G.total_blocks or 16
        local bitmap_bytes = math.ceil(total_blocks / 8)
        local mock_bitmap = {}
        
        test_retry_count = test_retry_count + 1
        print(string.format("Bitmap 获取尝试: %d", test_retry_count))
        
        -- 前4次重传仍有数据包丢失，第5次重传成功
        if test_retry_count < 5 then
            print("模拟数据包丢失状态...")
            -- 模拟数据包丢失
            for i = 1, bitmap_bytes do
                if i == 1 then
                    -- 第一个字节: 位7丢失 (0xFE = 11111110)
                    mock_bitmap[i] = 0x7F  -- 01111111 - 位7丢失
                elseif i == 2 then
                    -- 第二个字节: 位15丢失 (位7在第二个字节中)
                    mock_bitmap[i] = 0x7F  -- 01111111 - 位15丢失
                else
                    mock_bitmap[i] = 0xFF  -- 其他全部接收
                end
            end
        else
            print("第5次重传 - 所有数据包接收成功！")
            -- 第5次重传时，所有数据包都成功接收
            for i = 1, bitmap_bytes do
                mock_bitmap[i] = 0xFF  -- 全部接收
            end
        end
        
        local bitmap_hex = ""
        for i = 1, bitmap_bytes do
            bitmap_hex = bitmap_hex .. string.format("%02X", mock_bitmap[i])
        end
        
        print("接收 bitmap: " .. bitmap_hex)
        return bitmap_hex
    else
        -- 其他 APDU 命令使用基础模块的处理
        return base_ulc.comm.ulc_send_apdu(apdu)
    end
end

-- 重写 bitmap 模块以支持测试场景
local test_bitmap = {}

-- 复制基础 bitmap 功能
for k, v in pairs(base_ulc.bitmap) do
    test_bitmap[k] = v
end

-- 重写获取设备 bitmap 函数
function test_bitmap.get_device_bitmap()
    print("=== 获取设备 Bitmap (测试版本) ===")
    
    if _G.total_blocks == 0 then
        print("错误: 没有数据块信息")
        return nil
    end
    
    -- 使用测试版本的通信模块
    local bitmap_response = test_comm.ulc_send_apdu("FCDF000000")
    
    if not bitmap_response or bitmap_response == "9000" then
        print("获取bitmap失败")
        return nil
    end
    
    -- 将十六进制字符串转换为字节数组
    local bitmap_array = {}
    for i = 1, #bitmap_response, 2 do
        local byte_hex = bitmap_response:sub(i, i + 1)
        local byte_val = tonumber(byte_hex, 16)
        table.insert(bitmap_array, byte_val)
    end
    
    print(string.format("获取到 bitmap，长度: %d 字节", #bitmap_array))
    return bitmap_array
end

-- 重写重传函数以支持测试场景
function test_bitmap.retry_missing_packets(encrypted_firmware)
    print("=== 根据 Bitmap 重传丢失数据包 (测试版本) ===")
    
    local max_retries = 5
    local success = false
    local final_missing_packets = {}
    
    -- 重置重传计数器
    test_retry_count = 0
    
    for retry_count = 1, max_retries do
        print(string.format("重传尝试 %d/%d", retry_count, max_retries))
        
        -- 获取当前bitmap
        local device_bitmap = test_bitmap.get_device_bitmap()
        if not device_bitmap then
            print("获取bitmap失败，跳过此次重传")
            socket.sleep(1)
            goto continue
        end
        
        -- 检查是否所有数据包都已接收
        if base_ulc.utils.is_bitmap_complete(device_bitmap, _G.total_blocks) then
            print("所有数据包都已成功接收！")
            success = true
            break
        end
        
        -- 重传丢失的数据包
        local retransmitted = 0
        local current_missing = {}
        for block_index = 0, _G.total_blocks - 1 do
            if not base_ulc.utils.is_bit_set(device_bitmap, block_index) then
                table.insert(current_missing, block_index)
                print(string.format("重传数据块 %d", block_index))
                
                local block_info = base_ulc.bitmap.get_block_info(block_index)
                if block_info then
                    -- 重传这个数据包
                    test_bitmap.retransmit_single_packet(encrypted_firmware, block_index, block_info)
                    retransmitted = retransmitted + 1
                end
            end
        end
        
        -- 记录最后一轮的丢失数据包
        final_missing_packets = current_missing
        
        print(string.format("本轮重传了 %d 个数据包", retransmitted))
        
        if retransmitted == 0 then
            print("没有需要重传的数据包")
            success = true
            break
        end
        
        -- 等待一段时间再检查
        socket.sleep(1)
        
        ::continue::
    end
    
    if success then
        print("Bitmap 验证通过，所有数据包传输完整！")
        print(string.format("总共进行了 %d 次重传尝试", test_retry_count))
    else
        print("警告: 经过多次重传，仍有数据包丢失")
        
        -- 打印最终丢失的数据包详情
        if #final_missing_packets > 0 then
            print(string.format("=== 最终丢失的数据包列表 (共 %d 个) ===", #final_missing_packets))
            local missing_str = ""
            for i, packet_id in ipairs(final_missing_packets) do
                if i > 1 then
                    missing_str = missing_str .. ", "
                end
                missing_str = missing_str .. tostring(packet_id)
                
                -- 每行最多显示10个包号，避免行太长
                if i % 10 == 0 and i < #final_missing_packets then
                    print("丢失数据包: " .. missing_str)
                    missing_str = ""
                end
            end
            
            if missing_str ~= "" then
                print("丢失数据包: " .. missing_str)
            end
            
            print(string.format("总计: %d/%d 数据包丢失 (%.2f%%)", 
                               #final_missing_packets, _G.total_blocks, 
                               (#final_missing_packets * 100.0) / _G.total_blocks))
        end
    end
    
    return success
end

-- 重传单个数据包（使用测试通信模块）
function test_bitmap.retransmit_single_packet(encrypted_firmware, block_index, block_info)
    local packet_size = base_ulc.config.PACKET_SIZE
    local start_pos = block_index * packet_size * 2 + 1  -- *2 因为十六进制，+1 因为Lua索引从1开始
    local end_pos = math.min(start_pos + packet_size * 2 - 1, #encrypted_firmware)
    
    local packet_data = encrypted_firmware:sub(start_pos, end_pos)
    local crc = base_ulc.utils.crc16c(packet_data, 0)
    
    local cmd = "00D0000000" .. 
               base_ulc.utils.int_to_hex(#packet_data / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
               base_ulc.utils.int_to_hex(block_info.file_offset, 4) ..
               packet_data .. 
               base_ulc.utils.int_to_hex(crc, 2)
    
    test_comm.ulc_send_apdu(cmd)
    
    -- 小延迟
    socket.sleep(0.01)
end

-- 重写传输固件函数以使用测试版本的 bitmap
function test_ulc.transfer_firmware(encrypted_firmware)
    print("=== 传输固件 (测试版本) ===")
    
    local packet_size = base_ulc.config.PACKET_SIZE
    local total_size = #encrypted_firmware / 2  -- 除以2因为十六进制字符串
    _G.total_blocks = math.ceil(total_size / packet_size)
    
    print(string.format("固件大小: %d 字节", total_size))
    print(string.format("数据包大小: %d 字节", packet_size))
    print(string.format("总数据包数: %d", _G.total_blocks))
    
    -- 清空并重新设置数据块信息
    test_bitmap.clear_block_info()
    
    -- 分包传输
    for i = 0, _G.total_blocks - 1 do
        local start_pos = i * packet_size * 2 + 1  -- *2 因为十六进制，+1 因为Lua索引从1开始
        local end_pos = math.min(start_pos + packet_size * 2 - 1, #encrypted_firmware)
        local packet_data = encrypted_firmware:sub(start_pos, end_pos)
        local actual_size = #packet_data / 2
        
        -- 添加数据块信息
        test_bitmap.add_block_info(i, i * packet_size, 0x5000 + i * packet_size, actual_size)
        
        -- 计算CRC
        local crc = base_ulc.utils.crc16c(packet_data, 0)
        
        -- 构造APDU命令
        local cmd = "00D0000000" .. 
                   base_ulc.utils.int_to_hex(actual_size + 6, 2) ..  -- +6 用于偏移量+crc
                   base_ulc.utils.int_to_hex(i * packet_size, 4) ..
                   packet_data .. 
                   base_ulc.utils.int_to_hex(crc, 2)
        
        test_comm.ulc_send_apdu(cmd)
        
        -- 显示进度
        base_ulc.progress.show_progress((i + 1) * packet_size, total_size, "传输固件")
        
        -- 小延迟以模拟真实传输
        socket.sleep(0.01)
    end
    
    print("\n固件传输完成")
    
    -- 保存计算得到的 total_blocks 到全局变量
    _G.total_blocks = _G.total_blocks
    
    -- 使用bitmap验证传输完整性并重传丢失的数据包
    print("开始bitmap完整性检查和重传...")
    local bitmap_success = test_bitmap.retry_missing_packets(encrypted_firmware)
    
    if not bitmap_success then
        print("错误: Bitmap验证失败，固件传输不完整")
        return false
    end
    
    return true
end

-- 更新主要的固件更新函数
function test_ulc.update_firmware(firmware_path)
    print("=== ULC 固件更新开始 (测试版本) ===")
    print("测试场景: 模拟数据包7和15丢失，第5次重传成功")
    
    local start_time = os.time()
    
    -- 重置测试状态
    test_retry_count = 0
    
    -- 初始化
    base_ulc.ulc_update.initialize()
    
    -- 准备固件
    base_ulc.ulc_update.prepare_firmware(firmware_path)
    
    -- 设置加密
    local encrypted_firmware = base_ulc.ulc_update.setup_encryption()
    
    -- 传输固件（使用测试版本）
    local transfer_success = test_ulc.transfer_firmware(encrypted_firmware)
    
    if not transfer_success then
        print("固件传输失败")
        return false
    end
    
    -- 完成更新
    test_comm.ulc_send_apdu("80C40000")
    
    local end_time = os.time()
    local duration = end_time - start_time
    
    print("=== ULC 固件更新完成 ===")
    print(string.format("总耗时: %d 秒", duration))
    print(string.format("重传尝试次数: %d", test_retry_count))
    print("状态: 成功")
    
    return true
end

-- 替换相关模块
test_ulc.comm = test_comm
test_ulc.bitmap = test_bitmap

return test_ulc