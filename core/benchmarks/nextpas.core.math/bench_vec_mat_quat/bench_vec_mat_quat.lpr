{
  bench_vec_mat_quat.lpr
  Benchmark for nextpas.core.math vec/mat/quat operations.
  Compares against FPC RTL Math unit where applicable.
}
program bench_vec_mat_quat;

{$I nextpas.core.settings.inc}
{$O2+}

uses
  SysUtils,
  {$IFDEF FPC}Math,{$ENDIF}
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base,
  nextpas.core.math.quat.base;

const
  ITERATIONS = 10000000;

var
  GStart, GEnd, GFreq: Int64;

procedure StartTimer;
begin
  GStart := GetTickCount64;
end;

function ElapsedMs: Double;
begin
  GEnd := GetTickCount64;
  Result := GEnd - GStart;
end;

function NsPerOp(ATotalMs: Double; ACount: Integer): Double;
begin
  Result := (ATotalMs * 1000000.0) / ACount;
end;

procedure BenchHeader(const AName: string);
begin
  WriteLn('--- ', AName, ' ---');
end;

procedure BenchResult(const AName: string; ATotalMs: Double; ACount: Integer);
begin
  WriteLn(Format('  %-30s %10d ops  %8.1f ms  %8.1f ns/op',
    [AName, ACount, ATotalMs, NsPerOp(ATotalMs, ACount)]));
end;

{ === Vec3f Benchmarks === }

procedure BenchVec3fDot;
var
  A, B: TVec3f;
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TVec3f.Dot');
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := A.Dot(B);
  LT := ElapsedMs;
  BenchResult('TVec3f.Dot', LT, ITERATIONS);
  if LResult = 0 then WriteLn; { prevent optimization }
end;

procedure BenchVec3fLength;
var
  A: TVec3f;
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TVec3f.Length');
  A := TVec3f.Create(1.0, 2.0, 3.0);
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := A.Length;
  LT := ElapsedMs;
  BenchResult('TVec3f.Length', LT, ITERATIONS);
  if LResult = 0 then WriteLn;
end;

procedure BenchVec3fNormalize;
var
  A, R: TVec3f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TVec3f.Normalize');
  A := TVec3f.Create(1.0, 2.0, 3.0);
  StartTimer;
  for I := 1 to ITERATIONS do
    R := A.Normalize;
  LT := ElapsedMs;
  BenchResult('TVec3f.Normalize', LT, ITERATIONS);
  if R.X = 0 then WriteLn;
end;

{ === Vec4f Benchmarks === }

procedure BenchVec4fDot;
var
  A, B: TVec4f;
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TVec4f.Dot');
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := A.Dot(B);
  LT := ElapsedMs;
  BenchResult('TVec4f.Dot', LT, ITERATIONS);
  if LResult = 0 then WriteLn;
end;

{ === Mat4f Benchmarks === }

procedure BenchMat4fMultiply;
var
  A, B, C: TMat4f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TMat4f * TMat4f (SIMD)');
  A := Mat4fIdentity;
  A[0,0] := 2.0; A[1,1] := 3.0; A[2,2] := 4.0;
  A[3,0] := 10.0; A[3,1] := 20.0; A[3,2] := 30.0;
  B := Mat4fIdentity;
  B[0,0] := 0.5; B[1,1] := 0.33; B[2,2] := 0.25;
  StartTimer;
  for I := 1 to ITERATIONS do
    C := A * B;
  LT := ElapsedMs;
  BenchResult('TMat4f * TMat4f', LT, ITERATIONS);
  if C[0,0] = 0 then WriteLn;
end;

procedure BenchMat4fMulVec;
var
  M: TMat4f;
  V, R: TVec4f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('Mat4fMulVec (SIMD)');
  M := Mat4fIdentity;
  M[0,0] := 2.0; M[1,1] := 3.0; M[2,2] := 4.0;
  V := TVec4f.Create(1.0, 2.0, 3.0, 1.0);
  StartTimer;
  for I := 1 to ITERATIONS do
    R := Mat4fMulVec(M, V);
  LT := ElapsedMs;
  BenchResult('Mat4fMulVec', LT, ITERATIONS);
  if R.X = 0 then WriteLn;
end;

procedure BenchMat4fDeterminant;
var
  M: TMat4f;
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TMat4f.Determinant');
  M := Mat4fIdentity;
  M[0,0] := 2.0; M[1,1] := 3.0; M[2,2] := 4.0; M[3,3] := 5.0;
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := M.Determinant;
  LT := ElapsedMs;
  BenchResult('TMat4f.Determinant', LT, ITERATIONS);
  if LResult = 0 then WriteLn;
end;

procedure BenchMat4fInverse;
var
  M, R: TMat4f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TMat4f.Inverse');
  M := Mat4fIdentity;
  M[0,0] := 2.0; M[1,1] := 3.0; M[2,2] := 4.0; M[3,3] := 5.0;
  StartTimer;
  for I := 1 to ITERATIONS div 10 do
    R := M.Inverse;
  LT := ElapsedMs;
  BenchResult('TMat4f.Inverse', LT, ITERATIONS div 10);
  if R[0,0] = 0 then WriteLn;
end;

{ === Quat Benchmarks === }

procedure BenchQuatfRotateVec;
var
  Q: TQuatf;
  V, R: TVec3f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TQuatf.RotateVec');
  Q := TQuatf.FromAxisAngle(TVec3f.Create(0, 1, 0), HALF_PI);
  V := TVec3f.Create(1, 0, 0);
  StartTimer;
  for I := 1 to ITERATIONS do
    R := Q.RotateVec(V);
  LT := ElapsedMs;
  BenchResult('TQuatf.RotateVec', LT, ITERATIONS);
  if R.X = 0 then WriteLn;
end;

procedure BenchQuatfFromAxisAngle;
var
  Q: TQuatf;
  Axis: TVec3f;
  I: Integer;
  LT: Double;
begin
  BenchHeader('TQuatf.FromAxisAngle');
  Axis := TVec3f.Create(0, 1, 0);
  StartTimer;
  for I := 1 to ITERATIONS do
    Q := TQuatf.FromAxisAngle(Axis, HALF_PI);
  LT := ElapsedMs;
  BenchResult('TQuatf.FromAxisAngle', LT, ITERATIONS);
  if Q.X = 0 then WriteLn;
end;

{ === Scalar Trig Benchmarks (FPC RTL comparison) === }

procedure BenchSin;
var
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('Sin (Single)');
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := nextpas.core.math.trig.Sin(Single(I) * 0.001);
  LT := ElapsedMs;
  BenchResult('nextpas Sin', LT, ITERATIONS);
  if LResult = 0 then WriteLn;

  {$IFDEF FPC}
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := System.Sin(Single(I) * 0.001);
  LT := ElapsedMs;
  BenchResult('FPC RTL Sin', LT, ITERATIONS);
  if LResult = 0 then WriteLn;
  {$ENDIF}
end;

procedure BenchSqrt;
var
  LResult: Single;
  I: Integer;
  LT: Double;
begin
  BenchHeader('Sqrt (Single)');
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := Sqrt(Single(I) * 0.001);
  LT := ElapsedMs;
  BenchResult('nextpas Sqrt', LT, ITERATIONS);
  if LResult = 0 then WriteLn;

  {$IFDEF FPC}
  StartTimer;
  for I := 1 to ITERATIONS do
    LResult := System.Sqrt(Single(I) * 0.001);
  LT := ElapsedMs;
  BenchResult('FPC RTL Sqrt', LT, ITERATIONS);
  if LResult = 0 then WriteLn;
  {$ENDIF}
end;

{ === Main === }

begin
  WriteLn('=== nextpas.core.math Benchmarks ===');
  WriteLn('Iterations per test: ', ITERATIONS);
  WriteLn;

  BenchVec3fDot;
  WriteLn;
  BenchVec3fLength;
  WriteLn;
  BenchVec3fNormalize;
  WriteLn;
  BenchVec4fDot;
  WriteLn;
  BenchMat4fMultiply;
  WriteLn;
  BenchMat4fMulVec;
  WriteLn;
  BenchMat4fDeterminant;
  WriteLn;
  BenchMat4fInverse;
  WriteLn;
  BenchQuatfRotateVec;
  WriteLn;
  BenchQuatfFromAxisAngle;
  WriteLn;
  BenchSin;
  WriteLn;
  BenchSqrt;

  WriteLn;
  WriteLn('=== Done ===');
end.
