program test_impl_simd_win64_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math,
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.vec,
  nextpas.core.math.impl.simd;

var
  V3: TVec3f;
  V4: TVec4f;
  M: TMat4f;
  Q: TQuatf;
  S: Single;

begin
  V3 := TVec3f.Create(1.0, 2.0, 3.0);
  V4 := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  M := TMat4f.Identity;
  Q := TQuatf.Identity;

  V4 := SimdVec4fAdd(V4, SimdVec4fSub(V4, V4));
  V4 := SimdVec4fComponentMul(V4, SimdVec4fScale(V4, 1.0));
  V4 := SimdMat4fMulVec4f(M, V4);
  V3 := SimdVec3fCross(V3, SimdQuatfRotate(Q, V3));
  S := SimdVec4fDot(V4, V4) + SimdVec4fLength(V4) + SimdVec3fDot(V3, V3);
  if S < 0.0 then
    Halt(1);
end.
