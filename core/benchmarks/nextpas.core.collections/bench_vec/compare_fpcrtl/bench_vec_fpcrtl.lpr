program bench_vec_fpcrtl;
{$mode objfpc}{$H+}
{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, sysutils;
const N = 100000;
var GData: array of Int64;
procedure InitData;
var LI: Integer;
begin SetLength(GData, N); for LI := 0 to N - 1 do GData[LI] := Int64(LI) * 7919 + 42; end;
procedure BenchPush(const ACtx: IBenchContext);
var A: array of Int64; LI: Integer;
begin
  SetLength(A, 0);
  for LI := 0 to N - 1 do begin SetLength(A, Length(A) + 1); A[High(A)] := GData[LI]; end;
  ACtx.SetAllocs(N);
end;
procedure BenchPushPrealloc(const ACtx: IBenchContext);
var A: array of Int64; LI: Integer;
begin SetLength(A, N); for LI := 0 to N - 1 do A[LI] := GData[LI]; end;
procedure BenchPop(const ACtx: IBenchContext);
var A: array of Int64; LI: Integer;
begin
  SetLength(A, N); for LI := 0 to N - 1 do A[LI] := GData[LI];
  for LI := N - 1 downto 0 do SetLength(A, LI);
  ACtx.SetAllocs(N);
end;
procedure BenchGet(const ACtx: IBenchContext);
var LI: Integer; LSum: Int64;
begin LSum := 0; for LI := 0 to N - 1 do LSum := LSum + GData[LI]; end;
procedure BenchIterate(const ACtx: IBenchContext);
var LI: Integer; LSum: Int64;
begin LSum := 0; for LI := 0 to High(GData) do LSum := LSum + GData[LI]; end;
procedure BenchInsertMid(const ACtx: IBenchContext);
var A: array of Int64; LI, mid, LJ: Integer;
begin
  SetLength(A, 0);
  for LI := 0 to 999 do
  begin
    mid := Length(A) div 2;
    SetLength(A, Length(A) + 1);
    for LJ := High(A) downto mid + 1 do A[LJ] := A[LJ - 1];
    A[mid] := GData[LI];
  end;
  ACtx.SetAllocs(1000);
end;
procedure BenchDeleteMid(const ACtx: IBenchContext);
var A: array of Int64; LI, mid, LJ, LLen: Integer;
begin
  SetLength(A, 1000); for LI := 0 to 999 do A[LI] := GData[LI];
  for LI := 0 to 999 do
  begin
    LLen := Length(A);
    if LLen = 0 then Break;
    mid := LLen div 2;
    for LJ := mid to LLen - 2 do A[LJ] := A[LJ + 1];
    SetLength(A, LLen - 1);
  end;
  ACtx.SetAllocs(1000);
end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('vec_fpcrtl');
  LSuite
    .Add('Push/SetLength+assign', @BenchPush)
    .Add('PushPrealloc', @BenchPushPrealloc)
    .Add('Pop/SetLength', @BenchPop)
    .Add('Get', @BenchGet)
    .Add('Iterate', @BenchIterate)
    .Add('InsertMid', @BenchInsertMid)
    .Add('DeleteMid', @BenchDeleteMid);
  WriteLn(LSuite.Run.PrintToConsole);
end.
