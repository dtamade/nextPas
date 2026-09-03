unit nextpas.core.crypto.aesgcm;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base;

type
  TAESBlock = array[0..15] of Byte;
  TAESExpandedKey = array[0..59] of UInt32;

procedure AESKeyExpand(const AKey: TBytes; out AExpandedKey: TAESExpandedKey; out ANr: Integer);
procedure AESEncryptBlock(const AInput: TAESBlock; out AOutput: TAESBlock; const AExpandedKey: TAESExpandedKey; ANr: Integer);

function PurePascalAESGCMEncrypt(
  const AKey, AIV, APlaintext, AAAD: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;

function PurePascalAESGCMDecrypt(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  out APlaintext: TBytes
): Boolean;

function PurePascalAESGCMDecryptTo(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  APlaintext: PByte; APlainLen: Integer
): Boolean;

function AESNIGCMDecryptTo128(
  const AKey, AIV: TBytes; ACipher: PByte; ACipherLen: Integer;
  const ATag, AAAD: TBytes; ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMDecryptTo256(
  const AKey, AIV: TBytes; ACipher: PByte; ACipherLen: Integer;
  const ATag, AAAD: TBytes; ADest: PByte; ADestLen: Integer): Boolean;
// PByte tag/nonce 变体（栈上 12/16B 零堆，tlspas 泵直调）
function AESNIGCMDecryptTo128Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMDecryptTo256Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMEncryptTo128Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMEncryptTo256Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
// 零堆变体：AAAD 以 PByte/长度传入，规避 TBytes 5 字节堆分配（泵热路径）
function PurePascalAESGCMEncryptPtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
function PurePascalAESGCMDecryptPtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMEncryptTo128PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMEncryptTo256PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMDecryptTo128PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
function AESNIGCMDecryptTo256PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;

implementation

uses
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64;

var
  GAESNIDetected: Boolean = False;
  GAESNIChecked: Boolean = False;
  GPCLMULDetected: Boolean = False;
  GPCLMULChecked: Boolean = False;

function UseAESNI: Boolean; inline;
begin
  if not GAESNIChecked then
  begin
    GAESNIDetected := IsAESNIAvailable;
    GAESNIChecked := True;
  end;
  Result := GAESNIDetected;
end;

{$IFDEF CPUX86_64}
{$ASMMODE INTEL}
{$CODEALIGN CONSTMIN=16}

const
  GHASHReflectHi: array[0..15] of Byte = (
    $00, $80, $40, $C0, $20, $A0, $60, $E0,
    $10, $90, $50, $D0, $30, $B0, $70, $F0
  );
  GHASHReflectLo: array[0..15] of Byte = (
    $00, $08, $04, $0C, $02, $0A, $06, $0E,
    $01, $09, $05, $0D, $03, $0B, $07, $0F
  );
  GHASHMask0F: array[0..15] of Byte = (
    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F,
    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
  );

{$CODEALIGN CONSTMIN=1}

function IsPCLMULAvailable: Boolean; assembler; nostackframe;
asm
  push rbx
  mov eax, 1
  cpuid
  bt ecx, 1
  setc al
  movzx eax, al
  pop rbx
end;

procedure GHASHUpdatePCLMUL(var AState: TAESBlock; const AHashKey: TAESBlock;
  AData: PByte; ABlocks: Integer); assembler; nostackframe;
asm
  // rdi=AState, rsi=AHashKey, rdx=AData, ecx=ABlocks
  test ecx, ecx
  jle @done

  // Load LUT constants into xmm8-xmm10 (persistent across loop)
  movdqa xmm8, [rip + GHASHReflectHi]
  movdqa xmm9, [rip + GHASHReflectLo]
  movdqa xmm10, [rip + GHASHMask0F]

  // Load and pre-reflect H into xmm11
  movdqu xmm0, [rsi]
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2
  movdqa xmm11, xmm1   // xmm11 = reflected H

  // Load state and reflect into xmm12 (accumulator in reflected domain)
  movdqu xmm0, [rdi]
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2
  movdqa xmm12, xmm1   // xmm12 = reflected state

  mov r8d, ecx          // r8d = block counter

@loop:
  // Load data block, reflect it, XOR into reflected accumulator
  movdqu xmm0, [rdx]
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2       // xmm1 = reflected data block
  pxor xmm12, xmm1     // accumulator ^= reflected data

  // Karatsuba: xmm12 * xmm11
  movdqa xmm0, xmm12
  movdqa xmm2, xmm0
  movdqa xmm3, xmm0
  movdqa xmm4, xmm0
  pclmulqdq xmm2, xmm11, $00   // low
  pclmulqdq xmm3, xmm11, $11   // high
  pclmulqdq xmm4, xmm11, $01   // mid1
  movdqa xmm5, xmm0
  pclmulqdq xmm5, xmm11, $10   // mid2
  pxor xmm4, xmm5
  movdqa xmm5, xmm4
  pslldq xmm5, 8
  psrldq xmm4, 8
  pxor xmm2, xmm5              // xmm2 = C_L
  pxor xmm3, xmm4              // xmm3 = C_H

  // Reduction: P(x) = x^128 + x^7 + x^2 + x + 1
  // C_H << 7
  movdqa xmm4, xmm3
  movdqa xmm5, xmm3
  psllq xmm4, 7
  psrlq xmm5, 57
  pslldq xmm5, 8
  por xmm4, xmm5
  // C_H << 2
  movdqa xmm5, xmm3
  movdqa xmm6, xmm3
  psllq xmm5, 2
  psrlq xmm6, 62
  pslldq xmm6, 8
  por xmm5, xmm6
  // C_H << 1
  movdqa xmm6, xmm3
  movdqa xmm7, xmm3
  psllq xmm6, 1
  psrlq xmm7, 63
  pslldq xmm7, 8
  por xmm6, xmm7
  // Main = (<<7) XOR (<<2) XOR (<<1) XOR C_H
  pxor xmm4, xmm5
  pxor xmm4, xmm6
  pxor xmm4, xmm3
  // Overflow bits (from high qword of C_H)
  movdqa xmm5, xmm3
  psrlq xmm5, 57
  psrldq xmm5, 8
  movdqa xmm6, xmm3
  psrlq xmm6, 62
  psrldq xmm6, 8
  pxor xmm5, xmm6
  movdqa xmm6, xmm3
  psrlq xmm6, 63
  psrldq xmm6, 8
  pxor xmm5, xmm6
  // Reduce overflow
  movdqa xmm6, xmm5
  movdqa xmm7, xmm5
  psllq xmm6, 7
  pxor xmm5, xmm6
  movdqa xmm6, xmm7
  psllq xmm6, 2
  pxor xmm5, xmm6
  psllq xmm7, 1
  pxor xmm5, xmm7
  // Result = C_L XOR main XOR overflow
  pxor xmm2, xmm4
  pxor xmm2, xmm5
  movdqa xmm12, xmm2   // update reflected accumulator

  add rdx, 16
  dec r8d
  jnz @loop

  // Un-reflect final accumulator back to normal form
  movdqa xmm0, xmm12
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2
  movdqu [rdi], xmm1

@done:
end;

{$ENDIF}

function UsePCLMUL: Boolean; inline;
begin
  if not GPCLMULChecked then
  begin
    {$IFDEF CPUX86_64}
    GPCLMULDetected := IsPCLMULAvailable;
    {$ELSE}
    GPCLMULDetected := False;
    {$ENDIF}
    GPCLMULChecked := True;
  end;
  Result := GPCLMULDetected;
end;

const
  AES_BLOCK_SIZE = 16;
  GCM_TAG_SIZE = 16;

var
  SBox: array[0..255] of Byte = (
    $63,$7c,$77,$7b,$f2,$6b,$6f,$c5,$30,$01,$67,$2b,$fe,$d7,$ab,$76,
    $ca,$82,$c9,$7d,$fa,$59,$47,$f0,$ad,$d4,$a2,$af,$9c,$a4,$72,$c0,
    $b7,$fd,$93,$26,$36,$3f,$f7,$cc,$34,$a5,$e5,$f1,$71,$d8,$31,$15,
    $04,$c7,$23,$c3,$18,$96,$05,$9a,$07,$12,$80,$e2,$eb,$27,$b2,$75,
    $09,$83,$2c,$1a,$1b,$6e,$5a,$a0,$52,$3b,$d6,$b3,$29,$e3,$2f,$84,
    $53,$d1,$00,$ed,$20,$fc,$b1,$5b,$6a,$cb,$be,$39,$4a,$4c,$58,$cf,
    $d0,$ef,$aa,$fb,$43,$4d,$33,$85,$45,$f9,$02,$7f,$50,$3c,$9f,$a8,
    $51,$a3,$40,$8f,$92,$9d,$38,$f5,$bc,$b6,$da,$21,$10,$ff,$f3,$d2,
    $cd,$0c,$13,$ec,$5f,$97,$44,$17,$c4,$a7,$7e,$3d,$64,$5d,$19,$73,
    $60,$81,$4f,$dc,$22,$2a,$90,$88,$46,$ee,$b8,$14,$de,$5e,$0b,$db,
    $e0,$32,$3a,$0a,$49,$06,$24,$5c,$c2,$d3,$ac,$62,$91,$95,$e4,$79,
    $e7,$c8,$37,$6d,$8d,$d5,$4e,$a9,$6c,$56,$f4,$ea,$65,$7a,$ae,$08,
    $ba,$78,$25,$2e,$1c,$a6,$b4,$c6,$e8,$dd,$74,$1f,$4b,$bd,$8b,$8a,
    $70,$3e,$b5,$66,$48,$03,$f6,$0e,$61,$35,$57,$b9,$86,$c1,$1d,$9e,
    $e1,$f8,$98,$11,$69,$d9,$8e,$94,$9b,$1e,$87,$e9,$ce,$55,$28,$df,
    $8c,$a1,$89,$0d,$bf,$e6,$42,$68,$41,$99,$2d,$0f,$b0,$54,$bb,$16
  );

  Rcon: array[0..9] of UInt32 = (
    $01000000, $02000000, $04000000, $08000000, $10000000,
    $20000000, $40000000, $80000000, $1b000000, $36000000
  );

function SubWord(W: UInt32): UInt32; inline;
begin
  Result := (UInt32(SBox[(W shr 24) and $FF]) shl 24) or
            (UInt32(SBox[(W shr 16) and $FF]) shl 16) or
            (UInt32(SBox[(W shr 8) and $FF]) shl 8) or
            UInt32(SBox[W and $FF]);
end;

function RotWord(W: UInt32): UInt32; inline;
begin
  Result := (W shl 8) or (W shr 24);
end;

procedure AESKeyExpand(const AKey: TBytes; out AExpandedKey: TAESExpandedKey; out ANr: Integer);
var
  Nk, I: Integer;
  Temp: UInt32;
begin
  FillChar(AExpandedKey, SizeOf(AExpandedKey), 0);
  case Length(AKey) of
    16: begin Nk := 4; ANr := 10; end;
    24: begin Nk := 6; ANr := 12; end;
    32: begin Nk := 8; ANr := 14; end;
  else
    ANr := 0;
    Exit;
  end;

  for I := 0 to Nk - 1 do
    AExpandedKey[I] := (UInt32(AKey[I*4]) shl 24) or (UInt32(AKey[I*4+1]) shl 16) or
                       (UInt32(AKey[I*4+2]) shl 8) or UInt32(AKey[I*4+3]);

  for I := Nk to (ANr + 1) * 4 - 1 do
  begin
    Temp := AExpandedKey[I - 1];
    if (I mod Nk) = 0 then
      Temp := SubWord(RotWord(Temp)) xor Rcon[(I div Nk) - 1]
    else if (Nk > 6) and ((I mod Nk) = 4) then
      Temp := SubWord(Temp);
    AExpandedKey[I] := AExpandedKey[I - Nk] xor Temp;
  end;
end;

procedure AESEncryptBlock(const AInput: TAESBlock; out AOutput: TAESBlock;
  const AExpandedKey: TAESExpandedKey; ANr: Integer);
var
  S: array[0..15] of Byte;
  T: array[0..15] of Byte;
  I, R: Integer;
  A, B, C, D: Byte;

  function XTime(X: Byte): Byte; inline;
  begin
    Result := (X shl 1) xor (((X shr 7) and 1) * $1B);
  end;

begin
  for I := 0 to 15 do
    S[I] := AInput[I] xor Byte(AExpandedKey[I div 4] shr (24 - (I mod 4) * 8));

  for R := 1 to ANr - 1 do
  begin
    for I := 0 to 15 do
      S[I] := SBox[S[I]];

    T[0] := S[0]; T[1] := S[5]; T[2] := S[10]; T[3] := S[15];
    T[4] := S[4]; T[5] := S[9]; T[6] := S[14]; T[7] := S[3];
    T[8] := S[8]; T[9] := S[13]; T[10] := S[2]; T[11] := S[7];
    T[12] := S[12]; T[13] := S[1]; T[14] := S[6]; T[15] := S[11];

    for I := 0 to 3 do
    begin
      A := T[I*4]; B := T[I*4+1]; C := T[I*4+2]; D := T[I*4+3];
      S[I*4]   := XTime(A) xor XTime(B) xor B xor C xor D;
      S[I*4+1] := A xor XTime(B) xor XTime(C) xor C xor D;
      S[I*4+2] := A xor B xor XTime(C) xor XTime(D) xor D;
      S[I*4+3] := XTime(A) xor A xor B xor C xor XTime(D);
    end;

    for I := 0 to 15 do
      S[I] := S[I] xor Byte(AExpandedKey[R * 4 + I div 4] shr (24 - (I mod 4) * 8));
  end;

  for I := 0 to 15 do
    S[I] := SBox[S[I]];

  T[0] := S[0]; T[1] := S[5]; T[2] := S[10]; T[3] := S[15];
  T[4] := S[4]; T[5] := S[9]; T[6] := S[14]; T[7] := S[3];
  T[8] := S[8]; T[9] := S[13]; T[10] := S[2]; T[11] := S[7];
  T[12] := S[12]; T[13] := S[1]; T[14] := S[6]; T[15] := S[11];

  for I := 0 to 15 do
    AOutput[I] := T[I] xor Byte(AExpandedKey[ANr * 4 + I div 4] shr (24 - (I mod 4) * 8));
end;

procedure GHASHMultiplyScalar(var AX: TAESBlock; const LHPtr: TAESBlock);
var
  V: array[0..15] of Byte;
  Z: array[0..15] of Byte;
  I, J, K: Integer;
  Bit: Byte;
  LMask: Byte;
  Carry: Byte;
  LCarryMask: Byte;
begin
  Move(LHPtr[0], V[0], 16);
  FillChar(Z[0], 16, 0);

  for I := 0 to 15 do
    for J := 7 downto 0 do
    begin
      Bit := (AX[I] shr J) and 1;
      LMask := Byte(0) - Bit;
      for K := 0 to 15 do
        Z[K] := Z[K] xor (V[K] and LMask);

      Carry := V[15] and 1;
      for K := 15 downto 1 do
        V[K] := (V[K] shr 1) or ((V[K-1] and 1) shl 7);
      V[0] := V[0] shr 1;
      LCarryMask := Byte(0) - Carry;
      V[0] := V[0] xor ($E1 and LCarryMask);
    end;

  Move(Z[0], AX[0], 16);
end;

{$IFDEF CPUX86_64}
procedure GHASHMultiplyPCLMUL(var ABlock: TAESBlock; const AHashKey: TAESBlock);
  assembler; nostackframe;
asm
  // rdi=ABlock, rsi=AHashKey
  movdqa xmm8, [rip + GHASHReflectHi]
  movdqa xmm9, [rip + GHASHReflectLo]
  movdqa xmm10, [rip + GHASHMask0F]

  // Load and reflect ABlock
  movdqu xmm0, [rdi]
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2
  movdqa xmm0, xmm1   // xmm0 = reflected block

  // Load and reflect AHashKey
  movdqu xmm1, [rsi]
  movdqa xmm3, xmm1
  pand xmm3, xmm10
  psrlw xmm1, 4
  pand xmm1, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm3
  movdqa xmm3, xmm9
  pshufb xmm3, xmm1
  por xmm3, xmm2
  movdqa xmm1, xmm3   // xmm1 = reflected H

  // Karatsuba
  movdqa xmm2, xmm0
  movdqa xmm3, xmm0
  movdqa xmm4, xmm0
  pclmulqdq xmm2, xmm1, $00
  pclmulqdq xmm3, xmm1, $11
  pclmulqdq xmm4, xmm1, $01
  movdqa xmm5, xmm0
  pclmulqdq xmm5, xmm1, $10
  pxor xmm4, xmm5
  movdqa xmm5, xmm4
  pslldq xmm5, 8
  psrldq xmm4, 8
  pxor xmm2, xmm5
  pxor xmm3, xmm4

  // Reduction
  movdqa xmm4, xmm3
  movdqa xmm5, xmm3
  psllq xmm4, 7
  psrlq xmm5, 57
  pslldq xmm5, 8
  por xmm4, xmm5
  movdqa xmm5, xmm3
  movdqa xmm6, xmm3
  psllq xmm5, 2
  psrlq xmm6, 62
  pslldq xmm6, 8
  por xmm5, xmm6
  movdqa xmm6, xmm3
  movdqa xmm7, xmm3
  psllq xmm6, 1
  psrlq xmm7, 63
  pslldq xmm7, 8
  por xmm6, xmm7
  pxor xmm4, xmm5
  pxor xmm4, xmm6
  pxor xmm4, xmm3
  // Overflow
  movdqa xmm5, xmm3
  psrlq xmm5, 57
  psrldq xmm5, 8
  movdqa xmm6, xmm3
  psrlq xmm6, 62
  psrldq xmm6, 8
  pxor xmm5, xmm6
  movdqa xmm6, xmm3
  psrlq xmm6, 63
  psrldq xmm6, 8
  pxor xmm5, xmm6
  movdqa xmm6, xmm5
  movdqa xmm7, xmm5
  psllq xmm6, 7
  pxor xmm5, xmm6
  movdqa xmm6, xmm7
  psllq xmm6, 2
  pxor xmm5, xmm6
  psllq xmm7, 1
  pxor xmm5, xmm7
  pxor xmm2, xmm4
  pxor xmm2, xmm5

  // Reflect result back
  movdqa xmm0, xmm2
  movdqa xmm1, xmm0
  pand xmm1, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm2, xmm8
  pshufb xmm2, xmm1
  movdqa xmm1, xmm9
  pshufb xmm1, xmm0
  por xmm1, xmm2
  movdqu [rdi], xmm1
end;
{$ENDIF}

procedure GHASHMultiplySingle(var AX: TAESBlock; const LHPtr: TAESBlock);
begin
  {$IFDEF CPUX86_64}
  if UsePCLMUL then
  begin
    GHASHMultiplyPCLMUL(AX, LHPtr);
    Exit;
  end;
  {$ENDIF}
  GHASHMultiplyScalar(AX, LHPtr);
end;

{$IFDEF CPUX86_64}
type
  { 聚合 GHASH 幂表：[0]=H¹, [1]=H², [2]=H³, [3]=H⁴（正规域，asm 内反射） }
  TGHASHPowerTable = array[0..3] of TAESBlock;

{ 幂表构建：复用既有单块乘法（正规域），每组调用一次、成本按组摊薄 }
procedure BuildGHASHPowerTable(const AHashKey: TAESBlock; out APow: TGHASHPowerTable);
var
  I: Integer;
begin
  APow[0] := AHashKey;
  for I := 1 to 3 do
  begin
    APow[I] := APow[I - 1];
    GHASHMultiplyPCLMUL(APow[I], AHashKey);
  end;
end;

{ 聚合 GHASH：4 块一组延迟规约。
  数学依据：A₄ = (A₀⊕X₁)·H⁴ ⊕ X₂·H³ ⊕ X₃·H² ⊕ X₄·H；规约对 XOR 线性，
  故四个独立乘积可先求和（C_L/C_H 各自累积）再做一次共享规约。
  性能依据：原单块路径每块一条「乘法→规约」串行依赖链；此版四路乘法
  输入互不依赖可并行发射，规约成本由每块一次摊薄为每 4 块一次。
  寄存器布局：xmm8/9/10=LUT，xmm11..14=反射 H⁴/H³/H²/H¹，
  xmm15=反射累加器（跨组保持），xmm0/xmm7=临时。}
procedure GHASHUpdatePCLMULAgg(var AState: TAESBlock; const APow: TGHASHPowerTable;
  AData: PByte; ABlocks: Integer); assembler; nostackframe;
asm
  // rdi=AState, rsi=APow, rdx=AData, ecx=ABlocks（须为 4 的倍数且 ≥4）
  test ecx, ecx
  jle @done

  movdqa xmm8, [rip + GHASHReflectHi]
  movdqa xmm9, [rip + GHASHReflectLo]
  movdqa xmm10, [rip + GHASHMask0F]

  // 反射幂表：xmm11=H⁴ xmm12=H³ xmm13=H² xmm14=H¹（反射只碰 xmm0/xmm7）
  movdqu xmm0, [rsi + 48]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm11, xmm8
  pshufb xmm11, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm11, xmm7

  movdqu xmm0, [rsi + 32]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm12, xmm8
  pshufb xmm12, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm12, xmm7

  movdqu xmm0, [rsi + 16]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm13, xmm8
  pshufb xmm13, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm13, xmm7

  movdqu xmm0, [rsi]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm14, xmm8
  pshufb xmm14, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm14, xmm7

  // 累加器载入并反射（跨组保持反射域）
  movdqu xmm0, [rdi]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm15, xmm8
  pshufb xmm15, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm15, xmm7

  mov r8d, ecx

@group:
  pxor xmm5, xmm5        // C_L 累计
  pxor xmm6, xmm6        // C_H 累计

  // X1 → P1 = (acc ⊕ X1) · H⁴（A₀ 与 X1 同乘 H⁴，见顶部恒等式；
  //   各乘积输入互不依赖，乱序核并行发射——这是相对串行链的收益来源）
  movdqu xmm0, [rdx]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm1, xmm8
  pshufb xmm1, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm1, xmm7

  pxor xmm1, xmm15       // (A₀ ⊕ X₁)

  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm11, $00   // LO
  pxor xmm5, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm11, $11   // HI
  pxor xmm6, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm11, $01   // MID1
  pclmulqdq xmm1, xmm11, $10   // MID2（原始 X1 消耗于此）
  pxor xmm0, xmm1              // MID
  movdqa xmm7, xmm0
  pslldq xmm7, 8
  pxor xmm5, xmm7              // C_L ^= MID<<64
  psrldq xmm0, 8
  pxor xmm6, xmm0              // C_H ^= MID>>64

  // X2 → P2 = X2 · H³
  movdqu xmm0, [rdx + 16]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm1, xmm8
  pshufb xmm1, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm1, xmm7

  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm12, $00
  pxor xmm5, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm12, $11
  pxor xmm6, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm12, $01
  pclmulqdq xmm1, xmm12, $10
  pxor xmm0, xmm1
  movdqa xmm7, xmm0
  pslldq xmm7, 8
  pxor xmm5, xmm7
  psrldq xmm0, 8
  pxor xmm6, xmm0

  // X3 → P3 = X3 · H²
  movdqu xmm0, [rdx + 32]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm1, xmm8
  pshufb xmm1, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm1, xmm7

  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm13, $00
  pxor xmm5, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm13, $11
  pxor xmm6, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm13, $01
  pclmulqdq xmm1, xmm13, $10
  pxor xmm0, xmm1
  movdqa xmm7, xmm0
  pslldq xmm7, 8
  pxor xmm5, xmm7
  psrldq xmm0, 8
  pxor xmm6, xmm0

  // X4 → P4 = X4 · H¹（A₀ 已折入第一路，此处不再并入 acc）
  movdqu xmm0, [rdx + 48]
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm1, xmm8
  pshufb xmm1, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm1, xmm7

  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm14, $00
  pxor xmm5, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm14, $11
  pxor xmm6, xmm0
  movdqa xmm0, xmm1
  pclmulqdq xmm0, xmm14, $01
  pclmulqdq xmm1, xmm14, $10
  pxor xmm0, xmm1
  movdqa xmm7, xmm0
  pslldq xmm7, 8
  pxor xmm5, xmm7
  psrldq xmm0, 8
  pxor xmm6, xmm0

  // 每组共享规约：red(C_L,C_H) 覆写反射域累加器。
  //   GF(2^128) 规约对 XOR 线性 ⇒ 各组积和可独立规约；A₀ 已在第一路
  //   消费，故本组结果直接作为下一组 A₀（赋值而非 XOR）。
  movdqa xmm2, xmm5
  movdqa xmm3, xmm6
  movdqa xmm4, xmm3
  movdqa xmm5, xmm3
  psllq xmm4, 7
  psrlq xmm5, 57
  pslldq xmm5, 8
  por xmm4, xmm5
  movdqa xmm5, xmm3
  movdqa xmm6, xmm3
  psllq xmm5, 2
  psrlq xmm6, 62
  pslldq xmm6, 8
  por xmm5, xmm6
  movdqa xmm6, xmm3
  movdqa xmm7, xmm3
  psllq xmm6, 1
  psrlq xmm7, 63
  pslldq xmm7, 8
  por xmm6, xmm7
  pxor xmm4, xmm5
  pxor xmm4, xmm6
  pxor xmm4, xmm3
  movdqa xmm5, xmm3
  psrlq xmm5, 57
  psrldq xmm5, 8
  movdqa xmm6, xmm3
  psrlq xmm6, 62
  psrldq xmm6, 8
  pxor xmm5, xmm6
  movdqa xmm6, xmm3
  psrlq xmm6, 63
  psrldq xmm6, 8
  pxor xmm5, xmm6
  movdqa xmm6, xmm5
  movdqa xmm7, xmm5
  psllq xmm6, 7
  pxor xmm5, xmm6
  movdqa xmm6, xmm7
  psllq xmm6, 2
  pxor xmm5, xmm6
  psllq xmm7, 1
  pxor xmm5, xmm7
  pxor xmm2, xmm4
  pxor xmm2, xmm5
  movdqa xmm15, xmm2     // acc := red(本组积和)，作为下一组 A₀

  add rdx, 64
  sub r8d, 4
  jnz @group

  movdqa xmm0, xmm15
  movdqa xmm7, xmm0
  pand xmm7, xmm10
  psrlw xmm0, 4
  pand xmm0, xmm10
  movdqa xmm1, xmm8
  pshufb xmm1, xmm7
  movdqa xmm7, xmm9
  pshufb xmm7, xmm0
  por xmm1, xmm7
  movdqu [rdi], xmm1

@done:
end;
{$ENDIF}


procedure GHASHUpdate(var AState: TAESBlock; const LHPtr: TAESBlock; const AData: TBytes; AOffset, ALen: Integer);
var
  I, J, Blocks, Rem: Integer;
  Block: TAESBlock;
  LPow: TGHASHPowerTable;
  LAggBlocks: Integer;
begin
  Blocks := ALen div 16;
  Rem := ALen mod 16;

  {$IFDEF CPUX86_64}
  if UsePCLMUL and (Blocks > 0) then
  begin
    if Blocks >= 8 then
    begin
      { 聚合路径：≥2 组才值得付幂表构建成本；零头走单块路径续算 }
      BuildGHASHPowerTable(LHPtr, LPow);
      LAggBlocks := (Blocks div 4) * 4;
      GHASHUpdatePCLMULAgg(AState, LPow, @AData[AOffset], LAggBlocks);
      if Blocks > LAggBlocks then
        GHASHUpdatePCLMUL(AState, LHPtr,
          @AData[AOffset + LAggBlocks * 16], Blocks - LAggBlocks);
    end
    else
      GHASHUpdatePCLMUL(AState, LHPtr, @AData[AOffset], Blocks);
    if Rem > 0 then
    begin
      FillChar(Block[0], 16, 0);
      Move(AData[AOffset + Blocks * 16], Block[0], Rem);
      GHASHUpdatePCLMUL(AState, LHPtr, @Block[0], 1);
    end;
    Exit;
  end;
  {$ENDIF}

  for I := 0 to Blocks - 1 do
  begin
    for J := 0 to 15 do
      AState[J] := AState[J] xor AData[AOffset + I * 16 + J];
    GHASHMultiplyScalar(AState, LHPtr);
  end;

  if Rem > 0 then
  begin
    FillChar(Block[0], 16, 0);
    Move(AData[AOffset + Blocks * 16], Block[0], Rem);
    for J := 0 to 15 do
      AState[J] := AState[J] xor Block[J];
    GHASHMultiplyScalar(AState, LHPtr);
  end;
end;

procedure IncrementCounter(var ACounter: TAESBlock);
var
  C: UInt32;
begin
  C := (UInt32(ACounter[12]) shl 24) or (UInt32(ACounter[13]) shl 16) or
       (UInt32(ACounter[14]) shl 8) or UInt32(ACounter[15]);
  Inc(C);
  ACounter[12] := Byte(C shr 24);
  ACounter[13] := Byte(C shr 16);
  ACounter[14] := Byte(C shr 8);
  ACounter[15] := Byte(C);
end;

procedure GCTR(const AExpandedKey: TAESExpandedKey; ANr: Integer;
  const AICB: TAESBlock; const AInput: TBytes; AInputOffset, AInputLen: Integer;
  var AOutput: TBytes; AOutputOffset: Integer);
var
  CB, EncCB: TAESBlock;
  I, J, Blocks, Rem: Integer;
  LCtKey: TAESCt64Key;
begin
  if AInputLen = 0 then Exit;

  Move(AICB[0], CB[0], 16);
  Blocks := AInputLen div 16;
  Rem := AInputLen mod 16;

  // Use CT AES for the non-AES-NI path (this function is only called when AES-NI is unavailable)
  LCtKey.Nr := ANr;
  Move(AExpandedKey[0], LCtKey.RK[0], (ANr + 1) * 4 * SizeOf(UInt32));

  for I := 0 to Blocks - 1 do
  begin
    AESCt64EncryptBlock(@CB[0], @EncCB[0], LCtKey);
    for J := 0 to 15 do
      AOutput[AOutputOffset + I * 16 + J] := AInput[AInputOffset + I * 16 + J] xor EncCB[J];
    IncrementCounter(CB);
  end;

  if Rem > 0 then
  begin
    AESCt64EncryptBlock(@CB[0], @EncCB[0], LCtKey);
    for J := 0 to Rem - 1 do
      AOutput[AOutputOffset + Blocks * 16 + J] := AInput[AInputOffset + Blocks * 16 + J] xor EncCB[J];
  end;
end;

function AESNIGCMEncrypt128(
  const AKey, AIV, APlaintext, AAAD: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  PlainLen, AADLen, I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  SetLength(ACiphertext, 0);
  SetLength(ATag, 0);

  if Length(AIV) <> 12 then Exit;

  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);

  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  PlainLen := Length(APlaintext);
  AADLen := Length(AAAD);
  SetLength(ACiphertext, PlainLen);

  if PlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, @APlaintext[0], PlainLen, @ACiphertext[0]);
  end;

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if PlainLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, PlainLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(PlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  SetLength(ATag, GCM_TAG_SIZE);
  for I := 0 to 15 do
    ATag[I] := S[I] xor EncJ0[I];

  Result := True;
end;

function AESNIGCMEncrypt256(
  const AKey, AIV, APlaintext, AAAD: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  PlainLen, AADLen, I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  SetLength(ACiphertext, 0);
  SetLength(ATag, 0);

  if Length(AIV) <> 12 then Exit;

  AESNIExpandKey256(AKey, NiKey);

  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  PlainLen := Length(APlaintext);
  AADLen := Length(AAAD);
  SetLength(ACiphertext, PlainLen);

  if PlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, @APlaintext[0], PlainLen, @ACiphertext[0]);
  end;

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if PlainLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, PlainLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(PlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  SetLength(ATag, GCM_TAG_SIZE);
  for I := 0 to 15 do
    ATag[I] := S[I] xor EncJ0[I];

  Result := True;
end;

function PurePascalAESGCMEncrypt(
  const AKey, AIV, APlaintext, AAAD: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;
var
  ExpandedKey: TAESExpandedKey;
  Nr: Integer;
  H, J0, S: TAESBlock;
  ZeroBlock: TAESBlock;
  LenBlock: TAESBlock;
  EncJ0: TAESBlock;
  ICB: TAESBlock;
  PlainLen, AADLen: Integer;
  I: Integer;
  AADBits, CTBits: UInt64;
begin
  if UseAESNI then
  begin
    if Length(AKey) = 16 then
      Exit(AESNIGCMEncrypt128(AKey, AIV, APlaintext, AAAD, ACiphertext, ATag));
    if Length(AKey) = 32 then
      Exit(AESNIGCMEncrypt256(AKey, AIV, APlaintext, AAAD, ACiphertext, ATag));
  end;

  Result := False;
  SetLength(ACiphertext, 0);
  SetLength(ATag, 0);

  if not (Length(AKey) in [16, 24, 32]) then Exit;
  if Length(AIV) <> 12 then Exit;

  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then Exit;

  FillChar(ZeroBlock[0], 16, 0);
  AESEncryptBlock(ZeroBlock, H, ExpandedKey, Nr);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  PlainLen := Length(APlaintext);
  AADLen := Length(AAAD);

  SetLength(ACiphertext, PlainLen);

  if PlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(ICB);
    GCTR(ExpandedKey, Nr, ICB, APlaintext, 0, PlainLen, ACiphertext, 0);
  end;

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if PlainLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, PlainLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(PlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESEncryptBlock(J0, EncJ0, ExpandedKey, Nr);
  SetLength(ATag, GCM_TAG_SIZE);
  for I := 0 to 15 do
    ATag[I] := S[I] xor EncJ0[I];

  Result := True;
end;

function AESNIGCMDecrypt128(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  out APlaintext: TBytes
): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  CTLen, AADLen, I: Integer;
  TagBytes: TBytes;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  SetLength(APlaintext, 0);

  if Length(AIV) <> 12 then Exit;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;

  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);

  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  CTLen := Length(ACiphertext);
  AADLen := Length(AAAD);

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if CTLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, CTLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(CTLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  SetLength(TagBytes, GCM_TAG_SIZE);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];

  if TConstantTime.CompareBytes(TagBytes, ATag) <> 1 then
    Exit(False);

  SetLength(APlaintext, CTLen);
  if CTLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, @ACiphertext[0], CTLen, @APlaintext[0]);
  end;

  Result := True;
end;

function AESNIGCMDecrypt256(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  out APlaintext: TBytes
): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  CTLen, AADLen, I: Integer;
  TagBytes: TBytes;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  SetLength(APlaintext, 0);

  if Length(AIV) <> 12 then Exit;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;

  AESNIExpandKey256(AKey, NiKey);

  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  CTLen := Length(ACiphertext);
  AADLen := Length(AAAD);

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if CTLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, CTLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(CTLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  SetLength(TagBytes, GCM_TAG_SIZE);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];

  if TConstantTime.CompareBytes(TagBytes, ATag) <> 1 then
    Exit(False);

  SetLength(APlaintext, CTLen);
  if CTLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, @ACiphertext[0], CTLen, @APlaintext[0]);
  end;

  Result := True;
end;

function PurePascalAESGCMDecrypt(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  out APlaintext: TBytes
): Boolean;
var
  ExpandedKey: TAESExpandedKey;
  Nr: Integer;
  H, J0, S: TAESBlock;
  ZeroBlock: TAESBlock;
  LenBlock: TAESBlock;
  EncJ0: TAESBlock;
  ICB: TAESBlock;
  CTLen, AADLen: Integer;
  I: Integer;
  TagBytes: TBytes;
  AADBits, CTBits: UInt64;
begin
  if UseAESNI then
  begin
    if Length(AKey) = 16 then
      Exit(AESNIGCMDecrypt128(AKey, AIV, ACiphertext, ATag, AAAD, APlaintext));
    if Length(AKey) = 32 then
      Exit(AESNIGCMDecrypt256(AKey, AIV, ACiphertext, ATag, AAAD, APlaintext));
  end;

  Result := False;
  SetLength(APlaintext, 0);

  if not (Length(AKey) in [16, 24, 32]) then Exit;
  if Length(AIV) <> 12 then Exit;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;

  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then Exit;

  FillChar(ZeroBlock[0], 16, 0);
  AESEncryptBlock(ZeroBlock, H, ExpandedKey, Nr);

  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;

  CTLen := Length(ACiphertext);
  AADLen := Length(AAAD);

  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if CTLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, CTLen);

  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(CTLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);

  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);

  AESEncryptBlock(J0, EncJ0, ExpandedKey, Nr);
  SetLength(TagBytes, GCM_TAG_SIZE);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];

  if TConstantTime.CompareBytes(TagBytes, ATag) <> 1 then
    Exit(False);

  SetLength(APlaintext, CTLen);
  if CTLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(ICB);
    GCTR(ExpandedKey, Nr, ICB, ACiphertext, 0, CTLen, APlaintext, 0);
  end;

  Result := True;
end;

procedure GHASHUpdatePByte(var AState: TAESBlock; const H: TAESBlock; AData: PByte; ALen: Integer);
var
  LBlock: TAESBlock;
  J: Integer;
  LOff: Integer;
  LBlocks: Integer;
  LRem: Integer;
{$IFDEF CPUX86_64}
  LPow: TGHASHPowerTable;
  LAggBlocks: Integer;
{$ENDIF}
begin
  LBlocks := ALen div 16;
  LRem := ALen mod 16;
{$IFDEF CPUX86_64}
  if UsePCLMUL and (LBlocks > 0) then
  begin
    if LBlocks >= 8 then
    begin
      BuildGHASHPowerTable(H, LPow);
      LAggBlocks := (LBlocks div 4) * 4;
      GHASHUpdatePCLMULAgg(AState, LPow, AData, LAggBlocks);
      if LBlocks > LAggBlocks then
        GHASHUpdatePCLMUL(AState, H, AData + LAggBlocks * 16, LBlocks - LAggBlocks);
    end
    else
      GHASHUpdatePCLMUL(AState, H, AData, LBlocks);
    if LRem > 0 then
    begin
      FillChar(LBlock[0], 16, 0);
      Move((AData + LBlocks * 16)^, LBlock[0], LRem);
      GHASHUpdatePCLMUL(AState, H, @LBlock[0], 1);
    end;
    Exit;
  end;
{$ENDIF}
  LOff := 0;
  for J := 0 to LBlocks - 1 do
  begin
    AState[0] := AState[0] xor AData[LOff];
    AState[1] := AState[1] xor AData[LOff + 1];
    AState[2] := AState[2] xor AData[LOff + 2];
    AState[3] := AState[3] xor AData[LOff + 3];
    AState[4] := AState[4] xor AData[LOff + 4];
    AState[5] := AState[5] xor AData[LOff + 5];
    AState[6] := AState[6] xor AData[LOff + 6];
    AState[7] := AState[7] xor AData[LOff + 7];
    AState[8] := AState[8] xor AData[LOff + 8];
    AState[9] := AState[9] xor AData[LOff + 9];
    AState[10] := AState[10] xor AData[LOff + 10];
    AState[11] := AState[11] xor AData[LOff + 11];
    AState[12] := AState[12] xor AData[LOff + 12];
    AState[13] := AState[13] xor AData[LOff + 13];
    AState[14] := AState[14] xor AData[LOff + 14];
    AState[15] := AState[15] xor AData[LOff + 15];
    GHASHMultiplySingle(AState, H);
    Inc(LOff, 16);
  end;
  if LRem > 0 then
  begin
    FillChar(LBlock[0], 16, 0);
    Move(AData[LOff], LBlock[0], LRem);
    for J := 0 to 15 do
      AState[J] := AState[J] xor LBlock[J];
    GHASHMultiplySingle(AState, H);
  end;
end;

procedure GCTRTo(const AExpandedKey: TAESExpandedKey; ANr: Integer;
  const AICB: TAESBlock; ACipher: PByte; ACipherLen: Integer; APlainOut: PByte);
var
  CB, EncCB: TAESBlock;
  J, Blocks, Rem: Integer;
  LCtKey: TAESCt64Key;
  LOff: Integer;
begin
  if ACipherLen = 0 then Exit;
  Move(AICB[0], CB[0], 16);
  Blocks := ACipherLen div 16;
  Rem := ACipherLen mod 16;
  LCtKey.Nr := ANr;
  Move(AExpandedKey[0], LCtKey.RK[0], (ANr + 1) * 4 * SizeOf(UInt32));
  LOff := 0;
  for J := 0 to Blocks - 1 do
  begin
    AESCt64EncryptBlock(@CB[0], @EncCB[0], LCtKey);
    PUInt64(APlainOut + LOff)^ := PUInt64(ACipher + LOff)^ xor PUInt64(@EncCB[0])^;
    PUInt64(APlainOut + LOff + 8)^ := PUInt64(ACipher + LOff + 8)^ xor PUInt64(@EncCB[8])^;
    IncrementCounter(CB);
    Inc(LOff, 16);
  end;
  if Rem > 0 then
  begin
    AESCt64EncryptBlock(@CB[0], @EncCB[0], LCtKey);
    for J := 0 to Rem - 1 do
      APlainOut[LOff + J] := ACipher[LOff + J] xor EncCB[J];
  end;
end;

function AESNIGCMDecryptTo128(
  const AKey, AIV: TBytes; ACipher: PByte; ACipherLen: Integer;
  const ATag, AAAD: TBytes; ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
begin
  Result := False;
  if Length(AIV) <> 12 then Exit;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 16 then Exit;
  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], @ATag[0], GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMDecryptTo256(
  const AKey, AIV: TBytes; ACipher: PByte; ACipherLen: Integer;
  const ATag, AAAD: TBytes; ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
begin
  Result := False;
  if Length(AIV) <> 12 then Exit;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 32 then Exit;
  AESNIExpandKey256(AKey, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], @ATag[0], GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMDecryptTo128Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ATag = nil) and (ACipherLen >= 0) then
    if GCM_TAG_SIZE <> 0 then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 16 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (ATag = nil) and (GCM_TAG_SIZE > 0) then Exit;
  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], ATag, GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMDecryptTo256Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 32 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (ATag = nil) and (GCM_TAG_SIZE > 0) then Exit;
  AESNIExpandKey256(AKey, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], ATag, GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMEncryptTo128Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (APlainLen + 16 > 0) then Exit;
  if ADestLen < APlainLen + 16 then Exit;
  if Length(AKey) <> 16 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  if APlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, APlain, APlainLen, ADest);
  end;
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if APlainLen > 0 then
    GHASHUpdatePByte(S, H, ADest, APlainLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(APlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    (ADest + APlainLen)[I] := S[I] xor EncJ0[I];
  Result := True;
end;

function AESNIGCMEncryptTo256Ptr(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; const AAAD: TBytes;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (APlainLen + 16 > 0) then Exit;
  if ADestLen < APlainLen + 16 then Exit;
  if Length(AKey) <> 32 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  AESNIExpandKey256(AKey, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  if APlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, APlain, APlainLen, ADest);
  end;
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if APlainLen > 0 then
    GHASHUpdatePByte(S, H, ADest, APlainLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(APlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    (ADest + APlainLen)[I] := S[I] xor EncJ0[I];
  Result := True;
end;

function PurePascalAESGCMDecryptTo(
  const AKey, AIV, ACiphertext, ATag, AAAD: TBytes;
  APlaintext: PByte; APlainLen: Integer
): Boolean;
var
  LCTLen: Integer;
  ExpandedKey: TAESExpandedKey;
  Nr: Integer;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESBlock;
  ICB: TAESBlock;
  LenBlock: TAESBlock;
  AADLen, I: Integer;
  TagBytes: TAESBlock;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if Length(ATag) <> GCM_TAG_SIZE then Exit;
  if Length(AIV) <> 12 then Exit;
  LCTLen := Length(ACiphertext);
  if (APlaintext = nil) and (LCTLen > 0) then Exit;
  if APlainLen < LCTLen then Exit;
  if UseAESNI then
  begin
    if Length(AKey) = 16 then
    begin
      if LCTLen = 0 then
        Exit(AESNIGCMDecryptTo128(AKey, AIV, nil, 0, ATag, AAAD, APlaintext, APlainLen))
      else
        Exit(AESNIGCMDecryptTo128(AKey, AIV, @ACiphertext[0], LCTLen, ATag, AAAD, APlaintext, APlainLen));
    end;
    if Length(AKey) = 32 then
    begin
      if LCTLen = 0 then
        Exit(AESNIGCMDecryptTo256(AKey, AIV, nil, 0, ATag, AAAD, APlaintext, APlainLen))
      else
        Exit(AESNIGCMDecryptTo256(AKey, AIV, @ACiphertext[0], LCTLen, ATag, AAAD, APlaintext, APlainLen));
    end;
  end;
  if not (Length(AKey) in [16, 24, 32]) then Exit;
  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then Exit;
  FillChar(ZeroBlock[0], 16, 0);
  AESEncryptBlock(ZeroBlock, H, ExpandedKey, Nr);
  FillChar(J0[0], 16, 0);
  Move(AIV[0], J0[0], 12);
  J0[15] := 1;
  AADLen := Length(AAAD);
  FillChar(S[0], 16, 0);
  if AADLen > 0 then
    GHASHUpdate(S, H, AAAD, 0, AADLen);
  if LCTLen > 0 then
    GHASHUpdate(S, H, ACiphertext, 0, LCTLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AADLen) * 8;
  CTBits := UInt64(LCTLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESEncryptBlock(J0, EncJ0, ExpandedKey, Nr);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], @ATag[0], GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if LCTLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(ICB);
    GCTRTo(ExpandedKey, Nr, ICB, @ACiphertext[0], LCTLen, APlaintext);
  end;
  Result := True;
end;

function PurePascalAESGCMEncryptPtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  ExpandedKey: TAESExpandedKey;
  Nr, I: Integer;
  H, J0, S, EncJ0, ICB: TAESBlock;
  ZeroBlock: TAESBlock;
  LenBlock: TAESBlock;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (APlainLen + 16 > 0) then Exit;
  if ADestLen < APlainLen + 16 then Exit;
  if not (Length(AKey) in [16, 24, 32]) then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then Exit;
  FillChar(ZeroBlock[0], 16, 0);
  AESEncryptBlock(ZeroBlock, H, ExpandedKey, Nr);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  if APlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(ICB);
    // zero-copy PByte CTR via GCTRTo (CT64 constant-time, no TBytes alloc) — single source
    if APlain <> nil then
      GCTRTo(ExpandedKey, Nr, ICB, APlain, APlainLen, ADest);
  end;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if APlainLen > 0 then
    GHASHUpdatePByte(S, H, ADest, APlainLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(APlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESEncryptBlock(J0, EncJ0, ExpandedKey, Nr);
  for I := 0 to 15 do
    (ADest + APlainLen)[I] := S[I] xor EncJ0[I];
  Result := True;
end;

function PurePascalAESGCMDecryptPtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  ExpandedKey: TAESExpandedKey;
  Nr, I: Integer;
  H, J0, S, EncJ0, ICB: TAESBlock;
  ZeroBlock: TAESBlock;
  LenBlock: TAESBlock;
  TagBytes: TAESBlock;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if ATag = nil then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if not (Length(AKey) in [16, 24, 32]) then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  if (ACipher = nil) and (ACipherLen > 0) then Exit;
  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then Exit;
  FillChar(ZeroBlock[0], 16, 0);
  AESEncryptBlock(ZeroBlock, H, ExpandedKey, Nr);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESEncryptBlock(J0, EncJ0, ExpandedKey, Nr);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], ATag, GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(ICB);
    GCTRTo(ExpandedKey, Nr, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMEncryptTo128PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (APlainLen + 16 > 0) then Exit;
  if ADestLen < APlainLen + 16 then Exit;
  if Length(AKey) <> 16 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  if APlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, APlain, APlainLen, ADest);
  end;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if APlainLen > 0 then
    GHASHUpdatePByte(S, H, ADest, APlainLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(APlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    (ADest + APlainLen)[I] := S[I] xor EncJ0[I];
  Result := True;
end;

function AESNIGCMEncryptTo256PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  APlain: PByte; APlainLen: Integer; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  ICB: TAESNIBlock;
  LenBlock: TAESBlock;
  I: Integer;
  AADBits, CTBits: UInt64;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ADest = nil) and (APlainLen + 16 > 0) then Exit;
  if ADestLen < APlainLen + 16 then Exit;
  if Length(AKey) <> 32 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  AESNIExpandKey256(AKey, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  if APlainLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, APlain, APlainLen, ADest);
  end;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if APlainLen > 0 then
    GHASHUpdatePByte(S, H, ADest, APlainLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(APlainLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    (ADest + APlainLen)[I] := S[I] xor EncJ0[I];
  Result := True;
end;

function AESNIGCMDecryptTo128PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey128;
  KeyBlock: TAESNIBlock;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  LenBlock: TAESBlock;
  I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
  ICB: TAESBlock;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ATag = nil) then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 16 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  if (ACipher = nil) and (ACipherLen > 0) then Exit;
  Move(AKey[0], KeyBlock[0], 16);
  AESNIExpandKey128(KeyBlock, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock128(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock128(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], ATag, GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR128(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

function AESNIGCMDecryptTo256PtrAAD(
  const AKey: TBytes; ANonce: PByte; ANonceLen: Integer;
  ACipher: PByte; ACipherLen: Integer; ATag: PByte; AAAD: PByte; AAADLen: Integer;
  ADest: PByte; ADestLen: Integer): Boolean;
var
  NiKey: TAESNIExpandedKey256;
  H, J0, S: TAESBlock;
  ZeroBlock, EncJ0: TAESNIBlock;
  LenBlock: TAESBlock;
  I: Integer;
  AADBits, CTBits: UInt64;
  TagBytes: TAESBlock;
  ICB: TAESBlock;
begin
  Result := False;
  if ANonceLen <> 12 then Exit;
  if (ATag = nil) then Exit;
  if (ADest = nil) and (ACipherLen > 0) then Exit;
  if ADestLen < ACipherLen then Exit;
  if Length(AKey) <> 32 then Exit;
  if (ANonce = nil) and (ANonceLen > 0) then Exit;
  if (AAAD = nil) and (AAADLen > 0) then Exit;
  if (ACipher = nil) and (ACipherLen > 0) then Exit;
  AESNIExpandKey256(AKey, NiKey);
  FillChar(ZeroBlock[0], 16, 0);
  AESNIEncryptBlock256(ZeroBlock, TAESNIBlock(H), NiKey);
  FillChar(J0[0], 16, 0);
  Move(ANonce^, J0[0], 12);
  J0[15] := 1;
  FillChar(S[0], 16, 0);
  if AAADLen > 0 then
    GHASHUpdatePByte(S, H, AAAD, AAADLen);
  if ACipherLen > 0 then
    GHASHUpdatePByte(S, H, ACipher, ACipherLen);
  FillChar(LenBlock[0], 16, 0);
  AADBits := UInt64(AAADLen) * 8;
  CTBits := UInt64(ACipherLen) * 8;
  LenBlock[0] := Byte(AADBits shr 56);
  LenBlock[1] := Byte(AADBits shr 48);
  LenBlock[2] := Byte(AADBits shr 40);
  LenBlock[3] := Byte(AADBits shr 32);
  LenBlock[4] := Byte(AADBits shr 24);
  LenBlock[5] := Byte(AADBits shr 16);
  LenBlock[6] := Byte(AADBits shr 8);
  LenBlock[7] := Byte(AADBits);
  LenBlock[8] := Byte(CTBits shr 56);
  LenBlock[9] := Byte(CTBits shr 48);
  LenBlock[10] := Byte(CTBits shr 40);
  LenBlock[11] := Byte(CTBits shr 32);
  LenBlock[12] := Byte(CTBits shr 24);
  LenBlock[13] := Byte(CTBits shr 16);
  LenBlock[14] := Byte(CTBits shr 8);
  LenBlock[15] := Byte(CTBits);
  for I := 0 to 15 do
    S[I] := S[I] xor LenBlock[I];
  GHASHMultiplySingle(S, H);
  AESNIEncryptBlock256(TAESNIBlock(J0), EncJ0, NiKey);
  for I := 0 to 15 do
    TagBytes[I] := S[I] xor EncJ0[I];
  if TConstantTime.CompareBuffer(@TagBytes[0], ATag, GCM_TAG_SIZE) <> 1 then
    Exit(False);
  if ACipherLen > 0 then
  begin
    Move(J0[0], ICB[0], 16);
    IncrementCounter(TAESBlock(ICB));
    AESNIEncryptCTR256(NiKey, ICB, ACipher, ACipherLen, ADest);
  end;
  Result := True;
end;

end.
