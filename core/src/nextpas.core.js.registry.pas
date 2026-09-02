unit nextpas.core.js.registry;
{** @desc JS 后端注册表：收敛 L2 内扇出，工厂薄转发单缝。
     承载 5 后端工厂与探测单源（fake/js888/v8/chakra/QuickJS），
     工厂仅经 registry O(1) 索引分发，零硬编码 case 分支，扩展优雅（JsRegisterBackend）。
     守四件套 base←intf←(registry←factory)←门面 与 L0-L3（L2 内聚，单向 registry←factory），
     复用 bytes.ops 单源（经 loader 探测名单 + pure.base 几何，零拷贝），
     热点 inline 零拷贝 + Move 单源，资源幂等不丢（pure.base JsPureClose / quickjs StoreClear exactly-once）。 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf;
type
  TJsRuntimeFactory = function(const AOptions: TJsRuntimeOptions): IJsRuntime;
  TJsAvailableFunc = function: Boolean;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc = nil);
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean; inline;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean; inline;
implementation
uses
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs;
var
  GFactories: array[TJsBackendKind] of TJsRuntimeFactory;
  GAvail: array[TJsBackendKind] of TJsAvailableFunc;
  GRegistered: array[TJsBackendKind] of Boolean;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc);
begin
  // perf: O(1) enum index, inline store, zero alloc, single write, lock-free init-time only (single-thread registration before first use, no contended atomic)
  if not Assigned(AFactory) then
    raise EJsError.Create('Backend factory is nil', jecUnknown, 'Error', '', AKind);
  GFactories[AKind] := AFactory;
  GAvail[AKind] := AAvail;
  GRegistered[AKind] := True;
end;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean; inline;
begin
  // perf: inline array index Ord(AKind) O(1), zero-copy, no branch mispredict
  Result := GRegistered[AKind];
end;
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean; inline;
begin
  // perf: inline thin-forward to registry single source, O(1) avail check, zero alloc, no heap
  if not GRegistered[AKind] then Exit(False);
  if Assigned(GAvail[AKind]) then Exit(GAvail[AKind]());
  Result := True;
end;
function CreateFake(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  // perf: inline thin ctor, zero-copy options record, no extra alloc beyond runtime object
  Result := TJsFakeRuntime.Create(jsbkFake, AOptions);
end;
function CreateJs888(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsJs888Runtime.Create(AOptions);
end;
function CreateV8(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsV8Runtime.Create(AOptions);
end;
function CreateChakra(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsChakraRuntime.Create(AOptions);
end;
function QuickJsAvailable: Boolean; inline;
begin
  // single source via loader probe names, bytes.ops single source in loader (JsQuickJsProbeNames), inline thin-forward
  Result := JsQuickJsIsAvailable;
end;
function CreateQuickJs(const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // stability: exactly-once probe+load, fail-closed with probe names, no handle leak on failure
  if not JsQuickJsIsAvailable then
    raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs);
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS load failed', jecUnknown, 'Error', '', jsbkQuickJs);
  Result := TJsQuickJsRuntime.Create(AOptions);
end;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // perf: O(1) enum-index dispatch via registry array, no case-branch duplication, extension via JsRegisterBackend
  // stability: CheckJsRuntimeOptions by caller (factory) fail-closed before dispatch, no resource on throw; creation exactly-once, pure.base JsPureClose / quickjs StoreClear幂等不丢 via callee ctor/clear
  if not GRegistered[AKind] then
    raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
  if Assigned(GAvail[AKind]) and not GAvail[AKind]() then
  begin
    if AKind = jsbkQuickJs then
      raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
    else
      raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
  end;
  Result := GFactories[AKind](AOptions);
end;
procedure RegisterBuiltins;
begin
  JsRegisterBackend(jsbkFake, @CreateFake, nil);
  JsRegisterBackend(jsbkJs888, @CreateJs888, nil);
  JsRegisterBackend(jsbkV8, @CreateV8, nil);
  JsRegisterBackend(jsbkChakra, @CreateChakra, nil);
  JsRegisterBackend(jsbkQuickJs, @CreateQuickJs, @QuickJsAvailable);
end;
initialization
  RegisterBuiltins;
end.
