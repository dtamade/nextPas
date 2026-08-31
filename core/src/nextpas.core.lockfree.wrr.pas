{******************************************************************************
  nextpas.core.lockfree.wrr

  Weighted Round Robin: 加权轮询负载均衡器

  算法: 平滑加权轮询 (Smooth Weighted Round Robin, Nginx 算法)

  核心思想: 每个后端有 weight (配置权重) 和 current (当前权重)。
  每次选择 current 最大的后端，选择后 current -= totalWeight，
  其他后端 current += weight。实现平滑分配。

  复杂度:
    - Next: O(N) — 线性扫描后端列表
    - AddBackend: O(1)
    - 空间: O(N)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.wrr;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

const
  WRR_MAX_BACKENDS = 64;

type
  TWRRStatus = (
    wrrOk = 0,
    wrrClosed = 1,
    wrrNoBackends = 2,
    wrrFull = 3,
    wrrNotFound = 4,
    wrrInvalidWeight = 5
  );

  PWRRBackend = ^TWRRBackend;
  TWRRBackend = record
    FId: UInt64;
    FWeight: Integer;
    FCurrent: Integer;
    FActive: Boolean;
  end;

  TWRRImpl = class
  private
    FBackends: array of TWRRBackend;
    FCount: Integer;
    FCapacity: Integer;
    FTotalWeight: Integer;
    FLock: Int32;
    FClosed: Int32;

    procedure Lock;
    procedure Unlock;
  public
    constructor Create(ACapacity: UInt32 = WRR_MAX_BACKENDS);
    destructor Destroy; override;

    function AddBackend(AId: UInt64; AWeight: Integer): TWRRStatus;
    function RemoveBackend(AId: UInt64): TWRRStatus;
    function UpdateWeight(AId: UInt64; AWeight: Integer): TWRRStatus;
    function Next(out AId: UInt64): TWRRStatus;
    function GetCount: Integer;
    function GetTotalWeight: Integer;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

{ TWRRImpl }

procedure TWRRImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TWRRImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

constructor TWRRImpl.Create(ACapacity: UInt32);
var
  LI: Integer;
begin
  inherited Create;
  if ACapacity < 1 then
    ACapacity := 1;
  if ACapacity > WRR_MAX_BACKENDS then
    ACapacity := WRR_MAX_BACKENDS;
  FCapacity := ACapacity;
  FCount := 0;
  FTotalWeight := 0;
  SetLength(FBackends, FCapacity);
  for LI := 0 to FCapacity - 1 do
  begin
    FBackends[LI].FId := 0;
    FBackends[LI].FWeight := 0;
    FBackends[LI].FCurrent := 0;
    FBackends[LI].FActive := False;
  end;
  FLock := 0;
  FClosed := 0;
end;

destructor TWRRImpl.Destroy;
begin
  SetLength(FBackends, 0);
  inherited Destroy;
end;

function TWRRImpl.AddBackend(AId: UInt64; AWeight: Integer): TWRRStatus;
var
  LI: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(wrrClosed);
  if AWeight < 1 then
    Exit(wrrInvalidWeight);

  Lock;
  try
    for LI := 0 to FCount - 1 do
    begin
      if FBackends[LI].FId = AId then
      begin
        FTotalWeight := FTotalWeight - FBackends[LI].FWeight + AWeight;
        FBackends[LI].FWeight := AWeight;
        FBackends[LI].FCurrent := 0;
        Exit(wrrOk);
      end;
    end;

    if FCount >= FCapacity then
      Exit(wrrFull);

    FBackends[FCount].FId := AId;
    FBackends[FCount].FWeight := AWeight;
    FBackends[FCount].FCurrent := 0;
    FBackends[FCount].FActive := True;
    Inc(FCount);
    FTotalWeight := FTotalWeight + AWeight;

    Result := wrrOk;
  finally
    Unlock;
  end;
end;

function TWRRImpl.RemoveBackend(AId: UInt64): TWRRStatus;
var
  LI, LIdx: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(wrrClosed);

  Lock;
  try
    LIdx := -1;
    for LI := 0 to FCount - 1 do
    begin
      if FBackends[LI].FId = AId then
      begin
        LIdx := LI;
        Break;
      end;
    end;

    if LIdx < 0 then
      Exit(wrrNotFound);

    FTotalWeight := FTotalWeight - FBackends[LIdx].FWeight;
    Dec(FCount);
    for LI := LIdx to FCount - 1 do
      FBackends[LI] := FBackends[LI + 1];

    Result := wrrOk;
  finally
    Unlock;
  end;
end;

function TWRRImpl.UpdateWeight(AId: UInt64; AWeight: Integer): TWRRStatus;
var
  LI: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(wrrClosed);
  if AWeight < 1 then
    Exit(wrrInvalidWeight);

  Lock;
  try
    for LI := 0 to FCount - 1 do
    begin
      if FBackends[LI].FId = AId then
      begin
        FTotalWeight := FTotalWeight - FBackends[LI].FWeight + AWeight;
        FBackends[LI].FWeight := AWeight;
        FBackends[LI].FCurrent := 0;
        Exit(wrrOk);
      end;
    end;
    Result := wrrNotFound;
  finally
    Unlock;
  end;
end;

function TWRRImpl.Next(out AId: UInt64): TWRRStatus;
var
  LI, LBestIdx: Integer;
  LMaxCurrent: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(wrrClosed);

  Lock;
  try
    if FCount = 0 then
    begin
      AId := 0;
      Exit(wrrNoBackends);
    end;

    for LI := 0 to FCount - 1 do
      FBackends[LI].FCurrent := FBackends[LI].FCurrent + FBackends[LI].FWeight;

    LBestIdx := 0;
    LMaxCurrent := FBackends[0].FCurrent;
    for LI := 1 to FCount - 1 do
    begin
      if FBackends[LI].FCurrent > LMaxCurrent then
      begin
        LMaxCurrent := FBackends[LI].FCurrent;
        LBestIdx := LI;
      end;
    end;

    FBackends[LBestIdx].FCurrent := FBackends[LBestIdx].FCurrent - FTotalWeight;

    AId := FBackends[LBestIdx].FId;
    Result := wrrOk;
  finally
    Unlock;
  end;
end;

function TWRRImpl.GetCount: Integer;
begin
  Result := FCount;
end;

function TWRRImpl.GetTotalWeight: Integer;
begin
  Result := FTotalWeight;
end;

procedure TWRRImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TWRRImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
