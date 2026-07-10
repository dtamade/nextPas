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
  }
  TConcurrentRwLock = class
  private
    FState: Int32;  // 0 = unlocked, -1 = write locked, >0 = reader count
    FClosed: Int32;
    FWriterPending: Int32;
  public
    constructor Create;
    function TryReadLock: Boolean;
    function ReadLock: Boolean;
    function TryWriteLock: Boolean;
    function WriteLock: Boolean;
    procedure ReadUnlock;
    procedure WriteUnlock;
    procedure Close;
    function IsClosed: Boolean;
    function ReaderCount: Int32;
    function IsWriteLocked: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
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
  AtomicFetchAdd32(FWriterPending, 1, moAcqRel);
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      AtomicFetchSub32(FWriterPending, 1, moAcqRel);
      Exit(False);
    end;
    if TryWriteLock then
    begin
      AtomicFetchSub32(FWriterPending, 1, moAcqRel);
      Exit(True);
    end;
    CpuPause;
  end;
end;

procedure TConcurrentRwLock.ReadUnlock;
begin
  AtomicFetchSub32(FState, 1, moRelease);
end;

procedure TConcurrentRwLock.WriteUnlock;
begin
  AtomicStore32(FState, 0, moRelease);
end;

procedure TConcurrentRwLock.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentRwLock.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentRwLock.ReaderCount: Int32;
var
  LState: Int32;
begin
  LState := AtomicLoad32(FState, moAcquire);
  if LState > 0 then
    Result := LState
  else
    Result := 0;
end;

function TConcurrentRwLock.IsWriteLocked: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) < 0;
end;

end.
