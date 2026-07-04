program move_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  SIZE_4K   = 4096;
  SIZE_16K  = 16384;
  SIZE_64K  = 65536;
  SIZE_256K = 262144;

var
  GSrc4K,  GDst4K:  array[0..SIZE_4K-1] of Byte;
  GSrc16K, GDst16K: array[0..SIZE_16K-1] of Byte;
  GSrc64K, GDst64K: array[0..SIZE_64K-1] of Byte;
  GSrc256K, GDst256K: array[0..SIZE_256K-1] of Byte;

procedure InitBuffers;
var
  I: Integer;
begin
  for I := 0 to SIZE_256K-1 do
  begin
    if I < SIZE_4K then
      GSrc4K[I] := Byte(I * 7 + 3);
    if I < SIZE_16K then
      GSrc16K[I] := Byte(I * 13 + 5);
    if I < SIZE_64K then
      GSrc64K[I] := Byte(I * 17 + 11);
    GSrc256K[I] := Byte(I * 19 + 7);
  end;
end;

procedure BenchMove4K(const ACtx: IBenchContext);
begin
  Move(GSrc4K[0], GDst4K[0], SIZE_4K);
  ACtx.SetBytes(SIZE_4K);
end;

procedure BenchMove16K(const ACtx: IBenchContext);
begin
  Move(GSrc16K[0], GDst16K[0], SIZE_16K);
  ACtx.SetBytes(SIZE_16K);
end;

procedure BenchMove4KLoop(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 100 do
    Move(GSrc4K[0], GDst4K[0], SIZE_4K);
  ACtx.SetBytes(SIZE_4K * 100);
end;

procedure BenchMove16KLoop(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 100 do
    Move(GSrc16K[0], GDst16K[0], SIZE_16K);
  ACtx.SetBytes(SIZE_16K * 100);
end;

procedure BenchMove64K(const ACtx: IBenchContext);
begin
  Move(GSrc64K[0], GDst64K[0], SIZE_64K);
  ACtx.SetBytes(SIZE_64K);
end;

procedure BenchMove64KLoop(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 100 do
    Move(GSrc64K[0], GDst64K[0], SIZE_64K);
  ACtx.SetBytes(SIZE_64K * 100);
end;

procedure BenchMove256K(const ACtx: IBenchContext);
begin
  Move(GSrc256K[0], GDst256K[0], SIZE_256K);
  ACtx.SetBytes(SIZE_256K);
end;

procedure BenchMove256KLoop(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 100 do
    Move(GSrc256K[0], GDst256K[0], SIZE_256K);
  ACtx.SetBytes(SIZE_256K * 100);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitBuffers;

  LSuite := TBenchSuite.Create('move');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Move/4K', @BenchMove4K);
  LSuite.Add('Move/16K', @BenchMove16K);
  LSuite.Add('Move/64K', @BenchMove64K);
  LSuite.Add('Move/256K', @BenchMove256K);
  LSuite.Add('Move4K/x100', @BenchMove4KLoop);
  LSuite.Add('Move16K/x100', @BenchMove16KLoop);
  LSuite.Add('Move64K/x100', @BenchMove64KLoop);
  LSuite.Add('Move256K/x100', @BenchMove256KLoop);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
