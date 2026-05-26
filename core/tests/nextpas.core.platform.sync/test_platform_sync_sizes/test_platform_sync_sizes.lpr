program test_platform_sync_sizes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  {$IFDEF UNIX}PThreads, UnixType,{$ENDIF}
  nextpas.core.testing,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

{$IFDEF UNIX}
procedure TestMutexSize;
begin
  Check(SizeOf(pthread_mutex_t) <= PLATFORM_MUTEX_SIZE,
    'SizeOf(pthread_mutex_t)=' + IntToStr(SizeOf(pthread_mutex_t)) +
    ' exceeds PLATFORM_MUTEX_SIZE=' + IntToStr(PLATFORM_MUTEX_SIZE));
end;

procedure TestRwLockSize;
begin
  Check(SizeOf(pthread_rwlock_t) <= PLATFORM_RWLOCK_SIZE,
    'SizeOf(pthread_rwlock_t)=' + IntToStr(SizeOf(pthread_rwlock_t)) +
    ' exceeds PLATFORM_RWLOCK_SIZE=' + IntToStr(PLATFORM_RWLOCK_SIZE));
end;

procedure TestCondVarSize;
begin
  Check(SizeOf(pthread_cond_t) <= PLATFORM_CONDVAR_SIZE,
    'SizeOf(pthread_cond_t)=' + IntToStr(SizeOf(pthread_cond_t)) +
    ' exceeds PLATFORM_CONDVAR_SIZE=' + IntToStr(PLATFORM_CONDVAR_SIZE));
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.sizes');
  {$IFDEF UNIX}
  T.Run('Mutex size fits opaque buffer', @TestMutexSize);
  T.Run('RwLock size fits opaque buffer', @TestRwLockSize);
  T.Run('CondVar size fits opaque buffer', @TestCondVarSize);
  {$ENDIF}
  T.Summary;
end.
