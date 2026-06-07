unit nextpas.core.platform.which;

{$I nextpas.core.settings.inc}

interface

function platform_which(const AName: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

uses
  nextpas.core.platform.env,
  nextpas.core.platform.path,
  nextpas.core.platform.fs,
  nextpas.core.platform.posix.ffi;

const
{$IFDEF NEXTPAS_WINDOWS}
  PATH_SEP = ';';
{$ELSE}
  PATH_SEP = ':';
{$ENDIF}

type
  TAnsiCharArray = array of AnsiChar;

function IsExecutable(const APath: PAnsiChar): Boolean;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := access(APath, 1{X_OK}) = 0;
{$ELSE}
  Result := platform_fs_is_file(APath);
{$ENDIF}
end;

function LoadPathEnv(out APath: TAnsiCharArray; out APathLen: Int32): Boolean;
begin
  Result := False;
  repeat
    if platform_env_get('PATH', nil, 0, APathLen) <> 0 then
      Exit;
    if APathLen <= 0 then
      Exit;
    SetLength(APath, APathLen + 1);
    if platform_env_get('PATH', @APath[0], Length(APath), APathLen) <> 0 then
      Exit;
  until APathLen < Length(APath);
  Result := True;
end;

function platform_which(const AName: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LCandidate: array[0..1023] of AnsiChar;
  LPathBuf: array of AnsiChar;
  LPathLen, I, LStart, LDirLen, LNameLen: Int32;
begin
  if (AName = nil) or (AName[0] = #0) then
    Exit(-1);

  LNameLen := 0;
  while AName[LNameLen] <> #0 do Inc(LNameLen);

  if platform_path_is_absolute(AName) then
  begin
    if IsExecutable(AName) then
    begin
      if LNameLen >= ABufLen then LNameLen := ABufLen - 1;
      Move(AName^, ABuf^, LNameLen);
      ABuf[LNameLen] := #0;
      Exit(LNameLen);
    end;
    Exit(-1);
  end;

  if not LoadPathEnv(LPathBuf, LPathLen) then
    Exit(-1);

  I := 0;
  while I <= LPathLen do
  begin
    LStart := I;
    while (I < LPathLen) and (LPathBuf[I] <> PATH_SEP) do
      Inc(I);
    LDirLen := I - LStart;
    Inc(I); // skip separator

    if LDirLen = 0 then Continue;
    if LDirLen + 1 + LNameLen >= 1024 then Continue;

    LPathBuf[LStart + LDirLen] := #0; // temporarily null-terminate dir
    platform_path_join(@LPathBuf[LStart], AName, @LCandidate[0], 1024);
    LPathBuf[LStart + LDirLen] := PATH_SEP; // restore

    if IsExecutable(@LCandidate[0]) then
    begin
      LDirLen := 0;
      while LCandidate[LDirLen] <> #0 do Inc(LDirLen);
      if LDirLen >= ABufLen then LDirLen := ABufLen - 1;
      Move(LCandidate[0], ABuf^, LDirLen);
      ABuf[LDirLen] := #0;
      Exit(LDirLen);
    end;
  end;

  if ABuf <> nil then ABuf[0] := #0;
  Result := -1;
end;

end.
