unit nextpas.core.js.pure.base;
{ facade: re-export host/value/eval + compose call/close/io (eval extracted to js.eval, lifecycle extracted to js.lifecycle)
  Note: pure.* pure-family prefix, base shared base suffix — non-standard four-piece naming explicit exception per CONTRACT §1 & design-conventions:150.
  Single responsibility = thin facade only (type-carrier, no mutable globals); lifecycle → js.lifecycle single source (GPureClosed 64B padded atomic acquire/release, cache-line isolated, write-once rare, bulk IsValid zero via FValid, strong acquire, atomic_fetch_add+spinlock geometric via bytes.ops);
  Host→pure.host (future js.host, now pure.host single source), Heap/Value→pure.value (future js.value, now pure.value single source), IO→platform.fs L0 64MiB BytesCopy single source,
  all inline zero-copy via bytes.ops/text.view single source. wc -l ~320 <650 (<800 must-split), thin forwards via pure.host/pure.value/js.eval/js.lifecycle single source, L0-L3 kept.
  Close奢华收敛: JsPureClose dual overloads share single-source _JsPureHostsClear template, buckets variant adds single Invalidate. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value,
  nextpas.core.js.eval,
  nextpas.core.js.lifecycle;
type
  TJsPureHostRec = nextpas.core.js.pure.host.TJsPureHostRec;
  TJsPureHostArray = nextpas.core.js.pure.host.TJsPureHostArray;
  TJsPureHostBuckets = nextpas.core.js.pure.host.TJsPureHostBuckets;
  TJsPureProp = nextpas.core.js.pure.value.TJsPureProp;
  TJsPureObject = nextpas.core.js.pure.value.TJsPureObject;
  TJsPureHeap = nextpas.core.js.pure.value.TJsPureHeap;
  TJsPureHeapMetrics = nextpas.core.js.pure.value.TJsPureHeapMetrics;
const
  // single source: heap threshold owned by pure.value, eval tokens owned by js.eval
  JS_PURE_HEAP_HASH_THRESHOLD = nextpas.core.js.pure.value.JS_PURE_HEAP_HASH_THRESHOLD;
  JS_PURE_EVAL_WHILE_TRUE = nextpas.core.js.eval.JS_PURE_EVAL_WHILE_TRUE;
  JS_PURE_EVAL_JSON_STRINGIFY = nextpas.core.js.eval.JS_PURE_EVAL_JSON_STRINGIFY;
  JS_PURE_EVAL_MAGIC_X = nextpas.core.js.eval.JS_PURE_EVAL_MAGIC_X;
  JS_PURE_EVAL_BAD = nextpas.core.js.eval.JS_PURE_EVAL_BAD;
  JS_PURE_EVAL_FOO = nextpas.core.js.eval.JS_PURE_EVAL_FOO;
// lifecycle — owner js.lifecycle single source: GPureClosed 64B padded atomic (acquire/release, cache-line isolated, write-once rare, atomic_fetch_add id), intf零可变全局, bulk IsValid零原子 via FValid; pure.base thin-forward inline
function JsPureContextRegister: UInt64; inline;
procedure JsPureContextClose(AId: UInt64); inline;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
// Host — owner pure.host (future js.host) — inline thin-forward, bytes.ops FNV1a single source, per-Context buckets instance-isolated
function JsPureValidateHostName(const AName: string): Boolean; inline;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
// single dispatch template — 3 forms × bucket/non-bucket 12 inline thin forwards converged via _JsPureHostSetDispatch (PBuckets nil=linear, Kind 0/1/2 dispatches Func/Method/Proc), inline zero-copy via host view, bytes.ops FNV1a single source, validated Func/Method/Proc share same dispatch + JsPureCheckHostName single source; Host duties thin-forward to pure.host owner (future js.host), Heap/Value to pure.value (future js.value), IO stays base Level
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); inline; overload;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string); inline; overload;
procedure JsPureHostBucketsInvalidate(var Buckets: TJsPureHostBuckets); inline;
// Heap/Value — owner pure.value (future js.value) — inline thin-forward, bytes.ops+mem.dynarray single source, per-Context TJsPureValueState
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
procedure JsPureHeapMetricsReset; inline;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue; inline;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue; inline;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray; inline;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
procedure JsPureHeapClear(var Heap: TJsPureHeap); inline;
// Batch — owner pure.value (future js.value) — inline thin-forward, threshold >1000 batch vs loop, FNV1a32 pre-hash single source via bytes.ops, SpanEqual zero-copy inline, amortized O(1), SIXDIM P-4
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
function JsPureToJsonString(const AValue: TJsValue): string; inline;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
// Call/Close — thin compose pure.host+pure.value single source, lifecycle via js.lifecycle padded atomic, resource JsPureClose幂等不丢 (single-source _JsPureHostsClear)
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload;
// IO — owner platform.fs L0 (TryEvalFile) 64MiB BytesCopy single source, Eval→js.eval single source
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; inline; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline; overload;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.platform.fs,
  nextpas.core.js.eval;
const
  JS_PURE_FILE_MAX_BYTES = SizeUInt(64) * 1024 * 1024; // 64MiB local L0-aligned, numerically aligned with FORMAT_BULK_PARSE_MAX_BYTES canonical (owner format.limits), no L2→L2, bytes.ops single source via BytesCopy
type
  PJsPureHostBuckets = ^TJsPureHostBuckets;
// single dispatch template — three forms × bucket/non-bucket converged via PHostBuckets nil=linear, Kind dispatches handler type, inline zero-copy via host view, bytes.ops FNV1a single source; 6 overloads converged to one dispatch (PBuckets nil=linear else bucketed), future js.host split ready when >800
procedure _JsPureHostSetDispatch(var Hosts: TJsPureHostArray; Buckets: PJsPureHostBuckets; const AName: string; const AFunc: TJsHostFunction; const AMethod: TJsHostMethod; const AProc: TJsHostProc; AKind: Integer); inline;
begin
  // perf: inline single branch PBuckets nil check, zero-copy host view, bytes.ops single source, no heap alloc
  if Buckets <> nil then
    case AKind of
      0: nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets^, AName, AFunc, AKind);
      1: nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets^, AName, AMethod, AKind);
      2: nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets^, AName, AProc, AKind);
    end
  else
    case AKind of
      0: nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AFunc, AKind);
      1: nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AMethod, AKind);
      2: nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AProc, AKind);
    end;
end;
// single-source hosts clear template — luxury convergence, inline, single Move-free loop, resource not丢
procedure _JsPureHostsClear(var Hosts: TJsPureHostArray); inline;
var I: Integer;
begin
  // perf: inline loop, single source for JsPureClose dual overloads, zero alloc, single branch, string ref release per slot, no duplicate code, bytes.ops not needed (string managed)
  for I := 0 to High(Hosts) do
  begin
    Hosts[I].Name := '';
    Hosts[I].Func := nil;
    Hosts[I].Method := nil;
    Hosts[I].Proc := nil;
    Hosts[I].Hash := 0;
  end;
  SetLength(Hosts, 0);
end;
function JsPureContextRegister: UInt64; inline;
begin Result := nextpas.core.js.lifecycle.JsPureContextRegister; end;
procedure JsPureContextClose(AId: UInt64); inline;
begin nextpas.core.js.lifecycle.JsPureContextClose(AId); end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
begin Result := nextpas.core.js.lifecycle.JsPureContextIsClosed(AId); end;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
begin
  // perf: inline zero-alloc, thread-affine bulk 零原子 via FValid；跨线程强一致时走 acquire 检查 js.lifecycle GPureClosed，单分支
  // note: V.IsValid 本体已改为 FValid 零屏障，此为显式强一致封装供需要跨线程可见性的调用方
  Result := V.IsValid and not nextpas.core.js.lifecycle.JsPureContextIsClosed(V.FContextId);
end;
function JsPureValidateHostName(const AName: string): Boolean; inline;
begin Result := nextpas.core.js.pure.host.JsPureValidateHostName(AName); end;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureFindHost(Hosts, AName); end;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureFindHost(Hosts, Buckets, AName); end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureFindHostView(Hosts, AName); end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureFindHostView(Hosts, Buckets, AName); end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureHostFindOrAlloc(Hosts, AName); end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureHostFindOrAlloc(Hosts, Buckets, AName); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, nil, AName, AHandler, Default(TJsHostMethod), Default(TJsHostProc), AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, nil, AName, Default(TJsHostFunction), AHandler, Default(TJsHostProc), AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, nil, AName, Default(TJsHostFunction), Default(TJsHostMethod), AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, @Buckets, AName, AHandler, Default(TJsHostMethod), Default(TJsHostProc), AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, @Buckets, AName, Default(TJsHostFunction), AHandler, Default(TJsHostProc), AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
begin _JsPureHostSetDispatch(Hosts, @Buckets, AName, Default(TJsHostFunction), Default(TJsHostMethod), AHandler, AKind); end;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
begin Result := nextpas.core.js.pure.host.JsPureCheckHostName(AName, ABackend); end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, nil, AName, AHandler, Default(TJsHostMethod), Default(TJsHostProc), 0); end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, @Buckets, AName, AHandler, Default(TJsHostMethod), Default(TJsHostProc), 0); end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, nil, AName, Default(TJsHostFunction), AHandler, Default(TJsHostProc), 1); end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, @Buckets, AName, Default(TJsHostFunction), AHandler, Default(TJsHostProc), 1); end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, nil, AName, Default(TJsHostFunction), Default(TJsHostMethod), AHandler, 2); end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin JsPureCheckHostName(AName, ABackend); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend); _JsPureHostSetDispatch(Hosts, @Buckets, AName, Default(TJsHostFunction), Default(TJsHostMethod), AHandler, 2); end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); inline;
begin nextpas.core.js.pure.host.JsPureHostRemove(Hosts, AName); end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string); inline;
begin nextpas.core.js.pure.host.JsPureHostRemove(Hosts, Buckets, AName); end;
procedure JsPureHostBucketsInvalidate(var Buckets: TJsPureHostBuckets); inline;
begin nextpas.core.js.pure.host.JsPureHostBucketsInvalidate(Buckets); end;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapMetricsGet; end;
procedure JsPureHeapMetricsReset; inline;
begin nextpas.core.js.pure.value.JsPureHeapMetricsReset; end;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapFind(Heap, Obj); end;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapNewObject(Heap); end;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapNewArray(Heap); end;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapHasProp(Heap, Obj, Name); end;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapDeleteProp(Heap, Obj, Name); end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapGetKeys(Heap, Obj); end;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapGetProp(Heap, Obj, Name); end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
begin nextpas.core.js.pure.value.JsPureHeapSetProp(Heap, Obj, Name, Val); end;
procedure JsPureHeapClear(var Heap: TJsPureHeap); inline;
begin nextpas.core.js.pure.value.JsPureHeapClear(Heap); end;
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := nextpas.core.js.pure.value.JsPureHeapGetBatch(Heap, Objs, AName); end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin nextpas.core.js.pure.value.JsPureHeapSetBatch(Heap, Objs, AName, Vals); end;
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := nextpas.core.js.pure.value.JsPureIsHeapObject(V); end;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
begin Result := nextpas.core.js.pure.value.JsPureNewStringView(AView, AContextId); end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin Result := nextpas.core.js.pure.value.JsPureNewStringView(AView); end;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureNewString(AStr, AContextId); end;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureNewInt(AValue, AContextId); end;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureNewDouble(AValue, AContextId); end;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureNewBool(AValue, AContextId); end;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
begin Result := nextpas.core.js.pure.value.JsPureNewJson(AJson, Heap, AContextId); end;
function JsPureToJsonString(const AValue: TJsValue): string; inline;
begin Result := nextpas.core.js.pure.value.JsPureToJsonString(AValue); end;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
begin Result := nextpas.core.js.pure.value.JsPureToJson(AValue); end;
function JsCategoryFromErrorCategory(const ACategory: TErrorCategory): TJsErrorCategory; inline;
begin
  case ACategory of
    ecParse: Result := jecSyntax;
    ecNullReference: Result := jecReference;
    ecInvalidArgument, ecInvalidOperation: Result := jecType;
    ecNotImplemented, ecNotSupported: Result := jecNotSupported;
    ecTimeout: Result := jecTimeout;
    ecResourceExhausted: Result := jecMemory;
    ecInternal: Result := jecUnknown;
  else Result := jecUnknown; end;
end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  LIdx := JsPureFindHost(Hosts, LName);
  if LIdx < 0 then Exit;
  try
    case Hosts[LIdx].Kind of
      0: Result := Hosts[LIdx].Func(ACtx, AThis, AArgs);
      1: Result := Hosts[LIdx].Method(ACtx, AThis, AArgs);
      2: Result := Hosts[LIdx].Proc(ACtx, AThis, AArgs);
    end;
  except
    on E: EJsError do raise;
    on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
    on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
  end;
end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  LIdx := JsPureFindHost(Hosts, Buckets, LName);
  if LIdx < 0 then Exit;
  try
    case Hosts[LIdx].Kind of
      0: Result := Hosts[LIdx].Func(ACtx, AThis, AArgs);
      1: Result := Hosts[LIdx].Method(ACtx, AThis, AArgs);
      2: Result := Hosts[LIdx].Proc(ACtx, AThis, AArgs);
    end;
  except
    on E: EJsError do raise;
    on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
    on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
  end;
end;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
begin
  JsPureContextClose(AContextId);
  _JsPureHostsClear(Hosts);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
begin
  JsPureContextClose(AContextId);
  _JsPureHostsClear(Hosts);
  JsPureHostBucketsInvalidate(Buckets);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
var LData: Pointer; LLen: PtrUInt; LErr: Int32;
begin
  AText := '';
  Result := False;
  if APath = '' then Exit;
  LData := nil; LLen := 0;
  LErr := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LErr <> 0 then Exit;
  try
    if LLen > JS_PURE_FILE_MAX_BYTES then Exit(False);
    if LLen > 0 then
    begin
      SetLength(AText, LLen);
      // perf: inline single Move via bytes.ops BytesCopy single source, zero-copy Move, single alloc
      BytesCopy(Pointer(AText), LData, LLen);
    end else AText := '';
    Result := True;
  finally
    if LData <> nil then platform_fs_free_buf(LData);
  end;
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; inline;
begin
  // facade inline thin-forward to js.eval single source (table-driven SIMD scan, zero-copy view)
  Result := nextpas.core.js.eval.JsPureDoEval(ACtx, ACode, AOptions, ABackend, Hosts, AGlobal);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline;
begin
  // buckets variant thin-forward reusing same eval single source (host view via buckets)
  Result := nextpas.core.js.eval.JsPureDoEval(ACtx, ACode, AOptions, ABackend, Hosts, Buckets, AGlobal);
end;
end.
