program test_platform_ffi_owner_boundary;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SOURCE_DIR_FROM_TEST = '../../../src';
  SOURCE_DIR_FROM_ROOT = 'core/src';

var
  T: TTestRunner;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourceDir: string;
begin
  if DirectoryExists(SOURCE_DIR_FROM_TEST) then
    Exit(SOURCE_DIR_FROM_TEST);
  if DirectoryExists(SOURCE_DIR_FROM_ROOT) then
    Exit(SOURCE_DIR_FROM_ROOT);
  Result := SOURCE_DIR_FROM_TEST;
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestPlatformFFIOwnerBoundary;
var
  LSearch: TSearchRec;
  LSourceDir: string;
  LPath: string;
  LFileName: string;
  LSource: string;
  LFoundPlatform: Boolean;
  LFoundPlatformBase: Boolean;
  LFoundPlatformTime: Boolean;
  LFoundPlatformThread: Boolean;
  LFoundPlatformSync: Boolean;
  LFoundPosixFfi: Boolean;
  LFoundLinuxFfi: Boolean;
  LFoundDarwinFfi: Boolean;
  LFoundAndroidFfi: Boolean;
  LFoundFreeBSDFfi: Boolean;
  LFoundUnixFfi: Boolean;
  LFoundWindowsFfi: Boolean;
  LNonFfiCount: Integer;
  LFfiCount: Integer;
begin
  LSourceDir := ResolveSourceDir;
  LFoundPlatform := False;
  LFoundPlatformBase := False;
  LFoundPlatformTime := False;
  LFoundPlatformThread := False;
  LFoundPlatformSync := False;
  LFoundPosixFfi := False;
  LFoundLinuxFfi := False;
  LFoundDarwinFfi := False;
  LFoundAndroidFfi := False;
  LFoundFreeBSDFfi := False;
  LFoundUnixFfi := False;
  LFoundWindowsFfi := False;
  LNonFfiCount := 0;
  LFfiCount := 0;

  Check(FindFirst(IncludeTrailingPathDelimiter(LSourceDir) + 'nextpas.core.platform*.pas', faAnyFile, LSearch) = 0,
    'platform source audit must locate nextpas.core.platform*.pas under: ' + LSourceDir);
  try
    repeat
      if (LSearch.Attr and faDirectory) <> 0 then
        Continue;

      LFileName := LowerCase(LSearch.Name);
      LPath := IncludeTrailingPathDelimiter(LSourceDir) + LSearch.Name;

      if LFileName = 'nextpas.core.platform.sync.windows.ffi.pas' then
        Check(False, 'platform ffi must stay host-owned, not module-split: ' + LSearch.Name);

      if LFileName = 'nextpas.core.platform.pas' then
        LFoundPlatform := True
      else if LFileName = 'nextpas.core.platform.base.pas' then
        LFoundPlatformBase := True
      else if LFileName = 'nextpas.core.platform.time.pas' then
        LFoundPlatformTime := True
      else if LFileName = 'nextpas.core.platform.thread.pas' then
        LFoundPlatformThread := True
      else if LFileName = 'nextpas.core.platform.sync.pas' then
        LFoundPlatformSync := True
      else if LFileName = 'nextpas.core.platform.posix.ffi.pas' then
        LFoundPosixFfi := True
      else if LFileName = 'nextpas.core.platform.linux.ffi.pas' then
        LFoundLinuxFfi := True
      else if LFileName = 'nextpas.core.platform.darwin.ffi.pas' then
        LFoundDarwinFfi := True
      else if LFileName = 'nextpas.core.platform.android.ffi.pas' then
        LFoundAndroidFfi := True
      else if LFileName = 'nextpas.core.platform.freebsd.ffi.pas' then
        LFoundFreeBSDFfi := True
      else if LFileName = 'nextpas.core.platform.unix.ffi.pas' then
        LFoundUnixFfi := True
      else if LFileName = 'nextpas.core.platform.windows.ffi.pas' then
        LFoundWindowsFfi := True;

      LSource := ReadSourceFile(LPath);
      if Pos('.ffi.pas', LFileName) > 0 then
      begin
        Inc(LFfiCount);
        CheckTokenPresent(LSource, 'external ''',
          'platform ffi unit must own external declarations: ' + LSearch.Name);
      end
      else
      begin
        Inc(LNonFfiCount);
        CheckTokenAbsent(LSource, 'external ''',
          'non-ffi platform unit must not declare external ABI directly: ' + LSearch.Name);
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;

  Check(LNonFfiCount >= 5, 'platform source audit must see the core non-ffi units');
  Check(LFfiCount >= 7, 'platform source audit must see the host/shared ffi owner units');

  Check(LFoundPlatform, 'platform source audit must include nextpas.core.platform.pas');
  Check(LFoundPlatformBase, 'platform source audit must include nextpas.core.platform.base.pas');
  Check(LFoundPlatformTime, 'platform source audit must include nextpas.core.platform.time.pas');
  Check(LFoundPlatformThread, 'platform source audit must include nextpas.core.platform.thread.pas');
  Check(LFoundPlatformSync, 'platform source audit must include nextpas.core.platform.sync.pas');
  Check(LFoundPosixFfi, 'platform source audit must include nextpas.core.platform.posix.ffi.pas');
  Check(LFoundLinuxFfi, 'platform source audit must include nextpas.core.platform.linux.ffi.pas');
  Check(LFoundDarwinFfi, 'platform source audit must include nextpas.core.platform.darwin.ffi.pas');
  Check(LFoundAndroidFfi, 'platform source audit must include nextpas.core.platform.android.ffi.pas');
  Check(LFoundFreeBSDFfi, 'platform source audit must include nextpas.core.platform.freebsd.ffi.pas');
  Check(LFoundUnixFfi, 'platform source audit must include nextpas.core.platform.unix.ffi.pas');
  Check(LFoundWindowsFfi, 'platform source audit must include nextpas.core.platform.windows.ffi.pas');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_owner_boundary');
  T.Run('platform ffi ownership stays in ffi units', @TestPlatformFFIOwnerBoundary);
  T.Summary;
end.
