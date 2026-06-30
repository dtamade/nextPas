program test_guard;
{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.guard;

var
  T: TTestSuite;

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

procedure TestAllocMem;
var
  LAlloc: TGuardAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := PByte(LAlloc.AllocMem(128));
    Check(LPtr <> nil, 'AllocMem(128) returns non-nil');
    for LI := 0 to 127 do
      Check(LPtr[LI] = 0, 'AllocMem zero-initialized');
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: AllocMem zero-initialized');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMemSize;
var
  LAlloc: TGuardAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGuardAllocator.Create;
  try
    LPtr := LAlloc.GetMem(100);
    Check(LPtr <> nil, 'GetMem(100)');
    Check(LAlloc.MemSize(LPtr) = 100, 'MemSize = 100');
    LAlloc.FreeMem(LPtr);
    WriteLn('PASS: MemSize');
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
    LNew := PByte(LAlloc.ReallocMem(LPtr, 128, 256));
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
    Check(LAlloc.MemSize(nil) = 0, 'MemSize(nil) = 0');
    WriteLn('PASS: nil handling');
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
    Check(LTraits.HasMemSize = True, 'HasMemSize = True');
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

{ ── Main ── }

begin
  T := TTestSuite.Create('test_guard');

  T.Test('get_mem', @TestGetMem);
  T.Test('alloc_mem', @TestAllocMem);
  T.Test('mem_size', @TestMemSize);
  T.Test('realloc', @TestRealloc);
  T.Test('multiple_allocs', @TestMultipleAllocs);
  T.Test('page_aligned', @TestPageAligned);
  T.Test('nil_handling', @TestNilHandling);
  T.Test('traits', @TestTraits);
  T.Test('double_free_detection', @TestDoubleFreeDetection);

  T.Run;
  T.Summary;
end.
