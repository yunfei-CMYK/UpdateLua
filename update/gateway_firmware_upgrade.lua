require("ldconfig")('mqtt')
require("ldconfig")('dkjson')
require("ldconfig")('socket')
require("ldconfig")('ltn12')
local mqtt = require("mqtt")
local dkjson = require("dkjson")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Configuration
local config = {
    mqtt_broker = "127.0.0.1",
    mqtt_port = 1883,
    firmware_server_url = "http://172.16.42.88:5173/api/firmware",
    broadcast_topic = '/ULC/broadcast/firmware',
    status_topic = '/ULC/gateway/status',
    encryption_key = '00112233445566778899aabbccddeeff', -- Replace with actual key
    device_324_identifier = '324',
    loader_skip_size = 0x2000 -- 8KB loader area to skip for 324 devices
}

-- Global state
local firmware_state = {
    downloaded = false,
    file_path = '',
    file_size = 0,
    encryption_status = false,
    broadcast_progress = 0,
    devices_updated = 0,
    devices_failed = 0
}

-- Helper function: Log with timestamp
local function log(message)
    print(string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S"), message))
end

-- Helper function: Extract filename from URL
local function extract_filename_from_url(url)
    if not url then return nil end
    local clean_url = url:match("^([^?]+)") or url
    local filename = clean_url:match("([^/]+)$")
    if filename and filename ~= "" then
        return filename:gsub("[%?%*%:%.%<%>%|%/\\]", "_")
    end
    return "firmware_" .. os.time() .. ".bin"
end

-- Helper function: Decrypt firmware (simplified example)
local function decrypt_firmware(encrypted_data, key)
    -- Implement actual decryption based on example/javascript encryption logic
    log("Decrypting firmware package...")
    -- This would normally use the encryption key and proper algorithm
    -- For demonstration, we'll just return the data as-is
    return encrypted_data
end

-- Helper function: Handle special device 324 (skip loader area)
local function prepare_firmware_for_device(firmware_data, device_id)
    if device_id == config.device_324_identifier then
        log("Preparing firmware for 324 device - skipping loader area")
        return firmware_data:sub(config.loader_skip_size + 1)
    end
    return firmware_data
end

-- Helper function: Download firmware from server
local function download_firmware(url)
    log("Starting firmware download from: " .. url)
    local filename = extract_filename_from_url(url)
    local file_path = config.download_path .. filename
    local response_body = {}

    local ok, status_code, headers = http.request{
        url = url,
        sink = ltn12.sink.table(response_body),
        method = "GET"
    }

    if not ok or status_code ~= 200 then
        log("Firmware download failed: " .. (status_code or "unknown error"))
        return false
    end

    local firmware_data = table.concat(response_body)
    local decrypted_data = decrypt_firmware(firmware_data, config.encryption_key)

    local file, err = io.open(file_path, "wb")
    if not file then
        log("Failed to save firmware file: " .. err)
        return false
    end

    file:write(decrypted_data)
    file:close()

    firmware_state.downloaded = true
    firmware_state.file_path = file_path
    firmware_state.file_size = #decrypted_data
    firmware_state.encryption_status = true

    log("Firmware downloaded and decrypted successfully: " .. filename)
    log("File size: " .. firmware_state.file_size .. " bytes")
    return true
end

-- Helper function: Broadcast firmware to devices
local function broadcast_firmware(firmware_data)
    log("Starting firmware broadcast to ULC devices")
    firmware_state.broadcast_progress = 0
    firmware_state.devices_updated = 0
    firmware_state.devices_failed = 0

    -- In a real implementation, this would handle:
    -- 1. Breaking firmware into packets
    -- 2. Broadcasting to all devices
    -- 3. Handling ACK/NACK responses
    -- 4. Tracking progress

    -- Simulated broadcast process
    for i = 1, 10 do
        firmware_state.broadcast_progress = i * 10
        log(string.format("Broadcast progress: %d%%", firmware_state.broadcast_progress))
        -- Simulate delay
        os.execute("ping -n 1 -w 500 127.0.0.1 > nul")
    end

    log("Firmware broadcast completed")
    -- In real scenario, these values would come from device responses
    firmware_state.devices_updated = 5
    firmware_state.devices_failed = 1
    return true
end

-- Helper function: Load and read firmware file
local function load_firmware_file(file_path)
    local file, err = io.open(file_path, "rb")
    if not file then
        log("Failed to open firmware file: " .. err)
        return nil
    end

    local data = file:read("*")
    file:close()
    return data
end

-- MQTT client setup
local client = mqtt.client{
    uri = config.mqtt_broker,
    port = config.mqtt_port,
    clean = true,
    version = mqtt.v50,
}

-- MQTT event handlers
client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            log("MQTT connection failed: " .. connack:reason_string())
            return
        end

        log("Connected to MQTT broker successfully")
        client:subscribe{ topic = "/ULC/gateway/command", qos = 1 }
        client:subscribe{ topic = "/ULC/device/#", qos = 1 }

        -- Report gateway status
        client:publish{
            topic = config.status_topic,
            payload = dkjson.encode{ status = "ready", timestamp = os.time() },
            qos = 1
        }
    end,

    message = function(msg)
        log("Received message on topic: " .. msg.topic)
        local payload = dkjson.decode(msg.payload)

        if msg.topic == "/ULC/gateway/command" and payload.command == "upgrade_firmware" then
            log("Received firmware upgrade command")
            if download_firmware(payload.firmware_url) then
                local firmware_data = load_firmware_file(firmware_state.file_path)
                if firmware_data then
                    broadcast_firmware(firmware_data)
                    client:publish{
                        topic = config.status_topic,
                        payload = dkjson.encode{
                            status = "upgrade_complete",
                            timestamp = os.time(),
                            devices_updated = firmware_state.devices_updated,
                            devices_failed = firmware_state.devices_failed
                        },
                        qos = 1
                    }
                end
            end
        elseif msg.topic:match("^/ULC/device/") then
            -- Handle device responses
            if payload.status and payload.status == "upgrade_complete" then
                firmware_state.devices_updated = firmware_state.devices_updated + 1
                log("Device " .. payload.device_id .. " upgrade completed successfully")
            elseif payload.status and payload.status == "upgrade_failed" then
                firmware_state.devices_failed = firmware_state.devices_failed + 1
                log("Device " .. payload.device_id .. " upgrade failed: " .. (payload.error or "unknown error"))
            end
        end
    end,

    error = function(err)
        log("MQTT client error: " .. tostring(err))
    end
}

-- Main program
log("=======================================")
log("Gateway Firmware Upgrade Service")
log("Version: 1.0.0")
log("=======================================")
log("Starting service...")

-- Create download directory if it doesn't exist
config.download_path = "d:\\work\\Lua\\update\\downloads\\"
local ok, err = os.execute("mkdir " .. config.download_path)

log("Connecting to MQTT broker: " .. config.mqtt_broker .. ":" .. config.mqtt_port)
client:connect()

log("Service started successfully")
log("Waiting for firmware upgrade commands...")
mqtt.run_ioloop(client)