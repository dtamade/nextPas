{ Windows kernel32 additional types and constants - ported from FPC rtl/win/wininc/ }

const
  MAX_PATH = 260;

  ERROR_SUCCESS             = DWORD(0);
  ERROR_INVALID_FUNCTION    = DWORD(1);
  ERROR_FILE_NOT_FOUND      = DWORD(2);
  ERROR_PATH_NOT_FOUND      = DWORD(3);
  ERROR_TOO_MANY_OPEN_FILES = DWORD(4);
  ERROR_ACCESS_DENIED       = DWORD(5);
  ERROR_INVALID_HANDLE      = DWORD(6);
  ERROR_NOT_ENOUGH_MEMORY   = DWORD(8);
  ERROR_INVALID_DATA        = DWORD(13);
  ERROR_OUTOFMEMORY         = DWORD(14);
  ERROR_INVALID_DRIVE       = DWORD(15);
  ERROR_NO_MORE_FILES       = DWORD(18);
  ERROR_NOT_READY           = DWORD(21);
  ERROR_SHARING_VIOLATION   = DWORD(32);
  ERROR_LOCK_VIOLATION      = DWORD(33);
  ERROR_HANDLE_EOF          = DWORD(38);
  ERROR_FILE_EXISTS         = DWORD(80);
  ERROR_INVALID_PARAMETER   = DWORD(87);
  ERROR_BROKEN_PIPE         = DWORD(109);
  ERROR_INSUFFICIENT_BUFFER = DWORD(122);
  ERROR_INVALID_NAME        = DWORD(123);
  ERROR_MOD_NOT_FOUND       = DWORD(126);
  ERROR_PROC_NOT_FOUND      = DWORD(127);
  ERROR_DIR_NOT_EMPTY       = DWORD(145);
  ERROR_ALREADY_EXISTS      = DWORD(183);
  ERROR_ENVVAR_NOT_FOUND    = DWORD(203);
  ERROR_MORE_DATA           = DWORD(234);
  ERROR_NO_MORE_ITEMS       = DWORD(259);
  ERROR_DIRECTORY           = DWORD(267);
  ERROR_IO_PENDING          = DWORD(997);
  ERROR_NOT_FOUND           = DWORD(1168);
  ERROR_OPERATION_ABORTED   = DWORD(995);

  STD_INPUT_HANDLE  = DWORD(-10);
  STD_OUTPUT_HANDLE = DWORD(-11);
  STD_ERROR_HANDLE  = DWORD(-12);

  STARTF_USESHOWWINDOW = DWORD($00000001);
  STARTF_USESIZE       = DWORD($00000002);
  STARTF_USEPOSITION   = DWORD($00000004);
  STARTF_USESTDHANDLES = DWORD($00000100);

  CREATE_NEW        = DWORD(1);
  CREATE_ALWAYS_    = DWORD(2);
  OPEN_EXISTING_    = DWORD(3);
  OPEN_ALWAYS_      = DWORD(4);
  TRUNCATE_EXISTING_= DWORD(5);

  FILE_FLAG_WRITE_THROUGH   = DWORD($80000000);
  FILE_FLAG_OVERLAPPED      = DWORD($40000000);
  FILE_FLAG_NO_BUFFERING    = DWORD($20000000);
  FILE_FLAG_RANDOM_ACCESS   = DWORD($10000000);
  FILE_FLAG_SEQUENTIAL_SCAN = DWORD($08000000);
  FILE_FLAG_DELETE_ON_CLOSE  = DWORD($04000000);
  FILE_FLAG_BACKUP_SEMANTICS = DWORD($02000000);
  FILE_FLAG_POSIX_SEMANTICS  = DWORD($01000000);
  FILE_FLAG_OPEN_REPARSE_POINT = DWORD($00200000);

  PIPE_ACCESS_INBOUND  = DWORD(1);
  PIPE_ACCESS_OUTBOUND = DWORD(2);
  PIPE_ACCESS_DUPLEX   = DWORD(3);

type
  ULONG_PTR = PtrUInt;
  DWORD_PTR = ULONG_PTR;
  SIZE_T_WIN = ULONG_PTR;
  INT_PTR = PtrInt;
  LONG_PTR = PtrInt;
  UINT_PTR = PtrUInt;

  ULARGE_INTEGER = record
    case Byte of
      0: (LowPart: DWORD; HighPart: DWORD);
      1: (QuadPart: UInt64);
  end;
  PULARGE_INTEGER = ^ULARGE_INTEGER;

  OVERLAPPED = record
    Internal: ULONG_PTR;
    InternalHigh: ULONG_PTR;
    Offset: DWORD;
    OffsetHigh: DWORD;
    hEvent: HANDLE;
  end;
  LPOVERLAPPED = ^OVERLAPPED;

  TRTLCriticalSection = packed record
    DebugInfo: Pointer;
    LockCount: LongInt;
    RecursionCount: LongInt;
    OwningThread: HANDLE;
    LockSemaphore: HANDLE;
    SpinCount: ULONG_PTR;
  end;
  PRTLCriticalSection = ^TRTLCriticalSection;
  CRITICAL_SECTION = TRTLCriticalSection;
  LPCRITICAL_SECTION = PRTLCriticalSection;

  SYSTEMTIME = record
    wYear: WORD;
    wMonth: WORD;
    wDayOfWeek: WORD;
    wDay: WORD;
    wHour: WORD;
    wMinute: WORD;
    wSecond: WORD;
    wMilliseconds: WORD;
  end;
  LPSYSTEMTIME = ^SYSTEMTIME;

  WCHAR = WideChar;

  WIN32_FIND_DATAW = record
    dwFileAttributes: DWORD;
    ftCreationTime: FILETIME;
    ftLastAccessTime: FILETIME;
    ftLastWriteTime: FILETIME;
    nFileSizeHigh: DWORD;
    nFileSizeLow: DWORD;
    dwReserved0: DWORD;
    dwReserved1: DWORD;
    cFileName: array[0..MAX_PATH - 1] of WCHAR;
    cAlternateFileName: array[0..13] of WCHAR;
  end;
  LPWIN32_FIND_DATAW = ^WIN32_FIND_DATAW;

  WIN32_FIND_DATAA = record
    dwFileAttributes: DWORD;
    ftCreationTime: FILETIME;
    ftLastAccessTime: FILETIME;
    ftLastWriteTime: FILETIME;
    nFileSizeHigh: DWORD;
    nFileSizeLow: DWORD;
    dwReserved0: DWORD;
    dwReserved1: DWORD;
    cFileName: array[0..MAX_PATH - 1] of AnsiChar;
    cAlternateFileName: array[0..13] of AnsiChar;
  end;
  LPWIN32_FIND_DATAA = ^WIN32_FIND_DATAA;
