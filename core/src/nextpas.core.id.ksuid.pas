unit nextpas.core.id.ksuid;
{$I nextpas.core.settings.inc}

interface

type
  TKsuid = record
  public
    FBytes: array[0..19] of Byte;
  public
    class function New: TKsuid; static;
    class function NewAt(ATimestamp: UInt32): TKsuid; static;
    class function Parse(const AStr: string): TKsuid; static;
    class function TryParse(const AStr: string; out AKsuid: TKsuid): Boolean; static;
    class function Nil_: TKsuid; static;
    function ToString: string;
    function Timestamp: UInt32;
    function TimestampUnix: UInt32;
    function IsNil: Boolean;
    function CompareTo(const AOther: TKsuid): Int32;
    class operator = (const A, B: TKsuid): Boolean;
    class operator < (const A, B: TKsuid): Boolean;
  end;

const
  KSUID_EPOCH = UInt32(1400000000);
  KSUID_STRING_LENGTH = 27;

function KsuidNew: string;

implementation

uses
  nextpas.core.id.rng,
  nextpas.core.platform.time;

const
  BASE62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

procedure Base62Encode(const ABytes: array of Byte; ALen: Integer; var ADst: string);
var
  LSrc: array[0..19] of Byte;
  LI, LJ: Integer;
  LRem: UInt32;
begin
  Move(ABytes[0], LSrc[0], ALen);
  SetLength(ADst, KSUID_STRING_LENGTH);
  for LI := KSUID_STRING_LENGTH downto 1 do
  begin
    LRem := 0;
    for LJ := 0 to ALen - 1 do
    begin
      LRem := (LRem shl 8) or LSrc[LJ];
      LSrc[LJ] := Byte(LRem div 62);
      LRem := LRem mod 62;
    end;
    ADst[LI] := BASE62[LRem + 1];
  end;
end;

function Base62Decode(const AStr: string; var ADst: array of Byte; ALen: Integer): Boolean;
var
  LI, LJ: Integer;
  LCarry: UInt32;
  LVal: Int32;
begin
  if Length(AStr) <> KSUID_STRING_LENGTH then Exit(False);
  FillChar(ADst[0], ALen, 0);
  for LI := 1 to KSUID_STRING_LENGTH do
  begin
    LVal := Pos(AStr[LI], BASE62) - 1;
    if LVal < 0 then Exit(False);
    LCarry := UInt32(LVal);
    for LJ := ALen - 1 downto 0 do
    begin
      LCarry := LCarry + UInt32(ADst[LJ]) * 62;
      ADst[LJ] := Byte(LCarry and $FF);
      LCarry := LCarry shr 8;
    end;
  end;
  Result := True;
end;

class function TKsuid.New: TKsuid;
var
  LTs: UInt32;
begin
  LTs := UInt32(platform_realtime_ns div 1000000000) - KSUID_EPOCH;
  Result.FBytes[0] := Byte(LTs shr 24);
  Result.FBytes[1] := Byte(LTs shr 16);
  Result.FBytes[2] := Byte(LTs shr 8);
  Result.FBytes[3] := Byte(LTs);
  IdRngFillBytes(@Result.FBytes[4], 16);
end;

class function TKsuid.NewAt(ATimestamp: UInt32): TKsuid;
begin
  Result.FBytes[0] := Byte(ATimestamp shr 24);
  Result.FBytes[1] := Byte(ATimestamp shr 16);
  Result.FBytes[2] := Byte(ATimestamp shr 8);
  Result.FBytes[3] := Byte(ATimestamp);
  IdRngFillBytes(@Result.FBytes[4], 16);
end;

class function TKsuid.TryParse(const AStr: string; out AKsuid: TKsuid): Boolean;
begin
  Result := Base62Decode(AStr, AKsuid.FBytes, 20);
end;

class function TKsuid.Parse(const AStr: string): TKsuid;
begin
  if not TryParse(AStr, Result) then
    FillChar(Result.FBytes, 20, 0);
end;

class function TKsuid.Nil_: TKsuid;
begin
  FillChar(Result.FBytes, 20, 0);
end;

function TKsuid.ToString: string;
begin
  Base62Encode(FBytes, 20, Result);
end;

function TKsuid.Timestamp: UInt32;
begin
  Result := (UInt32(FBytes[0]) shl 24) or (UInt32(FBytes[1]) shl 16) or
            (UInt32(FBytes[2]) shl 8) or UInt32(FBytes[3]);
end;

function TKsuid.TimestampUnix: UInt32;
begin
  Result := Timestamp + KSUID_EPOCH;
end;

function TKsuid.IsNil: Boolean;
var LI: Integer;
begin
  for LI := 0 to 19 do
    if FBytes[LI] <> 0 then Exit(False);
  Result := True;
end;

function TKsuid.CompareTo(const AOther: TKsuid): Int32;
var LI: Integer;
begin
  for LI := 0 to 19 do
  begin
    if FBytes[LI] < AOther.FBytes[LI] then Exit(-1);
    if FBytes[LI] > AOther.FBytes[LI] then Exit(1);
  end;
  Result := 0;
end;

class operator TKsuid.= (const A, B: TKsuid): Boolean;
var LI: Integer;
begin
  for LI := 0 to 19 do
    if A.FBytes[LI] <> B.FBytes[LI] then Exit(False);
  Result := True;
end;

class operator TKsuid.< (const A, B: TKsuid): Boolean;
begin
  Result := A.CompareTo(B) < 0;
end;

function KsuidNew: string;
begin
  Result := TKsuid.New.ToString;
end;

end.
