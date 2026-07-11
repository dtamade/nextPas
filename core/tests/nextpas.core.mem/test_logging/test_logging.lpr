program test_logging;

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
  nextpas.core.mem.allocator.logging;

var
  GLogCount: Integer;

procedure TestLogProc(AEvent: TLogEvent; APtr: Pointer; ASize: SizeUInt);
begin
  Inc(GLogCount);
end;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
    try
      Check(LAlloc <> nil, 'created');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestCreateWithLogProc;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner, @TestLogProc);
    try
      Check(LAlloc <> nil, 'created with log proc');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMem;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
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
  LAlloc: TLoggingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
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
  LAlloc: TLoggingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
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

procedure TestLogProcCalled;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
  LP: Pointer;
begin
  GLogCount := 0;
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner, @TestLogProc);
    try
      LP := LAlloc.GetMem(64);
      Check(GLogCount >= 1, 'log proc called on GetMem');
      LAlloc.FreeMem(LP);
      Check(GLogCount >= 2, 'log proc called on FreeMem');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestSetLogProc;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
    try
      LAlloc.SetLogProc(@TestLogProc);
      Check(True, 'SetLogProc did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
    try
      Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
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
  LAlloc: TLoggingAllocator;
  LP: Pointer;
  LStats: TLoggingStats;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(64);
      LStats := LAlloc.GetStats;
      Check(LStats.AllocCount >= 1, 'total allocs >= 1');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestTraits;
var
  LInner: IAllocator;
  LAlloc: TLoggingAllocator;
  LTraits: TAllocatorTraits;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TLoggingAllocator.Create(LInner);
    try
      LTraits := LAlloc.Traits;
      Check(LTraits.SupportsRealloc = True, 'supports realloc');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_logging');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('create_with_log_proc', @TestCreateWithLogProc);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('log_proc_called', @TestLogProcCalled);
  T.Test('set_log_proc', @TestSetLogProc);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('stats', @TestStats);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
