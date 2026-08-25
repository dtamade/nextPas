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
{ Format 无 inline：路由体含回退扫描，内联会把扫描器复制进每个调用点。 }
function Format(const AFmt: string; const AArgs: array of const): string;
function CompareStr(const A, B: string): Integer; inline;
function SameText(const A, B: string): Boolean; inline;

{ Numeric conversion }
function IntToStr(const AValue: Int64): string; inline;
function Int64ToStr(const AValue: Int64): string; inline;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string; inline;
function StrToInt(const AStr: string): Integer; inline;
function StrToInt64(const AStr: string): Int64; inline;
function TryStrToInt(const AStr: string; out AValue: Integer): Boolean; inline;
function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean; inline;
function StrToIntDef(const AStr: string; const ADefault: Integer): Integer; inline;
function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64; inline;
function StrToFloat(const AStr: string): Double; inline;
function FloatToStr(const AValue: Double): string; inline;
function CurrToStr(const AValue: Currency): string; inline;
function BoolToStr(const AValue: Boolean; const AUseBoolStrs: Boolean = False): string; inline;

{ Bytes helpers (SysUtils-compat for tests / facades) }
function BytesOf(const AStr: string): TBytes; inline;
function StringOf(const ABytes: TBytes): string; inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; overload; inline;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; overload; inline;

{ String manipulation }
function Trim(const AStr: string): string; inline;
function TrimLeft(const AStr: string): string; inline;
function TrimRight(const AStr: string): string; inline;
function UpperCase(const AStr: string): string; inline;
function LowerCase(const AStr: string): string; inline;

{ String search }
function Pos(const ASubStr, AStr: string): Integer; inline;

{ Date/Time }
function Now: TDateTime; inline;
function Date: TDateTime; inline;
function Time: TDateTime; inline;
function DateTimeToStr(const AValue: TDateTime): string; inline;
function DateToStr(const AValue: TDateTime): string; inline;
function TimeToStr(const AValue: TDateTime): string; inline;
function FormatDateTime(const AFmt: string; AValue: TDateTime): string; inline;
function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime; inline;

{ File system }
function FileExists(const AFileName: string): Boolean; inline;
function DirectoryExists(const ADirectory: string): Boolean; inline;
function CreateDir(const ADir: string): Boolean; inline;
function RemoveDir(const ADir: string): Boolean; inline;
function ForceDirectories(const ADir: string): Boolean; inline;
function DeleteFile(const AFileName: string): Boolean; inline;
function RenameFile(const AOldName, ANewName: string): Boolean; inline;
function CopyFile(const ASrcName, ADestName: string): Boolean; inline;

{ Path manipulation }
const
  PathDelim = {$IFDEF WINDOWS}'\'{$ELSE}'/'{$ENDIF};

function ExtractFilePath(const AFileName: string): string; inline;
function ExtractFileName(const AFileName: string): string; inline;
function ExtractFileExt(const AFileName: string): string; inline;
function ExtractFileDir(const AFileName: string): string; inline;
function ExtractFileDrive(const AFileName: string): string; inline;
function ChangeFileExt(const AFileName, ANewExt: string): string; inline;
function IncludeTrailingPathDelimiter(const APath: string): string; inline;
function ExcludeTrailingPathDelimiter(const APath: string): string; inline;
function ExpandFileName(const AFileName: string): string; inline;
function GetTempDir: string; overload; inline;
function GetTempDir(Global: Boolean): string; overload; inline;

{ Working directory }
function GetCurrentDir: string; inline;
function SetCurrentDir(const ADir: string): Boolean; inline;

{ Command line }
function ParamCount: Integer; inline;
function ParamStr(AIndex: Integer): string; inline;

{ Environment }
function GetEnvironmentVariable(const AName: string): string; inline;

{ Process }
function GetProcessID: SizeUInt; inline;

{ Timing }
procedure Sleep(AMilliseconds: Cardinal); inline;

{ Error handling }
function SysErrorMessage(AErrorCode: Integer): string; inline;
function GetLastOSError: Integer; inline;

{ Exception backtrace — thin pass-through over the RTL raiseframe chain,
  so diagnostics can print stack traces without direct SysUtils use. }
function ExceptAddr: Pointer; inline;
function ExceptFrameCount: LongInt; inline;
function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;

implementation

uses
  SysUtils,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.base.utils,
  nextpas.core.text.compare,
  nextpas.core.text.utils,
  nextpas.core.time;

{ Returns True when AFmt uses any specifier outside the TextFormat safe set
  (%% %[-][0][width][.precision](s|d|u|x|X|f), including %f with no explicit
  precision). Such format strings fall back to the RTL SysUtils implementation,
  whose printf-style surface (e/g/c/m/n/p, indexed args, dynamic * width, ...)
  TextFormat does not cover. }
function FormatNeedsSysUtilsFallback(const AFmt: string): Boolean; inline;
var
  LIdx, LLen: Integer;
begin
  Result := False;
  LLen := Length(AFmt);
  LIdx := 1;
  while LIdx <= LLen do
  begin
    if AFmt[LIdx] <> '%' then
    begin
      Inc(LIdx);
      Continue;
    end;
    Inc(LIdx);
    if LIdx > LLen then Exit(False);
    if AFmt[LIdx] = '%' then
    begin
      Inc(LIdx);
      Continue;
    end;
    if AFmt[LIdx] = '-' then Inc(LIdx);
    if (LIdx <= LLen) and (AFmt[LIdx] = '0') then Inc(LIdx);
    while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
      Inc(LIdx);
    if (LIdx <= LLen) and (AFmt[LIdx] = '.') then
    begin
      Inc(LIdx);
      while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
        Inc(LIdx);
    end;
    if LIdx > LLen then Exit(False);
    case AFmt[LIdx] of
      'd', 'u', 'x', 'X', 's', 'f': ;
    else
      Exit(True);
    end;
    Inc(LIdx);
  end;
end;

{ Text formatting }

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  if FormatNeedsSysUtilsFallback(AFmt) then
    Result := SysUtils.Format(AFmt, AArgs)
  else
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

function BytesOf(const AStr: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AStr));
  if Length(AStr) > 0 then
    Move(AStr[1], Result[0], Length(AStr));
end;

function StringOf(const ABytes: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
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

function ExpandFileName(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExpandFileName(AFileName);
end;

function GetTempDir: string;
begin
  Result := nextpas.core.fs.GetTempDir;
end;

function GetTempDir(Global: Boolean): string;
begin
  { Global flag ignored — single temp root on nextPas fs facade }
  Result := nextpas.core.fs.GetTempDir;
end;

function GetProcessID: SizeUInt;
begin
  { FPC System owns GetProcessID; no BaseUnix/Windows in system facade. }
  Result := SizeUInt(System.GetProcessID);
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

function ExceptAddr: Pointer;
begin
  Result := SysUtils.ExceptAddr;
end;

function ExceptFrameCount: LongInt;
begin
  Result := SysUtils.ExceptFrameCount;
end;

function ExceptFrameAt(const AIndex: LongInt): CodePointer;
begin
  Result := SysUtils.ExceptFrames[AIndex];
end;

end.
