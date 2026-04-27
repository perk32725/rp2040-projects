ENTRY(my_main)

MEMORY
{
    RAMAPP (rwx) : ORIGIN = 0x20020000, LENGTH = 64K
}

SECTIONS
{
    . = 0x20020000;
    /* The entry point must be the very first thing at 0x20020000 */
    .text : {
        KEEP(*(.entry_point)) 
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > RAMAPP

    .data : {
        . = ALIGN(4);
        *(.data*)
        . = ALIGN(4);
    } > RAMAPP

    .bss  : { 
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        __bss_end__ = .;
        . = ALIGN(4);
    } > RAMAPP
    /DISCARD/ : { *(.ARM.exidx*) }
}
