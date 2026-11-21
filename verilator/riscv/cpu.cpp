// Verilator driver for vfd_16sd13gink: edge-detect the VFD pins (vfd_clk, vfd_cs, vfd_sdi) in the
// sim loop and replay each state change, in order, onto real GPIO pins from a second thread.
//   Pi build:      replay via lgpio (plain GPIO writes; SPI0 must NOT own these pins)
//   -DNO_PI build: replay stream is decoded into VFD commands/strings and printed (debug anywhere)
// Usage: ./obj_dir/Vtop <gpiochip#> [max_cycles]     (cycles 0 or omitted = run until Ctrl-C)
// On exit prints cycles/s and how often the sim had to wait for the replay thread (stalls).
#include <verilated.h>
#include "Vcpu.h"
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  int chip = argc > 1 ? atoi(argv[1]) : 0;
  uint64_t max_cycles = argc > 2 ? strtoull(argv[2], nullptr, 0) : 0;
  Vcpu top;
  for (int i = 0; i < max_cycles * 2; i++) {
    top.clk = !top.clk;
    top.eval();
  }
  printf("r10 = %d\n", top.r10);
  printf("cycle_cnt = %d\n", top.cycle_cnt);
  printf("inst_retired = %d\n", top.inst_retired);
  printf("IPC = %.2f\n", 1.0 * top.inst_retired / top.cycle_cnt);

#if 0
  top.clk = 0; top.rst_n = 1; top.eval();
  uint8_t prev = (top.vfd_clk ? B_CLK : 0) | (top.vfd_sdi ? B_SDI : 0) | (top.vfd_cs ? B_CS : 0);
  g_prev = prev; // pins start at the design's idle levels (CP high, CS high)
  if (!open_sink(chip, prev)) return 1;

  uint64_t cycles = 0, stalled = 0;
  auto t0 = std::chrono::steady_clock::now();

  while (!stop_flag && !(max_cycles && cycles >= max_cycles)) {
    top.clk = !top.clk;
    top.eval();
    cycles += top.clk;
  }
  double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  stop_flag = true;
  close_sink();
  fprintf(stderr, "cycles=%llu  %.1f M cycles/s  stalls=%llu\n",
          (unsigned long long)cycles, cycles / secs / 1e6, (unsigned long long)stalled);
#endif
  return 0;
}
