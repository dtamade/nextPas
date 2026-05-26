{
  # nextpas.core.mem.stats

  统计助手：为现有内存池类提供只读统计快照（不修改原类，不引入行为变化）。
}

unit nextpas.core.mem.stats;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.mem_pool,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.pool.slab;

// 通用统计记录

type
  TMemPoolStats = record
    BlockSize: SizeUInt;
    Capacity: Integer;
    AllocatedCount: Integer;
    AvailableCount: Integer;
    Utilization: Double; // 0.0 .. 1.0
  end;

  TStackPoolStats = record
    TotalSize: SizeUInt;
    UsedSize: SizeUInt;
    AvailableSize: SizeUInt;
    Utilization: Double; // 0.0 .. 1.0
  end;

  TBlockPoolStats = record
    BlockSize: SizeUInt;
    Capacity: SizeUInt;
    InUse: SizeUInt;
    Available: SizeUInt;
    Utilization: Double; // 0.0 .. 1.0
  end;



  TSlabPoolStats = nextpas.core.mem.pool.slab.TSlabPoolStats;

// 快照函数（零副作用）
function GetMemPoolStats(const aPool: TMemPool): TMemPoolStats; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
function GetStackPoolStats(const aPool: TStackPool): TStackPoolStats; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
function GetBlockPoolStats(const aPool: IBlockPool): TBlockPoolStats; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}
function GetSlabPoolStats(const aPool: TSlabPool): TSlabPoolStats; {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}

implementation

function GetMemPoolStats(const aPool: TMemPool): TMemPoolStats;
var
  LCapacity: Integer;
  LAllocated: Integer;
begin
  // 中文注释：从现有公开属性采集只读统计
  LCapacity := aPool.Capacity;
  LAllocated := aPool.AllocatedCount;

  Result.BlockSize := aPool.BlockSize;
  Result.Capacity := LCapacity;
  Result.AllocatedCount := LAllocated;
  Result.AvailableCount := LCapacity - LAllocated;
  if LCapacity > 0 then
    Result.Utilization := LAllocated / LCapacity
  else
    Result.Utilization := 0.0;
end;

function GetStackPoolStats(const aPool: TStackPool): TStackPoolStats;
var
  LTotal, LUsed: SizeUInt;
begin
  // 中文注释：读取总大小与已用大小，计算可用与利用率
  LTotal := aPool.TotalSize;
  LUsed := aPool.UsedSize;

  Result.TotalSize := LTotal;
  Result.UsedSize := LUsed;
  if LUsed <= LTotal then
    Result.AvailableSize := LTotal - LUsed
  else
    Result.AvailableSize := 0; // 防御性

  if LTotal > 0 then
    Result.Utilization := LUsed / LTotal
  else
    Result.Utilization := 0.0;
end;

function GetBlockPoolStats(const aPool: IBlockPool): TBlockPoolStats;
var
  LCapacity: SizeUInt;
  LInUse: SizeUInt;
  LAvailable: SizeUInt;
begin
  LCapacity := aPool.Capacity;
  LInUse := aPool.InUse;
  LAvailable := aPool.Available;

  Result.BlockSize := aPool.BlockSize;
  Result.Capacity := LCapacity;
  Result.InUse := LInUse;
  Result.Available := LAvailable;
  if LCapacity > 0 then
    Result.Utilization := LInUse / LCapacity
  else
    Result.Utilization := 0.0;
end;



function GetSlabPoolStats(const aPool: TSlabPool): TSlabPoolStats;
begin
  Result := aPool.Stats;
end;

end.
