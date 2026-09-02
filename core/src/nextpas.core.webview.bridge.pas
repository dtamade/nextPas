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

{ 帧长可观测性：调用方可先用此 helper 判断超限；TryDecodeFrame 超限
  返回 False 但递增背压计数并经 log.intf Warn 告警（Release 亦可观测，防拼接/洪泛隐式堆积，§6）。 }
function IsWebviewFrameOversized(const AFrameJson: string): Boolean; inline;
function IsWebviewFrameOversizedView(const AView: TStringView): Boolean; inline;
{ 背压可观测：超限帧计数（单调递增，跨线程可见需外层同步，UI 线程亲和） }
function WebviewOversizedCount: UInt64; inline;
procedure WebviewResetOversizedCount; inline;
procedure WebviewNoteOversized(ASize: SizeUInt); inline;
procedure SetWebviewBridgeLogger(ALogger: ILogger); inline;

{ TryDecodeFrame: §3.1 parse→validate→normalize; False on invalid, no raise. }
{ perf: hot path View+Document reuse zero alloc (Arena reuse), TStringView zero-copy. }
{ note: string overload allocates Document/Arena; hot loops must use View+Document. }
function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean; overload; inline;
{ View 入口：TStringView 零拷贝借用 }
function TryDecodeFrame(const AView: TStringView;
  out AFrame: TWebviewFrame): Boolean; overload; inline;
{ Document 复用：caller Init/Done, Parse reuse Arena, zero alloc per frame }
function TryDecodeFrame(const AView: TStringView; var ADoc: TJsonDocument;
  out AFrame: TWebviewFrame): Boolean; overload;

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
      非线程安全——只允许 UI 主线程触碰（与窗口壳同线程）。
      容器单源：委托 L1 collections.hashmap 通用开放寻址（WyHash/HashMix32/
      NextPow2/0.75 负载/Bitmap 单源），消除私有桶/Rehash/FindSlot 分叉；
      资产索引 distinctLens 最长前缀语义与通用 Map 不可映射故豁免（仅哈希/
      生长/相等仍单源，见 assets.pas）。 *}
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
  {** 资产路由索引已抽独立模块 TWebviewAssetIndex（L3 单哈希+有序 Lens），
      桥侧仅持单实例，消除数组+哈希双结构双写耦合；MountCount/最长探测
      由索引单源承载。 *}
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
  nextpas.core.json.parser,
  nextpas.core.json.writer,
  nextpas.core.bytes.ops,
  nextpas.core.hash.wyhash,
  nextpas.core.collections.hashmap.base,
  nextpas.core.simd.bitops,
  nextpas.core.log.intf,
  nextpas.core.webview.base,
  nextpas.core.webview.validation,
  nextpas.core.webview.utils;

{ JsStringLit: JSON Str subset, reuse json owner, no manual scan. }
{ perf: inline, TJsonWriter zero-copy Move, single reserve. }
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
  Result := Length(AFrameJson) > NPW_MAX_FRAME_BYTES;
end;

function IsWebviewFrameOversizedView(const AView: TStringView): Boolean; inline;
begin
  Result := AView.Len > SizeUInt(NPW_MAX_FRAME_BYTES);
end;

var
  GWebviewOversizedFrames: UInt64 = 0;
  GWebviewBridgeLogger: ILogger = nil;

function WebviewOversizedCount: UInt64; inline;
begin
  Result := GWebviewOversizedFrames;
end;

procedure WebviewResetOversizedCount; inline;
begin
  GWebviewOversizedFrames := 0;
end;

procedure WebviewNoteOversized(ASize: SizeUInt); inline;
begin
  Inc(GWebviewOversizedFrames);
  { stability: Release 亦可观测背压，Warn 告警防连续小帧/拼接攻击隐式堆积；采样避免洪泛日志 }
  if (GWebviewBridgeLogger <> nil) and ((GWebviewOversizedFrames <= 5) or (GWebviewOversizedFrames mod 64 = 0)) then
    GWebviewBridgeLogger.Warn('webview frame oversized');
end;

procedure SetWebviewBridgeLogger(ALogger: ILogger); inline;
begin
  GWebviewBridgeLogger := ALogger;
end;

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
begin
  { perf: inline + json owner 单源 canonical 重序列化；缺省/显式 null 零分配快路径；复杂 payload 经 JsonStringify 单源，热点 View+Document Arena 复用零分配（parse 零拷贝），Stringify 单次 builder 分配，双重 JSON 编解码已最小化——如需完全零拷贝需 json owner 反哺 RawSlice 能力（CONTRACT 为准） }
  if APayload.IsNull then
    Exit('null');
  Result := JsonStringify(APayload);
end;

function TryDecodeFrame(const AView: TStringView; var ADoc: TJsonDocument;
  out AFrame: TWebviewFrame): Boolean; overload;
var
  LRoot: TJsonValue;
  LPayload: TJsonValue;
begin
  Result := False;
  AFrame := Default(TWebviewFrame);
  if not BridgeParseFrame(AView, ADoc, LRoot) then
    Exit;
  if not BridgeValidateFrame(LRoot, AFrame.Id, AFrame.Cmd) then
    Exit;
  LPayload := LRoot.Get('payload');
  AFrame.PayloadJson := BridgeNormalizePayload(LPayload);
  Result := True;
end;

function TryDecodeFrame(const AView: TStringView;
  out AFrame: TWebviewFrame): Boolean; overload; inline;
var
  LDoc: TJsonDocument;
begin
  LDoc.Init(nil);
  try
    Result := TryDecodeFrame(AView, LDoc, AFrame);
  finally
    LDoc.Done;
  end;
end;

function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean; overload; inline;
var
  LView: TStringView;
begin
  { cold path single source: string overload zero-copy View forwarding to View overload, no duplicate Init/Done/Oversized; hot loops must use View+Document var ADoc reuse zero alloc per frame (Arena reuse) single source bytes.ops }
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
  { perf: 单次 TBufStringBuilder 预留+零拷贝 AppendInt/AppendBytes，W.Str 单次转义；无 IJsonBuilder 接口堆分配，无 IntToStr 临时串与 '+' 串拼接二次拷贝 }
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
  LB: TStringBuilder;
  LCode: string;
  LInner: TStringBuilder;
  LInnerStr: string;
  W: TJsonWriter;
begin
  { 双层转义复用 json.writer/text.escape 单源：内层 {"code":...,"message":...} 经 TJsonWriter 单源转义，外层经 W.Str 二次转义为 JS 串字面量；零手写 hex/双层分支，转义语义与 BuildResolveScript/BuildEmitScript 同源 }
  LCode := NormalizeInvokeCode(ACode);
  { perf: 内层 worst 6x（\u00xx），bytes.ops 单源预留单次 Init，零二次扩容与 Move；外层基于已求 inner 长度 *2 预留（" / \ 二次 2x，上界覆盖 \u00xx 7 字节总展开），零二次 Grow }
  LInner.Init(SizeUInt(32 + SizeUInt(Length(LCode)) * 6 + SizeUInt(Length(AMessage)) * 6));
  try
    W.Init(LInner);
    W.BeginObject;
    W.Key('code');
    W.Str(LCode);
    W.Key('message');
    W.Str(AMessage);
    W.EndObject;
    LInnerStr := LInner.ToString;
  finally
    LInner.Done;
  end;
  { stability: 单 outer builder，try/finally Done 不丢，与 BuildResolveScript 同纪律 }
  LB.Init(SizeUInt(15 + 20 + 1 + SizeUInt(Length(LInnerStr)) * 2 + 4));
  try
    LB.AppendBytes('__npw.__reject(', 15);
    LB.AppendInt(AId);
    LB.AppendChar(',');
    W.Init(LB);
    W.Str(LInnerStr);
    LB.AppendChar(')');
    Result := LB.ToString;
  finally
    LB.Done;
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
  { perf: 单 builder 复用，AppendInt/AppendBytes 零拷贝，W.Str 两次各经一次 Init 重置 RootWritten，避免 IJsonBuilder 与 '+' 拼接 }
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

{ ---- TWebviewInvokeRegistry：六形态归一 + 命名空间校验 + 单哈希 O(1) ---- }

{ ---- TWebviewInvokeRegistry：六形态归一 + 命名空间校验 + 单哈希 O(1) ---- }
{ perf: 容器单源 L1 collections.hashmap（WyHash/HashMix32/NextPow2/Bitmap 单源，0.75 负载），零私有桶分叉；inline 薄转零额外调用 }

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
  { stability: FMap.Free 释放全量托管串/接口（Clear→Finalize），nil 释放不丢，无 FillChar 绕过托管语义，inline 薄转 }
  if FMap <> nil then
    FMap.Free;
  FMap := nil;
  inherited Destroy;
end;

procedure TWebviewInvokeRegistry.Unregister(const ACmd: string);
begin
  { perf: O(1) 平均哈希探测（hashmap 单源 WyHash/HashMix32），tombstone 链路保持，静默 no-op }
  if FMap = nil then Exit;
  FMap.Remove(ACmd);
end;

function TWebviewInvokeRegistry.Count: Integer; inline;
begin
  { perf: inline O(1) 读，零额外调用 }
  if FMap = nil then Exit(0);
  Result := Integer(FMap.GetCount);
end;

function TWebviewInvokeRegistry.Find(const ACmd: string; out AIsAsync: Boolean;
  out ASync: TWebviewInvokeSyncHandler;
  out AAsync: TWebviewInvokeAsyncHandler): Boolean;
var
  LEntry: TInvokeEntry;
begin
  { perf: O(1) 平均哈希探测（WyHash 单源零拷贝 via HashOfAnsiString/HashMix32），hash 相等再字符串相等双筛，inline 热分发零额外调用 }
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
  { 单哈希+有序 Lens 单源承载：首个同前缀胜（CONTRACT §3.4），
    零双写；索引内部 WyHash + VecGrowCapacity 单源，O(1) 平均。 }
  FIndex.Add(LNormPrefix, AProvider);
end;

procedure TWebviewAssetsImpl.MountDirectory(const APrefix, ARootDir: string);
begin
  { CONTRACT §3.4：文件系统支撑归 fs owner，W1 显式不支持抛
    ENotSupportedError(ecNotSupported)，消息稳定可断言；门禁
    test_webview_bridge 覆盖 FInert/非惰性双路径与 Category 校验。
    开发模式 no-op 优先于不支持错误——保持两模式观感一致，无资源泄漏。 }
  if FInert then
    Exit;
  raise ENotSupportedError.Create('directory asset mounts are not supported yet');
end;

function TWebviewAssetsImpl.TryResolve(const ASchemeRelativePath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  I, LLen: Integer;
  LPath: string;
  LView, LSlice: TStringView;
  LProvider: IWebviewAssetProvider;
begin
  Result := False;
  ABytes := nil;
  AMimeType := '';
  if FInert then
    Exit;
  LPath := NormalizeWebviewAssetPath(ASchemeRelativePath);
  if LPath = '' then
    Exit;
  LView := TStringView.FromStr(LPath);
  { 单挂载根路径快路径：95% demo 单 provider 零扫描（与 MountCount inline 同源） }
  if (FIndex.Count = 1) and (FIndex.DistinctCount = 1) and (FIndex.DistinctLensAt(0) = 0) then
  begin
    if FIndex.TryGetByView(TStringView.Empty, LProvider) then
      Exit(LProvider.TryResolve(LPath, ABytes, AMimeType));
  end;
  { 哈希最长前缀探测：distinctLens 降序枚举，TStringView 零拷贝切片 +
    WyHash 视图哈希 O(1) 探测，单 distinct 零 Copy/GetsMem；多挂载仍
    O(distinct) 哈希优于全量 n*Pos 扫描，零堆分配证据见 bench_bridge。 }
  for I := 0 to FIndex.DistinctCount - 1 do
  begin
    LLen := FIndex.DistinctLensAt(I);
    if SizeUInt(LLen) > LView.Len then
      Continue;
    if LLen = 0 then
    begin
      if FIndex.TryGetByView(TStringView.Empty, LProvider) then
        Exit(LProvider.TryResolve(LPath, ABytes, AMimeType));
      Continue;
    end;
    LSlice := TStringView.Create(LView.Data, SizeUInt(LLen));
    if FIndex.TryGetByView(LSlice, LProvider) then
      Exit(LProvider.TryResolve(LPath, ABytes, AMimeType));
  end;
  Result := False;
end;

function TWebviewAssetsImpl.MountCount: Integer; inline;
begin
  Result := FIndex.Count;
end;

end.
