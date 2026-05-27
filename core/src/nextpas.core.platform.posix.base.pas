unit nextpas.core.platform.posix.base;

{$I nextpas.core.settings.inc}

interface

type
  timespec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;
  PTimeSpec = ^timespec;

  {$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  pthread_t = Pointer;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  pthread_t = PtrInt;
  {$ELSE}
  pthread_t = PtrUInt;
  {$ENDIF}

  {$IFDEF NEXTPAS_MACOS}
  pthread_key_t = PtrUInt;
  {$ELSEIF defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
  pthread_key_t = Int32;
  {$ELSE}
  pthread_key_t = UInt32;
  {$ENDIF}

  TPThreadStartRoutine = function(AArg: Pointer): Pointer; cdecl;
  TPThreadCondAttrSetClockProc = function(attr: Pointer; clk_id: Int32): Int32; cdecl;

  {$IFDEF NEXTPAS_FREEBSD}
  pthread_mutex_t = Pointer;
  pthread_mutexattr_t = Pointer;
  pthread_rwlock_t = Pointer;
  pthread_rwlockattr_t = Pointer;
  pthread_cond_t = Pointer;
  pthread_condattr_t = Pointer;
  {$ELSEIF defined(NEXTPAS_MACOS)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..63] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..199] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..23] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = PtrInt;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = PtrInt;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = PtrInt;
  {$ELSEIF defined(NEXTPAS_LINUX)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = Int32;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = Int64;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = Int32;
  {$ELSE}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;
  {$ENDIF}

implementation

end.
