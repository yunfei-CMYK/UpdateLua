-- SM2 签名验证实现
-- 基于 pkey.lua 示例的 SM2 使用方法

local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
    crypto.hex = require("tdr.lib.base16").encode
end

-- SM2 椭圆曲线参数
local SM2_PARAMS = {
    p = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFF",
    a = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC", 
    b = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93",
    n = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF7203DF6B61C6823DA31F6B049E8424DC",
    Gx = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7",
    Gy = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0"
}

-- 工具函数：十六进制字符串转二进制
local function hex_to_bin(hex_str)
    if not hex_str or hex_str == "" then
        return ""
    end
    
    -- 确保字符串长度为偶数
    if #hex_str % 2 ~= 0 then
        hex_str = "0" .. hex_str
    end
    
    local result = ""
    for i = 1, #hex_str, 2 do
        local hex_byte = hex_str:sub(i, i + 1)
        local byte_val = tonumber(hex_byte, 16)
        if byte_val then
            result = result .. string.char(byte_val)
        else
            error("无效的十六进制字符: " .. hex_byte)
        end
    end
    return result
end

-- 工具函数：二进制转十六进制字符串
local function bin_to_hex(bin_str)
    if not bin_str then
        return ""
    end
    return crypto.hex(bin_str)
end

-- 工具函数：字符串截取
local function substr(str, start_pos, length)
    if not str or start_pos < 1 then
        return ""
    end
    
    if length then
        return str:sub(start_pos, start_pos + length - 1)
    else
        return str:sub(start_pos)
    end
end

-- SM2 签名验证函数
-- 参数：
--   sm2_pubkey: SM2 公钥（十六进制字符串，不含"04"前缀）
--   user_id: 用户ID（十六进制字符串）
--   signature: 签名数据（十六进制字符串）
--   plain_data: 原始数据（字符串）
-- 返回：验证结果（boolean）
local function sm2_verify(sm2_pubkey, user_id, signature, plain_data)
    -- 参数验证
    if not sm2_pubkey or sm2_pubkey == "" then
        error("SM2 公钥不能为空")
    end
    
    if not signature or signature == "" then
        error("签名数据不能为空")
    end
    
    if not plain_data then
        error("原始数据不能为空")
    end
    
    -- 默认用户ID
    if not user_id or user_id == "" then
        user_id = "31323334353637383132333435363738"  -- "1234567812345678"
    end
    
    print("开始 SM2 签名验证...")
    print("公钥长度:", #sm2_pubkey)
    print("签名长度:", #signature)
    print("用户ID:", user_id)
    print("原始数据:", plain_data)
    
    -- 使用简化的方法：直接生成 SM2 密钥对进行测试
    local success, result = pcall(function()
        -- 方法1：尝试使用提供的公钥创建密钥对象
        local pubkey_without_prefix = sm2_pubkey
        if sm2_pubkey:sub(1, 2) == "04" then
            pubkey_without_prefix = sm2_pubkey:sub(3)
        end
        
        -- 构造完整的公钥（添加"04"前缀）
        local full_pubkey = "04" .. pubkey_without_prefix
        
        -- 验证公钥长度
        if #full_pubkey ~= 130 then
            error("公钥长度无效，应该是130个字符（含04前缀）")
        end
        
        local pubkey_bin = hex_to_bin(full_pubkey)
        print("公钥二进制长度:", #pubkey_bin)
        
        -- 尝试创建公钥对象
        local pkey = nil
        local create_success = false
        
        -- 方法1：使用 RAWPUBKEY 格式
        local ok1, err1 = pcall(function()
            pkey = crypto.pkey.new(pubkey_bin, "RAWPUBKEY/")
            if pkey then
                create_success = true
                print("成功使用 RAWPUBKEY 格式创建公钥对象")
            end
        end)
        
        if not create_success then
            -- 方法2：尝试使用 DER 格式
            local ok2, err2 = pcall(function()
                -- SM2 公钥的 DER 格式头部
                local der_header = hex_to_bin("3059301306072A8648CE3D020106082A811CCF5501822D03420000")
                local der_pubkey = der_header .. pubkey_bin
                pkey = crypto.pkey.new(der_pubkey, "PUBKEY/")
                if pkey then
                    create_success = true
                    print("成功使用 DER 格式创建公钥对象")
                end
            end)
        end
        
        if not create_success or not pkey then
            error("无法创建 SM2 公钥对象")
        end
        
        -- 转换签名格式
        local signature_bin = hex_to_bin(signature)
        print("签名二进制长度:", #signature_bin)
        
        -- 执行 SM2 签名验证
        -- 注意：这里使用 digestVerify 方法，它会自动处理 SM3 摘要
        local verify_result = pkey:digestVerify("SM3", plain_data, signature_bin)
        
        print("SM2 签名验证结果:", verify_result)
        return verify_result
    end)
    
    if success then
        return result
    else
        print("SM2 签名验证失败:", result)
        return false
    end
end

-- 导出模块
return {
    sm2_verify = sm2_verify,
    hex_to_bin = hex_to_bin,
    bin_to_hex = bin_to_hex,
    substr = substr,
    SM2_PARAMS = SM2_PARAMS
}