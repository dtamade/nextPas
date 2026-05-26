{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.adapter - 分配器接口适配器
## Abstract 摘要

Adapter classes to bridge IAllocator (v1.x) and IAlloc (v2.0) interfaces.
适配器类，用于桥接 IAllocator (v1.x) 和 IAlloc (v2.0) 接口。

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.adapter;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.alloc,
  nextpas.core.mem.layout,
  nextpas.core.mem.error,
  fgl;

type
  {**
   * TAllocatorToAllocAdapter
   *
   * @desc 将 IAllocator (v1.x) 适配为 IAlloc (v2.0) 接口
   *       Adapts IAllocator (v1.x) to IAlloc (v2.0) interface
   *
   * @purpose
   *   - 让旧的 IAllocator 实现可以被新的 IAlloc 代码使用
   *   - 渐进式迁移：无需一次性重写所有分配器
   *
   * @example
   *   var OldAlloc: IAllocator := GetRtlAllocator;
   *   var NewAlloc: IAlloc := TAllocatorToAllocAdapter.Create(OldAlloc);
   *   // 现在可以在需要 IAlloc 的地方使用 NewAlloc
   *}
  TAllocatorToAllocAdapter = class(TInterfacedObject, IAlloc)
  private
    FAllocator: IAllocator;
    FCaps: TAllocCaps;
  public
    {**
     * Create
     *
     * @desc 创建适配器
     *
     * @params
     *   aAllocator: IAllocator 要适配的 v1.x 分配器
     *}
    constructor Create(aAllocator: IAllocator);

    { IAlloc implementation }
    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    procedure Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
    function Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
    function Caps: TAllocCaps;

    {** 获取底层 IAllocator | Get underlying IAllocator *}
    property Allocator: IAllocator read FAllocator;
  end;

  {**
   * TAllocToAllocatorAdapter
   *
   * @desc 将 IAlloc (v2.0) 适配为 IAllocator (v1.x) 接口
   *       Adapts IAlloc (v2.0) to IAllocator (v1.x) interface
   *
   * @purpose
   *   - 让新的 IAlloc 实现可以被旧的 IAllocator 代码使用
   *   - 渐进式迁移：新分配器可以用于旧代码
   *
   * @example
   *   var NewAlloc: IAlloc := GetSystemAlloc;
   *   var OldAlloc: IAllocator := TAllocToAllocatorAdapter.Create(NewAlloc);
   *   // 现在可以在需要 IAllocator 的地方使用 OldAlloc
   *
   * @note
   *   IAlloc.Dealloc 需要布局信息，但 IAllocator.FreeMem 不提供。
   *   适配器使用默认对齐和零大小（大多数分配器忽略这些参数）。
   *}
  TAllocToAllocatorAdapter = class(TAllocator, IAllocator)
  private
    FAlloc: IAlloc;
    FTraits: TAllocatorTraits;
    FSizeMap: specialize TFPGMap<Pointer, SizeUInt>;
    procedure TrackSize(aPtr: Pointer; aSize: SizeUInt);
    procedure UntrackSize(aPtr: Pointer);
    function LookupSize(aPtr: Pointer): SizeUInt;
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    {**
     * Create
     *
     * @desc 创建适配器
     *
     * @params
     *   aAlloc: IAlloc 要适配的 v2.0 分配器
     *}
    constructor Create(aAlloc: IAlloc);

    { IAllocator overrides }
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits; override;

    {** 获取底层 IAlloc | Get underlying IAlloc *}
    property Alloc: IAlloc read FAlloc;
  end;

{**
 * WrapAsAlloc
 *
 * @desc 便捷函数：将 IAllocator 包装为 IAlloc
 *       Convenience function: wrap IAllocator as IAlloc
 *}
function WrapAsAlloc(aAllocator: IAllocator): IAlloc;

{**
 * WrapAsAllocator
 *
 * @desc 便捷函数：将 IAlloc 包装为 IAllocator
 *       Convenience function: wrap IAlloc as IAllocator
 *}
function WrapAsAllocator(aAlloc: IAlloc): IAllocator;

{**
 * TraitsToAllocCaps
 *
 * @desc 转换 TAllocatorTraits 到 TAllocCaps
 *       Convert TAllocatorTraits to TAllocCaps
 *}
function TraitsToAllocCaps(const aTraits: TAllocatorTraits): TAllocCaps;

{**
 * AllocCapsToTraits
 *
 * @desc 转换 TAllocCaps 到 TAllocatorTraits
 *       Convert TAllocCaps to TAllocatorTraits
 *}
function AllocCapsToTraits(const aCaps: TAllocCaps): TAllocatorTraits;

implementation

{ Helper functions }

function TraitsToAllocCaps(const aTraits: TAllocatorTraits): TAllocCaps;
begin
  Result.ZeroOnAlloc := aTraits.ZeroInitialized;
  Result.ThreadSafe := aTraits.ThreadSafe;
  Result.KnowsSize := aTraits.HasMemSize;
  Result.NativeAligned := aTraits.SupportsAligned;
  Result.CanRealloc := True;
  if aTraits.SupportsAligned then
    Result.MaxAlign := MEM_PAGE_SIZE
  else
    Result.MaxAlign := MEM_DEFAULT_ALIGN;
end;

function AllocCapsToTraits(const aCaps: TAllocCaps): TAllocatorTraits;
begin
  Result.ZeroInitialized := aCaps.ZeroOnAlloc;
  Result.ThreadSafe := aCaps.ThreadSafe;
  Result.HasMemSize := aCaps.KnowsSize;
  Result.SupportsAligned := aCaps.NativeAligned;
end;

function WrapAsAlloc(aAllocator: IAllocator): IAlloc;
begin
  Result := TAllocatorToAllocAdapter.Create(aAllocator);
end;

function WrapAsAllocator(aAlloc: IAlloc): IAllocator;
begin
  Result := TAllocToAllocatorAdapter.Create(aAlloc);
end;
procedure TAllocToAllocatorAdapter.TrackSize(aPtr: Pointer; aSize: SizeUInt);
var
  LIndex: SizeInt;
begin
  if aPtr = nil then Exit;
  if FSizeMap = nil then
    FSizeMap := specialize TFPGMap<Pointer, SizeUInt>.Create;
  LIndex := FSizeMap.IndexOf(aPtr);
  if LIndex < 0 then
    FSizeMap.Add(aPtr, aSize)
  else
    FSizeMap.Data[LIndex] := aSize;
end;

procedure TAllocToAllocatorAdapter.UntrackSize(aPtr: Pointer);
var
  LIndex: SizeInt;
begin
  if (FSizeMap = nil) or (aPtr = nil) then Exit;
  LIndex := FSizeMap.IndexOf(aPtr);
  if LIndex >= 0 then
    FSizeMap.Delete(LIndex);
end;

function TAllocToAllocatorAdapter.LookupSize(aPtr: Pointer): SizeUInt;
var
  LIndex: SizeInt;
begin
  if (FSizeMap = nil) or (aPtr = nil) then
    Exit(0);
  LIndex := FSizeMap.IndexOf(aPtr);
  if LIndex >= 0 then
    Result := FSizeMap.Data[LIndex]
  else
    Result := 0;
end;

{ TAllocatorToAllocAdapter }

constructor TAllocatorToAllocAdapter.Create(aAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := aAllocator;
  FCaps := TraitsToAllocCaps(aAllocator.Traits);
end;

function TAllocatorToAllocAdapter.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  if not aLayout.IsValid then
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  if aLayout.IsZeroSized then
  begin
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  // 需要对齐分配？
  if aLayout.Align > MEM_DEFAULT_ALIGN then
  begin
    LPtr := FAllocator.AllocAligned(aLayout.Size, aLayout.Align);
  end
  else
  begin
    LPtr := FAllocator.GetMem(aLayout.Size);
  end;

  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TAllocatorToAllocAdapter.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  if not aLayout.IsValid then
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  if aLayout.IsZeroSized then
  begin
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  // 需要对齐分配？
  if aLayout.Align > MEM_DEFAULT_ALIGN then
  begin
    LPtr := FAllocator.AllocAligned(aLayout.Size, aLayout.Align);
    if LPtr <> nil then
      FillChar(LPtr^, aLayout.Size, 0);
  end
  else
  begin
    LPtr := FAllocator.AllocMem(aLayout.Size);
  end;

  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

procedure TAllocatorToAllocAdapter.Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
begin
  if aPtr = nil then
    Exit;

  if aLayout.Align > MEM_DEFAULT_ALIGN then
    FAllocator.FreeAligned(aPtr)
  else
    FAllocator.FreeMem(aPtr);
end;

function TAllocatorToAllocAdapter.Realloc(aPtr: Pointer;
  const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
  LCopySize: SizeUInt;
begin
  // nil → Alloc
  if aPtr = nil then
  begin
    Result := Alloc(aNewLayout);
    Exit;
  end;

  // Zero size → Dealloc
  if aNewLayout.IsZeroSized then
  begin
    Dealloc(aPtr, aOldLayout);
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  if not aNewLayout.IsValid then
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  // 对齐相同且不超过默认对齐 → 直接 ReallocMem
  if (aOldLayout.Align <= MEM_DEFAULT_ALIGN) and (aNewLayout.Align <= MEM_DEFAULT_ALIGN) then
  begin
    LPtr := FAllocator.ReallocMem(aPtr, aNewLayout.Size);
    if LPtr = nil then
      Result := TAllocResult.Err(aeOutOfMemory)
    else
      Result := TAllocResult.Ok(LPtr);
    Exit;
  end;

  // 对齐分配：需要手动 Alloc + Copy + Free
  Result := Alloc(aNewLayout);
  if Result.IsErr then
    Exit;

  // 复制数据
  if aOldLayout.Size < aNewLayout.Size then
    LCopySize := aOldLayout.Size
  else
    LCopySize := aNewLayout.Size;

  if LCopySize > 0 then
    Move(aPtr^, Result.Ptr^, LCopySize);

  // 释放旧内存
  Dealloc(aPtr, aOldLayout);
end;

function TAllocatorToAllocAdapter.Caps: TAllocCaps;
begin
  Result := FCaps;
end;

{ TAllocToAllocatorAdapter }

constructor TAllocToAllocatorAdapter.Create(aAlloc: IAlloc);
begin
  inherited Create;
  FAlloc := aAlloc;
  FTraits := AllocCapsToTraits(aAlloc.Caps);
end;

function TAllocToAllocatorAdapter.DoGetMem(aSize: SizeUInt): Pointer;
var
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LLayout := TMemLayout.Create(aSize, MEM_DEFAULT_ALIGN);
  LResult := FAlloc.Alloc(LLayout);
  Result := LResult.Unwrap;
  if Result <> nil then
    TrackSize(Result, aSize);
end;

function TAllocToAllocatorAdapter.DoAllocMem(aSize: SizeUInt): Pointer;
var
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LLayout := TMemLayout.Create(aSize, MEM_DEFAULT_ALIGN);
  LResult := FAlloc.AllocZeroed(LLayout);
  Result := LResult.Unwrap;
  if Result <> nil then
    TrackSize(Result, aSize);
end;

function TAllocToAllocatorAdapter.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LOldLayout, LNewLayout: TMemLayout;
  LResult: TAllocResult;
  LOldSize: SizeUInt;
begin
  LOldSize := LookupSize(aDst);
  LOldLayout := TMemLayout.Create(LOldSize, MEM_DEFAULT_ALIGN);
  LNewLayout := TMemLayout.Create(aSize, MEM_DEFAULT_ALIGN);
  LResult := FAlloc.Realloc(aDst, LOldLayout, LNewLayout);
  Result := LResult.Unwrap;
  if Result <> nil then
  begin
    if Result <> aDst then
      UntrackSize(aDst);
    TrackSize(Result, aSize);
  end;
end;

procedure TAllocToAllocatorAdapter.DoFreeMem(aDst: Pointer);
var
  LLayout: TMemLayout;
begin
  LLayout := TMemLayout.Create(LookupSize(aDst), MEM_DEFAULT_ALIGN);
  UntrackSize(aDst);
  FAlloc.Dealloc(aDst, LLayout);
end;

function TAllocToAllocatorAdapter.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LLayout := TMemLayout.Create(aSize, aAlignment);
  LResult := FAlloc.Alloc(LLayout);
  Result := LResult.Unwrap;
  if Result <> nil then
    TrackSize(Result, aSize);
end;

procedure TAllocToAllocatorAdapter.FreeAligned(aPtr: Pointer);
var
  LLayout: TMemLayout;
begin
  LLayout := TMemLayout.Create(LookupSize(aPtr), MEM_DEFAULT_ALIGN);
  UntrackSize(aPtr);
  FAlloc.Dealloc(aPtr, LLayout);
end;

function TAllocToAllocatorAdapter.Traits: TAllocatorTraits;
begin
  Result := FTraits;
end;

end.
