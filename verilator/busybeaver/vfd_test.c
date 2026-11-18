// Sanity test for the Futaba 16-SD-13GINK VFD module: writes 16 fixed characters over bit-banged GPIO.
// Build:  gcc -O2 -Wall vfd_test.c -o vfd_test -llgpio
// Run:    ./vfd_test [gpiochip#] [text up to 16 chars]      (defaults: 0, "0123456789ABCDEF")
// Protocol (datasheet): CS active low frames a transfer; data shifted on CP rising edge, LSB first, CP idles high.
#include <lgpio.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PIN_CP 23   // header pin 16  (same as max_clk in sim_edge.cpp)
#define PIN_DA 24   // header pin 18  (same as max_din)
#define PIN_CS 25   // header pin 22  (same as max_ce_)

static int h;
static void w(int pin, int v) { lgGpioWrite(h, pin, v); }
static void gap(void) { lguSleep(0.00001); }  // ~10 us or more; datasheet minimums are 1-2 us

static void send_byte(uint8_t b) {
  for (int i = 0; i < 8; i++) {   // LSB first
    w(PIN_CP, 0);
    w(PIN_DA, (b >> i) & 1);
    w(PIN_CP, 1);                 // rising edge latches the bit
  }
  gap();                          // >= 2 us between bytes
}
static void frame_begin(void) { w(PIN_CS, 0); gap(); }
static void frame_end(void)   { gap(); w(PIN_CS, 1); gap(); }

int main(int argc, char** argv) {
  int chip = argc > 1 ? atoi(argv[1]) : 0;
  const char* text = argc > 2 ? argv[2] : "0123456789ABCDEF";

  h = lgGpiochipOpen(chip);
  if (h < 0) { fprintf(stderr, "lgGpiochipOpen(%d) failed: %d\n", chip, h); return 1; }
  if (lgGpioClaimOutput(h, 0, PIN_CS, 1) < 0 || lgGpioClaimOutput(h, 0, PIN_CP, 1) < 0 ||
      lgGpioClaimOutput(h, 0, PIN_DA, 0) < 0) {
    fprintf(stderr, "could not claim GPIO %d/%d/%d (in use? is SPI0 enabled?)\n", PIN_CP, PIN_DA, PIN_CS);
    return 1;
  }
  lguSleep(0.05);                                   // let the module settle (>= 2 ms after reset)

  frame_begin(); send_byte(0xE0); send_byte(0x0F); frame_end();   // 16 digits
  frame_begin(); send_byte(0xE4); send_byte(0xF0); frame_end();   // dimming 240/255 (max)

  char buf[16];
  memset(buf, ' ', sizeof buf);
  size_t n = strlen(text); if (n > 16) n = 16;
  memcpy(buf, text, n);
  frame_begin(); send_byte(0x20);                                   // DCRAM address 0, auto-increment
  for (int i = 0; i < 16; i++) send_byte((uint8_t)buf[i]);
  frame_end();

  frame_begin(); send_byte(0xE8); frame_end();                      // normal display (reset state is all-off)

  printf("sent: \"%.16s\"\n", buf);
  lgGpiochipClose(h);                                               // pins float afterwards; display keeps its RAM
  return 0;
}

