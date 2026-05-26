unit nextpas.core.mem.allocator.base;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.intf,
  nextpas.core.contracts
  {$IFDEF FAFAFA_CORE_STRICT_NULL_FREE}
  , nextpas.core.base
  {$ENDIF}
  ;

type
  {**
   * TAllocatorTraits
   *
   * @desc 只读能力描述，便于上层策略化选择
   *
   * 注意：所有 IAllocator 实现都提供 AllocAligned/FreeAligned 方法，
   * 但实现方式不同：
   * - SupportsAligned=True: 原生支持，无额外开销（如 mimalloc）
   * - SupportsAligned=False: 通过 over-allocate 模拟，有内存/性能开销
   *}
  TAllocatorTraits = record
    ZeroInitialized: Boolean;   // AllocMem 是否保证零填充
    ThreadSafe     : Boolean;   // 是否内置线程安全（无需外部加锁）
    HasMemSize     : Boolean;   // 是否支持查询已分配块大小（如 MemSizeOf）
    SupportsAligned: Boolean;   // 是否原生支持对齐分配（无 over-allocate 开销）
  end;
  {**
   * IAllocator
   *
   * @desc
   *   通用内存分配器的接口，提供统一的内存管理抽象。
   *   Universal memory allocator interface providing unified memory management abstraction.
   *
   * @usage
   *   用于解耦内存分配策略，支持自定义分配器（RTL、CRT、mimalloc 等）。
   *   Used to decouple memory allocation strategies, supporting custom allocators (RTL, CRT, mimalloc, etc.).
   *
   * @thread_safety
   *   线程安全性取决于具体实现，通过 Traits.ThreadSafe 查询。
   *   Thread safety depends on implementation, query via Traits.ThreadSafe.
   *
   * @example
   *   // 使用 RTL 分配器
   *   var Allocator: IAllocator;
   *   Allocator := GetRtlAllocator;
   *
   *   // 分配内存
   *   Ptr := Allocator.GetMem(1024);
   *   try
   *     // 使用内存...
   *   finally
   *     Allocator.FreeMem(Ptr);
   *   end;
   *
   *   // 对齐分配（用于 SIMD）
   *   AlignedPtr := Allocator.AllocAligned(256, 32);  // 32 字节对齐
   *   try
   *     // 使用对齐内存...
   *   finally
   *     Allocator.FreeAligned(AlignedPtr);
   *   end;
   *
   * @see TAllocator, GetRtlAllocator, GetCrtAllocator, TryGetMimallocAllocator
   *}
  IAllocator = interface(nextpas.core.mem.intf.IAllocator)
    ['{1CEB691D-D538-48D2-A5C4-A4F0A1B98928}']
    {**
     * GetMem
     * @desc 分配指定大小的内存块（不保证零初始化）
     * @param aSize 要分配的字节数
     * @return 指向分配内存的指针，失败返回 nil
     *}
    function GetMem(aSize: SizeUInt): Pointer;

    {**
     * AllocMem
     * @desc 分配指定大小的内存块并零初始化
     * @param aSize 要分配的字节数
     * @return 指向分配内存的指针，失败返回 nil
     *}
    function AllocMem(aSize: SizeUInt): Pointer;

    {**
     * ReallocMem
     * @desc 重新分配内存块大小
     * @param aDst 原内存块指针（可为 nil）
     * @param aSize 新的大小（0 表示释放）
     * @return 指向新内存块的指针
     *}
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;

    {**
     * FreeMem
     * @desc 释放内存块
     * @param aDst 要释放的内存块指针
     *}
    procedure FreeMem(aDst: Pointer);

    {**
     * AllocAligned
     * @desc 分配对齐的内存块（用于 SIMD 等需要对齐的场景）
     * @param aSize 要分配的字节数
     * @param aAlignment 对齐字节数（必须是 2 的幂）
     * @return 指向对齐内存的指针，失败返回 nil
     *}
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;

    {**
     * FreeAligned
     * @desc 释放对齐分配的内存块
     * @param aPtr 要释放的对齐内存块指针
     *}
    procedure FreeAligned(aPtr: Pointer);

    {**
     * Traits
     * @desc 查询分配器的能力特征
     * @return 分配器特征描述
     *}
    function Traits: TAllocatorTraits;
  end;

  {**
   * TAllocator
   *
   * @desc 内存分配器的抽象基类, 实现了 IAllocator 接口
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(aSize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(aDst: Pointer); virtual; abstract;
  public
    function  Allocate(const ASize: SizeUInt): Pointer; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    function  Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    procedure Deallocate(const APtr: Pointer); {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    function  GetMem(aSize: SizeUInt): Pointer; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(aSize: SizeUInt): Pointer; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(aDst: Pointer); {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
    // 对齐分配（默认回退实现，子类可覆盖为原生对齐）
    function  AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function  Traits: TAllocatorTraits; virtual;
  end;


implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned alloc helpers

function IsPowerOfTwo(x: SizeUInt): Boolean; inline;
begin
  Result := (x <> 0) and ((x and (x - 1)) = 0);
end;

function AlignUpPtr(P: Pointer; AAlignment: SizeUInt): Pointer; inline;
var
  LAddr, LMask: PtrUInt;
begin
  LAddr := PtrUInt(P);
  LMask := PtrUInt(AAlignment - 1);
  Result := Pointer((LAddr + LMask) and not LMask);
end;

function TAllocator.Traits: TAllocatorTraits;
begin
  // 基类缺省值：
  // - ThreadSafe=True: 大多数 RTL 分配器线程安全
  // - ZeroInitialized=False: GetMem 不保证零填充
  // - HasMemSize=False: 不支持查询块大小
  // - SupportsAligned=False: 通过 over-allocate 模拟
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := True;
  Result.HasMemSize      := False;
  Result.SupportsAligned := False;
end;

function TAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TAllocator.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := DoGetMem(aSize);
end;

function TAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := DoAllocMem(aSize);
end;

function TAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    if aDst <> nil then
      DoFreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Result := DoReallocMem(aDst, aSize);
end;

procedure TAllocator.FreeMem(aDst: Pointer);
begin
  if aDst = nil then
  begin
    {$IFDEF FAFAFA_CORE_STRICT_NULL_FREE}
    raise EArgumentNil.Create('TAllocator.FreeMem: aDst cannot be nil.');
    {$ELSE}
    Exit;
    {$ENDIF}
  end;
  DoFreeMem(aDst);
end;

function TAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if aSize = 0 then Exit(nil);
  if (aAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(aAlignment)) then
    ContractsRequire(False, 'AllocAligned: alignment must be power of two and >= pointer size');
  // Over-allocate and store the original pointer just before the aligned block
  LNeeded := aSize + aAlignment - 1 + SizeOf(Pointer);
  LRaw := GetMem(LNeeded);
  if LRaw = nil then Exit(nil);
  Result := AlignUpPtr(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), aAlignment);
  LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
  LHeaderPtr^ := LRaw;
end;

procedure TAllocator.FreeAligned(aPtr: Pointer);
var
  LRaw: Pointer;
  LHeaderPtr: PPointer;
begin
  if aPtr = nil then Exit;
  LHeaderPtr := PPointer(PtrUInt(aPtr) - SizeOf(Pointer));
  LRaw := LHeaderPtr^;
  FreeMem(LRaw);
end;

{$POP}

end.
