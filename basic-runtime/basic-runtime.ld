/* Define the entry point label in your assembly file */
ENTRY(_reset)

MEMORY
{
    FLASH(rx) : ORIGIN = 0x10000000, LENGTH = 2048k
    /* RP2040 has 264KB of SRAM starting at 0x20000000 */
    SRAM(rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

SECTIONS
{
 /* Second stage bootloader is prepended to the image. It must be 256 bytes big
       and checksummed. It is usually built by the boot_stage2 target
       in the Raspberry Pi Pico SDK
  */

    .flash_begin : {
        __flash_binary_start__ = .;
    } > FLASH

    .boot2 : {
        __entry_point__ = .;
		__boot2_start__ = .;
        KEEP (*(.boot2))
        __boot2_end__ = .;
    } > FLASH

    ASSERT(__boot2_end__ - __boot2_start__ == 256,
        "ERROR: Pico second stage bootloader must be 256 bytes in size")

    /* The second stage will always enter the image at the start of .text.
       The debugger will use the ELF entry point, which is the _entry_point
       symbol if present, otherwise defaults to start of .text.
       This can be used to transfer control back to the bootrom on debugger
       launches only, to perform proper flash setup.
    */

    /* Your vector table follows Boot2 */
    .text : {
        . = ALIGN(256);
        __vectors_start__ = .;
        KEEP (*(.vectors))      /* .section .vectors in vectors.s */
        __vectors_end__ = .;

        . = ALIGN(256);
        __reset_start__ = .;
        _reset = .;
        KEEP (*(.reset*))       /* .section .reset in reset.s */
        __reset_end__ = .;

        __uart_start__ = .;
        KEEP (*(.uart*))        /* .section .uart* in uart*.s */
        __uart_end__ = .;
    } > FLASH

    /* Place main code at the start of SRAM */
    .main : {
        . = ALIGN(4);
        __main_start__ = .;
        KEEP (*(.main*))        /* .section .main in source: my program code */
        __main_end__ = .;
    } > SRAM

    .data : { *(.data*) } > SRAM
    .bss  : { *(.bss*)  } > SRAM
    /* Define the top of the stack (grows downwards) */
    _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}

/* EOF: */
