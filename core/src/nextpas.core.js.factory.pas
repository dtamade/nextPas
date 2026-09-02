unit nextpas.core.js.factory;
{**
 * @desc JS 工厂：薄转发至 registry 单源（L2）。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf;
function CreateJsRuntime(AKind: TJsBackendKind = jsbkFake): IJsRuntime; overload;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime; overload;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; inline;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
implementation
uses
  nextpas.core.js.registry;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
begin
  // perf: inline thin-forward to TJsRuntimeOptions.Default, zero-copy record return, no heap alloc
  Result := TJsRuntimeOptions.Default;
end;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; inline;
begin
  // perf: inline thin-forward to registry single source O(1) enum index, zero-copy, no case duplication, no heap alloc
  Result := JsRegistryAvailable(AKind);
end;
function CreateJsRuntime(AKind: TJsBackendKind): IJsRuntime; inline;
begin
  // perf: inline thin-forward via factory single source, zero-copy IJsRuntime refcnt, no branching duplication
  Result := CreateJsRuntime(AKind, DefaultJsRuntimeOptions);
end;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // stability: CheckJsRuntimeOptions 先验负 Timeout fail-closed 无泄漏 (backend attribution via explicit AKind, 无默认, jsbkQuickJs/jsbkV8/jsbkFake 诊断归因不失真), registry O(1) 分发 exactly-once 抛 EJsBackendUnavailable（含 probe 名表，bytes.ops 单源）
  CheckJsRuntimeOptions(AOptions, AKind);
  Result := JsRegistryCreate(AKind, AOptions);
end;
end.
