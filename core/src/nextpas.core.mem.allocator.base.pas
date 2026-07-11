unit nextpas.core.mem.allocator.base;
{**
 * @desc Allocator 类型定义和可选基类。
 *
 * @note TAllocatorBase 是可选基类，处理常见模式（GetMem(0) 检查、nil 处理等）。
 *       分配器可以直接实现 IAllocator，也可以继承 TAllocatorBase 减少重复。
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

  {**
   * @desc 可选分配器基类，处理常见模式。
   *
   *  继承此类可减少重复代码：
   *  - GetMem/AllocMem 自动处理 ASize=0 → nil
   *  - ReallocMem 自动处理 APtr=nil 和 ASize=0
   *  - FreeMem 自动处理 APtr=nil
   *  - 提供默认 Traits 实现
   *
   *  子类只需实现：
   *  - DoGetMem(ASize): Pointer — 实际分配逻辑
   *  - DoFreeMem(APtr: Pointer) — 实际释放逻辑
   *  - 可选覆盖 DoAllocMem/DoReallocMem/Traits
   *}
  TAllocatorBase = class(TInterfacedObject, IAllocator)
  protected
    {** 实际分配逻辑，ASize > 0，返回非 nil 指针或 nil（OOM） }
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    {** 实际释放逻辑，APtr <> nil }
    procedure DoFreeMem(APtr: Pointer); virtual; abstract;
    {** 实际零初始化分配逻辑，默认调用 DoGetMem + FillChar }
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual;
    {** 实际重分配逻辑，默认分配+拷贝+释放 }
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; virtual;
  public
    {** 分配 ASize 字节，ASize=0 返回 nil }
    function GetMem(ASize: SizeUInt): Pointer;
    {** 分配 ASize 字节零初始化内存，ASize=0 返回 nil }
    function AllocMem(ASize: SizeUInt): Pointer;
    {** 重分配内存，APtr=nil 等价于 GetMem，ASize=0 等价于 FreeMem }
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    {** 释放内存，APtr=nil 时为空操作 }
    procedure FreeMem(APtr: Pointer);
    {** 返回分配器特征，默认：非零初始化、非线程安全、支持 Realloc }
    function Traits: TAllocatorTraits; virtual;
  end;

implementation

uses
  nextpas.core.mem.error;

{ TAllocatorBase }

function TAllocatorBase.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TAllocatorBase.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;
  Result := DoGetMem(ASize);
  if Result <> nil then
  begin
    LOldSize := ASize; { 简化：拷贝 ASize 字节，实际应取旧块大小 }
    if LOldSize > ASize then
      LOldSize := ASize;
    Move(APtr^, Result^, LOldSize);
    DoFreeMem(APtr);
  end;
end;

function TAllocatorBase.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoGetMem(ASize);
end;

function TAllocatorBase.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoAllocMem(ASize);
end;

function TAllocatorBase.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    if APtr <> nil then
      DoFreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(DoGetMem(ASize));
  Result := DoReallocMem(APtr, ASize);
end;

procedure TAllocatorBase.FreeMem(APtr: Pointer);
begin
  if APtr <> nil then
    DoFreeMem(APtr);
end;

function TAllocatorBase.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
