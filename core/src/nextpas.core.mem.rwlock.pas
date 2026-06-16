unit nextpas.core.mem.rwlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync;

type
  TMemRwLock = record
  private
    FHandle: TPlatformRwLock;
    FInitialized: Boolean;
  public
    procedure Init;
    procedure Done;
    procedure AcquireRead;
    procedure ReleaseRead;
    procedure AcquireWrite;
    procedure ReleaseWrite;
  end;

implementation

uses
  nextpas.core.errors;

procedure RaiseRwLockError(const AOperation: string; const AError: Int32); inline;
begin
  raise ENextPasError.CreateFmt('TMemRwLock.%s failed: %d', [AOperation, AError]);
end;

procedure TMemRwLock.Init;
var
  LResult: Int32;
begin
  if FInitialized then
    Exit;
  FillChar(FHandle, SizeOf(FHandle), 0);
  LResult := platform_rwlock_init(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('Init', LResult);
  FInitialized := True;
end;

procedure TMemRwLock.Done;
begin
  if not FInitialized then
    Exit;
  platform_rwlock_destroy(FHandle);
  FillChar(FHandle, SizeOf(FHandle), 0);
  FInitialized := False;
end;

procedure TMemRwLock.AcquireRead;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseRwLockError('AcquireRead', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_rdlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('AcquireRead', LResult);
end;

procedure TMemRwLock.ReleaseRead;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseRwLockError('ReleaseRead', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_rdunlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('ReleaseRead', LResult);
end;

procedure TMemRwLock.AcquireWrite;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseRwLockError('AcquireWrite', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_wrlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('AcquireWrite', LResult);
end;

procedure TMemRwLock.ReleaseWrite;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseRwLockError('ReleaseWrite', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_wrunlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('ReleaseWrite', LResult);
end;

end.
