# P5: RTL Bootstrap Strategy

> **Goal:** nextpas compiles its own System unit and produces standalone executables.

## Architecture (Codex-reviewed)

### Layer 0: Compiler Intrinsics (always built-in)
WriteLn, SetLength, Length, Inc, Dec, Ord, Chr, Halt, SizeOf, Assigned

### Layer 1: System unit (implicit uses)
TObject, Exception, fpc_* compilerproc helpers

### Layer 2: Platform units (explicit uses)
SysUtils, Classes, etc.

## Phase A: Hosted Bootstrap

### A1: compilerproc mechanism
- Parse `compilerproc` directive
- Codegen emits calls to fpc_* functions instead of inline
- Fallback to inline when System unit not loaded

### A2: Minimal System unit
- TObject base class
- fpc_ansistr_incr_ref / decr_ref
- fpc_dynarray_setlength
- Memory management (brk/mmap syscall)

### A3: Linker integration
- system.o + user.o → ELF executable
- _start → init → main → finalize → exit

### A4: Exception support
- DWARF unwinding or setjmp/longjmp (already have setjmp)
- fpc_raiseexception

## Blocking Items (priority order)
1. compilerproc directive (P0)
2. Implicit uses System (P0)
3. Pointer arithmetic (P1)
4. packed record (P1)
5. Inline assembly (P1) — already have module-level asm
6. InterlockedIncrement (P2)

## Current Status
- 131/131 LLVM smoke tests
- Unit compilation works (uses statement)
- Exception objects work (raise + ExceptObject)
- All OOP/generics/interface features complete
