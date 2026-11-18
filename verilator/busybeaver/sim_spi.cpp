// Verilator driver: watches the SPI pins of the design (max_clk, max_din, max_ce_),
// assembles 16-bit MAX7219 frames, and hands them to a sender thread.
//   Pi build:     frames go out via /dev/spidev0.0 (hardware SPI0: MOSI=GPIO10, SCLK=GPIO11, CE0=GPIO8)
//   -DNO_PI build: frames are decoded and printed (for debugging on any machine)
// Usage: ./obj_dir/Vtop [max_cycles]     (0 or omitted = run until Ctrl-C)
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
#include <fcntl.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

struct Ring {  // single-producer single-consumer, lock-free
  static const size_t N = 4096;
  std::atomic<size_t> head{0}, tail{0};
  uint16_t buf[N];
  bool push(uint16_t v) {
    size_t h = head.load(std::memory_order_relaxed), n = (h + 1) % N;
    if (n == tail.load(std::memory_order_acquire)) return false;
    buf[h] = v; head.store(n, std::memory_order_release); return true;
  }
  bool pop(uint16_t& v) {
    size_t t = tail.load(std::memory_order_relaxed);
    if (t == head.load(std::memory_order_acquire)) return false;
    v = buf[t]; tail.store((t + 1) % N, std::memory_order_release); return true;
  }
};

static Ring ring;
static std::atomic<bool> stop_flag{false};
static void on_sigint(int) { stop_flag = true; }

#ifdef NO_PI
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
  if (decode_mode & (1 << (d - 1))) {
    static const char* t = "0123456789-EHLP ";
    return t[v & 0xF];
  }
  return raw_char(v);
}
static bool open_sink() { return true; }
static void emit(uint16_t w) {
  uint8_t addr = w >> 8, data = w & 0xFF;
  printf("frame %04x  reg=0x%02x data=0x%02x", w, addr, data);
  if (addr >= 1 && addr <= 8) {
    digits[addr] = data;
    printf("  digits(8..1): ");
    for (int d = 8; d >= 1; d--) { putchar(seg_char(d)); if (digits[d] & 0x80) putchar('.'); }
  } else if (addr == 0x09) { decode_mode = data; printf("  decode mode"); }
  else if (addr == 0x0A) printf("  intensity");
  else if (addr == 0x0B) printf("  scan limit");
  else if (addr == 0x0C) printf("  %s", data & 1 ? "normal" : "shutdown");
  else if (addr == 0x0F) printf("  display test %s", data & 1 ? "on" : "off");
  putchar('\n');
}
#else
static int spi_fd = -1;
static bool open_sink() {
  spi_fd = open("/dev/spidev0.0", O_RDWR);
  if (spi_fd < 0) { perror("open /dev/spidev0.0 (enable SPI: dtparam=spi=on)"); return false; }
  uint8_t mode = SPI_MODE_0, bits = 8; uint32_t speed = 1000000;
  ioctl(spi_fd, SPI_IOC_WR_MODE, &mode);
  ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
  ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
  return true;
}
static void emit(uint16_t w) {
  uint8_t tx[2] = {uint8_t(w >> 8), uint8_t(w & 0xFF)};  // MSB first: register, then data
  spi_ioc_transfer tr = {};
  tr.tx_buf = (unsigned long)tx; tr.len = 2; tr.bits_per_word = 8; tr.speed_hz = 1000000;
  if (ioctl(spi_fd, SPI_IOC_MESSAGE(1), &tr) < 0) perror("spi transfer");
}
#endif

static void sender() {
  uint16_t w;
  for (;;) {
    if (ring.pop(w)) emit(w);
    else if (stop_flag) break;
    else std::this_thread::sleep_for(std::chrono::microseconds(200));
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  uint64_t max_cycles = argc > 1 ? strtoull(argv[1], nullptr, 0) : 0;
  signal(SIGINT, on_sigint);
  if (!open_sink()) return 1;

  Vtop top;
  top.clk = 0; top.rst_n = 1; top.eval();
  uint8_t pclk = top.max_clk, pce = top.max_ce_;
  uint16_t sh = 0; unsigned nbits = 0;
  uint64_t cycles = 0, dropped = 0, badlen = 0;
  std::thread th(sender);

  while (!stop_flag && !(max_cycles && cycles >= max_cycles)) {
    top.clk = !top.clk;
    top.eval();
    uint8_t c = top.max_clk, ce = top.max_ce_;
    if (!ce && pce) nbits = 0;                                   // CS falling: new frame
    if (!ce && c && !pclk) { sh = (sh << 1) | (top.max_din & 1); nbits++; }  // mode 0: sample on rising sck
    if (ce && !pce) {                                            // CS rising = MAX7219 LOAD
      if (nbits == 16) { if (!ring.push(sh)) dropped++; }
      else if (nbits) badlen++;
      nbits = 0;
    }
    pclk = c; pce = ce;
    cycles += top.clk;
  }
  stop_flag = true;
  th.join();
  fprintf(stderr, "cycles=%llu dropped=%llu bad_length_frames=%llu\n",
          (unsigned long long)cycles, (unsigned long long)dropped, (unsigned long long)badlen);
  return 0;
}
