unit nextpas.core.system.sysutils;
{**
 * @desc SysUtils compatibility facade — S4 minimal (text/conv only).
 *
 * Thin facade delegating to owner modules (text.conv, text.format,
 * bytes.ops, base.utils). Filesystem, path, time, environment,
 * process, and platform error ownership stays with fs/path/time/os.env
 * owners — not re-exported here (S4 owner-boundary integrity).
 *
 * Format delegates to nextpas.core.text.format.TextFormat (owner);
 * safe subset (%% %[-][0][width][.precision](s|d|u|x|X|f)) is the
 * supported surface; extended specifiers fall back to SysUtils.Format
 * via EInvalidArgument trap to preserve SysUtils parity.
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

{ Text formatting — owner text.format/text.conv }
function Format(const AFmt: string; const AArgs: array of const): string;
function CompareStr(const A, B: string): Integer;
function SameText(const A, B: string): Boolean;

{ Numeric conversion — owner text.conv }
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

{ Bytes helpers — single-source bytes.ops (zero-copy) }
function BytesOf(const AStr: string): TBytes;
function StringOf(const ABytes: TBytes): string;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; overload;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; overload;
function HexStr(const AValue: UInt64; const ADigits: Integer = 0): string; overload;
function HexStr(const AAddr: Pointer): string; overload;

{ String manipulation — owner text.conv }
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function UpperCase(const AStr: string): string;
function LowerCase(const AStr: string): string;

{ String search — owner text.view (zero-copy view) }
function Pos(const ASubStr, AStr: string): Integer;

{ Exception backtrace — owner exception (single-source) }
function ExceptAddr: Pointer; inline;
function ExceptFrameCount: LongInt; inline;
function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;

implementation

uses
  SysUtils,
  nextpas.core.bytes.ops,
  nextpas.core.base.utils,
  nextpas.core.text.compare,
  nextpas.core.text.utils,
  nextpas.core.text.view;

{ Text formatting — thin delegate to text owner with RTL fallback for extended specifiers. }
function Format(const AFmt: string; const AArgs: array of const): string;
begin
  try
    Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);
  except
    on E: EInvalidArgument do
      Result := SysUtils.Format(AFmt, AArgs);
  end;
end;

function SameText(const A, B: string): Boolean; inline;
begin
  Result := nextpas.core.text.conv.SameText(A, B);
end;

function CompareStr(const A, B: string): Integer; inline;
begin
  Result := nextpas.core.text.compare.TextCompare(A, B);
end;

{ Numeric conversion }

function IntToStr(const AValue: Int64): string; inline;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function Int64ToStr(const AValue: Int64): string; inline;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string; inline;
begin
  Result := nextpas.core.text.conv.IntToHex(AValue, ADigits);
end;

function StrToInt(const AStr: string): Integer; inline;
begin
  Result := Integer(nextpas.core.text.conv.StrToInt(AStr));
end;

function StrToInt64(const AStr: string): Int64; inline;
begin
  Result := nextpas.core.text.conv.StrToInt(AStr);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean; inline;
begin
  Result := nextpas.core.text.conv.TryStrToInt(AStr, AValue);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean; inline;
begin
  { 委托 text.conv：其 Val 语义接受 0x/$ 前缀与十进制，
    与 RTL SysUtils 仅十进制的行为存在差异（此处有意跟随 nextpas 语义）。 }
  Result := nextpas.core.text.conv.TryStrToInt64(AStr, AValue);
end;

function StrToIntDef(const AStr: string; const ADefault: Integer): Integer; inline;
begin
  if not TryStrToInt(AStr, Result) then
    Result := ADefault;
end;

function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64; inline;
begin
  if not TryStrToInt64(AStr, Result) then
    Result := ADefault;
end;

function StrToFloat(const AStr: string): Double; inline;
begin
  Result := nextpas.core.text.conv.StrToFloat(AStr);
end;

function FloatToStr(const AValue: Double): string; inline;
begin
  Result := nextpas.core.text.conv.FloatToStr(AValue);
end;

function CurrToStr(const AValue: Currency): string; inline;
begin
  Result := nextpas.core.text.conv.FloatToStr(AValue);
end;

function BoolToStr(const AValue: Boolean; const AUseBoolStrs: Boolean): string; inline;
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
  { single-source zero-copy: bytes.ops.StringToBytes = one Move, no temp copy }
  Result := nextpas.core.bytes.ops.StringToBytes(AStr);
end;

function StringOf(const ABytes: TBytes): string; inline;
begin
  { single-source zero-copy: bytes.ops.BytesToString = one Move, no temp copy }
  Result := nextpas.core.bytes.ops.BytesToString(ABytes);
end;

function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
begin
  Result := nextpas.core.base.utils.CompareMem(A, B, ASize);
end;

function Supports(const AInstance: TObject; const AIID: TGuid;
  out AIntf): Boolean; inline;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid;
  out AIntf): Boolean; inline;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

function HexStr(const AValue: UInt64; const ADigits: Integer): string; inline;
begin
  Result := nextpas.core.base.HexStr(AValue, ADigits);
end;

function HexStr(const AAddr: Pointer): string; inline;
begin
  Result := nextpas.core.base.HexStr(PtrUInt(AAddr), 0);
end;

{ String manipulation }

function Trim(const AStr: string): string; inline;
begin
  Result := nextpas.core.text.conv.Trim(AStr);
end;

function TrimLeft(const AStr: string): string; inline;
begin
  Result := nextpas.core.text.conv.TrimLeft(AStr);
end;

function TrimRight(const AStr: string): string; inline;
begin
  Result := nextpas.core.text.conv.TrimRight(AStr);
end;

function UpperCase(const AStr: string): string; inline;
begin
  Result := nextpas.core.text.conv.UpperCase(AStr);
end;

function LowerCase(const AStr: string): string; inline;
begin
  Result := nextpas.core.text.conv.LowerCase(AStr);
end;

{ String search — thin delegate to text.view owner (single-source, vectorized).
  Inline + zero-copy TStringView: no allocation, no temp string copy.
  1-based RTL Pos semantics: empty needle → 0; IndexOfStr 0→1 conversion. }

function Pos(const ASubStr, AStr: string): Integer; inline;
begin
  if ASubStr = '' then
    Exit(0);
  Result := nextpas.core.text.view.IndexOfStr(AStr, ASubStr);
  if Result < 0 then
    Result := 0
  else
    Inc(Result);
end;

{ Exception backtrace — single-source via nextpas.core.exception (no SysUtils direct). }
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
  if (AIndex < 0) or (AIndex >= nextpas.core.exception.ExceptFrameCount) then
    Result := nil
  else
    Result := nextpas.core.exception.ExceptFrames(AIndex);
end;

end.
