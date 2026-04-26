// setup_uart0: stolen from:
// Life with David - BMA Chapter 08 - Demo 2
// basic UART0 setup

// this code resides in FLASH; call from RAM

.cpu cortex-m0plus
.thumb

// using KEEP (*(.reset*)) in reset.ld
//.section .reset_uart0_code, "ax"
.section .uart_setup, "ax"
.align 4

.global setup_uart0
.type setup_uart0, %function
.thumb_func

// ******************** initalize UART 0 ***********
// This sets up the UART to communicate

/*----------------------------------------------------------------------------------------
 * setup_uart0():
 * Set peripheral clock 2.15.7-do after xosc started and before UART brought out of reset
 *----------------------------------------------------------------------------------------
 */
setup_uart0:
   push {r0-r3}

.equ    clk_per_ctrl,   0x48
set_peri_clk:
    ldr r0, =clck_base  // Base for clocks register
    mov r1, #1          // load in first bit
    lsl r1, #11         // shift over 11 bits to enable the clock generator
    add r1, #128        // add 0b10000000 to select the crystal ocsillator
    str r1, [r0,#clk_per_ctrl]  // store in clk_peri_ctrl (...100010000000)

// First reset the uart
reset_uart:
    ldr r0, =rst_set    // atomic register for clearing reset controller (0x4000c000+0x2000)
    mov r1, #1          // load 1 into bit 0
    lsl r1, #22         // shift bit over to align with bit 22, UART0
    str r1, [r0]        // store the bitmask into the atomic register to assert UART0 reset

// Bring UART0 out of reset (deassert the reset)
deassert_uart_reset:
    ldr r0, =rst_clr    // atomic register for clearing reset controller (0x4000c000+0x3000)
    str r1, [r0]        // store the bitmask into the atomic register to deassert UART0 reset

.equ    uart_rst_done,  8
// check if UART0 reset is deasserted
uartrst:
    ldr r0, =rst_base   // base address for reset controller
    ldr r2, [r0, #uart_rst_done]    // offset to get to the reset_done register
    and r2, r1          // isolate bit 22
    beq uartrst         // if bit 22 is 0 then check again, if not, reset is done

    nop

// Enable UART receive and transmit and then enable uart 4.2.8 UARTCR 0b1100000001
.equ    uartcr, 0x30
enable_uart:
    ldr r0, =uart0_rw       // uart0 register base address 4.2.8
    mov r1, #3              // move 0b11 for 8 bit word UARTCR: RXE and TXE
    lsl r1, #8              // and shift it over to bits 8 and 9
    add r1, #1              // add bit for enable UARTCR: UARTEN
    str r1, [r0, #uartcr]   // store in UARTCR register

// set baudy rate of UART0  4.2.7.1
// Required Baud Rate: 115200; UARTCLK: 12MHz 2.16.1
// (12*10^6)/(16*115200)~=6.5104; BRDI=6, BRDF=0.5104, m=integer((0.514*64)+0.5)=33
.equ    uartibrd,   0x24
.equ    uartfbrd,   0x28
set_baud_rate:
    mov r1, #6              // integer baud rate
    str r1, [r0, #uartibrd] // store in integer baud rate register UARTIBRD 4.2.8
    mov r1, #33             // fractional Baud Rate
    str r1, [r0, #uartfbrd] // store in fractional baud rate register, UARTFBRD 4.2.8

// ************** uart word length and fifos **************

// **************** either ************************
/*
// set word length (8 bits) and ENABLE FIFOs UARTLCR_H 4.2.8
set_word_len:
    mov r1, #112            // 0b01110000 = 112 (UARTLCR_H) (112: fifos enabled, 96: fifos disabled)
    str r1, [r0, #0x2c]     // store in UARTLCR_H
*/

// ****************** or *************************
// set word length (8 bits) and DISABLE FIFOs UARTLCR_H 4.2.8
// then set interrupt mask RXIM so a single key press will interrupt
.equ    uartlcr_h,  0x2c
.equ    uartimsc,   0x38
set_word_len:
    mov r1, #96             // 0b01100000 = 96 (UARTLCR_H) (112: fifos enabled, 96: fifos disabled)
    str r1, [r0, #uartlcr_h] // store in UARTLCR_H
    mov r1, #16             // sets bit 4 for RXIM
    str r1, [r0, #uartimsc] // store in UARTIMSC

// ***********************************************

// Connect UART0 on iobank_0 pads 0 and 1 using "Function 2"    2.19.2
.equ    gpio0_ctrl, 4
.equ    gpio1_ctrl, 0x0c
config_uart_gpio:
    ldr r0, =iob0_rw        // base address iobank_0            2.19.6.1
    mov r1, #2              // function 2 UART0_TX & UART0_RX   2.19.2
    str r1, [r0, #gpio0_ctrl] // store function 2 in GPIO0_CTRL   2.19.6.1
    str r1, [r0, #gpio1_ctrl] // store function 2 in GPIO1_CTRL   2.19.6.1

// ************** init NVIC for uart0 handler ***************
.equ    nvic_uart0, 20
    ldr r0, =nvic_enable    // load in NVIC enable base address
    mov r1, #1              // set bit 0
    lsl r1, #nvic_uart0     // move set bit over to  bit 20
    str r1, [r0]            // store in NVIC_ISER (2.4.8.)

exit_setup_uart:
    pop {r0-r3}
    bx  lr

/*--------------------------------------
 * uart0_data:
 *--------------------------------------
 */
mov  r0, r0                     // word align

uart0_data:
.equ clck_base,     0x40008000  // Clock register base address
.equ rst_base,      0x4000c000  // reset controller base 2.14.3
.equ rst_set,       0x4000e000  // atomic register for setting reset controller 2.1.2
.equ rst_clr,       0x4000f000  // atomic register for clearing reset controller 2.1.2

.equ uart0_rw,      0x40034000  // UART0 register base address 4.2.8

.equ nvic_enable,   0xe000e100  // set interrupt enable
.equ iob0_rw,       0x40014000  // iobank_0 base address 2.19.6.1

/* EOF:
 */
