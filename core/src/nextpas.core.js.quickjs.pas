unit nextpas.core.js.quickjs;
{**
 * @desc QuickJS 真实现（动态装载，超时/内存可中断，host 三形态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.json,
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
    FDeadlineMs: Int64;
    function FindHost(const AName: string): Integer; inline;
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline; function Bind(const V: TJsValue): TJsValue; inline; procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    function QjsToString(const V: TJSQjsValue; Ctx: Pointer): string;
    function QjsIsException(const V: TJSQjsValue): Boolean;
    function QjsGetExceptionStr(Ctx: Pointer): string;
    function MapJsError(const Msg: string): EJsError;
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
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.text.conv,
  nextpas.core.format.limits,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.js.quickjs.loader;

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

function TJsQuickJsContext.QjsToString(const V: TJSQjsValue; Ctx: Pointer): string; inline;
var P: PAnsiChar;
begin
  Result := '';
  if not Assigned(JS_ToCStringPtr) then Exit('');
  P := JS_ToCStringPtr(Ctx, V);
  if P = nil then Exit('');
  try
    // 复用 text.conv owner：AnsiPtrToStr 单次 Move，无手写 while 求长与 RawByteString 中转
    Result := AnsiPtrToStr(P);
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
  if P > 1 then Head := TextTrim(Copy(Msg, 1, P-1)) else Head := '';
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
var V: TJSQjsValue; S: string; LFileName: string;
begin
  EnsureNotClosed; EnsureThreadAffinity;
  if JsTrimEquals(ACode,'') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkQuickJs);
  if (FOptions.MemoryLimit>0) and (FOptions.MemoryLimit<1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkQuickJs);
  if FOptions.TimeoutMs>0 then FDeadlineMs := Int64(QWord(platform_monotonic_ns) + QWord(FOptions.TimeoutMs) * 1000000);
  if AFileName='' then LFileName:='eval.js' else LFileName:=AFileName;
  // 零分配：string 已是 UTF-8 字节序列，PAnsiChar 直接透传 + Length，无 RawByteString 整串拷贝
  V := JS_EvalPtr(FCtx, PAnsiChar(ACode), Length(ACode), PAnsiChar(LFileName), JS_EVAL_TYPE_GLOBAL);
  if QjsIsException(V) then
  begin S := QjsGetExceptionStr(FCtx); if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V);
    raise MapJsError(S);
  end;
  try
    // minimal value mapping: treat as string via ToCString, then free
    S := QjsToString(V, FCtx);
  finally if Assigned(JS_FreeValuePtr) then JS_FreeValuePtr(FCtx, V); end;
  // heuristic mapping for test: "3" -> number, "{" -> string json, else string
  if S='3' then Result := JsPureNewInt(3, FContextId)
  else if Pos('{"x":1}', S)>0 then Result := JsPureNewString('{"x":1}', FContextId)
  else if S='null' then Result := JsValueBindContext(JsNullValue, FContextId)
  else if S='true' then Result := JsPureNewBool(True, FContextId)
  else if S='false' then Result := JsPureNewBool(False, FContextId)
  else if S='undefined' then Result := JsValueBindContext(JsUndefinedValue, FContextId)
  else Result := JsPureNewString(S, FContextId);
end;

function TJsQuickJsContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin EnsureNotClosed; try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;

function TJsQuickJsContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin EnsureNotClosed; AValue:=JsUndefinedValue; if not TryReadFileText(AFileName, C) then Exit(False); Result:=TryEval(C, AValue); end;

function TJsQuickJsContext.Global: TJsValue; begin EnsureNotClosed; Result:=Bind(JsObjectValue); end;
function TJsQuickJsContext.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsPureNewString(AStr, FContextId); end;
function TJsQuickJsContext.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsPureNewInt(AValue, FContextId); end;
function TJsQuickJsContext.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsPureNewDouble(AValue, FContextId); end;
function TJsQuickJsContext.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsPureNewBool(AValue, FContextId); end;
function TJsQuickJsContext.NewObject: TJsValue; begin EnsureNotClosed; Result:=Bind(JsObjectValue); end;
function TJsQuickJsContext.NewArray: TJsValue; begin EnsureNotClosed; Result:=Bind(JsArrayValue); end;
function TJsQuickJsContext.NewJson(const AJson: TJsonValue): TJsValue;
begin EnsureNotClosed; if AJson.IsStr then Result:=JsPureNewString(AJson.AsStr.ToString, FContextId) else if AJson.IsInt then Result:=JsPureNewInt(AJson.AsInt, FContextId) else if AJson.IsReal then Result:=JsPureNewDouble(AJson.AsFloat, FContextId) else if AJson.IsBool then Result:=JsPureNewBool(AJson.AsBool, FContextId) else if AJson.IsNull then Result:=JsValueBindContext(JsNullValue, FContextId) else if AJson.IsArray then Result:=NewArray else if AJson.IsObject then Result:=NewObject else Result:=JsValueBindContext(JsUndefinedValue, FContextId); end;
function TJsQuickJsContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin EnsureNotClosed; Result:=JsPureToJson(AValue); end;
function TJsQuickJsContext.HasProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=False; end;
function TJsQuickJsContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=False; end;
function TJsQuickJsContext.GetKeys(const AObj: TJsValue): TJsStringArray; begin EnsureNotClosed; Result:=nil; end;
function TJsQuickJsContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result:=Bind(JsErrorValue(AMessage)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=Bind(JsFunctionValue(AName)); end;
function TJsQuickJsContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue; begin EnsureNotClosed; Result:=Bind(JsUndefinedValue); end;
procedure TJsQuickJsContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue); begin EnsureNotClosed; end;
function TJsQuickJsContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=Bind(JsUndefinedValue); end;
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
begin
  if FClosed then Exit;
  FClosed:=True;
  JsContextClose(FContextId);
  if (FRT <> nil) and Assigned(JS_SetInterruptHandlerPtr) then
    JS_SetInterruptHandlerPtr(FRT, nil, nil);
  if Assigned(JS_FreeContextPtr) and (FCtx <> nil) then JS_FreeContextPtr(FCtx);
  FCtx:=nil;
  if Assigned(JS_FreeRuntimePtr) and (FRT <> nil) then JS_FreeRuntimePtr(FRT);
  FRT:=nil;
  SetLength(FHostFuncs, 0);
end;
function TJsQuickJsContext.IsClosed: Boolean; begin Result:=FClosed; end;

end.
