/************************************************************************/
/* 升级324、泰凌微
/************************************************************************/
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

#include "hloop.h"
#include "hsocket.h"
#include "hssl.h"
#include "hbuf.h"
#include "hthread.h"

#include "common/hv_common.h"
#include "common/udp_client.h"

#include "ulc_app_inc.h"
#include "util.h"
#include "tdr_value_util.h"
#include "tdr_buf.h"

#include "ulc_driver_protocol_common.h"
#include "ulc_driver_protocol_apdu.h"

#include "ulc_app_upgrade_def.h"
#include "ulc_app_upgrade_file.h"
#include "ulc_app_upgrade_mgr.h"
#include "ulc_gateway_upgrade_cam_app.h"
#include "ulc_gateway_upgrade_node_cos.h"
#include "ulc_gateway_upgrade_task.h"

static hloop_t *s_upgrade_loop = NULL;

static HTHREAD_ROUTINE(worker_thread) {
    hloop_t* loop = (hloop_t*)userdata;
    hloop_run(loop);
    hloop_free(&loop);

    return 0;
}

static p_upgrade_data_info_st _upgrade_info_st_create(unsigned short dev_addr, unsigned char node_type, 
    unsigned int pack_type, char *version,
    unsigned char *data, unsigned int len)
{
    p_upgrade_data_info_st pst = (p_upgrade_data_info_st)malloc(sizeof(upgrade_data_info_st));
    pst->dev_addr = dev_addr;
    pst->node_type = node_type;
    pst->pack_type = pack_type;
    pst->package_size = len;
    strncpy(pst->version, version, sizeof(pst->version));
    pst->data = (unsigned char *)malloc(len);
    memcpy(pst->data, data, len);
    return pst;
}

static void _upgrade_info_st_destroy(p_upgrade_data_info_st pst)
{
    if (pst == NULL)
    {
        return;
    }

    if (pst->data)
    {
        free(pst->data);
    }

    free(pst);
}

static void _distribute_upgrade_pack(p_upgrade_data_info_st pst)
{
    // TODO 调整类型定义

    int ret = -1;

    if (pst->pack_type >= UPGRADE_PACK_TYPE_ULC_SMOKE && pst->pack_type < UPGRADE_PACK_TYPE_ULC_NODE_BLE_BASE) // 节点324
    {
        // TODO 比较版本号
        // 地址FFFF代表手拉手广播带返回
        ret = upgrade_ulc_dev_324_cos(pst->pack_type, ulc_logic_addr_broadcast, ulc_dev_module_role_base_324, pst->data, pst->package_size);
    }
    else if (pst->pack_type >= UPGRADE_PACK_TYPE_ULC_NODE_BLE_BASE && pst->pack_type < UPGRADE_PACK_TYPE_ULC_NODE_MAX) // 节点泰凌微
    {
        ret = upgrade_ulc_dev_telink(pst->pack_type, ulc_logic_addr_broadcast, ulc_dev_module_role_base_324, pst->data, pst->package_size);
    }
    else if (pst->pack_type == UPGRADE_PACK_TYPE_GATEWAY_APP)// 网关APP
    {
        // TODO 比较版本号
        ret = ulc_app_upgrade_file_save(pst);
        if (ret < 0)
        {
            LogPrintError("ulc_app_upgrade_file_save error: %d", ret);
            return;
        }

        ulc_app_upgrade_file_start_upgrade(pst->pack_type);
    }
    else if (pst->pack_type == UPGRADE_PACK_TYPE_SMOKE_CAM_APP)// 烟感摄像头APP
    {
        // TODO 比较版本号
        ret = ulc_gateway_upgrade_cam_app(pst->dev_addr, pst->node_type, pst->pack_type, pst->version, pst->data, pst->package_size);
    }
    else if (pst->pack_type == UPGRADE_PACK_TYPE_GATEWAY_BASE_324)// 网关324
    {
        ret = upgrade_ulc_dev_324_cos(pst->pack_type, ulc_logic_addr_to_gateway, ulc_dev_module_role_base_324, pst->data, pst->package_size);
    }
    else if (pst->pack_type == UPGRADE_PACK_TYPE_GATEWAY_CORE_324)// 网关324
    {
        ret = upgrade_ulc_dev_324_cos(pst->pack_type, ulc_logic_addr_to_gateway, ulc_dev_module_role_core_324, pst->data, pst->package_size);
    }
    else
    {

    }
}

static void _upgrade_event_cb(hevent_t* ev) {
    (ev->userdata);
    p_upgrade_data_info_st pst = (p_upgrade_data_info_st)ev->privdata;

    _distribute_upgrade_pack(pst);

    _upgrade_info_st_destroy(pst);
}

int create_ulc_upgrade_task()
{
    s_upgrade_loop = hloop_new(HLOOP_FLAG_AUTO_FREE);
    if (s_upgrade_loop == NULL)
    {
        return -1;
    }

    int ret = hthread_create(worker_thread, s_upgrade_loop);

    return ret;
}

void release_ulc_upgrade_task()
{
    if (s_upgrade_loop == NULL)
    {
        return;
    }

    hloop_stop(s_upgrade_loop);
}

void ulc_upgrade_task_post_event(unsigned short dev_addr, unsigned char node_type, unsigned int pack_type, char *version, unsigned char *data, unsigned int len)
{
    p_upgrade_data_info_st pst = _upgrade_info_st_create(dev_addr, node_type, pack_type, version, data, len);

    hevent_t ev;
    memset(&ev, 0, sizeof(ev));
    ev.loop = s_upgrade_loop;
    ev.cb = _upgrade_event_cb;
    ev.userdata = NULL;
    ev.privdata = pst;
    hloop_post_event(s_upgrade_loop, &ev);
}