#!/bin/bash
export PATH=$HOME/toolchains/rv32i-clang/bin:$PATH

~/toolchains/rv32i-clang/bin/riscv32-unknown-elf-clang \
  -O2 -ffreestanding -fno-builtin -ffunction-sections -fdata-sections \
  -nostdlib -static -T link.ld -Wl,--gc-sections \
  prog.c -o prog.o

~/toolchains/rv32i-clang/bin/llvm-objcopy -O binary -S prog.o prog.bin

~/toolchains/rv32i-clang/bin/llvm-objdump -S prog.o

od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c1-2 | head -n 32 > mem3.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c3-4 | head -n 32 > mem2.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c5-6 | head -n 32 > mem1.hex
od -t x4 -A none --width=4 prog.bin -v | colrm 1 1 | cut -c7-8 | head -n 32 > mem0.hex
echo "wrote mem0-3.hex"
