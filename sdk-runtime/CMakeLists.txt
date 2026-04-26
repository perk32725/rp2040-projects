cmake_minimum_required(VERSION 3.13)

# Standard C/C++ settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
#set(PICO_DEOPTIMIZED_DEBUG 1)

# Initialize Pico SDK
include(pico_sdk_import.cmake)
project(picow_blink C CXX ASM)
pico_sdk_init()

#-------------------------------------------------------------------------------
# RUNTIME (Flash Host)
# Provides all drivers and the function pointer table (host_api_t)
#-------------------------------------------------------------------------------
add_executable(runtime
    runtime_main.c
    runtime_exports.c
)

## Use our customized runtime linker script
pico_set_linker_script(runtime ${CMAKE_CURRENT_SOURCE_DIR}/runtime.ld)

# Link all necessary hardware libraries to provide symbols for the API table
target_link_libraries(runtime PRIVATE
    -Wl,--whole-archive
    pico_stdlib
    pico_cyw43_arch_lwip_threadsafe_background
    pico_btstack_ble
    pico_btstack_cyw43
    hardware_adc
    hardware_i2c
    hardware_spi
    hardware_dma
    hardware_pwm
    hardware_pio
    hardware_flash
    hardware_timer
    hardware_rtc
    pico_multicore
    hardware_dma
    hardware_watchdog
    hardware_resets
    pico_unique_id
    -Wl,--no-whole-archive
)

# include directories:
target_include_directories(runtime PRIVATE ${CMAKE_CURRENT_LIST_DIR})

set(EXPORTED_SYMBOLS
    # Integer Division
    __aeabi_uidiv __aeabi_uidivmod __aeabi_idivmod
    
    # 64-bit Integer
    __aeabi_uldivmod __aeabi_llsl __aeabi_llsr
    
    # Floating Point
    __aeabi_fadd __aeabi_fsub __aeabi_fmul __aeabi_fdiv
    __aeabi_i2f __aeabi_f2iz __aeabi_fcmplt __aeabi_fcmpgt
    
    # Optimized Memory
    __aeabi_memcpy __aeabi_memset __aeabi_memclr

    # System & Time
    stdio_init_all sleep_ms sleep_us get_absolute_time panic
    printf puts memcpy memset strlen strcmp malloc free

    # GPIO & ADC (Analog)
    gpio_init gpio_set_dir gpio_put gpio_get gpio_set_function
    adc_init adc_select_input adc_read adc_gpio_init

    # I2C & SPI
    i2c_init i2c_set_baudrate i2c_write_blocking i2c_read_blocking
    spi_init spi_set_baudrate spi_write_read_blocking

    # PWM & Timers
    pwm_gpio_to_slice_num pwm_set_wrap pwm_set_chan_level pwm_set_enabled
    add_alarm_in_ms add_alarm_in_us cancel_alarm hardware_alarm_set_callback

    # PIO (The "Hidden" Power)
    pio_add_program pio_sm_init pio_sm_set_enabled pio_sm_put_blocking
    pio_sm_get_blocking pio_sm_set_consecutive_pindirs

    # Multicore & Interrupts
    multicore_launch_core1 multicore_fifo_push_blocking multicore_fifo_pop_blocking
    irq_set_exclusive_handler irq_set_enabled irq_set_priority

    # Flash & Sync
    save_and_disable_interrupts restore_interrupts
    flash_range_erase flash_range_program

    # --- DMA (Direct Memory Access) ---
    dma_claim_unused_channel dma_channel_unclaim dma_channel_get_default_config
    channel_config_set_transfer_data_size channel_config_set_read_increment
    channel_config_set_write_increment channel_config_set_dreq
    dma_channel_configure dma_channel_start dma_channel_wait_for_finish_blocking
    dma_channel_is_busy dma_channel_abort

    # Your Custom Network Wrappers
    runtime_cyw43_arch_init runtime_get_link_status
    runtime_cyw43_arch_gpio_put
    runtime_wifi_reconnect runtime_tcp_connect runtime_tcp_write
    runtime_wifi_connect_async
    runtime_network_soft_reset cyw43_arch_lwip_begin cyw43_arch_lwip_end
    runtime_get_ip_info
    runtime_get_rssi_safe
    runtime_lwip_begin
    runtime_lwip_end
    runtime_ble_scan_start

    # --- UDP & pbuf (The "Missing Links") ---
    udp_new             # Create a new UDP PCB
    udp_recv            # Set the callback for incoming UDP packets
    udp_sendto          # Send UDP data to a specific IP/Port
    udp_remove          # Clean up the UDP PCB
    #pbuf_alloc          # Allocate memory for a network packet
    runtime_pbuf_alloc  # Allocate memory for a network packet
    pbuf_free           # Free packet memory (CRITICAL to avoid leaks)
    pbuf_copy_partial   # Extract data from a received packet
    ip4addr_aton

    # --- Reset & Watchdog (The "Reboot" button) ---
    watchdog_enable watchdog_update watchdog_reboot
    reset_block unreset_block

    # --- System Info ---
    get_core_num rp2040_chip_version flash_get_unique_id

    # --- Clocks (For custom baud rates/timing) ---
    clock_get_hz clock_configure

    # --- SIO Interpolators (The "Hidden Math" processors) ---
    interp_config_default interp_set_config interp_set_accumulator

    # --- RTC (Real-Time Clock) ---
    rtc_init rtc_set_datetime rtc_get_datetime rtc_running
    rtc_set_alarm rtc_enable_alarm rtc_disable_alarm

    # --- Bluetooth (BTstack) ---
    hci_init hci_power_control
    btstack_run_loop_execute
    l2cap_init l2cap_register_service
    gap_advertisements_enable gap_local_bd_addr
    hci_event_callback_registration_t
    hci_add_event_handler

    # --- BLE Central (Scanning) ---
    gap_set_scan_parameters
    gap_set_scan_enable

    # --- BLE Peripheral (Advertising) ---
    gap_advertisements_set_data
    gap_advertisements_enable

    # --- GATT (Data Exchange) ---
    att_server_init att_server_register_packet_handler

    # --- more for bluetooth:
    hci_send_cmd
    hci_le_set_scan_parameters
    hci_le_set_scan_enable

    # --- Wi-Fi Diagnostics & Identity ---
    #    cyw43_wifi_get_rssi
    cyw43_hal_get_mac

    # --- extras for fflush() and get_stdout()
    fflush
    get_stdout

    # --- System Governance (New) ---
    runtime_system_reboot           # Your custom wrapper for watchdog_reboot
    runtime_get_unique_id           # Your custom wrapper for board serial number
    watchdog_enable                 # Start the hardware watchdog
    watchdog_update                 # Kick the dog (reset timer)
    watchdog_caused_reboot          # Check if last boot was a crash

    # --- Power & Resets (New) ---
    reset_block                     # Force a hardware block to reset
    unreset_block                   # Release a hardware block from reset
    adc_set_temp_sensor_enabled     # Turn on the internal thermometer

    # --- Identity & Info (New) ---
    pico_get_unique_board_id        # SDK function for serial number
    get_core_num                    # Identify if code is on Core 0 or 1
    rp2040_chip_version             # Get the hardware revision
)

foreach(SYMBOL ${EXPORTED_SYMBOLS})
    target_link_options(runtime PRIVATE "-Wl,--undefined=${SYMBOL}")
endforeach()

# Standard SDK outputs (UF2, etc.)
pico_add_extra_outputs(runtime)
pico_enable_stdio_usb(runtime 0)
pico_enable_stdio_uart(runtime 1)

# EOF:
