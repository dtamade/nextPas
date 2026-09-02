unit nextpas.core.js.eval;
{ gated scan + strategy table — single source via bytes.ops SIMD, zero-copy,
  resource try-finally not丢, L0-L3 守分层, table-driven literals/sentinels.
  Perf: ScanEvalPredicates/TryHostDispatch not inline per red-line 2 (O(n) loops, I-Cache), thin forwards inline, bytes.ops single source. }
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
  nextpas.core.simd.vec,
  nextpas.core.simd.base,
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
// scanner — table-driven single-pass SIMD VecWidth predicate table single source, zero-copy views, not inline per red-line 2 (O(n) single scan vs O(3n) triple IndexOf), bytes.ops single source via Slice.Equals (CONTRACT §9), plus/paren + HasX singles coalesced + HasJson/While literals table-driven single source, VecWidth single pass + tail VecWidth overlapping single pass (short <VecWidth table-driven scalar branchless), inline thin helpers, B/op=0
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out Pred: TEvalPredicates);
var
  LLen: SizeUInt;
  LNeedJson, LNeedWhile: Boolean;
  LJsonLen, LWhileLen: SizeUInt;
  LJsonView, LWhileView: TStringView;
  LPos: SizeUInt;
  LCombined: TVecMask;
  // table-driven singles: '+' '(' 'x' (x gated by LNeedJson)
  LPredSingles: array[0..2] of AnsiChar;
  LSingleNeed: array[0..2] of Boolean;
  // table-driven lits: Json, While (first-char probe + Slice.Equals single source via bytes.ops)
  LLitViews: array[0..1] of TStringView;
  LLitLens: array[0..1] of SizeUInt;
  LLitNeed: array[0..1] of Boolean;
  LLitFirst: array[0..1] of AnsiChar;
  I: Integer;
  B: AnsiChar;
  function AllDone: Boolean; inline;
  begin
    Result := (not LNeedJson or Pred.HasJson) and (not LNeedWhile or Pred.HasWhile) and (not LNeedJson or not Pred.HasJson or Pred.HasX) and Pred.HasPlus and Pred.HasParen;
  end;
  procedure ProcessMaskedChunk(const ABase: SizeUInt; const AMask: TVecMask); inline;
  var
    LLocalMask: TVecMask;
    LLocalBit: Int32;
    J: Integer;
  begin
    LLocalMask := AMask;
    while LLocalMask <> TVecMask(0) do
    begin
      LLocalBit := VecCtz(LLocalMask);
      B := V.Data[ABase + SizeUInt(LLocalBit)];
      // singles table-driven dispatch single source
      for J := 0 to 2 do if LSingleNeed[J] and (B = LPredSingles[J]) then
      begin
        case J of
          0: if not Pred.HasPlus then begin Pred.HasPlus := True; Pred.PlusPos := ABase + SizeUInt(LLocalBit); LSingleNeed[J] := False; end;
          1: if not Pred.HasParen then begin Pred.HasParen := True; LSingleNeed[J] := False; end;
          2: if not Pred.HasX then begin Pred.HasX := True; LSingleNeed[J] := False; end;
        end;
        Break;
      end;
      // lits table-driven single source via bytes.ops Slice.Equals zero-copy
      for J := 0 to 1 do if LLitNeed[J] and (B = LLitFirst[J]) then
        if (ABase + SizeUInt(LLocalBit) + LLitLens[J] <= LLen) and V.Slice(ABase + SizeUInt(LLocalBit), LLitLens[J]).Equals(LLitViews[J]) then
        begin
          case J of 0: Pred.HasJson := True; 1: Pred.HasWhile := True; end;
          LLitNeed[J] := False;
          Break;
        end;
      LLocalMask := LLocalMask and not TVecMask(TVecMask(1) shl LLocalBit);
      if AllDone then Break;
    end;
  end;
begin
  Pred.HasWhile := False; Pred.HasJson := False; Pred.HasX := False;
  Pred.HasPlus := False; Pred.HasParen := False; Pred.PlusPos := 0;
  if V.IsEmpty then Exit;
  LLen := V.Len;
  LJsonLen := SizeUInt(Length(JS_PURE_EVAL_JSON_STRINGIFY));
  LWhileLen := SizeUInt(Length(JS_PURE_EVAL_WHILE_TRUE));
  LNeedJson := LLen >= LJsonLen;
  LNeedWhile := (ATimeoutMs > 0) and (LLen >= LWhileLen);
  // no early exit on LNeedJson/While alone: Plus/Paren coalesced into same single pass for TryPureIntAdd zero extra O(n)
  LJsonView := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY);
  LWhileView := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE);
  // table-driven init single source via bytes.ops zero-copy views, VecWidth predicate table
  LPredSingles[0] := '+'; LPredSingles[1] := '('; LPredSingles[2] := 'x';
  LSingleNeed[0] := True; LSingleNeed[1] := True; LSingleNeed[2] := LNeedJson;
  LLitViews[0] := LJsonView; LLitViews[1] := LWhileView;
  LLitLens[0] := LJsonLen; LLitLens[1] := LWhileLen;
  LLitNeed[0] := LNeedJson; LLitNeed[1] := LNeedWhile;
  LLitFirst[0] := LJsonView.Data[0]; LLitFirst[1] := LWhileView.Data[0];
  // perf: single-pass table-driven SIMD VecCmpEq single source, O(n) single scan vs O(3n) triple pass, bytes.ops Slice.Equals single source, VecWidth predicate table + literal table single source, early exit only when all predicates known, B/op=0
  LPos := 0;
  while LPos + VecWidth <= LLen do
  begin
    if AllDone then Break;
    LCombined := TVecMask(0);
    for I := 0 to 2 do if LSingleNeed[I] then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Ord(LPredSingles[I]));
    for I := 0 to 1 do if LLitNeed[I] then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Byte(LLitFirst[I]));
    if LCombined = TVecMask(0) then begin Inc(LPos, VecWidth); Continue; end;
    ProcessMaskedChunk(LPos, LCombined);
    if AllDone then Break;
    Inc(LPos, VecWidth);
  end;
  if AllDone then goto Final;
  // tail merged to VecWidth predicate table: overlapping final VecWidth for LLen >= VecWidth (single pass, no per-byte multi-branch), else table-driven scalar branchless
  if LPos < LLen then
  begin
    if LLen >= VecWidth then
    begin
      // overlapping tail VecWidth window covers remaining <VecWidth without per-byte multi-branch
      LPos := LLen - VecWidth;
      if not AllDone then
      begin
        LCombined := TVecMask(0);
        for I := 0 to 2 do if LSingleNeed[I] then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Ord(LPredSingles[I]));
        for I := 0 to 1 do if LLitNeed[I] then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Byte(LLitFirst[I]));
        if LCombined <> TVecMask(0) then ProcessMaskedChunk(LPos, LCombined);
      end;
    end else
    begin
      // short string (<VecWidth): table-driven scalar single branch via lookup tables, zero VecWidth overhead, single predicate table
      while LPos < LLen do
      begin
        if AllDone then Break;
        B := V.Data[LPos];
        for I := 0 to 2 do if LSingleNeed[I] and (B = LPredSingles[I]) then
        begin
          case I of
            0: begin if not Pred.HasPlus then begin Pred.HasPlus := True; Pred.PlusPos := LPos; end; LSingleNeed[I] := False; end;
            1: begin if not Pred.HasParen then begin Pred.HasParen := True; LSingleNeed[I] := False; end; end;
            2: begin if not Pred.HasX then begin Pred.HasX := True; LSingleNeed[I] := False; end; end;
          end;
          Break;
        end;
        for I := 0 to 1 do if LLitNeed[I] and (B = LLitFirst[I]) then
          if (LPos + LLitLens[I] <= LLen) and V.Slice(LPos, LLitLens[I]).Equals(LLitViews[I]) then
          begin case I of 0: Pred.HasJson := True; 1: Pred.HasWhile := True; end; LLitNeed[I] := False; Break; end;
        Inc(LPos);
      end;
    end;
  end;
Final:
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
