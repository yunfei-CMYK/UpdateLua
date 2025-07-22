#!/usr/bin/env lua
-- ULC 固件更新脚本 (Lua 实现)
-- 基于 JavaScript 版本: FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js
-- 作者: Lua 实现团队
-- 日期: 2024
require("ldconfig")("socket")
-- 加载所需模块
local socket = require("socket")
local lfs = require("lfs")

-- 配置常量
local CONFIG = {
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
    SM2_GY = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0"
}

-- 全局变量
local firmware_data = ""
local firmware_length = 0
local uuid1 = ""
local uuid2 = ""
local sm2_public_key = ""

-- 实用函数
local utils = {}

-- 将整数转换为指定长度的十六进制字符串
function utils.int_to_hex(value, length)
    local hex = string.format("%X", value)
    if length then
        hex = string.rep("0", math.max(0, length - #hex)) .. hex
    end
    return hex
end

-- 将十六进制字符串转换为整数
function utils.hex_to_int(hex_str)
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

-- 提取子字符串（类似 JavaScript 的 1 开始索引）
function utils.str_mid(str, start, length)
    if not length or length == -1 then
        return str:sub(start)
    end
    return str:sub(start, start + length - 1)
end

-- 获取字符串长度（对于十六进制字符串，除以 2）
function utils.str_len(str)
    return #str
end

-- 将字符串转换为十六进制表示
function utils.str_to_hex(str)
    return (str:gsub(".", function(c) return string.format("%02X", string.byte(c)) end))
end

-- 将十六进制字符串转换为二进制字符串
function utils.hex_to_str(hex)
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

-- CRC16 计算（兼容 JavaScript crc16c 函数）
function utils.crc16c(data, seed)
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

-- 文件操作
local file_ops = {}

-- 读取二进制文件并返回十六进制字符串
function file_ops.read_firmware(file_path)
    print("读取固件文件: " .. file_path)
    
    local file, err = io.open(file_path, "rb")
    if not file then
        error("打开固件文件失败: " .. (err or "未知错误"))
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
        error("读取固件文件内容失败")
    end
    
    -- 将二进制内容转换为十六进制字符串
    local hex_content = utils.str_to_hex(content)
    print(string.format("固件已加载: %.2f KB", #content / 1024))
    
    return hex_content, #content
end

-- 从十六进制字符串写入二进制文件
function file_ops.write_firmware(file_path, hex_data)
    print("写入固件文件: " .. file_path)
    
    local file, err = io.open(file_path, "wb")
    if not file then
        error("创建固件文件失败: " .. (err or "未知错误"))
    end
    
    local binary_data = utils.hex_to_str(hex_data)
    file:write(binary_data)
    file:close()
    
    print(string.format("固件已写入: %.2f KB", #binary_data / 1024))
end

-- 通信函数
local comm = {}

-- 模拟 ULC APDU 通信
function comm.ulc_send_apdu(apdu)
    print("发送 APDU: " .. apdu)
    
    -- Simulate different responses based on APDU command
    if apdu == "00A4000002DF20" then
        -- 选择应用
        return "9000"
    elseif apdu:sub(1, 8) == "E0B4011C" then
        -- 获取 SM2 公钥
        local mock_pubkey = CONFIG.PUB_KEY_X .. CONFIG.PUB_KEY_Y
        print("接收: " .. mock_pubkey)
        return mock_pubkey
    elseif apdu:sub(1, 8) == "80DB001C" then
        -- 获取 UUID 和签名
        local mock_uuid1 = "1122334455667788"
        local mock_uuid2 = "AABBCCDDEEFF0011"
        local mock_signature = string.rep("A", 64)  -- 64字节模拟签名
        local response = "01" .. mock_uuid1 .. "02" .. mock_uuid2 .. mock_signature
        print("接收: " .. response)
        return response
    elseif apdu:sub(1, 8) == "80DA0000" then
        -- 发送切换信息
        print("接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "00200010" then
        -- 发送加密的 SK
        print("接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "00D00000" then
        -- 发送固件数据
        print("接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "80C40000" then
        -- 固件更新完成检查
        print("接收: 9000")
        return "9000"
    elseif apdu:sub(1, 8) == "F0F60200" then
        -- 获取 COS 版本
        local version = "01020304"  -- 模拟版本
        print("接收: " .. version)
        return version
    else
        -- 默认响应
        print("接收: 9000")
        return "9000"
    end
end

-- 进度显示
local progress = {}

function progress.show_progress(current, total, description)
    local percentage = math.floor((current * 100) / total)
    local bar_width = 50
    local filled = math.floor((current * bar_width) / total)
    local empty = bar_width - filled
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local progress_text = string.format("\r%s %s %3d%% (%d/%d 字节)", 
                                      description or "进度", bar, percentage, current, total)
    
    io.write(progress_text)
    io.flush()
    
    if current >= total then
        print("")  -- 完成时换行
    end
end

-- 加密函数（模拟实现）
local crypto = {}

-- 模拟 SM2 签名验证
function crypto.sm2_verify(public_key, id, signature, plain_data)
    print("SM2 验证:")
    print("  公钥: " .. public_key)
    print("  ID: " .. (id or CONFIG.ENTL_ID))
    print("  签名: " .. signature)
    print("  原始数据: " .. plain_data)
    print("  验证结果: 通过 (模拟)")
    return true
end

-- 模拟 SM2 加密
function crypto.sm2_encrypt(public_key, plain_data)
    print("SM2 加密:")
    print("  公钥: " .. public_key)
    print("  原始数据: " .. plain_data)
    
    -- 返回模拟加密数据（应该比输入更长）
    local mock_encrypted = string.rep("E", #plain_data * 2)
    print("  加密结果: " .. mock_encrypted)
    return mock_encrypted
end

-- 模拟 SM4 加密
function crypto.sm4_encrypt(key, iv, data, mode)
    print("SM4 加密:")
    print("  密钥: " .. key)
    print("  初始向量: " .. (iv or "N/A"))
    print("  模式: " .. (mode or "ECB"))
    print("  数据长度: " .. #data)
    
    -- 对于模拟，只需返回经过一些转换的数据
    local encrypted = ""
    for i = 1, #data do
        local char = data:sub(i, i)
        local byte_val = string.byte(char)
        encrypted = encrypted .. string.char((byte_val + 1) % 256)
    end
    
    local hex_encrypted = utils.str_to_hex(encrypted)
    print("  加密后长度: " .. #hex_encrypted)
    return hex_encrypted
end

-- 模拟 SM4 MAC 计算
function crypto.sm4_mac(key, data)
    print("SM4 MAC:")
    print("  密钥: " .. key)
    print("  数据长度: " .. #data)
    
    -- 返回模拟的 16 字节 MAC
    local mock_mac = string.rep("F", 32)  -- 32 个十六进制字符 = 16 字节
    print("  MAC: " .. mock_mac)
    return mock_mac
end

-- 主要 ULC 固件更新函数
local ulc_update = {}

-- 初始化 ULC 连接并获取设备信息
function ulc_update.initialize()
    print("=== ULC 固件更新初始化 ===")
    
    -- 选择应用
    comm.ulc_send_apdu("00A4000002DF20")
    
    -- 获取 SM2 公钥
    local pubkey_response = comm.ulc_send_apdu("E0B4011C022000")
    sm2_public_key = pubkey_response
    print("SM2 公钥: " .. sm2_public_key)
    
    -- 获取 UUID 并验证签名
    local uuid_response = comm.ulc_send_apdu("80DB001C081122334455667788")
    local signature = uuid_response:sub(-64)  -- 最后 64 个字符
    local data_part = uuid_response:sub(1, -65)  -- 除签名外的所有内容
    
    -- 提取 UUID
    uuid1 = utils.str_mid(data_part, 3, 16)  -- 跳过前 2 个字符，取 16 个
    uuid2 = utils.str_mid(data_part, 21, 16) -- 跳到第 21 个位置，取 16 个
    
    print("UUID1: " .. uuid1)
    print("UUID2: " .. uuid2)
    
    -- 验证签名
    crypto.sm2_verify(sm2_public_key, "", signature, "1122334455667788" .. data_part)
    
    print("初始化成功完成！")
end

-- 准备固件数据
function ulc_update.prepare_firmware(firmware_path)
    print("=== 准备固件 ===")
    
    -- 读取固件文件
    firmware_data, firmware_length = file_ops.read_firmware(firmware_path)
    
    -- 如果需要，移除加载器（对于 ULC 直接 324 或扩展 324）
    if CONFIG.UPDATE_TYPE_FLAG == 0 or CONFIG.UPDATE_TYPE_FLAG == 2 then
        firmware_data = utils.str_mid(firmware_data, CONFIG.LOADER_SIZE * 2 + 1)  -- *2 用于十六进制，+1 用于 1 开始的索引
        firmware_length = firmware_length - CONFIG.LOADER_SIZE
        print("加载器已移除，新固件长度: " .. firmware_length)
    elseif CONFIG.UPDATE_TYPE_FLAG == 1 then
        -- 对 BLE 固件填充到 1K 边界
        local remainder = firmware_length % 0x400
        if remainder ~= 0 then
            local pad_size = 0x400 - remainder
            firmware_data = utils.pad_string(firmware_data, "FF", #firmware_data + pad_size * 2)
            firmware_length = firmware_length + pad_size
            print("固件已填充到 1K 边界，新长度: " .. firmware_length)
        end
    end
    
    -- 对齐到 16 字节边界
    local aligned_length = (firmware_length + 0x0F) & ~0x0F
    if aligned_length > firmware_length then
        firmware_data = utils.pad_string(firmware_data, "00", aligned_length * 2)
        firmware_length = aligned_length
        print("固件已对齐到 16 字节边界，最终长度: " .. firmware_length)
    end
    
    print("固件准备完成！")
end

-- 发送切换信息并设置加密
function ulc_update.setup_encryption()
    print("=== 设置加密 ===")
    
    -- 生成会话密钥（模拟）
    local session_key = string.rep("11", 16)  -- 16 字节密钥作为十六进制字符串
    print("会话密钥: " .. session_key)
    
    -- 加密固件并计算 MAC
    local encrypted_firmware = crypto.sm4_encrypt(session_key, "00000000000000000000000000000000", 
                                                 utils.hex_to_str(firmware_data), "ECB")
    local mac1 = crypto.sm4_mac(session_key, utils.hex_to_str(firmware_data))
    local mac2 = crypto.sm4_mac(session_key, utils.hex_to_str(encrypted_firmware))
    
    -- 根据更新类型确定设备 UUID
    local device_uuid = ""
    if CONFIG.UPDATE_TYPE_FLAG == 0 then
        device_uuid = uuid1
    else
        device_uuid = uuid2
    end
    
    -- 创建切换信息
    local new_uuid = string.rep("A2", 16)
    local start_sn = string.rep("00", 16)
    local end_sn = string.rep("FF", 16)
    
    local switch_info = "000081" .. device_uuid .. start_sn .. end_sn .. 
                       "40080100000000000000000000000000000000" .. new_uuid .. 
                       "00005000" .. utils.int_to_hex(firmware_length, 4) .. mac1 .. mac2
    
    print("切换信息: " .. switch_info)
    
    -- 签名切换信息（模拟）
    local signature = string.rep("S", 64)  -- 模拟 64 字节签名
    
    -- 发送切换信息
    local switch_cmd = "80DA000000" .. utils.int_to_hex(#switch_info + #signature, 4) .. 
                      switch_info .. signature
    comm.ulc_send_apdu(switch_cmd)
    
    -- 获取用于加密的公钥
    local pubkey_for_encrypt = comm.ulc_send_apdu("E0B4011C022000")
    
    -- 加密会话密钥
    local encrypted_sk = crypto.sm2_encrypt(pubkey_for_encrypt, session_key)
    
    -- 发送加密的会话密钥
    local sk_cmd = "0020001C00" .. utils.int_to_hex(#encrypted_sk, 4) .. encrypted_sk
    comm.ulc_send_apdu(sk_cmd)
    
    print("加密设置完成！")
    return encrypted_firmware
end

-- 传输固件数据
function ulc_update.transfer_firmware(encrypted_firmware)
    print("=== 传输固件 ===")
    
    local offset = 0
    local packet_size = CONFIG.PACKET_SIZE
    local total_packets = math.ceil(#encrypted_firmware / (packet_size * 2))  -- *2 用于十六进制
    local current_packet = 0
    
    print("需要发送的总包数: " .. total_packets)
    
    while offset < #encrypted_firmware do
        local remaining = #encrypted_firmware - offset
        local current_packet_size = math.min(packet_size * 2, remaining)  -- *2 用于十六进制
        
        local packet_data = encrypted_firmware:sub(offset + 1, offset + current_packet_size)
        local crc = utils.crc16c(packet_data, 0)
        
        local cmd = "00D0000000" .. 
                   utils.int_to_hex(current_packet_size / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
                   utils.int_to_hex(offset / 2, 4) ..  -- /2 因为十六进制转字节
                   packet_data .. 
                   utils.int_to_hex(crc, 2)
        
        comm.ulc_send_apdu(cmd)
        
        offset = offset + current_packet_size
        current_packet = current_packet + 1
        
        -- 显示进度
        progress.show_progress(current_packet, total_packets, "传输中")
        
        -- 小延迟以模拟真实传输
        socket.sleep(0.01)
    end
    
    print("固件传输完成！")
end

-- 验证固件更新完成
function ulc_update.verify_completion()
    print("=== 验证更新完成 ===")
    
    -- 发送完成检查命令
    comm.ulc_send_apdu("80C4000000")
    
    print("等待设备重启...")
    socket.sleep(2)  -- 等待 2 秒
    
    -- 重新连接并验证
    comm.ulc_send_apdu("00A4000002DF20")
    
    -- 获取 COS 版本
    local cos_version = comm.ulc_send_apdu("F0F6020000")
    print("新 COS 版本: " .. utils.str_to_hex(cos_version))
    
    if CONFIG.UPDATE_TYPE_FLAG == 1 then
        local nordic_version = comm.ulc_send_apdu("F0F6030000")
        print("Nordic 版本: " .. utils.str_to_hex(nordic_version))
    end
    
    print("更新验证完成！")
end

-- 主更新函数
function ulc_update.update_firmware(firmware_path)
    local start_time = os.time()
    
    print("=== ULC 固件更新已开始 ===")
    print("固件路径: " .. firmware_path)
    print("更新类型: " .. CONFIG.UPDATE_TYPE_FLAG)
    print("通信类型: " .. CONFIG.COMM_TYPE)
    print("开始时间: " .. os.date("%Y-%m-%d %H:%M:%S", start_time))
    print("")
    
    -- 步骤 1: 初始化连接
    ulc_update.initialize()
    print("")
    
    -- 步骤 2: 准备固件
    ulc_update.prepare_firmware(firmware_path)
    print("")
    
    -- 步骤 3: 设置加密
    local encrypted_firmware = ulc_update.setup_encryption()
    print("")
    
    -- 步骤 4: 传输固件
    ulc_update.transfer_firmware(encrypted_firmware)
    print("")
    
    -- 步骤 5: 验证完成
    ulc_update.verify_completion()
    print("")
    
    local end_time = os.time()
    local duration = end_time - start_time
    
    print("=== ULC 固件更新已完成 ===")
    print("总时间: " .. duration .. " 秒")
    print("状态: 成功")
end

-- 导出模块
return {
    config = CONFIG,
    utils = utils,
    file_ops = file_ops,
    comm = comm,
    crypto = crypto,
    progress = progress,
    ulc_update = ulc_update,
    update_firmware = ulc_update.update_firmware
}