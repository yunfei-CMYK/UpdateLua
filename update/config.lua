-- ULC 固件更新配置文件
-- 用于配置不同环境和场景下的固件更新参数

local config = {}

-- 基础配置
config.base = {
    -- 更新类型标志
    UPDATE_TYPE_FLAG = 0,  -- 0: ULC 直接 324, 1: BLE 芯片, 2: 扩展 324
    COMM_TYPE = 1,         -- 0: USB 通信, 1: ULC 通信
    DEVICE_ID = 2,         -- 使用 ULC 通信时的目标设备 ID
    PACKET_SIZE = 256,     -- 固件传输的数据包大小
    LOADER_SIZE = 0x2000,  -- 加载器大小 (8KB)
    
    -- 用于固件更新验证的 SM2 公钥
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3",
    
    -- SM2 曲线参数
    ENTL_ID = "31323334353637383132333435363738",
    SM2_A = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC",
    SM2_B = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93",
    SM2_GX = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7",
    SM2_GY = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0",
    
    -- 重试配置
    MAX_RETRIES = 5,       -- 最大重试次数
    RETRY_DELAY = 0.1,     -- 重试延迟（秒）
}

-- 生产环境配置
config.production = {
    TEST_MODE = false,         -- 禁用测试模式
    SIMULATE_ERRORS = false,   -- 禁用错误模拟
    ERROR_RATE = 0,           -- 错误率为0
    VERBOSE_OUTPUT = false,    -- 禁用详细输出
    PACKET_SIZE = 256,        -- 标准数据包大小
    MAX_RETRIES = 3,          -- 生产环境减少重试次数
    
    -- 生产环境固件路径
    FIRMWARE_PATHS = {
        [0] = "firmware/production/DBCos324.bin",
        [1] = "firmware/production/TDR_Ble_Slave.bin",
        [2] = "firmware/production/DBCos324_LoopExtend.bin"
    }
}

-- 测试环境配置
config.testing = {
    TEST_MODE = true,          -- 启用测试模式
    SIMULATE_ERRORS = true,    -- 启用错误模拟
    ERROR_RATE = 0.05,        -- 5%错误率
    VERBOSE_OUTPUT = true,     -- 启用详细输出
    PACKET_SIZE = 256,        -- 标准数据包大小
    MAX_RETRIES = 5,          -- 测试环境允许更多重试
    
    -- 固件路径配置（相对于update目录）
    FIRMWARE_PATHS = {
        [0] = "test_firmware/DBCos324.bin",
        [1] = "test_firmware/TDR_Ble_Slave_V1.0.25.bin",
        [2] = "test_firmware/DBCos324_LoopExtend.bin"
    }
}

-- 开发环境配置
config.development = {
    TEST_MODE = true,          -- 启用测试模式
    SIMULATE_ERRORS = false,   -- 禁用错误模拟（开发时减少干扰）
    ERROR_RATE = 0,           -- 错误率为0
    VERBOSE_OUTPUT = true,     -- 启用详细输出
    PACKET_SIZE = 128,        -- 较小的数据包便于调试
    MAX_RETRIES = 10,         -- 开发环境允许更多重试
    
    -- 开发环境固件路径
    FIRMWARE_PATHS = {
        [0] = "dev_firmware/DBCos324_dev.bin",
        [1] = "dev_firmware/TDR_Ble_Slave_dev.bin",
        [2] = "dev_firmware/DBCos324_LoopExtend_dev.bin"
    }
}

-- 性能测试配置
config.performance = {
    TEST_MODE = true,          -- 启用测试模式
    SIMULATE_ERRORS = false,   -- 禁用错误模拟以获得最佳性能
    ERROR_RATE = 0,           -- 错误率为0
    VERBOSE_OUTPUT = false,    -- 禁用详细输出以减少I/O开销
    PACKET_SIZE = 1024,       -- 使用更大的数据包提高传输效率
    MAX_RETRIES = 1,          -- 减少重试次数
    
    -- 性能测试固件路径
    FIRMWARE_PATHS = {
        [0] = "perf_firmware/DBCos324_large.bin",
        [1] = "perf_firmware/TDR_Ble_Slave_large.bin",
        [2] = "perf_firmware/DBCos324_LoopExtend_large.bin"
    }
}

-- 压力测试配置
config.stress = {
    TEST_MODE = true,          -- 启用测试模式
    SIMULATE_ERRORS = true,    -- 启用错误模拟
    ERROR_RATE = 0.2,         -- 20%高错误率
    VERBOSE_OUTPUT = true,     -- 启用详细输出以便分析
    PACKET_SIZE = 64,         -- 使用小数据包增加传输复杂度
    MAX_RETRIES = 20,         -- 允许大量重试
    
    -- 压力测试固件路径
    FIRMWARE_PATHS = {
        [0] = "stress_firmware/DBCos324_stress.bin",
        [1] = "stress_firmware/TDR_Ble_Slave_stress.bin",
        [2] = "stress_firmware/DBCos324_LoopExtend_stress.bin"
    }
}

-- 特定设备配置
config.devices = {
    -- ULC直连324设备配置
    ulc_direct_324 = {
        UPDATE_TYPE_FLAG = 0,
        COMM_TYPE = 1,
        DEVICE_ID = 2,
        PACKET_SIZE = 256,
        FIRMWARE_PATH = "firmware/ulc_direct/DBCos324.bin"
    },
    
    -- BLE芯片设备配置
    ble_chip = {
        UPDATE_TYPE_FLAG = 1,
        COMM_TYPE = 1,
        DEVICE_ID = 3,
        PACKET_SIZE = 128,  -- BLE可能需要较小的数据包
        FIRMWARE_PATH = "firmware/ble/TDR_Ble_Slave.bin"
    },
    
    -- 扩展324设备配置
    extend_324 = {
        UPDATE_TYPE_FLAG = 2,
        COMM_TYPE = 1,
        DEVICE_ID = 4,
        PACKET_SIZE = 512,  -- 扩展设备可能支持更大数据包
        FIRMWARE_PATH = "firmware/extend/DBCos324_LoopExtend.bin"
    }
}

-- 网络配置（如果需要远程固件下载）
config.network = {
    -- 固件服务器配置
    firmware_server = {
        base_url = "https://firmware.example.com/",
        api_key = "your_api_key_here",
        timeout = 30,  -- 下载超时时间（秒）
        retry_count = 3
    },
    
    -- 固件版本检查
    version_check = {
        enabled = true,
        check_url = "https://api.example.com/firmware/version",
        auto_download = false
    }
}

-- 日志配置
config.logging = {
    enabled = true,
    level = "INFO",  -- DEBUG, INFO, WARN, ERROR
    file_path = "logs/ulc_update.log",
    max_file_size = 10 * 1024 * 1024,  -- 10MB
    backup_count = 5,
    
    -- 日志格式
    format = "[%Y-%m-%d %H:%M:%S] [%level%] %message%"
}

-- 安全配置
config.security = {
    -- 签名验证
    verify_signature = true,
    signature_algorithm = "SM2",
    
    -- 加密配置
    encryption_enabled = true,
    encryption_algorithm = "SM4",
    key_exchange_algorithm = "SM2",
    
    -- 完整性检查
    integrity_check = true,
    checksum_algorithm = "CRC16"
}

-- 配置合并函数
function config.merge_configs(base_config, override_config)
    local merged = {}
    
    -- 复制基础配置
    for k, v in pairs(base_config) do
        merged[k] = v
    end
    
    -- 应用覆盖配置
    if override_config then
        for k, v in pairs(override_config) do
            merged[k] = v
        end
    end
    
    return merged
end

-- 获取指定环境的完整配置
function config.get_config(environment)
    local env_config = config[environment] or config.testing
    return config.merge_configs(config.base, env_config)
end

-- 获取设备特定配置
function config.get_device_config(device_type)
    local device_config = config.devices[device_type]
    if device_config then
        return config.merge_configs(config.base, device_config)
    else
        error("未知的设备类型: " .. tostring(device_type))
    end
end

-- 验证配置有效性
function config.validate_config(cfg)
    local required_fields = {
        "UPDATE_TYPE_FLAG", "COMM_TYPE", "PACKET_SIZE", 
        "MAX_RETRIES", "PUB_KEY_X", "PUB_KEY_Y"
    }
    
    for _, field in ipairs(required_fields) do
        if cfg[field] == nil then
            error("缺少必需的配置字段: " .. field)
        end
    end
    
    -- 验证数值范围
    if cfg.UPDATE_TYPE_FLAG < 0 or cfg.UPDATE_TYPE_FLAG > 2 then
        error("UPDATE_TYPE_FLAG 必须在 0-2 范围内")
    end
    
    if cfg.COMM_TYPE < 0 or cfg.COMM_TYPE > 1 then
        error("COMM_TYPE 必须在 0-1 范围内")
    end
    
    if cfg.PACKET_SIZE <= 0 or cfg.PACKET_SIZE > 2048 then
        error("PACKET_SIZE 必须在 1-2048 范围内")
    end
    
    if cfg.MAX_RETRIES < 0 or cfg.MAX_RETRIES > 100 then
        error("MAX_RETRIES 必须在 0-100 范围内")
    end
    
    return true
end

-- 显示配置信息
function config.print_config(cfg, title)
    title = title or "配置信息"
    print("=== " .. title .. " ===")
    
    local sorted_keys = {}
    for k in pairs(cfg) do
        if type(cfg[k]) ~= "table" and type(cfg[k]) ~= "function" then
            table.insert(sorted_keys, k)
        end
    end
    table.sort(sorted_keys)
    
    for _, k in ipairs(sorted_keys) do
        print(string.format("  %s: %s", k, tostring(cfg[k])))
    end
    print("")
end

-- 保存配置到文件
function config.save_config(cfg, file_path)
    local file = io.open(file_path, "w")
    if not file then
        error("无法创建配置文件: " .. file_path)
    end
    
    file:write("-- 自动生成的配置文件\n")
    file:write("-- 生成时间: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write("return {\n")
    
    for k, v in pairs(cfg) do
        if type(v) == "string" then
            file:write(string.format('  %s = "%s",\n', k, v))
        elseif type(v) == "number" or type(v) == "boolean" then
            file:write(string.format('  %s = %s,\n', k, tostring(v)))
        end
    end
    
    file:write("}\n")
    file:close()
    
    print("配置已保存到: " .. file_path)
end

-- 从文件加载配置
function config.load_config(file_path)
    local chunk, err = loadfile(file_path)
    if not chunk then
        error("无法加载配置文件: " .. file_path .. " (" .. (err or "未知错误") .. ")")
    end
    
    local loaded_config = chunk()
    if type(loaded_config) ~= "table" then
        error("配置文件格式错误: " .. file_path)
    end
    
    print("配置已从文件加载: " .. file_path)
    return loaded_config
end

return config