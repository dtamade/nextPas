unit nextpas.core.lockfree.phaser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreePhaserArriveResult = (paArrived, paAdvanced, paClosed, paTimeout);

  {** @desc 并发相位同步器（Phaser）
    @details 灵活的同步屏障，支持动态注册/注销。
      每个相位(phase)有 N 个参与方，所有参与方到达后进入下一相位。
      支持 Register/Arrive/ArriveAndAwaitAdvance/ArriveAndDeregister。
      适用场景：分阶段并行计算、动态任务分组。
  }
  TPhaser = class
  private
    FStateLock: Int32;
    FPhase: Int64;
    FParties: Int64;
    FArrived: Int64;
    FClosed: Int32;
    procedure AcquireState;
    procedure ReleaseState;
    function ArriveInternal(const ADeregister: Boolean; out AWaitPhase: Int64): Int64;
    function AwaitAdvanceInternal(const APhase: Int64; const ATimeoutNs: Int64): TLockFreePhaserArriveResult;
  public
    constructor Create(const AParties: Int64 = 0);
    destructor Destroy; override;
    function Register: Int64;
    function Arrive: Int64;
    function ArriveAndAwaitAdvance: Int64;
    function ArriveAndDeregister: Int64;
    function AwaitAdvance(const APhase: Int64): TLockFreePhaserArriveResult;
    function AwaitAdvanceTimeout(const APhase: Int64; const ATimeoutNs: Int64): TLockFreePhaserArriveResult;
    function GetPhase: Int64;
    function GetParties: Int64;
    function GetArrived: Int64;
    function GetUnarrived: Int64;
    procedure Terminate;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsTerminated: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TPhaser.Create(const AParties: Int64);
begin
  if AParties < 0 then
    raise EArgumentError.Create('TPhaser: parties must be >= 0');
  inherited Create;
  FStateLock := 0;
  FPhase := 0;
  FParties := AParties;
  FArrived := 0;
  FClosed := 0;
end;

procedure TPhaser.AcquireState;
var
  LSpinCount: Int32;
  LCasExpected: Int32;
begin
  LSpinCount := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FStateLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Exit;
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TPhaser.ReleaseState;
begin
  atomic_store(FStateLock, 0, mo_release);
end;

function TPhaser.Register: Int64;
begin
  AcquireState;
  try
    Result := atomic_load_64(FPhase, mo_acquire);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    if atomic_load_64(FParties, mo_relaxed) = High(Int64) then
      raise EInvalidOperationError.Create('TPhaser.Register: party count overflow');
    atomic_fetch_add_64(FParties, 1, mo_release);
  finally
    ReleaseState;
  end;
end;

function TPhaser.ArriveInternal(const ADeregister: Boolean;
  out AWaitPhase: Int64): Int64;
var
  LArrived: Int64;
  LParties: Int64;
begin
  AcquireState;
  try
    AWaitPhase := atomic_load_64(FPhase, mo_relaxed);
    Result := AWaitPhase;
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    LParties := atomic_load_64(FParties, mo_relaxed);
    LArrived := atomic_load_64(FArrived, mo_relaxed);

    if ADeregister then
    begin
      if LParties <= 0 then
        Exit;
      Dec(LParties);
      atomic_store_64(FParties, LParties, mo_relaxed);
    end
    else if LParties > 0 then
    begin
      if LArrived = High(Int64) then
        raise EInvalidOperationError.Create('TPhaser.Arrive: arrived count overflow');
      Inc(LArrived);
      atomic_store_64(FArrived, LArrived, mo_relaxed);
    end;

    if (LParties = 0) or (LArrived >= LParties) then
    begin
      atomic_store_64(FArrived, 0, mo_relaxed);
      Result := AWaitPhase + 1;
      atomic_store_64(FPhase, Result, mo_release);
    end;
  finally
    ReleaseState;
  end;
end;

function TPhaser.Arrive: Int64;
var
  LWaitPhase: Int64;
begin
  Result := ArriveInternal(False, LWaitPhase);
end;

function TPhaser.ArriveAndAwaitAdvance: Int64;
var
  LPhase: Int64;
begin
  Result := ArriveInternal(False, LPhase);
  if Result <> LPhase then
    Exit;

  while atomic_load_64(FPhase, mo_acquire) = LPhase do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
    begin
      Result := LPhase;
      Exit;
    end;
    CpuPause;
  end;
  Result := atomic_load_64(FPhase, mo_acquire);
end;

function TPhaser.ArriveAndDeregister: Int64;
var
  LWaitPhase: Int64;
begin
  Result := ArriveInternal(True, LWaitPhase);
end;

function TPhaser.AwaitAdvanceInternal(const APhase: Int64; const ATimeoutNs: Int64): TLockFreePhaserArriveResult;
var
  LStart: TInstant;
  LUseTimeout: Boolean;
begin
  LStart := Default(TInstant);
  LUseTimeout := ATimeoutNs > 0;
  if LUseTimeout then
    LStart := TInstant.Now;

  while atomic_load_64(FPhase, mo_acquire) = APhase do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(paClosed);
    if LUseTimeout and (LStart.Elapsed.AsNanoseconds >= ATimeoutNs) then
      Exit(paTimeout);
    CpuPause;
  end;
  Result := paAdvanced;
end;

function TPhaser.AwaitAdvance(const APhase: Int64): TLockFreePhaserArriveResult;
begin
  Result := AwaitAdvanceInternal(APhase, 0);
end;

function TPhaser.AwaitAdvanceTimeout(const APhase: Int64; const ATimeoutNs: Int64): TLockFreePhaserArriveResult;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TPhaser.AwaitAdvanceTimeout: timeout must be > 0');
  Result := AwaitAdvanceInternal(APhase, ATimeoutNs);
end;

function TPhaser.GetPhase: Int64;
begin
  Result := atomic_load_64(FPhase, mo_acquire);
end;

function TPhaser.GetParties: Int64;
begin
  Result := atomic_load_64(FParties, mo_acquire);
end;

function TPhaser.GetArrived: Int64;
begin
  Result := atomic_load_64(FArrived, mo_acquire);
end;

function TPhaser.GetUnarrived: Int64;
begin
  AcquireState;
  try
    Result := atomic_load_64(FParties, mo_relaxed) - atomic_load_64(FArrived, mo_relaxed);
  finally
    ReleaseState;
  end;
end;

procedure TPhaser.Terminate;
begin
  atomic_store(FClosed, 1, mo_release);
end;

procedure TPhaser.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TPhaser.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TPhaser.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TPhaser.IsTerminated: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
