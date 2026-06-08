program test_platform_memory;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.memory,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.memory');
  T.Run('alloc aligned and writable', @TestAllocAlignedAndWritable);
  T.Run('zero-size and invalid alignment fail closed', @TestZeroSizeAndInvalidAlignmentFailClosed);
  T.Run('free nil no-op', @TestFreeNilNoOp);
  T.Run('realloc nil and zero semantics', @TestReallocNilAndZeroSemantics);
  T.Run('realloc preserves prefix and alignment', @TestReallocPreservesPrefixAndAlignment);
  T.Run('realloc overflow fails closed', @TestReallocOverflowFailsClosedAndKeepsOldAllocation);
  T.Run('backend truth is explicit', @TestBackendTruthIsExplicit);
  T.Summary;
end.
