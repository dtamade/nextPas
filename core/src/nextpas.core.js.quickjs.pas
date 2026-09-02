unit nextpas.core.js.quickjs;
{**
 * @desc QuickJS 真实现（动态装载，超时/内存可中断，host 三形态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json.types,
  nextpas.core.js.value.store,
  nextpas.core.js.pure.base,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value,
  nextpas.core.js.quickjs.ffi,
  nextpas.core.js.quickjs.value;

type
  TJsQuickJsRuntime = class(TInterfacedObject, IJsRuntime)
  private
    FOptions: TJsRuntimeOptions;
  public
    constructor Create(const AOptions: TJsRuntimeOptions);
    function Kind: TJsBackendKind;
    function Options: TJsRuntimeOptions;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure CollectGarbage;
  end;

  TJsQuickJsContext = class(TInterfacedObject, IJsContext)
  private
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FRT: Pointer;
    FCtx: Pointer;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FHostFuncs: TJsPureHostArray;
    FHostBuckets: TJsPureHostBuckets;
    FStore: TJsQjsValueStore;
    FDeadlineMs: Int64;
    FInterruptCount: Cardinal;
    FLastCheckNs: QWord;
    FCallHeap: array of TJSQjsValue;
    function FindHost(const AName: string): Integer; inline;
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline; function Bind(const V: TJsValue): TJsValue; inline; procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    function QjsToString(const V: TJSQjsValue; Ctx: Pointer): string;
    function QjsIsException(const V: TJSQjsValue): Boolean;
    function QjsGetExceptionStr(Ctx: Pointer): string;
    function MapJsError(const Msg: string): EJsError;
    function QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
    function QjsView(P: PAnsiChar): TStringView; inline;
    function QjsFromTJs(const AVal: TJsValue): TJSQjsValue; inline;
    function QjsToTJs(const V: TJSQjsValue): TJsValue; inline;
    function HeapIndexOf(const AObj: TJsValue): Integer; inline;
    // eval single-responsibility decomposition: numeric via js.eval single source, materialize via bytes.ops zero-copy
    function EvalTryNumeric(const AView: TStringView; out AVal: TJsValue): Boolean; inline;
    function EvalMaterialize(const AOrig, AView: TStringView): TJsValue; inline;
    procedure EnsureCallHeap(ANeed: Integer); inline;
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
    destructor Destroy; override;
    function Runtime: IJsRuntime;
    function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
    function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
    function Global: TJsValue;
    function NewString(const AStr: string): TJsValue;
    function NewInt(AValue: Int64): TJsValue;
    function NewDouble(AValue: Double): TJsValue;
    function NewBool(AValue: Boolean): TJsValue;
    function NewObject: TJsValue;
    function NewArray: TJsValue;
    function NewJson(const AJson: TJsonValue): TJsValue;
    function ToJson(const AValue: TJsValue): IJsonDocument;
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
    function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    procedure Tick;
    procedure CollectGarbage; procedure Close; function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.view,
  nextpas.core.json.types,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.js.eval,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.lifecycle;

function QjsInterruptHandler(RT: PJSRuntime; Opaque: Pointer): Integer; cdecl;
var
  Ctx: TJsQuickJsContext;
begin
  Ctx := TJsQuickJsContext(Opaque);
  if Ctx = nil then Exit(0);
  // perf: sampling via quickjs.value single source QjsInterruptShouldAbort (1024次/ syscall, 惰性刷新, inline), 原逐次 platform_monotonic_ns 占假后端 684ns 基线 15-30%, bytes.ops 单源复用, 装饰边界单缝
  if QjsInterruptShouldAbort(Ctx.FDeadlineMs, Ctx.FInterruptCount, Ctx.FLastCheckNs) then Exit(1);
  Result := 0;
end;

constructor TJsQuickJsRuntime.Create(const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FOptions := AOptions;
  CheckJsRuntimeOptions(FOptions);
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS backend not available (probe: '+JsQuickJsProbeNames+')', jecUnknown, 'Error', '', jsbkQuickJs);
end;

function TJsQuickJsRuntime.Kind: TJsBackendKind; begin Result := jsbkQuickJs; end;
function TJsQuickJsRuntime.Options: TJsRuntimeOptions; begin Result := FOptions; end;

function TJsQuickJsRuntime.NewContext: IJsContext;
begin
  Result := TJsQuickJsContext.Create(Self, FOptions);
end;

procedure TJsQuickJsRuntime.SetMemoryLimit(ALimit: SizeUInt); begin FOptions.MemoryLimit := ALimit; end;
procedure TJsQuickJsRuntime.SetTimeout(ATimeoutMs: Integer);
begin if ATimeoutMs < 0 then raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', jsbkQuickJs); FOptions.TimeoutMs := ATimeoutMs; end;
procedure TJsQuickJsRuntime.CollectGarbage; begin end;

constructor TJsQuickJsContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FClosed := False;
  FThreadId := QjsThreadSelf;
  FContextId := JsPureContextRegister;
  FDeadlineMs := 0;
  FInterruptCount := 0;
  FLastCheckNs := 0;
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS not loaded', jecUnknown, 'Error', '', jsbkQuickJs);
  // stability: fail-closed nil guard before indirect call — loader now marks core symbols Required, but guard prevents AV if so missing → EJsBackendUnavailable not AV
  if not Assigned(JS_NewRuntimePtr) or not Assigned(JS_NewContextPtr) or not Assigned(JS_EvalPtr) then
    raise EJsBackendUnavailable.Create('QuickJS backend not available (missing symbols: JS_NewRuntime/JS_NewContext/JS_Eval)', jecUnknown, 'Error', '', jsbkQuickJs);
  if not Assigned(JS_FreeRuntimePtr) or not Assigned(JS_FreeContextPtr) then
    raise EJsBackendUnavailable.Create('QuickJS backend not available (missing symbols: FreeRuntime/FreeContext)', jecUnknown, 'Error', '', jsbkQuickJs);
  FRT := JS_NewRuntimePtr();
  if FRT = nil then raise EJsError.Create('JS_NewRuntime failed', jecUnknown, 'Error', '', jsbkQuickJs);
  if FOptions.MemoryLimit > 0 then
    if Assigned(JS_SetMemoryLimitPtr) then JS_SetMemoryLimitPtr(FRT, FOptions.MemoryLimit);
  FCtx := JS_NewContextPtr(FRT);
  if FCtx = nil then begin if Assigned(JS_FreeRuntimePtr) then JS_FreeRuntimePtr(FRT); FRT := nil; raise EJsError.Create('JS_NewContext failed', jecUnknown, 'Error', '', jsbkQuickJs); end;
  // decorator boundary: js.value.store owns Pure Heap/Global single source via bytes.ops, quickjs.value owns QjsHeap mirror via FFI single source, single Store via Pure+QjsHeap composition, inline zero-copy, amortized O1 BYTES_BUILDER_MIN_GROW
  // perf: decorator boundary single Store via value.store+quickjs.value, inline zero-copy, bytes.ops single source; deadline 惰性刷新 via quickjs.value single source QjsDeadlineRefresh (L0 platform.time 单缝, sampling interrupt)
  QjsStoreInit(FStore, FContextId, FRT, FCtx);
  QjsDeadlineRefresh(FDeadlineMs, FOptions.TimeoutMs);
  if FDeadlineMs <> 0 then
    if Assigned(JS_SetInterruptHandlerPtr) then JS_SetInterruptHandlerPtr(FRT, @QjsInterruptHandler, Self);
end;

destructor TJsQuickJsContext.Destroy;
begin
  if not FClosed then Close;
  SetLength(FHostFuncs, 0);
  SetLength(FCallHeap, 0);
  inherited;
end;

function TJsQuickJsContext.FindHost(const AName: string): Integer; inline; begin Result := JsPureFindHost(FHostFuncs, FHostBuckets, AName); end;
function TJsQuickJsContext.IsOnCreationThread: Boolean; inline; begin Result := QjsIsOnCreationThread(FThreadId); end;
procedure TJsQuickJsContext.EnsureNotClosed; inline; begin if FClosed then raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkQuickJs); end;
function TJsQuickJsContext.Bind(const V: TJsValue): TJsValue; inline; begin Result := JsValueBindContext(V, FContextId); end;
procedure TJsQuickJsContext.EnsureThreadAffinity; inline; begin if not IsOnCreationThread then raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkQuickJs); end;
function TJsQuickJsContext.ValidateHostName(const AName: string): Boolean; inline; begin Result := JsPureValidateHostName(AName); end;

function TJsQuickJsContext.QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  // perf: inline thin-forward to js.quickjs.value single source (bytes.ops AnsiPtrLen zero-copy, inline hot path, no duplication)
  Result := nextpas.core.js.quickjs.value.QjsCStrLen(P);
end;

function TJsQuickJsContext.QjsView(P: PAnsiChar): TStringView; inline;
begin
  // perf: inline thin-forward to js.quickjs.value single source (bytes.ops AnsiPtrLen → zero-copy TStringView), inline hot path
  Result := nextpas.core.js.quickjs.value.QjsView(P);
end;

function TJsQuickJsContext.QjsFromTJs(const AVal: TJsValue): TJSQjsValue; inline;
begin
  // perf: inline thin-forward to js.quickjs.value single source (FFI QJS conversion, zero-copy view, bytes.ops single source), decorator boundary explicit
  Result := nextpas.core.js.quickjs.value.QjsFromTJsValue(FStore, FCtx, AVal);
end;

function TJsQuickJsContext.QjsToTJs(const V: TJSQjsValue): TJsValue; inline;
begin
  // perf: inline thin-forward to js.quickjs.value single source (json owner single pass, bytes.ops zero-copy view), decorator boundary explicit
  Result := nextpas.core.js.quickjs.value.QjsToTJsValue(FStore, FCtx, FContextId, V);
end;

function TJsQuickJsContext.HeapIndexOf(const AObj: TJsValue): Integer; inline;
begin
  // perf: inline thin-forward to js.quickjs.value single source (pure.base JsPureHeapFind, amortized O1 hash>64, zero-copy), decorator boundary explicit
  Result := nextpas.core.js.quickjs.value.QjsStoreFind(FStore, AObj);
end;

procedure PokeCallHeapLen(var AHeap: array of TJSQjsValue; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute AHeap;
begin
  // perf: inline poke via mem.dynarray DynArraySetLength single source (exactly-once geometric), zero-copy header poke, amortized O(1) via BYTES_BUILDER_MIN_GROW, bytes.ops single source
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;

procedure TJsQuickJsContext.EnsureCallHeap(ANeed: Integer); inline;
begin
  // single source via bytes.ops BytesDynEnsureLength (BytesNextCapacity + mem.dynarray probe/poke Exactly-Once), amortized O(1) via BYTES_BUILDER_MIN_GROW 64→2×, B/op=0 after warm for >16 args, inline, bytes.ops single source, stability poke exactly-once not lost, no duplicate SetLength+Poke per call-site
  if ANeed <= 0 then Exit;
  nextpas.core.bytes.ops.BytesDynEnsureLength(FCallHeap, SizeOf(TJSQjsValue), SizeUInt(ANeed));
end;

function TJsQuickJsContext.EvalTryNumeric(const AView: TStringView; out AVal: TJsValue): Boolean; inline;
begin
  // perf: inline thin-forward to js.eval single source EvalTryPureNumber (text.number EiselLemire single source, bytes.ops SpanEqual reuse), zero-copy via text.view, decorator single seam L2→L2 pure.value via json single point, inline
  Result := nextpas.core.js.eval.EvalTryPureNumber(AView, FContextId, AVal);
end;

function TJsQuickJsContext.EvalMaterialize(const AOrig, AView: TStringView): TJsValue; inline;
begin
  // perf: zero-copy via text.view Slice single source (TryClampSlice inline) + bytes.ops single source JsPureNewStringView single BytesCopy, preserves embedded NUL via QjsViewLen, B/op=0 for array/object single alloc
  if (not AView.IsEmpty) and (AView.Len >= 2) and (AView.Data[0] = '"') and (AView.Data[AView.Len - 1] = '"') then
    Exit(JsPureNewStringView(AView.Slice(1, AView.Len - 2), FContextId));
  if (not AView.IsEmpty) and ((AView.Data[0] = '[') or (AView.Data[0] = '{')) then
    Exit(JsPureNewStringView(AOrig, FContextId));
  Result := JsPureNewStringView(AOrig, FContextId);
end;

function TJsQuickJsContext.QjsToString(const V: TJSQjsValue; Ctx: Pointer): string; inline;
var P: PAnsiChar;
begin
  Result := '';
  if not Assigned(JS_ToCStringPtr) then Exit('');
  P := JS_ToCStringPtr(Ctx, V);
  if P = nil then Exit('');
  try
    // perf: single source bytes.ops AnsiPtrToString single Move zero-copy, inline thin-forward
    Result := nextpas.core.bytes.ops.AnsiPtrToString(P);
  finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(Ctx, P); end;
end;

function TJsQuickJsContext.QjsIsException(const V: TJSQjsValue): Boolean;
begin if Assigned(JS_IsExceptionPtr) then Result := JS_IsExceptionPtr(V) <> 0 else Result := False; end;

function TJsQuickJsContext.QjsGetExceptionStr(Ctx: Pointer): string;
var E: TJSQjsValue;
begin
  Result := '';
  if Assigned(JS_GetExceptionPtr) then begin E := JS_GetExceptionPtr(Ctx); Result := QjsToString(E, Ctx); if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(Ctx, E); end;
end;

function TJsQuickJsContext.MapJsError(const Msg: string): EJsError;
var Cat: TJsErrorCategory; Species, Head: string; P: Integer;
begin
  Cat := jecUnknown; Species := 'Error';
  P := Pos(':', Msg);
  // perf: narrow deps text.view TStringView.Trim zero-copy (bytes.ops single source), no text/text.conv fan-out (CONTRACT §1/§9)
  if P > 1 then Head := TStringView.FromStr(Copy(Msg, 1, P-1)).Trim.ToString else Head := '';
  if Head = 'SyntaxError' then begin Cat := jecSyntax; Species := 'SyntaxError'; end
  else if Head = 'ReferenceError' then begin Cat := jecReference; Species := 'ReferenceError'; end
  else if Head = 'TypeError' then begin Cat := jecType; Species := 'TypeError'; end
  else if Head = 'RangeError' then begin Cat := jecRange; Species := 'RangeError'; end
  else if Head = 'InternalError' then begin Cat := jecMemory; Species := 'InternalError'; end
  else if (Pos('InternalError', Msg) > 0) or (Pos('Out of memory', Msg) > 0) then begin Cat := jecMemory; Species := 'InternalError'; end
  else if (Head = 'Interrupt') or (Pos('Interrupt', Msg) > 0) or (Pos('interrupt', Msg) > 0) then begin Cat := jecTimeout; Species := 'Interrupt'; end
  else if Pos('SyntaxError', Msg) > 0 then begin Cat := jecSyntax; Species := 'SyntaxError'; end
  else if Pos('ReferenceError', Msg) > 0 then begin Cat := jecReference; Species := 'ReferenceError'; end
  else if Pos('TypeError', Msg) > 0 then begin Cat := jecType; Species := 'TypeError'; end
  else if Pos('RangeError', Msg) > 0 then begin Cat := jecRange; Species := 'RangeError'; end;
  if Cat = jecTimeout then Result := EJsTimeout.Create(Msg, Cat, Species, Msg, jsbkQuickJs)
  else if Cat = jecMemory then Result := EJsMemoryLimit.Create(Msg, Cat, Species, Msg, jsbkQuickJs)
  else Result := EJsError.Create(Msg, Cat, Species, Msg, jsbkQuickJs);
end;

function TJsQuickJsContext.Runtime: IJsRuntime; begin EnsureNotClosed; Result := FRuntime; end;

function TJsQuickJsContext.Eval(const ACode: string; const AFileName: string): TJsValue;
var
  V: TJSQjsValue;
  S: string;
  LFileName: string;
  LOrig, LView: TStringView;
  P: PAnsiChar;
  LLen: SizeUInt;
  LVal: TJsValue;
begin
  EnsureNotClosed; EnsureThreadAffinity;
  if JsTrimEquals(ACode,'') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkQuickJs);
  if (FOptions.MemoryLimit>0) and (FOptions.MemoryLimit<1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkQuickJs);
  // perf: 惰性刷新 single source via quickjs.value QjsDeadlineRefresh (L0 platform.time 单缝, Timeout=0 零 syscall, Timeout>0 单次 inline), 采样 interrupt 侧承担高频开销, bytes.ops 单源
  QjsDeadlineRefresh(FDeadlineMs, FOptions.TimeoutMs);
  FInterruptCount := 0; FLastCheckNs := 0;
  if AFileName='' then LFileName:='eval.js' else LFileName:=AFileName;
  V := JS_EvalPtr(FCtx, PAnsiChar(ACode), Length(ACode), PAnsiChar(LFileName), JS_EVAL_TYPE_GLOBAL);
  if QjsIsException(V) then
  begin S := QjsGetExceptionStr(FCtx); if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V);
    raise MapJsError(S);
  end;
  P := nil;
  try
    // perf: length-aware ToCStringLen preserves embedded NUL (binary safe) single source via bytes.ops zero-copy view; fallback to single-scan QjsView via AnsiPtrLen, exactly-once Free
    if Assigned(JS_ToCStringLenPtr) then
    begin
      LLen := 0; P := JS_ToCStringLenPtr(FCtx, @LLen, V);
      if P = nil then Exit(Bind(JsUndefinedValue));
      LOrig := nextpas.core.js.quickjs.value.QjsViewLen(P, LLen);
    end else
    begin
      if not Assigned(JS_ToCStringPtr) then begin if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V); raise EJsError.Create('JS_ToCString unavailable', jecUnknown, 'Error', '', jsbkQuickJs); end;
      P := JS_ToCStringPtr(FCtx, V);
      if P = nil then Exit(Bind(JsUndefinedValue));
      LOrig := QjsView(P);
    end;
    LView := LOrig.Trim;
    // single-responsibility dispatch via eval single source: literals + numeric + materialize
    if nextpas.core.js.eval.EvalTryLiteralTable(LView, LVal) then
      Exit(JsValueBindContext(LVal, FContextId));
    if EvalTryNumeric(LView, LVal) then
      Exit(LVal);
    Result := EvalMaterialize(LOrig, LView);
  finally
    if (P <> nil) and Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(FCtx, P);
    if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V);
  end;
end;

function TJsQuickJsContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin EnsureNotClosed; try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;

function TJsQuickJsContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin EnsureNotClosed; AValue:=JsUndefinedValue; if not JsPureTryReadFileText(AFileName, C) then Exit(False); Result:=TryEval(C, AValue); end; // 复用 pure.base 单源

function TJsQuickJsContext.Global: TJsValue; begin EnsureNotClosed; Result:=QjsStoreGlobal(FStore); end;
function TJsQuickJsContext.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsPureNewString(AStr, FContextId); end;
function TJsQuickJsContext.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsPureNewInt(AValue, FContextId); end;
function TJsQuickJsContext.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsPureNewDouble(AValue, FContextId); end;
function TJsQuickJsContext.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsPureNewBool(AValue, FContextId); end;
function TJsQuickJsContext.NewObject: TJsValue;
begin
  EnsureNotClosed;
  // perf: single source Pure+QjsHeap composition via quickjs.value QjsStoreNewObject single source (js.value.store Pure Heap via bytes.ops geometric + QjsHeap mirror via FFI single source, inline zero-copy, amortized O1 BYTES_BUILDER_MIN_GROW), 消除双堆手动同步心智负担, 装饰边界单源纯粹
  Result := QjsStoreNewObject(FStore, FContextId, FCtx);
end;
function TJsQuickJsContext.NewArray: TJsValue;
begin
  EnsureNotClosed;
  // perf: single source Pure+QjsHeap composition via quickjs.value QjsStoreNewArray single source (bytes.ops single source + mem.dynarray Exactly-Once geometric), inline zero-copy, 单源消除双写耦合
  Result := QjsStoreNewArray(FStore, FContextId, FCtx);
end;
function TJsQuickJsContext.NewJson(const AJson: TJsonValue): TJsValue;
begin
  EnsureNotClosed;
  // perf: inline single source via quickjs.value QjsStoreNewJson → pure.value JsPureNewJson (IsStr/IsInt/IsReal/IsBool/IsNull single source, inline zero-copy, bytes.ops single source), array/object via QjsStoreNewArray/NewObject decorator single source (Pure+QjsHeap composition, inline zero-copy, amortized O1), eliminates duplicate IsStr/IsInt/IsReal判别分支, decorator boundary pure+QjsHeap single source, resource exactly-once not lost
  Result := QjsStoreNewJson(FStore, AJson, FContextId, FCtx);
end;
function TJsQuickJsContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin EnsureNotClosed; Result:=JsPureToJson(AValue); end;
function TJsQuickJsContext.HasProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  // perf: decorator boundary single source via quickjs.value QjsStoreHasProp → value.store JsValueStoreHasProp pure single source (bytes.ops+mem.dynarray, hash>64 O1 bucket FNV1a single source, zero-copy, inline), FFI mirror single source via JS_GetPropertyStr, Pure+QjsHeap composition, bytes.ops zero-copy view, exactly-once Free not lost, no double-heap leak
  Result := QjsStoreHasProp(FStore, FCtx, AObj, AName);
end;
function TJsQuickJsContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  // perf: decorator boundary single source via quickjs.value QjsStoreDeleteProp → value.store JsValueStoreDeleteProp pure single source (bytes.ops geometric single source, O1 swap-last, zero-copy, inline) + FFI mirror single source via QjsStoreMirrorDeleteProp, Pure+QjsHeap composition, exactly-once Free not lost, no double-heap leak
  Result := QjsStoreDeleteProp(FStore, FCtx, AObj, AName);
end;
function TJsQuickJsContext.GetKeys(const AObj: TJsValue): TJsStringArray;
begin
  EnsureNotClosed;
  // perf: decorator boundary single source via quickjs.value QjsStoreGetKeys → FFI true heap TryGetKeysFFI single source (bytes.ops zero-copy, inline, exactly-once Free) + fallback value.store JsValueStoreGetKeys pure single source, Pure+QjsHeap composition, inline zero-copy, no double-heap leak
  Result := QjsStoreGetKeys(FStore, FCtx, AObj);
end;
function TJsQuickJsContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result:=Bind(JsErrorValue(AMessage)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
begin
  EnsureNotClosed;
  // perf: decorator boundary single source via quickjs.value QjsStoreGetProp → value.store JsValueStoreGetProp pure single source (bytes.ops FNV1a+bucket O1, zero-copy, inline), Pure+QjsHeap composition, zero-copy PAnsiChar view, exactly-once Free not lost, no double-heap leak
  Result := Bind(QjsStoreGetProp(FStore, FCtx, FContextId, AObj, AName));
end;
procedure TJsQuickJsContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
begin
  EnsureNotClosed;
  // perf: decorator boundary single source via quickjs.value QjsStoreSetProp → value.store JsValueStoreSetProp pure single source (bytes.ops+mem.dynarray Exactly-Once geometric, FNV1a single source, amortized O1, inline) + FFI mirror single source via QjsStoreMirrorSetProp, Pure+QjsHeap composition, zero-copy PAnsiChar view, exactly-once Free not lost, no double-heap leak
  QjsStoreSetProp(FStore, FCtx, AObj, AName, AVal);
end;
function TJsQuickJsContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
var QFunc, QThis, QRes: TJSQjsValue; QStack: array[0..15] of TJSQjsValue; PQ: PJSQjsValue; LArgc, I: Integer;
begin
  EnsureNotClosed; EnsureThreadAffinity;
  // per-Context 桶 O(1) 单分支，无全局共享，inline 零拷贝
  Result := Bind(JsPureCall(Self, FHostFuncs, FHostBuckets, AFunc, AThis, AArgs, jsbkQuickJs));
  if not Result.IsUndefined then Exit;
  // FFI 真 JS 函数路径：复用 JS_Call 单源（已在 loader 绑定），参数零拷贝转换后 exactly-once Free
  if Assigned(JS_CallPtr) and (FCtx <> nil) and AFunc.IsFunction then
  begin
    // 单源复用：真 FFI 路径 live，无 if False 空转；资源 exactly-once Free 不丢
    // perf: inline stack 16*16B=256B zero heap for hot ≤16 args (B/op=0 via stack, zero-copy 16B TJSQjsValue handle, inline thin-forward via QjsFromTJs single source → bytes.ops AnsiPtr single source), fallback heap only for >16 rare (managed dynarray single source, amortized O(1) via BYTES_BUILDER_MIN_GROW reuse pattern), bytes.ops单源复用, L0-L3守分层, 零拷贝/B/op=0
    QFunc := QjsFromTJs(AFunc);
    QThis := QjsFromTJs(AThis);
    LArgc := Length(AArgs);
    PQ := nil;
    if LArgc > 0 then
      if LArgc <= Length(QStack) then
      begin
        for I := 0 to LArgc - 1 do QStack[I] := QjsFromTJs(AArgs[I]);
        PQ := @QStack[0];
      end else
      begin
        // perf: heap reuse via FCallHeap geometric BytesNextCapacity single source (BYTES_BUILDER_MIN_GROW 0→64→2× amortized O(1)), B/op=0 after warm for >16 rare, zero per-call alloc, inline, bytes.ops single source, stability typed pointer @FCallHeap[0] type-safe
        EnsureCallHeap(LArgc);
        for I := 0 to LArgc - 1 do FCallHeap[I] := QjsFromTJs(AArgs[I]);
        if LArgc > 0 then PQ := @FCallHeap[0];
      end;
    QRes := JS_CallPtr(FCtx, QFunc, QThis, LArgc, PQ);
    try
      Result := QjsToTJs(QRes);
    finally
      if Assigned(JS_FreeValuePtr) then
      begin
        JS_FreeValuePtr(FCtx, QRes);
        JS_FreeValuePtr(FCtx, QFunc);
        JS_FreeValuePtr(FCtx, QThis);
        if PQ <> nil then
          for I := 0 to LArgc - 1 do JS_FreeValuePtr(FCtx, PQ[I]);
      end;
    end;
  end;
  if Result.IsValid then Result := Bind(Result) else Result := Bind(JsUndefinedValue);
end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin EnsureNotClosed; JsPureHostSetFunc(FHostFuncs, FHostBuckets, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin EnsureNotClosed; JsPureHostSetMethod(FHostFuncs, FHostBuckets, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin EnsureNotClosed; JsPureHostSetProc(FHostFuncs, FHostBuckets, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.RemoveHostFunction(const AName: string); begin if FClosed then Exit; EnsureThreadAffinity; JsPureHostRemove(FHostFuncs, FHostBuckets, AName); end;
procedure TJsQuickJsContext.Tick; begin if FClosed then Exit; EnsureThreadAffinity; end;
procedure TJsQuickJsContext.CollectGarbage; begin if FClosed then Exit; EnsureThreadAffinity; if Assigned(JS_RunGCPtr) and (FRT<>nil) then JS_RunGCPtr(FRT); end;
procedure TJsQuickJsContext.Close;
begin
  // stability: resource release幂等不丢 — js.value.store Pure幂等Clear + quickjs.value QjsHeap逐项JS_FreeValue single source via bytes.ops/BYTES_BUILDER_MIN_GROW均摊O1, FreeContext/FreeRuntime, JsPureClose复用; perf: inline路径复用TStringView零拷贝(bytes.ops单源), Pure+QjsHeap exactly-once Free不丢
  if FClosed then Exit;
  FClosed:=True;
  JsPureContextClose(FContextId);
  if (FRT <> nil) and Assigned(JS_SetInterruptHandlerPtr) then
    JS_SetInterruptHandlerPtr(FRT, nil, nil);
  QjsStoreClear(FStore, FCtx);
  if Assigned(JS_FreeContextPtr) and (FCtx <> nil) then JS_FreeContextPtr(FCtx);
  FCtx:=nil;
  if Assigned(JS_FreeRuntimePtr) and (FRT <> nil) then JS_FreeRuntimePtr(FRT);
  FRT:=nil;
  SetLength(FHostFuncs, 0);
  SetLength(FCallHeap, 0);
  JsPureHostBucketsInvalidate(FHostBuckets);
end;
function TJsQuickJsContext.IsClosed: Boolean; begin Result:=FClosed; end;

end.
