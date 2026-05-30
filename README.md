# rp2040-projects
SDK and Non-SDK projects with the Raspberry Pi Pico

The idea here is to flash the runtime **once** (flashme script included) using a pico probe or equivalent, and use the gnu debugger to develop and troubleshoot programs.

**Background:**
I started this project after watching the Life with David series 'Raspberry Pi Pico Bare Metal Programming'.
David's series is excellant for showing how to set up your environment.
I also snagged a lot of his github files to play with.

One of my goals was to set up a runtime environment that I could put into FLASH and have available for other projects, without having to constantly wear down the FLASH while I was developing and playing.  What I wanted to do was use a picoprobe to download programs that I was working on straight into RAM while I did the development work.

I spent a lot of time with whatever Google AI was available, and created a potentially useful runtime environment using the SDK.  I include it here, and I will fill in more info later; right now I am concentrating on the basic project.

I liked what David did with his videos, and how he taught many aspects of how to program the Pi Pico and the RP2040 in really down-and-dirty, bare-metal, no-SDK programming, using the GNU compiler and an editor.
I'm a Mac guy, so I get to use vim, gdb, minicom, and ttys to get things done, along with an RP2350 Geeek used as a probe, a breadboard, a resister and LED, and jumper wires.

**sdk-runtime** is a Swiss-Army knife for all the Pico goodies in the SDK

**sdk-prj1** is a basic TTY and flasher program for the Pico-W; example code shows how to connect to your local wireless, get the current time, and a few other bits and pieces.

**basic-runtime** follows the "Life with David" series on RP2040 bare-metal-assembly programming, setting up the clocks, GPIO, copies the vector table to low RAM (0x20000000), provides setup routines for uart0 and uart1 used in the **basic-tty** project, and then jumps off a cliff to 0x20000100, where you hopefully have something for the cpu to do.

**basic-tty** is a basic flasher program that demonstrates a few things:
  - it modifies the vector table for UART input,
  - it prints a greeting on the TTY,
  - it goes into a forever loop waiting for input.
  - While it's waiting, it toggles GPIO2 at 3 Hz, with a 25% (or so) duty cycle.
    Why GPIO2 instead of GPIO25 like everyone else?
    I only have Pico-W's, and I haven't (yet) gotten around to figuring out the LED on the Pico-W in assembly language.

  The input loop recognizes a few basic commands:
  - dw (dump word)
  - di (dump integers or half-words)
  - db (dump bytes)
  - show c(onfig)
  - show g(pio)

  dw, di, and db all expect arguments in the form:
    dx 0xaaaaaaaa nnn
  where aaaaaaaa is a hex address somewhere in the Raspberry Pi Pico environment, and nnn is the decimal number of words, ints, or bytes to dump.

  Note that the d- command needs to be followed by exactly 1 space, then '0x' and the hex address. (see scan40x in the source)

  The address is checked against an internal table of valid memory ranges, and if the starting address is valid, it will dump contents until the end of the given range or you run out of valid locations.

  'show c' takes no arguments, and just displays a few sections of the system configuration register.  It is left as an exercise for the student to break down the bits of the system register and display them.

  'show g' nn shows the configuration and status register for a given GPIO (0-31)

**real-basic-tty** is a stripped-down version of **basic-tty** with all the dump and show routines in the archive directory, suitable for sample code.

Enjoy!
