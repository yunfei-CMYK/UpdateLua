#!/usr/bin/env lua
-- SM2 集成验证脚本
-- 用于快速验证 SM2 功能是否正确集成到 ulc_firmware_update_complete.lua 中

print("=== 🔐 SM2 集成验证脚本 ===")
print("")

-- 加载固件更新模块
-- 获取当前脚本所在目录
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

-- 添加当前目录和上级目录到模块搜索路径
-- 因为 ulc_firmware_update_complete.lua 在上级目录中
package.path = this_dir .. "?.lua;" .. this_dir .. "../?.lua;" .. package.path
local success, ulc_module = pcall(require, "ulc_firmware_update_complete")

if not success then
    print("❌ 错误: 无法加载 ulc_firmware_update_complete.lua 模块")
    print("   错误信息: " .. tostring(ulc_module))
    return
end

print("✅ 成功加载 ulc_firmware_update_complete.lua 模块")

-- 检查 crypto 模块是否存在
if not ulc_module.crypto then
    print("❌ 错误: crypto 模块不存在")
    return
end

print("✅ crypto 模块存在")

-- 检查 SM2 验证函数是否存在
local sm2_functions = {
    {"sm2_verify", "SM2 签名验证函数"},
    {"sm2_verify_direct", "SM2 直接模式验证函数"}
}

local functions_found = 0
for _, func_info in ipairs(sm2_functions) do
    local func_name, func_desc = func_info[1], func_info[2]
    if ulc_module.crypto[func_name] then
        print("✅ " .. func_desc .. " (" .. func_name .. ") 存在")
        functions_found = functions_found + 1
    else
        print("❌ " .. func_desc .. " (" .. func_name .. ") 不存在")
    end
end

print("")

-- 测试基本功能
if functions_found > 0 then
    print("🧪 测试基本 SM2 验证功能:")
    
    -- 测试数据
    local test_data = {
        public_key = "04" .. string.rep("A1B2C3D4", 16),  -- 模拟公钥
        id = "31323334353637383132333435363738",  -- "12345678" 的十六进制
        signature = string.rep("ABCD", 16),  -- 模拟签名
        plain_data = "48656C6C6F20576F726C64"  -- "Hello World" 的十六进制
    }
    
    -- 测试 sm2_verify 函数
    if ulc_module.crypto.sm2_verify then
        print("  📋 测试 sm2_verify 函数:")
        local success, result = pcall(function()
            return ulc_module.crypto.sm2_verify(
                test_data.public_key,
                test_data.id,
                test_data.signature,
                test_data.plain_data
            )
        end)
        
        if success then
            print("    ✅ 函数调用成功，返回值: " .. tostring(result))
        else
            print("    ❌ 函数调用失败: " .. tostring(result))
        end
    end
    
    print("")
    
    -- 测试 sm2_verify_direct 函数（如果存在）
    if ulc_module.crypto.sm2_verify_direct then
        print("  📋 测试 sm2_verify_direct 函数:")
        print("    ⚠️  需要真实的公钥对象，跳过此测试")
    end
    
    print("")
end

-- 检查配置常量
print("🔧 检查 SM2 相关配置:")
local config_items = {
    {"SM2_A", "SM2 椭圆曲线参数 a"},
    {"SM2_B", "SM2 椭圆曲线参数 b"},
    {"SM2_GX", "SM2 基点 Gx"},
    {"SM2_GY", "SM2 基点 Gy"},
    {"ENTL_ID", "默认用户标识符"}
}

local config_found = 0
for _, config_info in ipairs(config_items) do
    local config_name, config_desc = config_info[1], config_info[2]
    local config_value = ulc_module.get_config and ulc_module.get_config(config_name)
    if config_value then
        print("  ✅ " .. config_desc .. " (" .. config_name .. "): " .. tostring(config_value):sub(1, 20) .. "...")
        config_found = config_found + 1
    else
        print("  ❌ " .. config_desc .. " (" .. config_name .. ") 未找到")
    end
end

print("")

-- 总结
print("📊 集成验证总结:")
print("  SM2 函数: " .. functions_found .. "/" .. #sm2_functions .. " 个")
print("  配置项: " .. config_found .. "/" .. #config_items .. " 个")

if functions_found == #sm2_functions and config_found == #config_items then
    print("🎉 SM2 功能集成验证通过！")
    print("💡 可以使用以下命令进行完整测试:")
    print("   lua test_ulc_update.lua sm2")
else
    print("⚠️  SM2 功能集成可能存在问题，请检查上述错误信息")
end

print("")
print("=== 验证完成 ===")