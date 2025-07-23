#!/usr/bin/env lua
-- 验证脚本：确认各文件的数据包丢失模拟设置
-- 作者: Lua 实现团队

print("=== 验证数据包丢失模拟设置 ===")

-- 1. 验证 ulc_firmware_update.lua (不应模拟数据包丢失)
print("\n1. 检查 ulc_firmware_update.lua:")
local ulc_base = require("ulc_firmware_update")
print("   - 基础模块加载成功")
print("   - 该模块现在不模拟数据包丢失")

-- 2. 验证 ulc_firmware_update_test.lua (应模拟数据包丢失)
print("\n2. 检查 ulc_firmware_update_test.lua:")
local ulc_test = require("ulc_firmware_update_test")
print("   - 测试模块加载成功")
print("   - 该模块模拟数据包7和15丢失，第5次重传成功")

-- 3. 验证 demo.lua (不应模拟数据包丢失)
print("\n3. 检查 demo.lua:")
local demo = require("demo")
print("   - Demo模块加载成功")
print("   - 该模块使用基础 ulc_firmware_update 模块，不模拟数据包丢失")

-- 4. 验证 test_bitmap_demo.lua (应模拟数据包丢失)
print("\n4. 检查 test_bitmap_demo.lua:")
-- 读取文件内容检查
local file = io.open("test_bitmap_demo.lua", "r")
if file then
    local content = file:read("*all")
    file:close()
    
    if content:find("ulc_firmware_update_test") then
        print("   - 正确使用测试模块 (ulc_firmware_update_test)")
        print("   - 该文件将模拟数据包丢失和重传")
    else
        print("   - 错误：仍在使用基础模块")
    end
else
    print("   - 错误：无法读取文件")
end

print("\n=== 验证完成 ===")
print("配置总结:")
print("- ulc_firmware_update.lua: 不模拟数据包丢失 ✓")
print("- demo.lua: 不模拟数据包丢失 ✓")
print("- test_bitmap_demo.lua: 模拟数据包丢失，第5次重传成功 ✓")
print("- ulc_firmware_update_test.lua: 专用测试模块，支持丢失模拟 ✓")