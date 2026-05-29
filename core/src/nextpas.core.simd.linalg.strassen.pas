unit nextpas.core.simd.linalg.strassen;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

// Strassen matrix multiplication: O(N^2.807) for large square matrices
// Falls back to GemmBlockedF32 below threshold
procedure StrassenF32(AA, AB, AC: PSingle;
  AN, ALdA, ALdB, ALdC: SizeUInt);

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.linalg.gemm;

const
  STRASSEN_THRESHOLD = 128;

procedure MatAdd(AA, AB, AC: PSingle; AN, ALdA, ALdB, ALdC: SizeUInt);
var LI: SizeUInt;
begin
  for LI := 0 to AN - 1 do
    ArrayAddF32(@AA[LI * ALdA], @AB[LI * ALdB], @AC[LI * ALdC], AN);
end;

procedure MatSub(AA, AB, AC: PSingle; AN, ALdA, ALdB, ALdC: SizeUInt);
var LI: SizeUInt;
begin
  for LI := 0 to AN - 1 do
    ArraySubF32(@AA[LI * ALdA], @AB[LI * ALdB], @AC[LI * ALdC], AN);
end;

procedure StrassenF32(AA, AB, AC: PSingle;
  AN, ALdA, ALdB, ALdC: SizeUInt);
var
  LHalf: SizeUInt;
  LTmpSize: SizeUInt;
  LM1, LM2, LM3, LM4, LM5, LM6, LM7: PSingle;
  LT1, LT2: PSingle;
  LA11, LA12, LA21, LA22: PSingle;
  LB11, LB12, LB21, LB22: PSingle;
  LC11, LC12, LC21, LC22: PSingle;
begin
  if AN <= STRASSEN_THRESHOLD then
  begin
    FillChar(AC^, AN * ALdC * SizeOf(Single), 0);
    GemmBlockedF32(AA, AB, AC, AN, AN, AN, ALdA, ALdB, ALdC);
    Exit;
  end;

  LHalf := AN div 2;
  LTmpSize := LHalf * LHalf * SizeOf(Single);

  // Submatrix pointers
  LA11 := AA; LA12 := @AA[LHalf];
  LA21 := @AA[LHalf * ALdA]; LA22 := @AA[LHalf * ALdA + LHalf];
  LB11 := AB; LB12 := @AB[LHalf];
  LB21 := @AB[LHalf * ALdB]; LB22 := @AB[LHalf * ALdB + LHalf];
  LC11 := AC; LC12 := @AC[LHalf];
  LC21 := @AC[LHalf * ALdC]; LC22 := @AC[LHalf * ALdC + LHalf];

  // Allocate temporaries
  LM1 := PSingle(SimdAlloc(LTmpSize));
  LM2 := PSingle(SimdAlloc(LTmpSize));
  LM3 := PSingle(SimdAlloc(LTmpSize));
  LM4 := PSingle(SimdAlloc(LTmpSize));
  LM5 := PSingle(SimdAlloc(LTmpSize));
  LM6 := PSingle(SimdAlloc(LTmpSize));
  LM7 := PSingle(SimdAlloc(LTmpSize));
  LT1 := PSingle(SimdAlloc(LTmpSize));
  LT2 := PSingle(SimdAlloc(LTmpSize));

  // M1 = (A11 + A22) * (B11 + B22)
  MatAdd(LA11, LA22, LT1, LHalf, ALdA, ALdA, LHalf);
  MatAdd(LB11, LB22, LT2, LHalf, ALdB, ALdB, LHalf);
  StrassenF32(LT1, LT2, LM1, LHalf, LHalf, LHalf, LHalf);

  // M2 = (A21 + A22) * B11
  MatAdd(LA21, LA22, LT1, LHalf, ALdA, ALdA, LHalf);
  StrassenF32(LT1, LB11, LM2, LHalf, LHalf, ALdB, LHalf);

  // M3 = A11 * (B12 - B22)
  MatSub(LB12, LB22, LT1, LHalf, ALdB, ALdB, LHalf);
  StrassenF32(LA11, LT1, LM3, LHalf, ALdA, LHalf, LHalf);

  // M4 = A22 * (B21 - B11)
  MatSub(LB21, LB11, LT1, LHalf, ALdB, ALdB, LHalf);
  StrassenF32(LA22, LT1, LM4, LHalf, ALdA, LHalf, LHalf);

  // M5 = (A11 + A12) * B22
  MatAdd(LA11, LA12, LT1, LHalf, ALdA, ALdA, LHalf);
  StrassenF32(LT1, LB22, LM5, LHalf, LHalf, ALdB, LHalf);

  // M6 = (A21 - A11) * (B11 + B12)
  MatSub(LA21, LA11, LT1, LHalf, ALdA, ALdA, LHalf);
  MatAdd(LB11, LB12, LT2, LHalf, ALdB, ALdB, LHalf);
  StrassenF32(LT1, LT2, LM6, LHalf, LHalf, LHalf, LHalf);

  // M7 = (A12 - A22) * (B21 + B22)
  MatSub(LA12, LA22, LT1, LHalf, ALdA, ALdA, LHalf);
  MatAdd(LB21, LB22, LT2, LHalf, ALdB, ALdB, LHalf);
  StrassenF32(LT1, LT2, LM7, LHalf, LHalf, LHalf, LHalf);

  // C11 = M1 + M4 - M5 + M7
  MatAdd(LM1, LM4, LT1, LHalf, LHalf, LHalf, LHalf);
  MatSub(LT1, LM5, LT2, LHalf, LHalf, LHalf, LHalf);
  MatAdd(LT2, LM7, LC11, LHalf, LHalf, LHalf, ALdC);

  // C12 = M3 + M5
  MatAdd(LM3, LM5, LC12, LHalf, LHalf, LHalf, ALdC);

  // C21 = M2 + M4
  MatAdd(LM2, LM4, LC21, LHalf, LHalf, LHalf, ALdC);

  // C22 = M1 - M2 + M3 + M6
  MatSub(LM1, LM2, LT1, LHalf, LHalf, LHalf, LHalf);
  MatAdd(LT1, LM3, LT2, LHalf, LHalf, LHalf, LHalf);
  MatAdd(LT2, LM6, LC22, LHalf, LHalf, LHalf, ALdC);

  SimdFree(LT2); SimdFree(LT1);
  SimdFree(LM7); SimdFree(LM6); SimdFree(LM5);
  SimdFree(LM4); SimdFree(LM3); SimdFree(LM2); SimdFree(LM1);
end;

end.
