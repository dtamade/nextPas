unit nextpas.core.system.sysutils;
{**
 * @desc SysUtils compatibility facade for nextPas system kernel.
 *
 * Provides exception formatting, text conversion helpers,
 * case-insensitive comparison, numeric parsing, file system checks,
 * path manipulation, and environment access.
 *
 * All functions delegate to nextpas.core modules — this unit is a
 * thin facade, not an implementation.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv;

type
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;

{ Text formatting }
function Format(const AFmt: string; const AArgs: array of const): string;
function SameText(const A, B: string): Boolean;

{ Numeric conversion }
function IntToStr(const AValue: Int64): string;
function Int64ToStr(const AValue: Int64): string;
function StrToInt(const AStr: string): Integer;
function StrToInt64(const AStr: string): Int64;
function StrToFloat(const AStr: string): Double;
function FloatToStr(const AValue: Double): string;
function CurrToStr(const AValue: Currency): string;

{ String manipulation }
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function UpperCase(const AStr: string): string;
function LowerCase(const AStr: string): string;

{ String search }
function Pos(const ASubStr, AStr: string): Integer;

{ Date/Time }
function Now: TDateTime;
function Date: TDateTime;
function Time: TDateTime;
function DateTimeToStr(const AValue: TDateTime): string;
function DateToStr(const AValue: TDateTime): string;
function TimeToStr(const AValue: TDateTime): string;
function FormatDateTime(const AFmt: string; AValue: TDateTime): string;

{ File system }
function FileExists(const AFileName: string): Boolean;
function DirectoryExists(const ADirectory: string): Boolean;
function CreateDir(const ADir: string): Boolean;
function RemoveDir(const ADir: string): Boolean;
function ForceDirectories(const ADir: string): Boolean;
function DeleteFile(const AFileName: string): Boolean;
function RenameFile(const AOldName, ANewName: string): Boolean;
function CopyFile(const ASrcName, ADestName: string): Boolean;

{ Path manipulation }
function ExtractFilePath(const AFileName: string): string;
function ExtractFileName(const AFileName: string): string;
function ExtractFileExt(const AFileName: string): string;
function ExtractFileDir(const AFileName: string): string;
function ExtractFileDrive(const AFileName: string): string;
function ChangeFileExt(const AFileName, ANewExt: string): string;
function IncludeTrailingPathDelimiter(const APath: string): string;
function ExcludeTrailingPathDelimiter(const APath: string): string;

{ Working directory }
function GetCurrentDir: string;
function SetCurrentDir(const ADir: string): Boolean;

{ Command line }
function ParamCount: Integer;
function ParamStr(AIndex: Integer): string;

{ Environment }
function GetEnvironmentVariable(const AName: string): string;

{ Timing }
procedure Sleep(AMilliseconds: Cardinal);

{ Error handling }
function SysErrorMessage(AErrorCode: Integer): string;
function GetLastOSError: Integer;

implementation

uses
  SysUtils,
  nextpas.core.path,
  nextpas.core.fs;

{ Text formatting }

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.conv.Format(AFmt, AArgs);
end;

function SameText(const A, B: string): Boolean;
begin
  Result := nextpas.core.text.conv.SameText(A, B);
end;

{ Numeric conversion }

function IntToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function Int64ToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function StrToInt(const AStr: string): Integer;
begin
  Result := Integer(nextpas.core.text.conv.StrToInt(AStr));
end;

function StrToInt64(const AStr: string): Int64;
begin
  Result := nextpas.core.text.conv.StrToInt(AStr);
end;

function StrToFloat(const AStr: string): Double;
begin
  Result := nextpas.core.text.conv.StrToFloat(AStr);
end;

function FloatToStr(const AValue: Double): string;
begin
  Result := nextpas.core.text.conv.FloatToStr(AValue);
end;

function CurrToStr(const AValue: Currency): string;
begin
  Result := nextpas.core.text.conv.FloatToStr(AValue);
end;

{ String manipulation }

function Trim(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.Trim(AStr);
end;

function TrimLeft(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.TrimLeft(AStr);
end;

function TrimRight(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.TrimRight(AStr);
end;

function UpperCase(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.UpperCase(AStr);
end;

function LowerCase(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.LowerCase(AStr);
end;

{ String search }

function Pos(const ASubStr, AStr: string): Integer;
begin
  Result := System.Pos(ASubStr, AStr);
end;

{ Date/Time — delegates to platform }

function Now: TDateTime;
begin
  Result := SysUtils.Now;
end;

function Date: TDateTime;
begin
  Result := SysUtils.Date;
end;

function Time: TDateTime;
begin
  Result := SysUtils.Time;
end;

function DateTimeToStr(const AValue: TDateTime): string;
begin
  Result := SysUtils.DateTimeToStr(AValue);
end;

function DateToStr(const AValue: TDateTime): string;
begin
  Result := SysUtils.DateToStr(AValue);
end;

function TimeToStr(const AValue: TDateTime): string;
begin
  Result := SysUtils.TimeToStr(AValue);
end;

function FormatDateTime(const AFmt: string; AValue: TDateTime): string;
begin
  Result := SysUtils.FormatDateTime(AFmt, AValue);
end;

{ File system — delegates to nextpas.core.fs }

function FileExists(const AFileName: string): Boolean;
begin
  Result := nextpas.core.fs.FileExists(AFileName);
end;

function DirectoryExists(const ADirectory: string): Boolean;
begin
  Result := nextpas.core.fs.DirectoryExists(ADirectory);
end;

function CreateDir(const ADir: string): Boolean;
begin
  Result := nextpas.core.fs.ForceDirectories(ADir);
end;

function RemoveDir(const ADir: string): Boolean;
begin
  Result := nextpas.core.fs.DeleteFile(ADir);
end;

function ForceDirectories(const ADir: string): Boolean;
begin
  Result := nextpas.core.fs.ForceDirectories(ADir);
end;

function DeleteFile(const AFileName: string): Boolean;
begin
  Result := nextpas.core.fs.DeleteFile(AFileName);
end;

function RenameFile(const AOldName, ANewName: string): Boolean;
begin
  Result := SysUtils.RenameFile(AOldName, ANewName);
end;

function CopyFile(const ASrcName, ADestName: string): Boolean;
begin
  Result := nextpas.core.fs.CopyFile(ASrcName, ADestName) >= 0;
end;

{ Path manipulation — delegates to nextpas.core.path }

function ExtractFilePath(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExtractFilePath(AFileName);
end;

function ExtractFileName(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExtractFileName(AFileName);
end;

function ExtractFileExt(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExtractFileExt(AFileName);
end;

function ExtractFileDir(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExtractFileDir(AFileName);
end;

function ExtractFileDrive(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExtractFileDrive(AFileName);
end;

function ChangeFileExt(const AFileName, ANewExt: string): string;
begin
  Result := nextpas.core.path.ChangeFileExt(AFileName, ANewExt);
end;

function IncludeTrailingPathDelimiter(const APath: string): string;
begin
  Result := nextpas.core.path.IncludeTrailingPathDelimiter(APath);
end;

function ExcludeTrailingPathDelimiter(const APath: string): string;
begin
  Result := nextpas.core.path.ExcludeTrailingPathDelimiter(APath);
end;

{ Working directory — delegates to platform }

function GetCurrentDir: string;
begin
  Result := SysUtils.GetCurrentDir;
end;

function SetCurrentDir(const ADir: string): Boolean;
begin
  Result := SysUtils.SetCurrentDir(ADir);
end;

{ Command line — delegates to System }

function ParamCount: Integer;
begin
  Result := System.ParamCount;
end;

function ParamStr(AIndex: Integer): string;
begin
  Result := System.ParamStr(AIndex);
end;

{ Environment — delegates to platform }

function GetEnvironmentVariable(const AName: string): string;
begin
  Result := SysUtils.GetEnvironmentVariable(AName);
end;

{ Timing — delegates to platform }

procedure Sleep(AMilliseconds: Cardinal);
begin
  SysUtils.Sleep(AMilliseconds);
end;

{ Error handling — delegates to SysUtils }

function SysErrorMessage(AErrorCode: Integer): string;
begin
  Result := SysUtils.SysErrorMessage(AErrorCode);
end;

function GetLastOSError: Integer;
begin
  Result := SysUtils.GetLastOSError;
end;

end.
