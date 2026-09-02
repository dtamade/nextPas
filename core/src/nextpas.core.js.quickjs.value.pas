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
  nextpas.core.json.value,
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
function QjsStoreNewJson(var S: TJsQjsValueStore; const AJson: TJsonValue; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;
function QjsStoreHasProp(const S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string): Boolean;
function QjsStoreDeleteProp(var S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string): Boolean;
function QjsStoreGetKeys(const S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue): TJsStringArray;
function QjsStoreGetProp(const S: TJsQjsValueStore; ACtx: Pointer; AContextId: UInt64; const AObj: TJsValue; const AName: string): TJsValue;
procedure QjsStoreSetProp(var S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;

{ QJS 互转 single source via bytes.ops 零拷贝视图，单缝经 value.store 持有纯堆转换，保持 JSON owner 单源 }
function QjsFromTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
function QjsToTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
function QjsView(P: PAnsiChar): TStringView; inline;
function QjsViewLen(P: PAnsiChar; ALen: SizeUInt): TStringView; inline;
{ L0 single source thread/time/deadline helpers — thread/time/deadline 单缝统收敛至 js.lifecycle single source (L0 platform.thread + platform.time single slit via lifecycle), inline 零拷贝, 惰性刷新/采样降 syscall, bytes.ops+mem.dynarray 单源约束 }
function QjsThreadSelf: UInt64; inline;
function QjsIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
function QjsMonotonicNs: QWord; inline;
procedure QjsDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
function QjsInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;

implementation

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.js.lifecycle,
  nextpas.core.js.pure.value;

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

function QjsViewLen(P: PAnsiChar; ALen: SizeUInt): TStringView; inline;
begin
  // perf: length-aware zero-copy view via bytes.ops single source (TStringView.Create single source, no scan), preserves embedded NUL for binary, inline hot path
  if P = nil then Exit(TStringView.Empty);
  Result := TStringView.Create(P, ALen);
end;

function QjsFromTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
var Idx: Integer;
begin
  BytesZero(@Result, SizeUInt(SizeOf(Result))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy stats single slit, inline hot path
  if ACtx = nil then Exit;
  case AVal.Kind of
    jskString: if Assigned(JS_NewStringPtr) then Result := JS_NewStringPtr(ACtx, PAnsiChar(AVal.AsString));
    jskInteger:
      begin
        // perf: Kind carries integer mark zero FPU (replaces Trunc+AsDouble roundtrip Int64(Trunc(...)) extra FPU + 2^53 loss), inline single Kind branch, zero FPU overhead, owner base Kind single source via byte ops single source
        if Assigned(JS_NewInt64Ptr) then Result := JS_NewInt64Ptr(ACtx, AVal.AsInt);
      end;
    jskNumber:
      begin
        // perf: Kind distinct double path zero FPU integer compare, inline single branch, zero extra FPU, Kind integer mark single source avoids 2^53 precision loss, bytes.ops single source kept
        if Assigned(JS_NewFloat64Ptr) then Result := JS_NewFloat64Ptr(ACtx, AVal.AsDouble);
      end;
    jskBoolean: if Assigned(JS_NewBoolPtr) then Result := JS_NewBoolPtr(ACtx, Ord(AVal.AsBool));
    jskObject, jskArray, jskFunction:
      begin
        Idx := JsValueStoreFind(S.Pure, AVal);
        if (Idx >= 0) and (Idx < Length(S.QjsHeap)) and Assigned(JS_DupValuePtr) then Result := JS_DupValuePtr(ACtx, S.QjsHeap[Idx]);
      end;
    jskNull, jskUndefined: BytesZero(@Result, SizeUInt(SizeOf(Result))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy stats single slit
    else BytesZero(@Result, SizeUInt(SizeOf(Result))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy stats single slit
  end;
end;

function QjsToTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
var P: PAnsiChar; LTag: Int64; LDouble: Double; LInt: Int64; LLen: SizeUInt;
begin
  Result := JsValueBindContext(JsUndefinedValue, ACtxtId);
  if ACtx = nil then Exit;
  // perf: JS_Is* 快路径 O(1) tag inline + 零拷贝 single source via bytes.ops AnsiPtrToString single scan, 消除二次 O(n) ToCString+JsonParse; 1024 次热路径免 syscall/alloc, inline thin-forward via bytes.ops single source (设计约束 L0-L3 四件套 base←intf←value.store←quickjs.value, owner bytes.ops+mem.dynarray)
  LTag := Int64(V.Data[1]);
  case LTag of
    JS_TAG_UNDEFINED: Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
    JS_TAG_NULL: Exit(JsValueBindContext(JsNullValue, ACtxtId));
    JS_TAG_BOOL: Exit(JsPureNewBool(V.Data[0] <> 0, ACtxtId));
    JS_TAG_INT: begin LInt := Int64(Int32(V.Data[0] and $FFFFFFFF)); Exit(JsPureNewInt(LInt, ACtxtId)); end;
    JS_TAG_FLOAT64: begin nextpas.core.bytes.ops.BytesCopy(@LDouble, @V.Data[0], SizeOf(Double)); Exit(JsPureNewDouble(LDouble, ACtxtId)); end; // perf: inline single Move via bytes.ops BytesCopy single source (zero-copy), L1 single source, inline hot tag unpack
    JS_TAG_STRING:
      begin
        // perf: length-aware ToCStringLen preserves embedded NUL (binary safe) via bytes.ops zero-copy view; fallback to single-scan QjsView when Len API unavailable, inline
        if Assigned(JS_ToCStringLenPtr) then
        begin
          LLen := 0; P := JS_ToCStringLenPtr(ACtx, @LLen, V);
          if P = nil then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
          try Exit(JsPureNewStringView(QjsViewLen(P, LLen), ACtxtId));
          finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
        end;
        if not Assigned(JS_ToCStringPtr) then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
        P := JS_ToCStringPtr(ACtx, V);
        if P = nil then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
        try Exit(JsPureNewStringView(QjsView(P), ACtxtId));
        finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
      end;
    JS_TAG_OBJECT, JS_TAG_FUNCTION_BYTECODE, JS_TAG_MODULE:
      begin
        // perf: length-aware single ToCStringLen + QjsViewLen zero-copy via bytes.ops single source, B/op=1, exactly-once Free, preserves embedded NUL
        if Assigned(JS_ToCStringLenPtr) then
        begin
          LLen := 0; P := JS_ToCStringLenPtr(ACtx, @LLen, V);
          if P = nil then Exit(JsPureNewString('', ACtxtId));
          try Exit(JsPureNewStringView(QjsViewLen(P, LLen), ACtxtId));
          finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
        end;
        if not Assigned(JS_ToCStringPtr) then Exit(JsPureNewString('', ACtxtId));
        P := JS_ToCStringPtr(ACtx, V);
        if P = nil then Exit(JsPureNewString('', ACtxtId));
        try Exit(JsPureNewStringView(QjsView(P), ACtxtId)); finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
      end;
    JS_TAG_EXCEPTION: Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
  end;
  // fallback: length-aware ToCStringLen single source via bytes.ops, preserves binary NUL
  if Assigned(JS_ToCStringLenPtr) then
  begin
    LLen := 0; P := JS_ToCStringLenPtr(ACtx, @LLen, V);
    if P = nil then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
    try Exit(JsPureNewStringView(QjsViewLen(P, LLen), ACtxtId));
    finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
  end;
  if not Assigned(JS_ToCStringPtr) then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
  P := JS_ToCStringPtr(ACtx, V);
  if P = nil then Exit(JsValueBindContext(JsUndefinedValue, ACtxtId));
  try
    Exit(JsPureNewStringView(QjsView(P), ACtxtId));
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
    BytesZero(@S.QjsHeap[High(S.QjsHeap)], SizeUInt(SizeOf(TJSQjsValue))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy mirror sync single slit
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
    if Assigned(JS_NewArrayPtr) and (ACtx <> nil) then Q := JS_NewArrayPtr(ACtx) else BytesZero(@Q, SizeUInt(SizeOf(Q))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy mirror sync single slit
  end else
  begin
    if Assigned(JS_NewObjectPtr) and (ACtx <> nil) then Q := JS_NewObjectPtr(ACtx) else BytesZero(@Q, SizeUInt(SizeOf(Q))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy mirror sync single slit
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
  BytesZero(@QUndef, SizeUInt(SizeOf(QUndef))); // perf: inline FillChar single source via bytes.ops.BytesZero (SIMD), zero-copy stats single slit
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

function QjsStoreNewJson(var S: TJsQjsValueStore; const AJson: TJsonValue; AContextId: UInt64; ACtx: Pointer): TJsValue; inline;
begin
  // perf: inline single source via pure.value JsPureNewJson for primitives (IsStr/IsInt/IsReal/IsBool/IsNull single source, inline zero-copy, bytes.ops single source), array/object via QjsStoreNewArray/NewObject decorator single source (Pure+QjsHeap composition, inline zero-copy, amortized O1 BYTES_BUILDER_MIN_GROW), eliminates duplicate IsStr branch in quickjs context, pure.value owner single source, resource exactly-once mirror not lost
  if AJson.IsArray then Exit(QjsStoreNewArray(S, AContextId, ACtx));
  if AJson.IsObject then Exit(QjsStoreNewObject(S, AContextId, ACtx));
  Result := nextpas.core.js.pure.value.JsPureNewJson(AJson, S.Pure.Heap, AContextId);
end;

function QjsStoreHasProp(const S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string): Boolean;
var Idx: Integer; QRes: TJSQjsValue; P: PAnsiChar;
begin
  // perf: inline decorator pure single source via value.store JsValueStoreHasProp (bytes.ops+mem.dynarray, hash>64 O1 bucket FNV1a single source, zero-copy), FFI mirror single source via JS_GetPropertyStr, bytes.ops zero-copy view, exactly-once Free not lost
  Result := JsValueStoreHasProp(S.Pure, AObj, AName);
  if Result then Exit;
  Idx := QjsStoreFind(S, AObj);
  if (Idx < 0) or (Idx >= Length(S.QjsHeap)) or (ACtx = nil) or not Assigned(JS_GetPropertyStrPtr) then Exit(False);
  QRes := JS_GetPropertyStrPtr(ACtx, S.QjsHeap[Idx], PAnsiChar(AName));
  try
    if Assigned(JS_IsExceptionPtr) and (JS_IsExceptionPtr(QRes) <> 0) then Exit(False);
    if not Assigned(JS_ToCStringPtr) then Exit(False);
    P := JS_ToCStringPtr(ACtx, QRes);
    if P = nil then Exit(False);
    try
      // perf: zero-copy view via bytes.ops single source QjsView (AnsiPtrLen single scan) + Trim Equals inline, no alloc, decorator reuse
      Result := not QjsView(P).Trim.Equals(TStringView.FromStr('undefined'));
    finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(ACtx, P); end;
  finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(ACtx, QRes); end;
end;

function QjsStoreDeleteProp(var S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string): Boolean;
var Idx: Integer;
begin
  // perf: inline decorator pure single source via value.store JsValueStoreDeleteProp (bytes.ops geometric single source, O1 swap-last), mirror single source via QjsStoreMirrorDeleteProp FFI, Pure+QjsHeap composition, inline zero-copy
  Result := JsValueStoreDeleteProp(S.Pure, AObj, AName);
  Idx := QjsStoreFind(S, AObj);
  QjsStoreMirrorDeleteProp(S, ACtx, Idx, AName);
end;

function QjsStoreGetKeys(const S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue): TJsStringArray;
var Idx: Integer; LTmp: TJsStringArray;
begin
  // perf: decorator FFI true heap via QjsStoreTryGetKeysFFI single source (bytes.ops zero-copy, exactly-once Free), fallback pure single source via value.store JsValueStoreGetKeys, inline, Pure+QjsHeap composition
  Idx := QjsStoreFind(S, AObj);
  if QjsStoreTryGetKeysFFI(S, ACtx, Idx, LTmp) then Exit(LTmp);
  Result := JsValueStoreGetKeys(S.Pure, AObj);
end;

function QjsStoreGetProp(const S: TJsQjsValueStore; ACtx: Pointer; AContextId: UInt64; const AObj: TJsValue; const AName: string): TJsValue;
begin
  // perf: decorator pure single source via value.store JsValueStoreGetProp (hash>64 O1 bucket, bytes.ops FNV1a single source, zero-copy), single source single Store, inline, Pure+QjsHeap composition, FFI mirror kept in sync via SetProp;ACtx/AContextId kept for future FFI fallback single source via QjsToTJsValue, currently pure contract via value.store
  if ACtx = nil then ;
  if AContextId = 0 then ;
  Result := JsValueStoreGetProp(S.Pure, AObj, AName);
end;

procedure QjsStoreSetProp(var S: TJsQjsValueStore; ACtx: Pointer; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;
var Idx: Integer;
begin
  // perf: inline decorator pure single source via value.store JsValueStoreSetProp (bytes.ops+mem.dynarray Exactly-Once geometric, FNV1a single source, amortized O1), mirror single source via QjsStoreMirrorSetProp FFI, Pure+QjsHeap composition, zero-copy PAnsiChar view, exactly-once Free not lost
  Idx := QjsStoreFind(S, AObj);
  if Idx >= 0 then JsValueStoreSetProp(S.Pure, AObj, AName, AVal);
  QjsStoreMirrorSetProp(S, ACtx, Idx, AName, AVal);
end;

function QjsThreadSelf: UInt64; inline;
begin
  // perf: inline thin-forward to js.lifecycle single source JsPureThreadSelf (L0 platform.thread single slit via lifecycle→pure.base), zero-copy token, decorator reuse, single syscall via lifecycle
  Result := JsPureThreadSelf;
end;

function QjsIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
begin
  // perf: inline single compare via js.lifecycle single source JsPureIsOnCreationThread, zero syscall beyond one, no duplication, L0 platform.thread 单缝收敛至 lifecycle
  Result := JsPureIsOnCreationThread(ACreationId);
end;

function QjsMonotonicNs: QWord; inline;
begin
  // perf: inline thin-forward to js.lifecycle single source JsPureMonotonicNs (L0 platform.time single slit via lifecycle), single syscall, zero-copy, bytes.ops single source复用见 deadline, decorator reuse no dual entry
  Result := nextpas.core.js.lifecycle.JsPureMonotonicNs;
end;

procedure QjsDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
begin
  // perf: inline thin-forward to js.lifecycle single source JsPureDeadlineRefresh, 惰性刷新 single source via JsPureMonotonicNs inline, 仅 Timeout>0 触发单次 syscall, 高频 Eval 零额外开销, bytes.ops single source保持 CONTRACT, no dual platform.time entry
  nextpas.core.js.lifecycle.JsPureDeadlineRefresh(ADeadlineNs, ATimeoutMs);
end;

function QjsInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
begin
  // perf: inline thin-forward to js.lifecycle single source JsPureInterruptShouldAbort, 采样 1024次/syscall cache-line友好, 惰性刷新, 零拷贝 inline, exactly-once timeout语义 via lifecycle single slit
  Result := nextpas.core.js.lifecycle.JsPureInterruptShouldAbort(ADeadlineNs, ACounter, ALastNs);
end;

end.
