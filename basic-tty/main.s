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
    str r1, [r0, #GPIO_OUT_SET] // 0x14 GPIO output value set
    ldr r3, =big_num    // load countdown number
    bl delay            // branch to subroutine delay

    str r1, [r0, #GPIO_OUT_CLR] // 0x18 GPIO output value clear
    ldr r3, =bigr_num   // load countdown number
    bl delay            // branch to subroutine delay

    ldr r2, =something  // is something flag on?
    ldr r3, [r2]        // capture the flag
    orr r3, r3          // set the Z flag
    beq led_loop        // something = nothing

do_something:
    mov r3, #0
    str r3, [r2]        // say nothing

    push    {r0,r1}
    bl      productive_stuff
    pop     {r0,r1}

    mov r4, r0          // save sio_base into r4
    ldr r0, =prompt
    bl  prt_string      // say we're ready for next command

    mov r0, r4          // restore sio_base to r0
    b   led_loop        // and loop

//--------------------------------------------
// .ltorg is for Literal Organization
// it sets up a nearby place where a routine
// can find data
//--------------------------------------------

.ltorg                  // stash nearby data here

//-----------------------------------------------------------------------
// gpio_out_setup: sets up a given GPIO pin for output
// entry:
//  r0 = gpio#
// exit:
//  r0 = sio_base
//  r1 = control bit
//-----------------------------------------------------------------------
.equ GPIO_OE_SET,  0x24
.equ GPIO_SIO_F,   5
gpio_out_setup:
    push {r2, r3}

    ldr  r1, =ctrl_base  // 0x40014000 gpio
    mov  r2, #GPIO_SIO_F // gpio control function 5: SIO
    lsl  r3, r0, #3      // r3 = gpio# * 8 = status offset from *_base
    add  r3, #4          // 4 = control register
    str  r2, [r1, r3]    // SIO function to ctrl_base + offset

    mov  r1, #1          // output enable mask
    lsl  r1, r0          // mask by gpio#

    ldr  r0, =sio_base   // 0xd0000000, SIO base
    str  r1, [r0, #GPIO_OUT_CLR] // set it low       
    str  r1, [r0, #GPIO_OE_SET]  // then enable output

    pop  {r2, r3}
    bx   lr

//------------------------------------------
// delay()
//------------------------------------------
delay:
    sub r3, #1          // subtract 1 from register 3
    bne delay           // loop back to delay if not zero
    bx lr               // return from subroutine

//-----------------------------------------
// hexdumpw(): wrapper for dump_words()
//-----------------------------------------
hexdumpw:
    ldr r0, =hexw_msg
    bl  prt_string      // say 'hex dump words:'
    bl  setup_r1r2      // returns address in r1, count in r2
    bl  dump_words      // then dump 32-bit words
    b   hex_done

//-----------------------------------------
// hexdumpi(): wrapper for dump_ints()
//-----------------------------------------
hexdumpi:
    ldr r0, =hexi_msg
    bl  prt_string      // say 'hex dump words:'
    bl  setup_r1r2      // returns address in r1, count in r2
    bl  dump_ints       // dump 16-bit ints
    b   hex_done

//-----------------------------------------
// hexdumpb(): wrapper for dump_bytes()
//-----------------------------------------
hexdumpb:
    ldr r0, =hexb_msg
    bl  prt_string      // say 'hex dump bytes:'
    bl  setup_r1r2      // returns address in r1, count in r2

    mov r0, r1          // do a prt_reg here because dump_bytes is complex
    bl  prt_reg         // print the address
    bl  dump_bytes      // dump bytes

//-----------------------------------------
// hex_done: common exit point
//-----------------------------------------
hex_done:
    pop {r0-r2,pc}      // done

.ltorg                  // stash nearby data here

//----------------------------------------------
// productive_stuff:
// entry: r0, r1 already saved
//----------------------------------------------
.type productive_stuff, %function
.thumb_func

productive_stuff:
// look at the first 4 bytes in inpbuffer, see if we can make something of them:
    push {r0-r2,lr}

    ldr  r1, =inpbuffer
    ldr  r0, [r1]

    // see if user wants to dump some memory:
    ldr  r2, =dw_0       // 'dw 0'
    cmp  r0, r2          // r0 == 'dw 0'?
    beq  hexdumpw        // goto hexdump words

    ldr  r2, =di_0       // 'di 0'
    cmp  r0, r2          // r0 == 'di 0'?
    beq  hexdumpi        // goto hexdump ints

    ldr  r2, =db_0       // 'db 0'
    cmp  r0, r2          // r0 == 'db 0'?
    beq  hexdumpb        // goto hexdump bytes

    // look for other commands:
    // show command

    ldr  r2, =show      // did they say show something?
    cmp  r0, r2
    bne  skip_show      // if not...

    // move up to next word (right after the 'w')
    // and see what else we have
    // show-io: show IO port statuses
    // show-tmp: show CPU temperature
    // show-cfg: show system config

    add  r1, #4
    ldrb r0, [r1]   // grab the next char
    add  r1, #1     // and move up
    cmp  r0, #' '   // space?
    bne  to_nullpgm // wasn't a space ...

skip_space:
    ldrb r0, [r1]   // grab next char
    add  r1, #1     // and move up
    cmp  r0, #' '   // another space?
    beq  skip_space

    cmp  r0, #'s'
    beq  show_sys   // show sys

    cmp  r0, #'c'
    beq  show_cfg   // show cfg

    cmp  r0, #'g'
    beq  show_gpio  // show gpio

to_nullpgm:
    b    null_pgm   // show error

.ltorg

show_sys:   // show_sys: show sysinfo stuff
    ldr  r1, =sysinfo_base

    ldr  r0, =sysinfo_msg1
    bl   prt_string // say 'CHIP_ID: '

    ldr  r0, [r1, #0] //#SYSINFO_CHIP_ID_OFFSET]
    bl   hexoutw

    ldr  r0, =sysinfo_msg2
    bl   prt_string // say 'PLATFORM: ' on a new line

    ldr r0, [r1, #4] //#SYSINFO_CHIP_ID_OFFSET]
    bl  hexoutw

    ldr r0, =sysinfo_msg3
    bl  prt_string  // say 'GITREF_RP2040: '

    ldr r0, [r1, #0x40] //#SYSINFO_PLATFORM_OFFSET]
    bl  hexoutw

    mov r0, #0x0a
    bl  uart_out
    b   hex_done

.ltorg

show_cfg:           // show_cfg: show something of the system configuration
    ldr  r1, =syscfg_base
    ldr  r0, =syscfg_msg1
    bl   prt_string // say 'PROC0_NMI'
    ldr  r0, [r1,#0]
    bl   hexoutw
    
    ldr  r0, =syscfg_msg2
    bl   prt_string // say 'PROC1_NMI'
    ldr  r0, [r1,#4]
    bl   hexoutw

    ldr  r0, =syscfg_msg3
    bl   prt_string // say 'PROC_CONFIG'
    ldr  r0, [r1,#8]
    bl   hexoutw

    ldr  r0, =syscfg_msg4
    bl   prt_string // say 'PROC_IN_SYNC_BYPASS'
    ldr  r0, [r1,#0x0C]
    bl   hexoutw

    ldr  r0, =syscfg_msg5
    bl   prt_string // say 'PROC_IN_SYNC_BYPASS_HI'
    ldr  r0, [r1,#0x10]
    bl   hexoutw

    ldr  r0, =syscfg_msg6
    bl   prt_string // say 'DBGFORCE'
    ldr  r0, [r1,#0x14]
    bl   hexoutw

    ldr  r0, =syscfg_msg7
    bl   prt_string // say 'MEMPOWERDOWN'
    ldr  r0, [r1,#0x18]
    bl   hexoutw

    mov  r0, #0x0a
    bl   uart_out
    b    hex_done

.ltorg

skip_show:          // so we can find null_pgm
    b   null_pgm

show_gpio:          // show gpio status and control: show g[pio] 0-29
    // we got a 'g'; scan until we get a space, then scan until we don't get a space
    ldrb r0, [r1]   // grab next char
    add  r1, #1     // and move up
    orr  r0, r0     // end?
    beq  skip_show  // oops

    cmp  r0, #' '   // space?
    bne  show_gpio  // scan to space

g_gotspace:
    ldrb r0, [r1]
    add  r1, #1
    orr  r0, r0
    beq  skip_show

    cmp  r0, #' '
    beq  g_gotspace

    sub  r1, #1     // move back a trifle
    bl   build_dec  // returns r0=decimal number, r1=char after number
    mov  r2, r0     // put the register # in r2 for later

    cmp  r2, #30    // 0-29 only
    bge  skip_show

    ldr  r0, =gpio_msg
    bl   prt_string // say 'status   control'

    ldr  r1, =ctrl_base
    lsl  r2, #3     // skip 8 bytes per n

    ldr  r0, [r1, r2]
    bl   hexoutw    // display what we have

    mov  r0, #' '
    bl   uart_out

    add  r1, #4     // goto control register
    ldr  r0, [r1, r2]
    bl   hexoutw    // display what we have
    
    mov  r0, #0x0a  // NL
    bl   uart_out

    sub  r1, #4     // back to status register
    ldr  r0, [r1, r2]
    bl   show_stat_reg

    add  r1, #4
    ldr  r0, [r1, r2]
    bl   show_ctrl_reg

    b   hex_done

    // if nothing computes, print an error message
    // and go back to the shadows again...
null_pgm:
    ldr r0, =do_something_msg
    bl  prt_string      // ... error ...
    ldr r0, =menu
    bl  prt_string
    b   hex_done        // done

.ltorg

.include "input-routines.s"

.include "dump-routines.s"

//----------------------------------------------
// show_stat_reg
// entry: r0
//----------------------------------------------
.type show_stat_reg, %function
.thumb_func
show_stat_reg:
    push    {r0-r4, lr}

    ldr     r0,=gstat_msg
    bl      prt_string  // say "status bits:\n"
    pop     {r0}        // get r0 back

    mov  r2, r0     // save for later
    mov  r1, #1     // mask

    asr  r0, r2, #26
    and  r0, r1
    beq  ssr_1

    ldr  r0, =IRQTOPROC_msg
    bl   prt_string // say set

ssr_1:
    asr  r0, r2, #24
    and  r0, r1
    beq  ssr_2

    ldr  r0, =IRQFROMPAD_msg
    bl   prt_string // say set

ssr_2:
    asr  r0, r2, #19
    and  r0, r1
    beq  ssr_3

    ldr  r0, =INTOPERI_msg
    bl   prt_string // say set

ssr_3:
    asr  r0, r2, #17
    and  r0, r1
    beq  ssr_4

    ldr  r0, =INFROMPAD_msg
    bl   prt_string // say set

ssr_4:
    asr  r0, r2, #13
    and  r0, r1
    beq  ssr_5

    ldr  r0, =OETOPAD_msg
    bl   prt_string // say set

ssr_5:
    asr  r0, r2, #12
    and  r0, r1
    beq  ssr_6

    ldr  r0, =OEFROMPERI_msg
    bl   prt_string // say set

ssr_6:
    asr  r0, r2, #9
    and  r0, r1
    beq  ssr_7

    ldr  r0, =OUTTOPAD_msg
    bl   prt_string // say set

ssr_7:
    asr  r0, r2, #8
    and  r0, r1
    beq  ssr_8

    ldr  r0, =OUTFROMPERI_msg
    bl   prt_string // say set

ssr_8:
show_stat_don:
    pop     {r1-r4, pc}

//----------------------------------------------
// show_ctrl_reg
// entry: r0 = control register
//----------------------------------------------
.type show_ctrl_reg, %function
.thumb_func
show_ctrl_reg:
    push    {r0-r4, lr}

    ldr     r0, =gctrl_msg
    bl      prt_string  // say "\nFunction: "
    pop     {r0}        // get r0 back

    mov     r1, #31
    and     r0, r1      // just the low 5 bits
    mov     r1, #10     // 10's will land in r0, 1's in r1

    bl      intDivide

wait_here:
    add     r0, #'0'
    bl      uart_out    // 0-3

    mov     r0, r1      // grab remainder
    add     r0, #'0'
    bl      uart_out    // 0-9

    mov     r0, #0x0a
    bl      uart_out    // NL
    bl      uart_out    // NL

// demo stuff:
    mov     r0, #9
    bl      demo_dec    // say 'Number 9'

    mov     r0, #0
    sub     r0, #1
    lsr     r0, #1
    bl      demo_dec    // show max positive integer

    mov     r0, #1
    lsl     r0, #31
    bl      demo_dec    // show max negative integer

    mov     r0, #0
    sub     r0, #1
    bl      demo_dec    // show -1

show_ctrl_don:
    pop     {r1-r4, pc}

// -----------------------------------------------------------------------------
// demo_dec:
// -----------------------------------------------------------------------------
demo_dec:
    push    {r0,r1,r7, lr}
    mov     r7, r0
    ldr     r1, =decout_buffer

    ldr     r0, =demomsg_0
    bl      prt_string

    mov     r0, r7
    bl      hexoutw     // print reg in hex

    mov     r0, #' '
    bl      uart_out

    mov     r0, r7
    ldr     r1, =decout_buffer
    bl      sreg2dec

    mov     r0, r1
    bl      prt_string  // print reg in signed decimal

    mov     r0, #' '
    bl      uart_out

    mov     r0, r7
    ldr     r1, =decout_buffer
    bl      ureg2dec

    mov     r0, r1
    bl      prt_string  // print reg in unsigned decimal

    mov     r0, #0x0a
    bl      uart_out    // NL
    bl      uart_out    // NL

    pop     {r0,r1,r7, pc}

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

gstat_msg:        .asciz "status bits:\n"
IRQTOPROC_msg:    .asciz "IRQTOPROC set, "
IRQFROMPAD_msg:   .asciz "IRQFROMPAD set, "
INTOPERI_msg:     .asciz "INTOPERI set, "
INFROMPAD_msg:    .asciz "INFROMPAD set, "
OETOPAD_msg:      .asciz "OETOPAD set, "
OEFROMPERI_msg:   .asciz "OEFROMPERI set, "
OUTTOPAD_msg:     .asciz "OUTTOPAD set, "
OUTFROMPERI_msg:  .asciz "OUTFROMPERI set"

gctrl_msg:        .asciz "\nFunction: "

demomsg_0:        .asciz "hex:     dec:        unsigned:\n"

.align 4    // balance out the data

// this is in RAM:
.section .bss_main, "aw", %nobits
hexscii_:   .skip   20  // space for hexscii_output: '|...|\n\0'
decout_buffer:  .skip 32
decout_ptr:     .word 0

// EOF:
