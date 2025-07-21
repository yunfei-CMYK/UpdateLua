/************************************************************************/
/* 升级摄像头应用
/************************************************************************/
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#include "hv/md5.h"

#include "ulc_app_inc.h"
#include "util.h"
#include "tdr_value_util.h"
#include "tdr_buf.h"

#include "ulc_driver_protocol_common.h"
#include "ulc_driver_protocol_stream.h"
#include "ulc_driver_protocol_stream_app_proto.h"
#include "ulc_app_fec_ack.h"
#include "ulc_app_fec_ack_protocol.h"

#include "ulc_app_upgrade_def.h"
#include "ulc_app_upgrade_mgr.h"

#include "ulc_gateway_upgrade_cam_app.h"

int ulc_gateway_upgrade_cam_app(unsigned short dev_addr, unsigned char node_type, unsigned int pack_type, char * version, unsigned char *data, unsigned int data_len)
{
    LogPrintInfo("ulc_gateway_upgrade_cam_app begin##### dev_addr: %hX, pack_type: %d(0x%x)\n", dev_addr, pack_type, pack_type);
    int ret = 0;
    unsigned short stream_channel = STREAM_CHANNEL_ID_DATA;

    unsigned int head_len = 0;
    p_upgrade_pack_info_st pst = ulc_app_upgrade_mgr_pack_st(pack_type, data_len, version, &head_len);

    // 开始升级，发送升级包信息
    ret = ulc_app_fec_ack_send(dev_addr, stream_channel, node_type, ulc_stream_app_header_type_upgrade_app_begin, 0, (unsigned char *)pst, head_len);
    ulc_app_upgrade_mgr_release_st(&pst);
    if (ret < 0)
    {
        LogPrintError("upgrade_app_begin error: %X", APP_ERROR_SEND_STREAM_DATA_FAIL);
        return -1;
    }

    for (unsigned int offset = 0; offset < data_len; )
    {
        unsigned int block_len = ULC_STREAM_PACK_BLOCK_LENGTH;
        if ((data_len - offset) <= ULC_STREAM_PACK_BLOCK_LENGTH)
        {
            block_len = data_len - offset;
        }

        int sendLen = ulc_app_fec_ack_send(dev_addr, stream_channel, node_type, ulc_stream_app_header_type_upgrade_app_update, 0, data + offset, block_len);
        LogPrintInfo("ulc_gateway_upgrade_cam_app sendLen: %d\n", sendLen);
        if (sendLen < 0)
        {
            LogPrintError("upgrade cam app send error: %X", APP_ERROR_SEND_STREAM_DATA_FAIL);
            break;
        }

        offset += block_len;

        custom_os_sleep(10);
    }

    // 结束升级，发送md5校验
    unsigned char digest[16];
    hv_md5(data, data_len, digest);

    ret = ulc_app_fec_ack_send(dev_addr, stream_channel, node_type, ulc_stream_app_header_type_upgrade_app_end, 0, digest, 16);

    LogPrintInfo("ulc_gateway_upgrade_cam_app end#####\n");
    return ret;
}