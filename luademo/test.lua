require("ldconfig")('mqtt')
require("ldconfig")('dkjson') -- Ensure dkjson is loaded for JSON handling
require("ldconfig")('socket')
local mqtt = require("mqtt")
local dkjson = require("dkjson")
local http = require("socket.http")  -- Use the local http.lua module

--[[
MQTT固件下载客户端 - 文件组织结构说明
===========================================

本脚本会为每个下载的固件包创建专用文件夹，文件组织结构如下：

项目根目录/
├── test.lua                    (本脚本)
├── [固件名称]/                 (固件专用文件夹)
│   ├── [原始固件文件].bin      (下载的原始固件包)
│   ├── firmware_groups_info.txt (TLV解析结果和分组信息)
│   ├── firmware_mac.bin        (固件包MAC，如果存在)
│   ├── firmware_group_001.bin  (第1个分组文件)
│   ├── firmware_group_002.bin  (第2个分组文件)
│   └── ...                     (更多分组文件)

例如：
- 下载 test_firmware_large.bin 时，会创建 test_firmware_large/ 文件夹
- 所有相关文件都保存在该文件夹内，便于管理和部署

功能特性：
- 自动创建固件专用文件夹
- TLV格式解析和分组处理
- 完整的下载进度显示
- 详细的解析结果报告
===========================================
--]]

-- Script startup information
print("========================================")
print("MQTT Firmware Download Client Starting")
print("========================================")
print("Version: 1.0.0")
print("Description: MQTT client for firmware download and management")
print("Author: Lua MQTT Client")
print("Start time: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("Working directory: " .. (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")))
print("Broker: 127.0.0.1:1883")
print("Protocol: MQTT v5.0")
print("========================================")
print("Initializing MQTT client...")
print("")

-- Define multiple firmware-related topics
local firmware_topics = {
    "/{productId}/{deviceId}/firmware/upgrade",
    "/{productId}/{deviceId}/firmware/upgrade/reply",
    "/{productId}/{deviceId}/firmware/upgrade/progress",
    "/{productId}/{deviceId}/firmware/pull",
    "/{productId}/{deviceId}/firmware/pull/reply",
    "/{productId}/{deviceId}/firmware/report",
    "/{productId}/{deviceId}/firmware/read",
    "/{productId}/{deviceId}/firmware/read/reply"
}

-- Helper function: Safe JSON parsing using dkjson
local function safe_json_parse(json_str)
    if not json_str or json_str == "" then
        return false, "Empty JSON string"
    end
    
    local data, pos, err = dkjson.decode(json_str, 1, nil)
    
    if data then
        return true, data
    else
        return false, err or "Unknown parsing error"
    end
end

-- TLV解析相关辅助函数
-- 字节操作辅助函数：将字符串转换为字节数组
local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
end

-- 字节操作辅助函数：将字节数组转换为字符串
local function bytes_to_string(bytes, start_pos, length)
    start_pos = start_pos or 1
    length = length or (#bytes - start_pos + 1)
    
    local result = {}
    for i = start_pos, math.min(start_pos + length - 1, #bytes) do
        table.insert(result, string.char(bytes[i]))
    end
    return table.concat(result)
end

-- 字节操作辅助函数：从字节数组中读取多字节整数（大端序）
local function read_multibyte_int(bytes, start_pos, byte_count)
    local value = 0
    for i = 0, byte_count - 1 do
        if start_pos + i <= #bytes then
            value = value * 256 + bytes[start_pos + i]
        end
    end
    return value
end

-- 字节操作辅助函数：将字节数组转换为十六进制字符串
local function bytes_to_hex(bytes, start_pos, length)
    start_pos = start_pos or 1
    length = length or (#bytes - start_pos + 1)
    
    local hex_parts = {}
    for i = start_pos, math.min(start_pos + length - 1, #bytes) do
        table.insert(hex_parts, string.format("%02X", bytes[i]))
    end
    return table.concat(hex_parts, " ")
end

-- TLV解析器：解析单个TLV结构
local function parse_tlv(bytes, start_pos)
    if start_pos > #bytes then
        return nil, "Position out of bounds"
    end
    
    -- 读取TAG (1字节)
    local tag = bytes[start_pos]
    if not tag then
        return nil, "Cannot read TAG"
    end
    
    -- 读取LENGTH (2字节，大端序)
    if start_pos + 2 > #bytes then
        return nil, "Cannot read LENGTH"
    end
    local length = read_multibyte_int(bytes, start_pos + 1, 2)
    
    -- 读取VALUE
    local value_start = start_pos + 3
    local value_end = value_start + length - 1
    
    if value_end > #bytes then
        return nil, "VALUE length exceeds data bounds"
    end
    
    local value = {}
    for i = value_start, value_end do
        table.insert(value, bytes[i])
    end
    
    return {
        tag = tag,
        length = length,
        value = value,
        total_length = value_end - start_pos + 1,
        next_pos = value_end + 1
    }, nil
end

-- 固件包TLV解析器：解析TAG=0x71的固件包内容
local function parse_firmware_package(firmware_data)
    print("开始解析固件包TLV结构...")
    
    local bytes = string_to_bytes(firmware_data)
    print("固件包总大小: " .. #bytes .. " 字节")
    
    -- 查找TAG=0x71的固件包内容
    local pos = 1
    local package_info = {
        group_length = nil,    -- TAG=0x57: 分组长度
        mac = nil,             -- TAG=0x58: 固件包MAC
        encrypted_firmware = nil -- TAG=0x59: 密文固件包
    }
    
    -- 查找TAG=0x71的固件包
    local firmware_package_found = false
    
    while pos <= #bytes do
        local tlv, err = parse_tlv(bytes, pos)
        if not tlv then
            print("TLV解析错误 (位置 " .. pos .. "): " .. err)
            break
        end
        
        print(string.format("发现TLV: TAG=0x%02X, LENGTH=%d", tlv.tag, tlv.length))
        
        if tlv.tag == 0x71 then
            print("找到固件包 (TAG=0x71)，开始解析内部TLV结构...")
            firmware_package_found = true
            
            -- 解析固件包内部的TLV结构
            local inner_pos = 1
            local inner_bytes = tlv.value
            
            while inner_pos <= #inner_bytes do
                local inner_tlv, inner_err = parse_tlv(inner_bytes, inner_pos)
                if not inner_tlv then
                    print("内部TLV解析错误 (位置 " .. inner_pos .. "): " .. inner_err)
                    break
                end
                
                print(string.format("  内部TLV: TAG=0x%02X, LENGTH=%d", inner_tlv.tag, inner_tlv.length))
                
                if inner_tlv.tag == 0x57 then
                    -- 分组长度 (2字节)
                    if inner_tlv.length == 2 then
                        package_info.group_length = read_multibyte_int(inner_tlv.value, 1, 2)
                        print("    分组长度: " .. package_info.group_length .. " 字节")
                    else
                        print("    警告: 分组长度字段长度不正确 (期望2字节，实际" .. inner_tlv.length .. "字节)")
                    end
                    
                elseif inner_tlv.tag == 0x58 then
                    -- 固件包MAC (16字节)
                    if inner_tlv.length == 16 then
                        package_info.mac = inner_tlv.value
                        print("    固件包MAC: " .. bytes_to_hex(inner_tlv.value))
                    else
                        print("    警告: MAC字段长度不正确 (期望16字节，实际" .. inner_tlv.length .. "字节)")
                    end
                    
                elseif inner_tlv.tag == 0x59 then
                    -- 密文固件包
                    package_info.encrypted_firmware = inner_tlv.value
                    print("    密文固件包长度: " .. inner_tlv.length .. " 字节")
                    print("    固件数据预览: " .. bytes_to_hex(inner_tlv.value, 1, 16))
                    
                    -- 检查长度是否为分组长度的整数倍
                    if package_info.group_length then
                        local remainder = inner_tlv.length % package_info.group_length
                        if remainder == 0 then
                            local groups_count = inner_tlv.length / package_info.group_length
                            print("    ✓ 密文固件包长度是分组长度的整数倍 (" .. groups_count .. " 个分组)")
                        else
                            print("    ⚠ 警告: 密文固件包长度不是分组长度的整数倍 (余数: " .. remainder .. ")")
                        end
                    end
                    
                else
                    print(string.format("    未知内部TAG: 0x%02X", inner_tlv.tag))
                end
                
                inner_pos = inner_tlv.next_pos
            end
            
            break
        end
        
        pos = tlv.next_pos
    end
    
    if not firmware_package_found then
        return false, "未找到固件包 (TAG=0x71)"
    end
    
    return true, package_info
end

-- 固件分组处理函数：按分组长度分割密文固件包
local function split_firmware_into_groups(encrypted_firmware, group_length)
    if not encrypted_firmware or not group_length or group_length <= 0 then
        return nil, "无效的参数"
    end
    
    local firmware_length = #encrypted_firmware
    local groups_count = math.floor(firmware_length / group_length)
    
    if firmware_length % group_length ~= 0 then
        return nil, "固件长度不是分组长度的整数倍"
    end
    
    local groups = {}
    
    print("\n开始分组处理...")
    print("总长度: " .. firmware_length .. " 字节")
    print("分组长度: " .. group_length .. " 字节")
    print("分组数量: " .. groups_count)
    
    for i = 1, groups_count do
        local start_pos = (i - 1) * group_length + 1
        local end_pos = i * group_length
        
        local group_data = {}
        for j = start_pos, end_pos do
            table.insert(group_data, encrypted_firmware[j])
        end
        
        -- 生成预览（前16字节的十六进制）
        local preview_length = math.min(16, #group_data)
        local preview_bytes = {}
        for k = 1, preview_length do
            table.insert(preview_bytes, group_data[k])
        end
        local hex_preview = bytes_to_hex(preview_bytes)
        if #group_data > 16 then
            hex_preview = hex_preview .. "..."
        end
        
        table.insert(groups, {
            index = i,
            data = group_data,
            size = #group_data,
            hex_preview = hex_preview
        })
        
        print(string.format("分组 %d: %s", i, hex_preview))
    end
    
    return groups, nil
end

-- Helper function: Extract filename from URL
local function extract_filename_from_url(url)
    if not url then return nil end
    
    -- 移除URL中的查询参数部分
    local clean_url = url:match("^([^?]+)") or url
    
    -- 提取URL路径中的文件名
    local filename = clean_url:match("([^/]+)$")
    if filename and filename ~= "" then
        -- 移除文件名中可能包含的无效Windows字符
        filename = filename:gsub([[%?%*%:%.%"%<%>%|%/\]], "_")
        return filename
    end
    
    --  fallback: 基于时间戳生成文件名
    return "firmware_" .. os.time() .. ".bin"
end

-- Helper function: Get script directory
local function get_script_directory()
    local script_path = debug.getinfo(1, "S").source:sub(2)
    return script_path:match("(.*[/\\])")
end

-- Helper function: Create firmware directory based on filename
local function create_firmware_directory(filename)
    local script_dir = get_script_directory()
    
    -- 从文件名中提取基础名称（去除扩展名）
    local base_name = filename:match("^(.+)%..+$") or filename
    
    -- 清理文件名中的无效字符，确保可以作为文件夹名
    base_name = base_name:gsub('[<>:"/\\|?*]', '_')
    
    -- 创建固件专用文件夹路径
    local firmware_dir = script_dir .. base_name .. "\\"
    
    -- 尝试创建文件夹（Windows系统使用mkdir命令）
    local create_cmd = 'mkdir "' .. firmware_dir:sub(1, -2) .. '" 2>nul'
    os.execute(create_cmd)
    
    return firmware_dir, base_name
end

-- Helper function: Display progress bar
local function display_progress_bar(current, total, width)
    width = width or 50
    
    -- Ensure current and total are valid numbers and convert to integers
    current = math.floor(tonumber(current) or 0)
    total = math.floor(tonumber(total) or 1)
    
    -- Prevent division by zero
    if total <= 0 then total = 1 end
    if current > total then current = total end
    if current < 0 then current = 0 end
    
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local progress_text = string.format("%s %3d%% (%d/%d bytes)", bar, percentage, current, total)
    
    -- Use carriage return to overwrite the same line
    io.write("\r" .. progress_text)
    io.flush()
end

-- Helper function: Simulate download progress (since http.request doesn't support progress callback)
local function simulate_download_progress(total_size, duration_ms)
    duration_ms = duration_ms or 2000  -- Default 2 seconds
    local steps = 20
    
    -- Ensure total_size is a valid integer
    total_size = math.floor(tonumber(total_size) or 0)
    if total_size <= 0 then
        print("ERROR: Invalid file size for progress simulation")
        return
    end
    
    local step_size = total_size / steps
    local step_delay = duration_ms / steps / 1000  -- Convert to seconds
    
    print("Download progress:")
    
    for i = 0, steps do
        local current_size = math.floor(math.min(i * step_size, total_size))
        display_progress_bar(current_size, total_size)
        
        if i < steps then
            -- Simple delay simulation (not perfect but works for demonstration)
            local start_time = os.clock()
            while os.clock() - start_time < step_delay do
                -- Busy wait
            end
        end
    end
    
    print("")  -- New line after progress bar completion
end

-- Helper function: Download firmware from URL
-- Helper function: Download firmware from URL
local function download_firmware(url)
    if not url or url == "" then
        print("ERROR: Firmware URL is empty")
        return false, "URL is empty"
    end
    
    print("Starting firmware download...")
    print("Download URL: " .. url)
    
    -- Extract filename from URL
    local filename = extract_filename_from_url(url)
    
    -- Create firmware-specific directory
    local firmware_dir, base_name = create_firmware_directory(filename)
    local file_path = firmware_dir .. filename
    
    print("Firmware directory: " .. firmware_dir)
    print("Save path: " .. file_path)
    print("")
    
    -- Show initial progress
    print("Connecting to server...")
    
    -- Perform HTTP GET request using the correct http.request method
    local response_body, status_code, response_headers, status_line = http.request(url)
    
    if not response_body then
        print("HTTP request failed: " .. tostring(status_code))
        return false, "HTTP request failed: " .. tostring(status_code)
    end
    
    if status_code ~= 200 then
        print("HTTP response error: " .. tostring(status_code))
        return false, "HTTP response error: " .. tostring(status_code)
    end
    
    -- Check if response is HTML
    local is_html = false
    if response_headers and response_headers["content-type"] then
        is_html = string.find(response_headers["content-type"], "text/html", 1, true) ~= nil
    end
    
    -- If it's HTML, try to extract numbers from pre tag
    if is_html then
        print("Detected HTML response. Attempting to extract content...")
        local numbers = string.match(response_body, "<pre[^>]*>([%d%s]+)</pre>")
        if numbers then
            -- Remove whitespace
            numbers = string.gsub(numbers, "%s+", "")
            print("Successfully extracted numbers from HTML:")
            print("====================================")
            print(numbers)
            print("====================================")
            return true, {"extracted_numbers", numbers}
        else
            print("Failed to extract numbers from HTML response.")
            print("Raw HTML content:")
            print("====================================")
            print(response_body)
            print("====================================")
            return false, "Could not extract numbers from HTML"
        end
    end
    
    -- Get file size for progress simulation
    local file_size = #response_body
    
    print("Connected successfully!")
    print("File size: " .. string.format("%.2f KB", file_size / 1024))
    print("")
    
    -- Simulate download progress based on file size
    local progress_duration = math.max(1000, math.min(5000, file_size / 100))  -- 1-5 seconds based on size
    simulate_download_progress(file_size, progress_duration)
    
    -- Save original firmware to file
    print("Saving original file to disk...")
    local file, file_err = io.open(file_path, "wb")
    if not file then
        print("File creation failed: " .. tostring(file_err))
        
        -- 文件保存失败时，打印出获取到的内容
        print("Content received from URL:")
        print("====================================")
        print(response_body)
        print("====================================")
        
        return false, "File creation failed: " .. tostring(file_err)
    end
    
    file:write(response_body)
    file:close()
    
    print("Original firmware saved successfully!")
    print("")
    
    -- 开始TLV解析流程
    print(string.rep("=", 60))
    print("开始固件包TLV解析流程")
    print(string.rep("=", 60))
    
    local parse_success, package_info = parse_firmware_package(response_body)
    
    if not parse_success then
        print("TLV解析失败: " .. tostring(package_info))
        print("将按原始格式保存固件文件")
        
        print("\nDownload summary:")
        print("   - Filename: " .. filename)
        print("   - File size: " .. string.format("%.2f KB (%.0f bytes)", file_size / 1024, file_size))
        print("   - Firmware directory: " .. firmware_dir)
        print("   - Save location: " .. file_path)
        print("   - Status: Saved as original format")
        
        return true, {
            filename = filename,
            file_path = file_path,
            firmware_dir = firmware_dir,
            base_name = base_name,
            file_size = file_size,
            url = url,
            tlv_parsed = false
        }
    end
    
    print("\nTLV解析成功！")
    print("解析结果:")
    print("   - 分组长度: " .. (package_info.group_length or "未找到") .. " 字节")
    print("   - MAC长度: " .. (package_info.mac and #package_info.mac or "未找到") .. " 字节")
    print("   - 密文固件包长度: " .. (package_info.encrypted_firmware and #package_info.encrypted_firmware or "未找到") .. " 字节")
    
    -- 如果解析成功且有必要的信息，进行分组处理
    if package_info.group_length and package_info.encrypted_firmware then
        local groups, split_err = split_firmware_into_groups(package_info.encrypted_firmware, package_info.group_length)
        
        if groups then
            print("\n固件分组处理成功！")
            
            -- 保存分组信息到固件专用文件夹
            local groups_info_path = firmware_dir .. "firmware_groups_info.txt"
            local info_file = io.open(groups_info_path, "w")
            if info_file then
                info_file:write("固件包TLV解析结果\n")
                info_file:write("==================\n")
                info_file:write("原始文件: " .. filename .. "\n")
                info_file:write("文件大小: " .. file_size .. " 字节\n")
                info_file:write("分组长度: " .. package_info.group_length .. " 字节\n")
                info_file:write("分组数量: " .. #groups .. "\n")
                if package_info.mac then
                    info_file:write("固件包MAC: " .. bytes_to_hex(package_info.mac) .. "\n")
                end
                info_file:write("\n分组详情:\n")
                info_file:write("----------\n")
                
                for i, group in ipairs(groups) do
                    info_file:write(string.format("分组 %d: 大小=%d字节, 预览=%s\n", 
                                  group.index, group.size, group.hex_preview))
                end
                
                info_file:close()
                print("分组信息已保存到: " .. groups_info_path)
            end
            
            -- 可选：保存每个分组到单独的文件
            local save_groups = true  -- 可以根据需要设置为false
            if save_groups then
                print("\n保存分组文件到固件专用文件夹...")
                for i, group in ipairs(groups) do
                    local group_filename = string.format("firmware_group_%03d.bin", i)
                    local group_path = firmware_dir .. group_filename
                    local group_file = io.open(group_path, "wb")
                    if group_file then
                        local group_data_str = bytes_to_string(group.data)
                        group_file:write(group_data_str)
                        group_file:close()
                        print(string.format("   分组 %d 已保存: %s", i, group_filename))
                    end
                end
            end
            
            -- 保存MAC到固件专用文件夹
            if package_info.mac then
                local mac_path = firmware_dir .. "firmware_mac.bin"
                local mac_file = io.open(mac_path, "wb")
                if mac_file then
                    local mac_data_str = bytes_to_string(package_info.mac)
                    mac_file:write(mac_data_str)
                    mac_file:close()
                    print("固件包MAC已保存到: firmware_mac.bin")
                end
            end
            
        else
            print("固件分组处理失败: " .. tostring(split_err))
        end
    end
    
    print("\n" .. string.rep("=", 60))
    print("固件下载和解析完成")
    print(string.rep("=", 60))
    
    print("\nDownload summary:")
    print("   - 原始文件: " .. filename)
    print("   - 文件大小: " .. string.format("%.2f KB (%.0f bytes)", file_size / 1024, file_size))
    print("   - 固件文件夹: " .. firmware_dir)
    print("   - 原始文件路径: " .. file_path)
    print("   - TLV解析: " .. (parse_success and "成功" or "失败"))
    if parse_success then
        local groups_count = package_info.group_length and package_info.encrypted_firmware and 
                            math.floor(#package_info.encrypted_firmware / package_info.group_length) or 0
        print("   - 分组数量: " .. groups_count)
        print("   - 分组长度: " .. (package_info.group_length or "N/A") .. " 字节")
        if groups_count > 0 then
            print("   - 分组文件: firmware_group_001.bin ~ firmware_group_" .. string.format("%03d", groups_count) .. ".bin")
        end
        if package_info.mac then
            print("   - MAC文件: firmware_mac.bin")
        end
        print("   - 分组信息: firmware_groups_info.txt")
    end
    print("   - 状态: Ready for deployment")
    
    return true, {
        filename = filename,
        file_path = file_path,
        firmware_dir = firmware_dir,
        base_name = base_name,
        file_size = file_size,
        url = url,
        tlv_parsed = parse_success,
        package_info = package_info,
        groups_count = package_info.group_length and package_info.encrypted_firmware and 
                      math.floor(#package_info.encrypted_firmware / package_info.group_length) or 0
    }
end

-- Helper function: Handle different types of messages (simplified)
local function handle_firmware_message(topic, payload)
    print("\n" .. string.rep("=", 50))
    print("Message received - Topic: " .. tostring(topic))
    
    -- Try to parse JSON using dkjson
    local ok, data = safe_json_parse(payload)
    
    if ok and type(data) == "table" then
        print("JSON parsing successful")
        print("Message content:")
        print(string.rep("-", 20))
        
        -- Check for firmware URL in the message
        local firmware_url = nil
        
        -- Display the parsed JSON data and look for firmware URL
        for key, value in pairs(data) do
            if type(value) == "table" then
                print(key .. ": [table]")
            else
                print(key .. ": " .. tostring(value))
                
                -- Check for firmware URL fields
                if key == "firmware_url" or key == "url" or key == "download_url" then
                    firmware_url = tostring(value)
                end
            end
        end
        print(string.rep("-", 20))
        
        -- If firmware URL is found, attempt to download
        if firmware_url then
            print("Detected firmware download URL: " .. firmware_url)
            print(string.rep("*", 30))
            
            local success, result = download_firmware(firmware_url)
            
            if success then
                print("Firmware download process completed!")
                print("Download details:")
                print("   - Filename: " .. result.filename)
                print("   - File size: " .. string.format("%.2f KB", result.file_size / 1024))
                print("   - Save path: " .. result.file_path)
            else
                print("Firmware download failed: " .. tostring(result))
            end
            print(string.rep("*", 30))
        end
        
    else
        if not ok then
            print("JSON parsing failed: " .. tostring(data))
        else
            print("Message is not a valid JSON object")
        end
        print("Raw payload: " .. tostring(payload))
    end
    print(string.rep("=", 50) .. "\n")
end

-- create mqtt client
local client = mqtt.client{
    uri = "127.0.0.1",
    username = nil,
    clean = true,
    version = mqtt.v50,
}

client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            print("ERROR: Failed to connect to broker - " .. connack:reason_string())
            return
        end

        print("SUCCESS: Connected to MQTT broker")
        print("Connection details:")
        print("   - Broker: 127.0.0.1:1883")
        print("   - Protocol: MQTT v5.0")
        print("   - Clean session: true")
        print("")
        print("Subscribing to firmware topics...")

        -- Subscribe to all firmware-related topics
        local subscription_count = 0
        for i, topic in ipairs(firmware_topics) do
            assert(client:subscribe{ 
                topic = topic, 
                qos = 1, 
                callback = function(suback)
                    subscription_count = subscription_count + 1
                    print("   - Subscribed to: " .. topic)
                    
                    -- Print completion message when all subscriptions are done
                    if subscription_count == #firmware_topics then
                        print("")
                        print("All firmware topics subscribed successfully!")
                        print("Total subscriptions: " .. subscription_count)
                        print("Client is ready to receive firmware messages...")
                        print("========================================")
                        print("")
                    end
                end
            })
        end
    end,

    message = function(msg)
        assert(client:acknowledge(msg))
        
        -- Use simplified message handling function
        handle_firmware_message(msg.topic, msg.payload)
    end,

    error = function(err)
        print("ERROR: MQTT client error - " .. tostring(err))
        print("Attempting to reconnect...")
    end,
}

print("Starting MQTT client event loop...")
print("Press Ctrl+C to stop the client")
print("")

mqtt.run_ioloop(client)
