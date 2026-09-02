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
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.assets,
  nextpas.core.webview.utils,
  nextpas.core.text.view,
  nextpas.core.collections.hashmap,
  nextpas.core.log.intf;

const
  { 错误码稳定词汇表（BRIDGE_PROTOCOL §5） }
  NPW_CODE_HANDLER_MISSING = 'npw.handler_missing';
  NPW_CODE_HANDLER_ERROR = 'npw.handler_error';
  NPW_CODE_BAD_REQUEST = 'npw.bad_request';
  NPW_CODE_CLOSED = 'npw.closed';
  NPW_CODE_TIMEOUT = 'npw.timeout';
  NPW_CODE_EVAL_FAILED = 'npw.eval_failed';

  { JS 分配帧 id 的上界：u53 安全整数（Number.MAX_SAFE_INTEGER） }
  NPW_MAX_FRAME_ID = 9007199254740991;

  { 帧长上限：BRIDGE_PROTOCOL §6 业务建议 1 MiB Hard Limit，统一命名常量。
    复用 bytes.ops 单源思想：常量即契约，避免魔法数字漂移；与文档 §6 一致。 }
  NPW_MAX_FRAME_BYTES = 1 * 1024 * 1024;

type
  { js→native invoke 帧（§3.1）。payload 以规范化重序列化文本携带；
    缺省或显式 null 统一为 'null'。 }
  TWebviewFrame = record
    Id: Int64;
    Cmd: string;
    PayloadJson: string;
  end;

{ 帧超限判定与计数（Owner: webview.metrics，UI 线程亲和）。 }
function IsWebviewFrameOversized(const AFrameJson: string): Boolean; inline;
function IsWebviewFrameOversizedView(const AView: TStringView): Boolean; inline;
{ 背压计数（Owner: webview.metrics）。 }
function WebviewOversizedCount: UInt64; inline;
procedure WebviewResetOversizedCount; inline;
procedure WebviewNoteOversized(ASize: SizeUInt); inline;
{ deprecated no-op：L3 不再持有 log.intf 全局原子指针，caller 自持 ILogger 生命周期，test 隔离零成本；保留签名兼容旧调用。 }
procedure SetWebviewBridgeLogger(ALogger: ILogger); deprecated 'bridge no longer holds global logger; caller owns logger';

{ TryDecodeFrame: §3.1 parse→validate→normalize; False on invalid. }
function TryDecodeFrame(const AView: TStringView;
  out AFrame: TWebviewFrame): Boolean; overload;
function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean; overload; inline;

{ 回执/事件 Eval 脚本构造（§3.2/§3.3）。AResultJson/APayloadJson 须为合法 JSON（空串按 'null'）；ACode/AMessage/AEvent 为普通文本，经 json owner 转义。 }
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
      非线程安全——只允许 UI 主线程触碰（与窗口壳同线程）。
      容器单源：委托 L1 collections.hashmap 通用开放寻址（WyHash/HashMix32/
      NextPow2/0.75 负载/Bitmap 单源），消除私有桶/Rehash/FindSlot 分叉；
      资产索引最长前缀由 L2 prefixrouter Trie 单源承载（见 assets.pas）。 *}
  TWebviewInvokeRegistry = class(TInterfacedObject, IWebviewInvokeRegistry)
  private type
    TInvokeEntry = record
      IsAsync: Boolean;
      SyncHandler: TWebviewInvokeSyncHandler;
      AsyncHandler: TWebviewInvokeAsyncHandler;
    end;
  private
    FMap: specialize THashMap<string, TInvokeEntry>;
    procedure AddEntry(const ACmd: string; AIsAsync: Boolean;
      const ASync: TWebviewInvokeSyncHandler;
      const AAsync: TWebviewInvokeAsyncHandler);
  public
    constructor Create;
    destructor Destroy; override;
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
      out AAsync: TWebviewInvokeAsyncHandler): Boolean;
    function Count: Integer; inline;
  end;

  {** 嵌入式资产存储唯一实现：prefix 前缀路由到 provider 链，最长前缀
      优先；TryResolve 未命中返回 False（404 正常业务路径）。
      MountDirectory 需要文件系统 owner 支撑，W1 显式不支持抛
      ENotSupportedError(ecNotSupported)（CONTRACT §3.4，门禁
      test_webview_bridge 断言异常分类/消息可观测），落位时由 fs owner
      接管实现。契约可观测性：异常类/分类/消息文本为稳定契约。 *}
  {** 资产路由索引已抽独立模块 TWebviewAssetIndex（L3 单哈希+Trie 单源），
      桥侧仅持单实例，零 DistinctLens 双轨；MountCount/最长前缀 O(m) 由 Trie 单源承载。 *}
  TWebviewAssetsImpl = class(TInterfacedObject, IWebviewAssets)
  private
    FInert: Boolean;   { DevServerUrl 开发模式：挂载 no-op、解析一律 404 }
    FIndex: TWebviewAssetIndex;
  public
    constructor Create(AInert: Boolean = False);
    destructor Destroy; override;
    procedure MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider);
    { CONTRACT §3.4：非惰性下抛 ENotSupportedError(ecNotSupported)，
      消息含 'directory asset mounts are not supported yet' }
    procedure MountDirectory(const APrefix, ARootDir: string);
    function TryResolve(const ASchemeRelativePath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    function TryResolveView(const AView: TStringView;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    function MountCount: Integer; inline;
  end;

const
  { 注入脚本（§2）：document-start 主帧注入，每次导航重注。
    单份脚本服务全部后端——transport 在脚本内探测：
    WebKitGTK/WK 共用 window.webkit.messageHandlers.npw，
    WebView2 用 window.chrome.webview，均投递字符串化帧。
    公开面为 window.__npw 的 version/ready/invoke/listen/emit；
    内部面 __resolve/__reject/__emit 由 native 经 Eval 调用；
    ready promise 于脚本尾部兑现（§4 握手时序）。
    独立资源：真值在 nextpas.core.webview.bridge.js，Pascal 侧经
    nextpas.core.webview.bridge.script.inc 生成，单源可维护；
    hygiene 视其为意向跟踪生成源非构建产物（design-conventions.md §1
    generated vs hand-written），校验见 BRIDGE_PROTOCOL §2 与
    core/tests/nextpas.core.webview/contracts/check_webview_contracts.sh。 }
  NPW_BRIDGE_SCRIPT: string =
{$I nextpas.core.webview.bridge.script.inc}
    ;

implementation

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.text.escape,
  nextpas.core.json.parser,
  nextpas.core.json.writer,
  nextpas.core.bytes.ops,
  nextpas.core.hash.wyhash,
  nextpas.core.collections.hashmap.base,
  nextpas.core.webview.base,
  nextpas.core.webview.validation,
  nextpas.core.webview.utils,
  nextpas.core.webview.metrics;

{ JsStringLit: JSON Str subset via json owner. }
function JsStringLit(const AValue: string): string; inline;
var
  LB: TStringBuilder;
  W: TJsonWriter;
begin
  LB.Init(SizeUInt(Length(AValue)) + 8);
  try
    W.Init(LB);
    W.Str(AValue);
    Result := LB.ToString;
  finally
    LB.Done;
  end;
end;

function IsWebviewFrameOversized(const AFrameJson: string): Boolean; inline;
begin
  Result := IsWebviewFrameOversizedView(TStringView.FromStr(AFrameJson));
end;

function IsWebviewFrameOversizedView(const AView: TStringView): Boolean; inline;
begin
  Result := AView.Len > SizeUInt(NPW_MAX_FRAME_BYTES);
end;

function WebviewOversizedCount: UInt64; inline;
begin
  Result := WebviewMetricsOversizedCount;
end;

procedure WebviewResetOversizedCount; inline;
begin
  WebviewMetricsResetOversizedCount;
end;

procedure WebviewNoteOversized(ASize: SizeUInt); inline;
begin
  WebviewMetricsNoteOversized(ASize);
end;

{$PUSH}{$WARN 5024 OFF}
procedure SetWebviewBridgeLogger(ALogger: ILogger);
begin
  { deprecated no-op: global logger removed, caller owns ILogger; empty body彻底移除空分支噪音，零额外调用 }
end;
{$POP}

{ Parse→Validate→Normalize: three-layer split, zero-copy View, single builder Move. }

function BridgeParseFrame(const AView: TStringView; var ADoc: TJsonDocument;
  out ARoot: TJsonValue): Boolean; inline;
begin
  Result := False;
  if AView.Len = 0 then
    Exit;
  if IsWebviewFrameOversizedView(AView) then
  begin
    WebviewNoteOversized(AView.Len);
    Exit;
  end;
  if not ADoc.Parse(AView) then
    Exit;
  if ADoc.HasError then
    Exit;
  ARoot := TJsonValue.Create(ADoc, ADoc.Root);
  if not ARoot.IsObject then
    Exit;
  Result := True;
end;

function BridgeValidateFrame(const ARoot: TJsonValue; out AId: Int64;
  out ACmd: string): Boolean; inline;
var
  LField: TJsonValue;
begin
  Result := False;
  AId := 0;
  ACmd := '';
  LField := ARoot.Get('v');
  if not LField.IsInt then Exit;
  if LField.AsInt <> NPW_BRIDGE_VERSION then Exit;
  LField := ARoot.Get('id');
  if not LField.IsInt then Exit;
  AId := LField.AsInt;
  if (AId <= 0) or (AId > NPW_MAX_FRAME_ID) then Exit;
  LField := ARoot.Get('cmd');
  if not LField.IsStr then Exit;
  ACmd := LField.AsStr.ToString;
  if ACmd = '' then Exit;
  Result := True;
end;

function BridgeNormalizePayload(const APayload: TJsonValue): string; inline;
var
  LView: TStringView;
begin
  { zero-copy RawSlice; fallback JsonStringify only when empty. }
  if APayload.IsNull then
    Exit('null');
  LView := APayload.RawSlice;
  if LView.Len > 0 then
    Exit(LView.ToString);
  Result := JsonStringify(APayload);
end;

function TryDecodeFrame(const AView: TStringView;
  out AFrame: TWebviewFrame): Boolean; overload;
var
  LRoot: TJsonValue;
  LPayload: TJsonValue;
  LDoc: TJsonDocument;
begin
  { UI 线程亲和严谨：栈上局部 Arena，零全局共享、无锁竞争；TStringView 零拷贝 (bytes.ops 单源)，inline 薄转发。 }
  Result := False;
  AFrame := Default(TWebviewFrame);
  LDoc.Init(nil);
  try
    if not BridgeParseFrame(AView, LDoc, LRoot) then
      Exit;
    if not BridgeValidateFrame(LRoot, AFrame.Id, AFrame.Cmd) then
      Exit;
    LPayload := LRoot.Get('payload');
    AFrame.PayloadJson := BridgeNormalizePayload(LPayload);
    Result := True;
  finally
    LDoc.Done;
  end;
end;

function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean; overload; inline;
var
  LView: TStringView;
begin
  { inline zero-copy View forwarding (bytes.ops single source). }
  LView := TStringView.FromStr(AFrameJson);
  Result := TryDecodeFrame(LView, AFrame);
end;

function BuildResolveScript(AId: Int64; const AResultJson: string): string;
var
  LJson: string;
  LB: TStringBuilder;
  W: TJsonWriter;
begin
  LJson := AResultJson;
  if LJson = '' then
    LJson := 'null';
  LB.Init(SizeUInt(16 + 20 + Length(LJson) + 8));
  try
    LB.AppendBytes('__npw.__resolve(', 16);
    LB.AppendInt(AId);
    LB.AppendChar(',');
    W.Init(LB);
    W.Str(LJson);
    LB.AppendChar(')');
    Result := LB.ToString;
  finally
    LB.Done;
  end;
end;

function BuildRejectScript(AId: Int64; const ACode, AMessage: string): string;
var
  LCode: string;
  LB, LInner: TStringBuilder;
  W: TJsonWriter;
begin
  LCode := NormalizeInvokeCode(ACode);
  LInner.Init(SizeUInt(32 + SizeUInt(Length(LCode)) * 2 + SizeUInt(Length(AMessage)) * 2 + 16));
  try
    W.Init(LInner);
    W.BeginObject;
    W.Key('code'); W.Str(LCode);
    W.Key('message'); W.Str(AMessage);
    W.EndObject;
    LB.Init(SizeUInt(20 + LInner.Len * 2 + 16));
    try
      LB.AppendBytes('__npw.__reject(', 15);
      LB.AppendInt(AId);
      LB.AppendChar(',');
      W.Init(LB);
      W.Str(LInner.AsView);
      LB.AppendChar(')');
      Result := LB.ToString;
    finally
      LB.Done;
    end;
  finally
    LInner.Done;
  end;
end;

function BuildEmitScript(const AEvent, APayloadJson: string): string;
var
  LJson: string;
  LB: TStringBuilder;
  W: TJsonWriter;
begin
  CheckWebviewEventName(AEvent);
  LJson := APayloadJson;
  if LJson = '' then
    LJson := 'null';
  LB.Init(SizeUInt(13 + Length(AEvent) * 2 + Length(LJson) * 2 + 16));
  try
    LB.AppendBytes('__npw.__emit(', 13);
    W.Init(LB);
    W.Str(AEvent);
    LB.AppendChar(',');
    W.Init(LB);
    W.Str(LJson);
    LB.AppendChar(')');
    Result := LB.ToString;
  finally
    LB.Done;
  end;
end;

function NormalizeInvokeCode(const ACode: string): string; inline;
begin
  if ACode = '' then
    Result := NPW_CODE_BAD_REQUEST
  else
    Result := ACode;
end;

{ ---- TWebviewInvokeRegistry: 六形态归一，单哈希 O(1) ---- }

constructor TWebviewInvokeRegistry.Create;
begin
  inherited Create;
  FMap := specialize THashMap<string, TInvokeEntry>.Create(4);
end;

procedure TWebviewInvokeRegistry.AddEntry(const ACmd: string;
  AIsAsync: Boolean; const ASync: TWebviewInvokeSyncHandler;
  const AAsync: TWebviewInvokeAsyncHandler);
var
  LEntry: TInvokeEntry;
begin
  CheckInvokeCmd(ACmd);
  LEntry.IsAsync := AIsAsync;
  LEntry.SyncHandler := ASync;
  LEntry.AsyncHandler := AAsync;
  if not FMap.Add(ACmd, LEntry) then
    raise EWebviewInvalidState.CreateFmt(
      'invoke handler already registered: %s', [ACmd]);
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

destructor TWebviewInvokeRegistry.Destroy;
begin
  if FMap <> nil then
    FMap.Free;
  FMap := nil;
  inherited Destroy;
end;

procedure TWebviewInvokeRegistry.Unregister(const ACmd: string);
begin
  if FMap = nil then Exit;
  FMap.Remove(ACmd);
end;

function TWebviewInvokeRegistry.Count: Integer; inline;
begin
  if FMap = nil then Exit(0);
  Result := Integer(FMap.GetCount);
end;

function TWebviewInvokeRegistry.Find(const ACmd: string; out AIsAsync: Boolean;
  out ASync: TWebviewInvokeSyncHandler;
  out AAsync: TWebviewInvokeAsyncHandler): Boolean;
var
  LEntry: TInvokeEntry;
begin
  if (FMap = nil) or (FMap.GetCount = 0) then Exit(False);
  if not FMap.TryGetValue(ACmd, LEntry) then
    Exit(False);
  Result := True;
  AIsAsync := LEntry.IsAsync;
  ASync := LEntry.SyncHandler;
  AAsync := LEntry.AsyncHandler;
end;

{ ---- TWebviewAssetsImpl：前缀路由 + provider 链 ---- }

constructor TWebviewAssetsImpl.Create(AInert: Boolean);
begin
  inherited Create;
  FInert := AInert;
  FIndex := TWebviewAssetIndex.Create;
end;

destructor TWebviewAssetsImpl.Destroy;
begin
  if FIndex <> nil then
    FIndex.Free;
  FIndex := nil;
  inherited Destroy;
end;

procedure TWebviewAssetsImpl.MountEmbedded(const APrefix: string;
  AProvider: IWebviewAssetProvider);
var
  LNormPrefix: string;
begin
  if FInert then
    Exit;   { DevServerUrl 开发模式：资源服务让位 http dev server（§3.4） }
  if AProvider = nil then
    raise EWebviewInvalidState.Create('asset provider must not be nil');
  LNormPrefix := NormalizeWebviewAssetPath(APrefix);
  FIndex.Add(LNormPrefix, AProvider);
end;

procedure TWebviewAssetsImpl.MountDirectory(const APrefix, ARootDir: string);
begin
  { 不支持的目录挂载：抛 ENotSupportedError（CONTRACT §3.4）。 }
  if FInert then
    Exit;
  raise ENotSupportedError.Create('directory asset mounts are not supported yet');
end;

function TWebviewAssetsImpl.TryResolve(const ASchemeRelativePath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  Result := TryResolveView(TStringView.FromStr(ASchemeRelativePath), ABytes, AMimeType);
end;

function TWebviewAssetsImpl.TryResolveView(const AView: TStringView;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  LPath: string;
  LView, LNormView: TStringView;
  LProvider: IWebviewAssetProvider;
begin
  Result := False;
  ABytes := nil;
  AMimeType := '';
  if FInert then
    Exit;
  // view zero-copy; ToString deferred until provider hit
  LNormView := NormalizeWebviewAssetView(AView);
  if LNormView.Len = 0 then
    Exit;
  LView := LNormView;
  if (FIndex.Count = 1) and FIndex.TryGetByStr('', LProvider) then
  begin LPath := LNormView.ToString; Exit(LProvider.TryResolve(LPath, ABytes, AMimeType)); end;
  if FIndex.TryGetLongestPrefixByView(LView, LProvider) then
  begin LPath := LNormView.ToString; Exit(LProvider.TryResolve(LPath, ABytes, AMimeType)); end;
  Result := False;
end;

function TWebviewAssetsImpl.MountCount: Integer; inline;
begin
  Result := FIndex.Count;
end;

end.
