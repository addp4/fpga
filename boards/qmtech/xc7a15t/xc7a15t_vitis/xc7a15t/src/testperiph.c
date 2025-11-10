#include <stdio.h>
#include <inttypes.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xgpio.h"
#include "gpio_header.h"

#define DEVICE_MICROCHIP_23LC1024 1
#define DEVICE_ISSI_ISS66WVS4M8BLL 2
#define DEVICE_APS6404L 3

#define DEVICE DEVICE_MICROCHIP_23LC1024

static int spi_pass;
static int psram_errors;
static int word;
static int pattern;
static uint32_t rd_empty;

void flash_led() {
  static int led = 0;
  led += 1;
  *(int *)XPAR_AXI_GPIO_0_BASEADDR = ~led;
}

#define BLACK   "\033[1;30m"
#define RED     "\033[1;31m"
#define GREEN   "\033[1;32m"
#define YELLOW  "\033[1;33m"
#define BLUE    "\033[1;34m"
#define MAGENTA "\033[1;35m"
#define CYAN    "\033[1;36m"
#define WHITE   "\033[1;37m"

void vt100_at(int row, int col) {
  // xil_printf("\033[%d;%dH", row, col);
}

void vt100_cls() {
  // xil_printf("\033[2J");
}

/*=====================
  PERFMON
 ====================*/

void perfmon_init() {
	int *pmon_cr = (int *)(XPAR_AXIPMON_0_BASEADDR + 0x300);
	*pmon_cr |= 1;
    xil_printf("pmon: cr=0x%x\n", *pmon_cr);
}

uint32_t cycles() {
  int *pmon_sr = (int *)(XPAR_AXIPMON_0_BASEADDR + 0x2c);
  return *pmon_sr;
}

#define PMON_METRIC(n) *(int *)(XPAR_AXIPMON_0_BASEADDR + 0x200 + 0x10*(n))
// void perfmon_print() __attribute__ ((section(".data")));
void perfmon_print() {
	int *pmon_sr = (int *)(XPAR_AXIPMON_0_BASEADDR + 0x2c);
    xil_printf("pmon: sr=0x%x ", *pmon_sr);
    xil_printf("slot0(wb=%d wtx=%d wcy=%d ",
	       PMON_METRIC(0), PMON_METRIC(1), PMON_METRIC(2));
    xil_printf("rby=%d rtx=%d rcy=%d ",
	       PMON_METRIC(3), PMON_METRIC(4), PMON_METRIC(5));
    xil_printf("wlat=%d rlat=%d) ",
	       PMON_METRIC(2) / PMON_METRIC(1),
	       PMON_METRIC(5) / PMON_METRIC(4)
	       );
    xil_printf("slot1(wb=%d wtx=%d wcy=%d ",
	       PMON_METRIC(6), PMON_METRIC(7), PMON_METRIC(8));
    xil_printf("rby=%d rtx=%d rcy=%d ",
	       PMON_METRIC(9), PMON_METRIC(10), PMON_METRIC(11));
    xil_printf("wlat=%d rlat=%d) ",
	       PMON_METRIC(8) / PMON_METRIC(7),
	       PMON_METRIC(11) / PMON_METRIC(10)
	       );
    xil_printf("\r");
}

/*=====================
  SPI
 ====================*/

#define DGIER       0x1c
#define IPISR       0x20
#define IPIER       0x28
#define SRR         0x40
#define SPICR       0x60
#define SPISR       0x64
#define SPIDTR      0x68
#define SPIDRR      0x6C
#define SPISSR      0x70
#define Tx_FIFO_OCY 0x74
#define Rx_FIFO_OCY 0x78

volatile uint32_t *srr =    (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SRR);
volatile uint32_t *ipisr =  (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + IPISR);
volatile uint32_t *ipier =  (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + IPIER);
volatile uint32_t *spicr =  (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SPICR);
volatile uint32_t *spisr =  (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SPISR);
volatile uint32_t *spidtr = (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SPIDTR);
volatile uint32_t *spidrr = (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SPIDRR);
volatile uint32_t *spissr = (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + SPISSR);
volatile uint32_t *txfifo = (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + Tx_FIFO_OCY);
volatile uint32_t *rxfifo = (uint32_t *)(XPAR_AXI_QUAD_SPI_0_BASEADDR + Rx_FIFO_OCY);

void spi_clear_fifos() {
  *spicr = *spicr | (1 << 6) | (1 << 5);
  asm volatile("nop");
}

void spi_init() {
  spi_pass = 0;  // statics dont get initialized properly

  // reset core and wait 4 axi cycles
  *srr = 0xa;
  for (int i = i; i < 100; i++)
    asm volatile("nop");

  // the following sets all the bits in SPICR to known values and
  // also (1) aborts existing transactions by toggling bit 8 (master mode)
  // and (2) clears fifos (by setting bits 5 and 6)
  // spicr[9]=0 MSB first
  // spicr[8]=1 inhibit master mode (to abort pending shift reg, cleared in next steps)

  // spicr[7]=1 slave select honors SPISSR
  // spicr[6]=0 Rx FIFO reset
  // spicr[5]=0 Tx FIFO reset
  // spicr[4]=0 CPHA=0

  // spicr[3]=0 CPOL=0
  // spicr[2]=1 core is master
  // spicr[1]=1 enable SPI system
  // spicr[0]=0 loopback mode off
  *spicr = 0x186;
  asm volatile("nop");
  spi_clear_fifos();
  // spicr[8]=0 enable master mode
  *spicr = 0x086;
  asm volatile("nop");

}

void spi_begin() {
  *spissr = 0;  // CSn low - enable slave
}

void spi_end() {
  asm volatile("nop");
  *spissr = 1;  // CSn high - disable slave
  asm volatile("nop");
}

/*
  expected:
  read word: wtxn = 9 + 2, rtxn = 18  (+2 for CSn writes to *spissr)
  write word: wtxn = 8 + 2, rtxn = 16
  total: wtxn = 17 + 4, rtxn = 34 = 55 (matches observed)

  observed:
  for 132072 reads and writes
     pmon: slot1(wb=11010072 wtx=2752518 wcy=13762590 rby=17825868 rtx=4456467 rcy=64553213 wlat=5 rlat=14)
  wtx / writes = 2752518 / 132072 = 21
  rtx / reads  = 4456467 / 132072 = 34

  end to end:
  tx_cycles=720 rx_cycles=860 per 32-bit word
  at face value, not considering C overhead
  860 cycles/rxword => 215 cycles/byte => 6 cycles per axi txn[
  720 cycles/txword => 180 cycles/txbyte => 8.5 cycles per axi txn

  derive C overhead from known txn counts
  from 21 txn per write, tx cycles = 720 = 21 * (axi_cost + c_cost)
  from 34 txn per read, rx cycles = 860 = 34 * (axi_cost + c_cost)

*/
uint32_t spi_read_byte() {
  while (*spisr & 1)  // spin while rx is empty
    rd_empty += 1;
  return (*spidrr) & 0xff;  // read from receive fifo
}

uint32_t spi_write_byte(uint32_t byte) {
  while (*spisr & 8)  // spin while tx is full
    ;
  *spidtr = byte & 0xff;
  return spi_read_byte();  // read from receive fifo

}

void dump_spi_core_regs() {
  vt100_at(2, 1);
  uint32_t x = *spicr;
  xil_printf("SPICR=0x%x (lsb=%d,inhibit=%d,mssae=%d,rxreset=%d,txreset=%d,CPHA=%d,CPOL=%d,master=%d,SPE=%d,LOOP=%d)\r",
	     x, (x >> 9) & 1, (x >> 8) & 1, (x >> 7) & 1, (x >> 6) & 1,  (x >> 5) & 1,
	     (x >> 4) & 1,  (x >> 3) & 1,  (x >> 2) & 1,  (x >> 1) & 1, x & 1);
  vt100_at(3, 1);
  x = *spisr;
  xil_printf("SPISR=0x%x (cmderr=%d,looperr=%d,msberr=%d,slverr=%d,cpolcphaerr=%d,slvsel=%d,modf=%d,txfull=%d,txempty=%d,rxfull=%d,rxempty=%d)\r",
	     x, (x >> 10) & 1, (x >> 9) & 1, (x >> 8) & 1, (x >> 7) & 1, (x >> 6) & 1,  (x >> 5) & 1,
	     (x >> 4) & 1,  (x >> 3) & 1,  (x >> 2) & 1,  (x >> 1) & 1, x & 1);
  vt100_at(4, 1);
  xil_printf("SPISSR=0x%x TXFIFO=%d RXFIFO=%d IPISR=0x%x IPIER=0x%x\r",
	     *spissr, *txfifo, *rxfifo, *ipisr, *ipier);

  for (int i = 0; i < 3000000; i++)  // make output viewable
    ;
}

uint32_t psram_read_32(uint32_t addr) {
  spi_begin();

  *spidtr = 0x3;  // command = Read
  *spidtr = (addr >> 16) & 0xff;
  *spidtr = (addr >> 8) & 0xff;
  *spidtr = (addr >> 0) & 0xff;
  *spidtr = 0x11;  // dummy
  *spidtr = 0x12;  // dummy
  *spidtr = 0x13;  // dummy
  *spidtr = 0x14;  // dummy

  // consume 8 bytes. ignore first 4 and save last 4 as uint32
  uint32_t data = 0;
  for (int nbytes = 0; nbytes < 8; nbytes++) {
    uint32_t x = spi_read_byte();
    if (nbytes >= 4)
      data = (data << 8) | (x & 0xff);
  }
  spi_end();
  return data;
}

uint32_t psram_fastread_32(uint32_t addr) {
  spi_begin();

  *spidtr = 0xB;  // command = High Speed Read
  *spidtr = (addr >> 16) & 0xff;
  *spidtr = (addr >> 8) & 0xff;
  *spidtr = (addr >> 0) & 0xff;
  *spidtr = 0;  // dummy following address
  *spidtr = 0;  // read
  *spidtr = 0;  // read
  *spidtr = 0;  // read
  *spidtr = 0;  // read

  // consume rx fifo. return last 4 bytes as uint32
  uint32_t data = 0;
  for (int nbytes = 0; nbytes < 9; nbytes++) {
    data = (data << 8) | spi_read_byte();
  }

  spi_end();
  return data;
}

void psram_write32(uint32_t addr, uint32_t data) {
  spi_begin();

  *spidtr = 0x2;  // command = Write
  *spidtr = (addr >> 16) & 0xff;
  *spidtr = (addr >> 8) & 0xff;
  *spidtr = (addr >> 0) & 0xff;
  *spidtr = (data >> 24) & 0xff;
  *spidtr = (data >> 16) & 0xff;
  *spidtr = (data >> 8) & 0xff;
  *spidtr = (data >> 0) & 0xff;

  // consume 8 bytes
  for (int nbytes = 0; nbytes < 8; nbytes++) {
    spi_read_byte();
  }

  spi_end();
}

#if DEVICE == DEVICE_APS6404L

typedef struct {
  uint64_t eid;
  uint8_t mfid;
  uint8_t kgd;
} device_id;
device_id aps6404_id;

void psram_read_id(device_id *id) {
  spi_begin();
  spi_write_byte(0x9f);  // command = Read Mode Register
  spi_write_byte(0);  // don't care
  spi_write_byte(0);  // don't care
  spi_write_byte(0);  // don't care
  id->mfid = spi_write_byte(0);
  id->kgd = spi_write_byte(0);
  uint64_t x = 0;
  for (int i = 0; i < 6; i++)
    x = (x << 8) | spi_write_byte(0);
  id->eid = x;
  spi_end();
}

#endif

void psram_write_mode() {
  spi_begin();

  spi_write_byte(0x1);  // command = Write Mode Register
  spi_write_byte(0x40);
  // Second byte is optional on the 23AA04 and doesn't control anything useful so go with compatibility.
  spi_write_byte(0x14);

  spi_end();
}

uint32_t psram_read_mode() {
  spi_begin();

  spi_write_byte(0x5);  // command = Read Mode Register
  // uint32_t data = spi_write_byte(0);
  uint32_t data = (spi_write_byte(0) << 8) | spi_write_byte(0);

  spi_end();
  return data;
}

void psram_init() {
  psram_errors = 0;
  word = 0;
  pattern = 0;
  rd_empty = 0;

  *spissr = 1;  // wake device by toggling CSn
#if DEVICE == DEVICE_MICROCHIP_23LC1024
  psram_write_mode();
#elif DEVICE == DEVICE_APS6404L
  *spissr = 0;
  spi_write_byte(0x66);  // command = reset
  *spissr = 1;  // CSn high idle slave
  asm volatile("nop\n nop\n");
  *spissr = 0;
  spi_write_byte(0x99);
  *spissr = 1;  // CSn high idle slave
  asm volatile("nop\n nop\n nop\n nop\n nop\n");  // 50ns delay
  psram_read_id(&aps6404_id);
#endif
}

void psram_test() {
  // vt100_at(9, 1);

#if DEVICE == DEVICE_APS6404L
  xil_printf("device_id mfid=0x%x kgd=0x%x eid=%llx [%s %d mbit]\r",
		  aps6404_id.mfid,
		  aps6404_id.kgd, aps6404_id.eid,
		  aps6404_id.mfid == 0xd ? "apmemory" : "?",
		  16 << (aps6404_id.eid >> 45));
  const int num_words = (64 << 20) / 32;
  const int step_words = 131072;
#elif DEVICE == DEVICE_MICROCHIP_23LC1024
  const int num_bits = 4 << 20;
  const int num_words = num_bits / 32;
  const int step_words = 131072;
#endif

#if DEVICE == DEVICE_MICROCHIP_23LC1024
  uint32_t mode = psram_read_mode();
  xil_printf("mode=0x%x ", mode);
#endif

  xil_printf("pass %d pattern=%d ", spi_pass++, pattern);

  xil_printf("[%d,%d) writing...", word * 4, (word + step_words) * 4);
  uint32_t start_time = cycles();
  for (int i = word; i < word + step_words; i++) {
    uint32_t out;
    switch (pattern) {
    case 1: out = ~i; break;
    case 2: out = i ^ 0xdeadbeef; break;
    default: out = i; break;
    }
    psram_write32(i * 4, out);
  }
  uint32_t write_cycles = (cycles() - start_time) / step_words;

  xil_printf("reading...");
  start_time = cycles();
  for (int i = word; i < word + step_words; i++) {
    uint32_t data = psram_fastread_32(i * 4);
    uint32_t out;
    switch (pattern) {
    case 1: out = ~i; break;
    case 2: out = i ^ 0xdeadbeef; break;
    default: out = i; break;
    }
    if (data != out) {
      psram_errors += 1;
    }
  }
  uint32_t read_cycles = (cycles() - start_time) / step_words;

  word += step_words;
  if (word >= num_words) {
	  word = 0;
	  pattern = (pattern + 1) % 3;
  }

  xil_printf(RED "errors=%d" WHITE " rx_cycles=%u tx_cycles=%u\r",
	     psram_errors, read_cycles, write_cycles);
}

void spi_all() {
  spi_init();
  psram_init();
  perfmon_init();

  while (1) {
    *ipisr = *ipisr;   // clear interrupt flags
    vt100_cls();

    dump_spi_core_regs();

    psram_test();

    perfmon_print();

    flash_led();
  }
}

int main ()
{
  Xil_ICacheEnable();
  Xil_DCacheEnable();

  // loop();
  xil_printf("\rmain\r");
  spi_all();
  xil_printf("done\r");
  
  //Xil_DCacheDisable();
  //Xil_ICacheDisable();
  return 0;
}
