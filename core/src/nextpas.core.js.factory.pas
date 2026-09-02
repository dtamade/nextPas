unit nextpas.core.js.factory;
{** @desc JS 工厂：薄转发至注册表（零 L2 扇出，注册表单源）。
     承载 CreateJsRuntime / JsBackendAvailable / DefaultJsRuntimeOptions 薄转发，
     5 后端分支与探测下沉至 js.registry（O(1) 索引 + JsRegisterBackend 扩展优雅），
     工厂零直接 uses fake/js888/v8/chakra/quickjs，门面 inline 薄转发收益完整。
     守四件套 base←intf←registry←factory←门面 与 L0-L3（L2→L2 单缝经 intf/pure.base，零循环），
     复用 bytes.ops 单源（经 js.pure.base 几何 + js.registry 探测名单 + text.view 零拷贝），
     热点 inline 零拷贝 + Move 单源（registry O(1) 数组索引），资源幂等不丢（registry 构造 exactly-once 抛 EJsBackendUnavailable/CheckJsRuntimeOptions fail-closed，pure.base JsPureClose / quickjs StoreClear 不丢）。 *}
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
  // stability: CheckJsRuntimeOptions 先验负 Timeout fail-closed 无泄漏，registry O(1) 分发 exactly-once 抛 EJsBackendUnavailable（含 probe 名表，bytes.ops 单源）
  CheckJsRuntimeOptions(AOptions);
  Result := JsRegistryCreate(AKind, AOptions);
end;
end.
