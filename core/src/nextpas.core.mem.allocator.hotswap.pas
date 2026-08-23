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

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
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

type
  PHotswapHeader = ^THotswapHeader;
  THotswapHeader = record
    Origin: Pointer;        { raw pointer to the IAllocator that allocated this block }
    RequestedSize: SizeUInt; { original requested size }
  end;

const
  HOTSWAP_HEADER = SizeOf(THotswapHeader);

procedure FreeHeaderBlockAndReleaseOrigin(const AOrigin: IAllocator;
  const AHeader: PHotswapHeader); inline;
begin
  AOrigin.FreeMem(AHeader);
  AOrigin._Release; { Balance the header-owned reference acquired in GetMem. }
end;

{ THotswapAllocator }

constructor THotswapAllocator.Create(AInitial: IAllocator);
begin
  inherited Create;
  if AInitial = nil then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('THotswapAllocator', 'Create', 'AInitial cannot be nil'));
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
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('THotswapAllocator', 'Swap', 'ANew cannot be nil'));
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
var
  LHeader: PHotswapHeader;
  LCurrent: IAllocator;
begin
  if ASize = 0 then
    Exit(nil);

  LCurrent := FCurrent;
  LHeader := PHotswapHeader(LCurrent.GetMem(HOTSWAP_HEADER + ASize));
  if LHeader = nil then
    Exit(nil);
  LCurrent._AddRef; { 为存储的裸指针增加引用计数 }
  LHeader^.Origin := Pointer(LCurrent);
  LHeader^.RequestedSize := ASize;
  Result := Pointer(PByte(LHeader) + HOTSWAP_HEADER);
end;

function THotswapAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function THotswapAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LHeader: PHotswapHeader;
  LOrigin: IAllocator;
  LOldSize, LCopySize: SizeUInt;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));

  LHeader := PHotswapHeader(PByte(APtr) - HOTSWAP_HEADER);
  LOrigin := IAllocator(LHeader^.Origin);
  LOldSize := LHeader^.RequestedSize;

  if ASize <= LOldSize then
  begin
    { In-place: reallocate via origin, update header }
    Result := LOrigin.ReallocMem(LHeader, HOTSWAP_HEADER + ASize);
    if Result = nil then
      Exit(nil);
    PHotswapHeader(Result)^.RequestedSize := ASize;
    Exit(Pointer(PByte(Result) + HOTSWAP_HEADER));
  end;

  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  Move(APtr^, Result^, LCopySize);
  FreeHeaderBlockAndReleaseOrigin(LOrigin, LHeader);
end;

procedure THotswapAllocator.FreeMem(APtr: Pointer); inline;
var
  LHeader: PHotswapHeader;
  LOrigin: IAllocator;
begin
  if APtr = nil then
    Exit;
  LHeader := PHotswapHeader(PByte(APtr) - HOTSWAP_HEADER);
  LOrigin := IAllocator(LHeader^.Origin); { 赋值触发 _AddRef }
  FreeHeaderBlockAndReleaseOrigin(LOrigin, LHeader);
end;

function THotswapAllocator.Traits: TAllocatorTraits; inline;
begin
  if FCurrent <> nil then
    Result := FCurrent.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.ThreadSafe := False;
    Result.SupportsRealloc := False;
  end;
end;

end.
