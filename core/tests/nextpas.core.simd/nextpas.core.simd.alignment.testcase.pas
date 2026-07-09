unit nextpas.core.simd.alignment.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd,
  nextpas.core.simd.base;

{$M+}
type
  TTestCase_Alignment = class(TTestFixture)
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
  CheckNear(1.0, v.f[0], 0.0001, 'Unaligned[0]');
  CheckNear(2.0, v.f[1], 0.0001, 'Unaligned[1]');
  CheckNear(3.0, v.f[2], 0.0001, 'Unaligned[2]');
  CheckNear(4.0, v.f[3], 0.0001, 'Unaligned[3]');
end;

procedure TTestCase_Alignment.Test_F32x4_AlignedLoad_Correctness;
var
  buf: array[0..7] of Single;
  v: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do buf[i] := (i + 1) * 10.0;
  v := VecF32x4LoadAligned(@buf[0]);
  CheckNear(10.0, v.f[0], 0.0001, 'Aligned[0]');
  CheckNear(20.0, v.f[1], 0.0001, 'Aligned[1]');
  CheckNear(30.0, v.f[2], 0.0001, 'Aligned[2]');
  CheckNear(40.0, v.f[3], 0.0001, 'Aligned[3]');
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
  CheckNear(1.0, buf[3], 0.0001, 'UnalignedStore[3]');
  CheckNear(2.0, buf[4], 0.0001, 'UnalignedStore[4]');
  CheckNear(3.0, buf[5], 0.0001, 'UnalignedStore[5]');
  CheckNear(4.0, buf[6], 0.0001, 'UnalignedStore[6]');
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
    CheckNear(vAligned.f[i], vUnaligned.f[i], 0.0, 'Parity[' + IntToStr(i) + ']');
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
      CheckNear(Single(offset + i), v.f[i], 0.0001, 'Offset' + IntToStr(offset) + '[' + IntToStr(i) + ']');
  end;
end;


end.