/* Relocatable EE guest module. No absolute base, CRT or game heap symbols. */
SECTIONS
{
  .text 0 : { *(.text .text.* .gnu.linkonce.t.*) }
  .rodata 0 : { *(.rodata .rodata.* .rdata .gnu.linkonce.r.*) }
  .data 0 : { _gp = .; *(.data .data.* .gnu.linkonce.d.*) }
  .init_array 0 : {
    __init_array_start = .;
    KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
    KEEP(*(.init_array))
    KEEP(*(SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP(*(.ctors))
    __init_array_end = .;
  }
  .fini_array 0 : {
    __fini_array_start = .;
    KEEP(*(SORT_BY_INIT_PRIORITY(.fini_array.*)))
    KEEP(*(.fini_array))
    KEEP(*(SORT_BY_INIT_PRIORITY(.dtors.*)))
    KEEP(*(.dtors))
    __fini_array_end = .;
  }
  .bss 0 (NOLOAD) : { *(.bss .bss.* .gnu.linkonce.b.*) *(COMMON) }
}
