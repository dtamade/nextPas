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
  nextpas.core.system.memmanager;

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
   * 全局内存跟踪器
   *}
  function GlobalMemoryTracker: TMemoryTracker;

  {**
   * 启用全局内存跟踪
   *}
  procedure EnableGlobalMemoryTracking;

  {**
   * 禁用全局内存跟踪
   *}
  procedure DisableGlobalMemoryTracking;

  {**
   * 重置全局内存跟踪器
   *}
  procedure ResetGlobalMemoryTracker;

  {**
   * 获取全局内存统计
   *}
  function GetGlobalMemoryStats: TMemoryStats;

implementation

var
  GGlobalTracker: TMemoryTracker;
  GGlobalTrackerInitialized: Integer = 0;  // 0=未初始化, 1=已初始化
  GOriginalMemoryManager: TMemoryManager;
  GTrackingEnabled: Boolean = False;

procedure AtomicInc64(var ATarget: Int64; ADelta: Int64);
var
  LOld: Int64;
  LNew: Int64;
begin
  repeat
    LOld := ATarget;
    LNew := LOld + ADelta;
  until InterlockedCompareExchange64(ATarget, LNew, LOld) = LOld;
end;

procedure AtomicDec64(var ATarget: Int64; ADelta: Int64);
var
  LOld: Int64;
  LNew: Int64;
begin
  repeat
    LOld := ATarget;
    LNew := LOld - ADelta;
  until InterlockedCompareExchange64(ATarget, LNew, LOld) = LOld;
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
  if GTrackingEnabled then
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
  if GTrackingEnabled then
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
begin
  if not FEnabled then Exit;

  AtomicInc64(FStats.AllocCount, 1);
  AtomicInc64(FStats.AllocBytes, ASize);
  AtomicInc64(FStats.CurrentAllocs, 1);
  AtomicInc64(FStats.CurrentBytes, ASize);

  AtomicUpdatePeak(FStats.PeakAllocs, FStats.CurrentAllocs);
  AtomicUpdatePeak(FStats.PeakBytes, FStats.CurrentBytes);
end;

procedure TMemoryTracker.RecordFree(ASize: Int64);
begin
  if not FEnabled then Exit;

  AtomicInc64(FStats.FreeCount, 1);
  AtomicInc64(FStats.FreeBytes, ASize);
  AtomicDec64(FStats.CurrentAllocs, 1);
  AtomicDec64(FStats.CurrentBytes, ASize);
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

procedure EnableGlobalMemoryTracking;
begin
  if GTrackingEnabled then Exit;

  // 保存原始 memory manager
  GetMemoryManager(GOriginalMemoryManager);

  // 设置跟踪 memory manager
  GTrackingMemoryManager := GOriginalMemoryManager;
  GTrackingMemoryManager.GetMem := @TrackingGetMem;
  GTrackingMemoryManager.AllocMem := @TrackingAllocMem;
  GTrackingMemoryManager.FreeMem := @TrackingFreeMem;
  GTrackingMemoryManager.FreeMemSize := @TrackingFreeMemSize;
  GTrackingMemoryManager.ReAllocMem := @TrackingReAllocMem;

  // 重置统计
  if InterlockedCompareExchange(GGlobalTrackerInitialized, 1, 0) = 0 then
    GGlobalTracker := TMemoryTracker.Create(True);
  GGlobalTracker.Reset;

  // 启用跟踪
  GTrackingEnabled := True;
  SetMemoryManager(GTrackingMemoryManager);
end;

procedure DisableGlobalMemoryTracking;
begin
  if not GTrackingEnabled then Exit;

  // 恢复原始 memory manager
  SetMemoryManager(GOriginalMemoryManager);
  GTrackingEnabled := False;
end;

procedure ResetGlobalMemoryTracker;
begin
  if GGlobalTrackerInitialized = 0 then
  begin
    if InterlockedCompareExchange(GGlobalTrackerInitialized, 1, 0) = 0 then
      GGlobalTracker := TMemoryTracker.Create(True);
  end;
  GGlobalTracker.Reset;
end;

function GetGlobalMemoryStats: TMemoryStats;
begin
  Result := GlobalMemoryTracker.GetStats;
end;

end.
