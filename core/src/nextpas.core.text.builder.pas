unit nextpas.core.text.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf;

type
  TStringBuilder = record
  private
    FBuf: PAnsiChar;
    FLen: SizeUInt;
    FCap: SizeUInt;
    FAllocator: IAllocator;
    procedure Grow(const ANeeded: SizeUInt);
  public
    procedure Init(const AInitialCap: SizeUInt = 256);
    procedure InitWith(const AInitialCap: SizeUInt; const AAllocator: IAllocator);
    procedure Done;

    procedure AppendByte(const AByte: Byte); inline;
    procedure AppendChar(const ACh: AnsiChar); inline;
    procedure AppendChars(const ACh: AnsiChar; const ACount: SizeUInt);
    procedure AppendView(const AView: TStringView);
    procedure AppendStr(const AStr: string);
    procedure AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt);
    procedure AppendInt(const AValue: Int64);
    procedure AppendUInt(const AValue: UInt64);
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1);
    procedure AppendBool(const AValue: Boolean);
    procedure AppendFloat(const AValue: Double);

    function AsView: TStringView; inline;
    function ToString: string;
    function Len: SizeUInt; inline;
    function Cap: SizeUInt; inline;
    function Tail: PAnsiChar; inline;
    procedure AdvanceLen(const ACount: SizeUInt); inline;
    procedure Clear; inline;
    procedure Reserve(const AAdditional: SizeUInt);
  end;

implementation

uses
  nextpas.core.text.number;

procedure TStringBuilder.Grow(const ANeeded: SizeUInt);
var
  LNewCap, LRequired: SizeUInt;
begin
  LRequired := FLen + ANeeded;
  LNewCap := FCap;
  if LNewCap = 0 then
    LNewCap := 256;
  while LNewCap < LRequired do
  begin
    if LNewCap > (High(SizeUInt) shr 1) then
    begin
      LNewCap := LRequired;
      Break;
    end;
    LNewCap := LNewCap * 2;
  end;
  if FAllocator <> nil then
    FBuf := FAllocator.Reallocate(FBuf, LNewCap)
  else
    ReallocMem(FBuf, LNewCap);
  FCap := LNewCap;
end;

procedure TStringBuilder.Init(const AInitialCap: SizeUInt);
begin
  FLen := 0;
  FCap := AInitialCap;
  FAllocator := nil;
  if FCap > 0 then
    GetMem(FBuf, FCap)
  else
    FBuf := nil;
end;

procedure TStringBuilder.InitWith(const AInitialCap: SizeUInt; const AAllocator: IAllocator);
begin
  FLen := 0;
  FAllocator := AAllocator;
  FCap := AInitialCap;
  if FCap > 0 then
  begin
    if FAllocator <> nil then
      FBuf := FAllocator.Allocate(FCap)
    else
      GetMem(FBuf, FCap);
  end
  else
    FBuf := nil;
end;

procedure TStringBuilder.Done;
begin
  if FBuf <> nil then
  begin
    if FAllocator <> nil then
      FAllocator.Deallocate(FBuf)
    else
      FreeMem(FBuf);
    FBuf := nil;
  end;
  FLen := 0;
  FCap := 0;
  FAllocator := nil;
end;

procedure TStringBuilder.AppendByte(const AByte: Byte);
begin
  if FLen >= FCap then
    Grow(1);
  FBuf[FLen] := AnsiChar(AByte);
  Inc(FLen);
end;

procedure TStringBuilder.AppendChar(const ACh: AnsiChar);
begin
  if FLen >= FCap then
    Grow(1);
  FBuf[FLen] := ACh;
  Inc(FLen);
end;

procedure TStringBuilder.AppendChars(const ACh: AnsiChar; const ACount: SizeUInt);
begin
  if ACount = 0 then Exit;
  if FLen + ACount > FCap then
    Grow(ACount);
  FillChar(FBuf[FLen], ACount, Byte(ACh));
  Inc(FLen, ACount);
end;

procedure TStringBuilder.AppendView(const AView: TStringView);
begin
  if AView.Len = 0 then Exit;
  if FLen + AView.Len > FCap then
    Grow(AView.Len);
  Move(AView.Data^, FBuf[FLen], AView.Len);
  Inc(FLen, AView.Len);
end;

procedure TStringBuilder.AppendStr(const AStr: string);
var
  L: SizeUInt;
begin
  L := SizeUInt(Length(AStr));
  if L = 0 then Exit;
  if FLen + L > FCap then
    Grow(L);
  Move(PAnsiChar(AStr)^, FBuf[FLen], L);
  Inc(FLen, L);
end;

procedure TStringBuilder.AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt);
begin
  if ALen = 0 then Exit;
  if FLen + ALen > FCap then
    Grow(ALen);
  Move(AData^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TStringBuilder.AppendInt(const AValue: Int64);
var
  LWritten: Int32;
begin
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := IntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TStringBuilder.AppendUInt(const AValue: UInt64);
var
  LWritten: Int32;
begin
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := UIntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TStringBuilder.AppendHex(const AValue: UInt64; const AMinDigits: Int32);
var
  LWritten: Int32;
begin
  if FLen + 16 > FCap then
    Grow(16);
  LWritten := IntToHexBuffer(AValue, FBuf + FLen, AMinDigits);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TStringBuilder.AppendBool(const AValue: Boolean);
begin
  if AValue then
    AppendBytes('true', 4)
  else
    AppendBytes('false', 5);
end;

procedure TStringBuilder.AppendFloat(const AValue: Double);
var
  LWritten: Int32;
begin
  if FLen + 25 > FCap then
    Grow(25);
  LWritten := FloatToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

function TStringBuilder.AsView: TStringView;
begin
  Result := TStringView.Create(FBuf, FLen);
end;

function TStringBuilder.ToString: string;
begin
  if FLen = 0 then
    Result := ''
  else
    SetString(Result, FBuf, FLen);
end;

function TStringBuilder.Len: SizeUInt;
begin
  Result := FLen;
end;

function TStringBuilder.Cap: SizeUInt;
begin
  Result := FCap;
end;

function TStringBuilder.Tail: PAnsiChar;
begin
  Result := FBuf + FLen;
end;

procedure TStringBuilder.AdvanceLen(const ACount: SizeUInt);
begin
  Inc(FLen, ACount);
end;

procedure TStringBuilder.Clear;
begin
  FLen := 0;
end;

procedure TStringBuilder.Reserve(const AAdditional: SizeUInt);
begin
  if FLen + AAdditional > FCap then
    Grow(AAdditional);
end;

end.
