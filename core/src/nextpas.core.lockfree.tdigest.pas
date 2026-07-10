{******************************************************************************
  nextpas.core.lockfree.tdigest

  T-Digest: 流式分位数估计 (Streaming Quantile Estimation)

  算法: Ted Dunning & Otmar Ertl, "Computing Extremely Accurate Quantiles
  Using T-Digests" (2019)

  复杂度:
    - Add: O(k) — 维护有序质心列表
    - Quantile: O(k) — 线性扫描
    - 空间: O(k)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.tdigest;

{$mode objfpc}{$H+}

interface

uses
  Math,
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

const
  TDIGEST_DEFAULT_COMPRESSION = 100;

type
  TTDigestStatus = (
    tdOk = 0,
    tdClosed = 1,
    tdEmpty = 2
  );

  PCentroid = ^TCentroid;
  TCentroid = record
    FMean: Double;
    FCount: UInt64;
  end;

  TTDigestImpl = class
  private
    FCentroids: array of TCentroid;
    FCapacity: Integer;
    FCount: Integer;
    FTotalWeight: UInt64;
    FCompression: Double;
    FLock: Int32;
    FClosed: Int32;

    procedure CompressInternal;
    function FindInsertPos(const AMean: Double): Integer;
    procedure Lock;
    procedure Unlock;
  public
    constructor Create(ACompression: UInt32 = TDIGEST_DEFAULT_COMPRESSION);
    destructor Destroy; override;

    function Add(AValue: Double): TTDigestStatus;
    function Quantile(AQ: Double; out AValue: Double): TTDigestStatus;
    function Count: UInt64;
    function GetCompression: Double;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

procedure TTDigestImpl.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 1, 0) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TTDigestImpl.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

constructor TTDigestImpl.Create(ACompression: UInt32);
var
  LCap: Integer;
begin
  inherited Create;
  if ACompression < 10 then
    ACompression := 10;
  if ACompression > 1000 then
    ACompression := 1000;
  FCompression := ACompression;
  LCap := ACompression * 2 + 20;
  SetLength(FCentroids, LCap);
  FCapacity := LCap;
  FCount := 0;
  FTotalWeight := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TTDigestImpl.Destroy;
begin
  SetLength(FCentroids, 0);
  inherited Destroy;
end;

function TTDigestImpl.FindInsertPos(const AMean: Double): Integer;
var
  LLo, LHi, LMid: Integer;
begin
  LLo := 0;
  LHi := FCount;
  while LLo < LHi do
  begin
    LMid := (LLo + LHi) div 2;
    if FCentroids[LMid].FMean < AMean then
      LLo := LMid + 1
    else
      LHi := LMid;
  end;
  Result := LLo;
end;

procedure TTDigestImpl.CompressInternal;
var
  LNew: array of TCentroid;
  LNewCount, LI, LNewCap: Integer;
  LRange, LThreshold: Double;
begin
  if FCount <= 1 then
    Exit;

  { Compute merge threshold from data range and compression }
  LRange := FCentroids[FCount - 1].FMean - FCentroids[0].FMean;
  if LRange < 1e-12 then
    LRange := 1e-12;
  LThreshold := LRange / FCompression;
  if LThreshold < 1e-12 then
    LThreshold := 1e-12;

  LNewCap := FCapacity;
  SetLength(LNew, LNewCap);
  LNew[0] := FCentroids[0];
  LNewCount := 1;

  for LI := 1 to FCount - 1 do
  begin
    if (LNewCount > 0) and
       (Abs(FCentroids[LI].FMean - LNew[LNewCount - 1].FMean) < LThreshold) then
    begin
      LNew[LNewCount - 1].FMean :=
        (LNew[LNewCount - 1].FMean * LNew[LNewCount - 1].FCount +
         FCentroids[LI].FMean * FCentroids[LI].FCount) /
        (LNew[LNewCount - 1].FCount + FCentroids[LI].FCount);
      LNew[LNewCount - 1].FCount := LNew[LNewCount - 1].FCount + FCentroids[LI].FCount;
    end
    else
    begin
      if LNewCount >= LNewCap then
      begin
        LNewCap := LNewCap + LNewCap div 4 + 10;
        SetLength(LNew, LNewCap);
      end;
      LNew[LNewCount] := FCentroids[LI];
      Inc(LNewCount);
    end;
  end;

  SetLength(FCentroids, LNewCap);
  for LI := 0 to LNewCount - 1 do
    FCentroids[LI] := LNew[LI];
  FCount := LNewCount;
  FCapacity := LNewCap;
  SetLength(LNew, 0);
end;

function TTDigestImpl.Add(AValue: Double): TTDigestStatus;
var
  LPos, LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(tdClosed);

  Lock;
  try
    LPos := FindInsertPos(AValue);

    { Try to merge with adjacent centroid if values are very close }
    if (FCount > 0) and (LPos < FCount) and
       (Abs(FCentroids[LPos].FMean - AValue) < 1e-6) then
    begin
      FCentroids[LPos].FMean :=
        (FCentroids[LPos].FMean * FCentroids[LPos].FCount + AValue) /
        (FCentroids[LPos].FCount + 1);
      FCentroids[LPos].FCount := FCentroids[LPos].FCount + 1;
    end
    else if (LPos > 0) and (LPos <= FCount) and
            (Abs(FCentroids[LPos - 1].FMean - AValue) < 1e-6) then
    begin
      Dec(LPos);
      FCentroids[LPos].FMean :=
        (FCentroids[LPos].FMean * FCentroids[LPos].FCount + AValue) /
        (FCentroids[LPos].FCount + 1);
      FCentroids[LPos].FCount := FCentroids[LPos].FCount + 1;
    end
    else
    begin
      if (FCount >= FCapacity) or (FCount > Trunc(20.0 * FCompression)) then
        CompressInternal;
      if FCount >= FCapacity then
      begin
        { Last resort: merge with closest centroid }
        if LPos >= FCount then
          Dec(LPos);
        if LPos < 0 then
          LPos := 0;
        FCentroids[LPos].FMean :=
          (FCentroids[LPos].FMean * FCentroids[LPos].FCount + AValue) /
          (FCentroids[LPos].FCount + 1);
        FCentroids[LPos].FCount := FCentroids[LPos].FCount + 1;
      end
      else
      begin
        for LI := FCount downto LPos + 1 do
          FCentroids[LI] := FCentroids[LI - 1];
        FCentroids[LPos].FMean := AValue;
        FCentroids[LPos].FCount := 1;
        Inc(FCount);
      end;
    end;

    Inc(FTotalWeight);
    Result := tdOk;
  finally
    Unlock;
  end;
end;

function TTDigestImpl.Quantile(AQ: Double; out AValue: Double): TTDigestStatus;
var
  LTarget: Double;
  LWeightSoFar: UInt64;
  LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(tdClosed);
  if FTotalWeight = 0 then
    Exit(tdEmpty);
  if (AQ < 0.0) or (AQ > 1.0) then
  begin
    AValue := 0;
    Exit(tdEmpty);
  end;

  Lock;
  try
    if FCount = 0 then
    begin
      AValue := 0;
      Result := tdEmpty;
      Exit;
    end;

    LTarget := AQ * FTotalWeight;
    LWeightSoFar := 0;

    for LI := 0 to FCount - 1 do
    begin
      if LWeightSoFar + FCentroids[LI].FCount >= Trunc(LTarget) then
      begin
        AValue := FCentroids[LI].FMean;
        Result := tdOk;
        Exit;
      end;
      LWeightSoFar := LWeightSoFar + FCentroids[LI].FCount;
    end;

    AValue := FCentroids[FCount - 1].FMean;
    Result := tdOk;
  finally
    Unlock;
  end;
end;

function TTDigestImpl.Count: UInt64;
begin
  Result := FTotalWeight;
end;

function TTDigestImpl.GetCompression: Double;
begin
  Result := FCompression;
end;

procedure TTDigestImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TTDigestImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
