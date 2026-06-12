unit nextpas.core.id.xid;
{$I nextpas.core.settings.inc}

interface

type
  TXid = record
  public
    FBytes: array[0..11] of Byte;
  public
    class function New: TXid; static;
    class function Parse(const AStr: string): TXid; static;
    class function TryParse(const AStr: string; out AXid: TXid): Boolean; static;
    class function Nil_: TXid; static;
    function ToString: string;
    function Timestamp: UInt32;
    function IsNil: Boolean;
    function CompareTo(const AOther: TXid): Int32;
    class operator = (const A, B: TXid): Boolean;
    class operator < (const A, B: TXid): Boolean;
  end;

const
  XID_STRING_LENGTH = 20;

function XidNew: string;
function XidIsValid(const AStr: string): Boolean;
function XidTimestamp(const AStr: string): UInt32;
function XidTryTimestamp(const AStr: string; out ATimestamp: UInt32): Boolean;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.id.rng,
  nextpas.core.platform.time;

const
  XID_ENCODING = '0123456789abcdefghijklmnopqrstuv';
  XID_COUNTER_MASK = UInt32($FFFFFF);

var
  GMachineId: array[0..2] of Byte;
  GCounter: Int32 = 0;
  GNewLock: Int32 = 0;
  GLastTs: UInt32 = 0;
  GLastCnt: UInt32 = 0;
  GHasLastXid: Boolean = False;
  GXidInitState: Int32 = 0;
  GXidDecodeTable: array[0..127] of ShortInt;

procedure InitXidDecodeTable;
var LI: Integer;
begin
  for LI := 0 to 127 do
    GXidDecodeTable[LI] := -1;
  for LI := 0 to 31 do
    GXidDecodeTable[Ord(XID_ENCODING[LI + 1])] := ShortInt(LI);
end;

function GetPid16: UInt16;
begin
  {$IFDEF UNIX}
  Result := UInt16(GetProcessID and $FFFF);
  {$ELSE}
  Result := UInt16(0);
  {$ENDIF}
end;

procedure EnsureXidSeeded;
var
  LCounterSeed: array[0..2] of Byte;
begin
  if AtomicLoad32(GXidInitState, moAcquire) = 2 then
    Exit;

  if AtomicCompareExchange32(GXidInitState, 0, 1, moAcqRel) = 0 then
  begin
    try
      IdRngFillBytes(@GMachineId[0], 3);
      IdRngFillBytes(@LCounterSeed[0], 3);
      GCounter := (Int32(LCounterSeed[0]) shl 16) or
                  (Int32(LCounterSeed[1]) shl 8) or
                  Int32(LCounterSeed[2]);
      AtomicStore32(GXidInitState, 2, moRelease);
    except
      AtomicStore32(GXidInitState, 0, moRelease);
      raise;
    end;
    Exit;
  end;

  while AtomicLoad32(GXidInitState, moAcquire) = 1 do
    CpuPause;
  EnsureXidSeeded;
end;

function CurrentXidTimestamp: UInt32;
var
  LUnixSeconds: UInt64;
begin
  LUnixSeconds := platform_realtime_ns div 1000000000;
  if LUnixSeconds > UInt64(High(UInt32)) then
    raise EOutOfRange.Create('TXid.New: realtime clock exceeds XID timestamp range');
  Result := UInt32(LUnixSeconds);
end;

class function TXid.New: TXid;
var
  LTs: UInt32;
  LPid: UInt16;
  LRawCnt: UInt32;
  LCnt: UInt32;
begin
  EnsureXidSeeded;
  while AtomicCompareExchange32(GNewLock, 0, 1) <> 0 do
    CpuPause;
  try
    LTs := CurrentXidTimestamp;
    if LTs < GLastTs then
      LTs := GLastTs;
    LPid := GetPid16;
    LRawCnt := UInt32(AtomicFetchAdd32(GCounter, 1));
    LCnt := LRawCnt and XID_COUNTER_MASK;
    if GHasLastXid and (LCnt <= GLastCnt) and (LTs <= GLastTs) then
    begin
      if GLastTs = High(UInt32) then
        raise EOutOfRange.Create('TXid.New: logical timestamp exceeds XID timestamp range');
      LTs := GLastTs + 1;
    end
    else if LTs < GLastTs then
      LTs := GLastTs;
    GLastTs := LTs;
    GLastCnt := LCnt;
    GHasLastXid := True;

    Result.FBytes[0] := Byte(LTs shr 24);
    Result.FBytes[1] := Byte(LTs shr 16);
    Result.FBytes[2] := Byte(LTs shr 8);
    Result.FBytes[3] := Byte(LTs);
    Result.FBytes[4] := GMachineId[0];
    Result.FBytes[5] := GMachineId[1];
    Result.FBytes[6] := GMachineId[2];
    Result.FBytes[7] := Byte(LPid shr 8);
    Result.FBytes[8] := Byte(LPid);
    Result.FBytes[9] := Byte(LCnt shr 16);
    Result.FBytes[10] := Byte(LCnt shr 8);
    Result.FBytes[11] := Byte(LCnt);
  finally
    AtomicStore32(GNewLock, 0, moRelease);
  end;
end;

class function TXid.TryParse(const AStr: string; out AXid: TXid): Boolean;
var
  LI: Integer;
  LVal: Int32;
  LBuf: array[0..19] of Byte;
  LDecoded: TXid;
begin
  Result := False;
  if Length(AStr) <> XID_STRING_LENGTH then Exit;
  for LI := 0 to 19 do
  begin
    if (Ord(AStr[LI + 1]) > 127) then Exit;
    LVal := GXidDecodeTable[Ord(AStr[LI + 1])];
    if LVal < 0 then Exit;
    LBuf[LI] := Byte(LVal);
  end;
  if (LBuf[19] and $0F) <> 0 then Exit(False);
  FillChar(LDecoded.FBytes, 12, 0);
  LDecoded.FBytes[0]  := Byte((LBuf[0] shl 3) or (LBuf[1] shr 2));
  LDecoded.FBytes[1]  := Byte((LBuf[1] shl 6) or (LBuf[2] shl 1) or (LBuf[3] shr 4));
  LDecoded.FBytes[2]  := Byte((LBuf[3] shl 4) or (LBuf[4] shr 1));
  LDecoded.FBytes[3]  := Byte((LBuf[4] shl 7) or (LBuf[5] shl 2) or (LBuf[6] shr 3));
  LDecoded.FBytes[4]  := Byte((LBuf[6] shl 5) or LBuf[7]);
  LDecoded.FBytes[5]  := Byte((LBuf[8] shl 3) or (LBuf[9] shr 2));
  LDecoded.FBytes[6]  := Byte((LBuf[9] shl 6) or (LBuf[10] shl 1) or (LBuf[11] shr 4));
  LDecoded.FBytes[7]  := Byte((LBuf[11] shl 4) or (LBuf[12] shr 1));
  LDecoded.FBytes[8]  := Byte((LBuf[12] shl 7) or (LBuf[13] shl 2) or (LBuf[14] shr 3));
  LDecoded.FBytes[9]  := Byte((LBuf[14] shl 5) or LBuf[15]);
  LDecoded.FBytes[10] := Byte((LBuf[16] shl 3) or (LBuf[17] shr 2));
  LDecoded.FBytes[11] := Byte((LBuf[17] shl 6) or (LBuf[18] shl 1) or (LBuf[19] shr 4));
  AXid := LDecoded;
  Result := True;
end;

class function TXid.Parse(const AStr: string): TXid;
begin
  if not TryParse(AStr, Result) then
    raise EParseError.Create('TXid.Parse: invalid XID string');
end;

class function TXid.Nil_: TXid;
begin
  FillChar(Result.FBytes, 12, 0);
end;

function TXid.ToString: string;
var
  LB: array[0..11] of Byte;
begin
  LB := FBytes;
  SetLength(Result, XID_STRING_LENGTH);
  Result[1]  := XID_ENCODING[(LB[0] shr 3) + 1];
  Result[2]  := XID_ENCODING[(((LB[0] shl 2) or (LB[1] shr 6)) and $1F) + 1];
  Result[3]  := XID_ENCODING[((LB[1] shr 1) and $1F) + 1];
  Result[4]  := XID_ENCODING[(((LB[1] shl 4) or (LB[2] shr 4)) and $1F) + 1];
  Result[5]  := XID_ENCODING[(((LB[2] shl 1) or (LB[3] shr 7)) and $1F) + 1];
  Result[6]  := XID_ENCODING[((LB[3] shr 2) and $1F) + 1];
  Result[7]  := XID_ENCODING[(((LB[3] shl 3) or (LB[4] shr 5)) and $1F) + 1];
  Result[8]  := XID_ENCODING[(LB[4] and $1F) + 1];
  Result[9]  := XID_ENCODING[(LB[5] shr 3) + 1];
  Result[10] := XID_ENCODING[(((LB[5] shl 2) or (LB[6] shr 6)) and $1F) + 1];
  Result[11] := XID_ENCODING[((LB[6] shr 1) and $1F) + 1];
  Result[12] := XID_ENCODING[(((LB[6] shl 4) or (LB[7] shr 4)) and $1F) + 1];
  Result[13] := XID_ENCODING[(((LB[7] shl 1) or (LB[8] shr 7)) and $1F) + 1];
  Result[14] := XID_ENCODING[((LB[8] shr 2) and $1F) + 1];
  Result[15] := XID_ENCODING[(((LB[8] shl 3) or (LB[9] shr 5)) and $1F) + 1];
  Result[16] := XID_ENCODING[(LB[9] and $1F) + 1];
  Result[17] := XID_ENCODING[(LB[10] shr 3) + 1];
  Result[18] := XID_ENCODING[(((LB[10] shl 2) or (LB[11] shr 6)) and $1F) + 1];
  Result[19] := XID_ENCODING[((LB[11] shr 1) and $1F) + 1];
  Result[20] := XID_ENCODING[((LB[11] shl 4) and $1F) + 1];
end;

function TXid.Timestamp: UInt32;
begin
  Result := (UInt32(FBytes[0]) shl 24) or (UInt32(FBytes[1]) shl 16) or
            (UInt32(FBytes[2]) shl 8) or UInt32(FBytes[3]);
end;

function TXid.IsNil: Boolean;
var LI: Integer;
begin
  for LI := 0 to 11 do
    if FBytes[LI] <> 0 then Exit(False);
  Result := True;
end;

function TXid.CompareTo(const AOther: TXid): Int32;
var LI: Integer;
begin
  for LI := 0 to 11 do
  begin
    if FBytes[LI] < AOther.FBytes[LI] then Exit(-1);
    if FBytes[LI] > AOther.FBytes[LI] then Exit(1);
  end;
  Result := 0;
end;

class operator TXid.= (const A, B: TXid): Boolean;
var LI: Integer;
begin
  for LI := 0 to 11 do
    if A.FBytes[LI] <> B.FBytes[LI] then Exit(False);
  Result := True;
end;

class operator TXid.< (const A, B: TXid): Boolean;
begin
  Result := A.CompareTo(B) < 0;
end;

function XidNew: string;
begin
  Result := TXid.New.ToString;
end;

function XidIsValid(const AStr: string): Boolean;
var
  LXid: TXid;
begin
  Result := TXid.TryParse(AStr, LXid);
end;

function XidTimestamp(const AStr: string): UInt32;
var
  LTimestamp: UInt32;
begin
  if XidTryTimestamp(AStr, LTimestamp) then
    Result := LTimestamp
  else
    Result := 0;
end;

function XidTryTimestamp(const AStr: string; out ATimestamp: UInt32): Boolean;
var
  LXid: TXid;
begin
  if not TXid.TryParse(AStr, LXid) then
    Exit(False);
  ATimestamp := LXid.Timestamp;
  Result := True;
end;

initialization
  InitXidDecodeTable;

end.
