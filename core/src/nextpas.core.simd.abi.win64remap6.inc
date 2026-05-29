// Win64 → SysV ABI parameter remapping for 6-param nostackframe functions.
// Place at the VERY START of the asm block, BEFORE any push/sub rsp.
//
// Win64 entry: rcx=p1, rdx=p2, r8=p3, r9=p4, [rsp+40]=p5, [rsp+48]=p6
// SysV target: rdi=p1, rsi=p2, rdx=p3, rcx=p4, r8=p5, r9=p6
//
// Order is safe: rdi/rsi are scratch on Win64 entry (no input there).
{$IFNDEF UNIX}
  mov rdi, rcx
  mov rsi, rdx
  mov rdx, r8
  mov rcx, r9
  mov r8, [rsp + 40]
  mov r9, [rsp + 48]
{$ENDIF}
