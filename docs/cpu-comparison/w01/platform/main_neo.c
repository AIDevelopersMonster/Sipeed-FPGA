#include <stdint.h>
extern uint32_t w01_workload(void);
#define REG32(a) (*(volatile uint32_t *)(a))
#define EXPECTED 0xB26F8CA7u
/* W01 NEORV32 native MMIO. */
#define GPIO_OUT REG32(0xFFFC0004u)
#define CTRL REG32(0xFFF50000u)
#define TX REG32(0xFFF50004u)
static void board_uart_init(void) {CTRL=(116u<<6)|1u;}
static void uart_putc(char c) {
  while(!(CTRL&(1u<<19))){}
  TX=(uint8_t)c;
}
static void board_uart_drain(void) {while(CTRL&(1u<<31)){}}

static uint32_t cycle32(void) {
  uint32_t c;
  __asm__ volatile ("csrr %0, cycle" : "=r"(c) :: "memory");
  return c;
}
static void hex32(uint32_t v) {
  const char *digits="0123456789ABCDEF";
  for(int s=28;s>=0;s-=4) uart_putc(digits[(v>>s)&15]);
}
__attribute__((noreturn)) void main(void) {
  board_uart_init();
  GPIO_OUT=0x15;
  uint32_t start=cycle32();
  uint32_t digest=w01_workload();
  uint32_t elapsed=cycle32()-start;
  GPIO_OUT=(digest==EXPECTED)?0x2a:0x3f;
  const char *prefix="W01:";
  for(const char *p=prefix;*p;p++) uart_putc(*p);
  hex32(digest);uart_putc(':');hex32(elapsed);
  uart_putc('\r');uart_putc('\n');
  board_uart_drain();
  for(;;)__asm__ volatile("nop");
}
