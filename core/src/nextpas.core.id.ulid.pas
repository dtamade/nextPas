unit nextpas.core.id.ulid;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base;

function Ulid: TUlidString;
function UlidFromTimestamp(const ATimestampMs: UInt64): TUlidString;

implementation

uses
  nextpas.core.platform.time;

const
  CROCKFORD_ALPHABET: array[0..31] of Char = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function EncodeUlid(const ATimestampMs: UInt64): TUlidString;
var
  LRandom: array[0..9] of Byte;
  LI: Integer;
  LTs: UInt64;
begin
  SetLength(Result, ULID_LENGTH);

  LTs := ATimestampMs;
  for LI := 10 downto 1 do
  begin
    Result[LI] := CROCKFORD_ALPHABET[LTs and $1F];
    LTs := LTs shr 5;
  end;

  for LI := 0 to 9 do
    LRandom[LI] := Byte(Random(256));

  Result[11] := CROCKFORD_ALPHABET[(LRandom[0] and $F8) shr 3];
  Result[12] := CROCKFORD_ALPHABET[((LRandom[0] and $07) shl 2) or ((LRandom[1] and $C0) shr 6)];
  Result[13] := CROCKFORD_ALPHABET[(LRandom[1] and $3E) shr 1];
  Result[14] := CROCKFORD_ALPHABET[((LRandom[1] and $01) shl 4) or ((LRandom[2] and $F0) shr 4)];
  Result[15] := CROCKFORD_ALPHABET[((LRandom[2] and $0F) shl 1) or ((LRandom[3] and $80) shr 7)];
  Result[16] := CROCKFORD_ALPHABET[(LRandom[3] and $7C) shr 2];
  Result[17] := CROCKFORD_ALPHABET[((LRandom[3] and $03) shl 3) or ((LRandom[4] and $E0) shr 5)];
  Result[18] := CROCKFORD_ALPHABET[LRandom[4] and $1F];
  Result[19] := CROCKFORD_ALPHABET[(LRandom[5] and $F8) shr 3];
  Result[20] := CROCKFORD_ALPHABET[((LRandom[5] and $07) shl 2) or ((LRandom[6] and $C0) shr 6)];
  Result[21] := CROCKFORD_ALPHABET[(LRandom[6] and $3E) shr 1];
  Result[22] := CROCKFORD_ALPHABET[((LRandom[6] and $01) shl 4) or ((LRandom[7] and $F0) shr 4)];
  Result[23] := CROCKFORD_ALPHABET[((LRandom[7] and $0F) shl 1) or ((LRandom[8] and $80) shr 7)];
  Result[24] := CROCKFORD_ALPHABET[(LRandom[8] and $7C) shr 2];
  Result[25] := CROCKFORD_ALPHABET[((LRandom[8] and $03) shl 3) or ((LRandom[9] and $E0) shr 5)];
  Result[26] := CROCKFORD_ALPHABET[LRandom[9] and $1F];
end;

function Ulid: TUlidString;
var
  LMs: UInt64;
begin
  LMs := platform_realtime_ns div 1000000;
  Result := EncodeUlid(LMs);
end;

function UlidFromTimestamp(const ATimestampMs: UInt64): TUlidString;
begin
  Result := EncodeUlid(ATimestampMs);
end;

end.
