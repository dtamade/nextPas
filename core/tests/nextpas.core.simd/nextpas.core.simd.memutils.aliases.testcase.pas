unit nextpas.core.simd.memutils.aliases.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.memutils;

type
  // Aligned 内存工具测试（memutils）
  TTestCase_Memutils = class(TTestCase)
  published
    procedure Test_AlignedAlloc_AlignedAndWritable;
    procedure Test_AlignedRealloc_Grow_PreservesPrefix;
    procedure Test_AlignedRealloc_Shrink_PreservesPrefix;
    procedure Test_AlignedRealloc_NilAndZero_Semantics;
  end;

  // Rust 风格类型别名测试
  TTestCase_RustStyleAliases = class(TTestCase)
  published
    procedure Test_f32x4_Alias_SameSize;
    procedure Test_f32x4_Alias_Usable;
    procedure Test_f64x2_Alias_SameSize;
    procedure Test_f64x2_Alias_Usable;

    procedure Test_i32x4_Alias_SameSize;
    procedure Test_i32x4_Alias_Usable;
    procedure Test_i64x2_Alias_SameSize;
    procedure Test_i16x8_Alias_SameSize;
    procedure Test_i8x16_Alias_SameSize;

    procedure Test_u32x4_Alias_SameSize;
    procedure Test_u64x2_Alias_SameSize;
    procedure Test_u16x8_Alias_SameSize;
    procedure Test_u8x16_Alias_SameSize;

    procedure Test_f32x8_Alias_SameSize;
    procedure Test_f64x4_Alias_SameSize;
    procedure Test_i32x8_Alias_SameSize;

    procedure Test_f32x16_Alias_SameSize;
    procedure Test_f64x8_Alias_SameSize;
    procedure Test_i32x16_Alias_SameSize;

    procedure Test_Alias_InteropWithOriginal;
  end;

implementation

{ TTestCase_Memutils }

procedure TTestCase_Memutils.Test_AlignedAlloc_AlignedAndWritable;
var
  LPtr: PByte;
  LIndex: Integer;
begin
  LPtr := AlignedAlloc(128, SIMD_ALIGN_32);
  try
    AssertTrue('AlignedAlloc should return non-nil', LPtr <> nil);
    AssertTrue('Pointer should be 32-byte aligned', IsAligned(LPtr, SIMD_ALIGN_32));
    // Write and read back a simple pattern
    for LIndex := 0 to 127 do
      LPtr[LIndex] := Byte(LIndex and $FF);
    for LIndex := 0 to 127 do
      AssertEquals('Written data must round-trip', Byte(LIndex and $FF), LPtr[LIndex]);
  finally
    AlignedFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_AlignedRealloc_Grow_PreservesPrefix;
var
  LPtr, LReallocPtr: PByte;
  LIndex: Integer;
begin
  LPtr := nil;
  LReallocPtr := nil;
  // Start with a small buffer and grow it; existing bytes must be preserved
  LPtr := AlignedAlloc(16, SIMD_ALIGN_32);
  try
    for LIndex := 0 to 15 do
      LPtr[LIndex] := Byte(LIndex + 10);
    LReallocPtr := AlignedRealloc(LPtr, 64, SIMD_ALIGN_32);
    // After realloc, p should no longer be used
    LPtr := nil;
    AssertTrue('Realloc result should be non-nil', LReallocPtr <> nil);
    AssertTrue('Realloc result should be 32-byte aligned', IsAligned(LReallocPtr, SIMD_ALIGN_32));
    for LIndex := 0 to 15 do
      AssertEquals('Prefix bytes must be preserved after grow', Byte(LIndex + 10), LReallocPtr[LIndex]);
  finally
    if LReallocPtr <> nil then
      AlignedFree(LReallocPtr);
    if LPtr <> nil then
      AlignedFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_AlignedRealloc_Shrink_PreservesPrefix;
var
  LPtr, LReallocPtr: PByte;
  LIndex: Integer;
begin
  LPtr := nil;
  LReallocPtr := nil;
  // Start with a larger buffer and shrink it; leading bytes must be preserved
  LPtr := AlignedAlloc(64, SIMD_ALIGN_32);
  try
    for LIndex := 0 to 63 do
      LPtr[LIndex] := Byte(255 - LIndex);
    LReallocPtr := AlignedRealloc(LPtr, 16, SIMD_ALIGN_32);
    LPtr := nil;
    AssertTrue('Realloc result should be non-nil', LReallocPtr <> nil);
    AssertTrue('Realloc result should be 32-byte aligned', IsAligned(LReallocPtr, SIMD_ALIGN_32));
    for LIndex := 0 to 15 do
      AssertEquals('Prefix bytes must be preserved after shrink', Byte(255 - LIndex), LReallocPtr[LIndex]);
  finally
    if LReallocPtr <> nil then
      AlignedFree(LReallocPtr);
    if LPtr <> nil then
      AlignedFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_AlignedRealloc_NilAndZero_Semantics;
var
  LPtr, LResultPtr: PByte;
begin
  LPtr := nil;
  LResultPtr := nil;
  // realloc(nil, N) behaves like malloc(N)
  LPtr := AlignedRealloc(nil, 32, SIMD_ALIGN_16);
  try
    AssertTrue('Realloc(nil, N) should allocate', LPtr <> nil);
    AssertTrue('Allocated pointer should be aligned', IsAligned(LPtr, SIMD_ALIGN_16));

    // realloc(p, 0) behaves like free(p) and returns nil
    LResultPtr := AlignedRealloc(LPtr, 0, SIMD_ALIGN_16);
    LPtr := nil;
    AssertTrue('Realloc(p, 0) should return nil', LResultPtr = nil);
  finally
    if LResultPtr <> nil then
      AlignedFree(LResultPtr);
    if LPtr <> nil then
      AlignedFree(LPtr);
  end;
end;

{ TTestCase_RustStyleAliases }

procedure TTestCase_RustStyleAliases.Test_f32x4_Alias_SameSize;
begin
  AssertEquals('f32x4 should have same size as TVecF32x4', SizeOf(TVecF32x4), SizeOf(f32x4));
  AssertEquals('f32x4 size should be 16 bytes', 16, SizeOf(f32x4));
end;

procedure TTestCase_RustStyleAliases.Test_f32x4_Alias_Usable;
var
  LVec: f32x4;
  LIndex: Integer;
begin
  // 测试别名可以正常使用
  LVec.f[0] := 1.0;
  LVec.f[1] := 2.0;
  LVec.f[2] := 3.0;
  LVec.f[3] := 4.0;

  for LIndex := 0 to 3 do
    AssertEquals('Element ' + IntToStr(LIndex), Single(LIndex + 1), LVec.f[LIndex], 0.0001);
end;

procedure TTestCase_RustStyleAliases.Test_f64x2_Alias_SameSize;
begin
  AssertEquals('f64x2 should have same size as TVecF64x2', SizeOf(TVecF64x2), SizeOf(f64x2));
  AssertEquals('f64x2 size should be 16 bytes', 16, SizeOf(f64x2));
end;

procedure TTestCase_RustStyleAliases.Test_f64x2_Alias_Usable;
var
  LVec: f64x2;
begin
  LVec.d[0] := 1.5;
  LVec.d[1] := 2.5;

  AssertEquals('Element 0', 1.5, LVec.d[0], 0.0001);
  AssertEquals('Element 1', 2.5, LVec.d[1], 0.0001);
end;

procedure TTestCase_RustStyleAliases.Test_i32x4_Alias_SameSize;
begin
  AssertEquals('i32x4 should have same size as TVecI32x4', SizeOf(TVecI32x4), SizeOf(i32x4));
  AssertEquals('i32x4 size should be 16 bytes', 16, SizeOf(i32x4));
end;

procedure TTestCase_RustStyleAliases.Test_i32x4_Alias_Usable;
var
  LVec: i32x4;
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    LVec.i[LIndex] := LIndex * 10;

  for LIndex := 0 to 3 do
    AssertEquals('Element ' + IntToStr(LIndex), LIndex * 10, LVec.i[LIndex]);
end;

procedure TTestCase_RustStyleAliases.Test_i64x2_Alias_SameSize;
begin
  AssertEquals('i64x2 should have same size as TVecI64x2', SizeOf(TVecI64x2), SizeOf(i64x2));
  AssertEquals('i64x2 size should be 16 bytes', 16, SizeOf(i64x2));
end;

procedure TTestCase_RustStyleAliases.Test_i16x8_Alias_SameSize;
begin
  AssertEquals('i16x8 should have same size as TVecI16x8', SizeOf(TVecI16x8), SizeOf(i16x8));
  AssertEquals('i16x8 size should be 16 bytes', 16, SizeOf(i16x8));
end;

procedure TTestCase_RustStyleAliases.Test_i8x16_Alias_SameSize;
begin
  AssertEquals('i8x16 should have same size as TVecI8x16', SizeOf(TVecI8x16), SizeOf(i8x16));
  AssertEquals('i8x16 size should be 16 bytes', 16, SizeOf(i8x16));
end;

procedure TTestCase_RustStyleAliases.Test_u32x4_Alias_SameSize;
begin
  AssertEquals('u32x4 should have same size as TVecU32x4', SizeOf(TVecU32x4), SizeOf(u32x4));
  AssertEquals('u32x4 size should be 16 bytes', 16, SizeOf(u32x4));
end;

procedure TTestCase_RustStyleAliases.Test_u64x2_Alias_SameSize;
begin
  AssertEquals('u64x2 should have same size as TVecU64x2', SizeOf(TVecU64x2), SizeOf(u64x2));
  AssertEquals('u64x2 size should be 16 bytes', 16, SizeOf(u64x2));
end;

procedure TTestCase_RustStyleAliases.Test_u16x8_Alias_SameSize;
begin
  AssertEquals('u16x8 should have same size as TVecU16x8', SizeOf(TVecU16x8), SizeOf(u16x8));
  AssertEquals('u16x8 size should be 16 bytes', 16, SizeOf(u16x8));
end;

procedure TTestCase_RustStyleAliases.Test_u8x16_Alias_SameSize;
begin
  AssertEquals('u8x16 should have same size as TVecU8x16', SizeOf(TVecU8x16), SizeOf(u8x16));
  AssertEquals('u8x16 size should be 16 bytes', 16, SizeOf(u8x16));
end;

procedure TTestCase_RustStyleAliases.Test_f32x8_Alias_SameSize;
begin
  AssertEquals('f32x8 should have same size as TVecF32x8', SizeOf(TVecF32x8), SizeOf(f32x8));
  AssertEquals('f32x8 size should be 32 bytes', 32, SizeOf(f32x8));
end;

procedure TTestCase_RustStyleAliases.Test_f64x4_Alias_SameSize;
begin
  AssertEquals('f64x4 should have same size as TVecF64x4', SizeOf(TVecF64x4), SizeOf(f64x4));
  AssertEquals('f64x4 size should be 32 bytes', 32, SizeOf(f64x4));
end;

procedure TTestCase_RustStyleAliases.Test_i32x8_Alias_SameSize;
begin
  AssertEquals('i32x8 should have same size as TVecI32x8', SizeOf(TVecI32x8), SizeOf(i32x8));
  AssertEquals('i32x8 size should be 32 bytes', 32, SizeOf(i32x8));
end;

procedure TTestCase_RustStyleAliases.Test_f32x16_Alias_SameSize;
begin
  AssertEquals('f32x16 should have same size as TVecF32x16', SizeOf(TVecF32x16), SizeOf(f32x16));
  AssertEquals('f32x16 size should be 64 bytes', 64, SizeOf(f32x16));
end;

procedure TTestCase_RustStyleAliases.Test_f64x8_Alias_SameSize;
begin
  AssertEquals('f64x8 should have same size as TVecF64x8', SizeOf(TVecF64x8), SizeOf(f64x8));
  AssertEquals('f64x8 size should be 64 bytes', 64, SizeOf(f64x8));
end;

procedure TTestCase_RustStyleAliases.Test_i32x16_Alias_SameSize;
begin
  AssertEquals('i32x16 should have same size as TVecI32x16', SizeOf(TVecI32x16), SizeOf(i32x16));
  AssertEquals('i32x16 size should be 64 bytes', 64, SizeOf(i32x16));
end;

procedure TTestCase_RustStyleAliases.Test_Alias_InteropWithOriginal;
var
  LOriginal: TVecF32x4;
  LAlias: f32x4;
  LIndex: Integer;
begin
  // 测试别名和原始类型可互用
  for LIndex := 0 to 3 do
    LOriginal.f[LIndex] := LIndex + 1;

  LAlias := LOriginal;  // 直接赋值

  for LIndex := 0 to 3 do
    AssertEquals('Element ' + IntToStr(LIndex), LOriginal.f[LIndex], LAlias.f[LIndex], 0.0001);

  // 反向赋值
  for LIndex := 0 to 3 do
    LAlias.f[LIndex] := (LIndex + 1) * 10;

  LOriginal := LAlias;

  for LIndex := 0 to 3 do
    AssertEquals('Reverse element ' + IntToStr(LIndex), LAlias.f[LIndex], LOriginal.f[LIndex], 0.0001);
end;

initialization
  RegisterTest(TTestCase_Memutils);
  RegisterTest(TTestCase_RustStyleAliases);

end.
