unit nextpas.core.js.quickjs.value;
{**
 * @desc QuickJS 双堆装饰器值子模块 — 独立 js.value 语义，沉淀 FHeap 纯堆 + FQjsHeap 镜像 + FGlobal 三元同饰器.
 *       职责显式拆分：pure.base 拥有纯堆单源 (JsPureHeap* via bytes.ops+mem.dynarray)，本模块拥有 QJS 镜像同步 (FQjsHeap 容量/分配/FFI 枚举/镜像 Set/Delete)，
 *       Context 仅持单一 Store 字段，消除双写耦合。守四件套 base←intf←value←门面 与 L0-L3，复用 bytes.ops 单源，热点 inline/零拷贝，资源幂等不丢，CONTRACT 为准缺能力反哺 owner.
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
  TJsQjsValueStore = record
    Heap: TJsPureHeap;
    Global: TJsValue;
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

{ QJS 互转 single source via bytes.ops 零拷贝视图，单缝经 value 持有 Ctx 转换，保持 JSON owner 单源 }
function QjsFromTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; const AVal: TJsValue): TJSQjsValue; inline;
function QjsToTJsValue(const S: TJsQjsValueStore; ACtx: Pointer; ACtxtId: UInt64; const V: TJSQjsValue): TJsValue; inline;
function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
function QjsView(P: PAnsiChar): TStringView; inline;

implementation

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.mem.dynarray;

procedure PokeQjsHeapLen(var AHeap: array of TJSQjsValue; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute AHeap;
begin
  // perf: inline thin-forward to mem.dynarray DynArraySetLength single source (exactly-once geometric), zero-copy header poke, no manual High branch, amortized O(1) via BYTES_BUILDER_MIN_GROW
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;

function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  // perf: inline thin-forward to bytes.ops.AnsiPtrLen single source (zero-copy view length, single scan, no System.StrLen分叉), inline hot path
  Result := nextpas.core.bytes.ops.AnsiPtrLen(P);
end;

function QjsView(P: PAnsiChar): TStringView; inline;
begin
  // perf: inline single scan via QjsCStrLen (bytes.ops AnsiPtrLen single source) → zero-copy TStringView, inline hot path, no重复扫描
  if P = nil then Exit(TStringView.Empty);
  Result := TStringView.Create(P, QjsCStrLen(P));
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
        Idx := JsPureHeapFind(S.Heap, AVal);
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
  // reuse bytes.ops single source + mem.dynarray exactly-once geometric (no双写分支克隆 pure.base): SetLength(LCap) + single poke to ANeed via PokeQjsHeapLen→DynArraySetLength, amortized O(1) via BYTES_BUILDER_MIN_GROW 64→2×, inline zero-copy capacity math
  LOld := Length(S.QjsHeap);
  if LOld >= ANeed then Exit;
  LCap := BytesGrowCapacityInt(LOld, ANeed);
  SetLength(S.QjsHeap, LCap);
  if LCap <> ANeed then PokeQjsHeapLen(S.QjsHeap, SizeUInt(ANeed));
end;

function QjsStoreFind(const S: TJsQjsValueStore; const AObj: TJsValue): Integer; inline;
begin
  Result := JsPureHeapFind(S.Heap, AObj);
end;

function QjsStoreHeapLength(const S: TJsQjsValueStore): Integer; inline;
begin
  Result := Length(S.Heap);
end;

function QjsStoreGlobal(const S: TJsQjsValueStore): TJsValue; inline;
begin
  Result := S.Global;
end;

procedure QjsStoreInit(var S: TJsQjsValueStore; AContextId: UInt64; ARuntime, ACtx: Pointer); inline;
begin
  // owner boundary: pure.base owns Heap alloc, mirror owns QjsHeap sync via FFI single source, bytes.ops+mem single source capacity, inline zero-copy
  S.Global := JsValueBindContext(JsPureHeapNewObject(S.Heap), AContextId);
  SetLength(S.QjsHeap, Length(S.Heap));
  if (Length(S.Heap) > 0) and Assigned(JS_NewObjectPtr) and (ACtx <> nil) then
    S.QjsHeap[High(S.QjsHeap)] := JS_NewObjectPtr(ACtx)
  else if Length(S.QjsHeap) > 0 then
    FillChar(S.QjsHeap[High(S.QjsHeap)], SizeOf(TJSQjsValue), 0);
end;

procedure QjsStoreClear(var S: TJsQjsValueStore; ACtx: Pointer);
var I: Integer;
begin
  // stability: resource release幂等不丢 — QjsHeap逐项JS_FreeValue+Clear, pure heap clear, inline poke single source BYTES_BUILDER_MIN_GROW均摊O1 via SetLength+mem.dynarray poke
  for I := 0 to High(S.QjsHeap) do
    if Assigned(JS_FreeValuePtr) and (ACtx <> nil) then
      JS_FreeValuePtr(ACtx, S.QjsHeap[I]);
  SetLength(S.QjsHeap, 0);
  JsPureHeapClear(S.Heap);
  S.Global := JsUndefinedValue;
end;

procedure QjsStoreSyncNewEntry(var S: TJsQjsValueStore; AIdx: Integer; AIsArray: Boolean; ACtx: Pointer); inline;
var Q: TJSQjsValue;
begin
  // perf: amortized O(1) via BytesGrowCapacityInt single source (BYTES_BUILDER_MIN_GROW 64→2×), mem.dynarray Exactly-Once poke, inline thin-forward, zero-copy header poke
  QjsStoreEnsureCapacity(S, Length(S.Heap));
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
  // perf: FFI真堆枚举经 JS_GetOwnPropertyNames single source (bytes.ops zero-copy AnsiPtrToString), inline path; 资源 exactly-once Free不丢; fallback由调用方接管纯堆
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
  // owner boundary: pure heap already updated by caller via JsPureHeapSetProp; mirror only syncs QjsHeap via FFI single source JS_SetPropertyStr, exactly-once Free不丢, inline zero-copy PAnsiChar view (bytes.ops single source)
  if (AIdx < 0) or (AIdx >= Length(S.QjsHeap)) or not Assigned(JS_SetPropertyStrPtr) or (ACtx = nil) then
  begin
    AIdx := QjsStoreFind(S, S.Global);
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

end.
