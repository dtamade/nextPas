program test_platform_dl_wine;

{ Wine runtime evidence for platform.dl on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.platform.dl;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

const
  LIB_PATH = 'kernel32.dll';

{ 1. Load kernel32.dll }
procedure TestLoadKernel32;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIB_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open kernel32');
  Check(Lib.Handle <> 0, 'handle not zero');
  Check(platform_dl_close(Lib) = 0, 'close');
end;

{ 2. Resolve GetModuleHandleA from kernel32 }
procedure TestResolveGetModuleHandle;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
begin
  Check(platform_dl_open(LIB_PATH, PLATFORM_DL_NOW, Lib) = 0, 'open');
  Check(platform_dl_sym(Lib, 'GetModuleHandleA', Addr) = 0, 'resolve GetModuleHandleA');
  Check(Addr <> nil, 'addr not nil');
  platform_dl_close(Lib);
end;

{ 3. Load non-existent DLL returns error }
procedure TestLoadNonExistent;
var
  Lib: TPlatformLibrary;
  R: Int32;
begin
  R := platform_dl_open('nonexistent_xyz_999.dll', PLATFORM_DL_LAZY, Lib);
  Check(R <> 0, 'non-existent DLL returns error');
end;

{ 4. Resolve non-existent symbol returns error }
procedure TestResolveNonExistent;
var
  Lib: TPlatformLibrary;
  Addr: Pointer;
  R: Int32;
begin
  Check(platform_dl_open(LIB_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  R := platform_dl_sym(Lib, '__nonexistent_xyz_123', Addr);
  Check(R <> 0, 'non-existent sym returns error');
  Check(Addr = nil, 'addr is nil');
  platform_dl_close(Lib);
end;

{ 5. Double close returns error }
procedure TestDoubleClose;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open(LIB_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_close(Lib) = 0, 'first close');
  Check(platform_dl_close(Lib) <> 0, 'second close returns error');
end;

{ 6. dl_error after failure returns non-negative length }
procedure TestDlError;
var
  Lib: TPlatformLibrary;
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  platform_dl_open('nonexistent_xyz_999.dll', PLATFORM_DL_LAZY, Lib);
  R := platform_dl_error(@Buf[0], 256);
  Check(R >= 0, 'dl_error returns length >= 0');
end;

{ 7. Resolve same symbol twice returns same address }
procedure TestResolveConsistent;
var
  Lib: TPlatformLibrary;
  A1, A2: Pointer;
begin
  Check(platform_dl_open(LIB_PATH, PLATFORM_DL_LAZY, Lib) = 0, 'open');
  Check(platform_dl_sym(Lib, 'GetModuleHandleA', A1) = 0, 'resolve 1');
  Check(platform_dl_sym(Lib, 'GetModuleHandleA', A2) = 0, 'resolve 2');
  Check(A1 = A2, 'same address for same symbol');
  platform_dl_close(Lib);
end;

{ 8. Load user32.dll (second DLL) }
procedure TestLoadUser32;
var
  Lib: TPlatformLibrary;
begin
  Check(platform_dl_open('user32.dll', PLATFORM_DL_LAZY, Lib) = 0, 'open user32');
  Check(Lib.Handle <> 0, 'handle not zero');
  Check(platform_dl_close(Lib) = 0, 'close');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.dl.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('load kernel32.dll', @TestLoadKernel32);
  T.Test('resolve GetModuleHandleA', @TestResolveGetModuleHandle);
  T.Test('load non-existent DLL', @TestLoadNonExistent);
  T.Test('resolve non-existent symbol', @TestResolveNonExistent);
  T.Test('double close returns error', @TestDoubleClose);
  T.Test('dl_error after failure', @TestDlError);
  T.Test('resolve same symbol twice', @TestResolveConsistent);
  T.Test('load user32.dll', @TestLoadUser32);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
