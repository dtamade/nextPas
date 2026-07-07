{******************************************************************************
  nextpas.core.mem.stats — 分配统计收集器

  核心设计:
    1. 轻量级统计包装器，热路径零争用（原子计数器）
    2. 支持快照查询（当前/峰值/总量）
    3. 可选分配直方图（按大小分布）
    4. 线程安全，可包装任意 IAllocator

  性能目标:
    - GetMem/FreeMem 额外开销 < 5ns（原子递增）
    - Snapshot 查询零锁（原子读取）
    - Histogram bucket 选择：位运算 O(1)

  使用模式:
    var LStats: TAllocStatsAllocator;
    LStats := TAllocStatsAllocator.Create(DefaultAllocator);
    try
      // 正常使用 LStats 作为 IAllocator
      LPtr := LStats.GetMem(1024);
      LStats.FreeMem(LPtr);
      // 查询统计
      WriteLn('Active: ', LStats.Snapshot.ActiveAllocs);
    finally
      LStats.Free;
    end;
******************************************************************************}
unit nextpas.core.mem.stats;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  {** 分配快照 — 当前分配状态的只读视图 }
  TAllocSnapshot = record
    TotalAllocs: UInt64;         // 总分配次数
    TotalFrees: UInt64;          // 总释放次数
    ActiveAllocs: UInt64;        // 当前活跃分配数
    PeakAllocs: UInt64;          // 峰值分配数
    TotalBytesAllocated: UInt64; // 总分配字节数
    function AllocationRate: Double;  // 分配率 (allocs / total)
  end;

  {** 分配直方图 — 按大小分布的统计 }
  TAllocHistogram = record
    Buckets: array[0..8] of Int64;   // 16B/64B/256B/1KB/4KB/16KB/64KB/256KB/256KB+
    TotalBytes: Int64;
    TotalCount: Int64;
    function MeanSize: Double;
    function Percentile(APct: Double): SizeUInt;
    function BucketLabel(AIndex: Integer): string;
  end;

  {** TAllocStatsAllocator
   *
   *  包装任意 IAllocator，收集分配统计信息。
   *  热路径仅添加原子计数器递增（< 5ns 额外开销）。
   *  线程安全。
   *
   *  注意：FreeMem 不跟踪字节数（需要额外存储），
   *  只跟踪分配/释放次数和峰值。直方图跟踪分配大小分布。
   *}
  TAllocStatsAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    { 原子计数器 — 热路径 }
    FTotalAllocs: Int64;
    FTotalFrees: Int64;
    FActiveAllocs: Int64;
    FPeakAllocs: Int64;
    FTotalBytesAllocated: Int64;
    { 直方图 — 可选 }
    FHistogram: TAllocHistogram;
    FTrackHistogram: Boolean;
    procedure RecordAlloc(ASize: SizeUInt);
    procedure RecordFree;
    procedure UpdatePeak(var APeak: Int64; ANew: Int64);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator; ATrackHistogram: Boolean = False);
    destructor Destroy; override;

    {** 获取当前快照 }
    function Snapshot: TAllocSnapshot;
    {** 获取直方图（需要 ATrackHistogram=True） }
    function Histogram: TAllocHistogram;
    {** 重置统计（不影响活跃分配） }
    procedure ResetStats;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; override;
  end;

implementation

uses
  nextpas.core.mem.utils;

{ TAllocSnapshot }

function TAllocSnapshot.AllocationRate: Double;
begin
  if TotalAllocs + TotalFrees = 0 then
    Exit(0.0);
  Result := TotalAllocs / (TotalAllocs + TotalFrees);
end;

{ TAllocHistogram }

function TAllocHistogram.MeanSize: Double;
begin
  if TotalCount = 0 then
    Exit(0.0);
  Result := TotalBytes / TotalCount;
end;

function TAllocHistogram.Percentile(APct: Double): SizeUInt;
var
  LTarget: Int64;
  LAccum: Int64;
  LI: Integer;
  LUpper: array[0..8] of SizeUInt;
begin
  if TotalCount = 0 then
    Exit(0);
  LTarget := Trunc(APct * TotalCount / 100.0);
  if LTarget < 1 then
    LTarget := 1;
  LUpper[0] := 16;
  LUpper[1] := 64;
  LUpper[2] := 256;
  LUpper[3] := 1024;
  LUpper[4] := 4096;
  LUpper[5] := 16384;
  LUpper[6] := 65536;
  LUpper[7] := 262144;
  LUpper[8] := 262145;
  LAccum := 0;
  for LI := 0 to 8 do
  begin
    LAccum := LAccum + Buckets[LI];
    if LAccum >= LTarget then
      Exit(LUpper[LI]);
  end;
  Result := 262145;
end;

function TAllocHistogram.BucketLabel(AIndex: Integer): string;
begin
  case AIndex of
    0: Result := '0-16B';
    1: Result := '17-64B';
    2: Result := '65-256B';
    3: Result := '257B-1KB';
    4: Result := '1KB-4KB';
    5: Result := '4KB-16KB';
    6: Result := '16KB-64KB';
    7: Result := '64KB-256KB';
    8: Result := '>256KB';
  else
    Result := 'unknown';
  end;
end;

{ TAllocStatsAllocator }

constructor TAllocStatsAllocator.Create(AInner: IAllocator; ATrackHistogram: Boolean);
begin
  inherited Create;
  FInner := AInner;
  FTrackHistogram := ATrackHistogram;
  ResetStats;
end;

destructor TAllocStatsAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

procedure TAllocStatsAllocator.UpdatePeak(var APeak: Int64; ANew: Int64);
var
  LOld: Int64;
begin
  repeat
    LOld := APeak;
    if ANew <= LOld then
      Break;
  until InterlockedCompareExchange64(APeak, ANew, LOld) = LOld;
end;

procedure TAllocStatsAllocator.RecordAlloc(ASize: SizeUInt);
var
  LActive: Int64;
begin
  InterlockedExchangeAdd64(FTotalAllocs, 1);
  LActive := InterlockedExchangeAdd64(FActiveAllocs, 1) + 1;
  InterlockedExchangeAdd64(FTotalBytesAllocated, Int64(ASize));

  // 峰值更新
  UpdatePeak(FPeakAllocs, LActive);

  // 直方图
  if FTrackHistogram then
  begin
    if ASize <= 16 then
      InterlockedExchangeAdd64(FHistogram.Buckets[0], 1)
    else if ASize <= 64 then
      InterlockedExchangeAdd64(FHistogram.Buckets[1], 1)
    else if ASize <= 256 then
      InterlockedExchangeAdd64(FHistogram.Buckets[2], 1)
    else if ASize <= 1024 then
      InterlockedExchangeAdd64(FHistogram.Buckets[3], 1)
    else if ASize <= 4096 then
      InterlockedExchangeAdd64(FHistogram.Buckets[4], 1)
    else if ASize <= 16384 then
      InterlockedExchangeAdd64(FHistogram.Buckets[5], 1)
    else if ASize <= 65536 then
      InterlockedExchangeAdd64(FHistogram.Buckets[6], 1)
    else if ASize <= 262144 then
      InterlockedExchangeAdd64(FHistogram.Buckets[7], 1)
    else
      InterlockedExchangeAdd64(FHistogram.Buckets[8], 1);
    InterlockedExchangeAdd64(FHistogram.TotalBytes, Int64(ASize));
    InterlockedExchangeAdd64(FHistogram.TotalCount, 1);
  end;
end;

procedure TAllocStatsAllocator.RecordFree;
begin
  InterlockedExchangeAdd64(FTotalFrees, 1);
  InterlockedExchangeAdd64(FActiveAllocs, -1);
end;

function TAllocStatsAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TAllocStatsAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TAllocStatsAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  // ReallocMem 统计：释放旧 + 分配新
  if APtr <> nil then
    RecordFree;
  Result := FInner.ReallocMem(APtr, ASize);
  if (Result <> nil) and (ASize > 0) then
    RecordAlloc(ASize);
end;

procedure TAllocStatsAllocator.DoFreeMem(APtr: Pointer);
begin
  if APtr <> nil then
    RecordFree;
  FInner.FreeMem(APtr);
end;

function TAllocStatsAllocator.Snapshot: TAllocSnapshot;
begin
  Result.TotalAllocs := UInt64(FTotalAllocs);
  Result.TotalFrees := UInt64(FTotalFrees);
  Result.ActiveAllocs := UInt64(FActiveAllocs);
  Result.PeakAllocs := UInt64(FPeakAllocs);
  Result.TotalBytesAllocated := UInt64(FTotalBytesAllocated);
end;

function TAllocStatsAllocator.Histogram: TAllocHistogram;
begin
  Result := FHistogram;
end;

procedure TAllocStatsAllocator.ResetStats;
begin
  FTotalAllocs := 0;
  FTotalFrees := 0;
  FActiveAllocs := 0;
  FPeakAllocs := 0;
  FTotalBytesAllocated := 0;
  FillChar(FHistogram, SizeOf(FHistogram), 0);
end;

function TAllocStatsAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
end;

end.
