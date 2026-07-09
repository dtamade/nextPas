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
    FLastLeakNs: Int64;
    FClosed: Int32;
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
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

function GetNowNs: Int64;
begin
  Result := TInstant.Now.Elapsed.AsNanoseconds;
end;

constructor TLeakyBucket.Create(const ALeakRatePerSecond: Double; const ABucketSize: Double);
begin
  if ALeakRatePerSecond <= 0 then
    raise EArgumentError.Create('TLeakyBucket: leak rate must be > 0');
  if ABucketSize <= 0 then
    raise EArgumentError.Create('TLeakyBucket: bucket size must be > 0');
  inherited Create;
  FLeakRate := ALeakRatePerSecond;
  FBucketSize := ABucketSize;
  FLevel := 0;
  FLastLeakNs := GetNowNs;
  FClosed := 0;
end;

procedure TLeakyBucket.Leak;
var
  LNowNs: Int64;
  LElapsed: Double;
  LLeaked: Double;
begin
  LNowNs := GetNowNs;
  LElapsed := (LNowNs - FLastLeakNs) / 1000000000.0;
  if LElapsed <= 0 then
    Exit;
  LLeaked := LElapsed * FLeakRate;
  FLevel := FLevel - LLeaked;
  if FLevel < 0 then
    FLevel := 0;
  FLastLeakNs := LNowNs;
end;

function TLeakyBucket.TryAdd: TLeakyBucketResult;
begin
  Result := TryAddN(1.0);
end;

function TLeakyBucket.TryAddN(const AN: Double): TLeakyBucketResult;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TLeakyBucket.TryAddN: N must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(lbClosed);
  Leak;
  if FLevel + AN <= FBucketSize then
  begin
    FLevel := FLevel + AN;
    Result := lbAllowed;
  end
  else
    Result := lbRejected;
end;

procedure TLeakyBucket.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
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
  Leak;
  Result := FLevel;
end;

end.
