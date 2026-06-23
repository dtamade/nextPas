unit nextpas.core.mem.allocator.mimalloc.loader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl;

function TryLoadMimallocLibrary(out ALibrary: TPlatformLibrary): Boolean;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.os.env,
  nextpas.core.path;

function AsciiLower(const AValue: string): string;
var
  LIndex: Integer;
begin
  Result := AValue;
  for LIndex := 1 to Length(Result) do
    if (Result[LIndex] >= 'A') and (Result[LIndex] <= 'Z') then
      Result[LIndex] := Chr(Ord(Result[LIndex]) + 32);
end;

function IsLibraryValid(const ALibrary: TPlatformLibrary): Boolean; inline;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := ALibrary.Handle <> 0;
  {$ELSE}
  Result := ALibrary.Handle <> nil;
  {$ENDIF}
end;

function GetPlatformLibSubdir: string;
begin
  Result := AsciiLower({$I %FPCTARGETCPU%}) + '-' + AsciiLower({$I %FPCTARGETOS%});
end;

function TryOpenLibrary(const APath: string; out ALibrary: TPlatformLibrary): Boolean;
begin
  ZeroMem(@ALibrary, SizeOf(ALibrary));
  Result := platform_dl_open(PAnsiChar(AnsiString(APath)), PLATFORM_DL_NOW, ALibrary) = 0;
  if not Result then
    Exit(False);
  Result := IsLibraryValid(ALibrary);
end;

function TryLoadCandidate(const ADirectory, ALibName: string;
  out ALibrary: TPlatformLibrary): Boolean;
var
  LPath: string;
begin
  if ADirectory = '' then
    LPath := ALibName
  else
    LPath := PathJoin(ADirectory, ALibName);
  Result := TryOpenLibrary(LPath, ALibrary);
end;

function TryLoadEnvironmentOverride(out ALibrary: TPlatformLibrary): Boolean;
var
  LEnvPath: string;
begin
  {$IFDEF MSWINDOWS}
  LEnvPath := GetEnvironmentVariable('NEXTPAS_MIMALLOC_DLL');
  {$ELSE}
  LEnvPath := GetEnvironmentVariable('NEXTPAS_MIMALLOC_SO');
  {$ENDIF}

  if LEnvPath = '' then
    Exit(False);
  Result := TryOpenLibrary(LEnvPath, ALibrary);
end;

function TryLoadExecutableRelative(out ALibrary: TPlatformLibrary): Boolean;
var
  LExeDir: string;
  LLibDir: string;
  LSubdir: string;
begin
  LSubdir := GetPlatformLibSubdir;
  if LSubdir = '' then
    Exit(False);

  LExeDir := ExtractFilePath(ParamStr(0));
  LLibDir := PathJoin3(LExeDir, 'lib', LSubdir);

  {$IFDEF MSWINDOWS}
  Result := TryLoadCandidate(LLibDir, 'mimalloc.dll', ALibrary);
  if not Result then
    Result := TryLoadCandidate(LLibDir, 'mimalloc-redirect.dll', ALibrary);
  {$ELSE}
  Result := TryLoadCandidate(LLibDir, 'libmimalloc.so', ALibrary);
  if not Result then
    Result := TryLoadCandidate(LLibDir, 'libmimalloc.so.2', ALibrary);
  {$ENDIF}
end;

function TryLoadSystemFallback(out ALibrary: TPlatformLibrary): Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := TryLoadCandidate('', 'mimalloc.dll', ALibrary);
  if not Result then
    Result := TryLoadCandidate('', 'mimalloc-redirect.dll', ALibrary);
  {$ELSE}
  Result := TryLoadCandidate('', 'libmimalloc.so', ALibrary);
  if not Result then
    Result := TryLoadCandidate('', 'libmimalloc.so.2', ALibrary);
  if not Result then
    Result := TryLoadCandidate('', 'mimalloc', ALibrary);
  {$ENDIF}
end;

function TryLoadMimallocLibrary(out ALibrary: TPlatformLibrary): Boolean;
begin
  Result := TryLoadEnvironmentOverride(ALibrary);
  if Result then
    Exit(True);

  Result := TryLoadExecutableRelative(ALibrary);
  if Result then
    Exit(True);

  Result := TryLoadSystemFallback(ALibrary);
end;

end.
