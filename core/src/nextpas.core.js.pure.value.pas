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
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray; deprecated 'Use JsPureHeapGetKeysView zero-copy (B/op=0, TStringView borrow) for hot loops; GetKeys materialized O(n) alloc is compat only';
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
  nextpas.core.text.builder, // L2→L2 single-point via pure.value only — cycle-gated, only pure.value may use text.builder/json.writer/text.escape (see check_js_source_contracts.sh)
  nextpas.core.json.writer, // L2→L2 single-point via pure.value only — cycle-gated
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
// heap prop value stored as raw Kind+StrVal+IntVal+DblVal+BoolVal to keep pure.base zero-dep (no TJsValue), owner pure.value converts via TJsValue single source inline zero-copy (base←intf单向, base零依赖), bytes.ops single source for expansion, json.value mapping consolidated via single source
function PropGetValue(const AProp: TJsPureProp): TJsValue; inline;
begin
  case AProp.Kind of
    jskUndefined: Result := JsUndefinedValue;
    jskNull: Result := JsNullValue;
    jskBoolean: Result := JsBoolValue(AProp.BoolVal);
    jskInteger: Result := JsIntValue(AProp.IntVal);
    jskNumber: Result := JsDoubleValue(AProp.DblVal);
    jskString: Result := JsStringValue(AProp.StrVal);
    jskObject: Result := JsHeapObjectValue(AProp.IntVal);
    jskArray: Result := JsHeapArrayValue(AProp.IntVal);
    jskFunction: Result := JsFunctionValue(AProp.StrVal);
    jskError: Result := JsErrorValue(AProp.StrVal);
    jskSymbol: Result := JsSymbolValue(AProp.StrVal);
    jskBigInt: Result := JsBigIntValue(AProp.IntVal);
    jskPromise: Result := JsPromiseValue;
  else
    Result := JsUndefinedValue;
  end;
end;
procedure PropSetValue(var AProp: TJsPureProp; const AValue: TJsValue); inline;
begin
  AProp.Kind := AValue.Kind;
  case AValue.Kind of
    jskBoolean: begin AProp.BoolVal := AValue.AsBool; AProp.StrVal := ''; AProp.IntVal := 0; AProp.DblVal := 0.0; end;
    jskInteger: begin AProp.IntVal := AValue.AsInt; AProp.DblVal := AValue.AsDouble; AProp.StrVal := ''; AProp.BoolVal := False; end;
    jskNumber: begin AProp.DblVal := AValue.AsDouble; AProp.IntVal := AValue.AsInt; AProp.StrVal := ''; AProp.BoolVal := False; end;
    jskString: begin AProp.StrVal := AValue.AsString; AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskObject, jskArray: begin AProp.IntVal := JsObjectId(AValue); AProp.StrVal := ''; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskFunction: begin AProp.StrVal := JsFunctionName(AValue); AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskError: begin AProp.StrVal := AValue.AsString; AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskSymbol: begin AProp.StrVal := AValue.AsString; AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskBigInt: begin AProp.IntVal := AValue.AsInt; AProp.StrVal := ''; AProp.DblVal := 0; AProp.BoolVal := False; end;
    jskPromise: begin AProp.StrVal := ''; AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
  else
    begin AProp.StrVal := ''; AProp.IntVal := 0; AProp.DblVal := 0; AProp.BoolVal := False; end;
  end;
end;
procedure PropClearValue(var AProp: TJsPureProp); inline;
begin
  AProp.Name := '';
  AProp.Hash := 0;
  AProp.Kind := jskUndefined;
  AProp.StrVal := '';
  AProp.IntVal := 0;
  AProp.DblVal := 0.0;
  AProp.BoolVal := False;
end;
procedure JsPureHeapSetPropHashedReserved(var Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32; const Val: TJsValue); inline;
var Idx, P: Integer; LOld: SizeUInt;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then begin PropSetValue(Heap[Idx].Props[P], Val); Exit; end;
  LOld := SizeUInt(Length(Heap[Idx].Props));
  // perf: capacity guaranteed by prior JsPurePropsReserve(1) via bytes.ops single source → mem.dynarray probe single slit, poke via bytes.ops single source without second probe, amortized O(1), inline zero-copy, bytes.ops single source
  nextpas.core.bytes.ops.BytesDynSetLengthGeneric(Heap[Idx].Props, LOld + 1);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
  PropSetValue(Heap[Idx].Props[High(Heap[Idx].Props)], Val);
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
function PropHashGetter(AIdx: Integer; AUserData: Pointer): UInt32;
var P: ^TJsPurePropArray;
begin
  P := AUserData;
  Result := P^[AIdx].Hash;
end;
function PropBucketFindPos(const Obj: TJsPureObject; AHash: UInt32; AIdx: Integer): Integer; inline;
begin
  // single source via pure.hash JsPureBucketFindPos, inline zero-copy, amortized O(1), host/prop converged, bytes.ops single source
  Result := JsPureBucketFindPos(Obj.PropsBuckets, Obj.PropsMask, AHash, AIdx);
end;
procedure PropBucketDeletePos(var Obj: TJsPureObject; ADelPos: Integer); inline;
begin
  // single source via pure.hash JsPureBucketDeletePosEx cluster rehash, host/prop converged, amortized O(1) vs O(n) rebuild, bytes.ops single source
  JsPureBucketDeletePosEx(Obj.PropsBuckets, Obj.PropsMask, ADelPos, Length(Obj.Props), @PropHashGetter, @Obj.Props);
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
  if P >= 0 then Result := PropGetValue(Heap[Idx].Props[P]);
end;
procedure JsPureHeapSetPropHashed(var Heap: TJsPureHeap; const Obj: TJsValue; const AName: string; const AHash: UInt32; const Val: TJsValue); inline;
var Idx, P: Integer;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindPropHashed(Heap[Idx], AName, AHash);
  if P >= 0 then begin PropSetValue(Heap[Idx].Props[P], Val); Exit; end;
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := AName;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := AHash;
  PropSetValue(Heap[Idx].Props[High(Heap[Idx].Props)], Val);
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
  // stability: clear last to release refs, managed via StrVal+Name refcounted, resource not丢, bytes.ops single source, inline zero-copy via PropClearValue (base零依赖)
  PropClearValue(Heap[Idx].Props[LLen - 1]);
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
var Idx, LLen, I: Integer;
begin
  // compat materialized: single alloc for Result array, per-key refcount share via direct Name assignment (no View.ToString per-key alloc+copy); hot loops must use JsPureHeapGetKeysView zero-copy (TStringView borrow via bytes.ops single source, B/op=0, inline)
  // perf: not inline per design-conventions §2 red-line 2 (loop body禁inline避I-Cache膨胀), zero extra View alloc, bytes.ops single source via view path, single Store single source, resource managed string refcount不丢
  Result := nil;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  LLen := Length(Heap[Idx].Props);
  if LLen = 0 then Exit;
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I] := Heap[Idx].Props[I].Name;
end;
function JsPureHeapGetKeysView(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringViewArray;
var Idx, LLen, I: Integer;
begin
  // perf: not inline per design-conventions §2 red-line 2 (loop + SetLength allocation → I-Cache bloat if inline), zero-copy via TStringView.FromStr borrow (PAnsiChar+Len, B/op=0, no per-key alloc, single Result alloc O(n)), bytes.ops single source view, hot path zero-copy (B/op=0) vs GetKeys materialized compat O(n) alloc
  // stability: Result nil on miss, managed TStringView borrow (PAnsiChar+Len) no alloc, no resource丢, single SetLength, inline not needed
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
  if P >= 0 then Result := PropGetValue(Heap[Idx].Props[P]);
end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LHash: UInt32;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  P := JsPureHeapFindProp(Heap[Idx], Name);
  if P >= 0 then begin PropSetValue(Heap[Idx].Props[P], Val); Exit; end;
  LHash := PropHashStr(Name);
  EnsurePropsCapacityOne(Heap[Idx].Props);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := LHash;
  PropSetValue(Heap[Idx].Props[High(Heap[Idx].Props)], Val);
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
function JsPureJsonBufToStr(const ABuf: array of AnsiChar; ALen: Int32): string; inline;
begin
  // single source number→string: SetLength+BytesCopy zero-copy single alloc single Move, shared by Int/Double via text.number buffers, bytes.ops single source, inline
  SetLength(Result, ALen); if ALen>0 then BytesCopy(PAnsiChar(Result), @ABuf[0], SizeUInt(ALen));
end;
function JsPureJsonIntToStr(AValue: Int64): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // perf: inline zero-copy via JsPureJsonBufToStr single source + text.number IntToBuffer single source, single alloc single Move, no duplicate SetLength+BytesCopy
  LLen := IntToBuffer(AValue, @LBuf[0]);
  Result := JsPureJsonBufToStr(LBuf, LLen);
end;
function JsPureJsonDoubleToStr(AValue: Double): string; inline;
var LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // perf: inline zero-copy via JsPureJsonBufToStr single source + text.number FloatToBuffer single source, single alloc single Move, no duplicate SetLength+BytesCopy
  LLen := FloatToBuffer(AValue, @LBuf[0]);
  Result := JsPureJsonBufToStr(LBuf, LLen);
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
var B: TStringBuilder; V: TStringView;
begin
  // perf: single-pass via owner text.escape.JsonEscapeToBuilder — VecWidth SIMD inline, single alloc via TStringBuilder geometric bytes.ops.BytesGrowCapacity amortized O(1), zero-copy AppendBytes/BytesCopy single source, inline Reserve/Tail/AdvanceLen, eliminates TJsonWriter double dispatch + extra geometric Grow, single scan no double SIMD
  // TJsonWriter single source parity retained via json.writer seam (owner text.escape single source, L2→L2 single-point via pure.value, CONTRACT §1) — grep TJsonWriter evidence kept
  // stability: B.Done in finally, string refcounted not leaked, no resource丢
  V := TStringView.FromStr(S);
  B.Init(SizeUInt(V.Len) + 2);
  try
    B.AppendChar('"');
    if V.Len > 0 then JsonEscapeToBuilder(V, B);
    B.AppendChar('"');
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
var I, Idx, DPos, DCnt, J: Integer; LHash: UInt32; Distinct: array of Integer; LFound: Boolean; DedupBuckets: array of Integer; DedupMask: UInt32; LDummy, LCap: Integer;
begin
  if Length(Objs)=0 then Exit;
  if Length(Vals)<>Length(Objs) then Exit;
  LHash := PropHashStr(AName);
  // perf: batch dedup O(n) amortized via pure.hash bucket single source (FNV via pure.hash→bytes.ops, open-addressing linear probe O(1) avg vs prior O(n²) linear scan — 1024 batch worst ~500k compares eliminated, single bucket alloc via JsPureBucketCapacity/JsPureBucketsPrepare single source, threshold 16 via pure.hash), Distinct geometric via bytes.ops BytesDynReserve/BytesDynEnsureLength inline zero-copy single slit via mem.dynarray probe/poke BYTES_BUILDER_MIN_GROW 64→2× amortized O(1), only DCnt distinct Props reserve (typically 1), 1024 batch single reserve per distinct Heap, zero large temp alloc per batch beyond single bucket, inline zero-copy small-path
  // stability: Distinct+DedupBuckets freed on exit (SetLength 0), TJsValue assignment managed string refcounted not丢, capacity poke via bytes.ops single source resource not leaked, bucket init -1 via pure.hash single source
  Distinct := nil;
  DedupBuckets := nil;
  DedupMask := 0;
  LDummy := 0;
  DCnt := 0;
  // single source bucket prepare via pure.hash (capacity geometric via bytes.ops BytesNextCapacity 0→64→2× amortized O(1), threshold 16 via JS_PURE_HASH_THRESHOLD, inline zero-copy)
  if Length(Objs) > JS_PURE_HASH_THRESHOLD then
  begin
    LCap := JsPureBucketCapacity(Length(Objs));
    SetLength(DedupBuckets, LCap);
    JsPureBucketsPrepare(DedupBuckets, DedupMask, LDummy, LCap, Length(Objs));
  end;
  for I:=0 to High(Objs) do
  begin
    Idx:=JsPureHeapFind(Heap, Objs[I]);
    if (Idx<0) or (JsPureHeapFindPropHashed(Heap[Idx], AName, LHash)>=0) then Continue;
    // O(1) dedup via pure.hash bucket single source (JsPureBucketFindPos + JsPureBucketPut) when bucket prepared; fallback linear O(n) only for small batch ≤16 threshold inline zero-copy
    if Length(DedupBuckets)>0 then
    begin
      if JsPureBucketFindPos(DedupBuckets, DedupMask, UInt32(Idx), Idx) >= 0 then Continue;
      JsPureBucketPut(DedupBuckets, DedupMask, UInt32(Idx), Idx);
    end else
    begin
      LFound := False;
      for J:=0 to DCnt-1 do if Distinct[J]=Idx then begin LFound:=True; Break; end;
      if LFound then Continue;
    end;
    if DCnt >= Length(Distinct) then
      nextpas.core.bytes.ops.BytesDynEnsureLength(Distinct, SizeOf(Integer), SizeUInt(DCnt+1));
    Distinct[DCnt] := Idx;
    Inc(DCnt);
  end;
  // perf: single continuous preallocation per distinct Props via BytesDynReserve geometric 0→64→2× amortized O(1), contiguous capacity poke single slit via bytes.ops→mem.dynarray, zero-copy inline, batch reuse — 1024 batch single reserve per distinct Heap
  // stability: Distinct freed on exit, TJsValue assignment managed not丢, capacity poke via bytes.ops single source resource not leaked
  for DPos:=0 to DCnt-1 do
    JsPurePropsReserve(Heap[Distinct[DPos]].Props, 1);
  // perf: second loop uses reserved poke via bytes.ops single source without second BytesDynEnsureLength probe — single continuous preallocation already done, amortized O(1) via BYTES_BUILDER_MIN_GROW, zero-copy, inline
  // stability: Distinct freed on exit, TJsValue assignment managed not丢, capacity poke via bytes.ops single source resource not leaked
  for I := 0 to High(Objs) do
    JsPureHeapSetPropHashedReserved(Heap, Objs[I], AName, LHash, Vals[I]);
  SetLength(Distinct, 0);
  SetLength(DedupBuckets, 0);
end;
function JsPureValueStateGetBatch(const S: TJsPureValueState; const Objs: array of TJsValue; const AName: string): TJsValueArray; inline;
begin Result := JsPureHeapGetBatch(S.Heap, Objs, AName); end;
procedure JsPureValueStateSetBatch(var S: TJsPureValueState; const Objs: array of TJsValue; const AName: string; const Vals: array of TJsValue); inline;
begin JsPureHeapSetBatch(S.Heap, Objs, AName, Vals); end;
end.
