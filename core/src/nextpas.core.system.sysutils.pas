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
 *
 * Format delegates to nextpas.core.text.format.TextFormat (owner);
 * no RTL fallback — safe subset (%% %[-][0][width][.precision](s|d|u|x|X|f))
 * is the supported surface; extended specifiers are handled by the owner
 * where covered, otherwise raise via the text owner (thin facade).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.text.format;

type
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;
  TBytes = nextpas.core.base.TBytes;
  TStringArray = nextpas.core.base.TStringArray;

{ Text formatting }
function Format(const AFmt: string; const AArgs: array of const): string;
function CompareStr(const A, B: string): Integer;
function SameText(const A, B: string): Boolean;

{ Numeric conversion }
function IntToStr(const AValue: Int64): string;
function Int64ToStr(const AValue: Int64): string;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
function StrToInt(const AStr: string): Integer;
function StrToInt64(const AStr: string): Int64;
function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
function StrToIntDef(const AStr: string; const ADefault: Integer): Integer;
function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64;
function StrToFloat(const AStr: string): Double;
function FloatToStr(const AValue: Double): string;
function CurrToStr(const AValue: Currency): string;
function BoolToStr(const AValue: Boolean; const AUseBoolStrs: Boolean = False): string;

{ Bytes helpers (SysUtils-compat for tests / facades) }
function BytesOf(const AStr: string): TBytes;
function StringOf(const ABytes: TBytes): string;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; overload;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; overload;
function HexStr(const AValue: UInt64; const ADigits: Integer = 0): string; overload;
function HexStr(const AAddr: Pointer): string; overload;

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
function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime;

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
const
  PathDelim = {$IFDEF WINDOWS}'\'{$ELSE}'/'{$ENDIF};

function ExtractFilePath(const AFileName: string): string;
function ExtractFileName(const AFileName: string): string;
function ExtractFileExt(const AFileName: string): string;
function ExtractFileDir(const AFileName: string): string;
function ExtractFileDrive(const AFileName: string): string;
function ChangeFileExt(const AFileName, ANewExt: string): string;
function IncludeTrailingPathDelimiter(const APath: string): string;
function ExcludeTrailingPathDelimiter(const APath: string): string;
function ExpandFileName(const AFileName: string): string;
function GetTempDir: string; overload;
function GetTempDir(Global: Boolean): string; overload;

{ Working directory }
function GetCurrentDir: string;
function SetCurrentDir(const ADir: string): Boolean;

{ Command line }
function ParamCount: Integer;
function ParamStr(AIndex: Integer): string;

{ Environment }
function GetEnvironmentVariable(const AName: string): string;

{ Process }
function GetProcessID: SizeUInt;

{ Timing }
procedure Sleep(AMilliseconds: Cardinal);

{ Error handling }
function SysErrorMessage(AErrorCode: Integer): string;
function GetLastOSError: Integer;

{ Exception backtrace — thin pass-through over the RTL raiseframe chain,
  so diagnostics can print stack traces without direct SysUtils use. }
function ExceptAddr: Pointer;
function ExceptFrameCount: LongInt;
function ExceptFrameAt(const AIndex: LongInt): CodePointer;

implementation

uses
  SysUtils,
  nextpas.core.bytes.ops,
  nextpas.core.platform.error,
  nextpas.core.base.utils,
  nextpas.core.text.compare,
  nextpas.core.text.utils,
  nextpas.core.time;

{ Text formatting — thin delegate to text owner (no RTL fallback). }
function Format(const AFmt: string; const AArgs: array of const): string; inline;
begin
  Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);
end;

function SameText(const A, B: string): Boolean;
begin
  Result := nextpas.core.text.conv.SameText(A, B);
end;

function CompareStr(const A, B: string): Integer;
begin
  Result := nextpas.core.text.compare.TextCompare(A, B);
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

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
begin
  Result := nextpas.core.text.conv.IntToHex(AValue, ADigits);
end;

function StrToInt(const AStr: string): Integer;
begin
  Result := Integer(nextpas.core.text.conv.StrToInt(AStr));
end;

function StrToInt64(const AStr: string): Int64;
begin
  Result := nextpas.core.text.conv.StrToInt(AStr);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
begin
  Result := nextpas.core.text.conv.TryStrToInt(AStr, AValue);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
begin
  { 委托 text.conv：其 Val 语义接受 0x/$ 前缀与十进制，
    与 RTL SysUtils 仅十进制的行为存在差异（此处有意跟随 nextpas 语义）。 }
  Result := nextpas.core.text.conv.TryStrToInt64(AStr, AValue);
end;

function StrToIntDef(const AStr: string; const ADefault: Integer): Integer;
begin
  if not TryStrToInt(AStr, Result) then
    Result := ADefault;
end;

function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64;
begin
  if not TryStrToInt64(AStr, Result) then
    Result := ADefault;
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

function BoolToStr(const AValue: Boolean; const AUseBoolStrs: Boolean): string;
begin
  { SysUtils 语义：UseBoolStrs=True 输出 'True'/'False'，否则 '1'/'0'。 }
  if AUseBoolStrs then
    Result := nextpas.core.text.utils.BoolToStr(AValue)
  else if AValue then
    Result := '1'
  else
    Result := '0';
end;

function BytesOf(const AStr: string): TBytes; inline;
begin
  { single-source zero-copy: bytes.ops.StringToBytes = one Move, no temp string copy }
  Result := nextpas.core.bytes.ops.StringToBytes(AStr);
end;

function StringOf(const ABytes: TBytes): string; inline;
begin
  { single-source zero-copy: bytes.ops.BytesToString = one Move, no temp bytes copy }
  Result := nextpas.core.bytes.ops.BytesToString(ABytes);
end;

function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
begin
  Result := nextpas.core.base.utils.CompareMem(A, B, ASize);
end;

function Supports(const AInstance: TObject; const AIID: TGuid;
  out AIntf): Boolean;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid;
  out AIntf): Boolean;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

function HexStr(const AValue: UInt64; const ADigits: Integer): string;
begin
  Result := nextpas.core.base.HexStr(AValue, ADigits);
end;

function HexStr(const AAddr: Pointer): string;
begin
  Result := nextpas.core.base.HexStr(PtrUInt(AAddr), 0);
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

{ Date/Time — delegates to time owner (thin facade). }
function Now: TDateTime; inline;
begin
  Result := nextpas.core.time.DateTimeNow;
end;

function Date: TDateTime; inline;
begin
  Result := Trunc(nextpas.core.time.DateTimeNow);
end;

function Time: TDateTime; inline;
begin
  Result := Frac(nextpas.core.time.DateTimeNow);
end;

function DateTimeToStr(const AValue: TDateTime): string; inline;
begin
  Result := nextpas.core.time.DateTimeToStr(AValue);
end;

function DateToStr(const AValue: TDateTime): string; inline;
begin
  Result := nextpas.core.time.DateToStr(AValue);
end;

function TimeToStr(const AValue: TDateTime): string; inline;
begin
  Result := nextpas.core.time.FormatDateTime('%H:%M:%S', AValue);
end;

function FormatDateTime(const AFmt: string; AValue: TDateTime): string; inline;
begin
  Result := nextpas.core.time.FormatDateTime(AFmt, AValue);
end;

function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime;
const
  { 1899-12-30 的儒略日：与 RTL TDateTime epoch (0.0) 对齐
    （1900-01-01 = 2415021，前推两天）。 }
  DELPHI_EPOCH_JDN = 2415019;
var
  LDate: nextpas.core.time.TDate;
begin
  { RTL 兼容：1899-12-30 = 0.0。TDate 按儒略日计数，减 epoch 即
    RTL 口径的整日序号；年份 0..99 按字面值，不复刻 RTL 的
    1900+ 特例（调用方自行防御古老年份）。 }
  if not nextpas.core.time.TDate.TryCreate(AYear, AMonth, ADay, LDate) then
    raise EConvertError.CreateFmt('EncodeDate: invalid date %d-%d-%d',
      [AYear, AMonth, ADay]);
  Result := LDate.ToJulianDay - DELPHI_EPOCH_JDN;
end;

{ File system — delegates to SysUtils (L0: FPC RTL, avoids L2 fs) }

function FileExists(const AFileName: string): Boolean; inline;
begin
  Result := SysUtils.FileExists(AFileName);
end;

function DirectoryExists(const ADirectory: string): Boolean; inline;
begin
  Result := SysUtils.DirectoryExists(ADirectory);
end;

function CreateDir(const ADir: string): Boolean; inline;
begin
  Result := SysUtils.CreateDir(ADir);
end;

function RemoveDir(const ADir: string): Boolean; inline;
begin
  Result := SysUtils.RemoveDir(ADir);
end;

function ForceDirectories(const ADir: string): Boolean; inline;
begin
  Result := SysUtils.ForceDirectories(ADir);
end;

function DeleteFile(const AFileName: string): Boolean; inline;
begin
  Result := SysUtils.DeleteFile(AFileName);
end;

function RenameFile(const AOldName, ANewName: string): Boolean; inline;
begin
  Result := SysUtils.RenameFile(AOldName, ANewName);
end;

function CopyFile(const ASrcName, ADestName: string): Boolean;
var
  LSrc, LDst: File;
  LBuf: array[0..8191] of Byte;
  LRead, LWritten: LongInt;
begin
  // single-source copy via System file ops; no L2 fs dependency, resource-safe
  Result := False;
  if not SysUtils.FileExists(ASrcName) then Exit(False);
  AssignFile(LSrc, ASrcName);
  {$I-}
  Reset(LSrc, 1);
  if IOResult <> 0 then Exit(False);
  try
    AssignFile(LDst, ADestName);
    Rewrite(LDst, 1);
    if IOResult <> 0 then Exit(False);
    try
      repeat
        BlockRead(LSrc, LBuf, SizeOf(LBuf), LRead);
        if LRead > 0 then
        begin
          BlockWrite(LDst, LBuf, LRead, LWritten);
          if (IOResult <> 0) or (LWritten <> LRead) then Exit(False);
        end;
      until LRead = 0;
      Result := True;
    finally
      CloseFile(LDst);
    end;
  finally
    CloseFile(LSrc);
  end;
end;

{ Path manipulation — delegates to SysUtils (L0: FPC RTL, avoids L2 path) }

function ExtractFilePath(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExtractFilePath(AFileName);
end;

function ExtractFileName(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExtractFileName(AFileName);
end;

function ExtractFileExt(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExtractFileExt(AFileName);
end;

function ExtractFileDir(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExtractFileDir(AFileName);
end;

function ExtractFileDrive(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExtractFileDrive(AFileName);
end;

function ChangeFileExt(const AFileName, ANewExt: string): string; inline;
begin
  Result := SysUtils.ChangeFileExt(AFileName, ANewExt);
end;

function IncludeTrailingPathDelimiter(const APath: string): string; inline;
begin
  Result := SysUtils.IncludeTrailingPathDelimiter(APath);
end;

function ExcludeTrailingPathDelimiter(const APath: string): string; inline;
begin
  Result := SysUtils.ExcludeTrailingPathDelimiter(APath);
end;

function ExpandFileName(const AFileName: string): string; inline;
begin
  Result := SysUtils.ExpandFileName(AFileName);
end;

function GetTempDir: string; inline;
begin
  Result := SysUtils.GetTempDir;
  if (Result <> '') and (Result[Length(Result)] <> PathDelim) then
    Result := Result + PathDelim;
end;

function GetTempDir(Global: Boolean): string; inline;
begin
  // Global flag ignored — single temp root on SysUtils facade
  Result := GetTempDir;
end;

function GetProcessID: SizeUInt;
begin
  { FPC System owns GetProcessID; no BaseUnix/Windows in system facade. }
  Result := SizeUInt(System.GetProcessID);
end;

{ Working directory — delegates to SysUtils (L0: FPC RTL, avoids L2 fs) }

function GetCurrentDir: string; inline;
begin
  Result := SysUtils.GetCurrentDir;
end;

function SetCurrentDir(const ADir: string): Boolean; inline;
begin
  {$I-}
  ChDir(ADir);
  Result := IOResult = 0;
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

{ Environment — delegates to SysUtils (L0: FPC RTL, avoids Support os.env) }

function GetEnvironmentVariable(const AName: string): string; inline;
begin
  Result := SysUtils.GetEnvironmentVariable(AName);
end;

{ Timing — delegates to time owner (thin facade). }

procedure Sleep(AMilliseconds: Cardinal); inline;
begin
  nextpas.core.time.MsSleep(AMilliseconds);
end;

{ Error handling — delegates to platform.error owner (thin facade). }

function SysErrorMessage(AErrorCode: Integer): string;
var
  LBuf: array[0..255] of AnsiChar;
  LLen: Int32;
begin
  LLen := nextpas.core.platform.error.platform_error_message(AErrorCode, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBuf[0]), LLen)
  else if LLen = 0 then
    Result := ''
  else
    Result := 'unknown error ' + nextpas.core.text.conv.IntToStr(AErrorCode);
end;

function GetLastOSError: Integer; inline;
begin
  Result := nextpas.core.platform.error.platform_get_last_error();
end;

function ExceptAddr: Pointer; inline;
begin
  { single-source: owner nextpas.core.exception; inline zero-copy forward }
  Result := nextpas.core.exception.ExceptAddr;
end;

function ExceptFrameCount: LongInt; inline;
begin
  { single-source: owner nextpas.core.exception; inline zero-copy forward }
  Result := nextpas.core.exception.ExceptFrameCount;
end;

function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;
begin
  { single-source: owner nextpas.core.exception; inline with bounds guard, no exception loss }
  Result := nextpas.core.exception.ExceptFrameAt(AIndex);
end;

end.
