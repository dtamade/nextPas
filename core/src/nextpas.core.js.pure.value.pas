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
// Batch: owner pure.value, pre-hash via bytes.ops, not inline
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
  // inline via JsStringViewValue single source, zero-copy
  if AView.IsEmpty then Result := JsValueBindContext(JsStringValue(''), AContextId)
  else Result := JsValueBindContext(JsStringViewValue(AView.Data, AView.Len), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin
  // inline via JsStringViewValue single source, zero-copy
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
  // single source via json.writer + text.builder/text.escape, not inline
  case AValue.Kind of
    jskUndefined: Exit('undefined');
    jskNull: Exit('null');
    jskBoolean: if AValue.AsBool then Exit('true') else Exit('false');
    jskInteger:
      begin
        // Kind integer mark, zero FPU
        LLen := IntToBuffer(AValue.AsInt, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Exit;
      end;
    jskNumber:
      begin
        // double via FloatToBuffer single source
        LLen := FloatToBuffer(AValue.AsDouble, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Exit;
      end;
    jskString:
      begin
        S := AValue.AsString;
        // fast path: clean string zero-copy via BytesCopy
        if not JsonNeedsEscapeStr(S) then
        begin
          SetLength(Result, Length(S) + 2);
          PAnsiChar(Result)[0] := '"';
          if Length(S) > 0 then BytesCopy(PAnsiChar(Result) + 1, PAnsiChar(S), SizeUInt(Length(S)));
          PAnsiChar(Result)[Length(Result) - 1] := '"';
          Exit;
        end;
        // fallback via TJsonWriter single source, try-finally Done
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
function JsPureValueStateGetProp(const S: TJsPureValueState; const AObj: TJsValue; const AName: string): TJsValue; inline;
begin Result := JsPureHeapGetProp(S.Heap, AObj, AName); end;
procedure JsPureValueStateSetProp(var S: TJsPureValueState; const AObj: TJsValue; const AName: string; const AVal: TJsValue); inline;
begin JsPureHeapSetProp(S.Heap, AObj, AName, AVal); end;
{ Batch: pre-hash via bytes.ops, not inline }
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
var I: Integer; LHash: UInt32; LNeed: SizeUInt;
begin
  // single pre-hash via PropHashStr, not inline
  LNeed := SizeUInt(Length(Objs));
  if LNeed = 0 then Exit(nil);
  LHash := PropHashStr(AName);
  SetLength(Result, LNeed);
  for I := 0 to High(Objs) do
    Result[I] := JsPureHeapGetPropHashed(Heap, Objs[I], AName, LHash);
end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
var I, Idx: Integer; LHash: UInt32; Need: array of Byte;
begin
  // single pre-hash + bulk reserve single probe, not inline
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName);
  // bulk reserve: distinct heap objects need 1 slot each (amortized O(1), single probe per heap)
  SetLength(Need, Length(Heap));
  if Length(Need)>0 then FillChar(Need[0], Length(Need), 0);
  for I:=0 to High(Objs) do
  begin
    Idx:=JsPureHeapFind(Heap, Objs[I]);
    if (Idx>=0) and (JsPureHeapFindPropHashed(Heap[Idx], AName, LHash)<0) then Need[Idx]:=1;
  end;
  for Idx:=0 to High(Need) do if Need[Idx]<>0 then JsPurePropsReserve(Heap[Idx].Props, 1);
  for I := 0 to High(Objs) do
    JsPureHeapSetPropHashed(Heap, Objs[I], AName, LHash, Vals[I]);
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
