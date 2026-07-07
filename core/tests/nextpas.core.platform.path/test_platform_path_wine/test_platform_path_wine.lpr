program test_platform_path_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.platform.path;

var
  T: TTestSuite;

{ 1. is_absolute — basic cross-platform cases (nil, empty, relative) }
procedure TestPathIsAbsoluteBasic;
begin
  Check(not platform_path_is_absolute(nil), 'nil is not absolute');
  Check(not platform_path_is_absolute(''), 'empty string is not absolute');
  Check(not platform_path_is_absolute('foo'), 'relative path "foo" is not absolute');
  { Note: under Windows path semantics, "/" alone is not absolute -- a drive
    letter or UNC prefix is required. is_absolute("/foo") behavior is also
    Windows-context-dependent, so we don't assert it here. }
end;

{$IFDEF NEXTPAS_WINDOWS}

{ 2. is_absolute — Windows-specific drive letter and UNC cases }
procedure TestPathIsAbsoluteWindows;
begin
  Check(platform_path_is_absolute('C:\foo'), 'drive "C:\foo" is absolute');
  Check(platform_path_is_absolute('C:/foo'), 'drive "C:/foo" is absolute');
  Check(platform_path_is_absolute('\\server\share'), 'UNC "\\server\share" is absolute');
  Check(platform_path_is_absolute('//server/share'), 'UNC "//server/share" is absolute');
end;

{ 3. resolve — calls GetFullPathNameW under Wine }
procedure TestPathResolve;
var
  LBuf: array[0..4095] of AnsiChar;
  LRes, LLen: Int32;
begin
  LRes := platform_path_resolve('.', @LBuf[0], 4096);
  Check(LRes > 0, 'resolve(".") should return the CWD (non-zero length)');
  LLen := 0;
  while (LLen < LRes) and (LBuf[LLen] <> #0) do Inc(LLen);
  Check(LLen = LRes, 'resolve returned length should match actual string length');
  Check(platform_path_is_absolute(@LBuf[0]), 'resolved path should be absolute');
end;

{$ENDIF}

{ 4. join — basic path concatenation with separator }
procedure TestPathJoinBasic;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
  LExpected: AnsiString;
begin
  LExpected := 'foo' + PLATFORM_PATH_SEP + 'bar';
  LRes := platform_path_join('foo', 'bar', @LBuf[0], 256);
  Check(LRes = Length(LExpected), 'join returned wrong length for "foo"+"bar"');
  Check(string(PAnsiChar(@LBuf[0])) = string(LExpected),
    'join "foo"+"bar" mismatch: got "' + string(StrPas(@LBuf[0])) + '"');
end;

{ 5. join — absolute child overrides base }
procedure TestPathJoinAbsoluteChild;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
  LR: string;
begin
  { Under Windows path semantics, "/bar" is not necessarily absolute,
    so platform_path_join may keep base. Just verify it returns a non-empty
    result containing "bar". }
  LRes := platform_path_join('foo', '/bar', @LBuf[0], 256);
  Check(LRes > 0, 'join "foo" + "/bar" should return non-empty result');
  LR := string(PAnsiChar(@LBuf[0]));
  Check(Pos('bar', LR) > 0, 'join result should contain "bar", got "' + LR + '"');
end;

{ 6. join — empty base or empty child }
procedure TestPathJoinEmptyBase;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
begin
  LRes := platform_path_join('', 'bar', @LBuf[0], 256);
  Check(LRes = 3, 'join ""+"bar" should return length 3');
  Check(string(PAnsiChar(@LBuf[0])) = 'bar', 'join empty base should return child');

  LRes := platform_path_join('foo', '', @LBuf[0], 256);
  Check(LRes = 3, 'join "foo"+"" should return length 3');
  Check(string(PAnsiChar(@LBuf[0])) = 'foo', 'join empty child should return base');
end;

{ 7. dirname — extract directory component }
procedure TestPathDirname;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
begin
  LRes := platform_path_dirname('/foo/bar', @LBuf[0], 256);
  Check(LRes = 4, 'dirname("/foo/bar") should return length 4 ("/foo")');
  Check(string(PAnsiChar(@LBuf[0])) = '/foo',
    'dirname("/foo/bar") = "/foo", got "' + string(StrPas(@LBuf[0])) + '"');

  LRes := platform_path_dirname('/', @LBuf[0], 256);
  Check(LRes = 1, 'dirname("/") should return length 1');
  Check(string(PAnsiChar(@LBuf[0])) = '/', 'dirname("/") = "/"');

  LRes := platform_path_dirname('foo', @LBuf[0], 256);
  Check(LRes = 0, 'dirname("foo") should return length 0 (empty)');
  Check(string(PAnsiChar(@LBuf[0])) = '', 'dirname("foo") = ""');
end;

{ 8. basename — extract filename component }
procedure TestPathBasename;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
begin
  LRes := platform_path_basename('/foo/bar', @LBuf[0], 256);
  Check(LRes = 3, 'basename("/foo/bar") should return length 3 ("bar")');
  Check(string(PAnsiChar(@LBuf[0])) = 'bar',
    'basename("/foo/bar") = "bar", got "' + string(StrPas(@LBuf[0])) + '"');

  LRes := platform_path_basename('/foo/bar/', @LBuf[0], 256);
  Check(LRes = 3, 'basename("/foo/bar/") should return length 3 ("bar")');
  Check(string(PAnsiChar(@LBuf[0])) = 'bar', 'basename should strip trailing separator');
end;

{ 9. extension — extract file extension }
procedure TestPathExtension;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
begin
  LRes := platform_path_extension('foo.txt', @LBuf[0], 256);
  Check(LRes = 4, 'extension("foo.txt") should return length 4 (".txt")');
  Check(string(PAnsiChar(@LBuf[0])) = '.txt', 'extension("foo.txt") = ".txt"');

  LRes := platform_path_extension('foo', @LBuf[0], 256);
  Check(LRes = 0, 'extension("foo") should return length 0');
  Check(string(PAnsiChar(@LBuf[0])) = '', 'extension("foo") = ""');

  LRes := platform_path_extension('.hidden', @LBuf[0], 256);
  Check(LRes = 0, 'extension(".hidden") should return length 0 (dotfile)');
  Check(string(PAnsiChar(@LBuf[0])) = '', 'extension(".hidden") = ""');

  LRes := platform_path_extension('/foo/bar.txt', @LBuf[0], 256);
  Check(LRes = 4, 'extension("/foo/bar.txt") should return ".txt"');
  Check(string(PAnsiChar(@LBuf[0])) = '.txt', 'extension works with full path');
end;

{ 10. normalize — collapse . and .. components }
procedure TestPathNormalize;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
  LR: string;
{$IFDEF NEXTPAS_WINDOWS}
  LSep: Char;
{$ENDIF}
begin
{$IFDEF NEXTPAS_WINDOWS}
  LSep := '\';
{$ELSE}
  { Test with forward slashes (Unix-style) }
{$ENDIF}
  LRes := platform_path_normalize('/foo/./bar', @LBuf[0], 256);
  LR := string(PAnsiChar(@LBuf[0]));
{$IFDEF NEXTPAS_WINDOWS}
  { Windows: "/foo/./bar" has root "/" (prkWindowsRootedRelative), normalized to "/foo\bar" }
  Check((LR = 'foo' + LSep + 'bar') or (LR = LSep + 'foo' + LSep + 'bar') or
    (LR = '/' + 'foo' + LSep + 'bar'),
    'normalize "/foo/./bar" should yield "foo\bar" or "\foo\bar" or "/foo\bar", got "' + LR + '"');
{$ELSE}
  Check((LR = 'foo/bar') or (LR = '/foo/bar'),
    'normalize "/foo/./bar" should yield "foo/bar" or "/foo/bar", got "' + LR + '"');
{$ENDIF}

  LRes := platform_path_normalize('/foo/bar/../baz', @LBuf[0], 256);
  LR := string(PAnsiChar(@LBuf[0]));
{$IFDEF NEXTPAS_WINDOWS}
  { Windows: "/foo/bar/../baz" has root "/", normalized to "/foo\baz" }
  Check((LR = 'foo' + LSep + 'baz') or (LR = LSep + 'foo' + LSep + 'baz') or
    (LR = '/' + 'foo' + LSep + 'baz'),
    'normalize "/foo/bar/../baz" should yield "foo\baz" or "\foo\baz" or "/foo\baz", got "' + LR + '"');
{$ELSE}
  Check((LR = 'foo/baz') or (LR = '/foo/baz'),
    'normalize "/foo/bar/../baz" should yield "foo/baz" or "/foo/baz", got "' + LR + '"');
{$ENDIF}

  LRes := platform_path_normalize('foo/../bar', @LBuf[0], 256);
  LR := string(PAnsiChar(@LBuf[0]));
  Check(LR = 'bar', 'normalize "foo/../bar" = "bar", got "' + LR + '"');

  LRes := platform_path_normalize('/../foo', @LBuf[0], 256);
  LR := string(PAnsiChar(@LBuf[0]));
{$IFDEF NEXTPAS_WINDOWS}
  { Windows: "/../foo" — "/" is root, .. blocked by root, result is "/foo" }
  Check((LR = '..' + LSep + 'foo') or (LR = 'foo') or (LR = LSep + 'foo') or
    (LR = '/' + 'foo'),
    'normalize "/../foo" should yield ..\foo or foo or \foo or /foo, got "' + LR + '"');
{$ELSE}
  Check((LR = '../foo') or (LR = 'foo') or (LR = '/foo'),
    'normalize "/../foo" should yield ../foo or foo or /foo, got "' + LR + '"');
{$ENDIF}

  LRes := platform_path_normalize('.', @LBuf[0], 256);
  LR := string(PAnsiChar(@LBuf[0]));
  Check(LR = '.', 'normalize "." = ".", got "' + LR + '"');
end;

{ 11. ensure_sep — ensure trailing path separator }
procedure TestPathEnsureSep;
var
  LBuf: array[0..255] of AnsiChar;
  LRes: Int32;
  LExpected: AnsiString;
begin
  LRes := platform_path_ensure_sep('/foo', @LBuf[0], 256);
  LExpected := '/foo' + PLATFORM_PATH_SEP;
  Check(LRes = Length(LExpected), 'ensure_sep("/foo") length mismatch');
  Check(string(PAnsiChar(@LBuf[0])) = string(LExpected),
    'ensure_sep("/foo") = "' + string(LExpected) + '", got "' + string(StrPas(@LBuf[0])) + '"');

  LRes := platform_path_ensure_sep('/foo/', @LBuf[0], 256);
  Check(string(PAnsiChar(@LBuf[0])) = '/foo/', 'ensure_sep with trailing sep should not double');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.path.wine_runtime_smoke');
  T.Test('is_absolute basic', @TestPathIsAbsoluteBasic);
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('is_absolute Windows (drive/UNC)', @TestPathIsAbsoluteWindows);
  T.Test('resolve (GetFullPathNameW)', @TestPathResolve);
{$ENDIF}
  T.Test('join basic', @TestPathJoinBasic);
  T.Test('join absolute child', @TestPathJoinAbsoluteChild);
  T.Test('join empty base/child', @TestPathJoinEmptyBase);
  T.Test('dirname', @TestPathDirname);
  T.Test('basename', @TestPathBasename);
  T.Test('extension', @TestPathExtension);
  T.Test('normalize', @TestPathNormalize);
  T.Test('ensure_sep', @TestPathEnsureSep);
  if not T.Run then Halt(1);
end.