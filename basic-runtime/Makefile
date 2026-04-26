# Makefile- live with david-bma04 - bma07
#

MACH=cortex-m0plus
CC=${PICO_COMPILER} #arm-none-eabi-gcc
DIS=${PICO_TOOLCHAIN_PATH}/bin/arm-none-eabi-objdump
CFLAGS= -c -g -mcpu=$(MACH) -mthumb -std=gnu11 -Wall -O0
LFLAGS= -nostdlib -T basic-runtime.ld -Wl,-Map=basic-runtime.map

all: basic-runtime.elf

# boot2:
bs2_default_padded_checksummed.o:bs2_default_padded_checksummed.S
	$(CC) $(CFLAGS) -o $@ $^

# vector table:
vectors.o:vectors.s
	$(CC) $(CFLAGS) -o $@ $^

# sets up for UART0 communications:
setup_uart0.o:setup_uart0.s
	$(CC) $(CFLAGS) -o $@ $^

# sets up for UART1 communications:
setup_uart1.o:setup_uart1.s
	$(CC) $(CFLAGS) -o $@ $^

# puts the clock in order, enables IO:
basic-runtime.o:basic-runtime.s
	$(CC) $(CFLAGS) -o $@ $^

# the whole thing:
basic-runtime.elf:bs2_default_padded_checksummed.o vectors.o basic-runtime.o setup_uart0.o setup_uart1.o
	$(CC) $(LFLAGS) -o $@ $^
	$(DIS) -D basic-runtime.elf >basic-runtime.dis

# cleanup:
clean:
	-rm -f $(wildcard *.o)
	-rm -f $(wildcard *.elf)
	-rm -f $(wildcard *.uf2)
	-rm -f $(wildcard *.map)
	-rm -f $(wildcard *.dis)

# EOF:
