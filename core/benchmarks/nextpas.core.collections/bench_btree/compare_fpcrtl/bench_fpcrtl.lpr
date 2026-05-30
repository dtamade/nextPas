program bench_fpcrtl;
{$mode objfpc}{$H+}
uses SysUtils, fgl;

type
  TIntMap = specialize TFPGMap<Integer, Integer>;

const
  N = 10000;
  ITERS = 100;

var
  i, it: Integer;
  t1, t2: QWord;
  M: TIntMap;
  v: Integer;
  sink: Int64;
begin
  WriteLn('=== FPC RTL TFPGMap<Integer,Integer> (N=', N, ') ===');
  WriteLn;

  // Put
  t1 := GetTickCount64;
  for it := 1 to ITERS do
  begin
    M := TIntMap.Create;
    M.Sorted := True;
    for i := 0 to N - 1 do M.Add(i, i);
    M.Free;
  end;
  t2 := GetTickCount64;
  WriteLn('  Put:    ', (t2-t1)*1000000 div ITERS:10, ' ns/op');

  // Get
  M := TIntMap.Create;
  M.Sorted := True;
  for i := 0 to N - 1 do M.Add(i, i);
  sink := 0;
  t1 := GetTickCount64;
  for it := 1 to ITERS do
    for i := 0 to N - 1 do
    begin
      v := M.KeyData[i];
      Inc(sink, v);
    end;
  t2 := GetTickCount64;
  WriteLn('  Get:    ', (t2-t1)*1000000 div ITERS:10, ' ns/op');
  M.Free;

  if sink = 0 then Write('');
end.
