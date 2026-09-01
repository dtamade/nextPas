{**
 * nextpas.core.agent.streambox - 流式盒 Lock+Done+id 迟到丢弃封装（可复用面）。
 *
 * 职责：把 PERFORMANCE.md §7.2 / LIFECYCLE.md §8 的 TAiStreamBox 思想收为
 * 可复用的 nextpas.core 原语：平台互斥 + Done 终态 + id 失配丢弃，供 TUI/loop
 * 消费方直接复用；零直接依赖 FPC RTL SyncObjs/SysUtils，全部经
 * nextpas.core.platform.sync。
 * 契约权威：PERFORMANCE.md §7.2 + ARCHITECTURE.md §4/§6 + LIFECYCLE.md §1。
 * 反哺点：SyncObjs.TCriticalSection 收至 platform.sync TPlatformMutex。
 *}

unit nextpas.core.agent.streambox;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync,
  nextpas.core.agent.base;

type
  TAgentStreamBox = class
  private
    FLock: TPlatformMutex;
    FDone: Boolean;
    FId: UInt64;
    FPending: TStreamDeltaArray;
    FHead: Integer;
  public
    constructor Create(AId: UInt64);
    destructor Destroy; override;
    procedure Push(const ADelta: TStreamDelta; AId: UInt64);
    function TryPop(out ADelta: TStreamDelta): Boolean;
    procedure MarkDone;
    function IsDone: Boolean; inline;
    property Id: UInt64 read FId;
  end;

implementation

uses
  nextpas.core.errors;

constructor TAgentStreamBox.Create(AId: UInt64);
begin
  inherited Create;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('platform_mutex_init failed');
  FId := AId;
end;

destructor TAgentStreamBox.Destroy;
begin
  platform_mutex_destroy(FLock);
  inherited;
end;

procedure TAgentStreamBox.Push(const ADelta: TStreamDelta; AId: UInt64);
var
  LLen: Integer;
begin
  platform_mutex_lock(FLock);
  try
    if (AId <> FId) or FDone then Exit;
    LLen := Length(FPending);
    SetLength(FPending, LLen + 1);
    FPending[LLen] := ADelta;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAgentStreamBox.TryPop(out ADelta: TStreamDelta): Boolean;
var
  LLen, LRemaining: Integer;
begin
  platform_mutex_lock(FLock);
  try
    Result := FHead < Length(FPending);
    if not Result then Exit;
    ADelta := FPending[FHead];
    Inc(FHead);
    // 环形压缩：头部过半且堆积>64时一次性前移，摊销 O(1)
    if (FHead > 64) and (FHead > Length(FPending) div 2) then
    begin
      LLen := Length(FPending);
      LRemaining := LLen - FHead;
      if LRemaining > 0 then
        Move(FPending[FHead], FPending[0], LRemaining * SizeOf(TStreamDelta));
      SetLength(FPending, LRemaining);
      FHead := 0;
    end else if FHead = Length(FPending) then
    begin
      // 刚好消费完，重置以释放内存
      SetLength(FPending, 0);
      FHead := 0;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAgentStreamBox.MarkDone;
begin
  platform_mutex_lock(FLock);
  try
    FDone := True;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAgentStreamBox.IsDone: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FDone;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

end.
