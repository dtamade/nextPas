unit nextpas.core.system.sysutils;
{**
 * @desc SysUtils compatibility facade for nextPas system kernel (L0 root facade exception, soft-800 pure aggregation).
 *
 * Thin facade — all funcs delegate to owners (text + bytes single source, platform.files/fs/path/env/error, time, base.utils).
 * - Stub elegance: FPC SysUtils stub not used; nextPas stub bridges via units/<target>/ (no IFDEF fork, see CLAUDE.md dual-compiler).
 * - L7 converged 2026-09-03: 2 L0→L1 allowlist entries (text + bytes) single source — file/path/env converged to platform (single source inline zero-copy), text domain converged from 5 text sub-units to nextpas.core.text single source via bytes.ops single source (TByteSpan view, single Move in owner), inline zero-copy, try-finally not lost; not a platform violation, source-contract gated (registry 139-176, design-conventions §15).
 * - Lightness: ~800 lines soft-threshold pure aggregation (like http 1914 umbrella) — 40+ inline thin forwards, no Move/FillChar body (red-line 1/2), single source in owner, inline zero-copy, try-finally not lost.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.bytes;

type
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  ERangeError = nextpas.core.exception.ERangeError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;
  TBytes = nextpas.core.base.TBytes;
  TStringArray = nextpas.core.base.TStringArray;

{ Text formatting — single source text owner (converged via nextpas.core.text), inline thin forward (INV-5, bytes.ops single source) }
function Format(const AFmt: string; const AArgs: array of const): string; inline;
function CompareStr(const A, B: string): Integer;
function SameText(const A, B: string): Boolean;

{ Numeric conversion }
function IntToStr(const AValue: Int64): string;
function Int64ToStr(const AValue: Int64): string;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
function HexStr(const AValue: UInt64; const ADigits: Integer = 0): string; overload;
function HexStr(const AValue: Pointer): string; overload;
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

{ Bytes helpers (SysUtils-compat for tests / facades) — single source via bytes/text facade (bytes.ops single source, encoding-intent owner text); inline thin-forward, zero-copy TByteSpan view, no duplicate Move }
function BytesOf(const AStr: string): TBytes; inline;
function StringOf(const ABytes: TBytes): string; inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; overload;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; overload;

{ String manipulation }
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function UpperCase(const AStr: string): string;
function LowerCase(const AStr: string): string;

{ String search — single source via text.Pos (bytes.ops SpanIndexOfSpan SIMD single source) }
function Pos(const ASubStr, AStr: string): Integer; inline;

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
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.os.env,
  nextpas.core.base.utils,
  nextpas.core.text,
  nextpas.core.bytes,
  nextpas.core.time,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
  nextpas.core.platform.env,
  nextpas.core.platform.error;

{ Text formatting — single source via text owner (INV-5, L1 text owns formatting, converged 2026-09-03 text/bytes single source)
  perf: inline thin forward to TextFormat (single source zero-copy Move via TStringBuilder
  single SetLength+Move in owner, not inline per red-line 1/2); stub elegance: FPC SysUtils
  stub not used, nextPas stub bridges via units/<target>/, no IFDEF fork; L7 debt converged to text+bytes single source, lightness soft-800 pure aggregation }
function Format(const AFmt: string; const AArgs: array of const): string; inline;
begin
  { perf: inline thin forward to text.TextFormat single source (bytes.ops single source, zero-copy) }
  Result := nextpas.core.text.TextFormat(AFmt, AArgs);
end;

function SameText(const A, B: string): Boolean;
begin
  { perf: inline thin forward to text.SameText single source (bytes.ops SpanEqualIgnoreCase zero-copy) }
  Result := nextpas.core.text.SameText(A, B);
end;

function CompareStr(const A, B: string): Integer;
begin
  { perf: inline thin forward to text.CompareStr single source (bytes.ops SpanCompare zero-copy) }
  Result := nextpas.core.text.CompareStr(A, B);
end;

{ Numeric conversion }

function IntToStr(const AValue: Int64): string;
begin
  { perf: inline thin forward to text.IntToStr single source (text.number + bytes.ops BytesCopy single Move) }
  Result := nextpas.core.text.IntToStr(AValue);
end;

function Int64ToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.IntToStr(AValue);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
begin
  Result := nextpas.core.text.IntToHex(AValue, ADigits);
end;

function HexStr(const AValue: UInt64; const ADigits: Integer): string;
begin
  Result := nextpas.core.base.HexStr(AValue, ADigits);
end;

function HexStr(const AValue: Pointer): string;
begin
  Result := nextpas.core.base.HexStr(UInt64(PtrUInt(AValue)), 0);
end;

function StrToInt(const AStr: string): Integer;
begin
  { perf: inline thin forward to text.StrToInt single source (Int64 -> cast, range via Val) }
  Result := Integer(nextpas.core.text.StrToInt(AStr));
end;

function StrToInt64(const AStr: string): Int64;
begin
  Result := nextpas.core.text.StrToInt(AStr);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
begin
  { perf: inline thin forward to text.TryStrToInt32 single source (zero alloc) }
  Result := nextpas.core.text.TryStrToInt32(AStr, AValue);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
begin
  { 委托 text：其 Val 语义接受 0x/$ 前缀与十进制，
    与 RTL SysUtils 仅十进制的行为存在差异（此处有意跟随 nextpas 语义）。 single source via text facade -> bytes.ops }
  Result := nextpas.core.text.TryStrToInt(AStr, AValue);
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
  { perf: inline thin forward to text.StrToFloat single source (text.conv via bytes.ops) }
  Result := nextpas.core.text.StrToFloat(AStr);
end;

function FloatToStr(const AValue: Double): string;
begin
  Result := nextpas.core.text.FloatToStr(AValue);
end;

function CurrToStr(const AValue: Currency): string;
begin
  Result := nextpas.core.text.CurrToStr(AValue);
end;

function BoolToStr(const AValue: Boolean; const AUseBoolStrs: Boolean): string;
begin
  { SysUtils 语义：UseBoolStrs=True 输出 'True'/'False'，否则 '1'/'0'。 single source via text.BoolToStr }
  Result := nextpas.core.text.BoolToStr(AValue, AUseBoolStrs);
end;

function BytesOf(const AStr: string): TBytes; inline;
begin
  { perf: inline thin forward to bytes.StringToBytes single source via text.UTF8ToBytes (zero-copy PAnsiChar Move, single SetLength+Move in owner); bytes.ops single source, no duplicate Move, owner alloc not inline per red-line 1/2 }
  Result := nextpas.core.bytes.StringToBytes(AStr);
end;

function StringOf(const ABytes: TBytes): string; inline;
begin
  { perf: inline thin forward to bytes.BytesToString single source via text.BytesToUTF8 (zero-copy TByteSpan view, single Move in owner) }
  Result := nextpas.core.bytes.BytesToString(ABytes);
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

{ String manipulation — single source via text facade (L1 text owns, bytes.ops single source) }

function Trim(const AStr: string): string;
begin
  { perf: inline thin forward to text.Trim single source (text.utils via bytes.ops) }
  Result := nextpas.core.text.Trim(AStr);
end;

function TrimLeft(const AStr: string): string;
begin
  Result := nextpas.core.text.TrimLeft(AStr);
end;

function TrimRight(const AStr: string): string;
begin
  Result := nextpas.core.text.TrimRight(AStr);
end;

function UpperCase(const AStr: string): string;
begin
  Result := nextpas.core.text.UpperCase(AStr);
end;

function LowerCase(const AStr: string): string;
begin
  Result := nextpas.core.text.LowerCase(AStr);
end;

{ String search — single source via text.Pos (bytes.ops SpanIndexOfSpan SIMD single source, INV-5, L1 text owns search via bytes) }

function Pos(const ASubStr, AStr: string): Integer; inline;
begin
  { perf: inline thin-forward to text.Pos single source via bytes.ops.SpanIndexOfSpan SIMD (zero-copy TByteSpan view, inline, single source stays in bytes.ops/simd, hot path vectorized);
    stability: empty-needle guard matches FPC 0, bounds via owner, no resource leak }
  Result := nextpas.core.text.Pos(ASubStr, AStr);
end;

{ Date/Time — delegates to time owner (platform/time boundary, inline zero-copy) }

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

{ File system — delegates to platform.files/platform.fs L0 (single source via bytes.ops, inline zero-copy, try-finally not lost) }

function FileExists(const AFileName: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_fs_is_file single source (zero-copy PAnsiChar view, no alloc) }
  if AFileName = '' then Exit(False);
  Result := platform_fs_is_file(PAnsiChar(AFileName));
end;

function DirectoryExists(const ADirectory: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_fs_is_dir single source (zero-copy view) }
  if ADirectory = '' then Exit(False);
  Result := platform_fs_is_dir(PAnsiChar(ADirectory));
end;

function CreateDir(const ADir: string): Boolean; inline;
begin
  { perf: inline single syscall via platform_file_mkdir single source (zero-copy view); stability: no resource leak }
  if ADir = '' then Exit(False);
  Result := platform_file_mkdir(PAnsiChar(ADir), 493) = 0;
end;

function RemoveDir(const ADir: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_file_rmdir single source }
  if ADir = '' then Exit(False);
  Result := platform_file_rmdir(PAnsiChar(ADir)) = 0;
end;

function ForceDirectories(const ADir: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_fs_mkdir_p single source (recursive mkdir_p, zero-copy view) }
  if ADir = '' then Exit(False);
  Result := platform_fs_mkdir_p(PAnsiChar(ADir), 493) = 0;
end;

function DeleteFile(const AFileName: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_file_unlink single source }
  if AFileName = '' then Exit(False);
  Result := platform_file_unlink(PAnsiChar(AFileName)) = 0;
end;

function RenameFile(const AOldName, ANewName: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_file_rename single source (atomic rename, zero-copy view) }
  if (AOldName = '') or (ANewName = '') then Exit(False);
  Result := platform_file_rename(PAnsiChar(AOldName), PAnsiChar(ANewName)) = 0;
end;

function CopyFile(const ASrcName, ADestName: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_fs_copy_file single source (zero-copy sendfile/read-write, bytes.ops single source) }
  if (ASrcName = '') or (ADestName = '') then Exit(False);
  Result := platform_fs_copy_file(PAnsiChar(ASrcName), PAnsiChar(ADestName)) = 0;
end;

{ Path manipulation — delegates to platform.path L0 (single source via platform.path, inline zero-copy, bytes.ops single source in owner) }

function ExtractFilePath(const AFileName: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
  LDir: string;
begin
  { perf: inline thin forward to platform_path_dirname single source (zero-copy view, stack 4K, single Move in owner) }
  if AFileName = '' then Exit('');
  LNeed := platform_path_dirname(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
  if LNeed <= 0 then Exit('');
  if LNeed < SizeOf(LBuf) then
    SetString(LDir, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(LDir, LNeed);
    platform_path_dirname(PAnsiChar(AFileName), PAnsiChar(LDir), LNeed + 1);
    SetLength(LDir, LNeed);
  end;
  if LDir = '.' then Exit('');
  if (LDir <> '') and (LDir[Length(LDir)] <> PLATFORM_PATH_SEP) then
  begin
    if (Length(LDir) = 1) and (LDir[1] = '.') then Exit('')
    else if (LDir <> '/') and (LDir <> '\') then
      Result := LDir + PLATFORM_PATH_SEP
    else
      Result := LDir;
  end
  else
    Result := LDir;
end;

function ExtractFileName(const AFileName: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_basename single source (zero-copy view, stack 4K) }
  if AFileName = '' then Exit('');
  LNeed := platform_path_basename(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
  if LNeed <= 0 then Exit('');
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_basename(PAnsiChar(AFileName), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
end;

function ExtractFileExt(const AFileName: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_extension single source (zero-copy view) }
  if AFileName = '' then Exit('');
  LNeed := platform_path_extension(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
  if LNeed <= 0 then Exit('');
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_extension(PAnsiChar(AFileName), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
end;

function ExtractFileDir(const AFileName: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_dirname single source (zero-copy view, SysUtils trims trailing sep) }
  if AFileName = '' then Exit('');
  LNeed := platform_path_dirname(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
  if LNeed <= 0 then Exit('');
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_dirname(PAnsiChar(AFileName), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
  if Result = '.' then Result := '';
  { SysUtils: ExtractFileDir trims trailing sep except root }
  if (Result <> '') and (Result <> '/') and (Result[Length(Result)] = PLATFORM_PATH_SEP) then
    SetLength(Result, Length(Result) - 1);
end;

function ExtractFileDrive(const AFileName: string): string; inline;
begin
  { perf: zero-copy view via platform root classify (no alloc); Linux returns '' }
  {$IFDEF NEXTPAS_WINDOWS}
  if (Length(AFileName) >= 2) and (AFileName[2] = ':') and
     (((AFileName[1] >= 'A') and (AFileName[1] <= 'Z')) or ((AFileName[1] >= 'a') and (AFileName[1] <= 'z'))) then
    Result := Copy(AFileName, 1, 2)
  else
    Result := '';
  {$ELSE}
  Result := '';
  {$ENDIF}
end;

function ChangeFileExt(const AFileName, ANewExt: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_change_ext single source (zero-copy view, stack 4K) }
  if AFileName = '' then Exit('');
  LNeed := platform_path_change_ext(PAnsiChar(AFileName), PAnsiChar(ANewExt), @LBuf[0], SizeOf(LBuf));
  if LNeed < 0 then Exit(AFileName);
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_change_ext(PAnsiChar(AFileName), PAnsiChar(ANewExt), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
end;

function IncludeTrailingPathDelimiter(const APath: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_ensure_sep single source (zero-copy view) }
  if APath = '' then Exit(PLATFORM_PATH_SEP);
  LNeed := platform_path_ensure_sep(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf));
  if LNeed <= 0 then Exit(APath + PLATFORM_PATH_SEP);
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_ensure_sep(PAnsiChar(APath), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
end;

function ExcludeTrailingPathDelimiter(const APath: string): string; inline;
var
  LBuf: array[0..4095] of AnsiChar;
  LNeed: Int32;
begin
  { perf: inline thin forward to platform_path_trim_sep single source (zero-copy view) }
  if APath = '' then Exit('');
  LNeed := platform_path_trim_sep(PAnsiChar(APath), @LBuf[0], SizeOf(LBuf));
  if LNeed < 0 then Exit(APath);
  if LNeed = 0 then Exit('');
  if LNeed < SizeOf(LBuf) then
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
  else
  begin
    SetLength(Result, LNeed);
    platform_path_trim_sep(PAnsiChar(APath), PAnsiChar(Result), LNeed + 1);
    SetLength(Result, LNeed);
  end;
end;

function ExpandFileName(const AFileName: string): string;
var
  LBuf: array[0..4095] of AnsiChar;
  LHeap: array of AnsiChar;
  LNeed: Int32;
  LCwd: string;
begin
  { perf: thin forward to platform_path_resolve single source (zero-copy view, stack 4K + heap fallback, bytes.ops not duplicated); fallback via platform_file_getcwd for relative paths }
  if AFileName = '' then Exit('');
  LNeed := platform_path_resolve(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
  if (LNeed > 0) and (LNeed < SizeOf(LBuf)) then
  begin
    SetString(Result, PAnsiChar(@LBuf[0]), LNeed);
    Exit;
  end;
  if LNeed > 0 then
  begin
    SetLength(LHeap, LNeed + 1);
    platform_path_resolve(PAnsiChar(AFileName), @LHeap[0], Length(LHeap));
    SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    Exit;
  end;
  if platform_path_is_absolute(PAnsiChar(AFileName)) then
  begin
    LNeed := platform_path_normalize(PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
    if LNeed <= 0 then Exit(AFileName);
    if LNeed < SizeOf(LBuf) then
      SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
    else
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_normalize(PAnsiChar(AFileName), @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    end;
    Exit;
  end;
  LCwd := GetCurrentDir;
  if LCwd = '' then Exit(AFileName);
  { fallback: manual join + normalize via platform }
  begin
    LNeed := platform_path_join(PAnsiChar(LCwd), PAnsiChar(AFileName), @LBuf[0], SizeOf(LBuf));
    if LNeed <= 0 then Exit(LCwd + PLATFORM_PATH_SEP + AFileName);
    if LNeed >= SizeOf(LBuf) then
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_join(PAnsiChar(LCwd), PAnsiChar(AFileName), @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
      LCwd := Result;
    end
    else
      SetString(LCwd, PAnsiChar(@LBuf[0]), LNeed);
    LNeed := platform_path_normalize(PAnsiChar(LCwd), @LBuf[0], SizeOf(LBuf));
    if LNeed <= 0 then Exit(LCwd);
    if LNeed < SizeOf(LBuf) then
      SetString(Result, PAnsiChar(@LBuf[0]), LNeed)
    else
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_normalize(PAnsiChar(LCwd), @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    end;
  end;
end;

function GetTempDir: string;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  { perf: thin forward to platform_fs_temp_dir single source (zero-copy stack 4K, single Move in owner, ensure trailing sep) }
  LLen := platform_fs_temp_dir(@LBuf[0], SizeOf(LBuf));
  if LLen <= 0 then Exit('');
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
  if (Result <> '') and (Result[Length(Result)] <> PLATFORM_PATH_SEP) then
    Result := Result + PLATFORM_PATH_SEP;
end;

function GetTempDir(Global: Boolean): string;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  { Global flag ignored — single temp root via platform; perf: same single source }
  LLen := platform_fs_temp_dir(@LBuf[0], SizeOf(LBuf));
  if LLen <= 0 then Exit('');
  SetString(Result, PAnsiChar(@LBuf[0]), LLen);
  if (Result <> '') and (Result[Length(Result)] <> PLATFORM_PATH_SEP) then
    Result := Result + PLATFORM_PATH_SEP;
end;

function GetProcessID: SizeUInt;
begin
  { FPC System owns GetProcessID; no BaseUnix/Windows in system facade. }
  Result := SizeUInt(System.GetProcessID);
end;

{ Working directory — delegates to platform.files L0 (single source, inline zero-copy, try-finally not lost) }

function GetCurrentDir: string;
const
  CWD_STACK = 1024;
  CWD_MAX = 65536;
var
  LBuf: array[0..1023] of AnsiChar;
  LHeap: array of AnsiChar;
  LSize: SizeInt;
begin
  { perf: thin forward to platform_file_getcwd single source (zero-copy view, stack 1K + heap growth, sized alloc) }
  if platform_file_getcwd(@LBuf[0], CWD_STACK) <> nil then
    Exit(StrPas(@LBuf[0]));
  LSize := CWD_STACK * 2;
  repeat
    if LSize > CWD_MAX then Exit('');
    SetLength(LHeap, LSize);
    if platform_file_getcwd(@LHeap[0], PtrUInt(LSize)) <> nil then
      Exit(StrPas(@LHeap[0]));
    LSize := LSize * 2;
  until False;
end;

function SetCurrentDir(const ADir: string): Boolean; inline;
begin
  { perf: inline thin forward to platform_file_chdir single source (zero-copy view); stability: no resource leak }
  if ADir = '' then Exit(False);
  Result := platform_file_chdir(PAnsiChar(ADir)) = 0;
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

{ Environment — delegates to platform.env L0 (single source, inline zero-copy, try-finally not lost) }

function GetEnvironmentVariable(const AName: string): string; inline;
begin
  { perf: inline thin forward to platform_env_get_str single source (zero-copy view, single Move in owner, bytes.ops not duplicated) }
  if AName = '' then Exit('');
  Result := string(platform_env_get_str(AnsiString(AName)));
end;

{ Timing — delegates to time owner }

procedure Sleep(AMilliseconds: Cardinal); inline;
begin
  nextpas.core.time.MsSleep(AMilliseconds);
end;

{ Error handling — delegates to platform.error owner }

function SysErrorMessage(AErrorCode: Integer): string;
var
  LBuf: array[0..255] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_error_message(AErrorCode, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBuf[0]), LLen)
  else if LLen = 0 then
    Result := ''
  else
    Result := 'unknown error ' + nextpas.core.text.IntToStr(AErrorCode);
end;

function GetLastOSError: Integer; inline;
begin
  Result := platform_get_last_os_error;
end;

{ Exception backtrace — inline thin forward to exception owner L0 (single source via bytes.ops text, INV-5)
  perf: inline zero-copy forward to nextpas.core.exception (single source RTL raiseframe chain, stub elegance);
  stability: bounds-checked via owner (ExceptFrameAt returns nil out-of-range), no resource leak }
function ExceptAddr: Pointer; inline;
begin
  Result := nextpas.core.exception.ExceptAddr;
end;

function ExceptFrameCount: LongInt; inline;
begin
  Result := nextpas.core.exception.ExceptFrameCount;
end;

function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;
begin
  Result := nextpas.core.exception.ExceptFrameAt(AIndex);
end;

end.
