unit nextpas.core.lockfree.rwlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  {** @desc 并发读写锁
    @details 基于原子操作的读写锁实现。
      支持 ReadLock/WriteLock/Unlock/TryReadLock/TryWriteLock。
      适用于读多写少的场景。
 * @concurrency Thread-safe (see source for details).
  }
  TConcurrentRwLock = class
  private
    FState: Int32;  // 0 = unlocked, -1 = write locked, >0 = reader count
    FClosed: Int32;
    FWriterPending: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    function TryReadLock: Boolean;
    function ReadLock: Boolean;
    function TryWriteLock: Boolean;
    function WriteLock: Boolean;
    procedure ReadUnlock;
    procedure WriteUnlock;
    procedure Close;
    function IsClosed: Boolean; inline;
    function ReaderCount: Int32; inline;
    function IsWriteLocked: Boolean; inline;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TConcurrentRwLock.Create;
begin
  inherited Create;
  FState := 0;
  FClosed := 0;
  FWriterPending := 0;
end;

function TConcurrentRwLock.TryReadLock: Boolean;
var
  LOld: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  repeat
    LOld := AtomicLoad32(FState, moRelaxed);
    if (LOld < 0) or (AtomicLoad32(FWriterPending, moAcquire) <> 0) then
      Exit(False);  // Write locked
    if LOld = High(Int32) then
      Exit(False);
  until AtomicCompareExchange32(FState, LOld, LOld + 1, moAcqRel) = LOld;
  Result := True;
end;

function TConcurrentRwLock.ReadLock: Boolean;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    if TryReadLock then
      Exit(True);
    CpuPause;
  end;
end;

function TConcurrentRwLock.TryWriteLock: Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  Result := AtomicCompareExchange32(FState, 0, -1) = 0;
end;

function TConcurrentRwLock.WriteLock: Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  AtomicFetchAdd32(FWriterPending, 1, moAcqRel);
  try
    while True do
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(False);
      if TryWriteLock then
        Exit(True);
      CpuPause;
    end;
  finally
    AtomicFetchSub32(FWriterPending, 1, moAcqRel);
  end;
end;

procedure TConcurrentRwLock.ReadUnlock;
var
  LOld: Int32;
begin
  repeat
    LOld := AtomicLoad32(FState, moAcquire);
    if LOld <= 0 then
      Exit;
  until AtomicCompareExchange32(FState, LOld, LOld - 1, moRelease) = LOld;
end;

procedure TConcurrentRwLock.WriteUnlock;
begin
  AtomicCompareExchange32(FState, -1, 0, moRelease);
end;

procedure TConcurrentRwLock.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

destructor TConcurrentRwLock.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConcurrentRwLock.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentRwLock.ReaderCount: Int32; inline;
var
  LState: Int32;
begin
  LState := AtomicLoad32(FState, moAcquire);
  if LState > 0 then
    Result := LState
  else
    Result := 0;
end;

function TConcurrentRwLock.IsWriteLocked: Boolean; inline;
begin
  Result := AtomicLoad32(FState, moAcquire) < 0;
end;

end.
