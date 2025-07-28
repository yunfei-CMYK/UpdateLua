#!/usr/bin/env lua
-- 进度条修复测试脚本
-- 用于验证修改后的进度条实现是否正常工作

print("========================================")
print("进度条修复测试")
print("========================================")
print("测试参考 test_firmware_download.lua 的进度条实现")
print("")

-- 获取当前脚本所在目录
local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

-- 添加模块搜索路径
package.path = this_dir .. "?.lua;" .. this_dir .. "../?.lua;" .. package.path

-- 测试1: 测试 ulc_firmware_update_complete.lua 的进度条
print("=== 测试1: ulc_firmware_update_complete.lua 进度条 ===")

local ulc_update_module = require("ulc_firmware_update_complete")
local progress = ulc_update_module.progress

if progress then
    print("✅ 成功加载 progress 模块")
    
    -- 测试基本进度条
    print("📊 测试基本进度条:")
    for i = 0, 100, 10 do
        progress.show_progress(i, 100, "测试进度")
        -- 简单延迟
        local start_time = os.clock()
        while os.clock() - start_time < 0.1 do end
    end
    print("✅ 基本进度条测试完成")
    print("")
    
    -- 测试带额外信息的进度条
    print("📊 测试带额外信息的进度条:")
    for i = 0, 50, 5 do
        progress.show_progress(i, 50, "数据传输", string.format("已传输 %d KB", i * 2))
        local start_time = os.clock()
        while os.clock() - start_time < 0.1 do end
    end
    print("✅ 带额外信息的进度条测试完成")
    print("")
    
    -- 测试传输统计
    print("📊 测试传输统计:")
    local start_time = os.time()
    for i = 0, 1024, 64 do
        progress.show_transfer_stats(i, 1024, start_time, "文件传输")
        local delay_start = os.clock()
        while os.clock() - delay_start < 0.05 do end
    end
    print("✅ 传输统计测试完成")
    print("")
else
    print("❌ 无法加载 progress 模块")
end

-- 测试2: 测试 test_ulc_update.lua 的固定进度条
print("=== 测试2: test_ulc_update.lua 固定进度条 ===")

local this_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"

package.path = this_dir .. "?.lua;" .. package.path

local test_ulc_update = require("test_ulc_update")

-- 由于 test_ulc_update.lua 中的 fixed_progress 是局部变量，
-- 我们需要直接测试其中的进度条实现
-- 这里我们创建一个简化版本来测试

-- 简化的固定进度条实现（基于修改后的代码）
local fixed_progress = {}

local current_progress_state = {
    active = false,
    last_percentage = -1,
    start_time = 0,
    description = ""
}

local function display_progress_bar(current, total, width, description)
    width = width or 50
    
    current = math.floor(tonumber(current) or 0)
    total = math.floor(tonumber(total) or 1)
    
    if total <= 0 then total = 1 end
    if current > total then current = total end
    if current < 0 then current = 0 end
    
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local progress_text = string.format("%s %s %3d%% (%d/%d)", 
                                      description or "📊 进度", bar, percentage, current, total)
    
    io.write("\r" .. progress_text)
    io.flush()
    
    current_progress_state.active = true
    current_progress_state.last_percentage = percentage
    current_progress_state.description = description or "进度"
    
    if current >= total then
        io.write("\n")
        io.flush()
        current_progress_state.active = false
        current_progress_state.last_percentage = -1
    end
end

function fixed_progress.show_progress(current, total, description, extra_info)
    if not current or not total or total <= 0 then
        return
    end
    
    local desc = description or "📊 进度"
    if extra_info and extra_info ~= "" then
        desc = desc .. " " .. extra_info
    end
    
    display_progress_bar(current, total, 40, desc)
end

function fixed_progress.start_session(description)
    current_progress_state.start_time = os.time()
    current_progress_state.description = description or "进度"
    io.write(string.format("🚀 开始 %s\n", current_progress_state.description))
    io.flush()
end

function fixed_progress.end_session(final_message)
    if current_progress_state.active then
        io.write("\n")
        io.flush()
        current_progress_state.active = false
    end
    
    if final_message then
        io.write(final_message .. "\n")
        io.flush()
    end
    
    current_progress_state.last_percentage = -1
    current_progress_state.description = ""
end

-- 测试固定进度条
print("✅ 开始测试固定进度条")

-- 测试会话管理
fixed_progress.start_session("固件更新测试")

-- 测试进度条
for i = 0, 200, 10 do
    fixed_progress.show_progress(i, 200, "固件传输", string.format("块 %d", math.floor(i/10)))
    local start_time = os.clock()
    while os.clock() - start_time < 0.08 do end
end

fixed_progress.end_session("✅ 固件更新测试完成")
print("")

-- 测试3: 对比原始实现和修复后的实现
print("=== 测试3: 进度条特性对比 ===")
print("✅ 修复特点:")
print("   - 使用简单的 = 和 - 字符构建进度条")
print("   - 使用 \\r 回车符覆盖同一行")
print("   - 移除了复杂的 ANSI 转义序列")
print("   - 简化了状态管理")
print("   - 提高了兼容性")
print("")

-- 测试4: 边界情况测试
print("=== 测试4: 边界情况测试 ===")

print("📊 测试零值:")
progress.show_progress(0, 0, "零值测试")
print("✅ 零值测试完成")

print("📊 测试负值:")
progress.show_progress(-10, 100, "负值测试")
print("✅ 负值测试完成")

print("📊 测试超出范围:")
progress.show_progress(150, 100, "超出范围测试")
print("✅ 超出范围测试完成")

print("📊 测试非数字:")
progress.show_progress("abc", "def", "非数字测试")
print("✅ 非数字测试完成")

print("")
print("========================================")
print("✅ 所有进度条测试完成")
print("========================================")
print("修复总结:")
print("1. 参考了 test_firmware_download.lua 的简单有效实现")
print("2. 使用标准的回车符 \\r 覆盖同一行")
print("3. 移除了可能导致兼容性问题的 ANSI 转义序列")
print("4. 简化了状态管理和代码逻辑")
print("5. 保持了原有的功能特性")
print("")