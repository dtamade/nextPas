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

{ String manipulation }
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function UpperCase(const AStr: string): string;
function LowerCase(const AStr: string): string;
function CompareText(const A, B: string): Integer;

{ String search }
function Pos(const ASubStr, AStr: string): Integer;
function PosEx(const ASubStr, AStr: string; const AFrom: Integer = 1): Integer;
function SplitString(const S, Delimiters: string): TStringArray;

{ Exception ownership }
{ 仅在 except 块内有效：取得当前异常对象并把引用计数 +1，块结束时不再自动释放，
  所有权转移给调用方（负责 Free）。FPC 该符号属 System（objpash.inc），不在 SysUtils。 }
function AcquireExceptionObject: Pointer;

{ Date/Time }
function Now: TDateTime;
function Date: TDateTime;
function Time: TDateTime;
function DateTimeToStr(const AValue: TDateTime): string;
function DateToStr(const AValue: TDateTime): string;
function TimeToStr(const AValue: TDateTime): string;
function FormatDateTime(const AFmt: string; AValue: TDateTime): string;
function UnixToDateTime(const AValue: Int64): TDateTime;

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
function ExecuteProcess(const APath, AParams: string): Integer;
{ 执行外部程序并等待退出:参数数组逐项传递(空格安全,不按空格拆分;
  stdin/stdout/stderr 接 /dev/null)。返回退出码;-1 = 启动失败/等待失败 }
function RunProcessWait(const APath: string;
  const AArgs: array of string): Integer;

{ Timing }
procedure Sleep(AMilliseconds: Cardinal);

{ Error handling }
function SysErrorMessage(AErrorCode: Integer): string;
function GetLastOSError: Integer;
{ 置空并释放对象(FPC SysUtils 语义,无类型 var 兼容任意对象变量) }
procedure FreeAndNil(var AObj);

implementation

uses
  SysUtils,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.base.utils,
  nextpas.core.text.compare,
  nextpas.core.text.utils,
  nextpas.core.time,
  nextpas.core.platform.process,
  nextpas.core.platform.process.base;

{ Text formatting }

function Format(const AFmt: string; const AArgs: array of const): string;
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
  SetLength(Result, Length(AStr));
  if Length(AStr) > 0 then
    Move(AStr[1], Result[0], Length(AStr));
end;

function StringOf(const ABytes: TBytes): string;
begin
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

function CompareText(const A, B: string): Integer;
begin
  { SysUtils 语义:ASCII 大小写折叠后序数比较;不能用 UCA collation(排序语义不同) }
  Result := nextpas.core.text.compare.TextCompareI(A, B);
end;

{ String search }

function Pos(const ASubStr, AStr: string): Integer;
begin
  Result := System.Pos(ASubStr, AStr);
end;

function PosEx(const ASubStr, AStr: string; const AFrom: Integer = 1): Integer;
var
  LI, LJ, LSubLen, LStrLen: Integer;
begin
  { StrUtils 语义：从 AFrom（1-based）起查找；空子串在有效范围内命中 AFrom。 }
  LSubLen := Length(ASubStr);
  LStrLen := Length(AStr);
  Result := 0;
  if AFrom < 1 then
    Exit;
  if LSubLen = 0 then
  begin
    if AFrom <= LStrLen + 1 then
      Result := AFrom;
    Exit;
  end;
  if AFrom > LStrLen - LSubLen + 1 then
    Exit;
  for LI := AFrom to LStrLen - LSubLen + 1 do
  begin
    LJ := 1;
    while (LJ <= LSubLen) and (AStr[LI + LJ - 1] = ASubStr[LJ]) do
      Inc(LJ);
    if LJ > LSubLen then
      Exit(LI);
  end;
end;

function AcquireExceptionObject: Pointer;
begin
  { FPC 3.3.x 起该符号从 SysUtils 移入 System：SysUtils 限定调用失效
    （RTL 漂移实测），显式 System 限定避免依赖隐式解析域。 }
  Result := System.AcquireExceptionObject;
end;

function SplitString(const S, Delimiters: string): TStringArray;
var
  I, Start, Count: Integer;
begin
  { SysUtils 语义：按 Delimiters 中任意字符切分，连续分隔符不产生空段。 }
  SetLength(Result, 0);
  Count := 0;
  Start := 1;
  for I := 1 to Length(S) do
    if System.Pos(S[I], Delimiters) > 0 then
    begin
      if I > Start then
      begin
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1] := System.Copy(S, Start, I - Start);
      end;
      Start := I + 1;
    end;
  if Start <= Length(S) then
  begin
    Inc(Count);
    SetLength(Result, Count);
    Result[Count - 1] := System.Copy(S, Start, Length(S) - Start + 1);
  end;
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

function UnixToDateTime(const AValue: Int64): TDateTime;
begin
  Result := nextpas.core.time.UnixToDateTime(AValue);
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

function ExecuteProcess(const APath, AParams: string): Integer;
begin
  Result := SysUtils.ExecuteProcess(APath, AParams);
end;

function RunProcessWait(const APath: string;
  const AArgs: array of string): Integer;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LArgv: array of PAnsiChar;
  LResult: TPlatformProcessResult;
  LI, LErr: Integer;
begin
  Result := -1;
  SetLength(LArgv, Length(AArgs) + 2);
  { POSIX argv 惯例:argv[0] 必须是程序名,否则 -c 等参数整体错位 }
  LArgv[0] := PAnsiChar(APath);
  for LI := 0 to High(AArgs) do
    LArgv[LI + 1] := PAnsiChar(AArgs[LI]);
  LArgv[Length(AArgs) + 1] := nil;
  { [] 选项:子进程 stdin/stdout/stderr 全部接 /dev/null,无管道不阻塞 }
  if platform_process_create_piped(PAnsiChar(APath), @LArgv[0], nil, [],
      LProc, LPipes) <> 0 then Exit;
  try
    platform_process_close_handle(LPipes.StdinWrite);
    platform_process_close_handle(LPipes.StdoutRead);
    platform_process_close_handle(LPipes.StderrRead);
    LErr := platform_process_wait(LProc, LResult, 30000);
    if LErr <> 0 then Exit;
    Result := LResult.ExitCode;
  finally
    platform_process_close_handle(LPipes.StdinWrite);
    platform_process_close_handle(LPipes.StdoutRead);
    platform_process_close_handle(LPipes.StderrRead);
  end;
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

procedure FreeAndNil(var AObj);
begin
  nextpas.core.base.utils.FreeAndNil(AObj);
end;

end.
