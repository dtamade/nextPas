unit nextpas.core.simd.alignment.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$R-}{$Q-}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.base;

type
  TTestCase_Alignment = class(TTestCase)
  published
    procedure Test_F32x4_UnalignedLoad_NoFault;
    procedure Test_F32x4_AlignedLoad_Correctness;
    procedure Test_F32x4_UnalignedStore_NoFault;
    procedure Test_F32x4_AlignedVsUnaligned_Parity;
    procedure Test_F32x4_OffsetLoad_AllOffsets;
  end;

implementation

procedure TTestCase_Alignment.Test_F32x4_UnalignedLoad_NoFault;
var
  buf: array[0..31] of Single;
  v: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 31 do buf[i] := i * 1.0;
  v := VecF32x4Load(@buf[1]);
  AssertEquals('Unaligned[0]', 1.0, v.f[0], 0.0001);
  AssertEquals('Unaligned[1]', 2.0, v.f[1], 0.0001);
  AssertEquals('Unaligned[2]', 3.0, v.f[2], 0.0001);
  AssertEquals('Unaligned[3]', 4.0, v.f[3], 0.0001);
end;

procedure TTestCase_Alignment.Test_F32x4_AlignedLoad_Correctness;
var
  buf: array[0..7] of Single;
  v: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do buf[i] := (i + 1) * 10.0;
  v := VecF32x4LoadAligned(@buf[0]);
  AssertEquals('Aligned[0]', 10.0, v.f[0], 0.0001);
  AssertEquals('Aligned[1]', 20.0, v.f[1], 0.0001);
  AssertEquals('Aligned[2]', 30.0, v.f[2], 0.0001);
  AssertEquals('Aligned[3]', 40.0, v.f[3], 0.0001);
end;

procedure TTestCase_Alignment.Test_F32x4_UnalignedStore_NoFault;
var
  buf: array[0..31] of Single;
  v: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 31 do buf[i] := 0.0;
  v.f[0] := 1.0; v.f[1] := 2.0; v.f[2] := 3.0; v.f[3] := 4.0;
  VecF32x4Store(@buf[3], v);
  AssertEquals('UnalignedStore[3]', 1.0, buf[3], 0.0001);
  AssertEquals('UnalignedStore[4]', 2.0, buf[4], 0.0001);
  AssertEquals('UnalignedStore[5]', 3.0, buf[5], 0.0001);
  AssertEquals('UnalignedStore[6]', 4.0, buf[6], 0.0001);
end;

procedure TTestCase_Alignment.Test_F32x4_AlignedVsUnaligned_Parity;
var
  buf: array[0..15] of Single;
  vAligned, vUnaligned: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 15 do buf[i] := i * 3.14;
  vAligned := VecF32x4LoadAligned(@buf[0]);
  vUnaligned := VecF32x4Load(@buf[0]);
  for i := 0 to 3 do
    AssertEquals('Parity[' + IntToStr(i) + ']', vAligned.f[i], vUnaligned.f[i], 0.0);
end;

procedure TTestCase_Alignment.Test_F32x4_OffsetLoad_AllOffsets;
var
  buf: array[0..31] of Single;
  v: TVecF32x4;
  offset, i: Integer;
begin
  for i := 0 to 31 do buf[i] := i * 1.0;
  for offset := 0 to 7 do
  begin
    v := VecF32x4Load(@buf[offset]);
    for i := 0 to 3 do
      AssertEquals('Offset' + IntToStr(offset) + '[' + IntToStr(i) + ']',
        Single(offset + i), v.f[i], 0.0001);
  end;
end;

initialization
  RegisterTest(TTestCase_Alignment);

end.
