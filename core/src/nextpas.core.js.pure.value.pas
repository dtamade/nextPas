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
  TJsValueArray = array of TJsValue;
  TJsStringViewArray = array of TStringView;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
function JsPureHeapGetKeysView(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringViewArray; inline;
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
// text.escape single source
function JsPureNeedsBackslashUnescapeView(const AView: TStringView): Boolean; inline;
function JsPureUnescapeBackslashView(const AView: TStringView): string; inline;
function JsPureIsQuotedView(const AView: TStringView): Boolean; inline;
function JsPureStripOuterQuotesView(const AView: TStringView): TStringView; inline;
function JsPureToJsonString(const AValue: TJsValue): string;
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
// Batch: pure.hash single source, loop not inline
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
{ bytes.ops single source — geometric via BytesDynReserve/BytesDynEnsureLength single source (owner L1 bytes.ops → L0 mem.dynarray probe/poke single slit, BYTES_BUILDER_MIN_GROW 64→2× amortized O(1)), host/pure shared single source via bytes.ops thin-forward, no generic copy, no TBytes absolute alias, heap layout encapsulated in mem.dynarray, inline thin-forward zero-copy }
procedure JsPurePropsReserve(var Props: TJsPurePropArray; AAdditional: SizeUInt); inline;
begin
  if AAdditional=0 then Exit;
  nextpas.core.bytes.ops.BytesDynReserve(Props, SizeOf(TJsPureProp), AAdditional);
end;
procedure JsPureHeapReserve(var Heap: TJsPureHeap; AAdditional: SizeUInt); inline;
begin
  if AAdditional=0 then Exit;
  nextpas.core.bytes.ops.BytesDynReserve(Heap, SizeOf(TJsPureObject), AAdditional);
end;
procedure EnsurePropsCapacityOne(var Props: TJsPurePropArray); inline;
begin
  nextpas.core.bytes.ops.BytesDynEnsureLength(Props, SizeOf(TJsPureProp), SizeUInt(Length(Props))+1);
end;
procedure EnsureHeapCapacityOne(var Heap: TJsPureHeap); inline;
begin
  nextpas.core.bytes.ops.BytesDynEnsureLength(Heap, SizeOf(TJsPureObject), SizeUInt(Length(Heap))+1);
end;
// helpers to keep base zero-dep: value stored as Raw+Kind string, owner pure.value converts via TJsValue single source, text.number single source via IntToBuffer/FloatToBuffer zero-copy inline locale-independent (no SysUtils), bytes.ops single source via BytesCopy
function ValueRawOf(const V: TJsValue): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  case V.Kind of
    jskString, jskSymbol: Result := V.AsString;
    jskInteger, jskBigInt: begin LLen := IntToBuffer(V.AsInt, @LBuf[0]); SetString(Result, PAnsiChar(@LBuf[0]), LLen); end;
    jskNumber: begin LLen := FloatToBuffer(V.AsDouble, @LBuf[0]); SetString(Result, PAnsiChar(@LBuf[0]), LLen); end;
    jskBoolean: if V.AsBool then Result := 'true' else Result := 'false';
    jskNull: Result := 'null';
    jskUndefined: Result := 'undefined';
    jskObject, jskArray: begin LLen := IntToBuffer(JsObjectId(V), @LBuf[0]); SetString(Result, PAnsiChar(@LBuf[0]), LLen); end;
    jskFunction: Result := JsFunctionName(V);
    jskError: Result := V.AsString;
    jskPromise: Result := '';
    else Result := V.AsString;
  end;
end;
function ValueKindOf(const V: TJsValue): Integer; inline;
begin
  Result := Ord(V.Kind);
end;
function RawToValue(const Raw: string; AKind: Integer): TJsValue; inline;
var K: TJsValueKind; LView: TStringView; VInt: Int64; VDouble: Double;
begin
  K := TJsValueKind(AKind);
  LView := TStringView.FromStr(Raw);
  case K of
    jskString: Result := JsStringValue(Raw);
    jskSymbol: Result := JsSymbolValue(Raw);
    jskInteger: begin if not ViewToInt64(LView, VInt) then VInt:=0; Result := JsIntValue(VInt); end;
    jskBigInt: begin if not ViewToInt64(LView, VInt) then VInt:=0; Result := JsBigIntValue(VInt); end;
    jskNumber: begin if not ViewToDouble(LView, VDouble) then VDouble:=0; Result := JsDoubleValue(VDouble); end;
    jskBoolean: Result := JsBoolValue(Raw='true');
    jskNull: Result := JsNullValue;
    jskUndefined: Result := JsUndefinedValue;
    jskObject: begin if not ViewToInt64(LView, VInt) then VInt:=0; Result := JsHeapObjectValue(VInt); end;
    jskArray: begin if not ViewToInt64(LView, VInt) then VInt:=0; Result := JsHeapArrayValue(VInt); end;
    jskFunction: Result := JsFunctionValue(Raw);
    jskError: Result := JsErrorValue(Raw);
    jskPromise: Result := JsPromiseValue;
    else Result := JsStringValue(Raw);
  end;
end;
// batch reserved single source — assume BytesDynReserve(1) already done per deduped Idx, poke via mem.dynarray single source without second BytesDynEnsureLength probe, amortized O(1) halved 2048→1024 probes for 1024 batch
procedure JsPureHeapSetPropHashedReserved(var Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32; const Val: TJsValue); inline;
var Idx, P: Integer; LOld: SizeUInt;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then begin Heap[Idx].Props[P].Raw := ValueRawOf(Val); Heap[Idx].Props[P].Kind := ValueKindOf(Val); Exit; end;
  LOld := SizeUInt(Length(Heap[Idx].Props));
  // capacity guaranteed by prior JsPurePropsReserve(1) via bytes.ops → mem.dynarray probe, poke without second probe
  nextpas.core.mem.dynarray.DynArraySetLengthGeneric(Heap[Idx].Props, LOld + 1);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Raw := ValueRawOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Kind := ValueKindOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
  if Length(Heap[Idx].Props) > JS_PURE_HASH_THRESHOLD then
  begin
    if Length(Heap[Idx].PropsBuckets)=0 then PropBucketsRebuild(Heap[Idx])
    else if Length(Heap[Idx].PropsBuckets) <> JsPureBucketCapacity(Length(Heap[Idx].Props)) then PropBucketsRebuild(Heap[Idx])
    else JsPureBucketPut(Heap[Idx].PropsBuckets, Heap[Idx].PropsMask, AHash, High(Heap[Idx].Props));
  end
  else if Length(Heap[Idx].PropsBuckets)>0 then PropBucketsInvalidate(Heap[Idx]);
end;
function PropHashStr(const S: string): UInt32; inline;
begin
  Result := JsPureHashStr(S);
end;
procedure PropBucketsInvalidate(var Obj: TJsPureObject); inline;
begin SetLength(Obj.PropsBuckets,0); Obj.PropsMask:=0; end;
function PropBucketFindPos(const Obj: TJsPureObject; AHash: UInt32; AIdx: Integer): Integer;
var LPos, LProbe: Integer;
begin
  if Length(Obj.PropsBuckets)=0 then Exit(-1);
  LPos := Integer(AHash and Obj.PropsMask);
  for LProbe:=0 to High(Obj.PropsBuckets) do
  begin
    if Obj.PropsBuckets[LPos]=AIdx then Exit(LPos);
    if Obj.PropsBuckets[LPos]=-1 then Exit(-1);
    LPos := (LPos+1) and Integer(Obj.PropsMask);
  end;
  Result:=-1;
end;
procedure PropBucketDeletePos(var Obj: TJsPureObject; ADelPos: Integer);
var LCur, LRe: Integer; LHash: UInt32;
begin
  Obj.PropsBuckets[ADelPos]:=-1;
  LCur := (ADelPos+1) and Integer(Obj.PropsMask);
  while Obj.PropsBuckets[LCur]<>-1 do
  begin
    LRe := Obj.PropsBuckets[LCur];
    if (LRe<0) or (LRe>=Length(Obj.Props)) then
    begin
      Obj.PropsBuckets[LCur]:=-1;
      LCur := (LCur+1) and Integer(Obj.PropsMask);
      Continue;
    end;
    LHash := Obj.Props[LRe].Hash;
    Obj.PropsBuckets[LCur]:=-1;
    JsPureBucketPut(Obj.PropsBuckets, Obj.PropsMask, LHash, LRe);
    LCur := (LCur+1) and Integer(Obj.PropsMask);
  end;
end;
procedure PropBucketsRebuild(var Obj: TJsPureObject);
var LCount, I, LDummy: Integer; LHash: UInt32;
begin
  LCount := Length(Obj.Props);
  LDummy := 0;
  if not JsPureBucketsTryRebuild(Obj.PropsBuckets, Obj.PropsMask, LDummy, LCount) then Exit;
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
  Result := JsPureHeapFindPropHashed(AProps, AName, PropHashStr(AName));
end;
function JsPureHeapFindProp(const Obj: TJsPureObject; const AName: string): Integer; overload; inline;
begin
  Result := JsPureHeapFindPropHashed(Obj, AName, PropHashStr(AName));
end;
function JsPureHeapGetPropHashed(const Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32): TJsValue; inline;
var Idx, P: Integer;
begin
  Result := JsUndefinedValue;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then Result := RawToValue(Heap[Idx].Props[P].Raw, Heap[Idx].Props[P].Kind);
end;
procedure JsPureHeapSetPropHashed(var Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32; const Val: TJsValue); inline;
var Idx, P: Integer;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then begin Heap[Idx].Props[P].Raw := ValueRawOf(Val); Heap[Idx].Props[P].Kind := ValueKindOf(Val); Exit; end;
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Raw := ValueRawOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Kind := ValueKindOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
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
var Idx, I, LLen, LNew, LPosMoved, LPosRemoved: Integer; LHashRemoved, LHashMoved: UInt32; LWasValid: Boolean;
begin
  Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  I := JsPureHeapFindProp(Heap[Idx], Name);
  if I < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  // capture hashes before swap for O(1) incremental patch (pure.host parity, amortized O(1) vs O(n) rebuild)
  LWasValid := Length(Heap[Idx].PropsBuckets)>0;
  LHashRemoved := Heap[Idx].Props[I].Hash;
  if I <> LLen-1 then LHashMoved := Heap[Idx].Props[LLen-1].Hash else LHashMoved:=0;
  // O(1) swap-last, single assign
  if I <> LLen - 1 then
    Heap[Idx].Props[I] := Heap[Idx].Props[LLen - 1];
  // clear last to release refs
  Heap[Idx].Props[LLen - 1].Name := '';
  Heap[Idx].Props[LLen - 1].Hash := 0;
  Heap[Idx].Props[LLen - 1].Raw := '';
  Heap[Idx].Props[LLen - 1].Kind := 0;
  SetLength(Heap[Idx].Props, LLen - 1);
  LNew := LLen-1;
  if not LWasValid then
  begin
    if (LNew <= JS_PURE_HASH_THRESHOLD) and (Length(Heap[Idx].PropsBuckets)>0) then PropBucketsInvalidate(Heap[Idx]);
    Result := True; Exit;
  end;
  if LNew <= JS_PURE_HASH_THRESHOLD then
  begin
    PropBucketsInvalidate(Heap[Idx]); Result:=True; Exit;
  end;
  if Length(Heap[Idx].PropsBuckets) < JsPureBucketCapacity(LNew) then
  begin
    PropBucketsInvalidate(Heap[Idx]); Result:=True; Exit;
  end;
  // amortized O(1) incremental cluster patch vs O(n) full invalidate+rebuild — batch删O(k) not O(k·n), pure.host single source parity
  if I = LLen-1 then
  begin
    LPosRemoved := PropBucketFindPos(Heap[Idx], LHashRemoved, I);
    if LPosRemoved>=0 then PropBucketDeletePos(Heap[Idx], LPosRemoved)
    else PropBucketsInvalidate(Heap[Idx]);
  end else
  begin
    LPosMoved := PropBucketFindPos(Heap[Idx], LHashMoved, LLen-1);
    LPosRemoved := PropBucketFindPos(Heap[Idx], LHashRemoved, I);
    if (LPosMoved>=0) and (LPosRemoved>=0) then
    begin
      Heap[Idx].PropsBuckets[LPosMoved]:=I;
      PropBucketDeletePos(Heap[Idx], LPosRemoved);
    end else PropBucketsInvalidate(Heap[Idx]);
  end;
  Result := True;
end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var V: TJsStringViewArray; I: Integer;
begin
  // hot path prefers GetKeysView zero-copy; materialize via view
  V := JsPureHeapGetKeysView(Heap, Obj);
  if Length(V)=0 then Exit(nil);
  SetLength(Result, Length(V));
  for I:=0 to High(V) do
    Result[I] := V[I].ToString;
end;
function JsPureHeapGetKeysView(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringViewArray; inline;
var Idx, LLen, I: Integer;
begin
  Result := nil;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  if LLen = 0 then Exit;
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I] := TStringView.FromStr(Heap[Idx].Props[I].Name);
end;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
var Idx, P: Integer; begin Result := JsUndefinedValue; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindProp(Heap[Idx], Name);
  if P >= 0 then Result := RawToValue(Heap[Idx].Props[P].Raw, Heap[Idx].Props[P].Kind);
end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LHash: UInt32;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindProp(Heap[Idx], Name);
  if P >= 0 then begin Heap[Idx].Props[P].Raw := ValueRawOf(Val); Heap[Idx].Props[P].Kind := ValueKindOf(Val); Exit; end;
  LHash := PropHashStr(Name);
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Raw := ValueRawOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Kind := ValueKindOf(Val);
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := LHash;
  if Length(Heap[Idx].Props) > JS_PURE_HASH_THRESHOLD then
  begin
    if Length(Heap[Idx].PropsBuckets)=0 then PropBucketsRebuild(Heap[Idx])
    else if Length(Heap[Idx].PropsBuckets) <> JsPureBucketCapacity(Length(Heap[Idx].Props)) then PropBucketsRebuild(Heap[Idx])
    else JsPureBucketPut(Heap[Idx].PropsBuckets, Heap[Idx].PropsMask, LHash, High(Heap[Idx].Props));
  end
  else if Length(Heap[Idx].PropsBuckets)>0 then PropBucketsInvalidate(Heap[Idx]);
end;
procedure JsPureHeapClear(var Heap: TJsPureHeap);
var I: Integer;
begin
  for I := 0 to High(Heap) do
  begin
    SetLength(Heap[I].Props, 0);
    PropBucketsInvalidate(Heap[I]);
  end;
  SetLength(Heap, 0);
end;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
begin
  if AView.IsEmpty then Result := JsValueBindContext(JsStringValue(''), AContextId)
  else Result := JsValueBindContext(JsStringViewValue(AView.Data, AView.Len), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
begin
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
  Result := TextNeedsBackslashUnescapeView(AView);
end;
function JsPureUnescapeBackslashView(const AView: TStringView): string; inline;
begin
  Result := TextUnescapeBackslashView(AView);
end;
function JsPureIsQuotedView(const AView: TStringView): Boolean; inline;
begin
  Result := TextIsQuotedView(AView);
end;
function JsPureStripOuterQuotesView(const AView: TStringView): TStringView; inline;
begin
  Result := TextStripOuterQuotesView(AView);
end;
function JsPureJsonIntToStr(AValue: Int64): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  LLen := IntToBuffer(AValue, @LBuf[0]);
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;
function JsPureJsonDoubleToStr(AValue: Double): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  LLen := FloatToBuffer(AValue, @LBuf[0]);
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
end;
function JsPureJsonFastClean(const S: string; out AOut: string): Boolean; inline;
var B: TStringBuilder; LLen: SizeUInt; LP: PAnsiChar;
begin
  if JsonNeedsEscapeStr(S) then Exit(False);
  LLen := SizeUInt(Length(S));
  B.Init(LLen + 2);
  try
    // perf: reuse TStringBuilder geometric pool via bytes.ops.BytesGrowCapacity 0→64→2× amortized O(1), zero-copy via BytesCopy+Reserve/Tail/AdvanceLen single source, single alloc geopooled not per SetLength exact, inline
    B.Reserve(LLen + 2);
    LP := B.Tail;
    LP^ := '"'; Inc(LP);
    if LLen > 0 then begin BytesCopy(LP, PAnsiChar(S), LLen); Inc(LP, LLen); end;
    LP^ := '"'; Inc(LP);
    B.AdvanceLen(LLen + 2);
    AOut := B.ToString;
  finally B.Done; end;
  Result := True;
end;
function JsPureJsonEscaped(const S: string): string;
var B: TStringBuilder; W: TJsonWriter;
begin
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
function JsPureHeapGetBatch(const Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string): TJsValueArray;
var I: Integer; LHash: UInt32; LNeed: SizeUInt;
begin
  LNeed := SizeUInt(Length(Objs));
  if LNeed = 0 then Exit(nil);
  LHash := PropHashStr(AName);
  SetLength(Result, LNeed);
  for I := 0 to High(Objs) do
    Result[I] := JsPureHeapGetPropHashed(Heap, Objs[I], AName, LHash);
end;
procedure JsPureHeapSetBatch(var Heap: TJsPureHeap; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue);
var I, Idx: Integer; LHash: UInt32; LCap: Integer; LMask: UInt32; LDummy: Integer; Buckets: array of Integer; LProbe, LPos: Integer; LIdxHash: UInt32; LFound: Boolean;
begin
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName);
  LCap := JsPureBucketCapacity(Length(Objs));
  SetLength(Buckets, LCap);
  LDummy := 0;
  JsPureBucketsPrepare(Buckets, LMask, LDummy, LCap, 0);
  for I:=0 to High(Objs) do
  begin
    Idx:=JsPureHeapFind(Heap, Objs[I]);
    if (Idx<0) or (JsPureHeapFindPropHashed(Heap[Idx], AName, LHash)>=0) then Continue;
    LIdxHash := UInt32(Idx) * 2654435761;
    LPos := Integer(LIdxHash and LMask);
    LFound := False;
    for LProbe:=0 to High(Buckets) do
    begin
      if Buckets[LPos] = -1 then Break;
      if Buckets[LPos] = Idx then begin LFound := True; Break; end;
      LPos := (LPos + 1) and Integer(LMask);
    end;
    if LFound then Continue;
    Buckets[LPos] := Idx;
    JsPurePropsReserve(Heap[Idx].Props, 1);
  end;
  // perf: second loop uses reserved poke without second BytesDynEnsureLength probe — halved 2048→1024 probes for 1024 batch, amortized O(1) via BYTES_BUILDER_MIN_GROW, zero-copy, inline
  // stability: Buckets stack freed on exit, string Value assignment refcounted not丢, capacity poke via mem.dynarray single source resource not leaked
  for I := 0 to High(Objs) do
    JsPureHeapSetPropHashedReserved(Heap, Objs[I], AName, LHash, Vals[I]);
  SetLength(Buckets, 0);
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
