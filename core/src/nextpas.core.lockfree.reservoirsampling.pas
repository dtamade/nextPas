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
    FPRNG_S0, FPRNG_S1: UInt64;
    FLock: Int32;
    FClosed: Int32;
    class var FSeedCounter: Int64;
    class function MixSeed(const AValue: UInt64): UInt64; static; inline;
    procedure Lock; inline;
    procedure Unlock; inline;
    function NextRandom: UInt64; inline;
    function NextRandomBounded(const ABound: UInt64): UInt64;
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
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.atomic;

class function TReservoirSamplerImpl.MixSeed(const AValue: UInt64): UInt64;
var
  LMixed: UInt64;
begin
  LMixed := AValue xor (AValue shr 30);
  LMixed := LMixed * QWord($BF58476D1CE4E5B9);
  LMixed := LMixed xor (LMixed shr 27);
  LMixed := LMixed * QWord($94D049BB133111EB);
  Result := LMixed xor (LMixed shr 31);
end;

constructor TReservoirSamplerImpl.Create(const ACapacity: Int32);
var
  LNonce: UInt64;
begin
  if ACapacity < 1 then
    raise EArgumentError.Create('TReservoirSampler: capacity must be >= 1');
  if IsManagedType(T) then
    raise EArgumentError.Create('TReservoirSampler: T must be unmanaged');
  inherited Create;
  FCapacity := ACapacity;
  FCount := 0;
  LNonce := UInt64(AtomicFetchAdd64(FSeedCounter, 1, moRelaxed)) + 1;
  FPRNG_S0 := MixSeed(LNonce xor UInt64(PtrUInt(Self)) xor UInt64(ACapacity));
  FPRNG_S1 := MixSeed(LNonce xor QWord($9E3779B97F4A7C15));
  if FPRNG_S0 = 0 then FPRNG_S0 := QWord($DEADBEEFCAFEBABE);
  if FPRNG_S1 = 0 then FPRNG_S1 := QWord($123456789ABCDEF0);
  { Warm up: skip initial transient }
  NextRandom; NextRandom; NextRandom; NextRandom;
  FLock := 0;
  FClosed := 0;
  SetLength(FReservoir, FCapacity);
end;

procedure TReservoirSamplerImpl.Lock;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TReservoirSamplerImpl.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TReservoirSamplerImpl.NextRandom: UInt64; inline;
var
  LS1, LS0: UInt64;
begin
  { xorshift128+ — much better statistical quality than xorshift32 }
  LS0 := FPRNG_S0;
  LS1 := FPRNG_S1;
  FPRNG_S0 := LS1;
  LS0 := LS0 xor (LS0 shl 23);
  FPRNG_S1 := LS0 xor LS1 xor (LS0 shr 17) xor (LS1 shr 26);
  Result := FPRNG_S1 + LS1;
end;

function TReservoirSamplerImpl.NextRandomBounded(const ABound: UInt64): UInt64;
var
  LThreshold: UInt64;
begin
  if ABound = 0 then
    raise EArgumentError.Create('TReservoirSampler: random bound must be > 0');
  LThreshold := (High(UInt64) - ABound + 1) mod ABound;
  repeat
    Result := NextRandom;
  until Result >= LThreshold;
  Result := Result mod ABound;
end;

function TReservoirSamplerImpl.Add(const AItem: T): TReservoirResult;
var
  LIdx: Int64;
  LDraw: UInt64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rsClosed);
  Lock;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(rsClosed);
    if FCount = High(Int64) then
      raise EOverflow.Create('TReservoirSampler: item count overflow');
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
      LDraw := NextRandomBounded(UInt64(LIdx) + 1);
      if LDraw < UInt64(FCapacity) then
      begin
        FReservoir[Int32(LDraw)] := AItem;
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
    if LSize > 0 then
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
  Lock;
  try
    AtomicStore32(FClosed, 1, moRelease);
  finally
    Unlock;
  end;
end;

function TReservoirSamplerImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
