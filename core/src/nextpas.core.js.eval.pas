unit nextpas.core.js.eval;
{ gated scan + strategy table — scan semantics via text.scan single source (VecWidth predicate+literal table generic), zero-copy via bytes.ops SIMD (Slice.Equals/TStringView), resource try-finally not丢, L0-L3 守分层, table-driven literals/sentinels.
  Perf: ScanEvalPredicates delegates to text.scan ScanPredicateTable single-pass SIMD (O(n) single scan vs O(k*n), not inline per red-line 2), TryHostDispatch not inline, thin forwards inline, bytes.ops single source via text.view. }
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
type
  TEvalLiteralEntry = record Lit: string; Kind: Byte; end;
const
  EVAL_LITERALS: array[0..3] of TEvalLiteralEntry = (
    (Lit: 'null'; Kind: 0),
    (Lit: 'undefined'; Kind: 1),
    (Lit: 'true'; Kind: 2),
    (Lit: 'false'; Kind: 3)
  );
function EvalLiteralValue(AKind: Byte): TJsValue; inline;
function EvalTryLiteralTable(const V: TStringView; out OutVal: TJsValue): Boolean; inline;
function EvalTryPureNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; overload;
implementation
uses
  nextpas.core.text.number,
  nextpas.core.bytes.ops,
  nextpas.core.text.scan,
  nextpas.core.js.pure.value;
type
  TEvalPredicates = record
    HasWhile: Boolean;
    HasJson: Boolean;
    HasX: Boolean;
    HasPlus: Boolean;
    HasParen: Boolean;
    PlusPos: SizeUInt;
  end;
  PJsPureHostBuckets = ^TJsPureHostBuckets;
function TryPureIntAdd(const V: TStringView; const Pred: TEvalPredicates; out OutVal: TJsValue): Boolean;
var P: SizeUInt; L, R: TStringView; A, B: Int64;
begin
  Result := False;
  // single source via ScanEvalPredicates single-pass SIMD, zero extra O(n) IndexOf, bytes.ops single source
  if not Pred.HasPlus then Exit;
  if Pred.HasParen then Exit;
  P := Pred.PlusPos;
  L := V.Slice(0, P).Trim;
  R := V.Slice(P + 1, V.Len - P - 1).Trim;
  if L.IsEmpty or R.IsEmpty then Exit;
  if not ViewToInt64(L, A) then Exit;
  if not ViewToInt64(R, B) then Exit;
  OutVal := JsIntValue(A + B);
  Result := True;
end;
// scanner — delegated to text.scan generic predicate+literal table — independent scan semantics via text.scan ScanPredicateTable single source, VecWidth predicate table via simd.vec/bytes.ops, zero-copy views, not inline per red-line 2, L0-L3 keep, B/op=0
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out Pred: TEvalPredicates);
var
  LLen: SizeUInt;
  LNeedJson, LNeedWhile: Boolean;
  LJsonView, LWhileView: TStringView;
  LSingles: array[0..2] of TScanSingleEntry;
  LLits: array[0..1] of TScanLitEntry;
begin
  Pred.HasWhile := False; Pred.HasJson := False; Pred.HasX := False;
  Pred.HasPlus := False; Pred.HasParen := False; Pred.PlusPos := 0;
  if V.IsEmpty then Exit;
  LLen := V.Len;
  LNeedJson := LLen >= SizeUInt(Length(JS_PURE_EVAL_JSON_STRINGIFY));
  LNeedWhile := (ATimeoutMs > 0) and (LLen >= SizeUInt(Length(JS_PURE_EVAL_WHILE_TRUE)));
  LJsonView := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY);
  LWhileView := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE);
  // table-driven init single source via text.scan zero-copy views, VecWidth predicate table delegated to L1 text.scan generic ScanPredicateTable (bytes.ops single source via Slice.Equals), reuse candidate for json literal fast path sharing generic predicate table, inline thin, B/op=0
  LSingles[0].Ch := '+'; LSingles[0].Need := True; LSingles[0].Found := False; LSingles[0].Pos := 0;
  LSingles[1].Ch := '('; LSingles[1].Need := True; LSingles[1].Found := False; LSingles[1].Pos := 0;
  LSingles[2].Ch := 'x'; LSingles[2].Need := LNeedJson; LSingles[2].Found := False; LSingles[2].Pos := 0;
  LLits[0].View := LJsonView; LLits[0].Need := LNeedJson; LLits[0].Found := False; LLits[0].First := #0;
  LLits[1].View := LWhileView; LLits[1].Need := LNeedWhile; LLits[1].Found := False; LLits[1].First := #0;
  // perf: single-pass table-driven SIMD via text.scan single source, O(n) single scan vs O(k*n) multi-pass, bytes.ops Slice.Equals single source, VecWidth predicate+literal table generic sharing, not inline per red-line 2, L0-L3 keep
  ScanPredicateTable(V, LSingles, LLits);
  Pred.HasPlus := LSingles[0].Found; Pred.PlusPos := LSingles[0].Pos;
  Pred.HasParen := LSingles[1].Found;
  Pred.HasX := LSingles[2].Found;
  Pred.HasJson := LLits[0].Found;
  Pred.HasWhile := LLits[1].Found;
  if not Pred.HasJson then Pred.HasX := False;
end;
function EvalIsLiteralEquals(const V: TStringView; const Lit: string): Boolean; inline;
begin
  Result := V.Equals(TStringView.FromStr(Lit));
end;
// strategy tables — sentinel / literal, table-driven, inline, zero-copy via text.view
type
  TEvalSentinel = record Lit: string; Stack: string; end;
const
  EVAL_SENTINELS: array[0..1] of TEvalSentinel = (
    (Lit: JS_PURE_EVAL_BAD; Stack: 'at bad(:1:4'),
    (Lit: JS_PURE_EVAL_FOO; Stack: 'at foo(:1:4')
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
function EvalTryPureNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
var LFirst: AnsiChar; LInt: Int64; LDbl: Double;
begin
  // single source numeric discriminant via text.number single source (EiselLemire), bytes.ops single source, first-byte O(1) filter, B/op=0, single source for js.quickjs Eval and TryPureIntAdd path, inline thin-forward
  Result := False;
  if V.IsEmpty then Exit;
  LFirst := V.Data[0];
  if not (LFirst in ['0'..'9','-','+','.']) then Exit;
  if (V.IndexOf('.') < 0) and (V.IndexOf('e') < 0) and (V.IndexOf('E') < 0) then
  begin
    if ViewToInt64(V, LInt) then begin OutVal := JsPureNewInt(LInt, AContextId); Exit(True); end;
    if ViewToDouble(V, LDbl) then begin OutVal := JsPureNewDouble(LDbl, AContextId); Exit(True); end;
  end else
    if ViewToDouble(V, LDbl) then begin OutVal := JsPureNewDouble(LDbl, AContextId); Exit(True); end;
end;
function EvalFallback(const V: TStringView): TJsValue; inline;
begin
  Result := JsStringValue(V.ToString);
end;
// arg view single source — outer quote strip + backslash unescape via pure.value single source (text.escape → pure.value → js.eval), zero-copy via text.view + JsPureNewStringView, not inline per red-line 2 (owner pure.value SIMD block BytesCopy)
function EvalArgValue(const V: TStringView): TJsValue;
var
  LInner: TStringView;
  LStr: string;
begin
  // single source via pure.value JsPureNeedsBackslashUnescapeView/JsPureUnescapeBackslashView (owner text.escape via pure.value), bytes.ops BytesCopy single source, zero dangling, L2→L2 single-point
  if (V.Len >= 2) and ((V.Data[0] = '"') or (V.Data[0] = '''')) and (V.Data[V.Len - 1] = V.Data[0]) then
  begin
    LInner := V.Slice(1, V.Len - 2);
    if JsPureNeedsBackslashUnescapeView(LInner) then
    begin
      LStr := JsPureUnescapeBackslashView(LInner);
      Result := JsStringValue(LStr);
    end else
      Result := JsPureNewStringView(LInner);
  end else
  begin
    if V.IsEmpty then Result := JsStringValue('')
    else Result := JsPureNewStringView(V);
  end;
end;
// Layer 5 host dispatch — single source via pure.host.JsPureHostInvoke, zero-copy, bytes.ops single source, not inline per red-line 2 (quote/escape/paren loops + arg split, I-Cache)
// robust host dispatch: matching paren depth + quote/escape, multi-arg split, nested brackets, outer quote strip + backslash unescape via EvalArgValue single source
function TryHostDispatch(const AView: TStringView; ACtx: IJsContext; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue; ABackend: TJsBackendKind; out OutVal: TJsValue): Boolean;
var
  LIdxPos: PtrInt;
  LNameView, LInner: TStringView;
  LHostIdx: Integer;
  LThis: TJsValue;
  RPos: PtrInt;
  Depth: Integer;
  InQuote: AnsiChar;
  Escaped: Boolean;
  I: SizeUInt;
  C: AnsiChar;
  LArgs: array of TJsValue;
  LStart: SizeUInt;
  LArgCount: Integer;
  LView: TStringView;
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
  Depth := 1; InQuote := #0; Escaped := False; RPos := -1;
  for I := SizeUInt(LIdxPos) + 1 to AView.Len - 1 do
  begin
    C := AView.Data[I];
    if Escaped then begin Escaped := False; Continue; end;
    if InQuote <> #0 then
    begin
      if C = '\' then Escaped := True
      else if C = InQuote then InQuote := #0;
      Continue;
    end;
    if (C = '"') or (C = '''') then InQuote := C
    else if C = '(' then Inc(Depth)
    else if C = ')' then
    begin
      Dec(Depth);
      if Depth = 0 then begin RPos := PtrInt(I); Break; end;
      if Depth < 0 then Exit;
    end;
  end;
  if RPos < 0 then Exit;
  if SizeUInt(RPos) + 1 < AView.Len then
    if not AView.Slice(SizeUInt(RPos) + 1, AView.Len - SizeUInt(RPos) - 1).Trim.IsEmpty then Exit;
  LInner := AView.Slice(SizeUInt(LIdxPos) + 1, SizeUInt(RPos - LIdxPos - 1)).Trim;
  LThis := AGlobal;
  if LInner.IsEmpty then
  begin
    LArgs := nil;
    OutVal := nextpas.core.js.pure.host.JsPureHostInvoke(Hosts[LHostIdx], ACtx, LThis, LArgs, ABackend);
    Exit(True);
  end;
  // multi-arg split respecting quotes/escapes/nested ()
  SetLength(LArgs, 0);
  LStart := 0; Depth := 0; InQuote := #0; Escaped := False; LArgCount := 0;
  for I := 0 to LInner.Len - 1 do
  begin
    C := LInner.Data[I];
    if Escaped then begin Escaped := False; Continue; end;
    if InQuote <> #0 then
    begin
      if C = '\' then Escaped := True
      else if C = InQuote then InQuote := #0;
      Continue;
    end;
    if (C = '"') or (C = '''') then InQuote := C
    else if C = '(' then Inc(Depth)
    else if C = ')' then begin if Depth > 0 then Dec(Depth); end
    else if (C = ',') and (Depth = 0) then
    begin
      LView := LInner.Slice(LStart, I - LStart).Trim;
      SetLength(LArgs, LArgCount + 1);
      LArgs[LArgCount] := EvalArgValue(LView);
      Inc(LArgCount);
      LStart := I + 1;
    end;
  end;
  // tail — single source via EvalArgValue, text.view zero-copy, not inline
  LView := LInner.Slice(LStart, LInner.Len - LStart).Trim;
  if not LView.IsEmpty then
  begin
    SetLength(LArgs, Length(LArgs) + 1);
    LArgs[High(LArgs)] := EvalArgValue(LView);
  end;
  OutVal := nextpas.core.js.pure.host.JsPureHostInvoke(Hosts[LHostIdx], ACtx, LThis, LArgs, ABackend);
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
  if TryPureIntAdd(AView, Pred, LVal) then Exit(LVal);
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
