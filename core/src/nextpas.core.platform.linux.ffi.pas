unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.linux.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function linux_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function linux_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function linux_xstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__xstat';
function linux_lxstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__lxstat';
function linux_fxstat(
  const AVersion: Int32;
  const AFileDescriptor: Int32;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__fxstat';
function linux_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

implementation

end.
