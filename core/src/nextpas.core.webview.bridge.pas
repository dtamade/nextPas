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
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.builder,
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
function NormalizeInvokeCode(const ACode: string): string;

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
    function IndexOf(const ACmd: string): Integer;
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
      out AAsync: TWebviewInvokeAsyncHandler): Boolean;
    function Count: Integer;
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
    FInert: Boolean;   { DevServerUrl 开发模式：挂载 no-op、解析一律 404 }
  public
    constructor Create(AInert: Boolean = False);
    procedure MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider);
    procedure MountDirectory(const APrefix, ARootDir: string);
    function TryResolve(const ASchemeRelativePath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    function MountCount: Integer;
  end;

const
  { 注入脚本（§2）：document-start 主帧注入，每次导航重注。
    单份脚本服务全部后端——transport 在脚本内探测：
    WebKitGTK/WK 共用 window.webkit.messageHandlers.npw，
    WebView2 用 window.chrome.webview，均投递字符串化帧。
    公开面为 window.__npw 的 version/ready/invoke/listen/emit；
    内部面 __resolve/__reject/__emit 由 native 经 Eval 调用；
    ready promise 于脚本尾部兑现（§4 握手时序）。 }
  NPW_BRIDGE_SCRIPT: string =
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
    '    if (nextId > 9007199254740991)'#10 +
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

implementation

{ json.types/json.builder 已在 interface uses 引入 }

{ 把任意文本转成 JS 字符串字面量：JSON 字符串转义集是 JS 的子集
  （引号/反斜杠/控制字符），直接复用 json owner 的 Str 编码。
  bridge 内不做任何手工转义扫描（BRIDGE_PROTOCOL §6）。 }
function JsStringLit(const AValue: string): string;
var
  LB: IJsonBuilder;
begin
  LB := JsonBuilder;
  LB.Str(AValue);
  Result := LB.ToString;
end;

function TryDecodeFrame(const AFrameJson: string;
  out AFrame: TWebviewFrame): Boolean;
var
  LDoc: IJsonDocument;
  LRoot, LField: TJsonValue;
begin
  Result := False;
  AFrame := Default(TWebviewFrame);
  if (AFrameJson = '') or (Length(AFrameJson) > 2 * 1024 * 1024) then
    Exit;
  if not TryJsonParse(AFrameJson, LDoc) then
    Exit;
  if LDoc.HasError then
    Exit;
  LRoot := LDoc.Root;
  if not LRoot.IsObject then
    Exit;
  { v：必填整数，恒等于协议版本 }
  LField := LRoot.Get('v');
  if not LField.IsInt then
    Exit;
  if LField.AsInt <> NPW_BRIDGE_VERSION then
    Exit;
  { id：必填正整数，u53 上界内（native 不解释、原样回显） }
  LField := LRoot.Get('id');
  if not LField.IsInt then
    Exit;
  AFrame.Id := LField.AsInt;
  if (AFrame.Id <= 0) or (AFrame.Id > NPW_MAX_FRAME_ID) then
    Exit;
  { cmd：必填非空字符串 }
  LField := LRoot.Get('cmd');
  if not LField.IsStr then
    Exit;
  AFrame.Cmd := LField.AsStr.ToString;
  if AFrame.Cmd = '' then
    Exit;
  { payload：缺省/显式 null → 'null'；否则规范化重序列化 }
  LField := LRoot.Get('payload');
  if LField.IsNull then
    AFrame.PayloadJson := 'null'
  else
    AFrame.PayloadJson := JsonStringify(LField);
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
  LB: IJsonBuilder;
begin
  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key('code');
  LB.Str(NormalizeInvokeCode(ACode));
  LB.Key('message');
  LB.Str(AMessage);
  LB.EndObject;
  Result := '__npw.__reject(' + IntToStr(AId) + ',' +
    JsStringLit(LB.ToString) + ')';
end;

function BuildEmitScript(const AEvent, APayloadJson: string): string;
var
  LJson: string;
begin
  if AEvent = '' then
    raise EWebviewInvalidState.Create('bridge emit event name must not be empty');
  LJson := APayloadJson;
  if LJson = '' then
    LJson := 'null';
  Result := '__npw.__emit(' + JsStringLit(AEvent) + ',' +
    JsStringLit(LJson) + ')';
end;

function NormalizeInvokeCode(const ACode: string): string;
begin
  if ACode = '' then
    Result := NPW_CODE_BAD_REQUEST
  else
    Result := ACode;
end;

{ ---- TWebviewInvokeRegistry：六形态归一 + 命名空间校验 ---- }

function TWebviewInvokeRegistry.IndexOf(const ACmd: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Cmd = ACmd then
      Exit(I);
  Result := -1;
end;

procedure TWebviewInvokeRegistry.AddEntry(const ACmd: string;
  AIsAsync: Boolean; const ASync: TWebviewInvokeSyncHandler;
  const AAsync: TWebviewInvokeAsyncHandler);
begin
  CheckInvokeCmd(ACmd);
  if IndexOf(ACmd) >= 0 then
    raise EWebviewInvalidState.CreateFmt(
      'invoke handler already registered: %s', [ACmd]);
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)].Cmd := ACmd;
  FEntries[High(FEntries)].IsAsync := AIsAsync;
  FEntries[High(FEntries)].SyncHandler := ASync;
  FEntries[High(FEntries)].AsyncHandler := AAsync;
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
    Exit;   { 未注册是静默 no-op }
  for I := LIdx to High(FEntries) - 1 do
    FEntries[I] := FEntries[I + 1];
  SetLength(FEntries, Length(FEntries) - 1);
end;

function TWebviewInvokeRegistry.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TWebviewInvokeRegistry.Find(const ACmd: string; out AIsAsync: Boolean;
  out ASync: TWebviewInvokeSyncHandler;
  out AAsync: TWebviewInvokeAsyncHandler): Boolean;
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

procedure TWebviewAssetsImpl.MountEmbedded(const APrefix: string;
  AProvider: IWebviewAssetProvider);
var
  LPos, I: Integer;
begin
  if FInert then
    Exit;   { DevServerUrl 开发模式：资源服务让位 http dev server（§3.4） }
  if AProvider = nil then
    raise EWebviewInvalidState.Create('asset provider must not be nil');
  { 保持按前缀长度降序稳定有序：最长前缀优先，同长保持先挂先得——
    TryResolve 首命中即最优，平均 O(1)、最坏 O(n) 但 n≤~16 时常数极小；
    语义与 CONTRACT §3 最长前缀唯一命中/同长先挂一致 }
  LPos := Length(FMounts);
  for I := 0 to High(FMounts) do
    if Length(APrefix) > Length(FMounts[I].Prefix) then
    begin
      LPos := I;
      Break;
    end;
  SetLength(FMounts, Length(FMounts) + 1);
  for I := High(FMounts) downto LPos + 1 do
    FMounts[I] := FMounts[I - 1];
  FMounts[LPos].Prefix := APrefix;
  FMounts[LPos].Provider := AProvider;
end;

procedure TWebviewAssetsImpl.MountDirectory(const APrefix, ARootDir: string);
begin
  { 文件系统支撑归 fs owner；W1 显式不支持（CONTRACT §3.4 同 fake 立场）。
    开发模式同样 no-op 语义优先于不支持错误——保持两模式观感一致 }
  if FInert then
    Exit;
  raise ENotSupportedError.Create('directory asset mounts are not supported yet');
end;

function TWebviewAssetsImpl.TryResolve(const ASchemeRelativePath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  I: Integer;
  LPath: string;
begin
  Result := False;
  ABytes := nil;
  AMimeType := '';
  if FInert then
    Exit;
  LPath := ASchemeRelativePath;
  while (LPath <> '') and (LPath[1] = '/') do
    Delete(LPath, 1, 1);
  if LPath = '' then
    Exit;
  { 已按长度降序稳定排序：首个前缀命中即最长命中，同长先挂语义天然保持 }
  for I := 0 to High(FMounts) do
    if (FMounts[I].Prefix = '') or (Pos(FMounts[I].Prefix, LPath) = 1) then
      Exit(FMounts[I].Provider.TryResolve(LPath, ABytes, AMimeType));
  Result := False;
end;

function TWebviewAssetsImpl.MountCount: Integer;
begin
  Result := Length(FMounts);
end;

end.
