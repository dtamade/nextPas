unit nextpas.core.simd.memutils.aliases.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, fpcunit, testregistry,
  nextpas.core.errors,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.memutils;

type
  TTestProc = reference to procedure;

  // Aligned 内存工具测试（memutils）
  TTestCase_Memutils = class(TTestCase)
  private
    procedure ExpectArgumentError(const AName: string; const AProc: TTestProc);
    procedure ExpectOutOfMemory(const AName: string; const AProc: TTestProc);
  published
    procedure Test_AlignedAlloc_AlignedAndWritable;
    procedure Test_AlignedAlloc_64ByteAlignedAndWritable;
    procedure Test_AlignedAlloc_InvalidAlignment_FailClose;
    procedure Test_AlignedAlloc_ZeroSize_ReturnsNil;
    procedure Test_TAlignedArray_64ByteAligned;
    procedure Test_TAlignedArray_InvalidAlignment_FailClose;
    procedure Test_SimdAlloc_Sa64_64ByteAlignedAndWritable;
    procedure Test_SimdAlloc_ZeroSizeAndNilFree_Semantics;
    procedure Test_SimdAlloc_SizeOverflow_FailClose;
    procedure Test_SimdRealloc_SizeOverflow_FailClose;
    procedure Test_AlignedRealloc_Grow_PreservesPrefix;
    procedure Test_AlignedRealloc_Shrink_PreservesPrefix;
    procedure Test_AlignedRealloc_NilAndZero_Semantics;
    procedure Test_AlignedRealloc_InvalidAlignment_FailClose;
    procedure Test_AlignmentUtilities_InvalidAlignment_FailClose;
    procedure Test_AlignUp_Overflow_FailClose;
    procedure Test_AlignUpSize_Overflow_FailClose;
    procedure Test_AlignedMemOps_InvalidAlignment_FailClose;
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

procedure TTestCase_Memutils.ExpectArgumentError(const AName: string; const AProc: TTestProc);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc();
  except
    on EArgumentError do
      LRaised := True;
  end;
  AssertTrue(AName + ' should raise EArgumentError', LRaised);
end;

procedure TTestCase_Memutils.ExpectOutOfMemory(const AName: string; const AProc: TTestProc);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc();
  except
    on EOutOfMemory do
      LRaised := True;
  end;
  AssertTrue(AName + ' should raise EOutOfMemory', LRaised);
end;

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

procedure TTestCase_Memutils.Test_AlignedAlloc_64ByteAlignedAndWritable;
var
  LPtr: PByte;
  LIndex: Integer;
begin
  LPtr := AlignedAlloc(256, SIMD_ALIGN_64);
  try
    AssertTrue('AlignedAlloc should return non-nil', LPtr <> nil);
    AssertTrue('Pointer should be 64-byte aligned for AVX-512 storage',
      IsAligned(LPtr, SIMD_ALIGN_64));
    for LIndex := 0 to 255 do
      LPtr[LIndex] := Byte((LIndex * 3) and $FF);
    for LIndex := 0 to 255 do
      AssertEquals('Written 64-byte aligned data must round-trip',
        Byte((LIndex * 3) and $FF), LPtr[LIndex]);
  finally
    AlignedFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_AlignedAlloc_InvalidAlignment_FailClose;
begin
  ExpectArgumentError('AlignedAlloc alignment=0',
    procedure
    begin
      AlignedAlloc(16, 0);
    end);
  ExpectArgumentError('AlignedAlloc alignment=24',
    procedure
    begin
      AlignedAlloc(16, 24);
    end);
  ExpectArgumentError('AlignedAlloc alignment below pointer size',
    procedure
    begin
      AlignedAlloc(16, SizeOf(Pointer) shr 1);
    end);
end;

procedure TTestCase_Memutils.Test_AlignedAlloc_ZeroSize_ReturnsNil;
begin
  AssertTrue('AlignedAlloc(0, valid alignment) should return nil',
    AlignedAlloc(0, SIMD_ALIGN_16) = nil);
end;

procedure TTestCase_Memutils.Test_TAlignedArray_64ByteAligned;
type
  TByteAlignedArray = specialize TAlignedArray<Byte>;
var
  LArray: TByteAlignedArray;
  LIndex: Integer;
begin
  LArray := TByteAlignedArray.Create(128, SIMD_ALIGN_64);
  try
    AssertTrue('TAlignedArray should own non-nil storage', LArray.Data <> nil);
    AssertEquals('TAlignedArray should record requested 64-byte alignment',
      SIMD_ALIGN_64, LArray.Alignment);
    AssertTrue('TAlignedArray data should be 64-byte aligned',
      IsAligned(LArray.Data, SIMD_ALIGN_64));
    for LIndex := 0 to 127 do
      LArray[LIndex] := Byte((LIndex + 17) and $FF);
    for LIndex := 0 to 127 do
      AssertEquals('TAlignedArray 64-byte data must round-trip',
        Byte((LIndex + 17) and $FF), LArray[LIndex]);
  finally
    LArray.Free;
  end;
end;

procedure TTestCase_Memutils.Test_TAlignedArray_InvalidAlignment_FailClose;
type
  TByteAlignedArray = specialize TAlignedArray<Byte>;
begin
  ExpectArgumentError('TAlignedArray.Create alignment=0',
    procedure
    begin
      TByteAlignedArray.Create(4, 0);
    end);
  ExpectArgumentError('TAlignedArray.FromPointer alignment=24',
    procedure
    var
      LStorage: array[0..15] of Byte;
    begin
      TByteAlignedArray.FromPointer(@LStorage[0], Length(LStorage), 24);
    end);
end;

procedure TTestCase_Memutils.Test_SimdAlloc_Sa64_64ByteAlignedAndWritable;
var
  LPtr: PByte;
  LIndex: Integer;
begin
  LPtr := PByte(SimdAlloc(256, sa64));
  try
    AssertTrue('SimdAlloc(sa64) should return non-nil', LPtr <> nil);
    AssertTrue('SimdAlloc(sa64) should return 64-byte aligned storage',
      IsAligned(LPtr, SIMD_ALIGN_64));
    for LIndex := 0 to 255 do
      LPtr[LIndex] := Byte((255 - LIndex) and $FF);
    for LIndex := 0 to 255 do
      AssertEquals('SimdAlloc(sa64) data must round-trip',
        Byte((255 - LIndex) and $FF), LPtr[LIndex]);
  finally
    SimdFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_SimdAlloc_ZeroSizeAndNilFree_Semantics;
begin
  AssertTrue('SimdAlloc(0) should return nil', SimdAlloc(0, sa16) = nil);
  AssertTrue('SimdRealloc(nil, 0) should return nil', SimdRealloc(nil, 0, sa64) = nil);
  SimdFree(nil);
end;

procedure TTestCase_Memutils.Test_SimdAlloc_SizeOverflow_FailClose;
begin
  ExpectOutOfMemory('SimdAlloc(saAuto) size overflow',
    procedure
    begin
      SimdAlloc(High(SizeUInt), saAuto);
    end);
  ExpectOutOfMemory('SimdAlloc(sa16) size overflow',
    procedure
    begin
      SimdAlloc(High(SizeUInt), sa16);
    end);
  ExpectOutOfMemory('SimdAlloc(sa32) size overflow',
    procedure
    begin
      SimdAlloc(High(SizeUInt), sa32);
    end);
  ExpectOutOfMemory('SimdAlloc(sa64) size overflow',
    procedure
    begin
      SimdAlloc(High(SizeUInt), sa64);
    end);
end;

procedure TTestCase_Memutils.Test_SimdRealloc_SizeOverflow_FailClose;
  procedure ExpectOverflowPreservesPointer(const AName: string; const AAlignment: TSimdAlignment);
  var
    LPtr, LResultPtr: PByte;
    LRaised: Boolean;
  begin
    LPtr := PByte(SimdAlloc(16, sa16));
    LResultPtr := nil;
    try
      LPtr[0] := 77;
      LRaised := False;
      try
        LResultPtr := PByte(SimdRealloc(LPtr, High(SizeUInt), AAlignment));
      except
        on EOutOfMemory do
          LRaised := True;
      end;
      if not LRaised then
      begin
        if LResultPtr <> nil then
          SimdFree(LResultPtr);
        LPtr := nil; // Legacy behavior may already have freed the pointer.
      end;
      AssertTrue(AName + ' should raise EOutOfMemory', LRaised);
      AssertEquals(AName + ' must not free original pointer first', Byte(77), LPtr[0]);
    finally
      if LPtr <> nil then
        SimdFree(LPtr);
    end;
  end;
begin
  ExpectOverflowPreservesPointer('SimdRealloc(saAuto) size overflow', saAuto);
  ExpectOverflowPreservesPointer('SimdRealloc(sa16) size overflow', sa16);
  ExpectOverflowPreservesPointer('SimdRealloc(sa32) size overflow', sa32);
  ExpectOverflowPreservesPointer('SimdRealloc(sa64) size overflow', sa64);
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

procedure TTestCase_Memutils.Test_AlignedRealloc_InvalidAlignment_FailClose;
var
  LPtr: PByte;
  LRaised: Boolean;
begin
  ExpectArgumentError('AlignedRealloc(nil, N, alignment=0)',
    procedure
    begin
      AlignedRealloc(nil, 16, 0);
    end);

  LPtr := AlignedAlloc(16, SIMD_ALIGN_16);
  try
    LPtr[0] := 123;
    LRaised := False;
    try
      AlignedRealloc(LPtr, 0, 24);
    except
      on EArgumentError do
        LRaised := True;
    end;
    if not LRaised then
      LPtr := nil; // Legacy behavior may already have freed the pointer.
    AssertTrue('AlignedRealloc(p, 0, invalid alignment) should raise EArgumentError', LRaised);
    AssertEquals('Invalid realloc must not free original pointer first', Byte(123), LPtr[0]);
  finally
    if LPtr <> nil then
      AlignedFree(LPtr);
  end;
end;

procedure TTestCase_Memutils.Test_AlignmentUtilities_InvalidAlignment_FailClose;
var
  LStorage: array[0..31] of Byte;
begin
  ExpectArgumentError('IsAligned alignment=0',
    procedure
    begin
      IsAligned(@LStorage[0], 0);
    end);
  ExpectArgumentError('AlignUp alignment=24',
    procedure
    begin
      AlignUp(@LStorage[0], 24);
    end);
  ExpectArgumentError('AlignUpSize alignment below pointer size',
    procedure
    begin
      AlignUpSize(16, SizeOf(Pointer) shr 1);
    end);
end;

procedure TTestCase_Memutils.Test_AlignUp_Overflow_FailClose;
begin
  ExpectOutOfMemory('AlignUp pointer overflow',
    procedure
    begin
      AlignUp(Pointer(High(NativeUInt)), SIMD_ALIGN_16);
    end);
end;

procedure TTestCase_Memutils.Test_AlignUpSize_Overflow_FailClose;
var
  LSize: NativeUInt;
begin
  LSize := High(NativeUInt);
  ExpectOutOfMemory('AlignUpSize overflow',
    procedure
    begin
      AlignUpSize(LSize, SIMD_ALIGN_16);
    end);
end;

procedure TTestCase_Memutils.Test_AlignedMemOps_InvalidAlignment_FailClose;
var
  LSrc: array[0..15] of Byte;
  LDst: array[0..15] of Byte;
begin
  FillChar(LSrc, SizeOf(LSrc), 42);
  FillChar(LDst, SizeOf(LDst), 0);

  ExpectArgumentError('AlignedMemCopy alignment=0',
    procedure
    begin
      AlignedMemCopy(@LSrc[0], @LDst[0], SizeOf(LSrc), 0);
    end);
  ExpectArgumentError('AlignedMemFill alignment=24',
    procedure
    begin
      AlignedMemFill(@LDst[0], SizeOf(LDst), 17, 24);
    end);
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
