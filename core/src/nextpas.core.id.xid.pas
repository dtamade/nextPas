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

implementation

uses
  nextpas.core.atomic,
  nextpas.core.id.rng,
  nextpas.core.platform.time;

const
  XID_ENCODING = '0123456789abcdefghijklmnopqrstuv';

var
  GMachineId: array[0..2] of Byte;
  GCounter: Int32 = 0;

function GetPid16: UInt16;
begin
  {$IFDEF UNIX}
  Result := UInt16(GetProcessID and $FFFF);
  {$ELSE}
  Result := UInt16(0);
  {$ENDIF}
end;

class function TXid.New: TXid;
var
  LTs: UInt32;
  LPid: UInt16;
  LCnt: UInt32;
begin
  LTs := UInt32(platform_realtime_ns div 1000000000);
  LPid := GetPid16;
  LCnt := UInt32(AtomicFetchAdd32(GCounter, 1)) and $FFFFFF;

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
end;

class function TXid.TryParse(const AStr: string; out AXid: TXid): Boolean;
var
  LI: Integer;
  LVal: Int32;
  LBuf: array[0..19] of Byte;
begin
  Result := False;
  if Length(AStr) <> XID_STRING_LENGTH then Exit;
  for LI := 0 to 19 do
  begin
    LVal := Pos(AStr[LI + 1], XID_ENCODING) - 1;
    if LVal < 0 then Exit;
    LBuf[LI] := Byte(LVal);
  end;
  FillChar(AXid.FBytes, 12, 0);
  AXid.FBytes[0]  := (LBuf[0] shl 3) or (LBuf[1] shr 2);
  AXid.FBytes[1]  := (LBuf[1] shl 6) or (LBuf[2] shl 1) or (LBuf[3] shr 4);
  AXid.FBytes[2]  := (LBuf[3] shl 4) or (LBuf[4] shr 1);
  AXid.FBytes[3]  := (LBuf[4] shl 7) or (LBuf[5] shl 2) or (LBuf[6] shr 3);
  AXid.FBytes[4]  := (LBuf[6] shl 5) or LBuf[7];
  AXid.FBytes[5]  := (LBuf[8] shl 3) or (LBuf[9] shr 2);
  AXid.FBytes[6]  := (LBuf[9] shl 6) or (LBuf[10] shl 1) or (LBuf[11] shr 4);
  AXid.FBytes[7]  := (LBuf[11] shl 4) or (LBuf[12] shr 1);
  AXid.FBytes[8]  := (LBuf[12] shl 7) or (LBuf[13] shl 2) or (LBuf[14] shr 3);
  AXid.FBytes[9]  := (LBuf[14] shl 5) or LBuf[15];
  AXid.FBytes[10] := (LBuf[16] shl 3) or (LBuf[17] shr 2);
  AXid.FBytes[11] := (LBuf[17] shl 6) or (LBuf[18] shl 1) or (LBuf[19] shr 4);
  Result := True;
end;

class function TXid.Parse(const AStr: string): TXid;
begin
  if not TryParse(AStr, Result) then
    FillChar(Result.FBytes, 12, 0);
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

initialization
  IdRngFillBytes(@GMachineId[0], 3);
  IdRngFillBytes(@GCounter, 3);

end.
