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

// -----------------------------------------------------------------------------
// do something interesting here:
// -----------------------------------------------------------------------------
productive_stuff:
    bx      lr

// -----------------------------------------------------------------------------
// DATA
// -----------------------------------------------------------------------------

.align 2

defined_data:
.equ big_num,       0x000f0000  // large number for the delay loop
.equ bigr_num,      0x00800000  // larger number for the delay loop

.section .rodata
prompt:           .asciz "\n>_\b"
hello_world:      .asciz "\nHello World!"

// EOF:
