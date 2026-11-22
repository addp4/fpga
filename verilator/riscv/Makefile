CXX = clang++
ARMCC = /usr/local/google/home/nomurak/bin/aarch64-unknown-linux-gnu-g++ -fno-tree-slp-vectorize
# ARMCC = /usr/local/google/home/nomurak/bin/aarch64-ctng-clang++
# VERILATOR = /opt/verilator-4.038/bin/verilator
# VERILATOR = verilator --no-std-package
VERILATOR = ~/verilator-src/bin/verilator

default:	cpu

VFD_V := cpu.sv

# Synthesis-hygiene lint: enable all warnings, but keep them non-fatal and mute the
# cosmetic classes (UNUSED/UNDRIVEN fire constantly on partially-used packed structs).
# Scan output for the structural ones that matter: MULTIDRIVEN, LATCH, UNOPTFLAT,
# BLKANDNBLK, CASEINCOMPLETE, IMPLICIT, WIDTH. Drop -Wno-fatal to make those hard-stop.
LINTFLAGS := -Wall -Wno-fatal -Wno-UNUSED -Wno-UNDRIVEN -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-VARHIDDEN

cpu:
	$(VERILATOR) $(LINTFLAGS) --cc --exe -j 6 -O3 --x-assign fast --x-initial fast --noassert $(VFD_V) cpu.cpp
	make -C obj_dir -f Vcpu.mk -j OPT_FAST="-O3 -march=native -Wno-deprecated-declarations" OPT_GLOBAL="-O3 -march=native -Wno-deprecated-declarations" CXX="$(CXX)" LINK="$(CXX)"

quick:	cpu
	time ./obj_dir/Vcpu 0 1000

full:	cpu
	time ./obj_dir/Vcpu 0 90000000

clean:
	rm -rf obj_dir
