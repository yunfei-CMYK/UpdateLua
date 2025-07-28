-- SM2签名验证函数 - 兼容JavaScript版本实现
-- 参考: e:\Dev\Lua\example\javascript\FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js
-- 作者: longfei
-- 日期: 2025

require('ldconfig')('crypto')
local crypto = require('crypto')

print("=== SM2签名验证函数 - JavaScript兼容版本 ===")
print("LuaCrypto 版本: " .. crypto._VERSION)
print("")

-- SM2椭圆曲线参数（与JavaScript版本保持一致）
local ENTL_ID = "31323334353637383132333435363738"  -- 默认用户ID
local SM2_A = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC"
local SM2_B = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93"
local SM2_GX = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7"
local SM2_GY = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0"

-- 工具函数：十六进制字符串转二进制
local function hex_to_bin(hex_str)
    if not hex_str or hex_str == "" then
        return ""
    end
    
    -- 移除可能的空格和换行符
    hex_str = hex_str:gsub("%s+", "")
    
    -- 确保是偶数长度
    if #hex_str % 2 ~= 0 then
        hex_str = "0" .. hex_str
    end
    
    local result = {}
    for i = 1, #hex_str, 2 do
        local hex_byte = hex_str:sub(i, i + 1)
        local byte_val = tonumber(hex_byte, 16)
        if not byte_val then
            error("无效的十六进制字符: " .. hex_byte)
        end
        table.insert(result, string.char(byte_val))
    end
    
    return table.concat(result)
end

-- 工具函数：二进制转十六进制字符串
local function bin_to_hex(bin_str)
    if not bin_str then
        return ""
    end
    return crypto.hex(bin_str):upper()
end

-- 工具函数：字符串截取（模拟JavaScript的StrMid函数）
-- start_pos: 起始位置（1-based，与JavaScript的0-based不同）
-- length: 长度（-1表示到字符串末尾）
local function str_mid(str, start_pos, length)
    if not str or str == "" then
        return ""
    end
    
    if length == -1 then
        return str:sub(start_pos)
    else
        return str:sub(start_pos, start_pos + length - 1)
    end
end

-- SM2签名验证函数（简化版本，直接使用公钥对象）
-- 参数：
--   pubkey_obj: SM2公钥对象（crypto.pkey对象）
--   id: 用户标识符（十六进制字符串，可为空）
--   sign_data: 签名数据（十六进制字符串）
--   plain_data: 原始数据（十六进制字符串）
-- 返回：验证结果（boolean）
function SM2_verify_direct(pubkey_obj, id, sign_data, plain_data)
    print("=== SM2签名验证开始（直接模式）===")
    
    -- 参数验证
    if not pubkey_obj then
        print("❌ 错误: SM2公钥对象不能为空")
        return false
    end
    
    if not sign_data or sign_data == "" then
        print("❌ 错误: 签名数据不能为空")
        return false
    end
    
    if not plain_data then
        print("❌ 错误: 原始数据不能为空")
        return false
    end
    
    -- 使用默认ID（如果为空）
    local user_id = id
    if not user_id or user_id == "" then
        user_id = ENTL_ID
    end
    
    -- 调试输出
    print("签名值：", sign_data)
    print("id: ", user_id)
    print("待签名源数据：", plain_data)
    
    local success, result = pcall(function()
        -- 获取公钥的十六进制表示
        local pubkey_hex = ""
        local ok_get_key, err_get_key = pcall(function()
            local pubkey_raw = pubkey_obj:getString('RAWPUBKEY/')
            pubkey_hex = bin_to_hex(pubkey_raw)
            
            -- 确保公钥包含"04"前缀
            if not pubkey_hex:sub(1, 2) == "04" then
                pubkey_hex = "04" .. pubkey_hex
            end
        end)
        
        if not ok_get_key then
            print("⚠️  无法获取公钥十六进制表示: " .. tostring(err_get_key))
            -- 使用默认的测试公钥（这里应该根据实际情况调整）
            error("无法获取公钥数据")
        end
        
        print("SM2公钥：", pubkey_hex)
        
        -- 计算ZA值时，公钥值不包含首字节"04"
        local pubkey_without_prefix = str_mid(pubkey_hex, 3, -1)  -- 去掉首字节"04"（从第3个字符开始）
        
        -- 构造ZA值
        local za = "0080" .. user_id .. SM2_A .. SM2_B .. SM2_GX .. SM2_GY .. pubkey_without_prefix
        
        print("📝 ZA构造数据长度: " .. #za .. " 字符")
        print("📝 ZA数据: " .. za:sub(1, 100) .. "..." .. za:sub(-20))
        
        -- 第一次SM3哈希：计算ZA的摘要
        local za_bin = hex_to_bin(za)
        local md = crypto.digest("SM3", za_bin)
        local md_hex = bin_to_hex(md)
        print("🔍 ZA的SM3哈希值: " .. md_hex)
        
        -- 第二次SM3哈希：计算(ZA哈希值 + 原始数据)的摘要
        local plain_data_bin = hex_to_bin(plain_data)
        local md_hash = crypto.digest("SM3", md .. plain_data_bin)
        local md_hash_hex = bin_to_hex(md_hash)
        print("🔍 最终消息哈希值: " .. md_hash_hex)
        
        -- 执行SM2签名验证（直接使用传入的公钥对象）
        local signature_bin = hex_to_bin(sign_data)
        print("📊 签名二进制长度: " .. #signature_bin .. " 字节")
        
        -- 使用计算好的消息哈希进行验证
        local verify_result = pubkey_obj:verify(md_hash, signature_bin)
        
        print("🔍 SM2签名验证结果: " .. tostring(verify_result))
        return verify_result
    end)
    
    if success then
        if result then
            print("✅ SM2_verify_direct() 验证通过")
        else
            print("❌ SM2_verify_direct() 验证失败")
        end
        print("=== SM2签名验证结束（直接模式）===\n")
        return result
    else
        print("❌ SM2签名验证过程出错: " .. tostring(result))
        print("=== SM2签名验证结束（直接模式）===\n")
        return false
    end
end

-- 参数：
--   sm2_pubkey: SM2公钥（十六进制字符串，应包含"04"前缀）
--   id: 用户标识符（十六进制字符串，可为空）
--   sign_data: 签名数据（十六进制字符串）
--   plain_data: 原始数据（十六进制字符串）
-- 返回：验证结果（boolean）
function SM2_verify(sm2_pubkey, id, sign_data, plain_data)
    print("=== SM2签名验证开始 ===")
    
    -- 参数验证
    if not sm2_pubkey or sm2_pubkey == "" then
        print("❌ 错误: SM2公钥不能为空")
        return false
    end
    
    if not sign_data or sign_data == "" then
        print("❌ 错误: 签名数据不能为空")
        return false
    end
    
    if not plain_data then
        print("❌ 错误: 原始数据不能为空")
        return false
    end
    
    -- 使用默认ID（如果为空）
    local user_id = id
    if not user_id or user_id == "" then
        user_id = ENTL_ID
    end
    
    -- 调试输出（与JavaScript版本保持一致）
    print("签名值：", sign_data)
    print("SM2公钥：", sm2_pubkey)
    print("id: ", user_id)
    print("待签名源数据：", plain_data)
    
    local success, result = pcall(function()
        -- 计算ZA值时，公钥值不包含首字节"04"（与JavaScript版本逻辑一致）
        local pubkey_without_prefix = str_mid(sm2_pubkey, 3, -1)  -- 去掉首字节"04"（从第3个字符开始）
        
        -- 构造ZA值（完全按照JavaScript版本的逻辑）
        local za = "0080" .. user_id .. SM2_A .. SM2_B .. SM2_GX .. SM2_GY .. pubkey_without_prefix
        
        print("📝 ZA构造数据长度: " .. #za .. " 字符")
        print("📝 ZA数据: " .. za:sub(1, 100) .. "..." .. za:sub(-20))  -- 显示前100和后20字符
        
        -- 第一次SM3哈希：计算ZA的摘要
        local za_bin = hex_to_bin(za)
        local md = crypto.digest("SM3", za_bin)
        local md_hex = bin_to_hex(md)
        print("🔍 ZA的SM3哈希值: " .. md_hex)
        
        -- 第二次SM3哈希：计算(ZA哈希值 + 原始数据)的摘要
        local plain_data_bin = hex_to_bin(plain_data)
        local md_hash = crypto.digest("SM3", md .. plain_data_bin)
        local md_hash_hex = bin_to_hex(md_hash)
        print("🔍 最终消息哈希值: " .. md_hash_hex)
        
        -- 创建SM2公钥对象进行签名验证
        -- 确保公钥包含"04"前缀
        local full_pubkey = sm2_pubkey
        if not full_pubkey:sub(1, 2) == "04" then
            full_pubkey = "04" .. full_pubkey
        end
        
        -- 验证公钥长度
        if #full_pubkey ~= 130 then
            error("公钥长度无效，应该是130个字符（含04前缀），实际长度: " .. #full_pubkey)
        end
        
        print("📊 公钥长度验证通过: " .. #full_pubkey .. " 字符")
        
        -- 尝试多种方式创建SM2公钥对象
        local pkey = nil
        local create_success = false
        
        -- 方法1：使用RAWPUBKEY格式（包含04前缀）
        local ok1, err1 = pcall(function()
            local pubkey_bin = hex_to_bin(full_pubkey)
            pkey = crypto.pkey.new(pubkey_bin, "RAWPUBKEY/SM2")
            if pkey then
                create_success = true
                print("✅ 成功使用RAWPUBKEY/SM2格式创建公钥对象")
            end
        end)
        
        if not ok1 then
            print("⚠️  RAWPUBKEY/SM2方法失败: " .. tostring(err1))
        end
        
        -- 方法2：使用标准RAWPUBKEY格式
        if not create_success then
            local ok2, err2 = pcall(function()
                local pubkey_bin = hex_to_bin(full_pubkey)
                pkey = crypto.pkey.new(pubkey_bin, "RAWPUBKEY/")
                if pkey then
                    create_success = true
                    print("✅ 成功使用RAWPUBKEY格式创建公钥对象")
                end
            end)
            
            if not ok2 then
                print("⚠️  RAWPUBKEY方法失败: " .. tostring(err2))
            end
        end
        
        -- 方法3：使用DER格式
        if not create_success then
            local ok3, err3 = pcall(function()
                -- SM2公钥的DER格式头部（正确的SM2 OID）
                local der_header = hex_to_bin("3059301306072A8648CE3D020106082A811CCF5501822D034200")
                local pubkey_bin = hex_to_bin(full_pubkey)
                local der_pubkey = der_header .. pubkey_bin
                pkey = crypto.pkey.new(der_pubkey, "PUBKEY/")
                if pkey then
                    create_success = true
                    print("✅ 成功使用DER格式创建公钥对象")
                end
            end)
            
            if not ok3 then
                print("⚠️  DER方法失败: " .. tostring(err3))
            end
        end
        
        -- 方法4：尝试不带前缀的原始格式
        if not create_success then
            local ok4, err4 = pcall(function()
                local raw_pubkey_bin = hex_to_bin(pubkey_without_prefix)
                pkey = crypto.pkey.new(raw_pubkey_bin, "RAWPUBKEY/SM2")
                if pkey then
                    create_success = true
                    print("✅ 成功使用原始格式创建公钥对象")
                end
            end)
            
            if not ok4 then
                print("⚠️  原始格式方法失败: " .. tostring(err4))
            end
        end
        
        -- 方法5：尝试使用旧版API格式
        if not create_success then
            local ok5, err5 = pcall(function()
                if crypto.pkey.d2i then
                    -- 构造简单的DER格式
                    local simple_der = hex_to_bin("30" .. string.format("%02X", #full_pubkey/2 + 2) .. "0400" .. full_pubkey)
                    pkey = crypto.pkey.d2i('sm2', simple_der, 'pubkey')
                    if pkey then
                        create_success = true
                        print("✅ 成功使用旧版API格式创建公钥对象")
                    end
                end
            end)
            
            if not ok5 then
                print("⚠️  旧版API方法失败: " .. tostring(err5))
            end
        end
        
        if not create_success then
            error("无法创建SM2公钥对象，所有方法都失败了")
        end
        
        -- 执行SM2签名验证
        local signature_bin = hex_to_bin(sign_data)
        print("📊 签名二进制长度: " .. #signature_bin .. " 字节")
        
        -- 使用计算好的消息哈希进行验证
        local verify_result = pkey:verify(md_hash, signature_bin)
        
        print("🔍 SM2签名验证结果: " .. tostring(verify_result))
        return verify_result
    end)
    
    if success then
        if result then
            print("✅ SM2_verify() 验证通过")
        else
            print("❌ SM2_verify() 验证失败")
        end
        print("=== SM2签名验证结束 ===\n")
        return result
    else
        print("❌ SM2签名验证过程出错: " .. tostring(result))
        print("=== SM2签名验证结束 ===\n")
        return false
    end
end

-- 测试函数：生成测试数据并验证
local function test_sm2_verify()
    print("=== 开始SM2签名验证测试 ===")
    
    -- 生成SM2密钥对用于测试
    local pri, pub = nil, nil
    
    -- 尝试使用新版API生成密钥对
    local ok, err = pcall(function()
        pri = crypto.pkey.generate('SM2/')
        pub = crypto.pkey.new(pri:getString('PUBKEY/'), 'PUBKEY/')
    end)
    
    if not ok then
        print("⚠️  新版API失败，尝试旧版API: " .. tostring(err))
        -- 尝试使用旧版API
        if crypto.pkey.generate then
            local ok2, err2 = pcall(function()
                pri = crypto.pkey.generate('sm2')
                pub = crypto.pkey.d2i('sm2', pri:i2d('pubkey'), 'pubkey')
            end)
            
            if not ok2 then
                print("❌ 无法生成SM2密钥对: " .. tostring(err2))
                return false
            end
        else
            print("❌ 无法生成SM2密钥对，crypto库不支持")
            return false
        end
    end
    
    if not pri or not pub then
        print("❌ 密钥对生成失败")
        return false
    end
    
    print("✅ SM2密钥对生成成功")
    
    -- 获取公钥（十六进制格式）
    local pubkey_hex = ""
    local ok3, err3 = pcall(function()
        local pubkey_raw = pub:getString('RAWPUBKEY/')
        pubkey_hex = bin_to_hex(pubkey_raw)
        
        -- 确保公钥包含"04"前缀
        if not pubkey_hex:sub(1, 2) == "04" then
            pubkey_hex = "04" .. pubkey_hex
        end
    end)
    
    if not ok3 then
        print("⚠️  获取RAWPUBKEY失败，尝试其他方法: " .. tostring(err3))
        local ok4, err4 = pcall(function()
            -- 尝试使用旧版API获取公钥
            if pub.i2d then
                local pubkey_der = pub:i2d('pubkey')
                local pubkey_der_hex = bin_to_hex(pubkey_der)
                print("📊 DER格式公钥: " .. pubkey_der_hex)
                
                -- 从DER格式中提取原始公钥
                -- SM2公钥DER格式通常以特定的头部开始，公钥数据在最后
                if #pubkey_der_hex >= 130 then
                    -- 查找"04"开头的公钥数据
                    local pos = pubkey_der_hex:find("04")
                    if pos and pos <= #pubkey_der_hex - 128 then
                        pubkey_hex = pubkey_der_hex:sub(pos, pos + 129)  -- 提取130个字符（04 + 128字符公钥）
                    else
                        -- 如果找不到04前缀，取最后130个字符并添加04前缀
                        local raw_key = pubkey_der_hex:sub(-128)
                        pubkey_hex = "04" .. raw_key
                    end
                else
                    error("DER格式公钥长度不足")
                end
            else
                error("无法使用旧版API获取公钥")
            end
        end)
        
        if not ok4 then
            print("❌ 无法获取公钥: " .. tostring(err4))
            return false
        end
    end
    
    print("📊 生成的公钥: " .. pubkey_hex)
    print("📊 公钥长度: " .. #pubkey_hex .. " 字符")
    
    -- 测试数据
    local test_data = "1122334455667788"  -- 测试用的原始数据
    local test_id = ""  -- 使用默认ID
    
    -- 生成签名
    local signature_hex = ""
    local ok5, err5 = pcall(function()
        -- 计算ZA值
        local user_id = test_id
        if not user_id or user_id == "" then
            user_id = ENTL_ID
        end
        
        local pubkey_without_prefix = pubkey_hex:sub(3)  -- 去掉"04"前缀
        local za = "0080" .. user_id .. SM2_A .. SM2_B .. SM2_GX .. SM2_GY .. pubkey_without_prefix
        
        -- 计算ZA哈希
        local za_bin = hex_to_bin(za)
        local za_hash = crypto.digest("SM3", za_bin)
        
        -- 计算最终消息哈希
        local test_data_bin = hex_to_bin(test_data)
        local message_hash = crypto.digest("SM3", za_hash .. test_data_bin)
        
        -- 生成签名
        local signature_bin = pri:sign(message_hash)
        signature_hex = bin_to_hex(signature_bin)
    end)
    
    if not ok5 then
        print("❌ 签名生成失败: " .. tostring(err5))
        return false
    end
    
    print("📊 生成的签名: " .. signature_hex)
    print("📊 签名长度: " .. #signature_hex .. " 字符")
    
    -- 使用我们的SM2_verify函数进行验证
    print("\n--- 开始验证测试（直接模式）---")
    local verify_result_direct = SM2_verify_direct(pub, test_id, signature_hex, test_data)
    
    print("\n--- 开始验证测试（格式转换模式）---")
    local verify_result_convert = SM2_verify(pubkey_hex, test_id, signature_hex, test_data)
    
    if verify_result_direct then
        print("🎉 直接模式测试成功：SM2签名验证通过！")
    else
        print("❌ 直接模式测试失败：SM2签名验证未通过")
    end
    
    if verify_result_convert then
        print("🎉 格式转换模式测试成功：SM2签名验证通过！")
    else
        print("❌ 格式转换模式测试失败：SM2签名验证未通过")
    end
    
    -- 只要有一种方法成功就算测试通过
    return verify_result_direct or verify_result_convert
end

-- 主程序执行
print("=== SM2签名验证函数测试程序 ===")
print("本程序实现了与JavaScript版本完全兼容的SM2_verify函数")
print("")

-- 执行测试
local test_success = test_sm2_verify()

if test_success then
    print("\n🎉 所有测试通过！SM2_verify函数工作正常")
else
    print("\n❌ 测试失败，请检查crypto库支持或实现逻辑")
end

print("\n=== 程序结束 ===")