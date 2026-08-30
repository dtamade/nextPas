unit nextpas.core.webview.bridge;

{** @desc 桥协议 v1 唯一实现（后端无关）：js→native invoke 帧解码、
       native→js 回执/事件 Eval 脚本构造、错误码稳定词汇表与注入脚本常量。
       各后端只是 transport；本单元不感知引擎差异。

       硬规则（BRIDGE_PROTOCOL §6）：
       - JSON 解析/序列化一律经 json owner，本单元禁止手写字符串扫描；
       - 禁止 uses 任何后端/factory 单元，只认识 base 的常量与异常族；
       - 错误码是跨语言契约，改动 = 破坏性变更，需升协议版本。

       回执参数形态：__resolve/__reject/__emit 的 JSON 参数以"JSON 文本
       字符串"嵌入 Eval 脚本，JS 侧 JSON.parse 后兑现——与 §3.2 一致，
       且避免把业务 JSON 直接拼进脚本文本。 }

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.json.types,
  nextpas.core.webview.base,
  nextpas.core.webview.intf;

const
  { 错误码稳定词汇表（BRIDGE_PROTOCOL §5） }
  NPW_CODE_HANDLER_MISSING = 'npw.handler_missing';
  NPW_CODE_HANDLER_ERROR = 'npw.handler_error';
  NPW_CODE_BAD_REQUEST = 'npw.bad_request';
  NPW_CODE_CLOSED = 'npw.closed';
  NPW_CODE_EVAL_FAILED = 'npw.eval_failed';

  { JS 分配帧 id 的上界：u53 安全整数（Number.MAX_SAFE_INTEGER） }
  NPW_MAX_FRAME_ID = 9007199254740991;

type
  { js→native invoke 帧（§3.1）。payload 以规范化重序列化文本携带；
    缺省或显式 null 统一为 'null'。 }
  TWebviewFrame = record
    Id: Int64;
    Cmd: string;
    PayloadJson: string;
  end;

{ 解码并校验 invoke 帧（§3.1 非法判据全表）。非法返回 False 不抛异常：
  生产路径由 transport 静默忽略；fake 驱动面据此抛 EWebviewBadFrame。
  payload 经 json owner 规范化重序列化（值语义不变，文本可能换格式）。 }
function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean;

{ 回执/事件 Eval 脚本构造（§3.2/§3.3）。AResultJson/APayloadJson 必须是
  合法 JSON 文本（空串按 'null'）；ACode/AMessage/AEvent 为普通文本，
  内部经 json owner 转义为 JS 字符串字面量。 }
function BuildResolveScript(AId: Int64; const AResultJson: string): string;
function BuildRejectScript(AId: Int64; const ACode, AMessage: string): string;
function BuildEmitScript(const AEvent, APayloadJson: string): string;

{ handler 错误码归一化：EWebviewInvokeError 空 Code 补默认 npw.bad_request，
  非空（含 app.* 自定义码）原样透传（§5 规则）。 }
function NormalizeInvokeCode(const ACode: string): string; inline;

type
  {** invoke handler 注册表唯一实现：六形态注册统一归一为 reference 形态
      存储（design-conventions §8 范式），直接实现 IWebviewInvokeRegistry；
      fake 与 gtk 后端共用同一实例语义。命名空间校验委托 base.CheckInvokeCmd；
      重复 cmd 抛 EWebviewInvalidState；Unregister 对未注册 cmd 静默。
      非线程安全——只允许 UI 主线程触碰（与窗口壳同线程）。 *}
  TWebviewInvokeRegistry = class(TInterfacedObject, IWebviewInvokeRegistry)
  private type
    TEntry = record
      Cmd: string;
      IsAsync: Boolean;
      SyncHandler: TWebviewInvokeSyncHandler;
      AsyncHandler: TWebviewInvokeAsyncHandler;
    end;
  private
    FEntries: array of TEntry;
    FEntriesCount: Integer;
    FHash: array of Integer;
    FHashMask: Integer;
    procedure GrowEntries; inline;
    function HashOf(const S: string): UInt64; inline;
    procedure RebuildHash;
    procedure InsertHashEntry(const ACmd: string; AIdx: Integer);
    function IndexOf(const ACmd: string): Integer; inline;
    procedure AddEntry(const ACmd: string; AIsAsync: Boolean;
      const ASync: TWebviewInvokeSyncHandler;
      const AAsync: TWebviewInvokeAsyncHandler);
  public
    { IWebviewInvokeRegistry }
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler); overload;
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncMethod); overload;
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncProc); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncMethod); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncProc); overload;
    procedure Unregister(const ACmd: string);
    { 分发面：False = 未注册；按 IsAsync 选择形态调用 }
    function Find(const ACmd: string; out AIsAsync: Boolean;
      out ASync: TWebviewInvokeSyncHandler;
      out AAsync: TWebviewInvokeAsyncHandler): Boolean; inline;
    function Count: Integer; inline;
  end;

  {** 嵌入式资产存储唯一实现：prefix 前缀路由到 provider 链，最长前缀
      优先；TryResolve 未命中返回 False（404 正常业务路径）。
      MountDirectory 需要文件系统 owner 支撑，W1 显式不支持（抛
      ENotSupportedError），落位时由 fs owner 接管实现。 *}
  TWebviewAssetsImpl = class(TInterfacedObject, IWebviewAssets)
  private type
    TMount = record
      Prefix: string;
      Provider: IWebviewAssetProvider;
    end;
  private
    FMounts: array of TMount;
    FMountsCount: Integer;
    FInert: Boolean;
    FMountHash: array of Integer;
    FMountHashMask: Integer;
    procedure GrowMounts; inline;
    function MountHashOf(const S: string): UInt64; inline;
    procedure RebuildMountHash;
    function FindMountByPrefix(const APrefix: string): Integer;
  public
    constructor Create(AInert: Boolean = False);
    procedure MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider);
    procedure MountDirectory(const APrefix, ARootDir: string);
    function TryResolve(const ASchemeRelativePath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    function MountCount: Integer; inline;
  end;

var
  { 注入脚本（§2）：document-start 主帧注入，每次导航重注。
    单份脚本服务全部后端——transport 在脚本内探测：
    WebKitGTK/WK 共用 window.webkit.messageHandlers.npw，
    WebView2 用 window.chrome.webview，均投递字符串化帧。
    公开面为 window.__npw 的 version/ready/invoke/listen/emit；
    内部面 __resolve/__reject/__emit 由 native 经 Eval 调用；
    ready promise 于脚本尾部兑现（§4 握手时序）。
    单源：JS 侧 id 上界取 NPW_MAX_FRAME_ID 常量，避免双处硬编码漂移。 }
  NPW_BRIDGE_SCRIPT: string;

implementation

uses
  nextpas.core.hash.wyhash,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.mem.default;

{ 把任意文本转成 JS 字符串字面量：JSON 字符串转义集是 JS 的子集
  （引号/反斜杠/控制字符），直接复用 json writer 的 Str 编码。
  使用栈上 TStringBuilder 零堆分配快路径（小字符串内联缓冲）。 }
function JsStringLit(const AValue: string): string; inline;
var
  LB: TStringBuilder;
  W: TJsonWriter;
begin
  LB.Init(SizeUInt(Length(AValue)) + 32);
  try
    W.Init(LB);
    W.Str(PAnsiChar(AValue), SizeUInt(Length(AValue)));
    Result := LB.ToString;
  finally
    LB.Done;
  end;
end;

var
  GDecodeDoc: TJsonDocument;
  GDecodeDocInited: Boolean = False;

procedure EnsureDecodeDoc;
begin
  if not GDecodeDocInited then
  begin
    GDecodeDoc.Init(DefaultAllocator);
    GDecodeDocInited := True;
  end;
end;

function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean;
var
  LDocPtr: ^TJsonDocument;
  LRoot, LField: TJsonValue;
  LPayloadIdx: UInt32;
  LB: TStringBuilder;
  W: TJsonWriter;

  procedure WriteNode(AIdx: UInt32);
  var
    LNode, LKeyNode: PJsonNode;
    LChild, LValIdx: UInt32;
    I: UInt32;
  begin
    if AIdx = JSON_NODE_NONE then
    begin
      W.Null;
      Exit;
    end;
    LNode := LDocPtr^.Node(AIdx);
    case LNode^.Kind of
      jnkNull: W.Null;
      jnkBool: W.Bool(LNode^.BoolVal);
      jnkInt: W.Int(LNode^.IntVal);
      jnkReal: W.Float(LNode^.RealVal);
      jnkString:
        if (LNode^.Flags and JNF_CLEAN_STR) <> 0 then
          W.StrClean(LNode^.Str.Data, LNode^.Str.Len)
        else
          W.Str(LNode^.Str);
      jnkArray:
        begin
          W.BeginArray;
          LChild := LNode^.Container.FirstChild;
          for I := 0 to LNode^.Container.Count - 1 do
          begin
            if LChild = JSON_NODE_NONE then Break;
            WriteNode(LChild);
            LChild := LDocPtr^.Node(LChild)^.Next;
          end;
          W.EndArray;
        end;
      jnkObject:
        begin
          W.BeginObject;
          LChild := LNode^.Container.FirstChild;
          for I := 0 to LNode^.Container.Count - 1 do
          begin
            if LChild = JSON_NODE_NONE then Break;
            LKeyNode := LDocPtr^.Node(LChild);
            if (LKeyNode^.Flags and JNF_CLEAN_STR) <> 0 then
              W.KeyClean(LKeyNode^.Str.Data, LKeyNode^.Str.Len)
            else
              W.Key(LKeyNode^.Str);
            LValIdx := LKeyNode^.Next;
            WriteNode(LValIdx);
            if LValIdx <> JSON_NODE_NONE then
              LChild := LDocPtr^.Node(LValIdx)^.Next
            else
              LChild := JSON_NODE_NONE;
          end;
          W.EndObject;
        end;
    end;
  end;

begin
  Result := False;
  AFrame := Default(TWebviewFrame);
  if (AFrameJson = '') or (Length(AFrameJson) > 2 * 1024 * 1024) then
    Exit;
  EnsureDecodeDoc;
  LDocPtr := @GDecodeDoc;
  if not LDocPtr^.Parse(TStringView.FromStr(AFrameJson)) then
    Exit;
  if LDocPtr^.HasError then
    Exit;
  LRoot := TJsonValue.Create(LDocPtr^, LDocPtr^.Root);
  if not LRoot.IsObject then
    Exit;
  LField := LRoot.Get('v');
  if not LField.IsInt then
    Exit;
  if LField.AsInt <> NPW_BRIDGE_VERSION then
    Exit;
  LField := LRoot.Get('id');
  if not LField.IsInt then
    Exit;
  AFrame.Id := LField.AsInt;
  if (AFrame.Id <= 0) or (AFrame.Id > NPW_MAX_FRAME_ID) then
    Exit;
  LField := LRoot.Get('cmd');
  if not LField.IsStr then
    Exit;
  AFrame.Cmd := LField.AsStr.ToString;
  if AFrame.Cmd = '' then
    Exit;
  LField := LRoot.Get('payload');
  if LField.IsNull or (LField.FIdx = JSON_NODE_NONE) then
    AFrame.PayloadJson := 'null'
  else
  begin
    LPayloadIdx := LField.FIdx;
    LB.Init(256);
    try
      W.Init(LB);
      WriteNode(LPayloadIdx);
      AFrame.PayloadJson := LB.ToString;
    finally
      LB.Done;
    end;
  end;
  Result := True;
end;

function BuildResolveScript(AId: Int64; const AResultJson: string): string;
var
  LJson: string;
begin
  LJson := AResultJson;
  if LJson = '' then
    LJson := 'null';
  Result := '__npw.__resolve(' + IntToStr(AId) + ',' +
    JsStringLit(LJson) + ')';
end;

function BuildRejectScript(AId: Int64; const ACode, AMessage: string): string;
var
  LB: TStringBuilder;
  W: TJsonWriter;
  LJson: string;
begin
  LB.Init(128);
  try
    W.Init(LB);
    W.BeginObject;
    W.Key('code');
    W.Str(NormalizeInvokeCode(ACode));
    W.Key('message');
    W.Str(AMessage);
    W.EndObject;
    LJson := LB.ToString;
  finally
    LB.Done;
  end;
  Result := '__npw.__reject(' + IntToStr(AId) + ',' +
    JsStringLit(LJson) + ')';
end;

function BuildEmitScript(const AEvent, APayloadJson: string): string;
var
  LJson: string;
begin
  CheckWebviewEventName(AEvent);
  LJson := APayloadJson;
  if LJson = '' then
    LJson := 'null';
  Result := '__npw.__emit(' + JsStringLit(AEvent) + ',' +
    JsStringLit(LJson) + ')';
end;

function NormalizeInvokeCode(const ACode: string): string; inline;
begin
  if ACode = '' then
    Result := NPW_CODE_BAD_REQUEST
  else
    Result := ACode;
end;

{ ---- TWebviewInvokeRegistry：六形态归一 + 命名空间校验 ---- }

const
  INVOKE_HASH_THRESHOLD = 16; { S98: 8→16 降低小表哈希未命中，保持 n≤16 线性快路径优势 }

function TWebviewInvokeRegistry.HashOf(const S: string): UInt64; inline;
begin
  if Length(S) = 0 then
    Result := 0
  else
    Result := WyHash(@S[1], SizeUInt(Length(S)), 0);
end;

procedure TWebviewInvokeRegistry.RebuildHash;
var
  LCap, I, LPos: Integer;
  H: UInt64;
begin
  if FEntriesCount <= INVOKE_HASH_THRESHOLD then
  begin
    SetLength(FHash, 0);
    FHashMask := 0;
    Exit;
  end;
  LCap := 16;
  while LCap < FEntriesCount * 2 do
    LCap := LCap * 2;
  SetLength(FHash, LCap);
  FHashMask := LCap - 1;
  for I := 0 to LCap - 1 do
    FHash[I] := -1;
  for I := 0 to FEntriesCount - 1 do
  begin
    H := HashOf(FEntries[I].Cmd);
    LPos := Integer(H and UInt64(FHashMask));
    while FHash[LPos] <> -1 do
      LPos := (LPos + 1) and FHashMask;
    FHash[LPos] := I;
  end;
end;

procedure TWebviewInvokeRegistry.InsertHashEntry(const ACmd: string; AIdx: Integer);
var
  LPos: Integer;
  H: UInt64;
begin
  if FHashMask = 0 then
    Exit;
  if (FEntriesCount * 2 > Length(FHash)) then
  begin
    RebuildHash;
    Exit;
  end;
  H := HashOf(ACmd);
  LPos := Integer(H and UInt64(FHashMask));
  while FHash[LPos] <> -1 do
    LPos := (LPos + 1) and FHashMask;
  FHash[LPos] := AIdx;
end;

procedure TWebviewInvokeRegistry.GrowEntries; inline;
begin
  Assert(FEntriesCount >= 0, 'GrowEntries count');
  if FEntriesCount = Length(FEntries) then
    SetLength(FEntries, WebviewGrowCapacity(Length(FEntries)));
end;

function TWebviewInvokeRegistry.IndexOf(const ACmd: string): Integer; inline;
var
  I: Integer;
  H: UInt64;
  LPos, LStart, LIdx: Integer;
begin
  if (FEntriesCount <= INVOKE_HASH_THRESHOLD) or (FHashMask = 0) then
  begin
    for I := 0 to FEntriesCount - 1 do
      if FEntries[I].Cmd = ACmd then
        Exit(I);
    Exit(-1);
  end;
  H := HashOf(ACmd);
  LPos := Integer(H and UInt64(FHashMask));
  LStart := LPos;
  repeat
    LIdx := FHash[LPos];
    if LIdx = -1 then
      Exit(-1);
    if (LIdx >= 0) and (LIdx < FEntriesCount) and (FEntries[LIdx].Cmd = ACmd) then
      Exit(LIdx);
    LPos := (LPos + 1) and FHashMask;
  until LPos = LStart;
  Result := -1;
end;

procedure TWebviewInvokeRegistry.AddEntry(const ACmd: string;
  AIsAsync: Boolean; const ASync: TWebviewInvokeSyncHandler;
  const AAsync: TWebviewInvokeAsyncHandler);
var
  LWasThreshold: Boolean;
begin
  CheckInvokeCmd(ACmd);
  if IndexOf(ACmd) >= 0 then
    raise EWebviewInvalidState.CreateFmt(
      'invoke handler already registered: %s', [ACmd]);
  LWasThreshold := FEntriesCount = INVOKE_HASH_THRESHOLD;
  GrowEntries;
  FEntries[FEntriesCount].Cmd := ACmd;
  FEntries[FEntriesCount].IsAsync := AIsAsync;
  FEntries[FEntriesCount].SyncHandler := ASync;
  FEntries[FEntriesCount].AsyncHandler := AAsync;
  Inc(FEntriesCount);
  if FEntriesCount > INVOKE_HASH_THRESHOLD then
  begin
    if LWasThreshold then
      RebuildHash
    else
      InsertHashEntry(ACmd, FEntriesCount - 1);
  end;
end;

procedure TWebviewInvokeRegistry.Register(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler);
begin
  AddEntry(ACmd, False, AHandler, nil);
end;

procedure TWebviewInvokeRegistry.Register(const ACmd: string;
  AHandler: TWebviewInvokeSyncMethod);
begin
  Register(ACmd,
    function(const APayloadJson: string): string
    begin
      Result := AHandler(APayloadJson);
    end);
end;

procedure TWebviewInvokeRegistry.Register(const ACmd: string;
  AHandler: TWebviewInvokeSyncProc);
begin
  Register(ACmd,
    function(const APayloadJson: string): string
    begin
      Result := AHandler(APayloadJson);
    end);
end;

procedure TWebviewInvokeRegistry.RegisterAsync(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler);
begin
  AddEntry(ACmd, True, nil, AHandler);
end;

procedure TWebviewInvokeRegistry.RegisterAsync(const ACmd: string;
  AHandler: TWebviewInvokeAsyncMethod);
begin
  RegisterAsync(ACmd,
    procedure(const APayloadJson: string;
      const ACompletion: IWebviewInvokeCompletion)
    begin
      AHandler(APayloadJson, ACompletion);
    end);
end;

procedure TWebviewInvokeRegistry.RegisterAsync(const ACmd: string;
  AHandler: TWebviewInvokeAsyncProc);
begin
  RegisterAsync(ACmd,
    procedure(const APayloadJson: string;
      const ACompletion: IWebviewInvokeCompletion)
    begin
      AHandler(APayloadJson, ACompletion);
    end);
end;

procedure TWebviewInvokeRegistry.Unregister(const ACmd: string);
var
  LIdx, I: Integer;
begin
  LIdx := IndexOf(ACmd);
  if LIdx < 0 then
    Exit;
  for I := LIdx to FEntriesCount - 2 do
    FEntries[I] := FEntries[I + 1];
  Dec(FEntriesCount);
  if FEntriesCount < Length(FEntries) then
    FEntries[FEntriesCount] := Default(TEntry);
  if FHashMask <> 0 then
    RebuildHash;
end;

function TWebviewInvokeRegistry.Count: Integer; inline;
begin
  Result := FEntriesCount;
end;

function TWebviewInvokeRegistry.Find(const ACmd: string; out AIsAsync: Boolean;
  out ASync: TWebviewInvokeSyncHandler;
  out AAsync: TWebviewInvokeAsyncHandler): Boolean; inline;
var
  LIdx: Integer;
begin
  LIdx := IndexOf(ACmd);
  Result := LIdx >= 0;
  if not Result then
    Exit(False);
  AIsAsync := FEntries[LIdx].IsAsync;
  ASync := FEntries[LIdx].SyncHandler;
  AAsync := FEntries[LIdx].AsyncHandler;
end;

{ ---- TWebviewAssetsImpl：前缀路由 + provider 链 ---- }

constructor TWebviewAssetsImpl.Create(AInert: Boolean);
begin
  inherited Create;
  FInert := AInert;
end;

procedure TWebviewAssetsImpl.GrowMounts; inline;
begin
  Assert(FMountsCount >= 0, 'GrowMounts count');
  if FMountsCount = Length(FMounts) then
    SetLength(FMounts, WebviewGrowCapacity(Length(FMounts)));
end;

function TWebviewAssetsImpl.MountHashOf(const S: string): UInt64; inline;
begin
  if Length(S) = 0 then
    Result := 1469598103934665603
  else
    Result := WyHash(@S[1], SizeUInt(Length(S)), 0);
end;

procedure TWebviewAssetsImpl.RebuildMountHash;
var
  LCap, I, LPos: Integer;
  H: UInt64;
begin
  if FMountsCount <= 1 then
  begin
    SetLength(FMountHash, 0);
    FMountHashMask := 0;
    Exit;
  end;
  LCap := 16;
  while LCap < FMountsCount * 2 do
    LCap := LCap * 2;
  SetLength(FMountHash, LCap);
  FMountHashMask := LCap - 1;
  for I := 0 to LCap - 1 do
    FMountHash[I] := -1;
  for I := 0 to FMountsCount - 1 do
  begin
    H := MountHashOf(FMounts[I].Prefix);
    LPos := Integer(H and UInt64(FMountHashMask));
    while FMountHash[LPos] <> -1 do
    begin
      if FMounts[FMountHash[LPos]].Prefix = FMounts[I].Prefix then
        Break;
      LPos := (LPos + 1) and FMountHashMask;
    end;
    if FMountHash[LPos] = -1 then
      FMountHash[LPos] := I;
  end;
end;

function TWebviewAssetsImpl.FindMountByPrefix(const APrefix: string): Integer; inline;
var
  H: UInt64;
  LPos, LStart, LIdx: Integer;
begin
  if FMountHashMask = 0 then
  begin
    for LIdx := 0 to FMountsCount - 1 do
      if FMounts[LIdx].Prefix = APrefix then
        Exit(LIdx);
    Exit(-1);
  end;
  H := MountHashOf(APrefix); { S101: hot inline probe }
  LPos := Integer(H and UInt64(FMountHashMask));
  LStart := LPos;
  repeat
    LIdx := FMountHash[LPos];
    if LIdx = -1 then
      Exit(-1);
    if FMounts[LIdx].Prefix = APrefix then
      Exit(LIdx);
    LPos := (LPos + 1) and FMountHashMask;
  until LPos = LStart;
  Result := -1;
end;

procedure TWebviewAssetsImpl.MountEmbedded(const APrefix: string;
  AProvider: IWebviewAssetProvider);
var
  LPos, I: Integer;
  LNormPrefix: string;
begin
  if FInert then
    Exit;
  if AProvider = nil then
    raise EWebviewInvalidState.Create('asset provider must not be nil');
  LNormPrefix := NormalizeWebviewAssetPath(APrefix);
  LPos := FMountsCount;
  for I := 0 to FMountsCount - 1 do
    if Length(LNormPrefix) > Length(FMounts[I].Prefix) then
    begin
      LPos := I;
      Break;
    end;
  GrowMounts;
  for I := FMountsCount downto LPos + 1 do
    FMounts[I] := FMounts[I - 1];
  FMounts[LPos].Prefix := LNormPrefix;
  FMounts[LPos].Provider := AProvider;
  Inc(FMountsCount);
  if FMountsCount > 1 then
    RebuildMountHash;
end;

procedure TWebviewAssetsImpl.MountDirectory(const APrefix, ARootDir: string);
begin
  if FInert then
    Exit;
  if (APrefix <> '') or (ARootDir <> '') then ;
  raise ENotSupportedError.Create('directory asset mounts are not supported yet');
end;

{$PUSH}{$WARN 5057 OFF}
function TWebviewAssetsImpl.TryResolve(const ASchemeRelativePath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  LPath: string;
  LIdx, LLow, LHigh, LMid, LBest: Integer;
  LLen: Integer;
  LSub: string;
  LDistinct: array[0..31] of Integer;
  LDistinctCount, K: Integer;
begin
  Result := False;
  ABytes := nil;
  AMimeType := '';
  if FInert then
    Exit;
  LPath := NormalizeWebviewAssetPath(ASchemeRelativePath);
  if LPath = '' then
    Exit;
  if FMountsCount = 1 then
    Exit(FMounts[0].Provider.TryResolve(LPath, ABytes, AMimeType));
  if FMountsCount = 0 then
    Exit(False);
  FillChar(LDistinct, SizeOf(LDistinct), 0);
  if FMountHashMask <> 0 then
  begin
    LDistinctCount := 0;
    for LIdx := 0 to FMountsCount - 1 do
    begin
      LLen := Length(FMounts[LIdx].Prefix);
      for K := 0 to LDistinctCount - 1 do
        if LDistinct[K] = LLen then
          Break;
      if K = LDistinctCount then
      begin
        if LDistinctCount < 32 then
        begin
          LDistinct[LDistinctCount] := LLen;
          Inc(LDistinctCount);
        end;
      end;
    end;
    for K := 0 to LDistinctCount - 1 do
      for LIdx := K + 1 to LDistinctCount - 1 do
        if LDistinct[LIdx] > LDistinct[K] then
        begin
          LLen := LDistinct[K];
          LDistinct[K] := LDistinct[LIdx];
          LDistinct[LIdx] := LLen;
        end;
    for K := 0 to LDistinctCount - 1 do
    begin
      LLen := LDistinct[K];
      if LLen = 0 then
      begin
        LIdx := FindMountByPrefix('');
        if LIdx >= 0 then
          Exit(FMounts[LIdx].Provider.TryResolve(LPath, ABytes, AMimeType));
        Continue;
      end;
      if LLen > Length(LPath) then
        Continue;
      LSub := Copy(LPath, 1, LLen);
      LIdx := FindMountByPrefix(LSub);
      if LIdx < 0 then
        Continue;
      if Pos(FMounts[LIdx].Prefix, LPath) = 1 then
        Exit(FMounts[LIdx].Provider.TryResolve(LPath, ABytes, AMimeType));
    end;
  end;
  LLen := Length(LPath);
  LLow := 0;
  LHigh := FMountsCount - 1;
  LBest := FMountsCount;
  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) shr 1;
    if Length(FMounts[LMid].Prefix) <= LLen then
    begin
      LBest := LMid;
      LHigh := LMid - 1;
    end
    else
      LLow := LMid + 1;
  end;
  if LBest = FMountsCount then
    Exit(False);
  for LIdx := LBest to FMountsCount - 1 do
    if (FMounts[LIdx].Prefix = '') or (Pos(FMounts[LIdx].Prefix, LPath) = 1) then
      Exit(FMounts[LIdx].Provider.TryResolve(LPath, ABytes, AMimeType));
  Result := False;
end;
{$POP}

function TWebviewAssetsImpl.MountCount: Integer; inline;
begin
  Result := FMountsCount;
end;

function BuildBridgeScript: string;
begin
  Result :=
    '(() => {'#10 +
    '  '#39'use strict'#39';'#10 +
    '  if (window.__npw) return;'#10 +
    '  const send = (() => {'#10 +
    '    const wk = window.webkit && window.webkit.messageHandlers &&'#10 +
    '              window.webkit.messageHandlers.npw;'#10 +
    '    if (wk) return (t) => wk.postMessage(t);'#10 +
    '    const wv = window.chrome && window.chrome.webview;'#10 +
    '    if (wv) return (t) => wv.postMessage(t);'#10 +
    '    return null;'#10 +
    '  })();'#10 +
    '  const post = (frame) => {'#10 +
    '    if (!send) throw new Error('#39'npw: no transport'#39');'#10 +
    '    send(JSON.stringify(frame));'#10 +
    '  };'#10 +
    '  const pending = new Map();'#10 +
    '  let nextId = 1;'#10 +
    '  const listeners = new Map();'#10 +
    '  const invoke = (cmd, payload) => {'#10 +
    '    if (typeof cmd !== '#39'string'#39' || cmd.length === 0)'#10 +
    '      return Promise.reject(new Error('#39'npw: cmd required'#39'));'#10 +
    '    if (nextId > ' + IntToStr(NPW_MAX_FRAME_ID) + ')'#10 +
    '      return Promise.reject(new Error('#39'npw: id space exhausted'#39'));'#10 +
    '    const id = nextId++;'#10 +
    '    post({ v: 1, id: id,' + #10 +
    '          cmd: cmd,' + #10 +
    '          payload: payload === undefined ? null : payload });'#10 +
    '    return new Promise((resolve, reject) => {'#10 +
    '      pending.set(id, { resolve: resolve, reject: reject });'#10 +
    '    });'#10 +
    '  };'#10 +
    '  const listen = (event, callback) => {'#10 +
    '    let set = listeners.get(event);'#10 +
    '    if (!set) { set = new Set(); listeners.set(event, set); }'#10 +
    '    set.add(callback);'#10 +
    '    return () => set.delete(callback);'#10 +
    '  };'#10 +
    '  const emitLocal = (event, payload) => {'#10 +
    '    const set = listeners.get(event);'#10 +
    '    if (!set) return;'#10 +
    '    set.forEach((cb) => { cb(payload); });'#10 +
    '  };'#10 +
    '  const settle = (id, text, ok) => {'#10 +
    '    const p = pending.get(id);'#10 +
    '    if (!p) return;'#10 +
    '    pending.delete(id);'#10 +
    '    const value = JSON.parse(text);'#10 +
    '    if (ok) p.resolve(value); else p.reject(value);'#10 +
    '  };'#10 +
    '  let fireReady;'#10 +
    '  const ready = new Promise((fire) => { fireReady = fire; });'#10 +
    '  window.__npw = {'#10 +
    '    version: 1,'#10 +
    '    ready: ready,'#10 +
    '    invoke: invoke,'#10 +
    '    listen: listen,'#10 +
    '    emit: emitLocal,'#10 +
    '    __resolve: (id, t) => settle(id, t, true),'#10 +
    '    __reject: (id, t) => settle(id, t, false),'#10 +
    '    __emit: (event, t) => emitLocal(event, JSON.parse(t))'#10 +
    '  };'#10 +
    '  Object.freeze(window.__npw);'#10 +
    '  fireReady();'#10 +
    '})();'#10;
end;

initialization
  NPW_BRIDGE_SCRIPT := BuildBridgeScript;
  EnsureDecodeDoc;

finalization
  if GDecodeDocInited then
  begin
    GDecodeDoc.Done;
    GDecodeDocInited := False;
  end;

end.
