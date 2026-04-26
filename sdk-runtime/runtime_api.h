#ifndef RUNTIME_API_H
#define RUNTIME_API_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Force 32-bit register jumps to cross the 256MB RAM/Flash gap
#define FLASH_FUNC __attribute__((long_call))

// --- System Governance ---
extern void     FLASH_FUNC runtime_system_reboot(void);
extern void     FLASH_FUNC runtime_get_unique_id(uint8_t *id_out);

// --- Vitals ---
extern void     FLASH_FUNC adc_set_temp_sensor_enabled(bool enable);
extern void     FLASH_FUNC reset_block(uint32_t bits);
extern void     FLASH_FUNC unreset_block(uint32_t bits);

// --- System Identity ---
extern uint32_t FLASH_FUNC get_core_num(void);
extern uint8_t  FLASH_FUNC rp2040_chip_version(void);
extern void     FLASH_FUNC flash_get_unique_id(uint8_t *id_out);

// --- Watchdog & Reset ---
extern void     FLASH_FUNC watchdog_enable(uint32_t delay_ms, bool pause_on_debug);
extern void     FLASH_FUNC watchdog_update(void);
extern void     FLASH_FUNC watchdog_reboot(uint32_t pc, uint32_t sp, uint32_t delay_ms);
extern bool     FLASH_FUNC watchdog_caused_reboot(uint32_t pc, uint32_t sp, uint32_t delay_ms);

// --- Clock Control ---
// Useful if you need to know exactly how fast the CPU is running (default 125MHz)
extern uint32_t FLASH_FUNC clock_get_hz(uint32_t clock_index);

// --- Interpolators ---
// These are special hardware units in the SIO block that do fast fixed-point
// math and lane masking—great for high-speed audio or PIO data prep.
extern void     FLASH_FUNC interp_set_accumulator(uint32_t interp, uint32_t lane, uint32_t val);

// --- System & Time ---
extern void     FLASH_FUNC stdio_init_all(void);
extern void     FLASH_FUNC sleep_ms(uint32_t ms);          // <--- Restored
extern void     FLASH_FUNC sleep_us(uint64_t us);
extern uint64_t FLASH_FUNC get_absolute_time(void);
extern void     FLASH_FUNC panic(const char *fmt, ...);
extern int      FLASH_FUNC printf(const char *format, ...);
extern int      FLASH_FUNC fflush(void *stream);
extern void*    FLASH_FUNC get_stdout(void);
extern int      FLASH_FUNC puts(const char *s);
extern void*    FLASH_FUNC memcpy(void *dest, const void *src, size_t n);
extern void*    FLASH_FUNC memset(void *s, int c, size_t n);
extern size_t   FLASH_FUNC strlen(const char *s);
extern int      FLASH_FUNC strcmp(const char *s1, const char *s2);
extern void*    FLASH_FUNC malloc(size_t size);
extern void     FLASH_FUNC free(void *ptr);

// --- GPIO & ADC (Analog) ---
extern void     FLASH_FUNC gpio_init(uint32_t gpio);
extern void     FLASH_FUNC gpio_set_dir(uint32_t gpio, bool out); // <--- Restored
extern void     FLASH_FUNC gpio_put(uint32_t gpio, bool value);
extern bool     FLASH_FUNC gpio_get(uint32_t gpio);               // <--- Restored
extern void     FLASH_FUNC gpio_set_function(uint32_t gpio, int fn);
extern void     FLASH_FUNC adc_init(void);
extern void     FLASH_FUNC adc_gpio_init(uint32_t gpio);
extern void     FLASH_FUNC adc_select_input(uint32_t input);      // <--- Restored
extern uint16_t FLASH_FUNC adc_read(void);

// --- I2C & SPI ---
extern void     FLASH_FUNC i2c_init(void *i2c, uint32_t baudrate); // <--- Restored
extern uint32_t FLASH_FUNC i2c_set_baudrate(void *i2c, uint32_t baudrate);
extern int      FLASH_FUNC i2c_write_blocking(void *i2c, uint8_t addr, const uint8_t *src, size_t len, bool nostop);
extern int      FLASH_FUNC i2c_read_blocking(void *i2c, uint8_t addr, uint8_t *dst, size_t len, bool nostop);
extern void     FLASH_FUNC spi_init(void *spi, uint32_t baudrate); // <--- Restored
extern uint32_t FLASH_FUNC spi_set_baudrate(void *spi, uint32_t baudrate);
extern int      FLASH_FUNC spi_write_read_blocking(void *spi, const uint8_t *src, uint8_t *dst, size_t len);

// --- PWM & Timers ---
extern uint32_t FLASH_FUNC pwm_gpio_to_slice_num(uint32_t gpio);
extern void     FLASH_FUNC pwm_set_wrap(uint32_t slice, uint16_t wrap);
extern void     FLASH_FUNC pwm_set_chan_level(uint32_t slice, uint32_t chan, uint16_t lvl);
extern void     FLASH_FUNC pwm_set_enabled(uint32_t slice, bool enabled);
extern int      FLASH_FUNC add_alarm_in_ms(uint32_t ms, void *cb, void *user_data, bool fire_if_past);
extern int      FLASH_FUNC add_alarm_in_us(uint64_t us, void *cb, void *user_data, bool fire_if_past);
extern bool     FLASH_FUNC cancel_alarm(int alarm_id);
extern void     FLASH_FUNC hardware_alarm_set_callback(uint32_t alarm_num, void *cb);

// --- PIO (Programmable I/O) ---
extern uint32_t FLASH_FUNC pio_add_program(void *pio, const void *prog);
extern void     FLASH_FUNC pio_sm_init(void *pio, uint32_t sm, uint32_t off, const void *cfg);
extern void     FLASH_FUNC pio_sm_set_enabled(void *pio, uint32_t sm, bool enabled);
extern void     FLASH_FUNC pio_sm_put_blocking(void *pio, uint32_t sm, uint32_t data);
extern uint32_t FLASH_FUNC pio_sm_get_blocking(void *pio, uint32_t sm);
extern void     FLASH_FUNC pio_sm_set_consecutive_pindirs(void *pio, uint32_t sm, uint32_t pin, uint32_t count, bool is_out);

// --- Multicore & Interrupts ---
extern void     FLASH_FUNC multicore_launch_core1(void (*entry)(void));
extern void     FLASH_FUNC multicore_fifo_push_blocking(uint32_t data);
extern uint32_t FLASH_FUNC multicore_fifo_pop_blocking(void);
extern void     FLASH_FUNC irq_set_exclusive_handler(uint32_t num, void *handler);
extern void     FLASH_FUNC irq_set_enabled(uint32_t num, bool enabled);
extern void     FLASH_FUNC irq_set_priority(uint32_t num, uint32_t priority);

// --- Flash & Sync ---
extern uint32_t FLASH_FUNC save_and_disable_interrupts(void);
extern void     FLASH_FUNC restore_interrupts(uint32_t status);
extern void     FLASH_FUNC flash_range_erase(uint32_t flash_offs, size_t count);
extern void     FLASH_FUNC flash_range_program(uint32_t flash_offs, const uint8_t *data, size_t count);

// --- DMA (Direct Memory Access) ---
extern int      FLASH_FUNC dma_claim_unused_channel(bool required);
extern void     FLASH_FUNC dma_channel_unclaim(uint32_t channel);

// Note: This returns a struct by value in the SDK, which can be tricky
// across the bridge. It's safer to use the 'getter' in your RAM code
// if you include hardware_dma_headers, or use a wrapper.
extern void*    FLASH_FUNC dma_channel_get_default_config(uint32_t channel);

extern void     FLASH_FUNC dma_channel_configure(
    uint32_t channel,
    void *config,
    void *write_addr,
    const void *read_addr,
    uint32_t transfer_count,
    bool trigger
);

extern void     FLASH_FUNC dma_channel_start(uint32_t channel);
extern void     FLASH_FUNC dma_channel_abort(uint32_t channel);
extern bool     FLASH_FUNC dma_channel_is_busy(uint32_t channel);

// --- Custom Network Wrappers ---
extern int      FLASH_FUNC runtime_cyw43_arch_init(void);
extern void     FLASH_FUNC runtime_cyw43_arch_gpio_put(uint32_t pin, bool value);
extern int      FLASH_FUNC runtime_get_link_status(void);
extern int      FLASH_FUNC runtime_wifi_connect_async(const char *ssid, const char *pass);
extern int      FLASH_FUNC runtime_wifi_reconnect(const char *ssid, const char *pass);
extern void     FLASH_FUNC runtime_tcp_connect(const char *ip, uint16_t port);
extern void     FLASH_FUNC runtime_tcp_write(const char *data, uint16_t len);
extern void     FLASH_FUNC runtime_network_soft_reset(void);

extern void     FLASH_FUNC cyw43_arch_lwip_begin(void);
extern void     FLASH_FUNC cyw43_arch_lwip_end(void);

extern void     FLASH_FUNC runtime_get_ip_info(char *ip, char *mask, char *gw);

// --- UDP & Networking ---
extern void*    FLASH_FUNC udp_new(void);
extern void     FLASH_FUNC udp_recv(void *pcb, void *cb, void *arg);
extern int      FLASH_FUNC udp_sendto(void *pcb, void *p, const void *dst_ip, uint16_t port);
extern void     FLASH_FUNC udp_remove(void *pcb);

// --- Packet Buffer Management ---
typedef enum {
    PBUF_TRANSPORT = 0,
    PBUF_IP = 1,
    PBUF_LINK = 2,
    PBUF_RAW_TX = 3,
    PBUF_RAW = 4
} pbuf_layer;

typedef enum {
    PBUF_RAM = 0,
    PBUF_ROM = 1,
    PBUF_REF = 2,
    PBUF_POOL = 3
} pbuf_type;

//extern void*    FLASH_FUNC runtime_pbuf_alloc(pbuf_layer layer, uint16_t length, pbuf_type type);
extern void*    FLASH_FUNC runtime_pbuf_alloc(int layer, uint16_t length);
extern uint8_t  FLASH_FUNC pbuf_free(void *p);
extern uint16_t FLASH_FUNC pbuf_copy_partial(void *p, void *dataptr, uint16_t len, uint16_t offset);

// --- RTC Data Structure ---
typedef struct {
    int16_t year;    // 0..4095
    int8_t month;    // 1..12, 1 is January
    int8_t day;      // 1..31
    int8_t dotw;     // 0..6, 0 is Sunday
    int8_t hour;     // 0..23
    int8_t min;      // 0..59
    int8_t sec;      // 0..59
} datetime_t;

// --- NTP udp Data Structure ---
typedef struct {
    int8_t LVM;     // leap indicator (2bits) version (3bits) mode (3bits)
    int8_t stratum;
    int8_t poll;
    int8_t precision;
    uint32_t root_delay;
    uint32_t root_dispersion;
    uint32_t reference_id;
    uint64_t ref_timestamp;
    uint64_t org_timestamp;
    uint64_t rcv_timestamp;
    uint64_t tra_timestamp;
} ntptime_t;

typedef struct {
    uint32_t addr;
} ip4_addr_t;

typedef struct {
    ip4_addr_t ip4;
} ip_addr_t;

struct pbuf {
    struct pbuf *next;
    void *payload;
    uint16_t tot_len;
    uint16_t len;
    uint8_t  type_internal;
    uint8_t  flags;
    uint16_t ref;
};

extern int      FLASH_FUNC ip4addr_aton(const char *cp, ip_addr_t *addr);

// --- RTC Functions ---
extern void     FLASH_FUNC rtc_init(void);
extern bool     FLASH_FUNC rtc_set_datetime(datetime_t *t);
extern bool     FLASH_FUNC rtc_get_datetime(datetime_t *t);
extern bool     FLASH_FUNC rtc_running(void);

// --- Bluetooth (BTstack) ---
typedef enum {
    HCI_POWER_OFF = 0,
    HCI_POWER_ON  = 1,
    HCI_POWER_SLEEP = 2
} HCI_POWER_MODE;

extern void     FLASH_FUNC hci_init(const void *transport, const void *config);
extern void     FLASH_FUNC hci_power_control(HCI_POWER_MODE mode);
extern void     FLASH_FUNC gap_advertisements_enable(int enabled);

// Simple wrapper for your Runtime to start the BLE radio
extern int      FLASH_FUNC runtime_bluetooth_init(void);

extern void     FLASH_FUNC gap_set_scan_parameters(uint8_t scan_type, uint16_t scan_interval, uint16_t scan_window);
extern void     FLASH_FUNC gap_set_scan_enable(int enabled);

extern void     FLASH_FUNC hci_add_event_handler(void *event_handler);

extern void     FLASH_FUNC runtime_ble_scan_start(void);

// --- Wi-Fi Diagnostics & Identity ---
// RSSI returns signal strength in dBm (e.g., -50 is strong, -90 is very weak)
extern void     FLASH_FUNC  runtime_get_rssi_safe(int32_t *rssi_out);

// Returns 6 bytes of MAC address into the provided buffer
extern int      FLASH_FUNC cyw43_hal_get_mac(int interface, uint8_t *mac_out);

extern void     FLASH_FUNC runtime_lwip_begin(void);
extern void     FLASH_FUNC runtime_lwip_end(void);

// --- ARM AEABI Math Helpers (Compiler Internal) ---
// Note: We use uint32_t/int32_t to match the CPU registers

// Integer Division & Modulo
extern uint32_t FLASH_FUNC __aeabi_uidiv(uint32_t n, uint32_t d);    // n / d (unsigned)
extern int32_t  FLASH_FUNC __aeabi_idiv(int32_t n, int32_t d);      // n / d (signed)
extern uint64_t FLASH_FUNC __aeabi_uidivmod(uint32_t n, uint32_t d); // n % d (unsigned)
extern int64_t  FLASH_FUNC __aeabi_idivmod(int32_t n, int32_t d);   // n % d (signed)

// 64-bit Integer (Long Long)
extern uint64_t FLASH_FUNC __aeabi_uldivmod(uint64_t n, uint64_t d); // 64-bit n % d
extern uint64_t FLASH_FUNC __aeabi_llsl(uint64_t val, int shift);    // 64-bit <<
extern uint64_t FLASH_FUNC __aeabi_llsr(uint64_t val, int shift);    // 64-bit >>

// Single Precision Floating Point (float)
extern float    FLASH_FUNC __aeabi_fadd(float a, float b);
extern float    FLASH_FUNC __aeabi_fsub(float a, float b);
extern float    FLASH_FUNC __aeabi_fmul(float a, float b);
extern float    FLASH_FUNC __aeabi_fdiv(float a, float b);
extern float    FLASH_FUNC __aeabi_i2f(int32_t i);                   // int to float
extern int32_t  FLASH_FUNC __aeabi_f2iz(float f);                  // float to int

// Optimized Memory Blocks
extern void     FLASH_FUNC __aeabi_memcpy(void *dest, const void *src, size_t n);
extern void     FLASH_FUNC __aeabi_memset(void *dest, size_t n, int c);
extern void     FLASH_FUNC __aeabi_memclr(void *dest, size_t n);

#endif
