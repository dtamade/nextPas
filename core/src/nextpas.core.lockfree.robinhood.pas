{******************************************************************************
  nextpas.core.lockfree.robinhood

  Robin Hood Hash Map — open-addressing hash map with backward displacement.

  Design:
  - Open addressing with linear probing
  - Robin Hood insertion: if new element has greater PSL (probe sequence length)
    than existing element, swap them (steal from rich, give to poor)
  - Reduces probe-length variance; worst-case lookup remains O(n)
  - PSL = distance from ideal bucket position
  - Automatic resize at 75% load factor
  - Concurrent-safe: CAS spin lock
  - Keys and values are UInt64 (simple, no generic hash issues)

  Benefits over linear probing:
  - Much lower variance in probe lengths
  - Better worst-case performance
  - Cache-friendly sequential access

  2026-07-06  Phase 10
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.robinhood;

interface

uses
  nextpas.core.lockfree.base;

const
  ROBINHOOD_DEFAULT_CAPACITY = 16;

type
  TRobinHoodResult = (rhOk, rhNotFound, rhExists, rhFull, rhClosed);

  TRHEntry = record
    Key: UInt64;
    Value: UInt64;
    Distance: Int32;  { PSL: distance from ideal position }
    Used: Boolean;
  end;

  {** @desc Robin Hood 哈希表
    @details 开放寻址 + 后向位移，减少探测序列方差。
      最坏情况查找 O(n)，期望平均 O(1)。
      线程安全：CAS 自旋锁。 }
  TRobinHoodMap = class
  private
    FEntries: array of TRHEntry;
    FCapacity: Int32;
    FCount: Int32;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function HashKey(AKey: UInt64): UInt32;
    procedure Resize(ANewCapacity: Int32);
    function FindSlot(AKey: UInt64; out AIdx: Int32): Boolean;
  public
    constructor Create(const ACapacity: Int32 = ROBINHOOD_DEFAULT_CAPACITY);
    destructor Destroy; override;
    function Insert(AKey, AValue: UInt64): TRobinHoodResult;
    function Lookup(AKey: UInt64; out AValue: UInt64): TRobinHoodResult;
    function Delete(AKey: UInt64): TRobinHoodResult;
    function GetCount: Int32;
    function GetCapacity: Int32;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TRobinHoodMap.Create(const ACapacity: Int32);
var
  LI: Int32;
begin
  if ACapacity < 4 then
    raise EArgumentError.Create('TRobinHoodMap: capacity must be >= 4');
  inherited Create;
  FCapacity := ACapacity;
  FCount := 0;
  FLock := 0;
  FClosed := 0;
  SetLength(FEntries, FCapacity);
  for LI := 0 to FCapacity - 1 do
    FEntries[LI].Used := False;
end;

procedure TRobinHoodMap.Lock;
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

procedure TRobinHoodMap.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TRobinHoodMap.HashKey(AKey: UInt64): UInt32;
var
  LH: UInt64;
begin
  { FNV-1a }
  LH := 14695981039346656037;
  LH := (LH xor (AKey and $FFFFFFFF)) * 1099511628211;
  LH := (LH xor (AKey shr 32)) * 1099511628211;
  Result := UInt32(LH);
end;

procedure TRobinHoodMap.Resize(ANewCapacity: Int32);
var
  LOldEntries: array of TRHEntry;
  LOldCapacity, LI, LIdx, LDist: Int32;
  LKey, LValue, TmpKey, TmpValue: UInt64;
  TmpDist: Int32;
begin
  LOldEntries := FEntries;
  LOldCapacity := FCapacity;
  FCapacity := ANewCapacity;
  FCount := 0;
  SetLength(FEntries, FCapacity);
  for LI := 0 to FCapacity - 1 do
    FEntries[LI].Used := False;
  { Rehash all entries }
  for LI := 0 to LOldCapacity - 1 do
    if LOldEntries[LI].Used then
    begin
      LKey := LOldEntries[LI].Key;
      LValue := LOldEntries[LI].Value;
      LIdx := Int32(HashKey(LKey) mod UInt32(FCapacity));
      LDist := 0;
      while True do
      begin
        if not FEntries[LIdx].Used then
        begin
          FEntries[LIdx].Key := LKey;
          FEntries[LIdx].Value := LValue;
          FEntries[LIdx].Distance := LDist;
          FEntries[LIdx].Used := True;
          Inc(FCount);
          Break;
        end;
        if LDist > FEntries[LIdx].Distance then
        begin
          TmpKey := FEntries[LIdx].Key;
          TmpValue := FEntries[LIdx].Value;
          TmpDist := FEntries[LIdx].Distance;
          FEntries[LIdx].Key := LKey;
          FEntries[LIdx].Value := LValue;
          FEntries[LIdx].Distance := LDist;
          LKey := TmpKey;
          LValue := TmpValue;
          LDist := TmpDist;
        end;
        Inc(LDist);
        LIdx := (LIdx + 1) mod FCapacity;
      end;
    end;
end;

function TRobinHoodMap.FindSlot(AKey: UInt64; out AIdx: Int32): Boolean;
var
  LIdx, LDist: Int32;
begin
  Result := False;
  LIdx := Int32(HashKey(AKey) mod UInt32(FCapacity));
  LDist := 0;
  while True do
  begin
    if not FEntries[LIdx].Used then
    begin
      AIdx := LIdx;
      Exit(False);
    end;
    if FEntries[LIdx].Key = AKey then
    begin
      AIdx := LIdx;
      Exit(True);
    end;
    if LDist > FEntries[LIdx].Distance then
    begin
      AIdx := LIdx;
      Exit(False);
    end;
    Inc(LDist);
    LIdx := (LIdx + 1) mod FCapacity;
    if LDist >= FCapacity then
    begin
      AIdx := LIdx;
      Exit(False);
    end;
  end;
end;

function TRobinHoodMap.Insert(AKey, AValue: UInt64): TRobinHoodResult;
var
  LIdx, LDist, TmpDist: Int32;
  LKey, LValue, TmpKey, TmpValue: UInt64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rhClosed);
  Lock;
  try
    { Check if key exists }
    if FindSlot(AKey, LIdx) then
    begin
      FEntries[LIdx].Value := AValue;
      Exit(rhExists);
    end;
    { Check load factor (75%) }
    if (FCount + 1) * 4 >= FCapacity * 3 then
      Resize(FCapacity * 2);
    { Robin Hood insert }
    LIdx := Int32(HashKey(AKey) mod UInt32(FCapacity));
    LDist := 0;
    LKey := AKey;
    LValue := AValue;
    while True do
    begin
      if not FEntries[LIdx].Used then
      begin
        FEntries[LIdx].Key := LKey;
        FEntries[LIdx].Value := LValue;
        FEntries[LIdx].Distance := LDist;
        FEntries[LIdx].Used := True;
        Inc(FCount);
        Exit(rhOk);
      end;
      if FEntries[LIdx].Key = LKey then
      begin
        FEntries[LIdx].Value := LValue;
        Exit(rhExists);
      end;
      if LDist > FEntries[LIdx].Distance then
      begin
        TmpKey := FEntries[LIdx].Key;
        TmpValue := FEntries[LIdx].Value;
        TmpDist := FEntries[LIdx].Distance;
        FEntries[LIdx].Key := LKey;
        FEntries[LIdx].Value := LValue;
        FEntries[LIdx].Distance := LDist;
        LKey := TmpKey;
        LValue := TmpValue;
        LDist := TmpDist;
      end;
      Inc(LDist);
      LIdx := (LIdx + 1) mod FCapacity;
    end;
  finally
    Unlock;
  end;
end;

function TRobinHoodMap.Lookup(AKey: UInt64; out AValue: UInt64): TRobinHoodResult;
var
  LIdx: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rhClosed);
  Lock;
  try
    if FindSlot(AKey, LIdx) then
    begin
      AValue := FEntries[LIdx].Value;
      Exit(rhOk);
    end;
    Result := rhNotFound;
  finally
    Unlock;
  end;
end;

function TRobinHoodMap.Delete(AKey: UInt64): TRobinHoodResult;
var
  LIdx, LNext: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rhClosed);
  Lock;
  try
    if not FindSlot(AKey, LIdx) then
      Exit(rhNotFound);
    { Remove and shift subsequent entries backward }
    FEntries[LIdx].Used := False;
    Dec(FCount);
    LNext := (LIdx + 1) mod FCapacity;
    while FEntries[LNext].Used and (FEntries[LNext].Distance > 0) do
    begin
      FEntries[LIdx] := FEntries[LNext];
      Dec(FEntries[LIdx].Distance);
      FEntries[LNext].Used := False;
      LIdx := LNext;
      LNext := (LNext + 1) mod FCapacity;
    end;
    Result := rhOk;
  finally
    Unlock;
  end;
end;

function TRobinHoodMap.GetCount: Int32;
begin
  Lock;
  try
    Result := FCount;
  finally
    Unlock;
  end;
end;

function TRobinHoodMap.GetCapacity: Int32;
begin
  Lock;
  try
    Result := FCapacity;
  finally
    Unlock;
  end;
end;

procedure TRobinHoodMap.Clear;
var
  LI: Int32;
begin
  Lock;
  try
    for LI := 0 to FCapacity - 1 do
      FEntries[LI].Used := False;
    FCount := 0;
  finally
    Unlock;
  end;
end;

procedure TRobinHoodMap.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TRobinHoodMap.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TRobinHoodMap.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
