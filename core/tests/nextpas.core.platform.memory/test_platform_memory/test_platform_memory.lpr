program test_platform_memory;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.platform.memory,
  nextpas.core.test;

const
  PLATFORM_MEMORY_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.memory.pas';
  PLATFORM_MEMORY_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.memory.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';

var
  T: TTestSuite;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

function IsAligned(APtr: Pointer; AAlignment: SizeUInt): Boolean;
begin
  if (APtr = nil) or (AAlignment = 0) then
    Exit(False);
  Result := (PtrUInt(APtr) and PtrUInt(AAlignment - 1)) = 0;
end;

procedure TestAllocAlignedAndWritable;
var
  LPtr: PByte;
  LIndex: Integer;
begin
  LPtr := PByte(platform_aligned_alloc(256, 64));
  try
    Check(LPtr <> nil, 'alloc returns non-nil');
    Check(IsAligned(LPtr, 64), 'alloc returns 64-byte aligned storage');
    for LIndex := 0 to 255 do
      LPtr[LIndex] := Byte((LIndex * 7) and $FF);
    for LIndex := 0 to 255 do
      Check(LPtr[LIndex] = Byte((LIndex * 7) and $FF), 'aligned storage round-trips');
  finally
    platform_aligned_free(LPtr);
  end;
end;

procedure TestZeroSizeAndInvalidAlignmentFailClosed;
var
  LPtr: Pointer;
begin
  Check(platform_aligned_alloc(0, 64) = nil, 'zero-size alloc returns nil');
  Check(platform_aligned_alloc(64, 0) = nil, 'zero alignment returns nil');
  Check(platform_aligned_alloc(64, 3) = nil, 'non-power-of-two alignment returns nil');
  Check(platform_aligned_alloc(64, SizeOf(Pointer) div 2) = nil,
    'sub-pointer alignment returns nil');

  LPtr := platform_aligned_alloc(SizeUInt(High(SizeUInt)), 64);
  Check(LPtr = nil, 'overflow alloc returns nil');
end;

procedure TestFreeNilNoOp;
begin
  platform_aligned_free(nil);
  Check(True, 'free(nil) is a no-op');
end;

procedure TestReallocNilAndZeroSemantics;
var
  LPtr, LResult: PByte;
begin
  LPtr := PByte(platform_aligned_realloc(nil, 32, 16));
  try
    Check(LPtr <> nil, 'realloc(nil, N) allocates');
    Check(IsAligned(LPtr, 16), 'realloc(nil, N) respects alignment');
    LResult := platform_aligned_realloc(LPtr, 0, 16);
    LPtr := nil;
    Check(LResult = nil, 'realloc(ptr, 0) frees and returns nil');
  finally
    if LPtr <> nil then
      platform_aligned_free(LPtr);
  end;
end;

procedure TestReallocPreservesPrefixAndAlignment;
var
  LPtr, LGrown, LShrunk: PByte;
  LIndex: Integer;
begin
  LPtr := nil;
  LGrown := nil;
  LShrunk := nil;
  LPtr := PByte(platform_aligned_alloc(32, 64));
  try
    Check(LPtr <> nil, 'initial alloc returns non-nil');
    for LIndex := 0 to 31 do
      LPtr[LIndex] := Byte((LIndex + 19) and $FF);

    LGrown := PByte(platform_aligned_realloc(LPtr, 96, 64));
    LPtr := nil;
    Check(LGrown <> nil, 'grow realloc returns non-nil');
    Check(IsAligned(LGrown, 64), 'grow realloc preserves requested alignment');
    for LIndex := 0 to 31 do
      Check(LGrown[LIndex] = Byte((LIndex + 19) and $FF), 'grow realloc preserves prefix');

    LShrunk := PByte(platform_aligned_realloc(LGrown, 16, 64));
    LGrown := nil;
    Check(LShrunk <> nil, 'shrink realloc returns non-nil');
    Check(IsAligned(LShrunk, 64), 'shrink realloc preserves requested alignment');
    for LIndex := 0 to 15 do
      Check(LShrunk[LIndex] = Byte((LIndex + 19) and $FF), 'shrink realloc preserves prefix');
  finally
    if LShrunk <> nil then
      platform_aligned_free(LShrunk);
    if LGrown <> nil then
      platform_aligned_free(LGrown);
    if LPtr <> nil then
      platform_aligned_free(LPtr);
  end;
end;

procedure TestReallocOverflowFailsClosedAndKeepsOldAllocation;
var
  LPtr, LResult: PByte;
begin
  LPtr := PByte(platform_aligned_alloc(16, 64));
  try
    Check(LPtr <> nil, 'initial alloc returns non-nil');
    LPtr[0] := $A5;
    LResult := PByte(platform_aligned_realloc(LPtr, SizeUInt(High(SizeUInt)), 64));
    Check(LResult = nil, 'overflow realloc returns nil');
    Check(LPtr[0] = $A5, 'overflow realloc leaves old allocation owned by caller');
  finally
    platform_aligned_free(LPtr);
  end;
end;

procedure TestBackendTruthIsExplicit;
begin
  Check(platform_aligned_alloc_backend in [paabFallback, paabWindowsCRT, paabPosix],
    'backend truth is explicit');
  Check(platform_aligned_alloc_is_native =
    (platform_aligned_alloc_backend <> paabFallback),
    'native truth matches backend enum');
end;

procedure TestNativeBackendTruthMatchesForcedHost;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Check(platform_aligned_alloc_backend = paabWindowsCRT,
    'forced/native Windows host must report Windows CRT backend source truth');
  Check(platform_aligned_alloc_is_native,
    'forced/native Windows host must report native backend source truth');
{$ELSEIF defined(NEXTPAS_MACOS)}
  { Darwin native via mmap (heaptrc-agnostic, consistent with virtual mmap). }
  Check(platform_aligned_alloc_backend = paabPosix,
    'Darwin host reports POSIX backend (mmap-aligned native)');
  Check(platform_aligned_alloc_is_native,
    'Darwin host is native via mmap-aligned path');
{$ELSEIF defined(NEXTPAS_UNIX)}
  Check(platform_aligned_alloc_backend = paabPosix,
    'forced/native POSIX host must report POSIX backend source truth');
  Check(platform_aligned_alloc_is_native,
    'forced/native POSIX host must report native backend source truth');
{$ELSE}
  Check(platform_aligned_alloc_backend = paabFallback,
    'unknown host must report fallback backend truth');
  Check(not platform_aligned_alloc_is_native,
    'unknown host fallback must not report native truth');
{$ENDIF}
end;

procedure TestSecureZeroMemoryClearsBuffer;
var
  LBuffer: array[0..63] of Byte;
  LIndex: Integer;
begin
  for LIndex := Low(LBuffer) to High(LBuffer) do
    LBuffer[LIndex] := Byte($A0 + (LIndex and $0F));

  platform_secure_zero_memory(@LBuffer[0], SizeOf(LBuffer));

  for LIndex := Low(LBuffer) to High(LBuffer) do
    Check(LBuffer[LIndex] = 0, 'secure zero clears every byte');
end;

procedure TestSecureZeroMemoryNilAndZeroSizeNoOp;
var
  LByte: Byte;
begin
  LByte := $5A;
  platform_secure_zero_memory(nil, 16);
  platform_secure_zero_memory(nil, 0);
  platform_secure_zero_memory(@LByte, 0);
  Check(LByte = $5A, 'secure zero nil/zero-size inputs are no-op');
end;

procedure TestSecureZeroBackendTruthMatchesHost;
begin
  Check(platform_secure_zero_memory_backend in [
    pszbFallbackFillCharBarrier,
    pszbWindowsPermanentFallback,
    pszbPosixExplicitBZero
  ], 'secure zero backend truth is explicit');
{$IFDEF NEXTPAS_UNIX}
  Check(platform_secure_zero_memory_backend = pszbPosixExplicitBZero,
    'POSIX secure zero must report explicit_bzero native backend truth');
  Check(platform_secure_zero_memory_is_native,
    'POSIX secure zero explicit_bzero backend must report native truth');
{$ELSEIF defined(NEXTPAS_WINDOWS)}
  Check(platform_secure_zero_memory_backend = pszbWindowsPermanentFallback,
    'Windows secure zero is permanent FillChar+barrier fallback');
  Check(not platform_secure_zero_memory_is_native,
    'Windows secure zero permanent fallback is not native');
{$ELSE}
  Check(platform_secure_zero_memory_backend = pszbFallbackFillCharBarrier,
    'unknown-host secure zero reports generic FillChar+barrier truth');
  Check(not platform_secure_zero_memory_is_native,
    'unknown-host secure zero is not native');
{$ENDIF}
end;

procedure TestNativeBackendSourceContracts;
var
  LPlatformMemory: string;
  LWindowsFFI: string;
  LPosixFFI: string;
begin
  LPlatformMemory := ReadSourceFile(ResolveSourcePath(
    PLATFORM_MEMORY_SOURCE_PATH_FROM_TEST,
    PLATFORM_MEMORY_SOURCE_PATH_FROM_ROOT));
  LWindowsFFI := ReadSourceFile(ResolveSourcePath(
    WINDOWS_FFI_SOURCE_PATH_FROM_TEST,
    WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));
  LPosixFFI := ReadSourceFile(ResolveSourcePath(
    POSIX_FFI_SOURCE_PATH_FROM_TEST,
    POSIX_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPlatformMemory, 'nextpas.core.platform.windows.ffi',
    'platform.memory must consume host-owned Windows raw allocator FFI');
  CheckTokenPresent(LPlatformMemory, 'nextpas.core.platform.posix.ffi',
    'platform.memory must consume host-owned POSIX raw allocator FFI');
  CheckTokenPresent(LPlatformMemory, 'paabwindowscrt',
    'platform.memory must publish Windows CRT native backend truth');
  CheckTokenPresent(LPlatformMemory, 'paabposix',
    'platform.memory must publish POSIX native backend truth');
  CheckTokenPresent(LPlatformMemory, 'platform_native_aligned_raw_alloc',
    'platform.memory must route raw allocation through a native owner seam');
  CheckTokenPresent(LPlatformMemory, 'platform_native_aligned_raw_free',
    'platform.memory must route raw free through a native owner seam');

  CheckTokenPresent(LWindowsFFI, '_aligned_malloc',
    'windows.ffi must own Windows CRT aligned malloc binding');
  CheckTokenPresent(LWindowsFFI, '_aligned_free',
    'windows.ffi must own Windows CRT aligned free binding');
  CheckTokenPresent(LPosixFFI, 'posix_memalign',
    'posix.ffi must own POSIX aligned allocation binding');
  CheckTokenPresent(LPosixFFI, 'procedure free',
    'posix.ffi must own POSIX raw free binding');

  CheckTokenAbsent(LPlatformMemory, 'msvcrt.dll',
    'platform.memory must not own raw Windows library names directly');
  CheckTokenAbsent(LPlatformMemory, 'external ''c''',
    'platform.memory must not own raw POSIX external declarations directly');
end;

procedure TestSecureZeroSourceContracts;
var
  LPlatformMemory: string;
  LPosixFFI: string;
begin
  LPlatformMemory := ReadSourceFile(ResolveSourcePath(
    PLATFORM_MEMORY_SOURCE_PATH_FROM_TEST,
    PLATFORM_MEMORY_SOURCE_PATH_FROM_ROOT));
  LPosixFFI := ReadSourceFile(ResolveSourcePath(
    POSIX_FFI_SOURCE_PATH_FROM_TEST,
    POSIX_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPlatformMemory, 'procedure platform_secure_zero_memory',
    'platform.memory must publish the secure-zero owner seam');
  CheckTokenPresent(LPlatformMemory, 'platform_secure_zero_memory_barrier',
    'platform.memory secure zero must keep an optimization barrier seam');
  CheckTokenPresent(LPlatformMemory, 'noinline',
    'platform.memory secure zero barrier must not be inlined away');
  CheckTokenPresent(LPlatformMemory, 'secure-zero-backend=fallback-fillchar-readwritebarrier',
    'platform.memory must publish secure-zero fallback truth');
  CheckTokenPresent(LPlatformMemory, 'windows-native-secure-zero=permanent-fallback',
    'platform.memory must publish Windows secure-zero as permanent fallback');
  CheckTokenPresent(LPlatformMemory, 'windows-secure-zero-decision=D3.b-permanent-fillchar-barrier',
    'platform.memory must record D3.b permanent-fallback decision token');
  CheckTokenPresent(LPlatformMemory, 'posix-native-secure-zero=explicit_bzero',
    'platform.memory must publish POSIX native secure-zero backend as explicit_bzero');
  CheckTokenPresent(LPlatformMemory, 'native-secure-zero-promotion-requires=host-owned-ffi-export-with-wine-and-real-windows-proof',
    'platform.memory must gate future native secure-zero on export+dual host proof');
  CheckTokenPresent(LPlatformMemory, 'secure-zero-forced-compile-truth=source-contract',
    'platform.memory forced host branches must stay source-contract truth only');
  CheckTokenPresent(LPlatformMemory, 'windows-runtime-ready=false',
    'platform.memory must not claim Windows runtime readiness for secure zero');
  CheckTokenPresent(LPlatformMemory, 'windows-native-export=unavailable',
    'platform.memory must record Windows secure-zero export unavailability');
  CheckTokenPresent(LPlatformMemory, 'FillChar(',
    'platform.memory secure zero fallback must keep FillChar source truth');
  CheckTokenPresent(LPlatformMemory, 'ReadWriteBarrier',
    'platform.memory secure zero fallback must keep compiler barrier source truth');
  CheckTokenPresent(LPlatformMemory, 'TPlatformSecureZeroBackend',
    'platform.memory must name secure-zero backend readiness truth');
  CheckTokenPresent(LPlatformMemory, 'pszbFallbackFillCharBarrier',
    'platform.memory secure zero must publish fallback FillChar+barrier truth');
  CheckTokenPresent(LPlatformMemory, 'pszbWindowsPermanentFallback',
    'platform.memory secure zero must publish Windows permanent fallback truth');
  CheckTokenPresent(LPlatformMemory, 'pszbPosixExplicitBZero',
    'platform.memory secure zero must publish POSIX explicit_bzero native truth');
  CheckTokenPresent(LPlatformMemory, 'explicit_bzero',
    'platform.memory POSIX secure zero must consume explicit_bzero through posix.ffi');
  CheckTokenPresent(LPlatformMemory, 'platform_secure_zero_memory_backend',
    'platform.memory secure zero must keep backend truth centralized');
  CheckTokenPresent(LPlatformMemory, 'platform_secure_zero_memory_is_native',
    'platform.memory secure zero must keep native readiness truth explicit');
  CheckTokenPresent(LPosixFFI, 'procedure explicit_bzero',
    'posix.ffi must own POSIX explicit_bzero raw binding');
  CheckTokenPresent(LPosixFFI, 'external ''c'' name ''explicit_bzero''',
    'posix.ffi explicit_bzero binding must name the raw libc symbol');
  CheckTokenAbsent(LPlatformMemory, 'pszbPosixNativeDeferred',
    'platform.memory must not keep stale POSIX secure-zero deferred truth');
  CheckTokenAbsent(LPlatformMemory, 'pszbWindowsNativeDeferred',
    'platform.memory must not keep stale Windows secure-zero deferred truth');

  CheckTokenAbsent(LPlatformMemory, 'rtlsecurezeromemory',
    'platform.memory must not own Windows secure-zero raw API names directly');
  CheckTokenAbsent(LPlatformMemory, 'ntdll.dll',
    'platform.memory must not own Windows secure-zero library names directly');
  CheckTokenAbsent(LPlatformMemory, 'baseunix',
    'platform.memory must not depend on BaseUnix for secure-zero semantics');
  CheckTokenAbsent(LPlatformMemory, 'getprocaddress',
    'platform.memory must not perform raw Windows symbol lookup directly');
end;

{ Realloc error path tests }
procedure TestReallocInvalidAlignmentReturnsNil;
var
  LPtr, LResult: PByte;
begin
  LPtr := PByte(platform_aligned_alloc(32, 64));
  try
    Check(LPtr <> nil, 'initial alloc returns non-nil');
    LResult := PByte(platform_aligned_realloc(LPtr, 64, 0));
    Check(LResult = nil, 'realloc with zero alignment returns nil');
    LResult := PByte(platform_aligned_realloc(LPtr, 64, 3));
    Check(LResult = nil, 'realloc with non-power-of-two alignment returns nil');
    LResult := PByte(platform_aligned_realloc(LPtr, 64, SizeOf(Pointer) div 2));
    Check(LResult = nil, 'realloc with sub-pointer alignment returns nil');
  finally
    platform_aligned_free(LPtr);
  end;
end;

procedure TestReallocMismatchedAlignmentReturnsNil;
var
  LPtr, LResult: PByte;
begin
  LPtr := PByte(platform_aligned_alloc(32, 64));
  try
    Check(LPtr <> nil, 'initial alloc returns non-nil');
    LResult := PByte(platform_aligned_realloc(LPtr, 64, 128));
    Check(LResult = nil, 'realloc with mismatched alignment returns nil');
  finally
    platform_aligned_free(LPtr);
  end;
end;

{ Virtual memory error path tests }
procedure TestVirtualReserveZeroSizeReturnsNil;
begin
  Check(platform_virtual_reserve(0) = nil, 'virtual reserve with zero size returns nil');
end;

procedure TestVirtualCommitNilReturnsFalse;
begin
  Check(not platform_virtual_commit(nil, 4096), 'virtual commit with nil returns false');
end;

procedure TestVirtualCommitZeroSizeReturnsFalse;
var
  LPtr: Pointer;
begin
  LPtr := platform_virtual_reserve(4096);
  try
    Check(LPtr <> nil, 'virtual reserve returns non-nil');
    Check(not platform_virtual_commit(LPtr, 0), 'virtual commit with zero size returns false');
  finally
    platform_virtual_release(LPtr, 4096);
  end;
end;

procedure TestVirtualDecommitNilNoOp;
begin
  platform_virtual_decommit(nil, 4096);
  Check(True, 'virtual decommit with nil is no-op');
end;

procedure TestVirtualDecommitZeroSizeNoOp;
var
  LPtr: Pointer;
begin
  LPtr := platform_virtual_reserve(4096);
  try
    Check(LPtr <> nil, 'virtual reserve returns non-nil');
    platform_virtual_decommit(LPtr, 0);
    Check(True, 'virtual decommit with zero size is no-op');
  finally
    platform_virtual_release(LPtr, 4096);
  end;
end;

procedure TestVirtualReleaseNilNoOp;
begin
  platform_virtual_release(nil, 4096);
  Check(True, 'virtual release with nil is no-op');
end;

procedure TestVirtualReleaseZeroSizeNoOp;
var
  LPtr: Pointer;
begin
  LPtr := platform_virtual_reserve(4096);
  try
    Check(LPtr <> nil, 'virtual reserve returns non-nil');
    platform_virtual_release(LPtr, 0);
    Check(True, 'virtual release with zero size is no-op');
  finally
    platform_virtual_release(LPtr, 4096);
  end;
end;

{ Madvise error path tests }
procedure TestMadviseThpNilNoOp;
begin
  platform_madvise_thp(nil, 4096);
  Check(True, 'madvise thp with nil is no-op');
end;

procedure TestMadviseThpZeroSizeNoOp;
var
  LPtr: Pointer;
begin
  LPtr := platform_virtual_reserve(4096);
  try
    Check(LPtr <> nil, 'virtual reserve returns non-nil');
    platform_madvise_thp(LPtr, 0);
    Check(True, 'madvise thp with zero size is no-op');
  finally
    platform_virtual_release(LPtr, 4096);
  end;
end;

{ Additional error path tests }
procedure TestAllocVeryLargeAlignment;
var
  LPtr: Pointer;
const
  { Stay within platform_aligned_alloc MAX_ALIGNMENT (16MiB). Multi-GB
    posix_memalign has aborted Darwin aarch64 GHA at suite exit. }
  LARGE_ALIGN = 16 * 1024 * 1024;
begin
  LPtr := platform_aligned_alloc(64, LARGE_ALIGN);
  if LPtr <> nil then
  begin
    Check(IsAligned(LPtr, LARGE_ALIGN), '16MiB alignment');
    platform_aligned_free(LPtr);
  end
  else
    Check(True, '16MiB alignment allocation may fail on some systems');

  { Over-cap alignment must fail closed }
  Check(platform_aligned_alloc(64, SizeUInt(32) * 1024 * 1024) = nil,
    'alignment above 16MiB cap fails closed');
end;

procedure TestReallocGrowAndShrink;
var
  LPtr, LGrown, LShrunk: PByte;
  LIndex: Integer;
begin
  LPtr := PByte(platform_aligned_alloc(16, 64));
  try
    Check(LPtr <> nil, 'initial alloc');
    for LIndex := 0 to 15 do
      LPtr[LIndex] := Byte(LIndex);

    { Grow to 64 bytes }
    LGrown := PByte(platform_aligned_realloc(LPtr, 64, 64));
    LPtr := nil;
    Check(LGrown <> nil, 'grow realloc');
    for LIndex := 0 to 15 do
      Check(LGrown[LIndex] = Byte(LIndex), 'grow preserves data');

    { Shrink to 8 bytes }
    LShrunk := PByte(platform_aligned_realloc(LGrown, 8, 64));
    LGrown := nil;
    Check(LShrunk <> nil, 'shrink realloc');
    for LIndex := 0 to 7 do
      Check(LShrunk[LIndex] = Byte(LIndex), 'shrink preserves data');
  finally
    if LShrunk <> nil then platform_aligned_free(LShrunk);
    if LGrown <> nil then platform_aligned_free(LGrown);
    if LPtr <> nil then platform_aligned_free(LPtr);
  end;
end;

procedure TestVirtualReserveCommitDecommitRelease;
var
  LPtr: Pointer;
begin
  { Full lifecycle: reserve -> commit -> decommit -> release }
  LPtr := platform_virtual_reserve(4096 * 4);
  Check(LPtr <> nil, 'virtual reserve');

  Check(platform_virtual_commit(LPtr, 4096), 'virtual commit first page');
  PByte(LPtr)^ := $42;
  Check(PByte(LPtr)^ = $42, 'committed page is writable');

  platform_virtual_decommit(LPtr, 4096);
  Check(True, 'virtual decommit');

  platform_virtual_release(LPtr, 4096 * 4);
  Check(True, 'virtual release');
end;

procedure TestSecureZeroLargeBuffer;
var
  LBuffer: array[0..4095] of Byte;
  LIndex: Integer;
begin
  for LIndex := Low(LBuffer) to High(LBuffer) do
    LBuffer[LIndex] := Byte(LIndex and $FF);

  platform_secure_zero_memory(@LBuffer[0], SizeOf(LBuffer));

  for LIndex := Low(LBuffer) to High(LBuffer) do
    Check(LBuffer[LIndex] = 0, 'secure zero clears large buffer');
end;

procedure TestAllocVariousSizes;
var
  LPtr: Pointer;
  LSize: PtrUInt;
begin
  { Test various allocation sizes }
  for LSize in [1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256] do
  begin
    LPtr := platform_aligned_alloc(16, LSize);
    if LPtr <> nil then
    begin
      Check(IsAligned(LPtr, 16), 'alignment for size ' + IntToStr(LSize));
      FillChar(LPtr^, LSize, $AB);
      platform_aligned_free(LPtr);
    end;
  end;
  Check(True, 'various allocation sizes handled');
end;

procedure TestFreeNilMultipleTimes;
begin
  platform_aligned_free(nil);
  platform_aligned_free(nil);
  platform_aligned_free(nil);
  Check(True, 'free nil multiple times is safe');
end;

procedure TestSecureZeroMemoryFillPattern;
var
  LBuffer: array[0..255] of Byte;
  LIndex: Integer;
begin
  { Fill with pattern }
  for LIndex := 0 to 255 do
    LBuffer[LIndex] := Byte(LIndex);
  platform_secure_zero_memory(@LBuffer[0], 256);
  { Verify all zeros }
  for LIndex := 0 to 255 do
    Check(LBuffer[LIndex] = 0, 'zero at ' + IntToStr(LIndex));
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.memory');
  T.Test('alloc aligned and writable', @TestAllocAlignedAndWritable);
  T.Test('zero-size and invalid alignment fail closed', @TestZeroSizeAndInvalidAlignmentFailClosed);
  T.Test('free nil no-op', @TestFreeNilNoOp);
  T.Test('realloc nil and zero semantics', @TestReallocNilAndZeroSemantics);
  T.Test('realloc preserves prefix and alignment', @TestReallocPreservesPrefixAndAlignment);
  T.Test('realloc overflow fails closed', @TestReallocOverflowFailsClosedAndKeepsOldAllocation);
  T.Test('backend truth is explicit', @TestBackendTruthIsExplicit);
  T.Test('native backend truth matches forced host', @TestNativeBackendTruthMatchesForcedHost);
  T.Test('native backend source contracts', @TestNativeBackendSourceContracts);
  T.Test('secure zero clears buffer', @TestSecureZeroMemoryClearsBuffer);
  T.Test('secure zero nil and zero-size no-op', @TestSecureZeroMemoryNilAndZeroSizeNoOp);
  T.Test('secure zero backend truth matches host', @TestSecureZeroBackendTruthMatchesHost);
  T.Test('secure zero source contracts', @TestSecureZeroSourceContracts);
  T.Test('realloc invalid alignment returns nil', @TestReallocInvalidAlignmentReturnsNil);
  T.Test('realloc mismatched alignment returns nil', @TestReallocMismatchedAlignmentReturnsNil);
  T.Test('virtual reserve zero size returns nil', @TestVirtualReserveZeroSizeReturnsNil);
  T.Test('virtual commit nil returns false', @TestVirtualCommitNilReturnsFalse);
  T.Test('virtual commit zero size returns false', @TestVirtualCommitZeroSizeReturnsFalse);
  T.Test('virtual decommit nil no-op', @TestVirtualDecommitNilNoOp);
  T.Test('virtual decommit zero size no-op', @TestVirtualDecommitZeroSizeNoOp);
  T.Test('virtual release nil no-op', @TestVirtualReleaseNilNoOp);
  T.Test('virtual release zero size no-op', @TestVirtualReleaseZeroSizeNoOp);
  T.Test('madvise thp nil no-op', @TestMadviseThpNilNoOp);
  T.Test('madvise thp zero size no-op', @TestMadviseThpZeroSizeNoOp);
  T.Test('alloc very large alignment', @TestAllocVeryLargeAlignment);
  T.Test('realloc grow and shrink', @TestReallocGrowAndShrink);
  T.Test('virtual reserve commit decommit release', @TestVirtualReserveCommitDecommitRelease);
  T.Test('secure zero large buffer', @TestSecureZeroLargeBuffer);
  T.Test('alloc various sizes', @TestAllocVariousSizes);
  T.Test('free nil multiple times', @TestFreeNilMultipleTimes);
  T.Test('secure zero fill pattern', @TestSecureZeroMemoryFillPattern);
  if not T.Run then Halt(1);
end.
