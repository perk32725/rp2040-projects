// main.S:
/*
 Globals defined here:
    .global main
*/

.cpu cortex-m0plus
.thumb

.align 2
.section .main, "ax"

//------------------------------------------
// main()
//------------------------------------------
.global main
.type main, %function
.thumb_func

main:
    bl  uart_init       // in uart[01]-io.s
    ldr r0, =inpbuffer  // address of inpbuffer
    ldr r1, =inpptr     // pointer to r1
    str r0, [r1]        // address goes to inpptr

    // say we are on-line:
    ldr r0, =hello_world
    bl  prt_string
    ldr r0, =prompt
    bl  prt_string

    mov r0, #2          // use gpio2 for LED
    bl  gpio_out_setup  // and use our setup routine
    // returns r0 = sio_base, r1 = control bit

//------------------------------------------
// the forever loop:
// in use:
//   r0 = sio_base
//   r1 = GPIO control
// uses:
//   r3 = counter for delay()
// free to use:
//   r2-r7
//------------------------------------------
.equ GPIO_OUT_SET, 0x14
.equ GPIO_OUT_CLR, 0x18

led_loop:
    str     r1, [r0, #GPIO_OUT_SET] // ctrl bit goes to base GPIO address + 0x14: GPIO output set
    ldr     r3, =big_num    // load countdown number
    bl      delay           // branch to subroutine delay

    str     r1, [r0, #GPIO_OUT_CLR] // ctrl bit goes to base GPIO address + 0x18: GPIO output clear
    ldr     r3, =bigr_num   // load countdown number
    bl      delay           // branch to subroutine delay

    ldr     r2, =something  // is something flag on?
    ldr     r3, [r2]        // capture the flag
    orr     r3, r3          // set the Z flag
    beq     led_loop        // something = nothing

do_something:
    mov     r3, #0
    str     r3, [r2]        // say nothing

    push    {r0,r1}         // save GPIO pointer, control bit for LED
    bl      productive_stuff    // go and do wonderful things...

    ldr     r0, =prompt
    bl      prt_string      // say we're ready for next command

    pop     {r0,r1}         // put the LED registers back
    b       led_loop        // and loop

//.include "dump-routines.s"  // includes the main "productive stuff"

// -----------------------------------------------------------------------------
// DATA
// -----------------------------------------------------------------------------

.align 2

defined_data:
.equ big_num,       0x000f0000  // large number for the delay loop
.equ bigr_num,      0x00800000  // larger number for the delay loop
.equ sysinfo_base,  0x40000000  // SYSINFO_BASE 2.20
.equ syscfg_base,   0x40004000  // SYSCFG_BASE 2.21
.equ ctrl_base,     0x40014000  // GPIO04_CTRL 2.19.6.1
.equ sio_base,      0xd0000000  // SIO base 2.3.1.7

.equ dw_0,          0x30207764  // 'dw 0'
.equ di_0,          0x30206964  // 'di 0'
.equ db_0,          0x30206264  // 'db 0'
.equ show,          0x776f6873  // 'show'

.section .rodata
memmap:           .word 0x00000000,0x00003fff   // ROM
                  .word 0x10000000,0x10ffffff   // XIP flash
                  .word 0x20000000,0x2003ffff   // SRAM
                  .word 0x20040000,0x20041fff   // scratch space
                  .word 0x40000000,0x4fffffff   // peripherals
                  .word 0x50000000,0x50ffffff   // PIO/DMA
                  .word 0xd0000000,0xdfffffff   // SIO space
                  .word 0xe0000000,0xe00fffff   // PPB(System)

hello_world:      .asciz "\nHello World!"
prompt:           .asciz "\n>_\b"
do_something_msg: .asciz "\nDon't just do something, stand there!\n"
menu:             .asciz "menu:\ndw addr count, di addr count, db addr count,\nshow sys, show cfg, show gpio nn, \n"
gpio_msg:         .asciz "status   control\n"
hexw_msg:         .asciz "hex dump words:\n"
hexi_msg:         .asciz "hex dump ints:\n"
hexb_msg:         .asciz "hex dump bytes:\n"
outrange_msg:     .asciz ": out of range\n"
sysinfo_msg1:     .asciz "CHIP_ID: "
sysinfo_msg2:     .asciz "\nPLATFORM: "
sysinfo_msg3:     .asciz "\nGITREF_RP2040: "
hexscii_msg:      .asciz "|................|\n"

syscfg_msg1:      .asciz "PROC0_NMI: "
syscfg_msg2:      .asciz "\nPROC1_NMI: "
syscfg_msg3:      .asciz "\nPROC_CONFIG: "
syscfg_msg4:      .asciz "\nPROC_IN_SYNC_BYPASS: "
syscfg_msg5:      .asciz "\nPROC_IN_SYNC_BYPASS_HI: "
syscfg_msg6:      .asciz "\nDBGFORCE: "
syscfg_msg7:      .asciz "\nMEMPOWERDOWN: "

.align 4    // balance out the data

// this is in RAM:
.section .bss_main, "aw", %nobits
hexscii_:   .skip   20  // space for hexscii_output: '|...|\n\0'

// EOF:
