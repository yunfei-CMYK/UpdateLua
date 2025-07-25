-- TLV解析测试脚本
-- 用于测试固件包的TLV格式解析功能

-- 引入必要的模块
require('ldconfig')('socket')
local http = require("socket.http")

-- TLV解析辅助函数
local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
end

local function bytes_to_string(bytes)
    local chars = {}
    for i, byte in ipairs(bytes) do
        chars[i] = string.char(byte)
    end
    return table.concat(chars)
end

local function read_multibyte_int(bytes, start_pos, length)
    local value = 0
    for i = 0, length - 1 do
        if start_pos + i <= #bytes then
            value = value * 256 + bytes[start_pos + i]
        end
    end
    return value
end

local function bytes_to_hex(bytes)
    local hex_chars = {}
    for i, byte in ipairs(bytes) do
        hex_chars[i] = string.format("%02X", byte)
    end
    return table.concat(hex_chars, " ")
end

-- 解析单个TLV结构
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
        next_pos = value_end + 1
    }, nil
end

-- 解析固件包内容 (TAG=0x71)
local function parse_firmware_package(data)
    local bytes = string_to_bytes(data)
    local pos = 1
    local package_info = {}
    
    print("开始解析固件包数据...")
    print("数据总长度: " .. #bytes .. " 字节")
    
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
                    
                    -- 检查长度是否为分组长度的整数倍
                    if package_info.group_length then
                        local remainder = inner_tlv.length % package_info.group_length
                        if remainder == 0 then
                            print("    ✓ 密文固件包长度是分组长度的整数倍")
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
    
    -- 验证必要字段
    local missing_fields = {}
    if not package_info.group_length then
        table.insert(missing_fields, "分组长度 (TAG=0x57)")
    end
    if not package_info.mac then
        table.insert(missing_fields, "固件包MAC (TAG=0x58)")
    end
    if not package_info.encrypted_firmware then
        table.insert(missing_fields, "密文固件包 (TAG=0x59)")
    end
    
    if #missing_fields > 0 then
        return false, "缺少必要字段: " .. table.concat(missing_fields, ", ")
    end
    
    return true, package_info
end

-- 将密文固件包按分组长度分割
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
    
    for i = 1, groups_count do
        local start_pos = (i - 1) * group_length + 1
        local end_pos = i * group_length
        
        local group_data = {}
        for j = start_pos, end_pos do
            table.insert(group_data, encrypted_firmware[j])
        end
        
        -- 生成预览（前8字节的十六进制）
        local preview_length = math.min(8, #group_data)
        local preview_bytes = {}
        for k = 1, preview_length do
            table.insert(preview_bytes, group_data[k])
        end
        local hex_preview = bytes_to_hex(preview_bytes)
        if #group_data > 8 then
            hex_preview = hex_preview .. "..."
        end
        
        table.insert(groups, {
            index = i,
            data = group_data,
            size = #group_data,
            hex_preview = hex_preview
        })
    end
    
    return groups, nil
end

-- 创建测试用的TLV数据
local function create_test_tlv_data()
    print("创建测试用的TLV数据...")
    
    -- 创建内部TLV结构
    local inner_tlvs = {}
    
    -- TAG=0x57: 分组长度 (值: 1024)
    local group_length_value = {0x04, 0x00}  -- 1024 = 0x0400
    local group_length_tlv = string.char(0x57) .. string.char(0x00, 0x02) .. string.char(0x04, 0x00)
    table.insert(inner_tlvs, group_length_tlv)
    
    -- TAG=0x58: 固件包MAC (16字节)
    local mac_bytes = {}
    for i = 1, 16 do
        table.insert(mac_bytes, i - 1)  -- 0x00, 0x01, 0x02, ..., 0x0F
    end
    local mac_tlv = string.char(0x58) .. string.char(0x00, 0x10)  -- LENGTH=16
    for _, byte in ipairs(mac_bytes) do
        mac_tlv = mac_tlv .. string.char(byte)
    end
    table.insert(inner_tlvs, mac_tlv)
    
    -- TAG=0x59: 密文固件包 (2048字节，正好是1024的2倍)
    local firmware_size = 2048
    local firmware_bytes = {}
    for i = 1, firmware_size do
        table.insert(firmware_bytes, (i - 1) % 256)  -- 循环模式
    end
    local firmware_tlv = string.char(0x59) .. string.char(0x08, 0x00)  -- LENGTH=2048
    for _, byte in ipairs(firmware_bytes) do
        firmware_tlv = firmware_tlv .. string.char(byte)
    end
    table.insert(inner_tlvs, firmware_tlv)
    
    -- 组合内部TLV
    local inner_data = table.concat(inner_tlvs)
    local inner_length = #inner_data
    
    -- 创建外部TLV (TAG=0x71)
    local outer_tlv = string.char(0x71) .. 
                     string.char(math.floor(inner_length / 256), inner_length % 256) .. 
                     inner_data
    
    print("测试数据创建完成:")
    print("  - 外部TLV长度: " .. #outer_tlv .. " 字节")
    print("  - 内部数据长度: " .. inner_length .. " 字节")
    print("  - 分组长度: 1024 字节")
    print("  - 固件包大小: 2048 字节")
    print("  - 预期分组数: 2")
    
    return outer_tlv
end

-- 主测试函数
local function run_tlv_test()
    print(string.rep("=", 60))
    print("TLV解析功能测试")
    print(string.rep("=", 60))
    
    -- 创建测试数据
    local test_data = create_test_tlv_data()
    
    print("\n" .. string.rep("-", 40))
    print("开始解析测试...")
    print(string.rep("-", 40))
    
    -- 解析测试数据
    local success, result = parse_firmware_package(test_data)
    
    if success then
        print("\n✓ TLV解析成功！")
        print("解析结果:")
        print("  - 分组长度: " .. (result.group_length or "N/A") .. " 字节")
        print("  - MAC长度: " .. (result.mac and #result.mac or "N/A") .. " 字节")
        print("  - 密文固件包长度: " .. (result.encrypted_firmware and #result.encrypted_firmware or "N/A") .. " 字节")
        
        -- 测试分组功能
        if result.group_length and result.encrypted_firmware then
            print("\n" .. string.rep("-", 40))
            print("测试分组功能...")
            print(string.rep("-", 40))
            
            local groups, err = split_firmware_into_groups(result.encrypted_firmware, result.group_length)
            if groups then
                print("✓ 分组成功！")
                print("分组详情:")
                for i, group in ipairs(groups) do
                    print(string.format("  分组 %d: 大小=%d字节, 预览=%s", 
                                      group.index, group.size, group.hex_preview))
                end
            else
                print("✗ 分组失败: " .. tostring(err))
            end
        end
        
    else
        print("\n✗ TLV解析失败: " .. tostring(result))
    end
    
    print("\n" .. string.rep("=", 60))
    print("测试完成")
    print(string.rep("=", 60))
end

-- 运行测试
run_tlv_test()