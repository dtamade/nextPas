program test_static_avx2_misalignment;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}
{$R-}{$Q-}

uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.static.avx2;

type
  PVecF32x4 = ^TVecF32x4;
  PVecF32x8 = ^TVecF32x8;
  PVecF64x2 = ^TVecF64x2;

function MisalignedPtr(var ABuffer: TBytes; const AOffset: NativeUInt): Pointer;
begin
  if Length(ABuffer) <= Integer(AOffset) then
    raise Exception.Create('misalignment buffer is too small');
  Result := Pointer(PtrUInt(@ABuffer[0]) + AOffset);
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('[FAIL] ', AMessage);
  Halt(1);
end;

procedure CheckSingle(const AName: string; const AExpected, AActual: Single);
begin
  if Abs(AExpected - AActual) > 0.0001 then
    Fail(Format('%s expected %.6f got %.6f', [AName, AExpected, AActual]));
end;

procedure CheckDouble(const AName: string; const AExpected, AActual: Double);
begin
  if Abs(AExpected - AActual) > 0.0000001 then
    Fail(Format('%s expected %.12f got %.12f', [AName, AExpected, AActual]));
end;

procedure CheckF32x4;
var
  LA, LB: TBytes;
  PA, PB: PVecF32x4;
  LResult: TVecF32x4;
  I: Integer;
begin
  SetLength(LA, SizeOf(TVecF32x4) + 8);
  SetLength(LB, SizeOf(TVecF32x4) + 8);
  PA := PVecF32x4(MisalignedPtr(LA, 1));
  PB := PVecF32x4(MisalignedPtr(LB, 3));

  for I := 0 to 3 do
  begin
    PA^.f[I] := I + 1.0;
    PB^.f[I] := (I + 1.0) * 10.0;
  end;

  LResult := nextpas.core.simd.static.avx2.VecF32x4Add(PA^, PB^);
  for I := 0 to 3 do
    CheckSingle('F32x4Add[' + IntToStr(I) + ']', (I + 1.0) * 11.0, LResult.f[I]);

  LResult := nextpas.core.simd.static.avx2.VecF32x4Mul(PA^, PB^);
  for I := 0 to 3 do
    CheckSingle('F32x4Mul[' + IntToStr(I) + ']', Sqr(I + 1.0) * 10.0, LResult.f[I]);
end;

procedure CheckF32x8;
var
  LA, LB: TBytes;
  PA, PB: PVecF32x8;
  LResult: TVecF32x8;
  I: Integer;
begin
  SetLength(LA, SizeOf(TVecF32x8) + 16);
  SetLength(LB, SizeOf(TVecF32x8) + 16);
  PA := PVecF32x8(MisalignedPtr(LA, 5));
  PB := PVecF32x8(MisalignedPtr(LB, 7));

  for I := 0 to 7 do
  begin
    PA^.f[I] := I + 1.0;
    PB^.f[I] := 2.0;
  end;

  LResult := nextpas.core.simd.static.avx2.VecF32x8Add(PA^, PB^);
  for I := 0 to 7 do
    CheckSingle('F32x8Add[' + IntToStr(I) + ']', I + 3.0, LResult.f[I]);

  LResult := nextpas.core.simd.static.avx2.VecF32x8Mul(PA^, PB^);
  for I := 0 to 7 do
    CheckSingle('F32x8Mul[' + IntToStr(I) + ']', (I + 1.0) * 2.0, LResult.f[I]);
end;

procedure CheckF64x2;
var
  LA, LB: TBytes;
  PA, PB: PVecF64x2;
  LResult: TVecF64x2;
  I: Integer;
begin
  SetLength(LA, SizeOf(TVecF64x2) + 8);
  SetLength(LB, SizeOf(TVecF64x2) + 8);
  PA := PVecF64x2(MisalignedPtr(LA, 1));
  PB := PVecF64x2(MisalignedPtr(LB, 5));

  for I := 0 to 1 do
  begin
    PA^.d[I] := I + 1.0;
    PB^.d[I] := 0.5;
  end;

  LResult := nextpas.core.simd.static.avx2.VecF64x2Add(PA^, PB^);
  for I := 0 to 1 do
    CheckDouble('F64x2Add[' + IntToStr(I) + ']', I + 1.5, LResult.d[I]);

  LResult := nextpas.core.simd.static.avx2.VecF64x2Mul(PA^, PB^);
  for I := 0 to 1 do
    CheckDouble('F64x2Mul[' + IntToStr(I) + ']', (I + 1.0) * 0.5, LResult.d[I]);
end;

begin
  WriteLn('Static AVX2 misalignment smoke');
  if not HasAVX2 then
    Fail('static AVX2 smoke requires usable AVX2');

  CheckF32x4;
  CheckF32x8;
  CheckF64x2;

  WriteLn('[PASS] static AVX2 misaligned inputs are safe');
  WriteLn('[INFO] heaptrc must report 0 unfreed memory blocks');
end.
