/* runtime_main.c
 * this is the 'launchpad' from SDK initialization to the program of your choice,
 * which should be located at 0x20020000
 */
#include <stdio.h>
#include "pico/stdlib.h"
//#include "pico/cyw43_arch.h"
#include "pico/multicore.h"
//#include "lwip/tcp.h"
//#include "hardware/adc.h"
//#include "hardware/i2c.h"
//#include "hardware/spi.h"
//#include "hardware/dma.h"
//#include "host_api.h"

// Define the RAM application's entry point address,
// and set up a way to get to it:
// We add +1 to the address to ensure the Thumb bit is set (required for RP2040).
#define RAM_APP_ENTRY_POINT 0x20020000
uint32_t guest_addr = RAM_APP_ENTRY_POINT;

int main() {
    // Initialize the hardware subsystems the Guest will use
    stdio_init_all();      // Prepares UART/USB for printf
    // cyw43_arch_init();     // Prepares Wi-Fi chip for LED control
    // adc_init();            // Prepares ADC hardware

    printf("stdio initialized.\n");
    printf("Going to RAM...\n");

    // Jump to the RAM Guest
    void (*ram_entry)(void) = (void (*)(void))(guest_addr + 1);
    ram_entry();

    // Trap core if the Guest ever returns
    while (1) {
        __wfi();
    }
}

// EOF:
