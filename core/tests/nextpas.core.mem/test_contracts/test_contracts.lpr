program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.intf,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base;

type
  TByteArray = array[0..5] of Byte;
  TWordArray = array[0..3] of Word;
  TDWordArray = array[0..2] of UInt32;
  TQWordArray = array[0..1] of UInt64;

var
  T: TTestRunner;
  GGetMemCalls: Integer = 0;
  GAllocMemCalls: Integer = 0;
  GReallocMemCalls: Integer = 0;
  GFreeMemCalls: Integer = 0;

procedure ResetAllocatorCounters;
begin
  GGetMemCalls := 0;
  GAllocMemCalls := 0;
  GReallocMemCalls := 0;
  GFreeMemCalls := 0;
end;

function CallbackGetMem(aSize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  Result := System.GetMem(aSize);
end;

function CallbackAllocMem(aSize: SizeUInt): Pointer;
begin
  Inc(GAllocMemCalls);
  Result := System.AllocMem(aSize);
end;

function CallbackReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Inc(GReallocMemCalls);
  Result := System.ReallocMem(aDst, aSize);
end;

procedure CallbackFreeMem(aDst: Pointer);
begin
  Inc(GFreeMemCalls);
  System.FreeMem(aDst);
end;

procedure TestCallbackAllocatorCompatibilityMethods;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem);

  Check(LAllocator <> nil, 'callback allocator should be created');
  Check(LAllocator.GetMem(0) = nil, 'GetMem(0) should return nil');
  Check(LAllocator.AllocMem(0) = nil, 'AllocMem(0) should return nil');

  LPtr := LAllocator.ReallocMem(nil, 16);
  Check(LPtr <> nil, 'ReallocMem(nil, size) should allocate');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'ReallocMem(nil, size) should route through GetMem');
  CheckEqual(Int64(0), Int64(GReallocMemCalls), 'ReallocMem(nil, size) should not call realloc callback');

  PByte(LPtr)^ := $5A;
  LPtr := LAllocator.ReallocMem(LPtr, 32);
  Check(LPtr <> nil, 'ReallocMem(existing, size) should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'ReallocMem(existing, size) should call realloc callback');
  CheckEqual(Int64($5A), Int64(PByte(LPtr)^), 'ReallocMem should preserve the existing prefix');

  LPtr := LAllocator.ReallocMem(LPtr, 0);
  Check(LPtr = nil, 'ReallocMem(existing, 0) should free and return nil');
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'ReallocMem(existing, 0) should call free callback');

  LAllocator.FreeMem(nil);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'FreeMem(nil) should be a no-op');
end;

procedure TestCallbackAllocatorSupportsAllocateInterface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem) as nextpas.core.mem.intf.IAllocator;

  LPtr := LAllocator.Allocate(24);
  Check(LPtr <> nil, 'Allocate should delegate to the compatibility allocator');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'Allocate should route through GetMem');

  PByte(LPtr)^ := $33;
  LPtr := LAllocator.Reallocate(LPtr, 48);
  Check(LPtr <> nil, 'Reallocate should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'Reallocate should route through ReallocMem');
  CheckEqual(Int64($33), Int64(PByte(LPtr)^), 'Reallocate should preserve the prefix');

  LAllocator.Deallocate(LPtr);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'Deallocate should route through FreeMem');
end;

procedure TestRtlAllocatorZeroInitTraitsAndAlignedAlloc;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LTraits: nextpas.core.mem.allocator.base.TAllocatorTraits;
  LPtr: Pointer;
  I: Integer;
begin
  LAllocator := GetRtlAllocator;
  Check(LAllocator <> nil, 'RTL allocator should exist');

  LTraits := LAllocator.Traits;
  CheckEqual(True, LTraits.ZeroInitialized, 'RTL AllocMem should be zero initialized');
  CheckEqual(False, LTraits.SupportsAligned, 'RTL allocator should report non-native aligned support');
  CheckEqual(False, LTraits.HasMemSize, 'RTL allocator should not expose MemSize');

  LPtr := LAllocator.AllocMem(32);
  try
    for I := 0 to 31 do
      CheckEqual(Int64(0), Int64(PByte(LPtr)[I]), 'AllocMem should zero initialize each byte');
  finally
    LAllocator.FreeMem(LPtr);
  end;

  LPtr := LAllocator.AllocAligned(64, 32);
  try
    Check(LPtr <> nil, 'AllocAligned should return a pointer');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 32), 'AllocAligned should honor the requested alignment');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestMemUtilsNoOpAndOverlapContract;
var
  LBytes: TByteArray;
begin
  Copy(nil, nil, 0);
  CopyNonOverlap(nil, nil, 0);
  Fill8(nil, 0, $7F);
  Zero(nil, 0);

  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CheckEqual(False, IsOverlap(nil, 0, @LBytes[0], 4), 'nil block should not overlap');
  CheckEqual(False, IsOverlap(@LBytes[0], 2, @LBytes[2], 2), 'adjacent ranges should not overlap');
  CheckEqual(True, IsOverlap(@LBytes[0], 3, @LBytes[2], 3), 'intersecting ranges should overlap');
end;

procedure TestMemUtilsCopyUncheckedHandlesOverlap;
var
  LBytes: TByteArray;
begin
  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CopyUnChecked(@LBytes[0], @LBytes[1], 5);

  CheckEqual(Int64(1), Int64(LBytes[0]), 'copy overlap index 0');
  CheckEqual(Int64(1), Int64(LBytes[1]), 'copy overlap index 1');
  CheckEqual(Int64(2), Int64(LBytes[2]), 'copy overlap index 2');
  CheckEqual(Int64(3), Int64(LBytes[3]), 'copy overlap index 3');
  CheckEqual(Int64(4), Int64(LBytes[4]), 'copy overlap index 4');
  CheckEqual(Int64(5), Int64(LBytes[5]), 'copy overlap index 5');
end;

procedure TestMemUtilsFillAndZeroHelpers;
var
  LBytes: TByteArray;
  LWords: TWordArray;
  LDWords: TDWordArray;
  LQWords: TQWordArray;
  I: Integer;
begin
  Fill8(@LBytes[0], Length(LBytes), $AB);
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64($AB), Int64(LBytes[I]), 'Fill8 should write the requested byte');

  Fill16(@LWords[0], Length(LWords), $1234);
  for I := Low(LWords) to High(LWords) do
    CheckEqual(Int64($1234), Int64(LWords[I]), 'Fill16 should write the requested word');

  Fill32(@LDWords[0], Length(LDWords), $89ABCDEF);
  for I := Low(LDWords) to High(LDWords) do
    CheckEqual(Int64($89ABCDEF), Int64(LDWords[I]), 'Fill32 should write the requested dword');

  Fill64(@LQWords[0], Length(LQWords), $0123456789ABCDEF);
  for I := Low(LQWords) to High(LQWords) do
    CheckEqual(Int64($0123456789ABCDEF), Int64(LQWords[I]), 'Fill64 should write the requested qword');

  Zero(@LBytes[0], Length(LBytes));
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64(0), Int64(LBytes[I]), 'Zero should clear each byte');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.contracts');
  T.Run('callback allocator compatibility methods', @TestCallbackAllocatorCompatibilityMethods);
  T.Run('callback allocator supports allocate interface', @TestCallbackAllocatorSupportsAllocateInterface);
  T.Run('rtl allocator zero init traits and aligned alloc', @TestRtlAllocatorZeroInitTraitsAndAlignedAlloc);
  T.Run('mem.utils no-op and overlap contract', @TestMemUtilsNoOpAndOverlapContract);
  T.Run('mem.utils copy unchecked handles overlap', @TestMemUtilsCopyUncheckedHandlesOverlap);
  T.Run('mem.utils fill and zero helpers', @TestMemUtilsFillAndZeroHelpers);
  T.Summary;
end.
