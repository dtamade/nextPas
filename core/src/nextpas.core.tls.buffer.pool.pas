{**
 * Unit: nextpas.core.tls.buffer.pool
 * Purpose: 高性能内存缓冲区池 - 减少内存分配开销
 *
 * 架构升级 Phase 1: 零拷贝 I/O 优化
 *
 * 设计原则:
 * - 预分配缓冲区，避免频繁 malloc/free
 * - 三级缓冲区：Small(4KB), Medium(16KB), Large(64KB)
 * - 引用计数管理，自动回收
 * - 线程安全，支持高并发场景
 *
 * 性能目标:
 * - 减少 90%+ 内存分配
 * - 读取吞吐量提升 30-50%
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-02-05
 *}

unit nextpas.core.tls.buffer.pool;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{$modeswitch advancedrecords}

interface

uses
  SysUtils, SyncObjs;

const
  { 缓冲区大小级别 }
  BUFFER_SIZE_SMALL  = 4096;      // 4 KB - 小数据包
  BUFFER_SIZE_MEDIUM = 16384;     // 16 KB - 标准 TLS 记录
  BUFFER_SIZE_LARGE  = 65536;     // 64 KB - 大数据传输

  { 每级别预分配数量 }
  POOL_SIZE_SMALL  = 64;          // 256 KB 预分配
  POOL_SIZE_MEDIUM = 32;          // 512 KB 预分配
  POOL_SIZE_LARGE  = 8;           // 512 KB 预分配

  { 最大允许的缓冲区大小 }
  BUFFER_MAX_SIZE = 1048576;      // 1 MB

type
  { 缓冲区级别 }
  TBufferClass = (
    bcSmall,      // <= 4KB
    bcMedium,     // <= 16KB
    bcLarge,      // <= 64KB
    bcOversize    // > 64KB (直接分配)
  );

  { 池化缓冲区记录 }
  PPooledBuffer = ^TPooledBuffer;
  TPooledBuffer = record
  private
    FData: PByte;           // 数据指针
    FCapacity: Integer;     // 容量
    FLength: Integer;       // 当前使用长度
    FRefCount: Integer;     // 引用计数
    FBufferClass: TBufferClass;  // 缓冲区级别
    FPooled: Boolean;       // 是否来自池
    FInUse: Boolean;        // 是否正在使用
  public
    { 数据访问 }
    property Data: PByte read FData;
    property Capacity: Integer read FCapacity;
    property Length: Integer read FLength write FLength;
    property RefCount: Integer read FRefCount;
    property BufferClass: TBufferClass read FBufferClass;
    property IsPooled: Boolean read FPooled;

    { 数据操作 }
    procedure Clear;
    function Write(const ASrc; ACount: Integer): Integer;
    function Read(var ADst; ACount: Integer): Integer;
    function Append(const ASrc; ACount: Integer): Integer;

    { 转换 }
    function AsBytes: TBytes;
    function AsString: string;

    { 引用计数 (内部使用) }
    procedure AddRef;
    procedure Release;
  end;

  { 缓冲区池统计 }
  TBufferPoolStats = record
    TotalAllocations: Int64;      // 总分配次数
    PoolHits: Int64;              // 池命中次数
    PoolMisses: Int64;            // 池未命中次数
    OversizeAllocations: Int64;   // 超大缓冲区分配次数
    CurrentPooled: Integer;       // 当前池中数量
    CurrentInUse: Integer;        // 当前使用中数量
    PeakInUse: Integer;           // 峰值使用数量
    TotalBytesPooled: Int64;      // 池中总字节数
    TotalBytesInUse: Int64;       // 使用中总字节数

    function HitRate: Double;
  end;

  { 单级别缓冲区池 }
  TBufferPoolLevel = class
  private
    FLock: TCriticalSection;
    FBuffers: array of TPooledBuffer;
    FCapacity: Integer;
    FFreeCount: Integer;
    FBufferSize: Integer;
    FBufferClass: TBufferClass;
    FHits: Int64;
    FMisses: Int64;
  public
    constructor Create(ABufferSize, APoolSize: Integer; AClass: TBufferClass);
    destructor Destroy; override;

    function Acquire: PPooledBuffer;
    procedure Release(ABuffer: PPooledBuffer);

    property BufferSize: Integer read FBufferSize;
    property FreeCount: Integer read FFreeCount;
    property Hits: Int64 read FHits;
    property Misses: Int64 read FMisses;
  end;

  {**
   * TBufferPool - 全局缓冲区池
   *
   * 提供三级缓冲区池，自动选择合适大小的缓冲区。
   * 支持高并发场景，减少内存分配开销。
   *}
  TBufferPool = class
  private
    FSmallPool: TBufferPoolLevel;
    FMediumPool: TBufferPoolLevel;
    FLargePool: TBufferPoolLevel;
    FStats: TBufferPoolStats;
    FStatsLock: TCriticalSection;
    FEnabled: Boolean;

    function GetPoolForSize(ASize: Integer): TBufferPoolLevel;
    function ClassifySize(ASize: Integer): TBufferClass;
    procedure UpdateStats(AHit: Boolean; AClass: TBufferClass);

  public
    constructor Create;
    destructor Destroy; override;

    { 获取缓冲区 }
    function Acquire(AMinSize: Integer): PPooledBuffer;

    { 释放缓冲区 }
    procedure Release(ABuffer: PPooledBuffer);

    { 直接分配（不使用池）}
    function AllocateDirect(ASize: Integer): PPooledBuffer;
    procedure FreeDirect(ABuffer: PPooledBuffer);

    { 统计 }
    function GetStats: TBufferPoolStats;
    procedure ResetStats;

    { 配置 }
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

{ 全局缓冲区池单例 }
function GlobalBufferPool: TBufferPool;

{ 便捷函数 }
function AcquireBuffer(AMinSize: Integer): PPooledBuffer;
procedure ReleaseBuffer(ABuffer: PPooledBuffer);

implementation

var
  GBufferPool: TBufferPool = nil;
  GBufferPoolLock: TRTLCriticalSection;

{ ========================================================================
  TPooledBuffer
  ======================================================================== }

procedure TPooledBuffer.Clear;
begin
  FLength := 0;
  if FData <> nil then
    FillChar(FData^, FCapacity, 0);
end;

function TPooledBuffer.Write(const ASrc; ACount: Integer): Integer;
begin
  Result := ACount;
  if Result > FCapacity then
    Result := FCapacity;
  if Result > 0 then
  begin
    Move(ASrc, FData^, Result);
    FLength := Result;
  end;
end;

function TPooledBuffer.Read(var ADst; ACount: Integer): Integer;
begin
  Result := ACount;
  if Result > FLength then
    Result := FLength;
  if Result > 0 then
    Move(FData^, ADst, Result);
end;

function TPooledBuffer.Append(const ASrc; ACount: Integer): Integer;
var
  Available: Integer;
begin
  Available := FCapacity - FLength;
  Result := ACount;
  if Result > Available then
    Result := Available;
  if Result > 0 then
  begin
    Move(ASrc, (FData + FLength)^, Result);
    Inc(FLength, Result);
  end;
end;

function TPooledBuffer.AsBytes: TBytes;
begin
  SetLength(Result, FLength);
  if FLength > 0 then
    Move(FData^, Result[0], FLength);
end;

function TPooledBuffer.AsString: string;
begin
  SetString(Result, PAnsiChar(FData), FLength);
end;

procedure TPooledBuffer.AddRef;
begin
  InterlockedIncrement(FRefCount);
end;

procedure TPooledBuffer.Release;
begin
  if InterlockedDecrement(FRefCount) = 0 then
  begin
    if FPooled then
      GlobalBufferPool.Release(@Self)
    else
      GlobalBufferPool.FreeDirect(@Self);
  end;
end;

{ ========================================================================
  TBufferPoolStats
  ======================================================================== }

function TBufferPoolStats.HitRate: Double;
var
  Total: Int64;
begin
  Total := PoolHits + PoolMisses;
  if Total = 0 then
    Result := 0.0
  else
    Result := (PoolHits / Total) * 100.0;
end;

{ ========================================================================
  TBufferPoolLevel
  ======================================================================== }

constructor TBufferPoolLevel.Create(ABufferSize, APoolSize: Integer;
  AClass: TBufferClass);
var
  I: Integer;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FBufferSize := ABufferSize;
  FCapacity := APoolSize;
  FBufferClass := AClass;
  FFreeCount := APoolSize;
  FHits := 0;
  FMisses := 0;

  // 预分配缓冲区
  SetLength(FBuffers, APoolSize);
  for I := 0 to APoolSize - 1 do
  begin
    GetMem(FBuffers[I].FData, ABufferSize);
    FBuffers[I].FCapacity := ABufferSize;
    FBuffers[I].FLength := 0;
    FBuffers[I].FRefCount := 0;
    FBuffers[I].FBufferClass := AClass;
    FBuffers[I].FPooled := True;
    FBuffers[I].FInUse := False;
  end;
end;

destructor TBufferPoolLevel.Destroy;
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to Length(FBuffers) - 1 do
    begin
      if FBuffers[I].FData <> nil then
        FreeMem(FBuffers[I].FData);
    end;
    SetLength(FBuffers, 0);
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited Destroy;
end;

function TBufferPoolLevel.Acquire: PPooledBuffer;
var
  I: Integer;
begin
  Result := nil;
  FLock.Enter;
  try
    // 查找空闲缓冲区
    for I := 0 to Length(FBuffers) - 1 do
    begin
      if not FBuffers[I].FInUse then
      begin
        FBuffers[I].FInUse := True;
        FBuffers[I].FRefCount := 1;
        FBuffers[I].FLength := 0;
        Dec(FFreeCount);
        Inc(FHits);
        Result := @FBuffers[I];
        Exit;
      end;
    end;
    Inc(FMisses);
  finally
    FLock.Leave;
  end;
end;

procedure TBufferPoolLevel.Release(ABuffer: PPooledBuffer);
begin
  if ABuffer = nil then Exit;

  FLock.Enter;
  try
    ABuffer^.FInUse := False;
    ABuffer^.FRefCount := 0;
    ABuffer^.FLength := 0;
    Inc(FFreeCount);
  finally
    FLock.Leave;
  end;
end;

{ ========================================================================
  TBufferPool
  ======================================================================== }

constructor TBufferPool.Create;
begin
  inherited Create;
  FStatsLock := TCriticalSection.Create;
  FEnabled := True;

  // 创建三级缓冲区池
  FSmallPool := TBufferPoolLevel.Create(BUFFER_SIZE_SMALL, POOL_SIZE_SMALL, bcSmall);
  FMediumPool := TBufferPoolLevel.Create(BUFFER_SIZE_MEDIUM, POOL_SIZE_MEDIUM, bcMedium);
  FLargePool := TBufferPoolLevel.Create(BUFFER_SIZE_LARGE, POOL_SIZE_LARGE, bcLarge);

  // 初始化统计
  FillChar(FStats, SizeOf(FStats), 0);
  FStats.TotalBytesPooled :=
    (POOL_SIZE_SMALL * BUFFER_SIZE_SMALL) +
    (POOL_SIZE_MEDIUM * BUFFER_SIZE_MEDIUM) +
    (POOL_SIZE_LARGE * BUFFER_SIZE_LARGE);
end;

destructor TBufferPool.Destroy;
begin
  FSmallPool.Free;
  FMediumPool.Free;
  FLargePool.Free;
  FStatsLock.Free;
  inherited Destroy;
end;

function TBufferPool.ClassifySize(ASize: Integer): TBufferClass;
begin
  if ASize <= BUFFER_SIZE_SMALL then
    Result := bcSmall
  else if ASize <= BUFFER_SIZE_MEDIUM then
    Result := bcMedium
  else if ASize <= BUFFER_SIZE_LARGE then
    Result := bcLarge
  else
    Result := bcOversize;
end;

function TBufferPool.GetPoolForSize(ASize: Integer): TBufferPoolLevel;
begin
  case ClassifySize(ASize) of
    bcSmall:  Result := FSmallPool;
    bcMedium: Result := FMediumPool;
    bcLarge:  Result := FLargePool;
  else
    Result := nil;
  end;
end;

procedure TBufferPool.UpdateStats(AHit: Boolean; AClass: TBufferClass);
begin
  FStatsLock.Enter;
  try
    Inc(FStats.TotalAllocations);
    if AHit then
      Inc(FStats.PoolHits)
    else
      Inc(FStats.PoolMisses);

    if AClass = bcOversize then
      Inc(FStats.OversizeAllocations);

    // 更新当前使用数量
    FStats.CurrentInUse :=
      (POOL_SIZE_SMALL - FSmallPool.FreeCount) +
      (POOL_SIZE_MEDIUM - FMediumPool.FreeCount) +
      (POOL_SIZE_LARGE - FLargePool.FreeCount);

    if FStats.CurrentInUse > FStats.PeakInUse then
      FStats.PeakInUse := FStats.CurrentInUse;

    FStats.CurrentPooled :=
      FSmallPool.FreeCount + FMediumPool.FreeCount + FLargePool.FreeCount;

  finally
    FStatsLock.Leave;
  end;
end;

function TBufferPool.Acquire(AMinSize: Integer): PPooledBuffer;
var
  Pool: TBufferPoolLevel;
  BufClass: TBufferClass;
begin
  Result := nil;

  if not FEnabled then
  begin
    Result := AllocateDirect(AMinSize);
    Exit;
  end;

  BufClass := ClassifySize(AMinSize);

  // 超大缓冲区直接分配
  if BufClass = bcOversize then
  begin
    Result := AllocateDirect(AMinSize);
    UpdateStats(False, bcOversize);
    Exit;
  end;

  // 从对应池获取
  Pool := GetPoolForSize(AMinSize);
  if Pool <> nil then
    Result := Pool.Acquire;

  // 池耗尽时尝试更大级别
  if Result = nil then
  begin
    case BufClass of
      bcSmall:
      begin
        Result := FMediumPool.Acquire;
        if Result = nil then
          Result := FLargePool.Acquire;
      end;
      bcMedium:
        Result := FLargePool.Acquire;
    else
      ;
    end;
  end;

  // 所有池都耗尽，直接分配
  if Result = nil then
  begin
    Result := AllocateDirect(AMinSize);
    UpdateStats(False, BufClass);
  end
  else
    UpdateStats(True, BufClass);
end;

procedure TBufferPool.Release(ABuffer: PPooledBuffer);
var
  Pool: TBufferPoolLevel;
begin
  if ABuffer = nil then Exit;

  if not ABuffer^.FPooled then
  begin
    FreeDirect(ABuffer);
    Exit;
  end;

  Pool := GetPoolForSize(ABuffer^.FCapacity);
  if Pool <> nil then
    Pool.Release(ABuffer);
end;

function TBufferPool.AllocateDirect(ASize: Integer): PPooledBuffer;
begin
  New(Result);
  GetMem(Result^.FData, ASize);
  Result^.FCapacity := ASize;
  Result^.FLength := 0;
  Result^.FRefCount := 1;
  Result^.FBufferClass := bcOversize;
  Result^.FPooled := False;
  Result^.FInUse := True;
end;

procedure TBufferPool.FreeDirect(ABuffer: PPooledBuffer);
begin
  if ABuffer = nil then Exit;
  if ABuffer^.FData <> nil then
    FreeMem(ABuffer^.FData);
  Dispose(ABuffer);
end;

function TBufferPool.GetStats: TBufferPoolStats;
begin
  FStatsLock.Enter;
  try
    Result := FStats;
    Result.CurrentPooled :=
      FSmallPool.FreeCount + FMediumPool.FreeCount + FLargePool.FreeCount;
    Result.CurrentInUse :=
      (POOL_SIZE_SMALL - FSmallPool.FreeCount) +
      (POOL_SIZE_MEDIUM - FMediumPool.FreeCount) +
      (POOL_SIZE_LARGE - FLargePool.FreeCount);
  finally
    FStatsLock.Leave;
  end;
end;

procedure TBufferPool.ResetStats;
begin
  FStatsLock.Enter;
  try
    FStats.TotalAllocations := 0;
    FStats.PoolHits := 0;
    FStats.PoolMisses := 0;
    FStats.OversizeAllocations := 0;
    FStats.PeakInUse := 0;
  finally
    FStatsLock.Leave;
  end;
end;

{ ========================================================================
  全局函数
  ======================================================================== }

function GlobalBufferPool: TBufferPool;
begin
  if GBufferPool = nil then
  begin
    EnterCriticalSection(GBufferPoolLock);
    try
      if GBufferPool = nil then
        GBufferPool := TBufferPool.Create;
    finally
      LeaveCriticalSection(GBufferPoolLock);
    end;
  end;
  Result := GBufferPool;
end;

function AcquireBuffer(AMinSize: Integer): PPooledBuffer;
begin
  Result := GlobalBufferPool.Acquire(AMinSize);
end;

procedure ReleaseBuffer(ABuffer: PPooledBuffer);
begin
  GlobalBufferPool.Release(ABuffer);
end;

initialization
  InitCriticalSection(GBufferPoolLock);

finalization
  FreeAndNil(GBufferPool);
  DoneCriticalSection(GBufferPoolLock);

end.
