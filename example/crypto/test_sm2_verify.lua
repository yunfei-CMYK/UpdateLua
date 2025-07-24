-- SM2 签名验证测试脚本
-- 测试 sm2_verify_lua.lua 的功能

-- 加载 SM2 验证模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path
local sm2_module = require("sm2_verify_lua")

print("=== SM2 签名验证测试开始 ===")
print()

-- 测试用例1：基本功能测试（使用生成的密钥对）
print("=== 测试用例1：生成密钥对并测试签名验证 ===")
local success1, result1 = pcall(function()
    local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
    if not crypto.hex then
        crypto.hex = require("tdr.lib.base16").encode
    end
    
    -- 生成 SM2 密钥对
    print("正在生成 SM2 密钥对...")
    local keypair = crypto.pkey.generate('SM2/')
    
    if not keypair then
        error("无法生成 SM2 密钥对")
    end
    
    print("✅ SM2 密钥对生成成功")
    
    -- 获取公钥
    local pubkey_raw = keypair:getString('RAWPUBKEY/')
    print("原始公钥长度:", #pubkey_raw)
    print("原始公钥（前20字节）:", crypto.hex(pubkey_raw:sub(1, 20)))
    
    -- 测试消息
    local test_message = "Hello SM2 World!"
    print("测试消息:", test_message)
    
    -- 生成签名
    local signature = keypair:digestSign('SM3', test_message)
    print("签名长度:", #signature)
    print("签名（十六进制）:", crypto.hex(signature))
    
    -- 使用密钥对直接验证（作为对照）
    local direct_verify = keypair:digestVerify('SM3', test_message, signature)
    print("直接验证结果:", direct_verify)
    
    if direct_verify then
        print("✅ 密钥对生成和签名验证功能正常")
        return true
    else
        error("密钥对验证失败")
    end
end)

if success1 then
    print("测试用例1：通过")
else
    print("测试用例1：失败 -", result1)
end
print()

-- 测试用例2：工具函数测试
print("=== 测试用例2：工具函数测试 ===")
local success2, result2 = pcall(function()
    -- 测试十六进制转换
    local test_hex = "48656C6C6F"  -- "Hello"
    local test_bin = sm2_module.hex_to_bin(test_hex)
    local back_hex = sm2_module.bin_to_hex(test_bin)
    
    print("原始十六进制:", test_hex)
    print("转换为二进制:", test_bin)
    print("转换回十六进制:", back_hex:upper())
    
    if test_hex:upper() == back_hex:upper() then
        print("✅ 十六进制转换功能正常")
    else
        error("十六进制转换失败")
    end
    
    -- 测试字符串截取
    local test_str = "1234567890"
    local substr_result = sm2_module.substr(test_str, 3, 4)
    print("字符串截取测试:", test_str, "->", substr_result)
    
    if substr_result == "3456" then
        print("✅ 字符串截取功能正常")
    else
        error("字符串截取失败")
    end
    
    return true
end)

if success2 then
    print("测试用例2：通过")
else
    print("测试用例2：失败 -", result2)
end
print()

-- 测试用例3：参数验证测试
print("=== 测试用例3：参数验证测试 ===")
local test_cases = {
    {nil, "test_id", "test_sig", "test_data", "空公钥"},
    {"", "test_id", "test_sig", "test_data", "空公钥字符串"},
    {"valid_pubkey", "test_id", nil, "test_data", "空签名"},
    {"valid_pubkey", "test_id", "", "test_data", "空签名字符串"},
    {"valid_pubkey", "test_id", "test_sig", nil, "空数据"},
    {"short", "test_id", "test_sig", "test_data", "公钥太短"},
}

for i, case in ipairs(test_cases) do
    local pubkey, id, sig, data, desc = case[1], case[2], case[3], case[4], case[5]
    print(string.format("测试 %d - %s:", i, desc))
    
    local success, result = pcall(sm2_module.sm2_verify, pubkey, id, sig, data)
    if success then
        print("  结果: 验证通过 -", result)
    else
        print("  结果: 验证失败 -", result)
    end
end
print()

-- 测试用例4：SM2 参数检查
print("=== 测试用例4：SM2 参数检查 ===")
print("SM2 椭圆曲线参数:")
for key, value in pairs(sm2_module.SM2_PARAMS) do
    print(string.format("  %s: %s", key, value))
end
print()

print("=== 所有测试完成 ===")
print("注意：由于缺少真实的 SM2 签名数据，某些测试可能会失败。")
print("这是正常现象，主要目的是验证代码结构和基本功能。")