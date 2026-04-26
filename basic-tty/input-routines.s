// included by main.s
// ************** input string routines ******************************
//------------------------------------------
// build_hex():
// Entry: r1 = ptr to asciz
// Exit:  r0 = binary value
//        r1 = ??
//------------------------------------------
build_hex:
    push    {r2,r3}
    mov     r3, #0      // the result

build_hex_loop:
    ldrb    r0, [r1]
    mov     r2, #'0'    // reset r2
    cmp     r0, #'9'
    bgt     maybe_af

    cmp     r0, r2      // '0'
    blt     out_range   // done

    sub     r0, r2      // convert to binary
    b       add2result  // add to the result

maybe_af:
    mov     r2, #0x4f   // mask to lower to upper case 'a-f'
    and     r0, r2      // mask r0

    mov     r2, #55
    sub     r0, r2      // knock r0 down

    mov     r2, #15     // max value
    cmp     r0, r2      // compare
    bgt     out_range   // too big

add2result:             // else must be > 9 && < 16
    lsl     r3, #4      // shift r3 left 4 bits
    orr     r3, r0      // or r0 into r3
    add     r1, #1      // move to next char
    b       build_hex_loop

out_range:              // no more hex
    mov     r0, r3      // result in r0
    pop     {r2,r3}
    bx      lr          // we are a leaf function

//------------------------------------------------
// scan4chr()
// entry:
//  r0 = char to look for
//  r1 = addr ptr
// exit:
//  r0 = char, or 0 if not found
//  r1 = addr of found char or the Zero
//------------------------------------------------
scan4chr:
    push    {r2}
    mov     r2, r0      // stash char in r2

scan_loop:
    ldrb    r0, [r1]    // grab a char from [r1]

    tst     r0, r0      // end of .asciz?
    beq     scan_done   // stop at the end

    cmp     r2, r0      // did we find it?
    beq     scan_done

    add     r1, #1      // ptr += 1
    b       scan_loop   // and loop

scan_done:
    pop     {r2}        // done
    bx      lr          // leaf function

//------------------------------------------
// scan40x()
// entry:
//   r1 = addr ptr
// exit:
//   r0 = char at [r1]
//   r1 = after the 'x', or at the null terminator
//------------------------------------------
scan40x:
    ldrb    r0, [r1]        // grab a char

    tst     r0, r0          // end of .asciz?
    beq     scan40x_done    // stop at the end

    add     r1, #1          // ptr += 1
    cmp     r0, #'0'        // found the '0'?
    bne     scan40x         // searching for that Zero

    ldrb    r0, [r1]        // check next character
    cmp     r0, #'x'        // found the 'x'?
    bne     scan40x         // searching for 0x

    add     r1, #1          // pass the 'x'
    ldrb    r0, [r1]        // grab the char

scan40x_done:
    bx      lr              // fast exit; this is a leaf function

//------------------------------------------
// build_dec():
// Entry: r1 = ptr to asciz
// Exit:  r0 = binary value
//        r1 = at ![0..9]
//------------------------------------------
build_dec:
    push    {r2,r3}
    mov     r3, #0     // init target

build_dec_loop:
    ldrb    r0, [r1]   // grab char
    cmp     r0, #'9'
    bgt     dec_outrange

    sub     r0, #'0'   // convert to binary
    blt     dec_outrange

    lsl     r2, r3, #3 // r2 = r3 * 8
    lsl     r3, #1     // r3 *= 2
    add     r3, r2     // add r3*8 (in r2) *10 in r3
    add     r3, r0     // add newest digit
    add     r1, #1     // next char
    b       build_dec_loop

dec_outrange:       // done
    mov     r0, r3  // save return value
    pop     {r2,r3}
    bx      lr      // fast exit; this is a leaf function

// EOF:
