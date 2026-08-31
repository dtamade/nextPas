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
    function EqualsIgnoreCase(const AOther: TStringView): Boolean; inline;
    function StartsWith(const APrefix: TStringView): Boolean;
    function EndsWith(const ASuffix: TStringView): Boolean;

    function IndexOf(const ACh: AnsiChar): PtrInt;
    function LastIndexOf(const ACh: AnsiChar): PtrInt;
    function IndexOfStr(const ANeedle: TStringView): PtrInt; overload;
    function IndexOfStr(const ANeedle: TStringView; AFrom: PtrInt): PtrInt; overload;
    function Contains(const ACh: AnsiChar): Boolean; inline;
    function CountChar(const ACh: AnsiChar): SizeUInt;
    function SplitFirst(const ASep: AnsiChar; out ALeft, ARight: TStringView): Boolean;

    function PeekByte: Byte; inline;
    function TryConsumeByte(out AByte: Byte): Boolean; inline;
    procedure Advance(const ACount: SizeUInt); inline;

    function ToString: string;
    function ToSpan: TByteSpan; inline;
  end;

function IndexOfStr(const AValue, ASubStr: string): PtrInt; overload;
function IndexOfStr(const AValue, ASubStr: string; AFrom: PtrInt): PtrInt; overload;
function LastIndexOfStr(const AValue, ASubStr: string): PtrInt;

{ 一致切片即时拷贝（string→string）：等价
  TStringView.FromStr(ASrc).Slice(AOffset, ALength).ToString，但单次
  SetString、无中间 view 跨语句存活。存在理由：FPC 3.3.1-19195 对
  「X := TStringView.FromStr(X).Slice(..).ToString」自赋值链生成坏码——
  view 源缓冲在赋值期被提前失效，产出短一字符尾随 #0 的串（-O0 亦复现；
  与 Int64(Double) 强转缺陷同类）。源串可能与目标同变量的场景一律用本
  函数。越界钳制与 Slice 一致：AOffset >= Length(ASrc) → ''；ALength
  超出 → 截到末尾。 }
function SliceToStr(const ASrc: string; const AOffset, ALength: SizeUInt): string;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.char,
  nextpas.core.simd.base,
  nextpas.core.simd.vec;

class function TStringView.Create(const AData: PAnsiChar; const ALen: SizeUInt): TStringView;
begin
  if (ALen > 0) and (AData = nil) then
    raise EInvalidArgument.Create('TStringView.Create: non-empty view has nil data');
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
  Result := Create(PAnsiChar(ASpan.Data), ASpan.Len);
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
var
  LRemaining: SizeUInt;
begin
  if AOffset >= FLen then
  begin
    Result.FData := nil;
    Result.FLen := 0;
    Exit;
  end;
  Result.FData := FData + AOffset;
  LRemaining := FLen - AOffset;
  if ALength > LRemaining then
    Result.FLen := LRemaining
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

function TStringView.EqualsIgnoreCase(const AOther: TStringView): Boolean; inline;
begin
  if FLen <> AOther.FLen then
    Exit(False);
  if FLen = 0 then
    Exit(True);
  if FData = AOther.FData then
    Exit(True);
  Result := SpanEqualIgnoreCase(
    TByteSpan.Create(PByte(FData), FLen),
    TByteSpan.Create(PByte(AOther.FData), AOther.FLen));
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

function TStringView.IndexOfStr(const ANeedle: TStringView; AFrom: PtrInt): PtrInt;
var
  LRest: TStringView;
begin
  if AFrom < 0 then
    AFrom := 0;
  if SizeUInt(AFrom) > FLen then
    Exit(-1);
  if SizeUInt(AFrom) = FLen then
  begin
    if ANeedle.FLen = 0 then
      Exit(AFrom);
    Exit(-1);
  end;
  LRest := Slice(SizeUInt(AFrom), FLen - SizeUInt(AFrom));
  Result := LRest.IndexOfStr(ANeedle);
  if Result >= 0 then
    Inc(Result, AFrom);
end;

function TStringView.Contains(const ACh: AnsiChar): Boolean;
begin
  Result := IndexOf(ACh) >= 0;
end;

function TStringView.CountChar(const ACh: AnsiChar): SizeUInt;
var
  LPos: SizeUInt;
begin
  Result := 0;
  if FLen = 0 then
    Exit;
  LPos := 0;
  while LPos + VecWidth <= FLen do
  begin
    Inc(Result, VecPopcnt(VecCmpEq(@FData[LPos], Byte(ACh))));
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

function IndexOfStr(const AValue, ASubStr: string): PtrInt;
begin
  Result := TStringView.FromStr(AValue).IndexOfStr(TStringView.FromStr(ASubStr));
end;

function IndexOfStr(const AValue, ASubStr: string; AFrom: PtrInt): PtrInt;
begin
  Result := TStringView.FromStr(AValue).IndexOfStr(TStringView.FromStr(ASubStr), AFrom);
end;

function LastIndexOfStr(const AValue, ASubStr: string): PtrInt;
var
  LValue: TStringView;
  LNeedle: TStringView;
  I: PtrInt;
begin
  LValue := TStringView.FromStr(AValue);
  LNeedle := TStringView.FromStr(ASubStr);

  if (LNeedle.Len = 0) or (LNeedle.Len > LValue.Len) then
    Exit(-1);
  if LNeedle.Len = 1 then
    Exit(LValue.LastIndexOf(LNeedle.Data[0]));

  for I := PtrInt(LValue.Len - LNeedle.Len) downto 0 do
    if LValue.Slice(SizeUInt(I), LNeedle.Len).Equals(LNeedle) then
      Exit(I);
  Result := -1;
end;

function SliceToStr(const ASrc: string; const AOffset, ALength: SizeUInt): string;
var
  LSrcLen, LTake: SizeUInt;
begin
  LSrcLen := SizeUInt(Length(ASrc));
  if AOffset >= LSrcLen then
    Exit('');
  LTake := ALength;
  if LTake > LSrcLen - AOffset then
    LTake := LSrcLen - AOffset;
  SetString(Result, PAnsiChar(@ASrc[AOffset + 1]), PtrInt(LTake));
end;

end.
