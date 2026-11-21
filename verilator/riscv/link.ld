/* Single RAM region; edit ORIGIN/LENGTH for your memory map. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
  RAM (rwx) : ORIGIN = 0x0000000, LENGTH = 64K
}

STACK_SIZE = 4K;

SECTIONS {
  .text : {
    KEEP(*(.text.start))        /* _start first, at ORIGIN */
    *(.text .text.*)
  } > RAM

  .rodata : ALIGN(4) { *(.rodata .rodata.* .srodata .srodata.*) } > RAM

  .data : ALIGN(4) {
    *(.data .data.*)
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
  } > RAM

  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.sbss .sbss.* .bss .bss.* COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  .stack (NOLOAD) : ALIGN(16) {
    . += STACK_SIZE;
    __stack_top = .;
  } > RAM

  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
