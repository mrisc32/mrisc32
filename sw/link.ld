/* -*- mode: ld-script; tab-width: 4; indent-tabs-mode: nil; -*-             */
/* ------------------------------------------------------------------------- */
/* Linker script for running code in the simulator.                          */
/* ------------------------------------------------------------------------- */

OUTPUT_FORMAT("elf32-mrisc32")
OUTPUT_ARCH("mrisc32")
ENTRY(_start)

__ram_start  = 0x00000200;

SECTIONS
{
    /* --------------------------------------------------------------------- */
    /* Read-only stuff goes into the ROM.                                    */
    /* --------------------------------------------------------------------- */

    . = __ram_start;

    .text :
    {
        *(.entry*)  /* Force the entry point to the start of the image */
        *(.text*)
    }

    .rodata :
    {
        *(.rodata*)
    }


    .data :
    {
        *(.data*)
    }

    .sdata :
    {
        *(.sdata*)
    }


    /* --------------------------------------------------------------------- */
    /* BSS sections.                                                         */
    /* We define __bss_start and __bss_size so the startup code knows what   */
    /* memory area to clear.                                                 */
    /* --------------------------------------------------------------------- */

    . = ALIGN(4);
    __bss_start = .;

    .sbss (NOLOAD) :
    {
        *(.sbss*)
        *(.scommon*)
    }

    .bss (NOLOAD) :
    {
        *(.bss*)
        *(COMMON)
    }

    . = ALIGN(4);
    __bss_size = . - __bss_start;

    __ram_free_start = .;
}
