unit nextpas.core.mem.allocator.base;
{**
 * @desc Allocator 类型定义。
 *
 * @note TAllocator 基类已移除，所有 allocator 直接实现 IAllocator 接口。
 *       本单元保留类型别名以兼容现有引用。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.intf
  ;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TMemAllocator = nextpas.core.mem.intf.IAllocator;

implementation

end.
