// Verilator driver: edge-detect the MAX7219 pins (max_clk, max_din, max_ce_) in the sim loop and
// replay each state change, in order, onto real GPIO pins from a second thread.
//   Pi build:      replay via lgpio (plain GPIO writes; SPI controller must NOT own these pins)
//   -DNO_PI build: replay stream is decoded into MAX7219 frames and printed (debug on any machine)
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

// BCM pin numbers for the three outputs (plain GPIO; keep SPI0 disabled or choose pins it doesn't use)
static const int PIN_CLK = 23, PIN_DIN = 24, PIN_CE = 25;   // header pins 16, 18, 22
// State byte layout: bit0 = max_clk, bit1 = max_din, bit2 = max_ce_
static const uint8_t B_CLK = 1, B_DIN = 2, B_CE = 4;

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
static uint8_t g_prev = B_CE;  // replay-side view of the pins (idle: ce_ high, others low)

#ifdef NO_PI
static uint16_t sh = 0; static unsigned nbits = 0; static uint64_t badlen = 0;
static uint8_t decode_mode = 0, digits[9] = {0};
static char raw_char(uint8_t v) {  // v = segment bits without DP: bit6=A .. bit0=G
  switch (v & 0x7F) {
    case 0x7E: return '0'; case 0x30: return '1'; case 0x6D: return '2'; case 0x79: return '3';
    case 0x33: return '4'; case 0x5B: return '5'; case 0x5F: return '6'; case 0x70: return '7';
    case 0x7F: return '8'; case 0x7B: return '9'; case 0x77: return 'A'; case 0x1F: return 'b';
    case 0x4E: return 'C'; case 0x3D: return 'd'; case 0x4F: return 'E'; case 0x47: return 'F';
    case 0x37: return 'H'; case 0x0E: return 'L'; case 0x67: return 'P'; case 0x3E: return 'U';
    case 0x1D: return 'o'; case 0x05: return 'r'; case 0x15: return 'n'; case 0x1C: return 'u';
    case 0x0D: return 'c'; case 0x17: return 'h'; case 0x3B: return 'y'; case 0x5E: return 'G';
    case 0x38: return 'J'; case 0x01: return '-'; case 0x00: return ' ';
    default: return '?';
  }
}
static char seg_char(int d) {
  uint8_t v = digits[d];
  if (decode_mode & (1 << (d - 1))) { static const char* t = "0123456789-EHLP "; return t[v & 0xF]; }
  return raw_char(v);
}
static void emit(uint16_t w) {
  uint8_t addr = w >> 8, data = w & 0xFF;
  printf("frame %04x  reg=0x%02x data=0x%02x", w, addr, data);
  if (addr >= 1 && addr <= 8) {
    digits[addr] = data; printf("  digits(8..1): ");
    for (int d = 8; d >= 1; d--) { putchar(seg_char(d)); if (digits[d] & 0x80) putchar('.'); }
  } else if (addr == 0x09) { decode_mode = data; printf("  decode mode"); }
  else if (addr == 0x0A) printf("  intensity");
  else if (addr == 0x0B) printf("  scan limit");
  else if (addr == 0x0C) printf("  %s", data & 1 ? "normal" : "shutdown");
  else if (addr == 0x0F) printf("  display test %s", data & 1 ? "on" : "off");
  putchar('\n');
}

static bool open_sink(int) { return true; }

static void apply(uint8_t n) {
  uint8_t p = g_prev; g_prev = n;
  bool ce = n & B_CE, pce = p & B_CE;
  if (!ce && pce) nbits = 0;
  if (!ce && (n & B_CLK) && !(p & B_CLK)) {
    sh = (sh << 1) | ((n & B_DIN) ? 1 : 0);
    nbits++;
  }
  if (ce && !pce) {
    if (nbits == 16) emit(sh);
    else if (nbits) badlen++; nbits = 0;
  }
}

static void close_sink() { if (badlen) fprintf(stderr, "bad_length_frames=%llu\n", (unsigned long long)badlen); }

#else

static int gh = -1;

static bool open_sink(int chip) {
  gh = lgGpiochipOpen(chip);
  if (gh < 0) { fprintf(stderr, "lgGpiochipOpen(%d) failed: %d\n", chip, gh); return false; }
  if (lgGpioClaimOutput(gh, 0, PIN_CLK, 0) < 0 || lgGpioClaimOutput(gh, 0, PIN_DIN, 0) < 0 ||
      lgGpioClaimOutput(gh, 0, PIN_CE, 1) < 0) {
    fprintf(stderr, "could not claim GPIO %d/%d/%d (in use? SPI0 enabled?)\n", PIN_CLK, PIN_DIN, PIN_CE);
    return false;
  }
  return true;
}

static inline void wr(uint8_t bit, uint8_t n) {
  int pin = bit == B_CLK ? PIN_CLK : bit == B_DIN ? PIN_DIN : PIN_CE;
  lgGpioWrite(gh, pin, (n & bit) ? 1 : 0);
}

// Write only the pins that changed, in an order that keeps SPI setup/hold safe:
//   CS falling: CS first (before data/clock).  CS rising: CS last (after data/clock).
//   SCK rising: data before clock.             SCK falling: clock before data.
static void apply(uint8_t n) {
  uint8_t p = g_prev; if (n == p) return;
  uint8_t ch = n ^ p; g_prev = n;
  uint8_t order[3];
  if ((ch & B_CE) && !(n & B_CE))      { order[0] = B_CE;  order[1] = B_DIN; order[2] = B_CLK; }
  else if ((ch & B_CE) && (n & B_CE))  { order[0] = B_CLK; order[1] = B_DIN; order[2] = B_CE; }
  else if ((ch & B_CLK) && (n & B_CLK)){ order[0] = B_DIN; order[1] = B_CLK; order[2] = B_CE; }
  else                                 { order[0] = B_CLK; order[1] = B_DIN; order[2] = B_CE; }
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
  if (!open_sink(chip)) return 1;

  Vtop top;
  top.clk = 0; top.rst_n = 0; top.eval();
  // uint8_t prev = (top.max_clk ? B_CLK : 0) | (top.max_din ? B_DIN : 0) | (top.max_ce_ ? B_CE : 0);
  // rewrite for clk active low
  uint8_t prev = (top.max_clk ? B_CLK : 0) | (top.max_din ? B_DIN : 0) | (top.max_ce_ ? B_CE : 0);
  uint64_t cycles = 0, stalled = 0;
  std::thread th(replayer);
  auto t0 = std::chrono::steady_clock::now();
  bool done_printed = false;

  while (!stop_flag && !(max_cycles && cycles >= max_cycles)) {
    top.clk = !top.clk;
    top.eval();
    uint8_t s = (top.max_clk ? B_CLK : 0) | (top.max_din ? B_DIN : 0) | (top.max_ce_ ? B_CE : 0);
    if (s != prev) {                       // edge detected: record the new pin state
      prev = s;
      if (!ring.push(s)) {                 // queue full: wait rather than drop edges
        stalled++;
        while (!ring.push(s) && !stop_flag) std::this_thread::yield();
      }
    }
    cycles += top.clk;
    top.rst_n = 1;
    if (!done_printed && top.done) {
      printf("done at cycle %d\n", cycles);
      done_printed = true;
    }
    printf("ce=%d clk=%d din=%d\n", top.max_ce_, top.max_clk, top.max_din);
  }
  double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  stop_flag = true;
  th.join();
  close_sink();
  fprintf(stderr, "cycles=%llu  %.1f M cycles/s  stalls=%llu\n",
          (unsigned long long)cycles, cycles / secs / 1e6, (unsigned long long)stalled);
  return 0;
}
