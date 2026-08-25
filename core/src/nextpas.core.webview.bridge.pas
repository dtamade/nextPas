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
  nextpas.core.json,
  nextpas.core.webview.base;

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

uses
  nextpas.core.json.types,
  nextpas.core.json.builder;

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
  if not TryJsonParse(AFrameJson, LDoc) then
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

end.
