unit nextpas.core.js.pure.impl;
{**
 * @desc 兼容薄别名（已收敛至标准四件套门面 nextpas.core.js.pure，Runtime→pure.runtime + Context→pure.context 单源）。
 *       标准机械形态为 base←runtime/context←门面(pure.pas)；本单元仅为存量 uses 兼容而保留的纯 re-export 薄别名，
 *       无逻辑，零 FFI/零 platform.dl（L0 platform.thread/fs 直读经 context 单源），
 *       薄转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view/pure.host/pure.value/js.eval/js.lifecycle 单源）。
 *       资源释放幂等链：Close → JsPureContextClose + HostStateClear + ValueStateClear（via context 单源），try-finally 不丢。
 *       守 L0-L3 与四件套 base←runtime/context←门面，Host/Value 经 pure.host/pure.value 单源 per-Context 隔离 O(1) 桶，wc -l ~40 <800。
 *       新代码应直接 uses nextpas.core.js.pure；原单文件 ~360 行已拆为 pure.runtime ~45 + pure.context ~360。
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
