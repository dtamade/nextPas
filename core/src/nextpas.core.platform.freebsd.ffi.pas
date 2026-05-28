unit nextpas.core.platform.freebsd.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function __error: PInt32; cdecl; external 'c' name '__error';
function pthread_getthreadid_np: Int32; cdecl; external 'pthread' name 'pthread_getthreadid_np';
function sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformFreeBSDSigAction;
  AOldAction: PPlatformFreeBSDSigAction): Int32; cdecl; external 'c' name 'sigaction';
function sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
function pthread_sigmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'pthread' name 'pthread_sigmask';
function stat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'stat';
function lstat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'lstat';
function fstat(
  const AFileDescriptor: Int32;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'fstat';
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';

implementation

end.
