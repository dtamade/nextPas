{**
 * Unit: nextpas.core.tls.tls13.chacha20poly1305
 * Purpose: TLS 1.3 所需 ChaCha20-Poly1305 AEAD（纯 Pascal）
 *
 * 参考：RFC 8439
 * - ChaCha20 stream cipher
 * - Poly1305 one-time authenticator
 * - AEAD construction (AAD || pad || ciphertext || pad || lens)
 *}

unit nextpas.core.tls.tls13.chacha20poly1305;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface


function TryChaCha20Poly1305Encrypt(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;

function TryChaCha20Poly1305Decrypt(
  const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes;
  out APlaintext: TBytes
): Boolean;

function TryChaCha20Poly1305EncryptCombined(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes
): Boolean;

function TryChaCha20Poly1305DecryptCombined(
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes
): Boolean;

implementation

uses nextpas.core.crypto.constant_time;

const
  CHACHA20_KEY_SIZE = 32;
  CHACHA20_NONCE_SIZE = 12;
  CHACHA20_BLOCK_SIZE = 64;
  POLY1305_KEY_SIZE = 32;
  POLY1305_TAG_SIZE = 16;
  POLY1305_MASK_26 = $3FFFFFF;

{$IFDEF CPUX86_64}
var
  GChaCha20AVX2Checked: Boolean = False;
  GChaCha20HasAVX2: Boolean = False;

function ChaCha20DetectAVX2: Boolean;
var
  LEcx, LEbx: DWord;
begin
  if GChaCha20AVX2Checked then
    Exit(GChaCha20HasAVX2);
  LEcx := 0; LEbx := 0;
  asm
    push %rbx
    movl $1, %eax
    cpuid
    movl %ecx, LEcx
    pop %rbx
  end ['eax', 'ecx', 'edx'];
  if (LEcx and (1 shl 28)) = 0 then
  begin
    GChaCha20HasAVX2 := False;
    GChaCha20AVX2Checked := True;
    Exit(False);
  end;
  asm
    push %rbx
    movl $7, %eax
    xorl %ecx, %ecx
    cpuid
    movl %ebx, LEbx
    pop %rbx
  end ['eax', 'ecx', 'edx'];
  GChaCha20HasAVX2 := (LEbx and (1 shl 5)) <> 0;
  GChaCha20AVX2Checked := True;
  Result := GChaCha20HasAVX2;
end;
{$ENDIF}

function RotateLeft32(AValue: UInt32; ACount: Integer): UInt32; inline;
begin
  Result := (AValue shl ACount) or (AValue shr (32 - ACount));
end;

function Load32LE(const AData: TBytes; AOffset: Integer): UInt32; inline;
begin
  Result :=
    UInt32(AData[AOffset]) or
    (UInt32(AData[AOffset + 1]) shl 8) or
    (UInt32(AData[AOffset + 2]) shl 16) or
    (UInt32(AData[AOffset + 3]) shl 24);
end;

function Load32LEFromBytes(const AData: array of Byte; AOffset: Integer): UInt32;
begin
  Result :=
    UInt32(AData[AOffset]) or
    (UInt32(AData[AOffset + 1]) shl 8) or
    (UInt32(AData[AOffset + 2]) shl 16) or
    (UInt32(AData[AOffset + 3]) shl 24);
end;

procedure Store32LE(var AData: TBytes; AOffset: Integer; AValue: UInt32); inline;
begin
  AData[AOffset] := Byte(AValue and $FF);
  AData[AOffset + 1] := Byte((AValue shr 8) and $FF);
  AData[AOffset + 2] := Byte((AValue shr 16) and $FF);
  AData[AOffset + 3] := Byte((AValue shr 24) and $FF);
end;

procedure Store64LE(var AData: TBytes; AOffset: Integer; AValue: QWord); inline;
var
  I: Integer;
begin
  for I := 0 to 7 do
    AData[AOffset + I] := Byte((AValue shr (8 * I)) and $FF);
end;

procedure QuarterRound(var A, B, C, D: UInt32); inline;
begin
  A := A + B;
  D := RotateLeft32(D xor A, 16);
  C := C + D;
  B := RotateLeft32(B xor C, 12);
  A := A + B;
  D := RotateLeft32(D xor A, 8);
  C := C + D;
  B := RotateLeft32(B xor C, 7);
end;

function ChaCha20Block(const AKey, ANonce: TBytes; ACounter: UInt32): TBytes;
var
  LState: array[0..15] of UInt32;
  LWork: array[0..15] of UInt32;
  I: Integer;
begin
  SetLength(Result, CHACHA20_BLOCK_SIZE);

  LState[0] := $61707865;
  LState[1] := $3320646E;
  LState[2] := $79622D32;
  LState[3] := $6B206574;

  for I := 0 to 7 do
    LState[4 + I] := Load32LE(AKey, I * 4);

  LState[12] := ACounter;
  LState[13] := Load32LE(ANonce, 0);
  LState[14] := Load32LE(ANonce, 4);
  LState[15] := Load32LE(ANonce, 8);

  for I := 0 to 15 do
    LWork[I] := LState[I];

  for I := 0 to 9 do
  begin
    QuarterRound(LWork[0], LWork[4], LWork[8], LWork[12]);
    QuarterRound(LWork[1], LWork[5], LWork[9], LWork[13]);
    QuarterRound(LWork[2], LWork[6], LWork[10], LWork[14]);
    QuarterRound(LWork[3], LWork[7], LWork[11], LWork[15]);

    QuarterRound(LWork[0], LWork[5], LWork[10], LWork[15]);
    QuarterRound(LWork[1], LWork[6], LWork[11], LWork[12]);
    QuarterRound(LWork[2], LWork[7], LWork[8], LWork[13]);
    QuarterRound(LWork[3], LWork[4], LWork[9], LWork[14]);
  end;

  for I := 0 to 15 do
    Store32LE(Result, I * 4, LWork[I] + LState[I]);
end;

function ChaCha20Xor(const AKey, ANonce: TBytes; ACounter: UInt32; const AInput: TBytes): TBytes;
{$IFDEF CPUX86_64}
{$ASMMODE ATT}
const
  ROT16_MASK: array[0..15] of Byte = (2,3,0,1, 6,7,4,5, 10,11,8,9, 14,15,12,13);
  ROT8_MASK: array[0..15] of Byte = (3,0,1,2, 7,4,5,6, 11,8,9,10, 15,12,13,14);
var
  LState: array[0..15] of UInt32;
  LBlock: array[0..31] of UInt32;
  LOffset, LBlockLen, I: Integer;
begin
  SetLength(Result, Length(AInput));
  LOffset := 0;

  // Setup base state once
  LState[0] := $61707865; LState[1] := $3320646E;
  LState[2] := $79622D32; LState[3] := $6B206574;
  for I := 0 to 7 do
    LState[4 + I] := Load32LE(AKey, I * 4);
  LState[13] := Load32LE(ANonce, 0);
  LState[14] := Load32LE(ANonce, 4);
  LState[15] := Load32LE(ANonce, 8);

  // AVX2 4-block path (256 bytes at a time) — guarded by CPUID
  if ChaCha20DetectAVX2 then
  begin
    {$I nextpas.core.crypto.chacha20.4block.x86_64.inc}
  end;

  // AVX2 dual-block path: process 2 blocks (128 bytes) at a time
  while ChaCha20DetectAVX2 and (LOffset + 128 <= Length(AInput)) do
  begin
    LState[12] := ACounter;
    asm
      // Load state into XMM, then broadcast to YMM with counter adjustment
      movdqu LState+0, %xmm0
      movdqu LState+16, %xmm1
      movdqu LState+32, %xmm2
      movdqu LState+48, %xmm3

      // Create block1 row3 with counter+1
      movdqa %xmm3, %xmm4
      movq $1, %rax
      movd %eax, %xmm5
      paddd %xmm5, %xmm4    // xmm4 = row3 with counter+1

      // Broadcast to YMM: [block0 | block1]
      vinserti128 $1, %xmm0, %ymm0, %ymm0   // row0: same for both
      vinserti128 $1, %xmm1, %ymm1, %ymm1   // row1: same
      vinserti128 $1, %xmm2, %ymm2, %ymm2   // row2: same
      vinserti128 $1, %xmm4, %ymm3, %ymm3   // row3: [ctr | ctr+1]

      // Save original for final add
      vmovdqa %ymm0, %ymm8
      vmovdqa %ymm1, %ymm9
      vmovdqa %ymm2, %ymm10
      vmovdqa %ymm3, %ymm11

      // Load rotation masks (broadcast 128→256)
      vbroadcasti128 ROT16_MASK, %ymm12
      vbroadcasti128 ROT8_MASK, %ymm13

      // 10 double-rounds
      movq $10, %rcx
    .Lavx2_round:
      // Column round
      vpaddd %ymm1, %ymm0, %ymm0
      vpxor %ymm0, %ymm3, %ymm3
      vpshufb %ymm12, %ymm3, %ymm3
      vpaddd %ymm3, %ymm2, %ymm2
      vpxor %ymm2, %ymm1, %ymm1
      vpslld $12, %ymm1, %ymm7
      vpsrld $20, %ymm1, %ymm1
      vpor %ymm7, %ymm1, %ymm1
      vpaddd %ymm1, %ymm0, %ymm0
      vpxor %ymm0, %ymm3, %ymm3
      vpshufb %ymm13, %ymm3, %ymm3
      vpaddd %ymm3, %ymm2, %ymm2
      vpxor %ymm2, %ymm1, %ymm1
      vpslld $7, %ymm1, %ymm7
      vpsrld $25, %ymm1, %ymm1
      vpor %ymm7, %ymm1, %ymm1

      // Diagonal setup
      vpshufd $0x39, %ymm1, %ymm1
      vpshufd $0x4E, %ymm2, %ymm2
      vpshufd $0x93, %ymm3, %ymm3

      // Diagonal round
      vpaddd %ymm1, %ymm0, %ymm0
      vpxor %ymm0, %ymm3, %ymm3
      vpshufb %ymm12, %ymm3, %ymm3
      vpaddd %ymm3, %ymm2, %ymm2
      vpxor %ymm2, %ymm1, %ymm1
      vpslld $12, %ymm1, %ymm7
      vpsrld $20, %ymm1, %ymm1
      vpor %ymm7, %ymm1, %ymm1
      vpaddd %ymm1, %ymm0, %ymm0
      vpxor %ymm0, %ymm3, %ymm3
      vpshufb %ymm13, %ymm3, %ymm3
      vpaddd %ymm3, %ymm2, %ymm2
      vpxor %ymm2, %ymm1, %ymm1
      vpslld $7, %ymm1, %ymm7
      vpsrld $25, %ymm1, %ymm1
      vpor %ymm7, %ymm1, %ymm1

      // Un-rotate
      vpshufd $0x93, %ymm1, %ymm1
      vpshufd $0x4E, %ymm2, %ymm2
      vpshufd $0x39, %ymm3, %ymm3

      decq %rcx
      jnz .Lavx2_round

      // Add original state
      vpaddd %ymm8, %ymm0, %ymm0
      vpaddd %ymm9, %ymm1, %ymm1
      vpaddd %ymm10, %ymm2, %ymm2
      vpaddd %ymm11, %ymm3, %ymm3

      // Store 2 blocks (128 bytes) interleaved: block0 then block1
      // Extract low 128 (block0)
      vmovdqu %xmm0, LBlock+0
      vmovdqu %xmm1, LBlock+16
      vmovdqu %xmm2, LBlock+32
      vmovdqu %xmm3, LBlock+48
      // Extract high 128 (block1)
      vextracti128 $1, %ymm0, LBlock+64
      vextracti128 $1, %ymm1, LBlock+80
      vextracti128 $1, %ymm2, LBlock+96
      vextracti128 $1, %ymm3, LBlock+112

      vzeroupper
    end ['rax', 'rcx',
      'ymm0','ymm1','ymm2','ymm3','ymm7','ymm8','ymm9','ymm10','ymm11','ymm12','ymm13'];

    // XOR 128 bytes
    for I := 0 to 31 do
      PUInt32(@Result[LOffset + I*4])^ := PUInt32(@AInput[LOffset + I*4])^ xor LBlock[I];

    Inc(ACounter, 2);
    Inc(LOffset, 128);
  end;

  // SSE2 single-block path for remaining
  while LOffset < Length(AInput) do
  begin
    LState[12] := ACounter;

    // SSE2 ChaCha20 double-round (20 rounds = 10 double-rounds)
    asm
      // Load state rows into xmm0-xmm3
      movdqu LState+0, %xmm0      // row0: s[0..3]
      movdqu LState+16, %xmm1     // row1: s[4..7]
      movdqu LState+32, %xmm2     // row2: s[8..11]
      movdqu LState+48, %xmm3     // row3: s[12..15]

      // Save original state for final add
      movdqa %xmm0, %xmm8
      movdqa %xmm1, %xmm9
      movdqa %xmm2, %xmm10
      movdqa %xmm3, %xmm11

      // Load rotation masks
      movdqu ROT16_MASK, %xmm12
      movdqu ROT8_MASK, %xmm13

      // 10 double-rounds
      movq $10, %rcx
    .Lround_loop:
      // Column round: QR(0,4,8,12), QR(1,5,9,13), QR(2,6,10,14), QR(3,7,11,15)
      // a += b
      paddd %xmm1, %xmm0
      // d ^= a; d <<<= 16
      pxor %xmm0, %xmm3
      pshufb %xmm12, %xmm3
      // c += d
      paddd %xmm3, %xmm2
      // b ^= c; b <<<= 12
      movdqa %xmm2, %xmm7
      pxor %xmm7, %xmm1
      movdqa %xmm1, %xmm7
      pslld $12, %xmm1
      psrld $20, %xmm7
      por %xmm7, %xmm1
      // a += b
      paddd %xmm1, %xmm0
      // d ^= a; d <<<= 8
      pxor %xmm0, %xmm3
      pshufb %xmm13, %xmm3
      // c += d
      paddd %xmm3, %xmm2
      // b ^= c; b <<<= 7
      movdqa %xmm2, %xmm7
      pxor %xmm7, %xmm1
      movdqa %xmm1, %xmm7
      pslld $7, %xmm1
      psrld $25, %xmm7
      por %xmm7, %xmm1

      // Diagonal round: rotate rows for diagonal access
      // b = row1 rotated left by 1 word
      pshufd $0x39, %xmm1, %xmm1  // 0,1,2,3 → 1,2,3,0
      // c = row2 rotated left by 2 words
      pshufd $0x4E, %xmm2, %xmm2  // 0,1,2,3 → 2,3,0,1
      // d = row3 rotated left by 3 words
      pshufd $0x93, %xmm3, %xmm3  // 0,1,2,3 → 3,0,1,2

      // QR on diagonals (same ops as column round)
      paddd %xmm1, %xmm0
      pxor %xmm0, %xmm3
      pshufb %xmm12, %xmm3
      paddd %xmm3, %xmm2
      movdqa %xmm2, %xmm7
      pxor %xmm7, %xmm1
      movdqa %xmm1, %xmm7
      pslld $12, %xmm1
      psrld $20, %xmm7
      por %xmm7, %xmm1
      paddd %xmm1, %xmm0
      pxor %xmm0, %xmm3
      pshufb %xmm13, %xmm3
      paddd %xmm3, %xmm2
      movdqa %xmm2, %xmm7
      pxor %xmm7, %xmm1
      movdqa %xmm1, %xmm7
      pslld $7, %xmm1
      psrld $25, %xmm7
      por %xmm7, %xmm1

      // Un-rotate rows
      pshufd $0x93, %xmm1, %xmm1  // 1,2,3,0 → 0,1,2,3
      pshufd $0x4E, %xmm2, %xmm2  // 2,3,0,1 → 0,1,2,3
      pshufd $0x39, %xmm3, %xmm3  // 3,0,1,2 → 0,1,2,3

      decq %rcx
      jnz .Lround_loop

      // Add original state
      paddd %xmm8, %xmm0
      paddd %xmm9, %xmm1
      paddd %xmm10, %xmm2
      paddd %xmm11, %xmm3

      // Store result
      movdqu %xmm0, LBlock+0
      movdqu %xmm1, LBlock+16
      movdqu %xmm2, LBlock+32
      movdqu %xmm3, LBlock+48
    end ['rcx', 'xmm0','xmm1','xmm2','xmm3','xmm7','xmm8','xmm9','xmm10','xmm11','xmm12','xmm13'];

    LBlockLen := CHACHA20_BLOCK_SIZE;
    if LOffset + LBlockLen > Length(AInput) then
      LBlockLen := Length(AInput) - LOffset;

    I := 0;
    while I + 3 < LBlockLen do
    begin
      PUInt32(@Result[LOffset + I])^ := PUInt32(@AInput[LOffset + I])^ xor LBlock[I div 4];
      Inc(I, 4);
    end;
    while I < LBlockLen do
    begin
      Result[LOffset + I] := AInput[LOffset + I] xor PByte(PByte(@LBlock[0]) + I)^;
      Inc(I);
    end;

    Inc(ACounter);
    Inc(LOffset, LBlockLen);
  end;
end;
{$ELSE}

  while LOffset < Length(AInput) do
  begin
    LState[0] := $61707865;
    LState[1] := $3320646E;
    LState[2] := $79622D32;
    LState[3] := $6B206574;
    for I := 0 to 7 do
      LState[4 + I] := Load32LE(AKey, I * 4);
    LState[12] := ACounter;
    LState[13] := Load32LE(ANonce, 0);
    LState[14] := Load32LE(ANonce, 4);
    LState[15] := Load32LE(ANonce, 8);

    for I := 0 to 15 do
      LWork[I] := LState[I];

    for I := 0 to 9 do
    begin
      QuarterRound(LWork[0], LWork[4], LWork[8], LWork[12]);
      QuarterRound(LWork[1], LWork[5], LWork[9], LWork[13]);
      QuarterRound(LWork[2], LWork[6], LWork[10], LWork[14]);
      QuarterRound(LWork[3], LWork[7], LWork[11], LWork[15]);
      QuarterRound(LWork[0], LWork[5], LWork[10], LWork[15]);
      QuarterRound(LWork[1], LWork[6], LWork[11], LWork[12]);
      QuarterRound(LWork[2], LWork[7], LWork[8], LWork[13]);
      QuarterRound(LWork[3], LWork[4], LWork[9], LWork[14]);
    end;

    for I := 0 to 15 do
      LBlock[I] := LWork[I] + LState[I];

    LBlockLen := CHACHA20_BLOCK_SIZE;
    if LOffset + LBlockLen > Length(AInput) then
      LBlockLen := Length(AInput) - LOffset;

    // XOR in 4-byte chunks
    I := 0;
    while I + 3 < LBlockLen do
    begin
      PUInt32(@Result[LOffset + I])^ := PUInt32(@AInput[LOffset + I])^ xor PUInt32(@LBlock[I div 4])^;
      Inc(I, 4);
    end;
    // Remaining bytes
    while I < LBlockLen do
    begin
      Result[LOffset + I] := AInput[LOffset + I] xor PByte(PByte(@LBlock[0]) + I)^;
      Inc(I);
    end;

    Inc(ACounter);
    Inc(LOffset, LBlockLen);
  end;
end;
{$ENDIF}

function Poly1305MAC(const AKey, AMessage: TBytes): TBytes;
{$IFDEF CPUX86_64}
{$ASMMODE ATT}
type
  TPoly1305State = record
    H0, H1, H2: UInt64;
    R0, R1, R2: UInt64;
    S1, S2: UInt64;
  end;
var
  LState: TPoly1305State;
  LR128Lo, LR128Hi: UInt64;
  LOffset: Integer;
  LBlock: array[0..15] of Byte;
  D0Lo, D0Hi, D1Lo, D1Hi, D2Lo, D2Hi: UInt64;
  C: UInt64;
  G0, G1: UInt64;
  G2: Int64;
  FLo, FHi: UInt64;
begin
  SetLength(Result, POLY1305_TAG_SIZE);

  LR128Lo := PUInt64(@AKey[0])^ and $0FFFFFFC0FFFFFFF;
  LR128Hi := PUInt64(@AKey[8])^ and $0FFFFFFC0FFFFFFC;
  LState.R0 := LR128Lo and $0FFFFFFFFFFF;
  LState.R1 := ((LR128Lo shr 44) or (LR128Hi shl 20)) and $0FFFFFFFFFFF;
  LState.R2 := (LR128Hi shr 24) and $3FFFFFFFFFF;
  LState.S1 := LState.R1 * 20;
  LState.S2 := LState.R2 * 20;
  LState.H0 := 0; LState.H1 := 0; LState.H2 := 0;

  LOffset := 0;
  while LOffset + 16 <= Length(AMessage) do
  begin
    // Add message block
    LState.H0 := LState.H0 + (PUInt64(@AMessage[LOffset])^ and $0FFFFFFFFFFF);
    LState.H1 := LState.H1 + (((PUInt64(@AMessage[LOffset])^ shr 44) or (PUInt64(@AMessage[LOffset+8])^ shl 20)) and $0FFFFFFFFFFF);
    LState.H2 := LState.H2 + (((PUInt64(@AMessage[LOffset+8])^ shr 24) and $3FFFFFFFFFF) or (UInt64(1) shl 40));

    // 9 multiplies via mulq
    asm
      leaq LState, %rcx
      movq 0(%rcx), %rax; mulq 24(%rcx); movq %rax, D0Lo; movq %rdx, D0Hi
      movq 8(%rcx), %rax; mulq 56(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
      movq 16(%rcx), %rax; mulq 48(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
      movq 0(%rcx), %rax; mulq 32(%rcx); movq %rax, D1Lo; movq %rdx, D1Hi
      movq 8(%rcx), %rax; mulq 24(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
      movq 16(%rcx), %rax; mulq 56(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
      movq 0(%rcx), %rax; mulq 40(%rcx); movq %rax, D2Lo; movq %rdx, D2Hi
      movq 8(%rcx), %rax; mulq 32(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
      movq 16(%rcx), %rax; mulq 24(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
    end ['rax', 'rcx', 'rdx'];

    // Carry
    LState.H0 := D0Lo and $0FFFFFFFFFFF;
    C := (D0Lo shr 44) or (D0Hi shl 20);
    D1Lo := D1Lo + C; if D1Lo < C then Inc(D1Hi);
    LState.H1 := D1Lo and $0FFFFFFFFFFF;
    C := (D1Lo shr 44) or (D1Hi shl 20);
    D2Lo := D2Lo + C; if D2Lo < C then Inc(D2Hi);
    LState.H2 := D2Lo and $3FFFFFFFFFF;
    C := (D2Lo shr 42) or (D2Hi shl 22);
    LState.H0 := LState.H0 + C * 5;
    C := LState.H0 shr 44;
    LState.H0 := LState.H0 and $0FFFFFFFFFFF;
    LState.H1 := LState.H1 + C;

    Inc(LOffset, 16);
  end;

  // Final partial block
  if LOffset < Length(AMessage) then
  begin
    FillChar(LBlock, 16, 0);
    Move(AMessage[LOffset], LBlock[0], Length(AMessage) - LOffset);
    LBlock[Length(AMessage) - LOffset] := 1;

    LState.H0 := LState.H0 + (PUInt64(@LBlock[0])^ and $0FFFFFFFFFFF);
    LState.H1 := LState.H1 + (((PUInt64(@LBlock[0])^ shr 44) or (PUInt64(@LBlock[8])^ shl 20)) and $0FFFFFFFFFFF);
    LState.H2 := LState.H2 + ((PUInt64(@LBlock[8])^ shr 24) and $3FFFFFFFFFF);

    asm
      leaq LState, %rcx
      movq 0(%rcx), %rax; mulq 24(%rcx); movq %rax, D0Lo; movq %rdx, D0Hi
      movq 8(%rcx), %rax; mulq 56(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
      movq 16(%rcx), %rax; mulq 48(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
      movq 0(%rcx), %rax; mulq 32(%rcx); movq %rax, D1Lo; movq %rdx, D1Hi
      movq 8(%rcx), %rax; mulq 24(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
      movq 16(%rcx), %rax; mulq 56(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
      movq 0(%rcx), %rax; mulq 40(%rcx); movq %rax, D2Lo; movq %rdx, D2Hi
      movq 8(%rcx), %rax; mulq 32(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
      movq 16(%rcx), %rax; mulq 24(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
    end ['rax', 'rcx', 'rdx'];

    LState.H0 := D0Lo and $0FFFFFFFFFFF;
    C := (D0Lo shr 44) or (D0Hi shl 20);
    D1Lo := D1Lo + C; if D1Lo < C then Inc(D1Hi);
    LState.H1 := D1Lo and $0FFFFFFFFFFF;
    C := (D1Lo shr 44) or (D1Hi shl 20);
    D2Lo := D2Lo + C; if D2Lo < C then Inc(D2Hi);
    LState.H2 := D2Lo and $3FFFFFFFFFF;
    C := (D2Lo shr 42) or (D2Hi shl 22);
    LState.H0 := LState.H0 + C * 5;
    C := LState.H0 shr 44;
    LState.H0 := LState.H0 and $0FFFFFFFFFFF;
    LState.H1 := LState.H1 + C;
  end;

  // Final reduction
  C := LState.H1 shr 44; LState.H1 := LState.H1 and $0FFFFFFFFFFF;
  LState.H2 := LState.H2 + C;
  C := LState.H2 shr 42; LState.H2 := LState.H2 and $3FFFFFFFFFF;
  LState.H0 := LState.H0 + C * 5;
  C := LState.H0 shr 44; LState.H0 := LState.H0 and $0FFFFFFFFFFF;
  LState.H1 := LState.H1 + C;

  // Conditional subtraction of p
  G0 := LState.H0 + 5;
  C := G0 shr 44; G0 := G0 and $0FFFFFFFFFFF;
  G1 := LState.H1 + C;
  C := G1 shr 44; G1 := G1 and $0FFFFFFFFFFF;
  G2 := Int64(LState.H2) + Int64(C) - (Int64(1) shl 42);
  if G2 >= 0 then
  begin
    LState.H0 := G0; LState.H1 := G1; LState.H2 := UInt64(G2);
  end;

  // Add pad (128-bit)
  FLo := (LState.H0 or (LState.H1 shl 44)) + PUInt64(@AKey[16])^;
  FHi := (LState.H1 shr 20) or (LState.H2 shl 24);
  if FLo < PUInt64(@AKey[16])^ then Inc(FHi);
  FHi := FHi + PUInt64(@AKey[24])^;

  PUInt64(@Result[0])^ := FLo;
  PUInt64(@Result[8])^ := FHi;
end;
{$ELSE}
var
  R0, R1, R2, R3, R4: UInt64;
  S1, S2, S3, S4: UInt64;
  H0, H1, H2, H3, H4: UInt64;
  D0, D1, D2, D3, D4: UInt64;
  C: UInt64;
  LBlock: array[0..16] of Byte;
  LOffset, LChunkLen, I: Integer;
  T0, T1, T2, T3, T4: UInt32;
  G0, G1, G2, G3: UInt64;
  G4: Int64;
  F0, F1, F2, F3: UInt64;
  LPad0, LPad1, LPad2, LPad3: UInt32;
begin
  SetLength(Result, POLY1305_TAG_SIZE);

  R0 := UInt64(Load32LE(AKey, 0) and $3FFFFFF);
  R1 := UInt64((Load32LE(AKey, 3) shr 2) and $3FFFF03);
  R2 := UInt64((Load32LE(AKey, 6) shr 4) and $3FFC0FF);
  R3 := UInt64((Load32LE(AKey, 9) shr 6) and $3F03FFF);
  R4 := UInt64((Load32LE(AKey, 12) shr 8) and $00FFFFF);

  S1 := R1 * 5;
  S2 := R2 * 5;
  S3 := R3 * 5;
  S4 := R4 * 5;

  H0 := 0;
  H1 := 0;
  H2 := 0;
  H3 := 0;
  H4 := 0;

  LOffset := 0;
  // Fast path: process full 16-byte blocks directly from input
  while LOffset + 16 <= Length(AMessage) do
  begin
    T0 := UInt32(AMessage[LOffset]) or (UInt32(AMessage[LOffset+1]) shl 8) or
           (UInt32(AMessage[LOffset+2]) shl 16) or (UInt32(AMessage[LOffset+3]) shl 24);
    T1 := UInt32(AMessage[LOffset+3]) or (UInt32(AMessage[LOffset+4]) shl 8) or
           (UInt32(AMessage[LOffset+5]) shl 16) or (UInt32(AMessage[LOffset+6]) shl 24);
    T2 := UInt32(AMessage[LOffset+6]) or (UInt32(AMessage[LOffset+7]) shl 8) or
           (UInt32(AMessage[LOffset+8]) shl 16) or (UInt32(AMessage[LOffset+9]) shl 24);
    T3 := UInt32(AMessage[LOffset+9]) or (UInt32(AMessage[LOffset+10]) shl 8) or
           (UInt32(AMessage[LOffset+11]) shl 16) or (UInt32(AMessage[LOffset+12]) shl 24);
    T4 := UInt32(AMessage[LOffset+12]) or (UInt32(AMessage[LOffset+13]) shl 8) or
           (UInt32(AMessage[LOffset+14]) shl 16) or (UInt32(AMessage[LOffset+15]) shl 24);

    H0 := H0 + UInt64(T0 and $3FFFFFF);
    H1 := H1 + UInt64((T1 shr 2) and $3FFFFFF);
    H2 := H2 + UInt64((T2 shr 4) and $3FFFFFF);
    H3 := H3 + UInt64((T3 shr 6) and $3FFFFFF);
    H4 := H4 + UInt64(T4 shr 8) + (UInt64(1) shl 24);

    D0 := (H0 * R0) + (H1 * S4) + (H2 * S3) + (H3 * S2) + (H4 * S1);
    D1 := (H0 * R1) + (H1 * R0) + (H2 * S4) + (H3 * S3) + (H4 * S2);
    D2 := (H0 * R2) + (H1 * R1) + (H2 * R0) + (H3 * S4) + (H4 * S3);
    D3 := (H0 * R3) + (H1 * R2) + (H2 * R1) + (H3 * R0) + (H4 * S4);
    D4 := (H0 * R4) + (H1 * R3) + (H2 * R2) + (H3 * R1) + (H4 * R0);

    C := D0 shr 26; H0 := D0 and POLY1305_MASK_26; D1 := D1 + C;
    C := D1 shr 26; H1 := D1 and POLY1305_MASK_26; D2 := D2 + C;
    C := D2 shr 26; H2 := D2 and POLY1305_MASK_26; D3 := D3 + C;
    C := D3 shr 26; H3 := D3 and POLY1305_MASK_26; D4 := D4 + C;
    C := D4 shr 26; H4 := D4 and POLY1305_MASK_26; H0 := H0 + (C * 5);
    C := H0 shr 26; H0 := H0 and POLY1305_MASK_26; H1 := H1 + C;

    Inc(LOffset, 16);
  end;

  // Slow path: final partial block
  while LOffset < Length(AMessage) do
  begin
    FillChar(LBlock[0], SizeOf(LBlock), 0);

    LChunkLen := Length(AMessage) - LOffset;
    if LChunkLen > 16 then
      LChunkLen := 16;

    if LChunkLen > 0 then
      Move(AMessage[LOffset], LBlock[0], LChunkLen);
    LBlock[LChunkLen] := 1;

    T0 := Load32LEFromBytes(LBlock, 0);
    T1 := Load32LEFromBytes(LBlock, 3);
    T2 := Load32LEFromBytes(LBlock, 6);
    T3 := Load32LEFromBytes(LBlock, 9);
    T4 := Load32LEFromBytes(LBlock, 12);

    H0 := H0 + UInt64(T0 and $3FFFFFF);
    H1 := H1 + UInt64((T1 shr 2) and $3FFFFFF);
    H2 := H2 + UInt64((T2 shr 4) and $3FFFFFF);
    H3 := H3 + UInt64((T3 shr 6) and $3FFFFFF);
    H4 := H4 + UInt64(T4 shr 8) + (UInt64(LBlock[16]) shl 24);

    D0 := (H0 * R0) + (H1 * S4) + (H2 * S3) + (H3 * S2) + (H4 * S1);
    D1 := (H0 * R1) + (H1 * R0) + (H2 * S4) + (H3 * S3) + (H4 * S2);
    D2 := (H0 * R2) + (H1 * R1) + (H2 * R0) + (H3 * S4) + (H4 * S3);
    D3 := (H0 * R3) + (H1 * R2) + (H2 * R1) + (H3 * R0) + (H4 * S4);
    D4 := (H0 * R4) + (H1 * R3) + (H2 * R2) + (H3 * R1) + (H4 * R0);

    C := D0 shr 26;
    H0 := D0 and POLY1305_MASK_26;
    D1 := D1 + C;

    C := D1 shr 26;
    H1 := D1 and POLY1305_MASK_26;
    D2 := D2 + C;

    C := D2 shr 26;
    H2 := D2 and POLY1305_MASK_26;
    D3 := D3 + C;

    C := D3 shr 26;
    H3 := D3 and POLY1305_MASK_26;
    D4 := D4 + C;

    C := D4 shr 26;
    H4 := D4 and POLY1305_MASK_26;
    H0 := H0 + (C * 5);

    C := H0 shr 26;
    H0 := H0 and POLY1305_MASK_26;
    H1 := H1 + C;

    Inc(LOffset, LChunkLen);
  end;

  C := H1 shr 26;
  H1 := H1 and POLY1305_MASK_26;
  H2 := H2 + C;

  C := H2 shr 26;
  H2 := H2 and POLY1305_MASK_26;
  H3 := H3 + C;

  C := H3 shr 26;
  H3 := H3 and POLY1305_MASK_26;
  H4 := H4 + C;

  C := H4 shr 26;
  H4 := H4 and POLY1305_MASK_26;
  H0 := H0 + (C * 5);

  C := H0 shr 26;
  H0 := H0 and POLY1305_MASK_26;
  H1 := H1 + C;

  G0 := H0 + 5;
  C := G0 shr 26;
  G0 := G0 and POLY1305_MASK_26;

  G1 := H1 + C;
  C := G1 shr 26;
  G1 := G1 and POLY1305_MASK_26;

  G2 := H2 + C;
  C := G2 shr 26;
  G2 := G2 and POLY1305_MASK_26;

  G3 := H3 + C;
  C := G3 shr 26;
  G3 := G3 and POLY1305_MASK_26;

  G4 := Int64(H4) + Int64(C) - (Int64(1) shl 26);
  if G4 >= 0 then
  begin
    H0 := G0;
    H1 := G1;
    H2 := G2;
    H3 := G3;
    H4 := UInt64(G4);
  end;

  LPad0 := Load32LE(AKey, 16);
  LPad1 := Load32LE(AKey, 20);
  LPad2 := Load32LE(AKey, 24);
  LPad3 := Load32LE(AKey, 28);

  F0 := ((H0 or (H1 shl 26)) and $FFFFFFFF) + UInt64(LPad0);
  F1 := (((H1 shr 6) or (H2 shl 20)) and $FFFFFFFF) + UInt64(LPad1) + (F0 shr 32);
  F2 := (((H2 shr 12) or (H3 shl 14)) and $FFFFFFFF) + UInt64(LPad2) + (F1 shr 32);
  F3 := (((H3 shr 18) or (H4 shl 8)) and $FFFFFFFF) + UInt64(LPad3) + (F2 shr 32);

  Store32LE(Result, 0, UInt32(F0 and $FFFFFFFF));
  Store32LE(Result, 4, UInt32(F1 and $FFFFFFFF));
  Store32LE(Result, 8, UInt32(F2 and $FFFFFFFF));
  Store32LE(Result, 12, UInt32(F3 and $FFFFFFFF));

  for I := 0 to High(LBlock) do
    LBlock[I] := 0;
end;
{$ENDIF}

function BuildPoly1305Input(const AAAD, ACiphertext: TBytes): TBytes;
var
  LOffset: Integer;
  LAADPad, LCipherPad: Integer;
begin
  LAADPad := 0;
  if (Length(AAAD) mod 16) <> 0 then
    LAADPad := 16 - (Length(AAAD) mod 16);

  LCipherPad := 0;
  if (Length(ACiphertext) mod 16) <> 0 then
    LCipherPad := 16 - (Length(ACiphertext) mod 16);

  SetLength(Result,
    Length(AAAD) + LAADPad +
    Length(ACiphertext) + LCipherPad +
    16
  );

  LOffset := 0;
  if Length(AAAD) > 0 then
  begin
    Move(AAAD[0], Result[LOffset], Length(AAAD));
    Inc(LOffset, Length(AAAD));
  end;
  Inc(LOffset, LAADPad);

  if Length(ACiphertext) > 0 then
  begin
    Move(ACiphertext[0], Result[LOffset], Length(ACiphertext));
    Inc(LOffset, Length(ACiphertext));
  end;
  Inc(LOffset, LCipherPad);

  Store64LE(Result, LOffset, QWord(Length(AAAD)));
  Store64LE(Result, LOffset + 8, QWord(Length(ACiphertext)));
end;

{ === Streaming Poly1305 API (cross-platform, standalone procedures) === }

type
  TPoly1305Ctx = record
    H0, H1, H2: UInt64;   // accumulator (3×44-bit)
    R0, R1, R2: UInt64;   // key r (3×44-bit, clamped)
    S1, S2: UInt64;        // r1*20, r2*20
    Pad: array[0..15] of Byte; // one-time pad (s)
  end;

procedure Poly1305Init(out Ctx: TPoly1305Ctx; const AKey: PByte);
var
  LR128Lo, LR128Hi: UInt64;
begin
  LR128Lo := PUInt64(AKey)^ and $0FFFFFFC0FFFFFFF;
  LR128Hi := PUInt64(AKey + 8)^ and $0FFFFFFC0FFFFFFC;
  Ctx.R0 := LR128Lo and $0FFFFFFFFFFF;
  Ctx.R1 := ((LR128Lo shr 44) or (LR128Hi shl 20)) and $0FFFFFFFFFFF;
  Ctx.R2 := (LR128Hi shr 24) and $3FFFFFFFFFF;
  Ctx.S1 := Ctx.R1 * 20;
  Ctx.S2 := Ctx.R2 * 20;
  Ctx.H0 := 0; Ctx.H1 := 0; Ctx.H2 := 0;
  Move((AKey + 16)^, Ctx.Pad[0], 16);
end;

procedure Poly1305Update(var Ctx: TPoly1305Ctx; AData: PByte; AHiBit: UInt64);
var
  D0Lo, D0Hi, D1Lo, D1Hi, D2Lo, D2Hi, C: UInt64;
begin
  Ctx.H0 := Ctx.H0 + (PUInt64(AData)^ and $0FFFFFFFFFFF);
  Ctx.H1 := Ctx.H1 + (((PUInt64(AData)^ shr 44) or (PUInt64(AData + 8)^ shl 20)) and $0FFFFFFFFFFF);
  Ctx.H2 := Ctx.H2 + (((PUInt64(AData + 8)^ shr 24) and $3FFFFFFFFFF) or AHiBit);
  {$IFDEF CPUX86_64}
  {$ASMMODE ATT}
  asm
    movq Ctx, %rcx
    movq 0(%rcx), %rax; mulq 24(%rcx); movq %rax, D0Lo; movq %rdx, D0Hi
    movq 8(%rcx), %rax; mulq 56(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
    movq 16(%rcx), %rax; mulq 48(%rcx); addq %rax, D0Lo; adcq %rdx, D0Hi
    movq 0(%rcx), %rax; mulq 32(%rcx); movq %rax, D1Lo; movq %rdx, D1Hi
    movq 8(%rcx), %rax; mulq 24(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
    movq 16(%rcx), %rax; mulq 56(%rcx); addq %rax, D1Lo; adcq %rdx, D1Hi
    movq 0(%rcx), %rax; mulq 40(%rcx); movq %rax, D2Lo; movq %rdx, D2Hi
    movq 8(%rcx), %rax; mulq 32(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
    movq 16(%rcx), %rax; mulq 24(%rcx); addq %rax, D2Lo; adcq %rdx, D2Hi
  end ['rax', 'rcx', 'rdx'];
  {$ELSE}
  // Full 3×44-bit Poly1305 multiply for non-x86_64 platforms.
  // Each limb ≤ 2^44, so h[i]*r[j] ≤ 2^88 which fits in two UInt64 words
  // when accumulated with proper carry tracking.
  D0Lo := 0; D0Hi := 0;
  D1Lo := 0; D1Hi := 0;
  D2Lo := 0; D2Hi := 0;

  // D0 = H0*R0 + H1*S2 + H2*S1
  D0Lo := Ctx.H0 * Ctx.R0;
  D0Lo := D0Lo + Ctx.H1 * Ctx.S2;
  if D0Lo < Ctx.H1 * Ctx.S2 then Inc(D0Hi);
  D0Lo := D0Lo + Ctx.H2 * Ctx.S1;
  if D0Lo < Ctx.H2 * Ctx.S1 then Inc(D0Hi);

  // D1 = H0*R1 + H1*R0 + H2*S2
  D1Lo := Ctx.H0 * Ctx.R1;
  D1Lo := D1Lo + Ctx.H1 * Ctx.R0;
  if D1Lo < Ctx.H1 * Ctx.R0 then Inc(D1Hi);
  D1Lo := D1Lo + Ctx.H2 * Ctx.S2;
  if D1Lo < Ctx.H2 * Ctx.S2 then Inc(D1Hi);

  // D2 = H0*R2 + H1*R1 + H2*R0
  D2Lo := Ctx.H0 * Ctx.R2;
  D2Lo := D2Lo + Ctx.H1 * Ctx.R1;
  if D2Lo < Ctx.H1 * Ctx.R1 then Inc(D2Hi);
  D2Lo := D2Lo + Ctx.H2 * Ctx.R0;
  if D2Lo < Ctx.H2 * Ctx.R0 then Inc(D2Hi);
  {$ENDIF}
  Ctx.H0 := D0Lo and $0FFFFFFFFFFF;
  C := (D0Lo shr 44) or (D0Hi shl 20);
  D1Lo := D1Lo + C; if D1Lo < C then Inc(D1Hi);
  Ctx.H1 := D1Lo and $0FFFFFFFFFFF;
  C := (D1Lo shr 44) or (D1Hi shl 20);
  D2Lo := D2Lo + C; if D2Lo < C then Inc(D2Hi);
  Ctx.H2 := D2Lo and $3FFFFFFFFFF;
  C := (D2Lo shr 42) or (D2Hi shl 22);
  Ctx.H0 := Ctx.H0 + C * 5;
  C := Ctx.H0 shr 44; Ctx.H0 := Ctx.H0 and $0FFFFFFFFFFF; Ctx.H1 := Ctx.H1 + C;
end;

procedure Poly1305Finish(var Ctx: TPoly1305Ctx; ATag: PByte);
var
  C, G0, G1, FLo, FHi: UInt64;
  G2: Int64;
begin
  C := Ctx.H1 shr 44; Ctx.H1 := Ctx.H1 and $0FFFFFFFFFFF; Ctx.H2 := Ctx.H2 + C;
  C := Ctx.H2 shr 42; Ctx.H2 := Ctx.H2 and $3FFFFFFFFFF; Ctx.H0 := Ctx.H0 + C * 5;
  C := Ctx.H0 shr 44; Ctx.H0 := Ctx.H0 and $0FFFFFFFFFFF; Ctx.H1 := Ctx.H1 + C;
  G0 := Ctx.H0 + 5; C := G0 shr 44; G0 := G0 and $0FFFFFFFFFFF;
  G1 := Ctx.H1 + C; C := G1 shr 44; G1 := G1 and $0FFFFFFFFFFF;
  G2 := Int64(Ctx.H2) + Int64(C) - (Int64(1) shl 42);
  if G2 >= 0 then begin Ctx.H0 := G0; Ctx.H1 := G1; Ctx.H2 := UInt64(G2); end;
  FLo := (Ctx.H0 or (Ctx.H1 shl 44)) + PUInt64(@Ctx.Pad[0])^;
  FHi := (Ctx.H1 shr 20) or (Ctx.H2 shl 24);
  if FLo < PUInt64(@Ctx.Pad[0])^ then Inc(FHi);
  FHi := FHi + PUInt64(@Ctx.Pad[8])^;
  PUInt64(ATag)^ := FLo;
  PUInt64(ATag + 8)^ := FHi;
end;
function TryChaCha20Poly1305Encrypt(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;
var
  LPolyCtx: TPoly1305Ctx;
  LBlock0: TBytes;
  LOffset, I, J, LBlockLen: Integer;
  LPadBlock: array[0..15] of Byte;
begin
  SetLength(ACiphertext, 0); SetLength(ATag, 0);
  if Length(AKey) <> CHACHA20_KEY_SIZE then Exit(False);
  if Length(ANonce) <> CHACHA20_NONCE_SIZE then Exit(False);

  // Generate Poly1305 key from ChaCha20 block 0
  LBlock0 := ChaCha20Block(AKey, ANonce, 0);
  Poly1305Init(LPolyCtx, @LBlock0[0]);

  // Process AAD
  LOffset := 0;
  while LOffset + 16 <= Length(AAAD) do
  begin
    Poly1305Update(LPolyCtx, @AAAD[LOffset], UInt64(1) shl 40);
    Inc(LOffset, 16);
  end;
  if LOffset < Length(AAAD) then
  begin
    FillChar(LPadBlock, 16, 0);
    Move(AAAD[LOffset], LPadBlock[0], Length(AAAD) - LOffset);
    Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);
  end;

  // Single-pass: ChaCha20 encrypt + Poly1305 MAC
  ACiphertext := ChaCha20Xor(AKey, ANonce, 1, APlaintext);

  // Feed ciphertext to Poly1305 (data is hot in cache from ChaCha20Xor)
  LOffset := 0;
  while LOffset + 16 <= Length(ACiphertext) do
  begin
    Poly1305Update(LPolyCtx, @ACiphertext[LOffset], UInt64(1) shl 40);
    Inc(LOffset, 16);
  end;
  if LOffset < Length(ACiphertext) then
  begin
    FillChar(LPadBlock, 16, 0);
    Move(ACiphertext[LOffset], LPadBlock[0], Length(ACiphertext) - LOffset);
    Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);
  end;

  // Length block
  FillChar(LPadBlock, 16, 0);
  PUInt64(@LPadBlock[0])^ := UInt64(Length(AAAD));
  PUInt64(@LPadBlock[8])^ := UInt64(Length(APlaintext));
  Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);

  // Finalize tag
  SetLength(ATag, 16);
  Poly1305Finish(LPolyCtx, @ATag[0]);
  Result := True;
end;



function TryChaCha20Poly1305Decrypt(
  const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes;
  out APlaintext: TBytes
): Boolean;
var
  LBlock0: TBytes;
  LPolyCtx: TPoly1305Ctx;
  LExpectedTag: array[0..15] of Byte;
  LPadBlock: array[0..15] of Byte;
  LOffset: Integer;
begin
  SetLength(APlaintext, 0);

  if Length(AKey) <> CHACHA20_KEY_SIZE then
    Exit(False);
  if Length(ANonce) <> CHACHA20_NONCE_SIZE then
    Exit(False);
  if Length(ATag) <> POLY1305_TAG_SIZE then
    Exit(False);

  LBlock0 := ChaCha20Block(AKey, ANonce, 0);
  Poly1305Init(LPolyCtx, @LBlock0[0]);

  // Process AAD
  LOffset := 0;
  while LOffset + 16 <= Length(AAAD) do
  begin
    Poly1305Update(LPolyCtx, @AAAD[LOffset], UInt64(1) shl 40);
    Inc(LOffset, 16);
  end;
  if LOffset < Length(AAAD) then
  begin
    FillChar(LPadBlock, 16, 0);
    Move(AAAD[LOffset], LPadBlock[0], Length(AAAD) - LOffset);
    Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);
  end;

  // Process ciphertext
  LOffset := 0;
  while LOffset + 16 <= Length(ACiphertext) do
  begin
    Poly1305Update(LPolyCtx, @ACiphertext[LOffset], UInt64(1) shl 40);
    Inc(LOffset, 16);
  end;
  if LOffset < Length(ACiphertext) then
  begin
    FillChar(LPadBlock, 16, 0);
    Move(ACiphertext[LOffset], LPadBlock[0], Length(ACiphertext) - LOffset);
    Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);
  end;

  // Length block
  FillChar(LPadBlock, 16, 0);
  PUInt64(@LPadBlock[0])^ := UInt64(Length(AAAD));
  PUInt64(@LPadBlock[8])^ := UInt64(Length(ACiphertext));
  Poly1305Update(LPolyCtx, @LPadBlock[0], UInt64(1) shl 40);

  Poly1305Finish(LPolyCtx, @LExpectedTag[0]);

  if TConstantTime.CompareBuffer(@LExpectedTag[0], @ATag[0], 16) <> 1 then
    Exit(False);

  APlaintext := ChaCha20Xor(AKey, ANonce, 1, ACiphertext);
  Result := True;
end;

function TryChaCha20Poly1305EncryptCombined(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes
): Boolean;
var
  LCiphertext, LTag: TBytes;
begin
  SetLength(AEncrypted, 0);

  if not TryChaCha20Poly1305Encrypt(AKey, ANonce, AAAD, APlaintext, LCiphertext, LTag) then
    Exit(False);

  SetLength(AEncrypted, Length(LCiphertext) + Length(LTag));
  if Length(LCiphertext) > 0 then
    Move(LCiphertext[0], AEncrypted[0], Length(LCiphertext));
  if Length(LTag) > 0 then
    Move(LTag[0], AEncrypted[Length(LCiphertext)], Length(LTag));

  Result := True;
end;

function TryChaCha20Poly1305DecryptCombined(
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes
): Boolean;
var
  LCiphertext, LTag: TBytes;
  LCipherLen: Integer;
begin
  SetLength(APlaintext, 0);

  if Length(AEncrypted) < POLY1305_TAG_SIZE then
    Exit(False);

  LCipherLen := Length(AEncrypted) - POLY1305_TAG_SIZE;
  SetLength(LCiphertext, LCipherLen);
  if LCipherLen > 0 then
    Move(AEncrypted[0], LCiphertext[0], LCipherLen);

  SetLength(LTag, POLY1305_TAG_SIZE);
  Move(AEncrypted[LCipherLen], LTag[0], POLY1305_TAG_SIZE);

  Result := TryChaCha20Poly1305Decrypt(AKey, ANonce, AAAD, LCiphertext, LTag, APlaintext);
end;

end.
