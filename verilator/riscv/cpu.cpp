// Verilator driver for the RISC-V core, with the vfd_16sd13gink display sent over hardware SPI.
//
// The sim loop watches the VFD pins (vfd_clk, vfd_cs, vfd_sdi) and turns them back into bytes:
// sample DA on each rising CP edge while CS is low, LSB first, and close the frame when CS goes
// high. Each finished frame (one VFD command plus its data) goes into a queue. A sender thread
// sleeps until a frame arrives, then hands it to /dev/spidev<bus>.0 in one ioctl. The SPI
// controller clocks the bits out itself, so no host core has to spin toggling GPIOs.
//
// Wiring (SPI0, already enabled by dtparam=spi=on):
//   VFD CP  <- GPIO11 SPI0_SCLK (header pin 23)
//   VFD DA  <- GPIO10 SPI0_MOSI (header pin 19)
//   VFD CS  <- GPIO8  SPI0_CE0  (header pin 24)
// Bus format: CP idles high and the VFD samples on the rising edge -> SPI mode 3. The VFD wants
// LSB first; the RP1 controller only does MSB first, so each byte is bit-reversed before sending.
//
// Usage: ./obj_dir/Vcpu [spi_bus] [max_cycles]
//   spi_bus:    N opens /dev/spidevN.0 (default 0); -1 = no SPI, print the decoded display instead.
//   max_cycles: 0 or omitted = run until Ctrl-C.
// If the SPI device can't be opened, the program warns and prints the display instead.
#include <verilated.h>
#include "Vcpu.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <mutex>
#include <thread>
#include <vector>

#ifdef __linux__
#include <fcntl.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <unistd.h>
#define HAVE_SPIDEV 1
#endif

static const uint32_t SPI_HZ = 250000;    // VFD datasheet max CP is 500 kHz
static const uint16_t BYTE_GAP_US = 8;    // CS held low between bytes, like the Verilog's byte gap
static const size_t MAX_QUEUED = 256;     // frames; beyond this the newest are dropped (and counted)

static std::atomic<bool> stop_flag{false};
static void on_sigint(int) { stop_flag = true; }

// ---- frame queue: sim thread produces (rarely: a few frames per display update), sender consumes ----
static std::mutex q_mu;
static std::condition_variable q_cv;
static std::deque<std::vector<uint8_t>> q;
static bool q_done = false;
static uint64_t dropped = 0;

static void enqueue(const uint8_t* b, size_t n) {
  {
    std::lock_guard<std::mutex> lk(q_mu);
    if (q.size() >= MAX_QUEUED) { dropped++; return; }
    q.emplace_back(b, b + n);
  }
  q_cv.notify_one();
}

// ---- sinks ----
static int spi_fd = -1;

static bool open_spi(int bus) {
#ifdef HAVE_SPIDEV
  char path[32];
  snprintf(path, sizeof path, "/dev/spidev%d.0", bus);
  spi_fd = open(path, O_RDWR);
  if (spi_fd < 0) { fprintf(stderr, "open %s: %s (enable SPI: dtparam=spi=on)\n", path, strerror(errno)); return false; }
  uint8_t mode = SPI_MODE_3, bits = 8;
  uint32_t speed = SPI_HZ;
  if (ioctl(spi_fd, SPI_IOC_WR_MODE, &mode) < 0 || ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits) < 0 ||
      ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed) < 0) {
    perror("spidev setup");
    close(spi_fd); spi_fd = -1; return false;
  }
  return true;
#else
  (void)bus;
  fprintf(stderr, "no spidev on this platform\n");
  return false;
#endif
}

static inline uint8_t rev8(uint8_t b) {
  b = (b & 0xF0) >> 4 | (b & 0x0F) << 4;
  b = (b & 0xCC) >> 2 | (b & 0x33) << 2;
  return (b & 0xAA) >> 1 | (b & 0x55) << 1;
}

// One frame = one CS-low period: one transfer per byte, CS kept asserted, BYTE_GAP_US between bytes.
static void send_spi(const std::vector<uint8_t>& f) {
#ifdef HAVE_SPIDEV
  uint8_t tx[32];
  spi_ioc_transfer tr[32];
  size_t n = f.size() < 32 ? f.size() : 32;
  memset(tr, 0, sizeof tr);
  for (size_t i = 0; i < n; i++) {
    tx[i] = rev8(f[i]);
    tr[i].tx_buf = (unsigned long)&tx[i];
    tr[i].len = 1;
    tr[i].speed_hz = SPI_HZ;
    tr[i].bits_per_word = 8;
    tr[i].delay_usecs = (i + 1 < n) ? BYTE_GAP_US : 0;
  }
  if (ioctl(spi_fd, SPI_IOC_MESSAGE(n), tr) < 0) perror("spi transfer");
#else
  (void)f;
#endif
}

// Fallback: decode the frame and print the display when a DCRAM write lands.
static uint8_t screen[16];
static void print_frame(const std::vector<uint8_t>& f) {
  if (f.empty() || (f[0] & 0xE0) != 0x20) return;   // only DCRAM writes change the text
  unsigned a = f[0] & 0x1F;
  for (size_t i = 1; i < f.size(); i++, a++) if (a < 16) screen[a] = f[i];
  printf("display |");
  for (int i = 0; i < 16; i++) putchar(screen[i] >= 0x20 && screen[i] < 0x7F ? screen[i] : '?');
  printf("|\n");
  fflush(stdout);
}

static void sender() {
  for (;;) {
    std::vector<uint8_t> f;
    {
      std::unique_lock<std::mutex> lk(q_mu);
      q_cv.wait(lk, [] { return !q.empty() || q_done; });   // sleeps; no spinning
      if (q.empty()) return;                                 // q_done and drained
      f = std::move(q.front());
      q.pop_front();
    }
    if (spi_fd >= 0) send_spi(f); else print_frame(f);
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  int bus = argc > 1 ? atoi(argv[1]) : 0;
  uint64_t max_cycles = argc > 2 ? strtoull(argv[2], nullptr, 0) : 0;
  if (!max_cycles) max_cycles = ~0ULL;
  signal(SIGINT, on_sigint);
  memset(screen, ' ', sizeof screen);

  if (bus >= 0 && !open_spi(bus)) fprintf(stderr, "SPI unavailable; printing the display instead\n");
  std::thread th(sender);

  Vcpu top;
  top.clk = 0;
  top.eval();

  // VFD byte decoder state
  uint8_t pclk = top.vfd_clk, pcs = top.vfd_cs;
  uint8_t cur = 0, frame[32];
  unsigned nbits = 0, nframe = 0;
  uint64_t bad_frames = 0;

  auto t0 = std::chrono::steady_clock::now();
  uint64_t cycles = 0;
  while (!stop_flag && cycles < max_cycles) {
    top.clk = !top.clk;
    top.eval();
    cycles += top.clk;

    uint8_t c = top.vfd_clk, cs = top.vfd_cs;
    if (__builtin_expect(c == pclk && cs == pcs, 0))
      continue;  // pins change rarely; fast path
    if (!cs && pcs) { nbits = 0; nframe = 0; cur = 0; }	// CS falling: new frame
    if (!cs && c && !pclk) {	// CP rising: sample DA
      cur = (uint8_t)((cur >> 1) | (top.vfd_sdi ? 0x80 : 0));
      if (++nbits == 8) { if (nframe < sizeof frame) frame[nframe++] = cur; nbits = 0; cur = 0; }
    }
    if (cs && !pcs) {		// CS rising: frame done
      if (nbits) bad_frames++;
      else if (nframe) enqueue(frame, nframe);
    }
    pclk = c; pcs = cs;
  }

  double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();

  { std::lock_guard<std::mutex> lk(q_mu); q_done = true; }
  q_cv.notify_one();
  th.join();

  printf("r10 = %d\n", top.r10);
  printf("cycles = %llu\n", top.pmu_cycles);
  printf("inst_retired = %d\n", top.pmu_inst_retired);
  printf("IPC = %.2f\n", 1.0 * top.pmu_inst_retired / top.pmu_cycles);
  printf("br_retired = %d\n", top.pmu_br_retired);
  printf("br_taken = %d\n", top.pmu_br_taken);
  printf("br_indirect_retired = %d\n", top.pmu_br_indirect_retired);
  printf("load_retired = %d\n", top.pmu_load_retired);
  printf("store_retired = %d\n", top.pmu_store_retired);
  printf("alu_retired = %d\n", top.pmu_alu_retired);
  printf("reg_forwards = %d\n", top.pmu_reg_forwards);
  printf("user = %llu\n", top.pmu_user);
  printf("wall time = %.2f\n", elapsed);
  printf("cycles/sec = %.0f\n", cycles / elapsed);
  if (dropped || bad_frames)
    printf("vfd: dropped_frames = %llu  bad_frames = %llu\n", dropped, bad_frames);
  if (spi_fd >= 0) close(spi_fd);
  return 0;
}
