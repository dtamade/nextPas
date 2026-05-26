{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.alloc - Rust 风格分配器接口
## Abstract 摘要

Rust-style allocator interface (similar to GlobalAlloc trait).
Rust 风格的分配器接口，类似于 GlobalAlloc trait。

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.alloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

const
  {** IAlloc 接口 GUID *}
  GUID_IALLOC = '{A7E3D9F1-2B4C-4E8A-9D5F-6C7B8A9E0F12}';

type
  {**
   * IAlloc
   *
   * @desc Rust 风格的核心分配器接口
   *       Core allocator interface, similar to Rust's GlobalAlloc trait
   *
   * @design
   *   - 基于 Layout 的 API（而非分离的 size/align 参数）
   *   - 返回 Result 类型用于错误处理
   *   - 零成本抽象：所有热路径方法都应 inline
   *   - 能力自省：Caps 返回分配器能力
   *
   * @thread-safety
   *   取决于实现，通过 Caps.ThreadSafe 查询
   *
   * @example
   *   var Alloc: IAlloc := TSystemAlloc.Create;
   *   var Layout := TMemLayout.Create(1024, 16);
   *   var Result := Alloc.Alloc(Layout);
   *   if Result.IsOk then
   *   begin
   *     // 使用 Result.Ptr
   *     Alloc.Dealloc(Result.Ptr, Layout);
   *   end;
   *}
  IAlloc = interface
    [GUID_IALLOC]

    {**
     * Alloc
     *
     * @desc 分配内存
     *       Allocate memory
     *
     * @params
     *   aLayout: TMemLayout 内存布局（大小和对齐）
     *
     * @return TAllocResult 分配结果
     *
     * @note 性能关键：实现应尽可能 inline
     * @note 内存内容未定义（除非 Caps.ZeroOnAlloc = True）
     *}
    function Alloc(const aLayout: TMemLayout): TAllocResult;

    {**
     * AllocZeroed
     *
     * @desc 分配并清零内存
     *       Allocate and zero-fill memory
     *
     * @params
     *   aLayout: TMemLayout 内存布局
     *
     * @return TAllocResult 分配结果
     *
     * @note 如果 Caps.ZeroOnAlloc = True，等同于 Alloc
     *}
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;

    {**
     * Dealloc
     *
     * @desc 释放内存
     *       Deallocate memory
     *
     * @params
     *   aPtr: Pointer 要释放的指针
     *   aLayout: TMemLayout 原始分配时的布局
     *
     * @note aPtr = nil 时安全（无操作）
     * @note aLayout 必须与分配时相同
     *}
    procedure Dealloc(aPtr: Pointer; const aLayout: TMemLayout);

    {**
     * Realloc
     *
     * @desc 重新分配内存
     *       Reallocate memory
     *
     * @params
     *   aPtr: Pointer 原指针
     *   aOldLayout: TMemLayout 原布局
     *   aNewLayout: TMemLayout 新布局
     *
     * @return TAllocResult 新分配结果
     *
     * @note 如果 aPtr = nil，等同于 Alloc(aNewLayout)
     * @note 如果 aNewLayout.Size = 0，等同于 Dealloc + 返回空指针
     * @note 数据会保留（复制 min(old.Size, new.Size) 字节）
     *}
    function Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;

    {**
     * Caps
     *
     * @desc 获取分配器能力
     *       Get allocator capabilities
     *
     * @return TAllocCaps 能力描述
     *}
    function Caps: TAllocCaps;
  end;

  {**
   * TAllocBase
   *
   * @desc IAlloc 的抽象基类
   *       Abstract base class for IAlloc implementations
   *
   * @note 提供默认实现：
   *   - AllocZeroed: 调用 Alloc 后清零
   *   - Realloc: 默认实现（Alloc + Copy + Dealloc）
   *}
  TAllocBase = class(TInterfacedObject, IAlloc)
  protected
    FCaps: TAllocCaps;

    {** 子类必须实现的核心分配方法 *}
    function DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer; virtual; abstract;

    {** 子类必须实现的核心释放方法 *}
    procedure DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt); virtual; abstract;

    {** 可选：子类可以覆盖以提供优化的 Realloc *}
    function DoRealloc(aPtr: Pointer; aOldSize, aNewSize, aAlign: SizeUInt): Pointer; virtual;

  public
    constructor Create(const aCaps: TAllocCaps); virtual;

    { IAlloc }
    function Alloc(const aLayout: TMemLayout): TAllocResult; virtual;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult; virtual;
    procedure Dealloc(aPtr: Pointer; const aLayout: TMemLayout); virtual;
    function Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult; virtual;
    function Caps: TAllocCaps; virtual;
  end;

  {**
   * TSystemAlloc
   *
   * @desc 系统堆分配器
   *       System heap allocator (uses GetMem/FreeMem)
   *
   * @thread-safety 线程安全（依赖系统堆实现）
   *
   * @note 这是默认分配器，适用于一般用途
   *}
  TSystemAlloc = class(TAllocBase)
  protected
    function DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer; override;
    procedure DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt); override;
    function DoRealloc(aPtr: Pointer; aOldSize, aNewSize, aAlign: SizeUInt): Pointer; override;
  public
    constructor Create; reintroduce;
  end;

  {**
   * TAlignedAlloc
   *
   * @desc 对齐分配器
   *       Allocator with native aligned allocation support
   *
   * @note 使用额外空间存储原始指针以支持任意对齐
   *}
  TAlignedAlloc = class(TAllocBase)
  protected
    function DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer; override;
    procedure DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt); override;
  public
    constructor Create; reintroduce;
  end;

{**
 * GetSystemAlloc
 *
 * @desc 获取全局系统分配器单例
 *       Get global system allocator singleton
 *
 * @return IAlloc 系统分配器
 *
 * @thread-safety 线程安全
 *}
function GetSystemAlloc: IAlloc;

{**
 * GetAlignedAlloc
 *
 * @desc 获取全局对齐分配器单例
 *       Get global aligned allocator singleton
 *
 * @return IAlloc 对齐分配器
 *
 * @thread-safety 线程安全
 *}
function GetAlignedAlloc: IAlloc;

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned allocation

var
  GSystemAlloc: IAlloc = nil;
  GAlignedAlloc: IAlloc = nil;
  GAllocLock: TRTLCriticalSection;  // 线程安全锁

{ TAllocBase }

constructor TAllocBase.Create(const aCaps: TAllocCaps);
begin
  inherited Create;
  FCaps := aCaps;
end;

function TAllocBase.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  // ✅ P0-4: 检查布局有效性
  if not aLayout.IsValid then
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  // ✅ P0-4: 检查分配器能力（对齐支持）
  if not FCaps.SupportsLayout(aLayout) then
  begin
    Result := TAllocResult.Err(aeAlignmentNotSupported);
    Exit;
  end;

  if aLayout.IsZeroSized then
  begin
    // 零大小分配返回非 nil 的哨兵值（Rust 风格）
    // 但我们用 nil 更安全
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  LPtr := DoAlloc(aLayout.Size, aLayout.Align);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TAllocBase.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

procedure TAllocBase.Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
begin
  if aPtr = nil then
    Exit;

  DoDealloc(aPtr, aLayout.Size, aLayout.Align);
end;

function TAllocBase.DoRealloc(aPtr: Pointer; aOldSize, aNewSize, aAlign: SizeUInt): Pointer;
var
  LCopySize: SizeUInt;
begin
  // 默认实现：分配新块 + 复制 + 释放旧块
  Result := DoAlloc(aNewSize, aAlign);
  if Result = nil then
    Exit;

  // 复制数据
  if aOldSize < aNewSize then
    LCopySize := aOldSize
  else
    LCopySize := aNewSize;

  if LCopySize > 0 then
    Move(aPtr^, Result^, LCopySize);

  // 释放旧块
  DoDealloc(aPtr, aOldSize, aAlign);
end;

function TAllocBase.Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  // nil 指针 = 新分配
  if aPtr = nil then
  begin
    Result := Alloc(aNewLayout);
    Exit;
  end;

  // 零大小 = 释放
  if aNewLayout.IsZeroSized then
  begin
    Dealloc(aPtr, aOldLayout);
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  // ✅ P0-4: 验证布局有效性
  if not aNewLayout.IsValid then
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  // ✅ P0-4: 检查分配器能力（对齐支持）
  if not FCaps.SupportsLayout(aNewLayout) then
  begin
    Result := TAllocResult.Err(aeAlignmentNotSupported);
    Exit;
  end;

  // ✅ P0-4: 检查是否支持 Realloc
  if not FCaps.CanRealloc then
  begin
    Result := TAllocResult.Err(aeReallocNotSupported);
    Exit;
  end;

  // 对齐必须兼容
  if aNewLayout.Align > aOldLayout.Align then
  begin
    // 需要更大对齐 - 必须重新分配
    LPtr := DoAlloc(aNewLayout.Size, aNewLayout.Align);
    if LPtr = nil then
    begin
      Result := TAllocResult.Err(aeOutOfMemory);
      Exit;
    end;

    // 复制数据
    if aOldLayout.Size < aNewLayout.Size then
      Move(aPtr^, LPtr^, aOldLayout.Size)
    else
      Move(aPtr^, LPtr^, aNewLayout.Size);

    DoDealloc(aPtr, aOldLayout.Size, aOldLayout.Align);
    Result := TAllocResult.Ok(LPtr);
  end
  else
  begin
    // 对齐兼容，使用优化路径
    LPtr := DoRealloc(aPtr, aOldLayout.Size, aNewLayout.Size, aOldLayout.Align);
    if LPtr = nil then
      Result := TAllocResult.Err(aeOutOfMemory)
    else
      Result := TAllocResult.Ok(LPtr);
  end;
end;

function TAllocBase.Caps: TAllocCaps;
begin
  Result := FCaps;
end;

{ TSystemAlloc }

constructor TSystemAlloc.Create;
begin
  inherited Create(TAllocCaps.ForSystemHeap);
end;

function TSystemAlloc.DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer;
begin
  // 系统堆只保证指针对齐
  if aAlign > MEM_DEFAULT_ALIGN then
  begin
    Result := nil;  // 不支持大对齐，调用者应使用 TAlignedAlloc
    Exit;
  end;

  GetMem(Result, aSize);
end;

procedure TSystemAlloc.DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt);
begin
  FreeMem(aPtr);
end;

function TSystemAlloc.DoRealloc(aPtr: Pointer; aOldSize, aNewSize, aAlign: SizeUInt): Pointer;
begin
  Result := aPtr;
  ReallocMem(Result, aNewSize);
end;

{ TAlignedAlloc }

constructor TAlignedAlloc.Create;
var
  LCaps: TAllocCaps;
begin
  LCaps := TAllocCaps.Create(
    False,  // ZeroOnAlloc
    True,   // ThreadSafe
    False,  // KnowsSize
    True,   // NativeAligned - 支持任意对齐
    True,   // CanRealloc
    MEM_PAGE_SIZE  // MaxAlign
  );
  inherited Create(LCaps);
end;

function TAlignedAlloc.DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer;
var
  LActualSize: SizeUInt;
  LRawPtr: Pointer;
  LAlignedPtr: Pointer;
begin
  // 默认对齐使用系统堆
  if aAlign <= MEM_DEFAULT_ALIGN then
  begin
    GetMem(Result, aSize);
    Exit;
  end;

  // 分配额外空间：原始指针 + 对齐填充
  LActualSize := aSize + aAlign + SizeOf(Pointer);
  GetMem(LRawPtr, LActualSize);
  if LRawPtr = nil then
  begin
    Result := nil;
    Exit;
  end;

  // 计算对齐地址（保留空间存储原始指针）
  LAlignedPtr := Pointer(AlignUp(PtrUInt(LRawPtr) + SizeOf(Pointer), aAlign));

  // 在对齐地址前存储原始指针
  PPointer(PByte(LAlignedPtr) - SizeOf(Pointer))^ := LRawPtr;

  Result := LAlignedPtr;
end;

procedure TAlignedAlloc.DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt);
var
  LRawPtr: Pointer;
begin
  // 默认对齐直接释放
  if aAlign <= MEM_DEFAULT_ALIGN then
  begin
    FreeMem(aPtr);
    Exit;
  end;

  // 从对齐地址前获取原始指针
  LRawPtr := PPointer(PByte(aPtr) - SizeOf(Pointer))^;
  FreeMem(LRawPtr);
end;

{ Global accessors }

function GetSystemAlloc: IAlloc;
begin
  // 双重检查锁定 - 线程安全的单例初始化
  if GSystemAlloc = nil then
  begin
    EnterCriticalSection(GAllocLock);
    try
      if GSystemAlloc = nil then
        GSystemAlloc := TSystemAlloc.Create;
    finally
      LeaveCriticalSection(GAllocLock);
    end;
  end;
  Result := GSystemAlloc;
end;

function GetAlignedAlloc: IAlloc;
begin
  // 双重检查锁定 - 线程安全的单例初始化
  if GAlignedAlloc = nil then
  begin
    EnterCriticalSection(GAllocLock);
    try
      if GAlignedAlloc = nil then
        GAlignedAlloc := TAlignedAlloc.Create;
    finally
      LeaveCriticalSection(GAllocLock);
    end;
  end;
  Result := GAlignedAlloc;
end;

initialization
  InitCriticalSection(GAllocLock);

finalization
  DoneCriticalSection(GAllocLock);
  // 清理全局单例，避免 HeapTrc 报告内存泄漏
  GSystemAlloc := nil;
  GAlignedAlloc := nil;

{$POP}

end.
