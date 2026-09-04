program recops_bench;
{$mode ObjFPC}{$H+}{$inline on}
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 10000;
  ITERS = 1000;

type
  TRec = record
    A, B: Int64;
    C, D: Integer;
    E, F: Double;
  end;

var
  GData: array[0..N-1] of TRec;
  GDst:  array[0..N-1] of TRec;
  GSink: Int64;

procedure InitData;
var
  I: Integer;
  R: Int64;
begin
  R := 123456789;
  for I := 0 to N-1 do begin
    R := (R * 6364136223846793005 + 1442695040888963407) and $7FFFFFFFFFFFFFFF;
    GData[I].A := R;
    GData[I].B := R div 3;
    GData[I].C := Integer(R and $7FFFFFFF);
    GData[I].D := Integer((R shr 32) and $7FFFFFFF);
    GData[I].E := (R mod 10000) * 0.0001;
    GData[I].F := (R mod 7777)  * 0.0001;
  end;
end;

{ --- RecFilter: count + copy records where A > threshold --- }

procedure RecFilter(const ACtx: IBenchContext);
var
  I, Iter, LCount: Integer;
  LThresh: Int64;
begin
  LCount := 0;
  for Iter := 1 to ITERS do begin
    LThresh := Int64(Iter) * 1000;
    for I := 0 to N-1 do begin
      if GData[I].A > LThresh then begin
        GDst[LCount mod N] := GData[I];
        Inc(LCount);
      end;
    end;
  end;
  GSink := LCount;
  ACtx.SetBytes(ITERS * N * SizeOf(TRec));
end;

{ --- RecCopy: bulk copy record array (Move on 48-byte records) --- }

procedure RecCopy(const ACtx: IBenchContext);
var
  Iter: Integer;
begin
  for Iter := 1 to ITERS do
    Move(GData[0], GDst[0], SizeOf(GData));
  GSink := GDst[0].A;
  ACtx.SetBytes(ITERS * SizeOf(GData));
end;

{ --- RecFieldSum: sum specific field (stride 48B access pattern) --- }

procedure RecFieldSum(const ACtx: IBenchContext);
var
  I, Iter: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do
      Inc(LSum, GData[I].A);
  GSink := LSum;
  ACtx.SetBytes(ITERS * N * SizeOf(TRec));
end;

{ --- RecBuild: construct records from components --- }

procedure RecBuild(const ACtx: IBenchContext);
var
  I, Iter: Integer;
  LVal: Int64;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LVal := GData[I].A + GData[I].B;
      GDst[I].A := LVal;
      GDst[I].B := LVal * 2;
      GDst[I].C := GData[I].C;
      GDst[I].D := GData[I].D;
      GDst[I].E := GData[I].E + GData[I].F;
      GDst[I].F := GData[I].E * GData[I].F;
    end;
  GSink := GDst[0].A;
  ACtx.SetBytes(ITERS * N * SizeOf(TRec));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('recops');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('RecFilter',   @RecFilter);
  LSuite.Add('RecCopy',     @RecCopy);
  LSuite.Add('RecFieldSum', @RecFieldSum);
  LSuite.Add('RecBuild',    @RecBuild);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
