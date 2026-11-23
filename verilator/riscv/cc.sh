#!/bin/bash
set -euo pipefail

rpi() {
    riscv64-unknown-elf-gcc -O2 -march=rv32i -mabi=ilp32 -nostdlib -o prog.elf prog.c start.S -T link.ld

    riscv64-unknown-elf-objcopy -O binary -S prog.elf prog.bin

    riscv64-unknown-elf-objdump -S prog.elf

    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c1-2 > mem3.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c3-4 > mem2.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c5-6 > mem1.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c7-8 > mem0.hex
    echo "wrote mem0-3.hex"
}

macos() {
    riscv64-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -o prog.elf prog.c start.S -T link.ld 

    riscv64-elf-objcopy -O binary -S prog.elf prog.bin

    riscv64-elf-objdump -S prog.elf

    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c1-2 > mem3.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c3-4 > mem2.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c5-6 > mem1.hex
    od -t x4 -A none -v prog.bin  | tr '\n' ' ' | sed 's@  *@ @g'  | tr ' ' '\n' | cut -c7-8 > mem0.hex
    echo "wrote mem0-3.hex"
}

linux() {
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
}

if [[ $(uname) =~ Darwin ]]; then
    macos
elif [[ $(uname -a) =~ rpi ]]; then
    rpi
else
    linux
fi
