{**
 * nextpas.core.mem.intf - IAllocator 抽象分配接口与能力描述
 *
 * @desc Canonical allocator contract for nextpas.core.mem.
 *       本单元定义 IAllocator 与 TAllocatorTraits：所有具体分配器实现的公共契约。
 *
 * @contract
 *   - 调用方拥有 GetMem/AllocMem/ReallocMem 返回的指针，必须用同一 IAllocator 的 FreeMem 释放。
 *   - ASize=0：GetMem/AllocMem 返回 nil。
 *   - FreeMem(nil) 为空操作。
 *   - ReallocMem(nil, size) 等价 GetMem(size)；ReallocMem(ptr, 0) 等价 FreeMem(ptr) 并返回 nil。
 *   - OOM：GetMem/AllocMem/ReallocMem 返回 nil，不抛异常（原指针在 Realloc 失败时仍有效）。
 *   - 双重释放与非法指针：未定义行为；调试分配器（Guard/Sentinel 等）可抛 EAllocError。
 *   - 线程安全取决于 Traits.ThreadSafe。
 *
 * @see core/docs/mem/api-contracts.md
 * @see nextpas.core.mem.error (EAllocError / TAllocError)
 *}

unit nextpas.core.mem.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  {**
   * @desc Allocator capability description used by strategy code.
   *       描述分配器能力，供策略层与包装器查询。
   *
   * @field ZeroInitialized
   *   仅对 AllocMem 有效：AllocMem 保证返回全零内存。
   *   GetMem 不保证零填充，即使 ZeroInitialized=True。
   *
   * @field ThreadSafe
   *   True 时，所有方法可从多线程并发调用。
   *   False 时，调用方必须自行串行化。
   *
   * @field SupportsRealloc
   *   True 时，ReallocMem 可高效就地（或等价）调整大小。
   *   False 时，ReallocMem 可能不可用或抛 aeReallocNotSupported（视实现而定）。
   *}
  TAllocatorTraits = record
    ZeroInitialized: Boolean;  { AllocMem 返回全零内存 }
    ThreadSafe: Boolean;       { 所有方法线程安全 }
    SupportsRealloc: Boolean;  { ReallocMem 可用；False 时 ReallocMem 会抛 aeReallocNotSupported }
  end;

  {**
   * @desc Canonical nextpas.core allocator contract.
   *       抽象内存分配接口：统一 GetMem/AllocMem/ReallocMem/FreeMem 与 Traits。
   *
   * @purpose
   *   为 CRT、池、arena 适配器、调试包装器等提供可替换的分配后端。
   *
   * @contract
   *   - 所有权：返回指针由调用方拥有，必须通过本接口 FreeMem 释放（同一实例）。
   *   - 生命周期：分配器实例存活期间，已分配指针保持有效，直至 FreeMem 或 Realloc 成功迁移。
   *   - 零大小：GetMem(0)/AllocMem(0) → nil。
   *   - nil 释放：FreeMem(nil) → 无操作。
   *   - Realloc：见 ReallocMem 方法说明。
   *   - 线程安全：以 Traits.ThreadSafe 为准。
   *
   * @note 核心 5 方法：GetMem/AllocMem/ReallocMem/FreeMem + Traits。
   *       MemSize 与 AllocAligned/FreeAligned 已移至更专门的接口
   *       （IMemoryPool.MemSizeOf 和 IArena.AllocAligned）。
   *}
  IAllocator = interface
    ['{1CEB691D-D538-48D2-A5C4-A4F0A1B98928}']
    {**
     * @desc 分配 ASize 字节内存。
     * @param ASize 请求字节数。ASize=0 时返回 nil。
     * @return 未初始化内存指针；OOM 时返回 nil。ASize=0 时返回 nil。
     * @note 返回内存不保证零填充（即使 Traits.ZeroInitialized=True）。
     * @note 调用方拥有返回指针，必须用 FreeMem 释放。
     *}
    function GetMem(ASize: SizeUInt): Pointer;

    {**
     * @desc 分配 ASize 字节零初始化内存。
     * @param ASize 请求字节数。ASize=0 时返回 nil。
     * @return 全零内存指针；OOM 时返回 nil。ASize=0 时返回 nil。
     * @note 成功时内容全为零。调用方拥有返回指针，必须用 FreeMem 释放。
     *}
    function AllocMem(ASize: SizeUInt): Pointer;

    {**
     * @desc 调整已有分配的大小（可能移动数据）。
     * @param APtr  原指针。APtr=nil 时行为等价 GetMem(ASize)。
     * @param ASize 新大小。ASize=0 时释放 APtr 并返回 nil（等价 FreeMem）。
     * @return 新指针；失败时返回 nil，原指针仍有效（APtr<>nil 且 ASize>0 时）。
     * @note APtr<>nil 且 ASize>0：尝试扩/缩，可能原地或搬迁；搬迁时拷贝 min(旧,新) 字节。
     * @note SupportsRealloc=False 的实现可能抛 aeReallocNotSupported 或采用降级策略。
     *}
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;

    {**
     * @desc 释放由 GetMem/AllocMem/ReallocMem 得到的内存（单参；接口冻结五方法）。
     * @param APtr 待释放指针。APtr=nil 时为空操作。
     * @note 不得对同一指针调用两次（双重释放为未定义行为）。
     * @note 调试分配器（Guard、Sentinel 等）可能对非法指针或双重释放抛 EAllocError
     *       （aeInvalidPointer / aeDoubleFree / aeSentinelCorrupted 等）。
     * @note Sized free for DefaultHeap-owned blocks: process FreeMem(ptr,size) or
     *       FreeMemOf(alloc,ptr,size). FreeMemOf may skip this method on same-heap
     *       hot path — use this FreeMem when inject tracking must observe free.
     *}
    procedure FreeMem(APtr: Pointer);

    {**
     * @desc 返回本分配器的能力特征。
     * @return TAllocatorTraits（ZeroInitialized / ThreadSafe / SupportsRealloc）。
     * @note 调用方应根据 Traits 决定并发策略与是否依赖 Realloc。
     *}
    function Traits: TAllocatorTraits;
  end;

implementation

end.
