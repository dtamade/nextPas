unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base;

function SpanEqual(const A, B: TByteSpan): Boolean;
function SpanCompare(const A, B: TByteSpan): Integer;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt;
function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean; inline;
function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean;
function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
procedure SpanReverse(const ASpan: TByteSpan);

function SpanConcat(const A, B: TByteSpan): TBytes;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

implementation

function SpanEqual(const A, B: TByteSpan): Boolean;
var
  LI: SizeUInt;
begin
  if A.Len <> B.Len then
    Exit(False);
  if (A.Len = 0) or (A.Data = B.Data) then
    Exit(True);
  for LI := 0 to A.Len - 1 do
    if A.Data[LI] <> B.Data[LI] then
      Exit(False);
  Result := True;
end;

function SpanCompare(const A, B: TByteSpan): Integer;
var
  LI, LMin: SizeUInt;
begin
  if A.Len < B.Len then
    LMin := A.Len
  else
    LMin := B.Len;
  for LI := 0 to LMin - 1 do
  begin
    if A.Data[LI] < B.Data[LI] then
      Exit(-1);
    if A.Data[LI] > B.Data[LI] then
      Exit(1);
  end;
  if A.Len < B.Len then
    Result := -1
  else if A.Len > B.Len then
    Result := 1
  else
    Result := 0;
end;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt;
var
  LI: SizeUInt;
begin
  for LI := 0 to AHaystack.Len - 1 do
    if AHaystack.Data[LI] = ANeedle then
      Exit(SizeInt(LI));
  Result := -1;
end;

function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
var
  LI, LJ: SizeUInt;
  LMatch: Boolean;
begin
  if ANeedle.Len = 0 then
    Exit(0);
  if ANeedle.Len > AHaystack.Len then
    Exit(-1);
  for LI := 0 to AHaystack.Len - ANeedle.Len do
  begin
    LMatch := True;
    for LJ := 0 to ANeedle.Len - 1 do
      if AHaystack.Data[LI + LJ] <> ANeedle.Data[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
      Exit(SizeInt(LI));
  end;
  Result := -1;
end;

function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean;
begin
  Result := SpanIndexOf(AHaystack, ANeedle) >= 0;
end;

function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean;
var
  LI: SizeUInt;
begin
  if APrefix.Len = 0 then
    Exit(True);
  if APrefix.Len > AData.Len then
    Exit(False);
  for LI := 0 to APrefix.Len - 1 do
    if AData.Data[LI] <> APrefix.Data[LI] then
      Exit(False);
  Result := True;
end;

function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean;
var
  LI, LOffset: SizeUInt;
begin
  if ASuffix.Len = 0 then
    Exit(True);
  if ASuffix.Len > AData.Len then
    Exit(False);
  LOffset := AData.Len - ASuffix.Len;
  for LI := 0 to ASuffix.Len - 1 do
    if AData.Data[LOffset + LI] <> ASuffix.Data[LI] then
      Exit(False);
  Result := True;
end;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
begin
  if ASpan.Len > 0 then
    FillChar(ASpan.Data^, ASpan.Len, AValue);
end;

procedure SpanReverse(const ASpan: TByteSpan);
var
  LI, LJ: SizeUInt;
  LTmp: Byte;
begin
  if ASpan.Len <= 1 then
    Exit;
  LI := 0;
  LJ := ASpan.Len - 1;
  while LI < LJ do
  begin
    LTmp := ASpan.Data[LI];
    ASpan.Data[LI] := ASpan.Data[LJ];
    ASpan.Data[LJ] := LTmp;
    Inc(LI);
    Dec(LJ);
  end;
end;

function SpanConcat(const A, B: TByteSpan): TBytes;
begin
  SetLength(Result, A.Len + B.Len);
  if A.Len > 0 then
    Move(A.Data^, Result[0], A.Len);
  if B.Len > 0 then
    Move(B.Data^, Result[A.Len], B.Len);
end;

function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
begin
  SetLength(Result, ALength);
  if ALength > 0 then
    Move(ASpan.Data[AOffset], Result[0], ALength);
end;

function SpanClone(const ASpan: TByteSpan): TBytes;
begin
  SetLength(Result, ASpan.Len);
  if ASpan.Len > 0 then
    Move(ASpan.Data^, Result[0], ASpan.Len);
end;

{ TBytes convenience }

function BytesEqual(const A, B: TBytes): Boolean;
begin
  Result := SpanEqual(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

function BytesCompare(const A, B: TBytes): Integer;
begin
  Result := SpanCompare(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt;
begin
  Result := SpanIndexOf(TByteSpan.FromBytes(AData), ANeedle);
end;

function BytesConcat(const A, B: TBytes): TBytes;
begin
  Result := SpanConcat(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

end.
