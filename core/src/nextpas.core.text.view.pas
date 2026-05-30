unit nextpas.core.text.view;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  TStringView = record
  private
    FData: PAnsiChar;
    FLen: SizeUInt;
  public
    class function Create(const AData: PAnsiChar; const ALen: SizeUInt): TStringView; static; inline;
    class function FromStr(const AStr: string): TStringView; static; inline;
    class function FromSpan(const ASpan: TByteSpan): TStringView; static; inline;
    class function Empty: TStringView; static; inline;

    function IsEmpty: Boolean; inline;
    property Data: PAnsiChar read FData;
    property Len: SizeUInt read FLen;

    function Slice(const AOffset, ALength: SizeUInt): TStringView;
    function Left(const ACount: SizeUInt): TStringView; inline;
    function Right(const ACount: SizeUInt): TStringView; inline;
    function Trim: TStringView;
    function TrimLeft: TStringView;
    function TrimRight: TStringView;

    function Equals(const AOther: TStringView): Boolean;
    function EqualsIgnoreCase(const AOther: TStringView): Boolean;
    function StartsWith(const APrefix: TStringView): Boolean;
    function EndsWith(const ASuffix: TStringView): Boolean;

    function IndexOf(const ACh: AnsiChar): PtrInt;
    function LastIndexOf(const ACh: AnsiChar): PtrInt;
    function IndexOfStr(const ANeedle: TStringView): PtrInt;
    function Contains(const ACh: AnsiChar): Boolean; inline;
    function CountChar(const ACh: AnsiChar): SizeUInt;
    function SplitFirst(const ASep: AnsiChar; out ALeft, ARight: TStringView): Boolean;

    function PeekByte: Byte; inline;
    function TryConsumeByte(out AByte: Byte): Boolean; inline;
    procedure Advance(const ACount: SizeUInt); inline;

    function ToString: string;
    function ToSpan: TByteSpan; inline;
  end;

implementation

uses
  nextpas.core.text.char,
  nextpas.core.simd.base,
  nextpas.core.simd.vec;

class function TStringView.Create(const AData: PAnsiChar; const ALen: SizeUInt): TStringView;
begin
  Result.FData := AData;
  Result.FLen := ALen;
end;

class function TStringView.FromStr(const AStr: string): TStringView;
begin
  Result.FData := PAnsiChar(AStr);
  Result.FLen := SizeUInt(Length(AStr));
end;

class function TStringView.FromSpan(const ASpan: TByteSpan): TStringView;
begin
  Result.FData := PAnsiChar(ASpan.Data);
  Result.FLen := ASpan.Len;
end;

class function TStringView.Empty: TStringView;
begin
  Result.FData := nil;
  Result.FLen := 0;
end;

function TStringView.IsEmpty: Boolean;
begin
  Result := FLen = 0;
end;

function TStringView.Slice(const AOffset, ALength: SizeUInt): TStringView;
begin
  if AOffset >= FLen then
  begin
    Result.FData := nil;
    Result.FLen := 0;
    Exit;
  end;
  Result.FData := FData + AOffset;
  if AOffset + ALength > FLen then
    Result.FLen := FLen - AOffset
  else
    Result.FLen := ALength;
end;

function TStringView.Left(const ACount: SizeUInt): TStringView;
begin
  if ACount >= FLen then
    Result := Self
  else
  begin
    Result.FData := FData;
    Result.FLen := ACount;
  end;
end;

function TStringView.Right(const ACount: SizeUInt): TStringView;
begin
  if ACount >= FLen then
    Result := Self
  else
  begin
    Result.FData := FData + (FLen - ACount);
    Result.FLen := ACount;
  end;
end;

function TStringView.TrimLeft: TStringView;
var
  LPos: SizeUInt;
  i: Integer;
begin
  LPos := 0;
  while (LPos < FLen) and IsWhitespace(Byte(FData[LPos])) do
    Inc(LPos);
  Result.FData := FData + LPos;
  Result.FLen := FLen - LPos;
end;

function TStringView.TrimRight: TStringView;
var
  LEnd: SizeUInt;
begin
  LEnd := FLen;
  while (LEnd > 0) and IsWhitespace(Byte(FData[LEnd - 1])) do
    Dec(LEnd);
  Result.FData := FData;
  Result.FLen := LEnd;
end;

function TStringView.Trim: TStringView;
begin
  Result := TrimLeft.TrimRight;
end;

function TStringView.Equals(const AOther: TStringView): Boolean;
var
  LPos: SizeUInt;
  i: Integer;
begin
  if FLen <> AOther.FLen then
    Exit(False);
  if FLen = 0 then
    Exit(True);
  if FData = AOther.FData then
    Exit(True);
  LPos := 0;
  while LPos + VecWidth <= FLen do
  begin
    if VecCmpEq2(@FData[LPos], @AOther.FData[LPos]) <> TVecMask(not TVecMask(0)) then
      Exit(False);
    Inc(LPos, VecWidth);
  end;
  while LPos < FLen do
  begin
    if FData[LPos] <> AOther.FData[LPos] then
      Exit(False);
    Inc(LPos);
  end;
  Result := True;
end;

function TStringView.EqualsIgnoreCase(const AOther: TStringView): Boolean;
var
  LPos: SizeUInt;
  i: Integer;
  LBufA, LBufB: array[0..15] of Byte;
  LMaskA, LMaskB: TVecMask;
begin
  if FLen <> AOther.FLen then
    Exit(False);
  if FLen = 0 then
    Exit(True);
  LPos := 0;
  while LPos + VecWidth <= FLen do
  begin
    Move(FData[LPos], LBufA[0], 16);
    Move(AOther.FData[LPos], LBufB[0], 16);
    LMaskA := VecCmpRange(@LBufA[0], Ord('A'), Ord('Z'));
    for i := 0 to 15 do if (LMaskA and (1 shl i)) <> 0 then LBufA[i] := LBufA[i] + 32;
    LMaskB := VecCmpRange(@LBufB[0], Ord('A'), Ord('Z'));
    for i := 0 to 15 do if (LMaskB and (1 shl i)) <> 0 then LBufB[i] := LBufB[i] + 32;
    if VecCmpEq2(@LBufA[0], @LBufB[0]) <> TVecMask(not TVecMask(0)) then
      Exit(False);
    Inc(LPos, VecWidth);
  end;
  while LPos < FLen do
  begin
    if ToLower(Byte(FData[LPos])) <> ToLower(Byte(AOther.FData[LPos])) then
      Exit(False);
    Inc(LPos);
  end;
  Result := True;
end;

function TStringView.StartsWith(const APrefix: TStringView): Boolean;
var
  LV: TStringView;
begin
  if APrefix.FLen > FLen then
    Exit(False);
  if APrefix.FLen = 0 then
    Exit(True);
  LV := Left(APrefix.FLen);
  Result := LV.Equals(APrefix);
end;

function TStringView.EndsWith(const ASuffix: TStringView): Boolean;
var
  LV: TStringView;
begin
  if ASuffix.FLen > FLen then
    Exit(False);
  if ASuffix.FLen = 0 then
    Exit(True);
  LV := Right(ASuffix.FLen);
  Result := LV.Equals(ASuffix);
end;

function TStringView.IndexOf(const ACh: AnsiChar): PtrInt;
var
  LMask: TVecMask;
  LPos: SizeUInt;
  i: Integer;
begin
  if FLen = 0 then
    Exit(-1);
  LPos := 0;
  while LPos + VecWidth <= FLen do
  begin
    LMask := VecCmpEq(@FData[LPos], Byte(ACh));
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
  end;
  while LPos < FLen do
  begin
    if FData[LPos] = ACh then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function TStringView.LastIndexOf(const ACh: AnsiChar): PtrInt;
var
  I: PtrInt;
begin
  if FLen = 0 then
    Exit(-1);
  for I := PtrInt(FLen) - 1 downto 0 do
    if FData[I] = ACh then
      Exit(I);
  Result := -1;
end;

function TStringView.IndexOfStr(const ANeedle: TStringView): PtrInt;
var
  LMaskFirst, LMaskLast, LCombined: TVecMask;
  LPos: SizeUInt;
  i: Integer;
  LBit: Int32;
  LLastOfs: SizeUInt;
begin
  if ANeedle.FLen = 0 then
    Exit(0);
  if ANeedle.FLen > FLen then
    Exit(-1);
  if ANeedle.FLen = 1 then
    Exit(IndexOf(ANeedle.FData[0]));
  LLastOfs := ANeedle.FLen - 1;
  LPos := 0;
  while LPos + 16 + LLastOfs <= FLen do
  begin
    LMaskFirst := VecCmpEq(@FData[LPos], Byte(ANeedle.FData[0]));
    LMaskLast := VecCmpEq(@FData[LPos + LLastOfs], Byte(ANeedle.FData[LLastOfs]));
    LCombined := LMaskFirst and LMaskLast;
    while LCombined <> TVecMask(0) do
    begin
      LBit := VecCtz(LCombined);
      if Slice(LPos + SizeUInt(LBit), ANeedle.FLen).Equals(ANeedle) then
        Exit(PtrInt(LPos) + LBit);
      LCombined := LCombined and not TVecMask(TVecMask(1) shl LBit);
    end;
    Inc(LPos, VecWidth);
  end;
  while LPos <= FLen - ANeedle.FLen do
  begin
    if (FData[LPos] = ANeedle.FData[0]) and
       (FData[LPos + LLastOfs] = ANeedle.FData[LLastOfs]) then
      if Slice(LPos, ANeedle.FLen).Equals(ANeedle) then
        Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function TStringView.Contains(const ACh: AnsiChar): Boolean;
begin
  Result := IndexOf(ACh) >= 0;
end;

function TStringView.CountChar(const ACh: AnsiChar): SizeUInt;
var
  LPos: SizeUInt;
  i: Integer;
begin
  Result := 0;
  if FLen = 0 then
    Exit;
  LPos := 0;
  while LPos + VecWidth <= FLen do
  begin
    Inc(Result, Vec16Popcnt(VecCmpEq(@FData[LPos], Byte(ACh))));
    Inc(LPos, VecWidth);
  end;
  while LPos < FLen do
  begin
    if FData[LPos] = ACh then
      Inc(Result);
    Inc(LPos);
  end;
end;

function TStringView.SplitFirst(const ASep: AnsiChar; out ALeft, ARight: TStringView): Boolean;
var
  LIdx: PtrInt;
begin
  LIdx := IndexOf(ASep);
  if LIdx < 0 then
  begin
    ALeft := Self;
    ARight := TStringView.Empty;
    Exit(False);
  end;
  ALeft := Left(SizeUInt(LIdx));
  ARight := Slice(SizeUInt(LIdx) + 1, FLen - SizeUInt(LIdx) - 1);
  Result := True;
end;

function TStringView.PeekByte: Byte;
begin
  if FLen = 0 then
    Result := 0
  else
    Result := Byte(FData[0]);
end;

function TStringView.TryConsumeByte(out AByte: Byte): Boolean;
begin
  if FLen = 0 then
  begin
    AByte := 0;
    Exit(False);
  end;
  AByte := Byte(FData[0]);
  Inc(FData);
  Dec(FLen);
  Result := True;
end;

procedure TStringView.Advance(const ACount: SizeUInt);
begin
  if ACount >= FLen then
  begin
    Inc(FData, FLen);
    FLen := 0;
  end
  else
  begin
    Inc(FData, ACount);
    Dec(FLen, ACount);
  end;
end;

function TStringView.ToString: string;
begin
  if FLen = 0 then
    Result := ''
  else
    SetString(Result, FData, FLen);
end;

function TStringView.ToSpan: TByteSpan;
begin
  Result := TByteSpan.Create(PByte(FData), FLen);
end;

end.
