unit nextpas.core.sync.barrier;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf;

function CreateBarrier(const ACount: Int32): IBarrier;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.sync.errors,
  nextpas.core.platform.sync;

type
  TBarrier = class(TInterfacedObject, IBarrier)
  private
    FTotal: Int32;
    FCount: Int32;
    FGeneration: Int32;
  public
    constructor Create(const ACount: Int32);
    function Wait: TBarrierWaitResult;
  end;

constructor TBarrier.Create(const ACount: Int32);
begin
  inherited Create;
  if ACount <= 0 then
    SyncRaiseArg('Barrier: count must be > 0');
  FTotal := ACount;
  FCount := ACount;
  FGeneration := 0;
end;

function TBarrier.Wait: TBarrierWaitResult;
var
  LGen, LRemaining: Int32;
begin
  LGen := atomic_load(FGeneration, mo_acquire);
  LRemaining := atomic_fetch_sub(FCount, 1, mo_acq_rel) - 1;

  if LRemaining = 0 then
  begin
    atomic_store(FCount, FTotal, mo_release);
    atomic_fetch_add(FGeneration, 1, mo_release);
    platform_wake_address_all(@FGeneration);
    Result.IsLeader := True;
    Result.Generation := LGen;
  end
  else
  begin
    while atomic_load(FGeneration, mo_acquire) = LGen do
      platform_wait_address32(@FGeneration, LGen, -1);
    Result.IsLeader := False;
    Result.Generation := LGen;
  end;
end;

function CreateBarrier(const ACount: Int32): IBarrier;
begin
  Result := TBarrier.Create(ACount);
end;

end.
