{$mode objfpc}{$H+}
program pqueue_bench;

uses
  SysUtils, Classes, nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.collections.priorityqueue;

const
  N1K = 1000;
  N10K = 10000;
  N100K = 100000;

var
  GKeys: array[0..N100K - 1] of Int32;

function Int32Compare(const A, B: Int32; AData: Pointer): SizeInt;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

procedure GenData;
var
  I: Integer;
begin
  for I := 0 to N100K - 1 do
    GKeys[I] := Int32(N100K - I); { reverse order }
end;

{ --- Push all --- }
procedure Push_1K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N1K - 1 do
      LPQ.Push(GKeys[I]);
  finally
    LPQ.Free;
  end;
end;

procedure Push_10K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N10K - 1 do
      LPQ.Push(GKeys[I]);
  finally
    LPQ.Free;
  end;
end;

procedure Push_100K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N100K - 1 do
      LPQ.Push(GKeys[I]);
  finally
    LPQ.Free;
  end;
end;

{ --- Pop all (pre-filled) --- }
procedure Pop_1K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I, V: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N1K - 1 do
      LPQ.Push(GKeys[I]);
    for I := 0 to N1K - 1 do
      V := LPQ.Pop;
  finally
    LPQ.Free;
  end;
end;

procedure Pop_10K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I, V: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N10K - 1 do
      LPQ.Push(GKeys[I]);
    for I := 0 to N10K - 1 do
      V := LPQ.Pop;
  finally
    LPQ.Free;
  end;
end;

procedure Pop_100K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I, V: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N100K - 1 do
      LPQ.Push(GKeys[I]);
    for I := 0 to N100K - 1 do
      V := LPQ.Pop;
  finally
    LPQ.Free;
  end;
end;

{ --- Push+Pop interleaved (realistic workload) --- }
procedure Interleaved_1K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I, V: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N1K - 1 do
    begin
      LPQ.Push(GKeys[I]);
      if (I and 3) = 0 then
        V := LPQ.Pop;
    end;
  finally
    LPQ.Free;
  end;
end;

procedure Interleaved_10K(const ACtx: IBenchContext);
var
  LPQ: specialize TPriorityQueue<Int32>;
  I, V: Integer;
begin
  LPQ := specialize TPriorityQueue<Int32>.Create(@Int32Compare);
  try
    for I := 0 to N10K - 1 do
    begin
      LPQ.Push(GKeys[I]);
      if (I and 3) = 0 then
        V := LPQ.Pop;
    end;
  finally
    LPQ.Free;
  end;
end;

var
  LSuite: TBenchSuite;
  LResults: IBenchResults;
begin
  GenData;

  WriteLn('=== nextPas pqueue_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  LSuite := TBenchSuite.Create('PQueuePush');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Push/1K', @Push_1K);
  LSuite.Add('Push/10K', @Push_10K);
  LSuite.Add('Push/100K', @Push_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  LSuite := TBenchSuite.Create('PQueuePop');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Pop/1K', @Pop_1K);
  LSuite.Add('Pop/10K', @Pop_10K);
  LSuite.Add('Pop/100K', @Pop_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  LSuite := TBenchSuite.Create('PQueueInterleaved');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(5000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Interleaved/1K', @Interleaved_1K);
  LSuite.Add('Interleaved/10K', @Interleaved_10K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
