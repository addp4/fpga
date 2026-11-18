#!/bin/bash
rm -rf ~/verilator-src
git clone https://github.com/verilator/verilator ~/verilator-src
cd ~/verilator-src
git tag | grep 4.038          # confirm the exact tag name (expect v4.038)
git checkout v4.038
autoconf
./configure --prefix=$HOME/vl038
make -j40 && make install

export PATH=$HOME/vl038/bin:$PATH
# export VERILATOR_ROOT=$HOME/vl4p038/share/verilator
verilator --version           # must say 4.038, not 5.006

