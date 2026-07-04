program packed_bench;

{$mode objfpc}{$H+}

uses nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

type
  TParticle = packed record
    X, Y, Z: Single;
    Vx, Vy, Vz: Single;
    Mass: Single;
    Charge: Byte;
    Active: Boolean;
  end;  // 26 bytes packed

  TParticles = array[0..N-1] of TParticle;

var
  GSrc, GDst: TParticles;
  GSum: Single;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
  begin
    GSrc[I].X := I * 1.5;
    GSrc[I].Y := I * 2.5;
    GSrc[I].Z := I * 3.5;
    GSrc[I].Vx := I * 0.1;
    GSrc[I].Vy := I * 0.2;
    GSrc[I].Vz := I * 0.3;
    GSrc[I].Mass := I * 0.01;
    GSrc[I].Charge := Byte(I mod 3);
    GSrc[I].Active := (I mod 7) <> 0;
  end;
end;

procedure BenchPackedCopy(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GDst[I] := GSrc[I];
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

procedure BenchPackedMove(const ACtx: IBenchContext);
begin
  Move(GSrc[0], GDst[0], N * SizeOf(TParticle));
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

procedure BenchPackedUpdate(const ACtx: IBenchContext);
var
  I: Integer;
  LX: Single;
begin
  for I := 0 to N-1 do
  begin
    GSrc[I].X := GSrc[I].X + GSrc[I].Vx;
    GSrc[I].Y := GSrc[I].Y + GSrc[I].Vy;
    GSrc[I].Z := GSrc[I].Z + GSrc[I].Vz;
    LX := GSrc[I].X;
  end;
  GSum := LX;
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

procedure BenchPackedFilter(const ACtx: IBenchContext);
var
  I, LCount: Integer;
begin
  LCount := 0;
  for I := 0 to N-1 do
    if GSrc[I].Active and (GSrc[I].Mass > 0.5) then
      Inc(LCount);
  GSum := LCount;
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

procedure BenchPackedCompact(const ACtx: IBenchContext);
var
  I, LCount: Integer;
begin
  LCount := 0;
  for I := 0 to N-1 do
  begin
    if GSrc[I].Active then
    begin
      GDst[LCount] := GSrc[I];
      Inc(LCount);
    end;
  end;
  GSum := LCount;
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('packed');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('PackedCopy/100K', @BenchPackedCopy);
  LSuite.Add('PackedMove/100K', @BenchPackedMove);
  LSuite.Add('PackedUpdate/100K', @BenchPackedUpdate);
  LSuite.Add('PackedFilter/100K', @BenchPackedFilter);
  LSuite.Add('PackedCompact/100K', @BenchPackedCompact);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
