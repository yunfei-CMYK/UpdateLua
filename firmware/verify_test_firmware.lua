-- TLV固件包验证脚本
-- 用于验证生成的测试固件包文件是否符合TLV格式规范

-- TLV解析辅助函数
local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
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

local function bytes_to_hex(bytes, max_length)
    max_length = max_length or #bytes
    local hex_chars = {}
    for i = 1, math.min(max_length, #bytes) do
        hex_chars[i] = string.format("%02X", bytes[i])
    end
    local result = table.concat(hex_chars, " ")
    if #bytes > max_length then
        result = result .. "..."
    end
    return result
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

-- 验证固件包文件
local function verify_firmware_file(filename)
    print(string.rep("-", 50))
    print("验证文件: " .. filename)
    print(string.rep("-", 50))
    
    -- 读取文件
    local file = io.open(filename, "rb")
    if not file then
        print("❌ 无法打开文件: " .. filename)
        return false
    end
    
    local data = file:read("*all")
    file:close()
    
    print("文件大小: " .. #data .. " 字节")
    
    -- 转换为字节数组
    local bytes = string_to_bytes(data)
    
    -- 解析外层TLV (应该是TAG=0x71)
    local outer_tlv, err = parse_tlv(bytes, 1)
    if not outer_tlv then
        print("❌ 外层TLV解析失败: " .. err)
        return false
    end
    
    if outer_tlv.tag ~= 0x71 then
        print("❌ 外层TAG错误: 期望0x71，实际0x" .. string.format("%02X", outer_tlv.tag))
        return false
    end
    
    print("✅ 外层TLV: TAG=0x71, LENGTH=" .. outer_tlv.length)
    
    -- 解析内层TLV结构
    local inner_bytes = outer_tlv.value
    local pos = 1
    local package_info = {}
    
    while pos <= #inner_bytes do
        local tlv, tlv_err = parse_tlv(inner_bytes, pos)
        if not tlv then
            print("❌ 内层TLV解析失败 (位置 " .. pos .. "): " .. tlv_err)
            return false
        end
        
        if tlv.tag == 0x57 then
            -- 分组长度
            if tlv.length ~= 2 then
                print("❌ 分组长度字段长度错误: 期望2字节，实际" .. tlv.length .. "字节")
                return false
            end
            package_info.group_length = read_multibyte_int(tlv.value, 1, 2)
            print("✅ 分组长度: " .. package_info.group_length .. " 字节")
            
        elseif tlv.tag == 0x58 then
            -- 固件包MAC
            if tlv.length ~= 16 then
                print("❌ MAC字段长度错误: 期望16字节，实际" .. tlv.length .. "字节")
                return false
            end
            package_info.mac = tlv.value
            print("✅ 固件包MAC: " .. bytes_to_hex(tlv.value, 8))
            
        elseif tlv.tag == 0x59 then
            -- 密文固件包
            package_info.encrypted_firmware = tlv.value
            package_info.firmware_length = tlv.length
            print("✅ 密文固件包长度: " .. tlv.length .. " 字节")
            
        else
            print("⚠️  未知内层TAG: 0x" .. string.format("%02X", tlv.tag))
        end
        
        pos = tlv.next_pos
    end
    
    -- 验证必要字段
    local success = true
    if not package_info.group_length then
        print("❌ 缺少分组长度字段 (TAG=0x57)")
        success = false
    end
    if not package_info.mac then
        print("❌ 缺少MAC字段 (TAG=0x58)")
        success = false
    end
    if not package_info.encrypted_firmware then
        print("❌ 缺少密文固件包字段 (TAG=0x59)")
        success = false
    end
    
    -- 验证固件长度是分组长度的整数倍
    if package_info.group_length and package_info.firmware_length then
        local remainder = package_info.firmware_length % package_info.group_length
        if remainder == 0 then
            local groups_count = package_info.firmware_length / package_info.group_length
            print("✅ 固件长度验证通过: " .. groups_count .. " 个完整分组")
        else
            print("❌ 固件长度验证失败: 不是分组长度的整数倍 (余数: " .. remainder .. ")")
            success = false
        end
    end
    
    if success then
        print("🎉 文件验证成功！")
    else
        print("💥 文件验证失败！")
    end
    
    return success
end

-- 主验证函数
local function verify_all_files()
    print(string.rep("=", 60))
    print("TLV固件包文件验证")
    print(string.rep("=", 60))
    
    -- 使用绝对路径
    local firmware_dir = "E:\\Dev\\Lua\\firmware\\"
    local test_files = {
        firmware_dir .. "test_firmware_small.bin",
        firmware_dir .. "test_firmware_medium.bin", 
        firmware_dir .. "test_firmware_large.bin",
        firmware_dir .. "test_firmware_special.bin",
        firmware_dir .. "test_firmware_single.bin"
    }
    
    local success_count = 0
    local total_count = #test_files
    
    for _, filename in ipairs(test_files) do
        local success = verify_firmware_file(filename)
        if success then
            success_count = success_count + 1
        end
        print("")
    end
    
    print(string.rep("=", 60))
    print("验证结果汇总")
    print(string.rep("=", 60))
    print("总文件数: " .. total_count)
    print("验证成功: " .. success_count)
    print("验证失败: " .. (total_count - success_count))
    
    if success_count == total_count then
        print("🎉 所有文件验证通过！")
    else
        print("⚠️  部分文件验证失败，请检查！")
    end
end

-- 执行验证
verify_all_files()