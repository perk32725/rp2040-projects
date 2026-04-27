// my_asm.S
// simple template for Pi Pico assembly language programs
//
// what this does:
// not a thing
//
// inspired by:
// Life with David - Bare Metal Assembly

//.section .my_ram_section.my_asm, "ax"
.section .text.my_asm, "ax"
.global my_asm

// -----------------------------------------------------------------------------
// PUT INTERESTING STUFF HERE
// -----------------------------------------------------------------------------

.type my_asm, %function
.thumb_func
.align 2

my_asm:
        nop
        nop
        nop
        
        bx  lr

// EOF:
