program test_default_allocator;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,             // TThread
  nextpas.core.exception,
  nextpas.core.platform.thread,
  nextpas.core.testing,
  nextpas.core.mem;

const
  THREAD_COUNT = 12;
  ITERATION_COUNT = 64;

type
  TDefaultAllocatorThread = class(TThread)
  private
    FAllocator: IAllocator;
    FFailed: Boolean;
    FStartFlag: PLongInt;
  protected
    procedure Execute; override;
  public
    constructor Create(AStartFlag: PLongInt);
    property Allocator: IAllocator read FAllocator;
    property Failed: Boolean read FFailed;
  end;

var
  T: TTestRunner;

constructor TDefaultAllocatorThread.Create(AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FStartFlag := AStartFlag;
  FFailed := False;
end;

procedure TDefaultAllocatorThread.Execute;
var
  LIndex: Integer;
  LPtr: Pointer;
begin
  while FStartFlag^ = 0 do
    platform_thread_yield;

  try
    FAllocator := DefaultAllocator;
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LPtr := FAllocator.GetMem(32);
      if LPtr = nil then
        raise Exception.Create('DefaultAllocator.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LPtr := FAllocator.ReallocMem(LPtr, 64);
      if LPtr = nil then
        raise Exception.Create('DefaultAllocator.ReallocMem returned nil');
      if PByte(LPtr)^ <> Byte(LIndex) then
        raise Exception.Create('DefaultAllocator.ReallocMem did not preserve prefix');
      FAllocator.FreeMem(LPtr);
    end;
  except
    FFailed := True;
  end;
end;

procedure TestDefaultAllocatorSingletonSingleThread;
var
  LFirst: IAllocator;
  LSecond: IAllocator;
begin
  LFirst := DefaultAllocator;
  LSecond := DefaultAllocator;

  Check(LFirst <> nil, 'DefaultAllocator should return an allocator');
  Check(LFirst = LSecond, 'DefaultAllocator should return the canonical singleton');
  Check(LFirst.Traits.ThreadSafe, 'DefaultAllocator should publish a thread-safe allocator');
end;

procedure TestDefaultAllocatorConcurrentStart;
var
  LThreads: array[0..THREAD_COUNT - 1] of TDefaultAllocatorThread;
  LStartFlag: LongInt;
  LIndex: Integer;
  LFirst: IAllocator;
begin
  LStartFlag := 0;
  for LIndex := 0 to High(LThreads) do
  begin
    LThreads[LIndex] := TDefaultAllocatorThread.Create(@LStartFlag);
    LThreads[LIndex].Start;
  end;

  LStartFlag := 1;
  for LIndex := 0 to High(LThreads) do
    LThreads[LIndex].WaitFor;

  LFirst := LThreads[0].Allocator;
  try
    Check(LFirst <> nil, 'first worker should publish an allocator');
    for LIndex := 0 to High(LThreads) do
    begin
      Check(not LThreads[LIndex].Failed, 'worker should not fail');
      Check(LThreads[LIndex].Allocator <> nil, 'worker allocator should be assigned');
      Check(LThreads[LIndex].Allocator = LFirst, 'all workers should see the same allocator identity');
    end;
  finally
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.default_allocator');
  T.Run('singleton single-thread', @TestDefaultAllocatorSingletonSingleThread);
  T.Run('concurrent start returns same instance', @TestDefaultAllocatorConcurrentStart);
  T.Summary;
end.
