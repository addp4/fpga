#!/bin/bash
set -euo pipefail
export PATH=$HOME/toolchains/rv32i-clang/bin:$PATH

~/toolchains/rv32i-clang/bin/riscv32-unknown-elf-clang \
  -O2 -ffreestanding -fno-builtin -ffunction-sections -fdata-sections \
  -nostdlib -static -T link.ld -Wl,--gc-sections \
  start.S prog.c -o prog.elf

~/toolchains/rv32i-clang/bin/llvm-objcopy -O binary -S prog.elf prog.bin

~/toolchains/rv32i-clang/bin/llvm-objdump -S prog.elf

od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c1-2 > mem3.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c3-4 > mem2.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c5-6 > mem1.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c7-8 > mem0.hex
echo "wrote mem0-3.hex"
