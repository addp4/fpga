CXX = g++ -fno-tree-slp-vectorize
ARMCC = /usr/local/google/home/nomurak/bin/aarch64-unknown-linux-gnu-g++ -fno-tree-slp-vectorize
# ARMCC = /usr/local/google/home/nomurak/bin/aarch64-ctng-clang++
# VERILATOR = /opt/verilator-4.038/bin/verilator
VERILATOR = /usr/bin/verilator --no-std-package
# VERILATOR = /usr/bin/verilator

default:	cpu

VFD_V := cpu.sv

cpu:
	$(VERILATOR) --cc --exe -j 6 -O3 --x-assign fast --x-initial fast --noassert $(VFD_V) cpu.cpp -CFLAGS -DNO_PI
	make -C obj_dir -f Vcpu.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native" CXX="$(CXX)" LINK="$(CXX)" LDFLAGS="-static"
	time ./obj_dir/Vcpu 0 10000000

run:
	mscp ./obj_dir/Vcpu root@$(HOST):/data/Vcpu
	mssh $(HOST) gcontain run / -- /data/Vcpu 0 10000000

clean:
	rm -rf obj_dir
