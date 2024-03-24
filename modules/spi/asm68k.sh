#!/bin/bash
file=$1
set -euo pipefail

m68k-linux-gnu-as -m68000 -o a.o $file
m68k-linux-gnu-ld -Ttext=0  -o a.out a.o
m68k-linux-gnu-objdump -d -z -h a.out
m68k-linux-gnu-objcopy --dump-section .text=/tmp/foo  a.out
od -A none -v -t x1 /tmp/foo | tee mc68000_ram.data

