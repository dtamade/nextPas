{******************************************************************************
  nextpas.core.lockfree.leakybucket

  Leaky Bucket Rate Limiter — constant output rate traffic shaping.

  Design:
  - Water level increases on request arrival
  - Decreases at constant leak rate over time
  - Rejects when bucket overflows (water level > capacity)
  - Unlike Token Bucket: enforces constant output rate, not bursty
  - Concurrent-safe: CAS spin lock

  Classic traffic shaping algorithm, complementary to Token Bucket.

  2026-07-06  Phase 11
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.leakybucket;

interface

uses
  nextpas.core.lockfree.base;

type
  TLeakyBucketResult = (lbAllowed, lbRejected, lbClosed);

  {** @desc 漏桶限流器
    @details 恒定速率漏水，请求加水。桶满则拒绝。
      与 TokenBucket 互补：TokenBucket 允许突发，LeakyBucket 强制平滑输出。 }
  TLeakyBucket = class
  private
    FLeakRate: Double;     { units per second }
    FBucketSize: Double;   { max water level }
    FLevel: Double;        { current water level }
    FLastLeakNs: UInt64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    procedure Leak;
  public
    constructor Create(const ALeakRatePerSecond: Double; const ABucketSize: Double);
    function TryAdd: TLeakyBucketResult;
    function TryAddN(const AN: Double): TLeakyBucketResult;
    procedure Close;
    function IsClosed: Boolean;
    function GetLeakRate: Double;
    function GetBucketSize: Double;
    function GetLevel: Double;
  end;

implementation

uses
  Math,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.time;

function GetNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

constructor TLeakyBucket.Create(const ALeakRatePerSecond: Double; const ABucketSize: Double);
begin
  if IsNan(ALeakRatePerSecond) or IsInfinite(ALeakRatePerSecond) or
     (ALeakRatePerSecond <= 0) then
    raise EArgumentError.Create('TLeakyBucket: leak rate must be > 0');
  if IsNan(ABucketSize) or IsInfinite(ABucketSize) or (ABucketSize <= 0) then
    raise EArgumentError.Create('TLeakyBucket: bucket size must be > 0');
  inherited Create;
  FLeakRate := ALeakRatePerSecond;
  FBucketSize := ABucketSize;
  FLevel := 0;
  FLastLeakNs := GetNowNs;
  FLock := 0;
  FClosed := 0;
end;

procedure TLeakyBucket.Lock;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TLeakyBucket.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TLeakyBucket.Leak;
var
  LNowNs: UInt64;
  LElapsedNs: UInt64;
  LElapsed: Double;
begin
  LNowNs := GetNowNs;
  if LNowNs <= FLastLeakNs then
    Exit;
  LElapsedNs := LNowNs - FLastLeakNs;
  FLastLeakNs := LNowNs;
  if FLevel <= 0 then
    Exit;
  LElapsed := Double(LElapsedNs) / 1000000000.0;
  if LElapsed >= FLevel / FLeakRate then
    FLevel := 0;
  if FLevel > 0 then
    FLevel := FLevel - LElapsed * FLeakRate;
end;

function TLeakyBucket.TryAdd: TLeakyBucketResult;
begin
  Result := TryAddN(1.0);
end;

function TLeakyBucket.TryAddN(const AN: Double): TLeakyBucketResult;
begin
  if IsNan(AN) or IsInfinite(AN) or (AN <= 0) then
    raise EArgumentError.Create('TLeakyBucket.TryAddN: N must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(lbClosed);
  Lock;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(lbClosed);
    Leak;
    if AN <= FBucketSize - FLevel then
    begin
      FLevel := FLevel + AN;
      Result := lbAllowed;
    end
    else
      Result := lbRejected;
  finally
    Unlock;
  end;
end;

procedure TLeakyBucket.Close;
begin
  Lock;
  try
    AtomicStore32(FClosed, 1, moRelease);
  finally
    Unlock;
  end;
end;

function TLeakyBucket.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLeakyBucket.GetLeakRate: Double;
begin
  Result := FLeakRate;
end;

function TLeakyBucket.GetBucketSize: Double;
begin
  Result := FBucketSize;
end;

function TLeakyBucket.GetLevel: Double;
begin
  Lock;
  try
    Leak;
    Result := FLevel;
  finally
    Unlock;
  end;
end;

end.
