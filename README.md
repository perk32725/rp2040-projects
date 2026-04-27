# rp2040-projects
SDK and Non-SDK projects with the Raspberry Pi Pico

**sdk-runtime** is a Swiss-Army knife for all the Pico goodies in the SDK

**sdk-prj1** is a basic TTY and flasher program for the Pico-W; example code shows how to connect to your local wireless, get the current time, and a few other bits and pieces.

**basic-runtime** follows the "Life with David" series on RP2040 bare-metal-assembly programming, setting up the clocks, GPIO, and either uart0 or uart1 for use with the **basic-tty** project.

**basic-tty** has a basic TTY program that allows you to examine memory, GPIO port configurations, and a few other things.

The idea here is to flash the runtime **once** (flashme script included) using a pico probe or equivalent, and use the gnu debugger to develop and troubleshoot programs.

Enjoy!
