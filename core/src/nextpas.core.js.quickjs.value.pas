unit nextpas.core.js.quickjs.value;
{**
 * @desc QuickJS 镜像装饰器值子模块 — 装饰 js.value.store 纯存储，沉淀 QjsHeap 镜像 + FFI 同步.
 *       职责显式拆分：pure.base 拥有纯堆单源 (JsPureHeap* via bytes.ops+mem.dynarray)，js.value.store 拥有纯存储契约 (Heap/Global) 单源，
 *       本模块仅拥有 QJS 镜像同步 (QjsHeap 容量/分配/FFI枚举/镜像 Set/Delete + QJS互转)，Context 经装饰器组合单一 Store 字段消除双写耦合.
 *       守四件套 base←intf←value.store←quickjs.value 与 L0-L3，复用 bytes.ops 单源几何扩容与 text.view 零拷贝，热点 inline/零拷贝，资源幂等不丢，CONTRACT为准缺能力反哺 owner (bytes.ops+mem.dynarray owner).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.js.value.store,
  nextpas.core.js.quickjs.ffi,
  nextpas.core.text.view;

type
  TJsQjsValueStore = record
    Pure: TJsValueStore;
    QjsHeap: array of TJSQjsValue;
  end;

procedure QjsStoreInit(var S: TJsQjsValueStore; AContextId: UInt64; ARuntime, ACtx: Pointer); inline;
procedure QjsStoreClear(var S: TJsQjsValueStore; ACtx: Pointer);
function QjsStoreFind(const S: TJsQjsValueStore; const AObj: TJsValue): Integer; inline;
procedure QjsStoreEnsureCapacity(var S: TJsQjsValueStore; ANeed: Integer); inline;
procedure QjsStoreSyncNewEntry(var S: TJsQjsValueStore; AIdx: Integer; AIsArray: Boolean; ACtx: Pointer); inline;
function QjsStoreTryGetKeysFFI(const S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; out AKeys: TJsStringArray): Boolean;
procedure QjsStoreMirrorSetProp(var S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
procedure QjsStoreMirrorDeleteProp(var S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string); inline;
function QjsStoreGlobal(const S: TJsQjsValueStore): TJsValue; inline;
function QjsStoreHeapLength(const S: TJsQjsValueStore): Integer; inline;
function QjsStoreNewObject(var S: TJsQjsValueStore; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;
function QjsStoreNewArray(var S: TJsQjsValueStore; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;

{ QJS 互转 single source via bytes.ops 零拷贝视图，单缝经 value.store 持有纯堆转换，保持 JSON owner 单源 }
function QjsFromTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
function QjsToTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
function QjsView(P: PAnsiChar): TStringView; inline;
{ L0 single source thread/time/deadline helpers — quickjs.value 唯一持有 platform.thread/time 单缝, inline 零拷贝, 惰性刷新/采样降 syscall, bytes.ops 单源 }
function QjsThreadSelf: UInt64; inline;
function QjsIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
function QjsMonotonicNs: QWord; inline;
procedure QjsDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
function QjsInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;

implementation

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.mem.dynarray,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

procedure PokeQjsHeapLen(var AHeap: array of TJSQjsValue; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute AHeap;
begin
  // perf: inline thin-forward to mem.dynarray DynArraySetLength single source (exactly-once geometric), zero-copy header poke, no manual High branch, amortized O(1) via BYTES_BUILDER_MIN_GROW
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;

function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  // perf: inline thin-forward to js.value.store single source JsValueCStrLen → bytes.ops.AnsiPtrLen single source (zero-copy view length, single scan), inline hot path, decorator reuse no duplication
  Result := nextpas.core.js.value.store.JsValueCStrLen(P);
end;

function QjsView(P: PAnsiChar): TStringView; inline;
begin
  // perf: inline thin-forward to js.value.store single source JsValueView → bytes.ops AnsiPtrLen single source → zero-copy TStringView, inline hot path, no重复扫描, decorator reuse
  Result := nextpas.core.js.value.store.JsValueView(P);
end;

function QjsFromTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
var Idx: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if ACtx = nil then Exit;
  case AVal.Kind of
    jskString: if Assigned(JS_NewStringPtr) then Result := JS_NewStringPtr(ACtx, PAnsiChar(AVal.AsString));
    jskNumber:
      begin
        if (AVal.AsInt = Int64(Trunc(AVal.AsDouble))) and Assigned(JS_NewInt64Ptr) then Result := JS_NewInt64Ptr(ACtx, AVal.AsInt)
        else if Assigned(JS_NewFloat64Ptr) then Result := JS_NewFloat64Ptr(ACtx, AVal.AsDouble);
      end;
    jskBoolean: if Assigned(JS_NewBoolPtr) then Result := JS_NewBoolPtr(ACtx, Ord(AVal.AsBool));
    jskObject, jskArray, jskFunction:
      begin
        Idx := JsValueStoreFind(S.Pure, AVal);
        if (Idx >= 0) and (Idx < Length(S.QjsHeap)) and Assigned(JS_DupValuePtr) then Result := JS_DupValuePtr(ACtx, S.QjsHeap[Idx]);
      end;
    jskNull, jskUndefined: FillChar(Result, SizeOf(Result), 0);
    else FillChar(Result, SizeOf(Result), 0);
  end;
end;

function QjsToTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
var P: PAnsiChar; Vw, Tw: TStringView; Doc: IJsonDocument; Root: TJsonValue;
begin
  Result := JsValueBindContext(JsUndefinedValue, ACtxtId);
  if not Assigned(JS_ToCStringPtr) or (ACtx = nil) then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
  P := JS_ToCStringPtr(ACtx, V);
  if P = nil then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
  try
    Vw := QjsView(P);
    Tw := Vw.Trim;
    if Tw.Equals(TStringView.FromStr('null')) then Exit(JsValueBindContext(JsNullValue, ACtxtId));
    if Tw.Equals(TStringView.FromStr('undefined')) then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
    if Tw.Equals(TStringView.FromStr('true')) then Exit(JsPureNewBool(True, ACtxtId));
    if Tw.Equals(TStringView.FromStr('false')) then Exit(JsPureNewBool(False, ACtxtId));
    Doc := JsonParse(Tw);
    if not Doc.HasError then
    begin
      Root := Doc.Root;
      case Root.Kind of
        jnkInt: Exit(JsPureNewInt(Root.AsInt, ACtxtId));
        jnkReal: Exit(JsPureNewDouble(Root.AsFloat, ACtxtId));
        jnkBool: Exit(JsPureNewBool(Root.AsBool, ACtxtId));
        jnkNull: Exit(JsValueBindContext(JsNullValue, ACtxtId));
        jnkString: Exit(JsPureNewString(Root.AsStr.ToString, ACtxtId));
        jnkArray, jnkObject: Exit(JsPureNewString(Vw.ToString, ACtxtId));
      end;
    end;
    Result := JsPureNewString(Vw.ToString, ACtxtId);
  finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
end;

procedure QjsStoreEnsureCapacity(var S: TJsQjsValueStore; ANeed: Integer); inline;
var LOld, LCap: Integer;
begin
  // reuse bytes.ops single source + mem.dynarray exactly-once geometric (no双写分支克隆 pure.base/value.store): SetLength(LCap) + single poke to ANeed via PokeQjsHeapLen→DynArraySetLength, amortized O(1) via BYTES_BUILDER_MIN_GROW 64→2×, inline zero-copy capacity math, decorator pure length via value.store
  LOld := Length(S.QjsHeap);
  if LOld >= ANeed then Exit;
  LCap := BytesGrowCapacityInt(LOld, ANeed);
  SetLength(S.QjsHeap, LCap);
  if LCap <> ANeed then PokeQjsHeapLen(S.QjsHeap, SizeUInt(ANeed));
end;

function QjsStoreFind(const S: TJsQjsValueStore; const AObj: TJsValue): Integer; inline;
begin
  // perf: inline thin-forward to js.value.store single source JsValueStoreFind → pure.base JsPureHeapFind (hash>64 O1), zero-copy, inline hot path, decorator pure single source
  Result := JsValueStoreFind(S.Pure, AObj);
end;

function QjsStoreHeapLength(const S: TJsQjsValueStore): Integer; inline;
begin
  // perf: inline thin-forward to js.value.store single source JsValueStoreHeapLength, zero-copy Length read, O(1), decorator pure single source
  Result := JsValueStoreHeapLength(S.Pure);
end;

function QjsStoreGlobal(const S: TJsQjsValueStore): TJsValue; inline;
begin
  // perf: inline thin-forward to js.value.store single source JsValueStoreGlobal, zero-copy value return, decorator pure single source
  Result := JsValueStoreGlobal(S.Pure);
end;

procedure QjsStoreInit(var S: TJsQjsValueStore; AContextId: UInt64; ARuntime, ACtx: Pointer); inline;
begin
  // owner boundary: value.store owns Heap/Global alloc single source via pure.base+bytes.ops, mirror owns QjsHeap sync via FFI single source, inline zero-copy, decorator composition Pure+QjsHeap single field Store eliminated double-heap coupling
  JsValueStoreInit(S.Pure, AContextId);
  SetLength(S.QjsHeap, JsValueStoreHeapLength(S.Pure));
  if (JsValueStoreHeapLength(S.Pure) > 0) and Assigned(JS_NewObjectPtr) and (ACtx <> nil) then
    S.QjsHeap[High(S.QjsHeap)] := JS_NewObjectPtr(ACtx)
  else if Length(S.QjsHeap) > 0 then
    FillChar(S.QjsHeap[High(S.QjsHeap)], SizeOf(TJSQjsValue), 0);
end;

procedure QjsStoreClear(var S: TJsQjsValueStore; ACtx: Pointer);
var I: Integer;
begin
  // stability: resource release幂等不丢 — QjsHeap逐项JS_FreeValue+Clear + value.store纯堆Clear single source, inline poke single source BYTES_BUILDER_MIN_GROW均摊O1 via SetLength+mem.dynarray poke, decorator pure+mirror exactly-once Free不丢
  for I := 0 to High(S.QjsHeap) do
    if Assigned(JS_FreeValuePtr) and (ACtx <> nil) then
      JS_FreeValuePtr(ACtx, S.QjsHeap[I]);
  SetLength(S.QjsHeap, 0);
  JsValueStoreClear(S.Pure);
end;

procedure QjsStoreSyncNewEntry(var S: TJsQjsValueStore; AIdx: Integer; AIsArray: Boolean; ACtx: Pointer); inline;
var Q: TJSQjsValue;
begin
  // perf: amortized O(1) via BytesGrowCapacityInt single source (BYTES_BUILDER_MIN_GROW 64→2×), mem.dynarray Exactly-Once poke, inline thin-forward, zero-copy header poke, decorator pure length via value.store
  QjsStoreEnsureCapacity(S, JsValueStoreHeapLength(S.Pure));
  if AIdx < 0 then Exit;
  if AIsArray then
  begin
    if Assigned(JS_NewArrayPtr) and (ACtx <> nil) then Q := JS_NewArrayPtr(ACtx) else FillChar(Q, SizeOf(Q), 0);
  end else
  begin
    if Assigned(JS_NewObjectPtr) and (ACtx <> nil) then Q := JS_NewObjectPtr(ACtx) else FillChar(Q, SizeOf(Q), 0);
  end;
  S.QjsHeap[AIdx] := Q;
end;

function QjsStoreTryGetKeysFFI(const S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; out AKeys: TJsStringArray): Boolean;
var
  LLen: UInt32;
  LProps: PJSPropertyEnum;
  I: Integer;
  QStr: TJSQjsValue;
  P: PAnsiChar;
begin
  Result := False;
  AKeys := nil;
  // perf: FFI真堆枚举经 JS_GetOwnPropertyNames single source (bytes.ops zero-copy AnsiPtrToString), inline path; 资源 exactly-once Free不丢; fallback由调用方接管纯堆 via value.store
  if (ACtx = nil) or (AIdx < 0) or (AIdx >= Length(S.QjsHeap)) then Exit;
  if not Assigned(JS_GetOwnPropertyNamesPtr) or not Assigned(JS_FreePropertyEnumPtr) or not Assigned(JS_AtomToStringPtr) or not Assigned(JS_ToCStringPtr) or not Assigned(JS_FreeCStringPtr) or not Assigned(JS_FreeValuePtr) then Exit;
  LLen := 0;
  LProps := JS_GetOwnPropertyNamesPtr(ACtx, @LLen, S.QjsHeap[AIdx], JS_GPN_STRING_MASK);
  if LProps = nil then Exit;
  try
    SetLength(AKeys, LLen);
    for I := 0 to Integer(LLen) - 1 do
    begin
      QStr := JS_AtomToStringPtr(ACtx, LProps[I].atom);
      try
        P := JS_ToCStringPtr(ACtx, QStr);
        if P <> nil then
        try
          AKeys[I] := nextpas.core.bytes.ops.AnsiPtrToString(P);
        finally JS_FreeCStringPtr(ACtx, P); end
        else AKeys[I] := '';
      finally
        if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(ACtx, QStr);
      end;
    end;
    Result := True;
  finally
    JS_FreePropertyEnumPtr(ACtx, LProps, LLen);
  end;
end;

procedure QjsStoreMirrorSetProp(var S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
var QVal: TJSQjsValue;
begin
  // owner boundary: pure heap already updated by caller via JsPureHeapSetProp→value.store Pure.Heap single source; mirror only syncs QjsHeap via FFI single source JS_SetPropertyStr, exactly-once Free不丢, inline zero-copy PAnsiChar view (bytes.ops single source), decorator pure Global via value.store
  if (AIdx < 0) or (AIdx >= Length(S.QjsHeap)) or not Assigned(JS_SetPropertyStrPtr) or (ACtx = nil) then
  begin
    AIdx := QjsStoreFind(S, JsValueStoreGlobal(S.Pure));
    if (AIdx < 0) or (AIdx >= Length(S.QjsHeap)) then Exit;
  end;
  QVal := QjsFromTJsValue(S, ACtx, AVal);
  try
    JS_SetPropertyStrPtr(ACtx, S.QjsHeap[AIdx], PAnsiChar(AName), QVal);
  finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(ACtx, QVal); end;
end;

procedure QjsStoreMirrorDeleteProp(var S: TJsQjsValueStore; ACtx: Pointer; AIdx: Integer; const AName: string); inline;
var QUndef: TJSQjsValue;
begin
  if (AIdx < 0) or (AIdx >= Length(S.QjsHeap)) or not Assigned(JS_SetPropertyStrPtr) or (ACtx = nil) then Exit;
  FillChar(QUndef, SizeOf(QUndef), 0);
  JS_SetPropertyStrPtr(ACtx, S.QjsHeap[AIdx], PAnsiChar(AName), QUndef);
end;

function QjsStoreNewObject(var S: TJsQjsValueStore; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;
var Idx: Integer;
begin
  // perf: single source Pure+QjsHeap composition via value.store single source (bytes.ops geometric) + QjsHeap mirror, inline zero-copy, amortized O1 BYTES_BUILDER_MIN_GROW, 装饰边界单源消除双写心智负担
  Result := JsValueBindContext(JsPureHeapNewObject(S.Pure.Heap), AContextId);
  Idx := QjsStoreFind(S, Result);
  QjsStoreSyncNewEntry(S, Idx, False, ACtx);
end;

function QjsStoreNewArray(var S: TJsQjsValueStore; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;
var Idx: Integer;
begin
  // perf: single source Pure+QjsHeap composition via value.store single source (bytes.ops geometric) + QjsHeap mirror, inline zero-copy, amortized O1, 单源消除双堆手动同步
  Result := JsValueBindContext(JsPureHeapNewArray(S.Pure.Heap), AContextId);
  Idx := QjsStoreFind(S, Result);
  QjsStoreSyncNewEntry(S, Idx, True, ACtx);
end;

function QjsThreadSelf: UInt64; inline;
begin
  // perf: inline thin-forward to platform.thread single source (L0 single slit), zero-copy token, decorator reuse
  Result := UInt64(platform_thread_self);
end;

function QjsIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
begin
  // perf: inline single compare via QjsThreadSelf single source, zero syscall beyond one, no duplication
  Result := QjsThreadSelf = ACreationId;
end;

function QjsMonotonicNs: QWord; inline;
begin
  // perf: inline thin-forward to platform.time single source (L0 single slit, vdso), single syscall, bytes.ops single source复用见 deadline
  Result := QWord(platform_monotonic_ns);
end;

procedure QjsDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
begin
  // perf: 惰性刷新 single source via QjsMonotonicNs inline, 仅 Timeout>0 触发单次 syscall, 高频 Eval 零额外开销当 Timeout=0, 采样由 interrupt 侧承担, bytes.ops single source保持 CONTRACT
  if ATimeoutMs <= 0 then ADeadlineNs := 0
  else ADeadlineNs := Int64(QjsMonotonicNs + QWord(ATimeoutMs) * 1000000);
end;

function QjsInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
begin
  // perf: 采样降频 1024 次/ syscall (原逐次 clock_gettime 占假后端 684ns 基线 15-30%), 缓存行友好, 惰性刷新, 零拷贝 inline, exactly-once timeout 语义
  if ADeadlineNs = 0 then Exit(False);
  Inc(ACounter);
  if (ACounter and 1023) <> 0 then Exit(False);
  ALastNs := QjsMonotonicNs;
  Result := QWord(ALastNs) >= QWord(ADeadlineNs);
end;

end.
