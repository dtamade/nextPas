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
  nextpas.core.atomic.core,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex,
  nextpas.core.mem.error;

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

  TAllocStatsAllocator = class;

  {** TAllocStatsCollector
   *
   *  从多个 TAllocStatsAllocator 实例收集统计。
   *  每个 TAllocStatsAllocator 创建时注册，销毁时注销。
   *  注册/注销走冷路径（临界区），热路径零开销。
   *}
  TAllocStatsCollector = class
  private
    FLock: TMemMutex;
    FAllocators: array of TAllocStatsAllocator;
    FCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    {** 注册一个 allocator（由 TAllocStatsAllocator.Create 调用） }
    procedure Register(AAllocator: TAllocStatsAllocator);
    {** 注销一个 allocator（由 TAllocStatsAllocator.Destroy 调用） }
    procedure Unregister(AAllocator: TAllocStatsAllocator);

    {** 收集所有已注册 allocator 的快照 }
    function Collect: TAllocSnapshot;
    {** 已注册 allocator 数量 }
    function Count: Integer;
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
  TAllocStatsAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FCollector: TAllocStatsCollector;
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
  public
    {** 创建统计包装器。
     *  ACollector 非 nil 时注册到该收集器，nil 时不注册。 }
    constructor Create(AInner: IAllocator; ATrackHistogram: Boolean = False;
      ACollector: TAllocStatsCollector = nil);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;

    {** 获取当前快照 }
    function Snapshot: TAllocSnapshot;
    {** 获取直方图（需要 ATrackHistogram=True） }
    function Histogram: TAllocHistogram;
    {** 重置统计（不影响活跃分配） }
    procedure ResetStats;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;
  end;

{** 默认全局收集器 — 所有 TAllocStatsAllocator 默认注册到这里 }
function DefaultStatsCollector: TAllocStatsCollector;

implementation

uses
  nextpas.core.mem.utils,
  nextpas.core.base.utils;

{$IF DEFINED(CPUARM) OR DEFINED(CPU386)}
{ arm32/i386 无 FPC 64 位内建：转发到本库缝合层（arm32=LDREXD/STREXD，
  i386=LOCK CMPXCHG8B）。同名声明遮蔽缺失的 System 版本，调用点无需改动。 }
function InterlockedCompareExchange64(var Target: Int64; NewValue, Comparand: Int64): Int64; inline;
begin
  Result := _backend_cmpxchg_i64(Target, NewValue, Comparand);
end;

function InterlockedExchangeAdd64(var Target: Int64; Value: Int64): Int64; inline;
begin
  Result := _backend_xadd_i64(Target, Value);
end;

function InterlockedExchange64(var Target: Int64; Value: Int64): Int64; inline;
begin
  Result := _backend_xchg_i64(Target, Value);
end;
{$ENDIF}

var
  GDefaultCollector: TAllocStatsCollector = nil;

function DefaultStatsCollector: TAllocStatsCollector;
begin
  { Created in initialization section — no lazy init needed. }
  Result := GDefaultCollector;
end;

{ TAllocStatsCollector }

constructor TAllocStatsCollector.Create;
begin
  inherited Create;
  FLock.Init;
  FAllocators := nil;
  FCount := 0;
end;

destructor TAllocStatsCollector.Destroy;
begin
  FLock.Done;
  FAllocators := nil;
  inherited Destroy;
end;

procedure TAllocStatsCollector.Register(AAllocator: TAllocStatsAllocator);
begin
  FLock.Acquire;
  try
    if FCount >= Length(FAllocators) then
      SetLength(FAllocators, FCount + 16);
    FAllocators[FCount] := AAllocator;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

procedure TAllocStatsCollector.Unregister(AAllocator: TAllocStatsAllocator);
var
  LI, LJ: Integer;
begin
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
    begin
      if FAllocators[LI] = AAllocator then
      begin
        for LJ := LI to FCount - 2 do
          FAllocators[LJ] := FAllocators[LJ + 1];
        Dec(FCount);
        FAllocators[FCount] := nil;
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TAllocStatsCollector.Collect: TAllocSnapshot;
var
  LSnap: TAllocSnapshot;
  LI: Integer;
begin
  Result.TotalAllocs := 0;
  Result.TotalFrees := 0;
  Result.ActiveAllocs := 0;
  Result.PeakAllocs := 0;
  Result.TotalBytesAllocated := 0;
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
    begin
      LSnap := FAllocators[LI].Snapshot;
      Result.TotalAllocs := Result.TotalAllocs + LSnap.TotalAllocs;
      Result.TotalFrees := Result.TotalFrees + LSnap.TotalFrees;
      Result.ActiveAllocs := Result.ActiveAllocs + LSnap.ActiveAllocs;
      if LSnap.PeakAllocs > Result.PeakAllocs then
        Result.PeakAllocs := LSnap.PeakAllocs;
      Result.TotalBytesAllocated := Result.TotalBytesAllocated + LSnap.TotalBytesAllocated;
    end;
  finally
    FLock.Release;
  end;
end;

function TAllocStatsCollector.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

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

constructor TAllocStatsAllocator.Create(AInner: IAllocator;
  ATrackHistogram: Boolean; ACollector: TAllocStatsCollector);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TAllocStatsAllocator', 'Create', 'AInner must not be nil'));
  FInner := AInner;
  FTrackHistogram := ATrackHistogram;
  FCollector := ACollector;
  ResetStats;
  // 仅在显式传入 collector 时注册
  if FCollector <> nil then
    FCollector.Register(Self);
end;

destructor TAllocStatsAllocator.Destroy;
begin
  if FCollector <> nil then
    FCollector.Unregister(Self);
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

function TAllocStatsAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TAllocStatsAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TAllocStatsAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
  begin
    RecordFree;
    RecordAlloc(ASize);
  end;
end;

procedure TAllocStatsAllocator.FreeMem(APtr: Pointer);
begin
  if APtr = nil then Exit;
  FInner.FreeMem(APtr);
  RecordFree;
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
var
  LActiveAllocs: Int64;
  LIndex: Integer;
begin
  InterlockedExchange64(FTotalAllocs, 0);
  InterlockedExchange64(FTotalFrees, 0);
  InterlockedExchange64(FTotalBytesAllocated, 0);

  for LIndex := Low(FHistogram.Buckets) to High(FHistogram.Buckets) do
    InterlockedExchange64(FHistogram.Buckets[LIndex], 0);
  InterlockedExchange64(FHistogram.TotalBytes, 0);
  InterlockedExchange64(FHistogram.TotalCount, 0);

  LActiveAllocs := InterlockedCompareExchange64(FActiveAllocs, 0, 0);
  InterlockedExchange64(FPeakAllocs, 0);
  UpdatePeak(FPeakAllocs, LActiveAllocs);
  LActiveAllocs := InterlockedCompareExchange64(FActiveAllocs, 0, 0);
  UpdatePeak(FPeakAllocs, LActiveAllocs);
end;

function TAllocStatsAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
end;

initialization
  GDefaultCollector := TAllocStatsCollector.Create;

finalization
  FreeAndNil(GDefaultCollector);

end.
