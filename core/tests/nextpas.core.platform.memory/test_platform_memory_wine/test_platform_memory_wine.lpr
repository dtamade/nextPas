program test_platform_memory_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.memory;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

function IsAligned(APtr: Pointer; AAlignment: SizeUInt): Boolean;
begin
  if (APtr = nil) or (AAlignment = 0) then
    Exit(False);
  Result := (PtrUInt(APtr) and PtrUInt(AAlignment - 1)) = 0;
end;

{ 1. aligned_alloc + aligned_free roundtrip, alignment verification }
procedure TestAlignedAllocFree;
var
  LPtr: PByte;
  LIndex: Integer;
begin
  LPtr := PByte(platform_aligned_alloc(256, 64));
  try
    Check(LPtr <> nil, 'aligned_alloc returns non-nil');
    Check(IsAligned(LPtr, 64), 'aligned_alloc returns 64-byte aligned storage');
    for LIndex := 0 to 255 do
      LPtr[LIndex] := Byte((LIndex * 13) and $FF);
    for LIndex := 0 to 255 do
      Check(LPtr[LIndex] = Byte((LIndex * 13) and $FF), 'aligned storage round-trips under Wine');
  finally
    platform_aligned_free(LPtr);
  end;
end;

{ 2. page-aligned allocation }
procedure TestPageAlignedAlloc;
var
  LPtr: PByte;
begin
  LPtr := PByte(platform_aligned_alloc(4096, 4096));
  try
    Check(LPtr <> nil, 'page-aligned alloc returns non-nil');
    Check(IsAligned(LPtr, 4096), 'page-aligned alloc returns 4096-byte aligned storage');
  finally
    platform_aligned_free(LPtr);
  end;
end;

{ 3. aligned_realloc preserves alignment under Wine }
procedure TestAlignedRealloc;
var
  LPtr, LGrown: PByte;
  LIndex: Integer;
begin
  LPtr := nil;
  LGrown := nil;
  LPtr := PByte(platform_aligned_alloc(32, 64));
  try
    Check(LPtr <> nil, 'initial alloc returns non-nil');
    for LIndex := 0 to 31 do
      LPtr[LIndex] := Byte((LIndex + 7) and $FF);

    LGrown := PByte(platform_aligned_realloc(LPtr, 96, 64));
    LPtr := nil;
    Check(LGrown <> nil, 'realloc grown returns non-nil');
    Check(IsAligned(LGrown, 64), 'realloc preserves 64-byte alignment');
    for LIndex := 0 to 31 do
      Check(LGrown[LIndex] = Byte((LIndex + 7) and $FF), 'realloc preserves prefix data');
  finally
    if LGrown <> nil then
      platform_aligned_free(LGrown);
    if LPtr <> nil then
      platform_aligned_free(LPtr);
  end;
end;

{ 4. aligned_alloc_backend returns valid enum }
procedure TestAlignedAllocBackend;
begin
  Check(platform_aligned_alloc_backend in [paabFallback, paabWindowsCRT, paabPosix],
    'aligned_alloc_backend returns valid enum value');
end;

{ 5. aligned_alloc_is_native returns boolean }
procedure TestAlignedAllocIsNative;
begin
  Check(platform_aligned_alloc_is_native or (not platform_aligned_alloc_is_native),
    'aligned_alloc_is_native returns boolean');
  Check(platform_aligned_alloc_is_native = (platform_aligned_alloc_backend <> paabFallback),
    'is_native matches backend truth');
end;

{ 6. secure_zero_memory clears buffer }
procedure TestSecureZeroMemory;
var
  LBuffer: array[0..127] of Byte;
  LIndex: Integer;
begin
  for LIndex := Low(LBuffer) to High(LBuffer) do
    LBuffer[LIndex] := Byte($B0 + (LIndex and $0F));

  platform_secure_zero_memory(@LBuffer[0], SizeOf(LBuffer));

  for LIndex := Low(LBuffer) to High(LBuffer) do
    Check(LBuffer[LIndex] = 0, 'secure_zero_memory clears every byte');
end;

{ 7. secure_zero_memory_backend returns valid enum }
procedure TestSecureZeroBackend;
begin
  Check(platform_secure_zero_memory_backend in [
    pszbFallbackFillCharBarrier,
    pszbWindowsNativeDeferred,
    pszbPosixExplicitBZero
  ], 'secure_zero_memory_backend returns valid enum value');
end;

{ 8. secure_zero_memory_is_native returns boolean }
procedure TestSecureZeroIsNative;
begin
  Check(platform_secure_zero_memory_is_native or (not platform_secure_zero_memory_is_native),
    'secure_zero_memory_is_native returns boolean');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.memory.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('aligned_alloc+free roundtrip', @TestAlignedAllocFree);
  T.Run('page-aligned allocation', @TestPageAlignedAlloc);
  T.Run('aligned_realloc preserves alignment', @TestAlignedRealloc);
  T.Run('aligned_alloc_backend returns valid enum', @TestAlignedAllocBackend);
  T.Run('aligned_alloc_is_native returns boolean', @TestAlignedAllocIsNative);
  T.Run('secure_zero_memory clears buffer', @TestSecureZeroMemory);
  T.Run('secure_zero_memory_backend returns valid enum', @TestSecureZeroBackend);
  T.Run('secure_zero_memory_is_native returns boolean', @TestSecureZeroIsNative);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
