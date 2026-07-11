unit nextpas.core.mem.pool.base;

{$I nextpas.core.settings.inc}

interface

type
  {** 最小基座接口（可用于统一抽象，但不强制大小语义）
   *
   * 接口选择决策树:
   *   - 需要固定大小块池 + 容量/可用量查询？→ IBlockPool (blockpool.pas)
   *   - 需要可变大小分配 + 固定大小 Acquire 兼容？→ IMemoryPool (本单元)
   *   - 只需通用 Acquire/Release 抽象？→ IPool (本单元)
   *
   * IPool vs IBlockPool 签名差异说明:
   *   - IPool.Acquire(out APtr: Pointer): Boolean — Boolean + out param 模式，
   *     适用于需要区分"池耗尽"和"分配失败"的场景
   *   - IBlockPool.Acquire: Pointer — 直接返回指针，nil = 池耗尽，
   *     适用于热路径（减少分支，inline 友好）
   *   - 两者是不同层次的接口，不建议强行统一签名
   *}
  IPool = interface
    ['{6B2E8E2D-0C3A-4E6C-9D7F-2B7E4B7A9A10}']
    function Acquire(out APtr: Pointer): Boolean;
    function TryAcquire(out APtr: Pointer): Boolean;
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
    procedure Release(APtr: Pointer);
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);
    procedure Reset;
  end;

  // IMemoryPool — 通用内存池接口
  //
  // 继承自 IPool，同时暴露固定大小 API (Acquire/Release) 和可变大小 API (GetMem/FreeMem)。
  //
  // 语义约定：
  // - GetMem/FreeMem: 可变大小分配，支持任意大小（池内部可能走 size class 或 fallback）
  // - Acquire/Release: 固定大小分配，分配该池的"最小分配粒度"
  // - 实际使用：可变大小分配优先使用 GetMem/AllocMem/ReallocMem/FreeMem
  // - Acquire 系列仅用于兼容层/极简场景（如只需要固定大小块的场景）
  //
  // 与 IAllocator 的关系：
  // - IMemoryPool 同时实现 IAllocator（通过 GetMem/FreeMem/AllocMem/ReallocMem/Traits）
  // - 调用方可以将 IMemoryPool 当作 IAllocator 使用
  //
  // ⚠️ 同一对象两种分配语义 (以 TSlabPool 为例):
  //   - 通过 IPool 引用调用 Acquire → 分配最小 slab 单元 (通常 8B)
  //   - 通过 IAllocator 引用调用 GetMem(64) → 走 size-class 路由
  //   两者返回的指针可以互相 FreeMem/Release，但分配粒度不同。
  //   新代码应统一使用 IAllocator.GetMem/FreeMem，Acquire 仅保留向后兼容。
  //
  // 实现者：TSlabPool, TFixedSlabPool, TSlabPoolConcurrent 等
  IMemoryPool = interface(IPool)
    ['{6F6B4299-3B29-4C6F-917D-8D6B4B5E0E99}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
  end;

{ Method-of-object types for batch operation helpers. }
type
  TAcquireOneFunc = function: Pointer of object;
  TReleaseOneProc = procedure(APtr: Pointer) of object;

{**
 * @desc Default AcquireN loop: call AAcquire repeatedly, fill APtrs up to
 *       min(ACount, Length(APtrs)), stop on nil. Returns acquired count.
 *}
function DefaultAcquireN(const AAcquire: TAcquireOneFunc;
  out APtrs: array of Pointer; ACount: Integer): Integer;

{**
 * @desc Default ReleaseN loop: call ARelease for each entry in APtrs,
 *       up to min(ACount, Length(APtrs)).
 *}
procedure DefaultReleaseN(const ARelease: TReleaseOneProc;
  const APtrs: array of Pointer; ACount: Integer);

implementation

function DefaultAcquireN(const AAcquire: TAcquireOneFunc;
  out APtrs: array of Pointer; ACount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if ACount <= 0 then Exit;
  for LIdx := 0 to ACount - 1 do
  begin
    if LIdx > High(APtrs) then
      Break;
    LPtr := AAcquire();
    if LPtr = nil then
      Break;
    APtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure DefaultReleaseN(const ARelease: TReleaseOneProc;
  const APtrs: array of Pointer; ACount: Integer);
var
  LIdx: Integer;
begin
  if ACount <= 0 then Exit;
  for LIdx := 0 to ACount - 1 do
  begin
    if LIdx > High(APtrs) then
      Break;
    ARelease(APtrs[LIdx]);
  end;
end;

end.
