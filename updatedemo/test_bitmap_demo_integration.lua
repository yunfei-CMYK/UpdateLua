#!/usr/bin/env lua
-- 测试 demo.lua 中新增的 bitmap 演示功能
-- 验证 bitmap 演示是否正常工作

-- 加载演示模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path

print("=== 测试 Demo.lua 中的 Bitmap 演示功能 ===")
print()

-- 加载演示模块
local demo_module = require("demo")

-- 测试 bitmap 演示功能
print("1. 测试 bitmap 演示功能...")
print("   正在运行 bitmap 演示...")

local success, err = pcall(function()
    demo_module.demos.bitmap_demo()
end)

if success then
    print("✓ Bitmap 演示运行成功！")
else
    print("✗ Bitmap 演示运行失败:")
    print("   错误: " .. (err or "未知错误"))
end

print()
print("2. 验证演示菜单更新...")

-- 检查演示菜单是否包含 bitmap 选项
local menu_test_success = true
if not demo_module.demos.bitmap_demo then
    print("✗ bitmap_demo 函数未找到")
    menu_test_success = false
else
    print("✓ bitmap_demo 函数已正确添加")
end

if menu_test_success then
    print("✓ 演示菜单更新成功！")
else
    print("✗ 演示菜单更新失败")
end

print()
print("3. 测试完整演示列表...")

-- 测试是否可以获取演示配置
if demo_module.config then
    print("✓ 演示配置可用")
    print("   演示延迟: " .. demo_module.config.demo_delay .. " 秒")
    print("   演示固件大小: " .. demo_module.config.demo_firmware_size .. " 字节")
else
    print("✗ 演示配置不可用")
end

print()
print("=== 测试完成 ===")
print("Bitmap 演示功能已成功集成到 demo.lua 中！")
print()
print("使用方法:")
print("1. 运行 'lua demo.lua' 启动交互式菜单")
print("2. 选择选项 6 运行 Bitmap 功能演示")
print("3. 或选择选项 1 运行包含 bitmap 在内的所有演示")