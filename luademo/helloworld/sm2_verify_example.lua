-- SM2 验证函数使用示例

-- 加载 SM2 验证模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path
local sm2_module = require("sm2_verify_complete")

-- 示例1：基本使用
print("=== 示例1：基本 SM2 验证 ===")

-- 测试参数
local pubkey = "04A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D3190BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0"
local user_id = ""  -- 空字符串将使用默认 ENTL_ID
local signature = "签名数据的十六进制字符串"
local plain_data = "1122334455667788"

-- 调用验证函数
local verify_result = sm2_module.SM2_verify(pubkey, user_id, signature, plain_data)
print("验证结果:", verify_result and "通过" or "失败")

print("\n=== 示例2：自定义 ID 验证 ===")

-- 使用自定义 ID
local custom_id = "ABCDEF1234567890ABCDEF1234567890"
local verify_result2 = sm2_module.SM2_verify(pubkey, custom_id, signature, plain_data)
print("验证结果:", verify_result2 and "通过" or "失败")

print("\n=== 示例3：工具函数使用 ===")

-- 演示工具函数
local test_str = "Hello World"
local hex_str = sm2_module.str_to_hex(test_str)
print("字符串转十六进制:", test_str, "->", hex_str)

local back_str = sm2_module.hex_to_str(hex_str)
print("十六进制转字符串:", hex_str, "->", back_str)

-- 演示 str_mid 函数
local test_string = "0123456789ABCDEF"
print("原字符串:", test_string)
print("str_mid(str, 1, -1):", sm2_module.str_mid(test_string, 1, -1))  -- 去掉首字符
print("str_mid(str, 2, 4):", sm2_module.str_mid(test_string, 2, 4))    -- 从位置2开始取4个字符

print("\n=== 示例4：常量访问 ===")
print("ENTL_ID:", sm2_module.ENTL_ID)
print("SM2_A:", sm2_module.SM2_A)
print("SM2_B:", sm2_module.SM2_B)
print("SM2_GX:", sm2_module.SM2_GX)
print("SM2_GY:", sm2_module.SM2_GY)