program bench_vec_mat_quat;
{$I nextpas.core.settings.inc}{$O2+}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.math.base, nextpas.core.math.scalar, nextpas.core.math.trig,
  nextpas.core.math.vec.base, nextpas.core.math.mat.base, nextpas.core.math.quat.base;
var GSink: UInt64 = 0;
procedure BenchVec3fDot(const ACtx: IBenchContext);
var A, B: TVec3f;
begin A := TVec3f.Create(1.0, 2.0, 3.0); B := TVec3f.Create(4.0, 5.0, 6.0); GSink := GSink xor UInt64(A.Dot(B)); end;
procedure BenchVec3fLength(const ACtx: IBenchContext);
var A: TVec3f;
begin A := TVec3f.Create(1.0, 2.0, 3.0); GSink := GSink xor UInt64(A.Length); end;
procedure BenchVec3fNormalize(const ACtx: IBenchContext);
var A: TVec3f;
begin A := TVec3f.Create(1.0, 2.0, 3.0); GSink := GSink xor UInt64(A.Normalize.x); end;
procedure BenchVec3fCross(const ACtx: IBenchContext);
var A, B: TVec3f;
begin A := TVec3f.Create(1.0, 2.0, 3.0); B := TVec3f.Create(4.0, 5.0, 6.0); GSink := GSink xor UInt64(A.Cross(B).x); end;
procedure BenchVec4fDot(const ACtx: IBenchContext);
var A, B: TVec4f;
begin A := TVec4f.Create(1.0, 2.0, 3.0, 4.0); B := TVec4f.Create(5.0, 6.0, 7.0, 8.0); GSink := GSink xor UInt64(A.Dot(B)); end;
procedure BenchVec4fLength(const ACtx: IBenchContext);
var A: TVec4f;
begin A := TVec4f.Create(1.0, 2.0, 3.0, 4.0); GSink := GSink xor UInt64(A.Length); end;
procedure BenchMat4fMul(const ACtx: IBenchContext);
var A, B: TMat4f;
begin A := TMat4f.Identity; B := TMat4f.Identity; GSink := GSink xor UInt64(A.Mul(B).m00); end;
procedure BenchMat4fInverse(const ACtx: IBenchContext);
var A: TMat4f;
begin A := TMat4f.Identity; GSink := GSink xor UInt64(A.Inverse.m00); end;
procedure BenchMat4fDeterminant(const ACtx: IBenchContext);
var A: TMat4f;
begin A := TMat4f.Identity; GSink := GSink xor UInt64(A.Determinant); end;
procedure BenchQuatMul(const ACtx: IBenchContext);
var A, B: TQuat;
begin A := TQuat.Identity; B := TQuat.Identity; GSink := GSink xor UInt64(A.Mul(B).x); end;
procedure BenchQuatToMat4f(const ACtx: IBenchContext);
var A: TQuat; M: TMat4f;
begin A := TQuat.Identity; M := A.ToMat4f; GSink := GSink xor UInt64(M.m00); end;
procedure BenchQuatFromAxisAngle(const ACtx: IBenchContext);
var A: TQuat;
begin A := TQuat.FromAxisAngle(TVec3f.Create(0, 1, 0), 1.5708); GSink := GSink xor UInt64(A.x); end;
procedure BenchVec3dDot(const ACtx: IBenchContext);
var A, B: TVec3d;
begin A := TVec3d.Create(1.0, 2.0, 3.0); B := TVec3d.Create(4.0, 5.0, 6.0); GSink := GSink xor UInt64(A.Dot(B)); end;
procedure BenchVec3dLength(const ACtx: IBenchContext);
var A: TVec3d;
begin A := TVec3d.Create(1.0, 2.0, 3.0); GSink := GSink xor UInt64(A.Length); end;
procedure BenchMat4dMul(const ACtx: IBenchContext);
var A, B: TMat4d;
begin A := TMat4d.Identity; B := TMat4d.Identity; GSink := GSink xor UInt64(A.Mul(B).m00); end;
procedure BenchQuatdMul(const ACtx: IBenchContext);
var A, B: TQuatd;
begin A := TQuatd.Identity; B := TQuatd.Identity; GSink := GSink xor UInt64(A.Mul(B).x); end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('vec-mat-quat');
  LSuite.Add('TVec3f.Dot', @BenchVec3fDot).Add('TVec3f.Length', @BenchVec3fLength).Add('TVec3f.Normalize', @BenchVec3fNormalize)
    .Add('TVec3f.Cross', @BenchVec3fCross).Add('TVec4f.Dot', @BenchVec4fDot).Add('TVec4f.Length', @BenchVec4fLength)
    .Add('TMat4f.Mul', @BenchMat4fMul).Add('TMat4f.Inverse', @BenchMat4fInverse).Add('TMat4f.Determinant', @BenchMat4fDeterminant)
    .Add('TQuat.Mul', @BenchQuatMul).Add('TQuat.ToMat4f', @BenchQuatToMat4f).Add('TQuat.FromAxisAngle', @BenchQuatFromAxisAngle)
    .Add('TVec3d.Dot', @BenchVec3dDot).Add('TVec3d.Length', @BenchVec3dLength).Add('TMat4d.Mul', @BenchMat4dMul).Add('TQuatd.Mul', @BenchQuatdMul);
  WriteLn(LSuite.Run.PrintToConsole);
end.
