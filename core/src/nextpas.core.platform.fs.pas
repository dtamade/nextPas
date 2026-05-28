unit nextpas.core.platform.fs;

{$I nextpas.core.settings.inc}

interface

function platform_fs_exists(const APath: PAnsiChar): Boolean;
function platform_fs_is_file(const APath: PAnsiChar): Boolean;
function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
function platform_fs_temp_dir(ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.env;

function platform_fs_exists(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(APath, LStat) = 0;
end;

function platform_fs_is_file(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftRegular;
end;

function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftDirectory;
end;

function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
var
  LStat: TPlatformFileStat;
begin
  ASize := 0;
  Result := platform_file_stat(APath, LStat);
  if Result = 0 then
    ASize := LStat.Size;
end;

function platform_fs_temp_dir(ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: Int32;
  LResult: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
{$IFDEF NEXTPAS_WINDOWS}
  LResult := platform_env_get('TEMP', ABuf, ABufLen, LLen);
  if LResult <> 0 then
    LResult := platform_env_get('TMP', ABuf, ABufLen, LLen);
  if LResult <> 0 then
  begin
    if ABufLen >= 4 then
    begin
      ABuf[0] := 'C'; ABuf[1] := ':'; ABuf[2] := '\';
      ABuf[3] := #0;
      Exit(3);
    end;
    Exit(-1);
  end;
  Result := LLen;
{$ELSE}
  LResult := platform_env_get('TMPDIR', ABuf, ABufLen, LLen);
  if LResult = 0 then
    Result := LLen
  else
  begin
    if ABufLen >= 5 then
    begin
      ABuf[0] := '/'; ABuf[1] := 't'; ABuf[2] := 'm'; ABuf[3] := 'p';
      ABuf[4] := #0;
      Result := 4;
    end
    else
      Result := -1;
  end;
{$ENDIF}
end;

end.
