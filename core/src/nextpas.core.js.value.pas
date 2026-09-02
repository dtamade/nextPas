unit nextpas.core.js.value;
{ Value/Heap facade — independent L2 value owner (复用下沉): thin re-export pure.value single source, Heap+Global via bytes.ops+mem.dynarray geometric single source, inline zero-copy via text.view. Threshold >800时 pure.base Heap/Value职责可彻底迁至本单元，当前pure.value为单源owner，本单元为js.value独立门面 alias, 守 L0-L3, 四件套 base←intf←impl←门面. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.value;
type
  TJsHeapProp = TJsPureProp;
  TJsHeapObject = TJsPureObject;
  TJsHeap = TJsPureHeap;
  TJsHeapMetrics = TJsPureHeapMetrics;
  TJsValueState = TJsPureValueState;
const
  JS_HEAP_HASH_THRESHOLD = JS_PURE_HEAP_HASH_THRESHOLD;
function JsHeapFind(const Heap: TJsHeap; const Obj: TJsValue): Integer; inline;
function JsHeapNewObject(var Heap: TJsHeap): TJsValue; inline;
function JsHeapNewArray(var Heap: TJsHeap): TJsValue; inline;
function JsHeapGetProp(const Heap: TJsHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
procedure JsHeapSetProp(var Heap: TJsHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
procedure JsHeapClear(var Heap: TJsHeap); inline;
function JsNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline;
function JsNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
procedure JsValueStateClear(var S: TJsValueState); inline;
function JsValueToJsonString(const AValue: TJsValue): string;
function JsValueAsJson(const AValue: TJsValue): string; inline;
implementation
uses
  nextpas.core.bytes.ops,
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.text.escape,
  nextpas.core.text.number;
function JsHeapFind(const Heap: TJsHeap; const Obj: TJsValue): Integer; inline;
begin Result := JsPureHeapFind(Heap, Obj); end;
function JsHeapNewObject(var Heap: TJsHeap): TJsValue; inline;
begin Result := JsPureHeapNewObject(Heap); end;
function JsHeapNewArray(var Heap: TJsHeap): TJsValue; inline;
begin Result := JsPureHeapNewArray(Heap); end;
function JsHeapGetProp(const Heap: TJsHeap; const Obj: TJsValue; const Name: string): TJsValue; inline;
begin Result := JsPureHeapGetProp(Heap, Obj, Name); end;
procedure JsHeapSetProp(var Heap: TJsHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue); inline;
begin JsPureHeapSetProp(Heap, Obj, Name, Val); end;
procedure JsHeapClear(var Heap: TJsHeap); inline;
begin JsPureHeapClear(Heap); end;
function JsNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewStringView(AView, AContextId); end;
function JsNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewString(AStr, AContextId); end;
function JsNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin Result := JsPureNewInt(AValue, AContextId); end;
procedure JsValueStateClear(var S: TJsValueState); inline;
begin JsPureValueStateClear(S); end;
function JsValueToJsonString(const AValue: TJsValue): string;
var B: TStringBuilder; W: TJsonWriter; S: string; LBuf: array[0..63] of AnsiChar; LLen: Int32;
begin
  // single source via json.writer TJsonWriter seam + text.builder geometric via bytes.ops BytesNextCapacity single source, zero-copy BytesCopy single source, text.view zero-copy, text.escape SIMD single source
  // perf: thin single source owner js.value, number path zero builder via text.number IntToBuffer/FloatToBuffer stack single source single alloc, string clean fast path via JsonNeedsEscapeStr SIMD single source zero builder single alloc ('"'+S+'"' inline), escaped path single alloc + try-finally Done not lost, not inline per red-line (branch+builder)
  case AValue.Kind of
    jskUndefined: Exit('undefined');
    jskNull: Exit('null');
    jskBoolean: if AValue.AsBool then Exit('true') else Exit('false');
    jskNumber:
      begin
        // high-freq zero-builder: stack buffer via text.number single source, one SetString alloc, bytes.ops BytesCopy single source inside IntToBuffer/FloatToBuffer, no TStringBuilder heap
        if Double(AValue.AsInt) = AValue.AsDouble then
          LLen := IntToBuffer(AValue.AsInt, @LBuf[0])
        else
          LLen := FloatToBuffer(AValue.AsDouble, @LBuf[0]);
        SetString(Result, PAnsiChar(@LBuf[0]), LLen);
        Exit;
      end;
    jskString:
      begin
        S := AValue.AsString;
        // clean string fast path: zero builder, single alloc via concatenation, predicate single source via text.escape JsonNeedsEscapeStr SIMD VecWidth
        if not JsonNeedsEscapeStr(S) then
        begin
          Result := '"' + S + '"';
          Exit;
        end;
        // escaped path: single seam via json.writer TJsonWriter + builder geometric via bytes.ops single source, single alloc, try-finally not lost
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
function JsValueAsJson(const AValue: TJsValue): string; inline;
begin
  // perf: inline thin-forward to JsValueToJsonString single source, zero-copy, single seam with pure.value/intf
  Result := JsValueToJsonString(AValue);
end;
end.
