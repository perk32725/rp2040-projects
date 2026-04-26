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

set(PROJNAME "my_main")

#-------------------------------------------------------------------------------
# MY_MAIN (RAM Guest)
# Linked to 0x20020000.
#-------------------------------------------------------------------------------
add_executable(${PROJNAME}
    ${PROJNAME}.c
    my_asm.S
    other.c
)

# CRITICAL: Prevent the SDK from adding its own crt0.S and standard libs
# we already have those in the runtime.
set_target_properties(${PROJNAME} PROPERTIES SKIP_PICO_CRT0 1)
set_target_properties(${PROJNAME} PROPERTIES PICO_NO_TARGET_LINKER_SCRIPT 1)

# --- /Users/wrp/Desktop/Pico-asm/sdk-runtime/build
set(RUNTIME_BINARY_DIR "../../sdk-runtime/build")
set(RUNTIME_ELF "${RUNTIME_BINARY_DIR}/runtime.elf")
target_link_options(${PROJNAME} PRIVATE
    "-Wl,-R,${RUNTIME_ELF}" # symbols from runtime
    "-Wl,-Ttext,0x20020000" # where we land
    "-nostartfiles"         # No standard C startup logic
    "-nodefaultlibs"        # default libs already in FLASH
    "-Wl,-e,${PROJNAME}"        # Set the ELF entry point to '${PROJNAME}' in entry.S
    "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${PROJNAME}.map"
    "-T${CMAKE_CURRENT_SOURCE_DIR}/my_main.ld"
)

#add_dependencies(${PROJNAME} runtime)

# --- Link libraries (Headers only) ---
target_link_libraries(${PROJNAME} PRIVATE
    pico_base_headers
    pico_stdlib_headers

    pico_cyw43_arch_lwip_threadsafe_background_headers
    pico_rand_headers

    # peripherals:
    hardware_gpio_headers
    hardware_adc_headers
    hardware_i2c_headers
    hardware_spi_headers
    hardware_pwm_headers
    hardware_pio_headers
    hardware_flash_headers
    hardware_timer_headers
    hardware_sync_headers
    hardware_dma_headers
    hardware_rtc_headers
    hardware_watchdog_headers
    hardware_clocks_headers
    hardware_resets_headers
    hardware_interp_headers

    pico_multicore_headers
)

target_compile_definitions(${PROJNAME} PRIVATE
    PICO_CYW43_ARCH_POLL=0
    PICO_LWIP=1
    PICO_CYW43_CHIP_WIFI=1
    PICO_CYW43_ARCH_THREADSAFE_BACKGROUND=1
)

target_compile_options(${PROJNAME} PRIVATE
    "-fno-builtin-printf"
)

target_include_directories(${PROJNAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    "../sdk-runtime"
    "${PICO_SDK_PATH}/src/rp2_common/pico_async_context/include"
    "${PICO_SDK_PATH}/src/rp2_common/pico_lwip/include"
    "${PICO_SDK_PATH}/src/rp2_common/pico_cyw43_arch/include"
    "${PICO_SDK_PATH}/src/common/pico_util/include"
    "${PICO_SDK_PATH}/lib/lwip/src/include"
)

pico_add_extra_outputs(${PROJNAME})
pico_enable_stdio_usb(${PROJNAME} 0)
pico_enable_stdio_uart(${PROJNAME} 1)

add_custom_command(TARGET ${PROJNAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "generating disassembly"
    COMMAND ${CMAKE_OBJDUMP} -d -S $<TARGET_FILE:${PROJNAME}> > ${CMAKE_CURRENT_BINARY_DIR}/${PROJNAME}.dis
    VERBATIM
    COMMENT "Generating disassembly file: ${PROJNAME}.dis"
)

# EOF:
