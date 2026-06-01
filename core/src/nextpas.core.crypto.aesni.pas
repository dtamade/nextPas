unit nextpas.core.crypto.aesni;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Math;

type
  TAESNIBlock = array[0..15] of Byte;
  TAESNIExpandedKey128 = array[0..10, 0..15] of Byte;
  TAESNIExpandedKey256 = array[0..14, 0..15] of Byte;

function IsAESNIAvailable: Boolean;

function IsAESNI256Available: Boolean;

procedure AESNIExpandKey128(const AKey: TAESNIBlock; out AExpandedKey: TAESNIExpandedKey128);

procedure AESNIEncryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128);
procedure AESNIDecryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128);

procedure AESNIEncryptCTR128(const AKey: TAESNIExpandedKey128;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);

procedure AESNIExpandKey256(const AKey: array of Byte; out AExpandedKey: TAESNIExpandedKey256);

procedure AESNIEncryptBlock256(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey256);

procedure AESNIEncryptCTR256(const AKey: TAESNIExpandedKey256;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);

implementation

{$IFDEF CPUX86_64}
{$ASMMODE INTEL}

function IsAESNIAvailable: Boolean; assembler; nostackframe;
asm
  push rbx
  mov eax, 1
  cpuid
  bt ecx, 25
  setc al
  movzx eax, al
  pop rbx
end;

procedure AESNIExpandKey128(const AKey: TAESNIBlock; out AExpandedKey: TAESNIExpandedKey128);
assembler; nostackframe;
asm
  movdqu xmm1, [AKey]
  movdqu [AExpandedKey], xmm1

  aeskeygenassist xmm2, xmm1, $01
  call @expand
  movdqu [AExpandedKey + 16], xmm1
  aeskeygenassist xmm2, xmm1, $02
  call @expand
  movdqu [AExpandedKey + 32], xmm1
  aeskeygenassist xmm2, xmm1, $04
  call @expand
  movdqu [AExpandedKey + 48], xmm1
  aeskeygenassist xmm2, xmm1, $08
  call @expand
  movdqu [AExpandedKey + 64], xmm1
  aeskeygenassist xmm2, xmm1, $10
  call @expand
  movdqu [AExpandedKey + 80], xmm1
  aeskeygenassist xmm2, xmm1, $20
  call @expand
  movdqu [AExpandedKey + 96], xmm1
  aeskeygenassist xmm2, xmm1, $40
  call @expand
  movdqu [AExpandedKey + 112], xmm1
  aeskeygenassist xmm2, xmm1, $80
  call @expand
  movdqu [AExpandedKey + 128], xmm1
  aeskeygenassist xmm2, xmm1, $1b
  call @expand
  movdqu [AExpandedKey + 144], xmm1
  aeskeygenassist xmm2, xmm1, $36
  call @expand
  movdqu [AExpandedKey + 160], xmm1
  ret

@expand:
  pshufd xmm2, xmm2, $ff
  movdqa xmm3, xmm1
  pslldq xmm3, 4
  pxor xmm1, xmm3
  movdqa xmm3, xmm1
  pslldq xmm3, 4
  pxor xmm1, xmm3
  movdqa xmm3, xmm1
  pslldq xmm3, 4
  pxor xmm1, xmm3
  pxor xmm1, xmm2
  ret
end;

procedure AESNIEncryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128); assembler; nostackframe;
asm
  movdqu xmm0, [AInput]
  movdqu xmm1, [AExpandedKey]
  pxor xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 16]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 32]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 48]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 64]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 80]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 96]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 112]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 128]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 144]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 160]
  aesenclast xmm0, xmm1
  movdqu [AOutput], xmm0
end;

procedure AESNIDecryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128); assembler; nostackframe;
asm
  movdqu xmm0, [AInput]
  movdqu xmm1, [AExpandedKey + 160]
  pxor xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 144]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 128]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 112]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 96]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 80]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 64]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 48]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 32]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 16]
  aesimc xmm1, xmm1
  aesdec xmm0, xmm1
  movdqu xmm1, [AExpandedKey]
  aesdeclast xmm0, xmm1
  movdqu [AOutput], xmm0
end;

function IsAESNI256Available: Boolean;
begin
  Result := IsAESNIAvailable;
end;

procedure AESNIExpandKey256(const AKey: array of Byte; out AExpandedKey: TAESNIExpandedKey256);
const
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
  Rcon: array[0..6] of Byte = ($01,$02,$04,$08,$10,$20,$40);
var
  W: array[0..59] of UInt32;
  I: Integer;
  Temp: UInt32;
begin
  for I := 0 to 7 do
    W[I] := (UInt32(AKey[I*4]) shl 24) or (UInt32(AKey[I*4+1]) shl 16) or
            (UInt32(AKey[I*4+2]) shl 8) or UInt32(AKey[I*4+3]);

  for I := 8 to 59 do
  begin
    Temp := W[I-1];
    if (I mod 8) = 0 then
    begin
      Temp := (Temp shl 8) or (Temp shr 24);
      Temp := (UInt32(SBox[(Temp shr 24) and $FF]) shl 24) or
              (UInt32(SBox[(Temp shr 16) and $FF]) shl 16) or
              (UInt32(SBox[(Temp shr 8) and $FF]) shl 8) or
              UInt32(SBox[Temp and $FF]);
      Temp := Temp xor (UInt32(Rcon[I div 8 - 1]) shl 24);
    end
    else if (I mod 8) = 4 then
    begin
      Temp := (UInt32(SBox[(Temp shr 24) and $FF]) shl 24) or
              (UInt32(SBox[(Temp shr 16) and $FF]) shl 16) or
              (UInt32(SBox[(Temp shr 8) and $FF]) shl 8) or
              UInt32(SBox[Temp and $FF]);
    end;
    W[I] := W[I-8] xor Temp;
  end;

  for I := 0 to 14 do
  begin
    AExpandedKey[I][0] := Byte(W[I*4] shr 24);
    AExpandedKey[I][1] := Byte(W[I*4] shr 16);
    AExpandedKey[I][2] := Byte(W[I*4] shr 8);
    AExpandedKey[I][3] := Byte(W[I*4]);
    AExpandedKey[I][4] := Byte(W[I*4+1] shr 24);
    AExpandedKey[I][5] := Byte(W[I*4+1] shr 16);
    AExpandedKey[I][6] := Byte(W[I*4+1] shr 8);
    AExpandedKey[I][7] := Byte(W[I*4+1]);
    AExpandedKey[I][8] := Byte(W[I*4+2] shr 24);
    AExpandedKey[I][9] := Byte(W[I*4+2] shr 16);
    AExpandedKey[I][10] := Byte(W[I*4+2] shr 8);
    AExpandedKey[I][11] := Byte(W[I*4+2]);
    AExpandedKey[I][12] := Byte(W[I*4+3] shr 24);
    AExpandedKey[I][13] := Byte(W[I*4+3] shr 16);
    AExpandedKey[I][14] := Byte(W[I*4+3] shr 8);
    AExpandedKey[I][15] := Byte(W[I*4+3]);
  end;
end;

procedure AESNIEncryptBlock256(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey256); assembler; nostackframe;
asm
  movdqu xmm0, [AInput]
  movdqu xmm1, [AExpandedKey]
  pxor xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 16]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 32]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 48]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 64]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 80]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 96]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 112]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 128]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 144]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 160]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 176]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 192]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 208]
  aesenc xmm0, xmm1
  movdqu xmm1, [AExpandedKey + 224]
  aesenclast xmm0, xmm1
  movdqu [AOutput], xmm0
end;

procedure AESNIEncryptCTR256(const AKey: TAESNIExpandedKey256;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);
var
  LCtr: TAESNIBlock;
  LEnc: TAESNIBlock;
  LCtrs: array[0..7] of TAESNIBlock;
  LBlockIdx, LRemain, I: Integer;

  procedure IncCtr(var C: TAESNIBlock); inline;
  var V: UInt32;
  begin
    V := (UInt32(C[12]) shl 24) or (UInt32(C[13]) shl 16)
       or (UInt32(C[14]) shl 8) or UInt32(C[15]);
    Inc(V);
    C[12] := Byte(V shr 24); C[13] := Byte(V shr 16);
    C[14] := Byte(V shr 8); C[15] := Byte(V);
  end;

begin
  if AInputLen <= 0 then Exit;
  LCtr := AICB;
  LBlockIdx := 0;
  LRemain := AInputLen;

  while LRemain >= 128 do
  begin
    LCtrs[0] := LCtr;
    IncCtr(LCtr); LCtrs[1] := LCtr;
    IncCtr(LCtr); LCtrs[2] := LCtr;
    IncCtr(LCtr); LCtrs[3] := LCtr;
    IncCtr(LCtr); LCtrs[4] := LCtr;
    IncCtr(LCtr); LCtrs[5] := LCtr;
    IncCtr(LCtr); LCtrs[6] := LCtr;
    IncCtr(LCtr); LCtrs[7] := LCtr;
    IncCtr(LCtr);

    asm
      lea rax, LCtrs
      mov rcx, AKey

      movdqu xmm0, [rax]
      movdqu xmm1, [rax+16]
      movdqu xmm2, [rax+32]
      movdqu xmm3, [rax+48]
      movdqu xmm4, [rax+64]
      movdqu xmm5, [rax+80]
      movdqu xmm6, [rax+96]
      movdqu xmm7, [rax+112]

      movdqu xmm8, [rcx]
      pxor xmm0, xmm8
      pxor xmm1, xmm8
      pxor xmm2, xmm8
      pxor xmm3, xmm8
      pxor xmm4, xmm8
      pxor xmm5, xmm8
      pxor xmm6, xmm8
      pxor xmm7, xmm8

      movdqu xmm8, [rcx+16]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+32]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+48]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+64]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+80]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+96]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+112]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+128]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+144]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+160]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+176]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+192]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+208]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+224]
      aesenclast xmm0, xmm8
      aesenclast xmm1, xmm8
      aesenclast xmm2, xmm8
      aesenclast xmm3, xmm8
      aesenclast xmm4, xmm8
      aesenclast xmm5, xmm8
      aesenclast xmm6, xmm8
      aesenclast xmm7, xmm8

      mov rax, AInput
      movsxd rcx, dword ptr LBlockIdx
      add rax, rcx
      mov rdx, AOutput
      add rdx, rcx

      movdqu xmm8, [rax]
      pxor xmm0, xmm8
      movdqu [rdx], xmm0
      movdqu xmm9, [rax+16]
      pxor xmm1, xmm9
      movdqu [rdx+16], xmm1
      movdqu xmm10, [rax+32]
      pxor xmm2, xmm10
      movdqu [rdx+32], xmm2
      movdqu xmm11, [rax+48]
      pxor xmm3, xmm11
      movdqu [rdx+48], xmm3
      movdqu xmm12, [rax+64]
      pxor xmm4, xmm12
      movdqu [rdx+64], xmm4
      movdqu xmm13, [rax+80]
      pxor xmm5, xmm13
      movdqu [rdx+80], xmm5
      movdqu xmm14, [rax+96]
      pxor xmm6, xmm14
      movdqu [rdx+96], xmm6
      movdqu xmm15, [rax+112]
      pxor xmm7, xmm15
      movdqu [rdx+112], xmm7
    end ['rax', 'rcx', 'rdx', 'xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4', 'xmm5', 'xmm6', 'xmm7', 'xmm8', 'xmm9', 'xmm10', 'xmm11', 'xmm12', 'xmm13', 'xmm14', 'xmm15'];

    Inc(LBlockIdx, 128);
    Dec(LRemain, 128);
  end;

  while LRemain >= 64 do
  begin
    LCtrs[0] := LCtr;
    IncCtr(LCtr); LCtrs[1] := LCtr;
    IncCtr(LCtr); LCtrs[2] := LCtr;
    IncCtr(LCtr); LCtrs[3] := LCtr;
    IncCtr(LCtr);

    asm
      lea rax, LCtrs
      mov rcx, AKey

      movdqu xmm0, [rax]
      movdqu xmm1, [rax+16]
      movdqu xmm2, [rax+32]
      movdqu xmm3, [rax+48]

      movdqu xmm4, [rcx]
      pxor xmm0, xmm4
      pxor xmm1, xmm4
      pxor xmm2, xmm4
      pxor xmm3, xmm4

      movdqu xmm4, [rcx+16]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+32]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+48]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+64]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+80]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+96]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+112]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+128]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+144]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+160]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+176]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+192]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+208]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+224]
      aesenclast xmm0, xmm4
      aesenclast xmm1, xmm4
      aesenclast xmm2, xmm4
      aesenclast xmm3, xmm4

      mov rax, AInput
      movsxd rcx, dword ptr LBlockIdx
      add rax, rcx
      mov rdx, AOutput
      add rdx, rcx

      movdqu xmm4, [rax]
      pxor xmm0, xmm4
      movdqu [rdx], xmm0
      movdqu xmm4, [rax+16]
      pxor xmm1, xmm4
      movdqu [rdx+16], xmm1
      movdqu xmm4, [rax+32]
      pxor xmm2, xmm4
      movdqu [rdx+32], xmm2
      movdqu xmm4, [rax+48]
      pxor xmm3, xmm4
      movdqu [rdx+48], xmm3
    end ['rax', 'rcx', 'rdx', 'xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4'];

    Inc(LBlockIdx, 64);
    Dec(LRemain, 64);
  end;

  while LRemain > 0 do
  begin
    AESNIEncryptBlock256(LCtr, LEnc, AKey);
    for I := 0 to Min(15, LRemain - 1) do
      AOutput[LBlockIdx + I] := AInput[LBlockIdx + I] xor LEnc[I];
    IncCtr(LCtr);
    Inc(LBlockIdx, 16);
    Dec(LRemain, 16);
  end;
end;

procedure AESNIEncryptCTR128(const AKey: TAESNIExpandedKey128;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);
var
  LCtr: TAESNIBlock;
  LEnc: TAESNIBlock;
  LCtrs: array[0..7] of TAESNIBlock;
  LBlockIdx, LRemain, I: Integer;

  procedure IncCtr(var C: TAESNIBlock); inline;
  var V: UInt32;
  begin
    V := (UInt32(C[12]) shl 24) or (UInt32(C[13]) shl 16)
       or (UInt32(C[14]) shl 8) or UInt32(C[15]);
    Inc(V);
    C[12] := Byte(V shr 24); C[13] := Byte(V shr 16);
    C[14] := Byte(V shr 8); C[15] := Byte(V);
  end;

begin
  if AInputLen <= 0 then Exit;
  LCtr := AICB;
  LBlockIdx := 0;
  LRemain := AInputLen;

  while LRemain >= 128 do
  begin
    LCtrs[0] := LCtr;
    IncCtr(LCtr); LCtrs[1] := LCtr;
    IncCtr(LCtr); LCtrs[2] := LCtr;
    IncCtr(LCtr); LCtrs[3] := LCtr;
    IncCtr(LCtr); LCtrs[4] := LCtr;
    IncCtr(LCtr); LCtrs[5] := LCtr;
    IncCtr(LCtr); LCtrs[6] := LCtr;
    IncCtr(LCtr); LCtrs[7] := LCtr;
    IncCtr(LCtr);

    asm
      lea rax, LCtrs
      mov rcx, AKey

      movdqu xmm0, [rax]
      movdqu xmm1, [rax+16]
      movdqu xmm2, [rax+32]
      movdqu xmm3, [rax+48]
      movdqu xmm4, [rax+64]
      movdqu xmm5, [rax+80]
      movdqu xmm6, [rax+96]
      movdqu xmm7, [rax+112]

      movdqu xmm8, [rcx]
      pxor xmm0, xmm8
      pxor xmm1, xmm8
      pxor xmm2, xmm8
      pxor xmm3, xmm8
      pxor xmm4, xmm8
      pxor xmm5, xmm8
      pxor xmm6, xmm8
      pxor xmm7, xmm8

      movdqu xmm8, [rcx+16]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+32]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+48]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+64]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+80]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+96]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+112]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+128]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+144]
      aesenc xmm0, xmm8
      aesenc xmm1, xmm8
      aesenc xmm2, xmm8
      aesenc xmm3, xmm8
      aesenc xmm4, xmm8
      aesenc xmm5, xmm8
      aesenc xmm6, xmm8
      aesenc xmm7, xmm8
      movdqu xmm8, [rcx+160]
      aesenclast xmm0, xmm8
      aesenclast xmm1, xmm8
      aesenclast xmm2, xmm8
      aesenclast xmm3, xmm8
      aesenclast xmm4, xmm8
      aesenclast xmm5, xmm8
      aesenclast xmm6, xmm8
      aesenclast xmm7, xmm8

      mov rax, AInput
      movsxd rcx, dword ptr LBlockIdx
      add rax, rcx
      mov rdx, AOutput
      add rdx, rcx

      movdqu xmm8, [rax]
      pxor xmm0, xmm8
      movdqu [rdx], xmm0
      movdqu xmm9, [rax+16]
      pxor xmm1, xmm9
      movdqu [rdx+16], xmm1
      movdqu xmm10, [rax+32]
      pxor xmm2, xmm10
      movdqu [rdx+32], xmm2
      movdqu xmm11, [rax+48]
      pxor xmm3, xmm11
      movdqu [rdx+48], xmm3
      movdqu xmm12, [rax+64]
      pxor xmm4, xmm12
      movdqu [rdx+64], xmm4
      movdqu xmm13, [rax+80]
      pxor xmm5, xmm13
      movdqu [rdx+80], xmm5
      movdqu xmm14, [rax+96]
      pxor xmm6, xmm14
      movdqu [rdx+96], xmm6
      movdqu xmm15, [rax+112]
      pxor xmm7, xmm15
      movdqu [rdx+112], xmm7
    end ['rax', 'rcx', 'rdx', 'xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4', 'xmm5', 'xmm6', 'xmm7', 'xmm8', 'xmm9', 'xmm10', 'xmm11', 'xmm12', 'xmm13', 'xmm14', 'xmm15'];

    Inc(LBlockIdx, 128);
    Dec(LRemain, 128);
  end;

  while LRemain >= 64 do
  begin
    LCtrs[0] := LCtr;
    IncCtr(LCtr); LCtrs[1] := LCtr;
    IncCtr(LCtr); LCtrs[2] := LCtr;
    IncCtr(LCtr); LCtrs[3] := LCtr;
    IncCtr(LCtr);

    asm
      lea rax, LCtrs
      mov rcx, AKey

      movdqu xmm0, [rax]
      movdqu xmm1, [rax+16]
      movdqu xmm2, [rax+32]
      movdqu xmm3, [rax+48]

      movdqu xmm4, [rcx]
      pxor xmm0, xmm4
      pxor xmm1, xmm4
      pxor xmm2, xmm4
      pxor xmm3, xmm4

      movdqu xmm4, [rcx+16]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+32]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+48]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+64]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+80]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+96]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+112]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+128]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+144]
      aesenc xmm0, xmm4
      aesenc xmm1, xmm4
      aesenc xmm2, xmm4
      aesenc xmm3, xmm4
      movdqu xmm4, [rcx+160]
      aesenclast xmm0, xmm4
      aesenclast xmm1, xmm4
      aesenclast xmm2, xmm4
      aesenclast xmm3, xmm4

      mov rax, AInput
      movsxd rcx, dword ptr LBlockIdx
      add rax, rcx
      mov rdx, AOutput
      add rdx, rcx

      movdqu xmm4, [rax]
      pxor xmm0, xmm4
      movdqu [rdx], xmm0
      movdqu xmm4, [rax+16]
      pxor xmm1, xmm4
      movdqu [rdx+16], xmm1
      movdqu xmm4, [rax+32]
      pxor xmm2, xmm4
      movdqu [rdx+32], xmm2
      movdqu xmm4, [rax+48]
      pxor xmm3, xmm4
      movdqu [rdx+48], xmm3
    end ['rax', 'rcx', 'rdx', 'xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4'];

    Inc(LBlockIdx, 64);
    Dec(LRemain, 64);
  end;

  while LRemain > 0 do
  begin
    AESNIEncryptBlock128(LCtr, LEnc, AKey);
    for I := 0 to 15 do
    begin
      if I >= LRemain then Break;
      AOutput[LBlockIdx + I] := AInput[LBlockIdx + I] xor LEnc[I];
    end;
    IncCtr(LCtr);
    Inc(LBlockIdx, 16);
    Dec(LRemain, 16);
  end;
end;

{$ELSE}

function IsAESNIAvailable: Boolean;
begin
  Result := False;
end;

function IsAESNI256Available: Boolean;
begin
  Result := False;
end;

procedure AESNIExpandKey128(const AKey: TAESNIBlock; out AExpandedKey: TAESNIExpandedKey128);
begin
  FillChar(AExpandedKey, SizeOf(AExpandedKey), 0);
end;

procedure AESNIExpandKey256(const AKey: array of Byte; out AExpandedKey: TAESNIExpandedKey256);
begin
  FillChar(AExpandedKey, SizeOf(AExpandedKey), 0);
end;

procedure AESNIEncryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128);
begin
  Move(AInput, AOutput, 16);
end;

procedure AESNIDecryptBlock128(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey128);
begin
  Move(AInput, AOutput, 16);
end;

procedure AESNIEncryptBlock256(const AInput: TAESNIBlock; out AOutput: TAESNIBlock;
  const AExpandedKey: TAESNIExpandedKey256);
begin
  Move(AInput, AOutput, 16);
end;

procedure AESNIEncryptCTR128(const AKey: TAESNIExpandedKey128;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);
begin
  if AInputLen > 0 then
    Move(AInput^, AOutput^, AInputLen);
end;

procedure AESNIEncryptCTR256(const AKey: TAESNIExpandedKey256;
  const AICB: TAESNIBlock; const AInput: PByte; AInputLen: Integer; AOutput: PByte);
begin
  if AInputLen > 0 then
    Move(AInput^, AOutput^, AInputLen);
end;

{$ENDIF}

end.
