-- Test script for firmware download progress bar
-- This script demonstrates the progress bar functionality with error handling

-- Helper function: Display progress bar (same as in test.lua)
local function display_progress_bar(current, total, width)
    width = width or 50
    
    -- Ensure current and total are valid numbers and convert to integers
    current = math.floor(tonumber(current) or 0)
    total = math.floor(tonumber(total) or 1)
    
    -- Prevent division by zero
    if total <= 0 then total = 1 end
    if current > total then current = total end
    if current < 0 then current = 0 end
    
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "]"
    local progress_text = string.format("%s %3d%% (%d/%d bytes)", bar, percentage, current, total)
    
    -- Use carriage return to overwrite the same line
    io.write("\r" .. progress_text)
    io.flush()
end

-- Helper function: Simulate download progress (same as in test.lua)
local function simulate_download_progress(total_size, duration_ms)
    duration_ms = duration_ms or 2000  -- Default 2 seconds
    local steps = 20
    
    -- Ensure total_size is a valid integer
    total_size = math.floor(tonumber(total_size) or 0)
    if total_size <= 0 then
        print("ERROR: Invalid file size for progress simulation")
        return
    end
    
    local step_size = total_size / steps
    local step_delay = duration_ms / steps / 1000  -- Convert to seconds
    
    print("Download progress:")
    
    for i = 0, steps do
        local current_size = math.floor(math.min(i * step_size, total_size))
        display_progress_bar(current_size, total_size)
        
        if i < steps then
            -- Simple delay simulation
            local start_time = os.clock()
            while os.clock() - start_time < step_delay do
                -- Busy wait
            end
        end
    end
    
    print("")  -- New line after progress bar completion
end

-- Test the progress bar with different file sizes
print("=== Firmware Download Progress Bar Test ===")
print("")

print("Test 1: Small firmware file (1006 bytes - same as your error)")
simulate_download_progress(1006, 1500)
print("Download completed!")
print("")

print("Test 2: Medium firmware file (100 KB)")
simulate_download_progress(102400, 2500)
print("Download completed!")
print("")

print("Test 3: Large firmware file (1 MB)")
simulate_download_progress(1048576, 4000)
print("Download completed!")
print("")

print("Test 4: Edge case - Very small file (1 byte)")
simulate_download_progress(1, 500)
print("Download completed!")
print("")

print("Test 5: Edge case - Zero size (should show error)")
simulate_download_progress(0, 1000)
print("")

print("=== All tests completed ===")