#include <stdio.h>
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"

/* EXPORTED functions herein:
    get_stdout(void)
    runtime_cyw43_arch_gpio_put(uint pin, bool value) 
    runtime_sleep_ms(uint32_t sleeptime) 
    runtime_cyw43_arch_gpio_get(uint pin) 
    runtime_cyw43_arch_init(void) 
    runtime_get_link_status(void) 
    tcp_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) 
    tcp_connected_callback(void *arg, struct tcp_pcb *tpcb, err_t err) 
    runtime_tcp_connect(const char* ip_str, uint16_t port) 
    runtime_tcp_write(const char* data, uint16_t len) 
    runtime_wifi_connect_async(const char *ssid, const char *pw) 
    runtime_wifi_reconnect(const char* ssid, const char* pass) 
    runtime_wifi_disconnect_and_deinit(void) 
    runtime_network_soft_reset(void) 
    runtime_ble_scan_start(void) 
    runtime_get_ip_info(char *ip_out, char *mask_out, char *gw_out) 
    runtime_get_rssi(void) 
    runtime_get_rssi_safe(int32_t *rssi_out) 
    runtime_lwip_begin(void) 
    runtime_lwip_end(void) 
    runtime_system_reboot(void) 
    runtime_get_unique_id(uint8_t *id_out) 
 */

void* __attribute__((used))
get_stdout(void) {
    return (void*)stdout;
}

// wrapper function for a real symbol in ELF:
void __attribute__((used))
runtime_cyw43_arch_gpio_put(uint pin, bool value) {
    cyw43_arch_gpio_put(pin, value);
}

void __attribute__((used))
runtime_sleep_ms(uint32_t sleeptime) {
    sleep_ms(sleeptime);
}

// wrapper function for a real symbol in ELF:
void __attribute__((used))
runtime_cyw43_arch_gpio_get(uint pin) {
    cyw43_arch_gpio_get(pin);
}

// In runtime's exports.c
void __attribute__((used))
runtime_cyw43_arch_init(void) {
    cyw43_arch_init();
}

// Returns the current status of the Wi-Fi and IP link
int __attribute__((used))
runtime_get_link_status(void) {
    // No lock needed for status checks usually, but safe to include
    return cyw43_tcpip_link_status(&cyw43_state, CYW43_ITF_STA);
    /*
     * returns:
     * 3 link up
     * 2 link noip
     * 1 join
     * 0 down
     * -1 fail
     * -3 badauth
     */
}

static struct tcp_pcb* global_tcp_pcb = NULL;
//
// runtime "Connection Manager":
// Callback: Handle incoming data from the server
static err_t
tcp_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) {
    if (!p) {
        tcp_close(tpcb);
        global_tcp_pcb = NULL;
        return ERR_OK;
    }
    // For now, just acknowledge the data.
    // You can point this to a RAM buffer your assembly code reads.
    tcp_recved(tpcb, p->tot_len);
    pbuf_free(p);
    return ERR_OK;
}

// Callback: Called when the connection is successfully established
static err_t
tcp_connected_callback(void *arg, struct tcp_pcb *tpcb, err_t err) {
    if (err == ERR_OK) {
        global_tcp_pcb = tpcb;
        tcp_recv(tpcb, tcp_recv_callback);
    }
    return err;
}

// EXPORT: Trigger the connection (Call this once before jumping to RAM)
void __attribute__((used))
runtime_tcp_connect(const char* ip_str, uint16_t port) {
    ip_addr_t remote_addr;
    if (!ipaddr_aton(ip_str, &remote_addr)) return;

    cyw43_arch_lwip_begin();
    struct tcp_pcb* pcb = tcp_new();
    if (pcb) {
        tcp_connect(pcb, &remote_addr, port, tcp_connected_callback);
    }
    cyw43_arch_lwip_end();
}

// EXPORT: Send data over the existing connection
void __attribute__((used))
runtime_tcp_write(const char* data, uint16_t len) {
    if (!global_tcp_pcb) return;

    cyw43_arch_lwip_begin();
    tcp_write(global_tcp_pcb, data, len, TCP_WRITE_FLAG_COPY);
    tcp_output(global_tcp_pcb);
    cyw43_arch_lwip_end();
}

// reconnect wrapper:

// EXPORT Your custom wrapper to make the SDK function linkable
int __attribute__((used))
runtime_wifi_connect_async(const char *ssid, const char *pw) {
    // 1. Enable station mode (wakes up the Wi-Fi part of the chip)
    cyw43_arch_enable_sta_mode();

    // 2. Start the asynchronous connection attempt
    // Using WPA2_AES_PSK as a common default for modern routers
    return cyw43_arch_wifi_connect_async(ssid, pw, CYW43_AUTH_WPA2_AES_PSK);
}

// EXPORT function to trigger a fresh Wi-Fi connection
int __attribute__((used))
runtime_wifi_reconnect(const char* ssid, const char* pass) {
    // 1. Lock the background stack during the reset
    cyw43_arch_lwip_begin();

    // 2. Clear existing connection status if any
    cyw43_arch_disable_sta_mode();
    cyw43_arch_enable_sta_mode();

    // 3. Start the non-blocking join
    // This returns 0 if the attempt started, NOT if it finished.
    int err = cyw43_arch_wifi_connect_async(ssid, pass, CYW43_AUTH_WPA2_AES_PSK);

    cyw43_arch_lwip_end();
    return err;
}

#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"

// Exported to safely shut down everything
void __attribute__((used))
runtime_wifi_disconnect_and_deinit(void) {
    // 1. Lock the stack to prevent background interrupts during teardown
    cyw43_arch_lwip_begin();

    // 2. Clear any active TCP/UDP state (if you have global PCBs)
    if (global_tcp_pcb != NULL) {
        tcp_abort(global_tcp_pcb); // Use abort for a "hard" immediate kill
        global_tcp_pcb = NULL;
    }

    // 3. Kill the station interface (this tells the router we are leaving)
    cyw43_arch_disable_sta_mode();

    cyw43_arch_lwip_end();

    // 4. De-initialize the arch (shuts down the CYW43 chip power)
    cyw43_arch_deinit();

    // Optional: Small delay to let the chip hardware settle
    sleep_ms(50);
}

#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"

void __attribute__((used))
runtime_network_soft_reset(void) {
    // 1. Lock the stack to modify PCBs and Wi-Fi state
    cyw43_arch_lwip_begin();

    // 2. Kill the TCP connection immediately
    if (global_tcp_pcb != NULL) {
        tcp_abort(global_tcp_pcb); // Hard reset of the TCP state
        global_tcp_pcb = NULL;
    }

    // 3. Disconnect from the Access Point (Router)
    // This clears the IP address and DHCP state
    cyw43_arch_disable_sta_mode();
    sleep_ms(50);   // short delay

    // 4. Immediately re-enable it so the hardware stays "Ready"
    cyw43_arch_enable_sta_mode();

    cyw43_arch_lwip_end();
    sleep_ms(50);   // short delay
}

#include "btstack.h"
#include "hci.h"
#include "hci_cmd.h"

void __attribute__((used))
runtime_ble_scan_start(void) {
    cyw43_arch_lwip_begin();

    // 1. Set Scan Parameters: Active Scan (1), Interval (0x30), Window (0x30)
    // Values: Scan Type, Interval, Window, Own Addr Type, Filter Policy
    hci_send_cmd(&hci_le_set_scan_parameters, 1, 0x0030, 0x0030, 0, 0);

    // 2. Enable Scanning: 1 = Enable, 1 = Filter Duplicates
    hci_send_cmd(&hci_le_set_scan_enable, 1, 1);

    cyw43_arch_lwip_end();
}

#include "lwip/netif.h"
#include "lwip/ip_addr.h"

// Wrapper to get the assigned IP, Netmask, and Gateway
void __attribute__((used))
runtime_get_ip_info(char *ip_out, char *mask_out, char *gw_out) {
    if (netif_default) {
        // Convert the binary IP addresses to human-readable strings
        // Note: inet_ntoa uses a static buffer, so we copy it immediately
        strcpy(ip_out, ip4addr_ntoa(netif_ip4_addr(netif_default)));
        strcpy(mask_out, ip4addr_ntoa(netif_ip4_netmask(netif_default)));
        strcpy(gw_out, ip4addr_ntoa(netif_ip4_gw(netif_default)));
    } else {
        strcpy(ip_out, "0.0.0.0");
    }
}

int __attribute__((used))
runtime_get_rssi(void) {
    int32_t rssi;
    cyw43_wifi_get_rssi(&cyw43_state, &rssi);
    return rssi;
}

// Change to a 'void' return and pass the pointer explicitly
void __attribute__((used))
runtime_get_rssi_safe(int32_t *rssi_out) {
    // Initialize the target to a known error value first
    *rssi_out = -999;
    
    // Use the shared architecture lock to ensure the radio is ready
    cyw43_arch_lwip_begin();
    cyw43_wifi_get_rssi(&cyw43_state, rssi_out);
    cyw43_arch_lwip_end();
}

#include "pico/cyw43_arch.h"

// Create a real function out of the SDK macro
void __attribute__((used))
runtime_lwip_begin(void) {
    cyw43_arch_lwip_begin();
}

void __attribute__((used))
runtime_lwip_end(void) {
    cyw43_arch_lwip_end();
}

#include "hardware/watchdog.h"
#include "hardware/resets.h"
#include "pico/unique_id.h"

// Full hardware reboot
void __attribute__((used))
runtime_system_reboot(void) {
    watchdog_reboot(0, 0, 10); // Jump to 0, Stack 0, 10ms delay
}

// Get the unique 8-byte board ID
void __attribute__((used))
runtime_get_unique_id(uint8_t *id_out) {
    pico_unique_board_id_t id;
    pico_get_unique_board_id(&id);
    memcpy(id_out, id.id, 8);
}

#include "lwip/pbuf.h"

void* __attribute__((used)) runtime_pbuf_alloc(int layer_type, uint16_t len) {
    pbuf_layer layer;
    if (layer_type == 0) layer = PBUF_TRANSPORT;
    else layer = PBUF_RAW;

    // Explicitly cast the integers back to the enums the SDK wants
    return (void*)pbuf_alloc(layer, len, PBUF_RAM);
}

// EOF:
