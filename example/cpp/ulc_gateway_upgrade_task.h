
#ifndef _ULC_UPGRADE_UPGRADE_TASK_HH
#define _ULC_UPGRADE_UPGRADE_TASK_HH

#ifdef __cplusplus
extern "C"
{
#endif

    int create_ulc_upgrade_task();

    void ulc_upgrade_task_post_event(unsigned short dev_addr, unsigned char node_type, unsigned int pack_type, char *version, unsigned char *data, unsigned int len);

#ifdef __cplusplus
}
#endif

#endif
