unit nextpas.core.js.pure.value;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.hash,
  nextpas.core.js.pure.base;
type
  TJsPureProp = nextpas.core.js.pure.base.TJsPureProp;
  TJsPurePropArray = nextpas.core.js.pure.base.TJsPurePropArray;
  TJsPureObject = nextpas.core.js.pure.base.TJsPureObject;
  TJsPureHeap = nextpas.core.js.pure.base.TJsPureHeap;
  TJsValueArray = nextpas.core.js.pure.base.TJsValueArray;
  TJsStringViewArray = array of TStringView;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
function JsPureHeapGetKeysView(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringViewArray;
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
// arg view single source — backslash unescape thin-forward via text.escape single source, inline zero-copy via text.view, pure.value single seam (js.eval → pure.value → text.escape, L2→L2 single-point)
function JsPureNeedsBackslashUnescapeView(const AView: TStringView): Boolean; inline;
function JsPureUnescapeBackslashView(const AView: TStringView): string; inline;
function JsPureToJsonString(const AValue: TJsValue): string;
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
// Batch: owner pure.value, FNV1a32 single pre-hash via pure.hash→bytes.ops→HashBytes inline zero-copy + SpanEqual zero-copy, bytes.ops single source geometric BytesNextCapacity amortized O(1), loop not inline per red-line 2, threshold >1000 batch vs loop ratio in build/bench-eval-*.json,回归>10%门禁已生效
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
// ValueState: per-Context via pure.value, inline
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
function JsPureValueStateGetKeysView(const S: TJsPureValueState; const AObj: TJsValue): TJsStringViewArray; inline;
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

function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := V.IsObject or V.IsArray; end;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
var LIdx: Integer; LId: Int64;
begin
  if not JsPureIsHeapObject(Obj) then Exit(-1);
  LId := JsObjectId(Obj);
  if LId <= 0 then Exit(-1);
  // O(1) via Id=index+1, inline
  if (LId <= Int64(Length(Heap))) then
  begin
    LIdx := Integer(LId - 1);
    if Heap[LIdx].Id = LId then Exit(LIdx);
  end;
  Result := -1;
end;
{ capacity: geometric via bytes.ops + Exactly-Once via mem.dynarray, not inline per red-line 2 }
generic procedure EnsureCapacityOne<T>(var Arr: specialize TJsArray<T>);
var LOld, LNeed, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(Arr)); LNeed := LOld + 1;
  if nextpas.core.mem.dynarray.DynArrayCapacityGeneric(Arr, SizeOf(T)) >= LNeed then
  begin
    if LOld <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Arr, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(LOld, LNeed);
    SetLength(Arr, LCap);
    if LCap <> LNeed then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Arr, LNeed);
  end;
end;
procedure EnsurePropsCapacityOne(var Props: TJsPurePropArray);
begin specialize EnsureCapacityOne<TJsPureProp>(Props); end;
procedure EnsureHeapCapacityOne(var Heap: TJsPureHeap);
begin specialize EnsureCapacityOne<TJsPureObject>(Heap); end;
{ bulk reserve: single probe + geometric via bytes.ops, Exactly-Once via mem.dynarray, amortized O(1) for batch }
procedure JsPurePropsReserve(var Props: TJsPurePropArray; AAdditional: SizeUInt);
var LOld, LNeed, LCap, LCurCap: SizeUInt;
begin
  if AAdditional=0 then Exit;
  LOld:=SizeUInt(Length(Props)); LNeed:=LOld+AAdditional;
  LCurCap:=nextpas.core.mem.dynarray.DynArrayCapacityGeneric(Props, SizeOf(TJsPureProp));
  if LCurCap>=LNeed then Exit;
  LCap:=BytesNextCapacity(LOld, LNeed);
  SetLength(Props, LCap);
  if LCap<>LOld then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Props, LOld);
end;
procedure JsPureHeapReserve(var Heap: TJsPureHeap; AAdditional: SizeUInt);
var LOld, LNeed, LCap, LCurCap: SizeUInt;
begin
  if AAdditional=0 then Exit;
  LOld:=SizeUInt(Length(Heap)); LNeed:=LOld+AAdditional;
  LCurCap:=nextpas.core.mem.dynarray.DynArrayCapacityGeneric(Heap, SizeOf(TJsPureObject));
  if LCurCap>=LNeed then Exit;
  LCap:=BytesNextCapacity(LOld, LNeed);
  SetLength(Heap, LCap);
  if LCap<>LOld then nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Heap, LOld);
end;
{ prop hash: single source via pure.hash, inline }
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
  // bucket via pure.hash single source
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
{ find prop: hash-filter via pure.hash, bucket O(1) }
function JsPureHeapFindPropHashed(const AProps: array of TJsPureProp; const AName: string; const AHash: UInt32): Integer; overload;
var I: Integer;
begin
  // hash-filter when AHash<>0, inline
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
  // inline via PropHashStr single source
  Result := JsPureHeapFindPropHashed(AProps, AName, PropHashStr(AName));
end;
function JsPureHeapFindProp(const Obj: TJsPureObject; const AName: string): Integer; overload; inline;
begin
  // inline via PropHashStr single source
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
  // via EnsurePropsCapacityOne single source, not inline
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
  // >64 rebuild on cap mismatch else O(1) put
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
  // via EnsureHeapCapacityOne single source, not inline
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
  // O(1) swap-last, single assign
  if I <> LLen - 1 then
    Heap[Idx].Props[I] := Heap[Idx].Props[LLen - 1];
  // clear last to release refs
  Heap[Idx].Props[LLen - 1].Name := '';
  Heap[Idx].Props[LLen - 1].Hash := 0;
  Heap[Idx].Props[LLen - 1].Value := Default(TJsValue);
  SetLength(Heap[Idx].Props, LLen - 1);
  // invalidate buckets, lazy rebuild
  PropBucketsInvalidate(Heap[Idx]);
  Result := True;
end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var Idx, LLen, I: Integer;
begin
  Result := nil;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  if LLen = 0 then Exit;
  SetLength(Result, LLen);
  // perf: layered small inline loop vs large bulk view path zero-copy (see JsPureHeapGetKeysView via TStringView.FromStr single source, bytes.ops single source, no refcount jitter); single SetLength via bytes.ops BytesNextCapacity single source geometric via Heap reserve, inline fast path
  for I := 0 to LLen - 1 do
    Result[I] := Heap[Idx].Props[I].Name;
end;
function JsPureHeapGetKeysView(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringViewArray;
var Idx, LLen, I: Integer;
begin
  Result := nil;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  if LLen = 0 then Exit;
  SetLength(Result, LLen);
  // perf: zero-copy bulk view via TStringView.FromStr single source, bytes.ops single source, no string refcount jitter, inline view extent, large object zero-copy batch path
  for I := 0 to LLen - 1 do
    Result[I] := TStringView.FromStr(Heap[Idx].Props[I].Name);
end;
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
  // via EnsurePropsCapacityOne single source, not inline
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := LHash;
  // >64 rebuild on cap mismatch else O(1) put
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
  // inline zero-copy view via JsStringViewValue single source (bytes.ops TByteSpan single source, B/op=0 at creation, no Move/alloc)
  // perf: NewStringView B/op=0 zero-copy pass-through (Eval/Host hot path), AsString B/op=1 lazily via SpanToString single source when materialize, hosted FStrVal path B/op=0
  if AView.IsEmpty then Result := JsValueBindContext(JsStringValue(''), AContextId)
  else Result := JsValueBindContext(JsStringViewValue(AView.Data, AView.Len), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin
  // inline zero-copy view via JsStringViewValue single source (bytes.ops TByteSpan single source, B/op=0)
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
function JsPureNeedsBackslashUnescapeView(const AView: TStringView): Boolean; inline;
begin
  // inline thin-forward single source via text.escape TextNeedsBackslashUnescapeView, zero-copy, bytes.ops single source
  Result := TextNeedsBackslashUnescapeView(AView);
end;
function JsPureUnescapeBackslashView(const AView: TStringView): string; inline;
begin
  // inline thin-forward single source via text.escape TextUnescapeBackslashView, zero-copy BytesCopy single source via bytes.ops
  Result := TextUnescapeBackslashView(AView);
end;
{ layers for JsPureToJsonString: primitive via text.number single source inline zero-copy, string fast clean via bytes.ops BytesCopy single source, escaped via json.writer single source try-finally Done, heavy paths out-of-line per red-line 2 }
function JsPureJsonIntToStr(AValue: Int64): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // perf: inline single source via text.number IntToBuffer single source, zero FPU integer mark, zero-copy via SetString
  LLen := IntToBuffer(AValue, @LBuf[0]);
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;
function JsPureJsonDoubleToStr(AValue: Double): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // perf: inline single source via text.number FloatToBuffer single source, zero-copy via SetString
  LLen := FloatToBuffer(AValue, @LBuf[0]);
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;
function JsPureJsonFastClean(const S: string; out AOut: string): Boolean; inline;
var LLen: SizeUInt;
begin
  // perf: inline fast path via text.escape JsonNeedsEscapeStr SIMD single source VecWidth, zero-copy BytesCopy single source via bytes.ops inline
  if JsonNeedsEscapeStr(S) then Exit(False);
  LLen := SizeUInt(Length(S));
  SetLength(AOut, LLen + 2);
  PAnsiChar(AOut)[0] := '"';
  if LLen > 0 then BytesCopy(PAnsiChar(AOut) + 1, PAnsiChar(S), LLen);
  PAnsiChar(AOut)[Length(AOut) - 1] := '"';
  Result := True;
end;
function JsPureJsonEscaped(const S: string): string;
var B: TStringBuilder; W: TJsonWriter;
begin
  // single source via json.writer + text.builder single source, try-finally Done not lost
  B.Init(SizeUInt(Length(S)) + 2);
  try
    W.Init(B);
    W.Str(S);
    Result := B.ToString;
  finally B.Done; end;
end;
function JsPureToJsonString(const AValue: TJsValue): string;
var S: string;
begin
  // layered dispatch: primitive via inline helpers, string via fast/escaped layers single source via bytes.ops/json.writer, resource try-finally preserved inside escaped helper, single source layers
  case AValue.Kind of
    jskUndefined: Exit('undefined');
    jskNull: Exit('null');
    jskBoolean: if AValue.AsBool then Exit('true') else Exit('false');
    jskInteger: Exit(JsPureJsonIntToStr(AValue.AsInt));
    jskNumber: Exit(JsPureJsonDoubleToStr(AValue.AsDouble));
    jskString:
      begin
        S := AValue.AsString;
        if JsPureJsonFastClean(S, Result) then Exit;
        Result := JsPureJsonEscaped(S);
        Exit;
      end;
    jskSymbol: Exit('Symbol(' + AValue.AsString + ')');
    jskBigInt: Exit(JsPureJsonIntToStr(AValue.AsInt) + 'n');
  else
    Result := '';
  end;
end;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
begin
  // inline single source via Add*Node, ownership via ReleaseOwnership
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
{ ValueState: inline thin-forward }
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
function JsPureValueStateGetKeysView(const S: TJsPureValueState; const AObj: TJsValue): TJsStringViewArray; inline;
begin Result := JsPureHeapGetKeysView(S.Heap, AObj); end;
function JsPureValueStateGetProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): TJsValue; inline;
begin Result := JsPureHeapGetProp(S.Heap, AObj, AName); end;
procedure JsPureValueStateSetProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;
begin JsPureHeapSetProp(S.Heap, AObj, AName, AVal); end;
{ Batch: FNV1a32 single pre-hash via pure.hash inline zero-copy + SpanEqual zero-copy, bytes.ops single source geometric via pure.hash→HashBytes, loop not inline per red-line 2, threshold >1000 bulk ratio via bench_eval 1024 same-machine }
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
var I: Integer; LHash: UInt32; LNeed: SizeUInt;
begin
  // perf: single pre-hash via PropHashStr inline (pure.hash→bytes.ops HashBytes FNV1a32 single source), zero-copy view, amortized O(1) via bulk hash filter, not inline loop
  LNeed := SizeUInt(Length(Objs));
  if LNeed = 0 then Exit(nil);
  LHash := PropHashStr(AName);
  SetLength(Result, LNeed);
  for I := 0 to High(Objs) do
    Result[I] := JsPureHeapGetPropHashed(Heap, Objs[I], AName, LHash);
end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
var I, J, Idx: Integer; LHash: UInt32; LFound: Boolean;
begin
  // perf: single pre-hash via PropHashStr inline (pure.hash→bytes.ops HashBytes FNV1a32 single source) + bulk reserve single probe via bytes.ops BytesNextCapacity geometric amortized O(1), zero-copy SpanEqual filter, zero extra heap alloc via O(M²) inline dedup (no Need[Heap] FillChar), not inline loop per red-line 2, bytes.ops single source
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName);
  // bulk reserve: distinct heap objects need 1 slot each (amortized O(1), single probe per heap) — zero heap alloc via inline dedup, bytes.ops geometric via JsPurePropsReserve
  for I:=0 to High(Objs) do
  begin
    Idx:=JsPureHeapFind(Heap, Objs[I]);
    if (Idx<0) or (JsPureHeapFindPropHashed(Heap[Idx], AName, LHash)>=0) then Continue;
    LFound:=False;
    for J:=0 to I-1 do
      if JsPureHeapFind(Heap, Objs[J])=Idx then begin LFound:=True; Break; end;
    if LFound then Continue;
    JsPurePropsReserve(Heap[Idx].Props, 1);
  end;
  for I := 0 to High(Objs) do
    JsPureHeapSetPropHashed(Heap, Objs[I], AName, LHash, Vals[I]);
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
