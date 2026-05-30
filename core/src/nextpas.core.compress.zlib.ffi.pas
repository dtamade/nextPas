unit nextpas.core.compress.zlib.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  zlib;

{ This unit re-exports the FPC paszlib API.
  When NEXTPAS_USE_ZLIB_NATIVE is defined, the linker resolves
  against the system libz.so instead of the Pascal implementation.
  The paszlib unit already uses cdecl external 'z' when linking
  against the native library, so this unit simply documents the
  compile-time switch and provides a verification entry point. }

function NativeZlibVersion: PAnsiChar;

implementation

{$IFDEF NEXTPAS_USE_ZLIB_NATIVE}
function zlibVersion: PAnsiChar; cdecl; external 'z';

function NativeZlibVersion: PAnsiChar;
begin
  Result := zlibVersion;
end;
{$ELSE}
function NativeZlibVersion: PAnsiChar;
begin
  Result := zlib.zlibVersion;
end;
{$ENDIF}

end.
