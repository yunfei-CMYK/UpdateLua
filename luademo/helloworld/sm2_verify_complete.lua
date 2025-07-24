-- SM2 验证函数的完整 Lua 实现
-- 基于 JavaScript 版本的 SM2_verify 函数
require("ldconfig")("crypto")
-- 加载必要的库
local crypto = require("crypto")
local digest = crypto.digest
local pkey = crypto.pkey

-- SM2 椭圆曲线参数（与 JavaScript 版本完全一致）
local ENTL_ID = "31323334353637383132333435363738"
local a = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC"
local b = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93"
local Gx = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7"
local Gy = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0"

-- 工具函数：将字符串转换为十六进制
local function str_to_hex(str)
    if not str then return "" end
    return (str:gsub(".", function(c) return string.format("%02X", string.byte(c)) end))
end

-- 工具函数：将十六进制字符串转换为二进制字符串
local function hex_to_str(hex)
    if not hex then return "" end
    -- 确保十六进制字符串长度为偶数
    if #hex % 2 ~= 0 then
        hex = "0" .. hex
    end
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

-- 工具函数：提取子字符串（模拟 JavaScript 的 Def.StrMid）
-- start: 起始位置（从0开始，与JavaScript一致）
-- length: 长度，-1表示到字符串末尾
local function str_mid(str, start, length)
    if not str or not start then return "" end
    
    -- 转换为 Lua 的索引（从1开始）
    local lua_start = start + 1
    
    if not length or length == -1 then
        return str:sub(lua_start)
    else
        return str:sub(lua_start, lua_start + length - 1)
    end
end

-- SM2 验证函数（完全对应 JavaScript 版本）
local function SM2_verify(SM2_PubKey, id, SignData, plainData)
    -- 参数检查和默认值设置
    if not id or id == "" then
        id = ENTL_ID
    end
    
    -- 调试输出（对应 JavaScript 的 Debug.writeln）
    print("签名值：", SignData or "")
    print("SM2公钥：", SM2_PubKey or "")
    print("id:", id)
    print("待签名源数据：", plainData or "")
    
    -- 计算 ZA 值时，公钥值不包含首字节"04"
    -- 对应 JavaScript: Def.StrMid(SM2_PubKey, 1, -1)
    local pubkey_without_prefix = str_mid(SM2_PubKey, 1, -1)
    
    -- 构建 ZA 数据
    -- 对应 JavaScript: "0080" + id + a + b + Gx + Gy + Def.StrMid(SM2_PubKey, 1, -1)
    local za = "0080" .. id .. a .. b .. Gx .. Gy .. pubkey_without_prefix
    
    -- 第一步：计算 md = SM3(za)
    -- 对应 JavaScript: Digest.Init("SM3"); var md = Digest.Digest(za);
    local md = digest('sm3', hex_to_str(za))
    local md_hex = str_to_hex(md)
    
    -- 第二步：计算 md_Hash = SM3(md + plainData)
    -- 对应 JavaScript: Digest.Init("SM3"); var md_Hash = Digest.Digest(md + plainData);
    local md_hash = digest('sm3', md .. hex_to_str(plainData))
    local md_hash_hex = str_to_hex(md_hash)
    
    print("md_Hash:", md_hash_hex)
    
    -- 创建 SM2 公钥对象并进行验证
    -- 对应 JavaScript: Itrus.sm2_pubkey_import(SM2_PubKey); Itrus.sm2_verify(md_Hash, SignData);
    local success, result = pcall(function()
        local sm2_pubkey = pkey.new(hex_to_str(SM2_PubKey), 'RAWPUBKEY/')
        return sm2_pubkey:verify(hex_to_str(md_hash_hex), hex_to_str(SignData))
    end)
    
    if success and result then
        print("SM2_verify() 验证通过")
        return true
    else
        print("SM2_verify() 验证失败:", result or "未知错误")
        return false
    end
end

-- 测试函数
local function test_sm2_verify()
    print("=== SM2 验证函数测试 ===")
    
    -- 测试数据（示例）
    local test_pubkey = "04A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D3190BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0"
    local test_id = ""  -- 空字符串将使用默认 ENTL_ID
    local test_signature = "3045022100B1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDE022012345678901234567890123456789012345678901234567890123456789012"
    local test_plaindata = "1122334455667788AABBCCDDEEFF"
    
    local result = SM2_verify(test_pubkey, test_id, test_signature, test_plaindata)
    print("测试结果:", result and "成功" or "失败")
end

-- 导出函数
return {
    SM2_verify = SM2_verify,
    test = test_sm2_verify,
    -- 导出工具函数
    str_to_hex = str_to_hex,
    hex_to_str = hex_to_str,
    str_mid = str_mid,
    -- 导出常量
    ENTL_ID = ENTL_ID,
    SM2_A = a,
    SM2_B = b,
    SM2_GX = Gx,
    SM2_GY = Gy
}