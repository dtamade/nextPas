unit nextpas.core.mem.mutex;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync;

type
  TMemMutex = record
  private
    FHandle: TPlatformMutex;
    FInitialized: Boolean;
  public
    procedure Init;
    procedure Done;
    procedure Acquire;
    procedure Release;
  end;

implementation

uses
  nextpas.core.errors;

procedure RaiseMutexError(const AOperation: string; const AError: Int32); inline;
begin
  raise ENextPasError.CreateFmt('TMemMutex.%s failed: %d', [AOperation, AError]);
end;

procedure TMemMutex.Init;
var
  LResult: Int32;
begin
  if FInitialized then
    Exit;
  FillChar(FHandle, SizeOf(FHandle), 0);
  LResult := platform_mutex_init(FHandle, PLATFORM_MUTEX_ERRORCHECK);
  if LResult <> 0 then
    RaiseMutexError('Init', LResult);
  FInitialized := True;
end;

procedure TMemMutex.Done;
begin
  if not FInitialized then
    Exit;
  platform_mutex_destroy(FHandle);
  FillChar(FHandle, SizeOf(FHandle), 0);
  FInitialized := False;
end;

procedure TMemMutex.Acquire;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseMutexError('Acquire', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_lock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Acquire', LResult);
end;

procedure TMemMutex.Release;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseMutexError('Release', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_unlock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Release', LResult);
end;

end.
