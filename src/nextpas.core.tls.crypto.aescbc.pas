unit nextpas.core.tls.crypto.aescbc;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

function AESCBCEncryptNoPadding(const AKey, AIV, APlaintext: TBytes): TBytes;
function AESCBCDecryptNoPadding(const AKey, AIV, ACiphertext: TBytes): TBytes;

implementation

uses
  nextpas.core.tls.crypto.aesgcm;

const
  InvSBox: array[0..255] of Byte = (
    $52,$09,$6a,$d5,$30,$36,$a5,$38,$bf,$40,$a3,$9e,$81,$f3,$d7,$fb,
    $7c,$e3,$39,$82,$9b,$2f,$ff,$87,$34,$8e,$43,$44,$c4,$de,$e9,$cb,
    $54,$7b,$94,$32,$a6,$c2,$23,$3d,$ee,$4c,$95,$0b,$42,$fa,$c3,$4e,
    $08,$2e,$a1,$66,$28,$d9,$24,$b2,$76,$5b,$a2,$49,$6d,$8b,$d1,$25,
    $72,$f8,$f6,$64,$86,$68,$98,$16,$d4,$a4,$5c,$cc,$5d,$65,$b6,$92,
    $6c,$70,$48,$50,$fd,$ed,$b9,$da,$5e,$15,$46,$57,$a7,$8d,$9d,$84,
    $90,$d8,$ab,$00,$8c,$bc,$d3,$0a,$f7,$e4,$58,$05,$b8,$b3,$45,$06,
    $d0,$2c,$1e,$8f,$ca,$3f,$0f,$02,$c1,$af,$bd,$03,$01,$13,$8a,$6b,
    $3a,$91,$11,$41,$4f,$67,$dc,$ea,$97,$f2,$cf,$ce,$f0,$b4,$e6,$73,
    $96,$ac,$74,$22,$e7,$ad,$35,$85,$e2,$f9,$37,$e8,$1c,$75,$df,$6e,
    $47,$f1,$1a,$71,$1d,$29,$c5,$89,$6f,$b7,$62,$0e,$aa,$18,$be,$1b,
    $fc,$56,$3e,$4b,$c6,$d2,$79,$20,$9a,$db,$c0,$fe,$78,$cd,$5a,$f4,
    $1f,$dd,$a8,$33,$88,$07,$c7,$31,$b1,$12,$10,$59,$27,$80,$ec,$5f,
    $60,$51,$7f,$a9,$19,$b5,$4a,$0d,$2d,$e5,$7a,$9f,$93,$c9,$9c,$ef,
    $a0,$e0,$3b,$4d,$ae,$2a,$f5,$b0,$c8,$eb,$bb,$3c,$83,$53,$99,$61,
    $17,$2b,$04,$7e,$ba,$77,$d6,$26,$e1,$69,$14,$63,$55,$21,$0c,$7d
  );

procedure AESDecryptBlock(const AInput: TAESBlock; out AOutput: TAESBlock;
  const AExpandedKey: TAESExpandedKey; ANr: Integer);
var
  S: array[0..15] of Byte;
  T: array[0..15] of Byte;
  I, R: Integer;
  A, B, C, D: Byte;

  function Mul(X, Y: Byte): Byte;
  var
    P, HiBit: Byte;
    J: Integer;
  begin
    P := 0;
    for J := 0 to 7 do
    begin
      if (Y and 1) <> 0 then
        P := P xor X;
      HiBit := X and $80;
      X := X shl 1;
      if HiBit <> 0 then
        X := X xor $1B;
      Y := Y shr 1;
    end;
    Result := P;
  end;

begin
  for I := 0 to 15 do
    S[I] := AInput[I] xor Byte(AExpandedKey[ANr * 4 + I div 4] shr (24 - (I mod 4) * 8));

  for R := ANr - 1 downto 1 do
  begin
    T[0] := S[0]; T[1] := S[13]; T[2] := S[10]; T[3] := S[7];
    T[4] := S[4]; T[5] := S[1]; T[6] := S[14]; T[7] := S[11];
    T[8] := S[8]; T[9] := S[5]; T[10] := S[2]; T[11] := S[15];
    T[12] := S[12]; T[13] := S[9]; T[14] := S[6]; T[15] := S[3];

    for I := 0 to 15 do
      T[I] := InvSBox[T[I]];

    for I := 0 to 15 do
      T[I] := T[I] xor Byte(AExpandedKey[R * 4 + I div 4] shr (24 - (I mod 4) * 8));

    for I := 0 to 3 do
    begin
      A := T[I*4]; B := T[I*4+1]; C := T[I*4+2]; D := T[I*4+3];
      S[I*4]   := Mul($0e, A) xor Mul($0b, B) xor Mul($0d, C) xor Mul($09, D);
      S[I*4+1] := Mul($09, A) xor Mul($0e, B) xor Mul($0b, C) xor Mul($0d, D);
      S[I*4+2] := Mul($0d, A) xor Mul($09, B) xor Mul($0e, C) xor Mul($0b, D);
      S[I*4+3] := Mul($0b, A) xor Mul($0d, B) xor Mul($09, C) xor Mul($0e, D);
    end;
  end;

  T[0] := S[0]; T[1] := S[13]; T[2] := S[10]; T[3] := S[7];
  T[4] := S[4]; T[5] := S[1]; T[6] := S[14]; T[7] := S[11];
  T[8] := S[8]; T[9] := S[5]; T[10] := S[2]; T[11] := S[15];
  T[12] := S[12]; T[13] := S[9]; T[14] := S[6]; T[15] := S[3];

  for I := 0 to 15 do
    T[I] := InvSBox[T[I]];

  for I := 0 to 15 do
    AOutput[I] := T[I] xor Byte(AExpandedKey[I div 4] shr (24 - (I mod 4) * 8));
end;

function AESCBCEncryptNoPadding(const AKey, AIV, APlaintext: TBytes): TBytes;
var
  ExpandedKey: TAESExpandedKey;
  Nr: Integer;
  Blocks, I, J: Integer;
  InBlock, OutBlock, Prev: TAESBlock;
begin
  if (Length(APlaintext) mod 16) <> 0 then
    raise Exception.Create('AES-CBC plaintext must be a multiple of 16 bytes');

  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then
    raise Exception.Create('Invalid AES key length');

  Blocks := Length(APlaintext) div 16;
  SetLength(Result, Length(APlaintext));

  Move(AIV[0], Prev[0], 16);

  for I := 0 to Blocks - 1 do
  begin
    for J := 0 to 15 do
      InBlock[J] := APlaintext[I * 16 + J] xor Prev[J];
    AESEncryptBlock(InBlock, OutBlock, ExpandedKey, Nr);
    Move(OutBlock[0], Result[I * 16], 16);
    Prev := OutBlock;
  end;
end;

function AESCBCDecryptNoPadding(const AKey, AIV, ACiphertext: TBytes): TBytes;
var
  ExpandedKey: TAESExpandedKey;
  Nr: Integer;
  Blocks, I, J: Integer;
  InBlock, OutBlock, Prev, NextPrev: TAESBlock;
begin
  if (Length(ACiphertext) mod 16) <> 0 then
    raise Exception.Create('AES-CBC ciphertext must be a multiple of 16 bytes');

  AESKeyExpand(AKey, ExpandedKey, Nr);
  if Nr = 0 then
    raise Exception.Create('Invalid AES key length');

  Blocks := Length(ACiphertext) div 16;
  SetLength(Result, Length(ACiphertext));

  Move(AIV[0], Prev[0], 16);

  for I := 0 to Blocks - 1 do
  begin
    Move(ACiphertext[I * 16], InBlock[0], 16);
    NextPrev := InBlock;
    AESDecryptBlock(InBlock, OutBlock, ExpandedKey, Nr);
    for J := 0 to 15 do
      Result[I * 16 + J] := OutBlock[J] xor Prev[J];
    Prev := NextPrev;
  end;
end;

end.
