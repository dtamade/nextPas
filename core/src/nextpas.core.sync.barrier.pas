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
  nextpas.core.errors,
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
    raise EArgumentError.Create('Barrier: count must be > 0');
  FTotal := ACount;
  FCount := ACount;
  FGeneration := 0;
end;

function TBarrier.Wait: TBarrierWaitResult;
var
  LGen, LRemaining: Int32;
begin
  LGen := AtomicLoad32(FGeneration, moAcquire);
  LRemaining := AtomicFetchSub32(FCount, 1, moAcqRel) - 1;

  if LRemaining = 0 then
  begin
    AtomicStore32(FCount, FTotal, moRelease);
    AtomicFetchAdd32(FGeneration, 1, moRelease);
    platform_wake_address_all(@FGeneration);
    Result.IsLeader := True;
    Result.Generation := LGen;
  end
  else
  begin
    while AtomicLoad32(FGeneration, moAcquire) = LGen do
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
