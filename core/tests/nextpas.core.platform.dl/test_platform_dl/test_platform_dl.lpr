program test_platform_dl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.dl,
  nextpas.core.testing;

var
  T: TTestRunner;

const
{$IFDEF NEXTPAS_LINUX}
  LIBC_PATH = 'libc.so.6';
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  LIBC_PATH = 'libSystem.B.dylib';
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  LIBC_PATH = 'libc.so.7';
{$ENDIF}

procedure TestLoadLibc;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open libc');
  Check(Lib.Handle <> nil, 'handle not nil');
  Check(platform_dl_close(Lib) = 0, 'close');
end;

procedure TestResolveSym;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_NOW, Lib) = 0, 'open');
  Check(platform_dl_sym(Lib, 'strlen', Addr) = 0, 'resolve strlen');
  Check(Addr <> nil, 'strlen addr not nil');
  platform_dl_close(Lib);
end;

procedure TestLoadNonExistent;
var
  Lib: TPlatformLibrary;
  R: Int32;
begin
  R := platform_dl_open('/nonexistent_lib_xyz.so', PLATFORM_DL_LAZY, Lib);
  Check(R <> 0, 'non-existent returns error');
end;

procedure TestResolveNonExistent;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
  R: Int32;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  R := platform_dl_sym(Lib, '__nonexistent_symbol_xyz_123', Addr);
  Check(R <> 0, 'non-existent sym returns error');
  Check(Addr = nil, 'addr is nil');
  platform_dl_close(Lib);
end;

procedure TestDoubleClose;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_close(Lib) = 0, 'first close');
  Check(platform_dl_close(Lib) <> 0, 'second close returns error');
end;

procedure TestNilHandleSym;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
begin
  FillChar(Lib, SizeOf(Lib), 0);
  Check(platform_dl_sym(Lib, 'strlen', Addr) <> 0, 'nil handle returns error');
  Check(Addr = nil, 'addr is nil');
end;

procedure TestDlError;
var
  Lib: TPlatformLibrary;
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  platform_dl_open('/nonexistent_lib_xyz.so', PLATFORM_DL_LAZY, Lib);
  R := platform_dl_error(@Buf[0], 256);
  Check(R >= 0, 'dl_error returns length >= 0');
end;

procedure TestGlobalFlag;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_NOW or PLATFORM_DL_GLOBAL, Lib) = 0, 'open with GLOBAL');
  Check(Lib.Handle <> nil, 'handle not nil');
  platform_dl_close(Lib);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.dl');
  T.Run('load libc', @TestLoadLibc);
  T.Run('resolve strlen', @TestResolveSym);
  T.Run('load non-existent', @TestLoadNonExistent);
  T.Run('resolve non-existent sym', @TestResolveNonExistent);
  T.Run('double close', @TestDoubleClose);
  T.Run('nil handle sym', @TestNilHandleSym);
  T.Run('dl_error after failure', @TestDlError);
  T.Run('GLOBAL flag', @TestGlobalFlag);
  T.Summary;
end.
