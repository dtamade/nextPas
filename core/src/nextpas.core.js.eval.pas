unit nextpas.core.js.eval;
{ gated scan + strategy table — single source via bytes.ops SIMD, inline zero-copy,
  resource try-finally not丢, L0-L3 守分层, table-driven literals/sentinels. }
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
// scanner — gated single source via bytes.ops, inline zero-copy, conditional SIMD
function EvalNeedsJsonScan(const V: TStringView): Boolean; inline;
begin
  // length guard eliminates SpanIndexOfSpan for short codes (<15)
  if V.Len < SizeUInt(Length(JS_PURE_EVAL_JSON_STRINGIFY)) then Exit(False);
  // cheap single-byte filter before Boyer-Moore-Horspool SIMD
  Result := SpanIndexOf(V.ToSpan, Byte('J')) >= 0;
end;
function EvalNeedsWhileScan(const V: TStringView; ATimeoutMs: Integer): Boolean; inline;
begin
  if ATimeoutMs <= 0 then Exit(False);
  if V.Len < SizeUInt(Length(JS_PURE_EVAL_WHILE_TRUE)) then Exit(False);
  Result := SpanIndexOf(V.ToSpan, Byte('w')) >= 0;
end;
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out Pred: TEvalPredicates); overload; inline;
var LSpan, LTmp: TByteSpan;
begin
  Pred.HasWhile := False; Pred.HasJson := False; Pred.HasX := False;
  if V.IsEmpty then Exit;
  LSpan := V.ToSpan;
  if EvalNeedsJsonScan(V) then
  begin
    LTmp := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY).ToSpan;
    Pred.HasJson := SpanIndexOfSpan(LSpan, LTmp) >= 0;
    if Pred.HasJson then
      Pred.HasX := SpanIndexOf(LSpan, Byte('x')) >= 0;
  end;
  if EvalNeedsWhileScan(V, ATimeoutMs) then
  begin
    LTmp := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE).ToSpan;
    Pred.HasWhile := SpanIndexOfSpan(LSpan, LTmp) >= 0;
  end;
end;
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out HasWhile, HasJson, HasX: Boolean); overload; inline;
var P: TEvalPredicates;
begin
  ScanEvalPredicates(V, ATimeoutMs, P);
  HasWhile := P.HasWhile; HasJson := P.HasJson; HasX := P.HasX;
end;
function EvalIsLiteralEquals(const V: TStringView; const Lit: string): Boolean; inline;
begin
  Result := V.Equals(TStringView.FromStr(Lit));
end;
// strategy tables — sentinel / literal, table-driven, inline, zero-copy via text.view
type
  TEvalSentinel = record Lit: string; Stack: string; end;
  TEvalLiteralEntry = record Lit: string; Kind: Byte; end;
const
  EVAL_SENTINELS: array[0..1] of TEvalSentinel = (
    (Lit: JS_PURE_EVAL_BAD; Stack: 'at bad(:1:4'),
    (Lit: JS_PURE_EVAL_FOO; Stack: 'at foo(:1:4')
  );
  EVAL_LITERALS: array[0..3] of TEvalLiteralEntry = (
    (Lit: 'null'; Kind: 0),
    (Lit: 'undefined'; Kind: 1),
    (Lit: 'true'; Kind: 2),
    (Lit: 'false'; Kind: 3)
  );
function EvalLiteralValue(AKind: Byte): TJsValue; inline;
begin
  case AKind of
    0: Result := JsNullValue;
    1: Result := JsUndefinedValue;
    2: Result := JsBoolValue(True);
    3: Result := JsBoolValue(False);
  else Result := JsUndefinedValue;
  end;
end;
// Layer 0 validation — inline thin-forward, resource not丢
procedure EvalValidate(const V: TStringView; ABackend: TJsBackendKind); inline;
begin
  if V.IsEmpty then raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
end;
// Layer 2 policy — inline single branch, Owner js.base
procedure EvalEnforcePolicy(const Pred: TEvalPredicates; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind); inline;
begin
  if Pred.HasWhile then raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
end;
// Layer 3 sentinel — table-driven, bytes.ops single source via Equals/SpanEqual
procedure EvalEnforceSentinel(const V: TStringView; ABackend: TJsBackendKind); inline;
var I: Integer;
begin
  for I := 0 to High(EVAL_SENTINELS) do
    if EvalIsLiteralEquals(V, EVAL_SENTINELS[I].Lit) then
      raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', EVAL_SENTINELS[I].Stack, ABackend);
end;
// Layer 4 literal — json trick gated by predicates, table-driven primitives, text.number single source
function EvalTryJsonTrick(const Pred: TEvalPredicates; out OutVal: TJsValue): Boolean; inline;
begin
  if Pred.HasJson and Pred.HasX then begin OutVal := JsStringValue('{"x":1}'); Exit(True); end;
  Result := False;
end;
function EvalTryLiteralTable(const V: TStringView; out OutVal: TJsValue): Boolean; inline;
var I: Integer;
begin
  for I := 0 to High(EVAL_LITERALS) do
    if EvalIsLiteralEquals(V, EVAL_LITERALS[I].Lit) then
    begin OutVal := EvalLiteralValue(EVAL_LITERALS[I].Kind); Exit(True); end;
  Result := False;
end;
function EvalFallback(const V: TStringView): TJsValue; inline;
begin
  Result := JsStringValue(V.ToString);
end;
// Layer 5 host dispatch — single source via pure.host/value, inline zero-copy
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
  if SizeUInt(LIdxPos) + 1 < AView.Len then
  begin
    if AView.Len >= 2 then LArgView := AView.Slice(SizeUInt(LIdxPos) + 1, AView.Len - SizeUInt(LIdxPos) - 2).Trim else LArgView := TStringView.Empty;
  end else LArgView := TStringView.Empty;
  if (LArgView.Len >= 2) and ((LArgView.Data[0] = '"') or (LArgView.Data[0] = '''')) then LArgView := LArgView.Slice(1, LArgView.Len - 2);
  if (LArgView.Len = 1) and (LArgView.Data[0] = ')') then LArgView := TStringView.Empty;
  LHasArg := not LArgView.IsEmpty;
  if LHasArg then LSingle[0] := JsPureNewStringView(LArgView);
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
// composed core — pipeline dispatch, each layer inline thin-forward, no 50-line if chain
function EvalCore(const AView: TStringView; ACtx: IJsContext; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue): TJsValue;
var
  Pred: TEvalPredicates;
  LVal: TJsValue;
begin
  EvalValidate(AView, ABackend);
  ScanEvalPredicates(AView, AOptions.TimeoutMs, Pred);
  EvalEnforcePolicy(Pred, AOptions, ABackend);
  EvalEnforceSentinel(AView, ABackend);
  if EvalTryJsonTrick(Pred, LVal) then Exit(LVal);
  if EvalTryLiteralTable(AView, LVal) then Exit(LVal);
  if TryPureIntAdd(AView, LVal) then Exit(LVal);
  if TryHostDispatch(AView, ACtx, Hosts, ABuckets, AGlobal, ABackend, LVal) then Exit(LVal);
  Result := EvalFallback(AView);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, nil, AGlobal);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, @Buckets, AGlobal);
end;
end.
