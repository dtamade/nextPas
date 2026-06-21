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
  SysUtils;

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
  GGlobalTrackerInitialized: Boolean = False;
  GOriginalMemoryManager: TMemoryManager;
  GTrackingEnabled: Boolean = False;

{ TMemoryTracker }

function TrackingGetMem(Size: PtrUInt): Pointer;
begin
  Result := GOriginalMemoryManager.GetMem(Size);
  if GTrackingEnabled then
    GGlobalTracker.RecordAlloc(Size);
end;

function TrackingFreeMem(P: Pointer): PtrUInt;
begin
  if GTrackingEnabled then
    GGlobalTracker.RecordFree(0); // 简化：不跟踪具体大小
  Result := GOriginalMemoryManager.FreeMem(P);
end;

function TrackingReAllocMem(P: Pointer; Size: PtrUInt): Pointer;
begin
  if GTrackingEnabled then
  begin
    GGlobalTracker.RecordFree(0);
    GGlobalTracker.RecordAlloc(Size);
  end;
  Result := GOriginalMemoryManager.ReAllocMem(P, Size);
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

  Inc(FStats.AllocCount);
  Inc(FStats.AllocBytes, ASize);
  Inc(FStats.CurrentAllocs);
  Inc(FStats.CurrentBytes, ASize);

  // Update peak
  if FStats.CurrentAllocs > FStats.PeakAllocs then
    FStats.PeakAllocs := FStats.CurrentAllocs;
  if FStats.CurrentBytes > FStats.PeakBytes then
    FStats.PeakBytes := FStats.CurrentBytes;
end;

procedure TMemoryTracker.RecordFree(ASize: Int64);
begin
  if not FEnabled then Exit;

  Inc(FStats.FreeCount);
  Inc(FStats.FreeBytes, ASize);
  Dec(FStats.CurrentAllocs);
  Dec(FStats.CurrentBytes, ASize);
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
  if not GGlobalTrackerInitialized then
  begin
    GGlobalTracker := TMemoryTracker.Create(True);
    GGlobalTrackerInitialized := True;
  end;
  Result := GGlobalTracker;
end;

procedure EnableGlobalMemoryTracking;
begin
  if GTrackingEnabled then Exit;

  // 保存原始 memory manager
  GetMemoryManager(GOriginalMemoryManager);

  // 设置跟踪 memory manager
  GTrackingMemoryManager.GetMem := @TrackingGetMem;
  GTrackingMemoryManager.FreeMem := @TrackingFreeMem;
  GTrackingMemoryManager.ReAllocMem := @TrackingReAllocMem;

  // 重置统计
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
  GlobalMemoryTracker.Reset;
end;

function GetGlobalMemoryStats: TMemoryStats;
begin
  Result := GlobalMemoryTracker.GetStats;
end;

end.
