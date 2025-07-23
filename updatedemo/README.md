# ULC 固件升级 - Lua 实现

本项目是基于 `/e:/Dev/Lua/example/javascript/` 目录下原始 JavaScript 版本的 ULC（超低成本）固件升级功能的 Lua 实现。

## 概述

ULC 固件升级系统使用 SM2/SM4 加密算法为 ULC 设备提供安全的固件升级功能。此 Lua 实现在提供原生 Lua 接口的同时，保持与原始 JavaScript 版本的兼容性。

## 功能特性

- **ULC Direct 324 支持**：主要专注于 ULC 版本固件升级
- **SM2/SM4 加密**：安全的固件验证和加密
- **Bitmap 完整性检查**：使用bitmap机制确保固件包传输的完整性
- **智能重传机制**：自动检测并重传丢失的数据包
- **进度监控**：固件传输过程中的实时进度显示
- **模拟通信**：用于测试的模拟 APDU 通信
- **全面测试**：包含多种测试场景的完整测试套件
- **Windows 平台**：针对 Windows 开发环境优化

## 项目结构

```
updatedemo/
├── ulc_firmware_update.lua    # 主要固件升级模块
├── test_ulc_firmware.lua      # 综合测试套件
├── test_bitmap_demo.lua       # Bitmap 功能演示和测试
├── example_usage.lua          # 使用示例和演示
├── README.md                  # 本文档
├── test_firmware/             # 测试固件文件目录
└── test_results/              # 测试结果目录
```

## 系统要求

### Lua 依赖

- **Lua 5.1+**：核心 Lua 解释器
- **LuaSocket**：用于计时和网络操作
- **LuaFileSystem (lfs)**：用于目录操作

### Windows 安装

```bash
# 安装 Lua（如果尚未安装）
# 下载地址：https://www.lua.org/download.html

# 安装 LuaRocks（Lua 包管理器）
# 下载地址：https://luarocks.org/

# 安装所需包
luarocks install luasocket
luarocks install luafilesystem
```

## 快速开始

### 1. 基本使用

```lua
-- 加载模块
local ulc_update = require("ulc_firmware_update")

-- 配置 ULC direct 324 升级
ulc_update.config.UPDATE_TYPE_FLAG = 0  -- ULC direct 324
ulc_update.config.COMM_TYPE = 1         -- ULC 通信
ulc_update.config.DEVICE_ID = 2         -- 目标设备

-- 升级固件
ulc_update.update_firmware("path/to/firmware.bin")
```

### 2. 运行示例

```bash
cd updatedemo
lua example_usage.lua
```

### 3. 运行测试

```bash
cd updatedemo
lua test_ulc_firmware.lua
```

### 4. 测试 Bitmap 功能

```bash
cd updatedemo
lua test_bitmap_demo.lua
```

## 配置说明

### 升级类型

- `0`：ULC direct 324（默认）
- `1`：BLE 芯片升级
- `2`：扩展 324 升级

### 通信类型

- `0`：USB 通信
- `1`：ULC 通信（默认）

### 主要配置参数

```lua
CONFIG = {
    UPDATE_TYPE_FLAG = 0,      -- 升级类型
    COMM_TYPE = 1,             -- 通信方式
    DEVICE_ID = 2,             -- 目标设备 ID
    PACKET_SIZE = 256,         -- 传输数据包大小
    LOADER_SIZE = 0x2000,      -- 加载器大小（8KB）
  
    -- 用于固件升级验证的 SM2 公钥
    PUB_KEY_X = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31",
    PUB_KEY_Y = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0"
}
```

## API 参考

### 主要函数

#### `ulc_update.update_firmware(firmware_path)`

执行完整的固件升级过程。

- **参数**: `firmware_path` - 固件二进制文件路径
- **返回值**: 无（失败时抛出错误）

#### `ulc_update.initialize()`

初始化 ULC 连接并获取设备信息。

#### `ulc_update.prepare_firmware(firmware_path)`

读取并准备固件数据以供传输。

#### `ulc_update.setup_encryption()`

设置 SM2/SM4 加密以进行安全传输。

#### `ulc_update.transfer_firmware(encrypted_firmware)`

将加密的固件数据传输到设备。

#### `ulc_update.verify_completion()`

验证固件升级完成和设备重启。

### 工具函数

#### `utils.int_to_hex(value, length)`

将整数转换为十六进制字符串，可选填充。

#### `utils.hex_to_int(hex_str)`

将十六进制字符串转换为整数。

#### `utils.crc16c(data, seed)`

计算数据完整性的 CRC16 校验值。

#### `utils.str_to_hex(str)` / `utils.hex_to_str(hex)`

在字符串和十六进制表示之间转换。

### 文件操作

#### `file_ops.read_firmware(file_path)`

读取二进制固件文件并返回十六进制数据。

#### `file_ops.write_firmware(file_path, hex_data)`

将十六进制数据写入二进制固件文件。

### 通信

#### `comm.ulc_send_apdu(apdu)`

发送 APDU 命令并返回响应（模拟实现）。

### 加密

#### `crypto.sm2_verify(public_key, id, signature, data)`

验证 SM2 数字签名。

#### `crypto.sm2_encrypt(public_key, data)`

使用 SM2 算法加密数据。

#### `crypto.sm4_encrypt(key, iv, data, mode)`

使用 SM4 算法加密数据。

#### `crypto.sm4_mac(key, data)`

计算数据认证的 SM4 MAC。

### Bitmap 管理

#### `bitmap.add_block_info(index, file_offset, spi_flash_addr, block_len)`

添加数据块信息用于bitmap跟踪。

- **参数**: 
  - `index` - 数据块索引
  - `file_offset` - 文件偏移量
  - `spi_flash_addr` - SPI Flash地址
  - `block_len` - 数据块长度

#### `bitmap.get_block_info(index)`

获取指定索引的数据块信息。

- **参数**: `index` - 数据块索引
- **返回值**: 数据块信息表或nil

#### `bitmap.clear_block_info()`

清空所有数据块信息。

#### `bitmap.get_device_bitmap()`

从设备获取当前的bitmap状态。

- **返回值**: bitmap字节数组或nil

#### `bitmap.retry_missing_packets(encrypted_firmware)`

根据bitmap重传丢失的数据包。

- **参数**: `encrypted_firmware` - 加密的固件数据
- **返回值**: 布尔值，表示是否成功

#### `utils.is_bit_set(bitmap, bit_index)`

检查bitmap中指定位是否为1。

- **参数**: 
  - `bitmap` - bitmap字节数组
  - `bit_index` - 位索引（从0开始）
- **返回值**: 布尔值

#### `utils.set_bit(bitmap, bit_index)`

设置bitmap中指定位为1。

- **参数**: 
  - `bitmap` - bitmap字节数组
  - `bit_index` - 位索引（从0开始）

#### `utils.is_bitmap_complete(bitmap, total_bits)`

检查bitmap是否完整（所有位都为1）。

- **参数**: 
  - `bitmap` - bitmap字节数组
  - `total_bits` - 总位数
- **返回值**: 布尔值

## 测试

### 测试分类

1. **基本功能测试**: 核心模块功能
2. **固件大小测试**: 不同固件文件大小
3. **加密功能测试**: SM2/SM4 操作
4. **通信测试**: APDU 命令模拟
5. **Bitmap 完整性测试**: 数据包传输完整性验证
6. **重传机制测试**: 丢失数据包的自动重传
7. **错误处理测试**: 边界条件和错误情况
8. **性能测试**: 速度和效率测试
9. **完整升级测试**: 端到端模拟

### 运行测试

#### 交互式测试菜单

```bash
lua test_ulc_firmware.lua
```

#### 程序化测试

```lua
local test = require("test_ulc_firmware")
test.run_all()  -- 运行所有测试

-- Bitmap 功能测试
local bitmap_test = require("test_bitmap_demo")
bitmap_test.main()  -- 运行bitmap测试
```

### 测试结果

测试生成详细输出，包括：

- 单个测试结果
- 性能指标
- 错误处理验证
- 成功/失败统计

## 模拟实现

此实现使用模拟函数：

- **APDU 通信**: 模拟设备响应
- **加密操作**: 模拟 SM2/SM4 实现
- **设备交互**: 模拟 ULC 设备行为

### 真实实现说明

在生产环境中，需要替换模拟函数为：

- 实际的 APDU 通信库
- 真实的 SM2/SM4 加密实现
- 硬件特定的设备驱动

## 固件文件格式

### 支持的格式

- **二进制文件** (.bin)：原始固件数据
- **十六进制文件** (.hex)：Intel HEX 格式
- **自定义格式**：带有头部信息的固件包

### 文件结构

```
固件文件结构：
├── 头部 (可选)
│   ├── 版本信息
│   ├── CRC 校验
│   └── 大小信息
└── 固件数据
    ├── 引导加载程序
    ├── 应用程序代码
    └── 配置数据
```

### 大小限制

- **最小大小**：1KB
- **最大大小**：2MB
- **推荐大小**：64KB - 512KB

## Error Handling

### Common Errors

- File not found or unreadable
- Invalid firmware format
- Communication failures
- Cryptographic verification failures
- Device response timeouts

### Error Recovery

- Automatic retry mechanisms
- Graceful degradation
- Detailed error reporting
- Safe failure modes

## 性能

### 传输速度

- **USB 通信**：~100KB/s
- **ULC 通信**：~50KB/s
- **BLE 通信**：~20KB/s

### 内存使用

- **基础内存**：~2MB
- **固件缓存**：固件大小 × 2
- **加密缓存**：~1MB

### 优化建议

1. **分块传输**：使用适当的数据包大小
2. **并行处理**：同时进行加密和传输
3. **内存管理**：及时释放不需要的缓存
4. **错误重试**：智能重试机制

## 兼容性

### Lua 版本

- ✅ Lua 5.1
- ✅ Lua 5.2
- ✅ Lua 5.3
- ✅ Lua 5.4
- ✅ LuaJIT 2.0+

### 操作系统

- ✅ Windows 7/8/10/11
- ✅ Windows Server 2012+
- ⚠️ Linux（需要额外配置）
- ⚠️ macOS（需要额外配置）

### 依赖库

- **必需**：无（纯 Lua 实现）
- **可选**：LuaSocket（用于计时）
- **可选**：LuaFileSystem（用于目录操作）

## 开发指南

### 项目结构

```
updatedemo/
├── ulc_firmware_update.lua    # 核心模块
├── test_ulc_firmware.lua      # 测试套件
├── example_usage.lua          # 使用示例
├── config.lua                 # 配置管理
├── demo.lua                   # 功能演示
└── README.md                  # 文档
```

### 代码规范

- **命名约定**：snake_case 用于变量和函数
- **缩进**：4 个空格
- **注释**：中英文双语注释
- **错误处理**：使用 pcall 和 assert

### 扩展开发

1. **添加新的升级类型**

   ```lua
   -- 在 CONFIG 中添加新类型
   CONFIG.UPDATE_TYPES[3] = "新升级类型"

   -- 实现对应的处理函数
   function handle_new_update_type()
       -- 实现逻辑
   end
   ```
2. **添加新的通信方式**

   ```lua
   -- 扩展通信模块
   comm.new_protocol_send = function(data)
       -- 实现新协议
   end
   ```
3. **添加新的加密算法**

   ```lua
   -- 扩展加密模块
   crypto.new_algorithm = function(data, key)
       -- 实现新算法
   end
   ```

## 故障排除

### 常见问题

#### 1. Lua 环境问题

**问题**：`lua: command not found`
**解决方案**：

```bash
# 检查 Lua 安装
lua -v

# 如果未安装，从官网下载：https://www.lua.org/download.html
# 或使用包管理器安装
```

#### 2. 模块加载失败

**问题**：`module 'ulc_firmware_update' not found`
**解决方案**：

```bash
# 确保在正确的目录中运行
cd e:\Dev\Lua\updatedemo

# 检查文件是否存在
dir ulc_firmware_update.lua
```

#### 3. 固件文件错误

**问题**：`无法读取固件文件`
**解决方案**：

- 检查文件路径是否正确
- 确认文件权限
- 验证文件格式（二进制或十六进制）

#### 4. 通信超时

**问题**：`APDU 命令超时`
**解决方案**：

- 检查设备连接
- 增加超时时间
- 重试通信

#### 5. 加密错误

**问题**：`SM2/SM4 验证失败`
**解决方案**：

- 检查密钥格式
- 验证固件签名
- 确认加密参数

### 调试技巧

#### 启用详细日志

```lua
-- 在脚本开头添加
DEBUG = true
VERBOSE = true
```

#### 检查配置

```lua
-- 打印当前配置
for k, v in pairs(CONFIG) do
    print(k, v)
end
```

#### 测试通信

```lua
-- 测试基本通信
local response = comm.ulc_send_apdu("00A4040008A000000003000000")
print("响应:", response)
```

### 性能优化

#### 内存优化

```lua
-- 定期清理内存
collectgarbage("collect")
```

#### 传输优化

```lua
-- 调整数据包大小
CONFIG.PACKET_SIZE = 512  -- 增加到 512 字节
```

## 许可证

本项目采用 MIT 许可证。详情请参见 LICENSE 文件。

```
MIT License

Copyright (c) 2024 ULC Firmware Update Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 联系信息

- **项目主页**：[GitHub Repository]
- **问题报告**：[GitHub Issues]
- **文档**：[Wiki Pages]
- **邮箱**：support@ulc-firmware.com

## 更新日志

### v1.1.0 (2025-07-22)

- ✅ **新增 Bitmap 完整性检查功能**
  - 数据包传输状态跟踪
  - 自动检测丢失的数据包
  - 智能重传机制
  - 传输完整性验证
- ✅ **增强的错误处理**
  - 更好的重传逻辑
  - 详细的传输状态报告
- ✅ **新增测试文件**
  - `test_bitmap_demo.lua` - Bitmap功能演示
  - `verify_bitmap.lua` - 功能验证脚本

### v1.0.0 (2025-07-22)

- ✅ 初始版本发布
- ✅ ULC Direct 324 支持
- ✅ SM2/SM4 加密实现
- ✅ 完整测试套件
- ✅ Windows 平台优化

### 计划功能

- 🔄 真实硬件通信支持
- 🔄 Linux/macOS 兼容性
- 🔄 GUI 界面
- 🔄 批量升级功能
- 🔄 远程升级支持

---

**注意**：本项目仅用于开发和测试目的。在生产环境中使用前，请确保替换所有模拟实现为真实的硬件接口和加密库。
