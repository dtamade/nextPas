program bench_simd_seam;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.math.vec,
  nextpas.core.math.impl.simd;

const
  SAMPLE_COUNT = 16;

var
  B: TBenchRunner;
  GVec4A: array[0..SAMPLE_COUNT - 1] of TVec4f;
  GVec4B: array[0..SAMPLE_COUNT - 1] of TVec4f;
  GVec3A: array[0..SAMPLE_COUNT - 1] of TVec3f;
  GVec3B: array[0..SAMPLE_COUNT - 1] of TVec3f;
  GVec4Sink: TVec4f;
  GVec3Sink: TVec3f;
  GFloatSink: Single;

procedure InitInputs;
var
  I: Integer;
  LBase: Single;
begin
  for I := 0 to SAMPLE_COUNT - 1 do
  begin
    LBase := I + 1;
    GVec4A[I] := TVec4f.Create(LBase, LBase + 0.25, LBase + 0.5, LBase + 0.75);
    GVec4B[I] := TVec4f.Create(LBase * 1.5, LBase * 1.75, LBase * 2.0, LBase * 2.25);
    GVec3A[I] := TVec3f.Create(LBase, LBase + 1.0, LBase + 2.0);
    GVec3B[I] := TVec3f.Create(LBase * 2.0, LBase * 2.5, LBase * 3.0);
  end;

  GVec4Sink := TVec4f.Zero;
  GVec3Sink := TVec3f.Zero;
  GFloatSink := 0.0;
end;

function SampleIndex(const AIteration: Int64): Integer; inline;
begin
  Result := Integer(AIteration and (SAMPLE_COUNT - 1));
end;

procedure BenchVec4fScalarAdd(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec4f;
begin
  LValue := GVec4Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + (GVec4A[LIndex] + GVec4B[LIndex]);
  end;
  GVec4Sink := LValue;
end;

procedure BenchVec4fSimdAdd(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec4f;
begin
  LValue := GVec4Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := SimdVec4fAdd(LValue, SimdVec4fAdd(GVec4A[LIndex], GVec4B[LIndex]));
  end;
  GVec4Sink := LValue;
end;

procedure BenchVec4fScalarScale(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec4f;
begin
  LValue := GVec4Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + (GVec4A[LIndex] * 1.75);
  end;
  GVec4Sink := LValue;
end;

procedure BenchVec4fSimdScale(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec4f;
begin
  LValue := GVec4Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := SimdVec4fAdd(LValue, SimdVec4fScale(GVec4A[LIndex], 1.75));
  end;
  GVec4Sink := LValue;
end;

procedure BenchVec4fScalarDot(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: Single;
begin
  LValue := GFloatSink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + TVec4f.Dot(GVec4A[LIndex], GVec4B[LIndex]);
  end;
  GFloatSink := LValue;
end;

procedure BenchVec4fSimdDot(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: Single;
begin
  LValue := GFloatSink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + SimdVec4fDot(GVec4A[LIndex], GVec4B[LIndex]);
  end;
  GFloatSink := LValue;
end;

procedure BenchVec4fScalarLength(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: Single;
begin
  LValue := GFloatSink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + GVec4A[LIndex].Length;
  end;
  GFloatSink := LValue;
end;

procedure BenchVec4fSimdLength(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: Single;
begin
  LValue := GFloatSink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + SimdVec4fLength(GVec4A[LIndex]);
  end;
  GFloatSink := LValue;
end;

procedure BenchVec3fScalarCross(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec3f;
begin
  LValue := GVec3Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + TVec3f.Cross(GVec3A[LIndex], GVec3B[LIndex]);
  end;
  GVec3Sink := LValue;
end;

procedure BenchVec3fSimdCross(AIterations: Int64);
var
  I: Int64;
  LIndex: Integer;
  LValue: TVec3f;
begin
  LValue := GVec3Sink;
  for I := 1 to AIterations do
  begin
    LIndex := SampleIndex(I);
    LValue := LValue + SimdVec3fCross(GVec3A[LIndex], GVec3B[LIndex]);
  end;
  GVec3Sink := LValue;
end;

begin
  InitInputs;

  B := TBenchRunner.Create;
  try
    WriteLn('=== nextpas.core.math SIMD seam benchmark ===');
    WriteLn('compiler-flags=-MObjFPC -Sh -O2');
    WriteLn('input-set=16 fixed TVec3f/TVec4f pairs');
    WriteLn('scope=public scalar vector methods vs internal SIMD helper seam');
    WriteLn('decision-note=public math value methods are still scalar; this is evidence only');
    WriteLn;

    B.Run('TVec4f scalar add', @BenchVec4fScalarAdd);
    B.Run('TVec4f simd seam add', @BenchVec4fSimdAdd);
    B.Run('TVec4f scalar scale', @BenchVec4fScalarScale);
    B.Run('TVec4f simd seam scale', @BenchVec4fSimdScale);
    B.Run('TVec4f scalar dot', @BenchVec4fScalarDot);
    B.Run('TVec4f simd seam dot', @BenchVec4fSimdDot);
    B.Run('TVec4f scalar length', @BenchVec4fScalarLength);
    B.Run('TVec4f simd seam length', @BenchVec4fSimdLength);
    B.Run('TVec3f scalar cross', @BenchVec3fScalarCross);
    B.Run('TVec3f simd seam cross', @BenchVec3fSimdCross);
    WriteLn;
    B.Summary;
  finally
    B.Free;
  end;

  WriteLn;
  WriteLn('sink=', GFloatSink:0:3, ':', GVec4Sink.X:0:3, ':', GVec3Sink.X:0:3);
end.
