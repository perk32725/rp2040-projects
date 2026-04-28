// included by main.s

// ************** subroutines and productive stuff ******************
//------------------------------------------
// checkaddr()
// check r1 against memory map
// entry:
//  r0 = bit mask for boundaries
//  r1 = address to check
// exit:
//  r0 = 0 if all ok, else 1 with error message
//------------------------------------------
.type check_addr, %function
//.thumb_func

checkaddr:
    push    {r1-r4,lr}
    ldr     r2, =memmap     // set what we compare against
    mov     r3, #8          // set counter (8 blocks)
    mov     r4, r0          // save boundary

ca_loop:
    ldr     r0, [r2]        // grab a memory map start address
    cmp     r1, r0
    blt     ca_err          // too small...

is_ge:
    ldr     r0, [r2, #4]    // grab a memory map stop address
    sub     r0, r4          // subtract boundary
    cmp     r1, r0          // see if we are going over the top
    ble     is_le           // we are not

    add     r2, #8          // next entry
    bne     ca_loop         // keep going
    b       ca_err

is_le:
    mov     r0, r1          // put address in r0
    and     r1, r4          // mask the last bit or two
    bne     ca_err          // if we came up non-zero

is_inrange:
    mov     r0, #0          // flag in range
    b       ca_done

ca_err:
    mov     r0, #0x0a
    bl      uart_out

    mov     r0, r1
    bl      prt_reg

    ldr     r0, =outrange_msg
    bl      prt_string
    mov     r0, #1          // flag error

ca_done:
    pop     {r1-r4,pc}     // done

//----------------------------------------------
// setup_r1r2():
// entry:
//   inpbuffer = 'hd 0xxxxxxxxx nnn...
// calls:
//   scan40x
//   build_hex
//   build_dec
// exit:
//   r1 = given start address or 0 if '0x' not found
//   r2 = given count
//----------------------------------------------
setup_r1r2:
    push {lr}
    ldr  r1, =inpbuffer
    bl   scan40x
    orr  r0, r0
    beq  r1r2_done

r1r2_1:
    bl   build_hex  // build the hex address
    push {r0}       // save the address
    add  r1, #1     // move up

    // build the decimal count:
    bl   build_dec
    orr  r0, r0     // check result
    bne  r1r2_nz    // we have a limit
    mov  r0, #16    // set a limit

r1r2_nz:
    mov  r2, r0     // put count in r2 for dump_
    pop  {r1}       // addr ptr in r1, count in r2

r1r2_done:
    pop  {pc}

//------------------------------------------------
// dump_words()
// entry:
//   r1 = start of memory
//   r2 = word counter
// exit:
//   r0 trashed
//   r1 advanced to start + word counter
//   r2 = 0 if we exited normally, or entry count
//------------------------------------------------
.type dump_words, %function
.thumb_func

dump_words:
    push    {r3,lr}

dw_newline:
    mov     r3, #4      // reset words per line counter
    mov     r0, #0x0a
    bl      uart_out    // goto next line

    mov     r0, r1      // get the address
    bl      prt_reg     // print it nicely

dw_loop:
    mov     r0, #3      // word boundary - 1
    bl      checkaddr   // in range?
    orr     r0, r0      // check return value
    bne     dw_done     // out of range

    ldr     r0, [r1]    // grab a 32-bit word
    bl      hexoutw     // hexout the word
    mov     r0, #' '
    bl      uart_out    // and a space

    add     r1, #4      // move ptr up one word
    sub     r2, #1      // dec word counter
    beq     dw_done     // no more words

    sub     r3, #1      // dec words per line counter
    bne     dw_loop     // go 'round again, r
    b       dw_newline  // print out a new line

dw_done:
    mov     r0, #0x0a   // \n
    bl      uart_out    // spit out final NL
    pop     {r3,pc}     // done

//-----------------------------------------
// dump_ints():
// entry:
//  r1 = inpbuffer
//  r2 = count
//-----------------------------------------
.type dump_ints, %function
.thumb_func

dump_ints:
    push    {r3,lr}

di_newline:
    mov     r3, #8      // reset ints per line counter
    mov     r0, #0x0a
    bl      uart_out    // goto next line

    mov     r0, r1      // get the address
    bl      prt_reg     // print it nicely

di_loop:
    mov     r0, #1      // int boundary - 1
    bl      checkaddr
    orr     r0, r0
    bne     di_done     // out of range

    ldrh    r0, [r1]    // grab a 16-bit int
    bl      hexouti     // hexout 16 bits
    mov     r0, #' '
    bl      uart_out    // and a space

    add     r1, #2      // move up to the next word
    sub     r2, #1      // dec word counter
    beq     di_done     // no more words

    sub     r3, #1      // dec ints per line counter
    bne     di_loop     // go 'round again
    b       di_newline  // print out a new line

di_done:
    mov     r0, #0x0a
    bl      uart_out
    pop     {r3,pc}

//-----------------------------------------
// dump_bytes():
// entry:
//  r1 = inpbuffer
//  r2 = count
// outputs address in hex, ytes in hex,
// space separated, and ascii values if any
// after 16 bytes or end of data.
//-----------------------------------------
// 0123456789012345678901234567
// |................|n0
.type dump_bytes, %function
.thumb_func

dump_bytes:
    push    {r3,r4,r5,lr}

prep_dump_bytes:
    ldr     r4, =hexscii_       // target
    ldrb    r0, [r4]
    cmp     r0, #'|'
    beq     db_goahead          // assume we are ready

    ldr     r5, =hexscii_msg    // source
    mov     r3, #20             // count

prep_loop:
    ldrb    r0, [r5]            // source
    strb    r0, [r4]            // to target
    add     r4, #1
    add     r5, #1
    sub     r3, #1              // dec
    bne     prep_loop           // and loop

db_goahead:
    mov     r3, #16     // 16 bytes per line
    ldr     r4, =hexscii_
    add     r4, #1      // move up a trifle

db_loop:
    mov     r0, #0      // no boundaries
    bl      checkaddr
    orr     r0, r0
    bne     db_done     // out of range

    ldrb    r0, [r1]    // grab a byte
    bl      hexoutb     // hexout the byte
    mov     r0, #' '
    bl      uart_out    // and a space

// plunk byte into hexscii_
    ldrb    r0, [r1]    // grab it again
    cmp     r0, #' '
    blt     db_dot      // binary
    cmp     r0, #127
    blt     db_char     // it's a char

db_dot:
    mov     r0, #'.'    // say we're a dot...

db_char:
    strb    r0, [r4]    // plunk into hexscii_
    add     r4, #1      // next hexscii
    add     r1, #1      // mov up to the next address
    sub     r2, #1      // dec byte counter
    beq     db_done     // no more bytes

    sub     r3, #1      // dec bytes per line
    beq     db_newline  // end of line
    b       db_loop     // go 'round again

db_newline:
    ldr     r4, =hexscii_   // reset ptr
    mov     r0, r4          // copy it
    add     r4, #1          // move target ptr up a trifle
    bl      prt_string      // print the hexscii string

    mov     r3, #16         // reset bytes per line counter

    mov     r0, r1          // get the address
    bl      prt_reg         // print it nicely
    b       db_loop

db_done:
    ldr     r3, =hexscii_   // back to the beginning again...
    add     r3, #17         // move up to the end
    sub     r3, r4          // how far did we get?
    beq     db_exit         // got 'em all

// put in spaces so we can format  hexscii_
dbd_fill:
    mov     r0, #' '
    bl      uart_out
    bl      uart_out
    bl      uart_out        // 3 spaces per byte
    strb    r0, [r4]        // fill in hexscii_
    add     r4, #1
    sub     r3, #1
    bne     dbd_fill        // fill in spaces

// print out hexscii_ and we're done:
db_exit:
    ldr     r0, =hexscii_
    bl      prt_string      // print the hexscii string

    pop     {r3,r4,r5,pc}

//------------------------------------------
// prt_reg():
// entry:
//  r0 = word to dump
// outputs register value in hex, adds ': '
//------------------------------------------
.type prt_reg, %function
.thumb_func

prt_reg:
    push    {r0-r1,lr}
    mov     r1, r0      // save

    bl      hexoutw

    mov     r0, #':'    // add ': '
    bl      uart_out
    mov     r0, #' '
    bl      uart_out

    pop     {r0-r1,pc}

//------------------------------------------
// hexoutw():
// entry:
//  r0 = word to dump
// outputs r0 value in hex
//------------------------------------------
.type hexoutw, %function
.thumb_func

hexoutw:
    push    {r0-r1,lr}
    mov     r1, r0      // save

    asr     r0, #16
    bl      hexouti

    mov     r0, r1
    bl      hexouti

    pop     {r0-r1,pc}

//-----------------------------------------
// hexouti():
// entry:
//  r0 = int to dump
// outputs half-word r0 value in hex
//-----------------------------------------
.type hexouti, %function
.thumb_func

hexouti:
    push    {r1,lr}
    mov     r1, r0      // save

    asr     r0, #8      // shift upper byte down
    bl      hexoutb

    mov     r0, r1      // restore
    bl      hexoutb

    pop     {r1,pc}

//-----------------------------------------
// hexoutb():
// entry:
//  r0 = byte to dump
// outputs byte r0 value in hex
//-----------------------------------------
.type hexoutb, %function
.thumb_func

hexoutb:
    push    {r1,r2,lr}
    mov     r2, #0x0f   // mask

    mov     r1, r0      // save
    asr     r0, #4      // shift upper niblet

    and     r0, r2      // mask
    cmp     r0, #10     // compare
    blt     ready1      // ready to print
    add     r0, #39     // go a-f

ready1:
    add     r0, #'0'    // make it printable
    bl      uart_out    // and print it

    mov     r0, r1      // restore
    and     r0, r2      // mask
    cmp     r0, #10     // compare
    blt     ready2      // ready to print

    add     r0, #39     // go a-f

ready2:
    add     r0, #'0'    // make it printable
    bl      uart_out    // and print it

    pop     {r1,r2,pc}  // done here

//------------------------------------------------
// intDivide:
// entry:
//   r0 = dividend
//   r1 = divisor
// exit:
//   r0 = quotient
//   r1 = remainder
//------------------------------------------------
.global intDivide
.type intDivide, %function
.thumb_func

.macro div_delay    // delay 8 cycles
    b 1f
1:  b 1f
1:  b 1f
1:  b 1f
1:
.endm

intDivide:
    push    {r2}
    ldr     r2, =sio_base
    str     r0, [r2, #0x60] // dividend
    str     r1, [r2, #0x64] // divisor
    div_delay               // 8-cycle delay
    ldr     r1, [r2, #0x74] // remainder
    ldr     r0, [r2, #0x70] // quotient
    pop     {r2}
    bx      lr
// 13 instructions

//------------------------------------------------------------------------
// reg2dec
// entry:
//   r0 = number to convert
//   r1 = ptr to output buffer
// exit:
//   r1 = ptr to output buffer
//
// improved from "RP2040 Assembly Language Programming" by Stephen Smith
// call ureg2dec for unsigned output
// call sreg2dec for nsigned output
//------------------------------------------------------------------------
.global ureg2dec
.type   ureg2dec, %function
.thumb_func

ureg2dec:
    push    {r1,r4,r6,r7, lr}
    mov     r6, r1      // r6 gets buffer ptr
    mov     r4, r1      // r4 gets buffer ptr too
    mov     r7, #0      // flag
    b       cvt_digits  // we're doing unsigned

.global sreg2dec
.type   sreg2dec, %function
.thumb_func

sreg2dec:
    push    {r1,r4,r6,r7, lr}
    mov     r6, r1      // r6 gets buffer ptr
    mov     r4, r1      // r4 gets buffer ptr too
    mov     r7, #0      // flag

    cmp     r0, #0      // check sign
    bpl     cvt_digits

    mov     r7, #1      // say it's negative
    neg     r0, r0      // and negate the number

cvt_digits:
    mov     r1, #10
    bl      intDivide

    add     r1, #'0'    // spit out remainder
    strb    r1, [r4]
    add     r4, #1

    cmp     r0, #0
    bne     cvt_digits  // not done yet

    cmp     r7, #0      // was it negative?
    beq     was_pos

    mov     r0, #'-'    // put a minus sign in the output
    strb    r0, [r4]
    add     r4, #1

was_pos:
    mov     r0, #0
    strb    r0, [r4]    // nul terminate
    sub     r4, #1
    sub     r2, r4, r6  // buffer link in r2

revloop:
    ldrb    r0, [r4]
    ldrb    r3, [r6]
    strb    r0, [r6]
    strb    r3, [r4]    // swap
    sub     r4, #1      // move back
    add     r6, #1      // move up
    sub     r2, #2      // count
    bpl     revloop     // swap some more

    pop     {r1,r4,r6,r7,pc}

// EOF:
