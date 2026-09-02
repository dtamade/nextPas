{**
 * nextpas.core.checksum.adler32 - Adler-32 (RFC 1950, zlib)
 *
 * MOD 65521, NMAX 5552 blocking so mod deferred per chunk.
 * Single source for all Adler-32: checksum facade re-exports,
 * git/compress callers must not hand-roll the 65521 loop.
 * RFC 1950 test vector: "Wikipedia" -> $11E60398, empty -> 1.
 * Slice-friendly: Update takes Pointer+Len zero-copy.
 *}

unit nextpas.core.checksum.adler32;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  ADLER32_INIT = LongWord(1);
  ADLER32_MOD  = LongWord(65521);
  ADLER32_NMAX = SizeUInt(5552);

function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
function Adler32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
function Adler32OfBytes(const AData: TBytes): LongWord; inline;

implementation

function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
var
  P: PByte;
  A, B: LongWord;
  K: SizeUInt;
begin
  A := AAdler and $FFFF;
  B := (AAdler shr 16) and $FFFF;
  if ALen = 0 then
    Exit((B shl 16) or A);
  if AData = nil then
    Exit((B shl 16) or A);
  P := PByte(AData);
  while ALen > 0 do
  begin
    if ALen < ADLER32_NMAX then
      K := ALen
    else
      K := ADLER32_NMAX;
    Dec(ALen, K);
    while K >= 16 do
    begin
      A := A + P[0]; B := B + A;
      A := A + P[1]; B := B + A;
      A := A + P[2]; B := B + A;
      A := A + P[3]; B := B + A;
      A := A + P[4]; B := B + A;
      A := A + P[5]; B := B + A;
      A := A + P[6]; B := B + A;
      A := A + P[7]; B := B + A;
      A := A + P[8]; B := B + A;
      A := A + P[9]; B := B + A;
      A := A + P[10]; B := B + A;
      A := A + P[11]; B := B + A;
      A := A + P[12]; B := B + A;
      A := A + P[13]; B := B + A;
      A := A + P[14]; B := B + A;
      A := A + P[15]; B := B + A;
      Inc(P, 16);
      Dec(K, 16);
    end;
    while K > 0 do
    begin
      A := A + P^;
      B := B + A;
      Inc(P);
      Dec(K);
    end;
    A := A mod ADLER32_MOD;
    B := B mod ADLER32_MOD;
  end;
  Result := (B shl 16) or A;
end;

function Adler32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  if ALen = 0 then
    Exit(ADLER32_INIT);
  Result := Adler32Update(ADLER32_INIT, @ABuf, ALen);
end;

function Adler32OfBytes(const AData: TBytes): LongWord;
begin
  if Length(AData) = 0 then
    Exit(ADLER32_INIT);
  Result := Adler32Update(ADLER32_INIT, PByte(AData), SizeUInt(Length(AData)));
end;

end.
