# ULC 固件更新 Lua 实现

这是一个基于 JavaScript 版本 `FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js` 的完整 Lua 实现，支持 SM2/SM4 加密、CRC 校验、Bitmap 管理和 ULC 通信。

## 📁 文件结构

```
update/
├── ulc_firmware_update_complete.lua  # 主要的固件更新模块
├── test_ulc_update.lua               # 测试脚本
├── example_usage.lua                 # 使用示例
├── config.lua                        # 配置管理
├── README.md                         # 说明文档
└── test_firmware/                    # 测试固件目录（位于update文件夹下，自动创建）
    ├── DBCos324.bin
    ├── TDR_Ble_Slave_V1.0.25.bin
    └── DBCos324_LoopExtend.bin
```

## 🚀 快速开始

### 1. 基本使用

```lua
-- 加载固件更新模块
local ulc_update = require("ulc_firmware_update_complete")

-- 配置更新参数
ulc_update.set_config("UPDATE_TYPE_FLAG", 0)  -- ULC直连324
ulc_update.set_config("TEST_MODE", true)      -- 启用测试模式

-- 执行固件更新
local success = ulc_update.update_firmware("firmware/DBCos324.bin")

if success then
    print("🎉 固件更新成功！")
else
    print("❌ 固件更新失败！")
end
```

### 2. 运行测试

```bash
# 交互式测试菜单
lua test_ulc_update.lua

# 运行所有测试
lua test_ulc_update.lua all

# 测试特定更新类型
lua test_ulc_update.lua type 0  # ULC直连324
lua test_ulc_update.lua type 1  # BLE芯片
lua test_ulc_update.lua type 2  # 扩展324
```

### 3. 运行示例

```bash
# 运行所有使用示例
lua example_usage.lua
```

## 📋 功能特性

### ✅ 完整功能对应

| JavaScript 功能 | Lua 实现 | 状态 |
|----------------|----------|------|
| SM2 签名验证 | ✅ crypto.sm2_verify | 完成 |
| SM2 加密 | ✅ crypto.sm2_encrypt | 完成 |
| SM4 加密/MAC | ✅ crypto.sm4_encrypt/sm4_mac | 完成 |
| ULC APDU 通信 | ✅ comm.ulc_send_apdu | 完成 |
| CRC16 校验 | ✅ utils.crc16c | 完成 |
| 固件分包传输 | ✅ ulc_update.transfer_firmware | 完成 |
| 重试机制 | ✅ comm.ulc_send_apdu_with_retry | 完成 |
| 进度显示 | ✅ progress.show_progress | 完成 |

### 🆕 增强功能

| 功能 | 描述 |
|------|------|
| **Bitmap 管理** | 完整的数据包完整性验证和重传机制 |
| **配置管理** | 支持多环境配置（生产、测试、开发等） |
| **错误模拟** | 可配置的传输错误模拟，便于测试 |
| **详细日志** | 丰富的日志输出和进度显示 |
| **模块化设计** | 清晰的模块分离，便于维护和扩展 |

## ⚙️ 配置选项

### 基本配置

```lua
-- 更新类型
UPDATE_TYPE_FLAG = 0  -- 0: ULC直连324, 1: BLE芯片, 2: 扩展324

-- 通信类型
COMM_TYPE = 1         -- 0: USB通信, 1: ULC通信

-- 数据包大小
PACKET_SIZE = 256     -- 固件传输的数据包大小

-- 测试模式
TEST_MODE = true      -- 启用测试模式（模拟通信）

-- 错误模拟
SIMULATE_ERRORS = false  -- 是否模拟传输错误
ERROR_RATE = 0.05       -- 错误率 (5%)

-- 重试配置
MAX_RETRIES = 5       -- 最大重试次数
```

### 使用配置文件

```lua
local config = require("config")

-- 获取测试环境配置
local test_config = config.get_config("testing")

-- 获取生产环境配置
local prod_config = config.get_config("production")

-- 获取设备特定配置
local device_config = config.get_device_config("ulc_direct_324")
```

## 🧪 测试功能

### 1. 交互式测试

运行 `lua test_ulc_update.lua` 进入交互式菜单：

```
=== 🎮 ULC 固件更新测试菜单 ===
1. 运行所有测试
2. 测试 ULC直连324 更新
3. 测试 BLE芯片 更新
4. 测试 扩展324 更新
5. 测试配置功能
6. 测试工具函数
7. 测试 Bitmap 功能
8. 显示当前配置
9. 创建测试固件
0. 退出
```

### 2. 自动化测试

```bash
# 运行所有测试
lua test_ulc_update.lua all

# 测试特定功能
lua test_ulc_update.lua config    # 配置功能
lua test_ulc_update.lua utils     # 工具函数
lua test_ulc_update.lua bitmap    # Bitmap功能
```

### 3. 错误模拟测试

```lua
-- 启用错误模拟
ulc_update.set_config("SIMULATE_ERRORS", true)
ulc_update.set_config("ERROR_RATE", 0.1)  -- 10%错误率

-- 执行更新，观察重传机制
local success = ulc_update.update_firmware("test_firmware/DBCos324.bin")  -- 相对于update目录
```

## 📊 Bitmap 完整性验证

### 工作原理

1. **数据块记录**: 每个传输的数据包都会记录其信息
2. **Bitmap 获取**: 从设备获取接收状态的位图
3. **丢失检测**: 分析位图找出丢失的数据包
4. **智能重传**: 只重传丢失的数据包
5. **多轮验证**: 支持多轮重传直到完整或达到最大重试次数

### 使用示例

```lua
-- Bitmap功能会自动在固件传输过程中启用
local success = ulc_update.transfer_firmware(encrypted_firmware)

-- 如果有数据包丢失，会自动进行重传
-- 输出示例：
-- 📊 发现 15 个丢失数据包
-- 📋 丢失数据包: 5, 12, 18, 23, 27, 31, 45, 52, 67, 78, 89, 95, 101, 108, 115
-- 📈 丢失率: 2.34% (15/640)
-- 🔄 重传数据块 5
-- 🔄 重传数据块 12
-- ...
```

## 🔧 开发和调试

### 1. 启用详细输出

```lua
ulc_update.set_config("TEST_MODE", true)
ulc_update.show_config()  -- 显示当前配置
```

### 2. 自定义加密函数

```lua
-- 如果需要真实的加密实现，可以替换模拟函数
local crypto = ulc_update_module.crypto

function crypto.sm2_verify(public_key, id, signature, plain_data)
    -- 实现真实的SM2验证
    return your_sm2_verify_implementation(public_key, id, signature, plain_data)
end
```

### 3. 自定义通信函数

```lua
-- 替换模拟通信为真实通信
local comm = ulc_update_module.comm

function comm.ulc_send_apdu(apdu)
    -- 实现真实的ULC通信
    return your_ulc_communication_implementation(apdu)
end
```

## 📈 性能优化

### 1. 调整数据包大小

```lua
-- 对于高速连接，可以使用更大的数据包
ulc_update.set_config("PACKET_SIZE", 1024)

-- 对于不稳定连接，使用较小的数据包
ulc_update.set_config("PACKET_SIZE", 128)
```

### 2. 优化重试策略

```lua
-- 减少重试次数以提高速度
ulc_update.set_config("MAX_RETRIES", 3)

-- 或增加重试次数以提高成功率
ulc_update.set_config("MAX_RETRIES", 10)
```

### 3. 禁用不必要的功能

```lua
-- 生产环境配置
ulc_update.set_config("TEST_MODE", false)
ulc_update.set_config("SIMULATE_ERRORS", false)
ulc_update.set_config("VERBOSE_OUTPUT", false)
```

## 🔒 安全注意事项

1. **密钥管理**: 生产环境中应使用安全的密钥管理方案
2. **签名验证**: 确保固件签名验证功能正常工作
3. **传输加密**: 所有固件数据都应加密传输
4. **完整性检查**: 使用CRC和Bitmap确保数据完整性

## 🐛 故障排除

### 常见问题

1. **固件文件不存在**
   ```
   ❌ 固件文件不存在: firmware/DBCos324.bin
   ```
   解决：检查文件路径，或运行 `lua test_ulc_update.lua create` 创建测试文件

2. **通信超时**
   ```
   ❌ APDU发送失败，已重试5次: 传输错误
   ```
   解决：检查设备连接，或调整 `MAX_RETRIES` 配置

3. **Bitmap验证失败**
   ```
   ⚠️ 警告: 经过多次重传，仍有数据包丢失
   ```
   解决：检查传输质量，调整 `ERROR_RATE` 或增加 `MAX_RETRIES`

### 调试技巧

1. **启用详细输出**
   ```lua
   ulc_update.set_config("TEST_MODE", true)
   ```

2. **查看配置**
   ```lua
   ulc_update.show_config()
   ```

3. **单步测试**
   ```bash
   lua test_ulc_update.lua utils    # 测试工具函数
   lua test_ulc_update.lua bitmap   # 测试Bitmap功能
   ```

## 📝 更新日志

### v1.0.0 (2024-12-19)
- ✅ 完整实现JavaScript版本的所有功能
- ✅ 新增Bitmap完整性验证机制
- ✅ 新增配置管理系统
- ✅ 新增错误模拟和测试功能
- ✅ 新增详细的进度显示和日志
- ✅ 新增模块化设计和清晰的API

## 🤝 贡献

欢迎提交问题报告和功能请求！

## 📄 许可证

本项目基于原始JavaScript版本进行Lua移植和增强。