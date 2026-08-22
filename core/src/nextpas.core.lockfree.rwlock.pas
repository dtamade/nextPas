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
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  repeat
    LOld := atomic_load(FState, mo_relaxed);
    if (LOld < 0) or (atomic_load(FWriterPending, mo_acquire) <> 0) then
      Exit(False);  // Write locked
    if LOld = High(Int32) then
      Exit(False);
  until atomic_compare_exchange_strong(FState, LOld, LOld + 1, mo_acq_rel, mo_acquire);
  Result := True;
end;

function TConcurrentRwLock.ReadLock: Boolean;
begin
  Result := False;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    if TryReadLock then
      Exit(True);
    CpuPause;
  end;
end;

function TConcurrentRwLock.TryWriteLock: Boolean;
var
  LExpected: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LExpected := 0;
  Result := atomic_compare_exchange_strong(FState, LExpected, -1, mo_seq_cst, mo_seq_cst);
end;

function TConcurrentRwLock.WriteLock: Boolean;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  atomic_fetch_add(FWriterPending, 1, mo_acq_rel);
  try
    while True do
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(False);
      if TryWriteLock then
        Exit(True);
      CpuPause;
    end;
  finally
    atomic_fetch_sub(FWriterPending, 1, mo_acq_rel);
  end;
end;

procedure TConcurrentRwLock.ReadUnlock;
var
  LOld: Int32;
begin
  repeat
    LOld := atomic_load(FState, mo_acquire);
    if LOld <= 0 then
      Exit;
  until atomic_compare_exchange_strong(FState, LOld, LOld - 1, mo_release, mo_relaxed);
end;

procedure TConcurrentRwLock.WriteUnlock;
var
  LExpected: Int32;
begin
  LExpected := -1;
  atomic_compare_exchange_strong(FState, LExpected, 0, mo_release, mo_relaxed);
end;

procedure TConcurrentRwLock.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TConcurrentRwLock.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConcurrentRwLock.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentRwLock.ReaderCount: Int32; inline;
var
  LState: Int32;
begin
  LState := atomic_load(FState, mo_acquire);
  if LState > 0 then
    Result := LState
  else
    Result := 0;
end;

function TConcurrentRwLock.IsWriteLocked: Boolean; inline;
begin
  Result := atomic_load(FState, mo_acquire) < 0;
end;

end.
