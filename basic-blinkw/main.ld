/* Define the entry point label in your assembly file */
ENTRY(main)

MEMORY
{
    FLASH(rx) : ORIGIN = 0x10000000, LENGTH = 2048k
    /* RP2040 has 264KB of SRAM starting at 0x20000000 */
    SRAM(rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

PHDRS
{
    text_seg PT_LOAD FLAGS(5); /* Read (4) + Execute (1) = 5 (RX) */
    data_seg PT_LOAD FLAGS(6); /* Read (4) + Write (2) = 6 (RW)   */
}

SECTIONS
{
    .ramvectors : {
        __ramvectors_start = .;
        . = . + 256;
        __ramvectors_end = .;

    } >SRAM :data_seg

    .text : {
        . = ALIGN(256);
        __main_start__ = .;
        KEEP (*(.main*))            /* Program code */
        __main_end__ = .;
    } > SRAM :text_seg

    .data : {
        . = ALIGN(4);
        __data_start__ = .;
        *(.data*)
        __data_end__ = .;
    } > SRAM :data_seg

    .bss  : {
        . = ALIGN(4); 
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
    } > SRAM :data_seg
}

/* EOF: */
