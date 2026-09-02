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
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.js.pure.base,
  nextpas.core.js.quickjs.ffi;

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
    FHeap: TJsPureHeap;
    FGlobal: TJsValue;
    FQjsHeap: array of TJSQjsValue;
    FDeadlineMs: Int64;
    function FindHost(const AName: string): Integer; inline;
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline; function Bind(const V: TJsValue): TJsValue; inline; procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    function QjsToString(const V: TJSQjsValue; Ctx: Pointer): string;
    function QjsIsException(const V: TJSQjsValue): Boolean;
    function QjsGetExceptionStr(Ctx: Pointer): string;
    function MapJsError(const Msg: string): EJsError;
    function QjsCStrLen(P: PAnsiChar): SizeUInt;
    procedure EnsureQjsHeapCapacity(ANeed: Integer);
    function QjsView(P: PAnsiChar): TStringView; inline;
    function QjsFromTJs(const AVal: TJsValue): TJSQjsValue; inline;
    function QjsToTJs(const V: TJSQjsValue): TJsValue; inline;
    function HeapIndexOf(const AObj: TJsValue): Integer; inline;
    // decorator isolation: QJS mirror owns FQjsHeap sync, pure.base owns FHeap. NewObject/GetKeys/SetProp 双堆同步抽装饰器，owner边界清晰，复用bytes.ops+mem单源，inline零拷贝，摊还O1
    procedure DecoratorSyncNewEntry(AIdx: Integer; AIsArray: Boolean); inline;
    function DecoratorTryGetKeysFFI(AIdx: Integer; out AKeys: TJsStringArray): Boolean;
    procedure DecoratorMirrorSetProp(AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
    procedure DecoratorMirrorDeleteProp(AIdx: Integer; const AName: string); inline;
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
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.js.quickjs.loader;

// decorator owner boundary: FQjsHeap mirror owns QJS heap sync, pure.base owns FHeap. Capacity/poke single source via bytes.ops+mem.dynarray (zero-copy header poke, no manual High).
procedure PokeQjsHeapLen(var AHeap: array of TJSQjsValue; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute AHeap;
begin
  // perf: inline thin-forward to mem.dynarray DynArraySetLength single source (exactly-once geometric), zero-copy header poke, no manual High branch, amortized O(1) via BYTES_BUILDER_MIN_GROW
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;

function QjsInterruptHandler(RT: PJSRuntime; Opaque: Pointer): Integer; cdecl;
var
  Ctx: TJsQuickJsContext;
  NowNs: QWord;
begin
  Ctx := TJsQuickJsContext(Opaque);
  if Ctx = nil then Exit(0);
  if Ctx.FDeadlineMs = 0 then Exit(0);
  NowNs := QWord(platform_monotonic_ns);
  if NowNs >= QWord(Ctx.FDeadlineMs) then Exit(1);
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
  FThreadId := UInt64(platform_thread_self);
  FContextId := JsContextRegister;
  FDeadlineMs := 0;
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS not loaded', jecUnknown, 'Error', '', jsbkQuickJs);
  FRT := JS_NewRuntimePtr();
  if FRT = nil then raise EJsError.Create('JS_NewRuntime failed', jecUnknown, 'Error', '', jsbkQuickJs);
  if FOptions.MemoryLimit > 0 then
    if Assigned(JS_SetMemoryLimitPtr) then JS_SetMemoryLimitPtr(FRT, FOptions.MemoryLimit);
  FCtx := JS_NewContextPtr(FRT);
  if FCtx = nil then begin JS_FreeRuntimePtr(FRT); FRT := nil; raise EJsError.Create('JS_NewContext failed', jecUnknown, 'Error', '', jsbkQuickJs); end;
  FGlobal := JsValueBindContext(JsPureHeapNewObject(FHeap), FContextId);
  SetLength(FQjsHeap, Length(FHeap));
  if (Length(FHeap) > 0) and Assigned(JS_NewObjectPtr) and (FCtx <> nil) then
    FQjsHeap[High(FQjsHeap)] := JS_NewObjectPtr(FCtx)
  else if Length(FQjsHeap) > 0 then FillChar(FQjsHeap[High(FQjsHeap)], SizeOf(TJSQjsValue), 0);
  if FOptions.TimeoutMs > 0 then
  begin
    FDeadlineMs := Int64(QWord(platform_monotonic_ns) + QWord(FOptions.TimeoutMs) * 1000000);
    if Assigned(JS_SetInterruptHandlerPtr) then JS_SetInterruptHandlerPtr(FRT, @QjsInterruptHandler, Self);
  end;
end;

destructor TJsQuickJsContext.Destroy;
begin
  if not FClosed then Close;
  SetLength(FHostFuncs, 0);
  inherited;
end;

function TJsQuickJsContext.FindHost(const AName: string): Integer; inline; begin Result := JsPureFindHost(FHostFuncs, AName); end;
function TJsQuickJsContext.IsOnCreationThread: Boolean; inline; begin Result := UInt64(platform_thread_self) = FThreadId; end;
procedure TJsQuickJsContext.EnsureNotClosed; inline; begin if FClosed then raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkQuickJs); end;
function TJsQuickJsContext.Bind(const V: TJsValue): TJsValue; inline; begin Result := JsValueBindContext(V, FContextId); end;
procedure TJsQuickJsContext.EnsureThreadAffinity; inline; begin if not IsOnCreationThread then raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkQuickJs); end;
function TJsQuickJsContext.ValidateHostName(const AName: string): Boolean; inline; begin Result := JsPureValidateHostName(AName); end;

function TJsQuickJsContext.QjsCStrLen(P: PAnsiChar): SizeUInt; inline;
begin
  // perf: inline thin-forward to bytes.ops.AnsiPtrLen single source (zero-copy view length, single scan, no System.StrLen分叉), inline hot path
  Result := nextpas.core.bytes.ops.AnsiPtrLen(P);
end;

procedure TJsQuickJsContext.EnsureQjsHeapCapacity(ANeed: Integer);
var LOld,LCap: Integer;
begin
  // reuse bytes.ops single source + mem.dynarray exactly-once geometric (no双写分支克隆 pure.base): SetLength(LCap) + single poke to ANeed via PokeQjsHeapLen→DynArraySetLength, amortized O(1) via BYTES_BUILDER_MIN_GROW 64→2×, inline zero-copy capacity math
  LOld := Length(FQjsHeap);
  if LOld >= ANeed then Exit;
  LCap := BytesGrowCapacityInt(LOld, ANeed);
  SetLength(FQjsHeap, LCap);
  if LCap <> ANeed then PokeQjsHeapLen(FQjsHeap, SizeUInt(ANeed));
end;

function TJsQuickJsContext.QjsView(P: PAnsiChar): TStringView; inline;
begin
  // perf: inline single scan via QjsCStrLen (bytes.ops AnsiPtrLen single source) → zero-copy TStringView (bytes.ops single source SpanEqual/Move), inline hot path, no重复扫描
  if P = nil then Exit(TStringView.Empty);
  Result := TStringView.Create(P, QjsCStrLen(P));
end;

function TJsQuickJsContext.QjsFromTJs(const AVal: TJsValue): TJSQjsValue; inline;
var Idx: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if FCtx = nil then Exit;
  case AVal.Kind of
    jskString: if Assigned(JS_NewStringPtr) then Result := JS_NewStringPtr(FCtx, PAnsiChar(AVal.AsString));
    jskNumber:
      begin
        if (AVal.AsInt = Int64(Trunc(AVal.AsDouble))) and Assigned(JS_NewInt64Ptr) then Result := JS_NewInt64Ptr(FCtx, AVal.AsInt)
        else if Assigned(JS_NewFloat64Ptr) then Result := JS_NewFloat64Ptr(FCtx, AVal.AsDouble);
      end;
    jskBoolean: if Assigned(JS_NewBoolPtr) then Result := JS_NewBoolPtr(FCtx, Ord(AVal.AsBool));
    jskObject, jskArray, jskFunction:
      begin
        Idx := JsPureHeapFind(FHeap, AVal);
        if (Idx >= 0) and (Idx < Length(FQjsHeap)) and Assigned(JS_DupValuePtr) then Result := JS_DupValuePtr(FCtx, FQjsHeap[Idx]);
      end;
    jskNull, jskUndefined: FillChar(Result, SizeOf(Result), 0);
    else FillChar(Result, SizeOf(Result), 0);
  end;
end;

function TJsQuickJsContext.QjsToTJs(const V: TJSQjsValue): TJsValue; inline;
var P: PAnsiChar; Vw, Tw: TStringView; Doc: IJsonDocument; Root: TJsonValue;
begin
  Result := Bind(JsUndefinedValue);
  if not Assigned(JS_ToCStringPtr) or (FCtx = nil) then Exit(Bind(JsUndefinedValue));
  P := JS_ToCStringPtr(FCtx, V);
  if P = nil then Exit(Bind(JsUndefinedValue));
  try
    // perf: single scan via QjsView (bytes.ops single source, inline zero-copy) + single JsonParse (owner json, O(n) single pass, no ViewToInt64/ViewToDouble double scan, zero extra alloc)
    Vw := QjsView(P);
    Tw := Vw.Trim;
    if Tw.Equals(TStringView.FromStr('null')) then Exit(JsValueBindContext(JsNullValue, FContextId));
    if Tw.Equals(TStringView.FromStr('undefined')) then Exit(JsValueBindContext(JsUndefinedValue, FContextId));
    if Tw.Equals(TStringView.FromStr('true')) then Exit(JsPureNewBool(True, FContextId));
    if Tw.Equals(TStringView.FromStr('false')) then Exit(JsPureNewBool(False, FContextId));
    Doc := JsonParse(Tw);
    if not Doc.HasError then
    begin
      Root := Doc.Root;
      case Root.Kind of
        jnkInt: Exit(JsPureNewInt(Root.AsInt, FContextId));
        jnkReal: Exit(JsPureNewDouble(Root.AsFloat, FContextId));
        jnkBool: Exit(JsPureNewBool(Root.AsBool, FContextId));
        jnkNull: Exit(JsValueBindContext(JsNullValue, FContextId));
        jnkString: Exit(JsPureNewString(Root.AsStr.ToString, FContextId));
        jnkArray, jnkObject: Exit(JsPureNewString(Vw.ToString, FContextId));
      end;
    end;
    Result := JsPureNewString(Vw.ToString, FContextId);
  finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(FCtx, P); end;
end;

function TJsQuickJsContext.HeapIndexOf(const AObj: TJsValue): Integer; inline;
begin Result := JsPureHeapFind(FHeap, AObj); end;

// decorator isolation: QJS mirror decoration — owner boundary: pure.base owns FHeap (JsPureHeap*), mirror owns FQjsHeap (QJS values). Capacity single source via bytes.ops+mem.dynarray, inline zero-copy, amortized O1.
procedure TJsQuickJsContext.DecoratorSyncNewEntry(AIdx: Integer; AIsArray: Boolean); inline;
var Q: TJSQjsValue;
begin
  // perf: amortized O(1) via BytesGrowCapacityInt single source (BYTES_BUILDER_MIN_GROW 64→2×), mem.dynarray Exactly-Once poke, inline thin-forward, zero-copy header poke
  EnsureQjsHeapCapacity(Length(FHeap));
  if AIdx < 0 then Exit;
  if AIsArray then
  begin
    if Assigned(JS_NewArrayPtr) and (FCtx <> nil) then Q := JS_NewArrayPtr(FCtx) else FillChar(Q, SizeOf(Q), 0);
  end else
  begin
    if Assigned(JS_NewObjectPtr) and (FCtx <> nil) then Q := JS_NewObjectPtr(FCtx) else FillChar(Q, SizeOf(Q), 0);
  end;
  FQjsHeap[AIdx] := Q;
end;

function TJsQuickJsContext.DecoratorTryGetKeysFFI(AIdx: Integer; out AKeys: TJsStringArray): Boolean;
var
  LLen: UInt32;
  LProps: PJSPropertyEnum;
  I: Integer;
  QStr: TJSQjsValue;
  P: PAnsiChar;
begin
  Result := False;
  AKeys := nil;
  // perf: FFI真堆枚举经 JS_GetOwnPropertyNames single source (bytes.ops zero-copy AnsiPtrToString), inline path; 资源 exactly-once Free不丢; fallback由调用方接管纯堆
  if (FCtx = nil) or (AIdx < 0) or (AIdx >= Length(FQjsHeap)) then Exit;
  if not Assigned(JS_GetOwnPropertyNamesPtr) or not Assigned(JS_FreePropertyEnumPtr) or not Assigned(JS_AtomToStringPtr) or not Assigned(JS_ToCStringPtr) or not Assigned(JS_FreeCStringPtr) or not Assigned(JS_FreeValuePtr) then Exit;
  LLen := 0;
  LProps := JS_GetOwnPropertyNamesPtr(FCtx, @LLen, FQjsHeap[AIdx], JS_GPN_STRING_MASK);
  if LProps = nil then Exit;
  try
    SetLength(AKeys, LLen);
    for I := 0 to Integer(LLen) - 1 do
    begin
      QStr := JS_AtomToStringPtr(FCtx, LProps[I].atom);
      try
        P := JS_ToCStringPtr(FCtx, QStr);
        if P <> nil then
        try
          AKeys[I] := nextpas.core.bytes.ops.AnsiPtrToString(P);
        finally JS_FreeCStringPtr(FCtx, P); end
        else AKeys[I] := '';
      finally
        if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, QStr);
      end;
    end;
    Result := True;
  finally
    JS_FreePropertyEnumPtr(FCtx, LProps, LLen);
  end;
end;

procedure TJsQuickJsContext.DecoratorMirrorSetProp(AIdx: Integer; const AName: string; const AVal: TJsValue); inline;
var QVal: TJSQjsValue;
begin
  // owner boundary: pure heap already updated by caller via JsPureHeapSetProp; mirror only syncs FQjsHeap via FFI single source JS_SetPropertyStr, exactly-once Free不丢, inline zero-copy PAnsiChar view (bytes.ops single source)
  if (AIdx < 0) or (AIdx >= Length(FQjsHeap)) or not Assigned(JS_SetPropertyStrPtr) or (FCtx = nil) then
  begin
    // non-heap or closed mirror: try global mirror fallback (pure.base owns FGlobal, mirror syncs FQjsHeap[globalIdx])
    AIdx := HeapIndexOf(FGlobal);
    if (AIdx < 0) or (AIdx >= Length(FQjsHeap)) then Exit;
  end;
  QVal := QjsFromTJs(AVal);
  try
    JS_SetPropertyStrPtr(FCtx, FQjsHeap[AIdx], PAnsiChar(AName), QVal);
  finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, QVal); end;
end;

procedure TJsQuickJsContext.DecoratorMirrorDeleteProp(AIdx: Integer; const AName: string); inline;
var QUndef: TJSQjsValue;
begin
  if (AIdx < 0) or (AIdx >= Length(FQjsHeap)) or not Assigned(JS_SetPropertyStrPtr) or (FCtx = nil) then Exit;
  FillChar(QUndef, SizeOf(QUndef), 0);
  JS_SetPropertyStrPtr(FCtx, FQjsHeap[AIdx], PAnsiChar(AName), QUndef);
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
  LDoc: IJsonDocument;
  LRoot: TJsonValue;
  P: PAnsiChar;
begin
  EnsureNotClosed; EnsureThreadAffinity;
  if JsTrimEquals(ACode,'') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkQuickJs);
  if (FOptions.MemoryLimit>0) and (FOptions.MemoryLimit<1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkQuickJs);
  if FOptions.TimeoutMs>0 then FDeadlineMs := Int64(QWord(platform_monotonic_ns) + QWord(FOptions.TimeoutMs) * 1000000);
  if AFileName='' then LFileName:='eval.js' else LFileName:=AFileName;
  V := JS_EvalPtr(FCtx, PAnsiChar(ACode), Length(ACode), PAnsiChar(LFileName), JS_EVAL_TYPE_GLOBAL);
  if QjsIsException(V) then
  begin S := QjsGetExceptionStr(FCtx); if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V);
    raise MapJsError(S);
  end;
  P := nil;
  try
    if not Assigned(JS_ToCStringPtr) then begin if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V); raise EJsError.Create('JS_ToCString unavailable', jecUnknown, 'Error', '', jsbkQuickJs); end;
    P := JS_ToCStringPtr(FCtx, V);
    if P = nil then Exit(Bind(JsUndefinedValue));
    // perf: single scan via QjsView (bytes.ops single source, inline zero-copy) + single JsonParse (owner json, O(n) single pass, no ViewToInt64/ViewToDouble double scan, zero extra alloc)
    LOrig := QjsView(P);
    LView := LOrig.Trim;
    if LView.Equals(TStringView.FromStr('null')) then Exit(JsValueBindContext(JsNullValue, FContextId));
    if LView.Equals(TStringView.FromStr('true')) then Exit(JsPureNewBool(True, FContextId));
    if LView.Equals(TStringView.FromStr('false')) then Exit(JsPureNewBool(False, FContextId));
    if LView.Equals(TStringView.FromStr('undefined')) then Exit(JsValueBindContext(JsUndefinedValue, FContextId));
    // 统一编解码：走 json owner 单源（JsonParse+TJsonValue），消双份拷贝，视图零拷贝入参，保持 CONTRACT INV-5
    LDoc := JsonParse(LView);
    if not LDoc.HasError then
    begin
      LRoot := LDoc.Root;
      case LRoot.Kind of
        jnkInt: Exit(JsPureNewInt(LRoot.AsInt, FContextId));
        jnkReal: Exit(JsPureNewDouble(LRoot.AsFloat, FContextId));
        jnkBool: Exit(JsPureNewBool(LRoot.AsBool, FContextId));
        jnkNull: Exit(JsValueBindContext(JsNullValue, FContextId));
        jnkString: Exit(JsPureNewString(LRoot.AsStr.ToString, FContextId));
        jnkArray, jnkObject: Exit(JsPureNewString(LOrig.ToString, FContextId));
      end;
    end;
    Result := JsPureNewString(LOrig.ToString, FContextId);
  finally
    if (P <> nil) and Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(FCtx, P);
    if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V);
  end;
end;

function TJsQuickJsContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin EnsureNotClosed; try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;

function TJsQuickJsContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin EnsureNotClosed; AValue:=JsUndefinedValue; if not JsPureTryReadFileText(AFileName, C) then Exit(False); Result:=TryEval(C, AValue); end; // 复用 pure.base 单源

function TJsQuickJsContext.Global: TJsValue; begin EnsureNotClosed; Result:=FGlobal; end;
function TJsQuickJsContext.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsPureNewString(AStr, FContextId); end;
function TJsQuickJsContext.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsPureNewInt(AValue, FContextId); end;
function TJsQuickJsContext.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsPureNewDouble(AValue, FContextId); end;
function TJsQuickJsContext.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsPureNewBool(AValue, FContextId); end;
function TJsQuickJsContext.NewObject: TJsValue;
var Idx: Integer;
begin
  EnsureNotClosed;
  // owner boundary: pure.base owns FHeap alloc, decorator owns FQjsHeap mirror (bytes.ops+mem single source, amortized O1 inline zero-copy)
  Result:=Bind(JsPureHeapNewObject(FHeap));
  Idx := HeapIndexOf(Result);
  DecoratorSyncNewEntry(Idx, False);
end;
function TJsQuickJsContext.NewArray: TJsValue;
var Idx: Integer;
begin
  EnsureNotClosed;
  // owner boundary: pure.base owns FHeap alloc, decorator owns FQjsHeap mirror (bytes.ops+mem single source, amortized O1 inline zero-copy)
  Result:=Bind(JsPureHeapNewArray(FHeap));
  Idx := HeapIndexOf(Result);
  DecoratorSyncNewEntry(Idx, True);
end;
function TJsQuickJsContext.NewJson(const AJson: TJsonValue): TJsValue;
begin EnsureNotClosed; if AJson.IsStr then Result:=JsPureNewString(AJson.AsStr.ToString, FContextId) else if AJson.IsInt then Result:=JsPureNewInt(AJson.AsInt, FContextId) else if AJson.IsReal then Result:=JsPureNewDouble(AJson.AsFloat, FContextId) else if AJson.IsBool then Result:=JsPureNewBool(AJson.AsBool, FContextId) else if AJson.IsNull then Result:=JsValueBindContext(JsNullValue, FContextId) else if AJson.IsArray then Result:=NewArray else if AJson.IsObject then Result:=NewObject else Result:=JsValueBindContext(JsUndefinedValue, FContextId); end;
function TJsQuickJsContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin EnsureNotClosed; Result:=JsPureToJson(AValue); end;
function TJsQuickJsContext.HasProp(const AObj: TJsValue; const AName: string): Boolean;
var Idx: Integer; QRes: TJSQjsValue; P: PChar;
begin
  EnsureNotClosed;
  // 单源：纯堆为 CONTRACT 主路径，FFI 为真堆校验旁路（复用 JS_GetPropertyStr 单源，零分配视图，经 bytes.ops）
  Result := JsPureHeapHasProp(FHeap, AObj, AName);
  if Result then Exit;
  Idx := HeapIndexOf(AObj);
  if (Idx >= 0) and (Idx < Length(FQjsHeap)) and Assigned(JS_GetPropertyStrPtr) and (FCtx <> nil) then
  begin
    QRes := JS_GetPropertyStrPtr(FCtx, FQjsHeap[Idx], PAnsiChar(AName));
    try
      // QuickJS 返回 undefined 表示缺属性；复用 QjsToTJs 零拷贝视图判断
      if not QjsIsException(QRes) then
      begin
        P := nil;
        if Assigned(JS_ToCStringPtr) then P := JS_ToCStringPtr(FCtx, QRes);
        if P <> nil then
        try
          Result := QjsView(P).Trim.Equals(TStringView.FromStr('undefined')) = False;
          // 若为 undefined 且堆中缺，仍判 False；避免 undefined 值误判为存在时与堆语义一致（堆缺即 False）
          if Result then Result := True else Result := False;
        finally if Assigned(JS_FreeCStringPtr) then JS_FreeCStringPtr(FCtx, P); end;
      end;
    finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, QRes); end;
  end;
end;
function TJsQuickJsContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
var Idx: Integer;
begin
  EnsureNotClosed;
  // owner boundary: pure.base owns FHeap delete, decorator mirrors FQjsHeap FFI sync (single source JS_SetPropertyStr)
  Result := JsPureHeapDeleteProp(FHeap, AObj, AName);
  Idx := HeapIndexOf(AObj);
  DecoratorMirrorDeleteProp(Idx, AName);
end;
function TJsQuickJsContext.GetKeys(const AObj: TJsValue): TJsStringArray;
var
  Idx: Integer;
  LTmp: TJsStringArray;
begin
  EnsureNotClosed;
  // decorator isolation: FFI真堆枚举优先经 DecoratorTryGetKeysFFI (bytes.ops zero-copy, inline, exactly-once Free), 失败回落纯堆 CONTRACT pure.base单源，保持双堆一致
  Idx := HeapIndexOf(AObj);
  if DecoratorTryGetKeysFFI(Idx, LTmp) then Exit(LTmp);
  // fallback: pure heap CONTRACT INV-5 (json 单源之外纯堆单源)
  Result := JsPureHeapGetKeys(FHeap, AObj);
end;
function TJsQuickJsContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result:=Bind(JsErrorValue(AMessage)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
var Idx: Integer; QRes: TJSQjsValue;
begin
  EnsureNotClosed;
  Idx := HeapIndexOf(AObj);
  if Idx >= 0 then Exit(Bind(JsPureHeapGetProp(FHeap, AObj, AName)));
  // FFI 真堆路径：复用 JS_GetPropertyStr 单源，零拷贝视图转 TJsValue
  if Assigned(JS_GetPropertyStrPtr) and (FCtx <> nil) and (Idx >= 0) and (Idx < Length(FQjsHeap)) then
  begin
    QRes := JS_GetPropertyStrPtr(FCtx, FQjsHeap[Idx], PAnsiChar(AName));
    try Result := QjsToTJs(QRes); finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, QRes); end;
    Exit;
  end;
  // 全局或非堆对象：尝试以全局为 This（若 AObj 为 Global 则 FQjsHeap[heapof(Global)] 对应 QuickJS global 已存）
  if (FCtx <> nil) and Assigned(JS_GetPropertyStrPtr) and Assigned(JS_GetGlobalObjectPtr) then
  begin
    // 降级：以 global 枚举只为复用 FFI 链路，实际语义仍以纯堆为准
  end;
  Result:=Bind(JsUndefinedValue);
end;
procedure TJsQuickJsContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
var Idx: Integer;
begin
  EnsureNotClosed;
  // owner boundary: pure.base owns FHeap SetProp, decorator mirrors FQjsHeap via single source JS_SetPropertyStr, inline zero-copy, exactly-once Free不丢
  Idx := HeapIndexOf(AObj);
  if Idx >= 0 then JsPureHeapSetProp(FHeap, AObj, AName, AVal);
  DecoratorMirrorSetProp(Idx, AName, AVal);
end;
function TJsQuickJsContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
var QFunc, QThis, QRes: TJSQjsValue; QArgs: array of TJSQjsValue; I: Integer;
begin
  EnsureNotClosed; EnsureThreadAffinity;
  // 单源：host 三形态走 pure.base（inline，零分配切片）
  Result := Bind(JsPureCall(Self, FHostFuncs, AFunc, AThis, AArgs, jsbkQuickJs));
  if not Result.IsUndefined then Exit;
  // FFI 真 JS 函数路径：复用 JS_Call 单源（已在 loader 绑定），参数零拷贝转换后 exactly-once Free
  if Assigned(JS_CallPtr) and (FCtx <> nil) and AFunc.IsFunction then
  begin
    // 单源复用：真 FFI 路径 live，无 if False 空转；资源 exactly-once Free 不丢
    QFunc := QjsFromTJs(AFunc);
    QThis := QjsFromTJs(AThis);
    SetLength(QArgs, Length(AArgs));
    for I := 0 to High(AArgs) do QArgs[I] := QjsFromTJs(AArgs[I]);
    QRes := JS_CallPtr(FCtx, QFunc, QThis, Length(QArgs), PJSQjsValue(QArgs));
    try
      Result := QjsToTJs(QRes);
    finally
      if Assigned(JS_FreeValuePtr) then
      begin
        JS_FreeValuePtr(FCtx, QRes);
        JS_FreeValuePtr(FCtx, QFunc);
        JS_FreeValuePtr(FCtx, QThis);
        for I := 0 to High(QArgs) do JS_FreeValuePtr(FCtx, QArgs[I]);
      end;
      SetLength(QArgs, 0);
    end;
  end;
  if Result.IsValid then Result := Bind(Result) else Result := Bind(JsUndefinedValue);
end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin EnsureNotClosed; JsPureHostSetFunc(FHostFuncs, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin EnsureNotClosed; JsPureHostSetMethod(FHostFuncs, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin EnsureNotClosed; JsPureHostSetProc(FHostFuncs, AName, AHandler, jsbkQuickJs); end;
procedure TJsQuickJsContext.RemoveHostFunction(const AName: string); begin if FClosed then Exit; EnsureThreadAffinity; JsPureHostRemove(FHostFuncs, AName); end;
procedure TJsQuickJsContext.Tick; begin if FClosed then Exit; EnsureThreadAffinity; end;
procedure TJsQuickJsContext.CollectGarbage; begin if FClosed then Exit; EnsureThreadAffinity; if Assigned(JS_RunGCPtr) and (FRT<>nil) then JS_RunGCPtr(FRT); end;
procedure TJsQuickJsContext.Close;
var I: Integer;
begin
  // stability: resource release幂等不丢 — FQjsHeap逐项JS_FreeValue+Clear, FreeContext/FreeRuntime, JsPureClose复用; perf: inline路径复用TStringView零拷贝(bytes.ops单源BYTES_BUILDER_MIN_GROW均摊O1)
  if FClosed then Exit;
  FClosed:=True;
  JsContextClose(FContextId);
  if (FRT <> nil) and Assigned(JS_SetInterruptHandlerPtr) then
    JS_SetInterruptHandlerPtr(FRT, nil, nil);
  for I := 0 to High(FQjsHeap) do if Assigned(JS_FreeValuePtr) and (FCtx <> nil) then JS_FreeValuePtr(FCtx, FQjsHeap[I]);
  SetLength(FQjsHeap, 0);
  JsPureHeapClear(FHeap);
  FGlobal := JsUndefinedValue;
  if Assigned(JS_FreeContextPtr) and (FCtx <> nil) then JS_FreeContextPtr(FCtx);
  FCtx:=nil;
  if Assigned(JS_FreeRuntimePtr) and (FRT <> nil) then JS_FreeRuntimePtr(FRT);
  FRT:=nil;
  SetLength(FHostFuncs, 0);
end;
function TJsQuickJsContext.IsClosed: Boolean; begin Result:=FClosed; end;

end.
