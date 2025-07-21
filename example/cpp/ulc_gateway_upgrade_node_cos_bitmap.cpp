/************************************************************************/
/* 升级324、泰凌微时，根据读取的bitmap做重发
/************************************************************************/
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unordered_map>
#include <vector>

#include "hloop.h"
#include "hsocket.h"
#include "hssl.h"

#include "common/hv_common.h"
#include "common/udp_client.h"

#include "ulc_app_inc.h"
#include "util.h"
#include "tdr_value_util.h"
#include "tdr_buf.h"

#include "apdu.h"
#include "patrol_data_record.h"
#include "ulc_app_upgrade_def.h"
#include "ulc_driver_protocol_apdu.h"
#include "ulc_gateway_apdu_cmd.h"

#include "ulc_gateway_upgrade_node_cos_bitmap.h"

static std::unordered_map<unsigned short, p_upgrade_block_info_st> s_upgrade_cos_block_info;
static std::vector<unsigned short> s_upgrade_cos_dev;

void ulc_gateway_upgrade_cos_block_add(unsigned short index, p_upgrade_block_info_st pst)
{
    if (s_upgrade_cos_block_info[index] != NULL)
    {
        delete s_upgrade_cos_block_info[index];
    }

    p_upgrade_block_info_st p_info = new upgrade_block_info_st;
    p_info->FileOffset = pst->FileOffset;
    p_info->SPIFlashAddr = pst->SPIFlashAddr;
    p_info->blockLen = pst->blockLen;

    s_upgrade_cos_block_info[index] = p_info;
}

void ulc_gateway_upgrade_cos_block_clear()
{
    for (auto iter: s_upgrade_cos_block_info)
    {
        p_upgrade_block_info_st p_info = iter.second;
        if (p_info == NULL)
        {
            continue;
        }

        delete p_info;
    }

    s_upgrade_cos_block_info.clear();
}

p_upgrade_block_info_st ulc_gateway_upgrade_cos_block_get(unsigned short index)
{
    return s_upgrade_cos_block_info[index];
}

unsigned char ulc_gateway_upgrade_cos_conv_pack_type(unsigned int pack_type)
{
    if (pack_type > UPGRADE_PACK_TYPE_ULC_NODE_MAX)
    {
        return 0;
    }

    return ((unsigned char)pack_type & 0x3F);
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
        s_upgrade_cos_dev.push_back(dev_addr);
    }
}

static void _bitwise_or(unsigned char* pa, unsigned char* pb, unsigned int len) {
    for (unsigned int i = 0; i < len; i++)
    {
        pa[i] = pa[i] | pb[i];
    }
}

int ulc_gateway_upgrade_cos_get_bitmap(unsigned int pack_type, ulc_dev_module_role_type role_type, unsigned char *buf, unsigned int max_buf_len)
{
    LogPrintDebug("ulc_gateway_upgrade_cos_get_bitmap begin");
    int ret = -1;

    int block_count = s_upgrade_cos_block_info.size();
    if (block_count == 0)
    {
        LogPrintError("ulc_gateway_upgrade_cos_get_bitmap empty block");
        return -1;
    }

    int byte_len = block_count / 8 + (block_count % 8 ? 1 : 0);
    int compare_len = byte_len;
    if (max_buf_len < byte_len)
    {
        LogPrintError("ulc_gateway_upgrade_cos_get_bitmap buf is short, block_count: %d, max_buf_len: %d", block_count, max_buf_len);
        return -2;
    }

    memset(buf, 0, byte_len);

    unsigned char dev_type = ulc_gateway_upgrade_cos_conv_pack_type(pack_type);
    ulc_patrol_dev_process(_ulc_upgrade_dev_cb, &dev_type);

    for (auto iter : s_upgrade_cos_dev)
    {
        unsigned short dev_addr = iter;
        LogPrintDebug("ulc_gateway_upgrade_cos_get_bitmap dev: %hd", dev_addr);

        unsigned char resp[100];
        unsigned int max_resp_len = sizeof(resp);

        ret = ulc_gateway_cmd_with_group(dev_addr,
            role_type,
            ulc_dev_addr_type_node_addr,
            ulc_pack_end_flag_1,
            ulc_cmd_resp_flag_has,
            (unsigned char *)"\xFC\xDF\x00\x00\x00", 5,
            resp, max_resp_len);
        if (ret < 0)
        {
            LogPrintError("ulc_gateway_upgrade_cos_get_bitmap apdu fail dev: %hd, ret: %d(%X)", dev_addr, ret, ret);
            continue;
        }

        ret = ulc_apdu_check_response(resp, ret);
        if (ret < 0)
        {
            LogPrintError("ulc_gateway_upgrade_cos_get_bitmap resp error dev: %hd, ret: %d(%X)", dev_addr, ret, ret);
            continue;
        }

        if (ret < compare_len)
        {
            compare_len = ret;
        }

        _bitwise_or(buf, resp, compare_len);
    }

    s_upgrade_cos_dev.clear();

    LogPrintDebug(HLOG_HEXDUMP_FMT, "ulc_gateway_upgrade_cos_get_bitmap end", buf, byte_len);

    return block_count;
}
