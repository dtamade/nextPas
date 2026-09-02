unit nextpas.core.js.value;
{ Value/Heap facade — independent L2 value owner (复用下沉): thin re-export pure.value single source, Heap+Global via bytes.ops+mem.dynarray geometric single source, inline zero-copy via text.view. Threshold >800时 pure.base Heap/Value职责可彻底迁至本单元，当前pure.value为单源owner，本单元为js.value独立门面 alias, 守 L0-L3, 四件套 base←intf←impl←门面. }
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
end.
