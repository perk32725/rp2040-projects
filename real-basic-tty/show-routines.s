.cpu cortex-m0plus
.thumb

.align 2
.section .main.output, "ax"

//----------------------------------------------
// show_stat_reg
// entry: r0
//----------------------------------------------
.type show_stat_reg, %function
.thumb_func
.global show_stat_reg
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
.global show_ctrl_reg
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

.section .rodata

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

// this is in RAM:
.align 4    // balance out the data
.section .bss_main, "aw", %nobits
decout_buffer:  .skip 32
decout_ptr:     .word 0

// EOF:
