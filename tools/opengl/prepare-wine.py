"""Apply only the selected GL patch to BCD's pinned Wine, fail on drift."""
import hashlib,pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[2];w=r/'wine'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=w,text=True).strip()=='469e08af66c2638b74422e3d068620d400272d55'
p=r/'tools/opengl/wine-opengl.patch'
if subprocess.run(['git','apply','--reverse','--check',str(p)],cwd=w,capture_output=True).returncode:
 subprocess.run(['git','apply','--check',str(p)],cwd=w,check=True)
 subprocess.run(['git','apply',str(p)],cwd=w,check=True)
# Force an explicit MOV read of the TEB. BCD's existing x18 patcher rewrites
# MOV xN,x18 into a safe TLS load. Unlike the donor, we do not add stack-saving
# x18 store trampolines: ARM64EC's SP can be only 8-byte aligned.
p=w/'dlls/opengl32/private.h';s=p.read_text()
if 'bcd_gl_current_teb' not in s:
 anchor='#include "wine/wgl.h"'
 assert s.count(anchor)==1
 s=s.replace(anchor,anchor+'''

#if defined(__aarch64__) || defined(__arm64ec__)
static inline TEB *bcd_gl_current_teb(void)
{
    TEB *teb;
    __asm__ volatile ("mov %0, x18" : "=r"(teb));
    return teb;
}
#define NtCurrentTeb() bcd_gl_current_teb()
#endif
''')
 p.write_text(s)
print('Prepared matching PE/native opengl32 sources; safe explicit TEB reads')
