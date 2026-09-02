unit nextpas.core.js.pure.base;
{ facade: thin re-export host/value/eval/lifecycle via pure.host/pure.value/js.eval/js.lifecycle single source
  non-standard four-piece naming exception per CONTRACT §1 & design-conventions:150
  single responsibility = type-carrier + inline thin-forward, no mutable globals
  preferred entry = TJsPureHostState unified (JsPureHostStateSet*), legacy 12 HostSet thin-forwards deprecated compat direct to pure.host
  inline zero-copy via bytes.ops/text.view, L0-L3 kept, wc -l ~310 <800, CONTRACT §1 }
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
  TJsPureHostState = nextpas.core.js.pure.host.TJsPureHostState;
  TJsPureProp = nextpas.core.js.pure.value.TJsPureProp;
  TJsPureObject = nextpas.core.js.pure.value.TJsPureObject;
  TJsPureHeap = nextpas.core.js.pure.value.TJsPureHeap;
const
  // single source: heap threshold owned by pure.value, eval tokens owned by js.eval
  JS_PURE_HEAP_HASH_THRESHOLD = nextpas.core.js.pure.value.JS_PURE_HEAP_HASH_THRESHOLD;
  JS_PURE_EVAL_WHILE_TRUE = nextpas.core.js.eval.JS_PURE_EVAL_WHILE_TRUE;
  JS_PURE_EVAL_JSON_STRINGIFY = nextpas.core.js.eval.JS_PURE_EVAL_JSON_STRINGIFY;
  JS_PURE_EVAL_MAGIC_X = nextpas.core.js.eval.JS_PURE_EVAL_MAGIC_X;
  JS_PURE_EVAL_BAD = nextpas.core.js.eval.JS_PURE_EVAL_BAD;
  JS_PURE_EVAL_FOO = nextpas.core.js.eval.JS_PURE_EVAL_FOO;
// lifecycle — owner js.lifecycle single source, thin-forward inline zero-copy
function JsPureContextRegister: UInt64; inline;
procedure JsPureContextClose(AId: UInt64); inline;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureValueIsValid(const V: TJsValue): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
// Host — owner pure.host, inline thin-forward, bytes.ops FNV1a single source, per-Context buckets
function JsPureValidateHostName(const AName: string): Boolean; inline;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer; inline; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; inline; overload;
// HostSet — legacy compat 12 overloads deprecated, direct to pure.host single source, inline zero-copy; preferred TJsPureHostState unified
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline; deprecated 'use JsPureHostStateSet* via TJsPureHostState';
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetFunc via TJsPureHostState';
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetFunc via TJsPureHostState';
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetMethod via TJsPureHostState';
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetMethod via TJsPureHostState';
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetProc via TJsPureHostState';
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload; deprecated 'use JsPureHostStateSetProc via TJsPureHostState';
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); inline; overload;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string); inline; overload;
procedure JsPureHostBucketsInvalidate(var Buckets: TJsPureHostBuckets); inline;
// HostState — preferred unified entry via TJsPureHostState single source, inline zero-copy, bytes.ops single source, threshold 64 O(1)
function JsPureHostStateFind(var AState: TJsPureHostState; const AName: string): Integer; inline;
function JsPureHostStateFindView(var AState: TJsPureHostState; const AName: TStringView): Integer; inline;
procedure JsPureHostStateClear(var AState: TJsPureHostState); inline;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline;
procedure JsPureHostStateSetFunc(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateSetMethod(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateSetProc(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateRemove(var AState: TJsPureHostState; const AName: string); inline;
// Heap/Value — owner pure.value single source, inline thin-forward, bytes.ops+mem.dynarray single source, per-Context
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue; inline;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue; inline;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean; inline;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray; inline;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
procedure JsPureHeapClear(var Heap: TJsPureHeap); inline;
// Batch — owner pure.value, inline thin-forward, threshold >1000 batch vs loop, FNV1a32 single source via bytes.ops, amortized O(1)
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
// Call/Close — thin compose pure.host+pure.value, lifecycle via js.lifecycle; preferred State unified
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; var AState: TJsPureHostState; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload; inline;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload; deprecated 'use State overload via TJsPureHostState';
procedure JsPureClose(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload; deprecated 'use State overload via TJsPureHostState';
procedure JsPureClose(var AState: TJsPureHostState; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); overload; inline;
// IO — owner pure.host via platform.fs L0 64MiB, Eval→js.eval single source; preferred State
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; inline; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; var AState: TJsPureHostState; const AGlobal: TJsValue): TJsValue; inline; overload;
implementation
uses
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
function JsPureHostStateFind(var AState: TJsPureHostState; const AName: string): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureHostStateFind(AState, AName); end;
function JsPureHostStateFindView(var AState: TJsPureHostState; const AName: TStringView): Integer; inline;
begin Result := nextpas.core.js.pure.host.JsPureHostStateFindView(AState, AName); end;
procedure JsPureHostStateClear(var AState: TJsPureHostState); inline;
begin nextpas.core.js.pure.host.JsPureHostStateClear(AState); end;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(AState.Hosts, AState.Buckets, AName, AHandler, AKind); end;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(AState.Hosts, AState.Buckets, AName, AHandler, AKind); end;
procedure JsPureHostStateSet(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
begin nextpas.core.js.pure.host.JsPureHostSet(AState.Hosts, AState.Buckets, AName, AHandler, AKind); end;
procedure JsPureHostStateSetFunc(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostStateSetFunc(AState, AName, AHandler, ABackend); end;
procedure JsPureHostStateSetMethod(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostStateSetMethod(AState, AName, AHandler, ABackend); end;
procedure JsPureHostStateSetProc(var AState: TJsPureHostState; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin nextpas.core.js.pure.host.JsPureHostStateSetProc(AState, AName, AHandler, ABackend); end;
procedure JsPureHostStateRemove(var AState: TJsPureHostState; const AName: string); inline;
begin nextpas.core.js.pure.host.JsPureHostStateRemove(AState, AName); end;
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
// PBuckets single template — dual overloads converged to PBuckets nil=linear else bucketed, inline zero-copy via host view, bytes.ops single source
function _JsPureCallImpl(ACtx: IJsContext; const Hosts: TJsPureHostArray; Buckets: PJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  if Buckets <> nil then LIdx := JsPureFindHost(Hosts, Buckets^, LName) else LIdx := JsPureFindHost(Hosts, LName);
  if LIdx < 0 then Exit;
  Result := nextpas.core.js.pure.host.JsPureHostInvoke(Hosts[LIdx], ACtx, AThis, AArgs, ABackend);
end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, Hosts, nil, AFunc, AThis, AArgs, ABackend); end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, Hosts, @Buckets, AFunc, AThis, AArgs, ABackend); end;
function JsPureCall(ACtx: IJsContext; var AState: TJsPureHostState; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, AState.Hosts, @AState.Buckets, AFunc, AThis, AArgs, ABackend); end;
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
procedure JsPureClose(var AState: TJsPureHostState; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64); inline;
begin
  JsPureContextClose(AContextId);
  nextpas.core.js.pure.host.JsPureHostStateClear(AState);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
begin Result := nextpas.core.js.pure.host.JsPureTryReadFileText(APath, AText); end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; inline;
begin Result := nextpas.core.js.eval.JsPureDoEval(ACtx, ACode, AOptions, ABackend, Hosts, AGlobal); end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline;
begin Result := nextpas.core.js.eval.JsPureDoEval(ACtx, ACode, AOptions, ABackend, Hosts, Buckets, AGlobal); end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; var AState: TJsPureHostState; const AGlobal: TJsValue): TJsValue; inline;
begin Result := nextpas.core.js.eval.JsPureDoEval(ACtx, ACode, AOptions, ABackend, AState.Hosts, AState.Buckets, AGlobal); end;
end.
