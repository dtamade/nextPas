unit nextpas.core.mem.interfaces;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator;

// DEPRECATED: 本单元是历史兼容残留。
// IAllocator 的 canonical 定义在 nextpas.core.mem.intf。
// 新代码请直接使用 nextpas.core.mem.intf 或 nextpas.core.mem.allocator。
//
// v1 接口 (IMemPool/IStackPool/ISlabPool) 已不再有活跃消费者，
// 标记为 deprecated 以便下游迁移。

type
  IAllocator = nextpas.core.mem.allocator.IAllocator
    deprecated 'Use nextpas.core.mem.intf.IAllocator directly';

  // 固定块内存池接口 — v1 compat, 已废弃
  IMemPool = interface
    ['{B03C5A4C-89D9-462E-8F01-3A4C3E1B7F0B}']
    function Alloc: Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;
  end;

  // 栈式内存池接口 — v1 compat, 已废弃
  IStackPool = interface
    ['{9B1F8A19-3A7E-4F89-9D09-CA3CF57C52B8}']
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Reset;
    procedure RestoreState(AOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;
  end;

  // Slab 内存池接口 — v1 compat, 已废弃
  ISlabPool = interface
    ['{5C82C90D-7E8D-46C7-8B4E-4E8F3E7E8D1F}']
    function Alloc(ASize: SizeUInt): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
  end;

implementation

end.
