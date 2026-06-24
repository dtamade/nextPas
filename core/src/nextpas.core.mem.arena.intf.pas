unit nextpas.core.mem.arena.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.arena.base;

const
  GUID_IARENA: TGUID = '{8B7F3B2A-1D4E-4A5C-9F6D-2E8C7A1B3D5E}';

type
  {** IArena - Arena 分配器接口
   *
   *  线性分配器接口，分配只前进，Reset 一次性释放全部。
   *  适用于请求/帧/文档等有限生命周期的场景。
   *
   *  非线程安全。需要并发访问时，调用方使用 sync 模块原语保护。
   *}
  IArena = interface
    ['{8B7F3B2A-1D4E-4A5C-9F6D-2E8C7A1B3D5E}']

    {** 从 Arena 分配 ASize 字节，返回指针；空间不足返回 nil }
    function Alloc(ASize: SizeUInt): Pointer;
    {** 从 Arena 对齐分配 ASize 字节；对齐不是 2 的幂或空间不足返回 nil }
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    {** 从 Arena 分配 ASize 字节并清零；空间不足返回 nil }
    function AllocZeroed(ASize: SizeUInt): Pointer;

    {** 保存当前分配位置的标记，后续可用 RestoreToMark 回退 }
    function SaveMark: TArenaMark;
    {** 恢复到之前保存的标记位置 }
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena，所有已分配内存可重新使用 }
    procedure Reset;

    {** 返回已分配字节数 }
    function UsedSize: SizeUInt;
    {** 返回剩余可用字节数 }
    function RemainingSize: SizeUInt;
    {** 返回统计信息 }
    function Stats: TArenaStats;
  end;

implementation

end.
