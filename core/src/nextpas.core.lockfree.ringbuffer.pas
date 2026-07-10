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
    FSlots: array of TSlot;
    FCapacity: Int64;
    FMask: Int64;
    FHead: Int64;
    FTail: Int64;
    FClosed: Int32;
  public
    constructor Create(const ACapacity: Int64);
    function TryWrite(const AValue: T): TLockFreeRingBufferResult;
    function TryRead(out AValue: T): TLockFreeRingBufferResult;
    function WriteWait(const AValue: T): TLockFreeRingBufferResult;
    function ReadWait(out AValue: T): TLockFreeRingBufferResult;
    function WriteTimeout(const AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function ReadTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function Count: Int64;
    function GetCapacity: Int64;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    procedure Close;
    function IsClosed: Boolean;
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
    raise EArgumentError.Create('TRingBuffer: T must be unmanaged');
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
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rbClosed);
  while True do
  begin
    LHead := AtomicLoad64(FHead, moRelaxed);
    LTail := AtomicLoad64(FTail, moAcquire);
    if (LHead - LTail) >= FCapacity then
      Exit(rbFull);
    LIdx := LHead and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq <> LHead then
    begin
      CpuPause;
      Continue;
    end;
    if AtomicCompareExchange64(FHead, LHead, LHead + 1, moAcqRel) = LHead then
    begin
      FSlots[LIdx].Value := AValue;
      AtomicStore64(FSlots[LIdx].Sequence, LHead + 1, moRelease);
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
    LTail := AtomicLoad64(FTail, moRelaxed);
    LHead := AtomicLoad64(FHead, moAcquire);
    if LTail = LHead then
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(rbClosed);
      Exit(rbEmpty);
    end;
    LIdx := LTail and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq <> (LTail + 1) then
    begin
      CpuPause;
      Continue;
    end;
    if AtomicCompareExchange64(FTail, LTail, LTail + 1, moAcqRel) = LTail then
    begin
      AValue := FSlots[LIdx].Value;
      FSlots[LIdx].Value := Default(T);
      AtomicStore64(FSlots[LIdx].Sequence, LTail + FCapacity, moRelease);
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

function TRingBufferImpl.Count: Int64;
var
  LHead, LTail: Int64;
begin
  LHead := AtomicLoad64(FHead, moAcquire);
  LTail := AtomicLoad64(FTail, moAcquire);
  if LHead > LTail then
    Result := LHead - LTail
  else
    Result := 0;
end;

function TRingBufferImpl.GetCapacity: Int64;
begin
  Result := FCapacity;
end;

function TRingBufferImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FHead, moAcquire) = AtomicLoad64(FTail, moAcquire);
end;

function TRingBufferImpl.IsFull: Boolean;
var
  LHead, LTail: Int64;
begin
  LHead := AtomicLoad64(FHead, moAcquire);
  LTail := AtomicLoad64(FTail, moAcquire);
  Result := (LHead - LTail) >= FCapacity;
end;

procedure TRingBufferImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TRingBufferImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
