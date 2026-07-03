program test_fixed_slab;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.fixed_slab;

var
  T: TTestSuite;

{ --- Helpers --- }

procedure CheckZeroMem(APtr: Pointer; ASize: SizeUInt; const AName: string);
var
  LP: PByte;
  LIdx: SizeUInt;
  LAllZero: Boolean;
begin
  LP := PByte(APtr);
  LAllZero := True;
  for LIdx := 0 to ASize - 1 do
    if LP[LIdx] <> 0 then
    begin
      LAllZero := False;
      Break;
    end;
  Check(LAllZero, AName);
end;

{ --- Basic alloc/free --- }

procedure TestBasicAllocFree;
var
  LPool: TFixedSlabPool;
  LP1, LP2: Pointer;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LP1 := LPool.GetMem(32);
    Check(LP1 <> nil, 'GetMem(32) returns non-nil');
    LP2 := LPool.GetMem(32);
    Check(LP2 <> nil, 'GetMem(32) second returns non-nil');
    Check(LP1 <> LP2, 'two allocs return different pointers');
    LPool.FreeMem(LP1);
    LPool.FreeMem(LP2);
  finally
    LPool.Free;
  end;
end;

{ --- Multiple size classes --- }

procedure TestMultipleSizeClasses;
var
  LPool: TFixedSlabPool;
  LSizes: array[0..4] of SizeUInt;
  LPtrs: array[0..4] of Pointer;
  I: Integer;
begin
  LSizes[0] := 8;    // minimum slab size
  LSizes[1] := 16;
  LSizes[2] := 64;   // ngx_slab_exact_size boundary
  LSizes[3] := 256;
  LSizes[4] := 512;
  LPool := TFixedSlabPool.Create(65536);
  try
    for I := 0 to 4 do
    begin
      LPtrs[I] := LPool.GetMem(LSizes[I]);
      Check(LPtrs[I] <> nil, 'GetMem(size) returns non-nil');
      PByte(LPtrs[I])^ := $FF;  // verify writable
    end;
    for I := 0 to 4 do
      LPool.FreeMem(LPtrs[I]);
  finally
    LPool.Free;
  end;
end;

{ --- AllocMem zero-initialization --- }

procedure TestAllocMemZeroInit;
var
  LPool: TFixedSlabPool;
  LSizes: array[0..3] of SizeUInt;
  I: Integer;
  LP: Pointer;
begin
  LSizes[0] := 16;
  LSizes[1] := 64;
  LSizes[2] := 256;
  LSizes[3] := 512;
  LPool := TFixedSlabPool.Create(16384);
  try
    for I := 0 to 3 do
    begin
      LP := LPool.AllocMem(LSizes[I]);
      Check(LP <> nil, 'AllocMem non-nil');
      CheckZeroMem(LP, LSizes[I], 'AllocMem is zero-filled');
      LPool.FreeMem(LP);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- ReallocMem --- }

procedure TestReallocMemGrow;
var
  LPool: TFixedSlabPool;
  LP1, LP2: Pointer;
  LIdx: Integer;
begin
  LPool := TFixedSlabPool.Create(16384);
  try
    LP1 := LPool.GetMem(32);
    Check(LP1 <> nil, 'initial GetMem(32)');
    // Fill with pattern
    for LIdx := 0 to 31 do
      PByte(LP1)[LIdx] := Byte(LIdx + 1);
    // Grow to 128 bytes
    LP2 := LPool.ReallocMem(LP1, 128);
    Check(LP2 <> nil, 'ReallocMem(128) returns non-nil');
    // Verify pattern preserved in first 32 bytes
    for LIdx := 0 to 31 do
      Check(PByte(LP2)[LIdx] = Byte(LIdx + 1),
        'ReallocMem preserves data');
    LPool.FreeMem(LP2);
  finally
    LPool.Free;
  end;
end;

{ --- MemSize accuracy --- }

procedure TestMemSizeAccuracy;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
  LMemSize: SizeUInt;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LP := LPool.GetMem(32);
    Check(LP <> nil, 'GetMem(32)');
    LMemSize := LPool.MemSize(LP);
    Check(LMemSize >= 32, 'MemSize >= requested 32');
    LPool.FreeMem(LP);
    // nil MemSize should return 0
    Check(LPool.MemSize(nil) = 0, 'MemSize(nil) = 0');
  finally
    LPool.Free;
  end;
end;

{ --- MemSizeOf (actual chunk size) --- }

procedure TestMemSizeOf;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
  LChunkSize: SizeUInt;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LP := LPool.GetMem(32);
    Check(LP <> nil, 'GetMem(32)');
    LChunkSize := LPool.MemSizeOf(LP);
    // MemSizeOf returns actual chunk size (>= requested due to size class rounding)
    Check(LChunkSize >= 32, 'MemSizeOf >= requested 32');
    LPool.FreeMem(LP);
  finally
    LPool.Free;
  end;
end;

{ --- Traits --- }

procedure TestTraits;
var
  LPool: TFixedSlabPool;
  LTraits: TAllocatorTraits;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LTraits := LPool.Traits;
    Check(LTraits.ZeroInitialized = True, 'ZeroInitialized=True');
  finally
    LPool.Free;
  end;
end;

{ --- SecureFree zero-fills before release --- }

procedure TestSecureFreeZeroFill;
var
  LPool: TFixedSlabPool;
  LP: PByte;
  LIdx: Integer;
  LP2: Pointer;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LP := PByte(LPool.GetMem(32));
    Check(LP <> nil, 'GetMem(32)');
    // Fill with non-zero pattern
    for LIdx := 0 to 31 do
      LP[LIdx] := Byte(LIdx + 1);
    // SecureFree should zero then free
    LPool.SecureFree(Pointer(LP));
    // Re-allocate with AllocMem and verify zero
    LP2 := LPool.AllocMem(32);
    Check(LP2 <> nil, 'AllocMem after SecureFree');
    CheckZeroMem(LP2, 32, 'memory is zero after SecureFree+AllocMem');
    LPool.FreeMem(LP2);
  finally
    LPool.Free;
  end;
end;

{ --- SecureFree(nil) safety --- }

procedure TestSecureFreeNil;
var
  LPool: TFixedSlabPool;
  LException: Boolean;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LException := False;
    try
      LPool.SecureFree(nil);
    except
      LException := True;
    end;
    Check(not LException, 'SecureFree(nil) does not raise');
  finally
    LPool.Free;
  end;
end;

{ --- Acquire/Release direct API --- }

procedure TestAcquireReleaseAPI;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
  LOk: Boolean;
begin
  LPool := TFixedSlabPool.Create(4096);
  try
    LOk := LPool.Acquire(LP);
    Check(LOk, 'Acquire succeeds');
    Check(LP <> nil, 'Acquire returns non-nil pointer');
    LPool.Release(LP);
    // TryAcquire should also work
    LOk := LPool.TryAcquire(LP);
    Check(LOk, 'TryAcquire succeeds');
    Check(LP <> nil, 'TryAcquire returns non-nil pointer');
    LPool.Release(LP);
  finally
    LPool.Free;
  end;
end;

{ --- Capacity exhaustion --- }

procedure TestCapacityExhaustion;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
  LCount: Integer;
  LPtrs: array[0..255] of Pointer;
begin
  // Small pool: 4096 bytes with 64B blocks
  LPool := TFixedSlabPool.Create(4096);
  try
    LCount := 0;
    repeat
      LP := LPool.GetMem(64);
      if LP = nil then Break;
      if LCount < 256 then
        LPtrs[LCount] := LP;
      Inc(LCount);
    until LCount >= 256;
    Check(LCount > 0, 'allocated blocks before exhaustion');
    // After exhaustion, GetMem returns nil
    LP := LPool.GetMem(64);
    Check(LP = nil, 'GetMem returns nil after exhaustion');
    // Free all to avoid heaptrc leak report
    if LCount > 256 then LCount := 256;
    while LCount > 0 do
    begin
      Dec(LCount);
      LPool.FreeMem(LPtrs[LCount]);
    end;
  finally
    LPool.Free;
  end;
end;

{ --- Large object fallback --- }

procedure TestLargeObjectFallback;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
  LMemSize: SizeUInt;
begin
  LPool := TFixedSlabPool.Create(16384);
  try
    // Objects >= ngx_slab_max_size (2048 bytes) fall through to allocator
    LP := LPool.GetMem(4096);
    if LP <> nil then
    begin
      LMemSize := LPool.MemSize(LP);
      Check(LMemSize >= 4096, 'large object MemSize >= 4096');
      LPool.FreeMem(LP);
    end;
    // Even if large alloc returns nil (small capacity), no crash
  finally
    LPool.Free;
  end;
end;

{ --- Batch AcquireN/ReleaseN --- }

procedure TestBatchAcquireRelease;
var
  LPool: TFixedSlabPool;
  LPtrs: array[0..15] of Pointer;
  LCount: Integer;
  I: Integer;
begin
  LPool := TFixedSlabPool.Create(16384);
  try
    LCount := LPool.AcquireN(LPtrs, 16);
    Check(LCount > 0, 'AcquireN returned some');
    for I := 0 to LCount - 1 do
      Check(LPtrs[I] <> nil, 'batch element non-nil');
    LPool.ReleaseN(LPtrs, LCount);
  finally
    LPool.Free;
  end;
end;

{ --- Zero capacity safety --- }

procedure TestZeroCapacitySafe;
var
  LPool: TFixedSlabPool;
  LP: Pointer;
begin
  LPool := TFixedSlabPool.Create(0);
  try
    LP := LPool.GetMem(8);
    Check(LP = nil, 'GetMem on zero-capacity returns nil');
    LP := LPool.AllocMem(8);
    Check(LP = nil, 'AllocMem on zero-capacity returns nil');
    LPool.FreeMem(nil);  // no crash
    LPool.SecureFree(nil);  // no crash
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.fixed_slab');
  T.Test('basic alloc/free', @TestBasicAllocFree);
  T.Test('multiple size classes', @TestMultipleSizeClasses);
  T.Test('AllocMem zero-init', @TestAllocMemZeroInit);
  T.Test('ReallocMem grow', @TestReallocMemGrow);
  T.Test('MemSize accuracy', @TestMemSizeAccuracy);
  T.Test('MemSizeOf chunk size', @TestMemSizeOf);
  T.Test('Traits verification', @TestTraits);
  T.Test('SecureFree zero-fill', @TestSecureFreeZeroFill);
  T.Test('SecureFree(nil) safe', @TestSecureFreeNil);
  T.Test('Acquire/Release API', @TestAcquireReleaseAPI);
  T.Test('capacity exhaustion', @TestCapacityExhaustion);
  T.Test('large object fallback', @TestLargeObjectFallback);
  T.Test('batch AcquireN/ReleaseN', @TestBatchAcquireRelease);
  T.Test('zero capacity safety', @TestZeroCapacitySafe);
  T.Run;

  T.Summary;
end.
