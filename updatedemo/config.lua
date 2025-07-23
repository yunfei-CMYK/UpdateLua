-- ULC 固件更新配置文件
-- 此文件包含用于不同测试场景的各种配置预设
-- 作者: Longfei
-- 日期: 2024

local config_presets = {}

-- 默认 ULC Direct 324 配置
config_presets.ulc_direct_324 = {
    UPDATE_TYPE_FLAG = 0,      -- ULC direct 324
    COMM_TYPE = 1,             -- ULC 通信
    DEVICE_ID = 2,             -- 目标设备 ID
    PACKET_SIZE = 256,         -- 数据包大小
    LOADER_SIZE = 0x2000,      -- 8KB 加载器大小
    
    -- 描述
    name = "ULC Direct 324",
    description = "标准 ULC direct 324 固件更新",
    
    -- 测试参数
    test_firmware_size = 65536,  -- 64KB
    expected_duration = 30,      -- 秒
    
    -- SM2 公钥 (生产环境)
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3"
}

-- BLE 芯片更新配置
config_presets.ble_chip = {
    UPDATE_TYPE_FLAG = 1,      -- BLE 芯片
    COMM_TYPE = 1,             -- ULC 通信
    DEVICE_ID = 2,             -- 目标设备 ID
    PACKET_SIZE = 256,         -- 数据包大小
    LOADER_SIZE = 0x2000,      -- 8KB 加载器大小
    
    -- 描述
    name = "BLE Chip Update",
    description = "通过 ULC 的 BLE 芯片固件更新",
    
    -- 测试参数
    test_firmware_size = 131072, -- 128KB
    expected_duration = 45,      -- 秒
    
    -- SM2 公钥 (与 ULC 相同)
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3"
}

-- 扩展 324 配置
config_presets.extended_324 = {
    UPDATE_TYPE_FLAG = 2,      -- 扩展 324
    COMM_TYPE = 1,             -- ULC 通信
    DEVICE_ID = 2,             -- 目标设备 ID
    PACKET_SIZE = 512,         -- 扩展模式下更大的数据包大小
    LOADER_SIZE = 0x2000,      -- 8KB 加载器大小
    
    -- 描述
    name = "Extended 324",
    description = "扩展 324 固件更新",
    
    -- 测试参数
    test_firmware_size = 262144, -- 256KB
    expected_duration = 60,      -- 秒
    
    -- SM2 公钥 (与 ULC 相同)
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3"
}

-- USB 通信配置
config_presets.usb_comm = {
    UPDATE_TYPE_FLAG = 0,      -- ULC direct 324
    COMM_TYPE = 0,             -- USB 通信
    DEVICE_ID = 1,             -- USB 的不同设备 ID
    PACKET_SIZE = 1024,        -- USB 的更大数据包
    LOADER_SIZE = 0x2000,      -- 8KB 加载器大小
    
    -- 描述
    name = "USB Communication",
    description = "通过 USB 的 ULC 固件更新",
    
    -- 测试参数
    test_firmware_size = 65536,  -- 64KB
    expected_duration = 20,      -- 通过 USB 更快
    
    -- SM2 公钥 (与 ULC 相同)
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0",
    PUB_KEY_D = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3"
}

-- 开发/测试配置
config_presets.development = {
    UPDATE_TYPE_FLAG = 0,      -- ULC direct 324
    COMM_TYPE = 1,             -- ULC 通信
    DEVICE_ID = 2,             -- 目标设备 ID
    PACKET_SIZE = 128,         -- 用于测试的较小数据包
    LOADER_SIZE = 0x1000,      -- 用于测试的 4KB 加载器
    
    -- 描述
    name = "Development",
    description = "开发和测试配置",
    
    -- 测试参数
    test_firmware_size = 8192,   -- 用于快速测试的 8KB
    expected_duration = 10,      -- 快速测试
    
    -- SM2 公钥 (测试密钥)
    PUB_KEY_X = "1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF",
    PUB_KEY_Y = "FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321",
    PUB_KEY_D = "ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890"
}

-- 配置管理函数
local config_manager = {}

-- 应用配置预设
function config_manager.apply_preset(ulc_module, preset_name)
    local preset = config_presets[preset_name]
    if not preset then
        error("未知的配置预设: " .. preset_name)
    end
    
    print("应用配置预设: " .. preset.name)
    print("描述: " .. preset.description)
    
    -- 应用配置
    for key, value in pairs(preset) do
        if key ~= "name" and key ~= "description" and key ~= "test_firmware_size" and key ~= "expected_duration" then
            ulc_module.config[key] = value
        end
    end
    
    print("配置应用成功！")
    return preset
end

-- 列出可用预设
function config_manager.list_presets()
    print("可用的配置预设:")
    print("================================")
    for name, preset in pairs(config_presets) do
        print(string.format("%-15s - %s", name, preset.description))
    end
end

-- 获取预设信息
function config_manager.get_preset_info(preset_name)
    local preset = config_presets[preset_name]
    if not preset then
        return nil, "未知预设: " .. preset_name
    end
    
    return preset, nil
end

-- 验证配置
function config_manager.validate_config(config)
    local errors = {}
    
    -- 检查必填字段
    local required_fields = {
        "UPDATE_TYPE_FLAG", "COMM_TYPE", "DEVICE_ID", 
        "PACKET_SIZE", "LOADER_SIZE", "PUB_KEY_X", "PUB_KEY_Y"
    }
    
    for _, field in ipairs(required_fields) do
        if config[field] == nil then
            table.insert(errors, "缺少必填字段: " .. field)
        end
    end
    
    -- 验证范围
    if config.UPDATE_TYPE_FLAG and (config.UPDATE_TYPE_FLAG < 0 or config.UPDATE_TYPE_FLAG > 2) then
        table.insert(errors, "UPDATE_TYPE_FLAG 必须为 0、1 或 2")
    end
    
    if config.COMM_TYPE and (config.COMM_TYPE < 0 or config.COMM_TYPE > 1) then
        table.insert(errors, "COMM_TYPE 必须为 0 或 1")
    end
    
    if config.PACKET_SIZE and (config.PACKET_SIZE < 64 or config.PACKET_SIZE > 2048) then
        table.insert(errors, "PACKET_SIZE 应该在 64 到 2048 之间")
    end
    
    -- 验证十六进制字符串
    if config.PUB_KEY_X and #config.PUB_KEY_X ~= 64 then
        table.insert(errors, "PUB_KEY_X 必须为 64 个十六进制字符")
    end
    
    if config.PUB_KEY_Y and #config.PUB_KEY_Y ~= 64 then
        table.insert(errors, "PUB_KEY_Y 必须为 64 个十六进制字符")
    end
    
    return #errors == 0, errors
end

-- 创建自定义配置
function config_manager.create_custom_config(base_preset, overrides)
    local base = config_presets[base_preset]
    if not base then
        error("未知的基础预设: " .. base_preset)
    end
    
    local custom = {}
    
    -- 复制基础配置
    for key, value in pairs(base) do
        custom[key] = value
    end
    
    -- 应用覆盖
    for key, value in pairs(overrides) do
        custom[key] = value
    end
    
    -- 验证自定义配置
    local valid, errors = config_manager.validate_config(custom)
    if not valid then
        error("无效的自定义配置: " .. table.concat(errors, ", "))
    end
    
    return custom
end

-- 导出配置预设和管理器
return {
    presets = config_presets,
    manager = config_manager,
    
    -- 便捷函数
    apply = config_manager.apply_preset,
    list = config_manager.list_presets,
    info = config_manager.get_preset_info,
    validate = config_manager.validate_config,
    custom = config_manager.create_custom_config
}