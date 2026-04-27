# we now have a means to program a PICO so that it initializes from FLASH
# and then executes in RAM
#
# This version uses the Pico SDK residing in FLASH so we can play in RAM
# starting at 0x20020000
#
# Next step: split this into a 'runtime' project and 'other (RAM)' project
#
# use 'openocd -c "adapter speed 5000" -c "program reset.elf verify reset exit"
#   to flash boot2, vectors, and _reset
# use 'openocd' on it's own to set up the interface in a new window
# then use 'picodb main.elf' to debug your new main

# --- dump symbols:
# nm file.elf

# picodb is an alias:
#   alias picodb=/Applications/ARMGnuToolchain/15.2.rel1/arm-none-eabi/bin/arm-none-eabi-gdb

# .gdbinit:
#   target extended-remote :3333
#   load
#   monitor reset init
#   b main
#   continue

# debugging with the probe:

# using UART0:
# ls /dev/tty.usbmodem*
# minicom -D /dev/tty.usbmodem*

# export OPENOCD_SCRIPTS="$HOME/Desktop/Pico-W/openocd-0/scripts
# openocd -s $OPENOCD_SCRIPTS -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000"

# use flash-me to FLASH:
# ./flash-me reset.elf

# alias picodb=/Applications/ARMGnuToolchain/15.2.rel1/arm-none-eabi/bin/arm-none-eabi-gdb

#export PICO_TOOLCHAIN_PATH="/Applications/ARMGnuToolchain/15.2.rel1/arm-none-eabi"
# alias picodb="$PICO_TOOLCHAIN_PATH/bin/arm-none-eabi-gdb"
# using SDK:
#   cd to the project directory, and run:
#   picodb build/picow_blink.elf

(gdb) target extended-remote :3333
(gdb) add-symbol-file build/runtime.elf
(gdb) load
(gdb) monitor reset init
(gdb) b my_main
(gdb) continue

disassemble /m or /s shows source code; /r shows it in raw form (optional);
  use _entry_point[,+NNN
(gdb) disassemble /m &main

# disassemble:
disassemble start,end

# examine 10 instructions, starting at 'start':
(gdb) x/10i start

# dump memory:
(gdb) x/4xw 0x10000100  # show what should be vectory table
(gdb) x/8i  0x20000000  # disassemble start of RAM
(gdb) x/8i  0x10000000  # disassemble boot2
(gdb) x/8c  0x20000000  # display 8 characters

# dump registers:
(gdb) x/w   $pc|$sp|$r1|$r2|$r3...

# show all registers:
(gdb) i r

# EOF:
