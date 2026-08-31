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
    procedure AppendBool(const AValue: Boolean);
    procedure AppendFloat(const AValue: Double);
    function AsView: TStringView;
    function ToString: string;
    function Len: SizeUInt;
    function Cap: SizeUInt;
    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
    function Tail: PAnsiChar;
    procedure AdvanceLen(const ACount: SizeUInt);
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
    // perf: inline fast-path — FLen+Len <= FCap 时无 Grow 调用与分支溢出，仅 Move/Fill；
    // 批量小块追加前调用 Reserve(预估总量) 可批量储备、消除逐次 Grow 分支与拷贝。
    // 零拷贝路径：Tail 直接获写指针 + AdvanceLen 提交，避免中间 Move。
    procedure AppendChars(const ACh: AnsiChar; const ACount: SizeUInt); inline;
    procedure AppendView(const AView: TStringView); inline;
    procedure AppendStr(const AStr: string); inline;
    procedure AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt); inline;
    procedure AppendInt(const AValue: Int64); inline;
    procedure AppendUInt(const AValue: UInt64); inline;
    procedure AppendHex(const AValue: UInt64; const AMinDigits: Int32 = 1); inline;
    procedure AppendBool(const AValue: Boolean); inline;
    procedure AppendFloat(const AValue: Double); inline;

    function AsView: TStringView; inline;
    function ToString: string;
    function Len: SizeUInt; inline;
    function Cap: SizeUInt; inline;
    // perf: Tail/AdvanceLen 零拷贝直写（获取尾指针后外部填充，再 AdvanceLen 提交）
    function Tail: PAnsiChar; inline;
    procedure AdvanceLen(const ACount: SizeUInt); inline;
    procedure Clear; inline;
    // perf: 批量储备 — 调用方估算总量后 Reserve 一次，后续小块 Append 均走 inline 快路径无分支
    procedure Reserve(const AAdditional: SizeUInt); inline;
  end;

  { Compatibility alias for internal callers that still use TStringBuilder
    directly. Public facade users should prefer IStringBuilder. }
  TStringBuilder = TBufStringBuilder;

function MakeStringBuilder(const AInitialCap: SizeUInt = 256): IStringBuilder;

implementation

uses
  { Avoid nextpas.core.mem facade (arena/pool graph; hangs / false cycles under stage0).
    Default path uses System heap; allocator path uses IAllocator only. }
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
    function Tail: PAnsiChar;
    procedure AdvanceLen(const ACount: SizeUInt);
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

function TStringBuilderImpl.Tail: PAnsiChar;
begin
  Result := FBuilder.Tail;
end;

procedure TStringBuilderImpl.AdvanceLen(const ACount: SizeUInt);
begin
  FBuilder.AdvanceLen(ACount);
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
  // inline fast-path: capacity sufficient → no Grow branch; FillChar bulk
  if ACount = 0 then Exit;
  if FLen + ACount > FCap then
    Grow(ACount);
  FillChar(FBuf[FLen], ACount, Byte(ACh));
  Inc(FLen, ACount);
end;

procedure TBufStringBuilder.AppendView(const AView: TStringView); inline;
begin
  // inline + Reserve 批量：预留后此分支恒 false，单次 Grow 后多次 Move 无额外分支/拷贝
  if AView.Len = 0 then Exit;
  if AView.Data = nil then
    raise EInvalidArgument.Create('string builder view data is nil');
  if FLen + AView.Len > FCap then
    Grow(AView.Len);
  Move(AView.Data^, FBuf[FLen], AView.Len);
  Inc(FLen, AView.Len);
end;

procedure TBufStringBuilder.AppendStr(const AStr: string); inline;
var
  L: SizeUInt;
begin
  // inline fast-path, Move 一次拷贝；小块循环前 Reserve(LTotal) 可消除逐次 Grow
  L := SizeUInt(Length(AStr));
  if L = 0 then Exit;
  if FLen + L > FCap then
    Grow(L);
  Move(PAnsiChar(AStr)^, FBuf[FLen], L);
  Inc(FLen, L);
end;

procedure TBufStringBuilder.AppendBytes(const AData: PAnsiChar; const ALen: SizeUInt); inline;
begin
  // inline 单次 Move；与 bytes.ops 同源语义（零重复实现，L1 横向不依赖，仅语义一致）
  if ALen = 0 then Exit;
  if AData = nil then
    raise EInvalidArgument.Create('string builder byte source is nil');
  if FLen + ALen > FCap then
    Grow(ALen);
  Move(AData^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TBufStringBuilder.AppendInt(const AValue: Int64); inline;
var
  LWritten: Int32;
begin
  // inline: 预留 21 字节快路径，IntToBuffer 零分配直写
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := IntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendUInt(const AValue: UInt64); inline;
var
  LWritten: Int32;
begin
  // inline: 21 字节上界，UIntToBuffer 直写尾部
  if FLen + 21 > FCap then
    Grow(21);
  LWritten := UIntToBuffer(AValue, FBuf + FLen);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendHex(const AValue: UInt64; const AMinDigits: Int32); inline;
var
  LWritten: Int32;
begin
  // inline: 16 字节上界
  if FLen + 16 > FCap then
    Grow(16);
  LWritten := IntToHexBuffer(AValue, FBuf + FLen, AMinDigits);
  Inc(FLen, SizeUInt(LWritten));
end;

procedure TBufStringBuilder.AppendBool(const AValue: Boolean); inline;
begin
  // inline 委托 AppendBytes 单次 Move（已 inline）
  if AValue then
    AppendBytes('true', 4)
  else
    AppendBytes('false', 5);
end;

procedure TBufStringBuilder.AppendFloat(const AValue: Double); inline;
var
  LWritten: Int32;
begin
  // inline: 25 字节上界（Ryu），FloatToBuffer 直写
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

procedure TBufStringBuilder.Reserve(const AAdditional: SizeUInt); inline;
begin
  // 批量储备入口：循环前 Reserve(总量) 后续 Append* 均命中 inline 快路径
  if FLen + AAdditional > FCap then
    Grow(AAdditional);
end;

end.
