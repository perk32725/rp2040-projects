.cpu cortex-m0plus
.thumb

.align 2
.section .main.lib, "ax"

.equ sio_base,      0xd0000000  // SIO base 2.3.1.7
.equ ctrl_base,     0x40014000  // GPIO04_CTRL 2.19.6.1

//-----------------------------------------------------------------------
// gpio_out_setup: sets up a given GPIO pin for output
// entry:
//  r0 = gpio#
// exit:
//  r0 = sio_base
//  r1 = control bit
//-----------------------------------------------------------------------
.equ GPIO_OE_SET,  0x24
.equ GPIO_SIO_FN,  5
.equ CTRL_OFFSET,  4
.equ GPIO_OUT_CLR, 0x18
.equ GPIO_OUT_SET, 0x14


.type gpio_out_setup, %function
.thumb_func
.global gpio_out_setup

gpio_out_setup:
    push {r2, r3}

    ldr  r1, =ctrl_base   // 0x40014000 gpio
    mov  r2, #GPIO_SIO_FN // gpio control function 5: SIO
    lsl  r3, r0, #3       // r3 = gpio# * 8 = status offset from ctrl_base
    add  r3, #CTRL_OFFSET // 4 = control register
    str  r2, [r1, r3]     // set SIO function in [ctrl_base + offset]

    mov  r1, #1          // output enable mask
    lsl  r1, r0          // mask by gpio#

    ldr  r0, =sio_base   // 0xd0000000, SIO base
    str  r1, [r0, #GPIO_OUT_CLR] // set it low       
    str  r1, [r0, #GPIO_OE_SET]  // then enable output

    pop  {r2, r3}
    bx   lr

//------------------------------------------
// delay_nms:
//   entry: r2 = # of ms to delay
//   exit:  r2, r3 = 0
//
// delay_1ms:
//   entry: none
//   exit:  r3 = 0
//
// delay:
//   entry: r3 = counter
//   exit:  r3 = 0
//------------------------------------------
.type delay_nms, %function
.thumb_func
.global delay_nms
delay_nms:
    ldr r3, =800000     // 0xc3500 for 1 ms

delay_n:
    sub r3, #1          // subtract 1 from register 3
    bne delay_n         // loop back to delay if not zero

    sub r2, #1          // dec ms counter
    bne delay_nms       // do another

    bx lr               // return from subroutine

.type delay_1ms, %function
.thumb_func
.global delay_1ms
delay_1ms:
    ldr r3, =800000     // 0xc3500 for 1 ms

.type delay, %function
.thumb_func
.global delay
delay:
    sub r3, #1          // subtract 1 from register 3
    bne delay           // loop back to delay if not zero
    bx lr               // return from subroutine

//--------------------------------------------
// .ltorg is for Literal Organization
// it sets up a nearby place where a routine
// can find data
//--------------------------------------------

.ltorg                  // stash nearby data here

// EOF:
