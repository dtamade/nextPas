unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function darwin_errno_location: PInt32; cdecl; external 'c' name '__error';
function darwin_sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformDarwinSigAction;
  AOldAction: PPlatformDarwinSigAction): Int32; cdecl; external 'c' name 'sigaction';
function darwin_sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformDarwinSignalSet;
  AOldSet: PPlatformDarwinSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
function darwin_pthread_sigmask(
  const AHow: Int32;
  ANewSet: PPlatformDarwinSignalSet;
  AOldSet: PPlatformDarwinSignalSet): Int32; cdecl; external 'c' name 'pthread_sigmask';
function darwin_stat(
  const APath: PAnsiChar;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'stat$INODE64';
function darwin_lstat(
  const APath: PAnsiChar;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'lstat$INODE64';
function darwin_fstat(
  const AFileDescriptor: Int32;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'fstat$INODE64';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';

implementation

end.
