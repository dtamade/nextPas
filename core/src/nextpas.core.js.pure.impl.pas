unit nextpas.core.js.pure.impl;
{**
 * @desc 纯族聚合门面（四职责拆分后薄聚合，Runtime→pure.runtime + Context→pure.context 单源）。
 *       原单文件 Runtime+Context+Host+Value 四职责 ~360 行（阈值 800 内仍偏重）已按四件套拆分为
 *       pure.runtime(TJsPureRuntime 生命周期 <50 行 inline) + pure.context(TJsPureContext Host/Value/IO 组合 ~360 行)
 *       本单元仅纯 re-export 无逻辑，零 FFI/零 platform.dl（L0 platform.thread/fs 直读经 context 单源），
 *       薄转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view/pure.host/pure.value/js.eval/js.lifecycle 单源）。
 *       资源释放幂等链：Close → JsPureContextClose + HostStateClear + ValueStateClear（via context 单源），try-finally 不丢。
 *       守 L0-L3 与四件套 base←runtime/context←门面，Host/Value 经 pure.host/pure.value 单源 per-Context 隔离 O(1) 桶，wc -l ~40 <800。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.js.pure.host,
  nextpas.core.js.pure.value,
  nextpas.core.js.pure.runtime,
  nextpas.core.js.pure.context;

type
  TJsPureRuntime = nextpas.core.js.pure.runtime.TJsPureRuntime;
  TJsPureContext = nextpas.core.js.pure.context.TJsPureContext;

implementation

end.
