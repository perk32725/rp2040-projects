# Makefile- live with david-bma04 - bma07
#
# run make clean; make; make main.elf

CC=${PICO_COMPILER} #arm-none-eabi-gcc
DIS=${PICO_TOOLCHAIN_PATH}/bin/arm-none-eabi-objdump
MACH=cortex-m0plus
SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2040/hardware_regs/include
SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/common/pico_base/include
SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2_common/pico_platform/include

CFLAGS= -c -g -mcpu=$(MACH) -DPICO_RP2040=1 -mthumb -std=gnu11 -Wall -O0 ${SDK_INCLUDES}

# --just-symbols pulls in symbols from outside elf files
LFLAGS= -nostdlib -T main.ld  -Wl,--just-symbols=../basic-runtime/basic-runtime.elf -Wl,-Map=main.map

#all: main0.elf main1.elf
all: main.elf

main.o: main.s dump-routines.s input-routines.s
	$(CC) $(CFLAGS) -o $@ main.s

# --- choose uart0-io or uart1-io for use with main:
uart0-io.o: uart0-io.s
	$(CC) $(CFLAGS) -o $@ $^

#uart1-io.o: uart1-io.s
#	$(CC) $(CFLAGS) -o $@ $^

# --- main:
main.elf: main.o uart0-io.o
	$(CC) $(LFLAGS) -o $@ $^
	$(DIS) -D main.elf >main.dis

clean:
	-rm -f $(wildcard *.o)
	-rm -f $(wildcard *.elf)
	-rm -f $(wildcard *.uf2)
	-rm -f $(wildcard *.map)
	-rm -f $(wildcard *.dis)

# Define the root of your SDK
#PICO_SDK_PATH ?= /path/to/pico-sdk

## Required include paths for hardware registers
#SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2040/hardware_regs/include
#SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/common/pico_base/include
#SDK_INCLUDES += -I$(PICO_SDK_PATH)/src/rp2_common/pico_platform/include
#
## Update your CFLAGS
#CFLAGS = -c -g -mcpu=$(MACH) -mthumb -std=gnu11 -Wall -O0 $(SDK_INCLUDES)

# EOF:
