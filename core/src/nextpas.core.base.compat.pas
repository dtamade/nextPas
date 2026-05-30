unit nextpas.core.base.compat;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

{**
 * FPC RTL 兼容层
 *
 * @desc
 *   提供 fafafa.game 迁移所需的 FPC RTL 函数，内部委托 RTL。
 *   未来 nextPas 编译器就绪后替换为原生实现。
 *   这些函数让消费方可以 uses nextpas.core.base.compat 替代 uses SysUtils。
 *}

{ 内存比较 }
function CompareMem(P1, P2: Pointer; ALength: PtrUInt): Boolean; inline;

{ 浮点比较 }
function SameValue(const A, B: Double; AEpsilon: Double = 1E-12): Boolean; inline;

{ 接口查询 }
function Supports(const AInstance: TObject; const AIID: TGUID; out AIntf): Boolean; inline;
function Supports(const AInstance: IInterface; const AIID: TGUID; out AIntf): Boolean; inline;

{ 异常（re-export SysUtils.Exception 让消费方不需要直接 uses SysUtils） }
type
  Exception = SysUtils.Exception;
  EConvertError = SysUtils.EConvertError;

{ 字符串工具 }
function CompareText(const A, B: string): Integer; inline;
function SameText(const A, B: string): Boolean; inline;
function AnsiCompareStr(const A, B: string): Integer; inline;

{ 数值格式化 }
function FloatToStrF(AValue: Extended; AFormat: TFloatFormat;
  APrecision, ADigits: Integer): string; inline;

{ 文件系统 }
function FileExists(const APath: string): Boolean; inline;
function ExtractFilePath(const APath: string): string; inline;
function ExtractFileExt(const APath: string): string; inline;
function ExtractFileName(const APath: string): string; inline;
function ExpandFileName(const APath: string): string; inline;
function IncludeTrailingPathDelimiter(const APath: string): string; inline;
function DeleteFile(const APath: string): Boolean; inline;

{ 日期时间 }
function Now: TDateTime; inline;
function DateTimeToStr(const ADateTime: TDateTime): string; inline;
function FormatDateTime(const AFmt: string; const ADateTime: TDateTime): string; inline;

implementation

function CompareMem(P1, P2: Pointer; ALength: PtrUInt): Boolean;
begin
  Result := SysUtils.CompareMem(P1, P2, ALength);
end;

function SameValue(const A, B: Double; AEpsilon: Double): Boolean;
begin
  Result := System.Abs(A - B) <= AEpsilon;
end;

function Supports(const AInstance: TObject; const AIID: TGUID; out AIntf): Boolean;
begin
  Result := SysUtils.Supports(AInstance, AIID, AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGUID; out AIntf): Boolean;
begin
  Result := SysUtils.Supports(AInstance, AIID, AIntf);
end;

function CompareText(const A, B: string): Integer;
begin
  Result := SysUtils.CompareText(A, B);
end;

function SameText(const A, B: string): Boolean;
begin
  Result := SysUtils.SameText(A, B);
end;

function AnsiCompareStr(const A, B: string): Integer;
begin
  Result := SysUtils.AnsiCompareStr(A, B);
end;

function FloatToStrF(AValue: Extended; AFormat: TFloatFormat;
  APrecision, ADigits: Integer): string;
begin
  Result := SysUtils.FloatToStrF(AValue, AFormat, APrecision, ADigits);
end;

function Now: TDateTime;
begin
  Result := SysUtils.Now;
end;

function DateTimeToStr(const ADateTime: TDateTime): string;
begin
  Result := SysUtils.DateTimeToStr(ADateTime);
end;

function FormatDateTime(const AFmt: string; const ADateTime: TDateTime): string;
begin
  Result := SysUtils.FormatDateTime(AFmt, ADateTime);
end;

function FileExists(const APath: string): Boolean;
begin
  Result := SysUtils.FileExists(APath);
end;

function ExtractFilePath(const APath: string): string;
begin
  Result := SysUtils.ExtractFilePath(APath);
end;

function ExtractFileExt(const APath: string): string;
begin
  Result := SysUtils.ExtractFileExt(APath);
end;

function ExtractFileName(const APath: string): string;
begin
  Result := SysUtils.ExtractFileName(APath);
end;

function ExpandFileName(const APath: string): string;
begin
  Result := SysUtils.ExpandFileName(APath);
end;

function IncludeTrailingPathDelimiter(const APath: string): string;
begin
  Result := SysUtils.IncludeTrailingPathDelimiter(APath);
end;

function DeleteFile(const APath: string): Boolean;
begin
  Result := SysUtils.DeleteFile(APath);
end;

end.
