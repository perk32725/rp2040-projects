#ifndef _LWIPOPTS_H
#define _LWIPOPTS_H

#define MEMP_NUM_TCP_SEG        32

// Common settings for Pico W lwIP (Background mode)
#define NO_SYS                      1
#define LWIP_SOCKET                 0
#define LWIP_NETCONN                0

#define MEM_ALIGNMENT               4
#define MEM_SIZE                    4000

// 3. Recommended settings for Pico W Background mode
#define LWIP_CHKSUM_ALGORITHM       3
#define LWIP_CALLBACK_API           1
#define MEM_ALIGNMENT               4
#define MEM_SIZE                    4000
#define PBUF_POOL_SIZE              16
#define LWIP_TCP                    1
#define LWIP_UDP                    1
#define LWIP_DHCP                   1
#define LWIP_DNS                    1

// 4. Memory/Performance (Optional tuning)
#define TCP_MSS                     1460
#define TCP_WND                     (8 * TCP_MSS)
#define TCP_SND_BUF                 (8 * TCP_MSS)
//
// already here:
#ifndef NDEBUG
#define LWIP_DEBUG                  1
#endif

#endif
