# Reset entry: set up sp/gp, zero .bss, call main, then spin.
  .section .text.start, "ax"
  .globl _start
_start:

