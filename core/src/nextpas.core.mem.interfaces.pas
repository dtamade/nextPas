unit nextpas.core.mem.interfaces;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, nextpas.core.mem.allocator;

// 说明：本单元仅声明接口类型（P2 预研）。
// 不改变现有类用法；实现仍由现有类（TMemPool/TStackPool）提供。
// ISlabPool 接口保留，实现可使用 nextpas.core.mem.pool.slab 或 nextpas.core.mem.mimalloc。
//
// 注意：IAllocator 已从此单元移除，使用 nextpas.core.mem.allocator 中的定义。
// Note: IAllocator has been removed from this unit. Use the one from nextpas.core.mem.allocator.

// 基础分配器接口重导出（避免 GUID 冲突）
type
  IAllocator = nextpas.core.mem.allocator.IAllocator;

  // 固定块内存池接口
  IMemPool = interface
    ['{B03C5A4C-89D9-462E-8F01-3A4C3E1B7F0B}']
    function Alloc: Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean; // ASize ignored or must be <= BlockSize
    procedure Free(APtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;
  end;

  // 栈式内存池接口
  IStackPool = interface
    ['{9B1F8A19-3A7E-4F89-9D09-CA3CF57C52B8}']
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean; // default alignment = pointer size
    procedure Reset;
    procedure RestoreState(AOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;
  end;

  // Slab 内存池接口
  ISlabPool = interface
    ['{5C82C90D-7E8D-46C7-8B4E-4E8F3E7E8D1F}']
    function Alloc(ASize: SizeUInt): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
  end;

implementation

end.
