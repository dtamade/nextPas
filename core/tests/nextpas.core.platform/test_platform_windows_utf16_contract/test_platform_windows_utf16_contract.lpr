program test_platform_windows_utf16_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

const
  WINDOWS_UTF8_PATH_SAMPLE = 'tmp/中文文件名.txt';

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckProductionModuleHasNoAPathCalls(const ARelativePath: string;
  const AForbidden: array of string);
var
  LSource: string;
  I: Int32;
begin
  LSource := LoadSourceText(ARelativePath);
  for I := Low(AForbidden) to High(AForbidden) do
    CheckAbsent(LSource, AForbidden[I],
      ARelativePath + ' must not call ANSI path/environment WinAPI');
end;

procedure TestUtf16HelperSurface;
var
  LHelper: string;
begin
  Check(Pos('中文文件名', WINDOWS_UTF8_PATH_SAMPLE) > 0,
    'contract sample must include a non-ASCII Windows path');
  LHelper := LoadSourceText('src/nextpas.core.platform.windows.utf16.pas');
  CheckContains(LHelper, 'unit nextpas.core.platform.windows.utf16',
    'UTF-16 helper must be nextPas-owned');
  CheckContains(LHelper, 'platform_windows_utf8_to_wide',
    'helper must expose UTF-8 to UTF-16 conversion');
  CheckContains(LHelper, 'platform_windows_wide_to_utf8',
    'helper must expose UTF-16 to UTF-8 conversion');
  CheckContains(LHelper, 'MultiByteToWideChar',
    'helper must use WinAPI conversion through nextPas FFI');
  CheckContains(LHelper, 'WideCharToMultiByte',
    'helper must use WinAPI conversion through nextPas FFI');
end;

procedure TestWindowsFfiWideImports;
var
  LFfi: string;
begin
  LFfi := LoadSourceText('src/nextpas.core.platform.windows.ffi.pas');
  CheckContains(LFfi, 'LoadLibraryW', 'FFI must expose wide DLL path loading');
  CheckContains(LFfi, 'CreateFileW', 'FFI must expose wide file open');
  CheckContains(LFfi, 'GetFileAttributesExW', 'FFI must expose wide stat');
  CheckContains(LFfi, 'SetFileAttributesW', 'FFI must expose wide chmod');
  CheckContains(LFfi, 'CreateDirectoryW', 'FFI must expose wide mkdir');
  CheckContains(LFfi, 'RemoveDirectoryW', 'FFI must expose wide rmdir');
  CheckContains(LFfi, 'DeleteFileW', 'FFI must expose wide unlink');
  CheckContains(LFfi, 'MoveFileW', 'FFI must expose wide rename');
  CheckContains(LFfi, 'GetCurrentDirectoryW', 'FFI must expose wide getcwd');
  CheckContains(LFfi, 'SetCurrentDirectoryW', 'FFI must expose wide chdir');
  CheckContains(LFfi, 'GetFullPathNameW', 'FFI must expose wide path resolve');
  CheckContains(LFfi, 'FindFirstFileW', 'FFI must expose wide directory enumeration');
  CheckContains(LFfi, 'FindNextFileW', 'FFI must expose wide directory iteration');
  CheckContains(LFfi, 'CreateProcessW', 'FFI must expose wide process spawn');
  CheckContains(LFfi, 'GetModuleFileNameW', 'FFI must expose wide module path');
  CheckContains(LFfi, 'GetTempPathW', 'FFI must expose wide temp path');
  CheckContains(LFfi, 'GetFinalPathNameByHandleW', 'FFI must expose wide readlink');
  CheckContains(LFfi, 'CreateSymbolicLinkW', 'FFI must expose wide symlink');
  CheckContains(LFfi, 'GetEnvironmentVariableW', 'FFI must expose wide env get');
  CheckContains(LFfi, 'SetEnvironmentVariableW', 'FFI must expose wide env set');
  CheckContains(LFfi, 'MultiByteToWideChar', 'FFI must expose UTF-8 to UTF-16 API');
  CheckContains(LFfi, 'WideCharToMultiByte', 'FFI must expose UTF-16 to UTF-8 API');
end;

procedure TestProductionUsesWidePathApis;
begin
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.files.pas',
    ['CreateFileA', 'GetFileAttributesExA', 'SetFileAttributesA',
     'CreateDirectoryA', 'RemoveDirectoryA', 'DeleteFileA', 'MoveFileA',
     'GetCurrentDirectoryA', 'SetCurrentDirectoryA', 'CreateSymbolicLinkA',
     'GetFinalPathNameByHandleA', 'FindFirstFileA', 'FindNextFileA',
     'WIN32_FIND_DATAA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.path.pas',
    ['GetFullPathNameA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.env.pas',
    ['GetEnvironmentVariableA', 'SetEnvironmentVariableA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.mmap.pas',
    ['CreateFileA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.dl.pas',
    ['LoadLibraryA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.process.pas',
    ['STARTUPINFOA', 'CreateProcessA']);
  CheckProductionModuleHasNoAPathCalls('src/nextpas.core.platform.pty.pas',
    ['STARTUPINFOEXA', 'CreateProcessA']);
end;

procedure TestAllowedAnsiApisRemainExplicitlyAllowed;
var
  LFfi: string;
begin
  LFfi := LoadSourceText('src/nextpas.core.platform.windows.ffi.pas');
  CheckContains(LFfi, 'ReadFile', 'ReadFile has no ANSI/Wide split');
  CheckContains(LFfi, 'WriteFile', 'WriteFile has no ANSI/Wide split');
  CheckContains(LFfi, 'GetProcAddress', 'GetProcAddress takes a symbol name, not a path');
  CheckContains(LFfi, 'FormatMessageA', 'FormatMessageA is not a public path entrypoint');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.windows.utf16_contract');
  T.Run('helper surface', @TestUtf16HelperSurface);
  T.Run('FFI wide imports', @TestWindowsFfiWideImports);
  T.Run('production wide path APIs', @TestProductionUsesWidePathApis);
  T.Run('allowed non-path ANSI APIs', @TestAllowedAnsiApisRemainExplicitlyAllowed);
  T.Summary;
end.
