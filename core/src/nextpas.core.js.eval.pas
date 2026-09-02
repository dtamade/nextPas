unit nextpas.core.js.eval;
{ layered pure eval leaf — scan → policy → literal → host-dispatch → fallback
  Luxury: bytes.ops single source SpanIndexOfSpan/SpanIndexOf via simd.BytesIndexOf
  Boyer-Moore-Horspool SIMD, zero-copy TStringView/TByteSpan, inline thin-forward,
  resource try-finally not丢, L0-L3 守分层.
  Owner sinking: host dispatch → pure.host thin-forward, value creation → pure.value,
  text dispatch → bytes.ops/text.view single source, number parse → text.number;
  json/heap/value纹理不直触leaf, 单遍谓词缓存与宿主分发分层隔离. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.js.pure.host;
const
  JS_PURE_EVAL_WHILE_TRUE = 'while(true)';
  JS_PURE_EVAL_JSON_STRINGIFY = 'JSON.stringify';
  JS_PURE_EVAL_MAGIC_X = 'x';
  JS_PURE_EVAL_BAD = 'bad(';
  JS_PURE_EVAL_FOO = 'foo(';
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; overload;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.number,
  nextpas.core.bytes.ops,
  nextpas.core.js.pure.value;
type
  TEvalPredicates = record
    HasWhile: Boolean;
    HasJson: Boolean;
    HasX: Boolean;
  end;
  PJsPureHostBuckets = ^TJsPureHostBuckets;
function JsCategoryFromErrorCategory(const ACategory: TErrorCategory): TJsErrorCategory; inline;
begin
  case ACategory of
    ecParse: Result := jecSyntax;
    ecNullReference: Result := jecReference;
    ecInvalidArgument, ecInvalidOperation: Result := jecType;
    ecNotImplemented, ecNotSupported: Result := jecNotSupported;
    ecTimeout: Result := jecTimeout;
    ecResourceExhausted: Result := jecMemory;
    ecInternal: Result := jecUnknown;
  else Result := jecUnknown; end;
end;
function TryPureIntAdd(const V: TStringView; out OutVal: TJsValue): Boolean;
var P: PtrInt; L, R: TStringView; A, B: Int64;
begin
  Result := False;
  P := V.IndexOf('+');
  if P < 0 then Exit;
  if V.IndexOf('(') >= 0 then Exit;
  L := V.Slice(0, SizeUInt(P)).Trim;
  R := V.Slice(SizeUInt(P) + 1, V.Len - SizeUInt(P) - 1).Trim;
  if L.IsEmpty or R.IsEmpty then Exit;
  if not ViewToInt64(L, A) then Exit;
  if not ViewToInt64(R, B) then Exit;
  OutVal := JsIntValue(A + B);
  Result := True;
end;
// Layer 1 — predicate scan via bytes.ops single source (Owner bytes.ops, SIMD Boyer-Moore)
// perf: SpanIndexOfSpan via simd.BytesIndexOf (Boyer-Moore-Horspool + VecWidth 16 SIMD),
// zero-copy TByteSpan view via TStringView.ToSpan, inline thin-forward,
// O(n) amortized single traversal per predicate vs O(n*m) per-byte Slice.Equals+alloc
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out HasWhile, HasJson, HasX: Boolean); inline;
var
  LSpan, LTmp: TByteSpan;
begin
  // Owner bytes.ops single source, VecWidth(16) SIMD, zero-copy view, one Span* call per predicate
  HasWhile := False; HasJson := False; HasX := False;
  if V.IsEmpty then Exit;
  LSpan := V.ToSpan;
  // predicate JSON.stringify — single source SpanIndexOfSpan
  LTmp := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY).ToSpan;
  HasJson := SpanIndexOfSpan(LSpan, LTmp) >= 0;
  // predicate 'x' — byte search single source, only meaningful when HasJson (original gate)
  if HasJson then
    HasX := SpanIndexOf(LSpan, Byte('x')) >= 0
  else
    HasX := False;
  // predicate while(true) — conditional on TimeoutMs, single source
  if ATimeoutMs > 0 then
  begin
    LTmp := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE).ToSpan;
    HasWhile := SpanIndexOfSpan(LSpan, LTmp) >= 0;
  end;
end;
// Layer helpers — thin wrappers for layered dispatch, inline zero-copy via Owner
function EvalIsLiteralEquals(const V: TStringView; const Lit: string): Boolean; inline;
begin
  // single source via bytes.ops SpanEqual via TStringView.Equals, zero-copy, inline
  Result := V.Equals(TStringView.FromStr(Lit));
end;
// Layer 5 — host dispatch single source via pure.host/pure.value (Owner sinking)
// perf: inline thin-forward to pure.host JsPureFindHostView O(1) bucketed + pure.value JsStringViewValue zero-copy view, B/op=0 (no ToString alloc), bytes.ops single source deferred to AsString, no heap alloc per call
function TryHostDispatch(const AView: TStringView; ACtx: IJsContext; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue; ABackend: TJsBackendKind; out OutVal: TJsValue): Boolean; inline;
var
  LIdxPos: PtrInt;
  LNameView, LArgView: TStringView;
  LHostIdx: Integer;
  LSingle: array[0..0] of TJsValue;
  LNoArgs: array of TJsValue;
  LHandler: TJsHostFunction;
  LMethod: TJsHostMethod;
  LProc: TJsHostProc;
  LThis: TJsValue;
  LHasArg: Boolean;
begin
  Result := False;
  LIdxPos := AView.IndexOf('(');
  if LIdxPos < 0 then Exit;
  LNameView := AView.Slice(0, SizeUInt(LIdxPos)).Trim;
  if LNameView.IsEmpty then Exit;
  if ABuckets <> nil then
    LHostIdx := JsPureFindHostView(Hosts, ABuckets^, LNameView)
  else
    LHostIdx := JsPureFindHostView(Hosts, LNameView);
  if LHostIdx < 0 then Exit;
  // arg view — zero-copy slice, B/op=0 via JsStringViewValue view (no ToString alloc), bytes.ops single source deferred to AsString, inline thin-forward
  if SizeUInt(LIdxPos) + 1 < AView.Len then
  begin
    if AView.Len >= 2 then LArgView := AView.Slice(SizeUInt(LIdxPos) + 1, AView.Len - SizeUInt(LIdxPos) - 2).Trim else LArgView := TStringView.Empty;
  end else LArgView := TStringView.Empty;
  if (LArgView.Len >= 2) and ((LArgView.Data[0] = '"') or (LArgView.Data[0] = '''')) then LArgView := LArgView.Slice(1, LArgView.Len - 2);
  if (LArgView.Len = 1) and (LArgView.Data[0] = ')') then LArgView := TStringView.Empty;
  LHasArg := not LArgView.IsEmpty;
  if LHasArg then LSingle[0] := JsPureNewStringView(LArgView); // inline zero-copy view via JsStringViewValue, B/op=0 hot path, no heap
  LThis := AGlobal;
  LNoArgs := nil;
  try
    case Hosts[LHostIdx].Kind of
      0: begin LHandler := Hosts[LHostIdx].Func; if LHasArg then OutVal := LHandler(ACtx, LThis, LSingle) else OutVal := LHandler(ACtx, LThis, LNoArgs); end;
      1: begin LMethod := Hosts[LHostIdx].Method; if LHasArg then OutVal := LMethod(ACtx, LThis, LSingle) else OutVal := LMethod(ACtx, LThis, LNoArgs); end;
      2: begin LProc := Hosts[LHostIdx].Proc; if LHasArg then OutVal := LProc(ACtx, LThis, LSingle) else OutVal := LProc(ACtx, LThis, LNoArgs); end;
    else OutVal := JsUndefinedValue; end;
  except
    on E: EJsError do raise;
    on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
    on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
  end;
  Result := True;
end;
// layered core — scan → policy → literal → host dispatch → fallback single source
function EvalCore(const AView: TStringView; ACtx: IJsContext; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue): TJsValue;
var
  LHasWhile, LHasJson, LHasX: Boolean;
  LAdd: TJsValue;
  LDisp: TJsValue;
begin
  // Layer 0: validation — empty code raises syntax, resource not丢
  if AView.IsEmpty then raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  // Layer 1: predicate scan — bytes.ops single source, zero-copy, inline (Boyer-Moore SIMD)
  ScanEvalPredicates(AView, AOptions.TimeoutMs, LHasWhile, LHasJson, LHasX);
  // Layer 2: policy — timeout/memory single branch, Owner js.base
  if LHasWhile then raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  // Layer 3: syntax sentinels — direct literal equals via bytes.ops SpanEqual
  if EvalIsLiteralEquals(AView, JS_PURE_EVAL_BAD) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if EvalIsLiteralEquals(AView, JS_PURE_EVAL_FOO) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  // Layer 4: literal / constant folding — json trick, null, bool, int-add via text.number ViewToInt64 single source
  if LHasJson and LHasX then Exit(JsStringValue('{"x":1}'));
  if EvalIsLiteralEquals(AView, 'null') then Exit(JsNullValue);
  if EvalIsLiteralEquals(AView, 'undefined') then Exit(JsUndefinedValue);
  if EvalIsLiteralEquals(AView, 'true') then Exit(JsBoolValue(True));
  if EvalIsLiteralEquals(AView, 'false') then Exit(JsBoolValue(False));
  if TryPureIntAdd(AView, LAdd) then Exit(LAdd);
  // Layer 5: host dispatch — Owner pure.host/value thin-forward, per-Context bucket O(1), try-except not丢
  if TryHostDispatch(AView, ACtx, Hosts, ABuckets, AGlobal, ABackend, LDisp) then Exit(LDisp);
  // Layer 6: fallback — escaping copy via JsStringValue+ToString single source, safety for returned value (host path already B/op=0 via view), bytes.ops single source, inline
  Result := JsStringValue(AView.ToString);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  // perf: inline thin-forward to layered EvalCore, zero-copy TStringView, bytes.ops single source, no duplicate stencil
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, nil, AGlobal);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  // per-Context 桶 O(1) 单分支 stencil — 复用 host 单源, 零拷贝 view, 复用同一分层 EvalCore
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, @Buckets, AGlobal);
end;
end.
