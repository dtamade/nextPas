unit nextpas.core.lockfree.barrier;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TCyclicBarrierWaitResult = (bwArrived, bwClosed, bwTimeout, bwBroken);
  TBarrierGenerationOutcome = (bgoWaiting, bgoArrived, bgoBroken, bgoClosed);

  PBarrierGeneration = ^TBarrierGeneration;
  TBarrierGeneration = record
    Index: Int64;
    Remaining: Int64;
    Waiters: Int64;
    Outcome: TBarrierGenerationOutcome;
  end;

  {** @desc Concurrent cyclic barrier.
    @details Each generation keeps its outcome until every registered waiter
      has observed it. A timeout breaks only the generation in which it
      occurred; later generations remain reusable. }
  TCyclicBarrier = class
  private
    FParties: Int64;
    FStateLock: Int32;
    FGeneration: PBarrierGeneration;
    FClosed: Int32;
    procedure AcquireState;
    procedure ReleaseState;
    function CreateGeneration(const AIndex: Int64): PBarrierGeneration;
    procedure AdvanceGeneration(AGeneration: PBarrierGeneration;
      const AOutcome: TBarrierGenerationOutcome);
    procedure ReleaseGeneration(AGeneration: PBarrierGeneration);
    function AwaitInternal(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
  public
    constructor Create(const AParties: Int64);
    destructor Destroy; override;
    function Await: TCyclicBarrierWaitResult;
    function AwaitTimeout(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
    function GetParties: Int64;
    function GetNumberWaiting: Int64;
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TCyclicBarrier.Create(const AParties: Int64);
begin
  if (AParties <= 0) or (QWord(AParties) > QWord(High(UInt32))) then
    raise EArgumentError.Create('TCyclicBarrier: parties must be in 1..High(UInt32)');
  inherited Create;
  FParties := AParties;
  FStateLock := 0;
  FGeneration := CreateGeneration(0);
  FClosed := 0;
end;

destructor TCyclicBarrier.Destroy;
begin
  Dispose(FGeneration);
  inherited Destroy;
end;

procedure TCyclicBarrier.AcquireState;
var
  LSpinCount: Int32;
begin
  LSpinCount := 0;
  while AtomicCompareExchange32(FStateLock, 0, 1, moAcquire) <> 0 do
  begin
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TCyclicBarrier.ReleaseState;
begin
  AtomicStore32(FStateLock, 0, moRelease);
end;

function TCyclicBarrier.CreateGeneration(const AIndex: Int64): PBarrierGeneration;
begin
  New(Result);
  Result^.Index := AIndex;
  Result^.Remaining := FParties;
  Result^.Waiters := 0;
  Result^.Outcome := bgoWaiting;
end;

procedure TCyclicBarrier.AdvanceGeneration(AGeneration: PBarrierGeneration;
  const AOutcome: TBarrierGenerationOutcome);
var
  LNextIndex: Int64;
  LNextGeneration: PBarrierGeneration;
begin
  if AGeneration^.Index = High(Int64) then
    LNextIndex := 0
  else
    LNextIndex := AGeneration^.Index + 1;
  LNextGeneration := CreateGeneration(LNextIndex);
  AGeneration^.Outcome := AOutcome;
  FGeneration := LNextGeneration;
  if AGeneration^.Waiters = 0 then
    Dispose(AGeneration);
end;

procedure TCyclicBarrier.ReleaseGeneration(AGeneration: PBarrierGeneration);
begin
  if AGeneration^.Waiters <= 0 then
    Exit;
  Dec(AGeneration^.Waiters);
  if (AGeneration^.Waiters = 0) and (AGeneration <> FGeneration) then
    Dispose(AGeneration);
end;

function TCyclicBarrier.AwaitInternal(
  const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
var
  LDone: Boolean;
  LGeneration: PBarrierGeneration;
  LSpinCount: Int32;
  LStart: TInstant;
  LUseTimeout: Boolean;
begin
  LUseTimeout := ATimeoutNs > 0;
  if LUseTimeout then
    LStart := TInstant.Now;

  AcquireState;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(bwClosed);
    LGeneration := FGeneration;
    Inc(LGeneration^.Waiters);
    Dec(LGeneration^.Remaining);
    if LGeneration^.Remaining = 0 then
    begin
      AdvanceGeneration(LGeneration, bgoArrived);
      ReleaseGeneration(LGeneration);
      Exit(bwArrived);
    end;
  finally
    ReleaseState;
  end;

  LSpinCount := 0;
  while True do
  begin
    LDone := False;
    AcquireState;
    try
      case LGeneration^.Outcome of
        bgoArrived:
          begin
            Result := bwArrived;
            LDone := True;
          end;
        bgoBroken:
          begin
            Result := bwBroken;
            LDone := True;
          end;
        bgoClosed:
          begin
            Result := bwClosed;
            LDone := True;
          end;
        bgoWaiting:
          if LUseTimeout and
             (LStart.Elapsed.AsNanoseconds >= ATimeoutNs) then
          begin
            AdvanceGeneration(LGeneration, bgoBroken);
            Result := bwTimeout;
            LDone := True;
          end;
      end;
      if LDone then
        ReleaseGeneration(LGeneration);
    finally
      ReleaseState;
    end;
    if LDone then
      Exit;
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

function TCyclicBarrier.Await: TCyclicBarrierWaitResult;
begin
  Result := AwaitInternal(0);
end;

function TCyclicBarrier.AwaitTimeout(
  const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TCyclicBarrier.AwaitTimeout: timeout must be > 0');
  Result := AwaitInternal(ATimeoutNs);
end;

function TCyclicBarrier.GetParties: Int64;
begin
  Result := FParties;
end;

function TCyclicBarrier.GetNumberWaiting: Int64;
begin
  AcquireState;
  try
    Result := FGeneration^.Waiters;
  finally
    ReleaseState;
  end;
end;

procedure TCyclicBarrier.Reset;
begin
  AcquireState;
  try
    if FGeneration^.Outcome = bgoWaiting then
      AdvanceGeneration(FGeneration, bgoBroken);
  finally
    ReleaseState;
  end;
end;

procedure TCyclicBarrier.Close;
begin
  AcquireState;
  try
    if AtomicLoad32(FClosed, moRelaxed) <> 0 then
      Exit;
    AtomicStore32(FClosed, 1, moRelease);
    if FGeneration^.Outcome = bgoWaiting then
      FGeneration^.Outcome := bgoClosed;
  finally
    ReleaseState;
  end;
end;

function TCyclicBarrier.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
