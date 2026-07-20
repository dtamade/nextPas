program bench_vec_mat_quat;
{$I nextpas.core.settings.inc}{$O2+}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.math.base, nextpas.core.math.scalar, nextpas.core.math.trig,
  nextpas.core.math.vec.base, nextpas.core.math.mat.base, nextpas.core.math.quat.base;
var GSink: UInt64 = 0;

function SinkF32(const AValue: Single): UInt64; inline;
var LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits;
end;

function SinkF64(const AValue: Double): UInt64; inline;
var LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits;
end;

procedure BenchVec3fDot(const ACtx: IBenchContext);
var A, B: TVec3f; L: Single;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);
  L := A.Dot(B);
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec3fLength(const ACtx: IBenchContext);
var A: TVec3f; L: Single;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  L := A.Length;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec3fNormalize(const ACtx: IBenchContext);
var A: TVec3f; L: Single;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  L := A.Normalize.X;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec3fCross(const ACtx: IBenchContext);
var A, B: TVec3f; L: Single;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);
  L := A.Cross(B).X;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec4fDot(const ACtx: IBenchContext);
var A, B: TVec4f; L: Single;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);
  L := A.Dot(B);
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec4fLength(const ACtx: IBenchContext);
var A: TVec4f; L: Single;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  L := A.Length;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchMat4fMul(const ACtx: IBenchContext);
var A, B, C: TMat4f; L: Single;
begin
  A := Mat4fIdentity;
  B := Mat4fIdentity;
  C := A * B;
  L := C.Data[0, 0];
  GSink := GSink xor SinkF32(L);
end;
procedure BenchMat4fInverse(const ACtx: IBenchContext);
var A, C: TMat4f; L: Single;
begin
  A := Mat4fIdentity;
  C := A.Inverse;
  L := C.Data[0, 0];
  GSink := GSink xor SinkF32(L);
end;
procedure BenchMat4fDeterminant(const ACtx: IBenchContext);
var A: TMat4f; L: Single;
begin
  A := Mat4fIdentity;
  L := A.Determinant;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchQuatMul(const ACtx: IBenchContext);
var A, B, C: TQuatf; L: Single;
begin
  A := QuatfIdentity;
  B := QuatfIdentity;
  C := A * B;
  L := C.X;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchQuatToMat4f(const ACtx: IBenchContext);
var A: TQuatf; M: TMat4f; L: Single;
begin
  A := QuatfIdentity;
  M := A.ToMat4f;
  L := M.Data[0, 0];
  GSink := GSink xor SinkF32(L);
end;
procedure BenchQuatFromAxisAngle(const ACtx: IBenchContext);
var A: TQuatf; L: Single;
begin
  A := TQuatf.FromAxisAngle(TVec3f.Create(0, 1, 0), 1.5708);
  L := A.X;
  GSink := GSink xor SinkF32(L);
end;
procedure BenchVec3dDot(const ACtx: IBenchContext);
var A, B: TVec3d; L: Double;
begin
  A := TVec3d.Create(1.0, 2.0, 3.0);
  B := TVec3d.Create(4.0, 5.0, 6.0);
  L := A.Dot(B);
  GSink := GSink xor SinkF64(L);
end;
procedure BenchVec3dLength(const ACtx: IBenchContext);
var A: TVec3d; L: Double;
begin
  A := TVec3d.Create(1.0, 2.0, 3.0);
  L := A.Length;
  GSink := GSink xor SinkF64(L);
end;
procedure BenchMat4dMul(const ACtx: IBenchContext);
var A, B, C: TMat4d; L: Double;
begin
  A := Mat4dIdentity;
  B := Mat4dIdentity;
  C := A * B;
  L := C.Data[0, 0];
  GSink := GSink xor SinkF64(L);
end;
procedure BenchQuatdMul(const ACtx: IBenchContext);
var A, B, C: TQuatd; L: Double;
begin
  A := QuatdIdentity;
  B := QuatdIdentity;
  C := A * B;
  L := C.X;
  GSink := GSink xor SinkF64(L);
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('vec-mat-quat');
  LSuite.Add('TVec3f.Dot', @BenchVec3fDot).Add('TVec3f.Length', @BenchVec3fLength).Add('TVec3f.Normalize', @BenchVec3fNormalize)
    .Add('TVec3f.Cross', @BenchVec3fCross).Add('TVec4f.Dot', @BenchVec4fDot).Add('TVec4f.Length', @BenchVec4fLength)
    .Add('TMat4f.Mul', @BenchMat4fMul).Add('TMat4f.Inverse', @BenchMat4fInverse).Add('TMat4f.Determinant', @BenchMat4fDeterminant)
    .Add('TQuatf.Mul', @BenchQuatMul).Add('TQuatf.ToMat4f', @BenchQuatToMat4f).Add('TQuatf.FromAxisAngle', @BenchQuatFromAxisAngle)
    .Add('TVec3d.Dot', @BenchVec3dDot).Add('TVec3d.Length', @BenchVec3dLength).Add('TMat4d.Mul', @BenchMat4dMul).Add('TQuatd.Mul', @BenchQuatdMul);
  WriteLn(LSuite.Run.PrintToConsole);
end.
