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
      非线程安全——只允许 UI 主线程触碰（与窗口壳同线程）。 *}
  TWebviewInvokeRegistry = class(TInterfacedObject, IWebviewInvokeRegistry)
  private type
    TBucket = record
      State: Byte; // 0 Empty,1 Occupied,2 Deleted
      Hash: UInt32;
      Cmd: string;
      IsAsync: Boolean;
      SyncHandler: TWebviewInvokeSyncHandler;
      AsyncHandler: TWebviewInvokeAsyncHandler;
    end;
  private
    FBuckets: array of TBucket;
    FCapacity: SizeUInt;
    FMask: SizeUInt;
    FCount: SizeUInt;
    FUsed: SizeUInt;
    FMaxLoad: SizeUInt;
    function HashOf(const S: string): UInt32; inline;
    function NextPow2(X: SizeUInt): SizeUInt; inline;
    procedure RecalcMaxLoad; inline;
    procedure InitCapacity(ACap: SizeUInt);
    procedure Rehash(ANewCap: SizeUInt);
    function FindSlot(const ACmd: string; AHash: UInt32; out AIdx: SizeUInt): Boolean; inline;
    function IndexOf(const ACmd: string): Integer;
    procedure AddEntry(const ACmd: string; AIsAsync: Boolean;
      const ASync: TWebviewInvokeSyncHandler;
      const AAsync: TWebviewInvokeAsyncHandler);
  public
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
    nextpas.core.webview.bridge.script.inc 生成，单源可维护。 }
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

function BridgeNormalizePayload(const APayload: TJsonValue): string;
begin
  if APayload.IsNull then
    Result := 'null'
  else
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
  procedure AppendDoubleEscaped(const S: string); inline;
  var
    V: TStringView;
    I: SizeUInt;
    B: Byte;
    LHex: array[0..6] of AnsiChar;
  begin
    V := TStringView.FromStr(S);
    for I := 0 to V.Len - 1 do
    begin
      if V.Data = nil then Break;
      B := Byte(V.Data[I]);
      case B of
        Ord('"'): LB.AppendBytes('\\\"', 4);
        Ord('\'): LB.AppendBytes('\\\\', 4);
        8: LB.AppendBytes('\\b', 3);
        9: LB.AppendBytes('\\t', 3);
        10: LB.AppendBytes('\\n', 3);
        12: LB.AppendBytes('\\f', 3);
        13: LB.AppendBytes('\\r', 3);
      else
        if B < 32 then
        begin
          LHex[0] := '\';
          LHex[1] := '\';
          LHex[2] := 'u';
          LHex[3] := '0';
          LHex[4] := '0';
          if (B shr 4) < 10 then LHex[5] := AnsiChar(Ord('0') + (B shr 4))
          else LHex[5] := AnsiChar(Ord('a') + (B shr 4) - 10);
          if (B and $F) < 10 then LHex[6] := AnsiChar(Ord('0') + (B and $F))
          else LHex[6] := AnsiChar(Ord('a') + (B and $F) - 10);
          LB.AppendBytes(@LHex[0], 7);
        end
        else
          LB.AppendChar(AnsiChar(B));
      end;
    end;
  end;
begin
  { perf: 单预留单Builder零拷贝：单次 Init 预留 (worst 4x for \" / \\ double escape, 7x for control \\u00xx), AppendBytes/AppendInt/JsonEscape 双层转义单遍零拷贝 inline，bytes.ops 单源思想，无 ToString+Clear 双次分配与二次转义抖动；stability: try/finally Done 不丢 }
  LCode := NormalizeInvokeCode(ACode);
  LB.Init(SizeUInt(32 + Length(LCode) * 4 + Length(AMessage) * 4 + 15 + 20 + 32 + 8));
  try
    LB.AppendBytes('__npw.__reject(', 15);
    LB.AppendInt(AId);
    LB.AppendChar(',');
    LB.AppendChar('"');
    LB.AppendBytes('{\"code\":\"', 12);
    AppendDoubleEscaped(LCode);
    LB.AppendBytes('\",\"message\":\"', 17);
    AppendDoubleEscaped(AMessage);
    LB.AppendBytes('\"}', 3);
    LB.AppendChar('"');
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

function TWebviewInvokeRegistry.HashOf(const S: string): UInt32; inline;
begin
  { perf: inline + WyHash32 单源 nextpas.core.hash.wyhash 零拷贝，空串 2166136261 seed 与 THashMap/asset 单源一致，零分配 }
  if Length(S) = 0 then
    Exit(HashMix32(2166136261));
  Result := WyHash32(@S[1], SizeUInt(Length(S)));
end;

function TWebviewInvokeRegistry.NextPow2(X: SizeUInt): UInt32; inline;
begin
  { perf: inline + NextPow2 单源 nextpas.core.simd.bitops，位运算单指令，零额外调用 }
  if X <= 1 then Exit(1);
{$IF SizeOf(SizeUInt)=8}
  Result := UInt32(NextPow2_64(TU64(X)));
{$ELSE}
  Result := UInt32(NextPow2_32(TU32(X)));
{$ENDIF}
end;

procedure TWebviewInvokeRegistry.RecalcMaxLoad; inline;
begin
  { perf: inline 0.75 负载单源，零额外调用 }
  FMaxLoad := Trunc(FCapacity * 0.75);
  if (FCapacity > 0) and (FMaxLoad >= FCapacity) then
    FMaxLoad := FCapacity - 1;
end;

procedure TWebviewInvokeRegistry.InitCapacity(ACap: SizeUInt);
begin
  if ACap < 4 then ACap := 4;
  ACap := SizeUInt(NextPow2(ACap));
  SetLength(FBuckets, ACap);
  { stability: SetLength 已按 Default(TBucket) 零初始化托管字段（string/interface=nil），
    禁止 FillChar 全容量覆写托管语义与 O(cap) 置零抖动；inline 单源 }
  FCapacity := ACap;
  if ACap > 0 then
    FMask := ACap - 1
  else
    FMask := 0;
  FCount := 0;
  FUsed := 0;
  RecalcMaxLoad;
end;

procedure TWebviewInvokeRegistry.Rehash(ANewCap: SizeUInt);
var
  LOld: array of TBucket;
  LOldCap: SizeUInt;
  I: SizeUInt;
  LIdx: SizeUInt;
begin
  { stability: 线性探测重哈希，Finalize 全量串/接口不丢，Move 零拷贝转移所有权，旧桶清零防 double finalize }
  LOld := FBuckets;
  LOldCap := FCapacity;
  FBuckets := nil;
  FCapacity := 0;
  InitCapacity(ANewCap);
  for I := 0 to LOldCap - 1 do
    if LOld[I].State = 1 then
    begin
      LIdx := LOld[I].Hash and FMask;
      while FBuckets[LIdx].State = 1 do
        LIdx := (LIdx + 1) and FMask;
      { stability: 托管赋值转移所有权（string/interface AddRef），旧桶置空释放不丢，零 FillChar 绕过 }
      FBuckets[LIdx] := LOld[I];
      LOld[I].Cmd := '';
      LOld[I].SyncHandler := nil;
      LOld[I].AsyncHandler := nil;
      LOld[I].State := 0;
      LOld[I].Hash := 0;
      LOld[I].IsAsync := False;
      Inc(FCount);
      Inc(FUsed);
    end;
  SetLength(LOld, 0);
end;

function TWebviewInvokeRegistry.FindSlot(const ACmd: string; AHash: UInt32; out AIdx: SizeUInt): Boolean; inline;
var
  LIdx, LStart: SizeUInt;
  LFirstDel: SizeInt;
begin
  { perf: inline O(1) 平均线性探测，WyHash32 视图哈希直算，SpanEqual 前已 hash 预筛，Deleted 链路保持，首 Deleted 记位作插入点，零堆分配 }
  Result := False;
  if FCapacity = 0 then begin AIdx := 0; Exit(False); end;
  LIdx := AHash and FMask;
  LStart := LIdx;
  LFirstDel := -1;
  while True do
  begin
    case FBuckets[LIdx].State of
      0: begin
           if LFirstDel >= 0 then AIdx := SizeUInt(LFirstDel) else AIdx := LIdx;
           Exit(False);
         end;
      1: if (FBuckets[LIdx].Hash = AHash) and (FBuckets[LIdx].Cmd = ACmd) then
         begin AIdx := LIdx; Exit(True); end;
      2: if LFirstDel < 0 then LFirstDel := SizeInt(LIdx);
    end;
    LIdx := (LIdx + 1) and FMask;
    if LIdx = LStart then begin
      if LFirstDel >= 0 then AIdx := SizeUInt(LFirstDel) else AIdx := LIdx;
      Exit(False);
    end;
  end;
end;

function TWebviewInvokeRegistry.IndexOf(const ACmd: string): Integer;
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  { perf: O(1) 平均哈希探测，WyHash32 单源零拷贝，hash 相等再字符串相等双筛，inline 零额外调用 }
  if FCount = 0 then Exit(-1);
  H := HashOf(ACmd);
  if FindSlot(ACmd, H, LIdx) then
    Exit(Integer(LIdx));
  Result := -1;
end;

procedure TWebviewInvokeRegistry.AddEntry(const ACmd: string;
  AIsAsync: Boolean; const ASync: TWebviewInvokeSyncHandler;
  const AAsync: TWebviewInvokeAsyncHandler);
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  CheckInvokeCmd(ACmd);
  if FCapacity = 0 then InitCapacity(4);
  H := HashOf(ACmd);
  if FindSlot(ACmd, H, LIdx) then
    raise EWebviewInvalidState.CreateFmt(
      'invoke handler already registered: %s', [ACmd]);
  if FUsed >= FMaxLoad then
  begin
    Rehash(FCapacity shl 1);
    FindSlot(ACmd, H, LIdx);
  end;
  FBuckets[LIdx].State := 1;
  FBuckets[LIdx].Hash := H;
  FBuckets[LIdx].Cmd := ACmd;
  FBuckets[LIdx].IsAsync := AIsAsync;
  FBuckets[LIdx].SyncHandler := ASync;
  FBuckets[LIdx].AsyncHandler := AAsync;
  Inc(FCount);
  Inc(FUsed);
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
var
  I: SizeUInt;
begin
  { stability: Finalize 全量串/接口，nil 释放不丢，无 FillChar 绕过托管语义，inline 薄转 }
  if FCapacity > 0 then
    for I := 0 to FCapacity - 1 do
      if FBuckets[I].State = 1 then
      begin
        Finalize(FBuckets[I].Cmd);
        Finalize(FBuckets[I].SyncHandler);
        Finalize(FBuckets[I].AsyncHandler);
        FBuckets[I].State := 0;
        FBuckets[I].Hash := 0;
        FBuckets[I].IsAsync := False;
      end;
  SetLength(FBuckets, 0);
  FCapacity := 0;
  FMask := 0;
  FCount := 0;
  FUsed := 0;
  inherited Destroy;
end;

procedure TWebviewInvokeRegistry.Unregister(const ACmd: string);
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  { perf: O(1) 平均哈希探测，WyHash32 单源零拷贝，Deleted tombstone 保持链路，Finalize 释放串/接口不丢 }
  if FCount = 0 then Exit;
  H := HashOf(ACmd);
  if not FindSlot(ACmd, H, LIdx) then
    Exit; { 未注册是静默 no-op }
  Finalize(FBuckets[LIdx].Cmd);
  Finalize(FBuckets[LIdx].SyncHandler);
  Finalize(FBuckets[LIdx].AsyncHandler);
  FBuckets[LIdx].State := 2; // Deleted
  FBuckets[LIdx].Hash := 0;
  Dec(FCount);
end;

function TWebviewInvokeRegistry.Count: Integer; inline;
begin
  { perf: inline O(1) 读，零额外调用 }
  Result := Integer(FCount);
end;

function TWebviewInvokeRegistry.Find(const ACmd: string; out AIsAsync: Boolean;
  out ASync: TWebviewInvokeSyncHandler;
  out AAsync: TWebviewInvokeAsyncHandler): Boolean;
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  { perf: O(1) 平均哈希探测，WyHash32 单源零拷贝，hash 相等再字符串相等双筛，inline 热分发零额外调用 }
  if FCount = 0 then Exit(False);
  H := HashOf(ACmd);
  if not FindSlot(ACmd, H, LIdx) then
    Exit(False);
  Result := True;
  AIsAsync := FBuckets[LIdx].IsAsync;
  ASync := FBuckets[LIdx].SyncHandler;
  AAsync := FBuckets[LIdx].AsyncHandler;
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
