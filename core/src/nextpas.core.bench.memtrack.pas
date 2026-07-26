{**
 * @desc 基准测试内存跟踪器
 *
 * 提供精确的内存分配跟踪功能，
 * 用于基准测试中的内存使用分析。
 *}
unit nextpas.core.bench.memtrack;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.system.memmanager,
  nextpas.core.exception;

type
  {**
   * 内存统计信息
   *}
  TMemoryStats = record
    AllocCount: Int64;      // 分配次数
    FreeCount: Int64;       // 释放次数
    AllocBytes: Int64;      // 分配字节数
    FreeBytes: Int64;       // 释放字节数
    PeakAllocs: Int64;      // 峰值分配次数
    PeakBytes: Int64;       // 峰值字节数
    CurrentAllocs: Int64;   // 当前分配次数
    CurrentBytes: Int64;    // 当前字节数
  end;

  {**
   * 内存跟踪器
   *}
  TMemoryTracker = record
  private
    FStats: TMemoryStats;
    FEnabled: Boolean;
  public
    {**
     * 创建新的内存跟踪器
     *}
    class function Create(AEnabled: Boolean = True): TMemoryTracker; static;

    {**
     * 重置统计信息
     *}
    procedure Reset;

    {**
     * 记录分配
     *}
    procedure RecordAlloc(ASize: Int64);

    {**
     * 记录释放
     *}
    procedure RecordFree(ASize: Int64);

    {**
     * 获取统计信息
     *}
    function GetStats: TMemoryStats;

    {**
     * 是否启用
     *}
    function IsEnabled: Boolean;

    {**
     * 获取每次操作的平均分配字节数
     *}
    function BytesPerOp(AIterations: Int64): Double;

    {**
     * 获取每次操作的平均分配次数
     *}
    function AllocsPerOp(AIterations: Int64): Double;
  end;

  {**
   * 全局内存跟踪器（返回 record 拷贝 — 勿对结果调用 Record*；用 GetGlobalMemoryStats）。
   * @deprecated Prefer GetGlobalMemoryStats / ResetGlobalMemoryTracker.
   *}
  function GlobalMemoryTracker: TMemoryTracker;

  {**
   * 尝试启用全局内存跟踪。
   * @return True if tracking is active after the call.
   *         False if heaptrc is active, CAS contention, or install failed.
   *}
  function TryEnableGlobalMemoryTracking: Boolean;

  {**
   * 启用全局内存跟踪。
   * heaptrc 激活时静默 no-op（防双重 hook OOM）。
   * 其它失败路径抛 EBenchError（F-02：禁止静默假成功）。
   *}
  procedure EnableGlobalMemoryTracking;

  {**
   * 检测 heaptrc 是否已启用
   *
   * heaptrc (FPC -gh) 会 hook 内存管理器。如果 memtrack 也 hook，
   * 每次分配会经过两层追踪，开销 10-20x，可能导致 OOM。
   * 测试构建通过 -dHEAPTRC_ACTIVE 标志告知此函数（与 -gh 互斥矩阵见 CONTRACT）。
   *}
  function IsHeaptrcEnabled: Boolean;

  {**
   * 是否已安装全局 memtrack hook
   *}
  function IsGlobalMemoryTrackingEnabled: Boolean;

  {**
   * 禁用全局内存跟踪
   *}
  procedure DisableGlobalMemoryTracking;

  {**
   * 重置全局内存跟踪器
   *}
  procedure ResetGlobalMemoryTracker;

  {**
   * 获取全局内存统计（推荐读侧 API）
   *}
  function GetGlobalMemoryStats: TMemoryStats;

implementation

var
  GGlobalTracker: TMemoryTracker;
  GGlobalTrackerInitialized: Integer = 0;  // 0=未初始化, 1=已初始化
  GOriginalMemoryManager: TMemoryManager;
  GTrackingEnabled: Boolean = False;
  GEnableLock: Integer = 0;  // 0=unlocked, 1=locked — CAS try-lock for enable/disable

function AtomicInc64(var ATarget: Int64; ADelta: Int64): Int64;
var
  LOld: Int64;
  LNew: Int64;
begin
  repeat
    LOld := ATarget;
    LNew := LOld + ADelta;
  until InterlockedCompareExchange64(ATarget, LNew, LOld) = LOld;
  Result := LNew;
end;

function AtomicDec64(var ATarget: Int64; ADelta: Int64): Int64;
var
  LOld: Int64;
  LNew: Int64;
begin
  repeat
    LOld := ATarget;
    LNew := LOld - ADelta;
  until InterlockedCompareExchange64(ATarget, LNew, LOld) = LOld;
  Result := LNew;
end;

{** CAS 循环更新峰值（只升不降） }
procedure AtomicUpdatePeak(var ATarget: Int64; AValue: Int64);
var
  LOld: Int64;
begin
  repeat
    LOld := ATarget;
    if AValue <= LOld then
      Exit;
  until InterlockedCompareExchange64(ATarget, AValue, LOld) = LOld;
end;

{ TMemoryTracker }

function TrackingGetMem(Size: PtrUInt): Pointer;
begin
  Result := GOriginalMemoryManager.GetMem(Size);
  if GTrackingEnabled and (Result <> nil) then
    GGlobalTracker.RecordAlloc(Size);
end;

function TrackingAllocMem(Size: PtrUInt): Pointer;
begin
  Result := GOriginalMemoryManager.AllocMem(Size);
  if GTrackingEnabled and (Result <> nil) then
    GGlobalTracker.RecordAlloc(Size);
end;

function TrackingFreeMem(P: Pointer): PtrUInt;
var
  LSize: PtrUInt;
begin
  LSize := 0;
  if GTrackingEnabled and (P <> nil) and Assigned(GOriginalMemoryManager.MemSize) then
    LSize := GOriginalMemoryManager.MemSize(P);
  if GTrackingEnabled and (P <> nil) then
    GGlobalTracker.RecordFree(LSize);
  Result := GOriginalMemoryManager.FreeMem(P);
end;

function TrackingFreeMemSize(P: Pointer; Size: PtrUInt): PtrUInt;
var
  LSize: PtrUInt;
begin
  LSize := Size;
  if (LSize = 0) and (P <> nil) and Assigned(GOriginalMemoryManager.MemSize) then
    LSize := GOriginalMemoryManager.MemSize(P);
  if GTrackingEnabled and (P <> nil) then
    GGlobalTracker.RecordFree(LSize);
  if Assigned(GOriginalMemoryManager.FreeMemSize) then
    Result := GOriginalMemoryManager.FreeMemSize(P, Size)
  else
    Result := GOriginalMemoryManager.FreeMem(P);
end;

function TrackingReAllocMem(var P: Pointer; Size: PtrUInt): Pointer;
var
  LOldSize: PtrUInt;
begin
  LOldSize := 0;
  if GTrackingEnabled and (P <> nil) and Assigned(GOriginalMemoryManager.MemSize) then
    LOldSize := GOriginalMemoryManager.MemSize(P);
  Result := GOriginalMemoryManager.ReAllocMem(P, Size);
  if GTrackingEnabled and (Result <> nil) then
  begin
    if LOldSize > 0 then
      GGlobalTracker.RecordFree(LOldSize);
    GGlobalTracker.RecordAlloc(Size);
  end;
end;

var
  GTrackingMemoryManager: TMemoryManager;

class function TMemoryTracker.Create(AEnabled: Boolean): TMemoryTracker;
begin
  Result.FEnabled := AEnabled;
  Result.Reset;
end;

procedure TMemoryTracker.Reset;
begin
  FStats := Default(TMemoryStats);
end;

procedure TMemoryTracker.RecordAlloc(ASize: Int64);
var
  LNewAllocs, LNewBytes: Int64;
begin
  if not FEnabled then Exit;

  AtomicInc64(FStats.AllocCount, 1);
  AtomicInc64(FStats.AllocBytes, ASize);
  LNewAllocs := AtomicInc64(FStats.CurrentAllocs, 1);
  LNewBytes := AtomicInc64(FStats.CurrentBytes, ASize);

  AtomicUpdatePeak(FStats.PeakAllocs, LNewAllocs);
  AtomicUpdatePeak(FStats.PeakBytes, LNewBytes);
end;

procedure TMemoryTracker.RecordFree(ASize: Int64);
var
  LOld, LNew: Int64;
begin
  if not FEnabled then Exit;

  AtomicInc64(FStats.FreeCount, 1);
  { F-08: unknown size (0) still counts free ops but does not drive Current* negative }
  if ASize > 0 then
    AtomicInc64(FStats.FreeBytes, ASize);

  if ASize > 0 then
  begin
    repeat
      LOld := FStats.CurrentAllocs;
      if LOld <= 0 then
        Break;
      LNew := LOld - 1;
    until InterlockedCompareExchange64(FStats.CurrentAllocs, LNew, LOld) = LOld;

    repeat
      LOld := FStats.CurrentBytes;
      if LOld <= 0 then
        Break;
      if ASize >= LOld then
        LNew := 0
      else
        LNew := LOld - ASize;
    until InterlockedCompareExchange64(FStats.CurrentBytes, LNew, LOld) = LOld;
  end;
end;

function TMemoryTracker.GetStats: TMemoryStats;
begin
  Result := FStats;
end;

function TMemoryTracker.IsEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TMemoryTracker.BytesPerOp(AIterations: Int64): Double;
begin
  if AIterations > 0 then
    Result := FStats.AllocBytes / AIterations
  else
    Result := 0;
end;

function TMemoryTracker.AllocsPerOp(AIterations: Int64): Double;
begin
  if AIterations > 0 then
    Result := FStats.AllocCount / AIterations
  else
    Result := 0;
end;

{ Global Memory Tracker }

function GlobalMemoryTracker: TMemoryTracker;
begin
  if InterlockedCompareExchange(GGlobalTrackerInitialized, 1, 0) = 0 then
    GGlobalTracker := TMemoryTracker.Create(True);
  Result := GGlobalTracker;
end;

function IsHeaptrcEnabled: Boolean;
{ heaptrc (-gh) 会 hook 内存管理器。如果 memtrack 也 hook，
  每次分配会经过两层追踪，开销 10-20x，可能导致 OOM。
  测试构建通过 -dHEAPTRC_ACTIVE 标志告知此函数。 }
begin
  {$ifdef HEAPTRC_ACTIVE}
  Result := True;
  {$else}
  Result := False;
  {$endif}
end;

function TryEnableGlobalMemoryTracking: Boolean;
begin
  Result := False;
  { OOM guard: heaptrc 已激活则不装第二层 hook }
  if IsHeaptrcEnabled then
    Exit(False);
  if GTrackingEnabled then
    Exit(True);

  if InterlockedCompareExchange(GEnableLock, 1, 0) <> 0 then
    Exit(False);  { concurrent enable/disable in progress }

  try
    if GTrackingEnabled then
      Exit(True);

    GetMemoryManager(GOriginalMemoryManager);

    GTrackingMemoryManager := GOriginalMemoryManager;
    GTrackingMemoryManager.GetMem := @TrackingGetMem;
    GTrackingMemoryManager.AllocMem := @TrackingAllocMem;
    GTrackingMemoryManager.FreeMem := @TrackingFreeMem;
    GTrackingMemoryManager.FreeMemSize := @TrackingFreeMemSize;
    GTrackingMemoryManager.ReAllocMem := @TrackingReAllocMem;

    if InterlockedCompareExchange(GGlobalTrackerInitialized, 1, 0) = 0 then
    begin
      GGlobalTracker := TMemoryTracker.Create(True);
      GGlobalTracker.Reset;
    end;

    GTrackingEnabled := True;
    SetMemoryManager(GTrackingMemoryManager);
    Result := True;
  finally
    GEnableLock := 0;
  end;
end;

procedure EnableGlobalMemoryTracking;
begin
  if TryEnableGlobalMemoryTracking then
    Exit;
  { heaptrc: intentional soft skip (documented process isolation) }
  if IsHeaptrcEnabled then
    Exit;
  if GTrackingEnabled then
    Exit;
  raise ENextPasError.Create(
    'EnableGlobalMemoryTracking failed: concurrent enable/disable or install rejected. ' +
    'Memtrack is process-global; run one suite per process.');
end;

function IsGlobalMemoryTrackingEnabled: Boolean;
begin
  Result := GTrackingEnabled;
end;

procedure DisableGlobalMemoryTracking;
begin
  if not GTrackingEnabled then Exit;

  if InterlockedCompareExchange(GEnableLock, 1, 0) <> 0 then
    Exit;  { concurrent op — caller may retry; state unchanged }

  try
    if not GTrackingEnabled then Exit;

    SetMemoryManager(GOriginalMemoryManager);
    GTrackingEnabled := False;
  finally
    GEnableLock := 0;
  end;
end;

procedure ResetGlobalMemoryTracker;
begin
  if GGlobalTrackerInitialized = 0 then
  begin
    if InterlockedCompareExchange(GGlobalTrackerInitialized, 1, 0) = 0 then
      GGlobalTracker := TMemoryTracker.Create(True);
  end;
  if GGlobalTrackerInitialized <> 0 then  { F-02: guard against CAS loser race }
    GGlobalTracker.Reset;
end;

function GetGlobalMemoryStats: TMemoryStats;
begin
  Result := GlobalMemoryTracker.GetStats;
end;

end.
