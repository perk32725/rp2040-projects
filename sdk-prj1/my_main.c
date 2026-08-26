/**
 * Copyright (c) 2022 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"
*/
/* pick and choose:
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"
#include "hardware/adc.h"
#include "hardware/i2c.h"
#include "hardware/spi.h"
#include "hardware/dma.h"
#include "pico/multicore.h"
*/

//#include "lwip/ip_addr.h"
//#include "lwip/pbuf.h"
//#include "lwip/udp.h"

// forward declarations before runtime_api.h:
struct pbuf;
struct ip_addr;

//#define FLASH_FUNC __attribute__((long_call))

#include "runtime_api.h"
#undef ipaddr_aton

#ifndef CYW43_WL_GPIO_LED_PIN
#define CYW43_WL_GPIO_LED_PIN 0
#endif

extern void my_asm();
extern void my_c_function(void);    // resides in other.c

void trigger_ntp_sync(const char * server_ip_str);

void fill_date_from_unix(uint32_t unix_time, datetime_t * t);

#define NTP_MSG_LEN 48
uint8_t  udp_buffer[NTP_MSG_LEN] = {0};
uint32_t unix_time;

//------------------------------------------------------------
// my_main()
//------------------------------------------------------------
void __attribute__((section(".entry_point"))) my_main() {

    // network connect:
    printf("Connecting to network...\n");
    runtime_cyw43_arch_init();
    hci_power_control(HCI_POWER_ON);    // powered on, but not off?

    runtime_ble_scan_start();
    runtime_wifi_connect_async("<your-wifi>","<your password>");

    while(runtime_get_link_status() != 3) {
        printf("status: %d\n", runtime_get_link_status());
        sleep_ms(3000);
    }

    printf("\nConnected!\n\n");
    fflush(get_stdout());

    if (runtime_get_link_status() == 3) {
        uint32_t current_rssi = -999;
        uint8_t mac[6];
        char ip[16], mask[16], gw[16];

        sleep_ms(100);

        // Get IP Info using your previously made wrapper
        runtime_get_ip_info(ip, mask, gw);

        // Get Signal Strength (Pass cyw43_state which is at 0x200015e0 usually)
        // You may need to export 'cyw43_state' or use a wrapper.
        runtime_get_rssi_safe(&current_rssi);

        if (current_rssi == -999) {
            printf("RSSI Read Failure (Driver Busy)\n");
        }

        // Get MAC Address (0 = Station Interface)
        cyw43_hal_get_mac(0, mac);

        printf("--- Network Report ---\n");
        printf("IP:  %s\n", ip);
        printf("MAC: %02x:%02x:%02x:%02x:%02x:%02x\n", 
               mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        printf("Signal strength: %d dBm)\n", current_rssi);
        fflush(get_stdout());
    }

    // set up timekeeping:
    uint32_t seconds_today;
    datetime_t now;

    rtc_init();

    // sync with a handy NTP server:
    trigger_ntp_sync("162.159.200.1");
    sleep_ms(200);

    // assume it worked:
    seconds_today = unix_time % 86400;
    now.hour = (seconds_today / 3600);
    now.min  = (seconds_today % 3600) / 60;
    now.sec  = (seconds_today % 60);

    fill_date_from_unix(unix_time, &now);
    rtc_set_datetime(&now);

    sleep_ms(50);   // need a few ms before rtc_set_datetime() settles
    rtc_get_datetime(&now);

    printf("Current date: %04d-%02d-%02D\n", now.year, now.month, now.day);
    printf("Current time: %02d:%02d:%02d\n", now.hour, now.min, now.sec);

    // if we don't need the network connection on all the time:
    printf("\nnetwork disconnect\n");
    runtime_network_soft_reset();
    fflush(get_stdout());

    // the "Forever" loop:
    printf("\nFlashing...\n");
    int counter = 3;
    while (true) {
        my_asm();
        my_c_function();

        // LED On:
        runtime_lwip_begin();
        runtime_cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
        runtime_lwip_end();
        sleep_ms(25);

        // LED Off:
        runtime_lwip_begin();
        runtime_cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
        runtime_lwip_end();
        sleep_ms(250);

        counter -= 1;
        if (counter)
            continue;

        // about every second:
        rtc_get_datetime(&now);
        printf("Current time: %04d-%02d-%02d %02d:%02d:%02d\r", 
                now.year, now.month, now.day, now.hour, now.min, now.sec);
        fflush(get_stdout());
        counter = 3;
    }
}

// NTP Epoch (1900) to Unix Epoch (1970) difference
#define NTP_DELTA 2208988800ull // Seconds between 1900 and 1970

// UDP callback: Handles the packet coming back from the NTP server
#define NTP_PORT 123
//---------------------------------------------------------------
// --- The "Ear": Callback triggered when the server responds
//---------------------------------------------------------------
static void ntp_recv_callback(void *arg, void *pcb, void *p, const void *addr, uint16_t port) {
    if (!p) return;

    // Use your new bridge function to safely copy the data
    pbuf_copy_partial(p, udp_buffer, NTP_MSG_LEN, 0);

    // CRITICAL: You must free the packet provided by lwIP
    pbuf_free(p);

    // NTP Transmit Timestamp is in bytes 40-43
    uint32_t seconds =
        ((uint32_t)udp_buffer[40] << 24) |
        ((uint32_t)udp_buffer[41] << 16) |
        ((uint32_t)udp_buffer[42] << 8)  |
        ((uint32_t)udp_buffer[43]);

    unix_time = seconds - NTP_DELTA;

    // Set your RTC here (Convert unix_time to datetime_t first)
    printf("NTP Sync Success! Unix Time: %u\n", unix_time);
}

//-------------------------------------------------------------
// --- The "Voice": set callback function, send the request
//-------------------------------------------------------------
void trigger_ntp_sync(const char* server_ip_str) {
    ip_addr_t server_addr;
    ip4addr_aton(server_ip_str, &server_addr);

    // 1. Setup the callback function:
    void* pcb = udp_new();
    udp_recv(pcb, ntp_recv_callback, NULL);

    // 2. Build the request packet (LI=0, VN=4, Mode=3)
    runtime_lwip_begin();
    void* p = runtime_pbuf_alloc(0, 48);
    runtime_lwip_end();

    if (p) {
        uint8_t req[NTP_MSG_LEN] = {0};
        req[0] = 0xE3;

        // Copy request data into pbuf payload
        //runtime_memcpy(((struct pbuf*)p)->payload, req, NTP_MSG_LEN);
        memcpy(((struct pbuf*)p)->payload, req, NTP_MSG_LEN);

        // 3. Send to server
        udp_sendto(pcb, p, &server_addr, NTP_PORT);

        // Free our request pbuf after sending
        pbuf_free(p);
    }
}

//-------------------------------------------------------------
// --- function:
//-------------------------------------------------------------
void fill_date_from_unix(uint32_t unix_time, datetime_t * t) {
    // Days since Jan 1, 1970
    uint32_t days = unix_time / 86400;

    // Day of the week (Unix Epoch was a Thursday=4)
    t->dotw = (days + 4) % 7;

    // Calculate Year
    uint32_t y = 1970;
    while (true) {
        uint32_t days_in_year = (y % 4 == 0) ? 366 : 365;
        if (days < days_in_year) break;
        days -= days_in_year;
        y++;
    }
    t->year = (int16_t)y;

    // Calculate Month
    static const int8_t days_in_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int8_t m = 0;
    while (true) {
        int8_t dim = days_in_month[m];
        if (m == 1 && y % 4 == 0) dim = 29; // February Leap Year
        if (days < (uint32_t)dim) break;
        days -= dim;
        m++;
    }
    t->month = m + 1; // 1-indexed
    t->day = (int8_t)(days + 1); // 1-indexed
}

// EOF:
