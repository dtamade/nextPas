unit nextpas.core.js.value.store;
{**
 * @desc JS 值存储独立子模块 — 纯堆单源收敛 (js.value 语义，独立于 quickjs 宿主).
 *       拥有 Heap 纯堆 + Global 门面，QJS 镜像下沉至 quickjs.value 装饰器，消除双写耦合.
 *       职责显式拆分：pure.base 拥有堆实现 (JsPureHeap* via bytes.ops+mem.dynarray)，本模块拥有纯存储契约 (Heap/Global) 单源，
 *       quickjs.value 仅装饰 QjsHeap 镜像 (容量/分配/FFI枚举/镜像Set/Delete).
 *       Context 仅持单一 Store 字段 via 装饰器组合，守四件套 base←intf←value.store←门面 与 L0-L3，复用 bytes.ops 单源几何扩容与 text.view 零拷贝，热点 inline/零拷贝，资源幂等不丢，CONTRACT为准缺能力反哺 owner.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.text.view;

type
  TJsValueStore = record
    Heap: TJsPureHeap;
    Global: TJsValue;
  end;

procedure JsValueStoreInit(var S: TJsValueStore; AContextId: UInt64); inline;
procedure JsValueStoreClear(var S: TJsValueStore); inline;
function JsValueStoreFind(const S: TJsValueStore; const AObj: TJsValue): Integer; inline;
function JsValueStoreGlobal(const S: TJsValueStore): TJsValue; inline;
function JsValueStoreHeapLength(const S: TJsValueStore): Integer; inline;
function JsValueCStrLen(P: PAnsiChar): SizeUInt; inline;
function JsValueView(P: PAnsiChar): TStringView; inline;

implementation

uses
  nextpas.core.bytes.ops;

procedure JsValueStoreInit(var S: TJsValueStore; AContextId: UInt64); inline;
begin
  // owner boundary: pure.base owns Heap alloc single source via bytes.ops+mem.dynarray, inline zero-copy, single Store single source, no FFI, no double-heap coupling
  // perf: inline thin-forward to pure.base JsPureHeapNewObject single source, zero-copy Bind, amortized O(1) via BYTES_BUILDER_MIN_GROW
  S.Global := JsValueBindContext(JsPureHeapNewObject(S.Heap), AContextId);
end;

procedure JsValueStoreClear(var S: TJsValueStore); inline;
begin
  // stability: resource release幂等不丢 — 纯堆Clear single source via pure.base, inline poke single source BYTES_BUILDER_MIN_GROW均摊O1, zero-copy header poke
  JsPureHeapClear(S.Heap);
  S.Global := JsUndefinedValue;
end;

function JsValueStoreFind(const S: TJsValueStore; const AObj: TJsValue): Integer; inline;
begin
  // perf: inline thin-forward to pure.base JsPureHeapFind single source (hash>64 O1 via pure.value single source), zero-copy, inline hot path
  Result := JsPureHeapFind(S.Heap, AObj);
end;

function JsValueStoreGlobal(const S: TJsValueStore): TJsValue; inline;
begin
  // perf: inline zero-copy value return, single source Global gate, no heap scan
  Result := S.Global;
end;

function JsValueStoreHeapLength(const S: TJsValueStore): Integer; inline;
begin
  // perf: inline zero-copy Length read, no scan, O(1)
  Result := Length(S.Heap);
end;

function JsValueCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  // perf: inline thin-forward to bytes.ops.AnsiPtrLen single source (zero-copy view length, single scan, no System.StrLen分叉), inline hot path, reused by quickjs.value single source
  Result := nextpas.core.bytes.ops.AnsiPtrLen(P);
end;

function JsValueView(P: PAnsiChar): TStringView; inline;
begin
  // perf: inline single scan via JsValueCStrLen (bytes.ops AnsiPtrLen single source) → zero-copy TStringView, inline hot path, no重复扫描
  if P = nil then Exit(TStringView.Empty);
  Result := TStringView.Create(P, JsValueCStrLen(P));
end;

end.
