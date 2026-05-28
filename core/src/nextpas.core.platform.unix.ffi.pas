unit nextpas.core.platform.unix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.unix.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function unix_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function unix_sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformUnixSigAction;
  AOldAction: PPlatformUnixSigAction): Int32; cdecl; external 'c' name 'sigaction';
function unix_sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformUnixSignalSet;
  AOldSet: PPlatformUnixSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
function unix_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

implementation

end.
