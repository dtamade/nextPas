{$CODEPAGE UTF8}
unit nextpas.core.mem.mapped_slab_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils, nextpas.core.mem.memory_map;

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
    function GetPageDescriptor(aPageIndex: UInt32): Pointer;
    function DataOffsetToPointer(aOffset: UInt64): Pointer;
    function PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
    function PageUsableSize(aPageIndex: UInt32): UInt32;
    function CanAllocate(aSize: UInt64): Boolean;
    function CurrentMappingSize: UInt64;
    function TryCalculateRequiredSize(aPoolSize: UInt64; aPageSize: UInt32;
      out aRequiredSize: UInt64; out aTotalPages: UInt32): Boolean;
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
    FLargeFallbacks: array of Pointer;       // manager-owned system fallback blocks

    function GetPoolForSize(aSize: UInt64): TMappedSlabPool;
    function GetMaxValidSizeClass: UInt64;
    function AllocLargeFallback(aSize: UInt64): Pointer;
    procedure TrackLargeFallback(aPtr: Pointer);
    function UntrackLargeFallback(aPtr: Pointer): Boolean;
    procedure FreeLargeFallbacks;
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
  nextpas.core.mem.error,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

const
  // 内存布局常量
  HEADER_SIZE = 128;         // 头部大小
  SLAB_MAGIC = $534C4142;    // 'SLAB' 魔数
  SLAB_VERSION = 2;          // 版本号
  BLOCK_MAGIC = $4D53424C;   // 'MSBL' block magic
  BLOCK_STATE_FREE = 0;
  BLOCK_STATE_USED = 1;
  NO_FREE_OFFSET = High(UInt64);

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

function MappedSlabPoolIndexedName(const aPrefix: string; aIndex: Integer; const aSuffix: string): string;
var
  LIndexText: string;
begin
  Str(aIndex, LIndexText);
  Result := aPrefix + LIndexText + aSuffix;
end;

function MappedSlabPoolFileExists(const aFileName: string): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := (aFileName <> '') and (platform_file_stat(PAnsiChar(aFileName), LStat) = 0);
end;

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
    ResetGeneration: UInt32; // Reset 后旧指针失效
    Reserved: array[0..27] of Byte; // 保留字段
  end;

  PMappedSlabPage = ^TMappedSlabPage;
  TMappedSlabPage = packed record
    BlockSize: UInt32;       // payload size class, 0 means unused page
    BlockCapacity: UInt32;   // max blocks in this page
    AllocatedCount: UInt32;  // currently checked-out blocks
    FreeCount: UInt32;       // blocks in free list
    FreeHeadOffset: UInt64;  // offset of block header from FDataArea
    BumpOffset: UInt32;      // next uninitialized byte within page
    Generation: UInt32;      // copied from header reset generation
  end;

  PMappedSlabBlockHeader = ^TMappedSlabBlockHeader;
  TMappedSlabBlockHeader = packed record
    Magic: UInt32;
    PageIndex: UInt32;
    BlockSize: UInt32;
    RequestedSize: UInt32;
    State: UInt32;
    Generation: UInt32;
    NextFreeOffset: UInt64;
  end;

function TryAddU64(A, B: UInt64; out AResult: UInt64): Boolean; inline;
begin
  Result := A <= High(UInt64) - B;
  if Result then
    AResult := A + B
  else
    AResult := 0;
end;

function TryMulU64(A, B: UInt64; out AResult: UInt64): Boolean; inline;
begin
  Result := (A = 0) or (B <= High(UInt64) div A);
  if Result then
    AResult := A * B
  else
    AResult := 0;
end;

function TryRoundUpU64(AValue: UInt64; AAlignment: UInt32; out AResult: UInt64): Boolean; inline;
var
  LAdjusted: UInt64;
  LAlignment: UInt64;
begin
  AResult := 0;
  if AAlignment = 0 then
    Exit(False);

  LAlignment := AAlignment;
  if not TryAddU64(AValue, LAlignment - 1, LAdjusted) then
    Exit(False);

  AResult := (LAdjusted div LAlignment) * LAlignment;
  Result := True;
end;

function IsValidMappedSlabMaxSizeClass(AMaxSizeClass: UInt32): Boolean; inline;
begin
  Result := (AMaxSizeClass > 0) and
    (UInt64(AMaxSizeClass) <= High(UInt32) - SizeOf(TMappedSlabBlockHeader) - 7);
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

function TMappedSlabPool.GetPageDescriptor(aPageIndex: UInt32): Pointer;
begin
  Result := Pointer(PByte(FPages) + SizeUInt(aPageIndex) * SizeOf(TMappedSlabPage));
end;

function TMappedSlabPool.DataOffsetToPointer(aOffset: UInt64): Pointer;
begin
  Result := Pointer(PByte(FDataArea) + SizeUInt(aOffset));
end;

function TMappedSlabPool.PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
var
  LBase: PtrUInt;
  LPtr: PtrUInt;
begin
  Result := False;
  aOffset := 0;
  if (aPtr = nil) or (FDataArea = nil) then Exit;

  LBase := PtrUInt(FDataArea);
  LPtr := PtrUInt(aPtr);
  if LPtr < LBase then Exit;
  aOffset := UInt64(LPtr - LBase);
  Result := aOffset < FPoolSize;
end;

function TMappedSlabPool.PageUsableSize(aPageIndex: UInt32): UInt32;
var
  LPageStart: UInt64;
  LRemaining: UInt64;
begin
  LPageStart := UInt64(aPageIndex) * UInt64(FPageSize);
  if LPageStart >= FPoolSize then
    Exit(0);
  LRemaining := FPoolSize - LPageStart;
  if LRemaining > FPageSize then
    Result := FPageSize
  else
    Result := UInt32(LRemaining);
end;

function TMappedSlabPool.CanAllocate(aSize: UInt64): Boolean;
var
  LHeader: PMappedSlabHeader;
  LBlockSize: UInt32;
  LBlockBytes: UInt32;
  LPageIndex: UInt32;
  LPage: PMappedSlabPage;
  LPageUsable: UInt32;
begin
  Result := False;
  if not IsValid then Exit;

  if (aSize = 0) or (aSize > FMaxSizeClass) or
     (aSize > UInt64(High(UInt32)) - SizeOf(TMappedSlabBlockHeader) - 7) then
    Exit;

  LHeader := PMappedSlabHeader(FHeader);
  LBlockSize := UInt32((aSize + 7) and not UInt64(7));
  LBlockBytes := LBlockSize + SizeOf(TMappedSlabBlockHeader);

  for LPageIndex := 0 to LHeader^.TotalPages - 1 do
  begin
    LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
    LPageUsable := PageUsableSize(LPageIndex);

    if (LPage^.BlockSize = LBlockSize) and
       ((LPage^.FreeHeadOffset <> NO_FREE_OFFSET) or
        (UInt64(LPage^.BumpOffset) + LBlockBytes <= LPageUsable)) then
      Exit(True);

    if (LPage^.BlockSize = 0) and (LBlockBytes <= LPageUsable) then
      Exit(True);
  end;
end;

function TMappedSlabPool.CurrentMappingSize: UInt64;
begin
  if FMemoryMap <> nil then
    Exit(FMemoryMap.Size);
  if FSharedMemory <> nil then
    Exit(FSharedMemory.Size);
  Result := 0;
end;

function TMappedSlabPool.TryCalculateRequiredSize(aPoolSize: UInt64;
  aPageSize: UInt32; out aRequiredSize: UInt64; out aTotalPages: UInt32): Boolean;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
  LLayoutSize: UInt64;
begin
  aRequiredSize := 0;
  aTotalPages := 0;
  Result := False;

  if (aPoolSize = 0) or (aPageSize = 0) then
    Exit;

  LPageCount := aPoolSize div aPageSize;
  if (aPoolSize mod aPageSize) <> 0 then
    Inc(LPageCount);
  if (LPageCount = 0) or (LPageCount > High(UInt32)) then
    Exit;

  if not TryMulU64(LPageCount, SizeOf(TMappedSlabPage), LPageDescriptorSize) then
    Exit;
  if not TryAddU64(HEADER_SIZE, LPageDescriptorSize, LLayoutSize) then
    Exit;
  if not TryAddU64(LLayoutSize, aPoolSize, LLayoutSize) then
    Exit;
  if not TryRoundUpU64(LLayoutSize, aPageSize, aRequiredSize) then
    Exit;

  aTotalPages := UInt32(LPageCount);
  Result := True;
end;

function TMappedSlabPool.CalculateRequiredSize(aPoolSize: UInt64): UInt64;
var
  LTotalPages: UInt32;
begin
  if not TryCalculateRequiredSize(aPoolSize, FPageSize, Result, LTotalPages) then
    Result := 0;
end;

procedure TMappedSlabPool.InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  FPoolSize := aPoolSize;
  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;

  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.Magic := SLAB_MAGIC;
  LHeader^.Version := SLAB_VERSION;
  LHeader^.PoolSize := aPoolSize;
  LHeader^.PageSize := aPageSize;
  LHeader^.MaxSizeClass := aMaxSizeClass;
  LHeader^.TotalPages := (aPoolSize + aPageSize - 1) div aPageSize;
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;
  LHeader^.ResetGeneration := 1;
  FillChar(LHeader^.Reserved, SizeOf(LHeader^.Reserved), 0);
end;

function TMappedSlabPool.ValidateHeader: Boolean;
var
  LHeader: PMappedSlabHeader;
  LPoolSize: UInt64;
  LPageSize: UInt32;
  LMaxSizeClass: UInt32;
  LTotalPages: UInt32;
  LRequiredSize: UInt64;
begin
  Result := False;
  if FHeader = nil then Exit;
  if CurrentMappingSize < HEADER_SIZE then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  if (LHeader^.Magic <> SLAB_MAGIC) or (LHeader^.Version <> SLAB_VERSION) then
    Exit;

  LPoolSize := LHeader^.PoolSize;
  LPageSize := LHeader^.PageSize;
  LMaxSizeClass := LHeader^.MaxSizeClass;

  if not TryCalculateRequiredSize(LPoolSize, LPageSize, LRequiredSize, LTotalPages) then
    Exit;
  if LHeader^.TotalPages <> LTotalPages then
    Exit;
  if LHeader^.UsedPages > LHeader^.TotalPages then
    Exit;
  if LHeader^.ResetGeneration = 0 then
    Exit;
  if CurrentMappingSize < LRequiredSize then
    Exit;

  if not IsValidMappedSlabMaxSizeClass(LMaxSizeClass) then
    Exit;

  FPoolSize := LPoolSize;
  FPageSize := LPageSize;
  FMaxSizeClass := LMaxSizeClass;
  Result := True;
end;

procedure TMappedSlabPool.InitializeSlabStructures;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
begin
  LPageCount := (FPoolSize + FPageSize - 1) div FPageSize;
  LPageDescriptorSize := LPageCount * SizeOf(TMappedSlabPage);

  // 设置内存布局指针
  FPages := Pointer(PByte(FHeader) + HEADER_SIZE);
  FDataArea := Pointer(PByte(FPages) + LPageDescriptorSize);
  FSlabData := FDataArea;

  // 初始化页面描述符。描述符必须只含相对 offset，避免映射地址变化后失效。
  if FIsCreator then
    FillChar(FPages^, LPageDescriptorSize, 0);
end;

function TMappedSlabPool.CreateFile(const aFileName: string; aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
  LTotalPages: UInt32;
  LFileHandle: TPlatformFileHandle;
begin
  Result := False;
  Close;

  FMemoryMap := TMemoryMap.Create;
  try
    // 尝试打开现有文件
    if MappedSlabPoolFileExists(aFileName) then
    begin
      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then
      begin
        Close;
        Exit;
      end;
      FIsCreator := False;
    end
    else
    begin
      if (not IsValidMappedSlabMaxSizeClass(aMaxSizeClass)) or
         (not TryCalculateRequiredSize(aPoolSize, aPageSize, LRequiredSize, LTotalPages)) then
      begin
        Close;
        Exit;
      end;

      // 创建新文件并设置大小
      if platform_file_open(PAnsiChar(aFileName), fomReadWrite, fcmCreateAlways, LFileHandle) <> 0 then
      begin
        Close;
        Exit;
      end;
      if platform_file_truncate(LFileHandle, LRequiredSize) <> 0 then
      begin
        platform_file_close(LFileHandle);
        Close;
        Exit;
      end;
      platform_file_close(LFileHandle);

      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then
      begin
        Close;
        Exit;
      end;
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
      if not ValidateHeader then
      begin
        Close;
        Exit;
      end;
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

  if not MappedSlabPoolFileExists(aFileName) then Exit;

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then
    begin
      Close;
      Exit;
    end;

    FMode := mspFile;
    FIsCreator := False;
    FHeader := FMemoryMap.BaseAddress;

    if not ValidateHeader then
    begin
      Close;
      Exit;
    end;
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
  LTotalPages: UInt32;
begin
  Result := False;
  Close;

  FSharedMemory := TSharedMemory.Create;
  try
    if FSharedMemory.OpenShared(aName, mmaReadWrite) then
    begin
      FIsCreator := False;
    end
    else
    begin
      if (not IsValidMappedSlabMaxSizeClass(aMaxSizeClass)) or
         (not TryCalculateRequiredSize(aPoolSize, aPageSize, LRequiredSize, LTotalPages)) then
      begin
        Close;
        Exit;
      end;

      FPageSize := aPageSize;
      FMaxSizeClass := aMaxSizeClass;
      if not FSharedMemory.CreateShared(aName, LRequiredSize, mmaReadWrite) then
      begin
        Close;
        Exit;
      end;
      FIsCreator := FSharedMemory.IsCreator;
      if not FIsCreator then
      begin
        FSharedMemory.Close;
        if not FSharedMemory.OpenShared(aName, mmaReadWrite) then
        begin
          Close;
          Exit;
        end;
      end;
    end;

    if (not FIsCreator) and (not FSharedMemory.IsValid) then
    begin
      Close;
      Exit;
    end;

    FMode := mspShared;
    FHeader := FSharedMemory.BaseAddress;

    if FIsCreator then
    begin
      InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass);
    end
    else
    begin
      if not ValidateHeader then
      begin
        Close;
        Exit;
      end;
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
    if not FSharedMemory.OpenShared(aName, mmaReadWrite) then
    begin
      Close;
      Exit;
    end;

    FMode := mspShared;
    FIsCreator := False;
    FHeader := FSharedMemory.BaseAddress;

    if not ValidateHeader then
    begin
      Close;
      Exit;
    end;
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
  LTotalPages: UInt32;
begin
  Result := False;
  Close;

  if (not IsValidMappedSlabMaxSizeClass(aMaxSizeClass)) or
     (not TryCalculateRequiredSize(aPoolSize, aPageSize, LRequiredSize, LTotalPages)) then
    Exit;

  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.CreateAnonymous(LRequiredSize, mmaReadWrite) then
    begin
      Close;
      Exit;
    end;

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
  LBlockSize: UInt32;
  LBlockBytes: UInt32;
  LPageIndex: UInt32;
  LChosenPageIndex: UInt32;
  LPage: PMappedSlabPage;
  LChosenPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
  LBlockOffset: UInt64;
  LPageStart: UInt64;
  LPageUsable: UInt32;
  LFound: Boolean;
begin
  Result := nil;
  if not IsValid then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  if (aSize = 0) or (aSize > FMaxSizeClass) or
     (aSize > UInt64(High(UInt32)) - SizeOf(TMappedSlabBlockHeader) - 7) then
  begin
    Inc(LHeader^.FailedAllocs);
    Exit;
  end;

  LBlockSize := UInt32((aSize + 7) and not UInt64(7));
  LBlockBytes := LBlockSize + SizeOf(TMappedSlabBlockHeader);

  LFound := False;
  LChosenPage := nil;
  LChosenPageIndex := 0;

  for LPageIndex := 0 to LHeader^.TotalPages - 1 do
  begin
    LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
    LPageUsable := PageUsableSize(LPageIndex);

    if (LPage^.BlockSize = LBlockSize) and
       ((LPage^.FreeHeadOffset <> NO_FREE_OFFSET) or
        (UInt64(LPage^.BumpOffset) + LBlockBytes <= LPageUsable)) then
    begin
      LChosenPage := LPage;
      LChosenPageIndex := LPageIndex;
      LFound := True;
      Break;
    end;

    if (not LFound) and (LChosenPage = nil) and (LPage^.BlockSize = 0) and
       (LBlockBytes <= LPageUsable) then
    begin
      LChosenPage := LPage;
      LChosenPageIndex := LPageIndex;
    end;
  end;

  if LChosenPage = nil then
  begin
    Inc(LHeader^.FailedAllocs);
    Exit;
  end;

  if not LFound then
  begin
    LPageUsable := PageUsableSize(LChosenPageIndex);
    FillChar(LChosenPage^, SizeOf(TMappedSlabPage), 0);
    LChosenPage^.BlockSize := LBlockSize;
    LChosenPage^.BlockCapacity := LPageUsable div LBlockBytes;
    LChosenPage^.FreeHeadOffset := NO_FREE_OFFSET;
    LChosenPage^.Generation := LHeader^.ResetGeneration;
    Inc(LHeader^.UsedPages);
  end;

  if LChosenPage^.FreeHeadOffset <> NO_FREE_OFFSET then
  begin
    LBlockOffset := LChosenPage^.FreeHeadOffset;
    LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
    if (LBlock^.Magic <> BLOCK_MAGIC) or
       (LBlock^.PageIndex <> LChosenPageIndex) or
       (LBlock^.BlockSize <> LBlockSize) or
       (LBlock^.State <> BLOCK_STATE_FREE) or
       (LBlock^.Generation <> LChosenPage^.Generation) then
    begin
      Inc(LHeader^.FailedAllocs);
      Exit;
    end;
    LChosenPage^.FreeHeadOffset := LBlock^.NextFreeOffset;
    Dec(LChosenPage^.FreeCount);
  end
  else
  begin
    LPageUsable := PageUsableSize(LChosenPageIndex);
    if UInt64(LChosenPage^.BumpOffset) + LBlockBytes > LPageUsable then
    begin
      Inc(LHeader^.FailedAllocs);
      Exit;
    end;

    LPageStart := UInt64(LChosenPageIndex) * UInt64(FPageSize);
    LBlockOffset := LPageStart + LChosenPage^.BumpOffset;
    LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
    Inc(LChosenPage^.BumpOffset, LBlockBytes);
  end;

  LBlock^.Magic := BLOCK_MAGIC;
  LBlock^.PageIndex := LChosenPageIndex;
  LBlock^.BlockSize := LBlockSize;
  LBlock^.RequestedSize := UInt32(aSize);
  LBlock^.State := BLOCK_STATE_USED;
  LBlock^.Generation := LChosenPage^.Generation;
  LBlock^.NextFreeOffset := NO_FREE_OFFSET;

  Inc(LChosenPage^.AllocatedCount);
  Inc(LHeader^.TotalAllocs);
  Result := Pointer(PByte(LBlock) + SizeOf(TMappedSlabBlockHeader));
end;

procedure TMappedSlabPool.FreeBlock(aPtr: Pointer);
var
  LHeader: PMappedSlabHeader;
  LPayloadOffset: UInt64;
  LBlockOffset: UInt64;
  LPageIndex: UInt32;
  LPageStart: UInt64;
  LWithinPage: UInt64;
  LBlockStride: UInt32;
  LPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
begin
  if aPtr = nil then Exit;
  if not IsValid then
    raise EAllocError.Create(aePoolClosed, 'TMappedSlabPool.FreeBlock: pool is not valid');

  LHeader := PMappedSlabHeader(FHeader);
  if (not PointerToDataOffset(aPtr, LPayloadOffset)) or
     (LPayloadOffset < SizeOf(TMappedSlabBlockHeader)) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: pointer is not from this pool');

  LBlockOffset := LPayloadOffset - SizeOf(TMappedSlabBlockHeader);
  LPageIndex := LBlockOffset div FPageSize;
  if LPageIndex >= LHeader^.TotalPages then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: page index out of range');

  LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
  if (LPage^.BlockSize = 0) or (LPage^.Generation <> LHeader^.ResetGeneration) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: stale or unowned pointer');

  LPageStart := UInt64(LPageIndex) * UInt64(FPageSize);
  LBlockStride := LPage^.BlockSize + SizeOf(TMappedSlabBlockHeader);
  LWithinPage := LBlockOffset - LPageStart;
  if (LBlockStride = 0) or (LWithinPage mod LBlockStride <> 0) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: pointer is not a block payload');

  LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
  if (LBlock^.Magic <> BLOCK_MAGIC) or
     (LBlock^.PageIndex <> LPageIndex) or
     (LBlock^.BlockSize <> LPage^.BlockSize) or
     (LBlock^.Generation <> LPage^.Generation) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: invalid block header');

  if LBlock^.State = BLOCK_STATE_FREE then
    raise EAllocError.Create(aeDoubleFree, 'TMappedSlabPool.FreeBlock: double free detected');
  if LBlock^.State <> BLOCK_STATE_USED then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: invalid block state');

  LBlock^.State := BLOCK_STATE_FREE;
  LBlock^.NextFreeOffset := LPage^.FreeHeadOffset;
  LPage^.FreeHeadOffset := LBlockOffset;
  Inc(LPage^.FreeCount);
  if LPage^.AllocatedCount > 0 then
    Dec(LPage^.AllocatedCount);
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
  LPageDescriptorSize: UInt64;
begin
  if not IsValid then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;
  Inc(LHeader^.ResetGeneration);
  if LHeader^.ResetGeneration = 0 then
    LHeader^.ResetGeneration := 1;

  // 重置页面描述符
  if FPages <> nil then
  begin
    LPageDescriptorSize := UInt64(LHeader^.TotalPages) * SizeOf(TMappedSlabPage);
    FillChar(FPages^, LPageDescriptorSize, 0);
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
  FreeLargeFallbacks;
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
        LFileName := FBasePath + MappedSlabPoolIndexedName('slab_pool_', LIndex, '.dat');
        FPools[LIndex].CreateFile(LFileName, FPoolSizes[LIndex]);
      end;
      mspShared:
      begin
        LSharedName := FSharedPrefix + MappedSlabPoolIndexedName('SlabPool_', LIndex, '');
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

  Result := nil;
end;

function TMappedSlabPoolManager.GetMaxValidSizeClass: UInt64;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to High(FPools) do
  begin
    if (FPools[LIndex] <> nil) and FPools[LIndex].IsValid and
       (UInt64(FPools[LIndex].MaxSizeClass) > Result) then
      Result := FPools[LIndex].MaxSizeClass;
  end;
end;

function TMappedSlabPoolManager.AllocLargeFallback(aSize: UInt64): Pointer;
begin
  Result := nil;
  if aSize = 0 then Exit;
  {$IFNDEF CPU64}
  if aSize > UInt64(High(SizeUInt)) then Exit;
  {$ENDIF}

  GetMem(Result, SizeUInt(aSize));
  if Result <> nil then
  begin
    try
      TrackLargeFallback(Result);
    except
      FreeMem(Result);
      Result := nil;
      raise;
    end;
  end;
end;

procedure TMappedSlabPoolManager.TrackLargeFallback(aPtr: Pointer);
var
  LIndex: Integer;
  LCount: Integer;
begin
  if aPtr = nil then Exit;

  for LIndex := 0 to High(FLargeFallbacks) do
  begin
    if FLargeFallbacks[LIndex] = nil then
    begin
      FLargeFallbacks[LIndex] := aPtr;
      Exit;
    end;
  end;

  LCount := Length(FLargeFallbacks);
  SetLength(FLargeFallbacks, LCount + 1);
  FLargeFallbacks[LCount] := aPtr;
end;

function TMappedSlabPoolManager.UntrackLargeFallback(aPtr: Pointer): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  Result := False;
  if aPtr = nil then Exit;

  for LIndex := 0 to High(FLargeFallbacks) do
  begin
    if FLargeFallbacks[LIndex] = aPtr then
    begin
      LLast := High(FLargeFallbacks);
      FLargeFallbacks[LIndex] := FLargeFallbacks[LLast];
      SetLength(FLargeFallbacks, LLast);
      Exit(True);
    end;
  end;
end;

procedure TMappedSlabPoolManager.FreeLargeFallbacks;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FLargeFallbacks) do
  begin
    if FLargeFallbacks[LIndex] <> nil then
      FreeMem(FLargeFallbacks[LIndex]);
  end;
  SetLength(FLargeFallbacks, 0);
end;

function TMappedSlabPoolManager.AllocAny(aSize: UInt64): Pointer;
var
  LIndex: Integer;
  LMaxSizeClass: UInt64;
  LPool: TMappedSlabPool;
begin
  if aSize > FLargeObjectThreshold then
    Exit(AllocLargeFallback(aSize));

  for LIndex := 0 to High(FPools) do
  begin
    if (FPools[LIndex] <> nil) and FPools[LIndex].IsValid and
       (aSize <= FPools[LIndex].MaxSizeClass) and
       FPools[LIndex].CanAllocate(aSize) then
    begin
      Result := FPools[LIndex].Alloc(aSize);
      if Result <> nil then
        Exit;
    end;
  end;

  LMaxSizeClass := GetMaxValidSizeClass;
  if (aSize > LMaxSizeClass) and (LMaxSizeClass > 0) then
    Result := AllocLargeFallback(aSize)
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
  LMappedSize: UInt64;
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
      LBaseAddr := LPool.FDataArea;
      if (LBaseAddr <> nil) and
         (LPtrAddr >= SizeUInt(LBaseAddr)) and
         (LPtrAddr - SizeUInt(LBaseAddr) < LPool.PoolSize) then
      begin
        LPool.FreeBlock(aPtr);
        Exit;
      end;

      LBaseAddr := LPool.BaseAddress;
      LMappedSize := LPool.CalculateRequiredSize(LPool.PoolSize);
      if (LBaseAddr <> nil) and
         (LPtrAddr >= SizeUInt(LBaseAddr)) and
         (UInt64(LPtrAddr - SizeUInt(LBaseAddr)) < LMappedSize) then
        raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPoolManager.FreeAny: pointer is not a pool block');
    end;
  end;

  if UntrackLargeFallback(aPtr) then
  begin
    FreeMem(aPtr);
    Exit;
  end;

  raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPoolManager.FreeAny: pointer is not owned by this manager');
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
