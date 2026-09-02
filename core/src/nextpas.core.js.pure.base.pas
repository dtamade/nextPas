unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece (standard submodule base: nextpas.core.js.pure.base)
  single source via base canonical types (host/heap/value/lifecycle owners converge via impl), no mutable globals, zero logic
  single responsibility = type-carrier per four-piece base←intf←impl←门面, luxury thin — now pure type-carrier only, host/value/eval via owner pure.host/pure.value/js.eval single source (no base→host/value cycle, base zero dependency per design-conventions, former explicit exception narrowed, threshold 16 via pure.hash single source, bytes.ops geometric 0→64→2×)
  preferred entry = TJsPureHostState unified (via pure.host), no legacy shim, luxury thin
  inline zero-copy via bytes.ops/text.view single source (BytesCopy/SpanEqual), L0-L3 kept, wc -l ~80 <800, CONTRACT §1 }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;
type
  { Host types — canonical single source, owner pure.base (host impl aliases this, no base→host cycle) }
  TJsPureHostRec = record
    Name: string;
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
    Kind: Integer;
    Hash: UInt32;
  end;
  TJsPureHostArray = array of TJsPureHostRec;
  TJsPureHostBuckets = record
    Buckets: array of Integer;
    Mask: UInt32;
    Count: Integer;
  end;
  TJsPureHostState = record
    Hosts: TJsPureHostArray;
    Buckets: TJsPureHostBuckets;
  end;
  { Heap/Value types — canonical single source, owner pure.base (value impl aliases this) }
  TJsPureProp = record Name: string; Value: TJsValue; Hash: UInt32; end;
  generic TJsArray<T> = array of T;
  TJsPurePropArray = specialize TJsArray<TJsPureProp>;
  TJsPureObject = record Id: Int64; Props: TJsPurePropArray; PropsBuckets: array of Integer; PropsMask: UInt32; end;
  TJsPureHeap = specialize TJsArray<TJsPureObject>;
  TJsValueArray = array of TJsValue;
const
  // hash threshold 16 single source via pure.hash JS_PURE_HASH_THRESHOLD (bytes.ops BytesNextCapacity 0→64→2× geometric, inline zero-copy, canonical via pure.hash, no literal duplication, aligned with JSON_OBJECT_HASH_THRESHOLD 16 via json.types, O(1) for 50 scopes)
  JS_PURE_EVAL_WHILE_TRUE = 'while(true)';
  JS_PURE_EVAL_JSON_STRINGIFY = 'JSON.stringify';
  JS_PURE_EVAL_MAGIC_X = 'x';
  JS_PURE_EVAL_BAD = 'bad(';
  JS_PURE_EVAL_FOO = 'foo(';
// lifecycle — owner js.lifecycle single source, thin-forward inline zero-copy, base zero dependency (only lifecycle, no host/value/eval cycle)
function JsPureContextRegister: UInt64; inline;
procedure JsPureContextClose(AId: UInt64); inline;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
// Close — lifecycle + direct clear (no host/value cycle, bytes.ops zero-copy single source, inline, resource幂等不丢 via SetLength+ lifecycle Close)
procedure JsPureClose(var AState: TJsPureHostState; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); inline;
implementation
uses
  nextpas.core.js.lifecycle;
function JsPureContextRegister: UInt64; inline;
begin Result := nextpas.core.js.lifecycle.JsPureContextRegister; end;
procedure JsPureContextClose(AId: UInt64); inline;
begin nextpas.core.js.lifecycle.JsPureContextClose(AId); end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
begin Result := nextpas.core.js.lifecycle.JsPureContextIsClosed(AId); end;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
begin
  // INV-7 strong: explicit acquire via lifecycle GPureClosed compact 4B epoch*2+closed (atomic_load mo_acquire)
  // perf: inline zero-alloc strong, bulk hot path keep V.IsValid zero barrier (FValid only), cross-thread/post-Close safe via generation mismatch
  Result := V.IsValid and not nextpas.core.js.lifecycle.JsPureContextIsClosed(V.FContextId);
end;
function JsPureThreadSelf: UInt64; inline;
begin
  // perf: inline thin-forward to js.lifecycle single source JsPureThreadSelf (L0 platform.thread single slit via lifecycle), zero-copy token, inline hot path, bytes.ops 单源几何同保持
  Result := nextpas.core.js.lifecycle.JsPureThreadSelf;
end;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
begin
  // perf: inline single compare via js.lifecycle single source, zero syscall beyond one, no duplication, thread-affine single source via pure.base
  Result := nextpas.core.js.lifecycle.JsPureIsOnCreationThread(ACreationId);
end;
procedure JsPureClose(var AState: TJsPureHostState; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); inline;
var I, J: Integer;
begin
  // base zero dependency: no host/value cycle — direct clear via SetLength+Default, lifecycle Close single source, inline, resource幂等不丢 (no host/value unit, bytes.ops zero-copy single source)
  // perf: inline thin-forward lifecycle Close + direct Hosts/Heap clear O(n) single pass, no extra unit, amortized O(1) via mem.dynarray poke single source inside SetLength, zero-copy
  JsPureContextClose(AContextId);
  // HostState clear direct (avoids pure.host cycle)
  SetLength(AState.Hosts, 0);
  SetLength(AState.Buckets.Buckets, 0);
  AState.Buckets.Mask := 0;
  AState.Buckets.Count := 0;
  // Heap clear direct (avoids pure.value cycle) — release managed refs, resource不丢 via assignment
  for I := 0 to High(Heap) do
  begin
    for J := 0 to High(Heap[I].Props) do
    begin Heap[I].Props[J].Name := ''; Heap[I].Props[J].Hash := 0; Heap[I].Props[J].Value := Default(TJsValue); end;
    SetLength(Heap[I].Props, 0);
    SetLength(Heap[I].PropsBuckets, 0);
    Heap[I].PropsMask := 0;
  end;
  SetLength(Heap, 0);
  Global := JsUndefinedValue;
end;
end.
