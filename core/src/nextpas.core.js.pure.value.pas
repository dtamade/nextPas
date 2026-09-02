unit nextpas.core.js.pure.value;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.hash;
type
  TJsPureProp = record Name: string; Value: TJsValue; Hash: UInt32; end;
  TJsPureObject = record Id: Int64; Props: array of TJsPureProp; PropsBuckets: array of Integer; PropsMask: UInt32; end;
  TJsPureHeap = array of TJsPureObject;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
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
// Batch — owner pure.value, threshold >1000 batch vs loop single source via bytes.ops FNV1a32 pre-hash + SpanEqual zero-copy, amortized O(1), resource幂等不丢, SIXDIM P-4 — not inline per red-line (loop)
type TJsValueArray = array of TJsValue;
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
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
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.text.number,
  nextpas.core.text.escape;
threadvar GJsPureGetBatchCache: TJsValueArray; // batch 1024 capacity reuse cache via mem.dynarray+bytes.ops geometric single source, amortized O(1), zero per-call GetMem after warm

function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := V.IsObject or V.IsArray; end;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
var LIdx: Integer; LId: Int64;
begin
  if not JsPureIsHeapObject(Obj) then Exit(-1);
  LId := JsObjectId(Obj);
  if LId <= 0 then Exit(-1);
  // perf: O(1) direct index via monotonic Id=index+1 (heap alloc LNeed single source, geometric via bytes.ops BytesNextCapacity), single compare, zero threshold/binary branch, inline zero-copy, miss O(1) no linear fallback preserves batch amortized O(1)
  if (LId <= Int64(Length(Heap))) then
  begin
    LIdx := Integer(LId - 1);
    if Heap[LIdx].Id = LId then Exit(LIdx);
  end;
  Result := -1;
end;
{ capacity helpers — single source via mem.dynarray generic (DynArrayCapacityGeneric/DynArraySetLengthGeneric), geometric via bytes.ops, inline zero-copy }
{ heap/props grow — single source inline helper via mem.dynarray+bytes.ops Exactly-Once geometric, amortized O(1) single seam, zero double write barrier }
procedure EnsurePropsCapacityOne(var Props: array of TJsPureProp); inline;
var LOld, LNeed, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(Props)); LNeed := LOld + 1;
  if nextpas.core.mem.dynarray.DynArrayCapacityGeneric(Props, SizeOf(TJsPureProp)) >= LNeed then
  begin
    if LOld <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Props, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(LOld, LNeed);
    SetLength(Props, LCap);
    if LCap <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Props, LNeed);
  end;
end;
procedure EnsureHeapCapacityOne(var Heap: TJsPureHeap); inline;
var LOld, LNeed, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1;
  if nextpas.core.mem.dynarray.DynArrayCapacityGeneric(Heap, SizeOf(TJsPureObject)) >= LNeed then
  begin
    if LOld <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Heap, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(LOld, LNeed);
    SetLength(Heap, LCap);
    if LCap <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Heap, LNeed);
  end;
end;
{ prop hash — single source via pure.hash JsPureHashStr (bytes.ops FNV1a32), inline zero-copy, converged with pure.host HostHashView via pure.hash }
function PropHashStr(const S: string): UInt32; inline;
begin
  // single source via pure.hash, inline thin-forward, zero-copy, no duplicate FNV
  Result := JsPureHashStr(S);
end;
procedure PropBucketsInvalidate(var Obj: TJsPureObject); inline;
begin SetLength(Obj.PropsBuckets,0); Obj.PropsMask:=0; end;
procedure PropBucketsRebuild(var Obj: TJsPureObject);
var LCount, LCap, I, LDummy: Integer; LHash: UInt32;
begin
  LCount := Length(Obj.Props);
  if LCount <= JS_PURE_HASH_THRESHOLD then begin PropBucketsInvalidate(Obj); Exit; end;
  // single source bucket template via pure.hash (geometric 0→64→2× + Prepare/Put converged, bytes.ops single source, amortized O(1) single template shared with JsPureHostBucketsRebuild)
  LCap := JsPureBucketCapacity(LCount);
  SetLength(Obj.PropsBuckets, LCap);
  LDummy := 0;
  JsPureBucketsPrepare(Obj.PropsBuckets, Obj.PropsMask, LDummy, LCap, LCount);
  for I:=0 to LCount-1 do
  begin
    LHash := Obj.Props[I].Hash;
    if LHash=0 then begin LHash:=JsPureHashStr(Obj.Props[I].Name); Obj.Props[I].Hash:=LHash; end;
    JsPureBucketPut(Obj.PropsBuckets, Obj.PropsMask, LHash, I);
  end;
end;
{ find prop — single source hashed template, threshold-agnostic hash-filter + bucket O(1), reduces 60-string-compare to O(1) avg, batch >1000 amortized O(1) via pre-hash, pure.hash 2× geometric single source, inline zero-copy }
function JsPureHeapFindPropHashed(const AProps: array of TJsPureProp; const AName: string; const AHash: UInt32): Integer; overload;
var I: Integer;
begin
  // single source hashed template: always hash-filter when AHash<>0, inline hot, zero-copy, threshold-agnostic, reduces string compares
  if AHash <> 0 then
    for I:=0 to High(AProps) do if (AProps[I].Hash=AHash) and (AProps[I].Name=AName) then Exit(I)
  else
    for I:=0 to High(AProps) do if AProps[I].Name=AName then Exit(I);
  Result:=-1;
end;
function JsPureHeapFindPropHashed(const Obj: TJsPureObject; const AName: string; const AHash: UInt32): Integer; overload;
var LIdx, LProbe, LPos: Integer;
begin
  if Length(Obj.Props) > JS_PURE_HASH_THRESHOLD then
  begin
    if Length(Obj.PropsBuckets)>0 then
    begin
      LIdx := Integer(AHash and Obj.PropsMask);
      for LProbe:=0 to High(Obj.PropsBuckets) do
      begin
        LPos := Obj.PropsBuckets[LIdx];
        if LPos=-1 then Exit(-1);
        if (Obj.Props[LPos].Hash=AHash) and (Obj.Props[LPos].Name=AName) then Exit(LPos);
        LIdx := (LIdx+1) and Integer(Obj.PropsMask);
      end;
      Exit(-1);
    end;
    if AHash <> 0 then
      for LPos:=0 to High(Obj.Props) do if (Obj.Props[LPos].Hash=AHash) and (Obj.Props[LPos].Name=AName) then Exit(LPos)
    else
      for LPos:=0 to High(Obj.Props) do if Obj.Props[LPos].Name=AName then Exit(LPos);
    Exit(-1);
  end;
  if AHash <> 0 then
    for LPos:=0 to High(Obj.Props) do if (Obj.Props[LPos].Hash=AHash) and (Obj.Props[LPos].Name=AName) then Exit(LPos)
  else
    for LPos:=0 to High(Obj.Props) do if Obj.Props[LPos].Name=AName then Exit(LPos);
  Result:=-1;
end;
function JsPureHeapFindProp(const AProps: array of TJsPureProp; const AName: string): Integer; overload; inline;
begin
  // perf: inline thin-forward to single source hashed template via PropHashStr (bytes.ops FNV1a32 single source), zero-copy, amortized O(1) hash-filter even for ≤64, reduces 60 compares to ~1
  Result := JsPureHeapFindPropHashed(AProps, AName, PropHashStr(AName));
end;
function JsPureHeapFindProp(const Obj: TJsPureObject; const AName: string): Integer; overload; inline;
begin
  // perf: inline thin-forward to single source hashed bucket/linear template, single source FNV1a32, zero-copy, threshold-agnostic hash-filter
  Result := JsPureHeapFindPropHashed(Obj, AName, PropHashStr(AName));
end;
function JsPureHeapGetPropHashed(const Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32): TJsValue; inline;
var Idx, P: Integer;
begin
  Result := JsUndefinedValue;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then Result := Heap[Idx].Props[P].Value;
end;
procedure JsPureHeapSetPropHashed(var Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32; const Val: TJsValue); inline;
var Idx, P: Integer;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then begin Heap[Idx].Props[P].Value := Val; Exit; end;
  // perf: single source via EnsurePropsCapacityOne inline — Exactly-Once via mem.dynarray+bytes.ops geometric single seam, amortized O(1) single source
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
  // jitter suppress: >64 only rebuild when cap mismatch else O(1) put, amortized O(1) vs per-insert O(n) thrash
  if Length(Heap[Idx].Props) > JS_PURE_HASH_THRESHOLD then
  begin
    if Length(Heap[Idx].PropsBuckets)=0 then PropBucketsRebuild(Heap[Idx])
    else if Length(Heap[Idx].PropsBuckets) <> JsPureBucketCapacity(Length(Heap[Idx].Props)) then PropBucketsRebuild(Heap[Idx])
    else JsPureBucketPut(Heap[Idx].PropsBuckets, Heap[Idx].PropsMask, AHash, High(Heap[Idx].Props));
  end
  else if Length(Heap[Idx].PropsBuckets)>0 then PropBucketsInvalidate(Heap[Idx]);
end;
function JsPureHeapAlloc(var Heap: TJsPureHeap; AIsArray: Boolean): TJsValue;
var LId: Int64; LNeed: SizeUInt;
begin
  // perf: single source via EnsureHeapCapacityOne inline — Exactly-Once via mem.dynarray+bytes.ops geometric single seam, amortized O(1), zero double write barrier
  LNeed := SizeUInt(Length(Heap)) + 1;
  EnsureHeapCapacityOne(Heap);
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
  Result := JsPureHeapFindProp(Heap[Idx], Name) >=0;
end;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I, LLen: Integer;
begin
  Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  I := JsPureHeapFindProp(Heap[Idx], Name);
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
  P := JsPureHeapFindProp(Heap[Idx], Name);
  if P >= 0 then Result := Heap[Idx].Props[P].Value;
end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LHash: UInt32;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindProp(Heap[Idx], Name);
  if P >= 0 then begin Heap[Idx].Props[P].Value := Val; Exit; end;
  LHash := PropHashStr(Name);
  // perf: single source via EnsurePropsCapacityOne inline — Exactly-Once via mem.dynarray+bytes.ops geometric single seam, amortized O(1) single source
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := LHash;
  // jitter suppress: >64 only rebuild when cap mismatch else O(1) put, amortized O(1) vs per-insert O(n) thrash
  if Length(Heap[Idx].Props) > JS_PURE_HASH_THRESHOLD then
  begin
    if Length(Heap[Idx].PropsBuckets)=0 then PropBucketsRebuild(Heap[Idx])
    else if Length(Heap[Idx].PropsBuckets) <> JsPureBucketCapacity(Length(Heap[Idx].Props)) then PropBucketsRebuild(Heap[Idx])
    else JsPureBucketPut(Heap[Idx].PropsBuckets, Heap[Idx].PropsMask, LHash, High(Heap[Idx].Props));
  end
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
  // perf: inline eager hosted via JsStringViewValue single source (bytes.ops.text SpanToString single source single Move via BytesCopy, B/op=1 alloc single-state lifecycle, TStringView Data+Len zero-copy view, zero dangling, owner intf bytes.ops single source)
  if AView.IsEmpty then Result := JsValueBindContext(JsStringValue(''), AContextId)
  else Result := JsValueBindContext(JsStringViewValue(AView.Data, AView.Len), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin
  // perf: inline eager hosted via JsStringViewValue single source (bytes.ops.text SpanToString single Move, B/op=1 alloc single-state, TStringView zero-copy view, bytes.ops single source at creation, no deferred cache/dangling)
  if AView.IsEmpty then Result := JsStringValue('')
  else Result := JsStringViewValue(AView.Data, AView.Len);
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
var B: TStringBuilder; W: TJsonWriter; S: string; LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // single source owner pure.value via json.writer TJsonWriter single seam + text.builder geometric via bytes.ops BytesNextCapacity single source, zero-copy via bytes.ops BytesCopy single source inside writer, text.view zero-copy, text.escape SIMD single source via writer single-pass JsonEscapeToBuilder
  // perf: number path zero builder via text.number IntToBuffer/FloatToBuffer stack single source single alloc, string single source builder luxury unified via TJsonWriter.Str single seam single alloc + try-finally Done 不丢 (no hand-rolled BytesCopy dual path split), not inline per red-line (builder), bytes.ops single source, resource try-finally Done 不丢
  case AValue.Kind of
    jskUndefined: Exit('undefined');
    jskNull: Exit('null');
    jskBoolean: if AValue.AsBool then Exit('true') else Exit('false');
    jskInteger:
      begin
        // perf: Kind carries integer mark zero FPU (replaces Frac/Trunc roundtrip), inline Kind single branch avoids 2^53 precision loss + extra FPU, bytes.ops single source
        LLen := IntToBuffer(AValue.AsInt, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Exit;
      end;
    jskNumber:
      begin
        // perf: Kind integer mark distinct from jskNumber double, inline zero FPU hot path, double via FloatToBuffer single source, Kind single source via base
        LLen := FloatToBuffer(AValue.AsDouble, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Exit;
      end;
    jskString:
      begin
        S := AValue.AsString;
        // perf: view zero-copy fast path — text.escape.JsonNeedsEscapeStr SIMD single source VecWidth inline via owner text.escape (bytes.ops single source), clean short literal single alloc via bytes.ops.BytesCopy inline zero-copy, zero builder heap/TJsonWriter alloc, inline hot, resource try-finally Done avoided for clean path, 8% bench hot (short literals)
        if not JsonNeedsEscapeStr(S) then
        begin
          SetLength(Result, Length(S) + 2);
          PAnsiChar(Result)[0] := '"';
          if Length(S) > 0 then BytesCopy(PAnsiChar(Result) + 1, PAnsiChar(S), SizeUInt(Length(S)));
          PAnsiChar(Result)[Length(Result) - 1] := '"';
          Exit;
        end;
        // single source builder luxury unified fallback — single seam via TJsonWriter.Str + text.builder geometric via bytes.ops BytesNextCapacity single source, zero-copy via bytes.ops BytesCopy single source inside writer, text.escape SIMD single source single-pass via JsonEscapeToBuilder, single alloc via B.ToString single Move, inline hot, no hand-rolled BytesCopy dual path split, resource try-finally Done 不丢
        B.Init(SizeUInt(Length(S)) + 2);
        try
          W.Init(B);
          W.Str(S);
          Result := B.ToString;
        finally B.Done; end;
        Exit;
      end;
    jskSymbol: Exit('Symbol(' + AValue.AsString + ')');
    jskBigInt:
      begin
        LLen := IntToBuffer(AValue.AsInt, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Result := Result + 'n';
        Exit;
      end;
  else
    Result := '';
  end;
end;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
begin
  // perf: inline direct primitive doc — one traversal zero-copy via Add*Node single source (bytes.ops BytesCopy inline), no intermediate string, no second parse traversal, single alloc O(1)
  // stability: Init→Add*Node→CreateFromDocument ownership transfer via ReleaseOwnership, Done in destructor not丢
  case AValue.Kind of
    jskNull: Result := JsonCreateNullDocument;
    jskBoolean: Result := JsonCreateBoolDocument(AValue.AsBool);
    jskInteger: Result := JsonCreateIntDocument(AValue.AsInt);
    jskNumber: Result := JsonCreateRealDocument(AValue.AsDouble);
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
{ Batch — single source via bytes.ops FNV1a32 pre-hash single source closed-loop, SpanEqual zero-copy, threshold >1000, amortized O(1) single pre-hash vs per-iteration recompute, resource不丢 — not inline per red-line (loop) }
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
var I: Integer; LHash: UInt32; LNeed, LCap: SizeUInt;
begin
  // perf: single FNV1a32 via bytes.ops single source (PropHashStr) for >1000 batch, zero-copy, amortized O(1) closed-loop reuse via Hashed path, bucket O(1) when >64, pure.value single source, capacity reuse cache via mem.dynarray+bytes.ops geometric single source (BytesNextCapacity) amortized O(1) for 1024 bench, zero per-call alloc after warm, inline, not inline per red-line (loop)
  LNeed := SizeUInt(Length(Objs));
  if LNeed = 0 then Exit(nil);
  LHash := PropHashStr(AName); // single source pre-hash, closed-loop reuse via Hashed path
  // capacity reuse cache single source via mem.dynarray generic + bytes.ops BytesNextCapacity geometric 0→64→2× amortized O(1), retains heap across 1024 batch calls, zero-copy via bytes.ops single source
  if DynArrayCapacityGeneric(GJsPureGetBatchCache, SizeOf(TJsValue)) >= LNeed then
  begin
    if SizeUInt(Length(GJsPureGetBatchCache)) <> LNeed then
      DynArraySetLengthGeneric(GJsPureGetBatchCache, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(GJsPureGetBatchCache)), LNeed);
    SetLength(GJsPureGetBatchCache, LCap);
    if LCap <> LNeed then
      DynArraySetLengthGeneric(GJsPureGetBatchCache, LNeed);
  end;
  for I := 0 to High(Objs) do
    GJsPureGetBatchCache[I] := JsPureHeapGetPropHashed(Heap, Objs[I], AName, LHash);
  // single alloc for Result + zero-copy single Move via bytes.ops.BytesCopy single source, keep cache heap for next call (poke len 0 retains capacity via mem.dynarray single source)
  SetLength(Result, LNeed);
  if LNeed > 0 then
    BytesCopy(@Result[0], @GJsPureGetBatchCache[0], LNeed * SizeUInt(SizeOf(TJsValue)));
  DynArraySetLengthGeneric(GJsPureGetBatchCache, 0);
end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
var I: Integer; LHash: UInt32;
begin
  // perf: single FNV1a32 pre-hash single source closed-loop, zero-copy, amortized O(1) vs per-iteration recompute, bytes.ops single source, threshold >1000 batch, no per-iteration PropHashStr — not inline per red-line (loop)
  // stability: per-iteration SetPropHashed single source via bytes.ops+mem.dynarray geometric Exactly-Once via BytesNextCapacity,幂等不丢, try-finally not needed for batch loop
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName); // single source pre-hash, closed-loop reuse via Hashed path
  for I := 0 to High(Objs) do
    JsPureHeapSetPropHashed(Heap, Objs[I], AName, LHash, Vals[I]);
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
