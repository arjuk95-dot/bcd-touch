/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Bounded, read-only failure evidence for a 32-bit generated-code entry.
 * A register is only a candidate, never proof of the caller. */
#ifndef IOS_X86_ENTRY_CODE_H
#define IOS_X86_ENTRY_CODE_H
#include <stdint.h>
#include <stddef.h>

static size_t ios_x86_entry_code_window(uint64_t base, uint64_t candidate, uint64_t target,
                                       uintptr_t (*alias)(uintptr_t), uint64_t *start)
{
    size_t length = 0;
    uintptr_t first;
    uint64_t low;

    if (!base || candidate < 0x10020 || candidate > UINT32_MAX || target > UINT32_MAX ||
        candidate >= target || target - candidate > 0x10000 ||
        base > UINTPTR_MAX - UINT32_MAX) return 0;
    /* Only an existing anonymous executable alias is eligible. Never dump a
     * heap/stack register, or read across the end of its mapping. */
    if (!alias((uintptr_t)(base + candidate))) return 0;
    low = candidate - 32;
    first = alias((uintptr_t)(base + low));
    if (!first) return 0;
    while (length < 512 && low + length <= UINT32_MAX &&
           alias((uintptr_t)(base + low + length)) == first + length) length++;
    if (length <= 32) return 0;
    *start = low;
    return length;
}
#endif
