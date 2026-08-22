unit nextpas.core.lockfree.ringbuffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeRingBufferResult = (rbWritten, rbFull, rbEmpty, rbClosed);

  {** @desc 并发环形缓冲区（Ring Buffer）
    @details 固定大小 FIFO 队列，基于数组实现。
      使用 head/tail 指针 + CAS 实现 MPMC 安全。
      容量自动取整到 2 的幂，使用位掩码取模。
      适用场景：生产者-消费者、日志缓冲、实时系统。
  }
  generic TRingBufferImpl<T> = class
  private type
    TSlot = record
      Sequence: Int64;
      Value: T;
    end;
  private
    { Read-mostly header: written once in Create, read every op — keep off
      the CAS-hot lines below (F-033 thread-affinity layout rule). }
    FSlots: array of TSlot;
    FCapacity: Int64;
    FMask: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadHeader: TCacheLinePad;
    {$POP}
    { Producer line: FHead is CAS'd by every producer (TryWrite); consumers
      only acquire-read it. Isolating it keeps producer CAS invalidations
      from stomping the consumer CAS target below. }
    FHead: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadHead: TCacheLinePad;
    {$POP}
    { Consumer line: FTail is CAS'd by every consumer (TryRead). }
    FTail: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadTail: TCacheLinePad;
    {$POP}
    { Cold: written once on Close. }
    FClosed: Int32;
  public
    constructor Create(const ACapacity: Int64);
    destructor Destroy; override;
    function TryWrite(const AValue: T): TLockFreeRingBufferResult;
    function TryRead(out AValue: T): TLockFreeRingBufferResult;
    function WriteWait(const AValue: T): TLockFreeRingBufferResult;
    function ReadWait(out AValue: T): TLockFreeRingBufferResult;
    function WriteTimeout(const AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function ReadTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function Count: Int64; inline;
    function GetCapacity: Int64; inline;
    function IsEmpty: Boolean; inline;
    function IsFull: Boolean; inline;
    function Drain(const AMaxCount: Int64 = High(Int64)): Int64;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TRingBufferImpl.Create(const ACapacity: Int64);
var
  LI: Int64;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TRingBuffer: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity <= 0 then
    raise EArgumentError.Create('TRingBuffer: capacity must be > 0');
  if ACapacity > (Int64(1) shl 62) then
    raise EArgumentError.Create('TRingBuffer: capacity exceeds signed power-of-two limit');
  inherited Create;
  FCapacity := Int64(LockFreeNextPow2(PtrUInt(ACapacity)));
  FMask := FCapacity - 1;
  SetLength(FSlots, FCapacity);
  for LI := 0 to FCapacity - 1 do
    FSlots[LI].Sequence := LI;
  FHead := 0;
  FTail := 0;
  FClosed := 0;
end;

function TRingBufferImpl.TryWrite(const AValue: T): TLockFreeRingBufferResult;
var
  LHead: Int64;
  LTail: Int64;
  LIdx: Int64;
  LSeq: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rbClosed);
  while True do
  begin
    LHead := atomic_load_64(FHead, mo_relaxed);
    LTail := atomic_load_64(FTail, mo_acquire);
    if (LHead - LTail) >= FCapacity then
      Exit(rbFull);
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
      atomic_store_64(FSlots[LIdx].Sequence, LHead + 1, mo_release);
      Exit(rbWritten);
    end;
  end;
end;

function TRingBufferImpl.TryRead(out AValue: T): TLockFreeRingBufferResult;
var
  LHead: Int64;
  LTail: Int64;
  LIdx: Int64;
  LSeq: Int64;
begin
  while True do
  begin
    LTail := atomic_load_64(FTail, mo_relaxed);
    LHead := atomic_load_64(FHead, mo_acquire);
    if LTail = LHead then
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(rbClosed);
      Exit(rbEmpty);
    end;
    LIdx := LTail and FMask;
    LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
    if LSeq <> (LTail + 1) then
    begin
      CpuPause;
      Continue;
    end;
    if atomic_compare_exchange_strong_64(FTail, LTail, LTail + 1, mo_acq_rel, mo_acquire) then
    begin
      AValue := FSlots[LIdx].Value;
      FSlots[LIdx].Value := Default(T);
      atomic_store_64(FSlots[LIdx].Sequence, LTail + FCapacity, mo_release);
      Exit(rbWritten);
    end;
  end;
end;

function TRingBufferImpl.WriteWait(const AValue: T): TLockFreeRingBufferResult;
begin
  while True do
  begin
    Result := TryWrite(AValue);
    if Result <> rbFull then
      Exit;
    CpuPause;
  end;
end;

function TRingBufferImpl.ReadWait(out AValue: T): TLockFreeRingBufferResult;
begin
  while True do
  begin
    Result := TryRead(AValue);
    if Result <> rbEmpty then
      Exit;
    CpuPause;
  end;
end;

function TRingBufferImpl.WriteTimeout(const AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
var
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TRingBuffer.WriteTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    Result := TryWrite(AValue);
    if Result <> rbFull then
      Exit;
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(rbFull);
    CpuPause;
  end;
end;

function TRingBufferImpl.ReadTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
var
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TRingBuffer.ReadTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    Result := TryRead(AValue);
    if Result <> rbEmpty then
      Exit;
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(rbEmpty);
    CpuPause;
  end;
end;

function TRingBufferImpl.Count: Int64; inline;
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

function TRingBufferImpl.GetCapacity: Int64; inline;
begin
  Result := FCapacity;
end;

function TRingBufferImpl.IsEmpty: Boolean; inline;
begin
  Result := atomic_load_64(FHead, mo_acquire) = atomic_load_64(FTail, mo_acquire);
end;

function TRingBufferImpl.IsFull: Boolean; inline;
var
  LHead, LTail: Int64;
begin
  LHead := atomic_load_64(FHead, mo_acquire);
  LTail := atomic_load_64(FTail, mo_acquire);
  Result := (LHead - LTail) >= FCapacity;
end;

function TRingBufferImpl.Drain(const AMaxCount: Int64): Int64;
var
  LValue: T;
  LCount: Int64;
begin
  LCount := 0;
  while LCount < AMaxCount do
  begin
    if TryRead(LValue) <> rbWritten then
      Break;
    Inc(LCount);
  end;
  Result := LCount;
end;

procedure TRingBufferImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TRingBufferImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TRingBufferImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
