unit nextpas.core.crypto.aes.ct64;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TAESCt64Key = record
    RK: array[0..59] of UInt32;
    Nr: Integer;
  end;

procedure AESCt64KeyExpand(const AKey: TBytes; out AExpKey: TAESCt64Key);
procedure AESCt64EncryptBlock(const AIn: PByte; AOut: PByte; const AExpKey: TAESCt64Key);
function CTSBox(AX: Byte): Byte;

implementation

// Constant-time S-box: scans all 256 entries with masking.
// No cache-timing side channel — every lookup touches all entries.

const
  SBoxTable: array[0..255] of Byte = (
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

function CTSBox(AX: Byte): Byte;
var
  I: Integer;
  LResult: Byte;
  LMask: Byte;
begin
  LResult := 0;
  for I := 0 to 255 do
  begin
    LMask := Byte(0) - Byte(Ord(Byte(I) = AX));
    LResult := LResult or (SBoxTable[I] and LMask);
  end;
  Result := LResult;
end;

function CTSubWord(W: UInt32): UInt32; inline;
begin
  Result := (UInt32(CTSBox((W shr 24) and $FF)) shl 24) or
            (UInt32(CTSBox((W shr 16) and $FF)) shl 16) or
            (UInt32(CTSBox((W shr 8) and $FF)) shl 8) or
            UInt32(CTSBox(W and $FF));
end;

function RotWord(W: UInt32): UInt32; inline;
begin
  Result := (W shl 8) or (W shr 24);
end;

const
  Rcon: array[0..9] of UInt32 = (
    $01000000, $02000000, $04000000, $08000000, $10000000,
    $20000000, $40000000, $80000000, $1b000000, $36000000
  );

procedure AESCt64KeyExpand(const AKey: TBytes; out AExpKey: TAESCt64Key);
var
  Nk, I: Integer;
  Temp: UInt32;
begin
  case Length(AKey) of
    16: begin Nk := 4; AExpKey.Nr := 10; end;
    24: begin Nk := 6; AExpKey.Nr := 12; end;
    32: begin Nk := 8; AExpKey.Nr := 14; end;
  else
    AExpKey.Nr := 0; Exit;
  end;

  for I := 0 to Nk - 1 do
    AExpKey.RK[I] := (UInt32(AKey[I*4]) shl 24) or (UInt32(AKey[I*4+1]) shl 16) or
                     (UInt32(AKey[I*4+2]) shl 8) or UInt32(AKey[I*4+3]);

  for I := Nk to (AExpKey.Nr + 1) * 4 - 1 do
  begin
    Temp := AExpKey.RK[I - 1];
    if (I mod Nk) = 0 then
      Temp := CTSubWord(RotWord(Temp)) xor Rcon[(I div Nk) - 1]
    else if (Nk > 6) and ((I mod Nk) = 4) then
      Temp := CTSubWord(Temp);
    AExpKey.RK[I] := AExpKey.RK[I - Nk] xor Temp;
  end;
end;

function XTime(X: Byte): Byte; inline;
begin
  Result := (X shl 1) xor (((X shr 7) and 1) * $1B);
end;

procedure AESCt64EncryptBlock(const AIn: PByte; AOut: PByte; const AExpKey: TAESCt64Key);
var
  S, T: array[0..15] of Byte;
  I, R: Integer;
  A, B, C, D: Byte;
begin
  if AExpKey.Nr = 0 then
  begin
    FillChar(AOut^, 16, 0);
    Exit;
  end;
  for I := 0 to 15 do
    S[I] := AIn[I] xor Byte(AExpKey.RK[I div 4] shr (24 - (I mod 4) * 8));

  for R := 1 to AExpKey.Nr - 1 do
  begin
    for I := 0 to 15 do
      S[I] := CTSBox(S[I]);

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
      S[I] := S[I] xor Byte(AExpKey.RK[R * 4 + I div 4] shr (24 - (I mod 4) * 8));
  end;

  for I := 0 to 15 do
    S[I] := CTSBox(S[I]);

  T[0] := S[0]; T[1] := S[5]; T[2] := S[10]; T[3] := S[15];
  T[4] := S[4]; T[5] := S[9]; T[6] := S[14]; T[7] := S[3];
  T[8] := S[8]; T[9] := S[13]; T[10] := S[2]; T[11] := S[7];
  T[12] := S[12]; T[13] := S[1]; T[14] := S[6]; T[15] := S[11];

  for I := 0 to 15 do
    AOut[I] := T[I] xor Byte(AExpKey.RK[AExpKey.Nr * 4 + I div 4] shr (24 - (I mod 4) * 8));
end;

end.
