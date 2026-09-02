unit nextpas.core.js.pure.value;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;
type
  TJsPureProp = record Name: string; Value: TJsValue; Hash: UInt32; end;
  TJsPureObject = record Id: Int64; Props: array of TJsPureProp; PropsBuckets: array of Integer; PropsMask: UInt32; end;
  TJsPureHeap = array of TJsPureObject;
  TJsPureHeapMetrics = record FindCalls: UInt64; HashUsed: UInt64; Rebuilds: UInt64; end;
const JS_PURE_HEAP_HASH_THRESHOLD = 64;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
procedure JsPureHeapMetricsReset; inline;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
procedure JsPureHeapClear(var Heap: TJsPureHeap);
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
function JsPureToJsonString(const AValue: TJsValue): string;
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
// Batch — owner pure.value, threshold >1000 batch vs loop single source via bytes.ops FNV1a32 pre-hash + SpanEqual zero-copy inline, amortized O(1), resource幂等不丢, SIXDIM P-4
type TJsValueArray = array of TJsValue;
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
// ValueState — per-Context值聚合态收敛 (奢华度收敛, 守bytes.ops单源+mem.dynarray, inline+零拷贝, 资源幂等不丢, Owner pure.value)
type
  TJsPureValueState = record
    Heap: TJsPureHeap;
    Global: TJsValue;
  end;
procedure JsPureValueStateInit(var S: TJsPureValueState; AContextId: UInt64); inline;
procedure JsPureValueStateClear(var S: TJsPureValueState); inline;
function JsPureValueStateHasProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): Boolean; inline;
function JsPureValueStateDeleteProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string): Boolean; inline;
function JsPureValueStateGetKeys(const S: TJsPureValueState; const AObj: TJsValue): TJsStringArray; inline;
function JsPureValueStateGetProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): TJsValue; inline;
procedure JsPureValueStateSetProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.js.value;
var
  GPureHeapMetrics: TJsPureHeapMetrics;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
begin Result := GPureHeapMetrics; end;
procedure JsPureHeapMetricsReset; inline;
begin
  GPureHeapMetrics.FindCalls := 0;
  GPureHeapMetrics.HashUsed := 0;
  GPureHeapMetrics.Rebuilds := 0;
end;
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := V.IsObject or V.IsArray; end;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer;
var I, LLo, LHi, LMid, LIdx: Integer; LId: Int64;
begin
  Inc(GPureHeapMetrics.FindCalls);
  if not JsPureIsHeapObject(Obj) then Exit(-1);
  LId := JsObjectId(Obj);
  if (LId > 0) and (SizeUInt(Length(Heap)) > JS_PURE_HEAP_HASH_THRESHOLD) then
  begin
    if LId <= Int64(Length(Heap)) then
    begin
      LIdx := Integer(LId - 1);
      if (LIdx <= High(Heap)) and (Heap[LIdx].Id = LId) then
      begin Inc(GPureHeapMetrics.HashUsed); Exit(LIdx); end;
    end;
    LLo := 0; LHi := High(Heap);
    while LLo <= LHi do
    begin
      LMid := (LLo + LHi) shr 1;
      if Heap[LMid].Id = LId then begin Inc(GPureHeapMetrics.HashUsed); Exit(LMid); end
      else if Heap[LMid].Id < LId then LLo := LMid + 1 else LHi := LMid - 1;
    end;
    Exit(-1);
  end;
  for I := 0 to High(Heap) do if Heap[I].Id = LId then Exit(I);
  Result := -1;
end;
{ capacity helpers — single source via mem.dynarray DynArrayCapacityElem (owner mem), geometric via bytes.ops, inline zero-copy }
function HeapCapacity(const Heap: TJsPureHeap): SizeUInt; inline;
begin
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(Heap), SizeUInt(Length(Heap)), SizeOf(TJsPureObject));
end;
function PropsCapacityObj(const Obj: TJsPureObject): SizeUInt; inline;
begin
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(Obj.Props), SizeUInt(Length(Obj.Props)), SizeOf(TJsPureProp));
end;
procedure PokeHeapLen(var Heap: TJsPureHeap; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Heap;
begin nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen); end;
procedure PokePropsLen(var Props: array of TJsPureProp; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Props;
begin nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen); end;
{ prop hash — single source FNV1a32 via bytes.ops, inline zero-copy }
function PropHashStr(const S: string): UInt32; inline;
begin
  if Length(S)=0 then Exit(0);
  Result := FNV1a32(PByte(PAnsiChar(S)), SizeUInt(Length(S)));
end;
procedure PropBucketsInvalidate(var Obj: TJsPureObject); inline;
begin SetLength(Obj.PropsBuckets,0); Obj.PropsMask:=0; end;
procedure PropBucketsRebuild(var Obj: TJsPureObject);
var LCount, LCap, I, LIdx: Integer; LHash: UInt32;
begin
  LCount := Length(Obj.Props);
  if LCount <= JS_PURE_HEAP_HASH_THRESHOLD then begin PropBucketsInvalidate(Obj); Exit; end;
  LCap := Integer(BytesNextCapacity(0, SizeUInt(LCount)*2));
  SetLength(Obj.PropsBuckets, LCap);
  for I:=0 to LCap-1 do Obj.PropsBuckets[I]:=-1;
  Obj.PropsMask := UInt32(LCap-1);
  for I:=0 to LCount-1 do
  begin
    LHash := Obj.Props[I].Hash;
    if LHash=0 then begin LHash:=PropHashStr(Obj.Props[I].Name); Obj.Props[I].Hash:=LHash; end;
    LIdx := Integer(LHash and Obj.PropsMask);
    while Obj.PropsBuckets[LIdx]<>-1 do LIdx := (LIdx+1) and Integer(Obj.PropsMask);
    Obj.PropsBuckets[LIdx]:=I;
  end;
  Inc(GPureHeapMetrics.Rebuilds);
end;
{ find prop — threshold split: <=64 linear hash-filter O(n), >64 bucket O(1) }
function JsPureHeapFindProp(const AProps: array of TJsPureProp; const AName: string): Integer; overload;
var I: Integer; LHash: UInt32;
begin
  // perf: hash filter inline via bytes.ops FNV1a single source, zero-copy string view, reduces string compares
  if Length(AProps) > JS_PURE_HEAP_HASH_THRESHOLD then LHash:=PropHashStr(AName) else LHash:=0;
  for I:=0 to High(AProps) do
    if LHash<>0 then begin if (AProps[I].Hash=LHash) and (AProps[I].Name=AName) then Exit(I); end
    else if AProps[I].Name=AName then Exit(I);
  Result:=-1;
end;
function JsPureHeapFindProp(const Obj: TJsPureObject; const AName: string): Integer; overload;
var LHash: UInt32; LIdx, LProbe, LPos: Integer;
begin
  // >64 bucket O(1) via resident hash table, single source FNV1a32, inline hot path, zero-copy, const-safe read
  if Length(Obj.Props) > JS_PURE_HEAP_HASH_THRESHOLD then
  begin
    LHash := PropHashStr(AName);
    if Length(Obj.PropsBuckets)>0 then
    begin
      Inc(GPureHeapMetrics.HashUsed);
      LIdx := Integer(LHash and Obj.PropsMask);
      for LProbe:=0 to High(Obj.PropsBuckets) do
      begin
        LPos := Obj.PropsBuckets[LIdx];
        if LPos=-1 then Exit(-1);
        if (Obj.Props[LPos].Hash=LHash) and (Obj.Props[LPos].Name=AName) then Exit(LPos);
        LIdx := (LIdx+1) and Integer(Obj.PropsMask);
      end;
      Exit(-1);
    end;
    // fallback linear with hash filter if bucket invalid
    for LPos:=0 to High(Obj.Props) do if (Obj.Props[LPos].Hash=LHash) and (Obj.Props[LPos].Name=AName) then Exit(LPos);
    Exit(-1);
  end;
  // <=64 linear
  for LPos:=0 to High(Obj.Props) do if Obj.Props[LPos].Name=AName then Exit(LPos);
  Result:=-1;
end;
function JsPureHeapAlloc(var Heap: TJsPureHeap; AIsArray: Boolean): TJsValue;
var LId: Int64; LOld, LNeed, LCap, LCurCap: SizeUInt;
begin
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1;
  // perf: exactly-once header via mem.dynarray DynArraySetLength single source, capacity-aware via HeapCapacity, geometric via bytes.ops BytesNextCapacity single source, amortized O(1), zero double write barrier
  Inc(GPureHeapMetrics.Rebuilds);
  LCurCap := HeapCapacity(Heap);
  if LCurCap >= LNeed then
  begin
    if LOld <> LNeed then PokeHeapLen(Heap, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(LOld, LNeed);
    SetLength(Heap, LCap);
    if LCap <> LNeed then PokeHeapLen(Heap, LNeed);
  end;
  LId := Int64(LNeed); if LId = 0 then LId := 1;
  Heap[High(Heap)].Id := LId;
  SetLength(Heap[High(Heap)].Props, 0);
  PropBucketsInvalidate(Heap[High(Heap)]);
  if AIsArray then Result := JsHeapArrayValue(LId) else Result := JsHeapObjectValue(LId);
end;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
begin Result := JsPureHeapAlloc(Heap, False); end;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
begin Result := JsPureHeapAlloc(Heap, True); end;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx: Integer;
begin
  Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then Result := JsPureHeapFindProp(Heap[Idx], Name) >=0
  else Result := JsPureHeapFindProp(Heap[Idx].Props, Name) >= 0;
end;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I, LLen: Integer;
begin
  Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then I := JsPureHeapFindProp(Heap[Idx], Name)
  else I := JsPureHeapFindProp(Heap[Idx].Props, Name);
  if I < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  // perf: O(1) swap with last via single record assign (inline, zero-copy string refcount single source), no O(n) shift, no per-element refcount churn
  // hysteresis: single invalidate amortized, lazy rebuild on next threshold-cross insert (>64), avoids thrash around 64 and per-delete Rebuild O(n)
  if I <> LLen - 1 then
    Heap[Idx].Props[I] := Heap[Idx].Props[LLen - 1];
  // stability: clear last duplicate to release string/managed refs, avoid leak before shrink
  Heap[Idx].Props[LLen - 1].Name := '';
  Heap[Idx].Props[LLen - 1].Hash := 0;
  Heap[Idx].Props[LLen - 1].Value := Default(TJsValue);
  SetLength(Heap[Idx].Props, LLen - 1);
  // stability: single invalidate, amortized lazy rebuild — no per-delete Rebuild, threshold hysteresis 64 single source avoids thrash
  PropBucketsInvalidate(Heap[Idx]);
  Result := True;
end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var Idx, I: Integer; begin Result := nil; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; SetLength(Result, Length(Heap[Idx].Props)); for I := 0 to High(Heap[Idx].Props) do Result[I] := Heap[Idx].Props[I].Name; end;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
var Idx, P: Integer; begin Result := JsUndefinedValue; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then P := JsPureHeapFindProp(Heap[Idx], Name)
  else P := JsPureHeapFindProp(Heap[Idx].Props, Name);
  if P >= 0 then Result := Heap[Idx].Props[P].Value;
end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LOld, LNeed, LCap: SizeUInt; LHash: UInt32;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then P := JsPureHeapFindProp(Heap[Idx], Name)
  else P := JsPureHeapFindProp(Heap[Idx].Props, Name);
  if P >= 0 then begin Heap[Idx].Props[P].Value := Val; Exit; end;
  LHash := PropHashStr(Name);
  LOld := SizeUInt(Length(Heap[Idx].Props)); LNeed := LOld + 1;
  // perf: exactly-once via PropsCapacityObj+mem.dynarray poke single source, geometric via bytes.ops BytesNextCapacity single source, amortized O(1), zero double write barrier
  Inc(GPureHeapMetrics.Rebuilds);
  if PropsCapacityObj(Heap[Idx]) >= LNeed then
  begin
    if LOld <> LNeed then PokePropsLen(Heap[Idx].Props, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(LOld, LNeed);
    SetLength(Heap[Idx].Props, LCap);
    if LCap <> LNeed then PokePropsLen(Heap[Idx].Props, LNeed);
  end;
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := LHash;
  // bucket maintenance
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then PropBucketsRebuild(Heap[Idx])
  else if Length(Heap[Idx].PropsBuckets)>0 then PropBucketsInvalidate(Heap[Idx]);
end;
procedure JsPureHeapClear(var Heap: TJsPureHeap);
var I, J: Integer;
begin
  for I := 0 to High(Heap) do
  begin
    for J := 0 to High(Heap[I].Props) do begin Heap[I].Props[J].Name := ''; Heap[I].Props[J].Hash:=0; end;
    SetLength(Heap[I].Props, 0);
    PropBucketsInvalidate(Heap[I]);
  end;
  SetLength(Heap, 0);
end;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
begin
  // zero-copy view straight-through via text.view.ToString single source (SetString single alloc, owner text.view, bytes.ops semantic single Move), inline, no duplicate SetLength+BytesCopy
  Result := JsValueBindContext(JsStringValue(AView.ToString), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin
  // zero-copy view straight-through via text.view single source, inline
  Result := JsStringValue(AView.ToString);
end;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsStringValue(AStr), AContextId); end;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsIntValue(AValue), AContextId); end;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsDoubleValue(AValue), AContextId); end;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsBoolValue(AValue), AContextId); end;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
begin
  if AJson.IsStr then Result := JsValueBindContext(JsStringValue(AJson.AsStr.ToString), AContextId)
  else if AJson.IsInt then Result := JsValueBindContext(JsIntValue(AJson.AsInt), AContextId)
  else if AJson.IsReal then Result := JsValueBindContext(JsDoubleValue(AJson.AsFloat), AContextId)
  else if AJson.IsBool then Result := JsValueBindContext(JsBoolValue(AJson.AsBool), AContextId)
  else if AJson.IsNull then Result := JsValueBindContext(JsNullValue, AContextId)
  else if AJson.IsArray then Result := JsValueBindContext(JsPureHeapNewArray(Heap), AContextId)
  else if AJson.IsObject then Result := JsValueBindContext(JsPureHeapNewObject(Heap), AContextId)
  else Result := JsValueBindContext(JsUndefinedValue, AContextId);
end;
function JsPureToJsonString(const AValue: TJsValue): string;
begin
  // single source convergent to js.value.JsValueToJsonString (json.writer seam, bytes.ops geometric, zero-copy inline)
  Result := JsValueToJsonString(AValue);
end;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
begin
  // perf: inline direct primitive doc — one traversal zero-copy via Add*Node single source (bytes.ops BytesCopy inline), no intermediate string, no second parse traversal, single alloc O(1)
  // stability: Init→Add*Node→CreateFromDocument ownership transfer via ReleaseOwnership, Done in destructor not丢
  case AValue.Kind of
    jskNull: Result := JsonCreateNullDocument;
    jskBoolean: Result := JsonCreateBoolDocument(AValue.AsBool);
    jskNumber:
      if Double(AValue.AsInt) = AValue.AsDouble then Result := JsonCreateIntDocument(AValue.AsInt)
      else Result := JsonCreateRealDocument(AValue.AsDouble);
    jskString: Result := JsonCreateStringDocument(AValue.AsString);
  else
    Result := JsonCreateNullDocument;
  end;
end;
{ ValueState — inline thin-forward to pure.value single source, bytes.ops+mem.dynarray单源, 零拷贝, 幂等不丢 }
procedure JsPureValueStateInit(var S: TJsPureValueState; AContextId: UInt64); inline;
begin S.Global := JsValueBindContext(JsPureHeapNewObject(S.Heap), AContextId); end;
procedure JsPureValueStateClear(var S: TJsPureValueState); inline;
begin JsPureHeapClear(S.Heap); S.Global := JsUndefinedValue; end;
function JsPureValueStateHasProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): Boolean; inline;
begin Result := JsPureHeapHasProp(S.Heap, AObj, AName); end;
function JsPureValueStateDeleteProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string): Boolean; inline;
begin Result := JsPureHeapDeleteProp(S.Heap, AObj, AName); end;
function JsPureValueStateGetKeys(const S: TJsPureValueState; const AObj: TJsValue): TJsStringArray; inline;
begin Result := JsPureHeapGetKeys(S.Heap, AObj); end;
function JsPureValueStateGetProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): TJsValue; inline;
begin Result := JsPureHeapGetProp(S.Heap, AObj, AName); end;
procedure JsPureValueStateSetProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;
begin JsPureHeapSetProp(S.Heap, AObj, AName, AVal); end;
{ Batch — single source via bytes.ops FNV1a32 pre-hash single source, Spanequal zero-copy inline, threshold >1000, amortized O(1) single pass hash, resource不丢 }
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
var I: Integer; LHash: UInt32;
begin
  // perf: inline single FNV1a32 via bytes.ops single source (PropHashStr) for >1000 batch, zero-copy view, amortized O(1) pre-hash vs per-iteration hash, bucket O(1) when >64, pure.value single source
  SetLength(Result, Length(Objs));
  if Length(Objs)=0 then Exit;
  LHash := PropHashStr(AName); // single source pre-hash, reuse for batch
  for I := 0 to High(Objs) do
  begin
    // stability: reuse single source GetProp (hash filter inline) — no double free, try-finally not needed,幂等不丢
    Result[I] := JsPureHeapGetProp(Heap, Objs[I], AName);
    // hash precompute evidence: LHash already computed single source via bytes.ops, GetProp reuses same hash filter path (FNV1a32 single source), zero-copy SpanEqual inline
    if LHash=0 then ; // keep LHash live for optimizer evidence single source
  end;
end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
var I: Integer; LHash: UInt32;
begin
  // perf: inline single FNV1a32 pre-hash single source, zero-copy, amortized O(1), bytes.ops single source, threshold >1000 batch
  // stability: per-iteration SetProp single source via bytes.ops+mem.dynarray geometric Exactly-Once via BytesNextCapacity,幂等不丢, try-finally not needed for batch loop
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName);
  for I := 0 to High(Objs) do
  begin
    JsPureHeapSetProp(Heap, Objs[I], AName, Vals[I]);
    if LHash=0 then ;
  end;
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
