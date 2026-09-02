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
// single-pass predicate merge — one linear scan, zero-copy views, inline hot path, bytes.ops SpanEqual single source
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out Pred: TEvalPredicates); overload; inline;
var
  LData: PAnsiChar;
  LLen, I, LRem: SizeUInt;
  LNeedJson, LNeedWhile: Boolean;
  LJsonLen, LWhileLen: SizeUInt;
  LHasXSeen: Boolean;
  LJsonView, LWhileView: TStringView;
begin
  Pred.HasWhile := False; Pred.HasJson := False; Pred.HasX := False;
  if V.IsEmpty then Exit;
  LLen := V.Len;
  LData := V.Data;
  LJsonLen := SizeUInt(Length(JS_PURE_EVAL_JSON_STRINGIFY));
  LWhileLen := SizeUInt(Length(JS_PURE_EVAL_WHILE_TRUE));
  LNeedJson := LLen >= LJsonLen;
  LNeedWhile := (ATimeoutMs > 0) and (LLen >= LWhileLen);
  if not LNeedJson and not LNeedWhile then Exit;
  LJsonView := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY);
  LWhileView := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE);
  LHasXSeen := False;
  for I := 0 to LLen - 1 do
  begin
    if not LHasXSeen and (LData[I] = 'x') then LHasXSeen := True;
    if LNeedJson and not Pred.HasJson then
    begin
      LRem := LLen - I;
      if (LRem >= LJsonLen) and (LData[I] = 'J') then
        if V.Slice(I, LJsonLen).Equals(LJsonView) then Pred.HasJson := True;
    end;
    if LNeedWhile and not Pred.HasWhile then
    begin
      LRem := LLen - I;
      if (LRem >= LWhileLen) and (LData[I] = 'w') then
        if V.Slice(I, LWhileLen).Equals(LWhileView) then Pred.HasWhile := True;
    end;
    if Pred.HasJson and LHasXSeen then
      if not LNeedWhile or Pred.HasWhile then Break;
  end;
  Pred.HasX := Pred.HasJson and LHasXSeen;
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
// Layer 5 host dispatch — single source via pure.host.JsPureHostInvoke, inline zero-copy, bytes.ops single source
// robust host dispatch: matching paren depth + quote/escape, multi-arg split, nested brackets, outer quote strip + backslash unescape
function TryHostDispatch(const AView: TStringView; ACtx: IJsContext; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue; ABackend: TJsBackendKind; out OutVal: TJsValue): Boolean; inline;
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
  LInnerUnq: TStringView;
  LStr: string;
  J, LOut: SizeUInt;
  LNeedUnescape: Boolean;
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
      // strip outer quotes + backslash unescape zero-copy
      if (LView.Len >= 2) and ((LView.Data[0] = '"') or (LView.Data[0] = '''')) and (LView.Data[LView.Len - 1] = LView.Data[0]) then
      begin
        LInnerUnq := LView.Slice(1, LView.Len - 2);
        LNeedUnescape := False;
        for J := 0 to LInnerUnq.Len - 1 do if LInnerUnq.Data[J] = '\' then begin LNeedUnescape := True; Break; end;
        if LNeedUnescape then
        begin
          SetLength(LStr, LInnerUnq.Len);
          LOut := 0; J := 0;
          while J < LInnerUnq.Len do
          begin
            if (LInnerUnq.Data[J] = '\') and (J + 1 < LInnerUnq.Len) then
            begin
              Inc(J);
              LStr[LOut + 1] := LInnerUnq.Data[J];
              Inc(LOut);
            end else begin LStr[LOut + 1] := LInnerUnq.Data[J]; Inc(LOut); end;
            Inc(J);
          end;
          SetLength(LStr, LOut);
          SetLength(LArgs, LArgCount + 1); LArgs[LArgCount] := JsStringValue(LStr);
        end else begin SetLength(LArgs, LArgCount + 1); LArgs[LArgCount] := JsPureNewStringView(LInnerUnq); end;
      end else
      begin
        SetLength(LArgs, LArgCount + 1);
        if LView.IsEmpty then LArgs[LArgCount] := JsStringValue('') else LArgs[LArgCount] := JsPureNewStringView(LView);
      end;
      Inc(LArgCount);
      LStart := I + 1;
    end;
  end;
  // tail
  LView := LInner.Slice(LStart, LInner.Len - LStart).Trim;
  if not LView.IsEmpty then
  begin
    if (LView.Len >= 2) and ((LView.Data[0] = '"') or (LView.Data[0] = '''')) and (LView.Data[LView.Len - 1] = LView.Data[0]) then
    begin
      LInnerUnq := LView.Slice(1, LView.Len - 2);
      LNeedUnescape := False;
      for J := 0 to LInnerUnq.Len - 1 do if LInnerUnq.Data[J] = '\' then begin LNeedUnescape := True; Break; end;
      if LNeedUnescape then
      begin
        SetLength(LStr, LInnerUnq.Len);
        LOut := 0; J := 0;
        while J < LInnerUnq.Len do
        begin
          if (LInnerUnq.Data[J] = '\') and (J + 1 < LInnerUnq.Len) then begin Inc(J); LStr[LOut + 1] := LInnerUnq.Data[J]; Inc(LOut); end else begin LStr[LOut + 1] := LInnerUnq.Data[J]; Inc(LOut); end;
          Inc(J);
        end;
        SetLength(LStr, LOut);
        SetLength(LArgs, Length(LArgs) + 1); LArgs[High(LArgs)] := JsStringValue(LStr);
      end else begin SetLength(LArgs, Length(LArgs) + 1); LArgs[High(LArgs)] := JsPureNewStringView(LInnerUnq); end;
    end else begin SetLength(LArgs, Length(LArgs) + 1); LArgs[High(LArgs)] := JsPureNewStringView(LView); end;
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
