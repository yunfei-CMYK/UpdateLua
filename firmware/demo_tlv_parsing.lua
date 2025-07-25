-- TLV固件包解析演示脚本
-- 使用生成的测试固件包文件演示完整的TLV解析流程

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
                    print("    固件数据预览: " .. bytes_to_hex(inner_tlv.value, 16))
                    
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
    end
    
    return groups, nil
end

-- 演示解析单个文件
local function demo_parse_file(filename)
    print(string.rep("=", 70))
    print("演示解析文件: " .. filename)
    print(string.rep("=", 70))
    
    -- 读取文件
    local file = io.open(filename, "rb")
    if not file then
        print("❌ 无法打开文件: " .. filename)
        return false
    end
    
    local data = file:read("*all")
    file:close()
    
    print("文件大小: " .. #data .. " 字节")
    print("")
    
    -- 解析固件包
    local success, package_info = parse_firmware_package(data)
    
    if not success then
        print("❌ 解析失败: " .. tostring(package_info))
        return false
    end
    
    print("\n✅ 解析成功！")
    print("解析结果汇总:")
    print("  - 分组长度: " .. (package_info.group_length or "未找到") .. " 字节")
    print("  - MAC长度: " .. (package_info.mac and #package_info.mac or "未找到") .. " 字节")
    print("  - 密文固件包长度: " .. (package_info.encrypted_firmware and #package_info.encrypted_firmware or "未找到") .. " 字节")
    
    -- 进行分组处理
    if package_info.group_length and package_info.encrypted_firmware then
        print("\n开始分组处理...")
        local groups, err = split_firmware_into_groups(package_info.encrypted_firmware, package_info.group_length)
        
        if groups then
            print("✅ 分组处理成功！")
            print("分组详情:")
            for i, group in ipairs(groups) do
                print(string.format("  分组 %d: 大小=%d字节, 数据预览=%s", 
                                  group.index, group.size, group.hex_preview))
            end
        else
            print("❌ 分组处理失败: " .. tostring(err))
        end
    end
    
    print("")
    return true
end

-- 主演示函数
local function run_demo()
    print(string.rep("=", 70))
    print("TLV固件包解析演示")
    print(string.rep("=", 70))
    print("")
    
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
    
    for _, filename in ipairs(test_files) do
        local success = demo_parse_file(filename)
        if success then
            success_count = success_count + 1
        end
    end
    
    print(string.rep("=", 70))
    print("演示完成")
    print(string.rep("=", 70))
    print("成功解析: " .. success_count .. "/" .. #test_files .. " 个文件")
    
    if success_count == #test_files then
        print("🎉 所有测试文件解析成功！")
    else
        print("⚠️  部分文件解析失败")
    end
end

-- 运行演示
run_demo()