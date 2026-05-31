unit nextpas.core.hash.sha256;

{$mode objfpc}{$H+}

{ nextpas.core.hash.sha256 — SHA-256 实现 (FIPS 180-4)

  性能设计：
  - Write 使用 Move 块拷贝，完整块直接从输入 buffer 处理（零拷贝）
  - Sum 不改变状态（复制 state 后 finalize）
  - 预留 SHA-NI 硬件加速 dispatch (via nextpas.core.simd.vec16)
}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.hash.base,
  nextpas.core.hash.intf;

type
  TSHA256Hasher = class(TInterfacedObject, IHasher)
  private
    FH: array[0..7] of UInt32;
    FBuf: array[0..63] of Byte;
    FBufLen: SizeUInt;
    FTotalLen: UInt64;
    procedure ProcessBlock(ABlock: PByte);
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
    function Clone: IHasher;
  end;

function NewSHA256: IHasher;

implementation

const
  K: array[0..63] of UInt32 = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
    $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3,
    $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
    $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7,
    $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
    $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
    $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
    $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208,
    $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

function RR(AX: UInt32; AN: Integer): UInt32; inline;
begin
  Result := (AX shr AN) or (AX shl (32 - AN));
end;

procedure ProcessBlockLocal(ABlock: PByte; var AH: array of UInt32);
var
  W: array[0..63] of UInt32;
  A, B, C, D, E, F, G, H: UInt32;
  T1, T2: UInt32;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (UInt32(ABlock[I*4]) shl 24) or (UInt32(ABlock[I*4+1]) shl 16)
          or (UInt32(ABlock[I*4+2]) shl 8) or UInt32(ABlock[I*4+3]);

  for I := 16 to 63 do
    W[I] := (RR(W[I-2],17) xor RR(W[I-2],19) xor (W[I-2] shr 10))
           + W[I-7]
           + (RR(W[I-15],7) xor RR(W[I-15],18) xor (W[I-15] shr 3))
           + W[I-16];

  A := AH[0]; B := AH[1]; C := AH[2]; D := AH[3];
  E := AH[4]; F := AH[5]; G := AH[6]; H := AH[7];

  for I := 0 to 63 do
  begin
    T1 := H + (RR(E,6) xor RR(E,11) xor RR(E,25))
        + ((E and F) xor ((not E) and G)) + K[I] + W[I];
    T2 := (RR(A,2) xor RR(A,13) xor RR(A,22))
        + ((A and B) xor (A and C) xor (B and C));
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;

  Inc(AH[0], A); Inc(AH[1], B); Inc(AH[2], C); Inc(AH[3], D);
  Inc(AH[4], E); Inc(AH[5], F); Inc(AH[6], G); Inc(AH[7], H);
end;

{ TSHA256Hasher }

constructor TSHA256Hasher.Create;
begin
  inherited Create;
  Reset;
end;

procedure TSHA256Hasher.Reset;
begin
  FH[0] := $6a09e667; FH[1] := $bb67ae85;
  FH[2] := $3c6ef372; FH[3] := $a54ff53a;
  FH[4] := $510e527f; FH[5] := $9b05688c;
  FH[6] := $1f83d9ab; FH[7] := $5be0cd19;
  FBufLen := 0;
  FTotalLen := 0;
end;

{$IFDEF CPUX86_64}
{$I nextpas.core.hash.sha256.x64.inc}
{$I nextpas.core.hash.sha256.x64v2.inc}
{$I nextpas.core.hash.sha256.avx2.inc}
{$I nextpas.core.hash.sha256.avx2dual.inc}
{$I nextpas.core.hash.sha256.shani.inc}
{$ENDIF}

{$IFDEF CPUX86_64}
var
  GHasSHANI: Boolean = False;
  GHasAVX2: Boolean = False;
  GHasAVX: Boolean = False;
  GHasSSSE3: Boolean = False;
  GDispatchInitialized: Boolean = False;

procedure InitSHA256Dispatch;
var
  LEax, LEbx, LEcx, LEdx: DWord;
begin
  if GDispatchInitialized then
    Exit;
  LEax := 0; LEbx := 0; LEcx := 0; LEdx := 0;
  asm
    movl $1, %eax
    cpuid
    movl %ecx, LEcx
  end ['eax', 'ebx', 'ecx', 'edx'];
  GHasSSSE3 := (LEcx and (1 shl 9)) <> 0;
  GHasAVX := (LEcx and (1 shl 28)) <> 0;
  LEbx := 0;
  asm
    movl $7, %eax
    xorl %ecx, %ecx
    cpuid
    movl %ebx, LEbx
  end ['eax', 'ebx', 'ecx', 'edx'];
  GHasSHANI := (LEbx and (1 shl 29)) <> 0;
  GHasAVX2 := GHasAVX and ((LEbx and (1 shl 5)) <> 0) and ((LEbx and (1 shl 8)) <> 0);
  if GHasAVX then
    GHasAVX := (LEbx and (1 shl 8)) <> 0;
  if GHasSSSE3 then
    GHasSSSE3 := (LEbx and (1 shl 8)) <> 0;
  GDispatchInitialized := True;
end;
{$ENDIF}

procedure TSHA256Hasher.ProcessBlock(ABlock: PByte);
begin
  {$IFDEF CPUX86_64}
  if GHasSHANI then
    ProcessBlockSHANI(ABlock, @FH[0])
  else if GHasAVX2 then
    ProcessBlockAVX2(ABlock, @FH[0])
  else if GHasSSSE3 then
    ProcessBlockX64V2(ABlock, @FH[0])
  else
    ProcessBlockX64(ABlock, @FH[0]);
  {$ELSE}
  ProcessBlockLocal(ABlock, FH);
  {$ENDIF}
end;

function TSHA256Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LCopy: SizeUInt;
begin
  Result := ACount;
  LSrc := @ABuf;
  LRemaining := ACount;
  Inc(FTotalLen, ACount);

  if FBufLen > 0 then
  begin
    LCopy := SHA256_BLOCK_SIZE - FBufLen;
    if LCopy > LRemaining then
      LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy);
    Inc(FBufLen, LCopy);
    Inc(LSrc, LCopy);
    Dec(LRemaining, LCopy);
    if FBufLen = SHA256_BLOCK_SIZE then
    begin
      ProcessBlock(@FBuf[0]);
      FBufLen := 0;
    end;
  end;

  {$IFDEF CPUX86_64}
  while (LRemaining >= 128) and GHasAVX2 do
  begin
    ProcessBlocks2AVX2(LSrc, @FH[0]);
    Inc(LSrc, 128);
    Dec(LRemaining, 128);
  end;
  {$ENDIF}

  while LRemaining >= SHA256_BLOCK_SIZE do
  begin
    ProcessBlock(LSrc);
    Inc(LSrc, SHA256_BLOCK_SIZE);
    Dec(LRemaining, SHA256_BLOCK_SIZE);
  end;

  if LRemaining > 0 then
  begin
    Move(LSrc^, FBuf[0], LRemaining);
    FBufLen := LRemaining;
  end;
end;

procedure TSHA256Hasher.Sum(out ADst; const ASize: SizeUInt);
var
  LH: array[0..7] of UInt32;
  LBuf: array[0..63] of Byte;
  LBufLen: SizeUInt;
  LTotalBits: UInt64;
  LPadLen: SizeUInt;
  I: Integer;
  LDst: PByte;
begin
  Move(FH[0], LH[0], SizeOf(FH));
  Move(FBuf[0], LBuf[0], FBufLen);
  LBufLen := FBufLen;
  LTotalBits := FTotalLen * 8;

  LBuf[LBufLen] := $80;
  Inc(LBufLen);

  if LBufLen > 56 then
  begin
    while LBufLen < 64 do
    begin
      LBuf[LBufLen] := 0;
      Inc(LBufLen);
    end;
    {$IFDEF CPUX86_64}
    if GHasSHANI then
      ProcessBlockSHANI(@LBuf[0], @LH[0])
    else if GHasSSSE3 then
      ProcessBlockX64V2(@LBuf[0], @LH[0])
    else
      ProcessBlockX64(@LBuf[0], @LH[0]);
    {$ELSE}
    ProcessBlockLocal(@LBuf[0], LH);
    {$ENDIF}
    LBufLen := 0;
  end;

  while LBufLen < 56 do
  begin
    LBuf[LBufLen] := 0;
    Inc(LBufLen);
  end;

  LBuf[56] := Byte(LTotalBits shr 56);
  LBuf[57] := Byte(LTotalBits shr 48);
  LBuf[58] := Byte(LTotalBits shr 40);
  LBuf[59] := Byte(LTotalBits shr 32);
  LBuf[60] := Byte(LTotalBits shr 24);
  LBuf[61] := Byte(LTotalBits shr 16);
  LBuf[62] := Byte(LTotalBits shr 8);
  LBuf[63] := Byte(LTotalBits);

  {$IFDEF CPUX86_64}
  if GHasSHANI then
    ProcessBlockSHANI(@LBuf[0], @LH[0])
  else if GHasSSSE3 then
    ProcessBlockX64V2(@LBuf[0], @LH[0])
  else
    ProcessBlockX64(@LBuf[0], @LH[0]);
  {$ELSE}
  ProcessBlockLocal(@LBuf[0], LH);
  {$ENDIF}

  LDst := @ADst;
  for I := 0 to 7 do
  begin
    LDst[I*4]   := Byte(LH[I] shr 24);
    LDst[I*4+1] := Byte(LH[I] shr 16);
    LDst[I*4+2] := Byte(LH[I] shr 8);
    LDst[I*4+3] := Byte(LH[I]);
  end;
end;

function TSHA256Hasher.SumBytes: TBytes;
begin
  SetLength(Result, SHA256_DIGEST_SIZE);
  Sum(Result[0], SHA256_DIGEST_SIZE);
end;

function TSHA256Hasher.DigestSize: SizeUInt;
begin
  Result := SHA256_DIGEST_SIZE;
end;

function TSHA256Hasher.BlockSize: SizeUInt;
begin
  Result := SHA256_BLOCK_SIZE;
end;

function TSHA256Hasher.Clone: IHasher;
var
  LClone: TSHA256Hasher;
begin
  LClone := TSHA256Hasher.Create;
  Move(FH[0], LClone.FH[0], SizeOf(FH));
  Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
  LClone.FBufLen := FBufLen;
  LClone.FTotalLen := FTotalLen;
  Result := LClone;
end;

function NewSHA256: IHasher;
begin
  Result := TSHA256Hasher.Create;
end;

{$IFDEF CPUX86_64}
initialization
  InitSHA256Dispatch;
{$ENDIF}

end.
