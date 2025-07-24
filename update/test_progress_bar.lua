#!/usr/bin/env lua
-- 测试固定进度条显示效果

-- 模拟进度条状态
local progress_state = {
    active = false,
    last_line = "",
    last_percentage = -1
}

-- 清除当前行
local function clear_progress_line()
    if progress_state.active then
        io.write("\r\27[K")  -- 回到行首并清除整行
        io.flush()
    end
end

-- 显示进度条
local function show_progress(current, total, description, extra_info)
    if not current or not total or total <= 0 then
        return
    end
    
    local percentage = math.floor((current * 100) / total)
    local bar_width = 40
    local filled = math.floor((current * bar_width) / total)
    local empty = bar_width - filled
    
    filled = math.max(0, math.min(bar_width, filled))
    empty = math.max(0, bar_width - filled)
    
    local bar = "[" .. string.rep("█", filled) .. string.rep("░", empty) .. "]"
    local progress_text = string.format("%s %s %3d%% (%d/%d)", 
                                      description or "📊 进度", bar, percentage, current, total)
    
    if extra_info and extra_info ~= "" then
        progress_text = progress_text .. " " .. extra_info
    end
    
    -- 如果百分比没有变化且没有额外信息，不重复显示
    if progress_state.active and percentage == progress_state.last_percentage and not extra_info then
        return
    end
    
    -- 清除之前的进度条
    clear_progress_line()
    
    -- 显示新的进度条（不换行）
    io.write(progress_text)
    io.flush()
    
    -- 更新状态
    progress_state.active = true
    progress_state.last_line = progress_text
    progress_state.last_percentage = percentage
    
    -- 如果完成，换行并重置状态
    if current >= total then
        io.write("\n")
        io.flush()
        progress_state.active = false
        progress_state.last_line = ""
        progress_state.last_percentage = -1
    end
end

-- 显示传输统计
local function show_transfer_stats(transferred, total, start_time, description)
    local elapsed = os.time() - start_time
    local speed = elapsed > 0 and (transferred / elapsed) or 0
    local eta = speed > 0 and ((total - transferred) / speed) or 0
    
    local stats = string.format(" | 速度: %.1f KB/s | 剩余: %ds", 
                               speed / 1024, math.floor(eta))
    
    show_progress(transferred, total, (description or "传输") .. stats)
end

-- 测试函数
local function test_fixed_progress()
    print("=== 🧪 测试固定进度条显示效果 ===")
    print("测试1: 基本进度条")
    
    -- 测试基本进度条
    for i = 1, 100 do
        show_progress(i, 100, "📤 传输")
        -- 模拟处理时间
        os.execute("ping -n 1 127.0.0.1 > nul 2>&1")  -- Windows下的延迟
    end
    
    print("\n测试2: 带速度统计的进度条")
    local start_time = os.time()
    
    for i = 1, 50 do
        show_transfer_stats(i * 1024, 50 * 1024, start_time, "📤 传输")
        os.execute("ping -n 1 127.0.0.1 > nul 2>&1")
    end
    
    print("\n测试3: 重传进度条")
    
    for i = 1, 20 do
        local extra_info = string.format("重传 %d/20 (丢失率: %.1f%%)", i, (20-i)*5)
        show_progress(i, 20, "🔄 重传进度", extra_info)
        os.execute("ping -n 1 127.0.0.1 > nul 2>&1")
    end
    
    print("\n✅ 测试完成！")
end

-- 运行测试
test_fixed_progress()