program test_platform_memory;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.memory,
  nextpas.core.testing;

const
  PLATFORM_MEMORY_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.memory.pas';
  PLATFORM_MEMORY_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.memory.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';

var
  T: TTestRunner;

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
begin
  LPlatformMemory := ReadSourceFile(ResolveSourcePath(
    PLATFORM_MEMORY_SOURCE_PATH_FROM_TEST,
    PLATFORM_MEMORY_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPlatformMemory, 'procedure platform_secure_zero_memory',
    'platform.memory must publish the secure-zero owner seam');
  CheckTokenPresent(LPlatformMemory, 'platform_secure_zero_memory_barrier',
    'platform.memory secure zero must keep an optimization barrier seam');
  CheckTokenPresent(LPlatformMemory, 'noinline',
    'platform.memory secure zero barrier must not be inlined away');
  CheckTokenPresent(LPlatformMemory, 'secure-zero-backend=fallback-fillchar-readwritebarrier',
    'platform.memory must publish current secure-zero fallback truth');
  CheckTokenPresent(LPlatformMemory, 'windows-native-secure-zero=deferred',
    'platform.memory must publish Windows native secure-zero backend as deferred');
  CheckTokenPresent(LPlatformMemory, 'posix-native-secure-zero=deferred',
    'platform.memory must publish POSIX native secure-zero backend as deferred');
  CheckTokenPresent(LPlatformMemory, 'windows-runtime-ready=false',
    'platform.memory must not claim Windows runtime readiness for secure zero');

  CheckTokenAbsent(LPlatformMemory, 'rtlsecurezeromemory',
    'platform.memory must not own Windows secure-zero raw API names directly');
  CheckTokenAbsent(LPlatformMemory, 'ntdll.dll',
    'platform.memory must not own Windows secure-zero library names directly');
  CheckTokenAbsent(LPlatformMemory, 'baseunix',
    'platform.memory must not depend on BaseUnix for secure-zero semantics');
  CheckTokenAbsent(LPlatformMemory, 'getprocaddress',
    'platform.memory must not perform raw Windows symbol lookup directly');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.memory');
  T.Run('alloc aligned and writable', @TestAllocAlignedAndWritable);
  T.Run('zero-size and invalid alignment fail closed', @TestZeroSizeAndInvalidAlignmentFailClosed);
  T.Run('free nil no-op', @TestFreeNilNoOp);
  T.Run('realloc nil and zero semantics', @TestReallocNilAndZeroSemantics);
  T.Run('realloc preserves prefix and alignment', @TestReallocPreservesPrefixAndAlignment);
  T.Run('realloc overflow fails closed', @TestReallocOverflowFailsClosedAndKeepsOldAllocation);
  T.Run('backend truth is explicit', @TestBackendTruthIsExplicit);
  T.Run('native backend truth matches forced host', @TestNativeBackendTruthMatchesForcedHost);
  T.Run('native backend source contracts', @TestNativeBackendSourceContracts);
  T.Run('secure zero clears buffer', @TestSecureZeroMemoryClearsBuffer);
  T.Run('secure zero nil and zero-size no-op', @TestSecureZeroMemoryNilAndZeroSizeNoOp);
  T.Run('secure zero source contracts', @TestSecureZeroSourceContracts);
  T.Summary;
end.
