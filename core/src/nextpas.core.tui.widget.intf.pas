unit nextpas.core.tui.widget.intf;

{**
 * @desc Widget 渲染契约基础接口。
 *
 * IWidget 是所有 widget 的统一渲染契约：把当前帧的 UI 描述写入 buffer。
 * widget 不持有 buffer、不保留终端状态、不缓存渲染结果（immediate mode）。
 *
 * 具体 widget（TBlock/TParagraph/TList...）以 class(TInterfacedObject, IXxx)
 * 实现，其专属接口（IBlock/IList...）继承 IWidget 并在各自单元声明。被其他
 * widget 作为组件引用的 widget（如 Block 被 List 作外框）通过其接口被引用，
 * 保证接口层只依赖接口、不依赖具体实现类。
 *
 * 有状态 widget 的 RenderStateful（带 var AState）声明在各自 widget 的
 * 专属接口上——state record 类型各异，无法统一到泛型接口（FPC 限制）。
 *
 * @note 渲染分发走 COM 引用计数接口（vtable）。每帧 widget 数量有限
 *       （数十个），分发开销可忽略；热路径在 widget 内部的 buffer 操作，
 *       是直接的 PCell 指针写入，零额外开销。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer;

type
  {**
   * @desc 无状态 widget 渲染契约。
   * @params
   *   AArea    渲染目标矩形区域
   *   ABuffer  目标缓冲区（class 引用语义，写入直达）
   *}
  IWidget = interface
    ['{B7D3F1A0-9C42-4E18-8A6B-1F2E3D4C5A6B}']
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

end.
