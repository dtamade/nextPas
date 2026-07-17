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
