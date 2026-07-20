// === Facade Functions with NEON ===
// ICE-safe pattern: use ldp + fmov + ins instead of ldr q

function MemEqual_NEON(a, b: Pointer; len: SizeUInt): LongBool; assembler; nostackframe;
asm
  // x0 = a, x1 = b, x2 = len
  cbz   x2, .Lequal          // len == 0, return true
  cmp   x0, x1
  b.eq  .Lequal              // same pointer (including both nil)
  cbz   x0, .Lnotequal       // one nil => not equal
  cbz   x1, .Lnotequal
  
  // Process 16 bytes at a time
.Lloop16:
  cmp   x2, #16
  b.lo  .Ltail
  // ICE-safe load: ldp + fmov + ins instead of ldr q
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  cmeq  v0.16b, v0.16b, v1.16b
  // Check if all bytes equal (all 1s)
  uminv b2, v0.16b           // Min of all bytes
  umov  w3, v2.b[0]
  cmp   w3, #255
  b.ne  .Lnotequal
  sub   x2, x2, #16
  cbnz  x2, .Lloop16
  b     .Lequal
  
.Ltail:
  // Handle remaining bytes
  cbz   x2, .Lequal
.Ltailloop:
  ldrb  w3, [x0], #1
  ldrb  w4, [x1], #1
  cmp   w3, w4
  b.ne  .Lnotequal
  subs  x2, x2, #1
  b.ne  .Ltailloop
  
.Lequal:
  mov   w0, #1
  ret
  
.Lnotequal:
  mov   w0, #0
  ret
end;

function SumBytes_NEON(p: Pointer; len: SizeUInt): UInt64; assembler; nostackframe;
asm
  // x0 = p, x1 = len
  mov   x3, #0
  cbz   x1, .Ldone

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  uaddlv h0, v0.16b           // sum 16 bytes -> 16-bit
  umov  w2, v0.h[0]
  add   x3, x3, x2

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Ldone

.Ltail:
  cbz   x1, .Ldone
.Ltailloop:
  ldrb  w2, [x0], #1
  add   x3, x3, x2
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Ldone:
  mov   x0, x3
end;

function CountByte_NEON(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; assembler; nostackframe;
asm
  // x0 = p, x1 = len, w2 = value
  mov   x3, #0
  dup   v0.16b, w2
  cbz   x1, .Ldone

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load
  ldp   x4, x5, [x0], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  cmeq  v1.16b, v1.16b, v0.16b
  ushr  v1.16b, v1.16b, #7    // 0xFF -> 1, 0 -> 0
  uaddlv h1, v1.16b           // sum 16 bytes -> 16-bit
  umov  w4, v1.h[0]
  add   x3, x3, x4

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Ldone

.Ltail:
  cbz   x1, .Ldone
.Ltailloop:
  ldrb  w4, [x0], #1
  cmp   w4, w2
  cinc  x3, x3, eq
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Ldone:
  mov   x0, x3
end;

function MemFindByte_NEON(p: Pointer; len: SizeUInt; value: Byte): PtrInt; assembler; nostackframe;
asm
  // x0 = p, x1 = len, w2 = value
  mov   x3, x0               // Save original pointer
  dup   v0.16b, w2           // Broadcast search value
  cbz   x1, .Lnotfound
  
.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail
  // ICE-safe load (no post-increment here since we need x0 for found position)
  ldp   x4, x5, [x0]
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  cmeq  v1.16b, v1.16b, v0.16b
  // Check if any match
  umaxv b2, v1.16b           // Max of all bytes
  umov  w4, v2.b[0]
  cbnz  w4, .Lfound16
  add   x0, x0, #16
  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Lnotfound
  
.Lfound16:
  // Find exact position in the 16 bytes
  mov   w5, #0
.Lscan:
  umov  w4, v1.b[0]
  cbnz  w4, .Lfoundexact
  ext   v1.16b, v1.16b, v1.16b, #1  // Shift left by 1
  add   w5, w5, #1
  cmp   w5, #16
  b.lo  .Lscan
  
.Lfoundexact:
  add   x0, x0, x5
  sub   x0, x0, x3           // Return offset
  ret
  
.Ltail:
  cbz   x1, .Lnotfound
.Ltailloop:
  ldrb  w4, [x0]
  cmp   w4, w2
  b.eq  .Lfoundtail
  add   x0, x0, #1
  subs  x1, x1, #1
  b.ne  .Ltailloop
  b     .Lnotfound
  
.Lfoundtail:
  sub   x0, x0, x3
  ret
  
.Lnotfound:
  mov   x0, #-1
end;

// === BitsetPopCount NEON ===
// Uses parallel bit counting (SWAR algorithm) + horizontal sum
// Same algorithm as i386 SSE2 but with NEON instructions
function BitsetPopCount_NEON(p: Pointer; byteLen: SizeUInt): SizeUInt; assembler; nostackframe;
asm
  // x0 = p, x1 = byteLen
  // Return: x0 = popcount
  mov   x3, #0               // Total count
  cbz   x1, .Ldone
  cbz   x0, .Ldone

  // Prepare constants for SWAR popcount
  // 0x55 = 01010101, 0x33 = 00110011, 0x0F = 00001111
  mov   w4, #0x55
  dup   v16.16b, w4          // v16 = 0x55555555...
  mov   w4, #0x33
  dup   v17.16b, w4          // v17 = 0x33333333...
  mov   w4, #0x0F
  dup   v18.16b, w4          // v18 = 0x0F0F0F0F...

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load: ldp + fmov + ins
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]

  // SWAR popcount algorithm (parallel bit counting)
  // Step 1: x = x - ((x >> 1) & 0x55)
  ushr  v1.16b, v0.16b, #1   // v1 = x >> 1
  and   v1.16b, v1.16b, v16.16b  // v1 = (x >> 1) & 0x55
  sub   v0.16b, v0.16b, v1.16b   // v0 = x - ((x >> 1) & 0x55)

  // Step 2: x = (x & 0x33) + ((x >> 2) & 0x33)
  ushr  v1.16b, v0.16b, #2   // v1 = x >> 2
  and   v0.16b, v0.16b, v17.16b  // v0 = x & 0x33
  and   v1.16b, v1.16b, v17.16b  // v1 = (x >> 2) & 0x33
  add   v0.16b, v0.16b, v1.16b   // v0 = (x & 0x33) + ((x >> 2) & 0x33)

  // Step 3: x = (x + (x >> 4)) & 0x0F
  ushr  v1.16b, v0.16b, #4   // v1 = x >> 4
  add   v0.16b, v0.16b, v1.16b   // v0 = x + (x >> 4)
  and   v0.16b, v0.16b, v18.16b  // v0 = (x + (x >> 4)) & 0x0F

  // Now each byte in v0 contains popcount of original byte (0-8)
  // Sum all bytes using uaddlv (horizontal add across vector)
  uaddlv h0, v0.16b          // h0 = sum of all 16 bytes
  umov  w4, v0.h[0]
  add   x3, x3, x4

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Ldone

.Ltail:
  cbz   x1, .Ldone
  // Prepare scalar constants (reuse w6, w7 for tail loop)
  mov   w6, #0x55
  mov   w7, #0x33
.Ltailloop:
  ldrb  w4, [x0], #1
  // Inline popcount for single byte using SWAR
  lsr   w5, w4, #1
  and   w5, w5, w6           // w5 = (x >> 1) & 0x55
  sub   w4, w4, w5           // w4 = x - ((x >> 1) & 0x55)
  lsr   w5, w4, #2
  and   w4, w4, w7           // w4 = x & 0x33
  and   w5, w5, w7           // w5 = (x >> 2) & 0x33
  add   w4, w4, w5           // w4 = (x & 0x33) + ((x >> 2) & 0x33)
  lsr   w5, w4, #4
  add   w4, w4, w5           // w4 = x + (x >> 4)
  and   w4, w4, #0x0F        // 0x0F is valid bitmask immediate
  add   x3, x3, x4
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Ldone:
  mov   x0, x3
end;

// === MinMaxBytes NEON ===
// Uses uminv/umaxv for parallel min/max reduction
procedure MinMaxBytes_NEON(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); assembler; nostackframe;
asm
  // x0 = p, x1 = len, x2 = &minVal, x3 = &maxVal
  cbz   x1, .Lempty
  cbz   x0, .Lempty

  // Initialize min=255, max=0
  mov   w4, #255
  dup   v16.16b, w4          // v16 = current min (all 255)
  movi  v17.16b, #0          // v17 = current max (all 0)

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]

  // Update running min/max
  umin  v16.16b, v16.16b, v0.16b
  umax  v17.16b, v17.16b, v0.16b

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Lreduce

.Ltail:
  cbz   x1, .Lreduce
.Ltailloop:
  ldrb  w4, [x0], #1
  dup   v0.16b, w4
  umin  v16.16b, v16.16b, v0.16b
  umax  v17.16b, v17.16b, v0.16b
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Lreduce:
  // Reduce v16 to single min byte
  uminv b0, v16.16b
  umov  w4, v0.b[0]
  strb  w4, [x2]

  // Reduce v17 to single max byte
  umaxv b0, v17.16b
  umov  w4, v0.b[0]
  strb  w4, [x3]
  ret

.Lempty:
  // len=0 or p=nil: set min=max=0
  strb  wzr, [x2]
  strb  wzr, [x3]
end;

// === ToLowerAscii NEON ===
// For each byte: if 'A' <= byte <= 'Z', OR with 0x20
procedure ToLowerAscii_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // x0 = p, x1 = len
  cbz   x1, .Ldone
  cbz   x0, .Ldone

  // Prepare constants
  mov   w2, #'A'              // 65
  dup   v16.16b, w2           // v16 = 'A' broadcast
  mov   w2, #'Z'
  dup   v17.16b, w2           // v17 = 'Z' broadcast
  mov   w2, #0x20
  dup   v18.16b, w2           // v18 = 0x20 broadcast (case bit)

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load
  ldp   x2, x3, [x0]
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]

  // Check if in range ['A'..'Z']
  // mask = (byte >= 'A') & (byte <= 'Z')
  cmhs  v1.16b, v0.16b, v16.16b  // v1 = (byte >= 'A')
  cmhs  v2.16b, v17.16b, v0.16b  // v2 = ('Z' >= byte) = (byte <= 'Z')
  and   v1.16b, v1.16b, v2.16b   // v1 = mask

  // Apply: result = byte | (mask & 0x20)
  and   v1.16b, v1.16b, v18.16b  // v1 = mask & 0x20
  orr   v0.16b, v0.16b, v1.16b   // v0 = byte | (mask & 0x20)

  // Store back
  umov  x2, v0.d[0]
  umov  x3, v0.d[1]
  stp   x2, x3, [x0], #16

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Ldone

.Ltail:
  cbz   x1, .Ldone
.Ltailloop:
  ldrb  w2, [x0]
  sub   w3, w2, #'A'
  cmp   w3, #25               // 'Z' - 'A' = 25
  b.hi  .Lnochange
  orr   w2, w2, #0x20
.Lnochange:
  strb  w2, [x0], #1
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Ldone:
end;

// === ToUpperAscii NEON ===
// For each byte: if 'a' <= byte <= 'z', AND with ~0x20
procedure ToUpperAscii_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // x0 = p, x1 = len
  cbz   x1, .Ldone
  cbz   x0, .Ldone

  // Prepare constants
  mov   w2, #'a'              // 97
  dup   v16.16b, w2           // v16 = 'a' broadcast
  mov   w2, #'z'
  dup   v17.16b, w2           // v17 = 'z' broadcast
  mov   w2, #0x20
  dup   v18.16b, w2           // v18 = 0x20 broadcast (case bit)

.Lloop16:
  cmp   x1, #16
  b.lo  .Ltail

  // ICE-safe load
  ldp   x2, x3, [x0]
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]

  // Check if in range ['a'..'z']
  cmhs  v1.16b, v0.16b, v16.16b  // v1 = (byte >= 'a')
  cmhs  v2.16b, v17.16b, v0.16b  // v2 = ('z' >= byte) = (byte <= 'z')
  and   v1.16b, v1.16b, v2.16b   // v1 = mask (0xFF if lowercase)

  // Apply: result = byte & ~(mask & 0x20) = byte & (mask ? 0xDF : 0xFF)
  and   v1.16b, v1.16b, v18.16b  // v1 = mask & 0x20
  bic   v0.16b, v0.16b, v1.16b   // v0 = byte & ~(mask & 0x20)

  // Store back
  umov  x2, v0.d[0]
  umov  x3, v0.d[1]
  stp   x2, x3, [x0], #16

  sub   x1, x1, #16
  cbnz  x1, .Lloop16
  b     .Ldone

.Ltail:
  cbz   x1, .Ldone
.Ltailloop:
  ldrb  w2, [x0]
  sub   w3, w2, #'a'
  cmp   w3, #25               // 'z' - 'a' = 25
  b.hi  .Lnochange
  bic   w2, w2, #0x20
.Lnochange:
  strb  w2, [x0], #1
  subs  x1, x1, #1
  b.ne  .Ltailloop

.Ldone:
end;

// === AsciiIEqual NEON ===
// Case-insensitive comparison: convert both to lowercase, then compare
function AsciiIEqual_NEON(a, b: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // x0 = a, x1 = b, x2 = len
  // Return: w0 = 1 if equal, 0 otherwise
  cbz   x2, .Lequal           // len == 0 => equal
  cmp   x0, x1
  b.eq  .Lequal               // same pointer => equal
  cbz   x0, .Lnotequal        // one nil => not equal
  cbz   x1, .Lnotequal

  // Prepare constants for lowercase conversion
  mov   w3, #'A'
  dup   v16.16b, w3           // v16 = 'A'
  mov   w3, #'Z'
  dup   v17.16b, w3           // v17 = 'Z'
  mov   w3, #0x20
  dup   v18.16b, w3           // v18 = 0x20 (case bit)

.Lloop16:
  cmp   x2, #16
  b.lo  .Ltail

  // Load a
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]

  // Load b
  ldp   x3, x4, [x1], #16
  fmov  d2, x3
  fmov  d1, x4
  ins   v2.d[1], v1.d[0]

  // Convert a to lowercase
  cmhs  v3.16b, v0.16b, v16.16b
  cmhs  v4.16b, v17.16b, v0.16b
  and   v3.16b, v3.16b, v4.16b
  and   v3.16b, v3.16b, v18.16b
  orr   v0.16b, v0.16b, v3.16b

  // Convert b to lowercase
  cmhs  v3.16b, v2.16b, v16.16b
  cmhs  v4.16b, v17.16b, v2.16b
  and   v3.16b, v3.16b, v4.16b
  and   v3.16b, v3.16b, v18.16b
  orr   v2.16b, v2.16b, v3.16b

  // Compare
  cmeq  v0.16b, v0.16b, v2.16b
  uminv b0, v0.16b
  umov  w3, v0.b[0]
  cmp   w3, #255
  b.ne  .Lnotequal

  sub   x2, x2, #16
  cbnz  x2, .Lloop16
  b     .Lequal

.Ltail:
  cbz   x2, .Lequal
.Ltailloop:
  ldrb  w3, [x0], #1
  ldrb  w4, [x1], #1
  // Convert w3 to lowercase
  sub   w5, w3, #'A'
  cmp   w5, #25
  b.hi  .Lskip_a
  orr   w3, w3, #0x20
.Lskip_a:
  // Convert w4 to lowercase
  sub   w5, w4, #'A'
  cmp   w5, #25
  b.hi  .Lskip_b
  orr   w4, w4, #0x20
.Lskip_b:
  cmp   w3, w4
  b.ne  .Lnotequal
  subs  x2, x2, #1
  b.ne  .Ltailloop

.Lequal:
  mov   w0, #1
  ret

.Lnotequal:
  mov   w0, #0
end;

// === Phase 22a: NEON Memory Copy / Fill / DiffRange ===

procedure MemCopy_NEON(src, dst: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // x0 = src, x1 = dst, x2 = len
  cbz   x2, .Lcopy_done
  cbz   x0, .Lcopy_done
  cbz   x1, .Lcopy_done
  cmp   x0, x1
  b.eq  .Lcopy_done

.Lcopy_loop16:
  cmp   x2, #16
  b.lo  .Lcopy_tail
  // ICE-safe 16-byte load/store
  ldp   x3, x4, [x0], #16
  stp   x3, x4, [x1], #16
  sub   x2, x2, #16
  cbnz  x2, .Lcopy_loop16
  b     .Lcopy_done

.Lcopy_tail:
  cbz   x2, .Lcopy_done
.Lcopy_tail_loop:
  ldrb  w3, [x0], #1
  strb  w3, [x1], #1
  subs  x2, x2, #1
  b.ne  .Lcopy_tail_loop

.Lcopy_done:
  ret
end;

procedure MemSet_NEON(dst: Pointer; len: SizeUInt; value: Byte); assembler; nostackframe;
asm
  // x0 = dst, x1 = len, w2 = value
  cbz   x1, .Lset_done
  cbz   x0, .Lset_done
  dup   v0.16b, w2

.Lset_loop16:
  cmp   x1, #16
  b.lo  .Lset_tail
  // ICE-safe store of broadcast byte
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x0], #16
  sub   x1, x1, #16
  cbnz  x1, .Lset_loop16
  b     .Lset_done

.Lset_tail:
  cbz   x1, .Lset_done
.Lset_tail_loop:
  strb  w2, [x0], #1
  subs  x1, x1, #1
  b.ne  .Lset_tail_loop

.Lset_done:
  ret
end;

function MemDiffRange_NEON(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; assembler; nostackframe;
asm
  // x0 = a, x1 = b, x2 = len, x3 = &firstDiff, x4 = &lastDiff
  // Return: w0 = Boolean
  str   xzr, [x3]
  str   xzr, [x4]
  cbz   x2, .Ldiff_false

  // nil handling: either nil and pointers differ → full range
  cbz   x0, .Ldiff_nil
  cbz   x1, .Ldiff_nil
  cmp   x0, x1
  b.eq  .Ldiff_false

  mov   x5, x0               // save a base
  mov   x6, x1               // save b base
  mov   x7, x2               // save len
  mov   x8, #0               // offset = 0

  // ---- find first difference (16-byte NEON compare) ----
.Ldiff_first_loop:
  cmp   x2, #16
  b.lo  .Ldiff_first_tail
  ldp   x9, x10, [x0]
  fmov  d0, x9
  fmov  d2, x10
  ins   v0.d[1], v2.d[0]
  ldp   x9, x10, [x1]
  fmov  d1, x9
  fmov  d2, x10
  ins   v1.d[1], v2.d[0]
  cmeq  v0.16b, v0.16b, v1.16b
  uminv b2, v0.16b
  umov  w9, v2.b[0]
  cmp   w9, #255
  b.ne  .Ldiff_first_in_block
  add   x0, x0, #16
  add   x1, x1, #16
  add   x8, x8, #16
  sub   x2, x2, #16
  cbnz  x2, .Ldiff_first_loop
  b     .Ldiff_false

.Ldiff_first_in_block:
  // Scan 16 lanes for first unequal byte (mask byte != 0xFF)
  mov   w10, #0
.Ldiff_first_scan:
  umov  w9, v0.b[0]
  cmp   w9, #255
  b.ne  .Ldiff_first_found
  ext   v0.16b, v0.16b, v0.16b, #1
  add   w10, w10, #1
  cmp   w10, #16
  b.lo  .Ldiff_first_scan
  // Should not reach; treat as continue
  add   x0, x0, #16
  add   x1, x1, #16
  add   x8, x8, #16
  sub   x2, x2, #16
  cbnz  x2, .Ldiff_first_loop
  b     .Ldiff_false

.Ldiff_first_found:
  add   x8, x8, x10          // first offset
  str   x8, [x3]
  // last defaults to first; refine from end
  str   x8, [x4]
  b     .Ldiff_find_last

.Ldiff_first_tail:
  cbz   x2, .Ldiff_false
.Ldiff_first_tail_loop:
  ldrb  w9, [x0], #1
  ldrb  w10, [x1], #1
  cmp   w9, w10
  b.ne  .Ldiff_first_tail_found
  add   x8, x8, #1
  subs  x2, x2, #1
  b.ne  .Ldiff_first_tail_loop
  b     .Ldiff_false

.Ldiff_first_tail_found:
  str   x8, [x3]
  str   x8, [x4]

  // ---- find last difference: scan backward from end (scalar; one-shot) ----
.Ldiff_find_last:
  // x5=a base, x6=b base, x7=len, first in [x3]
  ldr   x8, [x3]             // firstDiff
  sub   x9, x7, #1           // i = len-1
.Ldiff_last_loop:
  cmp   x9, x8
  b.ls  .Ldiff_true          // i <= first → last already first
  ldrb  w10, [x5, x9]
  ldrb  w11, [x6, x9]
  cmp   w10, w11
  b.ne  .Ldiff_last_found
  sub   x9, x9, #1
  b     .Ldiff_last_loop

.Ldiff_last_found:
  str   x9, [x4]
  b     .Ldiff_true

.Ldiff_nil:
  // one nil (or both nil with different pointers already excluded by equal len==0)
  // if a <> b (pointer inequality): full range
  cmp   x0, x1
  b.eq  .Ldiff_false
  str   xzr, [x3]
  sub   x2, x2, #1
  str   x2, [x4]
  b     .Ldiff_true

.Ldiff_true:
  mov   w0, #1
  ret

.Ldiff_false:
  mov   w0, #0
  ret
end;

// === Phase 22b: NEON Memory Reverse / BytesIndexOf / Utf8Validate ===

procedure MemReverse_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // x0 = p, x1 = len
  cbz   x0, .Lrev_done
  cmp   x1, #1
  b.ls  .Lrev_done

  // x2 = left, x3 = right (last byte)
  mov   x2, x0
  add   x3, x0, x1
  sub   x3, x3, #1

  // ---- 16-byte block reverse from both ends ----
.Lrev_loop16:
  // need left+30 < right  (two non-overlapping 16B windows)
  add   x4, x2, #30
  cmp   x4, x3
  b.hs  .Lrev_loop8
  // load left 16
  ldp   x5, x6, [x2]
  fmov  d0, x5
  fmov  d2, x6
  ins   v0.d[1], v2.d[0]
  // load right-15 16
  sub   x7, x3, #15
  ldp   x5, x6, [x7]
  fmov  d1, x5
  fmov  d2, x6
  ins   v1.d[1], v2.d[0]
  // reverse each 16B vector: rev64 within halves, then swap halves
  rev64 v0.16b, v0.16b
  ext   v0.16b, v0.16b, v0.16b, #8
  rev64 v1.16b, v1.16b
  ext   v1.16b, v1.16b, v1.16b, #8
  // store left-reversed to right window, right-reversed to left
  umov  x5, v0.d[0]
  umov  x6, v0.d[1]
  stp   x5, x6, [x7]
  umov  x5, v1.d[0]
  umov  x6, v1.d[1]
  stp   x5, x6, [x2]
  add   x2, x2, #16
  sub   x3, x3, #16
  b     .Lrev_loop16

  // ---- 8-byte reverse via rev ----
.Lrev_loop8:
  add   x4, x2, #14
  cmp   x4, x3
  b.hs  .Lrev_loop1
  ldr   x5, [x2]
  sub   x7, x3, #7
  ldr   x6, [x7]
  rev   x5, x5
  rev   x6, x6
  str   x6, [x2]
  str   x5, [x7]
  add   x2, x2, #8
  sub   x3, x3, #8
  b     .Lrev_loop8

  // ---- byte tail ----
.Lrev_loop1:
  cmp   x2, x3
  b.hs  .Lrev_done
  ldrb  w5, [x2]
  ldrb  w6, [x3]
  strb  w6, [x2]
  strb  w5, [x3]
  add   x2, x2, #1
  sub   x3, x3, #1
  b     .Lrev_loop1

.Lrev_done:
  ret
end;

function BytesIndexOf_NEON(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; assembler; nostackframe;
asm
  // x0 = haystack, x1 = haystackLen, x2 = needle, x3 = needleLen
  // return: x0 = PtrInt index or -1
  // Match scalar edge semantics.
  cbz   x1, .Lbix_miss
  cbz   x3, .Lbix_miss
  cbz   x0, .Lbix_miss
  cbz   x2, .Lbix_miss
  cmp   x3, x1
  b.hi  .Lbix_miss

  // search window length = haystackLen - needleLen + 1
  sub   x4, x1, x3
  add   x4, x4, #1          // x4 = searchLen
  mov   x5, x0              // x5 = hay base
  mov   x6, #0              // x6 = offset
  ldrb  w7, [x2]            // first needle byte
  dup   v0.16b, w7

  // single-byte needle: pure NEON first-byte search (same shape as MemFindByte)
  cmp   x3, #1
  b.eq  .Lbix_one

.Lbix_loop16:
  cmp   x4, #16
  b.lo  .Lbix_tail
  ldp   x8, x9, [x5, x6]
  fmov  d1, x8
  fmov  d2, x9
  ins   v1.d[1], v2.d[0]
  cmeq  v1.16b, v1.16b, v0.16b
  umaxv b2, v1.16b
  umov  w8, v2.b[0]
  cbnz  w8, .Lbix_scan16
  add   x6, x6, #16
  sub   x4, x4, #16
  cbnz  x4, .Lbix_loop16
  b     .Lbix_miss

.Lbix_scan16:
  mov   w9, #0              // lane
.Lbix_scan_lane:
  umov  w8, v1.b[0]
  cbz   w8, .Lbix_next_lane
  // candidate at offset x6 + w9; verify full needle
  add   x10, x6, x9         // candidate index
  mov   x11, #0             // j
.Lbix_verify:
  cmp   x11, x3
  b.eq  .Lbix_hit
  add   x12, x5, x10
  ldrb  w8, [x12, x11]
  ldrb  w13, [x2, x11]
  cmp   w8, w13
  b.ne  .Lbix_next_lane
  add   x11, x11, #1
  b     .Lbix_verify

.Lbix_next_lane:
  ext   v1.16b, v1.16b, v1.16b, #1
  add   w9, w9, #1
  cmp   w9, #16
  b.lo  .Lbix_scan_lane
  // no verified hit in this block
  add   x6, x6, #16
  sub   x4, x4, #16
  cbnz  x4, .Lbix_loop16
  b     .Lbix_miss

.Lbix_one:
  // reuse searchLen in x4, first byte already in v0
.Lbix_one_loop16:
  cmp   x4, #16
  b.lo  .Lbix_one_tail
  ldp   x8, x9, [x5, x6]
  fmov  d1, x8
  fmov  d2, x9
  ins   v1.d[1], v2.d[0]
  cmeq  v1.16b, v1.16b, v0.16b
  umaxv b2, v1.16b
  umov  w8, v2.b[0]
  cbnz  w8, .Lbix_one_found16
  add   x6, x6, #16
  sub   x4, x4, #16
  cbnz  x4, .Lbix_one_loop16
  b     .Lbix_miss

.Lbix_one_found16:
  mov   w9, #0
.Lbix_one_scan:
  umov  w8, v1.b[0]
  cbnz  w8, .Lbix_one_hit
  ext   v1.16b, v1.16b, v1.16b, #1
  add   w9, w9, #1
  cmp   w9, #16
  b.lo  .Lbix_one_scan
  add   x6, x6, #16
  sub   x4, x4, #16
  cbnz  x4, .Lbix_one_loop16
  b     .Lbix_miss

.Lbix_one_hit:
  add   x0, x6, x9
  ret

.Lbix_one_tail:
  cbz   x4, .Lbix_miss
.Lbix_one_tail_loop:
  ldrb  w8, [x5, x6]
  cmp   w8, w7
  b.eq  .Lbix_hit_idx
  add   x6, x6, #1
  subs  x4, x4, #1
  b.ne  .Lbix_one_tail_loop
  b     .Lbix_miss

.Lbix_tail:
  cbz   x4, .Lbix_miss
.Lbix_tail_loop:
  // scalar first-byte filter then full verify
  ldrb  w8, [x5, x6]
  cmp   w8, w7
  b.ne  .Lbix_tail_next
  mov   x11, #0
.Lbix_tail_verify:
  cmp   x11, x3
  b.eq  .Lbix_hit_idx
  add   x12, x5, x6
  ldrb  w8, [x12, x11]
  ldrb  w13, [x2, x11]
  cmp   w8, w13
  b.ne  .Lbix_tail_next
  add   x11, x11, #1
  b     .Lbix_tail_verify
.Lbix_tail_next:
  add   x6, x6, #1
  subs  x4, x4, #1
  b.ne  .Lbix_tail_loop
  b     .Lbix_miss

.Lbix_hit:
  add   x0, x6, x9
  ret

.Lbix_hit_idx:
  mov   x0, x6
  ret

.Lbix_miss:
  mov   x0, #-1
  ret
end;

function Utf8Validate_NEON(p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // x0 = p, x1 = len
  // Return: w0 = Boolean
  // NEON ASCII fast path + scalar-parity multi-byte checks.
  cbz   x1, .Lutf8_true
  cbz   x0, .Lutf8_false

  mov   x2, x0              // base
  mov   x3, x1              // remaining
  mov   x4, #0              // offset

  // ---- 16-byte ASCII scan ----
.Lutf8_ascii16:
  cmp   x3, #16
  b.lo  .Lutf8_scalar
  ldp   x5, x6, [x2, x4]
  fmov  d0, x5
  fmov  d2, x6
  ins   v0.d[1], v2.d[0]
  // any high bit? max byte >= 0x80
  umaxv b1, v0.16b
  umov  w5, v1.b[0]
  tbnz  w5, #7, .Lutf8_scalar
  add   x4, x4, #16
  sub   x3, x3, #16
  cbnz  x3, .Lutf8_ascii16
  b     .Lutf8_true

  // ---- scalar-parity validation from offset x4 ----
.Lutf8_scalar:
  // x2=base, x1=original len, x4=i
.Lutf8_loop:
  cmp   x4, x1
  b.hs  .Lutf8_true
  ldrb  w5, [x2, x4]        // b
  // ASCII?
  tbz   w5, #7, .Lutf8_ascii1

  // 2-byte: C2..DF
  cmp   w5, #0xC2
  b.lo  .Lutf8_false
  cmp   w5, #0xDF
  b.ls  .Lutf8_seq2
  // 3-byte: E0..EF  (top nibble E)
  and   w6, w5, #0xF0
  cmp   w6, #0xE0
  b.eq  .Lutf8_seq3
  // 4-byte: F0..F4
  cmp   w5, #0xF0
  b.lo  .Lutf8_false
  cmp   w5, #0xF4
  b.hi  .Lutf8_false
  b     .Lutf8_seq4

.Lutf8_ascii1:
  add   x4, x4, #1
  b     .Lutf8_loop

.Lutf8_seq2:
  // need 1 continuation
  add   x6, x4, #1
  cmp   x6, x1
  b.hs  .Lutf8_false
  ldrb  w7, [x2, x6]
  and   w8, w7, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  add   x4, x4, #2
  b     .Lutf8_loop

.Lutf8_seq3:
  // need 2 continuations + overlong/surrogate checks
  add   x6, x4, #2
  cmp   x6, x1
  b.hs  .Lutf8_false
  add   x6, x4, #1
  ldrb  w7, [x2, x6]        // b2
  and   w8, w7, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  add   x6, x4, #2
  ldrb  w9, [x2, x6]        // b3
  and   w8, w9, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  // (b==E0 && b2<A0) invalid overlong
  cmp   w5, #0xE0
  b.ne  .Lutf8_seq3_sur
  cmp   w7, #0xA0
  b.lo  .Lutf8_false
.Lutf8_seq3_sur:
  // (b==ED && b2>=A0) invalid surrogate
  cmp   w5, #0xED
  b.ne  .Lutf8_seq3_ok
  cmp   w7, #0xA0
  b.hs  .Lutf8_false
.Lutf8_seq3_ok:
  add   x4, x4, #3
  b     .Lutf8_loop

.Lutf8_seq4:
  // need 3 continuations + range checks
  add   x6, x4, #3
  cmp   x6, x1
  b.hs  .Lutf8_false
  add   x6, x4, #1
  ldrb  w7, [x2, x6]        // b2
  and   w8, w7, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  add   x6, x4, #2
  ldrb  w9, [x2, x6]
  and   w8, w9, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  add   x6, x4, #3
  ldrb  w9, [x2, x6]
  and   w8, w9, #0xC0
  cmp   w8, #0x80
  b.ne  .Lutf8_false
  // (b==F0 && b2<90) overlong
  cmp   w5, #0xF0
  b.ne  .Lutf8_seq4_max
  cmp   w7, #0x90
  b.lo  .Lutf8_false
.Lutf8_seq4_max:
  // (b==F4 && b2>=90) too large
  cmp   w5, #0xF4
  b.ne  .Lutf8_seq4_ok
  cmp   w7, #0x90
  b.hs  .Lutf8_false
.Lutf8_seq4_ok:
  add   x4, x4, #4
  b     .Lutf8_loop

.Lutf8_true:
  mov   w0, #1
  ret

.Lutf8_false:
  mov   w0, #0
  ret
end;

// === Phase 23a: NEON BatchF32 ArrayAdd / ArraySub / ArrayMul ===
// ABI (AAPCS64): x0=aSrc1, x1=aSrc2, x2=aDst, x3=aCount
// ICE-safe: ldp/fmov/ins + fadd/fsub/fmul vN.4s + umov/stp; scalar s-reg tail.

procedure NEONArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larradd_done

.Larradd_loop4:
  cmp   x3, #4
  b.lo  .Larradd_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fadd  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larradd_loop4

.Larradd_tail:
  cbz   x3, .Larradd_done
.Larradd_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fadd  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larradd_tail_loop

.Larradd_done:
  ret
end;

procedure NEONArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrsub_done

.Larrsub_loop4:
  cmp   x3, #4
  b.lo  .Larrsub_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fsub  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrsub_loop4

.Larrsub_tail:
  cbz   x3, .Larrsub_done
.Larrsub_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fsub  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrsub_tail_loop

.Larrsub_done:
  ret
end;

procedure NEONArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrmul_done

.Larrmul_loop4:
  cmp   x3, #4
  b.lo  .Larrmul_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmul  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrmul_loop4

.Larrmul_tail:
  cbz   x3, .Larrmul_done
.Larrmul_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fmul  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrmul_tail_loop

.Larrmul_done:
  ret
end;

// === Batch B1: NEON BatchF32 ArrayDiv ===
// ABI (AAPCS64): x0=aSrc1, x1=aSrc2, x2=aDst, x3=aCount
// ICE-safe: same load/store pattern as Mul; fdiv vN.4s + scalar s-reg tail.

procedure NEONArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrdiv_done

.Larrdiv_loop4:
  cmp   x3, #4
  b.lo  .Larrdiv_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fdiv  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrdiv_loop4

.Larrdiv_tail:
  cbz   x3, .Larrdiv_done
.Larrdiv_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fdiv  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrdiv_tail_loop

.Larrdiv_done:
  ret
end;

// === Phase 23b: NEON BatchF32 ArrayMin / ArrayMax / ArrayAbs / ArrayNeg ===
// Min/Max ABI: x0=aSrc1, x1=aSrc2, x2=aDst, x3=aCount
// Abs/Neg ABI: x0=aSrc, x1=aDst, x2=aCount
// ICE-safe: ldp/fmov/ins + fmin/fmax/fabs/fneg + umov/stp; scalar s-reg tail.

procedure NEONArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrmin_done

.Larrmin_loop4:
  cmp   x3, #4
  b.lo  .Larrmin_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmin  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrmin_loop4

.Larrmin_tail:
  cbz   x3, .Larrmin_done
.Larrmin_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fmin  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrmin_tail_loop

.Larrmin_done:
  ret
end;

procedure NEONArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrmax_done

.Larrmax_loop4:
  cmp   x3, #4
  b.lo  .Larrmax_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d2, x5
  ins   v0.d[1], v2.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmax  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrmax_loop4

.Larrmax_tail:
  cbz   x3, .Larrmax_done
.Larrmax_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fmax  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrmax_tail_loop

.Larrmax_done:
  ret
end;

procedure NEONArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrabs_done

.Larrabs_loop4:
  cmp   x2, #4
  b.lo  .Larrabs_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fabs  v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrabs_loop4

.Larrabs_tail:
  cbz   x2, .Larrabs_done
.Larrabs_tail_loop:
  ldr   s0, [x0], #4
  fabs  s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrabs_tail_loop

.Larrabs_done:
  ret
end;

procedure NEONArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrneg_done

.Larrneg_loop4:
  cmp   x2, #4
  b.lo  .Larrneg_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fneg  v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrneg_loop4

.Larrneg_tail:
  cbz   x2, .Larrneg_done
.Larrneg_tail_loop:
  ldr   s0, [x0], #4
  fneg  s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrneg_tail_loop

.Larrneg_done:
  ret
end;

// === Batch B2: NEON BatchF32 ArrayMulScalar / ArrayAddScalar ===
// ABI (AAPCS64): x0=aSrc, x1=aDst, x2=aCount, s0=aScalar
// Broadcast scalar into v3.4s; ICE-safe load/store like Abs/Neg.

procedure NEONArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); assembler; nostackframe;
asm
  cbz   x2, .Larrmuls_done
  // aScalar in s0 → broadcast to v3.4s
  dup   v3.4s, v0.s[0]

.Larrmuls_loop4:
  cmp   x2, #4
  b.lo  .Larrmuls_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmul  v0.4s, v0.4s, v3.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrmuls_loop4

.Larrmuls_tail:
  cbz   x2, .Larrmuls_done
.Larrmuls_tail_loop:
  ldr   s0, [x0], #4
  fmul  s0, s0, s3
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrmuls_tail_loop

.Larrmuls_done:
  ret
end;

procedure NEONArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); assembler; nostackframe;
asm
  cbz   x2, .Larradds_done
  dup   v3.4s, v0.s[0]

.Larradds_loop4:
  cmp   x2, #4
  b.lo  .Larradds_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fadd  v0.4s, v0.4s, v3.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larradds_loop4

.Larradds_tail:
  cbz   x2, .Larradds_done
.Larradds_tail_loop:
  ldr   s0, [x0], #4
  fadd  s0, s0, s3
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larradds_tail_loop

.Larradds_done:
  ret
end;

// === Batch B3: NEON BatchF32 ArrayClamp / ArrayLerp ===
// Clamp ABI: x0=aSrc, x1=aDst, x2=aCount, s0=aMin, s1=aMax
// Lerp ABI:  x0=aStart, x1=aEnd, x2=aDst, x3=aCount, s0=aT
// Clamp scalar semantics: if v<aMin then aMin else if v>aMax then aMax
// Lerp scalar semantics: start + t*(end-start)

procedure NEONArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); assembler; nostackframe;
asm
  cbz   x2, .Larrclp_done
  dup   v2.4s, v0.s[0]   // min
  dup   v3.4s, v1.s[0]   // max

.Larrclp_loop4:
  cmp   x2, #4
  b.lo  .Larrclp_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmax  v0.4s, v0.4s, v2.4s
  fmin  v0.4s, v0.4s, v3.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrclp_loop4

.Larrclp_tail:
  cbz   x2, .Larrclp_done
.Larrclp_tail_loop:
  ldr   s0, [x0], #4
  fmax  s0, s0, s2
  fmin  s0, s0, s3
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrclp_tail_loop

.Larrclp_done:
  ret
end;

procedure NEONArrayLerpF32(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single); assembler; nostackframe;
asm
  cbz   x3, .Larrlerp_done
  dup   v4.4s, v0.s[0]   // t broadcast

.Larrlerp_loop4:
  cmp   x3, #4
  b.lo  .Larrlerp_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]   // start
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]   // end
  fsub  v2.4s, v1.4s, v0.4s
  fmul  v2.4s, v2.4s, v4.4s
  fadd  v0.4s, v0.4s, v2.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrlerp_loop4

.Larrlerp_tail:
  cbz   x3, .Larrlerp_done
.Larrlerp_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fsub  s1, s1, s0
  fmul  s1, s1, s4
  fadd  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrlerp_tail_loop

.Larrlerp_done:
  ret
end;

// === Batch B4: NEON BatchF32 ArrayFma / ArrayAxpy ===
// Fma:  x0=aA, x1=aB, x2=aC, x3=aDst, x4=aCount; dst = a*b+c (mul+add, not fmla)
// Axpy: s0=aAlpha, x0=aX, x1=aY, x2=aDst, x3=aCount; dst = alpha*x + y

procedure NEONArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x4, .Larrfma_done

.Larrfma_loop4:
  cmp   x4, #4
  b.lo  .Larrfma_tail
  ldp   x5, x6, [x0], #16
  fmov  d0, x5
  fmov  d1, x6
  ins   v0.d[1], v1.d[0]   // a
  ldp   x5, x6, [x1], #16
  fmov  d1, x5
  fmov  d2, x6
  ins   v1.d[1], v2.d[0]   // b
  ldp   x5, x6, [x2], #16
  fmov  d2, x5
  fmov  d3, x6
  ins   v2.d[1], v3.d[0]   // c
  fmul  v0.4s, v0.4s, v1.4s
  fadd  v0.4s, v0.4s, v2.4s
  umov  x5, v0.d[0]
  umov  x6, v0.d[1]
  stp   x5, x6, [x3], #16
  sub   x4, x4, #4
  b     .Larrfma_loop4

.Larrfma_tail:
  cbz   x4, .Larrfma_done
.Larrfma_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  ldr   s2, [x2], #4
  fmul  s0, s0, s1
  fadd  s0, s0, s2
  str   s0, [x3], #4
  subs  x4, x4, #1
  b.ne  .Larrfma_tail_loop

.Larrfma_done:
  ret
end;

procedure NEONArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larraxpy_done
  dup   v3.4s, v0.s[0]   // alpha

.Larraxpy_loop4:
  cmp   x3, #4
  b.lo  .Larraxpy_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]   // x
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]   // y
  fmul  v0.4s, v0.4s, v3.4s
  fadd  v0.4s, v0.4s, v1.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larraxpy_loop4

.Larraxpy_tail:
  cbz   x3, .Larraxpy_done
.Larraxpy_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fmul  s0, s0, s3
  fadd  s0, s0, s1
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larraxpy_tail_loop

.Larraxpy_done:
  ret
end;

// === Batch B5: NEON BatchF32 ArraySqrt / ReduceSum ===
// Sqrt ABI: x0=aSrc, x1=aDst, x2=aCount
// ReduceSum ABI: x0=aSrc, x1=aCount; result in s0
// ReduceSum may reorder adds vs scalar left-fold (float assoc); tests use near for large N.

procedure NEONArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrsqrt_done

.Larrsqrt_loop4:
  cmp   x2, #4
  b.lo  .Larrsqrt_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fsqrt v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrsqrt_loop4

.Larrsqrt_tail:
  cbz   x2, .Larrsqrt_done
.Larrsqrt_tail_loop:
  ldr   s0, [x0], #4
  fsqrt s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrsqrt_tail_loop

.Larrsqrt_done:
  ret
end;

function NEONReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;
asm
  movi  v1.4s, #0
  cbz   x1, .Lredsum_hadd

.Lredsum_loop4:
  cmp   x1, #4
  b.lo  .Lredsum_hadd
  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]
  fadd  v1.4s, v1.4s, v0.4s
  sub   x1, x1, #4
  b     .Lredsum_loop4

.Lredsum_hadd:
  faddp v2.4s, v1.4s, v1.4s
  faddp s0, v2.2s
  cbz   x1, .Lredsum_done

.Lredsum_tail:
  ldr   s1, [x0], #4
  fadd  s0, s0, s1
  subs  x1, x1, #1
  b.ne  .Lredsum_tail

.Lredsum_done:
  ret
end;

// === Batch B6: NEON BatchF32 ReduceMin / ReduceMax ===
// ABI: x0=aSrc, x1=aCount; result in s0. count=0 → 0.0 (scalar contract).

function NEONReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;
asm
  cbz   x1, .Lredmin_zero
  cmp   x1, #4
  b.lo  .Lredmin_scalar_init

  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]
  sub   x1, x1, #4

.Lredmin_loop4:
  cmp   x1, #4
  b.lo  .Lredmin_hmin
  ldp   x2, x3, [x0], #16
  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]
  fmin  v0.4s, v0.4s, v1.4s
  sub   x1, x1, #4
  b     .Lredmin_loop4

.Lredmin_hmin:
  fminp v1.4s, v0.4s, v0.4s
  fminp s0, v1.2s
  cbz   x1, .Lredmin_done

.Lredmin_tail:
  ldr   s1, [x0], #4
  fmin  s0, s0, s1
  subs  x1, x1, #1
  b.ne  .Lredmin_tail
  b     .Lredmin_done

.Lredmin_scalar_init:
  ldr   s0, [x0], #4
  subs  x1, x1, #1
  b.eq  .Lredmin_done
.Lredmin_scalar_loop:
  ldr   s1, [x0], #4
  fmin  s0, s0, s1
  subs  x1, x1, #1
  b.ne  .Lredmin_scalar_loop
  b     .Lredmin_done

.Lredmin_zero:
  fmov  s0, wzr

.Lredmin_done:
  ret
end;

function NEONReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;
asm
  cbz   x1, .Lredmax_zero
  cmp   x1, #4
  b.lo  .Lredmax_scalar_init

  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]
  sub   x1, x1, #4

.Lredmax_loop4:
  cmp   x1, #4
  b.lo  .Lredmax_hmax
  ldp   x2, x3, [x0], #16
  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]
  fmax  v0.4s, v0.4s, v1.4s
  sub   x1, x1, #4
  b     .Lredmax_loop4

.Lredmax_hmax:
  fmaxp v1.4s, v0.4s, v0.4s
  fmaxp s0, v1.2s
  cbz   x1, .Lredmax_done

.Lredmax_tail:
  ldr   s1, [x0], #4
  fmax  s0, s0, s1
  subs  x1, x1, #1
  b.ne  .Lredmax_tail
  b     .Lredmax_done

.Lredmax_scalar_init:
  ldr   s0, [x0], #4
  subs  x1, x1, #1
  b.eq  .Lredmax_done
.Lredmax_scalar_loop:
  ldr   s1, [x0], #4
  fmax  s0, s0, s1
  subs  x1, x1, #1
  b.ne  .Lredmax_scalar_loop
  b     .Lredmax_done

.Lredmax_zero:
  fmov  s0, wzr

.Lredmax_done:
  ret
end;

// === Batch B7: NEON BatchF32 ArrayRcp / ReduceDot ===
// Rcp: x0=aSrc, x1=aDst, x2=aCount; dst = 1.0/src via fdiv (not frecpe)
// ReduceDot: x0=aSrc1, x1=aSrc2, x2=aCount; result s0; may near-parity vs scalar

procedure NEONArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrrcp_done
  // 1.0f broadcast → v3
  mov   w3, #0x3f800000
  fmov  s3, w3
  dup   v3.4s, v3.s[0]

.Larrrcp_loop4:
  cmp   x2, #4
  b.lo  .Larrrcp_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fdiv  v0.4s, v3.4s, v0.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #4
  b     .Larrrcp_loop4

.Larrrcp_tail:
  cbz   x2, .Larrrcp_done
.Larrrcp_tail_loop:
  ldr   s0, [x0], #4
  fdiv  s0, s3, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrrcp_tail_loop

.Larrrcp_done:
  ret
end;

function NEONReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;
asm
  movi  v2.4s, #0
  cbz   x2, .Lreddot_hadd

.Lreddot_loop4:
  cmp   x2, #4
  b.lo  .Lreddot_hadd
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  ldp   x3, x4, [x1], #16
  fmov  d1, x3
  fmov  d3, x4
  ins   v1.d[1], v3.d[0]
  fmul  v0.4s, v0.4s, v1.4s
  fadd  v2.4s, v2.4s, v0.4s
  sub   x2, x2, #4
  b     .Lreddot_loop4

.Lreddot_hadd:
  faddp v0.4s, v2.4s, v2.4s
  faddp s0, v0.2s
  cbz   x2, .Lreddot_done

.Lreddot_tail:
  ldr   s1, [x0], #4
  ldr   s2, [x1], #4
  fmul  s1, s1, s2
  fadd  s0, s0, s1
  subs  x2, x2, #1
  b.ne  .Lreddot_tail

.Lreddot_done:
  ret
end;

// === Batch B8: NEON BatchF32 ArrayRsqrt / ArrayRcpRefine ===
// ABI: x0=aSrc, x1=aDst, x2=aCount
// Rsqrt: 1/sqrt via fsqrt+fdiv (not frsqrte); RcpRefine: 1/x via fdiv (scalar match)

procedure NEONArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrrsqrt_done
  mov   w3, #0x3f800000
  fmov  s3, w3
  dup   v3.4s, v3.s[0]

.Larrrsqrt_loop4:
  cmp   x2, #4
  b.lo  .Larrrsqrt_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fsqrt v0.4s, v0.4s
  fdiv  v0.4s, v3.4s, v0.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #4
  b     .Larrrsqrt_loop4

.Larrrsqrt_tail:
  cbz   x2, .Larrrsqrt_done
.Larrrsqrt_tail_loop:
  ldr   s0, [x0], #4
  fsqrt s0, s0
  fdiv  s0, s3, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrrsqrt_tail_loop

.Larrrsqrt_done:
  ret
end;

procedure NEONArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrrcpr_done
  mov   w3, #0x3f800000
  fmov  s3, w3
  dup   v3.4s, v3.s[0]

.Larrrcpr_loop4:
  cmp   x2, #4
  b.lo  .Larrrcpr_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fdiv  v0.4s, v3.4s, v0.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #4
  b     .Larrrcpr_loop4

.Larrrcpr_tail:
  cbz   x2, .Larrrcpr_done
.Larrrcpr_tail_loop:
  ldr   s0, [x0], #4
  fdiv  s0, s3, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrrcpr_tail_loop

.Larrrcpr_done:
  ret
end;

// === Batch B9: NEON BatchF32 ArrayRsqrtRefine ===
// Same exact formula as Rsqrt: 1/sqrt via fsqrt+fdiv (scalar match; not frsqrte)

procedure NEONArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrrsqrtr_done
  mov   w3, #0x3f800000
  fmov  s3, w3
  dup   v3.4s, v3.s[0]

.Larrrsqrtr_loop4:
  cmp   x2, #4
  b.lo  .Larrrsqrtr_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fsqrt v0.4s, v0.4s
  fdiv  v0.4s, v3.4s, v0.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #4
  b     .Larrrsqrtr_loop4

.Larrrsqrtr_tail:
  cbz   x2, .Larrrsqrtr_done
.Larrrsqrtr_tail_loop:
  ldr   s0, [x0], #4
  fsqrt s0, s0
  fdiv  s0, s3, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrrsqrtr_tail_loop

.Larrrsqrtr_done:
  ret
end;

// === Wave C1: NEON BatchF32 ArrayLinear ===
// ABI: x0=aSrc, x1=aDst, x2=aCount, s0=aScale, s1=aBias
// dst = src * scale + bias

procedure NEONArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); assembler; nostackframe;
asm
  cbz   x2, .Larrlin_done
  dup   v2.4s, v0.s[0]   // scale
  dup   v3.4s, v1.s[0]   // bias

.Larrlin_loop4:
  cmp   x2, #4
  b.lo  .Larrlin_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmul  v0.4s, v0.4s, v2.4s
  fadd  v0.4s, v0.4s, v3.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrlin_loop4

.Larrlin_tail:
  cbz   x2, .Larrlin_done
.Larrlin_tail_loop:
  ldr   s0, [x0], #4
  fmul  s0, s0, s2
  fadd  s0, s0, s3
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrlin_tail_loop

.Larrlin_done:
  ret
end;

// === Wave C2: NEON BatchF32 ArrayCeil / Floor / Trunc ===
// ABI: x0=aSrc, x1=aDst, x2=aCount
// frintp = ceil (+inf), frintm = floor (-inf), frintz = trunc (toward 0)

procedure NEONArrayCeilF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrceil_done

.Larrceil_loop4:
  cmp   x2, #4
  b.lo  .Larrceil_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintp v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrceil_loop4

.Larrceil_tail:
  cbz   x2, .Larrceil_done
.Larrceil_tail_loop:
  ldr   s0, [x0], #4
  frintp s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrceil_tail_loop

.Larrceil_done:
  ret
end;

procedure NEONArrayFloorF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrfloor_done

.Larrfloor_loop4:
  cmp   x2, #4
  b.lo  .Larrfloor_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintm v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrfloor_loop4

.Larrfloor_tail:
  cbz   x2, .Larrfloor_done
.Larrfloor_tail_loop:
  ldr   s0, [x0], #4
  frintm s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrfloor_tail_loop

.Larrfloor_done:
  ret
end;

procedure NEONArrayTruncF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrtrunc_done

.Larrtrunc_loop4:
  cmp   x2, #4
  b.lo  .Larrtrunc_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintz v0.4s, v0.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrtrunc_loop4

.Larrtrunc_tail:
  cbz   x2, .Larrtrunc_done
.Larrtrunc_tail_loop:
  ldr   s0, [x0], #4
  frintz s0, s0
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrtrunc_tail_loop

.Larrtrunc_done:
  ret
end;

// === Wave C3: NEON BatchF32 ArrayReLU / ArrayAbsDiff ===
// ReLU ABI: x0=aSrc, x1=aDst, x2=aCount; max(x, 0)
// AbsDiff ABI: x0=aSrc1, x1=aSrc2, x2=aDst, x3=aCount; abs(a-b)

procedure NEONArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Larrrelu_done
  movi  v1.4s, #0

.Larrrelu_loop4:
  cmp   x2, #4
  b.lo  .Larrrelu_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d2, x4
  ins   v0.d[1], v2.d[0]
  fmax  v0.4s, v0.4s, v1.4s
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Larrrelu_loop4

.Larrrelu_tail:
  cbz   x2, .Larrrelu_done
.Larrrelu_tail_loop:
  ldr   s0, [x0], #4
  fmax  s0, s0, s1
  str   s0, [x1], #4
  subs  x2, x2, #1
  b.ne  .Larrrelu_tail_loop

.Larrrelu_done:
  ret
end;

procedure NEONArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Larrabsd_done

.Larrabsd_loop4:
  cmp   x3, #4
  b.lo  .Larrabsd_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fsub  v0.4s, v0.4s, v1.4s
  fabs  v0.4s, v0.4s
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #4
  b     .Larrabsd_loop4

.Larrabsd_tail:
  cbz   x3, .Larrabsd_done
.Larrabsd_tail_loop:
  ldr   s0, [x0], #4
  ldr   s1, [x1], #4
  fsub  s0, s0, s1
  fabs  s0, s0
  str   s0, [x2], #4
  subs  x3, x3, #1
  b.ne  .Larrabsd_tail_loop

.Larrabsd_done:
  ret
end;

// === Wave C4a: NEON BatchF64 core 8 (2×f64 per vector) ===
// Binary ABI: x0=aSrc1, x1=aSrc2, x2=aDst, x3=aCount
// Unary ABI:  x0=aSrc, x1=aDst, x2=aCount
// ICE-safe: ldp/fmov/ins + f* vN.2d + umov/stp; scalar d-reg tail.

procedure NEONArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Laddf64_done
.Laddf64_loop2:
  cmp   x3, #2
  b.lo  .Laddf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fadd  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Laddf64_loop2
.Laddf64_tail:
  cbz   x3, .Laddf64_done
.Laddf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fadd  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Laddf64_tail_loop
.Laddf64_done:
  ret
end;

procedure NEONArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Lsubf64_done
.Lsubf64_loop2:
  cmp   x3, #2
  b.lo  .Lsubf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fsub  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Lsubf64_loop2
.Lsubf64_tail:
  cbz   x3, .Lsubf64_done
.Lsubf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fsub  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Lsubf64_tail_loop
.Lsubf64_done:
  ret
end;

procedure NEONArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Lmulf64_done
.Lmulf64_loop2:
  cmp   x3, #2
  b.lo  .Lmulf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmul  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Lmulf64_loop2
.Lmulf64_tail:
  cbz   x3, .Lmulf64_done
.Lmulf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fmul  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Lmulf64_tail_loop
.Lmulf64_done:
  ret
end;

procedure NEONArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Ldivf64_done
.Ldivf64_loop2:
  cmp   x3, #2
  b.lo  .Ldivf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fdiv  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Ldivf64_loop2
.Ldivf64_tail:
  cbz   x3, .Ldivf64_done
.Ldivf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fdiv  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Ldivf64_tail_loop
.Ldivf64_done:
  ret
end;

procedure NEONArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Lminf64_done
.Lminf64_loop2:
  cmp   x3, #2
  b.lo  .Lminf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmin  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Lminf64_loop2
.Lminf64_tail:
  cbz   x3, .Lminf64_done
.Lminf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fmin  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Lminf64_tail_loop
.Lminf64_done:
  ret
end;

procedure NEONArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Lmaxf64_done
.Lmaxf64_loop2:
  cmp   x3, #2
  b.lo  .Lmaxf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmax  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Lmaxf64_loop2
.Lmaxf64_tail:
  cbz   x3, .Lmaxf64_done
.Lmaxf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fmax  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Lmaxf64_tail_loop
.Lmaxf64_done:
  ret
end;

procedure NEONArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Labsf64_done
.Labsf64_loop2:
  cmp   x2, #2
  b.lo  .Labsf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fabs  v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Labsf64_loop2
.Labsf64_tail:
  cbz   x2, .Labsf64_done
.Labsf64_tail_loop:
  ldr   d0, [x0], #8
  fabs  d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Labsf64_tail_loop
.Labsf64_done:
  ret
end;

procedure NEONArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lnegf64_done
.Lnegf64_loop2:
  cmp   x2, #2
  b.lo  .Lnegf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fneg  v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lnegf64_loop2
.Lnegf64_tail:
  cbz   x2, .Lnegf64_done
.Lnegf64_tail_loop:
  ldr   d0, [x0], #8
  fneg  d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lnegf64_tail_loop
.Lnegf64_done:
  ret
end;

// === Wave C4b: NEON BatchF64 Sqrt / MulScalar / AddScalar / Reduce* ===
// Sqrt unary ABI: x0=aSrc, x1=aDst, x2=aCount
// Broadcast ABI:  x0=aSrc, x1=aDst, x2=aCount, d0=aScalar
// Reduce ABI:     x0=aSrc, x1=aCount; result d0  (Dot: x0,x1 srcs, x2=count)
// ICE-safe 2×f64; ReduceSum/Dot may near-parity vs scalar left-fold (assoc).

procedure NEONArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lsqrtf64_done
.Lsqrtf64_loop2:
  cmp   x2, #2
  b.lo  .Lsqrtf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fsqrt v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lsqrtf64_loop2
.Lsqrtf64_tail:
  cbz   x2, .Lsqrtf64_done
.Lsqrtf64_tail_loop:
  ldr   d0, [x0], #8
  fsqrt d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lsqrtf64_tail_loop
.Lsqrtf64_done:
  ret
end;

procedure NEONArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); assembler; nostackframe;
asm
  cbz   x2, .Lmulsf64_done
  dup   v3.2d, v0.d[0]
.Lmulsf64_loop2:
  cmp   x2, #2
  b.lo  .Lmulsf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmul  v0.2d, v0.2d, v3.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lmulsf64_loop2
.Lmulsf64_tail:
  cbz   x2, .Lmulsf64_done
.Lmulsf64_tail_loop:
  ldr   d0, [x0], #8
  fmul  d0, d0, d3
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lmulsf64_tail_loop
.Lmulsf64_done:
  ret
end;

procedure NEONArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); assembler; nostackframe;
asm
  cbz   x2, .Laddsf64_done
  dup   v3.2d, v0.d[0]
.Laddsf64_loop2:
  cmp   x2, #2
  b.lo  .Laddsf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fadd  v0.2d, v0.2d, v3.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Laddsf64_loop2
.Laddsf64_tail:
  cbz   x2, .Laddsf64_done
.Laddsf64_tail_loop:
  ldr   d0, [x0], #8
  fadd  d0, d0, d3
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Laddsf64_tail_loop
.Laddsf64_done:
  ret
end;

function NEONReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;
asm
  movi  v1.2d, #0
  cbz   x1, .Lredsumf64_hadd
.Lredsumf64_loop2:
  cmp   x1, #2
  b.lo  .Lredsumf64_hadd
  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]
  fadd  v1.2d, v1.2d, v0.2d
  sub   x1, x1, #2
  b     .Lredsumf64_loop2
.Lredsumf64_hadd:
  faddp d0, v1.2d
  cbz   x1, .Lredsumf64_done
.Lredsumf64_tail:
  ldr   d1, [x0], #8
  fadd  d0, d0, d1
  subs  x1, x1, #1
  b.ne  .Lredsumf64_tail
.Lredsumf64_done:
  ret
end;

function NEONReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;
asm
  movi  v2.2d, #0
  cbz   x2, .Lreddotf64_hadd
.Lreddotf64_loop2:
  cmp   x2, #2
  b.lo  .Lreddotf64_hadd
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  ldp   x3, x4, [x1], #16
  fmov  d1, x3
  fmov  d3, x4
  ins   v1.d[1], v3.d[0]
  fmul  v0.2d, v0.2d, v1.2d
  fadd  v2.2d, v2.2d, v0.2d
  sub   x2, x2, #2
  b     .Lreddotf64_loop2
.Lreddotf64_hadd:
  faddp d0, v2.2d
  cbz   x2, .Lreddotf64_done
.Lreddotf64_tail:
  ldr   d1, [x0], #8
  ldr   d2, [x1], #8
  fmul  d1, d1, d2
  fadd  d0, d0, d1
  subs  x2, x2, #1
  b.ne  .Lreddotf64_tail
.Lreddotf64_done:
  ret
end;

function NEONReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;
asm
  cbz   x1, .Lredminf64_zero
  cmp   x1, #2
  b.lo  .Lredminf64_scalar_init
  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]
  sub   x1, x1, #2
.Lredminf64_loop2:
  cmp   x1, #2
  b.lo  .Lredminf64_hmin
  ldp   x2, x3, [x0], #16
  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]
  fmin  v0.2d, v0.2d, v1.2d
  sub   x1, x1, #2
  b     .Lredminf64_loop2
.Lredminf64_hmin:
  fminp d0, v0.2d
  cbz   x1, .Lredminf64_done
.Lredminf64_tail:
  ldr   d1, [x0], #8
  fmin  d0, d0, d1
  subs  x1, x1, #1
  b.ne  .Lredminf64_tail
  b     .Lredminf64_done
.Lredminf64_scalar_init:
  ldr   d0, [x0], #8
  subs  x1, x1, #1
  b.eq  .Lredminf64_done
.Lredminf64_scalar_loop:
  ldr   d1, [x0], #8
  fmin  d0, d0, d1
  subs  x1, x1, #1
  b.ne  .Lredminf64_scalar_loop
  b     .Lredminf64_done
.Lredminf64_zero:
  fmov  d0, xzr
.Lredminf64_done:
  ret
end;

function NEONReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;
asm
  cbz   x1, .Lredmaxf64_zero
  cmp   x1, #2
  b.lo  .Lredmaxf64_scalar_init
  ldp   x2, x3, [x0], #16
  fmov  d0, x2
  fmov  d1, x3
  ins   v0.d[1], v1.d[0]
  sub   x1, x1, #2
.Lredmaxf64_loop2:
  cmp   x1, #2
  b.lo  .Lredmaxf64_hmax
  ldp   x2, x3, [x0], #16
  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]
  fmax  v0.2d, v0.2d, v1.2d
  sub   x1, x1, #2
  b     .Lredmaxf64_loop2
.Lredmaxf64_hmax:
  fmaxp d0, v0.2d
  cbz   x1, .Lredmaxf64_done
.Lredmaxf64_tail:
  ldr   d1, [x0], #8
  fmax  d0, d0, d1
  subs  x1, x1, #1
  b.ne  .Lredmaxf64_tail
  b     .Lredmaxf64_done
.Lredmaxf64_scalar_init:
  ldr   d0, [x0], #8
  subs  x1, x1, #1
  b.eq  .Lredmaxf64_done
.Lredmaxf64_scalar_loop:
  ldr   d1, [x0], #8
  fmax  d0, d0, d1
  subs  x1, x1, #1
  b.ne  .Lredmaxf64_scalar_loop
  b     .Lredmaxf64_done
.Lredmaxf64_zero:
  fmov  d0, xzr
.Lredmaxf64_done:
  ret
end;

// === Wave C4c: NEON BatchF64 Linear / Clamp / Lerp / Fma / Axpy ===
// Linear: x0=src, x1=dst, x2=count, d0=scale, d1=bias
// Clamp:  x0=src, x1=dst, x2=count, d0=min, d1=max
// Lerp:   x0=start, x1=end, x2=dst, x3=count, d0=t
// Fma:    x0=a, x1=b, x2=c, x3=dst, x4=count; dst=a*b+c (mul+add, not fmla)
// Axpy:   d0=alpha, x0=x, x1=y, x2=dst, x3=count
// ICE-safe 2×f64.

procedure NEONArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); assembler; nostackframe;
asm
  cbz   x2, .Llinf64_done
  dup   v2.2d, v0.d[0]
  dup   v3.2d, v1.d[0]
.Llinf64_loop2:
  cmp   x2, #2
  b.lo  .Llinf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmul  v0.2d, v0.2d, v2.2d
  fadd  v0.2d, v0.2d, v3.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Llinf64_loop2
.Llinf64_tail:
  cbz   x2, .Llinf64_done
.Llinf64_tail_loop:
  ldr   d0, [x0], #8
  fmul  d0, d0, d2
  fadd  d0, d0, d3
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Llinf64_tail_loop
.Llinf64_done:
  ret
end;

procedure NEONArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); assembler; nostackframe;
asm
  cbz   x2, .Lclampf64_done
  dup   v2.2d, v0.d[0]
  dup   v3.2d, v1.d[0]
.Lclampf64_loop2:
  cmp   x2, #2
  b.lo  .Lclampf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmax  v0.2d, v0.2d, v2.2d
  fmin  v0.2d, v0.2d, v3.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lclampf64_loop2
.Lclampf64_tail:
  cbz   x2, .Lclampf64_done
.Lclampf64_tail_loop:
  ldr   d0, [x0], #8
  fmax  d0, d0, d2
  fmin  d0, d0, d3
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lclampf64_tail_loop
.Lclampf64_done:
  ret
end;

procedure NEONArrayLerpF64(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double); assembler; nostackframe;
asm
  cbz   x3, .Llerpf64_done
  dup   v4.2d, v0.d[0]
.Llerpf64_loop2:
  cmp   x3, #2
  b.lo  .Llerpf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fsub  v2.2d, v1.2d, v0.2d
  fmul  v2.2d, v2.2d, v4.2d
  fadd  v0.2d, v0.2d, v2.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Llerpf64_loop2
.Llerpf64_tail:
  cbz   x3, .Llerpf64_done
.Llerpf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fsub  d1, d1, d0
  fmul  d1, d1, d4
  fadd  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Llerpf64_tail_loop
.Llerpf64_done:
  ret
end;

procedure NEONArrayFmaF64(aA, aB, aC, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x4, .Lfmaf64_done
.Lfmaf64_loop2:
  cmp   x4, #2
  b.lo  .Lfmaf64_tail
  ldp   x5, x6, [x0], #16
  fmov  d0, x5
  fmov  d1, x6
  ins   v0.d[1], v1.d[0]
  ldp   x5, x6, [x1], #16
  fmov  d1, x5
  fmov  d2, x6
  ins   v1.d[1], v2.d[0]
  ldp   x5, x6, [x2], #16
  fmov  d2, x5
  fmov  d3, x6
  ins   v2.d[1], v3.d[0]
  fmul  v0.2d, v0.2d, v1.2d
  fadd  v0.2d, v0.2d, v2.2d
  umov  x5, v0.d[0]
  umov  x6, v0.d[1]
  stp   x5, x6, [x3], #16
  sub   x4, x4, #2
  b     .Lfmaf64_loop2
.Lfmaf64_tail:
  cbz   x4, .Lfmaf64_done
.Lfmaf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  ldr   d2, [x2], #8
  fmul  d0, d0, d1
  fadd  d0, d0, d2
  str   d0, [x3], #8
  subs  x4, x4, #1
  b.ne  .Lfmaf64_tail_loop
.Lfmaf64_done:
  ret
end;

procedure NEONArrayAxpyF64(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Laxpyf64_done
  dup   v3.2d, v0.d[0]
.Laxpyf64_loop2:
  cmp   x3, #2
  b.lo  .Laxpyf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fmul  v0.2d, v0.2d, v3.2d
  fadd  v0.2d, v0.2d, v1.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Laxpyf64_loop2
.Laxpyf64_tail:
  cbz   x3, .Laxpyf64_done
.Laxpyf64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fmul  d0, d0, d3
  fadd  d0, d0, d1
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Laxpyf64_tail_loop
.Laxpyf64_done:
  ret
end;

// === Wave C4d: NEON BatchF64 Ceil/Floor/Trunc + ReLU/AbsDiff ===
// Unary ABI: x0=src, x1=dst, x2=count
// AbsDiff:   x0=src1, x1=src2, x2=dst, x3=count
// frintp=ceil, frintm=floor, frintz=trunc; ReLU=fmax(.,0); AbsDiff=fabs(a-b)

procedure NEONArrayCeilF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lceilf64_done
.Lceilf64_loop2:
  cmp   x2, #2
  b.lo  .Lceilf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintp v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lceilf64_loop2
.Lceilf64_tail:
  cbz   x2, .Lceilf64_done
.Lceilf64_tail_loop:
  ldr   d0, [x0], #8
  frintp d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lceilf64_tail_loop
.Lceilf64_done:
  ret
end;

procedure NEONArrayFloorF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lfloorf64_done
.Lfloorf64_loop2:
  cmp   x2, #2
  b.lo  .Lfloorf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintm v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lfloorf64_loop2
.Lfloorf64_tail:
  cbz   x2, .Lfloorf64_done
.Lfloorf64_tail_loop:
  ldr   d0, [x0], #8
  frintm d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lfloorf64_tail_loop
.Lfloorf64_done:
  ret
end;

procedure NEONArrayTruncF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Ltruncf64_done
.Ltruncf64_loop2:
  cmp   x2, #2
  b.lo  .Ltruncf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  frintz v0.2d, v0.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Ltruncf64_loop2
.Ltruncf64_tail:
  cbz   x2, .Ltruncf64_done
.Ltruncf64_tail_loop:
  ldr   d0, [x0], #8
  frintz d0, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Ltruncf64_tail_loop
.Ltruncf64_done:
  ret
end;

procedure NEONArrayReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lreluf64_done
  movi  v1.2d, #0
.Lreluf64_loop2:
  cmp   x2, #2
  b.lo  .Lreluf64_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d2, x4
  ins   v0.d[1], v2.d[0]
  fmax  v0.2d, v0.2d, v1.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lreluf64_loop2
.Lreluf64_tail:
  cbz   x2, .Lreluf64_done
.Lreluf64_tail_loop:
  ldr   d0, [x0], #8
  fmax  d0, d0, d1
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lreluf64_tail_loop
.Lreluf64_done:
  ret
end;

procedure NEONArrayAbsDiffF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x3, .Labsdifff64_done
.Labsdifff64_loop2:
  cmp   x3, #2
  b.lo  .Labsdifff64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  ldp   x4, x5, [x1], #16
  fmov  d1, x4
  fmov  d2, x5
  ins   v1.d[1], v2.d[0]
  fsub  v0.2d, v0.2d, v1.2d
  fabs  v0.2d, v0.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x2], #16
  sub   x3, x3, #2
  b     .Labsdifff64_loop2
.Labsdifff64_tail:
  cbz   x3, .Labsdifff64_done
.Labsdifff64_tail_loop:
  ldr   d0, [x0], #8
  ldr   d1, [x1], #8
  fsub  d0, d0, d1
  fabs  d0, d0
  str   d0, [x2], #8
  subs  x3, x3, #1
  b.ne  .Labsdifff64_tail_loop
.Labsdifff64_done:
  ret
end;

// === Wave C4e: NEON BatchF64 Rcp / Rsqrt / RcpRefine / RsqrtRefine ===
// ABI: x0=src, x1=dst, x2=count
// Rcp/RcpRefine: 1.0/x via fdiv (not frecpe); exact scalar match
// Rsqrt/RsqrtRefine: 1.0/sqrt(x) via fsqrt+fdiv (not frsqrte)
// 1.0d = 0x3FF0000000000000

procedure NEONArrayRcpF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lrcpf64_done
  mov   x3, #0x3FF0000000000000
  fmov  d3, x3
  dup   v3.2d, v3.d[0]
.Lrcpf64_loop2:
  cmp   x2, #2
  b.lo  .Lrcpf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fdiv  v0.2d, v3.2d, v0.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #2
  b     .Lrcpf64_loop2
.Lrcpf64_tail:
  cbz   x2, .Lrcpf64_done
.Lrcpf64_tail_loop:
  ldr   d0, [x0], #8
  fdiv  d0, d3, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lrcpf64_tail_loop
.Lrcpf64_done:
  ret
end;

procedure NEONArrayRsqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lrsqrtf64_done
  mov   x3, #0x3FF0000000000000
  fmov  d3, x3
  dup   v3.2d, v3.d[0]
.Lrsqrtf64_loop2:
  cmp   x2, #2
  b.lo  .Lrsqrtf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fsqrt v0.2d, v0.2d
  fdiv  v0.2d, v3.2d, v0.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #2
  b     .Lrsqrtf64_loop2
.Lrsqrtf64_tail:
  cbz   x2, .Lrsqrtf64_done
.Lrsqrtf64_tail_loop:
  ldr   d0, [x0], #8
  fsqrt d0, d0
  fdiv  d0, d3, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lrsqrtf64_tail_loop
.Lrsqrtf64_done:
  ret
end;

procedure NEONArrayRcpRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lrcprf64_done
  mov   x3, #0x3FF0000000000000
  fmov  d3, x3
  dup   v3.2d, v3.d[0]
.Lrcprf64_loop2:
  cmp   x2, #2
  b.lo  .Lrcprf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fdiv  v0.2d, v3.2d, v0.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #2
  b     .Lrcprf64_loop2
.Lrcprf64_tail:
  cbz   x2, .Lrcprf64_done
.Lrcprf64_tail_loop:
  ldr   d0, [x0], #8
  fdiv  d0, d3, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lrcprf64_tail_loop
.Lrcprf64_done:
  ret
end;

procedure NEONArrayRsqrtRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lrsqrrf64_done
  mov   x3, #0x3FF0000000000000
  fmov  d3, x3
  dup   v3.2d, v3.d[0]
.Lrsqrrf64_loop2:
  cmp   x2, #2
  b.lo  .Lrsqrrf64_tail
  ldp   x4, x5, [x0], #16
  fmov  d0, x4
  fmov  d1, x5
  ins   v0.d[1], v1.d[0]
  fsqrt v0.2d, v0.2d
  fdiv  v0.2d, v3.2d, v0.2d
  umov  x4, v0.d[0]
  umov  x5, v0.d[1]
  stp   x4, x5, [x1], #16
  sub   x2, x2, #2
  b     .Lrsqrrf64_loop2
.Lrsqrrf64_tail:
  cbz   x2, .Lrsqrrf64_done
.Lrsqrrf64_tail_loop:
  ldr   d0, [x0], #8
  fsqrt d0, d0
  fdiv  d0, d3, d0
  str   d0, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lrsqrrf64_tail_loop
.Lrsqrrf64_done:
  ret
end;

// === Wave C5 sample: NEON BatchF32 ArraySin / ArrayExp ===
// === Wave C5e: NEON BatchF32 ArraySin / ArrayExp — true 4-wide NEON asm ===
// Same math as C5 Cody-Waite / range-reduction poly; ICE-safe ldp/stp 4×f32.
// Constants loaded via bit patterns. Non-finite packets still evaluated in poly
// domain (tests use finite); tail uses s-reg scalar path matching poly.

// float bits helper pattern:
//   mov w9, #lo16 ; movk w9, #hi16, lsl #16 ; fmov sN, w9 ; dup vN.4s, vN.s[0]

procedure NEONArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lsinf32v_done

  // v16=2/pi, v17=pi/2hi, v18=pi/2mid, v19=S1, v20=S2, v21=S3
  // v22=C1, v23=C2, v24=C3, v25=1.0, v26=sign mask 0x80000000
  mov   w9, #0xF983
  movk  w9, #0x3F22, lsl #16
  fmov  s16, w9
  dup   v16.4s, v16.s[0]
  mov   w9, #0x0FDB
  movk  w9, #0x3FC9, lsl #16
  fmov  s17, w9
  dup   v17.4s, v17.s[0]
  mov   w9, #0xBD2E
  movk  w9, #0xB33B, lsl #16
  fmov  s18, w9
  dup   v18.4s, v18.s[0]
  mov   w9, #0xAAAB
  movk  w9, #0xBE2A, lsl #16
  fmov  s19, w9
  dup   v19.4s, v19.s[0]
  mov   w9, #0x8889
  movk  w9, #0x3C08, lsl #16
  fmov  s20, w9
  dup   v20.4s, v20.s[0]
  mov   w9, #0x0D01
  movk  w9, #0xB950, lsl #16
  fmov  s21, w9
  dup   v21.4s, v21.s[0]
  mov   w9, #0x0000
  movk  w9, #0xBF00, lsl #16
  fmov  s22, w9
  dup   v22.4s, v22.s[0]
  mov   w9, #0xAAAA
  movk  w9, #0x3D2A, lsl #16
  fmov  s23, w9
  dup   v23.4s, v23.s[0]
  mov   w9, #0x0B61
  movk  w9, #0xBAB6, lsl #16
  fmov  s24, w9
  dup   v24.4s, v24.s[0]
  mov   w9, #0x0000
  movk  w9, #0x3F80, lsl #16
  fmov  s25, w9
  dup   v25.4s, v25.s[0]
  mov   w9, #0x0000
  movk  w9, #0x8000, lsl #16
  fmov  s26, w9
  dup   v26.4s, v26.s[0]

.Lsinf32v_loop4:
  cmp   x2, #4
  b.lo  .Lsinf32v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]          // x in v0.4s

  // sign(x) → v1, |x| → v2
  and   v1.16b, v0.16b, v26.16b
  bic   v2.16b, v0.16b, v26.16b

  // j = round(|x| * 2/pi)
  fmul  v3.4s, v2.4s, v16.4s
  frintn v3.4s, v3.4s             // j as float
  fcvtzs v4.4s, v3.4s             // j as int

  // r = |x| - j*pi/2 (Cody-Waite)
  fmul  v5.4s, v3.4s, v17.4s
  fsub  v2.4s, v2.4s, v5.4s
  fmul  v5.4s, v3.4s, v18.4s
  fsub  v2.4s, v2.4s, v5.4s       // r
  fmul  v3.4s, v2.4s, v2.4s       // r2

  // sPoly = r*(1 + r2*(S1 + r2*(S2 + r2*S3)))
  fmul  v5.4s, v21.4s, v3.4s
  fadd  v5.4s, v5.4s, v20.4s
  fmul  v5.4s, v5.4s, v3.4s
  fadd  v5.4s, v5.4s, v19.4s
  fmul  v5.4s, v5.4s, v3.4s
  fadd  v5.4s, v5.4s, v25.4s
  fmul  v5.4s, v5.4s, v2.4s       // sPoly

  // cPoly = 1 + r2*(C1 + r2*(C2 + r2*C3))
  fmul  v6.4s, v24.4s, v3.4s
  fadd  v6.4s, v6.4s, v23.4s
  fmul  v6.4s, v6.4s, v3.4s
  fadd  v6.4s, v6.4s, v22.4s
  fmul  v6.4s, v6.4s, v3.4s
  fadd  v6.4s, v6.4s, v25.4s      // cPoly

  // blend: j odd → cPoly else sPoly
  movi  v0.4s, #1
  and   v7.16b, v4.16b, v0.16b
  cmeq  v7.4s, v7.4s, v0.4s       // 0xFFFFFFFF where (j&1)==1
  bsl   v7.16b, v6.16b, v5.16b    // odd→cPoly, even→sPoly

  // sign flip from (j>>1)&1 then original sign in v1
  ushr  v0.4s, v4.4s, #1
  movi  v5.4s, #1
  and   v0.16b, v0.16b, v5.16b
  shl   v0.4s, v0.4s, #31
  eor   v7.16b, v7.16b, v0.16b
  eor   v7.16b, v7.16b, v1.16b

  umov  x3, v7.d[0]
  umov  x4, v7.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Lsinf32v_loop4

.Lsinf32v_tail:
  cbz   x2, .Lsinf32v_done
.Lsinf32v_tail_loop:
  ldr   s0, [x0], #4
  // scalar poly (same constants in s16.. already set)
  // abs + sign
  fabs  s2, s0
  // j = round(abs*2/pi)
  fmul  s3, s2, s16
  frintn s3, s3
  fcvtzs w3, s3
  fmul  s5, s3, s17
  fsub  s2, s2, s5
  fmul  s5, s3, s18
  fsub  s2, s2, s5
  fmul  s3, s2, s2
  fmul  s5, s21, s3
  fadd  s5, s5, s20
  fmul  s5, s5, s3
  fadd  s5, s5, s19
  fmul  s5, s5, s3
  fadd  s5, s5, s25
  fmul  s5, s5, s2
  fmul  s6, s24, s3
  fadd  s6, s6, s23
  fmul  s6, s6, s3
  fadd  s6, s6, s22
  fmul  s6, s6, s3
  fadd  s6, s6, s25
  tst   w3, #1
  fcsel s7, s6, s5, ne
  lsr   w4, w3, #1
  and   w4, w4, #1
  cmp   w4, #0
  fneg  s5, s7
  fcsel s7, s5, s7, ne
  // apply sign of original s0
  fmov  w5, s0
  lsr   w5, w5, #31
  cmp   w5, #0
  fneg  s5, s7
  fcsel s7, s5, s7, ne
  str   s7, [x1], #4
  subs  x2, x2, #1
  b.ne  .Lsinf32v_tail_loop
.Lsinf32v_done:
  ret
end;

procedure NEONArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lexpf32v_done

  // v16=log2e, v17=ln2hi, v18=ln2lo, v19=c6.. use v19-v25 for poly, v26=max, v27=min, v28=1
  mov   w9, #0xAA3B
  movk  w9, #0x3FB8, lsl #16
  fmov  s16, w9
  dup   v16.4s, v16.s[0]
  mov   w9, #0x7200
  movk  w9, #0x3F31, lsl #16
  fmov  s17, w9
  dup   v17.4s, v17.s[0]
  mov   w9, #0xBE8E
  movk  w9, #0x35BF, lsl #16
  fmov  s18, w9
  dup   v18.4s, v18.s[0]
  mov   w9, #0x96C9
  movk  w9, #0x3AB6, lsl #16
  fmov  s19, w9
  dup   v19.4s, v19.s[0]        // c6
  mov   w9, #0x88A6
  movk  w9, #0x3C08, lsl #16
  fmov  s20, w9
  dup   v20.4s, v20.s[0]        // c5
  mov   w9, #0xAA7A
  movk  w9, #0x3D2A, lsl #16
  fmov  s21, w9
  dup   v21.4s, v21.s[0]        // c4
  mov   w9, #0xAAAB
  movk  w9, #0x3E2A, lsl #16
  fmov  s22, w9
  dup   v22.4s, v22.s[0]        // c3
  mov   w9, #0x0000
  movk  w9, #0x3F00, lsl #16
  fmov  s23, w9
  dup   v23.4s, v23.s[0]        // c2=0.5
  mov   w9, #0x0000
  movk  w9, #0x3F80, lsl #16
  fmov  s24, w9
  dup   v24.4s, v24.s[0]        // c1=c0=1
  mov   w9, #0x7213
  movk  w9, #0x42B1, lsl #16
  fmov  s26, w9
  dup   v26.4s, v26.s[0]        // max
  mov   w9, #0xAC4A
  movk  w9, #0xC2AE, lsl #16
  fmov  s27, w9
  dup   v27.4s, v27.s[0]        // min

.Lexpf32v_loop4:
  cmp   x2, #4
  b.lo  .Lexpf32v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]

  // clamp
  fmin  v0.4s, v0.4s, v26.4s
  fmax  v0.4s, v0.4s, v27.4s

  // n = round(x * log2e)
  fmul  v1.4s, v0.4s, v16.4s
  frintn v1.4s, v1.4s

  // r = x - n*ln2hi - n*ln2lo
  fmul  v2.4s, v1.4s, v17.4s
  fsub  v0.4s, v0.4s, v2.4s
  fmul  v2.4s, v1.4s, v18.4s
  fsub  v0.4s, v0.4s, v2.4s       // r

  // horner: (((((c6*r+c5)*r+c4)*r+c3)*r+c2)*r+c1)*r+c0
  fmul  v3.4s, v19.4s, v0.4s
  fadd  v3.4s, v3.4s, v20.4s
  fmul  v3.4s, v3.4s, v0.4s
  fadd  v3.4s, v3.4s, v21.4s
  fmul  v3.4s, v3.4s, v0.4s
  fadd  v3.4s, v3.4s, v22.4s
  fmul  v3.4s, v3.4s, v0.4s
  fadd  v3.4s, v3.4s, v23.4s
  fmul  v3.4s, v3.4s, v0.4s
  fadd  v3.4s, v3.4s, v24.4s
  fmul  v3.4s, v3.4s, v0.4s
  fadd  v3.4s, v3.4s, v24.4s      // poly

  // 2^n: fcvtzs n, shl 23, add bits
  fcvtzs v1.4s, v1.4s
  // clamp n to [-126,127]
  mov   w9, #127
  dup   v0.4s, w9
  smin  v1.4s, v1.4s, v0.4s
  mov   w9, #-126
  dup   v0.4s, w9
  smax  v1.4s, v1.4s, v0.4s
  shl   v1.4s, v1.4s, #23
  // reinterpret poly as int and add
  // v3 float bits + v1
  // use orr to copy bits then add as int
  mov   v0.16b, v3.16b
  add   v0.4s, v0.4s, v1.4s

  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Lexpf32v_loop4

.Lexpf32v_tail:
  cbz   x2, .Lexpf32v_done
.Lexpf32v_tail_loop:
  ldr   s0, [x0], #4
  fmin  s0, s0, s26
  fmax  s0, s0, s27
  fmul  s1, s0, s16
  frintn s1, s1
  fmul  s2, s1, s17
  fsub  s0, s0, s2
  fmul  s2, s1, s18
  fsub  s0, s0, s2
  fmul  s3, s19, s0
  fadd  s3, s3, s20
  fmul  s3, s3, s0
  fadd  s3, s3, s21
  fmul  s3, s3, s0
  fadd  s3, s3, s22
  fmul  s3, s3, s0
  fadd  s3, s3, s23
  fmul  s3, s3, s0
  fadd  s3, s3, s24
  fmul  s3, s3, s0
  fadd  s3, s3, s24
  fcvtzs w3, s1
  mov   w4, #127
  cmp   w3, w4
  csel  w3, w3, w4, lt
  mov   w4, #-126
  cmp   w3, w4
  csel  w3, w3, w4, gt
  fmov  w5, s3
  add   w5, w5, w3, lsl #23
  fmov  s3, w5
  str   s3, [x1], #4
  subs  x2, x2, #1
  b.ne  .Lexpf32v_tail_loop
.Lexpf32v_done:
  ret
end;

// === Wave C5e-ext: Cos/Log 4-wide + F64 Sin/Exp 2-wide NEON asm ===

procedure NEONArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lcosf32v_done
  mov   w9, #0xF983
  movk  w9, #0x3F22, lsl #16
  fmov  s16, w9
  dup   v16.4s, v16.s[0]
  mov   w9, #0x0FDB
  movk  w9, #0x3FC9, lsl #16
  fmov  s17, w9
  dup   v17.4s, v17.s[0]
  mov   w9, #0xBD2E
  movk  w9, #0xB33B, lsl #16
  fmov  s18, w9
  dup   v18.4s, v18.s[0]
  mov   w9, #0xAAAB
  movk  w9, #0xBE2A, lsl #16
  fmov  s19, w9
  dup   v19.4s, v19.s[0]
  mov   w9, #0x8889
  movk  w9, #0x3C08, lsl #16
  fmov  s20, w9
  dup   v20.4s, v20.s[0]
  mov   w9, #0x0D01
  movk  w9, #0xB950, lsl #16
  fmov  s21, w9
  dup   v21.4s, v21.s[0]
  mov   w9, #0x0000
  movk  w9, #0xBF00, lsl #16
  fmov  s22, w9
  dup   v22.4s, v22.s[0]
  mov   w9, #0xAAAA
  movk  w9, #0x3D2A, lsl #16
  fmov  s23, w9
  dup   v23.4s, v23.s[0]
  mov   w9, #0x0B61
  movk  w9, #0xBAB6, lsl #16
  fmov  s24, w9
  dup   v24.4s, v24.s[0]
  mov   w9, #0x0000
  movk  w9, #0x3F80, lsl #16
  fmov  s25, w9
  dup   v25.4s, v25.s[0]

.Lcosf32v_loop4:
  cmp   x2, #4
  b.lo  .Lcosf32v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fabs  v2.4s, v0.4s
  fmul  v3.4s, v2.4s, v16.4s
  frintn v3.4s, v3.4s
  fcvtzs v4.4s, v3.4s
  fmul  v5.4s, v3.4s, v17.4s
  fsub  v2.4s, v2.4s, v5.4s
  fmul  v5.4s, v3.4s, v18.4s
  fsub  v2.4s, v2.4s, v5.4s
  fmul  v3.4s, v2.4s, v2.4s
  fmul  v5.4s, v21.4s, v3.4s
  fadd  v5.4s, v5.4s, v20.4s
  fmul  v5.4s, v5.4s, v3.4s
  fadd  v5.4s, v5.4s, v19.4s
  fmul  v5.4s, v5.4s, v3.4s
  fadd  v5.4s, v5.4s, v25.4s
  fmul  v5.4s, v5.4s, v2.4s
  fmul  v6.4s, v24.4s, v3.4s
  fadd  v6.4s, v6.4s, v23.4s
  fmul  v6.4s, v6.4s, v3.4s
  fadd  v6.4s, v6.4s, v22.4s
  fmul  v6.4s, v6.4s, v3.4s
  fadd  v6.4s, v6.4s, v25.4s
  movi  v0.4s, #1
  add   v4.4s, v4.4s, v0.4s
  and   v7.16b, v4.16b, v0.16b
  cmeq  v7.4s, v7.4s, v0.4s
  bsl   v7.16b, v6.16b, v5.16b
  ushr  v0.4s, v4.4s, #1
  movi  v5.4s, #1
  and   v0.16b, v0.16b, v5.16b
  shl   v0.4s, v0.4s, #31
  eor   v7.16b, v7.16b, v0.16b
  umov  x3, v7.d[0]
  umov  x4, v7.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Lcosf32v_loop4
.Lcosf32v_tail:
  cbz   x2, .Lcosf32v_done
.Lcosf32v_tail_loop:
  ldr   s0, [x0], #4
  fabs  s2, s0
  fmul  s3, s2, s16
  frintn s3, s3
  fcvtzs w3, s3
  fmul  s5, s3, s17
  fsub  s2, s2, s5
  fmul  s5, s3, s18
  fsub  s2, s2, s5
  fmul  s3, s2, s2
  fmul  s5, s21, s3
  fadd  s5, s5, s20
  fmul  s5, s5, s3
  fadd  s5, s5, s19
  fmul  s5, s5, s3
  fadd  s5, s5, s25
  fmul  s5, s5, s2
  fmul  s6, s24, s3
  fadd  s6, s6, s23
  fmul  s6, s6, s3
  fadd  s6, s6, s22
  fmul  s6, s6, s3
  fadd  s6, s6, s25
  add   w3, w3, #1
  tst   w3, #1
  fcsel s7, s6, s5, ne
  lsr   w4, w3, #1
  and   w4, w4, #1
  cmp   w4, #0
  fneg  s5, s7
  fcsel s7, s5, s7, ne
  str   s7, [x1], #4
  subs  x2, x2, #1
  b.ne  .Lcosf32v_tail_loop
.Lcosf32v_done:
  ret
end;

procedure NEONArraySinCosF32(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;
  NEONArraySinF32(aSrc, aSinDst, aCount);
  NEONArrayCosF32(aSrc, aCosDst, aCount);
end;

procedure NEONArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Llogf32v_done
  mov   w9, #0x7218
  movk  w9, #0x3F31, lsl #16
  fmov  s16, w9
  dup   v16.4s, v16.s[0]
  mov   w9, #0x0000
  movk  w9, #0x3F80, lsl #16
  fmov  s17, w9
  dup   v17.4s, v17.s[0]
  mov   w9, #0x0000
  movk  w9, #0x4000, lsl #16
  fmov  s18, w9
  dup   v18.4s, v18.s[0]
  mov   w9, #0xAAAB
  movk  w9, #0x3EAA, lsl #16
  fmov  s19, w9
  dup   v19.4s, v19.s[0]
  mov   w9, #0xCCCD
  movk  w9, #0x3E4C, lsl #16
  fmov  s20, w9
  dup   v20.4s, v20.s[0]
  mov   w9, #0x4925
  movk  w9, #0x3E12, lsl #16
  fmov  s21, w9
  dup   v21.4s, v21.s[0]
  mov   w9, #0xFFFF
  movk  w9, #0x007F, lsl #16
  dup   v22.4s, w9
  mov   w9, #0x0000
  movk  w9, #0x3F00, lsl #16
  dup   v23.4s, w9
  mov   w9, #0x04F3
  movk  w9, #0x3F35, lsl #16
  fmov  s24, w9
  dup   v24.4s, v24.s[0]
  mov   w9, #126
  dup   v25.4s, w9

.Llogf32v_loop4:
  cmp   x2, #4
  b.lo  .Llogf32v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  ushr  v1.4s, v0.4s, #23
  mov   w9, #0xFF
  dup   v2.4s, w9
  and   v1.16b, v1.16b, v2.16b
  sub   v1.4s, v1.4s, v25.4s
  and   v2.16b, v0.16b, v22.16b
  orr   v2.16b, v2.16b, v23.16b
  fcmgt v3.4s, v24.4s, v2.4s
  fmul  v4.4s, v2.4s, v18.4s
  bit   v2.16b, v4.16b, v3.16b
  add   v1.4s, v1.4s, v3.4s
  fsub  v4.4s, v2.4s, v17.4s
  fadd  v5.4s, v2.4s, v17.4s
  fdiv  v4.4s, v4.4s, v5.4s
  fmul  v5.4s, v4.4s, v4.4s
  fmul  v6.4s, v21.4s, v5.4s
  fadd  v6.4s, v6.4s, v20.4s
  fmul  v6.4s, v6.4s, v5.4s
  fadd  v6.4s, v6.4s, v19.4s
  fmul  v6.4s, v6.4s, v5.4s
  fadd  v6.4s, v6.4s, v17.4s
  fmul  v6.4s, v6.4s, v4.4s
  fmul  v6.4s, v6.4s, v18.4s
  scvtf v1.4s, v1.4s
  fmul  v1.4s, v1.4s, v16.4s
  fadd  v6.4s, v6.4s, v1.4s
  umov  x3, v6.d[0]
  umov  x4, v6.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #4
  b     .Llogf32v_loop4
.Llogf32v_tail:
  cbz   x2, .Llogf32v_done
.Llogf32v_tail_loop:
  ldr   s0, [x0], #4
  fmov  w3, s0
  lsr   w5, w3, #31
  cbnz  w5, .Llogf32v_spec
  and   w4, w3, #0x7FFFFFFF
  cbz   w4, .Llogf32v_spec
  lsr   w4, w3, #23
  and   w4, w4, #0xFF
  cmp   w4, #0xFF
  b.eq  .Llogf32v_spec
  sub   w4, w4, #126
  and   w5, w3, #0x007FFFFF
  orr   w5, w5, #0x3F000000
  fmov  s2, w5
  mov   w6, #0x3F3504F3
  cmp   w5, w6
  b.hs  .Llogf32v_mok
  fmul  s2, s2, s18
  sub   w4, w4, #1
.Llogf32v_mok:
  fsub  s4, s2, s17
  fadd  s5, s2, s17
  fdiv  s4, s4, s5
  fmul  s5, s4, s4
  fmul  s6, s21, s5
  fadd  s6, s6, s20
  fmul  s6, s6, s5
  fadd  s6, s6, s19
  fmul  s6, s6, s5
  fadd  s6, s6, s17
  fmul  s6, s6, s4
  fmul  s6, s6, s18
  scvtf s1, w4
  fmul  s1, s1, s16
  fadd  s6, s6, s1
  str   s6, [x1], #4
  b     .Llogf32v_tc
.Llogf32v_spec:
  str   s0, [x1], #4
.Llogf32v_tc:
  subs  x2, x2, #1
  b.ne  .Llogf32v_tail_loop
.Llogf32v_done:
  ret
end;

procedure NEONArrayLog2F32(aSrc, aDst: PSingle; aCount: SizeUInt);
const
  CInvLn2: Single = 1.4426950408889634;
var
  i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then
    Exit;
  NEONArrayLogF32(aSrc, aDst, aCount);
  for i := 0 to aCount - 1 do
    aDst[i] := aDst[i] * CInvLn2;
end;

procedure NEONArrayLog10F32(aSrc, aDst: PSingle; aCount: SizeUInt);
const
  CInvLn10: Single = 0.4342944819032518;
var
  i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then
    Exit;
  NEONArrayLogF32(aSrc, aDst, aCount);
  for i := 0 to aCount - 1 do
    aDst[i] := aDst[i] * CInvLn10;
end;

procedure NEONArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lsinf64v_done
  mov   x9, #0xC883
  movk  x9, #0x6DC9, lsl #16
  movk  x9, #0x5F30, lsl #32
  movk  x9, #0x3FE4, lsl #48
  fmov  d16, x9
  dup   v16.2d, v16.d[0]
  mov   x9, #0x2D18
  movk  x9, #0x5444, lsl #16
  movk  x9, #0x21FB, lsl #32
  movk  x9, #0x3FF9, lsl #48
  fmov  d17, x9
  dup   v17.2d, v17.d[0]
  mov   x9, #0x5C07
  movk  x9, #0x3314, lsl #16
  movk  x9, #0xA626, lsl #32
  movk  x9, #0x3C91, lsl #48
  fmov  d18, x9
  dup   v18.2d, v18.d[0]
  mov   x9, #0x5555
  movk  x9, #0x5555, lsl #16
  movk  x9, #0x5555, lsl #32
  movk  x9, #0xBFC5, lsl #48
  fmov  d19, x9
  dup   v19.2d, v19.d[0]
  mov   x9, #0x1111
  movk  x9, #0x1111, lsl #16
  movk  x9, #0x1111, lsl #32
  movk  x9, #0x3F81, lsl #48
  fmov  d20, x9
  dup   v20.2d, v20.d[0]
  mov   x9, #0xA01A
  movk  x9, #0x1A01, lsl #16
  movk  x9, #0x01A0, lsl #32
  movk  x9, #0xBF2A, lsl #48
  fmov  d21, x9
  dup   v21.2d, v21.d[0]
  mov   x9, #0x0000
  movk  x9, #0x0000, lsl #16
  movk  x9, #0x0000, lsl #32
  movk  x9, #0xBFE0, lsl #48
  fmov  d22, x9
  dup   v22.2d, v22.d[0]
  mov   x9, #0x5555
  movk  x9, #0x5555, lsl #16
  movk  x9, #0x5555, lsl #32
  movk  x9, #0x3FA5, lsl #48
  fmov  d23, x9
  dup   v23.2d, v23.d[0]
  mov   x9, #0x6C17
  movk  x9, #0x16C1, lsl #16
  movk  x9, #0xC16C, lsl #32
  movk  x9, #0xBF56, lsl #48
  fmov  d24, x9
  dup   v24.2d, v24.d[0]
  mov   x9, #0x0000
  movk  x9, #0x0000, lsl #16
  movk  x9, #0x0000, lsl #32
  movk  x9, #0x3FF0, lsl #48
  fmov  d25, x9
  dup   v25.2d, v25.d[0]
  // sign mask high bit
  mov   x9, #0
  movk  x9, #0x8000, lsl #48
  fmov  d26, x9
  dup   v26.2d, v26.d[0]

.Lsinf64v_loop2:
  cmp   x2, #2
  b.lo  .Lsinf64v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  and   v1.16b, v0.16b, v26.16b
  bic   v2.16b, v0.16b, v26.16b
  fmul  v3.2d, v2.2d, v16.2d
  frintn v3.2d, v3.2d
  fcvtzs v4.2d, v3.2d
  fmul  v5.2d, v3.2d, v17.2d
  fsub  v2.2d, v2.2d, v5.2d
  fmul  v5.2d, v3.2d, v18.2d
  fsub  v2.2d, v2.2d, v5.2d
  fmul  v3.2d, v2.2d, v2.2d
  fmul  v5.2d, v21.2d, v3.2d
  fadd  v5.2d, v5.2d, v20.2d
  fmul  v5.2d, v5.2d, v3.2d
  fadd  v5.2d, v5.2d, v19.2d
  fmul  v5.2d, v5.2d, v3.2d
  fadd  v5.2d, v5.2d, v25.2d
  fmul  v5.2d, v5.2d, v2.2d
  fmul  v6.2d, v24.2d, v3.2d
  fadd  v6.2d, v6.2d, v23.2d
  fmul  v6.2d, v6.2d, v3.2d
  fadd  v6.2d, v6.2d, v22.2d
  fmul  v6.2d, v6.2d, v3.2d
  fadd  v6.2d, v6.2d, v25.2d
  // j&1 blend — use integer and on 64-bit j
  // fcvtzs gave 2s? fcvtzs v4.2d is 64-bit ints
  movi  v0.2d, #1
  and   v7.16b, v4.16b, v0.16b
  cmeq  v7.2d, v7.2d, v0.2d
  bsl   v7.16b, v6.16b, v5.16b
  ushr  v0.2d, v4.2d, #1
  movi  v5.2d, #1
  and   v0.16b, v0.16b, v5.16b
  // sign bit for f64 is bit 63: shl #63
  shl   v0.2d, v0.2d, #63
  eor   v7.16b, v7.16b, v0.16b
  eor   v7.16b, v7.16b, v1.16b
  umov  x3, v7.d[0]
  umov  x4, v7.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lsinf64v_loop2
.Lsinf64v_tail:
  cbz   x2, .Lsinf64v_done
.Lsinf64v_tail_loop:
  ldr   d0, [x0], #8
  fabs  d2, d0
  fmul  d3, d2, d16
  frintn d3, d3
  fcvtzs x3, d3
  fmul  d5, d3, d17
  fsub  d2, d2, d5
  fmul  d5, d3, d18
  fsub  d2, d2, d5
  fmul  d3, d2, d2
  fmul  d5, d21, d3
  fadd  d5, d5, d20
  fmul  d5, d5, d3
  fadd  d5, d5, d19
  fmul  d5, d5, d3
  fadd  d5, d5, d25
  fmul  d5, d5, d2
  fmul  d6, d24, d3
  fadd  d6, d6, d23
  fmul  d6, d6, d3
  fadd  d6, d6, d22
  fmul  d6, d6, d3
  fadd  d6, d6, d25
  tst   x3, #1
  fcsel d7, d6, d5, ne
  lsr   x4, x3, #1
  and   x4, x4, #1
  cmp   x4, #0
  fneg  d5, d7
  fcsel d7, d5, d7, ne
  fmov  x5, d0
  lsr   x5, x5, #63
  cmp   x5, #0
  fneg  d5, d7
  fcsel d7, d5, d7, ne
  str   d7, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lsinf64v_tail_loop
.Lsinf64v_done:
  ret
end;

procedure NEONArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;
asm
  cbz   x2, .Lexpf64v_done
  mov   x9, #0x82FE
  movk  x9, #0x652B, lsl #16
  movk  x9, #0x1547, lsl #32
  movk  x9, #0x3FF7, lsl #48
  fmov  d16, x9
  dup   v16.2d, v16.d[0]
  mov   x9, #0x39EF
  movk  x9, #0xFEFA, lsl #16
  movk  x9, #0x2E42, lsl #32
  movk  x9, #0x3FE6, lsl #48
  fmov  d17, x9
  dup   v17.2d, v17.d[0]
  mov   x9, #0x3C76
  movk  x9, #0x3579, lsl #16
  movk  x9, #0x39EF, lsl #32
  movk  x9, #0x3DEA, lsl #48
  fmov  d18, x9
  dup   v18.2d, v18.d[0]
  mov   x9, #0x6C17
  movk  x9, #0x16C1, lsl #16
  movk  x9, #0xC16C, lsl #32
  movk  x9, #0x3F56, lsl #48
  fmov  d19, x9
  dup   v19.2d, v19.d[0]
  mov   x9, #0x1111
  movk  x9, #0x1111, lsl #16
  movk  x9, #0x1111, lsl #32
  movk  x9, #0x3F81, lsl #48
  fmov  d20, x9
  dup   v20.2d, v20.d[0]
  mov   x9, #0x5555
  movk  x9, #0x5555, lsl #16
  movk  x9, #0x5555, lsl #32
  movk  x9, #0x3FA5, lsl #48
  fmov  d21, x9
  dup   v21.2d, v21.d[0]
  mov   x9, #0x5555
  movk  x9, #0x5555, lsl #16
  movk  x9, #0x5555, lsl #32
  movk  x9, #0x3FC5, lsl #48
  fmov  d22, x9
  dup   v22.2d, v22.d[0]
  mov   x9, #0x0000
  movk  x9, #0x0000, lsl #16
  movk  x9, #0x0000, lsl #32
  movk  x9, #0x3FE0, lsl #48
  fmov  d23, x9
  dup   v23.2d, v23.d[0]
  mov   x9, #0x0000
  movk  x9, #0x0000, lsl #16
  movk  x9, #0x0000, lsl #32
  movk  x9, #0x3FF0, lsl #48
  fmov  d24, x9
  dup   v24.2d, v24.d[0]
  mov   x9, #0x39EF
  movk  x9, #0xFEFA, lsl #16
  movk  x9, #0x2E42, lsl #32
  movk  x9, #0x4086, lsl #48
  fmov  d26, x9
  dup   v26.2d, v26.d[0]
  mov   x9, #0xBCD2
  movk  x9, #0xDD7A, lsl #16
  movk  x9, #0x232B, lsl #32
  movk  x9, #0xC086, lsl #48
  fmov  d27, x9
  dup   v27.2d, v27.d[0]

.Lexpf64v_loop2:
  cmp   x2, #2
  b.lo  .Lexpf64v_tail
  ldp   x3, x4, [x0], #16
  fmov  d0, x3
  fmov  d1, x4
  ins   v0.d[1], v1.d[0]
  fmin  v0.2d, v0.2d, v26.2d
  fmax  v0.2d, v0.2d, v27.2d
  fmul  v1.2d, v0.2d, v16.2d
  frintn v1.2d, v1.2d
  fmul  v2.2d, v1.2d, v17.2d
  fsub  v0.2d, v0.2d, v2.2d
  fmul  v2.2d, v1.2d, v18.2d
  fsub  v0.2d, v0.2d, v2.2d
  fmul  v3.2d, v19.2d, v0.2d
  fadd  v3.2d, v3.2d, v20.2d
  fmul  v3.2d, v3.2d, v0.2d
  fadd  v3.2d, v3.2d, v21.2d
  fmul  v3.2d, v3.2d, v0.2d
  fadd  v3.2d, v3.2d, v22.2d
  fmul  v3.2d, v3.2d, v0.2d
  fadd  v3.2d, v3.2d, v23.2d
  fmul  v3.2d, v3.2d, v0.2d
  fadd  v3.2d, v3.2d, v24.2d
  fmul  v3.2d, v3.2d, v0.2d
  fadd  v3.2d, v3.2d, v24.2d
  fcvtzs v1.2d, v1.2d
  // clamp n to [-1022,1023]
  mov   x9, #1023
  dup   v0.2d, x9
  smin  v1.2d, v1.2d, v0.2d
  mov   x9, #-1022
  dup   v0.2d, x9
  smax  v1.2d, v1.2d, v0.2d
  shl   v1.2d, v1.2d, #52
  mov   v0.16b, v3.16b
  add   v0.2d, v0.2d, v1.2d
  umov  x3, v0.d[0]
  umov  x4, v0.d[1]
  stp   x3, x4, [x1], #16
  sub   x2, x2, #2
  b     .Lexpf64v_loop2
.Lexpf64v_tail:
  cbz   x2, .Lexpf64v_done
.Lexpf64v_tail_loop:
  ldr   d0, [x0], #8
  fmin  d0, d0, d26
  fmax  d0, d0, d27
  fmul  d1, d0, d16
  frintn d1, d1
  fmul  d2, d1, d17
  fsub  d0, d0, d2
  fmul  d2, d1, d18
  fsub  d0, d0, d2
  fmul  d3, d19, d0
  fadd  d3, d3, d20
  fmul  d3, d3, d0
  fadd  d3, d3, d21
  fmul  d3, d3, d0
  fadd  d3, d3, d22
  fmul  d3, d3, d0
  fadd  d3, d3, d23
  fmul  d3, d3, d0
  fadd  d3, d3, d24
  fmul  d3, d3, d0
  fadd  d3, d3, d24
  fcvtzs x3, d1
  mov   x4, #1023
  cmp   x3, x4
  csel  x3, x3, x4, lt
  mov   x4, #-1022
  cmp   x3, x4
  csel  x3, x3, x4, gt
  fmov  x5, d3
  add   x5, x5, x3, lsl #52
  fmov  d3, x5
  str   d3, [x1], #8
  subs  x2, x2, #1
  b.ne  .Lexpf64v_tail_loop
.Lexpf64v_done:
  ret
end;
