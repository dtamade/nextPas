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
  private
    FBuffer: array of T;
    FCapacity: Int64;
    FMask: Int64;
    FHead: Int64;
    FTail: Int64;
    FClosed: Int32;
    class function LockFreeNextPow2(AValue: Int64): Int64; static;
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

class function TRingBufferImpl.LockFreeNextPow2(AValue: Int64): Int64;
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

constructor TRingBufferImpl.Create(const ACapacity: Int64);
begin
  if ACapacity <= 0 then
    raise EArgumentError.Create('TRingBuffer: capacity must be > 0');
  inherited Create;
  FCapacity := LockFreeNextPow2(ACapacity);
  FMask := FCapacity - 1;
  SetLength(FBuffer, FCapacity);
  FHead := 0;
  FTail := 0;
  FClosed := 0;
end;

function TRingBufferImpl.TryWrite(const AValue: T): TLockFreeRingBufferResult;
var
  LHead, LNext: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rbClosed);
  repeat
    LHead := AtomicLoad64(FHead, moRelaxed);
    LNext := (LHead + 1) and FMask;
    if LNext = AtomicLoad64(FTail, moAcquire) then
      Exit(rbFull);
  until AtomicCompareExchange64(FHead, LHead, LNext, moAcqRel) = LHead;
  FBuffer[LHead] := AValue;
  Result := rbWritten;
end;

function TRingBufferImpl.TryRead(out AValue: T): TLockFreeRingBufferResult;
var
  LTail, LNext: Int64;
begin
  repeat
    LTail := AtomicLoad64(FTail, moRelaxed);
    if LTail = AtomicLoad64(FHead, moAcquire) then
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(rbClosed);
      Exit(rbEmpty);
    end;
    LNext := (LTail + 1) and FMask;
  until AtomicCompareExchange64(FTail, LTail, LNext, moAcqRel) = LTail;
  AValue := FBuffer[LTail];
  Result := rbWritten;
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
  if LHead >= LTail then
    Result := LHead - LTail
  else
    Result := FCapacity - LTail + LHead;
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
  Result := ((LHead + 1) and FMask) = LTail;
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
