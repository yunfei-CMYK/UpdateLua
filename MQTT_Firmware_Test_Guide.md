# MQTT固件下载测试指南

## 🚀 快速开始

### 1. 启动固件下载服务器
```bash
cd e:\Dev\Lua\pydemo
python firmware_server.py
```

### 2. 启动MQTT客户端
```bash
cd e:\Dev\Lua\luademo
lua test.lua
```

### 3. 使用MQTTX发送测试消息

## 📡 MQTT测试消息格式

### 基本固件下载消息
**Topic:** `/{productId}/{deviceId}/firmware/upgrade`

**Payload:**
```json
{
  "firmware_url": "http://localhost:8000/firmware/test.bin",
  "version": "1.0.0",
  "description": "测试固件包",
  "size": 1024,
  "checksum": "abc123"
}
```

### 固件拉取回复消息
**Topic:** `/{productId}/{deviceId}/firmware/pull/reply`

**Payload:**
```json
{
  "status": "success",
  "firmware_url": "http://localhost:8000/firmware/test.bin",
  "version": "1.0.0",
  "release_date": "2024-12-20",
  "description": "最新固件版本"
}
```

### 简化测试消息
**Topic:** `/{productId}/{deviceId}/firmware/upgrade`

**Payload:**
```json
{
  "firmware_url": "http://localhost:8000/firmware/test.bin"
}
```

## 🔧 MQTTX配置

### 连接设置
- **Host:** 127.0.0.1
- **Port:** 1883
- **Client ID:** mqttx_test_client
- **Username:** (留空)
- **Password:** (留空)

### 发布设置
- **Topic:** `/{productId}/{deviceId}/firmware/upgrade`
- **QoS:** 1
- **Payload:** 使用上面的JSON格式

## 📋 测试步骤

1. **启动服务器**
   ```bash
   python firmware_server.py
   ```
   - 服务器将在 http://localhost:8000 启动
   - 自动打开浏览器显示固件列表

2. **启动Lua客户端**
   ```bash
   lua test.lua
   ```
   - 连接到MQTT broker
   - 订阅固件相关主题

3. **发送测试消息**
   - 打开MQTTX
   - 连接到本地MQTT broker
   - 发布包含固件URL的消息

4. **验证下载**
   - 检查Lua客户端控制台输出
   - 确认固件文件已下载到luademo目录

## 🎯 预期结果

### Lua客户端输出示例：
```
==================================================
Message received - Topic: /{productId}/{deviceId}/firmware/upgrade
JSON parsing successful
Message content:
--------------------
firmware_url: http://localhost:8000/firmware/test.bin
version: 1.0.0
description: 测试固件包
--------------------
🔍 检测到固件下载URL: http://localhost:8000/firmware/test.bin
******************************
🔄 开始下载固件...
📍 下载URL: http://localhost:8000/firmware/test.bin
📁 保存路径: e:\Dev\Lua\luademo\test.bin
✅ 固件下载成功!
📦 文件名: test.bin
📏 文件大小: 1.23 KB
💾 保存位置: e:\Dev\Lua\luademo\test.bin
🎉 固件下载流程完成!
📋 下载详情:
   - 文件名: test.bin
   - 文件大小: 1.23 KB
   - 保存路径: e:\Dev\Lua\luademo\test.bin
******************************
==================================================
```

### Python服务器输出示例：
```
📥 固件下载请求: test.bin - 2024-12-20 10:30:45
```

## 🔍 故障排除

### 常见问题

1. **HTTP请求失败**
   - 检查固件服务器是否运行
   - 确认URL格式正确
   - 检查网络连接

2. **文件保存失败**
   - 检查目录权限
   - 确认磁盘空间充足

3. **MQTT连接失败**
   - 确认MQTT broker运行
   - 检查连接参数

### 调试技巧

1. **查看详细日志**
   - Lua客户端会显示详细的下载过程
   - Python服务器会记录下载请求

2. **验证文件完整性**
   - 比较下载文件与原文件大小
   - 检查文件内容

## 📁 文件结构

```
e:\Dev\Lua\
├── luademo\
│   ├── test.lua          # MQTT客户端（已修改支持固件下载）
│   └── test.bin          # 下载的固件文件
└── pydemo\
    ├── firmware_server.py # 固件下载服务器
    └── test.bin          # 原始固件文件
```