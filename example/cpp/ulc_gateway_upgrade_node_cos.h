
#ifndef _ULC_UPGRADE_UPGRADE_NODE_COS_HH
#define _ULC_UPGRADE_UPGRADE_NODE_COS_HH


#ifdef __cplusplus
extern "C"
{
#endif

    int upgrade_ulc_dev_telink(unsigned int pack_type, unsigned short dev_addr, ulc_dev_module_role_type role_type, unsigned char *data, unsigned int data_len);

    int upgrade_ulc_dev_324_cos(unsigned int pack_type, unsigned short dev_addr, ulc_dev_module_role_type role_type, unsigned char *data, unsigned int data_len);

    unsigned char check_upgrade_pack_is_324(unsigned int pack_type);

#ifdef __cplusplus
}
#endif

#endif
