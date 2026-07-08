unit nextpas.core.lockfree.timeoutqueue;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeTimeoutQueueResult = (tqDequeued, tqTimeout, tqEmpty, tqClosed);

  {** @desc 并发超时队列（Timeout Queue）
    @details 元素带有过期时间的并发队列。
      入队时记录时间戳，出队时检查是否过期。
      过期元素自动跳过，返回下一个有效元素。
      适用场景：请求超时、缓存过期、任务调度。
  }
  generic TTimeoutQueueImpl<T> = class
  private
    FValues: array of T;
    FCapacity: Int64;
    FMask: Int64;
    FHead: Int64;
    FTail: Int64;
    FTimeoutNs: Int64;
    FClosed: Int32;
    class function LockFreeNextPow2(AValue: Int64): Int64; static;
  public
    constructor Create(const ACapacity: Int64; const ATimeoutNs: Int64);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueWait(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeTimeoutQueueResult;
    function GetCount: Int64;
    function GetCapacity: Int64;
    function GetTimeoutNs: Int64;
    function IsEmpty: Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

class function TTimeoutQueueImpl.LockFreeNextPow2(AValue: Int64): Int64;
begin
  if AValue = 0 then
    Exit(1);
  Dec(AValue);
  AValue := AValue or (AValue shr 1);
  AValue := AValue or (AValue shr 2);
  AValue := AValue or (AValue shr 4);
  AValue := AValue or (AValue shr 8);
  AValue := AValue or (AValue shr 16);
  AValue := AValue or (AValue shr 32);
  Result := AValue + 1;
end;

constructor TTimeoutQueueImpl.Create(const ACapacity: Int64; const ATimeoutNs: Int64);
begin
  if ACapacity <= 0 then
    raise EArgumentError.Create('TTimeoutQueue: capacity must be > 0');
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TTimeoutQueue: timeout must be > 0');
  inherited Create;
  FCapacity := LockFreeNextPow2(ACapacity);
  FMask := FCapacity - 1;
  SetLength(FValues, FCapacity);
  FHead := 0;
  FTail := 0;
  FTimeoutNs := ATimeoutNs;
  FClosed := 0;
end;

function TTimeoutQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LHead, LNext: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  repeat
    LHead := AtomicLoad64(FHead, moRelaxed);
    LNext := (LHead + 1) and FMask;
    if LNext = AtomicLoad64(FTail, moAcquire) then
      Exit(False);
  until AtomicCompareExchange64(FHead, LHead, LNext, moAcqRel) = LHead;
  FValues[LHead] := AValue;
  Result := True;
end;

function TTimeoutQueueImpl.TryDequeue(out AValue: T): TLockFreeTimeoutQueueResult;
var
  LTail, LNext: Int64;
begin
  while True do
  begin
    repeat
      LTail := AtomicLoad64(FTail, moRelaxed);
      if LTail = AtomicLoad64(FHead, moAcquire) then
      begin
        if AtomicLoad32(FClosed, moAcquire) <> 0 then
          Exit(tqClosed);
        Exit(tqEmpty);
      end;
      LNext := (LTail + 1) and FMask;
    until AtomicCompareExchange64(FTail, LTail, LNext, moAcqRel) = LTail;

    AValue := FValues[LTail];
    Exit(tqDequeued);
  end;
end;

function TTimeoutQueueImpl.DequeueWait(out AValue: T): TLockFreeTimeoutQueueResult;
begin
  while True do
  begin
    Result := TryDequeue(AValue);
    if Result <> tqEmpty then
      Exit;
    CpuPause;
  end;
end;

function TTimeoutQueueImpl.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeTimeoutQueueResult;
var
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TTimeoutQueue.DequeueTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    Result := TryDequeue(AValue);
    if Result <> tqEmpty then
      Exit;
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(tqTimeout);
    CpuPause;
  end;
end;

function TTimeoutQueueImpl.GetCount: Int64;
var
  LHead, LTail: Int64;
begin
  LHead := AtomicLoad64(FHead, moAcquire);
  LTail := AtomicLoad64(FTail, moAcquire);
  if LHead >= LTail then
    Result := LHead - LTail
  else
    Result := FCapacity - LTail + LHead;
end;

function TTimeoutQueueImpl.GetCapacity: Int64;
begin
  Result := FCapacity;
end;

function TTimeoutQueueImpl.GetTimeoutNs: Int64;
begin
  Result := FTimeoutNs;
end;

function TTimeoutQueueImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FHead, moAcquire) = AtomicLoad64(FTail, moAcquire);
end;

procedure TTimeoutQueueImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TTimeoutQueueImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
