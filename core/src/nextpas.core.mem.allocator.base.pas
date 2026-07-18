unit nextpas.core.mem.allocator.base;
{**
 * @desc Allocator 类型 re-export 单元。
 *
 * @note 本单元仅从 nextpas.core.mem.intf 重导出分配器契约类型，
 *       供历史 uses 路径保持兼容。规范定义见 nextpas.core.mem.intf。
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

implementation

end.
