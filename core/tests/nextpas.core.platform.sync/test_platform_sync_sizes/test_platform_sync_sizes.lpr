program test_platform_sync_sizes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.posix.ffi,{$ENDIF}
  nextpas.core.testing,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

type
  TEmbeddedMutex = record
    Prefix: Byte;
    Mutex: TPlatformMutex;
  end;

  TEmbeddedRwLock = record
    Prefix: Byte;
    RwLock: TPlatformRwLock;
  end;

  TEmbeddedCondVar = record
    Prefix: Byte;
    CondVar: TPlatformCondVar;
  end;

{$IFDEF NEXTPAS_LINUX}
  TEmbeddedNativeMutex = record
    Prefix: Byte;
    Mutex: pthread_mutex_t;
  end;

  TEmbeddedNativeRwLock = record
    Prefix: Byte;
    RwLock: pthread_rwlock_t;
  end;

  TEmbeddedNativeCondVar = record
    Prefix: Byte;
    CondVar: pthread_cond_t;
  end;
{$ENDIF}

procedure CheckPointerAligned(const AName: string; APtr: Pointer);
begin
  Check((PtrUInt(APtr) mod SizeOf(Pointer)) = 0, AName + ' must be pointer-aligned');
end;

{$IFDEF NEXTPAS_LINUX}
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

procedure TestOpaqueAlignmentMatchesNativeLinuxABI;
var
  LEmbeddedMutex: TEmbeddedMutex;
  LEmbeddedRwLock: TEmbeddedRwLock;
  LEmbeddedCondVar: TEmbeddedCondVar;
  LNativeMutex: TEmbeddedNativeMutex;
  LNativeRwLock: TEmbeddedNativeRwLock;
  LNativeCondVar: TEmbeddedNativeCondVar;
begin
  Check((PtrUInt(@LEmbeddedMutex.Mutex) - PtrUInt(@LEmbeddedMutex)) =
    (PtrUInt(@LNativeMutex.Mutex) - PtrUInt(@LNativeMutex)),
    'platform mutex alignment must match Linux pthread_mutex_t embedding');
  Check((PtrUInt(@LEmbeddedRwLock.RwLock) - PtrUInt(@LEmbeddedRwLock)) =
    (PtrUInt(@LNativeRwLock.RwLock) - PtrUInt(@LNativeRwLock)),
    'platform rwlock alignment must match Linux pthread_rwlock_t embedding');
  Check((PtrUInt(@LEmbeddedCondVar.CondVar) - PtrUInt(@LEmbeddedCondVar)) =
    (PtrUInt(@LNativeCondVar.CondVar) - PtrUInt(@LNativeCondVar)),
    'platform condvar alignment must match Linux pthread_cond_t embedding');
end;
{$ENDIF}

procedure TestOpaqueAlignment;
var
  LMutexes: array[0..1] of TPlatformMutex;
  LRwLocks: array[0..1] of TPlatformRwLock;
  LCondVars: array[0..1] of TPlatformCondVar;
  LEmbeddedMutex: TEmbeddedMutex;
  LEmbeddedRwLock: TEmbeddedRwLock;
  LEmbeddedCondVar: TEmbeddedCondVar;
begin
  CheckPointerAligned('mutex array element', @LMutexes[1]);
  CheckPointerAligned('rwlock array element', @LRwLocks[1]);
  CheckPointerAligned('condvar array element', @LCondVars[1]);
  CheckPointerAligned('embedded mutex', @LEmbeddedMutex.Mutex);
  CheckPointerAligned('embedded rwlock', @LEmbeddedRwLock.RwLock);
  CheckPointerAligned('embedded condvar', @LEmbeddedCondVar.CondVar);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.sizes');
  {$IFDEF NEXTPAS_LINUX}
  T.Run('Mutex size fits opaque buffer', @TestMutexSize);
  T.Run('RwLock size fits opaque buffer', @TestRwLockSize);
  T.Run('CondVar size fits opaque buffer', @TestCondVarSize);
  T.Run('Opaque alignment matches Linux native ABI', @TestOpaqueAlignmentMatchesNativeLinuxABI);
  {$ENDIF}
  T.Run('Opaque storage is pointer-aligned', @TestOpaqueAlignment);
  T.Summary;
end.
