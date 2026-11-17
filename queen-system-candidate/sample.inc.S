// Called ONLY on ExitFunctionECJit's existing 1/64 sampled path, after its
// ring store. x28 is a proven CpuStateFrame here; generic ExitFunctionEC isn't.
// x4/x16/x17/x23 are already scratch in the original exit. Preserve NZCV;
// preserve all argument/SRA registers, x9 target, SP and LR. No stack access.
.macro QUEEN_COPY_SAMPLE
  adrp x16, QueenCopyConfig
  add x16, x16, #:lo12:QueenCopyConfig
  ldr x17, [x16, #32]
  cbz x17, .Lqcs_done\@
  mrs x4, nzcv
  ldr x17, [x16]
  cmp x9, x17
  b.eq .Lqcs_match\@
  ldr x17, [x16, #8]
  cmp x9, x17
  b.eq .Lqcs_match\@
  ldr x17, [x16, #16]
  cmp x9, x17
  b.eq .Lqcs_match\@
  ldr x17, [x16, #24]
  cmp x9, x17
  b.ne .Lqcs_restore\@
.Lqcs_match\@:
  // Exact API target matched. Count coverage independently from row success.
  adrp x16, QueenCopySeen
  add x16, x16, #:lo12:QueenCopySeen
  mov x17, #1
  stadd x17, [x16]
  lsr x17, x28, #20
  eor x17, x17, x28, lsr #12
  and x17, x17, #255
  adrp x16, QueenCopyRows
  add x16, x16, #:lo12:QueenCopyRows
  add x16, x16, x17, lsl #11
  ldar x17, [x16]
  cbnz x17, .Lqcs_owner\@
  // Empty row claim; no spinning and no overwrite of another frame.
  casal x17, x28, [x16]
  cbz x17, .Lqcs_tid\@
.Lqcs_owner\@:
  cmp x17, x28
  b.ne .Lqcs_drop\@
.Lqcs_tid\@:
  IOS_LOAD_TEB x23
  ldr w23, [x23, #0x48]
  ldr x17, [x16, #8]
  cbnz x17, .Lqcs_check_tid\@
  // Same frame cannot be owned by two live guest threads; recursive sampling
  // initializes the same TID. A recycled frame with another TID is rejected.
  add x17, x16, #8
  stlr x23, [x17]
  b .Lqcs_classify\@
.Lqcs_check_tid\@:
  cmp x17, x23
  b.ne .Lqcs_drop\@
.Lqcs_classify\@:
  adrp x17, QueenCopyConfig
  add x17, x17, #:lo12:QueenCopyConfig
  ldr x23, [x17]
  cmp x9, x23
  b.eq .Lqcs_copy\@
  ldr x23, [x17, #8]
  cmp x9, x23
  b.eq .Lqcs_copy\@
  mov x23, #520 // memset's 65-bin array follows memcpy's.
  b .Lqcs_bytes\@
.Lqcs_copy\@:
  mov x23, #0
.Lqcs_bytes\@:
  // Byte sums are diagnostic only; mark overflow explicitly, never silently
  // interpret wrapped totals as a real size distribution.
  add x17, x16, #1056
  add x17, x17, x23, lsr #6 // 0 or8 selects API's byte sum.
  ldadd x2, x17, [x17]
  adds x17, x17, x2
  b.cc .Lqcs_bucket\@
  add x17, x16, #1072
  add x17, x17, x23, lsr #6
  mov x23, #1
  str x23, [x17]
  // Recover the API offset after using x23 for the overflow marker.
  sub x23, x17, x16
  sub x23, x23, #1072
  lsl x23, x23, #6 // 0 or512
  cbz x23, .Lqcs_bucket\@
  add x23, x23, #8 // 520
.Lqcs_bucket\@:
  clz x17, x2
  neg x17, x17
  add x17, x17, #64 // zero size -> bucket0, UINT64_MAX ->64.
  add x17, x16, x17, lsl #3
  add x17, x17, #16
  add x17, x17, x23
  mov x23, #1
  stadd x23, [x17]
  b .Lqcs_restore\@
.Lqcs_drop\@:
  adrp x16, QueenCopyDropped
  add x16, x16, #:lo12:QueenCopyDropped
  mov x17, #1
  stadd x17, [x16]
.Lqcs_restore\@:
  msr nzcv, x4
.Lqcs_done\@:
.endm
