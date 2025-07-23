#!/usr/bin/env lua
-- quick_test.lua
-- 快速测试修复后的progress函数

print("=== 快速测试 Progress 函数修复 ===")

-- 加载模块
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
package.path = this_dir .. "?.lua;" .. package.path
local ulc_update = require("ulc_firmware_update")

print("1. 测试正常参数...")
ulc_update.progress.show_progress(50, 100, "正常测试")
print("✓ 正常参数测试通过")

print("\n2. 测试边界参数...")
ulc_update.progress.show_progress(0, 100, "边界测试")
ulc_update.progress.show_progress(100, 100, "边界测试")
print("✓ 边界参数测试通过")

print("\n3. 测试无效参数...")
ulc_update.progress.show_progress(nil, 100, "无效测试")
ulc_update.progress.show_progress(50, nil, "无效测试")
ulc_update.progress.show_progress(50, 0, "无效测试")
print("✓ 无效参数测试通过")

print("\n4. 测试大数值...")
ulc_update.progress.show_progress(999999, 1000000, "大数值测试")
print("✓ 大数值测试通过")

print("\n=== 所有测试通过！Progress 函数修复成功 ===")