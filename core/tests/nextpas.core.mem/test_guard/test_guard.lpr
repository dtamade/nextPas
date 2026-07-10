program test_guard;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.guard;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ ── Basic alloc/free ── }

procedure TestGetMem;
var
  LAlloc: TGuardAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64) returns non-nil');
    FillChar(LPtr^, 64, $AA);
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: basic GetMem/FreeMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TGuardAllocator;
  LPtr, LNew: PByte;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := PByte(LAlloc.GetMem(64));
    Check(LPtr <> nil, 'GetMem(64)');
    for LI := 0 to 63 do
      LPtr[LI] := Byte(LI);
    LNew := PByte(LAlloc.ReallocMem(LPtr, 256));
    Check(LNew <> nil, 'ReallocMem(256)');
    for LI := 0 to 63 do
      Check(LNew[LI] = Byte(LI), 'data preserved');
    LAlloc.FreeMem(LNew);
    WriteLn('PASS: ReallocMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TGuardAllocator;
  LPtrs: array[0..99] of Pointer;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    for LI := 0 to 99 do
    begin
      LPtrs[LI] := LAlloc.GetMem(16 + SizeUInt(LI * 7));
      Check(LPtrs[LI] <> nil, 'alloc ' + IntToStr(LI));
    end;
    for LI := 0 to 99 do
      FillChar(LPtrs[LI]^, 16 + SizeUInt(LI * 7), $BB);
    for LI := 0 to 99 do
      LAlloc.FreeMem(LPtrs[LI]);
    WriteLn('PASS: 100 allocations, no overlap');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPageAligned;
var
  LAlloc: TGuardAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := LAlloc.GetMem(4096);
    Check(LPtr <> nil, 'GetMem(4096)');
    FillChar(LPtr^, 4096, $CC);
    LAlloc.FreeMem(LPtr);
    LPtr := LAlloc.GetMem(8192);
    Check(LPtr <> nil, 'GetMem(8192)');
    FillChar(LPtr^, 8192, $DD);
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: page-aligned sizes');
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilHandling;
var
  LAlloc: TGuardAllocator;
begin
  LAlloc := TGuardAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) = nil');
    LAlloc.FreeMem(nil);
    WriteLn('PASS: nil handling');
  finally
    LAlloc.Free;
  end;
end;

{ T-02: AllocMem must zero-initialize (DoAllocMem override) }

procedure TestAllocMemZeroed;
var
  LAlloc: TGuardAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := PByte(LAlloc.AllocMem(256));
    Check(LPtr <> nil, 'AllocMem(256) returns non-nil');
    for LI := 0 to 255 do
      Check(LPtr[LI] = 0, 'byte[' + IntToStr(LI) + '] is zero');
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: AllocMem zero-initialization');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TGuardAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ThreadSafe = False, 'ThreadSafe = False');
    WriteLn('PASS: traits');
  finally
    LAlloc.Free;
  end;
end;

{ ── Double-free detection ── }

procedure TestDoubleFreeDetection;
var
  LAlloc: TGuardAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64)');
    LAlloc.FreeMem(LPtr);

    { Guard allocator unmaps memory on free; second free hits unmapped page }
    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'double free should raise an exception (unmapped page)');
    WriteLn('PASS: double-free detection');
  finally
    LAlloc.Free;
  end;
end;

{ ── ReallocMem boundary tests ── }

procedure TestReallocNil;
var
  LAlloc: TGuardAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGuardAllocator.Create;
  try
    { ReallocMem(nil) should behave like GetMem. }
    LPtr := LAlloc.ReallocMem(nil, 128);
    Check(LPtr <> nil, 'ReallocMem(nil, 128) returns non-nil');
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: ReallocMem(nil) acts as GetMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocWildPointer;
var
  LAlloc: TGuardAllocator;
  LRaised: Boolean;
  LStackVar: array[0..63] of Byte;
begin
  LAlloc := TGuardAllocator.Create;
  try
    { Case 1: Unmapped pointer ($DEADBEEF) — raises EAccessViolation. }
    LRaised := False;
    try
      LAlloc.ReallocMem(Pointer($DEADBEEF), 64);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'unmapped pointer ReallocMem raises');

    { Case 2: Mapped pointer (stack) but not from guard allocator —
      Magic check catches it and raises EAllocError. }
    LRaised := False;
    try
      LAlloc.ReallocMem(@LStackVar[0], 128);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'stack pointer ReallocMem raises EAllocError');
    WriteLn('PASS: ReallocMem wild pointer raises');
  finally
    LAlloc.Free;
  end;
end;

{ NEW-025: 大分配 (>4KB) 边界测试 }
procedure TestLargeAllocation;
var
  LAlloc: TGuardAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    { 16KB 分配 — 跨越多个页面 }
    LPtr := PByte(LAlloc.GetMem(16384));
    Check(LPtr <> nil, 'GetMem(16384) returns non-nil');
    { 写入全部内容验证内存有效 }
    for LI := 0 to 16383 do
      LPtr[LI] := Byte(LI and $FF);
    { 验证数据完整性 }
    for LI := 0 to 16383 do
      Check(LPtr[LI] = Byte(LI and $FF), 'data at ' + IntToStr(LI));
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: large allocation (16KB)');
  finally
    LAlloc.Free;
  end;
end;

{ NEW-025: 多次大分配释放交错测试 }
procedure TestMultipleLargeAllocs;
var
  LAlloc: TGuardAllocator;
  LPtrs: array[0..7] of Pointer;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    { 8 个 8KB 分配 }
    for LI := 0 to 7 do
    begin
      LPtrs[LI] := LAlloc.GetMem(8192);
      Check(LPtrs[LI] <> nil, 'alloc #' + IntToStr(LI));
      FillChar(LPtrs[LI]^, 8192, Byte(LI));
    end;
    { 释放偶数，保留奇数 }
    for LI := 0 to 7 do
      if LI mod 2 = 0 then
        LAlloc.FreeMem(LPtrs[LI]);
    { 重新分配偶数 }
    for LI := 0 to 7 do
      if LI mod 2 = 0 then
      begin
        LPtrs[LI] := LAlloc.GetMem(8192);
        Check(LPtrs[LI] <> nil, 're-alloc #' + IntToStr(LI));
      end;
    { 全部释放 }
    for LI := 0 to 7 do
      LAlloc.FreeMem(LPtrs[LI]);
    WriteLn('PASS: multiple large allocs interleaved');
  finally
    LAlloc.Free;
  end;
end;

{ NEW-025: 无效指针 FreeMem 检测 }
procedure TestFreeInvalidPointer;
var
  LAlloc: TGuardAllocator;
  LRaised: Boolean;
  LStackVar: array[0..63] of Byte;
begin
  LAlloc := TGuardAllocator.Create;
  try
    { 释放栈指针（不是 guard allocator 分配的）→ 应抛出异常 }
    LRaised := False;
    try
      LAlloc.FreeMem(@LStackVar[0]);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'free stack pointer raises EAllocError');
    WriteLn('PASS: free invalid pointer detected');
  finally
    LAlloc.Free;
  end;
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('test_guard');

  T.Test('get_mem', @TestGetMem);
  T.Test('realloc', @TestRealloc);
  T.Test('multiple_allocs', @TestMultipleAllocs);
  T.Test('page_aligned', @TestPageAligned);
  T.Test('nil_handling', @TestNilHandling);
  T.Test('alloc_mem_zeroed', @TestAllocMemZeroed);
  T.Test('traits', @TestTraits);
  T.Test('double_free_detection', @TestDoubleFreeDetection);
  T.Test('realloc_nil', @TestReallocNil);
  T.Test('realloc_wild_pointer', @TestReallocWildPointer);
  T.Test('large_allocation_16KB (NEW-025)', @TestLargeAllocation);
  T.Test('multiple_large_allocs (NEW-025)', @TestMultipleLargeAllocs);
  T.Test('free_invalid_pointer (NEW-025)', @TestFreeInvalidPointer);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
