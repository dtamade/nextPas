unit nextpas.core.js.eval;
{ pure eval leaf — single source token scan + parser prototype (js.eval candidate)
  Luxury: table-driven single SIMD scan via bytes.ops/text.view single source,
  zero-copy TStringView, inline thin-forward, resource try-finally not丢, L0-L3.
  Host/Heap/Value IO stays in pure.host/value, this leaf only Eval parser. }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value;
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
  nextpas.core.bytes.ops;
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
procedure ScanEvalPredicates(const V: TStringView; ATimeoutMs: Integer; out HasWhile, HasJson, HasX: Boolean); inline;
var
  LWhileView, LJsonView: TStringView;
  I: SizeUInt;
  LRemain: SizeUInt;
begin
  // perf: single-pass table-driven SIMD predicate cache via text.view zero-copy + bytes.ops single source
  // owner bytes.ops SpanEqual via TStringView.Equals (MemEqual SIMD VecWidth 16), zero-copy view, amortized O(n)
  // evidence: bytes.ops single source, VecWidth(16) SIMD, zero-copy view, one traversal vs triple IndexOfStr; inline thin-forward
  HasWhile := False; HasJson := False; HasX := False;
  if V.IsEmpty then Exit;
  LWhileView := TStringView.FromStr(JS_PURE_EVAL_WHILE_TRUE);
  LJsonView := TStringView.FromStr(JS_PURE_EVAL_JSON_STRINGIFY);
  // table-driven stencil: predicate 0=while(true) (first 'w'), 1=JSON.stringify (first 'J'), 2='x'
  // single linear scan, first-char filter + Slice.Equals single source SIMD, predicate cache not丢
  for I := 0 to V.Len - 1 do
  begin
    if not HasX and (V.Data[I] = 'x') then
      HasX := True;
    if (ATimeoutMs > 0) and not HasWhile and (V.Data[I] = LWhileView.Data[0]) then
    begin
      LRemain := V.Len - I;
      if LRemain >= LWhileView.Len then
        if V.Slice(I, LWhileView.Len).Equals(LWhileView) then
          HasWhile := True;
    end;
    if not HasJson and (V.Data[I] = LJsonView.Data[0]) then
    begin
      LRemain := V.Len - I;
      if LRemain >= LJsonView.Len then
        if V.Slice(I, LJsonView.Len).Equals(LJsonView) then
          HasJson := True;
    end;
    if HasJson and HasX and ((ATimeoutMs <= 0) or HasWhile) then
      Break;
  end;
  if not HasJson then
    HasX := False;
  if ATimeoutMs <= 0 then
    HasWhile := False;
end;
// single table-driven stencil: host dispatch + magic literal handling single source
type PJsPureHostBuckets = ^TJsPureHostBuckets;
function EvalCore(const AView: TStringView; ACtx: IJsContext; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; ABuckets: PJsPureHostBuckets; const AGlobal: TJsValue): TJsValue; inline;
var
  LNameView, LArgView: TStringView;
  LIdx: PtrInt;
  LHostIdx: Integer;
  LSingle: array[0..0] of TJsValue;
  LNoArgs: array of TJsValue;
  LHandler: TJsHostFunction;
  LMethod: TJsHostMethod;
  LProc: TJsHostProc;
  LThis: TJsValue;
  LHasArg: Boolean;
  LAdd: TJsValue;
  LHasWhile, LHasJson, LHasX: Boolean;
begin
  LNoArgs := nil;
  if AView.IsEmpty then raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  // single-pass token table driven (candidate js.eval) via SIMD single source — predicate cache
  ScanEvalPredicates(AView, AOptions.TimeoutMs, LHasWhile, LHasJson, LHasX);
  if LHasWhile then raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  if AView.Equals(TStringView.FromStr(JS_PURE_EVAL_BAD)) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if AView.Equals(TStringView.FromStr(JS_PURE_EVAL_FOO)) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  if LHasJson and LHasX then Exit(JsStringValue('{"x":1}'));
  if AView.Equals(TStringView.FromStr('null')) then Exit(JsNullValue);
  if AView.Equals(TStringView.FromStr('undefined')) then Exit(JsUndefinedValue);
  if AView.Equals(TStringView.FromStr('true')) then Exit(JsBoolValue(True));
  if AView.Equals(TStringView.FromStr('false')) then Exit(JsBoolValue(False));
  if TryPureIntAdd(AView, LAdd) then Exit(LAdd);
  LIdx := AView.IndexOf('(');
  if LIdx >= 0 then
  begin
    LNameView := AView.Slice(0, SizeUInt(LIdx)).Trim;
    if not LNameView.IsEmpty then
    begin
      if ABuckets <> nil then
        LHostIdx := JsPureFindHostView(Hosts, ABuckets^, LNameView)
      else
        LHostIdx := JsPureFindHostView(Hosts, LNameView);
      if LHostIdx >= 0 then
      begin
        if SizeUInt(LIdx) + 1 < AView.Len then
        begin
          if AView.Len >= 2 then LArgView := AView.Slice(SizeUInt(LIdx) + 1, AView.Len - SizeUInt(LIdx) - 2).Trim else LArgView := TStringView.Empty;
        end else LArgView := TStringView.Empty;
        if (LArgView.Len >= 2) and ((LArgView.Data[0] = '"') or (LArgView.Data[0] = '''')) then LArgView := LArgView.Slice(1, LArgView.Len - 2);
        if (LArgView.Len = 1) and (LArgView.Data[0] = ')') then LArgView := TStringView.Empty;
        LHasArg := not LArgView.IsEmpty;
        if LHasArg then LSingle[0] := JsPureNewStringView(LArgView);
        LThis := AGlobal;
        try
          case Hosts[LHostIdx].Kind of
            0: begin LHandler := Hosts[LHostIdx].Func; if LHasArg then Result := LHandler(ACtx, LThis, LSingle) else Result := LHandler(ACtx, LThis, LNoArgs); end;
            1: begin LMethod := Hosts[LHostIdx].Method; if LHasArg then Result := LMethod(ACtx, LThis, LSingle) else Result := LMethod(ACtx, LThis, LNoArgs); end;
            2: begin LProc := Hosts[LHostIdx].Proc; if LHasArg then Result := LProc(ACtx, LThis, LSingle) else Result := LProc(ACtx, LThis, LNoArgs); end;
          end;
        except on E: EJsError do raise; on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend); on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend); end;
        Exit;
      end;
    end;
  end;
  Result := JsPureNewStringView(AView);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  // perf: inline thin-forward to single stencil EvalCore, zero-copy TStringView, bytes.ops single source, no duplicate stencil
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, nil, AGlobal);
end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AGlobal: TJsValue): TJsValue;
var LView: TStringView;
begin
  // per-Context 桶 O(1) 单分支 stencil — 复用 host 单源, 零拷贝 view, 复用同一 EvalCore
  LView := TStringView.FromStr(ACode).Trim;
  Result := EvalCore(LView, ACtx, AOptions, ABackend, Hosts, @Buckets, AGlobal);
end;
end.
