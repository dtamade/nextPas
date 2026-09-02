unit nextpas.core.js.factory;
{** @desc JS 工厂：薄转发至注册表单源（自身零直接 uses，传递扇出经 registry 唯一扇出点显式收敛，非掩盖）。
     承载 CreateJsRuntime / JsBackendAvailable / DefaultJsRuntimeOptions 薄转发，
     5 后端分支与探测显式下沉至 js.registry 单源（O(1) 索引 + JsRegisterBackend 扩展优雅，registry 为 L2 唯一扇出 owner，工厂传递扇出经 registry 单缝），
     工厂零直接 uses fake/js888/v8/chakra/quickjs（传递扇出经 registry 单缝显式，非零扇出掩盖硬耦合），门面 inline 薄转发收益完整。
     守四件套 base←intf←registry←factory←门面 与 L0-L3（L2→L2 单缝经 intf/pure.base→registry，registry 唯一扇出，零循环），
     复用 bytes.ops 单源（经 js.pure.base 几何 BytesNextCapacity + js.registry 探测名单 SpanTrim/SpanEqual + text.view 零拷贝，BytesCopy 单源 inline），
     热点 inline 零拷贝 + Move 单源（registry O(1) 数组索引 via VaultRef snapshot），资源幂等不丢（registry 构造 exactly-once 抛 EJsBackendUnavailable/CheckJsRuntimeOptions fail-closed，pure.base JsPureClose / quickjs StoreClear 幂等不丢）。 *}
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
