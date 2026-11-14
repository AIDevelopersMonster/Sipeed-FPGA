/* Minimal C runtime primitive required by clang when lowering struct copies.
 * Freestanding RV32I; no standard C library or libgcc at link time.
 * SPDX-License-Identifier: MIT
 */
#include <stddef.h>
void *memcpy(void *dst, const void *src, size_t count) {
    unsigned char *d=(unsigned char *)dst;
    const unsigned char *s=(const unsigned char *)src;
    size_t i;
    for (i=0;i<count;++i) d[i]=s[i];
    return dst;
}
