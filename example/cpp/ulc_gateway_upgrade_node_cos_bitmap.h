
#ifndef _ULC_UPGRADE_UPGRADE_NODE_COS_BITMAP_HH
#define _ULC_UPGRADE_UPGRADE_NODE_COS_BITMAP_HH

typedef struct _upgrade_block_info_st
{
    unsigned int FileOffset;
    unsigned int SPIFlashAddr;
    unsigned int blockLen;
} upgrade_block_info_st, *p_upgrade_block_info_st;


#ifdef __cplusplus
extern "C"
{
#endif

    void ulc_gateway_upgrade_cos_block_add(unsigned short index, p_upgrade_block_info_st pst);

    void ulc_gateway_upgrade_cos_block_clear();

    unsigned char ulc_gateway_upgrade_cos_conv_pack_type(unsigned int pack_type);

    p_upgrade_block_info_st ulc_gateway_upgrade_cos_block_get(unsigned short index);

    int ulc_gateway_upgrade_cos_get_bitmap(unsigned int pack_type, ulc_dev_module_role_type role_type, unsigned char* buf, unsigned int max_buf_len);

#ifdef __cplusplus
}
#endif

#endif
