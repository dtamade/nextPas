{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_consistent_hashring;

uses
  SysUtils,
  nextpas.core.lockfree.consistent_hashring;

var
  GRing: TConsistentHashRing;
  GPassed, GFailed: Int32;

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

procedure Test_AddRemove;
var
  LRes: TConsistentHashRingResult;
begin
  WriteLn('--- Add/Remove ---');
  GRing := TConsistentHashRing.Create(10);
  try
    LRes := GRing.AddNode('node-a');
    Check(LRes = chrOk, 'AddNode(node-a) = ok');
    Check(GRing.NodeCount = 1, 'NodeCount = 1');

    LRes := GRing.AddNode('node-b');
    Check(LRes = chrOk, 'AddNode(node-b) = ok');
    Check(GRing.NodeCount = 2, 'NodeCount = 2');

    LRes := GRing.AddNode('node-a');
    Check(LRes = chrNodeExists, 'AddNode(node-a) again = exists');

    LRes := GRing.RemoveNode('node-a');
    Check(LRes = chrOk, 'RemoveNode(node-a) = ok');
    Check(GRing.NodeCount = 1, 'NodeCount = 1');

    LRes := GRing.RemoveNode('node-a');
    Check(LRes = chrNodeNotFound, 'RemoveNode(node-a) again = not found');

    LRes := GRing.RemoveNode('node-c');
    Check(LRes = chrNodeNotFound, 'RemoveNode(node-c) = not found');
  finally
    GRing.Free;
  end;
end;

procedure Test_GetNode;
var
  LNode, LNode2: AnsiString;
begin
  WriteLn('--- GetNode ---');
  GRing := TConsistentHashRing.Create(50);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');
    GRing.AddNode('node-c');

    LNode := GRing.GetNode('key1');
    Check(LNode <> '', 'GetNode(key1) returns non-empty');

    LNode := GRing.GetNode('key2');
    Check(LNode <> '', 'GetNode(key2) returns non-empty');

    { Same key should always return same node }
    LNode2 := GRing.GetNode('key1');
    Check(LNode = LNode2, 'Same key returns same node');
  finally
    GRing.Free;
  end;
end;

procedure Test_Distribution;
var
  LCounts: array[0..2] of Int32;
  LNode: AnsiString;
  I: Int32;
begin
  WriteLn('--- Distribution ---');
  GRing := TConsistentHashRing.Create(150);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');
    GRing.AddNode('node-c');

    LCounts[0] := 0;
    LCounts[1] := 0;
    LCounts[2] := 0;

    for I := 0 to 9999 do
    begin
      LNode := GRing.GetNode('key-' + IntToStr(I));
      if LNode = 'node-a' then
        Inc(LCounts[0])
      else if LNode = 'node-b' then
        Inc(LCounts[1])
      else if LNode = 'node-c' then
        Inc(LCounts[2]);
    end;

    { Each node should get roughly 33% +/- 10% }
    Check((LCounts[0] > 2000) and (LCounts[0] < 4500), 'node-a distribution ~33%');
    Check((LCounts[1] > 2000) and (LCounts[1] < 4500), 'node-b distribution ~33%');
    Check((LCounts[2] > 2000) and (LCounts[2] < 4500), 'node-c distribution ~33%');

    WriteLn(Format('  Distribution: a=%d b=%d c=%d', [LCounts[0], LCounts[1], LCounts[2]]));
  finally
    GRing.Free;
  end;
end;

procedure Test_MinimalDisruption;
var
  LBefore: array[0..999] of AnsiString;
  LChanged, I: Int32;
  LAfter: AnsiString;
begin
  WriteLn('--- Minimal Disruption ---');
  GRing := TConsistentHashRing.Create(150);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');
    GRing.AddNode('node-c');
    GRing.AddNode('node-d');

    { Record mappings before adding node-e }
    for I := 0 to High(LBefore) do
      LBefore[I] := GRing.GetNode('key-' + IntToStr(I));

    GRing.AddNode('node-e');

    { Count how many keys changed }
    LChanged := 0;
    for I := 0 to High(LBefore) do
    begin
      LAfter := GRing.GetNode('key-' + IntToStr(I));
      if LAfter <> LBefore[I] then
      begin
        Inc(LChanged);
        Check(LAfter = 'node-e', 'Changed keys must migrate to the added node');
      end;
    end;

    { With 150 vnodes, adding a 5th node should change roughly 20% of keys. }
    Check((LChanged >= 100) and (LChanged <= 300),
      'Adding 5th node changes 10%-30% of keys');
    WriteLn(Format('  Disruption: %d/1000 keys changed', [LChanged]));
  finally
    GRing.Free;
  end;
end;

procedure Test_GetNodes;
var
  LNodes: specialize TArray<AnsiString>;
begin
  WriteLn('--- GetNodes ---');
  GRing := TConsistentHashRing.Create(50);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');
    GRing.AddNode('node-c');

    LNodes := GRing.GetNodes('key1', 2);
    Check(Length(LNodes) = 2, 'GetNodes(key1, 2) returns 2 nodes');
    Check(LNodes[0] <> LNodes[1], 'GetNodes returns distinct nodes');

    LNodes := GRing.GetNodes('key1', 5);
    Check(Length(LNodes) = 3, 'GetNodes(key1, 5) returns 3 nodes (all available)');

    LNodes := GRing.GetNodes('', 5);
    Check(Length(LNodes) = 3,
      'GetNodes from slot zero terminates after visiting all available nodes');
  finally
    GRing.Free;
  end;
end;

procedure Test_RemoveOnlyMigratesRemovedNodeKeys;
var
  LBefore: array[0..999] of AnsiString;
  LAfter: AnsiString;
  LI: Int32;
begin
  WriteLn('--- Remove Migration ---');
  GRing := TConsistentHashRing.Create(150);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');
    GRing.AddNode('node-c');
    GRing.AddNode('node-d');
    GRing.AddNode('node-e');
    for LI := 0 to High(LBefore) do
      LBefore[LI] := GRing.GetNode('remove-key-' + IntToStr(LI));

    Check(GRing.RemoveNode('node-e') = chrOk, 'RemoveNode(node-e) = ok');
    for LI := 0 to High(LBefore) do
    begin
      LAfter := GRing.GetNode('remove-key-' + IntToStr(LI));
      if LBefore[LI] = 'node-e' then
        Check(LAfter <> 'node-e', 'Removed-node keys migrate to a surviving node')
      else
        Check(LAfter = LBefore[LI], 'Other keys retain their previous owner');
    end;
  finally
    GRing.Free;
  end;
end;

procedure Test_ContainsNode;
begin
  WriteLn('--- ContainsNode ---');
  GRing := TConsistentHashRing.Create(10);
  try
    GRing.AddNode('node-a');
    GRing.AddNode('node-b');

    Check(GRing.ContainsNode('node-a'), 'ContainsNode(node-a) = true');
    Check(GRing.ContainsNode('node-b'), 'ContainsNode(node-b) = true');
    Check(not GRing.ContainsNode('node-c'), 'ContainsNode(node-c) = false');

    GRing.RemoveNode('node-a');
    Check(not GRing.ContainsNode('node-a'), 'ContainsNode(node-a) after remove = false');
  finally
    GRing.Free;
  end;
end;

procedure Test_RingSize;
begin
  WriteLn('--- RingSize ---');
  GRing := TConsistentHashRing.Create(10);
  try
    Check(GRing.RingSize = 0, 'RingSize = 0 initially');
    GRing.AddNode('node-a');
    Check(GRing.RingSize = 10, 'RingSize = 10 (1 node * 10 vnodes)');
    GRing.AddNode('node-b');
    Check(GRing.RingSize = 20, 'RingSize = 20 (2 nodes * 10 vnodes)');
  finally
    GRing.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Consistent Hash Ring Tests ===');
  Test_AddRemove;
  Test_GetNode;
  Test_Distribution;
  Test_MinimalDisruption;
  Test_GetNodes;
  Test_RemoveOnlyMigratesRemovedNodeKeys;
  Test_ContainsNode;
  Test_RingSize;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
