unit nextpas.core.id.ulid;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base;

function Ulid: TUlidString;
function UlidFromTimestamp(const ATimestampMs: UInt64): TUlidString;
function UlidIsValid(const AStr: string): Boolean;
function UlidTimestampMs(const AStr: string): UInt64;
function UlidTryTimestampMs(const AStr: string; out ATimestampMs: UInt64): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.id.rng,
  nextpas.core.platform.time;

const
  CROCKFORD_ALPHABET: array[0..31] of Char = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function EncodeUlid(const ATimestampMs: UInt64): TUlidString;
var
  LRandom: array[0..9] of Byte;
  LI: Integer;
  LTs: UInt64;
begin
  if ATimestampMs > UInt64($FFFFFFFFFFFF) then
    raise EOutOfRange.Create('UlidFromTimestamp: timestamp must fit 48 bits');
  SetLength(Result, ULID_LENGTH);

  LTs := ATimestampMs;
  for LI := 10 downto 1 do
  begin
    Result[LI] := CROCKFORD_ALPHABET[LTs and $1F];
    LTs := LTs shr 5;
  end;

  IdRngFillBytes(@LRandom[0], 10);

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

function CrockfordVal(ACh: Char): Int32;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'A'..'H': Result := Ord(ACh) - Ord('A') + 10;
    'a'..'h': Result := Ord(ACh) - Ord('a') + 10;
    'J', 'K': Result := Ord(ACh) - Ord('J') + 18;
    'j', 'k': Result := Ord(ACh) - Ord('j') + 18;
    'M', 'N': Result := Ord(ACh) - Ord('M') + 20;
    'm', 'n': Result := Ord(ACh) - Ord('m') + 20;
    'P'..'T': Result := Ord(ACh) - Ord('P') + 22;
    'p'..'t': Result := Ord(ACh) - Ord('p') + 22;
    'V'..'Z': Result := Ord(ACh) - Ord('V') + 27;
    'v'..'z': Result := Ord(ACh) - Ord('v') + 27;
  else
    Result := -1;
  end;
end;

function UlidIsValid(const AStr: string): Boolean;
var LI: Integer;
begin
  if Length(AStr) <> ULID_LENGTH then Exit(False);
  if CrockfordVal(AStr[1]) > 7 then Exit(False);
  for LI := 1 to ULID_LENGTH do
    if CrockfordVal(AStr[LI]) < 0 then Exit(False);
  Result := True;
end;

function UlidTimestampMs(const AStr: string): UInt64;
var
  LValue: UInt64;
begin
  if UlidTryTimestampMs(AStr, LValue) then
    Result := LValue
  else
    Result := 0;
end;

function UlidTryTimestampMs(const AStr: string; out ATimestampMs: UInt64): Boolean;
var
  LI: Integer;
  LVal: Int32;
  LValue: UInt64;
begin
  if Length(AStr) <> ULID_LENGTH then Exit(False);
  if not UlidIsValid(AStr) then Exit(False);
  LValue := 0;
  for LI := 1 to 10 do
  begin
    LVal := CrockfordVal(AStr[LI]);
    if LVal < 0 then Exit(False);
    if (LI = 1) and (LVal > 7) then Exit(False);
    LValue := (LValue shl 5) or UInt64(LVal);
  end;
  ATimestampMs := LValue;
  Result := True;
end;

end.
