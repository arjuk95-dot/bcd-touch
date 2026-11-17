#!/usr/bin/env python3
"""Queen alternative DLL ONLY. Source transform, NOT a complete installer/build.
The integrating Module.cpp must allocate/validate/register the actual leaves.
No mutation of source targets, exports, IATs or EC bitmap.
"""
import pathlib, sys
root = pathlib.Path(sys.argv[1])
here = pathlib.Path(__file__).parent
header = root / 'FEXCore/include/FEXCore/Core/QueenGuestLeaf.h'
header.write_bytes((here / header.name).read_bytes())

def replace(path, before, after):
    p = root / path
    s = p.read_text()
    if s.count(before) != 1:
        raise SystemExit(f'{path}: expected exactly one source anchor')
    p.write_text(s.replace(before, after))

include = '''#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
#include <FEXCore/Core/QueenGuestLeaf.h>
#endif
'''
for path in ['FEXCore/Source/Interface/Core/JIT/BranchOps.cpp',
             'FEXCore/Source/Interface/Core/Dispatcher/Dispatcher.cpp']:
    p = root / path
    s = p.read_text()
    if 'QueenGuestLeaf.h' in s:
        raise SystemExit(f'{path}: already patched')
    p.write_text(include + s)

replace('FEXCore/Source/Interface/Core/JIT/BranchOps.cpp',
"""  uint64_t NewRIP;
""", """  uint64_t NewRIP;
#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
  uint64_t QueenOriginalNative = 0;
  ARMEmitter::ForwardLabel QueenOriginalNativeLabel;
#endif
""")

replace('FEXCore/Source/Interface/Core/JIT/BranchOps.cpp',
"""}

DEF_OP(Jump) {""", """#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
  if (QueenOriginalNative) {
    // Guest CALL continuation may fall through here. Skip the cold native
    // fallback; only the TF branch above may enter it.
    ARMEmitter::ForwardLabel QueenLeafContinue;
    (void)b(&QueenLeafContinue);
    (void)Bind(&QueenOriginalNativeLabel);
    if (CallRetStackUsed()) {
      str(REG_CALLRET_SP, STATE_PTR(CpuStateFrame, State.callret_sp));
    }
    add(ARMEmitter::Size::i64Bit, ARMEmitter::Reg::rsp, StaticRegisters[X86State::REG_RSP], 0);
    InsertGuestRIPMove(EC_CALL_CHECKER_PC_REG, QueenOriginalNative);
    ldr(TMP2, STATE_PTR(CpuStateFrame, Pointers.ExitFunctionEC));
    if (Op->Hint == IR::BranchHint::Call && IosEcReturnWithRet) {
      blr(TMP2);
    } else {
      br(TMP2);
    }
    (void)Bind(&QueenLeafContinue);
  }
#endif
}

DEF_OP(Jump) {""")

replace('FEXCore/Source/Interface/Core/JIT/BranchOps.cpp',
'''    if (NewRIP < EC_CODE_BITMAP_MAX_ADDRESS && RtlIsEcCode(NewRIP)) {''',
'''#ifdef FEX_IOS_HOST
    // Use the ordinary guest branch lowering, including CALL shadow-stack
    // bookkeeping. Runtime trap stepping retains the original native path.
    if (const auto Leaf = FEXCore::Core::QueenGuestLeafLookup(NewRIP)) {
      QueenOriginalNative = NewRIP;
      ldrb(TMP1, STATE_PTR(CpuStateFrame, State.flags[X86State::RFLAG_TF_RAW_LOC]));
      (void)cbnz(ARMEmitter::Size::i32Bit, TMP1, &QueenOriginalNativeLabel);
      NewRIP = Leaf;
    }
#endif
    if (NewRIP < EC_CODE_BITMAP_MAX_ADDRESS && RtlIsEcCode(NewRIP)) {''')

replace('FEXCore/Source/Interface/Core/Dispatcher/Dispatcher.cpp',
'''  (void)tbz(TMP1, 0, &l_NotECCode);

  if (CallRetStackUsed()) {''',
'''  (void)tbz(TMP1, 0, &l_NotECCode);

#ifdef FEX_IOS_HOST
  // Preserve original native instruction stepping. Only the EC-positive
  // path pays a lookup; ordinary guest dispatch remains unchanged.
  ARMEmitter::ForwardLabel l_QueenNative;
  ldrb(TMP1, STATE_PTR(CpuStateFrame, State.flags[X86State::RFLAG_TF_RAW_LOC]));
  (void)cbnz(ARMEmitter::Size::i32Bit, TMP1, &l_QueenNative);
  LoadConstant(ARMEmitter::Size::i64Bit, TMP1,
               reinterpret_cast<uint64_t>(FEXCore::Core::QueenGuestLeafTargets));
  ubfx(ARMEmitter::Size::i64Bit, TMP2, RipReg, 3, 6);
  add(TMP1, TMP1, TMP2, ARMEmitter::ShiftType::LSL, 4);
  ldp<ARMEmitter::IndexType::OFFSET>(TMP1, TMP2, TMP1, 0);
  sub(TMP1, TMP1, RipReg); // No NZCV change.
  (void)cbnz(ARMEmitter::Size::i64Bit, TMP1, &l_QueenNative);
  (void)cbz(ARMEmitter::Size::i64Bit, TMP2, &l_QueenNative);
  mov(RipReg, TMP2);
  str(RipReg, STATE_PTR(CpuStateFrame, State.rip));
  (void)b(&l_NotECCode);
  (void)Bind(&l_QueenNative);
#endif

  if (CallRetStackUsed()) {''')

p = root / 'Source/Windows/ARM64EC/Module.cpp'
s = p.read_text()
if 'QueenGuestLeafTargets[64]' in s:
    raise SystemExit('Module.cpp: already patched')
p.write_text(include + '''
#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
namespace FEXCore::Core {
alignas(64) QueenGuestLeafTarget QueenGuestLeafTargets[64] {};
}
#endif
''' + s)
print('Source route applied; registration is deliberately NOT automatic.')
