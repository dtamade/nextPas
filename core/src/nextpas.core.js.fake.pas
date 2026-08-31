unit nextpas.core.js.fake;
{**
 * @desc 假后端（纯 Pascal，零外部依赖，CI 必跑，确定性语义）。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.text.view,
  nextpas.core.json;

type
  TJsFakeRuntime = class;
  TJsFakeContext = class;
  TJsFakeValueRef = class(TInterfacedObject, IJsValueRef)
  private
    FValue: TJsValue;
  public
    constructor Create(const AValue: TJsValue);
    function Value: TJsValue;
  end;
  TJsFakeRuntime = class(TInterfacedObject, IJsRuntime)
  private
    FOptions: TJsRuntimeOptions;
    FKind: TJsBackendKind;
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
    function Kind: TJsBackendKind;
    function Options: TJsRuntimeOptions;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure CollectGarbage;
  end;
  TJsFakeContext = class(TInterfacedObject, IJsContext)
  private
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FHostFuncs: TJsPureHostArray;
    FHeap: TJsPureHeap;
    FGlobal: TJsValue;
    function FindHost(const AName: string): Integer; inline;
    function FindHostView(const AName: TStringView): Integer; inline;
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline;
    procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    function DoEval(const ACode: string): TJsValue; inline;
    procedure DoSetHost(const AName: string);
    function Bind(const V: TJsValue): TJsValue; inline;
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
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
    function Call(const AFunc: TJsValue; const AThis: TJsValue;
      const AArgs: array of TJsValue): TJsValue;
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
  nextpas.core.fs.path,
  nextpas.core.format.limits,
  nextpas.core.text,
  nextpas.core.platform.thread;
constructor TJsFakeValueRef.Create(const AValue: TJsValue);
begin
  inherited Create;
  FValue := AValue;
end;

function TJsFakeValueRef.Value: TJsValue;
begin
  Result := FValue;
end;

constructor TJsFakeRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FKind := AKind;
  FOptions := AOptions;
  CheckJsRuntimeOptions(FOptions);
end;

function TJsFakeRuntime.Kind: TJsBackendKind;
begin
  Result := FKind;
end;

function TJsFakeRuntime.Options: TJsRuntimeOptions;
begin
  Result := FOptions;
end;

function TJsFakeRuntime.NewContext: IJsContext;
begin
  Result := TJsFakeContext.Create(Self, FOptions);
end;

procedure TJsFakeRuntime.SetMemoryLimit(ALimit: SizeUInt);
begin
  FOptions.MemoryLimit := ALimit;
end;

procedure TJsFakeRuntime.SetTimeout(ATimeoutMs: Integer);
begin
  if ATimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', FKind);
  FOptions.TimeoutMs := ATimeoutMs;
end;

procedure TJsFakeRuntime.CollectGarbage;
begin
end;

constructor TJsFakeContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FClosed := False;
  FThreadId := UInt64(platform_thread_self);
  FContextId := JsContextRegister;
  FGlobal := Bind(JsPureHeapNewObject(FHeap));
end;

function TJsFakeContext.FindHost(const AName: string): Integer; inline;
begin
  Result := JsPureFindHost(FHostFuncs, AName);
end;

function TJsFakeContext.IsOnCreationThread: Boolean; inline;
begin
  Result := UInt64(platform_thread_self) = FThreadId;
end;

procedure TJsFakeContext.EnsureNotClosed; inline;
begin
  if FClosed then
    raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkFake);
end;

procedure TJsFakeContext.EnsureThreadAffinity; inline;
begin
  if not IsOnCreationThread then
    raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkFake);
end;

function TJsFakeContext.ValidateHostName(const AName: string): Boolean; inline;
begin
  Result := JsPureValidateHostName(AName);
end;


function TJsFakeContext.FindHostView(const AName: TStringView): Integer; inline;
begin
  Result := JsPureFindHostView(FHostFuncs, AName);
end;

function TJsFakeContext.Bind(const V: TJsValue): TJsValue; inline;
begin
  Result := JsValueBindContext(V, FContextId);
end;

function TJsFakeContext.DoEval(const ACode: string): TJsValue; inline;
begin
  Result := Bind(JsPureDoEval(Self, ACode, FOptions, jsbkFake, FHostFuncs, Global));
end;

function TJsFakeContext.Runtime: IJsRuntime;
begin
  EnsureNotClosed;
  Result := FRuntime;
end;

function TJsFakeContext.Eval(const ACode: string; const AFileName: string): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := DoEval(ACode);
end;

function TJsFakeContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin
  try
    AValue := Eval(ACode);
    Result := True;
  except
    AValue := JsUndefinedValue;
    Result := False;
  end;
end;

function TJsFakeContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin EnsureNotClosed; AValue:=JsUndefinedValue; if not TryReadFileText(AFileName, C) then Exit(False); Result:=TryEval(C, AValue); end;

function TJsFakeContext.Global: TJsValue;
begin
  EnsureNotClosed;
  Result := FGlobal;
end;

function TJsFakeContext.NewString(const AStr: string): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewString(AStr, FContextId);
end;

function TJsFakeContext.NewInt(AValue: Int64): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewInt(AValue, FContextId);
end;

function TJsFakeContext.NewDouble(AValue: Double): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewDouble(AValue, FContextId);
end;

function TJsFakeContext.NewBool(AValue: Boolean): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewBool(AValue, FContextId);
end;

function TJsFakeContext.NewObject: TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsObjectValue);
end;

function TJsFakeContext.NewArray: TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsArrayValue);
end;

function TJsFakeContext.NewJson(const AJson: TJsonValue): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewJson(AJson, FHeap, FContextId);
end;

function TJsFakeContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin
  EnsureNotClosed;
  Result := JsPureToJson(AValue);
end;
function TJsFakeContext.HasProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result := False; end;
function TJsFakeContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result := False; end;
function TJsFakeContext.GetKeys(const AObj: TJsValue): TJsStringArray; begin EnsureNotClosed; Result := nil; end;
function TJsFakeContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result := Bind(JsErrorValue(AMessage)); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := Bind(JsFunctionValue(AName)); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := Bind(JsFunctionValue(AName)); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := Bind(JsFunctionValue(AName)); end;

function TJsFakeContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsUndefinedValue);
end;

procedure TJsFakeContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
begin
  EnsureNotClosed;
end;

function TJsFakeContext.Call(const AFunc: TJsValue; const AThis: TJsValue;
  const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := Bind(JsUndefinedValue);
end;

procedure TJsFakeContext.DoSetHost(const AName: string);
begin
  EnsureNotClosed;
  if not ValidateHostName(AName) then
    raise EJsError.Create('Invalid host function name: ' + AName, jecSyntax, 'SyntaxError', '', jsbkFake);
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  JsPureHostSet(FHostFuncs, AName, AHandler, 0);
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  JsPureHostSet(FHostFuncs, AName, AHandler, 1);
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  JsPureHostSet(FHostFuncs, AName, AHandler, 2);
end;

procedure TJsFakeContext.RemoveHostFunction(const AName: string);
begin
  if FClosed then Exit;
  EnsureThreadAffinity;
  JsPureHostRemove(FHostFuncs, AName);
end;

procedure TJsFakeContext.Tick;
begin
  if FClosed then Exit;
  EnsureThreadAffinity;
end;

procedure TJsFakeContext.CollectGarbage;
begin
  if FClosed then Exit;
  EnsureThreadAffinity;
end;

procedure TJsFakeContext.Close;
var
  I: Integer;
begin
  if FClosed then Exit;
  FClosed := True;
  JsContextClose(FContextId);
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

function TJsFakeContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;
end.
