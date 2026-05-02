// picow_led.s:
// AI-generated assembly language program to set up
// and toggle the LED on a PicoW
// minor modifications to the original code was done by ME.

// --- Constants and Register Addresses ---
.equ SIO_BASE,         0xd0000000
.equ PADS_BANK0_BASE,  0x4001c000
.equ IO_BANK0_BASE,    0x40014000

// Pin Masks
.equ GP23_REG_ON, (1 << 23)
.equ GP24_DATA,   (1 << 24)
.equ GP25_CS,     (1 << 25)
.equ GP29_CLK,    (1 << 29)
.equ SPI_PINS,    (GP23_REG_ON | GP24_DATA | GP25_CS | GP29_CLK)

// CYW43439 Commands (Write, Function 1, 4 Bytes)
.equ CMD_GPIO_EN,  0x90322004  // Reg 0x18000644
.equ CMD_GPIO_OUT, 0x90320004  // Reg 0x18000640

.thumb_func
//.global _start
.global main

main:
//picow_led_init:
//_start:
    // --- 1. CONFIGURE IO FUNCTIONS (Set to SIO - Function 5) ---
    ldr r0, =IO_BANK0_BASE
    add r0, #0x80   // move up a trifle
    mov r1, #5
    str r1, [r0, #0x3c]  // GP23_CTRL
    str r1, [r0, #0x44]  // GP24_CTRL
    str r1, [r0, #0x4c]  // GP25_CTRL
    str r1, [r0, #0x6c]  // GP29_CTRL

    // --- 2. CONFIGURE PADS (8mA, Input Enable, Schmitt) ---
    ldr r0, =PADS_BANK0_BASE
    movs r1, #0x52
    str r1, [r0, #0x60]  // GP23
    str r1, [r0, #0x64]  // GP24
    str r1, [r0, #0x68]  // GP25
    str r1, [r0, #0x78]  // GP29

    // --- 3. INITIAL PIN STATES (STRAPPING) ---
    ldr r0, =SIO_BASE
    ldr r1, =GP25_CS
    str r1, [r0, #0x14]  // CS High
    ldr r1, =(GP24_DATA | GP29_CLK)
    str r1, [r0, #0x18]  // Data/Clock Low (Critical for SPI mode strap)

    // --- 4. ENABLE OUTPUTS ---
    ldr r1, =SPI_PINS
    str r1, [r0, #0x24]  // GPIO_OE_SET

    // --- 5. POWER UP CHIP ---
    ldr r1, =GP23_REG_ON
    str r1, [r0, #0x14]  // WL_REG_ON High
    
    ldr r0, =420000      // ~10ms delay at 125MHz
    bl  delay_cycles

    // --- 6. ENABLE LED OUTPUT ON WIRELESS CHIP ---
    ldr r0, =CMD_GPIO_EN
    ldr r1, =0x00000001  // Enable WL_GPIO0
    bl  write_register

// forever loop (initial test):
loop:
    // --- 7. LED ON ---
    ldr r0, =CMD_GPIO_OUT
    ldr r1, =0x00000001
    bl  write_register

    ldr r0, =2000000     // Simple delay
    bl  delay_cycles

    // --- 8. LED OFF ---
    ldr r0, =CMD_GPIO_OUT
    ldr r1, =0x00000000
    bl  write_register

    ldr r0, =2000000
    bl  delay_cycles
    b   loop

// --- HELPER: WRITE REGISTER ---
// R0 = Command, R1 = Data
write_register:
    push {r4, lr}
    mov r4, r1           // Save data
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #0x18]  // CS Low

    // Shift out Command
    bl  shift_out_32     // R0 already has cmd

    // Shift out Data
    mov r0, r4           // Restore data
    bl  shift_out_32

    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #0x14]  // CS High
    pop {r4, pc}

// --- HELPER: SHIFT OUT 32 BITS ---
// R0 = Value to shift
shift_out_32:
    ldr r1, =SIO_BASE
    ldr r2, =GP24_DATA
    ldr r3, =GP29_CLK
    movs r5, #32
bit_loop:
    lsl r0, #1
    bcs  set_high
    str  r2, [r1, #0x18] // Data Low
    b    pulse
set_high:
    str  r2, [r1, #0x14] // Data High
pulse:
    str  r3, [r1, #0x14] // Clock High
    str  r3, [r1, #0x18] // Clock Low
    sub  r5, #1
    bne  bit_loop
    bx   lr

// --- HELPER: DELAY ---
delay_cycles:
    sub  r0, #1
    bne  delay_cycles
    bx   lr

// EOF:
