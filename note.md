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

|             |          |
| ----------- | -------- |
| **参数**      | **说明**   |
| `productId` | 产品ID     |
| `deviceId`  | 设备ID     |
| `version`   | 固件版本     |
| `url`       | 用于设备下载固件 |
