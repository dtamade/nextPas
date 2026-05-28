unit nextpas.core.fpc.sysutils;

{$I nextpas.core.settings.inc}

interface

{ --- Types and Constants --- }

type
  TFileName = type string;
  TReplaceFlags = set of (rfReplaceAll, rfIgnoreCase);

const
{$IFDEF NEXTPAS_WINDOWS}
  PathDelim = '\';
  DriveDelim = ':';
  PathSep = ';';
  LineEnding = #13#10;
{$ELSE}
  PathDelim = '/';
  DriveDelim = '';
  PathSep = ':';
  LineEnding = #10;
{$ENDIF}

  faReadOnly   = $00000001;
  faHidden     = $00000002;
  faSysFile    = $00000004;
  faDirectory  = $00000010;
  faArchive    = $00000020;
  faNormal     = $00000080;
  faSymLink    = $00000400;
  faAnyFile    = $000001FF;

  fmOpenRead       = $0000;
  fmOpenWrite      = $0001;
  fmOpenReadWrite  = $0002;

{ --- String Functions --- }

function UpperCase(const S: string): string;
function LowerCase(const S: string): string;
function CompareStr(const S1, S2: string): Integer;
function CompareText(const S1, S2: string): Integer;
function SameText(const S1, S2: string): Boolean;
function SameStr(const S1, S2: string): Boolean;
function Trim(const S: string): string;
function TrimLeft(const S: string): string;
function TrimRight(const S: string): string;

{ --- Integer/String Conversion --- }

function IntToStr(Value: Longint): string; overload;
function IntToStr(Value: Int64): string; overload;
function IntToHex(Value: Int64; Digits: Integer): string;
function StrToInt(const S: string): Longint;
function StrToInt64(const S: string): Int64;
function TryStrToInt(const S: string; out Value: Longint): Boolean;
function TryStrToInt64(const S: string; out Value: Int64): Boolean;
function StrToIntDef(const S: string; Default: Longint): Longint;
function StrToInt64Def(const S: string; Default: Int64): Int64;

{ --- File Name Manipulation --- }

function ExtractFilePath(const FileName: string): string;
function ExtractFileDir(const FileName: string): string;
function ExtractFileName(const FileName: string): string;
function ExtractFileExt(const FileName: string): string;
function ChangeFileExt(const FileName, Extension: string): string;
function ExpandFileName(const FileName: string): string;
function IncludeTrailingPathDelimiter(const Path: string): string;
function ExcludeTrailingPathDelimiter(const Path: string): string;
function ConcatPaths(const Paths: array of string): string;

{ --- File System --- }

function FileExists(const FileName: string): Boolean;
function DirectoryExists(const Directory: string): Boolean;
function DeleteFile(const FileName: string): Boolean;
function RenameFile(const OldName, NewName: string): Boolean;
function ForceDirectories(const Dir: string): Boolean;

{ --- OS Utilities --- }

function GetEnvironmentVariable(const EnvVar: string): string;
procedure Sleep(Milliseconds: Cardinal);
function GetTempDir: string;

implementation

uses
  nextpas.core.platform.fmt,
  nextpas.core.platform.path,
  nextpas.core.platform.fs,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.env,
  nextpas.core.platform.thread;

{ --- String Functions --- }

function UpperCase(const S: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (S[I] >= 'a') and (S[I] <= 'z') then
      Result[I] := Chr(Ord(S[I]) - 32)
    else
      Result[I] := S[I];
end;

function LowerCase(const S: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (S[I] >= 'A') and (S[I] <= 'Z') then
      Result[I] := Chr(Ord(S[I]) + 32)
    else
      Result[I] := S[I];
end;

function CompareStr(const S1, S2: string): Integer;
var
  I, L1, L2, LMin: Integer;
begin
  L1 := Length(S1);
  L2 := Length(S2);
  LMin := L1;
  if L2 < LMin then LMin := L2;
  for I := 1 to LMin do
  begin
    Result := Ord(S1[I]) - Ord(S2[I]);
    if Result <> 0 then Exit;
  end;
  Result := L1 - L2;
end;

function CompareText(const S1, S2: string): Integer;
var
  I, L1, L2, LMin: Integer;
  C1, C2: Byte;
begin
  L1 := Length(S1);
  L2 := Length(S2);
  LMin := L1;
  if L2 < LMin then LMin := L2;
  for I := 1 to LMin do
  begin
    C1 := Ord(S1[I]);
    C2 := Ord(S2[I]);
    if (C1 >= Ord('A')) and (C1 <= Ord('Z')) then Inc(C1, 32);
    if (C2 >= Ord('A')) and (C2 <= Ord('Z')) then Inc(C2, 32);
    Result := C1 - C2;
    if Result <> 0 then Exit;
  end;
  Result := L1 - L2;
end;

function SameText(const S1, S2: string): Boolean;
begin
  Result := platform_str_equal_nocase(PAnsiChar(S1), Length(S1),
    PAnsiChar(S2), Length(S2));
end;

function SameStr(const S1, S2: string): Boolean;
begin
  Result := S1 = S2;
end;

function Trim(const S: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] <= ' ') do Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] <= ' ') do Dec(LEnd);
  Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function TrimLeft(const S: string): string;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] <= ' ') do Inc(I);
  Result := Copy(S, I, Length(S) - I + 1);
end;

function TrimRight(const S: string): string;
var
  I: Integer;
begin
  I := Length(S);
  while (I > 0) and (S[I] <= ' ') do Dec(I);
  Result := Copy(S, 1, I);
end;

{ --- Integer/String Conversion --- }

function IntToStr(Value: Longint): string;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(Int64(Value), @Buf[0], 32);
  Result := Buf;
end;

function IntToStr(Value: Int64): string;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(Value, @Buf[0], 32);
  Result := Buf;
end;

function IntToHex(Value: Int64; Digits: Integer): string;
var
  Buf: array[0..15] of AnsiChar;
  LLen, I: Integer;
begin
  platform_fmt_hex(UInt64(Value), @Buf[0], 16);
  LLen := 0;
  while Buf[LLen] <> #0 do Inc(LLen);
  if Digits > LLen then
  begin
    SetLength(Result, Digits);
    for I := 1 to Digits - LLen do
      Result[I] := '0';
    Move(Buf[0], Result[Digits - LLen + 1], LLen);
  end
  else
    Result := PAnsiChar(@Buf[0]);
end;

{ PLACEHOLDER_IMPL_CONTINUE }

function StrToInt(const S: string): Longint;
var V: Int64;
begin
  if platform_parse_int(PAnsiChar(S), Length(S), V) <> 0 then
    RunError(106);
  Result := Longint(V);
end;

function StrToInt64(const S: string): Int64;
begin
  if platform_parse_int(PAnsiChar(S), Length(S), Result) <> 0 then
    RunError(106);
end;

function TryStrToInt(const S: string; out Value: Longint): Boolean;
var V: Int64;
begin
  Result := platform_parse_int(PAnsiChar(S), Length(S), V) = 0;
  if Result then
    Value := Longint(V)
  else
    Value := 0;
end;

function TryStrToInt64(const S: string; out Value: Int64): Boolean;
begin
  Result := platform_parse_int(PAnsiChar(S), Length(S), Value) = 0;
  if not Result then Value := 0;
end;

function StrToIntDef(const S: string; Default: Longint): Longint;
begin
  if not TryStrToInt(S, Result) then
    Result := Default;
end;

function StrToInt64Def(const S: string; Default: Int64): Int64;
begin
  if not TryStrToInt64(S, Result) then
    Result := Default;
end;

{ --- File Name Manipulation --- }

function ExtractFilePath(const FileName: string): string;
var Buf: array[0..1023] of AnsiChar;
begin
  platform_path_dirname(PAnsiChar(FileName), @Buf[0], 1024);
  Result := IncludeTrailingPathDelimiter(Buf);
end;

function ExtractFileDir(const FileName: string): string;
var Buf: array[0..1023] of AnsiChar;
begin
  platform_path_dirname(PAnsiChar(FileName), @Buf[0], 1024);
  Result := Buf;
end;

function ExtractFileName(const FileName: string): string;
var Buf: array[0..255] of AnsiChar;
begin
  platform_path_basename(PAnsiChar(FileName), @Buf[0], 256);
  Result := Buf;
end;

function ExtractFileExt(const FileName: string): string;
var Buf: array[0..63] of AnsiChar;
begin
  platform_path_extension(PAnsiChar(FileName), @Buf[0], 64);
  Result := Buf;
end;

function ChangeFileExt(const FileName, Extension: string): string;
var Buf: array[0..1023] of AnsiChar;
begin
  platform_path_change_ext(PAnsiChar(FileName), PAnsiChar(Extension),
    @Buf[0], 1024);
  Result := Buf;
end;

function ExpandFileName(const FileName: string): string;
var Buf: array[0..4095] of AnsiChar;
begin
  if platform_path_resolve(PAnsiChar(FileName), @Buf[0], 4096) >= 0 then
    Result := Buf
  else
    Result := FileName;
end;

function IncludeTrailingPathDelimiter(const Path: string): string;
var Buf: array[0..1023] of AnsiChar;
begin
  platform_path_ensure_sep(PAnsiChar(Path), @Buf[0], 1024);
  Result := Buf;
end;

function ExcludeTrailingPathDelimiter(const Path: string): string;
var L: Integer;
begin
  Result := Path;
  L := Length(Result);
  if (L > 0) and ((Result[L] = '/') or (Result[L] = '\')) then
    SetLength(Result, L - 1);
end;

function ConcatPaths(const Paths: array of string): string;
var
  Buf: array[0..1023] of AnsiChar;
  I: Integer;
begin
  if Length(Paths) = 0 then Exit('');
  Result := Paths[0];
  for I := 1 to High(Paths) do
  begin
    platform_path_join(PAnsiChar(Result), PAnsiChar(Paths[I]), @Buf[0], 1024);
    Result := Buf;
  end;
end;

{ --- File System --- }

function FileExists(const FileName: string): Boolean;
begin
  Result := platform_fs_is_file(PAnsiChar(FileName));
end;

function DirectoryExists(const Directory: string): Boolean;
begin
  Result := platform_fs_is_dir(PAnsiChar(Directory));
end;

function DeleteFile(const FileName: string): Boolean;
begin
  Result := platform_file_unlink(PAnsiChar(FileName)) = 0;
end;

function RenameFile(const OldName, NewName: string): Boolean;
begin
  Result := platform_file_rename(PAnsiChar(OldName), PAnsiChar(NewName)) = 0;
end;

function ForceDirectories(const Dir: string): Boolean;
begin
  Result := platform_fs_mkdir_p(PAnsiChar(Dir), 493) = 0;
end;

{ --- OS Utilities --- }

function GetEnvironmentVariable(const EnvVar: string): string;
var
  Buf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  if platform_env_get(PAnsiChar(EnvVar), @Buf[0], 4096, LLen) = 0 then
    Result := Buf
  else
    Result := '';
end;

procedure Sleep(Milliseconds: Cardinal);
begin
  platform_thread_sleep_ns(UInt64(Milliseconds) * 1000000);
end;

function GetTempDir: string;
var Buf: array[0..511] of AnsiChar;
begin
  if platform_fs_temp_dir(@Buf[0], 512) > 0 then
    Result := IncludeTrailingPathDelimiter(Buf)
  else
    Result := '/tmp/';
end;

end.

