{$mode objfpc}{$H+}
program objlife_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

type
  PNode = ^TNode;
  TNode = record
    Next: PNode;
    Value: Int64;
    Pad: array[0..47] of Byte;
  end;

var
  GHead: PNode;

{ AllocN + FreeN: allocate N nodes, then free all }
procedure BenchAllocFree(const ACtx: IBenchContext);
var
  I: Integer;
  LP, LTmp: PNode;
begin
  LP := nil;
  for I := 0 to N - 1 do
  begin
    New(LTmp);
    LTmp^.Value := I;
    LTmp^.Next := LP;
    LP := LTmp;
  end;
  while LP <> nil do
  begin
    LTmp := LP^.Next;
    Dispose(LP);
    LP := LTmp;
  end;
  ACtx.SetBytes(N * SizeOf(TNode));
end;

{ AllocFreeShuffle: allocate, store pointers, free in reverse }
procedure BenchAllocFreeShuffle(const ACtx: IBenchContext);
var
  I: Integer;
  LArr: array of PNode;
begin
  SetLength(LArr, N);
  for I := 0 to N - 1 do
  begin
    New(LArr[I]);
    LArr[I]^.Value := I;
  end;
  for I := N - 1 downto 0 do
    Dispose(LArr[I]);
  ACtx.SetBytes(N * SizeOf(TNode));
end;

{ LinkedBuild: build linked list then traverse }
procedure BenchLinkedBuild(const ACtx: IBenchContext);
var
  I: Integer;
  LP, LTmp: PNode;
  LSum: Int64;
begin
  LP := nil;
  for I := 0 to N - 1 do
  begin
    New(LTmp);
    LTmp^.Value := I;
    LTmp^.Next := LP;
    LP := LTmp;
  end;
  LSum := 0;
  LTmp := LP;
  while LTmp <> nil do
  begin
    LSum += LTmp^.Value;
    LTmp := LTmp^.Next;
  end;
  while LP <> nil do
  begin
    LTmp := LP^.Next;
    Dispose(LP);
    LP := LTmp;
  end;
  if LSum = 0 then WriteLn('');
  ACtx.SetBytes(N * SizeOf(TNode));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('objlife');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('AllocFree', @BenchAllocFree);
  LSuite.Add('AllocFreeShuffle', @BenchAllocFreeShuffle);
  LSuite.Add('LinkedBuild', @BenchLinkedBuild);

  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
