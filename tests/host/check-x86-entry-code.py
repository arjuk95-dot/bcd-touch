#!/usr/bin/env python3
"""Compile production diagnostic bounds; no game, Wine or iOS execution."""
from pathlib import Path
import os
import subprocess
import tempfile
root=Path(__file__).resolve().parents[2]
source=r'''
#include <assert.h>
#include <stdio.h>
#include "ios_x86_entry_code.h"
static uintptr_t resolve(uintptr_t p) {
    return p>=0x4fff30000ULL && p<0x4fff40000ULL ? p-0x4fff30000ULL+0x300000000ULL:0;
}
int main(void) {
    uint64_t start=0;
    // Fault fixture: stop exactly at the end of the alias, before the image header.
    assert(ios_x86_entry_code_window(0x400000000ULL,0xfff3fef5,0xfff40048,resolve,&start)==299);
    assert(start==0xfff3fed5);
    // Full window, wrong registers, unrelated far targets, overflow, unmapped heap.
    assert(ios_x86_entry_code_window(0x400000000ULL,0xfff3c000,0xfff40048,resolve,&start)==512);
    assert(!ios_x86_entry_code_window(0x400000000ULL,0x1bdf1930,0xfff40048,resolve,&start));
    assert(!ios_x86_entry_code_window(0x400000000ULL,0xfff30000,0xfff40048,resolve,&start));
    assert(!ios_x86_entry_code_window(0,0xfff3fef5,0xfff40048,resolve,&start));
    assert(!ios_x86_entry_code_window(UINT64_MAX,0xfff3fef5,0xfff40048,resolve,&start));
    assert(!ios_x86_entry_code_window(0x400000000ULL,0x1fff3fef5ULL,0xfff40048,resolve,&start));
    assert(!ios_x86_entry_code_window(0x400000000ULL,0xfff40048,0xfff3fef5,resolve,&start));
    puts("PASS: bounded generated-code failure window; mapping limits and invalid candidates");
}
'''
with tempfile.TemporaryDirectory(prefix='bcd-entry-code-') as tmp:
    p=Path(tmp);src=p/'check.c';exe=p/'check';src.write_text(source)
    subprocess.run([os.environ.get('CC','cc'),'-Wall','-Wextra','-Werror','-I',str(root/'build/ntdll-unix'),str(src),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
