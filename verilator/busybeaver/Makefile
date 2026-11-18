
ABSL_CFLAGS := $(shell pkg-config --cflags absl_str_format)
ABSL_LDFLAGS := $(shell pkg-config --libs absl_str_format)

default:	sim_fake

sim_main:
	verilator --cc --exe --build -j 0 -O3 --x-assign fast --x-initial fast --noassert \
	  top.v sim_main.cpp \
	  -MAKEFLAGS "OPT_FAST='-O3 -march=native' OPT_GLOBAL='-O3 -march=native'" \
	  -CFLAGS "$(ABSL_CFLAGS)" -LDFLAGS "$(ABSL_LDFLAGS)" -LDFLAGS -llgpio
	echo "run: ./obj_dir/Vtop <gpiochip#> <clk_hz>"
	./obj_dir/Vtop

sim_fake:
	verilator --cc --exe --build -j 0 -O3 --x-assign fast --x-initial fast --noassert \
	  top.v sim_fake.cpp \
	  -MAKEFLAGS "OPT_FAST='-O3 -march=native' OPT_GLOBAL='-O3 -march=native'" \
	  -CFLAGS "$(ABSL_CFLAGS)" -LDFLAGS "$(ABSL_LDFLAGS)"
	./obj_dir/Vtop

spi_fake:
	verilator --cc --exe -j 0 -O3 --x-assign fast --x-initial fast --noassert top.v sim_spi.cpp -CFLAGS -DNO_PI
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop 100000000

spi_real:
	verilator --cc --exe -j 0 -O3 --x-assign fast --x-initial fast --noassert top.v sim_spi.cpp
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop

edge_fake:
	verilator --cc --exe -j 0 -O3 --x-assign fast --x-initial fast --noassert top.v sim_edge.cpp -CFLAGS -DNO_PI
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop 0 100000000

edge_real:
	verilator --cc --exe -j 0 -O3 --x-assign fast --x-initial fast --noassert top.v sim_edge.cpp -LDFLAGS -llgpio
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop 0

# Add to your Makefile (top.v must instantiate vfd_16sd13gink and export vfd_clk, vfd_cs, vfd_sdi).
# Two steps so OPT_FAST really takes effect.
VFD_V := top.v vfd_16sd13gink.v

vfd_train:
	verilator --cc --exe -j 3 -O3 --x-assign fast --x-initial fast --noassert $(VFD_V) sim_vfd.cpp -CFLAGS -DNO_PI
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 --profile-generate" OPT_GLOBAL="-O3 --profile-generate" LDFLAGS="-fprofile-generate"
	./obj_dir/Vtop 0 30000000
	rm -f obj_dir/*.o obj_dir/Vtop obj_dir/*.a
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 --profile-use" OPT_GLOBAL="-O3 --profile-use"

vfd_fake:
	verilator --cc --exe -j 3 -O3 --x-assign fast --x-initial fast --noassert $(VFD_V) sim_vfd.cpp -CFLAGS -DNO_PI
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop 0 100000000

vfd_real:
	verilator --cc --exe -j 3 -O3 --x-assign fast --x-initial fast --noassert $(VFD_V) sim_vfd.cpp -LDFLAGS -llgpio
	make -C obj_dir -f Vtop.mk -j OPT_FAST="-O3 -march=native" OPT_GLOBAL="-O3 -march=native"
	./obj_dir/Vtop 0

clean:
	rm -rf obj_dir
