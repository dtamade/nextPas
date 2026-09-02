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
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.system.heap,
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
{ capacity helpers — single source geometric via bytes.ops, zero-copy header poke via mem.dynarray }
type
  PDynArrayHeader = ^TDynArrayHeader;
  TDynArrayHeader = record RefCnt: PtrInt; High: PtrInt; end;
function HeapCapacity(const Heap: TJsPureHeap): SizeUInt; inline;
var LP: Pointer; LBlock: Pointer; LSize: SizeUInt;
begin
  LP := Pointer(Heap);
  if LP = nil then Exit(0);
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then Exit(SizeUInt(Length(Heap)));
  Result := (LSize - SizeOf(TDynArrayHeader)) div SizeOf(TJsPureObject);
end;
function PropsCapacityObj(const Obj: TJsPureObject): SizeUInt; inline;
var LP: Pointer; LBlock: Pointer; LSize: SizeUInt;
begin
  LP := Pointer(Obj.Props);
  if LP = nil then Exit(0);
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then Exit(SizeUInt(Length(Obj.Props)));
  Result := (LSize - SizeOf(TDynArrayHeader)) div SizeOf(TJsPureProp);
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
  LCap := 1;
  while LCap < LCount*2 do LCap := LCap shl 1;
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
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1; LCap := BytesNextCapacity(LOld, LNeed);
  LCurCap := HeapCapacity(Heap);
  if LCurCap >= LNeed then
  begin
    // perf: capacity sufficient — exactly-once poke via mem.dynarray, no SetLength, amortized O(1) batch NewObject, zero-copy header
    if LOld <> LNeed then PokeHeapLen(Heap, LNeed);
  end else
  begin
    Inc(GPureHeapMetrics.Rebuilds);
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
var Idx, I, J: Integer;
begin
  Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then I := JsPureHeapFindProp(Heap[Idx], Name)
  else I := JsPureHeapFindProp(Heap[Idx].Props, Name);
  if I < 0 then Exit;
  for J := I to High(Heap[Idx].Props) - 1 do Heap[Idx].Props[J] := Heap[Idx].Props[J + 1];
  // clear last duplicate string to avoid leak before shrink
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := '';
  Heap[Idx].Props[High(Heap[Idx].Props)].Hash := 0;
  SetLength(Heap[Idx].Props, Length(Heap[Idx].Props) - 1);
  // stability: invalidate bucket, rebuild if still > threshold
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then PropBucketsRebuild(Heap[Idx])
  else PropBucketsInvalidate(Heap[Idx]);
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
var Idx, P: Integer; LOld, LNeed, LCap, LCurCap: SizeUInt; LHash: UInt32;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit;
  if Length(Heap[Idx].Props) > JS_PURE_HEAP_HASH_THRESHOLD then P := JsPureHeapFindProp(Heap[Idx], Name)
  else P := JsPureHeapFindProp(Heap[Idx].Props, Name);
  if P >= 0 then begin Heap[Idx].Props[P].Value := Val; Exit; end;
  LHash := PropHashStr(Name);
  LOld := SizeUInt(Length(Heap[Idx].Props)); LNeed := LOld + 1; LCap := BytesNextCapacity(LOld, LNeed);
  LCurCap := PropsCapacityObj(Heap[Idx]);
  if LCurCap >= LNeed then
  begin
    // perf: capacity sufficient — exactly-once poke via mem.dynarray, no SetLength, amortized O(1) batch SetProp
    if LOld <> LNeed then PokePropsLen(Heap[Idx].Props, LNeed);
  end else
  begin
    Inc(GPureHeapMetrics.Rebuilds);
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
var S: string;
begin
  // zero-copy view via BytesCopy single source
  if AView.Len = 0 then S := '' else begin SetLength(S, AView.Len); BytesCopy(Pointer(S), AView.Data, AView.Len); end;
  Result := JsValueBindContext(JsStringValue(S), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
var S: string;
begin
  // zero-copy via BytesCopy
  if AView.Len = 0 then S := '' else begin SetLength(S, AView.Len); BytesCopy(Pointer(S), AView.Data, AView.Len); end;
  Result := JsStringValue(S);
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
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
begin Result := JsonParse(JsPureToJsonString(AValue)); end;
end.
