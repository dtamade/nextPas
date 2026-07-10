program test_scoped;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.scoped;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- TScopedAllocator tests --- }

procedure TestScopedInitiallyEmpty;
var
  LScoped: TScopedAllocator;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    Check(LScoped.TrackedCount = 0, 'initially tracked=0');
    Check(LScoped.TrackedBytes = 0, 'initially bytes=0');
  finally
    LScoped.Free;
  end;
end;

procedure TestScopedTracksAllocations;
var
  LScoped: TScopedAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    LPtr1 := LScoped.GetMem(100);
    Check(LScoped.TrackedCount = 1, 'tracked=1 after alloc');
    LPtr2 := LScoped.GetMem(200);
    Check(LScoped.TrackedCount = 2, 'tracked=2 after alloc');
    Check(LScoped.TrackedBytes >= 300, 'bytes >= 300');

    LScoped.FreeMem(LPtr1);
    Check(LScoped.TrackedCount = 1, 'tracked=1 after free');
    LScoped.FreeMem(LPtr2);
    Check(LScoped.TrackedCount = 0, 'tracked=0 after all free');
  finally
    LScoped.Free;
  end;
end;

procedure TestScopedAutoFreesOnDestroy;
var
  LScoped: TScopedAllocator;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  // 分配但不释放
  LScoped.GetMem(100);
  LScoped.GetMem(200);
  LScoped.GetMem(300);
  Check(LScoped.TrackedCount = 3, 'tracked=3');
  // 析构时应自动释放所有分配
  LScoped.Free;
  // 如果有泄漏，heaptrc 会报告
end;

procedure TestScopedReset;
var
  LScoped: TScopedAllocator;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    LScoped.GetMem(100);
    LScoped.GetMem(200);
    Check(LScoped.TrackedCount = 2, 'tracked=2 before reset');

    LScoped.Reset;
    Check(LScoped.TrackedCount = 0, 'tracked=0 after reset');
    Check(LScoped.TrackedBytes = 0, 'bytes=0 after reset');

    // Reset 后可以继续使用
    LScoped.GetMem(50);
    Check(LScoped.TrackedCount = 1, 'tracked=1 after post-reset alloc');
  finally
    LScoped.Free;
  end;
end;

procedure TestScopedRealloc;
var
  LScoped: TScopedAllocator;
  LPtr: Pointer;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LScoped.GetMem(100);
    Check(LScoped.TrackedCount = 1, 'tracked=1');

    LPtr := LScoped.ReallocMem(LPtr, 200);
    Check(LScoped.TrackedCount = 1, 'tracked=1 after realloc');
    Check(LPtr <> nil, 'realloc returned non-nil');

    LScoped.FreeMem(LPtr);
    Check(LScoped.TrackedCount = 0, 'tracked=0 after free');
  finally
    LScoped.Free;
  end;
end;

procedure TestScopedAllocMem;
var
  LScoped: TScopedAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LScoped.AllocMem(100);
    Check(LScoped.TrackedCount = 1, 'tracked=1 after alloc_mem');
    // AllocMem 应该零初始化
    for LI := 0 to 99 do
    begin
      if PByte(LPtr)[LI] <> 0 then
      begin
        Check(False, 'AllocMem not zeroed');
        Break;
      end;
    end;
    LScoped.FreeMem(LPtr);
  finally
    LScoped.Free;
  end;
end;

procedure TestScopedTraits;
var
  LScoped: TScopedAllocator;
  LTraits: TAllocatorTraits;
begin
  LScoped := TScopedAllocator.Create(GetRtlAllocator);
  try
    LTraits := LScoped.Traits;
    Check(LTraits.SupportsRealloc, 'RTL supports realloc');
  finally
    LScoped.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.allocator.scoped');

  T.Test('initially empty', @TestScopedInitiallyEmpty);
  T.Test('tracks allocations', @TestScopedTracksAllocations);
  T.Test('auto-frees on destroy', @TestScopedAutoFreesOnDestroy);
  T.Test('reset', @TestScopedReset);
  T.Test('realloc', @TestScopedRealloc);
  T.Test('alloc_mem', @TestScopedAllocMem);
  T.Test('traits', @TestScopedTraits);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
