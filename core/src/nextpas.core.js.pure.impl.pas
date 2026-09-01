unit nextpas.core.js.pure.impl;
{**
 * @desc 纯后端共享模板（js888/v8/chakra 单源，零 FFI/零 platform.dl）。
 *       抽取三纯后端 95% 克隆，仅 BackendKind 差异走构造参数注入，
 *       薄转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view）。
 *       资源释放幂等：Close → JsPureClose 统一清 Hosts/Heap/Global + ContextId 失效。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.json,
  nextpas.core.json.value;

type
  TJsPureRuntime = class(TInterfacedObject, IJsRuntime)
  private
    FKind: TJsBackendKind;
    FOptions: TJsRuntimeOptions;
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
    function Kind: TJsBackendKind;
    function Options: TJsRuntimeOptions;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure CollectGarbage;
  end;

  TJsPureContext = class(TInterfacedObject, IJsContext)
  private
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FHostFuncs: TJsPureHostArray;
    FHeap: TJsPureHeap;
    FGlobal: TJsValue;
    FBackend: TJsBackendKind;
    function FindHost(const AName: string): Integer; inline;
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline;
    procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    function DoEval(const ACode: string): TJsValue;
    procedure DoSetHost(const AName: string);
    function Bind(const V: TJsValue): TJsValue; inline;
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
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
    procedure CollectGarbage;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.platform.thread;

{ TJsPureRuntime }

constructor TJsPureRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FKind := AKind;
  FOptions := AOptions;
  CheckJsRuntimeOptions(FOptions);
end;

function TJsPureRuntime.Kind: TJsBackendKind;
begin
  Result := FKind;
end;

function TJsPureRuntime.Options: TJsRuntimeOptions;
begin
  Result := FOptions;
end;

function TJsPureRuntime.NewContext: IJsContext;
begin
  Result := TJsPureContext.Create(Self, FOptions, FKind);
end;

procedure TJsPureRuntime.SetMemoryLimit(ALimit: SizeUInt);
begin
  FOptions.MemoryLimit := ALimit;
end;

procedure TJsPureRuntime.SetTimeout(ATimeoutMs: Integer);
begin
  if ATimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', FKind);
  FOptions.TimeoutMs := ATimeoutMs;
end;

procedure TJsPureRuntime.CollectGarbage;
begin
end;

{ TJsPureContext }

constructor TJsPureContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FBackend := ABackend;
  FClosed := False;
  FThreadId := UInt64(platform_thread_self);
  FContextId := JsContextRegister;
  FGlobal := Bind(JsPureHeapNewObject(FHeap));
end;

function TJsPureContext.FindHost(const AName: string): Integer; inline;
begin
  Result := JsPureFindHost(FHostFuncs, AName);
end;

function TJsPureContext.IsOnCreationThread: Boolean; inline;
begin
  Result := UInt64(platform_thread_self) = FThreadId;
end;

procedure TJsPureContext.EnsureNotClosed; inline;
begin
  if FClosed then
    raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', FBackend);
end;

procedure TJsPureContext.EnsureThreadAffinity; inline;
begin
  if not IsOnCreationThread then
    raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', FBackend);
end;

function TJsPureContext.ValidateHostName(const AName: string): Boolean; inline;
begin
  Result := JsPureValidateHostName(AName);
end;

function TJsPureContext.Bind(const V: TJsValue): TJsValue; inline;
begin
  Result := JsValueBindContext(V, FContextId);
end;

function TJsPureContext.DoEval(const ACode: string): TJsValue;
begin
  Result := Bind(JsPureDoEval(Self, ACode, FOptions, FBackend, FHostFuncs, Global));
end;

procedure TJsPureContext.DoSetHost(const AName: string);
begin
  EnsureNotClosed;
  JsPureCheckHostName(AName, FBackend);
end;

function TJsPureContext.Runtime: IJsRuntime;
begin
  EnsureNotClosed;
  Result := FRuntime;
end;

function TJsPureContext.Eval(const ACode: string; const AFileName: string): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := DoEval(ACode);
end;

function TJsPureContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin
  EnsureNotClosed;
  try
    AValue := Eval(ACode);
    Result := True;
  except
    AValue := JsUndefinedValue;
    Result := False;
  end;
end;

function TJsPureContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var
  C: string;
begin
  EnsureNotClosed;
  AValue := JsUndefinedValue;
  if not JsPureTryReadFileText(AFileName, C) then
    Exit(False);
  Result := TryEval(C, AValue);
end;

function TJsPureContext.Global: TJsValue;
begin
  EnsureNotClosed;
  Result := FGlobal;
end;

function TJsPureContext.NewString(const AStr: string): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewString(AStr, FContextId);
end;

function TJsPureContext.NewInt(AValue: Int64): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewInt(AValue, FContextId);
end;

function TJsPureContext.NewDouble(AValue: Double): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewDouble(AValue, FContextId);
end;

function TJsPureContext.NewBool(AValue: Boolean): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewBool(AValue, FContextId);
end;

function TJsPureContext.NewObject: TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsPureHeapNewObject(FHeap));
end;

function TJsPureContext.NewArray: TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsPureHeapNewArray(FHeap));
end;

function TJsPureContext.NewJson(const AJson: TJsonValue): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewJson(AJson, FHeap, FContextId);
end;

function TJsPureContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin
  EnsureNotClosed;
  Result := JsPureToJson(AValue);
end;

function TJsPureContext.HasProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  Result := JsPureHeapHasProp(FHeap, AObj, AName);
end;

function TJsPureContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  Result := JsPureHeapDeleteProp(FHeap, AObj, AName);
end;

function TJsPureContext.GetKeys(const AObj: TJsValue): TJsStringArray;
begin
  EnsureNotClosed;
  Result := JsPureHeapGetKeys(FHeap, AObj);
end;

function TJsPureContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsErrorValue(AMessage));
end;

function TJsPureContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue;
begin
  EnsureNotClosed;
  if Assigned(AHandler) then
    SetHostFunction(AName, AHandler);
  Result := Bind(JsFunctionValue(AName));
end;

function TJsPureContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue;
begin
  EnsureNotClosed;
  if Assigned(AHandler) then
    SetHostFunction(AName, AHandler);
  Result := Bind(JsFunctionValue(AName));
end;

function TJsPureContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue;
begin
  EnsureNotClosed;
  if Assigned(AHandler) then
    SetHostFunction(AName, AHandler);
  Result := Bind(JsFunctionValue(AName));
end;

function TJsPureContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsPureHeapGetProp(FHeap, AObj, AName));
end;

procedure TJsPureContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
begin
  EnsureNotClosed;
  JsPureHeapSetProp(FHeap, AObj, AName, AVal);
end;

function TJsPureContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := Bind(JsPureCall(Self, FHostFuncs, AFunc, AThis, AArgs, FBackend));
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin
  EnsureNotClosed;
  JsPureHostSetFunc(FHostFuncs, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin
  EnsureNotClosed;
  JsPureHostSetMethod(FHostFuncs, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin
  EnsureNotClosed;
  JsPureHostSetProc(FHostFuncs, AName, AHandler, FBackend);
end;

procedure TJsPureContext.RemoveHostFunction(const AName: string);
begin
  if FClosed then
    Exit;
  EnsureThreadAffinity;
  JsPureHostRemove(FHostFuncs, AName);
end;

procedure TJsPureContext.Tick;
begin
  if FClosed then
    Exit;
  EnsureThreadAffinity;
end;

procedure TJsPureContext.CollectGarbage;
begin
  if FClosed then
    Exit;
  EnsureThreadAffinity;
end;

procedure TJsPureContext.Close;
begin
  if FClosed then
    Exit;
  FClosed := True;
  JsPureClose(FHostFuncs, FHeap, FGlobal, FContextId);
end;

function TJsPureContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;

end.
