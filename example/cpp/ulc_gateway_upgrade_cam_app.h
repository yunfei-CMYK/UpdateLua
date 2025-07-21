
#ifndef _ULC_GATEWAY_UPGRADE_CAM_APP_HH
#define _ULC_GATEWAY_UPGRADE_CAM_APP_HH

#ifdef __cplusplus
extern "C"
{
#endif

    int ulc_gateway_upgrade_cam_app(unsigned short dev_addr, unsigned char node_type, unsigned int pack_type, char * version, unsigned char *data, unsigned int data_len);

#ifdef __cplusplus
}
#endif

#endif
