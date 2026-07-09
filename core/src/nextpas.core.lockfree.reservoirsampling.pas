{******************************************************************************
  nextpas.core.lockfree.reservoirsampling

  Reservoir Sampling — streaming uniform random sampling.

  Design:
  - Maintains a fixed-size reservoir of sampled items
  - On item i (0-indexed): if i < k, add to reservoir;
    otherwise replace a random element with probability k/i
  - Guarantees: each item in the stream has equal probability k/n of being
    in the final sample (Vitter's Algorithm R)
  - O(1) per item, O(k) space
  - Concurrent-safe: CAS spin lock

  Theory: Vitter "Random Sampling with a Reservoir" (1985)
  Use cases: streaming analytics, random subset selection, A/B testing.

  2026-07-06  Phase 11
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.reservoirsampling;

interface

uses
  nextpas.core.lockfree.base;

const
  RESERVOIR_DEFAULT_SIZE = 64;

type
  TReservoirResult = (rsAdded, rsReplaced, rsSkipped, rsClosed);

  {** @desc 蓄水池采样器
    @details 固定内存处理无限流，等概率采样。
      每个元素被选中的概率 = k/n（k=池大小，n=已见元素数）。 }
  generic TReservoirSamplerImpl<T> = class
  private
    type
      TItemArray = array of T;
  private
    FReservoir: TItemArray;
    FCapacity: Int32;
    FCount: Int64;
    FPRNG: UInt32;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function NextRandom: UInt32; inline;
  public
    constructor Create(const ACapacity: Int32 = RESERVOIR_DEFAULT_SIZE);
    function Add(const AItem: T): TReservoirResult;
    function GetCount: Int64;
    function GetSampleSize: Int32;
    procedure GetSample(out ASample: TItemArray);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

  generic TReservoirSampler<T> = class(specialize TReservoirSamplerImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TReservoirSamplerImpl.Create(const ACapacity: Int32);
begin
  if ACapacity < 1 then
    raise EArgumentError.Create('TReservoirSampler: capacity must be >= 1');
  if IsManagedType(T) then
    raise EArgumentError.Create('TReservoirSampler: T must be unmanaged');
  inherited Create;
  FCapacity := ACapacity;
  FCount := 0;
  FPRNG := 12345;
  FLock := 0;
  FClosed := 0;
  SetLength(FReservoir, FCapacity);
end;

procedure TReservoirSamplerImpl.Lock;
begin
  while AtomicCompareExchange32(FLock, 1, 0, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TReservoirSamplerImpl.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TReservoirSamplerImpl.NextRandom: UInt32; inline;
begin
  FPRNG := FPRNG xor (FPRNG shl 13);
  FPRNG := FPRNG xor (FPRNG shr 17);
  FPRNG := FPRNG xor (FPRNG shl 5);
  Result := FPRNG;
end;

function TReservoirSamplerImpl.Add(const AItem: T): TReservoirResult;
var
  LIdx: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rsClosed);
  Lock;
  try
    LIdx := FCount;
    Inc(FCount);
    if LIdx < FCapacity then
    begin
      { Reservoir not full: always add }
      FReservoir[Int32(LIdx)] := AItem;
      Exit(rsAdded);
    end
    else
    begin
      { Reservoir full: replace with probability k/i }
      if (NextRandom mod UInt32(LIdx + 1)) < UInt32(FCapacity) then
      begin
        FReservoir[Int32(NextRandom mod UInt32(FCapacity))] := AItem;
        Exit(rsReplaced);
      end;
      Result := rsSkipped;
    end;
  finally
    Unlock;
  end;
end;

function TReservoirSamplerImpl.GetCount: Int64;
begin
  Lock;
  try
    Result := FCount;
  finally
    Unlock;
  end;
end;

function TReservoirSamplerImpl.GetSampleSize: Int32;
begin
  Lock;
  try
    if FCount < FCapacity then
      Result := Int32(FCount)
    else
      Result := FCapacity;
  finally
    Unlock;
  end;
end;

procedure TReservoirSamplerImpl.GetSample(out ASample: TItemArray);
var
  LSize: Int32;
begin
  Lock;
  try
    if FCount < FCapacity then
      LSize := Int32(FCount)
    else
      LSize := FCapacity;
    SetLength(ASample, LSize);
    Move(FReservoir[0], ASample[0], LSize * SizeOf(T));
  finally
    Unlock;
  end;
end;

procedure TReservoirSamplerImpl.Clear;
begin
  Lock;
  try
    FCount := 0;
  finally
    Unlock;
  end;
end;

procedure TReservoirSamplerImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TReservoirSamplerImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
