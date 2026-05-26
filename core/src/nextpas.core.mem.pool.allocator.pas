unit nextpas.core.mem.pool.allocator;

{$I nextpas.core.settings.inc}

{**
 * TPoolAllocator - 固定块池分配器适配器
 *
 * 将 TFixedPool 适配为 IAllocator 接口，用于集合节点分配优化。
 * 对标 Rust bumpalo / typed-arena 的设计理念：
 * - O(1) 分配和释放
 * - 固定块大小，零碎片
 * - 适用于 TreeMap/LinkedHashMap/ForwardList 等节点分配
 *
 * 使用示例:
 *   var Pool: IAllocator;
 *       Map: ITreeMap<Integer, String>;
 *   begin
 *     Pool := MakePoolAllocator(SizeOf(TRedBlackTreeNode<Integer, String>), 10000);
 *     Map := MakeTreeMap<Integer, String>(0, @IntCompare, Pool);
 *   end;
 *}

interface

uses
  SysUtils,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.fixed;

type
  {**
   * TPoolAllocator
   *
   * @desc 固定块池分配器，实现 IAllocator 接口
   * @note 固定大小分配使用池，超出大小使用后备分配器
   *}
  TPoolAllocator = class(TInterfacedObject, IAllocator)
  private
    FPool: TFixedPool;
    FBlockSize: SizeUInt;
    FFallback: IAllocator;  // 用于非标准大小分配的后备分配器
    function GetAllocatedCount: Integer;
    function GetCapacity: Integer;
    function GetAvailable: Integer;
  public
    {**
     * Create
     *
     * @param ABlockSize 块大小（自动对齐到 8 字节）
     * @param ACapacity 池容量（块数量）
     * @param AFallback 后备分配器（用于非标准大小分配）
     *}
    constructor Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator = nil);
    destructor Destroy; override;

    // IAllocator
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
    // 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）
    function GetMemSize(aPtr: Pointer): SizeUInt;
    function TryGetMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
    function TryAllocMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;

    // 统计
    property BlockSize: SizeUInt read FBlockSize;
    property AllocatedCount: Integer read GetAllocatedCount;
    property Capacity: Integer read GetCapacity;
    property Available: Integer read GetAvailable;
  end;

{**
 * MakePoolAllocator
 *
 * @desc 创建池分配器
 * @param ABlockSize 块大小
 * @param ACapacity 池容量
 * @param AFallback 后备分配器
 * @return IAllocator 池分配器接口
 *}
function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator = nil): IAllocator;

implementation

{ TPoolAllocator }

constructor TPoolAllocator.Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator);
var
  LAlignedSize: SizeUInt;
begin
  inherited Create;

  // 确保块大小是 8 的倍数（指针对齐）
  LAlignedSize := (ABlockSize + 7) and not SizeUInt(7);
  if LAlignedSize < SizeOf(Pointer) then
    LAlignedSize := SizeOf(Pointer);

  FBlockSize := LAlignedSize;

  if AFallback = nil then
    FFallback := GetRtlAllocator
  else
    FFallback := AFallback;

  FPool := TFixedPool.Create(FBlockSize, ACapacity, 16, FFallback);
end;

destructor TPoolAllocator.Destroy;
begin
  FreeAndNil(FPool);
  inherited Destroy;
end;

function TPoolAllocator.GetAllocatedCount: Integer;
begin
  Result := FPool.AllocatedCount;
end;

function TPoolAllocator.GetCapacity: Integer;
begin
  Result := FPool.Capacity;
end;

function TPoolAllocator.GetAvailable: Integer;
begin
  Result := FPool.Available;
end;

function TPoolAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TPoolAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TPoolAllocator.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TPoolAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize <= FBlockSize then
  begin
    // 从池分配
    if FPool.TryAlloc(Result) then
      Exit;
  end;
  // 池满或大小超出，使用后备分配器
  Result := FFallback.GetMem(aSize);
end;

function TPoolAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TPoolAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  // 池分配器不支持 ReallocMem
  // 如果是池中的指针，释放并重新分配
  if (aDst <> nil) and FPool.Owns(aDst) then
  begin
    Result := GetMem(aSize);
    if Result <> nil then
    begin
      // 复制旧数据（最多复制 FBlockSize）
      if aSize > FBlockSize then
        Move(aDst^, Result^, FBlockSize)
      else
        Move(aDst^, Result^, aSize);
      FPool.ReleasePtr(aDst);
    end;
  end
  else
    // 不是池中的指针，使用后备分配器
    Result := FFallback.ReallocMem(aDst, aSize);
end;

procedure TPoolAllocator.FreeMem(aDst: Pointer);
begin
  if aDst = nil then
    Exit;

  if FPool.Owns(aDst) then
    FPool.ReleasePtr(aDst)
  else
    FFallback.FreeMem(aDst);
end;

function TPoolAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  // 池分配器的块已经是 16 字节对齐的
  // 如果请求的对齐 <= 16，直接使用池分配
  if (aAlignment <= 16) and (aSize <= FBlockSize) then
  begin
    if FPool.TryAlloc(Result) then
      Exit;
  end;
  // 否则使用后备分配器
  Result := FFallback.AllocAligned(aSize, aAlignment);
end;

procedure TPoolAllocator.FreeAligned(aPtr: Pointer);
begin
  if aPtr = nil then
    Exit;

  if FPool.Owns(aPtr) then
    FPool.ReleasePtr(aPtr)
  else
    FFallback.FreeAligned(aPtr);
end;

function TPoolAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;  // TFixedPool 不是线程安全的
  Result.HasMemSize := True;   // 我们知道块大小
  Result.SupportsAligned := True;  // 块是 16 字节对齐的
end;

// 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）

function TPoolAllocator.GetMemSize(aPtr: Pointer): SizeUInt;
begin
  if (aPtr = nil) then
    Exit(0);
  // 如果是池中的指针，返回块大小
  if FPool.Owns(aPtr) then
    Result := FBlockSize
  else
    // 后备分配器不保证支持此方法，返回 0 表示未知
    Result := 0;
end;

function TPoolAllocator.TryGetMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
begin
  aPtr := GetMem(aSize);
  Result := (aPtr <> nil) or (aSize = 0);
end;

function TPoolAllocator.TryAllocMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
begin
  aPtr := AllocMem(aSize);
  Result := (aPtr <> nil) or (aSize = 0);
end;

{ Factory function }

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator): IAllocator;
begin
  Result := TPoolAllocator.Create(ABlockSize, ACapacity, AFallback);
end;

end.
