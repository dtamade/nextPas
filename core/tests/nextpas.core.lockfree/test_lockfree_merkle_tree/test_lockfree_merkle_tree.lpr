program test_lockfree_merkle_tree;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  Classes,
  SysUtils,
  nextpas.core.lockfree.merkle_tree;

var
  GTree: TMerkleTree;
  GPassed, GFailed: Int32;

type
  TMerkleAddThread = class(TThread)
  private
    FTree: TMerkleTree;
    FStartIndex, FCount: Int32;
  protected
    procedure Execute; override;
  public
    constructor Create(ATree: TMerkleTree; AStartIndex, ACount: Int32);
  end;

constructor TMerkleAddThread.Create(ATree: TMerkleTree;
  AStartIndex, ACount: Int32);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FTree := ATree;
  FStartIndex := AStartIndex;
  FCount := ACount;
end;

procedure TMerkleAddThread.Execute;
var
  LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    FTree.AddLeaf('leaf-' + IntToStr(FStartIndex + LI));
end;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure TestAddLeaf;
begin
  WriteLn('--- TestAddLeaf ---');
  GTree := TMerkleTree.Create;
  try
    Check(GTree.AddLeaf('hello') = mkOk, 'Add leaf hello');
    Check(GTree.AddLeaf('world') = mkOk, 'Add leaf world');
    Check(GTree.GetLeafCount = 2, 'Leaf count = 2');
    Check(GTree.GetRootHash <> 0, 'Root hash nonzero');
  finally
    GTree.Free;
  end;
end;

procedure TestRootHash;
var
  LHash1, LHash2: UInt64;
begin
  WriteLn('--- TestRootHash ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('a');
    GTree.AddLeaf('b');
    GTree.AddLeaf('c');
    LHash1 := GTree.GetRootHash;
    Check(LHash1 <> 0, 'Root hash nonzero');
    { Same data should give same hash }
    LHash2 := GTree.GetRootHash;
    Check(LHash1 = LHash2, 'Same data same hash');
  finally
    GTree.Free;
  end;
end;

procedure TestDifferentData;
var
  LHash1, LHash2: UInt64;
begin
  WriteLn('--- TestDifferentData ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('hello');
    LHash1 := GTree.GetRootHash;
    GTree.Free;
    GTree := TMerkleTree.Create;
    GTree.AddLeaf('world');
    LHash2 := GTree.GetRootHash;
    Check(LHash1 <> LHash2, 'Different data different hash');
  finally
    GTree.Free;
  end;
end;

procedure TestVerify;
begin
  WriteLn('--- TestVerify ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('data1');
    GTree.AddLeaf('data2');
    Check(GTree.Verify, 'Verify passes');
  finally
    GTree.Free;
  end;
end;

procedure TestClear;
begin
  WriteLn('--- TestClear ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('a');
    GTree.AddLeaf('b');
    GTree.Clear;
    Check(GTree.GetLeafCount = 0, 'Cleared leaf count');
    Check(GTree.GetRootHash = 0, 'Cleared root hash');
  finally
    GTree.Free;
  end;
end;

procedure TestClose;
begin
  WriteLn('--- TestClose ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('a');
    GTree.Close;
    Check(GTree.IsClosed, 'Is closed');
    Check(GTree.AddLeaf('b') = mkClosed, 'Add after close fails');
  finally
    GTree.Free;
  end;
end;

procedure TestGetLeafHash;
begin
  WriteLn('--- TestGetLeafHash ---');
  GTree := TMerkleTree.Create;
  try
    GTree.AddLeaf('a');
    GTree.AddLeaf('b');
    Check(GTree.GetLeafHash(0) <> 0, 'Leaf 0 hash nonzero');
    Check(GTree.GetLeafHash(1) <> 0, 'Leaf 1 hash nonzero');
    Check(GTree.GetLeafHash(0) <> GTree.GetLeafHash(1), 'Different leaves different hash');
    Check(GTree.GetLeafHash(-1) = 0, 'Invalid index returns 0');
  finally
    GTree.Free;
  end;
end;

procedure TestConcurrentAddLeaf;
const
  THREAD_COUNT = 4;
  LEAVES_PER_THREAD = 200;
var
  LThreads: array[0..THREAD_COUNT - 1] of TMerkleAddThread;
  LI: Int32;
begin
  WriteLn('--- TestConcurrentAddLeaf ---');
  GTree := TMerkleTree.Create;
  try
    for LI := 0 to High(LThreads) do
      LThreads[LI] := TMerkleAddThread.Create(GTree,
        LI * LEAVES_PER_THREAD, LEAVES_PER_THREAD);
    for LI := 0 to High(LThreads) do
      LThreads[LI].Start;
    for LI := 0 to High(LThreads) do
    begin
      LThreads[LI].WaitFor;
      LThreads[LI].Free;
    end;
    Check(GTree.GetLeafCount = THREAD_COUNT * LEAVES_PER_THREAD,
      'Concurrent additions publish every leaf');
    Check(GTree.Verify, 'Concurrent additions propagate a valid root');
  finally
    GTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_merkle_tree ===');
  GPassed := 0;
  GFailed := 0;
  TestAddLeaf;
  TestRootHash;
  TestDifferentData;
  TestVerify;
  TestClear;
  TestClose;
  TestGetLeafHash;
  TestConcurrentAddLeaf;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
