unit nextpas.core.platform.android.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.android.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function android_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function android_errno_location: PInt32; cdecl; external 'c' name '__errno';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function android_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

implementation

end.
