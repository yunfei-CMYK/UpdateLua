# 升级流程

324升级：
1.物联网平台推送升级通知
	https://hanta.yuque.com/px7kg1/yfac2l/uhg5zatequbcex1k#
2.网关下载升级包（http）
3.网关下发升级包
	广播+读bitmap确认
4.密钥交换（出生证）
5.启动升级
6.验证升级结果，做标记。

蓝牙升级，与324类似。

网关应用升级：替换lua和so文件。
摄像头应用升级：ULC传输文件，替换文件。

内核驱动升级：替换ko文件。

WiFi升级，待定

uwb模块，待定。

## open local mqtt broker

```cmd
.\mosquitto -c .\mosquitto.conf -v
```

不能挂梯子，不然无法正确下载

## 固件升级报文格式

### 更新固件消息

`Topic`: `/{productId}/{deviceId}/firmware/upgrade`
详细格式：

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "url":"固件文件下载地址",
  "version":"版本号",
  "parameters":{},//其他参数
  "sign":"文件签名值",
  "signMethod":"签名方式",
  "firmwareId":"固件ID",
  "size":100000//文件大小,字节
}
```

### 更新固件消息回复

`Topic`: `/{productId}/{deviceId}/firmware/upgrade/reply`
详细格式：

```json
{
  "success":true,
  "messageId":"1551807719374848000",
  "timestamp":1658213956066
}
```

### 上报更新固件进度

`Topic`: `/{productId}/{deviceId}/firmware/upgrade/progress`

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "progress":50,//进度,0-100
  "complete":false, //是否完成更新
  "version":"升级的版本号",
  "success":true,//是否更新成功,complete为true时有效
  "errorReason":"失败原因",
  "firmwareId":"固件ID"
}
```

**MQTT升级步骤：**

1. 平台推送固件升级，平台给设备发送升级消息
2. 设备给平台回复一条消息
3. 设备发送一条升级进度的消息给平台（一直发送，直到进度为100）

### 拉取固件更新

`Topic`: `/{productId}/{deviceId}/firmware/pull`

方向上行,拉取平台的最新固件信息.

详细格式:

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "messageId":"消息ID",//回复的时候会回复相同的ID
  "currentVersion":"1.0",//当前版本,可以为null
  "requestVersion":"1.2", //请求更新版本,为null则为最新版本
}
```

### 拉取固件更新回复

`Topic`:`/{productId}/{deviceId}/firmware/pull/reply`

方向下行,平台回复拉取的固件信息.

详细格式:

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "messageId":"请求的ID",
  "url":"固件文件下载地址",
  "version":"版本号",
  "parameters":{},//其他参数
  "sign":"文件签名值",
  "signMethod":"签名方式",
  "firmwareId":"固件ID",
  "size":100000//文件大小,字节
}
```

### 上报固件版本

`Topic`: `/{productId}/{deviceId}/firmware/report`

方向上行,设备向平台上报固件版本.

详细格式:

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "version":"版本号"
}
```

### 获取固件版本

`Topic`:`/{productId}/{deviceId}/firmware/read`

方向下行,平台读取设备固件版本

详细格式:

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "messageId":"消息ID"
}
```

### 获取固件版本回复

`Topic`:`/{productId}/{deviceId}/firmware/read/reply`

方向上行,设备回复平台读取设备固件版本指令

详细格式:

```json
{
  "timestamp":1601196762389, //毫秒时间戳
  "messageId":"读取指令中的消息ID",
  "version":""//版本号
}
```

## 远程升级步骤

### 平台推送

1. **开始升级（平台发给设备）**

定时器每30秒会触发检查，为升级任务创建对应的升级任务记录。

然后发送开始升级的消息到设备，升级记录状态变为升级中。

`Topic`:`/{productId}/{deviceId}/firmware/upgrade`

详细格式:

```json
{
  "messageId": "1551807719374848000",
  "deviceId": "1549217055251308544",
  "headers": {
    "deviceName": "固件升级",
    "productName": "升级",
    "productId": "1549064506569449472",
    "creatorId": "1199596756811550720",
    "timeout": 10000
  },
  "timestamp": 1658814766149,
  "url": "http://127.0.0.1:8844/file/97b8f5ae7311a275c27e734b633635d0?accessKey=65bd8a681e1fea659886962621ddf337",
  "version": "1.0",
  "parameters": {
    "test": "test"
  },
  "sign": "b292b8415378b8660705f1e9a312cb0b",
  "signMethod": "MD5",
  "firmwareId": "1551519269396340736",
  "size": 570,
  "messageType": "UPGRADE_FIRMWARE"
}
```

|                |                  |
| -------------- | ---------------- |
| **参数** | **说明**   |
| `productId`  | 产品ID           |
| `deviceId`   | 设备ID           |
| `version`    | 固件版本         |
| `url`        | 用于设备下载固件 |

---

# FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js 详细介绍

## 文件概述

这是一个用于固件更新的JavaScript脚本，主要用于通过ULC（Universal Logic Controller）通道对设备进行固件升级。该脚本使用SM2（国密非对称加密算法）和SM4（国密对称加密算法）进行安全通信和数据加密，并使用CRC（循环冗余校验）确保数据传输的完整性。

## 主要功能

1. **多设备类型支持**：

   - 支持直连的324设备（UpdateTypeFlag=0）
   - 支持附属蓝牙芯片（UpdateTypeFlag=1）
   - 支持网关扩展板324（UpdateTypeFlag=2）
2. **通信方式**：

   - 支持USB通道（CommType=0）
   - 支持ULC通道（CommType=1）
3. **安全机制**：

   - 使用SM2算法进行身份验证和签名验证
   - 使用SM4算法对固件进行加密
   - 计算明文和密文固件的MAC值确保完整性
4. **固件传输**：

   - 支持分包传输（默认包大小256字节）
   - 使用bitmap方式管理传输状态（但不支持断点续传）
   - 对每个数据包进行CRC校验

## 关键函数说明

### SM2_verify 函数

```javascript
function SM2_verify(SM2_PubKey, id, SignData, plainData)
```

- 功能：使用SM2算法验证签名
- 参数：
  - SM2_PubKey：SM2公钥
  - id：身份标识（默认使用ENTL_ID）
  - SignData：签名数据
  - plainData：原始数据

### ULC_Send_APDU 函数

```javascript
function ULC_Send_APDU(apdu)
```

- 功能：发送APDU命令到设备
- 参数：
  - apdu：APDU命令字符串
- 特点：
  - 根据CommType选择通信方式
  - 包含重试机制（最多尝试3次）
  - 返回去除状态字的响应数据

### Main 函数

- 功能：主函数，执行固件更新的完整流程
- 主要步骤：
  1. 初始化读卡器和通信环境
  2. 获取设备UUID并验证
  3. 准备固件文件（根据设备类型选择不同路径）
  4. 处理固件数据（移除Loader部分、对齐等）
  5. 计算固件MAC值并加密固件
  6. 发送升级信息和签名数据
  7. 传输加密后的固件数据（分包传输）
  8. 等待设备重启并验证版本

## 技术细节

### 固件处理

1. **固件选择**：根据UpdateTypeFlag选择不同的固件文件
2. **预处理**：
   - 对于324设备，移除Loader部分（0x2000字节）
   - 对于蓝牙芯片，将固件补齐至1K整数倍
3. **对齐处理**：将固件长度对齐到16字节边界

### 加密流程

1. **生成会话密钥**：创建SM4加密用的会话密钥（SK）
2. **计算MAC值**：
   - 明文固件MAC：使用SM4-CBC模式计算
   - 密文固件MAC：对加密后的固件再次计算MAC
3. **固件加密**：使用SM4-ECB模式和会话密钥加密固件
4. **密钥保护**：使用SM2算法加密会话密钥后传输

### 传输机制

1. **分包传输**：将固件按256字节分包传输
2. **CRC校验**：对每个数据包计算CRC值
3. **进度显示**：显示传输百分比
4. **错误处理**：捕获传输异常并提供调试信息

## 注意事项

1. 脚本支持bitmap方式但不支持断点续传（注释掉的USE_BREAK_POINT功能）
2. 包含了SM2算法的椭圆曲线参数（a, b, Gx, Gy）
3. 固件大小有一定限制（注释掉的代码显示曾经限制为220K）
4. 脚本包含重试机制以提高通信可靠性

## 总结

这个脚本是一个完整的固件更新解决方案，结合了国密算法（SM2/SM4）和CRC校验，通过ULC通道安全地更新多种设备的固件。它实现了固件的加密传输、完整性验证和版本确认，保证了固件更新过程的安全性和可靠性。

---

# ULC 固件更新脚本 (ulc_firmware_update.lua) 详细介绍

`<mcfile name="ulc_firmware_update.lua" path="e:\Dev\Lua\updatedemo\ulc_firmware_update.lua"></mcfile>` 是一个用 Lua 语言实现的 ULC 固件更新脚本，它是基于 JavaScript 版本的 `<mcfile name="FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js" path="e:\Dev\Lua\example\javascript\FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js"></mcfile>` 进行移植的。该脚本提供了一套完整的固件更新解决方案，支持 SM2/SM4 加密、CRC16 校验、Bitmap 管理和 ULC 通信。

## 文件结构

该文件由以下几个主要模块组成：

1. **配置模块 (CONFIG)**：包含固件更新所需的各种配置参数
2. **工具函数模块 (utils)**：提供各种辅助函数，如十六进制转换、CRC16 计算等
3. **文件操作模块 (file_ops)**：处理固件文件的读写操作
4. **通信模块 (comm)**：模拟 ULC APDU 通信
5. **进度显示模块 (progress)**：提供进度条显示功能
6. **加密模块 (crypto)**：模拟 SM2/SM4 加密和签名验证
7. **Bitmap 管理模块 (bitmap)**：管理数据块信息和处理丢失数据包的重传
8. **ULC 更新模块 (ulc_update)**：实现固件更新的核心流程

## 核心功能

### 1. 初始化连接 (ulc_update.initialize)

该函数负责初始化 ULC 连接并获取设备信息：

- 选择应用
- 获取设备的 SM2 公钥
- 获取设备的 UUID
- 验证签名

```lua
function ulc_update.initialize()
    print("=== ULC 固件更新初始化 ===")
  
    -- 选择应用
    comm.ulc_send_apdu("00A4000002DF20")
  
    -- 获取 SM2 公钥
    local pubkey_response = comm.ulc_send_apdu("E0B4011C022000")
    sm2_public_key = pubkey_response
    print("SM2 公钥: " .. sm2_public_key)
  
    -- 获取 UUID 并验证签名
    local uuid_response = comm.ulc_send_apdu("80DB001C081122334455667788")
    local signature = uuid_response:sub(-64)  -- 最后 64 个字符
    local data_part = uuid_response:sub(1, -65)  -- 除签名外的所有内容
  
    -- 提取 UUID
    uuid1 = utils.str_mid(data_part, 3, 16)  -- 跳过前 2 个字符，取 16 个
    uuid2 = utils.str_mid(data_part, 21, 16) -- 跳到第 21 个位置，取 16 个
  
    print("UUID1: " .. uuid1)
    print("UUID2: " .. uuid2)
  
    -- 验证签名
    crypto.sm2_verify(sm2_public_key, "", signature, "1122334455667788" .. data_part)
  
    print("初始化成功完成！")
end
```

### 2. 准备固件 (ulc_update.prepare_firmware)

该函数负责读取固件文件并进行必要的处理：

- 读取固件文件
- 根据更新类型移除加载器或填充固件
- 对齐固件到 16 字节边界

```lua
function ulc_update.prepare_firmware(firmware_path)
    print("=== 准备固件 ===")
  
    -- 读取固件文件
    firmware_data, firmware_length = file_ops.read_firmware(firmware_path)
  
    -- 如果需要，移除加载器（对于 ULC 直接 324 或扩展 324）
    if CONFIG.UPDATE_TYPE_FLAG == 0 or CONFIG.UPDATE_TYPE_FLAG == 2 then
        firmware_data = utils.str_mid(firmware_data, CONFIG.LOADER_SIZE * 2 + 1)
        firmware_length = firmware_length - CONFIG.LOADER_SIZE
        print("加载器已移除，新固件长度: " .. firmware_length)
    elseif CONFIG.UPDATE_TYPE_FLAG == 1 then
        -- 对 BLE 固件填充到 1K 边界
        local remainder = firmware_length % 0x400
        if remainder ~= 0 then
            local pad_size = 0x400 - remainder
            firmware_data = utils.pad_string(firmware_data, "FF", #firmware_data + pad_size * 2)
            firmware_length = firmware_length + pad_size
            print("固件已填充到 1K 边界，新长度: " .. firmware_length)
        end
    end
  
    -- 对齐到 16 字节边界
    local aligned_length = (firmware_length + 0x0F) & ~0x0F
    if aligned_length > firmware_length then
        firmware_data = utils.pad_string(firmware_data, "00", aligned_length * 2)
        firmware_length = aligned_length
        print("固件已对齐到 16 字节边界，最终长度: " .. firmware_length)
    end
  
    print("固件准备完成！")
end
```

### 3. 设置加密 (ulc_update.setup_encryption)

该函数负责设置加密参数并加密固件：

- 生成会话密钥
- 使用 SM4 加密固件
- 计算 MAC 值
- 创建并发送切换信息
- 加密会话密钥并发送

```lua
function ulc_update.setup_encryption()
    print("=== 设置加密 ===")
  
    -- 生成会话密钥（模拟）
    local session_key = string.rep("11", 16)  -- 16 字节密钥作为十六进制字符串
    print("会话密钥: " .. session_key)
  
    -- 加密固件并计算 MAC
    local encrypted_firmware = crypto.sm4_encrypt(session_key, "00000000000000000000000000000000", 
                                                 utils.hex_to_str(firmware_data), "ECB")
    local mac1 = crypto.sm4_mac(session_key, utils.hex_to_str(firmware_data))
    local mac2 = crypto.sm4_mac(session_key, utils.hex_to_str(encrypted_firmware))
  
    -- 根据更新类型确定设备 UUID
    local device_uuid = ""
    if CONFIG.UPDATE_TYPE_FLAG == 0 then
        device_uuid = uuid1
    else
        device_uuid = uuid2
    end
  
    -- 创建切换信息
    local new_uuid = string.rep("A2", 16)
    local start_sn = string.rep("00", 16)
    local end_sn = string.rep("FF", 16)
  
    local switch_info = "000081" .. device_uuid .. start_sn .. end_sn .. 
                       "40080100000000000000000000000000000000" .. new_uuid .. 
                       "00005000" .. utils.int_to_hex(firmware_length, 4) .. mac1 .. mac2
  
    print("切换信息: " .. switch_info)
  
    -- 签名切换信息（模拟）
    local signature = string.rep("S", 64)  -- 模拟 64 字节签名
  
    -- 发送切换信息
    local switch_cmd = "80DA000000" .. utils.int_to_hex(#switch_info + #signature, 4) .. 
                      switch_info .. signature
    comm.ulc_send_apdu(switch_cmd)
  
    -- 获取用于加密的公钥
    local pubkey_for_encrypt = comm.ulc_send_apdu("E0B4011C022000")
  
    -- 加密会话密钥
    local encrypted_sk = crypto.sm2_encrypt(pubkey_for_encrypt, session_key)
  
    -- 发送加密的会话密钥
    local sk_cmd = "0020001C00" .. utils.int_to_hex(#encrypted_sk, 4) .. encrypted_sk
    comm.ulc_send_apdu(sk_cmd)
  
    print("加密设置完成！")
    return encrypted_firmware
end
```

### 4. 传输固件 (ulc_update.transfer_firmware)

该函数负责将加密后的固件分包传输到设备：

- 计算总数据包数量
- 将固件分成多个数据包发送
- 使用 Bitmap 验证传输完整性
- 重传丢失的数据包

```lua
function ulc_update.transfer_firmware(encrypted_firmware)
    print("=== 传输固件 ===")
  
    -- 验证输入参数
    if not encrypted_firmware or #encrypted_firmware == 0 then
        print("错误: 加密固件数据为空")
        return false
    end
  
    local offset = 0
    local packet_size = CONFIG.PACKET_SIZE
  
    -- 确保packet_size是有效的正数
    if not packet_size or packet_size <= 0 then
        print("错误: 数据包大小无效")
        return false
    end
  
    -- 计算总块数，确保结果是有效的正整数
    local firmware_length = #encrypted_firmware
    local bytes_per_packet = packet_size * 2  -- *2 用于十六进制
    local calculated_total_blocks = math.ceil(firmware_length / bytes_per_packet)
  
    -- 验证total_blocks是有效的
    if not calculated_total_blocks or calculated_total_blocks <= 0 or calculated_total_blocks ~= calculated_total_blocks then  -- 检查NaN
        print("错误: 计算的总块数无效")
        return false
    end
  
    local current_packet = 0
    local spi_flash_addr = 0x5000  -- 起始Flash地址
  
    print("需要发送的总包数: " .. calculated_total_blocks)
  
    -- 清空之前的数据块信息
    bitmap.clear_block_info()
  
    -- 设置总块数到bitmap模块
    total_blocks = calculated_total_blocks
  
    while offset < #encrypted_firmware do
        local remaining = #encrypted_firmware - offset
        local current_packet_size = math.min(packet_size * 2, remaining)  -- *2 用于十六进制
  
        local packet_data = encrypted_firmware:sub(offset + 1, offset + current_packet_size)
        local crc = utils.crc16c(packet_data, 0)
  
        -- 记录数据块信息用于bitmap验证
        bitmap.add_block_info(current_packet, offset / 2, spi_flash_addr, current_packet_size / 2)
  
        local cmd = "00D0000000" .. 
                   utils.int_to_hex(current_packet_size / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
                   utils.int_to_hex(offset / 2, 4) ..  -- /2 因为十六进制转字节
                   packet_data .. 
                   utils.int_to_hex(crc, 2)
  
        comm.ulc_send_apdu(cmd)
  
        offset = offset + current_packet_size
        current_packet = current_packet + 1
        spi_flash_addr = spi_flash_addr + (current_packet_size / 2)
  
        -- 显示进度（确保参数有效）
        if current_packet <= total_blocks then
            progress.show_progress(current_packet, total_blocks, "传输中")
        end
  
        -- 小延迟以模拟真实传输
        socket.sleep(0.01)
    end
  
    print("初始固件传输完成！")
  
    -- 使用bitmap验证传输完整性并重传丢失的数据包
    print("")
    local bitmap_success = bitmap.retry_missing_packets(encrypted_firmware)
  
    if bitmap_success then
        print("固件传输完成，所有数据包完整性验证通过！")
    else
        print("警告: 固件传输可能不完整，请检查设备状态")
    end
  
    return bitmap_success
end
```

### 5. 验证完成 (ulc_update.verify_completion)

该函数负责验证固件更新是否成功完成：

- 发送完成检查命令
- 等待设备重启
- 重新连接并获取新版本信息

```lua
function ulc_update.verify_completion()
    print("=== 验证更新完成 ===")
  
    -- 发送完成检查命令
    comm.ulc_send_apdu("80C4000000")
  
    print("等待设备重启...")
    socket.sleep(2)  -- 等待 2 秒
  
    -- 重新连接并验证
    comm.ulc_send_apdu("00A4000002DF20")
  
    -- 获取 COS 版本
    local cos_version = comm.ulc_send_apdu("F0F6020000")
    print("新 COS 版本: " .. utils.str_to_hex(cos_version))
  
    if CONFIG.UPDATE_TYPE_FLAG == 1 then
        local nordic_version = comm.ulc_send_apdu("F0F6030000")
        print("Nordic 版本: " .. utils.str_to_hex(nordic_version))
    end
  
    print("更新验证完成！")
end
```

## 特色功能

### Bitmap 管理和数据包重传

该脚本实现了基于 Bitmap 的数据包丢失检测和重传机制：

1. **Bitmap 获取**：从设备获取当前已接收数据包的 Bitmap
2. **丢失数据包检测**：通过分析 Bitmap 识别丢失的数据包
3. **数据包重传**：针对丢失的数据包进行重传
4. **多次重试**：支持多次重传尝试，提高传输成功率
5. **详细日志**：提供丢失数据包的详细统计和日志

### 模拟通信

该脚本使用 `comm.ulc_send_apdu` 函数模拟 ULC 通信，便于在没有实际设备的情况下进行测试：

```lua
function comm.ulc_send_apdu(apdu)
    print("发送 APDU: " .. apdu)
  
    -- Simulate different responses based on APDU command
    if apdu == "00A4000002DF20" then
        -- 选择应用
        return "9000"
    elseif apdu:sub(1, 8) == "E0B4011C" then
        -- 获取 SM2 公钥
        local mock_pubkey = CONFIG.PUB_KEY_X .. CONFIG.PUB_KEY_Y
        print("接收: " .. mock_pubkey)
        return mock_pubkey
    elseif apdu:sub(1, 8) == "80DB001C" then
        -- 获取 UUID 和签名
        local mock_uuid1 = "1122334455667788"
        local mock_uuid2 = "AABBCCDDEEFF0011"
        local mock_signature = string.rep("A", 64)  -- 64字节模拟签名
        local response = "01" .. mock_uuid1 .. "02" .. mock_uuid2 .. mock_signature
        print("接收: " .. response)
        return response
    end
    -- ... 其他命令处理 ...
end
```

## 主更新流程

整个固件更新流程由 `ulc_update.update_firmware` 函数协调：

```lua
function ulc_update.update_firmware(firmware_path)
    local start_time = os.time()
  
    print("=== ULC 固件更新已开始 ===")
    print("固件路径: " .. firmware_path)
    print("更新类型: " .. CONFIG.UPDATE_TYPE_FLAG)
    print("通信类型: " .. CONFIG.COMM_TYPE)
    print("开始时间: " .. os.date("%Y-%m-%d %H:%M:%S", start_time))
    print("")
  
    local success = false
  
    -- 步骤 1: 初始化连接
    ulc_update.initialize()
    print("")
  
    -- 步骤 2: 准备固件
    ulc_update.prepare_firmware(firmware_path)
    print("")
  
    -- 步骤 3: 设置加密
    local encrypted_firmware = ulc_update.setup_encryption()
    print("")
  
    -- 步骤 4: 传输固件（包含bitmap完整性验证）
    local transfer_success = ulc_update.transfer_firmware(encrypted_firmware)
    print("")
  
    if transfer_success then
        -- 步骤 5: 验证完成
        ulc_update.verify_completion()
        print("")
        success = true
    else
        print("固件传输失败，跳过完成验证")
    end
  
    -- 清理bitmap信息
    bitmap.clear_block_info()
  
    local end_time = os.time()
    local duration = end_time - start_time
  
    print("=== ULC 固件更新已完成 ===")
    print("总时间: " .. duration .. " 秒")
    print("状态: " .. (success and "成功" or "失败"))
  
    return success
end
```

## 模块导出

该脚本将所有模块导出，便于其他脚本引用：

```lua
return {
    config = CONFIG,
    utils = utils,
    file_ops = file_ops,
    comm = comm,
    crypto = crypto,
    progress = progress,
    bitmap = bitmap,
    ulc_update = ulc_update,
    update_firmware = ulc_update.update_firmware
}
```

## 总结

`<mcfile name="ulc_firmware_update.lua" path="e:\Dev\Lua\updatedemo\ulc_firmware_update.lua"></mcfile>` 是一个功能完整的 ULC 固件更新脚本，它提供了：

1. **完整的更新流程**：从初始化到验证完成的全流程支持
2. **安全机制**：支持 SM2/SM4 加密和签名验证
3. **可靠传输**：基于 Bitmap 的数据包丢失检测和重传机制
4. **灵活配置**：支持多种更新类型和通信方式
5. **友好界面**：提供进度显示和详细日志
6. **模拟测试**：支持在没有实际设备的情况下进行测试

该脚本可以作为 ULC 固件更新的参考实现，也可以根据实际需求进行定制和扩展。

# JavaScript与Lua固件更新文件功能对比分析

我对 `FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.js`和 `ulc_firmware_update.lua`两个文件进行了详细分析，下面是它们在具体功能实现上的对应关系：

## 1. 基础配置与常量定义

### JavaScript实现

```javascript
var UpdateTypeFlag = 0;    //0表示与ULC直连的324；1表示附属蓝牙芯片；2表示网关扩展板324
var CommType = 1;          //0表示使用USB通道，1表示使用ULC通道
var DeviceID = 2;          //表示使用ULC通道时目的设备ID

var ENTL_ID = "31323334353637383132333435363738";

var a = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC";
var b = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93";
var Gx = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7";
var Gy = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0";
```

### Lua实现

```lua
local CONFIG = {
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
    SM2_GY = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0"
}
```

**对应关系**：Lua版本将所有配置集中在 `CONFIG`表中，而JavaScript版本使用单独的全局变量。Lua版本还增加了 `PACKET_SIZE`和 `LOADER_SIZE`常量的显式定义。

## 2. SM2签名验证函数

### JavaScript实现

```javascript
function SM2_verify(SM2_PubKey, id, SignData, plainData) {
    if (id == "")
        id = ENTL_ID;
  
    Debug.writeln("签名值：", SignData);
    Debug.writeln("SM2公钥：", SM2_PubKey);
    Debug.writeln("id: ", id);
    Debug.writeln("待签名源数据：", plainData);
  
    // 计算ZA值时，公钥值不包含首字节"04"
    var za = "0080" + id + a+ b+ Gx+ Gy +  Def.StrMid(SM2_PubKey, 1, -1);
    var Digest = Mgr.CreateInstance("LgnAlg.LgnDigest");
    Digest.Init("SM3");
    var md = Digest.Digest(za);
    Digest.Init("SM3");
    var md_Hash = Digest.Digest(md + plainData);
    Debug.writeln("md_Hash:", md_Hash);
  
    var Itrus = Mgr.CreateInstance("LgnAlg.LgnItrus");
    Itrus.sm2_pubkey_import(SM2_PubKey);    
    Itrus.sm2_verify(md_Hash, SignData);
    Debug.writeln("SM2_verify() 验证通过");
}
```

### Lua实现

```lua
function crypto.sm2_verify(public_key, id, signature, plain_data)
    print("SM2 验证:")
    print("  公钥: " .. public_key)
    print("  ID: " .. (id or CONFIG.ENTL_ID))
    print("  签名: " .. signature)
    print("  原始数据: " .. plain_data)
    print("  验证结果: 通过 (模拟)")
    return true
end
```

**对应关系**：JavaScript版本实现了完整的SM2签名验证逻辑，而Lua版本提供了一个模拟实现，仅打印参数并返回成功。

## 3. ULC通信函数

### JavaScript实现

```javascript
function ULC_Send_APDU(apdu)
{
    var ret = "";
    if(0 == CommType)
    {
        ret = Ins.ExecuteSingleEx(apdu);
    }
    else
    {
        ret = Ins.ExecuteSingleEx("FCD550" + Def.Int2Hex(DeviceID, 1) + Def.Int2Hex(Def.StrLen(apdu), 3) + apdu, "[SW:<6FF3><9000>]");
        if("9000" == Ins.GetSW())
        {
            var sw = Def.StrRight(ret, 2);
            if("9000" == sw)
            {
                return Def.StrLeft(ret, Def.StrLen(ret)-2);
            }
            else
            {
                throw -1;
            }
        }
        // ... 重试逻辑 ...
    }
}
```

### Lua实现

```lua
function comm.ulc_send_apdu(apdu)
    print("发送 APDU: " .. apdu)
  
    -- Simulate different responses based on APDU command
    if apdu == "00A4000002DF20" then
        -- 选择应用
        return "9000"
    elseif apdu:sub(1, 8) == "E0B4011C" then
        -- 获取 SM2 公钥
        local mock_pubkey = CONFIG.PUB_KEY_X .. CONFIG.PUB_KEY_Y
        print("接收: " .. mock_pubkey)
        return mock_pubkey
    -- ... 其他命令处理 ...
    else
        -- 默认响应
        print("接收: 9000")
        return "9000"
    end
end
```

**对应关系**：JavaScript版本实现了实际的ULC通信，包括重试机制，而Lua版本提供了一个模拟实现，根据不同的APDU命令返回模拟响应。

## 4. 固件读取与处理

### JavaScript实现

```javascript
var FirmwarePath = CurWorkPath + "..\\DBCos324.bin";
// ... 根据UpdateTypeFlag选择不同路径 ...
var CosObj = Mgr.CreateInstance("LgnPacket.LgnFile");
CosObj.Open(FirmwarePath);
var CosLen = CosObj.Parameter("SIZE");
CosObj.Parameter("POINTER")=0;
var Firmware = CosObj.Read(CosLen, 0);

if(0 == UpdateTypeFlag || 2 == UpdateTypeFlag)
{
    LoaderSize = 0x2000;
    Firmware = Def.StrMid(Firmware, LoaderSize);
}
else if(1 == UpdateTypeFlag)
{
    //将bin文件补齐至1k整数倍
    if(Def.StrLen(Firmware) % 0x400)
        Firmware = Def.StrFullTail(Firmware, "FF", 0x400);
}
```

### Lua实现

```lua
function file_ops.read_firmware(file_path)
    print("读取固件文件: " .. file_path)
  
    local file, err = io.open(file_path, "rb")
    if not file then
        error("打开固件文件失败: " .. (err or "未知错误"))
    end
  
    local content = file:read("*all")
    file:close()
  
    if not content then
        error("读取固件文件内容失败")
    end
  
    -- 将二进制内容转换为十六进制字符串
    local hex_content = utils.str_to_hex(content)
    print(string.format("固件已加载: %.2f KB", #content / 1024))
  
    return hex_content, #content
end

function ulc_update.prepare_firmware(firmware_path)
    print("=== 准备固件 ===")
  
    -- 读取固件文件
    firmware_data, firmware_length = file_ops.read_firmware(firmware_path)
  
    -- 如果需要，移除加载器（对于 ULC 直接 324 或扩展 324）
    if CONFIG.UPDATE_TYPE_FLAG == 0 or CONFIG.UPDATE_TYPE_FLAG == 2 then
        firmware_data = utils.str_mid(firmware_data, CONFIG.LOADER_SIZE * 2 + 1)  -- *2 用于十六进制，+1 用于 1 开始的索引
        firmware_length = firmware_length - CONFIG.LOADER_SIZE
        print("加载器已移除，新固件长度: " .. firmware_length)
    elseif CONFIG.UPDATE_TYPE_FLAG == 1 then
        -- 对 BLE 固件填充到 1K 边界
        local remainder = firmware_length % 0x400
        if remainder ~= 0 then
            local pad_size = 0x400 - remainder
            firmware_data = utils.pad_string(firmware_data, "FF", #firmware_data + pad_size * 2)
            firmware_length = firmware_length + pad_size
            print("固件已填充到 1K 边界，新长度: " .. firmware_length)
        end
    end
  
    -- 对齐到 16 字节边界
    local aligned_length = (firmware_length + 0x0F) & ~0x0F
    if aligned_length > firmware_length then
        firmware_data = utils.pad_string(firmware_data, "00", aligned_length * 2)
        firmware_length = aligned_length
        print("固件已对齐到 16 字节边界，最终长度: " .. firmware_length)
    end
  
    print("固件准备完成！")
end
```

**对应关系**：两个版本都实现了固件读取和处理，但Lua版本将功能拆分为 `read_firmware`和 `prepare_firmware`两个函数，逻辑更清晰。两者都根据更新类型进行不同处理：移除加载器或填充到1K边界。

## 5. 加密设置与会话密钥处理

### JavaScript实现

```javascript
var SK = Def.StrFullTail("11", "11", 16);

//明文固件MAC
var mac11 = Def.StrRight( Alg.Encrypt("SM4-CBC", SK, "00000000000000000000000000000000", Firmware, true), 16);    
var CipherFirmware = Alg.Encrypt("SM4-ECB", SK, "00000000000000000000000000000000", Firmware, false)
//密文固件MAC
var mac22 = Def.StrRight( Alg.Encrypt("SM4-CBC", SK, "00000000000000000000000000000000", CipherFirmware, true), 16);  

// ... 构建切换信息 ...
var switchInfo = "000081" + deviceUUID + startSN + endSN + "40080100000000000000000000000000000000" + newUUID + "00005000" + Def.Int2Hex(FLen, 4) + mac11 + mac22;

// ... 签名切换信息并发送 ...
var signdata =  SM2.Sign_rs(switchInfo, "31323334353637383132333435363738");
ULC_Send_APDU("80DA000000" + Def.StrLen2Hex(switchInfo + signdata, 2) + switchInfo + signdata);

// ... 获取公钥并加密会话密钥 ...
ret = ULC_Send_APDU("E0B4011C022000");
sm2_n = ret;
var Itrus = Mgr.CreateInstance("LgnAlg.LgnItrus");
Itrus.sm2_pubkey_import(sm2_n);
var encryptSK = Itrus.sm2_encrypt(SK);
ULC_Send_APDU("0020001C00" + Def.StrLen2Hex(encryptSK, 2) + encryptSK);
```

### Lua实现

```lua
function ulc_update.setup_encryption()
    print("=== 设置加密 ===")
  
    -- 生成会话密钥（模拟）
    local session_key = string.rep("11", 16)  -- 16 字节密钥作为十六进制字符串
    print("会话密钥: " .. session_key)
  
    -- 加密固件并计算 MAC
    local encrypted_firmware = crypto.sm4_encrypt(session_key, "00000000000000000000000000000000", 
                                                 utils.hex_to_str(firmware_data), "ECB")
    local mac1 = crypto.sm4_mac(session_key, utils.hex_to_str(firmware_data))
    local mac2 = crypto.sm4_mac(session_key, utils.hex_to_str(encrypted_firmware))
  
    -- 根据更新类型确定设备 UUID
    local device_uuid = ""
    if CONFIG.UPDATE_TYPE_FLAG == 0 then
        device_uuid = uuid1
    else
        device_uuid = uuid2
    end
  
    -- 创建切换信息
    local new_uuid = string.rep("A2", 16)
    local start_sn = string.rep("00", 16)
    local end_sn = string.rep("FF", 16)
  
    local switch_info = "000081" .. device_uuid .. start_sn .. end_sn .. 
                       "40080100000000000000000000000000000000" .. new_uuid .. 
                       "00005000" .. utils.int_to_hex(firmware_length, 4) .. mac1 .. mac2
  
    -- 签名切换信息（模拟）
    local signature = string.rep("S", 64)  -- 模拟 64 字节签名
  
    -- 发送切换信息
    local switch_cmd = "80DA000000" .. utils.int_to_hex(#switch_info + #signature, 4) .. 
                      switch_info .. signature
    comm.ulc_send_apdu(switch_cmd)
  
    -- 获取用于加密的公钥
    local pubkey_for_encrypt = comm.ulc_send_apdu("E0B4011C022000")
  
    -- 加密会话密钥
    local encrypted_sk = crypto.sm2_encrypt(pubkey_for_encrypt, session_key)
  
    -- 发送加密的会话密钥
    local sk_cmd = "0020001C00" .. utils.int_to_hex(#encrypted_sk, 4) .. encrypted_sk
    comm.ulc_send_apdu(sk_cmd)
  
    print("加密设置完成！")
    return encrypted_firmware
end
```

**对应关系**：两个版本都实现了类似的加密流程：生成会话密钥、加密固件、计算MAC、构建切换信息、签名、加密会话密钥并发送。Lua版本将整个流程封装在一个函数中，并返回加密后的固件数据。

## 6. 固件传输与数据包处理

### JavaScript实现

```javascript
//开始下载升级固件
Ins.InsParam("DEBUGER") = null;
for(offset = startoffset; offset + PacketSize < FLen; offset += PacketSize)
{
    try
    {
        {
            var send_Data = Def.StrMid(CipherFirmware, offset, PacketSize);
            var crc = crc16c(send_Data,0);
            ULC_Send_APDU("00D0000000" + Def.Int2Hex2(PacketSize+6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2));
        }
    }
    catch(e)
    {
        Debug.writeln("SW: ", Ins.GetSW());
        Debug.writeln("Ret: ", Ins.GetRet());
        Debug.writeln("offset: ", offset);
        throw -1;
    }
  
    if(percent != Math.floor((offset * 100 / FLen)))
    {
        percent = Math.floor((offset * 100 / FLen));
        Debug.writeln(percent + "%");
    }
}
var send_Data = Def.StrMid(CipherFirmware, offset);
var crc = crc16c(send_Data,0);
ULC_Send_APDU("00D0000000" + Def.Int2Hex2(FLen - offset + 6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2));
```

### Lua实现

```lua
function ulc_update.transfer_firmware(encrypted_firmware)
    print("=== 传输固件 ===")
  
    -- 验证输入参数
    if not encrypted_firmware or #encrypted_firmware == 0 then
        print("错误: 加密固件数据为空")
        return false
    end
  
    local offset = 0
    local packet_size = CONFIG.PACKET_SIZE
  
    -- 确保packet_size是有效的正数
    if not packet_size or packet_size <= 0 then
        print("错误: 数据包大小无效")
        return false
    end
  
    -- 计算总块数，确保结果是有效的正整数
    local firmware_length = #encrypted_firmware
    local bytes_per_packet = packet_size * 2  -- *2 用于十六进制
    local calculated_total_blocks = math.ceil(firmware_length / bytes_per_packet)
  
    -- 验证total_blocks是有效的
    if not calculated_total_blocks or calculated_total_blocks <= 0 or calculated_total_blocks ~= calculated_total_blocks then  -- 检查NaN
        print("错误: 计算的总块数无效")
        return false
    end
  
    local current_packet = 0
    local spi_flash_addr = 0x5000  -- 起始Flash地址
  
    print("需要发送的总包数: " .. calculated_total_blocks)
  
    -- 清空之前的数据块信息
    bitmap.clear_block_info()
  
    -- 设置总块数到bitmap模块
    total_blocks = calculated_total_blocks
  
    while offset < #encrypted_firmware do
        local remaining = #encrypted_firmware - offset
        local current_packet_size = math.min(packet_size * 2, remaining)  -- *2 用于十六进制
    
        local packet_data = encrypted_firmware:sub(offset + 1, offset + current_packet_size)
        local crc = utils.crc16c(packet_data, 0)
    
        -- 记录数据块信息用于bitmap验证
        bitmap.add_block_info(current_packet, offset / 2, spi_flash_addr, current_packet_size / 2)
    
        local cmd = "00D0000000" .. 
                   utils.int_to_hex(current_packet_size / 2 + 6, 2) ..  -- /2 因为十六进制转字节，+6 用于偏移量+crc
                   utils.int_to_hex(offset / 2, 4) ..  -- /2 因为十六进制转字节
                   packet_data .. 
                   utils.int_to_hex(crc, 2)
    
        comm.ulc_send_apdu(cmd)
    
        offset = offset + current_packet_size
        current_packet = current_packet + 1
        spi_flash_addr = spi_flash_addr + (current_packet_size / 2)
    
        -- 显示进度（确保参数有效）
        if current_packet <= total_blocks then
            progress.show_progress(current_packet, total_blocks, "传输中")
        end
    
        -- 小延迟以模拟真实传输
        socket.sleep(0.01)
    end
  
    print("初始固件传输完成！")
  
    -- 使用bitmap验证传输完整性并重传丢失的数据包
    print("")
    local bitmap_success = bitmap.retry_missing_packets(encrypted_firmware)
  
    if bitmap_success then
        print("固件传输完成，所有数据包完整性验证通过！")
    else
        print("警告: 固件传输可能不完整，请检查设备状态")
    end
  
    return bitmap_success
end
```

**对应关系**：两个版本都实现了分包传输固件的功能，但Lua版本增加了更多的参数验证、错误处理和进度显示。最重要的是，Lua版本增加了Bitmap管理和丢失数据包重传功能，这在JavaScript版本中没有实现。

## 7. 完成验证

### JavaScript实现

```javascript
ULC_Send_APDU("80c4000000");

Debug.writeln("========等待KEY升级完成后重启...");
Ins.ExecuteSingleEx("CMD[DELAY:0]");
// 选择读卡器
Ins.ExecuteSingleEx("CMD[READER:SR_WinReaderU.dll||cdrom||4]");
// 设置卡片类型：BASE，CARD, PBOC, PSAM, PK；默认为PBOC
Ins.InsVar("CARDTYPE") = "BASE";
Ins.ExecuteSingleEx("CMD[ATR]");

ULC_Send_APDU("00A4000002DF20");

//Ins.ExecuteSingleEx("CMD[ENCOMM:11223344556677889900112233445577]");
var cosVer = ULC_Send_APDU("F0F6020000");
Debug.writeln("主COS Version: " + Def.Str2Hex(cosVer));
if(1 == UpdateTypeFlag)
{
    cosVer = ULC_Send_APDU("F0F6030000");
    Debug.writeln("Nordic Version: " + Def.Str2Hex(cosVer));
}
```

### Lua实现

```lua
function ulc_update.verify_completion()
    print("=== 验证更新完成 ===")
  
    -- 发送完成检查命令
    comm.ulc_send_apdu("80C4000000")
  
    print("等待设备重启...")
    socket.sleep(2)  -- 等待 2 秒
  
    -- 重新连接并验证
    comm.ulc_send_apdu("00A4000002DF20")
  
    -- 获取 COS 版本
    local cos_version = comm.ulc_send_apdu("F0F6020000")
    print("新 COS 版本: " .. utils.str_to_hex(cos_version))
  
    if CONFIG.UPDATE_TYPE_FLAG == 1 then
        local nordic_version = comm.ulc_send_apdu("F0F6030000")
        print("Nordic 版本: " .. utils.str_to_hex(nordic_version))
    end
  
    print("更新验证完成！")
end
```

**对应关系**：两个版本都实现了类似的完成验证流程：发送完成命令、等待设备重启、重新连接、获取版本信息。Lua版本将整个流程封装在一个函数中，逻辑更清晰。

## 8. 主函数/入口点

### JavaScript实现

```javascript
function Main() {
    // ... 初始化 ...
    // ... 获取UUID和验证签名 ...
    // ... 准备固件 ...
    // ... 设置加密 ...
    // ... 传输固件 ...
    // ... 完成验证 ...
  
    Debug.writeln("测试结束");
}
```

### Lua实现

```lua
function ulc_update.update_firmware(firmware_path)
    local start_time = os.time()
  
    print("=== ULC 固件更新已开始 ===")
    print("固件路径: " .. firmware_path)
    print("更新类型: " .. CONFIG.UPDATE_TYPE_FLAG)
    print("通信类型: " .. CONFIG.COMM_TYPE)
    print("开始时间: " .. os.date("%Y-%m-%d %H:%M:%S", start_time))
    print("")
  
    local success = false
  
    -- 步骤 1: 初始化连接
    ulc_update.initialize()
    print("")
  
    -- 步骤 2: 准备固件
    ulc_update.prepare_firmware(firmware_path)
    print("")
  
    -- 步骤 3: 设置加密
    local encrypted_firmware = ulc_update.setup_encryption()
    print("")
  
    -- 步骤 4: 传输固件（包含bitmap完整性验证）
    local transfer_success = ulc_update.transfer_firmware(encrypted_firmware)
    print("")
  
    if transfer_success then
        -- 步骤 5: 验证完成
        ulc_update.verify_completion()
        print("")
        success = true
    else
        print("固件传输失败，跳过完成验证")
    end
  
    -- 清理bitmap信息
    bitmap.clear_block_info()
  
    local end_time = os.time()
    local duration = end_time - start_time
  
    print("=== ULC 固件更新已完成 ===")
    print("总时间: " .. duration .. " 秒")
    print("状态: " .. (success and "成功" or "失败"))
  
    return success
end
```

**对应关系**：两个版本都实现了完整的固件更新流程，但Lua版本将流程拆分为多个函数，并在主函数中调用，结构更清晰。Lua版本还增加了时间记录、状态返回等功能。

## 9. Bitmap管理（Lua特有功能）

### Lua实现

```lua
function bitmap.get_device_bitmap()
    // ... 获取设备bitmap ...
end

function bitmap.retry_missing_packets(encrypted_firmware)
    // ... 根据bitmap重传丢失的数据包 ...
end

function bitmap.retransmit_single_packet(encrypted_firmware, block_index, block_info)
    // ... 重传单个数据包 ...
end
```

**对应关系**：Bitmap管理是Lua版本特有的功能，JavaScript版本没有实现。这个功能用于检测和重传丢失的数据包，提高固件传输的可靠性。

## 10. 工具函数

### JavaScript实现

使用了内置的 `Def`对象提供的函数，如 `Def.StrMid`、`Def.Int2Hex`等。

### Lua实现

```lua
function utils.int_to_hex(value, length)
    // ... 将整数转换为十六进制字符串 ...
end

function utils.hex_to_int(hex_str)
    // ... 将十六进制字符串转换为整数 ...
end

function utils.str_mid(str, start, length)
    // ... 提取子字符串 ...
end

function utils.crc16c(data, seed)
    // ... CRC16计算 ...
end
```

**对应关系**：Lua版本实现了一系列工具函数，以模拟JavaScript版本中使用的 `Def`对象的功能。

## 总结

两个文件在功能上基本对应，但实现方式有所不同：

1. **结构组织**：JavaScript版本使用全局函数和变量，Lua版本使用模块化设计，将功能分组到不同的表（如 `utils`、`crypto`、`bitmap`等）。
2. **功能扩展**：Lua版本在JavaScript版本的基础上增加了一些功能，特别是Bitmap管理和丢失数据包重传功能。
3. **错误处理**：Lua版本增加了更多的参数验证和错误处理逻辑。
4. **模拟实现**：Lua版本对一些依赖外部库的功能（如加密、通信）提供了模拟实现，而JavaScript版本使用实际的外部库。
5. **代码清晰度**：Lua版本将大功能拆分为小函数，逻辑更清晰，而JavaScript版本的 `Main`函数较为庞大。

总的来说，Lua版本是对JavaScript版本的一个改进和扩展，保持了核心功能的同时，增加了更多的功能和更好的代码组织。

基于updatedemo文件夹与JS升级程序对比


---



# Lua 与 JavaScript 版本固件更新脚本功能比较分析

通过对 `ulc_firmware_update_complete.lua` 和 `FirmwareUpdate_SM2_SM4_通用平台_CRC_ULC.txt` 两个脚本的详细分析，我将按功能模块对它们进行比较，详细介绍各自的实现方式和差异。

## 1. 基础配置与常量定义

### JavaScript 版本

- 使用全局变量直接定义配置项：`UpdateTypeFlag`、`CommType`、`DeviceID`
- 定义 SM2 曲线参数：`a`、`b`、`Gx`、`Gy`
- 定义 ENTL_ID 常量用于 SM2 签名
- 公钥和私钥直接在 `Main()` 函数中定义

### Lua 版本

- 使用 `CONFIG` 表集中管理所有配置项
- 包含更丰富的配置选项：错误模拟、测试模式、重试次数等
- 同样定义了 SM2 曲线参数和 ENTL_ID
- 配置项有详细注释说明用途

## 2. 文件操作功能

### JavaScript 版本

- 使用 `LgnPacket.LgnFile` 对象操作文件
- 文件路径处理较为简单，使用相对路径
- 读取固件文件的代码集中在 `Main()` 函数中

### Lua 版本

- 封装了专门的 `file_ops` 模块
- 提供了更完整的文件操作函数：`read_firmware`、`write_firmware`、`file_exists`
- 文件操作有详细的错误处理和日志输出
- 支持二进制与十六进制字符串的相互转换

## 3. 通信功能

### JavaScript 版本

- `ULC_Send_APDU` 函数处理 APDU 通信
- 支持 USB 和 ULC 两种通信方式
- 通信错误处理采用简单的重试机制（固定重试 3 次）
- 使用 `throw` 抛出异常处理通信错误

### Lua 版本

- 封装了专门的 `comm` 模块
- `ulc_send_apdu` 和 `ulc_send_apdu_with_retry` 函数处理通信
- 支持可配置的重试次数和递增延迟
- 通信错误处理更完善，包含详细日志
- 在测试模式下支持模拟传输延迟和错误

## 4. 加密算法功能

### JavaScript 版本

- 使用外部库实现加密功能：`LgnAlg.LgnSM2`、`LgnAlg.LgnItrus`、`LgnAlg.LgnDigest`
- SM2 签名验证函数 `SM2_verify` 实现较为简洁
- 加密过程直接在 `Main()` 函数中实现

### Lua 版本

- 封装了专门的 `crypto` 模块
- 模拟实现了多种加密功能：`sm2_verify`、`sm2_encrypt`、`sm4_encrypt`、`sm4_mac`、`sm2_sign`
- 每个加密函数都有详细的日志输出
- 在测试模式下支持模拟加密过程

## 5. Bitmap 管理功能

### JavaScript 版本

- 没有专门的 Bitmap 管理模块
- 不支持基于 Bitmap 的丢失数据包重传
- 仅支持简单的断点续传（通过注释掉的代码可以看出）

### Lua 版本

- 封装了专门的 `bitmap` 模块
- 提供了完整的 Bitmap 管理功能：`add_block_info`、`get_block_info`、`clear_block_info`
- 支持获取设备 Bitmap 并分析丢失的数据包
- 实现了基于 Bitmap 的丢失数据包重传机制
- 提供了丢失率统计和详细日志

## 6. 进度显示功能

### JavaScript 版本

- 简单的百分比进度显示
- 直接在 `Main()` 函数中实现
- 只在百分比变化时输出日志

### Lua 版本

- 封装了专门的 `progress` 模块
- 提供了两个进度显示函数：`show_progress` 和 `show_transfer_stats`
- 支持进度条、传输速度和剩余时间估计
- 进度显示更加直观和详细

## 7. 固件处理功能

### JavaScript 版本

- 固件处理逻辑直接在 `Main()` 函数中实现
- 支持移除加载器和填充到 1K 边界
- 固件对齐到 16 字节边界

### Lua 版本

- 在 `ulc_update.prepare_firmware` 函数中集中处理固件
- 同样支持移除加载器和填充到边界
- 提供了更详细的日志输出
- 固件处理逻辑更清晰

## 8. 固件传输功能

### JavaScript 版本

- 固件传输逻辑直接在 `Main()` 函数中实现
- 使用简单的循环发送数据包
- 不支持丢失数据包的重传

### Lua 版本

- 在 `ulc_update.transfer_firmware` 函数中实现
- 支持基于 Bitmap 的丢失数据包重传
- 提供了详细的传输统计和进度显示
- 传输过程有完整的错误处理

## 9. 固件验证功能

### JavaScript 版本

- 验证逻辑简单，主要是获取版本信息
- 根据更新类型获取不同的版本信息

### Lua 版本

- 在 `ulc_update.verify_completion` 函数中实现
- 同样根据更新类型获取不同的版本信息
- 提供了更详细的日志输出

## 10. 错误处理与日志

### JavaScript 版本

- 错误处理较为简单，主要使用 `try-catch` 和 `throw`
- 日志输出使用 `Debug.writeln`
- 缺乏系统化的错误处理机制

### Lua 版本

- 使用 `pcall` 进行错误捕获和处理
- 日志输出更加丰富，使用不同的前缀表示不同类型的日志
- 错误处理更加系统化，每个步骤都有错误处理

## 11. 代码组织与模块化

### JavaScript 版本

- 代码组织较为简单，主要集中在 `Main()` 函数中
- 只有少量的辅助函数
- 缺乏模块化设计

### Lua 版本

- 代码组织更加模块化，分为多个功能模块：`utils`、`file_ops`、`comm`、`crypto`、`progress`、`bitmap`、`ulc_update`
- 每个模块都有明确的职责
- 主要功能封装在 `ulc_update` 模块中，并提供了清晰的 API
- 支持配置管理功能：`set_config`、`get_config`、`show_config`

## 12. 可测试性与调试功能

### JavaScript 版本

- 调试功能较为简单，主要依赖 `Debug.writeln`
- 缺乏专门的测试模式

### Lua 版本

- 提供了专门的测试模式
- 支持错误模拟和传输错误模拟
- 提供了更丰富的调试信息
- 支持配置显示和修改

## 总结

Lua 版本相比 JavaScript 版本有以下优势：

1. **更好的模块化设计**：代码组织更清晰，功能划分更合理
2. **更完善的错误处理**：每个步骤都有详细的错误处理和日志
3. **更丰富的功能**：支持 Bitmap 管理、丢失数据包重传、进度显示等
4. **更好的可测试性**：支持测试模式和错误模拟
5. **更灵活的配置管理**：支持配置显示和修改

JavaScript 版本的优势在于：

1. **使用实际的加密库**：而不是模拟实现
2. **代码更简洁**：整体代码量较少

两个脚本的核心功能实现基本相同，都支持三种类型的固件更新（ULC直连324、BLE芯片、扩展324），都实现了固件的读取、处理、加密和传输功能。Lua 版本在功能完整性、代码组织、错误处理和可测试性方面更胜一筹，而 JavaScript 版本则更加简洁直接。
