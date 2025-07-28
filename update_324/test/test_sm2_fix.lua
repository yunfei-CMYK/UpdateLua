#!/usr/bin/env lua
-- 测试SM2验证修复的简单脚本

-- 添加路径以便找到模块
package.path = package.path .. ";../?.lua"

-- 加载主模块
local ulc_update = require("ulc_firmware_update_complete")

print("🧪 测试SM2验证修复")
print("==================")

-- 测试1：直接测试SM2验证函数
print("\n📋 测试1: 直接测试SM2验证函数")
local test_pubkey = "04" .. string.rep("A", 128)  -- 模拟公钥
local test_signature = string.rep("B", 64)        -- 模拟签名
local test_data = "1122334455667788ABCDEF"        -- 模拟数据

local result1 = ulc_update.crypto.sm2_verify(test_pubkey, "", test_signature, test_data)
print("结果: " .. tostring(result1))

-- 测试2：测试初始化流程
print("\n📋 测试2: 测试初始化流程")
local success, error_msg = pcall(function()
    ulc_update.ulc_update.initialize()
end)

if success then
    print("✅ 初始化测试通过")
else
    print("❌ 初始化测试失败: " .. tostring(error_msg))
end

-- 测试3：测试固件准备流程
print("\n📋 测试3: 测试固件准备流程")
local test_firmware_path = "../firmware/test_firmware.bin"

-- 创建一个测试固件文件
local test_firmware_content = string.rep("FF", 1024)  -- 1KB的测试数据
local file = io.open(test_firmware_path, "w")
if file then
    file:write(test_firmware_content)
    file:close()
    
    local success2, error_msg2 = pcall(function()
        ulc_update.ulc_update.prepare_firmware(test_firmware_path)
    end)
    
    if success2 then
        print("✅ 固件准备测试通过")
    else
        print("❌ 固件准备测试失败: " .. tostring(error_msg2))
    end
    
    -- 清理测试文件
    os.remove(test_firmware_path)
else
    print("⚠️  无法创建测试固件文件，跳过固件准备测试")
end

print("\n🎯 测试完成")