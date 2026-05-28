unit nextpas.core.simd.sse42;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === SSE4.2 Backend Implementation ===
// Provides SIMD-accelerated operations using x86-64 SSE4.2 instructions.
// SSE4.2 focuses on string processing and CRC32 hardware acceleration.
//
// Key SSE4.2 instructions:
// - CRC32: Hardware CRC32C (Castagnoli polynomial) computation
// - PCMPESTRI/PCMPESTRM: Explicit-length string compare returning index/mask
// - PCMPISTRI/PCMPISTRM: Implicit-length string compare (null-terminated)
// - PCMPGTQ: 64-bit signed integer greater-than comparison
//
// Note: POPCNT is often associated with SSE4.2 but is actually a separate
// CPUID flag. It may or may not be present on SSE4.2 CPUs.

procedure RegisterSSE42Backend;

// === CRC32 Hardware Functions (Public API) ===
// These use the CRC32C polynomial (iSCSI polynomial: 0x1EDC6F41)

function CRC32C_8(crc: UInt32; value: Byte): UInt32;
function CRC32C_16(crc: UInt32; value: UInt16): UInt32;
function CRC32C_32(crc: UInt32; value: UInt32): UInt32;
function CRC32C_64(crc: UInt64; value: UInt64): UInt64;

// CRC32C for byte buffer
function CRC32C_Buffer(const data: Pointer; len: SizeUInt; initial: UInt32 = $FFFFFFFF): UInt32;

// === String Operations (Public API) ===
// Find first occurrence of any byte from 'needles' in 'haystack'
// Returns index (0-based) or -1 if not found
function FindFirstOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
                            const needles: PAnsiChar; needlesLen: Integer): Integer;

// Find first byte NOT in 'chars' set
function FindFirstNotOf_SSE42(const str: PAnsiChar; strLen: Integer;
                               const chars: PAnsiChar; charsLen: Integer): Integer;

implementation

uses
  nextpas.core.simd.cpuinfo;

const
  CRC32C_REFLECTED_POLY = UInt32($82F63B78);

// Shared chunked PCMPESTRI scan for positive and negative byte-set searches.
function FindFirstPcmpestri_SSE42(const aHaystack: PAnsiChar; aHaystackLen: Integer;
  const aNeedles: PAnsiChar; aNeedlesLen: Integer; const aNegativePolarity: Boolean): Integer; inline;
var
  LIndex: Integer;
  LHaystackLen, LNeedlesLen: Integer;
  LHaystackPtr, LNeedlesPtr: PAnsiChar;
  LFound: Boolean;
begin
  Result := -1;
  if (aHaystack = nil) or (aHaystackLen <= 0) or (aNeedles = nil) or (aNeedlesLen <= 0) then
    Exit;

  LNeedlesLen := aNeedlesLen;
  if LNeedlesLen > 16 then
    LNeedlesLen := 16;

  LHaystackPtr := aHaystack;
  LNeedlesPtr := aNeedles;
  LHaystackLen := aHaystackLen;
  LIndex := 0;
  LFound := False;

  while LHaystackLen > 0 do
  begin
    if aNegativePolarity then
    begin
      asm
        mov    rax, LHaystackPtr
        mov    rdx, LNeedlesPtr
        mov    ecx, LHaystackLen
        mov    r8d, LNeedlesLen

        movdqu xmm0, [rdx]
        movdqu xmm1, [rax]

        mov    eax, r8d
        mov    edx, ecx
        cmp    edx, 16
        jle    @use_edx
        mov    edx, 16
      @use_edx:

        // Negative polarity can surface zero-padded tail bytes as a synthetic
        // not-in-set hit at the explicit chunk boundary; reject that sentinel.
        db $66, $0F, $3A, $61, $C1, $10

        jnc    @no_match
        cmp    ecx, edx
        jge    @no_match
        mov    [LIndex], ecx
        mov    byte ptr [LFound], 1
        jmp    @done

      @no_match:
        mov    byte ptr [LFound], 0

      @done:
      end;
    end
    else
    begin
      asm
        mov    rax, LHaystackPtr
        mov    rdx, LNeedlesPtr
        mov    ecx, LHaystackLen
        mov    r8d, LNeedlesLen

        movdqu xmm0, [rdx]
        movdqu xmm1, [rax]

        mov    eax, r8d
        mov    edx, ecx
        cmp    edx, 16
        jle    @use_edx
        mov    edx, 16
      @use_edx:

        db $66, $0F, $3A, $61, $C1, $00

        jnc    @no_match
        mov    [LIndex], ecx
        mov    byte ptr [LFound], 1
        jmp    @done

      @no_match:
        mov    byte ptr [LFound], 0

      @done:
      end;
    end;

    if LFound then
    begin
      Result := (LHaystackPtr - aHaystack) + LIndex;
      Exit;
    end;

    if LHaystackLen <= 16 then
      Break;
    Inc(LHaystackPtr, 16);
    Dec(LHaystackLen, 16);
  end;
end;

// === CRC32C Hardware Implementation ===
// SSE4.2 provides CRC32 instruction with Castagnoli polynomial

function CRC32C_UpdateByte_Scalar(crc: UInt32; value: Byte): UInt32; inline;
var
  LBit: Integer;
begin
  Result := crc xor UInt32(value);
  for LBit := 0 to 7 do
    if (Result and 1) <> 0 then
      Result := (Result shr 1) xor CRC32C_REFLECTED_POLY
    else
      Result := Result shr 1;
end;

function CRC32C_UpdateWord_Scalar(crc: UInt32; value: UInt16): UInt32; inline;
begin
  Result := CRC32C_UpdateByte_Scalar(crc, Byte(value and $FF));
  Result := CRC32C_UpdateByte_Scalar(Result, Byte((value shr 8) and $FF));
end;

function CRC32C_UpdateDWord_Scalar(crc: UInt32; value: UInt32): UInt32; inline;
begin
  Result := CRC32C_UpdateWord_Scalar(crc, UInt16(value and $FFFF));
  Result := CRC32C_UpdateWord_Scalar(Result, UInt16((value shr 16) and $FFFF));
end;

function CRC32C_UpdateQWord_Scalar(crc: UInt32; value: UInt64): UInt32; inline;
begin
  Result := CRC32C_UpdateDWord_Scalar(crc, UInt32(value and $FFFFFFFF));
  Result := CRC32C_UpdateDWord_Scalar(Result, UInt32(value shr 32));
end;

{$IFDEF DARWIN}
function CRC32C_8(crc: UInt32; value: Byte): UInt32;
begin
  Result := CRC32C_UpdateByte_Scalar(crc, value);
end;

function CRC32C_16(crc: UInt32; value: UInt16): UInt32;
begin
  Result := CRC32C_UpdateWord_Scalar(crc, value);
end;

function CRC32C_32(crc: UInt32; value: UInt32): UInt32;
begin
  Result := CRC32C_UpdateDWord_Scalar(crc, value);
end;

function CRC32C_64(crc: UInt64; value: UInt64): UInt64;
begin
  Result := CRC32C_UpdateQWord_Scalar(UInt32(crc), value);
end;
{$ELSE}
function CRC32C_8(crc: UInt32; value: Byte): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // RDI = crc, RSI = value
  mov    eax, edi
  movzx  esi, sil
  crc32  eax, sil
  {$ELSE}
  // RCX = crc, RDX = value
  mov    eax, ecx
  crc32  eax, dl
  {$ENDIF}
end;

function CRC32C_16(crc: UInt32; value: UInt16): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov    eax, edi
  crc32  eax, si
  {$ELSE}
  mov    eax, ecx
  crc32  eax, dx
  {$ENDIF}
end;

function CRC32C_32(crc: UInt32; value: UInt32): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov    eax, edi
  crc32  eax, esi
  {$ELSE}
  mov    eax, ecx
  crc32  eax, edx
  {$ENDIF}
end;

function CRC32C_64(crc: UInt64; value: UInt64): UInt64; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov    rax, rdi
  crc32  rax, rsi
  {$ELSE}
  mov    rax, rcx
  crc32  rax, rdx
  {$ENDIF}
end;
{$ENDIF}

// CRC32C for byte buffer - optimized with 64-bit processing
function CRC32C_Buffer(const data: Pointer; len: SizeUInt; initial: UInt32): UInt32;
var
  p: PByte;
  remaining: SizeUInt;
  crc64: UInt64;
begin
  if (data = nil) or (len = 0) then
  begin
    Result := initial;
    Exit;
  end;

  p := PByte(data);
  remaining := len;
  crc64 := initial;

  {$IFDEF DARWIN}
  while remaining >= 8 do
  begin
    crc64 := CRC32C_64(crc64, PUInt64(p)^);
    Inc(p, 8);
    Dec(remaining, 8);
  end;

  if remaining >= 4 then
  begin
    crc64 := CRC32C_32(UInt32(crc64), PUInt32(p)^);
    Inc(p, 4);
    Dec(remaining, 4);
  end;

  if remaining >= 2 then
  begin
    crc64 := CRC32C_16(UInt32(crc64), PUInt16(p)^);
    Inc(p, 2);
    Dec(remaining, 2);
  end;

  if remaining >= 1 then
    crc64 := CRC32C_8(UInt32(crc64), p^);
  {$ELSE}
  // Process 8 bytes at a time
  while remaining >= 8 do
  begin
    asm
      mov    rax, crc64
      mov    rdx, p
      mov    rdx, [rdx]      // Load 8 bytes
      crc32  rax, rdx
      mov    crc64, rax
    end;
    Inc(p, 8);
    Dec(remaining, 8);
  end;

  // Process 4 bytes
  if remaining >= 4 then
  begin
    asm
      mov    eax, dword ptr [crc64]
      mov    rdx, p
      mov    edx, [rdx]
      crc32  eax, edx
      mov    dword ptr [crc64], eax
    end;
    Inc(p, 4);
    Dec(remaining, 4);
  end;

  // Process 2 bytes
  if remaining >= 2 then
  begin
    asm
      mov    eax, dword ptr [crc64]
      mov    rdx, p
      movzx  edx, word ptr [rdx]
      crc32  eax, dx
      mov    dword ptr [crc64], eax
    end;
    Inc(p, 2);
    Dec(remaining, 2);
  end;

  // Process remaining byte
  if remaining >= 1 then
  begin
    asm
      mov    eax, dword ptr [crc64]
      mov    rdx, p
      movzx  edx, byte ptr [rdx]
      crc32  eax, dl
      mov    dword ptr [crc64], eax
    end;
  end;
  {$ENDIF}

  Result := UInt32(crc64);
end;

// === String Operations using PCMPESTRI/PCMPISTRM ===
// PCMPESTRI: Packed Compare Explicit-length String, Return Index
// Immediate byte encoding:
//   [1:0] = Source data format: 00=unsigned bytes, 01=unsigned words, 10=signed bytes, 11=signed words
//   [3:2] = Aggregation: 00=equal any, 01=ranges, 10=equal each, 11=equal ordered
//   [5:4] = Polarity: 00=positive, 01=negative, 10=masked positive, 11=masked negative
//   [6]   = Output selection: 0=least significant, 1=most significant

// Find first occurrence of any byte from 'needles' in 'haystack'
// Uses "equal any" mode (imm8 = 0x00)
function FindFirstOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
                            const needles: PAnsiChar; needlesLen: Integer): Integer;
begin
  Result := FindFirstPcmpestri_SSE42(haystack, haystackLen, needles, needlesLen, False);
end;

// Find first byte NOT in character set
// Uses "equal any" with negative polarity (imm8 = 0x10)
function FindFirstNotOf_SSE42(const str: PAnsiChar; strLen: Integer;
                               const chars: PAnsiChar; charsLen: Integer): Integer;
begin
  Result := -1;
  if (str = nil) or (strLen <= 0) then
    Exit;
  if (chars = nil) or (charsLen <= 0) then
  begin
    // No chars to match means first char is "not in set"
    Result := 0;
    Exit;
  end;

  Result := FindFirstPcmpestri_SSE42(str, strLen, chars, charsLen, True);
end;

// === SSE4.2 64-bit Comparison ===

function SSE42CmpGtI64x2(const a, b: TVecI64x2): TMask2;
var
  pa, pb: Pointer;
  maskVal: Integer;
begin
  // Win64 ABI: avoid addressing const records directly in inline asm.
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpgtq  xmm0, xmm1
    movmskpd eax, xmm0
    mov      maskVal, eax
  end;
  Result := TMask2(maskVal);
end;

// BytesIndexOf_SSE42 - 使用 pcmpestri 做子串搜索
// pcmpestri imm=$0C: equal ordered (substring match), 返回最低匹配位置
function BytesIndexOf_SSE42(haystack: Pointer; haystackLen: SizeUInt;
  needle: Pointer; needleLen: SizeUInt): PtrInt;
var
  ph: PByte;
  i: SizeUInt;
  LIdx: Integer;
  LHayLen, LNeedLen: Integer;
begin
  Result := -1;
  if (haystackLen = 0) or (needleLen = 0) or (haystack = nil) or (needle = nil) then Exit;
  if needleLen > haystackLen then Exit;
  if needleLen > 16 then
  begin
    // pcmpestri 只支持 needle <= 16 字节，回退标量
    ph := PByte(haystack);
    for i := 0 to haystackLen - needleLen do
    begin
      if CompareByte(ph[i], PByte(needle)^, needleLen) = 0 then
        Exit(PtrInt(i));
    end;
    Exit;
  end;

  ph := PByte(haystack);
  i := 0;

  {$PUSH}{$ASMMODE INTEL}
  // 加载 needle 到 xmm0 (最多 16 字节)
  asm
    mov rax, needle
    movdqu xmm0, [rax]
  end;

  while i + 16 <= haystackLen do
  begin
    LHayLen := 16;
    if i + 16 > haystackLen then
      LHayLen := Integer(haystackLen - i);
    LNeedLen := Integer(needleLen);
    asm
      mov rax, ph
      add rax, i
      movdqu xmm1, [rax]
      mov eax, LNeedLen
      mov edx, LHayLen
      // pcmpestri xmm0, xmm1, $0C (equal ordered, unsigned bytes)
      db $66, $0F, $3A, $61, $C1, $0C
      mov LIdx, ecx
      // CF=1 if match found (IntRes2 != 0)
    end;
    if LIdx < LHayLen then
    begin
      // 验证完整匹配（pcmpestri 可能给出部分匹配）
      if i + SizeUInt(LIdx) + needleLen <= haystackLen then
      begin
        if CompareByte(ph[i + SizeUInt(LIdx)], PByte(needle)^, needleLen) = 0 then
        begin
          Result := PtrInt(i + SizeUInt(LIdx));
          Exit;
        end;
      end;
      // 不是完整匹配，从下一个位置继续
      Inc(i, SizeUInt(LIdx) + 1);
      Continue;
    end;
    Inc(i, 16);
  end;
  {$POP}

  // 标量处理尾部
  while i <= haystackLen - needleLen do
  begin
    if CompareByte(ph[i], PByte(needle)^, needleLen) = 0 then
      Exit(PtrInt(i));
    Inc(i);
  end;
end;

// === Backend Registration ===

{$I nextpas.core.simd.sse42.register.inc}


end.
