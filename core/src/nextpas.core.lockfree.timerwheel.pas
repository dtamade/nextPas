unit nextpas.core.lockfree.timerwheel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TTimerCallback = procedure(AData: Pointer);
  TLockFreeTimerResult = (twScheduled, twCancelled, twClosed, twNotFound);

  TTimerEntry = record
    Callback: TTimerCallback;
    Data: Pointer;
    Rounds: Int64;
    Active: Boolean;
  end;

  {** @desc 并发定时器轮（Timer Wheel）
    @details 高效管理大量定时任务的数据结构。
      使用环形数组 + 轮次计数实现定时器。
      每个 tick 推进一个槽位，到期的定时器执行回调。
      适用场景：超时管理、心跳检测、定时任务调度。
  }
  TTimerWheel = class
  private
    FSlots: array of array of TTimerEntry;
    FSlotCount: Int64;
    FCurrentSlot: Int64;
    FTickIntervalNs: Int64;
    FTotalTicks: Int64;
    FClosed: Int32;
  public
    constructor Create(const ASlotCount: Int64; const ATickIntervalNs: Int64);
    function Schedule(const ACallback: TTimerCallback; const AData: Pointer; const ADelayTicks: Int64): Int64;
    function Cancel(const ATimerId: Int64): TLockFreeTimerResult;
    procedure Tick;
    procedure TickN(const AN: Int64);
    function ProcessExpired: Int64;
    function GetCurrentSlot: Int64;
    function GetTotalTicks: Int64;
    function GetTickIntervalNs: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TTimerWheel.Create(const ASlotCount: Int64; const ATickIntervalNs: Int64);
begin
  if ASlotCount <= 0 then
    raise EArgumentError.Create('TTimerWheel: slot count must be > 0');
  if ATickIntervalNs <= 0 then
    raise EArgumentError.Create('TTimerWheel: tick interval must be > 0');
  inherited Create;
  FSlotCount := ASlotCount;
  FCurrentSlot := 0;
  FTickIntervalNs := ATickIntervalNs;
  FTotalTicks := 0;
  FClosed := 0;
  SetLength(FSlots, FSlotCount);
end;

function TTimerWheel.Schedule(const ACallback: TTimerCallback; const AData: Pointer; const ADelayTicks: Int64): Int64;
var
  LTargetSlot: Int64;
  LRounds: Int64;
  LEntry: TTimerEntry;
  LLen: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(-1);
  if ADelayTicks <= 0 then
    raise EArgumentError.Create('TTimerWheel.Schedule: delay must be > 0');

  LRounds := ADelayTicks div FSlotCount;
  LTargetSlot := (FCurrentSlot + ADelayTicks) mod FSlotCount;

  LEntry.Callback := ACallback;
  LEntry.Data := AData;
  LEntry.Rounds := LRounds;
  LEntry.Active := True;

  LLen := Length(FSlots[LTargetSlot]);
  SetLength(FSlots[LTargetSlot], LLen + 1);
  FSlots[LTargetSlot][LLen] := LEntry;

  // Timer ID encodes slot and index
  Result := LTargetSlot * 1000000 + LLen;
end;

function TTimerWheel.Cancel(const ATimerId: Int64): TLockFreeTimerResult;
var
  LSlot, LIndex: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(twClosed);

  LSlot := ATimerId div 1000000;
  LIndex := ATimerId mod 1000000;

  if (LSlot < 0) or (LSlot >= FSlotCount) then
    Exit(twNotFound);
  if (LIndex < 0) or (LIndex >= Length(FSlots[LSlot])) then
    Exit(twNotFound);

  if FSlots[LSlot][LIndex].Active then
  begin
    FSlots[LSlot][LIndex].Active := False;
    Result := twCancelled;
  end
  else
    Result := twNotFound;
end;

procedure TTimerWheel.Tick;
begin
  FCurrentSlot := (FCurrentSlot + 1) mod FSlotCount;
  AtomicFetchAdd64(FTotalTicks, 1, moRelaxed);
end;

procedure TTimerWheel.TickN(const AN: Int64);
var
  LI: Int64;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TTimerWheel.TickN: N must be > 0');
  for LI := 1 to AN do
    Tick;
end;

function TTimerWheel.ProcessExpired: Int64;
var
  LSlot: Int64;
  LI, LCount: Int64;
  LEntry: TTimerEntry;
begin
  Result := 0;
  LSlot := FCurrentSlot;
  LCount := Length(FSlots[LSlot]);

  for LI := 0 to LCount - 1 do
  begin
    LEntry := FSlots[LSlot][LI];
    if not LEntry.Active then
      Continue;
    if LEntry.Rounds > 0 then
    begin
      Dec(FSlots[LSlot][LI].Rounds);
      Continue;
    end;
    // Timer expired
    FSlots[LSlot][LI].Active := False;
    if Assigned(LEntry.Callback) then
      LEntry.Callback(LEntry.Data);
    Inc(Result);
  end;
end;

function TTimerWheel.GetCurrentSlot: Int64;
begin
  Result := FCurrentSlot;
end;

function TTimerWheel.GetTotalTicks: Int64;
begin
  Result := AtomicLoad64(FTotalTicks, moAcquire);
end;

function TTimerWheel.GetTickIntervalNs: Int64;
begin
  Result := FTickIntervalNs;
end;

procedure TTimerWheel.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TTimerWheel.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
