program recordcopy_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

type
  { 64 bytes — cache-line aligned }
  TTransform = record
    M00, M01, M02, M03: Single;
    M10, M11, M12, M13: Single;
    M20, M21, M22, M23: Single;
    M30, M31, M32, M33: Single;
  end;

  { 24 bytes — small struct }
  TVec3 = record
    X, Y, Z: Single;
  end;

  { 128 bytes — 2 cache lines }
  TParticle = record
    Pos: TVec3;
    Vel: TVec3;
    Accel: TVec3;
    Rot: TTransform;
    Mass: Single;
    Charge: Byte;
    Active: Boolean;
  end;

var
  GSrc, GDst: array[0..N-1] of TParticle;
  GMatSrc, GMatDst: array[0..N-1] of TTransform;
  GVecSrc, GVecDst: array[0..N-1] of TVec3;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
  begin
    GSrc[I].Pos.X := I * 0.1;
    GSrc[I].Pos.Y := I * 0.2;
    GSrc[I].Pos.Z := I * 0.3;
    GSrc[I].Mass := 1.0;
    GSrc[I].Active := True;
    GMatSrc[I].M00 := 1.0;
    GMatSrc[I].M11 := 1.0;
    GMatSrc[I].M22 := 1.0;
    GMatSrc[I].M33 := 1.0;
    GVecSrc[I].X := I;
    GVecSrc[I].Y := I + 1;
    GVecSrc[I].Z := I + 2;
  end;
end;

{ --- Particle copy (128 bytes) --- }

procedure BenchCopy_ParticleAssign(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GDst[I] := GSrc[I];
  GSink := Ord(GDst[0].Active);
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

procedure BenchCopy_ParticleMove(const ACtx: IBenchContext);
begin
  Move(GSrc[0], GDst[0], N * SizeOf(TParticle));
  GSink := Ord(GDst[0].Active);
  ACtx.SetBytes(N * SizeOf(TParticle));
end;

{ --- Transform copy (64 bytes) --- }

procedure BenchCopy_MatAssign(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GMatDst[I] := GMatSrc[I];
  GSink := Round(GMatDst[0].M00);
  ACtx.SetBytes(N * SizeOf(TTransform));
end;

procedure BenchCopy_MatMove(const ACtx: IBenchContext);
begin
  Move(GMatSrc[0], GMatDst[0], N * SizeOf(TTransform));
  GSink := Round(GMatDst[0].M00);
  ACtx.SetBytes(N * SizeOf(TTransform));
end;

{ --- Vec3 copy (12 bytes) --- }

procedure BenchCopy_VecAssign(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GVecDst[I] := GVecSrc[I];
  GSink := Round(GVecDst[0].X);
  ACtx.SetBytes(N * SizeOf(TVec3));
end;

{ --- Transform update (read-modify-write) --- }

procedure BenchCopy_MatUpdate(const ACtx: IBenchContext);
var
  I: Integer;
  L: TTransform;
begin
  for I := 0 to N-1 do
  begin
    L := GMatSrc[I];
    L.M00 := L.M00 * 1.1;
    L.M11 := L.M11 * 1.1;
    L.M22 := L.M22 * 1.1;
    L.M33 := L.M33 * 1.1;
    GMatDst[I] := L;
  end;
  GSink := Round(GMatDst[0].M00);
  ACtx.SetBytes(N * SizeOf(TTransform));
end;

{ --- Field-by-field copy (baseline) --- }

procedure BenchCopy_MatFields(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
  begin
    GMatDst[I].M00 := GMatSrc[I].M00;
    GMatDst[I].M01 := GMatSrc[I].M01;
    GMatDst[I].M02 := GMatSrc[I].M02;
    GMatDst[I].M03 := GMatSrc[I].M03;
    GMatDst[I].M10 := GMatSrc[I].M10;
    GMatDst[I].M11 := GMatSrc[I].M11;
    GMatDst[I].M12 := GMatSrc[I].M12;
    GMatDst[I].M13 := GMatSrc[I].M13;
    GMatDst[I].M20 := GMatSrc[I].M20;
    GMatDst[I].M21 := GMatSrc[I].M21;
    GMatDst[I].M22 := GMatSrc[I].M22;
    GMatDst[I].M23 := GMatSrc[I].M23;
    GMatDst[I].M30 := GMatSrc[I].M30;
    GMatDst[I].M31 := GMatSrc[I].M31;
    GMatDst[I].M32 := GMatSrc[I].M32;
    GMatDst[I].M33 := GMatSrc[I].M33;
  end;
  GSink := Round(GMatDst[0].M00);
  ACtx.SetBytes(N * SizeOf(TTransform));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('recordcopy');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Copy/ParticleAssign/100K', @BenchCopy_ParticleAssign);
  LSuite.Add('Copy/ParticleMove/100K', @BenchCopy_ParticleMove);
  LSuite.Add('Copy/MatAssign/100K', @BenchCopy_MatAssign);
  LSuite.Add('Copy/MatMove/100K', @BenchCopy_MatMove);
  LSuite.Add('Copy/MatUpdate/100K', @BenchCopy_MatUpdate);
  LSuite.Add('Copy/MatFields/100K', @BenchCopy_MatFields);
  LSuite.Add('Copy/VecAssign/100K', @BenchCopy_VecAssign);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
