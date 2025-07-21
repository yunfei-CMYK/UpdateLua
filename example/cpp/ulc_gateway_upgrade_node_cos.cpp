/************************************************************************/
/* 升级324、泰凌微
/************************************************************************/
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <map>

#include "hloop.h"
#include "hsocket.h"
#include "hssl.h"

#include "common/hv_common.h"
#include "common/udp_client.h"

#include "custom_os.h"
#include "ulc_app_inc.h"
#include "util.h"
#include "tdr_value_util.h"
#include "tdr_buf.h"
#include "sm4.h"

#include "apdu.h"
#include "patrol_data_record.h"
#include "ulc_driver_protocol_apdu.h"
#include "ulc_driver_protocol_common.h"
#include "ulc_driver_protocol_def.h"
#include "ulc_driver_protocol_tlv_package.h"
#include "ulc_gateway_apdu_cmd.h"

#include "ulc_app_upgrade_def.h"
#include "ulc_gateway_upgrade_node_cos_bitmap.h"
#include "ulc_gateway_upgrade_node_cos.h"

#define DEFAULT_APDU_RESP_LEN 2000

static std::map<unsigned short, unsigned char> s_upgrade_dev_addr;

#if 1

//------------------------------------根据实际情况修改------------------------------------
// 如果升级包前面包含loader数据，需要调过；如果不包含，该值设置为0
static unsigned int BootloaderSize = 0x2000;

//复用逻辑改片内
static unsigned int SPIFlashEraseUnitSize = 0x1000;

//片内可用512K-0X5000 = 492k
//片内备份起始地址0x5000 + 492/2 = 266k
// 和升级文件大小有关，如果升级文件大，需要增大备份区，将FWBackupAddr的值前移
static unsigned int FWBackupAddr = 0x50000;			//片内flash

//------------------------------------根据实际情况修改------------------------------------

const static unsigned char FlashFWEnable = 0x01;

const static unsigned char *userKey = (const unsigned char *)"\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x12\x34";
const static unsigned char *macPadding = (const unsigned char *)"\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10\x10";

const static unsigned int FixDataLgth = 0x100;

const static unsigned char * TagString = (const unsigned char *)"Tendyron";

typedef int(*_parse_resp_cb)(unsigned char *resp, unsigned int resp_len);

// TODO xll 声光警报器等其他设备
static unsigned char _conv_pack_type_to_broadcast_hw_type(unsigned int pack_type)
{
    unsigned char hw_type = 0;
    switch (pack_type)
    {
    case UPGRADE_PACK_TYPE_GATEWAY_BASE_324:
        hw_type = HW_LOOP_GATE_V001A;
        break;
    case UPGRADE_PACK_TYPE_ULC_SMOKE:
        hw_type = HW_YG_324_V001;
        break;
    case UPGRADE_PACK_TYPE_ULC_IO:
        hw_type = HW_IN_OUT_324_V001A;
        break;
    case UPGRADE_PACK_TYPE_ULC_SHOUBAO:
        hw_type = HW_ULC_CLARM_V001A;
        break;
    case UPGRADE_PACK_TYPE_ULC_XIAOBAO:
        hw_type = 0;
        break;
    case UPGRADE_PACK_TYPE_ULC_TEMPRATURE:
        hw_type = HW_WG_324_V001;
        break;
    default:
        break;
    }

    return hw_type;
}

static int _parse_resp_breakppint(unsigned char *resp, unsigned int resp_len)
{
    if (resp_len < 4)
    {
        return 0;
    }

    unsigned int breakpoint = tdr_value_util_uint32_from_bytes(resp);
    
    return (int)breakpoint;
}

// 发送给网关自己的324
static int _send_apdu_to_gateway_324(ulc_dev_module_role_type role_type, _parse_resp_cb cb, unsigned char *cmd, unsigned int cmd_len)
{
    unsigned short dev_addr = ulc_logic_addr_to_gateway;

    unsigned char *resp = (unsigned char *)malloc(DEFAULT_APDU_RESP_LEN);
    
    int ret = ulc_apdu_wrapper(dev_addr,
        role_type,
        ulc_dev_addr_type_node_addr,
        ulc_pack_end_flag_1,
        ulc_cmd_resp_flag_has,
        cmd, cmd_len,
        resp, DEFAULT_APDU_RESP_LEN, NULL);
    if (ret < 0)
    {
        free(resp);
        LogPrintError("upgrade apdu error, addr: %X, code: %X", dev_addr, ret);
        return ret;
    }

    ret = ulc_apdu_check_response(resp, (unsigned int)ret);
    if (ret < 0)
    {
        free(resp);
        LogPrintError("upgrade apdu error, addr: %X, code: %X", dev_addr, ret);
        return ret;
    }

    if (cb)
    {
        ret = cb(resp, ret);
    }

    free(resp);

    return ret;
}

static int _send_apdu_to_ulc_node(ulc_dev_module_role_type role_type, unsigned short dev_addr, unsigned char* cmd, unsigned int cmd_len)
{
    unsigned char* resp = (unsigned char*)malloc(100);

    int ret = ulc_gateway_cmd_with_group(dev_addr,
        role_type,
        ulc_dev_addr_type_node_addr,
        ulc_pack_end_flag_1,
        ulc_cmd_resp_flag_has,
        cmd, cmd_len,
        resp, 100);
    if (ret < 0)
    {
        free(resp);
        LogPrintError("upgrade apdu error, addr: %X, code: %X", dev_addr, ret);
        return ret;
    }

    ret = ulc_apdu_check_response(resp, (unsigned int)ret);
    if (ret < 0)
    {
        free(resp);
        LogPrintError("upgrade apdu error, addr: %X, code: %X", dev_addr, ret);
        return ret;
    }

    free(resp);

    return ret;
}

static int _get_smallest_breakpoint_form_tlv(p_music_tlv_package_tlv_st *ppst, unsigned int st_count)
{
    unsigned int min_breakpoint = 0xFFFFFFFF;

    for (unsigned int index = 0; index < st_count; index++)
    {
        p_music_tlv_package_tlv_st pst = ppst[index];
        if (pst == NULL || pst->data == NULL)
        {
            LogPrintError("pst == NULL || pst->data_len == 0 || pst->data == NULL error: %X", APP_ERROR_TLV_PACKAGE_PARSE_TLV_VALUE);
            break;
        }

        if (pst->data_len < 4)
        {
            LogPrintError("pst->data_len == %d error: %X", pst->data_len, APP_ERROR_TLV_PACKAGE_PARSE_TLV_VALUE);
            break;
        }

        unsigned int breakpoint = tdr_value_util_uint32_from_bytes(pst->data);
        if (breakpoint < min_breakpoint)
        {
            min_breakpoint = breakpoint;
        }
    }

    return (min_breakpoint == 0xFFFFFFFF ? 0 : (int)min_breakpoint);
}

static int _broadcast_upgrade_apdu(unsigned char dev_type, unsigned char *cmd, unsigned int cmd_len, _parse_tlv_resp_cb cb)
{
    return ulc_driver_protocol_tlv_package_broadcast(dev_type, cmd, cmd_len, cb);
}

static int _send_apdu_to_324(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type,
    _parse_tlv_resp_cb tlv_cb, _parse_resp_cb cb,
    unsigned char *cmd, unsigned int cmd_len)
{
    if (devAddr == ulc_logic_addr_to_gateway)
    {
        return _send_apdu_to_gateway_324(role_type, cb, cmd, cmd_len);
    } 
    else
    {
        unsigned char dev_type = role_type | (hw_type << 3);
        return _broadcast_upgrade_apdu(dev_type, cmd, cmd_len, tlv_cb);
    }
}

static void _EraseSPIFlash(ulc_dev_module_role_type role_type)
{
    for (auto it = s_upgrade_dev_addr.rbegin(); it != s_upgrade_dev_addr.rend(); ++it)
    {
        unsigned short devAddr = it->first;
        if (_send_apdu_to_ulc_node(role_type, devAddr, (unsigned char *)"\xFC\xDE\x00\x00\x00", 5) < 0)
        {
            LogPrintError("_EraseSPIFlash fail: %d", devAddr);
        }
    }
}

// 读断点续传位置
static unsigned int _ReadBreakPoint(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned int SPIFlashAddr)
{
    LogPrintInfo("_ReadBreakPoint begin devAddr: %hX\n", devAddr);

    int ret = -1;

    ret = _send_apdu_to_324(hw_type, devAddr, role_type, _get_smallest_breakpoint_form_tlv, _parse_resp_breakppint, (unsigned char *)"\xFC\xDD\x00\x00\x04", 5);

    LogPrintInfo("_ReadBreakPoint end offset: %d", ret);
    return (unsigned int)ret;
}

#if 0
//擦除 SPI Flash 固件备份区
static int _EraseSPIFlash(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned int EraseFlashSize)
{
    LogPrintInfo("_EraseSPIFlash begin#####\n");

    int ret = -1;

    unsigned char cmd[15];
    memcpy(cmd, "\xFC\xD9\x04\x00\x08", 5);

    //cduan:20230315适配plc，备份区擦除分批，控制单条apdu处理时间，以免超时失败
    unsigned int offset;
    for (offset = FWBackupAddr; offset + 0X8000 < FWBackupAddr + EraseFlashSize; offset += 0X8000)
    {
        tdr_value_util_uint32_to_bytes(offset, cmd + 5);
        tdr_value_util_uint32_to_bytes(0X8000, cmd + 9);
        ret = _send_apdu_to_324(hw_type, devAddr, role_type, NULL, NULL, cmd, 13);
        if (ret <= 0)
        {
            break;
        }
    }

    tdr_value_util_uint32_to_bytes(offset, cmd + 5);
    tdr_value_util_uint32_to_bytes(FWBackupAddr + EraseFlashSize - offset, cmd + 9);
    ret = _send_apdu_to_324(hw_type, devAddr, role_type, NULL, NULL, cmd, 13);

    LogPrintInfo("_EraseSPIFlash end##### ret: %d\n", ret);
    return ret;
}

static int _ReadSPIFlash(unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned char* crc, unsigned int offset, unsigned char* buf, unsigned int bufLen)
{
    LogPrintDebug("_ReadSPIFlash devAddr: %hX, offset: %d\n", devAddr, offset);
    char szIp[20];
    unsigned short realAddr = GetOriginalDevAddr(devAddr, szIp, sizeof(szIp));

    unsigned char cmd[20] = { 0 };

    cmd[0] = CTRL_CENTER_CMD_TYPE_BLOCK_TRANS;
    cmd[1] = (unsigned char)((realAddr >> 8) & 0x00FF);
    cmd[2] = (unsigned char)(realAddr & 0x00FF);

    memcpy(cmd + 3, "\xFC\xD9\x02\x00\x08", 5);

    cmd[8] = (unsigned char)(FixDataLgth / 256);
    cmd[9] = (unsigned char)(FixDataLgth % 256);

    tdr_value_util_uint32_to_bytes(offset, cmd + 10);

    memcpy(cmd + 14, crc, 2);

    int ret = SendGatewayApduAndRecv(cmd, 16, szIp, buf, bufLen);

    LogPrintDebug("_ReadSPIFlash end ret: %d\n", ret);
    return ret;
}
#endif

static int _EraseSPIFlash()
{
}

static int _WriteSPIFlash(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned int offset, unsigned char *data, unsigned int dataLen)
{
    LogPrintDebug("_WriteSPIFlash begin devAddr: %hX, offset: %d(%X)\n", devAddr, offset, offset);

    unsigned int totalLen = dataLen + 15;

    unsigned char *cmd = (unsigned char *)malloc(totalLen);

    memcpy(cmd, "\xFC\xDB\x00\x00\x00", 5);

    cmd[5] = (unsigned char)((dataLen + 8) / 256);
    cmd[6] = (unsigned char)((dataLen + 8) % 256);

    tdr_value_util_uint16_to_bytes(dataLen, cmd + 7);
    tdr_value_util_uint32_to_bytes(offset, cmd + 9);

    unsigned char crc[2];
    calc_crc_16(data, dataLen, crc);
    memcpy(cmd + 13, crc, 2);

    memcpy(cmd + 15, data, dataLen);

    int ret = _send_apdu_to_324(hw_type, devAddr, role_type, NULL, NULL, cmd, totalLen);
    if (ret < 0)
    {
        LogPrintError("_WriteSPIFlash error: %d", ret);
    }

    free(cmd);

    LogPrintDebug("_WriteSPIFlash end ret: %d\n", ret);
    return ret;
}

static int _DoUpgrade324Cmd(unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned char *data, unsigned int dataLen)
{
    LogPrintDebug("_DoUpgrade324Cmd begin devAddr: %hX\n", devAddr);

    unsigned char *cmd = (unsigned char *)malloc(dataLen + 20);

    memcpy(cmd, "\xFC\xFE\x00\x00\x00", 5);

    cmd[4] = (unsigned char)(dataLen);

    memcpy(cmd + 5, data, dataLen);

    int ret = _send_apdu_to_ulc_node(role_type, devAddr, cmd, dataLen + 5);
    if (ret < 0)
    {
        LogPrintError("_DoUpgrade324Cmd error: %d", ret);
    }

    free(cmd);

    LogPrintDebug("_DoUpgrade324Cmd end ret: %d\n", ret);
    return ret;
}

static int _SM4_ecb_encrypt(const unsigned char *in, unsigned char *out,
    const unsigned long length, const SM4_KEY *key, const int enc)
{
    if (key == NULL)
    {
        return -1;
    }
    if (length % SM4_BLOCK_SIZE != 0)
    {
        return -1;
    }

    for (unsigned long offset = 0; offset < length; offset += SM4_BLOCK_SIZE)
    {
        SM4_ecb_encrypt(in + offset, out + offset, key, enc);
    }

    return 0;
}

static int _CalcMac(SM4_KEY *sm4Key, unsigned char *cosData, unsigned int cosLen, unsigned char *buf, unsigned int bufLen)
{
    if (sm4Key == NULL || cosData == NULL || buf == NULL || bufLen < SM4_BLOCK_SIZE)
    {
        return -1;
    }
    unsigned char iv[16] = { 0 };
    unsigned char *tmpData = (unsigned char*)malloc(cosLen + 16);

    SM4_cbc_encrypt(cosData, tmpData, cosLen, sm4Key, iv, SM4_ENCRYPT);
    memcpy(iv, tmpData + cosLen - SM4_BLOCK_SIZE, SM4_BLOCK_SIZE);

    SM4_cbc_encrypt(macPadding, tmpData, SM4_BLOCK_SIZE, sm4Key, iv, SM4_ENCRYPT);
    memcpy(buf, tmpData, SM4_BLOCK_SIZE);

    free(tmpData);

    return 0;
}

static int _CheckCrc(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned char *crc, unsigned int SPIFlashAddr, unsigned int srcLen)
{
    LogPrintDebug("_CheckCrc begin devAddr: %hX\n", devAddr);

    unsigned char cmd[20] = { 0 };

    memcpy(cmd, "\xFC\xDA\x00\x00\x08", 5);

    tdr_value_util_uint16_to_bytes(srcLen, cmd + 5);
    tdr_value_util_uint32_to_bytes(SPIFlashAddr, cmd + 7);

    memcpy(cmd + 11, crc, 2);

    int ret = _send_apdu_to_324(hw_type, devAddr, role_type, NULL, NULL, cmd, 13);
    if (ret < 0)
    {
        LogPrintError("apdu error: %d", ret);
    }

    LogPrintDebug("_CheckCrc end ret: %d\n", ret);
    return ret;
}

static int _WriteCosBlockData(unsigned int packType, unsigned short devAddr, ulc_dev_module_role_type role_type, SM4_KEY* sm4Key, 
    unsigned char* cosData, unsigned int FileOffset, unsigned int SPIFlashAddr, unsigned int blockLen)
{
    int ret = -1;

    unsigned char* tmpData = (unsigned char*)malloc(blockLen + 16);

    unsigned char hw_type = _conv_pack_type_to_broadcast_hw_type(packType);

    unsigned char* plain = cosData + FileOffset;

    if (check_upgrade_pack_is_324(packType) == 1)
    {
        _SM4_ecb_encrypt(plain, tmpData, blockLen, sm4Key, SM4_ENCRYPT);
    }
    else  // 泰凌微
    {
        memcpy(tmpData, plain, blockLen);
    }

    ret = _WriteSPIFlash(hw_type, devAddr, role_type, SPIFlashAddr, tmpData, blockLen);

#if 0
    //校验CRC，验证写入数据是否正确
    unsigned char crc[2];
    calc_crc_16(tmpData, FixDataLgth, crc);
    ret = _CheckCrc(hw_type, devAddr, role_type, crc, SPIFlashAddr, FixDataLgth);
    if (ret < 0)
    {
        break;
    }
#endif

    free(tmpData);

    return ret;
}

static bool _retry_broadcast_by_bitmap(unsigned int packType, unsigned short devAddr, ulc_dev_module_role_type role_type, SM4_KEY* sm4Key, unsigned char* cosData)
{
    bool has_success = true;
    // 读bitmap重发
    for (int retry_count = 0; retry_count < 5; retry_count++)
    {
        LogPrintDebug("_retry_broadcast_by_bitmap retry_count: %d", retry_count);
        // 获取bitmap
        unsigned char bitmap[100] = { 0 };
        int block_count = ulc_gateway_upgrade_cos_get_bitmap(packType, role_type, bitmap, sizeof(bitmap));
        if (block_count < 0)
        {
            continue;
        }

        // 根据bitmap广播缺包
        int byte_len = block_count / 8 + (block_count % 8 ? 1 : 0);
        unsigned short block_index = 0; // 遍历bitmap时不能超过最大分包数
        has_success = true; // 如果bitmap每位都是1，代表广播已经成功，退出重试过程
        for (size_t n = 0; n < byte_len; n++) 
        {
            if (block_index >= block_count)
            {
                break;
            }
            char c = bitmap[n];
            if (c == 0xFF)
            {
                block_index += 8;
                continue;
            }
            // 遍历字符的8个位(从最高位到最低位)
            for (int j = 7; j >= 0; j--, block_index++)
            {
                if (block_index >= block_count)
                {
                    break;
                }
                if (((c >> j) & 1) == 1)    // 1代表COS已收到对应分包，0代表没收到
                {
                    continue;
                }
                p_upgrade_block_info_st pst = ulc_gateway_upgrade_cos_block_get(block_index);
                if (pst == NULL)
                {
                    continue;
                }
                _WriteCosBlockData(packType, devAddr, role_type, sm4Key,
                    cosData, pst->FileOffset, pst->SPIFlashAddr, pst->blockLen);
                has_success = false;
            }
        }
        if (has_success)
        {
            break;
        }
    }

    LogPrintDebug("_retry_broadcast_by_bitmap end has_success: %d", has_success);
    return has_success;
}

static void _ulc_upgrade_dev_cb(unsigned short dev_addr, unsigned char dev_type, bool is_online, unsigned char state, void* param)
{
    if (!is_online)
    {
        LogPrintWarn("_ulc_upgrade_dev_cb dev offline: %hd", dev_addr);
        return;
    }
    else if (state != 0)
    {
        LogPrintWarn("_ulc_upgrade_dev_cb dev state: %hd, dev_addr: %hd", state, dev_addr);
        return;
    }

    // 只读取要升级的类型的设备
    if (*(unsigned char*)param == dev_type)
    {
        s_upgrade_dev_addr[dev_addr] = 1;
    }
}

static int _WriteCosData(unsigned int packType, unsigned short devAddr, ulc_dev_module_role_type role_type, SM4_KEY *sm4Key, 
    unsigned char *cosData, unsigned int cosLen,
    unsigned int FileOffset, unsigned int SPIFlashAddr)
{
    LogPrintInfo("_WriteCosData begin\n");
    if (cosData == NULL)
    {
        return -1;
    }

    int ret = -1;
    unsigned short index = 0;

    LogPrintInfo("_WriteCosData FileOffset: %d, cosLen: %d, to writelen: %d\n", FileOffset, cosLen, cosLen - FileOffset);
    for (; FileOffset < cosLen; FileOffset += FixDataLgth)
    {
        LogPrintInfo("_WriteCosData file offset: %d\n", FileOffset);
        ret = _WriteCosBlockData(packType, devAddr, role_type, sm4Key,
            cosData, FileOffset, SPIFlashAddr, FixDataLgth);
        if (ret < 0)
        {
            LogPrintError("_WriteCosBlockData index: %d, ret: %d(%X)", index, ret, ret);
        }

        upgrade_block_info_st info_st = { FileOffset, SPIFlashAddr, FixDataLgth };
        ulc_gateway_upgrade_cos_block_add(index++, &info_st);

        SPIFlashAddr += FixDataLgth;

        custom_os_sleep(6);     // 等待写flash操作
    }

    bool has_success = _retry_broadcast_by_bitmap(packType, devAddr, role_type, sm4Key, cosData);
    if (has_success)
    {
        ret = 0;
    }
    else
    {
        LogPrintError("_WriteCosData fail after retry by bitmap");
        ret = -1;
    }

    ulc_gateway_upgrade_cos_block_clear();

    LogPrintDebug("_WriteCosData end, ret: %d", ret);
    return ret;
}

static int _BuildBaseCommandInfo(unsigned int cosLen, unsigned char *fwMac, unsigned char *buf, unsigned int bufSize)
{
    unsigned int offset = 0;

    unsigned int FWUpdategAddr = 0x00005000; // /*NationZ boot0x3000*/

    unsigned char command[100];
    memset(command, 0, sizeof(command));

    offset += strlen((const char*)TagString);
    memcpy(command, TagString, offset);

    tdr_value_util_uint32_to_bytes(cosLen, command + offset);
    offset += 4;

    tdr_value_util_uint32_to_bytes(FWBackupAddr, command + offset);
    offset += 4;

    tdr_value_util_uint32_to_bytes(FWUpdategAddr, command + offset);
    offset += 4;

    offset += 8;
    offset += 8;
    offset += 4;
    offset += 4;

    command[offset] = FlashFWEnable;
    offset += 1;
    offset += 1;

    command[offset] = 0xAA;
    offset += 1;

    command[offset] = 0x00;
    offset += 1;

    memcpy(command + offset, userKey, SM4_BLOCK_SIZE);
    offset += SM4_BLOCK_SIZE;

    memcpy(command + offset, fwMac, SM4_BLOCK_SIZE);
    offset += SM4_BLOCK_SIZE;

    if (bufSize < offset)
    {
        return -1;
    }

    memcpy(buf, command, offset);
    return offset;
}

static int _DoUpgrade324(unsigned short devAddr, ulc_dev_module_role_type role_type, SM4_KEY *sm4Key, unsigned int cosLen, unsigned char *fwMac)
{
    LogPrintInfo("_DoUpgrade324 begin");
    if (sm4Key == NULL || fwMac == NULL)
    {
        return -1;
    }

    unsigned char buf[120] = { 0 };
    int commandLen = _BuildBaseCommandInfo(cosLen, fwMac, buf, sizeof(buf));

    unsigned char commandMac[SM4_BLOCK_SIZE];
    unsigned char iv[16] = { 0 };

    unsigned char *tmpData = (unsigned char *)malloc(commandLen + 16);

    SM4_cbc_encrypt(buf, tmpData, commandLen, sm4Key, iv, SM4_ENCRYPT);
    memcpy(iv, tmpData + commandLen - SM4_BLOCK_SIZE, SM4_BLOCK_SIZE);

    SM4_cbc_encrypt(macPadding, tmpData, SM4_BLOCK_SIZE, sm4Key, iv, SM4_ENCRYPT);
    memcpy(commandMac, tmpData, SM4_BLOCK_SIZE);
    free(tmpData);

    memcpy(buf + commandLen, commandMac, SM4_BLOCK_SIZE);

    int ret = -1;
    // 从最后面的开始升级
    for (auto it = s_upgrade_dev_addr.rbegin(); it != s_upgrade_dev_addr.rend(); ++it)
    {
        ret = _DoUpgrade324Cmd(devAddr, role_type, buf, commandLen + SM4_BLOCK_SIZE);
        if (ret < 0)
        {
            LogPrintError("_DoUpgrade324Cmd fail, ret: %d(%X)", ret, ret);
        }
    }

    LogPrintInfo("_DoUpgrade324 end ret: %d", ret);
    return ret;
}

static int _StartUpgradeTelink(unsigned char hw_type, unsigned short devAddr, ulc_dev_module_role_type role_type, unsigned char uploadId, unsigned int FWSize)
{
    LogPrintInfo("_StartUpgradeTelink devAddr: %hX, FWSize: %d(%X)\n", devAddr, FWSize, FWSize);

    unsigned char cmd[20] = { 0 };

    memcpy(cmd, "\x00\xE0\x10\x00\x05", 5);

    cmd[5] = uploadId;

    tdr_value_util_uint32_to_bytes(FWSize, cmd + 6);

    int ret = _send_apdu_to_324(hw_type, devAddr, role_type, NULL, NULL, cmd, 10);
    if (ret < 0)
    {
        LogPrintError("_send_apdu_to_324 error: %d", ret);
    }

    LogPrintInfo("_StartUpgradeTelink end ret: %d\n", ret);
    return ret;
}

static int _DoUpgradeTelink(unsigned short devAddr, ulc_dev_module_role_type role_type)
{
    LogPrintInfo("_DoUpgradeTelink devAddr: %hX\n", devAddr);

    int ret = -1;
    // 从最后面的开始升级
    for (auto it = s_upgrade_dev_addr.rbegin(); it != s_upgrade_dev_addr.rend(); ++it)
    {
        ret = _send_apdu_to_ulc_node(role_type, devAddr, (unsigned char *)"\x00\xE0\x13\x00\x00", 5);
        if (ret < 0)
        {
            LogPrintError("_DoUpgradeTelink fail, ret: %d(%X)", ret, ret);
        }
    }

    LogPrintInfo("_DoUpgradeTelink end ret: %d\n", ret);
    return ret;
}

static unsigned char *_PreProcessData(unsigned char *data, unsigned int dataLen, unsigned int *pTotalLen)
{
    unsigned char *totalData;
    // 数据预处理，补位
#if 0
    if (dataLen % 0x400 != 0)
    {
        // 补齐至1k整数倍（需要包含芯片自带的0x4000loader）
    }
#endif
    unsigned int totalLen = (dataLen + SPIFlashEraseUnitSize - 1) & ~(SPIFlashEraseUnitSize - 1);
    totalData = (unsigned char*)malloc(totalLen);
    memcpy(totalData, data, dataLen);
    LogPrintInfo("_PreProcessData totalLen: %d, dataLen: %d\n", totalLen, dataLen);
    if (totalLen > dataLen)
    {
        memset(totalData + dataLen, 0xFF, totalLen - dataLen);
    }

    *pTotalLen = totalLen;
    return totalData;
}

int upgrade_ulc_dev_telink(unsigned int pack_type, unsigned short dev_addr, ulc_dev_module_role_type role_type, unsigned char *data, unsigned int data_len)
{
    if (data == NULL)
    {
        return NULL;
    }

    LogPrintInfo("upgrade_ulc_dev_telink begin dev_addr: %hX, data_len: %d(0x%x)\n", dev_addr, data_len, data_len);

    //保证文件大小大于一个page让下载逻辑能够顺利进行，且不会覆盖BL区域
    if (data_len > (0x7F000))
    {
        LogPrintError("upgrade_ulc_dev_telink data_len error: %hx\n", data_len);
        return -1;
    }

    int ret;

    unsigned char hw_type = _conv_pack_type_to_broadcast_hw_type(pack_type);

    unsigned int totalLen = 0;
    unsigned char *totalData = _PreProcessData(data, data_len, &totalLen);

    ret = _StartUpgradeTelink(hw_type, dev_addr, role_type, 1, totalLen);
    if (ret < 0)
    {
        free(totalData);
        LogPrintError("_StartUpgradeTelink error, ret: %d\n", ret);
        return -1;
    }

    unsigned int SPIFlashAddr = FWBackupAddr;

    // 读断点续传位置
    //unsigned int breakPoint = _ReadBreakPoint(hw_type, dev_addr, role_type, SPIFlashAddr);
    unsigned int breakPoint = 0;
    if (breakPoint >= totalLen)
    {
        free(totalData);
        LogPrintError("upgrade_ulc_dev_telink _ReadBreakPoint error, breakPoint: %d\n", breakPoint);
        return -2;
    }

    s_upgrade_dev_addr.clear();
    unsigned char dev_type = ulc_gateway_upgrade_cos_conv_pack_type(pack_type);
    ulc_patrol_dev_process(_ulc_upgrade_dev_cb, &dev_type);

    // 先擦除，防止存在垃圾数据
    _EraseSPIFlash(role_type);

    unsigned int FileOffset = breakPoint;
    SPIFlashAddr += breakPoint;

    ret = _WriteCosData(pack_type, dev_addr, role_type, NULL, totalData, totalLen, FileOffset, SPIFlashAddr);

    free(totalData);

    if (ret < 0)
    {
        s_upgrade_dev_addr.clear();
        LogPrintError("upgrade_ulc_dev_telink _WriteCosData error, ret: %d\n", ret);
        return ret;
    }

    ret = _DoUpgradeTelink(dev_addr, role_type);
    if (ret < 0)
    {
        s_upgrade_dev_addr.clear();
        LogPrintError("Upgrade324COS _DoUpgradeTelink error, ret: %d\n", ret);
        return ret;
    }

    s_upgrade_dev_addr.clear();
    LogPrintInfo("upgrade_ulc_dev_telink end, ret: %d\n", ret);
    return ret;
}

int upgrade_ulc_dev_324_cos(unsigned int pack_type, unsigned short dev_addr, ulc_dev_module_role_type role_type, unsigned char *data, unsigned int data_len)
{
    if (data == NULL)
    {
        return NULL;
    }

    LogPrintInfo("upgrade_ulc_dev_324_cos begin dev_addr: %hX, data_len: %d(0x%x)\n", dev_addr, data_len, data_len);
    //保证文件大小大于一个page让下载逻辑能够顺利进行，且不会覆盖BL区域
    if (data_len < BootloaderSize || data_len >(0x7F000 - BootloaderSize))
    {
        LogPrintError("upgrade_ulc_dev_324_cos data_len error: %hx\n", data_len);
        return -1;
    }

    // 跳过升级包的bootloader部分
    data = data + BootloaderSize;
    data_len = data_len - BootloaderSize;

    unsigned char hw_type = _conv_pack_type_to_broadcast_hw_type(pack_type);

    int ret;

    SM4_KEY sm4Key;
    const int bits = 128;
    ret = SM4_set_key(userKey, bits, &sm4Key);
    if (ret < 0)
    {
        LogPrintError("upgrade_ulc_dev_324_cos SM4_set_key error, ret: %d\n", ret);
        return ret;
    }

    unsigned int SPIFlashAddr = FWBackupAddr;

    unsigned int totalLen = 0;
    unsigned char *totalData = _PreProcessData(data, data_len, &totalLen);

    unsigned char fwMac[16] = { 0 };

    //计算升级包明文MAC
    _CalcMac(&sm4Key, totalData, totalLen, fwMac, sizeof(fwMac));

    // 读断点续传位置
    //unsigned int breakPoint = _ReadBreakPoint(hw_type, dev_addr, role_type, SPIFlashAddr);
    unsigned int breakPoint = 0;
    if (breakPoint >= totalLen)
    {
        free(totalData);
        LogPrintError("upgrade_ulc_dev_324_cos _ReadBreakPoint error, breakPoint: %d\n", breakPoint);
        return -2;
    }

    s_upgrade_dev_addr.clear();
    unsigned char dev_type = ulc_gateway_upgrade_cos_conv_pack_type(pack_type);
    ulc_patrol_dev_process(_ulc_upgrade_dev_cb, &dev_type);

    // 先擦除，防止存在垃圾数据
    _EraseSPIFlash(role_type);

    unsigned int FileOffset = breakPoint;
    SPIFlashAddr += breakPoint;

    ret = _WriteCosData(pack_type, dev_addr, role_type, &sm4Key, totalData, totalLen, FileOffset, SPIFlashAddr);

    free(totalData);

    if (ret < 0)
    {
        s_upgrade_dev_addr.clear();
        LogPrintError("upgrade_ulc_dev_324_cos _WriteCosData error, ret: %d\n", ret);
        return ret;
    }

    ret = _DoUpgrade324(dev_addr, role_type, &sm4Key, totalLen, fwMac);
    if (ret < 0)
    {
        s_upgrade_dev_addr.clear();
        LogPrintError("Upgrade324COS _StartUpgrade324 error, ret: %d\n", ret);
        return ret;
    }

    s_upgrade_dev_addr.clear();
    LogPrintInfo("upgrade_ulc_dev_324_cos end, ret: %d\n", ret);
    return ret;
}

unsigned char check_upgrade_pack_is_324(unsigned int pack_type)
{
    if (pack_type < UPGRADE_PACK_TYPE_ULC_NODE_BLE_BASE || pack_type > UPGRADE_PACK_TYPE_ULC_NODE_MAX)    // 324
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

#endif