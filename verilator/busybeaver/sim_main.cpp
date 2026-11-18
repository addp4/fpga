// Verilator testbench bridging top.v ports to real Pi 5 GPIO via lgpio.
#include <verilated.h>
#include <lgpio.h>
#include <chrono>
#include <thread>
#include <cstdio>
#include <cstdlib>
#include "Vtop.h"

static const int PIN_LED_BLINK = 27;  // BCM numbers

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  int chip = 0;  // for rpi5
  int h = lgGpiochipOpen(chip);
  if (h < 0) { fprintf(stderr, "lgGpiochipOpen(%d) failed: %d\n", chip, h); return 1; }
  lgGpioClaimOutput(h, 0, PIN_LED_BLINK, 0);

  int led_blink = -1;
  uint64_t clk_cnt = 0;
  uint64_t clk_cnt0 = 0;
  Vtop top;
  top.clk = 0;
  top.rst_n = 1;
  auto t0 = std::chrono::steady_clock::now();
  // in loop, after each full cycle (two evals): if ((++n & ((1ull<<28)-1)) == 0) { print n / elapsed seconds }
  for (;;) {
    top.clk = !top.clk;
    clk_cnt += top.clk;		// increments on posedge
    top.eval();
    if (led_blink != top.led_blink) {
      lgGpioWrite(h, PIN_LED_BLINK, top.led_blink);
      if (led_blink != -1) {	// print stats
	auto t1 = std::chrono::steady_clock::now();
	std::chrono::duration<double> elapsed_seconds = t1 - t0;
	printf("%f cycles per second\n", (clk_cnt - clk_cnt0) / elapsed_seconds.count());
	t0 = t1;
	clk_cnt0 = clk_cnt;
      }
      led_blink = top.led_blink;
    }
  }
}
