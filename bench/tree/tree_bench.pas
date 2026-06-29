program tree_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv;

const
  N = 100000;

type
  PNode = ^TNode;
  TNode = record
    Key: Int64;
    Left, Right: PNode;
  end;

var
  GKeys: array[0..N-1] of Int64;
  I: Integer;

procedure Shuffle(var A: array of Int64; Count: Integer);
var J: Integer; T: Int64; Seed: UInt32;
begin
  Seed := 12345;
  for J := Count - 1 downto 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    I := Integer(Seed mod UInt32(J + 1));
    T := A[J]; A[J] := A[I]; A[I] := T;
  end;
end;

function BSTInsert(Root: PNode; Key: Int64): PNode;
begin
  if Root = nil then
  begin
    New(Result);
    Result^.Key := Key;
    Result^.Left := nil;
    Result^.Right := nil;
    Exit;
  end;
  if Key < Root^.Key then
    Root^.Left := BSTInsert(Root^.Left, Key)
  else
    Root^.Right := BSTInsert(Root^.Right, Key);
  Result := Root;
end;

function BSTLookup(Root: PNode; Key: Int64): PNode;
begin
  Result := Root;
  while Result <> nil do
  begin
    if Key = Result^.Key then Exit
    else if Key < Result^.Key then Result := Result^.Left
    else Result := Result^.Right;
  end;
end;

function InOrderSum(Root: PNode): Int64;
begin
  if Root = nil then
  begin
    Result := 0;
    Exit;
  end;
  Result := InOrderSum(Root^.Left) + Root^.Key + InOrderSum(Root^.Right);
end;

procedure FreeTree(Root: PNode);
begin
  if Root = nil then Exit;
  FreeTree(Root^.Left);
  FreeTree(Root^.Right);
  Dispose(Root);
end;

procedure InitData;
begin
  for I := 0 to N - 1 do
    GKeys[I] := I;
  Shuffle(GKeys, N);
end;

procedure BenchInsert(const ACtx: IBenchContext);
var Root: PNode; J: Integer;
begin
  Root := nil;
  for J := 0 to N - 1 do
    Root := BSTInsert(Root, GKeys[J]);
  ACtx.SetBytes(N * SizeOf(TNode));
  FreeTree(Root);
end;

procedure BenchLookup(const ACtx: IBenchContext);
var Root, Found: PNode; J: Integer;
begin
  Root := nil;
  for J := 0 to N - 1 do
    Root := BSTInsert(Root, GKeys[J]);
  for J := 0 to N - 1 do
    Found := BSTLookup(Root, GKeys[J]);
  ACtx.SetBytes(N * SizeOf(TNode));
  if Found = nil then WriteLn('');
  FreeTree(Root);
end;

procedure BenchInsertLookup(const ACtx: IBenchContext);
var Root, Found: PNode; J: Integer;
begin
  Root := nil;
  for J := 0 to N - 1 do
    Root := BSTInsert(Root, GKeys[J]);
  for J := 0 to N - 1 do
    Found := BSTLookup(Root, GKeys[J]);
  ACtx.SetBytes(N * SizeOf(TNode) * 2);
  if Found = nil then WriteLn('');
  FreeTree(Root);
end;

procedure BenchInOrder(const ACtx: IBenchContext);
var Root: PNode; J: Integer; S: Int64;
begin
  Root := nil;
  for J := 0 to N - 1 do
    Root := BSTInsert(Root, GKeys[J]);
  S := InOrderSum(Root);
  ACtx.SetBytes(N * SizeOf(TNode));
  if S < 0 then WriteLn('');
  FreeTree(Root);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas BST Benchmark ===');
  WriteLn('N=', N, ' random keys');
  WriteLn;

  LSuite := TBenchSuite.Create('Tree')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Insert/100k', @BenchInsert);
  LSuite.Add('Lookup/100k', @BenchLookup);
  LSuite.Add('InsertLookup/100k', @BenchInsertLookup);
  LSuite.Add('InOrder/100k', @BenchInOrder);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
