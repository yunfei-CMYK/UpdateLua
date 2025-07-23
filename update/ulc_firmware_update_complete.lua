#!/usr/bin/env lua
-- ULC 固件更新脚本 (完整版本)
-- 基于 JavaScript 版本: FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js
-- 作者: Lua 实现团队
-- 日期: 2024
-- 功能: 支持SM2/SM4加密、CRC校验、Bitmap管理和ULC通信

-- 加载所需模块
require("ldconfig")("socket")
require("ldconfig")("lfs")
local socket = require("socket")
local lfs = require("lfs")

-- 配置常量
local CONFIG = {
    -- 更新类型标志
    UPDATE_TYPE_FLAG = 0,  -- 0: ULC 直接 324, 1: BLE 芯片, 2: 扩展 324
    COMM_TYPE = 1,         -- 0: USB 通信, 1: ULC 通信
    DEVICE_ID = 2,         -- 使用 ULC 通信时的目标设备 ID
    PACKET_SIZE = 256,     -- 固件传输的数据包大小
    LOADER_SIZE = 0x2000,  -- 加载器大小 (8KB)
    
    -- 用于固件更新验证的 SM2 公钥
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3",
    
    -- SM2 曲线参数
    ENTL_ID = "31323334353637383132333435363738",
    SM2_A = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC",
    SM2_B = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93",
    SM2_GX = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7",
    SM2_GY = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0",
    
    -- 测试模式配置
    TEST_MODE = true,      -- 是否启用测试模式
    SIMULATE_ERRORS = false, -- 是否模拟传输错误
    ERROR_RATE = 0.05,     -- 错误率 (5%)
    MAX_RETRIES = 5,       -- 最大重试次数
    
    -- 固件路径配置（相对于update目录）
    FIRMWARE_PATHS = {
        [0] = "test_firmware/DBCos324.bin",                    -- ULC 直接 324
        [1] = "test_firmware/TDR_Ble_Slave_V1.0.25.bin",     -- BLE 芯片
        [2] = "test_firmware/DBCos324_LoopExtend.bin"         -- 扩展 324
    }
}

-- 全局变量
local firmware_data = ""
local firmware_length = 0
local uuid1 = ""
local uuid2 = ""
local sm2_public_key = ""

-- Bitmap 相关全局变量
local upgrade_block_info = {}  -- 存储每个数据块的信息
local total_blocks = 0         -- 总数据块数量

-- 实用函数模块
local utils = {}

-- 将整数转换为指定长度的十六进制字符串
function utils.int_to_hex(value, length)
    if not value then return "00" end
    local hex = string.format("%X", value)
    if length then
        hex = string.rep("0", math.max(0, length - #hex)) .. hex
    end
    return hex
end

-- 将十六进制字符串转换为整数
function utils.hex_to_int(hex_str)
    if not hex_str or hex_str == "" then return 0 end
    return tonumber(hex_str, 16) or 0
end

-- 用指定字符将字符串填充到指定长度
function utils.pad_string(str, char, length)
    local current_len = #str
    if current_len >= length then
        return str:sub(1, length)
    end
    local pad_len = length - current_len
    return str .. string.rep(char, pad_len)
end

-- 提取子字符串（类似 JavaScript 的 StrMid）
function utils.str_mid(str, start, length)
    if not str or not start then return "" end
    if not length or length == -1 then
        return str:sub(start)
    end
    return str:sub(start, start + length - 1)
end

-- 获取字符串长度
function utils.str_len(str)
    return str and #str or 0
end

-- 将字符串转换为十六进制表示
function utils.str_to_hex(str)
    if not str then return "" end
    return (str:gsub(".", function(c) return string.format("%02X", string.byte(c)) end))
end

-- 将十六进制字符串转换为二进制字符串
function utils.hex_to_str(hex)
    if not hex then return "" end
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

-- CRC16 计算（兼容 JavaScript crc16c 函数）
function utils.crc16c(data, seed)
    if not data then return 0 end
    local crc = seed or 0
    local data_len = #data
    
    for j = 1, data_len do
        local byte_val = utils.hex_to_int(data:sub(j, j))
        
        for i = 1, 8 do
            local bit = crc & 1
            if (byte_val & 1) ~= 0 then
                bit = bit ~ 1
            end
            
            if bit ~= 0 then
                crc = crc ~ 0x4002
            end
            
            crc = crc >> 1
            
            if bit ~= 0 then
                crc = crc | 0x8000
            end
            
            byte_val = byte_val >> 1
        end
    end
    
    return crc
end

-- 生成随机数据
function utils.generate_random_hex(length)
    local chars = "0123456789ABCDEF"
    local result = ""
    math.randomseed(os.time())
    for i = 1, length do
        local rand_index = math.random(1, #chars)
        result = result .. chars:sub(rand_index, rand_index)
    end
    return result
end

-- Bitmap 相关函数
-- 将两个字节数组进行按位或操作
function utils.bitwise_or(array1, array2, length)
    local result = {}
    for i = 1, length do
        result[i] = (array1[i] or 0) | (array2[i] or 0)
    end
    return result
end

-- 检查bitmap中指定位是否为1
function utils.is_bit_set(bitmap, bit_index)
    local byte_index = math.floor(bit_index / 8) + 1  -- Lua数组从1开始
    local bit_offset = bit_index % 8
    local byte_val = bitmap[byte_index] or 0
    return ((byte_val >> (7 - bit_offset)) & 1) == 1
end

-- 设置bitmap中指定位为1
function utils.set_bit(bitmap, bit_index)
    local byte_index = math.floor(bit_index / 8) + 1  -- Lua数组从1开始
    local bit_offset = bit_index % 8
    if not bitmap[byte_index] then
        bitmap[byte_index] = 0
    end
    bitmap[byte_index] = bitmap[byte_index] | (1 << (7 - bit_offset))
end

-- 检查bitmap是否全部为1（所有数据包都已接收）
function utils.is_bitmap_complete(bitmap, total_bits)
    for i = 0, total_bits - 1 do
        if not utils.is_bit_set(bitmap, i) then
            return false
        end
    end
    return true
end

-- 模拟传输错误
function utils.simulate_transmission_error()
    if not CONFIG.SIMULATE_ERRORS then
        return false
    end
    return math.random() < CONFIG.ERROR_RATE
end

-- 文件操作模块
local file_ops = {}

-- 读取二进制文件并返回十六进制字符串
function file_ops.read_firmware(file_path)
    print("📁 读取固件文件: " .. file_path)
    
    local file, err = io.open(file_path, "rb")
    if not file then
        error("❌ 打开固件文件失败: " .. (err or "未知错误"))
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
        error("❌ 读取固件文件内容失败")
    end
    
    -- 将二进制内容转换为十六进制字符串
    local hex_content = utils.str_to_hex(content)
    print(string.format("✅ 固件已加载: %.2f KB", #content / 1024))
    
    return hex_content, #content
end

-- 从十六进制字符串写入二进制文件
function file_ops.write_firmware(file_path, hex_data)
    print("💾 写入固件文件: " .. file_path)
    
    local file, err = io.open(file_path, "wb")
    if not file then
        error("❌ 创建固件文件失败: " .. (err or "未知错误"))
    end
    
    local binary_data = utils.hex_to_str(hex_data)
    file:write(binary_data)
    file:close()
    
    print(string.format("✅ 固件已写入: %.2f KB", #binary_data / 1024))
end

-- 检查文件是否存在
function file_ops.file_exists(file_path)
    local file = io.open(file_path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- 通信函数模块
local comm = {}

-- 模拟 ULC APDU 通信
function comm.ulc_send_apdu(apdu)
    print("📤 发送 APDU: " .. apdu)
    
    -- 模拟传输延迟
    if CONFIG.TEST_MODE then
        socket.sleep(0.01)
    end
    
    -- 模拟传输错误
    if utils.simulate_transmission_error() then
        print("⚠️  模拟传输错误")
        error("传输错误")
    end
    
    -- 根据不同的APDU命令返回模拟响应
    if apdu == "00A4000002DF20" then
        -- 选择应用
        print("📥 接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "E0B4011C" then
        -- 获取 SM2 公钥
        local mock_pubkey = CONFIG.PUB_KEY_X .. CONFIG.PUB_KEY_Y
        print("📥 接收: " .. mock_pubkey)
        return mock_pubkey
    elseif apdu:sub(1, 8) == "80DB001C" then
        -- 获取 UUID 和签名
        local mock_uuid1 = utils.generate_random_hex(16)
        local mock_uuid2 = utils.generate_random_hex(16)
        local mock_signature = string.rep("A", 64)  -- 64字节模拟签名
        local response = "01" .. mock_uuid1 .. "02" .. mock_uuid2 .. mock_signature
        print("📥 接收: " .. response)
        return response
    elseif apdu:sub(1, 8) == "80DA0000" then
        -- 发送切换信息
        print("📥 接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "00200010" then
        -- 发送加密的 SK
        print("📥 接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "00D00000" then
        -- 发送固件数据
        print("📥 接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "80C40000" then
        -- 固件更新完成检查
        print("📥 接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "F0F60200" then
        -- 获取 COS 版本
        local version = "01020304"  -- 模拟版本
        print("📥 接收: " .. version)
        return version
    elseif apdu == "FCDF000000" then
        -- 获取 bitmap
        local bitmap_bytes = math.ceil(total_blocks / 8)
        local mock_bitmap = {}
        
        -- 模拟部分数据包丢失
        for i = 1, bitmap_bytes do
            if CONFIG.SIMULATE_ERRORS and math.random() < CONFIG.ERROR_RATE then
                mock_bitmap[i] = math.random(0, 254)  -- 随机丢失一些包
            else
                mock_bitmap[i] = 0xFF  -- 全部接收
            end
        end
        
        local bitmap_hex = ""
        for i = 1, bitmap_bytes do
            bitmap_hex = bitmap_hex .. string.format("%02X", mock_bitmap[i])
        end
        
        print("📥 接收 bitmap: " .. bitmap_hex)
        return bitmap_hex
    else
        -- 默认响应
        print("📥 接收: 9000")
        return "9000"
    end
end

-- 带重试的APDU发送
function comm.ulc_send_apdu_with_retry(apdu, max_retries)
    max_retries = max_retries or CONFIG.MAX_RETRIES
    local last_error = nil
    
    for attempt = 1, max_retries do
        local success, result = pcall(comm.ulc_send_apdu, apdu)
        if success then
            return result
        else
            last_error = result
            if attempt < max_retries then
                print(string.format("⚠️  重试 %d/%d: %s", attempt, max_retries, result))
                socket.sleep(0.1 * attempt)  -- 递增延迟
            end
        end
    end
    
    error("❌ APDU发送失败，已重试" .. max_retries .. "次: " .. (last_error or "未知错误"))
end

-- 进度显示模块
local progress = {}

function progress.show_progress(current, total, description)
    -- 确保参数是有效的数字
    if not current or not total or total <= 0 then
        return
    end
    
    local percentage = math.floor((current * 100) / total)
    local bar_width = 50
    local filled = math.floor((current * bar_width) / total)
    local empty = bar_width - filled
    
    -- 确保filled和empty都是非负整数
    filled = math.max(0, math.min(bar_width, filled))
    empty = math.max(0, bar_width - filled)
    
    local bar = "[" .. string.rep("█", filled) .. string.rep("░", empty) .. "]"
    local progress_text = string.format("\r%s %s %3d%% (%d/%d)", 
                                      description or "📊 进度", bar, percentage, current, total)
    
    io.write(progress_text)
    io.flush()
    
    if current >= total then
        print("")  -- 完成时换行
    end
end

-- 显示详细的传输统计
function progress.show_transfer_stats(transferred, total, start_time, description)
    local elapsed = os.time() - start_time
    local speed = elapsed > 0 and (transferred / elapsed) or 0
    local eta = speed > 0 and ((total - transferred) / speed) or 0
    
    local stats = string.format(" | 速度: %.1f KB/s | 剩余: %ds", 
                               speed / 1024, math.floor(eta))
    
    progress.show_progress(transferred, total, (description or "传输") .. stats)
end

-- 加密函数模块（模拟实现）
local crypto = {}

-- 模拟 SM2 签名验证
function crypto.sm2_verify(public_key, id, signature, plain_data)
    print("🔐 SM2 验证:")
    print("  公钥: " .. (public_key or ""))
    print("  ID: " .. (id or CONFIG.ENTL_ID))
    print("  签名: " .. (signature or ""))
    print("  原始数据: " .. (plain_data or ""))
    
    -- 模拟验证过程
    if CONFIG.TEST_MODE then
        socket.sleep(0.1)  -- 模拟验证时间
    end
    
    print("  ✅ 验证结果: 通过 (模拟)")
    return true
end

-- 模拟 SM2 加密
function crypto.sm2_encrypt(public_key, plain_data)
    print("🔐 SM2 加密:")
    print("  公钥: " .. (public_key or ""))
    print("  原始数据长度: " .. #(plain_data or ""))
    
    -- 返回模拟加密数据（应该比输入更长）
    local mock_encrypted = string.rep("E", #(plain_data or "") * 2)
    print("  加密结果长度: " .. #mock_encrypted)
    return mock_encrypted
end

-- 模拟 SM4 加密
function crypto.sm4_encrypt(key, iv, data, mode)
    print("🔐 SM4 加密:")
    print("  密钥: " .. (key or ""))
    print("  初始向量: " .. (iv or "N/A"))
    print("  模式: " .. (mode or "ECB"))
    print("  数据长度: " .. #(data or ""))
    
    -- 对于模拟，只需返回经过一些转换的数据
    local encrypted = ""
    local input_data = data or ""
    for i = 1, #input_data do
        local char = input_data:sub(i, i)
        local byte_val = string.byte(char)
        encrypted = encrypted .. string.char((byte_val + 1) % 256)
    end
    
    local hex_encrypted = utils.str_to_hex(encrypted)
    print("  加密后长度: " .. #hex_encrypted)
    return hex_encrypted
end

-- 模拟 SM4 MAC 计算
function crypto.sm4_mac(key, data)
    print("🔐 SM4 MAC:")
    print("  密钥: " .. (key or ""))
    print("  数据长度: " .. #(data or ""))
    
    -- 返回模拟的 16 字节 MAC
    local mock_mac = string.rep("F", 32)  -- 32 个十六进制字符 = 16 字节
    print("  MAC: " .. mock_mac)
    return mock_mac
end

-- 模拟 SM2 签名
function crypto.sm2_sign(private_key, data, id)
    print("🔐 SM2 签名:")
    print("  私钥: " .. (private_key or ""))
    print("  数据: " .. (data or ""))
    print("  ID: " .. (id or CONFIG.ENTL_ID))
    
    -- 返回模拟的 64 字节签名
    local mock_signature = string.rep("S", 64)
    print("  签名: " .. mock_signature)
    return mock_signature
end

-- Bitmap 管理模块
local bitmap = {}

-- 添加数据块信息
function bitmap.add_block_info(index, file_offset, spi_flash_addr, block_len)
    upgrade_block_info[index] = {
        file_offset = file_offset,
        spi_flash_addr = spi_flash_addr,
        block_len = block_len
    }
    if CONFIG.TEST_MODE then
        print(string.format("📦 添加数据块 %d: 文件偏移=%d, Flash地址=0x%X, 长度=%d", 
                           index, file_offset, spi_flash_addr, block_len))
    end
end

-- 获取数据块信息
function bitmap.get_block_info(index)
    return upgrade_block_info[index]
end

-- 清空数据块信息
function bitmap.clear_block_info()
    upgrade_block_info = {}
    total_blocks = 0
    print("🗑️  已清空数据块信息")
end

-- 获取设备的bitmap
function bitmap.get_device_bitmap()
    print("=== 📊 获取设备 Bitmap ===")
    
    if total_blocks == 0 then
        print("❌ 错误: 没有数据块信息")
        return nil
    end
    
    -- 发送获取bitmap的APDU命令
    local bitmap_response = comm.ulc_send_apdu_with_retry("FCDF000000")
    
    if not bitmap_response or bitmap_response == "9000" then
        print("❌ 获取bitmap失败")
        return nil
    end
    
    -- 将十六进制字符串转换为字节数组
    local bitmap_array = {}
    for i = 1, #bitmap_response, 2 do
        local byte_hex = bitmap_response:sub(i, i + 1)
        local byte_val = tonumber(byte_hex, 16)
        table.insert(bitmap_array, byte_val)
    end
    
    print(string.format("✅ 获取到 bitmap，长度: %d 字节", #bitmap_array))
    return bitmap_array
end

-- 根据bitmap重传丢失的数据包
function bitmap.retry_missing_packets(encrypted_firmware)
    print("=== 🔄 根据 Bitmap 重传丢失数据包 ===")
    
    local max_retries = CONFIG.MAX_RETRIES
    local success = false
    local final_missing_packets = {}
    
    for retry_count = 1, max_retries do
        print(string.format("🔄 重传尝试 %d/%d", retry_count, max_retries))
        
        -- 获取当前bitmap
        local device_bitmap = bitmap.get_device_bitmap()
        if not device_bitmap then
            print("⚠️  获取bitmap失败，跳过此次重传")
            socket.sleep(1)
            goto continue
        end
        
        -- 检查是否所有数据包都已接收
        if utils.is_bitmap_complete(device_bitmap, total_blocks) then
            print("🎉 所有数据包都已成功接收！")
            success = true
            break
        end
        
        -- 分析丢失的数据包
        local retransmitted = 0
        local current_missing = {}
        local missing_ranges = {}
        
        for block_index = 0, total_blocks - 1 do
            if not utils.is_bit_set(device_bitmap, block_index) then
                table.insert(current_missing, block_index)
            end
        end
        
        -- 分析丢失数据包的范围
        if #current_missing > 0 then
            print(string.format("📊 发现 %d 个丢失数据包", #current_missing))
            
            -- 显示丢失数据包的详细信息
            local missing_str = ""
            for i, packet_id in ipairs(current_missing) do
                if i > 1 then
                    missing_str = missing_str .. ", "
                end
                missing_str = missing_str .. tostring(packet_id)
                
                -- 每行最多显示10个包号
                if i % 10 == 0 and i < #current_missing then
                    print("📋 丢失数据包: " .. missing_str)
                    missing_str = ""
                end
            end
            
            if missing_str ~= "" then
                print("📋 丢失数据包: " .. missing_str)
            end
            
            -- 计算丢失率
            local loss_rate = (#current_missing * 100.0) / total_blocks
            print(string.format("📈 丢失率: %.2f%% (%d/%d)", loss_rate, #current_missing, total_blocks))
        end
        
        -- 重传丢失的数据包
        for _, block_index in ipairs(current_missing) do
            print(string.format("📤 重传数据块 %d", block_index))
            
            local block_info = bitmap.get_block_info(block_index)
            if block_info then
                -- 重传这个数据包
                bitmap.retransmit_single_packet(encrypted_firmware, block_index, block_info)
                retransmitted = retransmitted + 1
                
                -- 显示重传进度
                if retransmitted % 10 == 0 or retransmitted == #current_missing then
                    progress.show_progress(retransmitted, #current_missing, "🔄 重传进度")
                end
            end
        end
        
        -- 记录最后一轮的丢失数据包
        final_missing_packets = current_missing
        
        print(string.format("✅ 本轮重传了 %d 个数据包", retransmitted))
        
        if retransmitted == 0 then
            print("ℹ️  没有需要重传的数据包")
            success = true
            break
        end
        
        -- 等待一段时间再检查
        socket.sleep(1)
        
        ::continue::
    end
    
    if success then
        print("🎉 Bitmap 验证通过，所有数据包传输完整！")
    else
        print("⚠️  警告: 经过多次重传，仍有数据包丢失")
        
        -- 打印最终丢失的数据包详情
        if #final_missing_packets > 0 then
            print(string.format("=== ❌ 最终丢失的数据包列表 (共 %d 个) ===", #final_missing_packets))
            
            -- 分析丢失数据包的范围
            local ranges = {}
            local start_range = final_missing_packets[1]
            local end_range = final_missing_packets[1]
            
            for i = 2, #final_missing_packets do
                if final_missing_packets[i] == end_range + 1 then
                    end_range = final_missing_packets[i]
                else
                    if start_range == end_range then
                        table.insert(ranges, tostring(start_range))
                    else
                        table.insert(ranges, start_range .. "-" .. end_range)
                    end
                    start_range = final_missing_packets[i]
                    end_range = final_missing_packets[i]
                end
            end
            
            -- 添加最后一个范围
            if start_range == end_range then
                table.insert(ranges, tostring(start_range))
            else
                table.insert(ranges, start_range .. "-" .. end_range)
            end
            
            print("📋 丢失数据包范围: " .. table.concat(ranges, ", "))
            print(string.format("📊 总计: %d/%d 数据包丢失 (%.2f%%)", 
                               #final_missing_packets, total_blocks, 
                               (#final_missing_packets * 100.0) / total_blocks))
        end
    end
    
    return success
end

-- 重传单个数据包
function bitmap.retransmit_single_packet(encrypted_firmware, block_index, block_info)
    local packet_size = CONFIG.PACKET_SIZE
    local start_pos = block_index * packet_size * 2 + 1  -- *2 因为十六进制，+1 因为Lua索引从1开始
    local end_pos = math.min(start_pos + packet_size * 2 - 1, #encrypted_firmware)
    
    local packet_data = encrypted_firmware:sub(start_pos, end_pos)
    local crc = utils.crc16c(packet_data, 0)
    
    local cmd = "00D0000000" .. 
               utils.int_to_hex(#packet_data / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
               utils.int_to_hex(block_info.file_offset, 4) ..
               packet_data .. 
               utils.int_to_hex(crc, 2)
    
    comm.ulc_send_apdu_with_retry(cmd)
    
    -- 小延迟
    socket.sleep(0.01)
end

-- 主要 ULC 固件更新函数模块
local ulc_update = {}

-- 初始化 ULC 连接并获取设备信息
function ulc_update.initialize()
    print("=== 🚀 ULC 固件更新初始化 ===")
    
    -- 选择应用
    comm.ulc_send_apdu_with_retry("00A4000002DF20")
    
    -- 获取 SM2 公钥
    local pubkey_response = comm.ulc_send_apdu_with_retry("E0B4011C022000")
    sm2_public_key = pubkey_response
    print("🔑 SM2 公钥: " .. sm2_public_key)
    
    -- 获取 UUID 并验证签名
    local uuid_response = comm.ulc_send_apdu_with_retry("80DB001C081122334455667788")
    local signature = uuid_response:sub(-64)  -- 最后 64 个字符
    local data_part = uuid_response:sub(1, -65)  -- 除签名外的所有内容
    
    -- 提取 UUID
    uuid1 = utils.str_mid(data_part, 3, 16)  -- 跳过前 2 个字符，取 16 个
    uuid2 = utils.str_mid(data_part, 21, 16) -- 跳到第 21 个位置，取 16 个
    
    print("🆔 UUID1: " .. uuid1)
    print("🆔 UUID2: " .. uuid2)
    
    -- 验证签名
    crypto.sm2_verify(sm2_public_key, "", signature, "1122334455667788" .. data_part)
    
    print("✅ 初始化成功完成！")
end

-- 准备固件数据
function ulc_update.prepare_firmware(firmware_path)
    print("=== 📦 准备固件 ===")
    
    -- 检查固件文件是否存在
    if not file_ops.file_exists(firmware_path) then
        error("❌ 固件文件不存在: " .. firmware_path)
    end
    
    -- 读取固件文件
    firmware_data, firmware_length = file_ops.read_firmware(firmware_path)
    
    print(string.format("📊 原始固件长度: %d 字节 (%.2f KB)", firmware_length, firmware_length / 1024))
    
    -- 如果需要，移除加载器（对于 ULC 直接 324 或扩展 324）
    if CONFIG.UPDATE_TYPE_FLAG == 0 or CONFIG.UPDATE_TYPE_FLAG == 2 then
        firmware_data = utils.str_mid(firmware_data, CONFIG.LOADER_SIZE * 2 + 1)  -- *2 用于十六进制，+1 用于 1 开始的索引
        firmware_length = firmware_length - CONFIG.LOADER_SIZE
        print(string.format("✂️  加载器已移除，新固件长度: %d 字节 (%.2f KB)", firmware_length, firmware_length / 1024))
    elseif CONFIG.UPDATE_TYPE_FLAG == 1 then
        -- 对 BLE 固件填充到 1K 边界
        local remainder = firmware_length % 0x400
        if remainder ~= 0 then
            local pad_size = 0x400 - remainder
            firmware_data = utils.pad_string(firmware_data, "FF", #firmware_data + pad_size * 2)
            firmware_length = firmware_length + pad_size
            print(string.format("📏 固件已填充到 1K 边界，新长度: %d 字节 (%.2f KB)", firmware_length, firmware_length / 1024))
        end
    end
    
    -- 对齐到 16 字节边界
    local aligned_length = (firmware_length + 0x0F) & ~0x0F
    if aligned_length > firmware_length then
        firmware_data = utils.pad_string(firmware_data, "00", aligned_length * 2)
        firmware_length = aligned_length
        print(string.format("📐 固件已对齐到 16 字节边界，最终长度: %d 字节 (%.2f KB)", firmware_length, firmware_length / 1024))
    end
    
    print("✅ 固件准备完成！")
end

-- 发送切换信息并设置加密
function ulc_update.setup_encryption()
    print("=== 🔐 设置加密 ===")
    
    -- 生成会话密钥
    local session_key = string.rep("11", 16)  -- 16 字节密钥作为十六进制字符串
    print("🔑 会话密钥: " .. session_key)
    
    -- 加密固件并计算 MAC
    print("🔄 正在加密固件...")
    local encrypted_firmware = crypto.sm4_encrypt(session_key, "00000000000000000000000000000000", 
                                                 utils.hex_to_str(firmware_data), "ECB")
    local mac1 = crypto.sm4_mac(session_key, utils.hex_to_str(firmware_data))
    local mac2 = crypto.sm4_mac(session_key, utils.hex_to_str(encrypted_firmware))
    
    print("✅ 固件加密完成")
    print("🔒 明文MAC: " .. mac1)
    print("🔒 密文MAC: " .. mac2)
    
    -- 根据更新类型确定设备 UUID
    local device_uuid = ""
    if CONFIG.UPDATE_TYPE_FLAG == 0 then
        device_uuid = uuid1
    else
        device_uuid = uuid2
    end
    
    print("🆔 使用设备UUID: " .. device_uuid)
    
    -- 创建切换信息
    local new_uuid = string.rep("A2", 16)
    local start_sn = string.rep("00", 16)
    local end_sn = string.rep("FF", 16)
    
    local switch_info = "000081" .. device_uuid .. start_sn .. end_sn .. 
                       "40080100000000000000000000000000000000" .. new_uuid .. 
                       "00005000" .. utils.int_to_hex(firmware_length, 4) .. mac1 .. mac2
    
    print("📋 切换信息: " .. switch_info)
    
    -- 签名切换信息
    local signature = crypto.sm2_sign(CONFIG.PUB_KEY_D, switch_info, CONFIG.ENTL_ID)
    
    -- 发送切换信息
    local switch_cmd = "80DA000000" .. utils.int_to_hex(#switch_info + #signature, 4) .. 
                      switch_info .. signature
    comm.ulc_send_apdu_with_retry(switch_cmd)
    
    -- 获取用于加密的公钥
    local pubkey_for_encrypt = comm.ulc_send_apdu_with_retry("E0B4011C022000")
    
    -- 加密会话密钥
    local encrypted_sk = crypto.sm2_encrypt(pubkey_for_encrypt, session_key)
    
    -- 发送加密的会话密钥
    local sk_cmd = "0020001C00" .. utils.int_to_hex(#encrypted_sk, 4) .. encrypted_sk
    comm.ulc_send_apdu_with_retry(sk_cmd)
    
    print("✅ 加密设置完成！")
    return encrypted_firmware
end

-- 传输固件数据
function ulc_update.transfer_firmware(encrypted_firmware)
    print("=== 📤 传输固件 ===")
    
    -- 验证输入参数
    if not encrypted_firmware or #encrypted_firmware == 0 then
        print("❌ 错误: 加密固件数据为空")
        return false
    end
    
    local offset = 0
    local packet_size = CONFIG.PACKET_SIZE
    local start_time = os.time()
    
    -- 确保packet_size是有效的正数
    if not packet_size or packet_size <= 0 then
        print("❌ 错误: 数据包大小无效")
        return false
    end
    
    -- 计算总块数
    local firmware_length = #encrypted_firmware
    local bytes_per_packet = packet_size * 2  -- *2 用于十六进制
    local calculated_total_blocks = math.ceil(firmware_length / bytes_per_packet)
    
    -- 验证total_blocks是有效的
    if not calculated_total_blocks or calculated_total_blocks <= 0 then
        print("❌ 错误: 计算的总块数无效")
        return false
    end
    
    local current_packet = 0
    local spi_flash_addr = 0x5000  -- 起始Flash地址
    
    print(string.format("📊 需要发送的总包数: %d", calculated_total_blocks))
    print(string.format("📦 数据包大小: %d 字节", packet_size))
    print(string.format("💾 固件总大小: %.2f KB", firmware_length / 2 / 1024))
    
    -- 清空之前的数据块信息
    bitmap.clear_block_info()
    
    -- 设置总块数到bitmap模块
    total_blocks = calculated_total_blocks
    
    print("🚀 开始传输固件数据...")
    
    while offset < #encrypted_firmware do
        local remaining = #encrypted_firmware - offset
        local current_packet_size = math.min(packet_size * 2, remaining)  -- *2 用于十六进制
        
        local packet_data = encrypted_firmware:sub(offset + 1, offset + current_packet_size)
        local crc = utils.crc16c(packet_data, 0)
        
        -- 记录数据块信息用于bitmap验证
        bitmap.add_block_info(current_packet, offset / 2, spi_flash_addr, current_packet_size / 2)
        
        local cmd = "00D0000000" .. 
                   utils.int_to_hex(current_packet_size / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
                   utils.int_to_hex(offset / 2, 4) ..  -- /2 因为十六进制转字节
                   packet_data .. 
                   utils.int_to_hex(crc, 2)
        
        comm.ulc_send_apdu_with_retry(cmd)
        
        offset = offset + current_packet_size
        current_packet = current_packet + 1
        spi_flash_addr = spi_flash_addr + (current_packet_size / 2)
        
        -- 显示详细进度
        if current_packet <= total_blocks then
            progress.show_transfer_stats(offset / 2, firmware_length / 2, start_time, "📤 传输")
        end
        
        -- 小延迟以模拟真实传输
        socket.sleep(0.01)
    end
    
    print("\n✅ 初始固件传输完成！")
    
    -- 使用bitmap验证传输完整性并重传丢失的数据包
    print("")
    local bitmap_success = bitmap.retry_missing_packets(encrypted_firmware)
    
    if bitmap_success then
        print("🎉 固件传输完成，所有数据包完整性验证通过！")
    else
        print("⚠️  警告: 固件传输可能不完整，请检查设备状态")
    end
    
    return bitmap_success
end

-- 验证固件更新完成
function ulc_update.verify_completion()
    print("=== ✅ 验证更新完成 ===")
    
    -- 发送完成检查命令
    comm.ulc_send_apdu_with_retry("80C4000000")
    
    print("⏳ 等待设备重启...")
    socket.sleep(2)  -- 等待 2 秒
    
    -- 重新连接并验证
    comm.ulc_send_apdu_with_retry("00A4000002DF20")
    
    -- 获取 COS 版本
    local cos_version = comm.ulc_send_apdu_with_retry("F0F6020000")
    print("📋 新 COS 版本: " .. utils.str_to_hex(cos_version))
    
    if CONFIG.UPDATE_TYPE_FLAG == 1 then
        local nordic_version = comm.ulc_send_apdu_with_retry("F0F6030000")
        print("📋 Nordic 版本: " .. utils.str_to_hex(nordic_version))
    end
    
    if CONFIG.UPDATE_TYPE_FLAG == 2 then
        -- 测试扩展324升级包是否正确
        local extend_version = comm.ulc_send_apdu_with_retry("FCD5261805FCD5100000")
        extend_version = extend_version:sub(1, -3)  -- 移除最后的状态码
        print("📋 扩展324 版本: " .. utils.str_to_hex(extend_version))
    end
    
    print("✅ 更新验证完成！")
end

-- 主更新函数
function ulc_update.update_firmware(firmware_path)
    local start_time = os.time()
    
    print("=== 🚀 ULC 固件更新已开始 ===")
    print("📁 固件路径: " .. firmware_path)
    print("🔧 更新类型: " .. CONFIG.UPDATE_TYPE_FLAG .. " (" .. 
          (CONFIG.UPDATE_TYPE_FLAG == 0 and "ULC直连324" or 
           CONFIG.UPDATE_TYPE_FLAG == 1 and "BLE芯片" or "扩展324") .. ")")
    print("📡 通信类型: " .. CONFIG.COMM_TYPE .. " (" .. 
          (CONFIG.COMM_TYPE == 0 and "USB" or "ULC") .. ")")
    print("🕒 开始时间: " .. os.date("%Y-%m-%d %H:%M:%S", start_time))
    print("🧪 测试模式: " .. (CONFIG.TEST_MODE and "启用" or "禁用"))
    print("⚠️  错误模拟: " .. (CONFIG.SIMULATE_ERRORS and "启用" or "禁用"))
    print("")
    
    local success = false
    
    -- 步骤 1: 初始化连接
    local step_success, step_error = pcall(ulc_update.initialize)
    if not step_success then
        print("❌ 初始化失败: " .. step_error)
        return false
    end
    print("")
    
    -- 步骤 2: 准备固件
    step_success, step_error = pcall(ulc_update.prepare_firmware, firmware_path)
    if not step_success then
        print("❌ 固件准备失败: " .. step_error)
        return false
    end
    print("")
    
    -- 步骤 3: 设置加密
    local encrypted_firmware
    step_success, encrypted_firmware = pcall(ulc_update.setup_encryption)
    if not step_success then
        print("❌ 加密设置失败: " .. encrypted_firmware)
        return false
    end
    print("")
    
    -- 步骤 4: 传输固件（包含bitmap完整性验证）
    local transfer_success
    step_success, transfer_success = pcall(ulc_update.transfer_firmware, encrypted_firmware)
    if not step_success then
        print("❌ 固件传输失败: " .. transfer_success)
        return false
    end
    print("")
    
    if transfer_success then
        -- 步骤 5: 验证完成
        step_success, step_error = pcall(ulc_update.verify_completion)
        if not step_success then
            print("❌ 完成验证失败: " .. step_error)
            return false
        end
        print("")
        success = true
    else
        print("❌ 固件传输失败，跳过完成验证")
    end
    
    -- 清理bitmap信息
    bitmap.clear_block_info()
    
    local end_time = os.time()
    local duration = end_time - start_time
    
    print("=== 🏁 ULC 固件更新已完成 ===")
    print("⏱️  总时间: " .. duration .. " 秒")
    print("📊 状态: " .. (success and "✅ 成功" or "❌ 失败"))
    print("🕒 结束时间: " .. os.date("%Y-%m-%d %H:%M:%S", end_time))
    
    return success
end

-- 配置管理函数
function ulc_update.set_config(key, value)
    if CONFIG[key] ~= nil then
        CONFIG[key] = value
        print(string.format("⚙️  配置已更新: %s = %s", key, tostring(value)))
    else
        print(string.format("⚠️  未知配置项: %s", key))
    end
end

function ulc_update.get_config(key)
    return CONFIG[key]
end

function ulc_update.show_config()
    print("=== ⚙️  当前配置 ===")
    for key, value in pairs(CONFIG) do
        if type(value) ~= "table" then
            print(string.format("  %s: %s", key, tostring(value)))
        end
    end
end

-- 导出模块
return {
    config = CONFIG,
    utils = utils,
    file_ops = file_ops,
    comm = comm,
    crypto = crypto,
    progress = progress,
    bitmap = bitmap,
    ulc_update = ulc_update,
    update_firmware = ulc_update.update_firmware,
    set_config = ulc_update.set_config,
    get_config = ulc_update.get_config,
    show_config = ulc_update.show_config
}