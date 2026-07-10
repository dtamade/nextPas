program test_sliding;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.sliding;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      Check(LAlloc <> nil, 'created');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMem;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(64);
      Check(LP <> nil, 'GetMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestAllocMem;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LP := LAlloc.AllocMem(64);
      Check(LP <> nil, 'AllocMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestReallocMem;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(32);
      LP := LAlloc.ReallocMem(LP, 64);
      Check(LP <> nil, 'ReallocMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestPushPop;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      Check(LAlloc.Push, 'Push succeeded');
      LAlloc.Pop;
      Check(True, 'Push/Pop completed');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestPushPopNested;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      Check(LAlloc.Push, 'Push 1 succeeded');
      Check(LAlloc.Push, 'Push 2 succeeded');
      LAlloc.Pop;
      LAlloc.Pop;
      Check(True, 'Nested Push/Pop completed');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestPushAllocPop;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      Check(LAlloc.Push, 'Push succeeded');
      LP := LAlloc.GetMem(64);
      Check(LP <> nil, 'GetMem returned pointer');
      LAlloc.Pop;
      Check(True, 'Pop after alloc completed');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      Check(LAlloc.GetMem(0) <> nil, 'GetMem(0) returns non-nil from RTL');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LAlloc.FreeMem(nil);
      Check(True, 'FreeMem(nil) did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestStats;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LStats: TSlidingStats;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LStats := LAlloc.GetStats;
      Check(LStats.PushCount = 0, 'initial push count=0');
      Check(LStats.PopCount = 0, 'initial pop count=0');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestTraits;
var
  LInner: IAllocator;
  LAlloc: TSlidingAllocator;
  LTraits: TAllocatorTraits;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TSlidingAllocator.Create(LInner);
    try
      LTraits := LAlloc.Traits;
      Check(not LTraits.SupportsRealloc, 'does not support realloc');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_sliding');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('push_pop', @TestPushPop);
  T.Test('push_pop_nested', @TestPushPopNested);
  T.Test('push_alloc_pop', @TestPushAllocPop);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('stats', @TestStats);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
