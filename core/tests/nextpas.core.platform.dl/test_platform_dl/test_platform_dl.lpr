program test_platform_dl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.dl,
  nextpas.core.test;

var
  T: TTestSuite;

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
{$IFDEF NEXTPAS_WINDOWS}
  LIBC_PATH = 'kernel32.dll';
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

procedure TestLoadSelf;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(nil, PLATFORM_DL_LAZY, Lib) = 0, 'open nil = self');
  Check(Lib.Handle <> nil, 'self handle not nil');
  platform_dl_close(Lib);
end;

procedure TestErrorSmallBuffer;
var
  Lib: TPlatformLibrary;
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  platform_dl_open('/nonexistent_lib_xyz.so', PLATFORM_DL_LAZY, Lib);
  R := platform_dl_error(@Buf[0], 4);
  Check(R >= 0, 'small buffer does not crash');
  Check(Buf[3] = #0, 'null terminated');
end;

procedure TestSymNilName;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_sym(Lib, nil, Addr) <> 0, 'nil name returns error');
  Check(Addr = nil, 'addr is nil for nil name');
  platform_dl_close(Lib);
end;

procedure TestErrorNilBuffer;
var
  R: Int32;
begin
  R := platform_dl_error(nil, 256);
  Check(R < 0, 'nil buffer returns error');
end;

procedure TestErrorZeroLength;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_dl_error(@Buf[0], 0);
  Check(R < 0, 'zero length returns error');
end;

procedure TestResolveMultiple;
var
  Lib: TPlatformLibrary;
  A1, A2: Pointer;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_sym(Lib, 'strlen', A1) = 0, 'resolve 1');
  Check(platform_dl_sym(Lib, 'strlen', A2) = 0, 'resolve 2');
  Check(A1 = A2, 'same address');
  platform_dl_close(Lib);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.dl');
  T.Test('load libc', @TestLoadLibc);
  T.Test('resolve strlen', @TestResolveSym);
  T.Test('load non-existent', @TestLoadNonExistent);
  T.Test('resolve non-existent sym', @TestResolveNonExistent);
  T.Test('double close', @TestDoubleClose);
  T.Test('nil handle sym', @TestNilHandleSym);
  T.Test('dl_error after failure', @TestDlError);
  T.Test('GLOBAL flag', @TestGlobalFlag);
  T.Test('load self (nil path)', @TestLoadSelf);
  T.Test('error small buffer', @TestErrorSmallBuffer);
  T.Test('resolve same sym twice', @TestResolveMultiple);
  T.Test('sym nil name returns error', @TestSymNilName);
  T.Test('dl_error nil buffer', @TestErrorNilBuffer);
  T.Test('dl_error zero length', @TestErrorZeroLength);
  if not T.Run then Halt(1);
end.
