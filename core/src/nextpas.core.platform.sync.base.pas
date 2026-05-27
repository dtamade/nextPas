unit nextpas.core.platform.sync.base;

{$I nextpas.core.settings.inc}

interface

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.linux.base;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.darwin.base;
{$ENDIF}

{$IFDEF NEXTPAS_ANDROID}
uses
  nextpas.core.platform.android.base;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.freebsd.base;
{$ENDIF}

{$IF defined(NEXTPAS_UNIX) and not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_ANDROID) and not defined(NEXTPAS_FREEBSD)}
uses
  nextpas.core.platform.unix.base;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base;
{$ENDIF}

type
  {$IFDEF NEXTPAS_UNIX}
  TPlatformMutexAlign = TPlatformPThreadMutexAlign;
  TPlatformRwLockAlign = TPlatformPThreadRwLockAlign;
  TPlatformCondVarAlign = TPlatformPThreadCondVarAlign;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  TPlatformMutexAlign = TPlatformWindowsMutexAlign;
  TPlatformRwLockAlign = TPlatformWindowsRwLockAlign;
  TPlatformCondVarAlign = TPlatformWindowsCondVarAlign;
  {$ELSE}
  TPlatformMutexAlign = record
    Value: PtrUInt;
  end;

  TPlatformRwLockAlign = record
    Value: PtrUInt;
  end;

  TPlatformCondVarAlign = record
    Value: PtrUInt;
  end;
  {$ENDIF}

const
  {$IFDEF NEXTPAS_UNIX}
  PLATFORM_MUTEX_SIZE   = PLATFORM_PTHREAD_MUTEX_SIZE;
  PLATFORM_RWLOCK_SIZE  = PLATFORM_PTHREAD_RWLOCK_SIZE;
  PLATFORM_CONDVAR_SIZE = PLATFORM_PTHREAD_CONDVAR_SIZE;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  PLATFORM_MUTEX_SIZE   = PLATFORM_WINDOWS_MUTEX_SIZE;
  PLATFORM_RWLOCK_SIZE  = PLATFORM_WINDOWS_RWLOCK_SIZE;
  PLATFORM_CONDVAR_SIZE = PLATFORM_WINDOWS_CONDVAR_SIZE;
  {$ELSE}
  PLATFORM_MUTEX_SIZE   = 64;
  PLATFORM_RWLOCK_SIZE  = 64;
  PLATFORM_CONDVAR_SIZE = 64;
  {$ENDIF}

type
  TPlatformMutex = record
    case Integer of
      0: (FAlign: TPlatformMutexAlign);
      1: (FOpaque: array[0..PLATFORM_MUTEX_SIZE - 1] of Byte);
  end;

  TPlatformRwLock = record
    case Integer of
      0: (FAlign: TPlatformRwLockAlign);
      1: (FOpaque: array[0..PLATFORM_RWLOCK_SIZE - 1] of Byte);
  end;

  TPlatformCondVar = record
    case Integer of
      0: (FAlign: TPlatformCondVarAlign);
      1: (FOpaque: array[0..PLATFORM_CONDVAR_SIZE - 1] of Byte);
  end;

const
  PLATFORM_MUTEX_NORMAL     = 0;
  PLATFORM_MUTEX_ERRORCHECK = 1;
  PLATFORM_MUTEX_RECURSIVE  = 2;

  PLATFORM_ERR_AGAIN       = 11;
  PLATFORM_ERR_BUSY        = 16;
  PLATFORM_ERR_INVALID     = 22;
  PLATFORM_ERR_UNSUPPORTED = 95;
  PLATFORM_ERR_TIMEOUT     = 110;

implementation

end.
