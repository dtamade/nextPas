program list_bench;
{$mode ObjFPC}{$H+}

uses
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
    Value: Int64;
    Next: PNode;
  end;

var
  GList: PNode;
  I: Integer;

procedure BuildList(var Head: PNode; Count: Integer);
var
  Tail, Node: PNode;
  I: Integer;
begin
  Head := nil;
  Tail := nil;
  for I := 0 to Count - 1 do
  begin
    New(Node);
    Node^.Value := I;
    Node^.Next := nil;
    if Head = nil then
      Head := Node
    else
      Tail^.Next := Node;
    Tail := Node;
  end;
end;

procedure FreeList(Head: PNode);
var Tmp: PNode;
begin
  while Head <> nil do
  begin
    Tmp := Head;
    Head := Head^.Next;
    Dispose(Tmp);
  end;
end;

function TraverseSum(Head: PNode): Int64;
begin
  Result := 0;
  while Head <> nil do
  begin
    Result := Result + Head^.Value;
    Head := Head^.Next;
  end;
end;

function MergeSort(Head: PNode): PNode;
var
  Slow, Fast, Mid, Left, Right, Result_: PNode;
begin
  if (Head = nil) or (Head^.Next = nil) then
  begin
    Result := Head;
    Exit;
  end;
  Slow := Head;
  Fast := Head^.Next;
  while (Fast <> nil) and (Fast^.Next <> nil) do
  begin
    Slow := Slow^.Next;
    Fast := Fast^.Next^.Next;
  end;
  Mid := Slow^.Next;
  Slow^.Next := nil;
  Left := MergeSort(Head);
  Right := MergeSort(Mid);
  Result_ := nil;
  if Left^.Value <= Right^.Value then
  begin
    Result_ := Left;
    Left := Left^.Next;
  end
  else
  begin
    Result_ := Right;
    Right := Right^.Next;
  end;
  Head := Result_;
  while (Left <> nil) and (Right <> nil) do
  begin
    if Left^.Value <= Right^.Value then
    begin
      Head^.Next := Left;
      Left := Left^.Next;
    end
    else
    begin
      Head^.Next := Right;
      Right := Right^.Next;
    end;
    Head := Head^.Next;
  end;
  if Left <> nil then Head^.Next := Left
  else Head^.Next := Right;
  Result := Result_;
end;

procedure InitData;
begin
  BuildList(GList, N);
end;

procedure BenchBuild(const ACtx: IBenchContext);
var Head: PNode;
begin
  BuildList(Head, N);
  ACtx.SetBytes(N * SizeOf(TNode));
  FreeList(Head);
end;

procedure BenchTraverse(const ACtx: IBenchContext);
var S: Int64;
begin
  S := TraverseSum(GList);
  ACtx.SetBytes(N * SizeOf(TNode));
  if S < 0 then WriteLn('');
end;

procedure BenchBuildTraverse(const ACtx: IBenchContext);
var Head: PNode; S: Int64;
begin
  BuildList(Head, N);
  S := TraverseSum(Head);
  ACtx.SetBytes(N * SizeOf(TNode) * 2);
  if S < 0 then WriteLn('');
  FreeList(Head);
end;

procedure BenchMergeSort(const ACtx: IBenchContext);
var Head: PNode;
begin
  BuildList(Head, N);
  Head := MergeSort(Head);
  ACtx.SetBytes(N * SizeOf(TNode));
  if Head^.Value > Head^.Next^.Value then WriteLn('');
  FreeList(Head);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Linked List Benchmark ===');
  WriteLn('N=', N, ' nodes');
  WriteLn;

  LSuite := TBenchSuite.Create('list')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Build/100k', @BenchBuild);
  LSuite.Add('Traverse/100k', @BenchTraverse);
  LSuite.Add('BuildTraverse/100k', @BenchBuildTraverse);
  LSuite.Add('MergeSort/100k', @BenchMergeSort);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);

  FreeList(GList);
end.
