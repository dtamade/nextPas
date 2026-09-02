unit nextpas.core.js.pure.base;
{ facade: re-export host/value/eval + compose call/close/io (eval extracted to js.eval, lifecycle extracted to js.lifecycle)
  Note: pure.* pure-family prefix, base shared base suffix — non-standard four-piece naming explicit exception per CONTRACT §1 & design-conventions:150.
  Single responsibility = thin facade only (type-carrier, no mutable globals); lifecycle → js.lifecycle single source (GPureClosed 64B padded atomic acquire/release, cache-line isolated, write-once rare, bulk IsValid zero via FValid, strong acquire, atomic_fetch_add+spinlock geometric via bytes.ops);
  Host→pure.host single source permanent owner (including JsPureHostsClear+JsPureTryReadFileText single source via platform.fs/bytes.ops), Heap/Value→pure.value single source permanent owner, IO→pure.host single source (platform.fs L0 64MiB BytesCopy single source via host), Eval→js.eval single source,
  all inline zero-copy via bytes.ops/text.view single source. wc -l ~280 <800 (800 must-split, 阈值 800), thin forwards via pure.host/pure.value/js.eval/js.lifecycle single source, L0-L3 kept. No threshold migration, pure.host/pure.value permanent single source owner, CONTRACT §1为准.
  Close奢华收敛: JsPureClose dual overloads via pure.host.JsPureHostsClear single source, buckets variant adds single Invalidate; HostSet 12 thin-forwards direct to pure.host (no dispatcher inline branching, I-Cache 不膨胀); JsPureCall dual overloads converged via PBuckets nil template single source. }
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
// lifecycle — owner js.lifecycle single source: GPureClosed 64B padded atomic (acquire/release, cache-line isolated, write-once rare, atomic_fetch_add id), thread affinity JsPureThreadSelf via lifecycle platform.thread single slit; intf零可变全局, bulk IsValid零原子 via FValid; pure.base thin-forward inline zero-copy
function JsPureContextRegister: UInt64; inline;
procedure JsPureContextClose(AId: UInt64); inline;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
// Host — owner pure.host (future js.host) — inline thin-forward, bytes.ops FNV1a single source, per-Context buckets instance-isolated
function JsPureValidateHostName(const AName: string): Boolean; inline;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
// HostSet — 3 forms × bucket/non-bucket 12 inline thin-forwards direct to pure.host single source (no dispatcher inline branching, I-Cache 不膨胀), zero-copy via host view, bytes.ops FNV1a single source, validated via pure.host; Host duties thin-forward to pure.host permanent owner, Heap/Value to pure.value permanent owner, IO via pure.host, no dual entry, single source via pure.* single owner, L0-L3 kept
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
// Heap/Value — owner pure.value permanent single source — inline thin-forward, bytes.ops+mem.dynarray single source, per-Context TJsPureValueState, no js.value dual entry, pure.value single owner, L0-L3 kept
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
// Batch — owner pure.value permanent single source — inline thin-forward, threshold >1000 batch vs loop, FNV1a32 pre-hash single source via bytes.ops, SpanEqual zero-copy inline, amortized O(1), SIXDIM P-4, no js.value dual entry
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
// Call/Close — thin compose pure.host+pure.value single source, lifecycle via js.lifecycle padded atomic, resource JsPureClose幂等不丢 (single-source pure.host.JsPureHostsClear)
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload;
// IO — owner pure.host (platform.fs L0 64MiB BytesCopy single source via host), Eval→js.eval single source
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; inline; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline; overload;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.js.eval;
type
  PJsPureHostBuckets = ^TJsPureHostBuckets;
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
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, AName, AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets, AName, AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets, AName, AHandler, AKind); end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(Hosts, Buckets, AName, AHandler, AKind); end;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
begin Result := nextpas.core.js.pure.host.JsPureCheckHostName(AName, ABackend); end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetFunc(Hosts, AName, AHandler, ABackend); end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetFunc(Hosts, Buckets, AName, AHandler, ABackend); end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetMethod(Hosts, AName, AHandler, ABackend); end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetMethod(Hosts, Buckets, AName, AHandler, ABackend); end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetProc(Hosts, AName, AHandler, ABackend); end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostSetProc(Hosts, Buckets, AName, AHandler, ABackend); end;
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
// PBuckets single template — luxury convergence: dual overloads 42行 95%克隆收敛为 PBuckets nil=linear else bucketed single source, inline零拷贝 via host view, bytes.ops single source, no heap alloc
function _JsPureCallImpl(ACtx: IJsContext; const Hosts: TJsPureHostArray; Buckets: PJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  if Buckets <> nil then LIdx := JsPureFindHost(Hosts, Buckets^, LName) else LIdx := JsPureFindHost(Hosts, LName);
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
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, Hosts, nil, AFunc, AThis, AArgs, ABackend); end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, Hosts, @Buckets, AFunc, AThis, AArgs, ABackend); end;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
begin
  JsPureContextClose(AContextId);
  nextpas.core.js.pure.host.JsPureHostsClear(Hosts);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
begin
  JsPureContextClose(AContextId);
  nextpas.core.js.pure.host.JsPureHostsClear(Hosts);
  JsPureHostBucketsInvalidate(Buckets);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
begin Result := nextpas.core.js.pure.host.JsPureTryReadFileText(APath, AText); end;
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
