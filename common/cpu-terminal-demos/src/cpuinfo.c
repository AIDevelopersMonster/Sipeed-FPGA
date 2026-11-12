/* Architecture-neutral diagnostics, with one known CRC-32 test vector. */
#include "demos.h"
#include <limits.h>

static unsigned long crc32_9bytes(void)
{
    const unsigned char bytes[9] = {'1','2','3','4','5','6','7','8','9'};
    unsigned long crc = 0xFFFFFFFFUL;
    int i, b;
    for (i=0; i<9; i++) {
        crc ^= (unsigned long)bytes[i];
        for (b=0; b<8; b++) {
            if (crc & 1UL) crc = (crc >> 1) ^ 0xEDB88320UL;
            else crc >>= 1;
            crc &= 0xFFFFFFFFUL;
        }
    }
    return (crc ^ 0xFFFFFFFFUL) & 0xFFFFFFFFUL;
}

void demo_cpu_info(void)
{
    unsigned short word = 0x0102U;
    unsigned char *first = (unsigned char *)&word;
    unsigned long crc = crc32_9bytes();
    t_puts("\nCPU INTEGER / ENDIAN / CRC32 DEMO\n");
    t_puts("CHAR_BIT=");t_uint((unsigned long)CHAR_BIT);
    t_puts(" sizeof(char)=");t_uint((unsigned long)sizeof(char));
    t_puts(" sizeof(short)=");t_uint((unsigned long)sizeof(short));
    t_puts(" sizeof(int)=");t_uint((unsigned long)sizeof(int));
    t_puts(" sizeof(long)=");t_uint((unsigned long)sizeof(long));
    t_puts(" sizeof(void*)=");t_uint((unsigned long)sizeof(void *));
    t_putchar('\n');
    t_puts("BYTE ORDER=");
    t_puts(first[0]==2 ? "LITTLE" : (first[0]==1 ? "BIG" : "OTHER"));
    t_putchar('\n');
    t_puts("CRC32(123456789)=0x");t_hex32(crc);
    t_puts(" (expected CBF43926) ");
    t_puts(crc==0xCBF43926UL ? "PASS\n" : "FAIL\n");
    t_puts("TIME/CYCLES: not reported (requires target-specific timer)\n");
}