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

procedure TestLoadSameLibTwice;
var
  Lib1, Lib2: TPlatformLibrary;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib1) = 0, 'open 1');
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib2) = 0, 'open 2');
  Check(Lib1.Handle <> nil, 'handle 1 not nil');
  Check(Lib2.Handle <> nil, 'handle 2 not nil');
  { Both should be valid }
  platform_dl_close(Lib1);
  platform_dl_close(Lib2);
end;

procedure TestSymAfterClose;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
  R: Int32;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_close(Lib) = 0, 'close');
  R := platform_dl_sym(Lib, 'strlen', Addr);
  Check(R <> 0, 'sym after close returns error');
  Check(Addr = nil, 'addr is nil after close');
end;

procedure TestErrorClearAfterSuccess;
var
  Lib: TPlatformLibrary;
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  { Trigger an error }
  platform_dl_open('/nonexistent_lib_xyz.so', PLATFORM_DL_LAZY, Lib);
  { Now succeed }
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open after error');
  { Error should reflect the previous failure, not the success }
  R := platform_dl_error(@Buf[0], 256);
  Check(R >= 0, 'dl_error returns length');
  platform_dl_close(Lib);
end;

procedure TestLoadWithRTLD_NOW;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_NOW, Lib) = 0, 'open with RTLD_NOW');
  Check(Lib.Handle <> nil, 'handle not nil');
  platform_dl_close(Lib);
end;

procedure TestLoadMultipleLibs;
var
  Lib1, Lib2: TPlatformLibrary;
  Addr1, Addr2: Pointer;
begin
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib1) = 0, 'open lib1');
  Check(platform_dl_open(LIBC_PATH, PLATFORM_DL_LAZY, Lib2) = 0, 'open lib2');
  Check(platform_dl_sym(Lib1, 'strlen', Addr1) = 0, 'sym from lib1');
  Check(platform_dl_sym(Lib2, 'strlen', Addr2) = 0, 'sym from lib2');
  Check(Addr1 = Addr2, 'same symbol from both libs');
  platform_dl_close(Lib1);
  platform_dl_close(Lib2);
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
  T.Test('load same lib twice', @TestLoadSameLibTwice);
  T.Test('sym after close', @TestSymAfterClose);
  T.Test('error clears after success', @TestErrorClearAfterSuccess);
  T.Test('load with RTLD_NOW', @TestLoadWithRTLD_NOW);
  T.Test('load multiple libs', @TestLoadMultipleLibs);
  if not T.Run then Halt(1);
end.
