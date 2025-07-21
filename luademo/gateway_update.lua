require("ldconfig")('mqtt')
require("ldconfig")('dkjson') -- Ensure dkjson is loaded for JSON handling
require("ldconfig")('socket')
local mqtt = require("mqtt")
local dkjson = require("dkjson")
local http = require("socket.http")  -- Use the local http.lua module

-- Script startup information
print("========================================")
print("MQTT Firmware Download Client Starting")
print("========================================")
print("Version: 1.0.0")
print("Description: MQTT client for firmware download and management")
print("Author: Lua MQTT Client")
print("Start time: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("Working directory: " .. (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")))
print("Broker: 127.0.0.1:1883")
print("Protocol: MQTT v5.0")
print("========================================")
print("Initializing MQTT client...")
print("")

-- Define multiple firmware-related topics
local firmware_topics = {
    "/{productId}/{deviceId}/firmware/upgrade",
    "/{productId}/{deviceId}/firmware/upgrade/reply",
    "/{productId}/{deviceId}/firmware/upgrade/progress",
    "/{productId}/{deviceId}/firmware/pull",
    "/{productId}/{deviceId}/firmware/pull/reply",
    "/{productId}/{deviceId}/firmware/report",
    "/{productId}/{deviceId}/firmware/read",
    "/{productId}/{deviceId}/firmware/read/reply"
}

-- Helper function: Safe JSON parsing using dkjson
local function safe_json_parse(json_str)
    if not json_str or json_str == "" then
        return false, "Empty JSON string"
    end
    
    local data, pos, err = dkjson.decode(json_str, 1, nil)
    
    if data then
        return true, data
    else
        return false, err or "Unknown parsing error"
    end
end

-- Helper function: Extract filename from URL
local function extract_filename_from_url(url)
    if not url then return nil end
    
    -- Extract filename from URL path
    local filename = url:match("([^/]+)$")
    if filename and filename ~= "" then
        return filename
    end
    
    -- Fallback: generate filename based on timestamp
    return "firmware_" .. os.time() .. ".bin"
end

-- Helper function: Get script directory
local function get_script_directory()
    local script_path = debug.getinfo(1, "S").source:sub(2)
    return script_path:match("(.*[/\\])")
end

-- Helper function: Display progress bar
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

-- Helper function: Simulate download progress (since http.request doesn't support progress callback)
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
            -- Simple delay simulation (not perfect but works for demonstration)
            local start_time = os.clock()
            while os.clock() - start_time < step_delay do
                -- Busy wait
            end
        end
    end
    
    print("")  -- New line after progress bar completion
end

-- Helper function: Download firmware from URL
local function download_firmware(url)
    if not url or url == "" then
        print("ERROR: Firmware URL is empty")
        return false, "URL is empty"
    end
    
    print("Starting firmware download...")
    print("Download URL: " .. url)
    
    -- Extract filename from URL
    local filename = extract_filename_from_url(url)
    local script_dir = get_script_directory()
    local file_path = script_dir .. filename
    
    print("Save path: " .. file_path)
    print("")
    
    -- Show initial progress
    print("Connecting to server...")
    
    -- Perform HTTP GET request using the correct http.request method
    local response_body, status_code, response_headers, status_line = http.request(url)
    
    if not response_body then
        print("HTTP request failed: " .. tostring(status_code))
        return false, "HTTP request failed: " .. tostring(status_code)
    end
    
    if status_code ~= 200 then
        print("HTTP response error: " .. tostring(status_code))
        return false, "HTTP response error: " .. tostring(status_code)
    end
    
    -- Get file size for progress simulation
    local file_size = #response_body
    
    print("Connected successfully!")
    print("File size: " .. string.format("%.2f KB", file_size / 1024))
    print("")
    
    -- Simulate download progress based on file size
    local progress_duration = math.max(1000, math.min(5000, file_size / 100))  -- 1-5 seconds based on size
    simulate_download_progress(file_size, progress_duration)
    
    -- Save firmware to file
    print("Saving file to disk...")
    local file, file_err = io.open(file_path, "wb")
    if not file then
        print("File creation failed: " .. tostring(file_err))
        return false, "File creation failed: " .. tostring(file_err)
    end
    
    file:write(response_body)
    file:close()
    
    print("Firmware download completed successfully!")
    print("")
    print("Download summary:")
    print("   - Filename: " .. filename)
    print("   - File size: " .. string.format("%.2f KB (%.0f bytes)", file_size / 1024, file_size))
    print("   - Save location: " .. file_path)
    print("   - Status: Ready for deployment")
    
    return true, {
        filename = filename,
        file_path = file_path,
        file_size = file_size,
        url = url
    }
end

-- Helper function: Handle different types of messages (simplified)
local function handle_firmware_message(topic, payload)
    print("\n" .. string.rep("=", 50))
    print("Message received - Topic: " .. tostring(topic))
    
    -- Try to parse JSON using dkjson
    local ok, data = safe_json_parse(payload)
    
    if ok and type(data) == "table" then
        print("JSON parsing successful")
        print("Message content:")
        print(string.rep("-", 20))
        
        -- Check for firmware URL in the message
        local firmware_url = nil
        
        -- Display the parsed JSON data and look for firmware URL
        for key, value in pairs(data) do
            if type(value) == "table" then
                print(key .. ": [table]")
            else
                print(key .. ": " .. tostring(value))
                
                -- Check for firmware URL fields
                if key == "firmware_url" or key == "url" or key == "download_url" then
                    firmware_url = tostring(value)
                end
            end
        end
        print(string.rep("-", 20))
        
        -- If firmware URL is found, attempt to download
        if firmware_url then
            print("Detected firmware download URL: " .. firmware_url)
            print(string.rep("*", 30))
            
            local success, result = download_firmware(firmware_url)
            
            if success then
                print("Firmware download process completed!")
                print("Download details:")
                print("   - Filename: " .. result.filename)
                print("   - File size: " .. string.format("%.2f KB", result.file_size / 1024))
                print("   - Save path: " .. result.file_path)
            else
                print("Firmware download failed: " .. tostring(result))
            end
            print(string.rep("*", 30))
        end
        
    else
        if not ok then
            print("JSON parsing failed: " .. tostring(data))
        else
            print("Message is not a valid JSON object")
        end
        print("Raw payload: " .. tostring(payload))
    end
    print(string.rep("=", 50) .. "\n")
end

-- create mqtt client
local client = mqtt.client{
    uri = "127.0.0.1",
    username = nil,
    clean = true,
    version = mqtt.v50,
}

client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            print("ERROR: Failed to connect to broker - " .. connack:reason_string())
            return
        end

        print("SUCCESS: Connected to MQTT broker")
        print("Connection details:")
        print("   - Broker: 127.0.0.1:1883")
        print("   - Protocol: MQTT v5.0")
        print("   - Clean session: true")
        print("")
        print("Subscribing to firmware topics...")

        -- Subscribe to all firmware-related topics
        local subscription_count = 0
        for i, topic in ipairs(firmware_topics) do
            assert(client:subscribe{ 
                topic = topic, 
                qos = 1, 
                callback = function(suback)
                    subscription_count = subscription_count + 1
                    print("   - Subscribed to: " .. topic)
                    
                    -- Print completion message when all subscriptions are done
                    if subscription_count == #firmware_topics then
                        print("")
                        print("All firmware topics subscribed successfully!")
                        print("Total subscriptions: " .. subscription_count)
                        print("Client is ready to receive firmware messages...")
                        print("========================================")
                        print("")
                    end
                end
            })
        end
    end,

    message = function(msg)
        assert(client:acknowledge(msg))
        
        -- Use simplified message handling function
        handle_firmware_message(msg.topic, msg.payload)
    end,

    error = function(err)
        print("ERROR: MQTT client error - " .. tostring(err))
        print("Attempting to reconnect...")
    end,
}

print("Starting MQTT client event loop...")
print("Press Ctrl+C to stop the client")
print("")

mqtt.run_ioloop(client)
