#ifndef _PICO_BTSTACK_BTSTACK_CONFIG_H
#define _PICO_BTSTACK_BTSTACK_CONFIG_H

#define HAVE_CHIPSET_CYW43
#define HAVE_PICO_INCLUDE_CONFIG_H

//#define ENABLE_BLE
#define ENABLE_LE_CENTRAL
#define ENABLE_LE_PERIPHERAL
#define HAVE_MALLOC

// The SDK defines ENABLE_BLE/ENABLE_CLASSIC automatically 
// when you link the corresponding libraries.

#ifdef ENABLE_BLE
#define ENABLE_LE_PERIPHERAL
#define ENABLE_LE_CENTRAL
#define ENABLE_L2CAP_LE_CREDIT_BASED_FLOW_CONTROL_MODE
#endif

// Core BTstack configuration
#define HCI_OUTGOING_PRE_BUFFER_SIZE 4
#define HCI_ACL_PAYLOAD_SIZE (1691 + 4)
#define HCI_ACL_CHUNK_SIZE_ALIGNMENT 4

// Resource limits (adjust as needed for RAM)
#define MAX_NR_HCI_CONNECTIONS 1
#define MAX_NR_L2CAP_CHANNELS  2
#define MAX_NR_L2CAP_SERVICES  2
#define MAX_NR_GATT_CLIENTS    1
#define MAX_NR_LE_DEVICE_DB_ENTRIES 4

// Link Key DB and LE Device DB using TLV on top of Flash Sector interface.
#define NVM_NUM_LINK_KEYS 16
#define NVM_NUM_DEVICE_DB_ENTRIES 16

// additional stuff:
#define HAVE_POSIX_TIME
#define HAVE_BSTACK_STDIN

// Enable hex-dumping for HCI packet debugging
#define ENABLE_PRINTF_HEXDUMP

// Allow BTstack to use your runtime's printf/puts
#define ENABLE_PRINTF

#define ENABLE_LE_CENTRAL
#define ENABLE_LE_PERIPHERAL
//#define ENABLE_LE_DATA_CHANNELS
#define ENABLE_GATT_CLIENT

#endif
