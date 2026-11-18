// Verilator driver for vfd_16sd13gink: edge-detect the VFD pins (vfd_clk, vfd_cs, vfd_sdi) in the
// sim loop and replay each state change, in order, onto real GPIO pins from a second thread.
//   Pi build:      replay via lgpio (plain GPIO writes; SPI0 must NOT own these pins)
//   -DNO_PI build: replay stream is decoded into VFD commands/strings and printed (debug anywhere)
// Usage: ./obj_dir/Vtop <gpiochip#> [max_cycles]     (cycles 0 or omitted = run until Ctrl-C)
// On exit prints cycles/s and how often the sim had to wait for the replay thread (stalls).
#include <verilated.h>
#include "Vtop.h"
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>

#ifndef NO_PI
#include <lgpio.h>
#endif

// BCM pins, same wiring as vfd_test.c:  vfd_clk -> GPIO23 (hdr 16), vfd_sdi -> GPIO24 (18), vfd_cs -> GPIO25 (22)
static const int PIN_CLK = 23, PIN_SDI = 24, PIN_CS = 25;
// State byte layout: bit0 = vfd_clk, bit1 = vfd_sdi, bit2 = vfd_cs (active low)
static const uint8_t B_CLK = 1, B_SDI = 2, B_CS = 4;

struct Ring {  // single-producer single-consumer, lock-free; holds pin-state snapshots
  static const size_t N = 1 << 16;
  std::atomic<size_t> head{0}, tail{0};
  uint8_t buf[N];
  bool push(uint8_t v) {
    size_t h = head.load(std::memory_order_relaxed), n = (h + 1) % N;
    if (n == tail.load(std::memory_order_acquire)) return false;
    buf[h] = v; head.store(n, std::memory_order_release); return true;
  }
  bool pop(uint8_t& v) {
    size_t t = tail.load(std::memory_order_relaxed);
    if (t == head.load(std::memory_order_acquire)) return false;
    v = buf[t]; tail.store((t + 1) % N, std::memory_order_release); return true;
  }
};

static Ring ring;
static std::atomic<bool> stop_flag{false};
static void on_sigint(int) { stop_flag = true; }
static uint8_t g_prev = B_CS | B_CLK;  // replay-side view of the pins; overwritten from the first eval

#ifdef NO_PI
// ---- decoder: CS-framed bytes, LSB first, sampled on CP rising edge ----
static uint8_t cur = 0, fb[64], screen[24];
static unsigned nbits = 0, nfb = 0;
static uint64_t badframes = 0;
static char pc(uint8_t c) { return (c >= 0x20 && c < 0x7F) ? (char)c : '?'; }
static void show_screen() {
  printf("  display |");
  for (int i = 0; i < 16; i++) putchar(pc(screen[i]));
  printf("|\n");
}
static void decode_frame() {
  if (nbits) { printf("frame: partial byte (%u bits) - protocol error\n", nbits); badframes++; }
  if (!nfb) return;
  uint8_t c = fb[0];
  printf("frame:");
  for (unsigned i = 0; i < nfb; i++) printf(" %02x", fb[i]);
  if ((c & 0xE0) == 0x20) {                       // DCRAM write: 001xxxxx, auto-increment
    unsigned a = c & 0x1F;
    printf("  DCRAM write @%u, %u chars\n", a, nfb - 1);
    if (a > 0x17) { printf("  address out of range (0..23)\n"); badframes++; }
    for (unsigned i = 1; i < nfb; i++) { screen[a % 24] = fb[i]; a = (a + 1) % 24; }
    show_screen();
  } else if ((c & 0xE0) == 0x40) printf("  CGRAM (user font %u) write, %u data bytes\n", c & 7, nfb - 1);
  else if ((c & 0xE0) == 0x60) printf("  ADRAM write @%u\n", c & 0x1F);
  else if ((c & 0xE0) == 0x80) printf("  URAM write @%u (not used on this tube)\n", c & 7);
  else if ((c & 0xFC) == 0xE0) printf("  display timing: %u digits\n", nfb > 1 ? (fb[1] & 0xF) + 1 : 0);
  else if ((c & 0xFC) == 0xE4) printf("  dimming %u/255\n", nfb > 1 ? fb[1] : 0);
  else if ((c & 0xFC) == 0xE8) {
    static const char* m[] = {"normal operation", "all on (datasheet: don't use)", "all lights OFF", "all on (don't use)"};
    printf("  display light: %s\n", m[c & 3]);
  } else if ((c & 0xFC) == 0xEC) printf("  stand-by %s\n", (c & 1) ? "ON" : "off");
  else { printf("  unknown command\n"); badframes++; }
  nfb = 0;
}
static bool open_sink(int, uint8_t) { return true; }
static void apply(uint8_t n) {
  uint8_t p = g_prev; g_prev = n;
  bool cs = n & B_CS, pcs = p & B_CS;
  if (!cs && pcs) { nbits = 0; nfb = 0; cur = 0; }                       // CS falling: new frame
  if (!cs && (n & B_CLK) && !(p & B_CLK)) {                              // CP rising: sample DA, LSB first
    cur = (uint8_t)((cur >> 1) | ((n & B_SDI) ? 0x80 : 0));
    if (++nbits == 8) { if (nfb < sizeof fb) fb[nfb++] = cur; nbits = 0; cur = 0; }
  }
  if (cs && !pcs) decode_frame();                                        // CS rising: frame complete
}
static void close_sink() { if (badframes) fprintf(stderr, "bad_frames=%llu\n", (unsigned long long)badframes); }
#else
static int gh = -1;
static bool open_sink(int chip, uint8_t init) {
  gh = lgGpiochipOpen(chip);
  if (gh < 0) { fprintf(stderr, "lgGpiochipOpen(%d) failed: %d\n", chip, gh); return false; }
  g_prev = init;
  if (lgGpioClaimOutput(gh, 0, PIN_CLK, (init & B_CLK) ? 1 : 0) < 0 ||
      lgGpioClaimOutput(gh, 0, PIN_SDI, (init & B_SDI) ? 1 : 0) < 0 ||
      lgGpioClaimOutput(gh, 0, PIN_CS,  (init & B_CS)  ? 1 : 0) < 0) {
    fprintf(stderr, "could not claim GPIO %d/%d/%d (in use? SPI0 enabled?)\n", PIN_CLK, PIN_SDI, PIN_CS);
    return false;
  }
  return true;
}
static inline void wr(uint8_t bit, uint8_t n) {
  int pin = bit == B_CLK ? PIN_CLK : bit == B_SDI ? PIN_SDI : PIN_CS;
  lgGpioWrite(gh, pin, (n & bit) ? 1 : 0);
}
// Write only the pins that changed, in an order that keeps setup/hold safe:
//   CS falling: CS first.  CS rising: CS last.  CP rising: data before clock.  CP falling: clock before data.
static void apply(uint8_t n) {
  uint8_t p = g_prev; if (n == p) return;
  uint8_t ch = n ^ p; g_prev = n;
  uint8_t order[3];
  if ((ch & B_CS) && !(n & B_CS))       { order[0] = B_CS;  order[1] = B_SDI; order[2] = B_CLK; }
  else if ((ch & B_CS) && (n & B_CS))   { order[0] = B_CLK; order[1] = B_SDI; order[2] = B_CS; }
  else if ((ch & B_CLK) && (n & B_CLK)) { order[0] = B_SDI; order[1] = B_CLK; order[2] = B_CS; }
  else                                  { order[0] = B_CLK; order[1] = B_SDI; order[2] = B_CS; }
  for (int i = 0; i < 3; i++) if (ch & order[i]) wr(order[i], n);
}
static void close_sink() {}
#endif

static void replayer() {
  uint8_t s;
  for (;;) {
    if (ring.pop(s)) apply(s);
    else if (stop_flag) break;
    else std::this_thread::yield();
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  int chip = argc > 1 ? atoi(argv[1]) : 0;
  uint64_t max_cycles = argc > 2 ? strtoull(argv[2], nullptr, 0) : 0;
  signal(SIGINT, on_sigint);

  Vtop top;
  top.clk = 0; top.rst_n = 1; top.eval();
  uint8_t prev = (top.vfd_clk ? B_CLK : 0) | (top.vfd_sdi ? B_SDI : 0) | (top.vfd_cs ? B_CS : 0);
  g_prev = prev;                                   // pins start at the design's idle levels (CP high, CS high)
  if (!open_sink(chip, prev)) return 1;

  uint64_t cycles = 0, stalled = 0;
  std::thread th(replayer);
  auto t0 = std::chrono::steady_clock::now();

  while (!stop_flag && !(max_cycles && cycles >= max_cycles)) {
    top.clk = !top.clk;
    top.eval();
    uint8_t s = (top.vfd_clk ? B_CLK : 0) | (top.vfd_sdi ? B_SDI : 0) | (top.vfd_cs ? B_CS : 0);
    if (s != prev) {                       // edge detected: record the new pin state
      prev = s;
      if (!ring.push(s)) {                 // queue full: wait rather than drop edges
        stalled++;
        while (!ring.push(s) && !stop_flag) std::this_thread::yield();
      }
    }
    cycles += top.clk;
  }
  double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  stop_flag = true;
  th.join();
  close_sink();
  fprintf(stderr, "cycles=%llu  %.1f M cycles/s  stalls=%llu\n",
          (unsigned long long)cycles, cycles / secs / 1e6, (unsigned long long)stalled);
  return 0;
}
