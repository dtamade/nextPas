unit nextpas.core.js.pure.predicates;
{ pure predicates — constants + numeric predicate single source for js.eval (L2 pure family)
  收敛 js.eval 的字面量/哨兵/数值谓词至单源谓词池，text.number/text.scan 为 L1 owner 单源，
  bytes.ops 零拷贝视图单源，热点 inline 薄转发，资源 try-finally 幂等不丢，缺能力反哺 owner。 }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.text.scan,
  nextpas.core.bytes.ops;
type
  TJsPredLiteralEntry = nextpas.core.text.scan.TScanJsLiteralEntry;
  TJsPredSentinelEntry = nextpas.core.text.scan.TScanJsSentinelEntry;
const
  // single source via text.scan owner (SCAN_*), bytes.ops single source via TStringView.Equals zero-copy inline, L0-L3 keep, no duplicate
  JS_PRED_LITERALS: array[0..3] of TScanJsLiteralEntry = (
    (Lit: nextpas.core.text.scan.SCAN_JSON_LITERAL_NULL; Kind: 0),
    (Lit: nextpas.core.text.scan.SCAN_JS_LITERAL_UNDEFINED; Kind: 1),
    (Lit: nextpas.core.text.scan.SCAN_JSON_LITERAL_TRUE; Kind: 2),
    (Lit: nextpas.core.text.scan.SCAN_JSON_LITERAL_FALSE; Kind: 3)
  );
  JS_PRED_SENTINELS: array[0..1] of TScanJsSentinelEntry = (
    (Lit: nextpas.core.text.scan.SCAN_JS_EVAL_SENTINEL_BAD; Stack: nextpas.core.text.scan.SCAN_JS_EVAL_SENTINEL_BAD_STACK),
    (Lit: nextpas.core.text.scan.SCAN_JS_EVAL_SENTINEL_FOO; Stack: nextpas.core.text.scan.SCAN_JS_EVAL_SENTINEL_FOO_STACK)
  );
function JsPredTryLiteral(const V: TStringView; out AKind: Byte): Boolean; inline;
function JsPredTrySentinel(const V: TStringView; out AStack: TStringView): Boolean; inline;
function JsPredHasFloatMarker(const V: TStringView): Boolean; inline;
function JsPredLiteralValue(AKind: Byte): TJsValue; inline;
function JsPredTryNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
implementation
uses
  nextpas.core.text.number,
  nextpas.core.js.pure.value;
function JsPredTryLiteral(const V: TStringView; out AKind: Byte): Boolean; inline;
begin
  // perf: inline thin-forward via text.scan owner single source, bytes.ops SpanEqual SIMD zero-copy, B/op=0, L0-L3 keep
  Result := nextpas.core.text.scan.ScanTryJsLiteral(V, AKind);
end;
function JsPredTrySentinel(const V: TStringView; out AStack: TStringView): Boolean; inline;
begin
  // perf: inline thin-forward via text.scan owner single source, bytes.ops zero-copy, B/op=0
  Result := nextpas.core.text.scan.ScanTryJsSentinel(V, AStack);
end;
function JsPredHasFloatMarker(const V: TStringView): Boolean; inline;
begin
  // perf: inline thin-forward single-pass ScanFindByte3 VecWidth SIMD O(n) vs O(3n), bytes.ops single source, B/op=0
  Result := nextpas.core.text.scan.ScanHasFloatMarker(V);
end;
function JsPredLiteralValue(AKind: Byte): TJsValue; inline;
begin
  // perf: inline single branch Kind compare, zero FPU, no alloc, single source for js.eval literal table
  case AKind of
    0: Result := JsNullValue;
    1: Result := JsUndefinedValue;
    2: Result := JsBoolValue(True);
    3: Result := JsBoolValue(False);
  else Result := JsUndefinedValue;
  end;
end;
function JsPredTryNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
var LFirst: AnsiChar; LInt: Int64; LDbl: Double;
begin
  // perf: single source numeric predicate via text.number (EiselLemire) + text.scan float marker single-pass VecWidth SIMD, bytes.ops single source, first-byte O(1) filter, inline thin-forward, B/op=0, try-finally not丢, L0-L3 keep
  Result := False;
  if V.IsEmpty then Exit;
  LFirst := V.Data[0];
  if not (LFirst in ['0'..'9','-','+','.']) then Exit;
  if not nextpas.core.text.scan.ScanHasFloatMarker(V) then
  begin
    if ViewToInt64(V, LInt) then begin OutVal := JsPureNewInt(LInt, AContextId); Exit(True); end;
    if ViewToDouble(V, LDbl) then begin OutVal := JsPureNewDouble(LDbl, AContextId); Exit(True); end;
  end else
    if ViewToDouble(V, LDbl) then begin OutVal := JsPureNewDouble(LDbl, AContextId); Exit(True); end;
end;
end.
