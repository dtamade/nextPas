{
# nextpas.core.mem.arena.types - Arena 接口定义

## 摘要

Arena 分配器接口定义，从 blockpool 模块拆出，使 arena 子系统自包含。

## 设计

- IArena: 线性分配器接口（bump allocator）
- TArenaMarker: 保存/恢复标记类型
- 零实现依赖，纯接口定义

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.arena.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

const
  {** IArena 接口 GUID *}
  GUID_IARENA = '{C905F1B3-4D6E-5A0C-BF78-8E9D0C102345}';

type
  {**
   * IArena
   *
   * @desc 线性分配器接口
   *       Arena/bump allocator interface
   *
   *  设计目标：
   *  - 分配只前进，释放一次性（Reset 或 RestoreToMark）
   *  - O(1) 分配，零碎片
   *  - 适用于编译器、解析器、请求处理等有限生命周期场景
   *}
  IArena = interface
    [GUID_IARENA]
    {** 分配 ASize 字节，返回指针；失败返回 nil }
    function Alloc(aSize: SizeUInt): Pointer;
    {** 分配 ASize 字节，按 AAlignment 对齐；对齐必须是 2 的幂 }
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    {** 分配 ASize 字节并清零；失败返回 nil }
    function AllocZeroed(aSize: SizeUInt): Pointer;
    {** 保存当前分配位置标记 }
    function SaveMark: TArenaMarker;
    {** 恢复到标记位置 }
    procedure RestoreToMark(aMark: TArenaMarker);
    {** 重置 Arena，所有已分配内存可重新使用 }
    procedure Reset;
    {** 返回后备内存总字节数 }
    function TotalSize: SizeUInt;
    {** 返回已分配字节数 }
    function UsedSize: SizeUInt;
    {** 返回剩余可用字节数 }
    function RemainingSize: SizeUInt;
  end;

implementation

end.
