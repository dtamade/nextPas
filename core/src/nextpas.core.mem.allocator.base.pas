unit nextpas.core.mem.allocator.base;
{**
 * @desc Allocator 类型 re-export 单元 + 接口面 sized 辅助函数。
 *
 * @note 本单元仅依赖 nextpas.core.mem.intf 与 nextpas.core.system.heap
 *       （无 arena/pool graph，无 FPC RTL 直连），供 text.builder 等
 *       stage0 安全消费者使用（CA-016，
 *       core/docs/plans/2026-08-10-text-builder-inject-grow-owner-decision.md）。
 *       历史 uses 路径兼容 re-export；规范类型定义见 nextpas.core.mem.intf。
 *
 *       sized helper 与 mem 门面 ReallocMemOf 语义分层：
 *       - 门面版（nextpas.core.mem）：AAllocator=nil/DefaultAllocator 时走
 *         DefaultHeap sized 路径（arena/pool graph，stage0 不可用）。
 *       - 本单元接口面版：AAllocator<>nil 委托 IAllocator 方法（size 由
 *         分配器内部跟踪）；nil 走 nextpas.core.system.heap 封装
 *         （RTL 堆自跟踪，经 mem RTL 隔离门禁）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf
  ;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TMemAllocator = nextpas.core.mem.intf.IAllocator;

{** 接口面 sized realloc（stage0 安全，无 mem 门面 graph 依赖）。
    AAllocator<>nil 时委托 IAllocator 方法；nil 时用 nextpas.core.system.heap
    封装（NpSystemReallocMem 返回移动后的新指针）。
    AOldSize 为契约标注（文档化旧尺寸），非运行输入——分配器/RTL 各自
    内部跟踪 size。与门面 ReallocMemOf 的差异：不触碰 DefaultHeap /
    arena / pool graph。 }
function ReallocMemSized(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer; inline;

{** 接口面 sized free 配对（stage0 安全）。allocator<>nil 委托接口方法；
    nil 走 nextpas.core.system.heap 封装。 }
procedure FreeMemSized(const AAllocator: IAllocator; APtr: Pointer); inline;

implementation

uses
  nextpas.core.system.heap;

function ReallocMemSized(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer; inline;
{$WARN 5024 OFF} // AOldSize: documented contract annotation, not a runtime input
begin
  if APtr = nil then
  begin
    if AAllocator <> nil then
      Exit(AAllocator.GetMem(ANewSize));
    Exit(NpSystemGetMem(ANewSize));
  end;
  if AAllocator <> nil then
    Exit(AAllocator.ReallocMem(APtr, ANewSize));
  Result := NpSystemReallocMem(APtr, ANewSize);
end;

procedure FreeMemSized(const AAllocator: IAllocator; APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  if AAllocator <> nil then
    AAllocator.FreeMem(APtr)
  else
    NpSystemFreeMem(APtr);
end;

end.
