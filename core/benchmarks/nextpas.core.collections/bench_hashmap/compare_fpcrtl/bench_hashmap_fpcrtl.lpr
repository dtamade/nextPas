program bench_hashmap_fpcrtl;
{$mode objfpc}{$H+}
{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, sysutils;
const N = 100000; HASH_SIZE = 131072;
type
  PEntry = ^TEntry;
  TEntry = record Key, Value: Int32; Next: PEntry; end;
  TSimpleHashMap = record Buckets: array of PEntry; Count: Integer; end;
var GMap: TSimpleHashMap; GSink: Int64;
function HashKey(k: Int32): UInt32; inline;
begin Result := UInt32(k) * 2654435761; end;
procedure InitMap(var M: TSimpleHashMap);
begin SetLength(M.Buckets, HASH_SIZE); FillChar(M.Buckets[0], HASH_SIZE * SizeOf(Pointer), 0); M.Count := 0; end;
procedure FreeMap(var M: TSimpleHashMap);
var i: Integer; p, n: PEntry;
begin
  for i := 0 to High(M.Buckets) do begin p := M.Buckets[i]; while p <> nil do begin n := p^.Next; Dispose(p); p := n; end; end;
  SetLength(M.Buckets, 0); M.Count := 0;
end;
procedure MapPut(var M: TSimpleHashMap; k, v: Int32);
var idx: UInt32; p: PEntry;
begin
  idx := HashKey(k) and (HASH_SIZE - 1);
  p := M.Buckets[idx];
  while p <> nil do begin if p^.Key = k then begin p^.Value := v; Exit; end; p := p^.Next; end;
  New(p); p^.Key := k; p^.Value := v; p^.Next := M.Buckets[idx]; M.Buckets[idx] := p; Inc(M.Count);
end;
function MapGet(var M: TSimpleHashMap; k: Int32; out v: Int32): Boolean;
var idx: UInt32; p: PEntry;
begin
  idx := HashKey(k) and (HASH_SIZE - 1);
  p := M.Buckets[idx];
  while p <> nil do begin if p^.Key = k then begin v := p^.Value; Exit(True); end; p := p^.Next; end;
  Result := False;
end;
procedure BenchPut(const ACtx: IBenchContext);
var M: TSimpleHashMap; i: Integer;
begin
  InitMap(M);
  for i := 0 to N - 1 do MapPut(M, i, i);
  GSink := GSink + M.Count;
  FreeMap(M);
end;
procedure BenchGetHit(const ACtx: IBenchContext);
var i, v: Integer;
begin for i := 0 to N - 1 do if MapGet(GMap, i, v) then GSink := GSink + v; end;
procedure BenchGetMiss(const ACtx: IBenchContext);
var i, v: Integer;
begin for i := N to N + N - 1 do if MapGet(GMap, i, v) then GSink := GSink + v; end;
var LSuite: IBenchSuite; LI: Integer;
begin
  InitMap(GMap);
  for LI := 0 to N - 1 do MapPut(GMap, LI, LI);
  LSuite := TBenchSuite.Create('hashmap_fpcrtl');
  LSuite
    .Add('Put', @BenchPut)
    .Add('Get(hit)', @BenchGetHit)
    .Add('Get(miss)', @BenchGetMiss);
  WriteLn(LSuite.Run.PrintToConsole);
  FreeMap(GMap);
end.
