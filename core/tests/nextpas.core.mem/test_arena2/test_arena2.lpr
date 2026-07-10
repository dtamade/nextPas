program test_arena2;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.arena2,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateAndDestroy;
var
  LArena: TArena2Allocator;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator);
  try
    Check(LArena.UsedBytes = 0, 'initial used should be 0');
    Check(LArena.PageCount >= 1, 'should have at least 1 page');
  finally
    LArena.Free;
  end;
end;

procedure TestBasicAlloc;
var
  LArena: TArena2Allocator;
  LPtr1, LPtr2: Pointer;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator);
  try
    LPtr1 := LArena.GetMem(64);
    Check(LPtr1 <> nil, 'first alloc should succeed');
    Check(LArena.UsedBytes > 0, 'used should increase');

    LPtr2 := LArena.GetMem(128);
    Check(LPtr2 <> nil, 'second alloc should succeed');
    Check(LPtr2 <> LPtr1, 'pointers should differ');
  finally
    LArena.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LArena: TArena2Allocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator);
  try
    LPtr := LArena.AllocMem(32);
    Check(LPtr <> nil, 'AllocMem should succeed');

    LAllZero := True;
    for LI := 0 to 31 do
    begin
      if PByte(PtrUInt(LPtr) + PtrUInt(LI))^ <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    end;
    Check(LAllZero, 'AllocMem should zero-initialize');
  finally
    LArena.Free;
  end;
end;

procedure TestReset;
var
  LArena: TArena2Allocator;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator, 4096);
  try
    LArena.GetMem(1024);
    LArena.GetMem(1024);
    Check(LArena.UsedBytes > 0, 'used should be > 0');

    LArena.Reset;
    Check(LArena.UsedBytes = 0, 'used should be 0 after reset');
    Check(LArena.PageCount = 1, 'should have 1 page after reset');

    LArena.GetMem(64);
    Check(LArena.UsedBytes > 0, 'alloc after reset should work');
  finally
    LArena.Free;
  end;
end;

procedure TestManyAllocations;
var
  LArena: TArena2Allocator;
  LPtrs: array[0..99] of Pointer;
  LI: Integer;
begin
  { 使用小页，多次分配验证增长 }
  LArena := TArena2Allocator.Create(DefaultAllocator, 1024);
  try
    for LI := 0 to 99 do
    begin
      LPtrs[LI] := LArena.GetMem(64);
      Check(LPtrs[LI] <> nil, 'alloc should succeed at ' + IntToStr(LI));
    end;

    { 总分配 6400B，页大小 1024B，应该有多个页 }
    Check(LArena.UsedBytes >= 6400, 'used should be >= 6400');
  finally
    LArena.Free;
  end;
end;

procedure TestStats;
var
  LArena: TArena2Allocator;
  LStats: TArena2Stats;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator, 4096);
  try
    LArena.GetMem(100);
    LArena.GetMem(200);

    LStats := LArena.GetStats;
    Check(LStats.PageSize = 4096, 'page size should be 4096');
    Check(LStats.AllocCount = 2, 'alloc count should be 2');
    Check(LStats.UsedBytes > 0, 'used bytes should be > 0');
  finally
    LArena.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TArena2Allocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

procedure TestTraits;
var
  LArena: TArena2Allocator;
  LTraits: TAllocatorTraits;
begin
  LArena := TArena2Allocator.Create(DefaultAllocator);
  try
    LTraits := LArena.Traits;
    Check(not LTraits.SupportsRealloc, 'arena does not support realloc');
    Check(not LTraits.ThreadSafe, 'arena is not thread-safe');
  finally
    LArena.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_arena2');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('reset', @TestReset);
  T.Test('many_allocations', @TestManyAllocations);
  T.Test('stats', @TestStats);
  T.Test('nil_inner', @TestNilInner);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
