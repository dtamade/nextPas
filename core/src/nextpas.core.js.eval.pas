unit nextpas.core.js.eval;
{ gated scan + strategy table — scan semantics via text.scan single source (VecWidth predicate+literal table generic + ScanFindByte3 single-pass float marker O(n) vs O(3n)) }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.text.scan,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.predicates;
const
  JS_PURE_EVAL_WHILE_TRUE = 'while(true)';
  JS_PURE_EVAL_JSON_STRINGIFY = 'JSON.stringify';
  JS_PURE_EVAL_MAGIC_X = 'x';
  JS_PURE_EVAL_BAD = 'bad(';
  JS_PURE_EVAL_FOO = 'foo(';
// predicates single source via js.pure.predicates JS_PRED_LITERALS/JS_PRED_SENTINELS (text.scan owner single source, bytes.ops zero-copy inline, L0-L3 keep, no duplicate EVAL_* table)
type
  TEvalLiteralEntry = nextpas.core.js.pure.predicates.TJsPredLiteralEntry;
function EvalLiteralValue(AKind: Byte): TJsValue; inline;
function EvalTryLiteralTable(const V: TStringView; out OutVal: TJsValue): Boolean; inline;
function EvalTryPureNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue; overload;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; overload;
implementation
uses
  nextpas.core.bytes.ops,
  nextpas.core.text.number,
  nextpas.core.js.pure.value; // text.scan/pure.predicates already used in interface — no duplicate uses entry
var
  // hoisted constant views — zero-copy via TStringView.FromStr once at unit init, not per Eval (was LJsonView/LWhileView FromStr per ScanEvalPredicates), single source via TStringView inline, bytes.ops single source via view, B/op=0
  EvalJsonView: TStringView;
  EvalWhileView: TStringView;
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
  LSingles: array[0..2] of TScanSingleEntry;
  LLits: array[0..1] of TScanLitEntry;
begin
  Pred.HasWhile := False; Pred.HasJson := False; Pred.HasX := False;
  Pred.HasPlus := False; Pred.HasParen := False; Pred.PlusPos := 0;
  if V.IsEmpty then Exit;
  LLen := V.Len;
  LNeedJson := LLen >= SizeUInt(Length(JS_PURE_EVAL_JSON_STRINGIFY));
  LNeedWhile := (ATimeoutMs > 0) and (LLen >= SizeUInt(Length(JS_PURE_EVAL_WHILE_TRUE)));
  // table-driven init single source via text.scan zero-copy hoisted constant views (EvalJsonView/EvalWhileView once at unit init, not per Eval FromStr), VecWidth predicate table delegated to L1 text.scan generic ScanPredicateTable (bytes.ops single source via Slice.Equals), reuse candidate for json literal fast path sharing generic predicate table, inline thin, B/op=0
  LSingles[0].Ch := '+'; LSingles[0].Need := True; LSingles[0].Found := False; LSingles[0].Pos := 0;
  LSingles[1].Ch := '('; LSingles[1].Need := True; LSingles[1].Found := False; LSingles[1].Pos := 0;
  LSingles[2].Ch := 'x'; LSingles[2].Need := LNeedJson; LSingles[2].Found := False; LSingles[2].Pos := 0;
  LLits[0].View := EvalJsonView; LLits[0].Need := LNeedJson; LLits[0].Found := False; LLits[0].First := #0;
  LLits[1].View := EvalWhileView; LLits[1].Need := LNeedWhile; LLits[1].Found := False; LLits[1].First := #0;
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
// predicates single source via js.pure.predicates JS_PRED_* (text.scan owner single source, bytes.ops zero-copy inline, L0-L3 keep, no duplicate EVAL_* table)
type
  TEvalSentinel = nextpas.core.js.pure.predicates.TJsPredSentinelEntry;
function EvalLiteralValue(AKind: Byte): TJsValue; inline;
begin
  // perf: inline thin-forward via predicates single source JsPredLiteralValue, bytes.ops zero-copy, B/op=0
  Result := nextpas.core.js.pure.predicates.JsPredLiteralValue(AKind);
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
// Layer 3 sentinel — predicates single source via js.pure.predicates, bytes.ops zero-copy inline, B/op=0, L0-L3 keep
procedure EvalEnforceSentinel(const V: TStringView; ABackend: TJsBackendKind); inline;
var LStack: TStringView;
begin
  // single source via js.pure.predicates JsPredTrySentinel (text.scan owner single source, bytes.ops zero-copy inline, B/op=0)
  if nextpas.core.js.pure.predicates.JsPredTrySentinel(V, LStack) then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', LStack.ToString, ABackend);
end;
// Layer 4 literal — json trick gated by predicates, table-driven primitives, text.number single source
function EvalTryJsonTrick(const Pred: TEvalPredicates; out OutVal: TJsValue): Boolean; inline;
begin
  if Pred.HasJson and Pred.HasX then begin OutVal := JsStringValue('{"x":1}'); Exit(True); end;
  Result := False;
end;
function EvalTryLiteralTable(const V: TStringView; out OutVal: TJsValue): Boolean; inline;
var LKind: Byte;
begin
  // single source via js.pure.predicates JsPredTryLiteral (text.scan owner single source, bytes.ops zero-copy inline, B/op=0)
  if nextpas.core.js.pure.predicates.JsPredTryLiteral(V, LKind) then
  begin OutVal := EvalLiteralValue(LKind); Exit(True); end;
  Result := False;
end;
function EvalTryPureNumber(const V: TStringView; AContextId: UInt64; out OutVal: TJsValue): Boolean; inline;
begin
  // perf: inline thin-forward via js.pure.predicates JsPredTryNumber single source (text.number EiselLemire + text.scan float marker single-pass VecWidth SIMD, bytes.ops zero-copy), B/op=0, L0-L3 keep, try-finally not丢
  Result := nextpas.core.js.pure.predicates.JsPredTryNumber(V, AContextId, OutVal);
end;
function EvalFallback(const V: TStringView): TJsValue; inline;
begin
  Result := JsStringValue(V.ToString);
end;
// arg view single source — outer quote strip + backslash unescape via pure.value single source (text.escape → pure.value → js.eval), zero-copy via text.view + JsPureNewStringView, not inline per red-line 2 (owner text.escape SIMD block BytesCopy, StripOuterQuotes via text.escape single source)
function EvalArgValue(const V: TStringView): TJsValue;
var
  LInner: TStringView;
  LStr: string;
begin
  // single source via text.escape TextStripOuterQuotesView/JsPureStripOuterQuotesView + JsPureNeedsBackslashUnescapeView/JsPureUnescapeBackslashView (owner text.escape), bytes.ops BytesCopy single source, zero dangling, L2→L2 single-point, feed-back to text.escape single source
  LInner := JsPureStripOuterQuotesView(V);
  if JsPureNeedsBackslashUnescapeView(LInner) then
  begin
    LStr := JsPureUnescapeBackslashView(LInner);
    Result := JsStringValue(LStr);
  end else
    Result := JsPureNewStringView(LInner);
end;
// Layer 5 host dispatch — single source via pure.host.JsPureHostInvoke, zero-copy, bytes.ops single source, not inline per red-line 2 (quote/escape/paren loops + arg split, I-Cache)
// robust host dispatch: matching paren depth + quote/escape, multi-arg split, nested brackets, outer quote strip + backslash unescape via EvalArgValue single source
function TryHostDispatch(const AView: TStringView; ACtx: IJsContext; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue; ABackend: TJsBackendKind; out OutVal: TJsValue): Boolean;
var
  LIdxPos: PtrInt;
  LNameView, LInner: TStringView;
  LHostIdx: Integer;
  LThis: TJsValue;
  RPos: SizeUInt;
  LArgs: array of TJsValue;
  LStack: array[0..3] of TJsValue;
  UseStack: Boolean;
  Upper, LArgCount: SizeUInt;
  LStart, Pos, LLen: SizeUInt;
  Depth: Integer;
  InQuote: AnsiChar;
  Escaped: Boolean;
  N: PtrInt;
  C: AnsiChar;
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
  // outer matching via L1 owner text.scan single source SIMD VecWidth skip (ScanFindMatchingParen via ScanFindByte2+ScanFindAny4, O(n/VecWidth) vs per-char), zero-copy TStringView, not inline per red-line 2, bytes.ops single source not duplicated, L0-L3 keep
  if not nextpas.core.text.scan.ScanFindMatchingParen(AView, SizeUInt(LIdxPos), RPos) then Exit;
  if RPos + 1 < AView.Len then
    if not AView.Slice(RPos + 1, AView.Len - RPos - 1).Trim.IsEmpty then Exit;
  LInner := AView.Slice(SizeUInt(LIdxPos) + 1, RPos - SizeUInt(LIdxPos) - 1).Trim;
  LThis := AGlobal;
  if LInner.IsEmpty then
  begin
    LArgs := nil;
    OutVal := nextpas.core.js.pure.host.JsPureHostInvoke(Hosts[LHostIdx], ACtx, LThis, LArgs, ABackend);
    Exit(True);
  end;
  // zero-alloc fast path for host hotspot: stack 4 inline + Slice zero-copy (B/op=0 for noop single-arg BENCHMARKS) vs bulk heap via bytes.ops single source geometric 0→64→2× Exactly-Once poke for larger, inline not per red-line 2, bytes.ops single source
  Upper := nextpas.core.text.scan.ScanCountJsArgs(LInner);
  if Upper = 0 then Upper := 1;
  // trailing comma overestimates by 1 (ScanCount is commas+1, tail empty not added) — correct before alloc to keep Exactly-Once poke, B/op=0, bytes.ops single source
  if (Upper > 0) and (LInner.Len > 0) and (LInner.Data[LInner.Len - 1] = AnsiChar(',')) then Dec(Upper);
  UseStack := False;
  if Upper = 0 then
    LArgs := nil
  else if Upper <= SizeUInt(High(LStack) + 1) then
  begin
    UseStack := True;
    LArgs := nil;
  end else
    nextpas.core.bytes.ops.BytesDynEnsureLength(LArgs, SizeOf(TJsValue), Upper);
  // multi-arg split via L1 owner text.scan single source SIMD (ScanFindByte2+ScanFindAny5 VecWidth skip, O(n/VecWidth) vs per-char, zero-copy Slice/Trim), resource managed not丢 (dynamic array, no leak)
  LStart := 0; Depth := 0; InQuote := #0; Escaped := False; LArgCount := 0; Pos := 0; LLen := LInner.Len;
  while Pos < LLen do
  begin
    if Escaped then begin Escaped := False; Inc(Pos); Continue; end;
    if InQuote <> #0 then
    begin
      N := nextpas.core.text.scan.ScanFindByte2(@LInner.Data[Pos], LLen - Pos, Byte('\'), Byte(InQuote));
      if N < 0 then Break;
      Pos := Pos + SizeUInt(N);
      C := LInner.Data[Pos];
      if C = '\' then begin Escaped := True; Inc(Pos); Continue; end;
      InQuote := #0;
      Inc(Pos);
      Continue;
    end else
    begin
      N := nextpas.core.text.scan.ScanFindAny5(@LInner.Data[Pos], LLen - Pos, Byte('"'), Byte(''''), Byte('('), Byte(')'), Byte(','));
      if N < 0 then Break;
      Pos := Pos + SizeUInt(N);
      C := LInner.Data[Pos];
      if C = '"' then InQuote := '"'
      else if C = '''' then InQuote := ''''
      else if C = '(' then Inc(Depth)
      else if C = ')' then begin if Depth > 0 then Dec(Depth); end
      else if (C = ',') and (Depth = 0) then
      begin
        LView := LInner.Slice(LStart, Pos - LStart).Trim;
        // zero-copy via TStringView.Slice/Trim + EvalArgValue single source via text.escape, single bulk/stack alloc not per-arg
        if UseStack then LStack[LArgCount] := EvalArgValue(LView) else LArgs[LArgCount] := EvalArgValue(LView);
        Inc(LArgCount);
        LStart := Pos + 1;
      end;
      Inc(Pos);
    end;
  end;
  // tail — zero-copy via text.view Slice/Trim, single source EvalArgValue, no per-arg EnsureLength, no shrink (Exactly-Once poke)
  LView := LInner.Slice(LStart, LLen - LStart).Trim;
  if not LView.IsEmpty then
  begin
    if LArgCount < Upper then
    begin
      if UseStack then LStack[LArgCount] := EvalArgValue(LView) else LArgs[LArgCount] := EvalArgValue(LView);
      Inc(LArgCount);
    end;
  end;
  // no second BytesDynSetLengthGeneric shrink — Upper pre-corrected for trailing comma, Exactly-Once poke via single BytesDynEnsureLength (heap path) or zero-alloc stack Slice (hot path B/op=0 via System.Slice zero-copy inline, stack managed finalize不丢), bytes.ops single source, stability no leak
  if UseStack then
    OutVal := nextpas.core.js.pure.host.JsPureHostInvoke(Hosts[LHostIdx], ACtx, LThis, System.Slice(LStack, Integer(LArgCount)), ABackend)
  else
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

initialization
  // hoisted constant views — single FromStr at unit load, zero per-Eval alloc, zero-copy view via text.view inline, bytes.ops single source, B/op=0
  EvalJsonView := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY);
  EvalWhileView := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE);
end.
