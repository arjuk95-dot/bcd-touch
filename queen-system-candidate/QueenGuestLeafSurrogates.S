/* Purpose-written x86-64 guest surrogates. Not extracted game or DLL code.
 * Implements the Windows x64 TEB ABI used by this pinned runtime:
 * LastErrorValue gs:0x68, TlsSlots gs:0x1480, TlsExpansionSlots gs:0x1780,
 * ClientId.UniqueThread gs:0x48. Validation of the original native APIs
 * remains separate and fail-closed in QueenGuestLeafInstall.h.
 */
.intel_syntax noprefix
.section .text.queen_tls,"ax",@progbits
.global queen_tls
queen_tls:
    mov dword ptr gs:[0x68], 0
    cmp ecx, 64
    jae .Lexpansion
    mov eax, ecx
    mov rax, qword ptr gs:[rax*8+0x1480]
    ret
.Lexpansion:
    sub ecx, 64
    cmp ecx, 1024
    jae .Linvalid
    mov rax, qword ptr gs:[0x1780]
    test rax, rax
    je .Lzero
    mov rax, qword ptr [rax+rcx*8]
    ret
.Linvalid:
    mov dword ptr gs:[0x68], 87
.Lzero:
    xor eax, eax
    ret
.section .text.queen_tid,"ax",@progbits
.global queen_tid
queen_tid:
    mov eax, dword ptr gs:[0x48]
    ret
.section .note.GNU-stack,"",@progbits
