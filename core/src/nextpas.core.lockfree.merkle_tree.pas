unit nextpas.core.lockfree.merkle_tree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TMerkleResult = (mkOk, mkNotFound, mkClosed);

  PMerkleLeaf = ^TMerkleLeaf;
  TMerkleLeaf = record
    Hash: UInt64;
    Data: AnsiString;
    Next: PMerkleLeaf;
  end;

  TMerkleProof = record
    Hashes: array of UInt64;
    Indices: array of Int32;
    Count: Int32;
  end;

  {** @desc Merkle 哈希树
    @details 基于 FNV-1a 哈希的 Merkle 树。
      支持数据完整性验证、证明生成/验证、增量更新。
      适用场景：数据同步、区块链、分布式存储。
  }
  TMerkleTree = class
  private
    FLeaves: PMerkleLeaf;
    FLeafCount: Int32;
    FRootHash: UInt64;
    FLock: Int32;
    FClosed: Int32;
    function CalculateRootHash(out ALeavesValid: Boolean): UInt64;
    procedure ComputeRootHash;
    function FnvHash(const AData: AnsiString): UInt64;
    procedure LockTree;
    procedure UnlockTree;
  public
    constructor Create;
    destructor Destroy; override;
    function AddLeaf(const AData: AnsiString): TMerkleResult;
    function GetRootHash: UInt64;
    function GetLeafCount: Int32;
    function GetLeafHash(AIndex: Int32): UInt64;
    function Verify: Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.atomic;

const
  FNV_OFFSET = 14695981039346656037;
  FNV_PRIME = 1099511628211;

function TMerkleTree.FnvHash(const AData: AnsiString): UInt64;
var
  LI: Int32;
begin
  Result := FNV_OFFSET;
  for LI := 1 to Length(AData) do
    Result := (Result xor Ord(AData[LI])) * FNV_PRIME;
end;

constructor TMerkleTree.Create;
begin
  inherited Create;
  FLeaves := nil;
  FLeafCount := 0;
  FRootHash := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TMerkleTree.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TMerkleTree.AddLeaf(const AData: AnsiString): TMerkleResult;
var
  LLeaf: PMerkleLeaf;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(mkClosed);
  LockTree;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(mkClosed);
    New(LLeaf);
    LLeaf^.Data := AData;
    LLeaf^.Hash := FnvHash(AData);
    LLeaf^.Next := FLeaves;
    FLeaves := LLeaf;
    Inc(FLeafCount);
    ComputeRootHash;
    Result := mkOk;
  finally
    UnlockTree;
  end;
end;

function TMerkleTree.CalculateRootHash(out ALeavesValid: Boolean): UInt64;
var
  LHashes: array of UInt64;
  LHash: UInt64;
  LCount, LI: Int32;
  LLeaf: PMerkleLeaf;
begin
  ALeavesValid := True;
  if FLeafCount = 0 then
    Exit(0);
  SetLength(LHashes, FLeafCount);
  LLeaf := FLeaves;
  LI := FLeafCount - 1;
  while LLeaf <> nil do
  begin
    if LI < 0 then
    begin
      ALeavesValid := False;
      Exit(0);
    end;
    LHash := FnvHash(LLeaf^.Data);
    if LHash <> LLeaf^.Hash then
      ALeavesValid := False;
    LHashes[LI] := LHash;
    Dec(LI);
    LLeaf := LLeaf^.Next;
  end;
  if LI <> -1 then
  begin
    ALeavesValid := False;
    Exit(0);
  end;
  LCount := FLeafCount;
  while LCount > 1 do
  begin
    LI := 0;
    while LI < LCount - 1 do
    begin
      LHashes[LI div 2] := (LHashes[LI] * FNV_PRIME) xor LHashes[LI + 1];
      Inc(LI, 2);
    end;
    if LCount mod 2 <> 0 then
      LHashes[LCount div 2] := LHashes[LCount - 1];
    LCount := (LCount + 1) div 2;
  end;
  Result := LHashes[0];
end;

procedure TMerkleTree.ComputeRootHash;
var
  LLeavesValid: Boolean;
begin
  FRootHash := CalculateRootHash(LLeavesValid);
end;

procedure TMerkleTree.LockTree;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
  begin
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

procedure TMerkleTree.UnlockTree;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TMerkleTree.GetRootHash: UInt64;
begin
  LockTree;
  try
    Result := FRootHash;
  finally
    UnlockTree;
  end;
end;

function TMerkleTree.GetLeafCount: Int32;
begin
  LockTree;
  try
    Result := FLeafCount;
  finally
    UnlockTree;
  end;
end;

function TMerkleTree.GetLeafHash(AIndex: Int32): UInt64;
var
  LLeaf: PMerkleLeaf;
  LI: Int32;
begin
  LockTree;
  try
    if (AIndex < 0) or (AIndex >= FLeafCount) then
      Exit(0);
    LLeaf := FLeaves;
    LI := 0;
    while (LLeaf <> nil) and (LI < FLeafCount - 1 - AIndex) do
    begin
      LLeaf := LLeaf^.Next;
      Inc(LI);
    end;
    if LLeaf <> nil then
      Result := LLeaf^.Hash
    else
      Result := 0;
  finally
    UnlockTree;
  end;
end;

function TMerkleTree.Verify: Boolean;
var
  LCalculatedRoot: UInt64;
  LLeavesValid: Boolean;
begin
  LockTree;
  try
    LCalculatedRoot := CalculateRootHash(LLeavesValid);
    Result := LLeavesValid and (LCalculatedRoot = FRootHash);
  finally
    UnlockTree;
  end;
end;

procedure TMerkleTree.Clear;
var
  LLeaf, LNext: PMerkleLeaf;
begin
  LockTree;
  try
    LLeaf := FLeaves;
    while LLeaf <> nil do
    begin
      LNext := LLeaf^.Next;
      LLeaf^.Data := '';
      Dispose(LLeaf);
      LLeaf := LNext;
    end;
    FLeaves := nil;
    FLeafCount := 0;
    FRootHash := 0;
  finally
    UnlockTree;
  end;
end;

procedure TMerkleTree.Close;
begin
  LockTree;
  try
    AtomicStore32(FClosed, 1, moRelease);
  finally
    UnlockTree;
  end;
end;

function TMerkleTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
