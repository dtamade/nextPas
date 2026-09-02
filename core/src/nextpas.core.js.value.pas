unit nextpas.core.js.value;
{ Value/Heap facade — deprecated compat alias: canonical single source is nextpas.core.js.pure.value (Owner pure.value, L2). Thin re-export pure.value inline zero-copy via text.view, Heap+Global via bytes.ops+mem.dynarray geometric single source. New code import via pure.value or pure.base aggregated; do not add new js.value entry. Threshold >800时 Heap/Value职责可迁至 js.value 届时 pure.value 转薄转发, 当前 pure.value 单源 owner (JsValueToJsonString single source via json.writer seam shared, bytes.ops single source). 守 L0-L3, 四件套 base←intf←impl←门面, 资源 try-finally Done 不丢. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.value;
type
  TJsHeapProp = TJsPureProp;
  TJsHeapObject = TJsPureObject;
  TJsHeap = TJsPureHeap;
  TJsHeapMetrics = TJsPureHeapMetrics;
  TJsValueState = TJsPureValueState;
const
  JS_HEAP_HASH_THRESHOLD = JS_PURE_HEAP_HASH_THRESHOLD;
function JsHeapFind(const Heap: TJsHeap; const Obj: TJsValue): Integer; inline;
function JsHeapNewObject(var Heap: TJsHeap): TJsValue; inline;
function JsHeapNewArray(var Heap: TJsHeap): TJsValue; inline;
function JsHeapGetProp(const Heap: TJsHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
procedure JsHeapSetProp(var Heap: TJsHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
procedure JsHeapClear(var Heap: TJsHeap); inline;
function JsNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline;
function JsNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
procedure JsValueStateClear(var S: TJsValueState); inline;
function JsValueToJsonString(const AValue: TJsValue): string;
function JsValueAsJson(const AValue: TJsValue): string; inline;
implementation
function JsHeapFind(const Heap: TJsHeap; const Obj: TJsValue): Integer; inline;
begin Result := JsPureHeapFind(Heap, Obj); end;
function JsHeapNewObject(var Heap: TJsHeap): TJsValue; inline;
begin Result := JsPureHeapNewObject(Heap); end;
function JsHeapNewArray(var Heap: TJsHeap): TJsValue; inline;
begin Result := JsPureHeapNewArray(Heap); end;
function JsHeapGetProp(const Heap: TJsHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
begin Result := JsPureHeapGetProp(Heap, Obj, Name); end;
procedure JsHeapSetProp(var Heap: TJsHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
begin JsPureHeapSetProp(Heap, Obj, Name, Val); end;
procedure JsHeapClear(var Heap: TJsHeap); inline;
begin JsPureHeapClear(Heap); end;
function JsNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewStringView(AView, AContextId); end;
function JsNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewString(AStr, AContextId); end;
function JsNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewInt(AValue, AContextId); end;
procedure JsValueStateClear(var S: TJsValueState); inline;
begin JsPureValueStateClear(S); end;
function JsValueToJsonString(const AValue: TJsValue): string;
begin
  // single source via pure.value JsPureToJsonString (json.writer seam + bytes.ops geometric single source, zero-copy, resource try-finally in owner not lost, inline thin alias deprecated)
  Result := JsPureToJsonString(AValue);
end;
function JsValueAsJson(const AValue: TJsValue): string; inline;
begin
  // perf: inline thin-forward to JsValueToJsonString single source, zero-copy, single seam with pure.value/intf
  Result := JsValueToJsonString(AValue);
end;
end.
