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
  TJsPureProp = record Name: string; Value: TJsValue; end;
  TJsPureObject = record Id: Int64; Props: array of TJsPureProp; end;
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
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.json.writer,
  nextpas.core.mem.dynarray,
  nextpas.core.js.value; // single source convergent: JsPureToJsonString via js.value
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
  // threshold split: >64 use direct index + binary search
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
procedure PokeHeapLen(var Heap: TJsPureHeap; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Heap;
begin nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen); end;
procedure PokePropsLen(var Props: array of TJsPureProp; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Props;
begin nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen); end;
function JsPureHeapAlloc(var Heap: TJsPureHeap; AIsArray: Boolean): TJsValue;
var LId: Int64; LOld, LNeed, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1; LCap := BytesNextCapacity(LOld, LNeed);
  if LCap > LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap, LCap); if LCap <> LNeed then PokeHeapLen(Heap, LNeed); end else SetLength(Heap, LNeed);
  LId := Int64(LNeed); if LId = 0 then LId := 1; Heap[High(Heap)].Id := LId; SetLength(Heap[High(Heap)].Props, 0);
  if AIsArray then Result := JsHeapArrayValue(LId) else Result := JsHeapObjectValue(LId);
end;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
begin Result := JsPureHeapAlloc(Heap, False); end;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
begin Result := JsPureHeapAlloc(Heap, True); end;
function JsPureHeapFindProp(const AProps: array of TJsPureProp; const AName: string): Integer;
var I: Integer; begin for I := 0 to High(AProps) do if AProps[I].Name = AName then Exit(I); Result := -1; end;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx: Integer; begin Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; Result := JsPureHeapFindProp(Heap[Idx].Props, Name) >= 0; end;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I, J: Integer; begin Result := False; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; I := JsPureHeapFindProp(Heap[Idx].Props, Name); if I < 0 then Exit;
  for J := I to High(Heap[Idx].Props) - 1 do Heap[Idx].Props[J] := Heap[Idx].Props[J + 1]; SetLength(Heap[Idx].Props, Length(Heap[Idx].Props) - 1); Result := True; end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var Idx, I: Integer; begin Result := nil; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; SetLength(Result, Length(Heap[Idx].Props)); for I := 0 to High(Heap[Idx].Props) do Result[I] := Heap[Idx].Props[I].Name; end;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
var Idx, P: Integer; begin Result := JsUndefinedValue; Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; P := JsPureHeapFindProp(Heap[Idx].Props, Name); if P >= 0 then Result := Heap[Idx].Props[P].Value; end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LOld, LNeed, LCap: SizeUInt;
begin
  Idx := JsPureHeapFind(Heap, Obj); if Idx < 0 then Exit; P := JsPureHeapFindProp(Heap[Idx].Props, Name); if P >= 0 then begin Heap[Idx].Props[P].Value := Val; Exit; end;
  LOld := SizeUInt(Length(Heap[Idx].Props)); LNeed := LOld + 1; LCap := BytesNextCapacity(LOld, LNeed);
  if LCap > LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap[Idx].Props, LCap); if LCap <> LNeed then PokePropsLen(Heap[Idx].Props, LNeed); end else SetLength(Heap[Idx].Props, LNeed);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name; Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
end;
procedure JsPureHeapClear(var Heap: TJsPureHeap);
var I, J: Integer;
begin
  for I := 0 to High(Heap) do
  begin
    for J := 0 to High(Heap[I].Props) do Heap[I].Props[J].Name := '';
    SetLength(Heap[I].Props, 0);
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
