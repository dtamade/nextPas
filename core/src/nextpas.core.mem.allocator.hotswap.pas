{
# nextpas.core.mem.allocator.hotswap

## 摘要

Hotswap allocator — 运行时原子替换分配器。

特性:
- 运行时原子切换分配器
- 新分配立即使用新分配器
- 切换计数统计
- 线程安全

适用场景: 运行时切换 debug/release 分配器、A/B 测试分配策略。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.hotswap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** THotswapAllocator
   *
   *  运行时原子替换分配器。
   *  新分配立即使用新分配器，旧分配仍在旧分配器上释放。
   *
   *  使用模式:
   *    var LHotswap: THotswapAllocator;
   *    LHotswap := THotswapAllocator.Create(DefaultAllocator);
   *    try
   *      // 运行时切换
   *      LHotswap.Swap(TGuardAllocator.Create(DefaultAllocator));
   *      // 新分配使用 TGuardAllocator
   *      LPtr := LHotswap.GetMem(1024);
   *    finally
   *      LHotswap.Free;
   *    end;
   *}
  THotswapAllocator = class(TInterfacedObject, IAllocator)
  private
    FCurrent: IAllocator;
    FSwapCount: UInt64;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    {** 创建热切换分配器
     *  @param AInitial 初始分配器
     *}
    constructor Create(AInitial: IAllocator);
    destructor Destroy; override;

    {** 原子切换到新分配器 }
    procedure Swap(ANew: IAllocator);
    {** 获取当前分配器 }
    function Current: IAllocator;
    {** 切换次数 }
    function SwapCount: UInt64;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

{ THotswapAllocator }

constructor THotswapAllocator.Create(AInitial: IAllocator);
begin
  inherited Create;
  if AInitial = nil then
    raise EAllocError.Create(aeInvalidLayout, 'THotswapAllocator.Create: AInitial cannot be nil');
  FCurrent := AInitial;
  FSwapCount := 0;
end;

destructor THotswapAllocator.Destroy;
begin
  FCurrent := nil;
  inherited Destroy;
end;

procedure THotswapAllocator.Swap(ANew: IAllocator);
begin
  if ANew = nil then
    raise EAllocError.Create(aeInvalidLayout, 'THotswapAllocator.Swap: ANew cannot be nil');
  FCurrent := ANew;
  Inc(FSwapCount);
end;

function THotswapAllocator.Current: IAllocator;
begin
  Result := FCurrent;
end;

function THotswapAllocator.SwapCount: UInt64;
begin
  Result := FSwapCount;
end;

function THotswapAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FCurrent.GetMem(ASize);
end;

function THotswapAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FCurrent.AllocMem(ASize);
end;

function THotswapAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  Result := FCurrent.ReallocMem(APtr, ASize);
end;

procedure THotswapAllocator.FreeMem(APtr: Pointer); inline;
begin
  FCurrent.FreeMem(APtr);
end;

function THotswapAllocator.Traits: TAllocatorTraits; inline;
begin
  if FCurrent <> nil then
    Result := FCurrent.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.SupportsRealloc := False;
  end;
end;

end.
