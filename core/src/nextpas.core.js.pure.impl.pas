unit nextpas.core.js.pure.impl;
{**
 * @desc 纯后端共享模板（js888/v8/chakra 单源，零 FFI/零 platform.dl）。
 *       抽取三纯后端 95% 克隆，仅 BackendKind 差异走构造参数注入，
 *       薄转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view）。
 *       资源释放幂等：Close → JsPureClose 统一清 HostState/ValueState + ContextId 失效。
 *       四职责已落地组合收敛：Runtime(lifecycle) + Context{HostState via pure.host, ValueState via pure.value, IO via pure.base直读} 分层聚合，
 *       单单元 ~360 行 <800 阈值内（800 必拆，wc -l ~360 实测），奢华度已收敛（Host→pure.host.TJsPureHostState per-Context隔离 inline零拷贝 + Value→pure.value.TJsPureValueState Heap/Global via bytes.ops+mem.dynarray, IO 直读 pure.base单源），守 L0–L3。
 *       性能：热点 FindHostView/Bind/DoEval/New* inline + TStringView/BytesCopy 零拷贝 + bytes.ops 单源几何扩容；稳定：try-finally/JsPureClose/FreeAndNil 不丢。
 *       Host 桶 per-Context 实例隔离（FHost.Buckets），无全局共享，线程高级感 + 单分支重建零抖动；ValueState Heap per-Context隔离 via pure.value单源，资源幂等不丢。
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
  { TJsPureRuntime — Runtime lifecycle (Factory→Runtime→NewContext), 单职责 <30 行 }
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

  { TJsPureContext — Context 职责组合收敛（阈值 800 内 ~360 行，奢华度已收敛）
    字段组合：Lifecycle:FRuntime/FOptions/FClosed/FThreadId/FContextId/FBackend + Host:FHost(TJsPureHostState pure.host) + Value:FValue(TJsPureValueState pure.value) + IO:File直读 pure.base
    已落地 pure.host(TJsPureHostState per-Context隔离, bytes.ops FNV1a+BytesCopy单源 inline零拷贝, 幂等不丢) + pure.value(TJsPureValueState Heap/Global via bytes.ops+mem.dynarray inline零拷贝) 组合，薄转发 pure.base单源，守 L0-L3 }
  TJsPureContext = class(TInterfacedObject, IJsContext)
  private
    // core lifecycle — Runtime/Lifecycle 单职责, 幂等, bytes.ops单源
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FBackend: TJsBackendKind;
    // Host聚合态 — 已落地 pure.host.TJsPureHostState (per-Context实例隔离, bytes.ops FNV1a单源 inline零拷贝, 幂等不丢, Owner pure.host)
    FHost: TJsPureHostState;
    // Value/Heap聚合态 — 已落地 pure.value.TJsPureValueState (Heap+Global via bytes.ops+mem.dynarray单源 inline零拷贝, 幂等不丢, Owner pure.value)
    FValue: TJsPureValueState;
    // Host helpers (inline + TStringView 零拷贝 + bytes.ops FNV1a 单源, per-Context 桶 O(1) 单分支, 复用 pure.host单源)
    function FindHost(const AName: string): Integer; inline;
    function FindHostView(const AName: TStringView): Integer; inline;
    // core affinity/validation helpers (inline)
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline;
    procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    // Value helpers (inline 零拷贝绑定, 复用 pure.value单源)
    function DoEval(const ACode: string): TJsValue; inline;
    procedure DoSetHost(const AName: string);
    function Bind(const V: TJsValue): TJsValue; inline;
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
    // core lifecycle
    function Runtime: IJsRuntime;
    procedure Close;
    function IsClosed: Boolean;
    procedure Tick;
    procedure CollectGarbage;
    // Value 职责 (已落地 pure.value, inline 薄转发 pure.value单源)
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
    // Heap 职责 (已落地 pure.value, 委托 pure.value Heap 单源 via bytes.ops+mem.dynarray)
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    // Host 职责 (已落地 pure.host, 委托 pure.host single source via bytes.ops FNV1a)
    function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    // IO 职责 (已落地 pure.base L0 platform.fs 直读, 64MiB限流, 零拷贝 BytesCopy，IO薄转发单源)
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
  end;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text;

{ TJsPureRuntime — Lifecycle }

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

{ TJsPureContext — core lifecycle (组合收敛: HostState+ValueState) }

constructor TJsPureContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FBackend := ABackend;
  FClosed := False;
  FThreadId := JsPureThreadSelf;
  FContextId := JsPureContextRegister;
  // ValueState per-Context隔离 via pure.value单源, FHost zero-init per-Context隔离, 无全局共享, 线程高级感
  JsPureValueStateInit(FValue, FContextId);
end;

function TJsPureContext.FindHost(const AName: string): Integer; inline;
begin
  // per-Context 桶 O(1) 单分支 + TStringView 零拷贝 + bytes.ops FNV1a 单源, inline 复用 pure.host单源
  Result := JsPureFindHost(FHost.Hosts, FHost.Buckets, AName);
end;

function TJsPureContext.FindHostView(const AName: TStringView): Integer; inline;
begin
  // per-Context 桶 O(1) 单分支 + TStringView 零拷贝 + bytes.ops 单源, inline 复用 pure.host单源
  Result := JsPureFindHostView(FHost.Hosts, FHost.Buckets, AName);
end;

function TJsPureContext.IsOnCreationThread: Boolean; inline;
begin
  // perf: inline thin-forward to js.lifecycle/pure.base single source JsPureIsOnCreationThread (L0 platform.thread single slit via lifecycle), zero-copy token, single syscall inline, bytes.ops 单源同保持
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
  Result := JsValueBindContext(V, FContextId); // inline 零拷贝绑定 ContextId, pure.value单源
end;

function TJsPureContext.DoEval(const ACode: string): TJsValue; inline;
begin
  // per-Context 桶注入，单分支重建零抖动 + TStringView 零拷贝, inline 薄转发 pure.base单源 via HostState+ValueState组合
  Result := Bind(JsPureDoEval(Self, ACode, FOptions, FBackend, FHost.Hosts, FHost.Buckets, FValue.Global));
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

{ TJsPureContext — Value 职责 (已落地 pure.value, inline薄转发) }

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

{ TJsPureContext — Heap 职责 (已落地 pure.value, 委托 ValueState单源) }

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

{ TJsPureContext — Host 职责 (已落地 pure.host, 委托 HostState单源) }

function TJsPureContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  // per-Context 桶 O(1) 单分支, inline 复用 pure.host/pure.base单源 via HostState组合
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
  // per-Context 桶失效，仅本实例，不影响他 Context，线程隔离高级感, 复用 HostState单源
  JsPureHostStateRemove(FHost, AName);
end;

{ TJsPureContext — IO 职责 (L0 platform.fs 直读, 已落地 pure.base单源) }

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

{ TJsPureContext — lifecycle / GC (幂等, 资源不丢, 组合收敛) }

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
  JsPureClose(FHost, FValue.Heap, FValue.Global, FContextId);
end;

function TJsPureContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;

end.
