unit nextpas.core.js.chakra;
{** @desc 纯 Pascal 后端占位（零 FFI/零 platform.dl，恒可用，与 fake 同约束，S3 可演进为真解析器）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js.pure.base, nextpas.core.json;
type
  TJsChakraRuntime = class(TInterfacedObject, IJsRuntime)
  private FOptions: TJsRuntimeOptions;
  public constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
  constructor Create(const AOptions: TJsRuntimeOptions); overload;
  function Kind: TJsBackendKind; function Options: TJsRuntimeOptions;
  function NewContext: IJsContext; procedure SetMemoryLimit(ALimit: SizeUInt);
  procedure SetTimeout(ATimeoutMs: Integer); procedure CollectGarbage;
  end;
  TJsChakraContext = class(TInterfacedObject, IJsContext)
  private FRuntime: IJsRuntime; FOptions: TJsRuntimeOptions; FClosed: Boolean; FThreadId: UInt64;
    FHostFuncs: TJsPureHostArray; FHeap: TJsPureHeap; FGlobal: TJsValue;
    function FindHost(const AName: string): Integer; inline; function IsOnCreationThread: Boolean;
    procedure EnsureNotClosed; procedure EnsureThreadAffinity; function ValidateHostName(const AName: string): Boolean; inline;
    function DoEval(const ACode: string): TJsValue; procedure DoSetHost(const AName: string);
  public constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
  function Runtime: IJsRuntime; function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
  function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
  function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
  function Global: TJsValue; function NewString(const AStr: string): TJsValue;
  function NewInt(AValue: Int64): TJsValue; function NewDouble(AValue: Double): TJsValue;
  function NewBool(AValue: Boolean): TJsValue; function NewObject: TJsValue; function NewArray: TJsValue;
  function NewJson(const AJson: TJsonValue): TJsValue; function ToJson(const AValue: TJsValue): IJsonDocument;
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
  procedure RemoveHostFunction(const AName: string); procedure Tick; procedure CollectGarbage; procedure Close; function IsClosed: Boolean;
  end;
implementation
uses nextpas.core.base, nextpas.core.exception, nextpas.core.fs, nextpas.core.format.limits, nextpas.core.text, nextpas.core.platform.thread;
constructor TJsChakraRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
constructor TJsChakraRuntime.Create(const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
function TJsChakraRuntime.Kind: TJsBackendKind; begin Result := jsbkChakra; end;
function TJsChakraRuntime.Options: TJsRuntimeOptions; begin Result := FOptions; end;
function TJsChakraRuntime.NewContext: IJsContext; begin Result := TJsChakraContext.Create(Self, FOptions); end;
procedure TJsChakraRuntime.SetMemoryLimit(ALimit: SizeUInt); begin FOptions.MemoryLimit := ALimit; end;
procedure TJsChakraRuntime.SetTimeout(ATimeoutMs: Integer);
begin if ATimeoutMs < 0 then raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', jsbkChakra); FOptions.TimeoutMs := ATimeoutMs; end;
procedure TJsChakraRuntime.CollectGarbage; begin end;
constructor TJsChakraContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin inherited Create; FRuntime := ARuntime; FOptions := AOptions; FClosed := False; FThreadId := UInt64(platform_thread_self); FGlobal := JsPureHeapNewObject(FHeap); end;
function TJsChakraContext.FindHost(const AName: string): Integer; inline; begin Result := JsPureFindHost(FHostFuncs, AName); end;
function TJsChakraContext.IsOnCreationThread: Boolean; inline; begin Result := UInt64(platform_thread_self)=FThreadId; end;
procedure TJsChakraContext.EnsureNotClosed; inline; begin if FClosed then raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkChakra); end;
procedure TJsChakraContext.EnsureThreadAffinity; inline; begin if not IsOnCreationThread then raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkChakra); end;
function TJsChakraContext.ValidateHostName(const AName: string): Boolean; inline; begin Result := JsPureValidateHostName(AName); end;
function TJsChakraContext.DoEval(const ACode: string): TJsValue; begin Result := JsPureDoEval(Self, ACode, FOptions, jsbkChakra, FHostFuncs, Global); end;
function TJsChakraContext.Runtime: IJsRuntime; begin EnsureNotClosed; Result:=FRuntime; end;
function TJsChakraContext.Eval(const ACode: string; const AFileName: string): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=DoEval(ACode); end;
function TJsChakraContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean; begin EnsureNotClosed; try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;
function TJsChakraContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin EnsureNotClosed; AValue:=JsUndefinedValue; if not TryReadFileText(AFileName, C) then Exit(False); Result:=TryEval(C, AValue); end;
function TJsChakraContext.Global: TJsValue; begin EnsureNotClosed; Result:=FGlobal; end;
function TJsChakraContext.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsStringValue(AStr); end;
function TJsChakraContext.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsIntValue(AValue); end;
function TJsChakraContext.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsDoubleValue(AValue); end;
function TJsChakraContext.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsBoolValue(AValue); end;
function TJsChakraContext.NewObject: TJsValue; begin EnsureNotClosed; Result:=JsPureHeapNewObject(FHeap); end;
function TJsChakraContext.NewArray: TJsValue; begin EnsureNotClosed; Result:=JsPureHeapNewArray(FHeap); end;
function TJsChakraContext.NewJson(const AJson: TJsonValue): TJsValue;
begin EnsureNotClosed; if AJson.IsStr then Result:=JsStringValue(AJson.AsStr.ToString) else if AJson.IsInt then Result:=JsIntValue(AJson.AsInt) else if AJson.IsBool then Result:=JsBoolValue(AJson.AsBool) else if AJson.IsNull then Result:=JsNullValue else if AJson.IsArray then Result:=NewArray else if AJson.IsObject then Result:=NewObject else Result:=JsUndefinedValue; end;
function TJsChakraContext.ToJson(const AValue: TJsValue): IJsonDocument;
var LJson: string; begin EnsureNotClosed; case AValue.Kind of jskString: LJson:='"'+AValue.AsString+'"'; jskNumber: LJson:=nextpas.core.text.IntToStr(AValue.AsInt); jskBoolean: if AValue.AsBool then LJson:='true' else LJson:='false'; jskNull: LJson:='null'; else LJson:='null'; end; Result:=JsonParse(LJson); end;
function TJsChakraContext.HasProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=JsPureHeapHasProp(FHeap, AObj, AName); end;
function TJsChakraContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=JsPureHeapDeleteProp(FHeap, AObj, AName); end;
function TJsChakraContext.GetKeys(const AObj: TJsValue): TJsStringArray; begin EnsureNotClosed; Result:=JsPureHeapGetKeys(FHeap, AObj); end;
function TJsChakraContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result:=JsErrorValue(AMessage); end;
function TJsChakraContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsChakraContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsChakraContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsChakraContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue; begin EnsureNotClosed; Result:=JsPureHeapGetProp(FHeap, AObj, AName); end;
procedure TJsChakraContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue); begin EnsureNotClosed; JsPureHeapSetProp(FHeap, AObj, AName, AVal); end;
function TJsChakraContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=JsPureCall(Self, FHostFuncs, AFunc, AThis, AArgs, jsbkChakra); end;
procedure TJsChakraContext.DoSetHost(const AName: string); begin EnsureNotClosed; if not ValidateHostName(AName) then raise EJsError.Create('Invalid host function name: '+AName,jecSyntax,'SyntaxError','',jsbkChakra); end;
procedure TJsChakraContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkChakra); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Func:=AHandler; FHostFuncs[LIdx].Kind:=0; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Func:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=0; end;
procedure TJsChakraContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkChakra); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Method:=AHandler; FHostFuncs[LIdx].Kind:=1; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Method:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=1; end;
procedure TJsChakraContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkChakra); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Proc:=AHandler; FHostFuncs[LIdx].Kind:=2; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Proc:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=2; end;
procedure TJsChakraContext.RemoveHostFunction(const AName: string);
var LIdx,I: Integer; begin EnsureNotClosed; LIdx:=FindHost(AName); if LIdx<0 then Exit; for I:=LIdx to High(FHostFuncs)-1 do FHostFuncs[I]:=FHostFuncs[I+1]; SetLength(FHostFuncs,Length(FHostFuncs)-1); end;
procedure TJsChakraContext.Tick; begin EnsureNotClosed; end;
procedure TJsChakraContext.CollectGarbage; begin EnsureNotClosed; end;
procedure TJsChakraContext.Close;
var I: Integer;
begin
  if FClosed then Exit;
  FClosed := True;
  for I := 0 to High(FHostFuncs) do
  begin
    FHostFuncs[I].Name := '';
    FHostFuncs[I].Func := nil;
    FHostFuncs[I].Method := nil;
    FHostFuncs[I].Proc := nil;
  end;
  SetLength(FHostFuncs, 0);
  JsPureHeapClear(FHeap);
  FGlobal := JsUndefinedValue;
end;
function TJsChakraContext.IsClosed: Boolean; begin Result:=FClosed; end;
end.
