{$CODEPAGE UTF8}
unit nextpas.core.mem.mapped_slab_pool;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, nextpas.core.mem.memory_map;

type
  {**
   * TMappedSlabPoolMode
   *
   * @desc 映射 Slab 池的模式
   *}
  TMappedSlabPoolMode = (
    mspFile,      // 基于文件的映射池
    mspShared,    // 基于共享内存的映射池
    mspAnonymous  // 基于匿名映射的池
  );

  {**
   * TMappedSlabPool
   *
   * @desc 基于内存映射的 Slab 分配器
   *       结合了 TMemoryMap 的高效内存管理和 TSlabPool 的快速分配算法
   *       支持大块内存的映射分配，特别适合大对象和持久化场景
   *}
  TMappedSlabPool = class
  private
    FMemoryMap: TMemoryMap;
    FSharedMemory: TSharedMemory;
    FMode: TMappedSlabPoolMode;
    FIsCreator: Boolean;

    // Slab 管理数据（存储在映射内存中）
    FHeader: Pointer;
    FSlabData: Pointer;
    FPoolSize: UInt64;
    FPageSize: UInt32;
    FMaxSizeClass: UInt32;

    // 内存布局指针
    FPages: Pointer;          // 页面描述符数组
    FDataArea: Pointer;       // 实际数据区域

    function GetBaseAddress: Pointer;
    function CalculateRequiredSize(aPoolSize: UInt64): UInt64;
    procedure InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
    function ValidateHeader: Boolean;
    procedure InitializeSlabStructures;

  public
    constructor Create;
    destructor Destroy; override;

    {**
     * CreateFile
     *
     * @desc 创建基于文件的映射 Slab 池
     * @param aFileName 文件路径
     * @param aPoolSize 池大小（字节）
     * @param aPageSize 页面大小（默认4096）
     * @param aMaxSizeClass 最大大小类别（默认2048）
     * @return 是否成功
     *}
    function CreateFile(const aFileName: string; aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048): Boolean;

    {**
     * OpenFile
     *
     * @desc 打开已存在的文件映射 Slab 池
     * @param aFileName 文件路径
     * @return 是否成功
     *}
    function OpenFile(const aFileName: string): Boolean;

    {**
     * CreateShared
     *
     * @desc 创建跨进程共享 Slab 池
     * @param aName 共享内存名称
     * @param aPoolSize 池大小（字节）
     * @param aPageSize 页面大小（默认4096）
     * @param aMaxSizeClass 最大大小类别（默认2048）
     * @return 是否成功
     *}
    function CreateShared(const aName: string; aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048): Boolean;

    {**
     * OpenShared
     *
     * @desc 打开已存在的共享 Slab 池
     * @param aName 共享内存名称
     * @return 是否成功
     *}
    function OpenShared(const aName: string): Boolean;

    {**
     * CreateAnonymous
     *
     * @desc 创建匿名映射 Slab 池
     * @param aPoolSize 池大小（字节）
     * @param aPageSize 页面大小（默认4096）
     * @param aMaxSizeClass 最大大小类别（默认2048）
     * @return 是否成功
     *}
    function CreateAnonymous(aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048): Boolean;

    {**
     * Close
     *
     * @desc 关闭映射 Slab 池
     *}
    procedure Close;


    {**
     * FreeBlock
     *
     * @desc 释放通过 Alloc 得到的块（避免与 TObject.Free 名称冲突）
     *}
    procedure FreeBlock(aPtr: Pointer);

    {**
     * Alloc
     *
     * @desc 分配指定大小的内存块
     * @param aSize 请求的字节数
     * @return 分配的内存指针，失败返回 nil
     *}
    function Alloc(aSize: UInt64): Pointer;



    {**
     * Flush
     *
     * @desc 将修改刷新到存储设备（仅文件映射有效）
     * @return 是否成功
     *}
    function Flush: Boolean;

    {**
     * FlushRange
     *
     * @desc 将指定范围的修改刷新到存储设备
     * @param aOffset 偏移量
     * @param aSize 大小
     * @return 是否成功
     *}
    function FlushRange(aOffset: UInt64; aSize: UInt64): Boolean;

    {**
     * GetStats
     *
     * @desc 获取统计信息
     * @param aTotalAllocs 总分配次数
     * @param aTotalFrees 总释放次数
     * @param aFailedAllocs 失败分配次数
     * @param aUsedPages 已使用页面数
     * @param aTotalPages 总页面数
     *}
    procedure GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
      out aUsedPages, aTotalPages: UInt32);

    {**
     * Reset
     *
     * @desc 重置池状态（清空所有分配）
     *}
    procedure Reset;

    {**
     * IsValid
     *
     * @desc 检查池是否有效
     *}
    function IsValid: Boolean;

    // 属性
    property BaseAddress: Pointer read GetBaseAddress;
    property PoolSize: UInt64 read FPoolSize;
    property PageSize: UInt32 read FPageSize;
    property MaxSizeClass: UInt32 read FMaxSizeClass;
    property Mode: TMappedSlabPoolMode read FMode;
    property IsCreator: Boolean read FIsCreator;
  end;

  {**
   * TMappedSlabPoolManager
   *
   * @desc 映射 Slab 池管理器
   *       管理多个不同大小的映射 Slab 池，自动选择最适合的池进行分配
   *       支持超大对象的直接映射分配
   *}
  TMappedSlabPoolManager = class
  private
    FPools: array[0..8] of TMappedSlabPool; // 9个不同大小的池
    FPoolSizes: array[0..8] of UInt64;      // 对应的池大小
    FLargeObjectThreshold: UInt64;          // 大对象阈值
    FBasePath: string;                      // 文件池的基础路径
    FSharedPrefix: string;                  // 共享池的名称前缀

    function GetPoolForSize(aSize: UInt64): TMappedSlabPool;
    procedure InitializePools(aMode: TMappedSlabPoolMode);
    procedure DestroyPools;

  public
    constructor Create(aMode: TMappedSlabPoolMode = mspAnonymous;
      const aBasePath: string = ''; const aSharedPrefix: string = '');
    destructor Destroy; override;

    {**
     * AllocAny
     *
     * @desc 分配任意大小的内存
     * @param aSize 请求的字节数
     * @return 分配的内存指针，失败返回 nil
     *}
    function AllocAny(aSize: UInt64): Pointer;

    {**
     * FreeAny
     *
     * @desc 释放内存
     * @param aPtr 要释放的内存指针
     *}
    procedure FreeAny(aPtr: Pointer);

    {**
     * FlushAll
     *
     * @desc 刷新所有池的修改到存储设备
     * @return 是否全部成功
     *}
    function FlushAll: Boolean;

    {**
     * GetTotalStats
     *
     * @desc 获取所有池的汇总统计信息
     *}
    procedure GetTotalStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
      out aUsedMemory, aTotalMemory: UInt64);

    // 属性
    property LargeObjectThreshold: UInt64 read FLargeObjectThreshold write FLargeObjectThreshold;
  end;

implementation

uses
  Classes;

const
  // 内存布局常量
  HEADER_SIZE = 128;         // 头部大小
  SLAB_MAGIC = $534C4142;    // 'SLAB' 魔数
  SLAB_VERSION = 1;          // 版本号

  // 默认池大小（字节）
  DEFAULT_POOL_SIZES: array[0..8] of UInt64 = (
    1024*1024,      // 1MB
    4*1024*1024,    // 4MB
    16*1024*1024,   // 16MB
    64*1024*1024,   // 64MB
    256*1024*1024,  // 256MB
    512*1024*1024,  // 512MB
    1024*1024*1024, // 1GB
    2048*1024*1024, // 2GB
    4096*1024*1024  // 4GB
  );

type
  // 映射 Slab 池头部结构
  PMappedSlabHeader = ^TMappedSlabHeader;
  TMappedSlabHeader = packed record
    Magic: UInt32;           // 魔数
    Version: UInt32;         // 版本号
    PoolSize: UInt64;        // 池大小
    PageSize: UInt32;        // 页面大小
    MaxSizeClass: UInt32;    // 最大大小类别
    TotalPages: UInt32;      // 总页面数
    UsedPages: UInt32;       // 已使用页面数
    TotalAllocs: UInt64;     // 总分配次数
    TotalFrees: UInt64;      // 总释放次数
    FailedAllocs: UInt64;    // 失败分配次数
    Reserved: array[0..31] of Byte; // 保留字段
  end;

{ TMappedSlabPool }

constructor TMappedSlabPool.Create;
begin
  inherited Create;
  FMemoryMap := nil;
  FSharedMemory := nil;
  FMode := mspAnonymous;
  FIsCreator := False;
  FHeader := nil;
  FSlabData := nil;
  FPoolSize := 0;
  FPageSize := 4096;
  FMaxSizeClass := 2048;
  FPages := nil;
  FDataArea := nil;
end;

destructor TMappedSlabPool.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMappedSlabPool.GetBaseAddress: Pointer;
begin
  if FMemoryMap <> nil then
    Result := FMemoryMap.BaseAddress
  else if FSharedMemory <> nil then
    Result := FSharedMemory.BaseAddress
  else
    Result := nil;
end;

function TMappedSlabPool.CalculateRequiredSize(aPoolSize: UInt64): UInt64;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
begin
  // 计算页面数量
  LPageCount := (aPoolSize + FPageSize - 1) div FPageSize;

  // 页面描述符大小（简化的 slab 页面结构）
  LPageDescriptorSize := LPageCount * 32; // 每个页面描述符32字节

  // 总大小 = 头部 + 页面描述符 + 数据区域
  Result := HEADER_SIZE + LPageDescriptorSize + aPoolSize;

  // 对齐到页面边界
  Result := ((Result + FPageSize - 1) div FPageSize) * FPageSize;
end;

procedure TMappedSlabPool.InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.Magic := SLAB_MAGIC;
  LHeader^.Version := SLAB_VERSION;
  LHeader^.PoolSize := aPoolSize;
  LHeader^.PageSize := aPageSize;
  LHeader^.MaxSizeClass := aMaxSizeClass;
  LHeader^.TotalPages := aPoolSize div aPageSize;
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;
  FillChar(LHeader^.Reserved, SizeOf(LHeader^.Reserved), 0);
end;

function TMappedSlabPool.ValidateHeader: Boolean;
var
  LHeader: PMappedSlabHeader;
begin
  Result := False;
  if FHeader = nil then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  if (LHeader^.Magic <> SLAB_MAGIC) or (LHeader^.Version <> SLAB_VERSION) then
    Exit;

  FPoolSize := LHeader^.PoolSize;
  FPageSize := LHeader^.PageSize;
  FMaxSizeClass := LHeader^.MaxSizeClass;
  Result := True;
end;

procedure TMappedSlabPool.InitializeSlabStructures;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
begin
  LPageCount := FPoolSize div FPageSize;
  LPageDescriptorSize := LPageCount * 32;

  // 设置内存布局指针
  FPages := Pointer(PByte(FHeader) + HEADER_SIZE);
  FDataArea := Pointer(PByte(FPages) + LPageDescriptorSize);

  // 初始化页面描述符（简化实现）
  if FIsCreator then
    FillChar(FPages^, LPageDescriptorSize, 0);
end;

function TMappedSlabPool.CreateFile(const aFileName: string; aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
begin
  Result := False;
  Close;

  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);

  FMemoryMap := TMemoryMap.Create;
  try
    // 尝试打开现有文件
    if FileExists(aFileName) then
    begin
      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;
      FIsCreator := False;
    end
    else
    begin
      // 创建新文件
      with TFileStream.Create(aFileName, fmCreate) do
      try
        Size := LRequiredSize;
      finally
        Free;
      end;

      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;
      FIsCreator := True;
    end;

    FMode := mspFile;
    FHeader := FMemoryMap.BaseAddress;

    if FIsCreator then
    begin
      InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass);
    end
    else
    begin
      if not ValidateHeader then Exit;
    end;

    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;

function TMappedSlabPool.OpenFile(const aFileName: string): Boolean;
begin
  Result := False;
  Close;

  if not FileExists(aFileName) then Exit;

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;

    FMode := mspFile;
    FIsCreator := False;
    FHeader := FMemoryMap.BaseAddress;

    if not ValidateHeader then Exit;
    InitializeSlabStructures;

    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;

function TMappedSlabPool.CreateShared(const aName: string; aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
begin
  Result := False;
  Close;

  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);

  FSharedMemory := TSharedMemory.Create;
  try
    if FSharedMemory.CreateShared(aName, LRequiredSize, mmaReadWrite) then
    begin
      FIsCreator := FSharedMemory.IsCreator;
    end
    else
    begin
      // 尝试打开已存在的
      if not FSharedMemory.OpenShared(aName, mmaReadWrite) then Exit;
      FIsCreator := False;
    end;

    FMode := mspShared;
    FHeader := FSharedMemory.BaseAddress;

    if FIsCreator then
    begin
      InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass);
    end
    else
    begin
      if not ValidateHeader then Exit;
    end;

    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;

function TMappedSlabPool.OpenShared(const aName: string): Boolean;
begin
  Result := False;
  Close;

  FSharedMemory := TSharedMemory.Create;
  try
    if not FSharedMemory.OpenShared(aName, mmaReadWrite) then Exit;

    FMode := mspShared;
    FIsCreator := False;
    FHeader := FSharedMemory.BaseAddress;

    if not ValidateHeader then Exit;
    InitializeSlabStructures;

    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;

function TMappedSlabPool.CreateAnonymous(aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
begin
  Result := False;
  Close;

  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.CreateAnonymous(LRequiredSize, mmaReadWrite) then Exit;

    FMode := mspAnonymous;
    FIsCreator := True;
    FHeader := FMemoryMap.BaseAddress;

    InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass);
    InitializeSlabStructures;

    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;

procedure TMappedSlabPool.Close;
begin
  FHeader := nil;
  FSlabData := nil;
  FPages := nil;
  FDataArea := nil;
  FPoolSize := 0;
  FIsCreator := False;

  if Assigned(FMemoryMap) then
  begin
    FMemoryMap.Free;
    FMemoryMap := nil;
  end;

  if Assigned(FSharedMemory) then
  begin
    FSharedMemory.Free;
    FSharedMemory := nil;
  end;
end;

function TMappedSlabPool.Alloc(aSize: UInt64): Pointer;
var
  LHeader: PMappedSlabHeader;
  LAlignedSize: UInt64;
  LPageIndex: UInt32;
  LOffset: UInt64;
begin
  Result := nil;
  if not IsValid or (aSize = 0) or (aSize > FMaxSizeClass) then
  begin
    if IsValid then
      Inc(PMappedSlabHeader(FHeader)^.FailedAllocs);
    Exit;
  end;

  LHeader := PMappedSlabHeader(FHeader);

  // 简化的分配算法：线性分配（实际应该实现完整的 slab 算法）
  LAlignedSize := (aSize + 7) and not 7; // 8字节对齐

  // 查找可用空间（简化实现）
  if LHeader^.UsedPages * FPageSize + LAlignedSize <= FPoolSize then
  begin
    LPageIndex := LHeader^.UsedPages;
    LOffset := (LPageIndex * FPageSize) + (LAlignedSize * (LHeader^.TotalAllocs mod (FPageSize div LAlignedSize)));

    if LOffset + LAlignedSize <= FPoolSize then
    begin
      Result := Pointer(PByte(FDataArea) + LOffset);
      Inc(LHeader^.TotalAllocs);

      // 简单的页面使用跟踪
      if (LHeader^.TotalAllocs mod (FPageSize div LAlignedSize)) = 0 then
        Inc(LHeader^.UsedPages);
    end
    else
      Inc(LHeader^.FailedAllocs);
  end
  else
    Inc(LHeader^.FailedAllocs);
end;

procedure TMappedSlabPool.FreeBlock(aPtr: Pointer);
var
  LHeader: PMappedSlabHeader;
begin
  if not IsValid or (aPtr = nil) then Exit;

  LHeader := PMappedSlabHeader(FHeader);

  // 简化的释放实现：只增加计数器
  // 实际应该实现完整的 slab 释放算法
  Inc(LHeader^.TotalFrees);
end;

function TMappedSlabPool.Flush: Boolean;
begin
  Result := False;
  if FMemoryMap <> nil then
    Result := FMemoryMap.Flush
  else if FSharedMemory <> nil then
    Result := FSharedMemory.Flush;
end;

function TMappedSlabPool.FlushRange(aOffset: UInt64; aSize: UInt64): Boolean;
begin
  Result := False;
  if FMemoryMap <> nil then
    Result := FMemoryMap.FlushRange(aOffset, aSize)
  else if FSharedMemory <> nil then
    Result := FSharedMemory.FlushRange(aOffset, aSize);
end;

procedure TMappedSlabPool.GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
  out aUsedPages, aTotalPages: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  if IsValid then
  begin
    LHeader := PMappedSlabHeader(FHeader);
    aTotalAllocs := LHeader^.TotalAllocs;
    aTotalFrees := LHeader^.TotalFrees;
    aFailedAllocs := LHeader^.FailedAllocs;
    aUsedPages := LHeader^.UsedPages;
    aTotalPages := LHeader^.TotalPages;
  end
  else
  begin
    aTotalAllocs := 0;
    aTotalFrees := 0;
    aFailedAllocs := 0;
    aUsedPages := 0;
    aTotalPages := 0;
  end;
end;

procedure TMappedSlabPool.Reset;
var
  LHeader: PMappedSlabHeader;
begin
  if not IsValid then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;

  // 重置页面描述符
  if FPages <> nil then
  begin
    FillChar(FPages^, (FPoolSize div FPageSize) * 32, 0);
  end;
end;

function TMappedSlabPool.IsValid: Boolean;
begin
  Result := (FHeader <> nil) and (FDataArea <> nil) and
            (FPoolSize > 0) and
            ((FMemoryMap <> nil) or (FSharedMemory <> nil));
end;

{ TMappedSlabPoolManager }

constructor TMappedSlabPoolManager.Create(aMode: TMappedSlabPoolMode;
  const aBasePath: string; const aSharedPrefix: string);
begin
  inherited Create;
  FLargeObjectThreshold := 4096*1024*1024; // 4GB
  FBasePath := aBasePath;
  FSharedPrefix := aSharedPrefix;

  // 复制默认池大小
  Move(DEFAULT_POOL_SIZES[0], FPoolSizes[0], SizeOf(DEFAULT_POOL_SIZES));

  InitializePools(aMode);
end;

destructor TMappedSlabPoolManager.Destroy;
begin
  DestroyPools;
  inherited Destroy;
end;

procedure TMappedSlabPoolManager.InitializePools(aMode: TMappedSlabPoolMode);
var
  LIndex: Integer;
  LFileName, LSharedName: string;
begin
  for LIndex := 0 to High(FPools) do
  begin
    FPools[LIndex] := TMappedSlabPool.Create;

    case aMode of
      mspFile:
      begin
        LFileName := FBasePath + Format('slab_pool_%d.dat', [LIndex]);
        FPools[LIndex].CreateFile(LFileName, FPoolSizes[LIndex]);
      end;
      mspShared:
      begin
        LSharedName := FSharedPrefix + Format('SlabPool_%d', [LIndex]);
        FPools[LIndex].CreateShared(LSharedName, FPoolSizes[LIndex]);
      end;
      mspAnonymous:
      begin
        FPools[LIndex].CreateAnonymous(FPoolSizes[LIndex]);
      end;
    end;
  end;
end;

procedure TMappedSlabPoolManager.DestroyPools;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FPools) do
  begin
    if Assigned(FPools[LIndex]) then
    begin
      // 避免与 TMappedSlabPool.Free(APtr: Pointer) 同名导致的方法解析歧义
      TObject(FPools[LIndex]).Free;
      FPools[LIndex] := nil;
    end;
  end;
end;

function TMappedSlabPoolManager.GetPoolForSize(aSize: UInt64): TMappedSlabPool;
var
  LIndex: Integer;
begin
  // 选择第一个能容纳该大小的池
  for LIndex := 0 to High(FPools) do
  begin
    if (aSize <= FPools[LIndex].MaxSizeClass) and FPools[LIndex].IsValid then
    begin
      Result := FPools[LIndex];
      Exit;
    end;
  end;

  // 如果没有合适的池，返回最大的池
  Result := FPools[High(FPools)];
end;

function TMappedSlabPoolManager.AllocAny(aSize: UInt64): Pointer;
var
  LPool: TMappedSlabPool;
begin
  if aSize > FLargeObjectThreshold then
  begin
    // 超大对象，使用系统分配器
    GetMem(Result, aSize);
  end
  else
  begin
    LPool := GetPoolForSize(aSize);
    if LPool <> nil then
      Result := LPool.Alloc(aSize)
    else
      Result := nil;
  end;
end;

{$PUSH}
{$WARN 4055 OFF} // 局部屏蔽：指针与整型转换
procedure TMappedSlabPoolManager.FreeAny(aPtr: Pointer);
var
  LIndex: Integer;
  LPool: TMappedSlabPool;
  LBaseAddr: Pointer;
  LPtrAddr: SizeUInt;
begin
  if aPtr = nil then Exit;

  // 尝试在各个池中查找该指针
  // 使用指针算术避免 4055 提示
  LPtrAddr := SizeUInt(aPtr); // 仅作无符号比较，不做算术
  for LIndex := 0 to High(FPools) do
  begin
    LPool := FPools[LIndex];
    if LPool.IsValid then
    begin
      LBaseAddr := LPool.BaseAddress;
      if (LPtrAddr >= SizeUInt(LBaseAddr)) and
         (LPtrAddr - SizeUInt(LBaseAddr) < LPool.PoolSize) then
      begin
        LPool.FreeBlock(aPtr);
        Exit;
      end;
    end;
  end;

  // 如果在池中找不到，假设是系统分配的大对象
  FreeMem(aPtr);
end;
{$POP}

function TMappedSlabPoolManager.FlushAll: Boolean;
var
  LIndex: Integer;
begin
  Result := True;
  for LIndex := 0 to High(FPools) do
  begin
    if FPools[LIndex].IsValid then
      Result := Result and FPools[LIndex].Flush;
  end;
end;

procedure TMappedSlabPoolManager.GetTotalStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
  out aUsedMemory, aTotalMemory: UInt64);
var
  LIndex: Integer;
  LAllocs, LFrees, LFailed: UInt64;
  LUsedPages, LTotalPages: UInt32;
begin
  aTotalAllocs := 0;
  aTotalFrees := 0;
  aFailedAllocs := 0;
  aUsedMemory := 0;
  aTotalMemory := 0;

  for LIndex := 0 to High(FPools) do
  begin
    if FPools[LIndex].IsValid then
    begin
      FPools[LIndex].GetStats(LAllocs, LFrees, LFailed, LUsedPages, LTotalPages);
      aTotalAllocs := aTotalAllocs + LAllocs;
      aTotalFrees := aTotalFrees + LFrees;
      aFailedAllocs := aFailedAllocs + LFailed;
      aUsedMemory := aUsedMemory + (LUsedPages * FPools[LIndex].PageSize);
      aTotalMemory := aTotalMemory + FPools[LIndex].PoolSize;
    end;
  end;
end;

end.
