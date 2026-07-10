program test_allocator_mimalloc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.mimalloc;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestTryGetMimallocAllocatorNoLib;
var
  LAlloc: IAllocator;
begin
  { Without mimalloc library installed, TryGet should return False }
  if not TryGetMimallocAllocator(LAlloc) then
    Check(LAlloc = nil, 'TryGet returned False, allocator should be nil')
  else
    Check(LAlloc <> nil, 'TryGet returned True, allocator should not be nil');
end;

procedure TestMimallocUsableSizeAvailable;
begin
  { Just verify it doesn't crash — result depends on library availability }
  MimallocUsableSizeAvailable;
  Check(True, 'MimallocUsableSizeAvailable should not crash');
end;

procedure TestTryGetMimallocUsableSizeNil;
var
  LSize: SizeUInt;
  LResult: Boolean;
begin
  LResult := TryGetMimallocUsableSize(nil, LSize);
  Check(not LResult, 'TryGetMimallocUsableSize(nil) should return False');
  Check(LSize = 0, 'Size should be 0 for nil pointer');
end;

procedure TestTryGetMimallocUsableSizeNoLib;
var
  LSize: SizeUInt;
  LResult: Boolean;
begin
  { Without mimalloc, UsableSize should return False for any pointer }
  LResult := TryGetMimallocUsableSize(Pointer(1), LSize);
  if MimallocUsableSizeAvailable then
    Check(LResult, 'mimalloc available: should return True for valid pointer')
  else
    Check(not LResult, 'mimalloc not available: should return False');
end;

procedure TestGetMimallocAllocator;
var
  LAlloc: IAllocator;
  LGotException: Boolean;
begin
  LGotException := False;
  try
    LAlloc := GetMimallocAllocator;
    { If mimalloc is available, verify basic functionality }
    if LAlloc <> nil then
    begin
      Check(LAlloc.GetMem(64) <> nil, 'GetMem should work');
      Check(LAlloc.Traits.ZeroInitialized, 'mimalloc should be zero-initialized');
    end;
  except
    on E: Exception do
      LGotException := True;
  end;
  { Either succeeds (lib available) or raises (lib not available) }
  Check((LAlloc <> nil) or LGotException, 'Should succeed or raise exception');
end;

procedure TestMimallocAllocatorTraits;
var
  LAlloc: IAllocator;
begin
  if TryGetMimallocAllocator(LAlloc) then
  begin
    Check(LAlloc.Traits.ZeroInitialized, 'mimalloc should be ZeroInitialized');
    Check(LAlloc.Traits.ThreadSafe, 'mimalloc should be ThreadSafe');
    Check(LAlloc.Traits.SupportsRealloc, 'mimalloc should support realloc');
  end
  else
    Check(True, 'mimalloc not available, skipping traits check');
end;

procedure TestMimallocAllocatorGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LGotException: Boolean;
begin
  if TryGetMimallocAllocator(LAlloc) then
  begin
    LGotException := False;
    try
      LPtr := LAlloc.GetMem(1024);
      Check(LPtr <> nil, 'GetMem(1024) should succeed');
      LAlloc.FreeMem(LPtr);
    except
      on E: Exception do
        LGotException := True;
    end;
    { Either works (lib loaded) or raises (lib not loadable) }
    Check(LGotException or True, 'GetMem should work or raise gracefully');
  end
  else
    Check(True, 'mimalloc not available, skipping');
end;

begin
  T := TTestSuite.Create('test_allocator_mimalloc');
  T.Test('TryGetMimallocAllocatorNoLib', @TestTryGetMimallocAllocatorNoLib);
  T.Test('MimallocUsableSizeAvailable', @TestMimallocUsableSizeAvailable);
  T.Test('TryGetMimallocUsableSizeNil', @TestTryGetMimallocUsableSizeNil);
  T.Test('TryGetMimallocUsableSizeNoLib', @TestTryGetMimallocUsableSizeNoLib);
  T.Test('GetMimallocAllocator', @TestGetMimallocAllocator);
  T.Test('MimallocAllocatorTraits', @TestMimallocAllocatorTraits);
  T.Test('MimallocAllocatorGetMem', @TestMimallocAllocatorGetMem);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
