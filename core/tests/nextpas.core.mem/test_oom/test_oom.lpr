program test_oom;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.oom;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- TOomHandler tests --- }

var
  GOomCallCount: Integer;
  GShouldRetry: Boolean;
  GCallOrder: string;

procedure TestOomHandler(ARequestedSize: SizeUInt; var ARetry: Boolean);
begin
  Inc(GOomCallCount);
  ARetry := GShouldRetry;
end;

procedure ChainHandler1(ARequestedSize: SizeUInt; var ARetry: Boolean);
begin
  GCallOrder := GCallOrder + '1';
  ARetry := False;
end;

procedure ChainHandler2(ARequestedSize: SizeUInt; var ARetry: Boolean);
begin
  GCallOrder := GCallOrder + '2';
  ARetry := True;
end;

procedure ChainHandler3(ARequestedSize: SizeUInt; var ARetry: Boolean);
begin
  GCallOrder := GCallOrder + '3';
  ARetry := False;
end;

procedure TestHandlerInitiallyEmpty;
var
  LHandler: TOomHandler;
begin
  LHandler := TOomHandler.Create;
  try
    Check(LHandler.Count = 0, 'handler initially empty');
  finally
    LHandler.Free;
  end;
end;

procedure TestHandlerRegisterUnregister;
var
  LHandler: TOomHandler;
begin
  LHandler := TOomHandler.Create;
  try
    LHandler.Register(@TestOomHandler);
    Check(LHandler.Count = 1, 'count=1 after register');
    LHandler.Unregister(@TestOomHandler);
    Check(LHandler.Count = 0, 'count=0 after unregister');
  finally
    LHandler.Free;
  end;
end;

procedure TestHandlerCallsCallback;
var
  LHandler: TOomHandler;
  LRetry: Boolean;
begin
  LHandler := TOomHandler.Create;
  try
    LHandler.Register(@TestOomHandler);
    GOomCallCount := 0;
    GShouldRetry := False;
    LRetry := LHandler.TryHandle(1024);
    Check(GOomCallCount = 1, 'callback called once');
    Check(not LRetry, 'no retry when handler says no');

    GShouldRetry := True;
    GOomCallCount := 0;
    LRetry := LHandler.TryHandle(1024);
    Check(GOomCallCount = 1, 'callback called once');
    Check(LRetry, 'retry when handler says yes');
  finally
    LHandler.Free;
  end;
end;

procedure TestHandlerChain;
var
  LHandler: TOomHandler;
begin
  LHandler := TOomHandler.Create;
  try
    LHandler.Register(@ChainHandler1);
    LHandler.Register(@ChainHandler2);
    LHandler.Register(@ChainHandler3);

    GCallOrder := '';
    LHandler.TryHandle(100);
    // ChainHandler2 返回 True，ChainHandler3 不应被调用
    Check(GCallOrder = '12', 'chain stops at first retry: got ' + GCallOrder);
  finally
    LHandler.Free;
  end;
end;

{ --- TOomAllocator tests --- }

procedure TestOomAllocatorPassthrough;
var
  LHandler: TOomHandler;
  LAllocator: TOomAllocator;
  LPtr: Pointer;
begin
  LHandler := TOomHandler.Create;
  LAllocator := TOomAllocator.Create(GetRtlAllocator, LHandler);
  try
    // 正常分配应直接通过，不触发 OOM handler
    LPtr := LAllocator.GetMem(1024);
    Check(LPtr <> nil, 'normal alloc succeeds');
    LAllocator.FreeMem(LPtr);
  finally
    LAllocator.Free;
    LHandler.Free;
  end;
end;

procedure TestOomAllocatorTraits;
var
  LHandler: TOomHandler;
  LAllocator: TOomAllocator;
  LTraits: TAllocatorTraits;
begin
  LHandler := TOomHandler.Create;
  LAllocator := TOomAllocator.Create(GetRtlAllocator, LHandler);
  try
    LTraits := LAllocator.Traits;
    Check(LTraits.SupportsRealloc, 'RTL supports realloc');
  finally
    LAllocator.Free;
    LHandler.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.oom');

  T.Test('handler initially empty', @TestHandlerInitiallyEmpty);
  T.Test('handler register/unregister', @TestHandlerRegisterUnregister);
  T.Test('handler calls callback', @TestHandlerCallsCallback);
  T.Test('handler chain stops at retry', @TestHandlerChain);
  T.Test('oom allocator passthrough', @TestOomAllocatorPassthrough);
  T.Test('oom allocator traits', @TestOomAllocatorTraits);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
