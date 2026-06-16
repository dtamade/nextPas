unit nextpas.core.text.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf;

type
  IStringBuilder = interface
    ['{0F3C5C09-6A06-4B65-A346-0E34A1A9F7F6}']
    procedure AppendChar(const ACh: AnsiChar);
    procedure AppendView(const AView: TStringView);
    procedure AppendStr(const AStr: string);
    procedure AppendInt(const AValue: Int64);
    procedure AppendUInt(const AValue: UInt64);
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1);
    procedure AppendBool(const AValue: Boolean);
    procedure AppendFloat(const AValue: Double);
    function AsView: TStringView;
    function ToString: string;
    function Len: SizeUInt;
    function Cap: SizeUInt;
    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
  end;

  TBufStringBuilder = record
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

  { Compatibility alias for internal callers that still use TStringBuilder
    directly. Public facade users should prefer IStringBuilder. }
  TStringBuilder = TBufStringBuilder;

function MakeStringBuilder(const AInitialCap: SizeUInt = 256): IStringBuilder;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.number;

type
  TStringBuilderImpl = class(TInterfacedObject, IStringBuilder)
  private
    FBuilder: TBufStringBuilder;
  public
    constructor Create(const AInitialCap: SizeUInt);
    destructor Destroy; override;
    procedure AppendChar(const ACh: AnsiChar);
    procedure AppendView(const AView: TStringView);
    procedure AppendStr(const AStr: string);
    procedure AppendInt(const AValue: Int64);
    procedure AppendUInt(const AValue: UInt64);
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1);
    procedure AppendBool(const AValue: Boolean);
    procedure AppendFloat(const AValue: Double);
    function AsView: TStringView;
    function ToString: string; override;
    function Len: SizeUInt;
    function Cap: SizeUInt;
    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
  end;

function MakeStringBuilder(const AInitialCap: SizeUInt): IStringBuilder;
begin
  Result := TStringBuilderImpl.Create(AInitialCap);
end;

constructor TStringBuilderImpl.Create(const AInitialCap: SizeUInt);
begin
  inherited Create;
  FBuilder.Init(AInitialCap);
end;

destructor TStringBuilderImpl.Destroy;
begin
  FBuilder.Done;
  inherited;
end;

procedure TStringBuilderImpl.AppendChar(const ACh: AnsiChar);
begin
  FBuilder.AppendChar(ACh);
end;

procedure TStringBuilderImpl.AppendView(const AView: TStringView);
begin
  FBuilder.AppendView(AView);
end;

procedure TStringBuilderImpl.AppendStr(const AStr: string);
begin
  FBuilder.AppendStr(AStr);
end;

procedure TStringBuilderImpl.AppendInt(const AValue: Int64);
begin
  FBuilder.AppendInt(AValue);
end;

procedure TStringBuilderImpl.AppendUInt(const AValue: UInt64);
begin
  FBuilder.AppendUInt(AValue);
end;

procedure TStringBuilderImpl.AppendHex(const AValue: UInt64; const AMinDigits: Int32);
begin
  FBuilder.AppendHex(AValue, AMinDigits);
end;

procedure TStringBuilderImpl.AppendBool(const AValue: Boolean);
begin
  FBuilder.AppendBool(AValue);
end;

procedure TStringBuilderImpl.AppendFloat(const AValue: Double);
begin
  FBuilder.AppendFloat(AValue);
end;

function TStringBuilderImpl.AsView: TStringView;
begin
  Result := FBuilder.AsView;
end;

function TStringBuilderImpl.ToString: string;
begin
  Result := FBuilder.ToString;
end;

function TStringBuilderImpl.Len: SizeUInt;
begin
  Result := FBuilder.Len;
end;

function TStringBuilderImpl.Cap: SizeUInt;
begin
  Result := FBuilder.Cap;
end;

procedure TStringBuilderImpl.Clear;
begin
  FBuilder.Clear;
end;

procedure TStringBuilderImpl.Reserve(const AAdditional: SizeUInt);
begin
  FBuilder.Reserve(AAdditional);
end;

procedure TBufStringBuilder.Grow(const ANeeded: SizeUInt);
var
  LNewCap, LRequired: SizeUInt;
begin
  if ANeeded > High(SizeUInt) - FLen then
    raise EOverflow.Create('string builder capacity overflow');
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
    FBuf := FAllocator.ReallocMem(FBuf, LNewCap)
  else
    ReallocMem(FBuf, LNewCap);
  if (LNewCap > 0) and (FBuf = nil) then
    raise EOutOfMemory.Create('string builder allocation failed');
  FCap := LNewCap;
end;

procedure TBufStringBuilder.Init(const AInitialCap: SizeUInt);
begin
  FLen := 0;
  FCap := AInitialCap;
  FAllocator := nil;
  if FCap > 0 then
    GetMem(FBuf, FCap)
  else
    FBuf := nil;
end;

procedure TBufStringBuilder.InitWith(const AInitialCap: SizeUInt; const AAllocator: IAllocator);
begin
  FLen := 0;
  FAllocator := AAllocator;
  FCap := AInitialCap;
  if FCap > 0 then
  begin
    if FAllocator <> nil then
      FBuf := FAllocator.GetMem(FCap)
    else
      GetMem(FBuf, FCap);
  end
  else
    FBuf := nil;
end;

procedure TBufStringBuilder.Done;
begin
  if FBuf <> nil then
  begin
    if FAllocator <> nil then
      FAllocator.FreeMem(FBuf)
    else
      FreeMem(FBuf);
    FBuf := nil;
  end;
  FLen := 0;
  FCap := 0;
  FAllocator := nil;
end;

procedure TBufStringBuilder.AppendByte(const AByte: Byte);
begin
  if FLen >= FCap then
    Grow(1);
  FBuf[FLen] := AnsiChar(AByte);
  Inc(FLen);
end;

procedure TBufStringBuilder.AppendChar(const ACh: AnsiChar);
begin
  if FLen >= FCap then
    Grow(1);
  FBuf[FLen] := ACh;
  Inc(FLen);
end;

procedure TBufStringBuilder.AppendChars(const ACh: AnsiChar; const ACount: SizeUInt);
begin
  if ACount = 0 then Exit;
  if FLen + ACount > FCap then
    Grow(ACount);
  FillChar(FBuf[FLen], ACount, Byte(ACh));
  Inc(FLen, ACount);
end;

procedure TBufStringBuilder.AppendView(const AView: TStringView);
begin
  if AView.Len = 0 then Exit;
  if AView.Data = nil then
    raise EInvalidArgument.Create('string builder view data is nil');
  if FLen + AView.Len > FCap then
    Grow(AView.Len);
  Move(AView.Data^, FBuf[FLen], AView.Len);
  Inc(FLen, AView.Len);
end;

procedure TBufStringBuilder.AppendStr(const AStr: string);
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

procedure TBufStringBuilder.AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt);
begin
  if ALen = 0 then Exit;
  if AData = nil then
    raise EInvalidArgument.Create('string builder byte source is nil');
  if FLen + ALen > FCap then
    Grow(ALen);
  Move(AData^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TBufStringBuilder.AppendInt(const AValue: Int64);
var
  LWritten: Int32;
begin
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := IntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendUInt(const AValue: UInt64);
var
  LWritten: Int32;
begin
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := UIntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendHex(const AValue: UInt64; const AMinDigits: Int32);
var
  LWritten: Int32;
begin
  if FLen + 16 > FCap then
    Grow(16);
  LWritten := IntToHexBuffer(AValue, FBuf + FLen, AMinDigits);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendBool(const AValue: Boolean);
begin
  if AValue then
    AppendBytes('true', 4)
  else
    AppendBytes('false', 5);
end;

procedure TBufStringBuilder.AppendFloat(const AValue: Double);
var
  LWritten: Int32;
begin
  if FLen + 25 > FCap then
    Grow(25);
  LWritten := FloatToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

function TBufStringBuilder.AsView: TStringView;
begin
  Result := TStringView.Create(FBuf, FLen);
end;

function TBufStringBuilder.ToString: string;
begin
  if FLen = 0 then
    Result := ''
  else
    SetString(Result, FBuf, FLen);
end;

function TBufStringBuilder.Len: SizeUInt;
begin
  Result := FLen;
end;

function TBufStringBuilder.Cap: SizeUInt;
begin
  Result := FCap;
end;

function TBufStringBuilder.Tail: PAnsiChar;
begin
  if FBuf = nil then
    Result := nil
  else
    Result := FBuf + FLen;
end;

procedure TBufStringBuilder.AdvanceLen(const ACount: SizeUInt);
begin
  if ACount > FCap - FLen then
    raise EInvalidArgument.Create('string builder advance exceeds capacity');
  Inc(FLen, ACount);
end;

procedure TBufStringBuilder.Clear;
begin
  FLen := 0;
end;

procedure TBufStringBuilder.Reserve(const AAdditional: SizeUInt);
begin
  if FLen + AAdditional > FCap then
    Grow(AAdditional);
end;

end.
