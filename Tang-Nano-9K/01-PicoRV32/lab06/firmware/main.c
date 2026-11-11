#include <stdint.h>
/* Native Pico adapter; same 16KiB ROM / 2KiB RAM and GPIO sequence as NEORV32. */
#define REG32(a) (*(volatile uint32_t*)(a))
#define LED REG32(0x20000000u)
#define TX REG32(0x20000010u)
#define READY REG32(0x20000014u)
static void putc_uart(char c) {
  while (!(READY & 1u)) {}
  TX = (uint8_t)c;
}
__attribute__((noreturn)) void main(void) {
  const char *s = "PICORV32 READY\r\n";
  LED = 0x15u;
  for (; *s; s++) putc_uart(*s);
  while (!(READY & 1u)) {}
  LED = 0x2au;
  for (;;) __asm__ volatile("nop");
}
