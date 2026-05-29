unit nextpas.core.fs.path;

{$I nextpas.core.settings.inc}

interface

function FsPathJoin(const AParts: array of string): string;
function FsPathDir(const APath: string): string;
function FsPathBase(const APath: string): string;
function FsPathExt(const APath: string): string;
function FsPathClean(const APath: string): string;
function FsPathAbs(const APath: string): string;
function FsPathIsAbs(const APath: string): Boolean;

implementation

uses
  nextpas.core.platform.path;

function FsPathJoin(const AParts: array of string): string;
var
  LBuf: array[0..4095] of AnsiChar;
  LI: Integer;
  LCurrent: string;
begin
  if Length(AParts) = 0 then
    Exit('');
  LCurrent := AParts[0];
  for LI := 1 to High(AParts) do
  begin
    if platform_path_join(PAnsiChar(LCurrent), PAnsiChar(AParts[LI]),
      @LBuf[0], SizeOf(LBuf)) > 0 then
      LCurrent := StrPas(@LBuf[0])
    else
      LCurrent := LCurrent + '/' + AParts[LI];
  end;
  Result := LCurrent;
end;

function FsPathDir(const APath: string): string;
var
  LBuf: array[0..4095] of AnsiChar;
begin
  if platform_path_dirname(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := StrPas(@LBuf[0])
  else
    Result := '.';
end;

function FsPathBase(const APath: string): string;
var
  LBuf: array[0..4095] of AnsiChar;
begin
  if platform_path_basename(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := StrPas(@LBuf[0])
  else
    Result := APath;
end;

function FsPathExt(const APath: string): string;
var
  LBuf: array[0..255] of AnsiChar;
begin
  if platform_path_extension(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := StrPas(@LBuf[0])
  else
    Result := '';
end;

function FsPathClean(const APath: string): string;
var
  LBuf: array[0..4095] of AnsiChar;
begin
  if platform_path_normalize(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := StrPas(@LBuf[0])
  else
    Result := APath;
end;

function FsPathAbs(const APath: string): string;
var
  LBuf: array[0..4095] of AnsiChar;
begin
  if platform_path_resolve(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := StrPas(@LBuf[0])
  else
    Result := APath;
end;

function FsPathIsAbs(const APath: string): Boolean;
begin
  Result := platform_path_is_absolute(PAnsiChar(APath));
end;

end.
