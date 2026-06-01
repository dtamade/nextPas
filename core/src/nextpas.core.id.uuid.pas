unit nextpas.core.id.uuid;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base;

type
  TUuid = record
  public
    FBytes: array[0..15] of Byte;
  public
    class function NewV4: TUuid; static;
    class function NewV7: TUuid; static;
    class function NewV7At(const ATimestampMs: UInt64): TUuid; static;
    class function NewV5(const ANamespace: TUuid; const AName: string): TUuid; static;
    class function Parse(const AStr: string): TUuid; static;
    class function TryParse(const AStr: string; out AUuid: TUuid): Boolean; static;
    class function Nil_: TUuid; static;
    class function Max: TUuid; static;
    class function FromBytes(const ABytes: array of Byte): TUuid; static;
    function ToString: string;
    function ToStringNoDash: string;
    function ToURN: string;
    function Version: Byte;
    function Variant: Byte;
    function IsNil: Boolean;
    function Equals(const AOther: TUuid): Boolean;
    function CompareTo(const AOther: TUuid): Int32;
    function TimestampMs: UInt64;
    function Hash: UInt32;
    class operator = (const A, B: TUuid): Boolean;
    class operator < (const A, B: TUuid): Boolean;
  end;

function UuidV4: TUuidString;
function UuidV7: TUuidString;
function UuidParse(const AStr: string): TUuid;
function UuidIsValid(const AStr: string): Boolean;

implementation

uses
  nextpas.core.id.rng,
  nextpas.core.platform.time,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1;

const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';

function HexVal(ACh: Char): Int32; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

procedure FormatUuid(const ABytes: array of Byte; var ADst: string);
var
  LI, LJ: Integer;
begin
  SetLength(ADst, UUID_LENGTH);
  LJ := 1;
  for LI := 0 to 15 do
  begin
    ADst[LJ]     := HEX_CHARS[ABytes[LI] shr 4];
    ADst[LJ + 1] := HEX_CHARS[ABytes[LI] and $0F];
    Inc(LJ, 2);
    if (LI = 3) or (LI = 5) or (LI = 7) or (LI = 9) then
    begin
      ADst[LJ] := '-';
      Inc(LJ);
    end;
  end;
end;

class function TUuid.NewV4: TUuid;
begin
  IdRngFillBytes(@Result.FBytes[0], 16);
  Result.FBytes[6] := (Result.FBytes[6] and $0F) or $40;
  Result.FBytes[8] := (Result.FBytes[8] and $3F) or $80;
end;

class function TUuid.NewV7: TUuid;
var
  LMs: UInt64;
begin
  LMs := platform_realtime_ns div 1000000;
  Result.FBytes[0] := Byte(LMs shr 40);
  Result.FBytes[1] := Byte(LMs shr 32);
  Result.FBytes[2] := Byte(LMs shr 24);
  Result.FBytes[3] := Byte(LMs shr 16);
  Result.FBytes[4] := Byte(LMs shr 8);
  Result.FBytes[5] := Byte(LMs);
  IdRngFillBytes(@Result.FBytes[6], 10);
  Result.FBytes[6] := (Result.FBytes[6] and $0F) or $70;
  Result.FBytes[8] := (Result.FBytes[8] and $3F) or $80;
end;

class function TUuid.NewV7At(const ATimestampMs: UInt64): TUuid;
begin
  Result.FBytes[0] := Byte(ATimestampMs shr 40);
  Result.FBytes[1] := Byte(ATimestampMs shr 32);
  Result.FBytes[2] := Byte(ATimestampMs shr 24);
  Result.FBytes[3] := Byte(ATimestampMs shr 16);
  Result.FBytes[4] := Byte(ATimestampMs shr 8);
  Result.FBytes[5] := Byte(ATimestampMs);
  IdRngFillBytes(@Result.FBytes[6], 10);
  Result.FBytes[6] := (Result.FBytes[6] and $0F) or $70;
  Result.FBytes[8] := (Result.FBytes[8] and $3F) or $80;
end;

class function TUuid.NewV5(const ANamespace: TUuid; const AName: string): TUuid;
var
  LHasher: IHasher;
  LDigest: array[0..19] of Byte;
begin
  LHasher := NewSHA1;
  LHasher.Write(ANamespace.FBytes[0], 16);
  if Length(AName) > 0 then
    LHasher.Write(AName[1], Length(AName));
  LHasher.Sum(LDigest[0], 20);
  Move(LDigest[0], Result.FBytes[0], 16);
  Result.FBytes[6] := (Result.FBytes[6] and $0F) or $50; { version 5 }
  Result.FBytes[8] := (Result.FBytes[8] and $3F) or $80; { variant 10xx }
end;

class function TUuid.FromBytes(const ABytes: array of Byte): TUuid;
var
  LI, LLen: Integer;
begin
  FillChar(Result.FBytes, 16, 0);
  LLen := Length(ABytes);
  if LLen > 16 then LLen := 16;
  for LI := 0 to LLen - 1 do
    Result.FBytes[LI] := ABytes[LI];
end;

class function TUuid.TryParse(const AStr: string; out AUuid: TUuid): Boolean;
var
  LI, LJ, LHi, LLo: Int32;
begin
  Result := False;
  if Length(AStr) <> UUID_LENGTH then Exit;
  if (AStr[9] <> '-') or (AStr[14] <> '-') or
     (AStr[19] <> '-') or (AStr[24] <> '-') then Exit;
  FillChar(AUuid.FBytes, 16, 0);
  LJ := 0;
  LI := 1;
  while LI <= UUID_LENGTH do
  begin
    if AStr[LI] = '-' then begin Inc(LI); Continue; end;
    if LI + 1 > UUID_LENGTH then Exit;
    LHi := HexVal(AStr[LI]);
    LLo := HexVal(AStr[LI + 1]);
    if (LHi < 0) or (LLo < 0) then Exit;
    if LJ > 15 then Exit;
    AUuid.FBytes[LJ] := Byte((LHi shl 4) or LLo);
    Inc(LJ);
    Inc(LI, 2);
  end;
  Result := (LJ = 16);
end;

class function TUuid.Parse(const AStr: string): TUuid;
begin
  if not TryParse(AStr, Result) then
    FillChar(Result.FBytes, 16, 0);
end;

class function TUuid.Nil_: TUuid;
begin
  FillChar(Result.FBytes, 16, 0);
end;

class function TUuid.Max: TUuid;
begin
  FillChar(Result.FBytes, 16, $FF);
end;

function TUuid.ToString: string;
begin
  FormatUuid(FBytes, Result);
end;

function TUuid.ToStringNoDash: string;
var LI: Integer;
begin
  SetLength(Result, 32);
  for LI := 0 to 15 do
  begin
    Result[LI * 2 + 1] := HEX_CHARS[FBytes[LI] shr 4];
    Result[LI * 2 + 2] := HEX_CHARS[FBytes[LI] and $0F];
  end;
end;

function TUuid.ToURN: string;
begin
  Result := 'urn:uuid:' + ToString;
end;

function TUuid.Version: Byte;
begin
  Result := (FBytes[6] shr 4) and $0F;
end;

function TUuid.Variant: Byte;
begin
  Result := (FBytes[8] shr 6) and $03;
end;

function TUuid.IsNil: Boolean;
var LI: Integer;
begin
  for LI := 0 to 15 do
    if FBytes[LI] <> 0 then Exit(False);
  Result := True;
end;

function TUuid.Equals(const AOther: TUuid): Boolean;
var LI: Integer;
begin
  for LI := 0 to 15 do
    if FBytes[LI] <> AOther.FBytes[LI] then Exit(False);
  Result := True;
end;

function TUuid.CompareTo(const AOther: TUuid): Int32;
var LI: Integer;
begin
  for LI := 0 to 15 do
  begin
    if FBytes[LI] < AOther.FBytes[LI] then Exit(-1);
    if FBytes[LI] > AOther.FBytes[LI] then Exit(1);
  end;
  Result := 0;
end;

function TUuid.TimestampMs: UInt64;
begin
  if Version <> 7 then Exit(0);
  Result := (UInt64(FBytes[0]) shl 40) or (UInt64(FBytes[1]) shl 32) or
            (UInt64(FBytes[2]) shl 24) or (UInt64(FBytes[3]) shl 16) or
            (UInt64(FBytes[4]) shl 8) or UInt64(FBytes[5]);
end;

function TUuid.Hash: UInt32;
var LA, LB, LC, LD: UInt32;
begin
  Move(FBytes[0], LA, 4);
  Move(FBytes[4], LB, 4);
  Move(FBytes[8], LC, 4);
  Move(FBytes[12], LD, 4);
  Result := LA xor LB xor LC xor LD;
end;

class operator TUuid.= (const A, B: TUuid): Boolean;
var LI: Integer;
begin
  for LI := 0 to 15 do
    if A.FBytes[LI] <> B.FBytes[LI] then Exit(False);
  Result := True;
end;

class operator TUuid.< (const A, B: TUuid): Boolean;
var LI: Integer;
begin
  for LI := 0 to 15 do
  begin
    if A.FBytes[LI] < B.FBytes[LI] then Exit(True);
    if A.FBytes[LI] > B.FBytes[LI] then Exit(False);
  end;
  Result := False;
end;

function UuidV4: TUuidString;
begin
  Result := TUuid.NewV4.ToString;
end;

function UuidV7: TUuidString;
begin
  Result := TUuid.NewV7.ToString;
end;

function UuidParse(const AStr: string): TUuid;
begin
  Result := TUuid.Parse(AStr);
end;

function UuidIsValid(const AStr: string): Boolean;
var LDummy: TUuid;
begin
  Result := TUuid.TryParse(AStr, LDummy);
end;

end.
