program test_mapped_file;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.mapped_file,
  nextpas.core.mem.error;

var
  T: TTestSuite;

const
  TEST_SIZE = 64 * 1024; { 64KB }

procedure TestCreateAndDestroy;
var
  LAlloc: TMappedFileAllocator;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    Check(LAlloc.IsMapped, 'should be mapped');
    Check(LAlloc.MappedSize = TEST_SIZE, 'mapped size should match');
    Check(LAlloc.BaseAddress <> nil, 'base address should not be nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlloc;
var
  LAlloc: TMappedFileAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    LPtr := LAlloc.GetMem(1024);
    Check(LPtr <> nil, 'alloc should succeed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TMappedFileAllocator;
  LPtrs: array[0..2] of Pointer;
  LI: Integer;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    for LI := 0 to 2 do
    begin
      LPtrs[LI] := LAlloc.GetMem(256);
      Check(LPtrs[LI] <> nil, 'alloc should succeed');
    end;
    Check(LPtrs[0] <> LPtrs[1], 'pointers should be different');
    Check(LPtrs[1] <> LPtrs[2], 'pointers should be different');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TMappedFileAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    LPtr := LAlloc.AllocMem(256);
    Check(LPtr <> nil, 'alloc should succeed');
    for LI := 0 to 255 do
    begin
      if PByte(PtrUInt(LPtr) + LI)^ <> 0 then
      begin
        Check(False, 'should be zero-initialized');
        Break;
      end;
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TMappedFileAllocator;
  LStats: TMappedFileStats;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    LAlloc.GetMem(1024);
    LStats := LAlloc.GetStats;
    Check(LStats.MappedSize = TEST_SIZE, 'mapped size should match');
    Check(LStats.AllocatedBytes = 1032, 'allocated bytes should be 1032 (1024 + 8 size header, 8-aligned)');
    Check(LStats.AllocCount = 1, 'alloc count should be 1');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFlush;
var
  LAlloc: TMappedFileAllocator;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    LAlloc.GetMem(1024);
    LAlloc.Flush;
    Check(True, 'flush should succeed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TMappedFileAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TMappedFileAllocator.Create('', TEST_SIZE, True);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.SupportsRealloc, 'should support realloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFileBackedCreate;
var
  LAlloc: TMappedFileAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMappedFileAllocator.Create('/tmp/npas_mmap_test.bin', TEST_SIZE, True);
  try
    Check(LAlloc.IsMapped, 'should be mapped');
    Check(LAlloc.MappedSize = TEST_SIZE, 'mapped size should match');
    LPtr := LAlloc.GetMem(1024);
    Check(LPtr <> nil, 'alloc should succeed');
    PInt32(LPtr)^ := $12345678;
    LAlloc.Flush;
  finally
    LAlloc.Free;
  end;
end;

procedure TestFileBackedReopen;
var
  LAlloc: TMappedFileAllocator;
  LStats: TMappedFileStats;
begin
  { Open the file created by TestFileBackedCreate }
  LAlloc := TMappedFileAllocator.Create('/tmp/npas_mmap_test.bin', TEST_SIZE, False);
  try
    Check(LAlloc.IsMapped, 'should be mapped');
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 1, 'alloc count should be 1 after reopen');
    Check(LStats.AllocatedBytes = 1032, 'allocated bytes should be 1032 (1024 + 8 size header, 8-aligned)');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFileBackedTruncate;
var
  LAlloc: TMappedFileAllocator;
begin
  { Create with ACreate=True should truncate existing file }
  LAlloc := TMappedFileAllocator.Create('/tmp/npas_mmap_test.bin', TEST_SIZE, True);
  try
    Check(LAlloc.GetStats.AllocCount = 0, 'alloc count should be 0 after truncate-create');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_mapped_file');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('alloc', @TestAlloc);
  T.Test('multiple_allocs', @TestMultipleAllocs);
  T.Test('alloc_mem', @TestAllocMem);
  T.Test('stats', @TestStats);
  T.Test('flush', @TestFlush);
  T.Test('traits', @TestTraits);
  T.Test('file_backed_create', @TestFileBackedCreate);
  T.Test('file_backed_reopen', @TestFileBackedReopen);
  T.Test('file_backed_truncate', @TestFileBackedTruncate);
  T.Run;
  T.Summary;
end.
