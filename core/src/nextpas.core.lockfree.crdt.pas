unit nextpas.core.lockfree.crdt;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TCRDTResult = (crOk, crNotFound, crClosed, crInvalid);

  TInt64Array = array of Int64;

  {** @desc G-Counter (只增计数器)
    @details 多节点合并取最大值。每个节点独立计数，合并时取各节点最大值之和。
      适用场景：分布式计数、页面浏览量、点赞数。
  }
  TGCounter = class
  private
    FNodes: array of Int64;
    FNodeCount: Int32;
    FClosed: Int32;
    FLock: Int32;
    procedure Lock;
    procedure Unlock;
    procedure Snapshot(out ANodes: TInt64Array);
  public
    constructor Create(ANodeCount: Int32);
    function Increment(ANodeId: Int32; AAmount: Int64): TCRDTResult;
    function Value: Int64;
    function NodeValue(ANodeId: Int32): Int64;
    procedure Merge(const AOther: TGCounter);
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc PN-Counter (正负计数器)
    @details 两个 G-Counter 组合，一个计增一个计减。
      支持 Increment/Decrement，合并时分别合并。
  }
  TPNCounter = class
  private
    FPositive: TGCounter;
    FNegative: TGCounter;
    FClosed: Int32;
  public
    constructor Create(ANodeCount: Int32);
    destructor Destroy; override;
    function Increment(ANodeId: Int32; AAmount: Int64): TCRDTResult;
    function Decrement(ANodeId: Int32; AAmount: Int64): TCRDTResult;
    function Value: Int64;
    procedure Merge(const AOther: TPNCounter);
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc LWW-Register (最后写入胜出寄存器)
    @details 使用时间戳解决冲突，时间戳大的值胜出。
      适用场景：配置同步、状态复制。
  }
  TLWWRegister = class
  private
    FValue: AnsiString;
    FTimestamp: Int64;
    FClosed: Int32;
    FLock: Int32;
    procedure Lock;
    procedure Unlock;
    procedure Snapshot(out AValue: AnsiString; out ATimestamp: Int64);
  public
    constructor Create;
    function Assign(const AValue: AnsiString; ATimestamp: Int64): TCRDTResult;
    function Read(out AValue: AnsiString): Int64;
    procedure Merge(const AOther: TLWWRegister);
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc OR-Set (观察移除集合)
    @details 支持并发添加和删除，删除只影响已观察到的添加。
      使用唯一标签避免删除丢失。
  }
  TORSet = class
  private type
    TEntry = record
      Value: AnsiString;
      Tag: UInt64;
      Removed: Boolean;
    end;
    TEntries = array of TEntry;
  private
    FAddSet: TEntries;
    FCount: Int32;
    FCapacity: Int32;
    FClosed: Int32;
    FLock: Int32;
    class var FGlobalTag: UInt64;
    procedure Grow;
    function FindIndex(const AValue: AnsiString; ATag: UInt64): Int32;
    procedure Lock;
    procedure Unlock;
    procedure Snapshot(out AEntries: TEntries);
  public
    constructor Create;
    function Add(const AValue: AnsiString): TCRDTResult;
    function Remove(const AValue: AnsiString): TCRDTResult;
    function Contains(const AValue: AnsiString): Boolean;
    function Count: Int32;
    procedure Merge(const AOther: TORSet);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function TryAddCounterValue(var ATotal: Int64; AValue: Int64): Boolean;
begin
  Result := (AValue >= 0) and (AValue <= High(Int64) - ATotal);
  if Result then
    ATotal := ATotal + AValue;
end;

{ TGCounter }

constructor TGCounter.Create(ANodeCount: Int32);
var
  LI: Int32;
begin
  inherited Create;
  if ANodeCount <= 0 then
    raise EArgumentError.Create('TGCounter: node count must be positive');
  FNodeCount := ANodeCount;
  SetLength(FNodes, FNodeCount);
  for LI := 0 to FNodeCount - 1 do
    FNodes[LI] := 0;
  FClosed := 0;
  FLock := 0;
end;

procedure TGCounter.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TGCounter.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TGCounter.Snapshot(out ANodes: TInt64Array);
var
  LI: Int32;
begin
  Lock;
  try
    SetLength(ANodes, FNodeCount);
    for LI := 0 to FNodeCount - 1 do
      ANodes[LI] := FNodes[LI];
  finally
    Unlock;
  end;
end;

function TGCounter.Increment(ANodeId: Int32; AAmount: Int64): TCRDTResult;
var
  LI: Int32;
  LTotal: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  if (ANodeId < 0) or (ANodeId >= FNodeCount) then
    Exit(crNotFound);
  if AAmount < 0 then
    Exit(crInvalid);
  Lock;
  try
    LTotal := 0;
    for LI := 0 to FNodeCount - 1 do
      if not TryAddCounterValue(LTotal, FNodes[LI]) then
        Exit(crInvalid);
    if AAmount > High(Int64) - LTotal then
      Exit(crInvalid);
    FNodes[ANodeId] := FNodes[ANodeId] + AAmount;
    Result := crOk;
  finally
    Unlock;
  end;
end;

function TGCounter.Value: Int64;
var
  LI: Int32;
begin
  Lock;
  try
    Result := 0;
    for LI := 0 to FNodeCount - 1 do
      Result := Result + FNodes[LI];
  finally
    Unlock;
  end;
end;

function TGCounter.NodeValue(ANodeId: Int32): Int64;
begin
  Lock;
  try
    if (ANodeId < 0) or (ANodeId >= FNodeCount) then
      Result := 0
    else
      Result := FNodes[ANodeId];
  finally
    Unlock;
  end;
end;

procedure TGCounter.Merge(const AOther: TGCounter);
var
  LI, LJoinedCount: Int32;
  LJoinedValue, LTotal: Int64;
  LOtherNodes: TInt64Array;
begin
  if (AOther = nil) or (AOther = Self) then
    Exit;
  AOther.Snapshot(LOtherNodes);
  Lock;
  try
    LJoinedCount := FNodeCount;
    if Length(LOtherNodes) > LJoinedCount then
      LJoinedCount := Length(LOtherNodes);
    LTotal := 0;
    for LI := 0 to LJoinedCount - 1 do
    begin
      if LI < FNodeCount then
        LJoinedValue := FNodes[LI]
      else
        LJoinedValue := 0;
      if (LI < Length(LOtherNodes)) and
         (LOtherNodes[LI] > LJoinedValue) then
        LJoinedValue := LOtherNodes[LI];
      if not TryAddCounterValue(LTotal, LJoinedValue) then
        raise EArgumentError.Create(
          'TGCounter: merged value exceeds Int64 range');
    end;

    if Length(LOtherNodes) > FNodeCount then
    begin
      SetLength(FNodes, Length(LOtherNodes));
      FNodeCount := Length(LOtherNodes);
    end;
    for LI := 0 to High(LOtherNodes) do
      if LOtherNodes[LI] > FNodes[LI] then
        FNodes[LI] := LOtherNodes[LI];
  finally
    Unlock;
  end;
end;

procedure TGCounter.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TGCounter.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

{ TPNCounter }

constructor TPNCounter.Create(ANodeCount: Int32);
begin
  inherited Create;
  FPositive := TGCounter.Create(ANodeCount);
  FNegative := TGCounter.Create(ANodeCount);
  FClosed := 0;
end;

destructor TPNCounter.Destroy;
begin
  FPositive.Free;
  FNegative.Free;
  inherited Destroy;
end;

function TPNCounter.Increment(ANodeId: Int32; AAmount: Int64): TCRDTResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  Result := FPositive.Increment(ANodeId, AAmount);
end;

function TPNCounter.Decrement(ANodeId: Int32; AAmount: Int64): TCRDTResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  Result := FNegative.Increment(ANodeId, AAmount);
end;

function TPNCounter.Value: Int64;
begin
  Result := FPositive.Value - FNegative.Value;
end;

procedure TPNCounter.Merge(const AOther: TPNCounter);
begin
  if AOther = nil then
    Exit;
  FPositive.Merge(AOther.FPositive);
  FNegative.Merge(AOther.FNegative);
end;

procedure TPNCounter.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TPNCounter.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

{ TLWWRegister }

constructor TLWWRegister.Create;
begin
  inherited Create;
  FValue := '';
  FTimestamp := 0;
  FClosed := 0;
  FLock := 0;
end;

procedure TLWWRegister.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TLWWRegister.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TLWWRegister.Snapshot(out AValue: AnsiString; out ATimestamp: Int64);
begin
  Lock;
  try
    AValue := FValue;
    ATimestamp := FTimestamp;
  finally
    Unlock;
  end;
end;

function TLWWRegister.Assign(const AValue: AnsiString; ATimestamp: Int64): TCRDTResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  Lock;
  try
    if (ATimestamp > FTimestamp) or
       ((ATimestamp = FTimestamp) and (AValue > FValue)) then
    begin
      FValue := AValue;
      FTimestamp := ATimestamp;
    end;
    Result := crOk;
  finally
    Unlock;
  end;
end;

function TLWWRegister.Read(out AValue: AnsiString): Int64;
begin
  Lock;
  try
    AValue := FValue;
    Result := FTimestamp;
  finally
    Unlock;
  end;
end;

procedure TLWWRegister.Merge(const AOther: TLWWRegister);
var
  LOtherValue: AnsiString;
  LOtherTimestamp: Int64;
begin
  if (AOther = nil) or (AOther = Self) then
    Exit;
  AOther.Snapshot(LOtherValue, LOtherTimestamp);
  Lock;
  try
    if (LOtherTimestamp > FTimestamp) or
       ((LOtherTimestamp = FTimestamp) and (LOtherValue > FValue)) then
    begin
      FValue := LOtherValue;
      FTimestamp := LOtherTimestamp;
    end;
  finally
    Unlock;
  end;
end;

procedure TLWWRegister.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TLWWRegister.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

{ TORSet }

constructor TORSet.Create;
begin
  inherited Create;
  FCapacity := 16;
  SetLength(FAddSet, FCapacity);
  FCount := 0;
  FClosed := 0;
  FLock := 0;
end;

procedure TORSet.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TORSet.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TORSet.Snapshot(out AEntries: TEntries);
var
  LI: Int32;
begin
  Lock;
  try
    SetLength(AEntries, FCount);
    for LI := 0 to FCount - 1 do
      AEntries[LI] := FAddSet[LI];
  finally
    Unlock;
  end;
end;

procedure TORSet.Grow;
var
  LNewCap: Int32;
begin
  LNewCap := FCapacity * 2;
  SetLength(FAddSet, LNewCap);
  FCapacity := LNewCap;
end;

function TORSet.FindIndex(const AValue: AnsiString; ATag: UInt64): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if (FAddSet[LI].Value = AValue) and (FAddSet[LI].Tag = ATag) then
      Exit(LI);
  Result := -1;
end;

function TORSet.Add(const AValue: AnsiString): TCRDTResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  Lock;
  try
    if FCount >= FCapacity then
      Grow;
    FAddSet[FCount].Value := AValue;
    FAddSet[FCount].Tag := atomic_fetch_add_64(Int64(FGlobalTag), 1, mo_relaxed) + 1;
    FAddSet[FCount].Removed := False;
    Inc(FCount);
    Result := crOk;
  finally
    Unlock;
  end;
end;

function TORSet.Remove(const AValue: AnsiString): TCRDTResult;
var
  LI: Int32;
  LFound: Boolean;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(crClosed);
  Lock;
  try
    LFound := False;
    for LI := 0 to FCount - 1 do
      if (FAddSet[LI].Value = AValue) and (not FAddSet[LI].Removed) then
      begin
        FAddSet[LI].Removed := True;
        LFound := True;
      end;
    if LFound then
      Result := crOk
    else
      Result := crNotFound;
  finally
    Unlock;
  end;
end;

function TORSet.Contains(const AValue: AnsiString): Boolean;
var
  LI: Int32;
begin
  Lock;
  try
    for LI := 0 to FCount - 1 do
      if (FAddSet[LI].Value = AValue) and (not FAddSet[LI].Removed) then
        Exit(True);
    Result := False;
  finally
    Unlock;
  end;
end;

function TORSet.Count: Int32;
var
  LI: Int32;
begin
  Lock;
  try
    Result := 0;
    for LI := 0 to FCount - 1 do
      if not FAddSet[LI].Removed then
        Inc(Result);
  finally
    Unlock;
  end;
end;

procedure TORSet.Merge(const AOther: TORSet);
var
  LEntries: TEntries;
  LI, LIdx: Int32;
begin
  if (AOther = nil) or (AOther = Self) then
    Exit;
  AOther.Snapshot(LEntries);
  Lock;
  try
    for LI := 0 to High(LEntries) do
    begin
      LIdx := FindIndex(LEntries[LI].Value, LEntries[LI].Tag);
      if LIdx < 0 then
      begin
        if FCount >= FCapacity then
          Grow;
        FAddSet[FCount] := LEntries[LI];
        Inc(FCount);
      end
      else if LEntries[LI].Removed then
        FAddSet[LIdx].Removed := True;
    end;
  finally
    Unlock;
  end;
end;

procedure TORSet.Clear;
begin
  Lock;
  try
    FCount := 0;
  finally
    Unlock;
  end;
end;

procedure TORSet.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TORSet.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
