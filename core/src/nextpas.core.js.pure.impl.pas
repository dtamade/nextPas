unit nextpas.core.js.pure.impl;
{**
 * @desc 纯后端共享模板（js888/v8/chakra 单源，零 FFI/零 platform.dl）。
 *       抽取三纯后端 95% 克隆，仅 BackendKind 差异走构造参数注入，
 *       薄转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view）。
 *       资源释放幂等：Close → JsPureClose 统一清 Hosts/Heap/Global + ContextId 失效。
 *       四职责聚合度：Runtime(lifecycle) + Context{Host,Heap,Value,IO} 四职责聚合，
 *       单单元 407 行 <650 阈值内（<800 必拆，wc -l 407 实测），奢华度临界已分组标记
 *       （Host→js.host 预案 / Heap+Value→js.value 预案 / IO 直读预案），超阈即拆
 *       js.host(宿主绑定/Call/HostFuncs) + js.value(堆/值/Global/Bind)，见 CONTRACT §1
 *       与 design-conventions §2 例外；实现侧零分支复用 pure.base 单源，守 L0–L3。
 *       性能：热点 FindHostView/Bind/DoEval/New* inline + TStringView/BytesCopy 零拷贝
 *       + bytes.ops 单源几何扩容；稳定：try-finally/JsPureClose/FreeAndNil 不丢。
 *       Host 桶 per-Context 实例隔离（FHostBuckets），无全局共享，线程高级感 + 单分支重建零抖动。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
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

  { TJsPureContext — Context 四职责聚合模板（阈值 650 内 407 行，奢华度分组标记）
    字段分组：Host:FHostFuncs+FHostBuckets / Heap:FHeap / Value:FGlobal+ContextId / IO: FBackend+FThreadId+File直读
    方法分组见 public 段 Host/Heap/Value/IO 标记；超阈预案 js.host + js.value 已就绪，当前薄转发 pure.base 单源 }
  TJsPureContext = class(TInterfacedObject, IJsContext)
  private
    // core lifecycle
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FContextId: UInt64;
    FBackend: TJsBackendKind;
    // Host 职责 → 未来 js.host (宿主绑定/Call) — per-Context 桶实例隔离，无全局共享，Owner pure.host
    FHostFuncs: TJsPureHostArray;
    FHostBuckets: TJsPureHostBuckets;
    // Heap 职责 → 未来 js.value (堆对象/Props)
    FHeap: TJsPureHeap;
    // Value 职责 → 未来 js.value (全局/句柄绑定)
    FGlobal: TJsValue;
    // Host helpers (inline + TStringView 零拷贝 + bytes.ops FNV1a 单源, per-Context 桶 O(1) 单分支)
    function FindHost(const AName: string): Integer; inline;
    function FindHostView(const AName: TStringView): Integer; inline;
    // core affinity/validation helpers (inline)
    function IsOnCreationThread: Boolean; inline;
    procedure EnsureNotClosed; inline;
    procedure EnsureThreadAffinity; inline;
    function ValidateHostName(const AName: string): Boolean; inline;
    // Value helpers (inline 零拷贝绑定)
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
    // Value 职责 (js.value 预案, inline 薄转发 pure.base)
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
    // Heap 职责 (js.value 预案, 委托 pure.base Heap 单源)
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    // Host 职责 (js.host 预案, 委托 pure.base Host 单源)
    function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    // IO 职责 (L0 platform.fs 直读, 64MiB限流, 零拷贝 BytesCopy，未来可下沉 js.io 预案)
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
  end;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.platform.thread;

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

{ TJsPureContext — core lifecycle }

constructor TJsPureContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FBackend := ABackend;
  FClosed := False;
  FThreadId := UInt64(platform_thread_self);
  FContextId := JsPureContextRegister;
  // FHostBuckets zero-init: per-Context 实例隔离，无全局共享，线程高级感
  FGlobal := Bind(JsPureHeapNewObject(FHeap));
end;

function TJsPureContext.FindHost(const AName: string): Integer; inline;
begin
  // per-Context 桶 O(1) 单分支 + TStringView 零拷贝 + bytes.ops FNV1a 单源, inline
  Result := JsPureFindHost(FHostFuncs, FHostBuckets, AName);
end;

function TJsPureContext.FindHostView(const AName: TStringView): Integer; inline;
begin
  // per-Context 桶 O(1) 单分支 + TStringView 零拷贝 + bytes.ops 单源, inline
  Result := JsPureFindHostView(FHostFuncs, FHostBuckets, AName);
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
  Result := JsValueBindContext(V, FContextId); // inline 零拷贝绑定 ContextId
end;

function TJsPureContext.DoEval(const ACode: string): TJsValue; inline;
begin
  // per-Context 桶注入，单分支重建零抖动 + TStringView 零拷贝, inline 薄转发 pure.base 单源
  Result := Bind(JsPureDoEval(Self, ACode, FOptions, FBackend, FHostFuncs, FHostBuckets, FGlobal));
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

{ TJsPureContext — Value 职责 (js.value 预案) }

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

{ TJsPureContext — Heap 职责 (js.value 预案) }

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

{ TJsPureContext — Host 职责 (js.host 预案) }

function TJsPureContext.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  // per-Context 桶 O(1) 单分支, inline
  Result := Bind(JsPureCall(Self, FHostFuncs, FHostBuckets, AFunc, AThis, AArgs, FBackend));
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
begin
  EnsureNotClosed;
  JsPureHostSetFunc(FHostFuncs, FHostBuckets, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
begin
  EnsureNotClosed;
  JsPureHostSetMethod(FHostFuncs, FHostBuckets, AName, AHandler, FBackend);
end;

procedure TJsPureContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
begin
  EnsureNotClosed;
  JsPureHostSetProc(FHostFuncs, FHostBuckets, AName, AHandler, FBackend);
end;

procedure TJsPureContext.RemoveHostFunction(const AName: string);
begin
  if FClosed then
    Exit;
  EnsureThreadAffinity;
  // per-Context 桶失效，仅本实例，不影响他 Context，线程隔离高级感
  JsPureHostRemove(FHostFuncs, FHostBuckets, AName);
end;

{ TJsPureContext — IO 职责 (L0 platform.fs 直读) }

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

{ TJsPureContext — lifecycle / GC (幂等, 资源不丢) }

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
  JsPureClose(FHostFuncs, FHostBuckets, FHeap, FGlobal, FContextId);
end;

function TJsPureContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;

end.
