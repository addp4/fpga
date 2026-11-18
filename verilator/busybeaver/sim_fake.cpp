// Verilator testbench bridging top.v ports to real Pi 5 GPIO via lgpio.
#include <verilated.h>
#include <lgpio.h>
#include <chrono>
#include <thread>
#include <cstdio>
#include <cstdlib>
#include "absl/strings/str_format.h"
#include "Vtop.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vtop top;
  int led_blink = -1;
  top.clk = 0;
  top.rst_n = 1;
  int prev_max_clk = 0;
  int prev_max_ce_ = 0;
  int max_byte = 0;
  for (;;) {
    top.clk = !top.clk;
    top.eval();
    if (led_blink != top.led_blink) {
      absl::PrintF("hi\n");
      led_blink = top.led_blink;
    }

    int max_clk_edge = top.max_clk == 1 & !prev_max_clk;
    int max_ce_edge = top.max_ce_ == 1 & !prev_max_ce_;
    prev_max_clk = top.max_clk;
    prev_max_ce_ = top.max_ce_;
    if (max_clk_edge && !top.max_ce_) {
      max_byte = (max_byte << 1) | top.max_din;
    }
    if (max_ce_edge) {
      printf("max_out=%04x\n", max_byte);
      max_byte = 0;
    }
  }
}
