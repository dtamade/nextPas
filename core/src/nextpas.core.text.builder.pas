unit nextpas.core.text.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  IStringBuilder = interface
    ['{0F3C5C09-6A06-4B65-A346-0E34A1A9F7F6}']
    procedure AppendChar(const ACh: AnsiChar);
    procedure AppendView(const AView: TStringView);
    procedure AppendStr(const AStr: string);
    procedure AppendInt(const AValue: Int64);
    procedure AppendUInt(const AValue: UInt64);
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1);
    procedure AppendBool(const AValue: Boolean); inline;
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
    procedure AppendChars(const ACh: AnsiChar; const ACount: SizeUInt); inline;
    procedure AppendView(const AView: TStringView); inline;
    procedure AppendStr(const AStr: string); inline;
    procedure AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt); inline;
    procedure AppendInt(const AValue: Int64);
    procedure AppendUInt(const AValue: UInt64);
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1);
    procedure AppendBool(const AValue: Boolean); inline;
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

{ Unified TBuf capacity estimate — single source via bytes.ops BuilderCap* (owner=bytes.ops, L1 text.builder re-export).
  Sinks dispersed `Length(A)+Length(B)+N` / `Join total+delim*(n-1)` hand estimates into one inline helper;
  growth itself already via BytesCalcGrowCap. inline zero-cost, overflow fail-closed. }
function TBufEstimateForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
function TBufEstimateForJoin(const ATotal, ACount, ADelimLen: SizeUInt): SizeUInt; inline;
function TBufEstimateWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt = 256): SizeUInt; inline;

function MakeStringBuilder(const AInitialCap: SizeUInt = 256): IStringBuilder;

implementation

uses
  { Avoid nextpas.core.mem facade (arena/pool graph; hangs / false cycles under stage0).
    Default path uses System heap; allocator path uses IAllocator only. }
  nextpas.core.base,
  nextpas.core.bytes.ops,
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
    procedure AppendBool(const AValue: Boolean); inline;
    procedure AppendFloat(const AValue: Double);
    function AsView: TStringView;
    function ToString: string; override;
    function Len: SizeUInt;
    function Cap: SizeUInt;
    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
  end;

function TBufEstimateForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.bytes.ops.BuilderCapForTwo(ALen1, ALen2);
end;

function TBufEstimateForJoin(const ATotal, ACount, ADelimLen: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.bytes.ops.BuilderCapForJoin(ATotal, ACount, ADelimLen);
end;

function TBufEstimateWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.bytes.ops.BuilderCapWithMin(AEstimate, AMin);
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
  // single source: reuse bytes.ops.BytesGrowCapacity (INV-2, amortized O(1) geometric, BYTES_BUILDER_MIN_GROW) — not inline per red-line 2 (while loop I-Cache); zero-copy capacity math, sized ReallocMemSized
  if ANeeded > High(SizeUInt) - FLen then
    raise EOverflow.Create('string builder capacity overflow');
  LRequired := FLen + ANeeded;
  LNewCap := nextpas.core.bytes.ops.BytesGrowCapacity(FCap, LRequired);
  { 接口面 sized 辅助（CA-016，owner decision 2026-08-10）：allocator<>nil
    委托 IAllocator 方法（分配器内部跟踪 size），nil 走 System 堆（RTL
    自跟踪）。与门面 ReallocMemOf 语义分层——不触碰 mem 门面 graph，
    满足 stage0 自举约束。 }
  FBuf := ReallocMemSized(FAllocator, FBuf, FCap, LNewCap);
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
    FBuf := System.GetMem(FCap)
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
      FBuf := System.GetMem(FCap);
  end
  else
    FBuf := nil;
end;

procedure TBufStringBuilder.Done;
begin
  if FBuf <> nil then
  begin
    { 与 Grow 的 ReallocMemSized 配对的接口面释放（CA-016）：allocator≠nil
      委托接口方法，nil 走 nextpas.core.system.heap 封装。 }
    FreeMemSized(FAllocator, FBuf);
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

procedure TBufStringBuilder.AppendChars(const ACh: AnsiChar; const ACount: SizeUInt); inline;
begin
  if ACount = 0 then Exit;
  if FLen + ACount > FCap then
    Grow(ACount);
  // perf: single source Fill via bytes.ops (BytesZero for 0, SpanFill for arbitrary) inline zero-copy, no raw FillChar — L1 single source, red-line 1/2
  if Byte(ACh) = 0 then
    nextpas.core.bytes.ops.BytesZero(FBuf + FLen, ACount)
  else
    nextpas.core.bytes.ops.SpanFill(TByteSpan.Create(PByte(FBuf + FLen), ACount), Byte(ACh));
  Inc(FLen, ACount);
end;

procedure TBufStringBuilder.AppendView(const AView: TStringView); inline;
begin
  if AView.Len = 0 then Exit;
  if AView.Data = nil then
    raise EInvalidArgument.Create('string builder view data is nil');
  if FLen + AView.Len > FCap then
    Grow(AView.Len);
  // perf: zero-copy single Move via bytes.ops.BytesCopy inline single source (L1 单源, red-line 1/2), no raw Move, inline hot path
  nextpas.core.bytes.ops.BytesCopy(FBuf + FLen, AView.Data, AView.Len);
  Inc(FLen, AView.Len);
end;

procedure TBufStringBuilder.AppendStr(const AStr: string); inline;
var
  L: SizeUInt;
begin
  L := SizeUInt(Length(AStr));
  if L = 0 then Exit;
  if FLen + L > FCap then
    Grow(L);
  // perf: zero-copy single Move via bytes.ops.BytesCopy inline single source (L1 单源, red-line 1/2), no raw Move, inline hot path
  nextpas.core.bytes.ops.BytesCopy(FBuf + FLen, PAnsiChar(AStr), L);
  Inc(FLen, L);
end;

procedure TBufStringBuilder.AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt); inline;
begin
  if ALen = 0 then Exit;
  if AData = nil then
    raise EInvalidArgument.Create('string builder byte source is nil');
  if FLen + ALen > FCap then
    Grow(ALen);
  // perf: zero-copy single Move via bytes.ops.BytesCopy inline single source (L1 单源, red-line 1/2), no raw Move, inline hot path
  nextpas.core.bytes.ops.BytesCopy(FBuf + FLen, AData, ALen);
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
