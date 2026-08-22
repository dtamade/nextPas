{******************************************************************************
  nextpas.core.lockfree.consistent_hashring

  Consistent Hash Ring — distributed hash ring with virtual nodes.

  Design:
  - Ring is a sorted array of (hash, node-name) pairs
  - Virtual nodes (vnodes) per physical node for even distribution
  - Binary search for lookup: O(log N)
  - One spin lock serializes reads and writes over a stable sorted array
  - FNV-1a hash for ring positions

  Use cases: distributed caching, load balancing, sharding.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.consistent_hashring;

interface

uses
  nextpas.core.errors;

type
  TConsistentHashRingResult = (
    chrOk,
    chrNodeExists,
    chrNodeNotFound,
    chrInvalidVnodes
  );

  TRingNode = record
    Hash: UInt32;
    Name: AnsiString;
  end;
  PRingNode = ^TRingNode;

  {** @concurrency Thread-safe (see source for details). }
  TConsistentHashRing = class
  private
    FNodes: array of TRingNode;
    FCount: Int32;
    FCapacity: Int32;
    FVnodesPerNode: Int32;
    FLock: Int32;

    function ComputeHash(const AKey: AnsiString): UInt32;
    function FindSlot(AHash: UInt32): Int32;
    procedure SortRing;
    procedure Grow;
    procedure AcquireLock;
    procedure ReleaseLock;
  public
    constructor Create(AVnodesPerNode: Int32 = 150);
    destructor Destroy; override;

    function AddNode(const AName: AnsiString): TConsistentHashRingResult;
    function RemoveNode(const AName: AnsiString): TConsistentHashRingResult;
    function GetNode(const AKey: AnsiString): AnsiString;
    function GetNodes(const AKey: AnsiString; ACount: Int32): specialize TArray<AnsiString>;
    function ContainsNode(const AName: AnsiString): Boolean;
    function NodeCount: Int32;
    function RingSize: Int32;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.text.conv;

{ ---------- FNV-1a Hash ---------- }

function Fnv1aHash(const AData: Pointer; ALength: Int32): UInt32;
const
  FNV_OFFSET = 2166136261;
  FNV_PRIME  = 16777619;
var
  I: Int32;
  LByte: PByte;
begin
  Result := FNV_OFFSET;
  LByte := PByte(AData);
  for I := 0 to ALength - 1 do
  begin
    Result := Result xor LByte^;
    Result := Result * FNV_PRIME;
    Inc(LByte);
  end;
end;

{ ---------- TConsistentHashRing ---------- }

constructor TConsistentHashRing.Create(AVnodesPerNode: Int32);
begin
  inherited Create;
  if AVnodesPerNode < 1 then
    AVnodesPerNode := 150;
  FVnodesPerNode := AVnodesPerNode;
  FCapacity := 64;
  SetLength(FNodes, FCapacity);
  FCount := 0;
  FLock := 0;
end;

destructor TConsistentHashRing.Destroy;
begin
  SetLength(FNodes, 0);
  inherited Destroy;
end;

function TConsistentHashRing.ComputeHash(const AKey: AnsiString): UInt32;
begin
  if Length(AKey) = 0 then
    Result := 0
  else
    Result := Fnv1aHash(@AKey[1], Length(AKey));
end;

procedure TConsistentHashRing.AcquireLock;
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

procedure TConsistentHashRing.ReleaseLock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TConsistentHashRing.Grow;
var
  LNewCap: Int32;
begin
  LNewCap := FCapacity * 2;
  SetLength(FNodes, LNewCap);
  FCapacity := LNewCap;
end;

procedure TConsistentHashRing.SortRing;
var
  I, J: Int32;
  LTemp: TRingNode;
begin
  { Insertion sort - ring is nearly sorted after incremental add }
  for I := 1 to FCount - 1 do
  begin
    LTemp := FNodes[I];
    J := I - 1;
    while (J >= 0) and (FNodes[J].Hash > LTemp.Hash) do
    begin
      FNodes[J + 1] := FNodes[J];
      Dec(J);
    end;
    FNodes[J + 1] := LTemp;
  end;
end;

function TConsistentHashRing.FindSlot(AHash: UInt32): Int32;
var
  LLo, LHi, LMid: Int32;
begin
  { Binary search for first node with hash >= AHash }
  if FCount = 0 then
    Exit(-1);

  LLo := 0;
  LHi := FCount - 1;

  if AHash > FNodes[LHi].Hash then
    Exit(0); { Wrap around }

  while LLo < LHi do
  begin
    LMid := (LLo + LHi) div 2;
    if FNodes[LMid].Hash < AHash then
      LLo := LMid + 1
    else
      LHi := LMid;
  end;

  Result := LLo;
end;

function TConsistentHashRing.AddNode(const AName: AnsiString): TConsistentHashRingResult;
var
  I: Int32;
  LHash: UInt32;
  LVnodeName: AnsiString;
begin
  AcquireLock;
  try
    { Check if node already exists }
    for I := 0 to FCount - 1 do
      if FNodes[I].Name = AName then
        Exit(chrNodeExists);

    { Add virtual nodes }
    for I := 0 to FVnodesPerNode - 1 do
    begin
      if FCount >= FCapacity then
        Grow;
      LVnodeName := AName + '#' + IntToStr(I);
      LHash := ComputeHash(LVnodeName);
      FNodes[FCount].Hash := LHash;
      FNodes[FCount].Name := AName;
      Inc(FCount);
    end;

    SortRing;
    Result := chrOk;
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.RemoveNode(const AName: AnsiString): TConsistentHashRingResult;
var
  I, J, LRemoved: Int32;
begin
  AcquireLock;
  try
    LRemoved := 0;
    I := 0;
    while I < FCount do
    begin
      if FNodes[I].Name = AName then
      begin
        { Shift remaining elements }
        for J := I to FCount - 2 do
          FNodes[J] := FNodes[J + 1];
        Dec(FCount);
        Inc(LRemoved);
      end
      else
        Inc(I);
    end;

    if LRemoved = 0 then
      Exit(chrNodeNotFound);

    Result := chrOk;
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.GetNode(const AKey: AnsiString): AnsiString;
var
  LHash: UInt32;
  LSlot: Int32;
begin
  AcquireLock;
  try
    if FCount = 0 then
      Exit('');
    LHash := ComputeHash(AKey);
    LSlot := FindSlot(LHash);
    if LSlot < 0 then
      Exit('');
    Result := FNodes[LSlot].Name;
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.GetNodes(const AKey: AnsiString; ACount: Int32): specialize TArray<AnsiString>;
var
  LHash: UInt32;
  LSlot, I, K, LFound, LVisited: Int32;
  LSeen: array of AnsiString;
  LSeenCount: Int32;
  LIsNew: Boolean;
begin
  Result := nil;
  SetLength(Result, 0);
  AcquireLock;
  try
    if (FCount = 0) or (ACount <= 0) then
      Exit;
    LHash := ComputeHash(AKey);
    LSlot := FindSlot(LHash);
    if LSlot < 0 then
      Exit;
    SetLength(LSeen, ACount);
    LSeenCount := 0;
    SetLength(Result, ACount);
    LFound := 0;
    I := LSlot;
    LVisited := 0;
    while (LFound < ACount) and (LVisited < FCount) do
    begin
      if I >= FCount then
        I := 0;
      LIsNew := True;
      for K := 0 to LSeenCount - 1 do
        if LSeen[K] = FNodes[I].Name then
        begin
          LIsNew := False;
          Break;
        end;
      if LIsNew then
      begin
        LSeen[LSeenCount] := FNodes[I].Name;
        Inc(LSeenCount);
        Result[LFound] := FNodes[I].Name;
        Inc(LFound);
      end;
      Inc(I);
      Inc(LVisited);
    end;
    SetLength(Result, LFound);
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.ContainsNode(const AName: AnsiString): Boolean;
var
  I: Int32;
begin
  AcquireLock;
  try
    Result := False;
    for I := 0 to FCount - 1 do
      if FNodes[I].Name = AName then
        Exit(True);
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.NodeCount: Int32;
var
  I, K: Int32;
  LNames: array of AnsiString;
  LNameCount: Int32;
  LIsNew: Boolean;
begin
  AcquireLock;
  try
    SetLength(LNames, FCount);
    LNameCount := 0;
    for I := 0 to FCount - 1 do
    begin
      LIsNew := True;
      for K := 0 to LNameCount - 1 do
        if LNames[K] = FNodes[I].Name then
        begin
          LIsNew := False;
          Break;
        end;
      if LIsNew then
      begin
        LNames[LNameCount] := FNodes[I].Name;
        Inc(LNameCount);
      end;
    end;
    Result := LNameCount;
  finally
    ReleaseLock;
  end;
end;

function TConsistentHashRing.RingSize: Int32;
begin
  AcquireLock;
  try
    Result := FCount;
  finally
    ReleaseLock;
  end;
end;

end.
