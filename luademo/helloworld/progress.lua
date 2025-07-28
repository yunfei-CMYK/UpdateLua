local function display_progress_bar(current, total, width)
    width = width or 50

    current = math.floor(tonumber(current) or 0)
    total = math.floor(tonumber(total) or 1)

    if total <=0 then total =1 end
    if current > total then current = total end
    if current < 0 then current = 0 end

    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local empty = width - filled

    local bar = "[" .. string.rep("=", filled) .. string.rep("-",empty) .. "]"
    local progress_text = string.format("%s %3d%% (%d/%d bytes)", bar, percentage, current, total)
    io.write("\r" .. progress_text)
    io.flush()
end