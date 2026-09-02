unit nextpas.core.js.value.store;
{**
 * @desc JS 值存储独立子模块 — 双堆装饰器下沉单源 (js.value 语义，独立于 quickjs 宿主).
 *       沉淀 pure Heap + QJS 镜像 + Global 三元，消除 Context 内双写耦合，装饰器边界显式拆分.
 *       Context 仅持单一 Store 字段，容量/镜像/枚举/集/删经本模块 single source  via bytes.ops+mem.dynarray，
 *       热点 inline/零拷贝，资源幂等不丢，守四件套 base←intf←value←门面 与 L0-L3，缺能力反哺 owner.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.js.quickjs.ffi,
  nextpas.core.text.view;

type
  TJsValueStore = nextpas.core.js.quickjs.value.TJsQjsValueStore;

procedure JsValueStoreInit(var S: TJsValueStore; AContextId: UInt64; ARuntime, ACtx: Pointer); inline;
procedure JsValueStoreClear(var S: TJsValueStore; ACtx: Pointer); inline;
function JsValueStoreFind(const S: TJsValueStore; const AObj: TJsValue): Integer; inline;
procedure JsValueStoreEnsureCapacity(var S: TJsValueStore; ANeed: Integer); inline;
procedure JsValueStoreSyncNewEntry(var S: TJsValueStore; AIdx: Integer; AIsArray: Boolean; ACtx: Pointer); inline;
function JsValueStoreTryGetKeysFFI(const S: TJsValueStore; ACtx: Pointer; AIdx: Integer; out AKeys: TJsStringArray): Boolean; inline;
procedure JsValueStoreMirrorSetProp(var S: TJsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
procedure JsValueStoreMirrorDeleteProp(var S: TJsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string); inline;
function JsValueStoreGlobal(const S: TJsValueStore): TJsValue; inline;
function JsValueStoreHeapLength(const S: TJsValueStore): Integer; inline;
function JsValueCStrLen(P: PAnsiChar): SizeUInt; inline;
function JsValueView(P: PAnsiChar): TStringView; inline;
function JsValueFromTJs(const S: TJsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
function JsValueToTJs(const S: TJsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;

implementation

uses
  nextpas.core.js.quickjs.value;

procedure JsValueStoreInit(var S: TJsValueStore; AContextId: UInt64; ARuntime, ACtx: Pointer); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreInit(S, AContextId, ARuntime, ACtx);
end;

procedure JsValueStoreClear(var S: TJsValueStore; ACtx: Pointer); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreClear(S, ACtx);
end;

function JsValueStoreFind(const S: TJsValueStore; const AObj: TJsValue): Integer; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsStoreFind(S, AObj);
end;

procedure JsValueStoreEnsureCapacity(var S: TJsValueStore; ANeed: Integer); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreEnsureCapacity(S, ANeed);
end;

procedure JsValueStoreSyncNewEntry(var S: TJsValueStore; AIdx: Integer; AIsArray: Boolean; ACtx: Pointer); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreSyncNewEntry(S, AIdx, AIsArray, ACtx);
end;

function JsValueStoreTryGetKeysFFI(const S: TJsValueStore; ACtx: Pointer; AIdx: Integer; out AKeys: TJsStringArray): Boolean; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsStoreTryGetKeysFFI(S, ACtx, AIdx, AKeys);
end;

procedure JsValueStoreMirrorSetProp(var S: TJsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreMirrorSetProp(S, ACtx, AIdx, AName, AVal);
end;

procedure JsValueStoreMirrorDeleteProp(var S: TJsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string); inline;
begin
  nextpas.core.js.quickjs.value.QjsStoreMirrorDeleteProp(S, ACtx, AIdx, AName);
end;

function JsValueStoreGlobal(const S: TJsValueStore): TJsValue; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsStoreGlobal(S);
end;

function JsValueStoreHeapLength(const S: TJsValueStore): Integer; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsStoreHeapLength(S);
end;

function JsValueCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsCStrLen(P);
end;

function JsValueView(P: PAnsiChar): TStringView; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsView(P);
end;

function JsValueFromTJs(const S: TJsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsFromTJsValue(S, ACtx, AVal);
end;

function JsValueToTJs(const S: TJsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
begin
  Result := nextpas.core.js.quickjs.value.QjsToTJsValue(S, ACtx, ACtxtId, V);
end;

end.
