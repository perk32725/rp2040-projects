// basic-runtime.S
// from Life with David: Bare Metal Adventures

.cpu cortex-m0plus
.thumb

.section .reset
.global _reset
// -- do this when we put the vector table in RAM:
//
//    ldr r0, =0xe000ed08
//    ldr r1, =0x20000000
//    str r1, [r0]
//    dsb
//    isb

_reset:

// Set up the Crystal oscillator
    ldr r0, =xosc_base  // 0x40024000 load xosc base address
    mov r1, #0xaa       // load 10101010 into r1
    lsl r1, r1, #4      // and shift to 101010100000
    str r1, [r0, #0]    // and store into XOSC:CNTL 2.16.7
    mov r1, #47         // load startup delay of "47" 2.16.3
    str r1, [r0, #0xc]  // and store in XOSC:STARTUP 2.16.7

// Start the XOSC
    ldr r0, =xosc_aset  // 0x40026000 load in the xosc atomic set register base address
    ldr r1, =xosc_en    // 0x00fab000 load in xosc enable word 2.16.7
    str r1, [r0, #0]    // and store in the atomic set register for XOSC:CNTL 2.16.7

// --- Wait for the crystal to start up
    ldr r0, =xosc_base  // 0x40024000 load xosc base address
xosc_rdy:
    ldr r1, [r0, #0x04] // load in XOSC:STATUS 2.16.7
    lsr r1, r1, #31     // and shift over 31 bits to isolate STABLE bit
    beq xosc_rdy        // if not stable, check again

// --- now the crystal oscillator is running, switch clock sources
    ldr r0, =clok_base  // 0x40008000 load in clock registers base address
    mov r1, #2          // selects the xosc for the ref clock
    str r1, [r0, #0x30] // save it in CLOCKS: CLK_REF_CTRL 2.15.7
    mov r1, #0          // selects the ref clock for the system clock
    str r1, [r0, #0x3c] // save it in CLOCKS: CLK_SYS_CTRL 2.15.7

// this selects the clock to output for CLK_GPOUT0 for debugging
    mov r1, #0xa        // load in bits for selecting clk_ref for CLK_GPOUT0
                        // 0x4-ROSC, 0x5-XOSC, 0x6-clk_sys, 0xa-clk_ref
    lsl r1, r1, #5      // move to bit 5
    str r1, [r0, #0x00] // store in CLOCKS: CLK_GPOUT0_CTRL 2.15.7
    ldr r0, =clok_aset  // 0x4000a000 load in clock atomic set register base
    mov r1, #1          // load in 1 bit
    lsl r1, r1, #11     // shift over 11 bits to enable CLOCKS: CLK_GPOUT0_CTRL
    str r1, [r0, #0x00] // store clock enable bit in CLOCKS: CLK_GPOUT0_CTRL atomic set reg

// --- set up the PLL for xosc
// bring pll out of reset
// releases the peripheral reset for pll_sys
    ldr r0, =rst_clr    // 0x4000f000 atomic register for clearing reset controller (0x4000c000+0x3000)
    mov r1, #1          // load a 1 into bit 1
    lsl r1, r1, #12     // shift over 12 bits for pll_sys
    str r1, [r0, #0]    // store the bitmask into the atomic register to clear register

// check if reset is done
pll_rst:
    ldr r0, =rst_base   // 0x4000c000 base address for reset controller
    ldr r1, [r0, #8]    // offset to get to the reset_done register
    mov r2, #1          // load 1 in bit 1 of register 2
    lsl r2, r2, #12     // shift over 12 bits for pll_sys
    and r1, r1, r2      // isolate bit 12
    beq pll_rst         // if bit 12 is 0 then check again, if not, reset is done

// --- now enable pll_sys
    ldr r0, =pll_sys_base   // 0x40028000
    mov r1, #125        // exact 125MHz lock at FBDIV=125, PD1=6, PD2=2, 2.18.2.1
    str r1, [r0,#8]     // store in PLL: FBDIV_INT 2.18.4
    mov r1, #0x62       // PD1 = 6, PD2 = 2
    lsl r1, r1, #12     // and shift over 12 bits
    str r1, [r0, #0x0c] // store in PLL: PRIM 2.18.4

// --- power up the pll
    ldr r0, =pll_sys_aclr   // 0x4002b000
    mov r1, #0x21       // clear PD, VCOPD in PLL: PWR
    str r1, [r0,#4]     // store in PLL: PWR 2.18.4

// wait for the pll to lock
    ldr r0, =pll_sys_base   // 0x40028000
pll_lock:
    ldr r1, [r0, #0]    // load in the pll status register
    lsr r1, r1, #31     // isolate the "pll locked" bit
    beq pll_lock        // if not locked, check again

// --- set the pll divisor here if desired

// --- enable the pll_lock
    ldr r0, =pll_sys_aclr   // 0x4002b000
    mov r1, #0x08       // clear POSTDIVPD in PLL: PWR to power up
    str r1, [r0, #4]

// --- switch from ref clock to pll (pll is the aux source default)
    ldr r0, =clok_base  // 0x40008000
    mov r1, #1          // change to clksrc_clk_sys_aux in CLOCKS: CLK_SYS_CTRL 2.15.7
                        // clksrc_pll_sys is the default for clksrc_clk_sys_aux
    str r1, [r0, #0x3c] // store in CLOCKS: CLK_SYS_CTRL 2.15.7

// --- releases the peripheral reset for iobank_0
    ldr r0, =rst_clr    // 0x4000f000 atomic register for clearing reset controller (0x4000c000+0x3000)
    mov r1, #32         // load a 1 into bit 5
    str r1, [r0, #0]    // store the bitmask into the atomic register to clear register

// wait for iobank_0 reset:
iob_rst:
    ldr r0, =rst_base   // 0x4000c000 base address for reset controller
    ldr r1, [r0, #8]    // offset to get to the reset_done register
    mov r2, #32         // load 1 in bit 5 of register 2 (...0000000000100000)
    and r1, r1, r2      // isolate bit 5
    beq iob_rst         // if bit five is 0 then check again, if not, reset is done

// --- copy vector table to our dynamic vector table:
    ldr r0, =0x10000100 // start of FLASH vector table
    ldr r1, =0x20000000 // where we put it
    mov r2, #48         // 48 vectors total

vloop:
    ldr r3, [r0]        // load
    str r3, [r1]        // store
    add r0, #4          // inc 1 word
    add r1, #4          // inc 1 word
    sub r2, #1          // dec
    bne vloop           // ho-hum ...

    // setup VTOR:
    ldr r0, =0x20000000 // our vector table
    ldr r1, =0xe000ed08 // vector table offset register 2.4.8
    str r0, [r1]

jmp2main:
    ldr r0, =main       // point to main()
    mov r1, #1
    orr r0, r0, r1      // set bit 1 so we stay in THUMB mode
    bx  r0              // branch to main()

// -----------------------------------------------------------------------------
// DATA
// -----------------------------------------------------------------------------
    mov r0, r0          // word align

defined_data:
.equ main,         0x20000100
.equ sio_base,     0xd0000000   // SIO base 2.3.1.7

.equ clok_base,    0x40008000   // Clock register base address 2.15.7
.equ clok_aset,    0x4000a000   // Clock atomic set (base + 0x2000, see 2.1.2)

.equ rst_base,     0x4000c000   // reset controller base 2.14.3
.equ rst_clr,      0x4000f000   // reset atomic clear (base + 0x2000, see 2.1.2)

.equ xosc_base,    0x40024000   // XOSC Base address 2.16.7
.equ xosc_aset,    0x40026000   // XOSC atomic set (base + 0x2000, see 2.1.2)
.equ xosc_en,      0x00fab000   // enable word for xosc

.equ pll_sys_base, 0x40028000   // PLL system registers base address 2.18.4
.equ pll_sys_aclr, 0x4002b000   // PLL system atomic clear base address (base + 0x3000, see 2.1.2)


// EOF:
