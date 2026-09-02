unit nextpas.core.js.pure.context;
{**
 * @desc 纯族 Context 单职责子模块（四职责拆分 Context 侧，组合 Host/Value/IO 薄转发）。
 *       聚合 HostState via pure.host(TJsPureHostState per-Context隔离 inline零拷贝) +
 *       ValueState via pure.value(TJsPureValueState Heap/Global via bytes.ops+mem.dynarray) +
 *       IO via pure.base直读（经 js.eval 单源），lifecycle via js.lifecycle single source。
 *       热点 FindHostView/Bind/DoEval/New* inline + TStringView/BytesCopy 零拷贝 + bytes.ops 单源几何扩容；
 *       资源释放幂等：Close → JsPureContextClose 统一清 HostState/ValueState + ContextId 失效，try-finally/FreeAndNil 不丢。
 *       守 L0-L3（仅向下依赖 L0-L1 + pure.host/pure.value/js.eval/js.lifecycle 单源，复用 bytes.ops 单源），wc -l ~360 <800。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;

type
  { TJsPureContext — Context 组合（生命周期:FRuntime/FOptions/FClosed/FThreadId/FContextId/FBackend + Host:FHost + Value:FValue + IO直读） }
  TJsPureContext = class(TInterfacedObject, IJsContext)
  private
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FBackend: TJsBackendKind;
    FHost: TJsPureHostState;
    FValue: TJsPureValueState;
    FInterruptSampleInterval: Cardinal;
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
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
    function Runtime: IJsRuntime;
    procedure Close;
    function IsClosed: Boolean;
    procedure Tick;
    procedure CollectGarbage;
    procedure SetInterruptSampleInterval(AInterval: Cardinal);
    function GetInterruptSampleInterval: Cardinal;
    function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
    function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
    function Global: TJsValue;
    function NewString(const AStr: string): TJsValue;
    function NewInt(AValue: Int64): TJsValue;
    function NewDouble(AValue: Double): TJsValue;
    function NewBool(AValue: Boolean): TJsValue;
    function NewObject: TJsValue;
    function NewArray: TJsValue;
    function NewJson(const AJson: TJsonValue): TJsValue;
    function ToJson(const AValue: TJsValue): IJsonDocument;
    function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
    function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
  end;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.view,
  nextpas.core.js.eval,
  nextpas.core.js.lifecycle,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value;

constructor TJsPureContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FBackend := ABackend;
  FClosed := False;
  FThreadId := JsPureThreadSelf;
  FContextId := JsPureContextRegister;
  FInterruptSampleInterval := JsInterruptSampleIntervalNormalized(FOptions.InterruptSampleInterval);
  JsPureValueStateInit(FValue, FContextId);
end;

function TJsPureContext.FindHost(const AName: string): Integer; inline;
begin
  Result := JsPureFindHost(FHost.Hosts, FHost.Buckets, AName);
end;

function TJsPureContext.FindHostView(const AName: TStringView): Integer; inline;
begin
  Result := JsPureFindHostView(FHost.Hosts, FHost.Buckets, AName);
end;

function TJsPureContext.IsOnCreationThread: Boolean; inline;
begin
  Result := JsPureIsOnCreationThread(FThreadId);
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

function TJsPureContext.DoEval(const ACode: string): TJsValue; inline;
begin
  Result := Bind(nextpas.core.js.eval.JsPureDoEval(Self, ACode, FOptions, FBackend, FHost.Hosts, FHost.Buckets, FValue.Global));
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

function TJsPureContext.Global: TJsValue;
begin
  EnsureNotClosed;
  Result := FValue.Global;
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
  Result := Bind(JsPureHeapNewObject(FValue.Heap));
end;

function TJsPureContext.NewArray: TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsPureHeapNewArray(FValue.Heap));
end;

function TJsPureContext.NewJson(const AJson: TJsonValue): TJsValue;
begin
  EnsureNotClosed;
  Result := JsPureNewJson(AJson, FValue.Heap, FContextId);
end;

function TJsPureContext.ToJson(const AValue: TJsValue): IJsonDocument;
begin
  EnsureNotClosed;
  Result := JsPureToJson(AValue);
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

function TJsPureContext.HasProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  Result := JsPureValueStateHasProp(FValue, AObj, AName);
end;

function TJsPureContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
begin
  EnsureNotClosed;
  Result := JsPureValueStateDeleteProp(FValue, AObj, AName);
end;

function TJsPureContext.GetKeys(const AObj: TJsValue): TJsStringArray;
begin
  EnsureNotClosed;
  Result := JsPureValueStateGetKeys(FValue, AObj);
end;

function TJsPureContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
begin
  EnsureNotClosed;
  Result := Bind(JsPureValueStateGetProp(FValue, AObj, AName));
end;

procedure TJsPureContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
begin
  EnsureNotClosed;
  JsPureValueStateSetProp(FValue, AObj, AName, AVal);
end;

function TJsPureContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := Bind(JsPureCall(Self, FHost.Hosts, FHost.Buckets, AFunc, AThis, AArgs, FBackend));
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin
  EnsureNotClosed;
  JsPureHostStateSetFunc(FHost, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin
  EnsureNotClosed;
  JsPureHostStateSetMethod(FHost, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin
  EnsureNotClosed;
  JsPureHostStateSetProc(FHost, AName, AHandler, FBackend);
end;

procedure TJsPureContext.RemoveHostFunction(const AName: string);
begin
  if FClosed then
    Exit;
  EnsureThreadAffinity;
  JsPureHostStateRemove(FHost, AName);
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
  JsPureContextClose(FContextId);
  JsPureHostStateClear(FHost);
  JsPureValueStateClear(FValue);
end;

function TJsPureContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;

procedure TJsPureContext.SetInterruptSampleInterval(AInterval: Cardinal);
begin
  // perf: inline normalized via base single source, zero alloc, tunable timely/overhead, owner base, inline
  if FClosed then Exit;
  EnsureThreadAffinity;
  FInterruptSampleInterval := JsInterruptSampleIntervalNormalized(AInterval);
  FOptions.InterruptSampleInterval := FInterruptSampleInterval;
end;

function TJsPureContext.GetInterruptSampleInterval: Cardinal;
begin
  Result := FInterruptSampleInterval;
end;

end.
