unit nextpas.core.lockfree.timeoutqueue;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.time.base;

type
  TLockFreeTimeoutQueueResult = (tqDequeued, tqTimeout, tqEmpty, tqClosed);
  TTimeoutQueueInstant = nextpas.core.time.base.TInstant;

  {** @desc 并发超时队列（Timeout Queue）
    @details 元素带有过期时间的并发队列。
      入队时记录时间戳，出队时检查是否过期。
      过期元素自动跳过，返回下一个有效元素。
      适用场景：请求超时、缓存过期、任务调度。
  }
  generic TTimeoutQueueImpl<T> = class
  private type
    TSlot = record
      Sequence: Int64;
      EnqueuedAt: TTimeoutQueueInstant;
      Value: T;
    end;
  private
    FSlots: array of TSlot;
    FCapacity: Int64;
    FMask: Int64;
    FHead: Int64;
    FTail: Int64;
    FTimeoutNs: Int64;
    FClosed: Int32;
  public
    constructor Create(const ACapacity: Int64; const ATimeoutNs: Int64);
    destructor Destroy; override;
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueWait(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeTimeoutQueueResult;
    function GetCount: Int64; inline;
    function GetCapacity: Int64; inline;
    function GetTimeoutNs: Int64; inline;
    function IsEmpty: Boolean; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TTimeoutQueueImpl.Create(const ACapacity: Int64; const ATimeoutNs: Int64);
var
  LI: Int64;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TTimeoutQueue: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity <= 0 then
    raise EArgumentError.Create('TTimeoutQueue: capacity must be > 0');
  if ACapacity > (Int64(1) shl 62) then
    raise EArgumentError.Create('TTimeoutQueue: capacity exceeds signed power-of-two limit');
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TTimeoutQueue: timeout must be > 0');
  inherited Create;
  FCapacity := Int64(LockFreeNextPow2(PtrUInt(ACapacity)));
  FMask := FCapacity - 1;
  SetLength(FSlots, FCapacity);
  for LI := 0 to FCapacity - 1 do
    FSlots[LI].Sequence := LI;
  FHead := 0;
  FTail := 0;
  FTimeoutNs := ATimeoutNs;
  FClosed := 0;
end;

function TTimeoutQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LHead: Int64;
  LTail: Int64;
  LIdx: Int64;
  LSeq: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  while True do
  begin
    LHead := atomic_load_64(FHead, mo_relaxed);
    LTail := atomic_load_64(FTail, mo_acquire);
    if (LHead - LTail) >= FCapacity then
      Exit(False);
    LIdx := LHead and FMask;
    LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
    if LSeq <> LHead then
    begin
      CpuPause;
      Continue;
    end;
    if atomic_compare_exchange_strong_64(FHead, LHead, LHead + 1, mo_acq_rel, mo_acquire) then
    begin
      FSlots[LIdx].Value := AValue;
      FSlots[LIdx].EnqueuedAt := TTimeoutQueueInstant.Now;
      atomic_store_64(FSlots[LIdx].Sequence, LHead + 1, mo_release);
      Exit(True);
    end;
  end;
end;

function TTimeoutQueueImpl.TryDequeue(out AValue: T): TLockFreeTimeoutQueueResult;
var
  LHead: Int64;
  LTail: Int64;
  LIdx: Int64;
  LSeq: Int64;
  LAgeNs: Int64;
  LNow: TTimeoutQueueInstant;
begin
  while True do
  begin
    LTail := atomic_load_64(FTail, mo_relaxed);
    LHead := atomic_load_64(FHead, mo_acquire);
    if LTail = LHead then
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(tqClosed);
      Exit(tqEmpty);
    end;

    LIdx := LTail and FMask;
    LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
    if LSeq <> (LTail + 1) then
    begin
      CpuPause;
      Continue;
    end;

    if not atomic_compare_exchange_strong_64(FTail, LTail, LTail + 1, mo_acq_rel, mo_acquire) then
      Continue;

    LNow := TTimeoutQueueInstant.Now;
    LAgeNs := (LNow - FSlots[LIdx].EnqueuedAt).AsNanoseconds;
    if LAgeNs < FTimeoutNs then
    begin
      AValue := FSlots[LIdx].Value;
      FSlots[LIdx].Value := Default(T);
      atomic_store_64(FSlots[LIdx].Sequence, LTail + FCapacity, mo_release);
      Exit(tqDequeued);
    end;

    FSlots[LIdx].Value := Default(T);
    atomic_store_64(FSlots[LIdx].Sequence, LTail + FCapacity, mo_release);
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
  LStart: TTimeoutQueueInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TTimeoutQueue.DequeueTimeout: timeout must be > 0');
  LStart := TTimeoutQueueInstant.Now;
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

function TTimeoutQueueImpl.GetCount: Int64; inline;
var
  LHead, LTail: Int64;
begin
  LHead := atomic_load_64(FHead, mo_acquire);
  LTail := atomic_load_64(FTail, mo_acquire);
  if LHead > LTail then
    Result := LHead - LTail
  else
    Result := 0;
end;

function TTimeoutQueueImpl.GetCapacity: Int64; inline;
begin
  Result := FCapacity;
end;

function TTimeoutQueueImpl.GetTimeoutNs: Int64; inline;
begin
  Result := FTimeoutNs;
end;

function TTimeoutQueueImpl.IsEmpty: Boolean; inline;
begin
  Result := atomic_load_64(FHead, mo_acquire) = atomic_load_64(FTail, mo_acquire);
end;

procedure TTimeoutQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TTimeoutQueueImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TTimeoutQueueImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
