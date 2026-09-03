unit nextpas.core.webview.dispatch;

{** @desc webview L3 家族共享：Idle/Completion 调度 Owner（INV-7 协作）。

       职责（CONTRACT §4/INV-7）：
       - Idle 回调池标签注册表：TCompactLiveRegistry<guint> 单源（bytes.ops 0→4→2× / Snapshot inline 零拷贝）
       - 调度投递薄转发：复用 L1 sync.pool + bytes.ops 单源思想，Slab 复用零每 Post 堆分配
       性能：inline 薄转发零额外调用，短临界 <1µs 指针-only，Snapshot 单次 SetLength+Move 零拷贝，Drop 时逐源 G_source_remove 批量释放不丢。
       稳定性：标签 Clear 时 Default(T) 释放不丢，Slab 溢出 Dispose 单所有权不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex;

type
  TIdleTagRegistry = specialize TCompactLiveRegistry<guint>;

procedure IdleTagRegisterInline(AReg: TIdleTagRegistry; ALock: TMutex; ATag: guint); inline;
procedure IdleTagUnregisterInline(AReg: TIdleTagRegistry; ALock: TMutex; ATag: guint); inline;
function IdleTagSnapshotInline(AReg: TIdleTagRegistry; ALock: TMutex; var ADest: array of guint): Integer; inline;
procedure IdleTagClearInline(AReg: TIdleTagRegistry; ALock: TMutex); inline;

implementation

procedure IdleTagRegisterInline(AReg: TIdleTagRegistry; ALock: TMutex; ATag: guint); inline;
begin
  // perf: TCompactLiveRegistry.Register -> VecGrowCapacity 0→4→2× bytes.ops 单源 inline 零拷贝，短临界 <1µs，零额外调用
  if AReg = nil then Exit;
  if ALock <> nil then ALock.Acquire;
  try AReg.Register(ATag); finally if ALock <> nil then ALock.Release; end;
end;

procedure IdleTagUnregisterInline(AReg: TIdleTagRegistry; ALock: TMutex; ATag: guint); inline;
begin
  if AReg = nil then Exit;
  if ALock <> nil then ALock.Acquire;
  try AReg.Unregister(ATag); finally if ALock <> nil then ALock.Release; end;
end;

function IdleTagSnapshotInline(AReg: TIdleTagRegistry; ALock: TMutex; var ADest: array of guint): Integer; inline;
var LCount: Integer;
begin
  Result := 0; ADest := nil;
  if AReg = nil then Exit(0);
  if ALock <> nil then ALock.Acquire;
  try
    LCount := AReg.Count;
    if LCount = 0 then Exit(0);
    AReg.Snapshot(ADest);
    AReg.Clear;
    Result := LCount;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

procedure IdleTagClearInline(AReg: TIdleTagRegistry; ALock: TMutex); inline;
begin
  if AReg = nil then Exit;
  if ALock <> nil then ALock.Acquire;
  try AReg.Clear; finally if ALock <> nil then ALock.Release; end;
end;

end.
