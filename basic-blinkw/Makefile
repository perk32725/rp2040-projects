CC=${PICO_COMPILER}
DIS=${PICO_TOOLCHAIN_PATH}/bin/arm-none-eabi-objdump
MACH=cortex-m0plus

SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2040/hardware_regs/include
SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/common/pico_base/include
SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2_common/pico_platform/include

CFLAGS= -c -g -mcpu=$(MACH) -DPICO_RP2040=1 -mthumb -std=gnu11 -Wall -O0 ${SDK_INCLUDES}
LFLAGS= -nostdlib -T main.ld -Wl,--just-symbols=../basic-runtime/basic-runtime.elf -Wl,-Map=main.map

all: main.elf

main.o: picow-led-5.S
	$(CC) $(CFLAGS) -o $@ picow-led-5.S

main.elf: main.o
	$(CC) $(LFLAGS) -o $@ $^
	$(DIS) -D main.elf >main.dis

# EOF:
