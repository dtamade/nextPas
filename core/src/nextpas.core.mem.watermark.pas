{
# nextpas.core.mem.watermark

## 摘要

Memory watermark — 内存使用高/低水位线监控 + 回调。

特性:
- 高水位线和临界水位线监控
- 回调链：多个 handler 按注册顺序调用
- 线程安全
- 与 TAllocStatsAllocator 配合使用

适用场景: 生产环境内存监控、降级策略触发。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.watermark;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.error,
  nextpas.core.mem.mutex;

type
  {** 水位线级别 }
  TWatermarkLevel = (
    wlNormal,    { 正常 }
    wlHigh,      { 高水位线 }
    wlCritical   { 临界水位线 }
  );

  {** 水位线事件回调 }
  TWatermarkEvent = procedure(ALevel: TWatermarkLevel; AUsedBytes: UInt64);

  {** TMemoryWatermark
   *
   *  内存使用水位线监控器。
   *  注册回调在水位线变化时触发。
   *
   *  使用模式:
   *    var LWatermark: TMemoryWatermark;
   *    LWatermark := TMemoryWatermark.Create(100 * 1024 * 1024, 200 * 1024 * 1024);
   *    try
   *      LWatermark.RegisterHandler(wlHigh, @OnHighWatermark);
   *      LWatermark.RegisterHandler(wlCritical, @OnCriticalWatermark);
   *      // 每次分配后检查
   *      LWatermark.Check(CurrentAllocBytes);
   *    finally
   *      LWatermark.Free;
   *    end;
   *}
  TMemoryWatermark = class
  private
    FHighBytes: UInt64;
    FCriticalBytes: UInt64;
    FCurrentLevel: TWatermarkLevel;
    FLock: TMemMutex;
    { 回调链 }
    FHandlers: array of record
      Level: TWatermarkLevel;
      Handler: TWatermarkEvent;
    end;
    FHandlerCount: Integer;
    procedure FireCallbacks(ALevel: TWatermarkLevel; AUsedBytes: UInt64);
  public
    {** 创建水位线监控器
     *  @param AHighBytes 高水位线阈值（字节）
     *  @param ACriticalBytes 临界水位线阈值（字节）
     *}
    constructor Create(AHighBytes: UInt64; ACriticalBytes: UInt64);
    destructor Destroy; override;

    {** 检查当前使用量，触发回调 }
    procedure Check(AUsedBytes: UInt64);
    {** 注册回调 }
    procedure RegisterHandler(ALevel: TWatermarkLevel; AHandler: TWatermarkEvent);
    {** 当前水位线级别 }
    function CurrentLevel: TWatermarkLevel;
    {** 高水位线阈值 }
    property HighBytes: UInt64 read FHighBytes;
    {** 临界水位线阈值 }
    property CriticalBytes: UInt64 read FCriticalBytes;
  end;

implementation

const
  MAX_WATERMARK_HANDLERS = 16;

{ TMemoryWatermark }

constructor TMemoryWatermark.Create(AHighBytes: UInt64; ACriticalBytes: UInt64);
begin
  inherited Create;
  if ACriticalBytes <= AHighBytes then
    raise EAllocError.Create(aeInvalidLayout,
      'TMemoryWatermark.Create: CriticalBytes must be > HighBytes');
  FHighBytes := AHighBytes;
  FCriticalBytes := ACriticalBytes;
  FCurrentLevel := wlNormal;
  FHandlerCount := 0;
  SetLength(FHandlers, MAX_WATERMARK_HANDLERS);
  FLock.Init;
end;

destructor TMemoryWatermark.Destroy;
begin
  FLock.Done;
  SetLength(FHandlers, 0);
  inherited Destroy;
end;

procedure TMemoryWatermark.RegisterHandler(ALevel: TWatermarkLevel;
  AHandler: TWatermarkEvent);
begin
  if not Assigned(AHandler) then Exit;
  FLock.Acquire;
  try
    if FHandlerCount < MAX_WATERMARK_HANDLERS then
    begin
      FHandlers[FHandlerCount].Level := ALevel;
      FHandlers[FHandlerCount].Handler := AHandler;
      Inc(FHandlerCount);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TMemoryWatermark.FireCallbacks(ALevel: TWatermarkLevel; AUsedBytes: UInt64);
var
  LI: Integer;
begin
  for LI := 0 to FHandlerCount - 1 do
  begin
    if (FHandlers[LI].Level = ALevel) and Assigned(FHandlers[LI].Handler) then
      FHandlers[LI].Handler(ALevel, AUsedBytes);
  end;
end;

procedure TMemoryWatermark.Check(AUsedBytes: UInt64);
var
  LOldLevel, LNewLevel: TWatermarkLevel;
begin
  { 确定新级别 }
  if AUsedBytes >= FCriticalBytes then
    LNewLevel := wlCritical
  else if AUsedBytes >= FHighBytes then
    LNewLevel := wlHigh
  else
    LNewLevel := wlNormal;

  FLock.Acquire;
  try
    LOldLevel := FCurrentLevel;
    if LNewLevel <> LOldLevel then
    begin
      FCurrentLevel := LNewLevel;
      { 只在升级时触发回调（normal→high, high→critical） }
      if Ord(LNewLevel) > Ord(LOldLevel) then
        FireCallbacks(LNewLevel, AUsedBytes);
    end;
  finally
    FLock.Release;
  end;
end;

function TMemoryWatermark.CurrentLevel: TWatermarkLevel;
begin
  FLock.Acquire;
  try
    Result := FCurrentLevel;
  finally
    FLock.Release;
  end;
end;

end.
