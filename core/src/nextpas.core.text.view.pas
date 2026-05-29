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
    function IndexOfStr(const ANeedle: TStringView): PtrInt;
    function Contains(const ACh: AnsiChar): Boolean; inline;
    function CountChar(const ACh: AnsiChar): SizeUInt;

    function PeekByte: Byte; inline;
    function TryConsumeByte(out AByte: Byte): Boolean; inline;
    procedure Advance(const ACount: SizeUInt); inline;

    function ToString: string;
    function ToSpan: TByteSpan; inline;
  end;

implementation

uses
  nextpas.core.text.char,
  nextpas.core.simd.api.v2;

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
begin
  if FLen <> AOther.FLen then
    Exit(False);
  if FLen = 0 then
    Exit(True);
  if FData = AOther.FData then
    Exit(True);
  Result := MemEqual(FData, AOther.FData, FLen);
end;

function TStringView.EqualsIgnoreCase(const AOther: TStringView): Boolean;
var
  I: SizeUInt;
begin
  if FLen <> AOther.FLen then
    Exit(False);
  for I := 0 to FLen - 1 do
    if ToLower(Byte(FData[I])) <> ToLower(Byte(AOther.FData[I])) then
      Exit(False);
  Result := True;
end;

function TStringView.StartsWith(const APrefix: TStringView): Boolean;
begin
  if APrefix.FLen > FLen then
    Exit(False);
  if APrefix.FLen = 0 then
    Exit(True);
  Result := MemEqual(FData, APrefix.FData, APrefix.FLen);
end;

function TStringView.EndsWith(const ASuffix: TStringView): Boolean;
begin
  if ASuffix.FLen > FLen then
    Exit(False);
  if ASuffix.FLen = 0 then
    Exit(True);
  Result := MemEqual(FData + (FLen - ASuffix.FLen), ASuffix.FData, ASuffix.FLen);
end;

function TStringView.IndexOf(const ACh: AnsiChar): PtrInt;
begin
  if FLen = 0 then
    Exit(-1);
  Result := MemFindByte(FData, FLen, Byte(ACh));
end;

function TStringView.IndexOfStr(const ANeedle: TStringView): PtrInt;
begin
  if ANeedle.FLen = 0 then
    Exit(0);
  if ANeedle.FLen > FLen then
    Exit(-1);
  if ANeedle.FLen = 1 then
    Exit(IndexOf(ANeedle.FData[0]));
  Result := BytesIndexOf(FData, FLen, ANeedle.FData, ANeedle.FLen);
end;

function TStringView.Contains(const ACh: AnsiChar): Boolean;
begin
  Result := IndexOf(ACh) >= 0;
end;

function TStringView.CountChar(const ACh: AnsiChar): SizeUInt;
begin
  if FLen = 0 then
    Exit(0);
  Result := CountByte(FData, FLen, Byte(ACh));
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
