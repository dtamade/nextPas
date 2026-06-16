program test_api_coverage_gather_scatter;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.simd.base,
  nextpas.core.simd,
  nextpas.core.simd.api_coverage.support;

procedure TestGatherScatterFacade;
var
  dataF: array[0..7] of Single;
  dataI: array[0..7] of Int32;
  idx: TVecI32x4;
  orF: TVecF32x4;
  orI: TVecI32x4;
  vf: TVecF32x4;
  vi: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    dataF[i] := (i + 1) * 10.0;
    dataI[i] := (i + 1) * 100;
  end;

  idx := VecI32x4Make(0, 3, 5, 7);
  orF := VecF32x4Make(-1.0, -2.0, -3.0, -4.0);
  orI := VecI32x4Make(-10, -20, -30, -40);

  vf := VecF32x4Gather(@dataF[0], idx);
  CheckFloat(vf.f[0], 10.0, 'Gather facade f32[0]');
  CheckFloat(vf.f[3], 80.0, 'Gather facade f32[3]');

  vi := VecI32x4Gather(@dataI[0], idx);
  Check(vi.i[0] = 100, 'Gather facade i32[0]');
  Check(vi.i[2] = 600, 'Gather facade i32[2]');

  vf := VecF32x4GatherSelect(@dataF[0], TMask4($05), idx, orF);
  CheckFloat(vf.f[0], 10.0, 'GatherSelect facade f32 enabled[0]');
  CheckFloat(vf.f[1], -2.0, 'GatherSelect facade f32 masked[1]');
  CheckFloat(vf.f[2], 60.0, 'GatherSelect facade f32 enabled[2]');
  CheckFloat(vf.f[3], -4.0, 'GatherSelect facade f32 masked[3]');

  vi := VecI32x4GatherSelect(@dataI[0], TMask4($0A), idx, orI);
  Check(vi.i[0] = -10, 'GatherSelect facade i32 masked[0]');
  Check(vi.i[1] = 400, 'GatherSelect facade i32 enabled[1]');
  Check(vi.i[2] = -30, 'GatherSelect facade i32 masked[2]');
  Check(vi.i[3] = 800, 'GatherSelect facade i32 enabled[3]');

  VecF32x4Scatter(@dataF[0], idx, VecF32x4Make(1.0, 2.0, 3.0, 4.0));
  CheckFloat(dataF[0], 1.0, 'Scatter facade f32[0]');
  CheckFloat(dataF[3], 2.0, 'Scatter facade f32[1]');
  CheckFloat(dataF[5], 3.0, 'Scatter facade f32[2]');
  CheckFloat(dataF[7], 4.0, 'Scatter facade f32[3]');

  VecI32x4Scatter(@dataI[0], idx, VecI32x4Make(11, 22, 33, 44));
  Check(dataI[0] = 11, 'Scatter facade i32[0]');
  Check(dataI[3] = 22, 'Scatter facade i32[1]');
  Check(dataI[5] = 33, 'Scatter facade i32[2]');
  Check(dataI[7] = 44, 'Scatter facade i32[3]');

  for i := 0 to 7 do
  begin
    dataF[i] := -(i + 1);
    dataI[i] := -(i + 1) * 10;
  end;

  VecF32x4ScatterSelect(@dataF[0], TMask4($09), idx, VecF32x4Make(11.0, 22.0, 33.0, 44.0));
  CheckFloat(dataF[0], 11.0, 'ScatterSelect facade f32 enabled[0]');
  CheckFloat(dataF[3], -4.0, 'ScatterSelect facade f32 masked[1]');
  CheckFloat(dataF[5], -6.0, 'ScatterSelect facade f32 masked[2]');
  CheckFloat(dataF[7], 44.0, 'ScatterSelect facade f32 enabled[3]');

  VecI32x4ScatterSelect(@dataI[0], TMask4($06), idx, VecI32x4Make(111, 222, 333, 444));
  Check(dataI[0] = -10, 'ScatterSelect facade i32 masked[0]');
  Check(dataI[3] = 222, 'ScatterSelect facade i32 enabled[1]');
  Check(dataI[5] = 333, 'ScatterSelect facade i32 enabled[2]');
  Check(dataI[7] = -80, 'ScatterSelect facade i32 masked[3]');
end;

procedure TestGatherScatterDuplicateIndexSemantics;
var
  dataF: array[0..7] of Single;
  dataI: array[0..7] of Int32;
  idx: TVecI32x4;
  vf: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    dataF[i] := (i + 1) * 10.0;
    dataI[i] := -1;
  end;

  idx := VecI32x4Make(3, 1, 3, 1);
  vf := VecF32x4Gather(@dataF[0], idx);
  CheckFloat(vf.f[0], 40.0, 'duplicate gather f32 preserves lane duplication[0]');
  CheckFloat(vf.f[1], 20.0, 'duplicate gather f32 preserves lane duplication[1]');
  CheckFloat(vf.f[2], 40.0, 'duplicate gather f32 preserves lane duplication[2]');
  CheckFloat(vf.f[3], 20.0, 'duplicate gather f32 preserves lane duplication[3]');

  idx := VecI32x4Make(5, 2, 5, 5);
  VecI32x4Scatter(@dataI[0], idx, VecI32x4Make(11, 22, 33, 44));
  Check(dataI[5] = 44, 'duplicate scatter i32 last lane wins');
  Check(dataI[2] = 22, 'duplicate scatter i32 preserves unrelated lane write');

  for i := 0 to 7 do
    dataF[i] := -1.0;

  idx := VecI32x4Make(4, 4, 4, 6);
  VecF32x4ScatterSelect(@dataF[0], TMask4($0D), idx, VecF32x4Make(10.0, 20.0, 30.0, 40.0));
  CheckFloat(dataF[4], 30.0, 'duplicate scatter select f32 last enabled lane wins');
  CheckFloat(dataF[6], 40.0, 'duplicate scatter select f32 preserves final enabled tail');
end;

procedure TestGatherScatterNilBaseContract;
var
  idx: TVecI32x4;
  orF: TVecF32x4;
  orI: TVecI32x4;
  vf: TVecF32x4;
  vi: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  idx := VecI32x4Make(0, 1, 2, 3);
  orF := VecF32x4Make(-1.0, -2.0, -3.0, -4.0);
  orI := VecI32x4Make(-10, -20, -30, -40);

  raisedArgumentNil := False;
  try
    VecF32x4Gather(nil, idx);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'gather facade f32 nil base raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'gather facade f32 nil base raises EArgumentNil');

  raisedArgumentNil := False;
  try
    VecI32x4Gather(nil, idx);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'gather facade i32 nil base raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'gather facade i32 nil base raises EArgumentNil');

  raisedArgumentNil := False;
  try
    VecF32x4Scatter(nil, idx, VecF32x4Make(1.0, 2.0, 3.0, 4.0));
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'scatter facade f32 nil base raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'scatter facade f32 nil base raises EArgumentNil');

  raisedArgumentNil := False;
  try
    VecI32x4Scatter(nil, idx, VecI32x4Make(11, 22, 33, 44));
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'scatter facade i32 nil base raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'scatter facade i32 nil base raises EArgumentNil');

  vf := VecF32x4GatherSelect(nil, TMask4($00), idx, orF);
  CheckFloat(vf.f[0], -1.0, 'gather select facade f32 nil base all-disabled returns orVal[0]');
  CheckFloat(vf.f[1], -2.0, 'gather select facade f32 nil base all-disabled returns orVal[1]');
  CheckFloat(vf.f[2], -3.0, 'gather select facade f32 nil base all-disabled returns orVal[2]');
  CheckFloat(vf.f[3], -4.0, 'gather select facade f32 nil base all-disabled returns orVal[3]');

  vi := VecI32x4GatherSelect(nil, TMask4($00), idx, orI);
  Check(vi.i[0] = -10, 'gather select facade i32 nil base all-disabled returns orVal[0]');
  Check(vi.i[1] = -20, 'gather select facade i32 nil base all-disabled returns orVal[1]');
  Check(vi.i[2] = -30, 'gather select facade i32 nil base all-disabled returns orVal[2]');
  Check(vi.i[3] = -40, 'gather select facade i32 nil base all-disabled returns orVal[3]');

  raisedArgumentNil := False;
  try
    VecF32x4GatherSelect(nil, TMask4($01), idx, orF);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'gather select facade f32 nil base enabled lane raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'gather select facade f32 nil base enabled lane raises EArgumentNil');

  raisedArgumentNil := False;
  try
    VecI32x4GatherSelect(nil, TMask4($02), idx, orI);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'gather select facade i32 nil base enabled lane raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'gather select facade i32 nil base enabled lane raises EArgumentNil');

  try
    VecF32x4ScatterSelect(nil, TMask4($00), idx, VecF32x4Make(11.0, 22.0, 33.0, 44.0));
    Check(True, 'scatter select facade f32 nil base all-disabled is no-op');
  except
    on E: Exception do
      Check(False, 'scatter select facade f32 nil base all-disabled raised ' + E.ClassName);
  end;

  try
    VecI32x4ScatterSelect(nil, TMask4($00), idx, VecI32x4Make(11, 22, 33, 44));
    Check(True, 'scatter select facade i32 nil base all-disabled is no-op');
  except
    on E: Exception do
      Check(False, 'scatter select facade i32 nil base all-disabled raised ' + E.ClassName);
  end;

  raisedArgumentNil := False;
  try
    VecF32x4ScatterSelect(nil, TMask4($04), idx, VecF32x4Make(11.0, 22.0, 33.0, 44.0));
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'scatter select facade f32 nil base enabled lane raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'scatter select facade f32 nil base enabled lane raises EArgumentNil');

  raisedArgumentNil := False;
  try
    VecI32x4ScatterSelect(nil, TMask4($08), idx, VecI32x4Make(11, 22, 33, 44));
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Check(False, 'scatter select facade i32 nil base enabled lane raised ' + E.ClassName);
  end;
  Check(raisedArgumentNil, 'scatter select facade i32 nil base enabled lane raises EArgumentNil');
end;

begin
  StartApiCoverageSuite('API Coverage Gather Scatter');
  TestGatherScatterFacade;
  TestGatherScatterDuplicateIndexSemantics;
  TestGatherScatterNilBaseContract;
  PrintApiCoverageSummary;
end.
