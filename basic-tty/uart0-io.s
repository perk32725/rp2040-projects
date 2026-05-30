// uart0-io: stolen from:
// Life with David - BMA Chapter 08 - Demo 2
// basic UART0 setup and usage

/*
 Globals defined here:
   functions:
    .global uart_init
    .global uart_out
    .global prt_string

   in .bss_uart:
    .global inpbuffer
    .global inpptr
    .global something
 */

.cpu cortex-m0plus
.thumb

.section .uart, "ax"
.align 4

//------------------------------------------
// put our UART ISR in RAM vector table
// call setup_uart0
//------------------------------------------
.global uart_init
.type uart_init, %function
.thumb_func

uart_init:
    push    {lr}

    ldr     r0, =uart_isr   // our ISR
    ldr     r1, =0x20000090 // interrupt_20 in vector table
    str     r0, [r1]        // modify interrupt_20

    // long call to setup_uart0:
    ldr     r1, =setup_uart0
    blx     r1              // need indirect because FLASH

    pop     {pc}            // and we're done

// ************** interrupt handler **********************************
//------------------------------------------
// _uart_isr()
//------------------------------------------
.type uart_isr, %function
.thumb_func

uart_isr:
    push    {lr}
    ldr     r1, =uart0_rw   // base address for uart registers
    ldr     r0, [r1]        // grab a byte

    ldr     r1, =inpptr     // where in the buffer are we?
    ldr     r2, [r1]        // r2 has *inpptr

    cmp     r0, #8          // BS??
    bne     uart_chk_cr     // no...

    // it's a backspace:
    sub     r2, #1          // r1 = inpptr
    str     r2, [r1]        // put it back

    mov     r0, #32         // spit out a space
    bl      uart_out
    mov     r0, #8          // and another backspace
    bl      uart_out

    b       _uart_done

uart_chk_cr:
    cmp     r0, #0x0d       // CR?
    bne     add_char        // buffer the char and continue
    
    // it's a CR:
    mov     r0, #0          // zero out ...
    strb    r0, [r2]        // ... the string

    ldr     r2, =inpbuffer
    str     r2, [r1]        // reset inpptr
    ldr     r1, =something
    str     r2, [r1]        // say something
    b       _uart_done

// buffer the char:
// TODO: add check for buffer overflow
add_char:
    strb    r0, [r2]
    add     r2, #1
    str     r2, [r1]

_uart_done:
    mov     r0, #0x30       // reset bits
    ldr     r1, =uart0_rw   // base address for uart registers
    str     r0, [r1, #0x44] // say interrupt done
    pop     {pc}            // back to the shadows

//------------------------------------------
// uart_out()
// entry: r0 = char to send
//------------------------------------------
.equ UART_FLAG, 0x18
.equ UART_BUSY, 8
.equ UART_TXFULL, 32
.global uart_out
.type uart_out, %function
.thumb_func

uart_out:     // data out in r0
    push {r0,r1,r2,r3}

uart_out_loop:  
    ldr r1, =uart0_rw   // base address for uart0 registers
    ldr r2, [r1, #UART_FLAG] // read UART0 flag register UARTFR 4.2.8
//    mov r3, #UART_TXFULL   // mask for bit 5, TX FIFO full TXFF
    mov r3, #UART_BUSY  // mask for bit 3, UART BUSY 
    and r2, r3          // isolate bit 5 or 3
    bne uart_out_loop   // if uart busy or TX FIFO is full, go back and check again

    mov r2, #0xff       // bit mask for the 8 lowest bits
    and r0, r2          // get rid of all but the lowest 8 bits of data
    str r0, [r1]        // store data in uart data register, UARTDR

    pop {r0,r1,r2,r3}
    bx  lr              // we are a leaf function

//------------------------------------------
// prt_string()
// entry: r0 = string to print
//------------------------------------------
.global prt_string
.type prt_string, %function
.thumb_func

prt_string:
    push {r0,r1,lr}
    mov  r1, r0             // put strptr in r1

str_loop:
    ldrb r0, [r1]
    orr  r0, r0
    beq  str_done

    bl   uart_out
    add  r1, #1
    b    str_loop

str_done:
    pop  {r0,r1,pc}

//-----------------------------------------------------------
.section .uart_data, "a"
.align 4
uart_data:

.equ uart0_rw,      0x40034000 // UART0 register base address 4.2.8

// this is in RAM:
.section .bss_uart, "aw", %nobits

.global something
something:  .word    0  // say we should do something

.global inpptr
inpptr:     .word    0  // where we are in the buffer

.global inpbuffer
inpbuffer:  .skip  512  // space for input buffer (.skip fills with Zeros)

// EOF:
