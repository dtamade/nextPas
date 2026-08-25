unit nextpas.core.zip.base;
{**
 * @desc ZIP 基本类型与共享契约：方法枚举、条目元数据、签名/上限常量、
 *       条目名安全谓词、unix 秒与 DOS 日期时间字互转。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  {** @desc 条目压缩方法（central/local 的 method 字段已知子集） *}
  TZipMethod = (
    zmStore,
    zmDeflate
  );

  {** @desc central directory 单条目元数据（尺寸/偏移为 Zip64 宽度） *}
  TZipEntryInfo = record
    Name: string;                { 归档内存储的原始名字节（UTF-8 约定） }
    Method: TZipMethod;          { 已知方法；未知方法保持 zmStore，看 MethodCode }
    MethodCode: Word;            { 原始 method 字段值 }
    Crc32: LongWord;
    CompressedSize: UInt64;
    UncompressedSize: UInt64;
    ModTimeUnixSec: Int64;
    LocalHeaderOffset: UInt64;
    IsDirectory: Boolean;
  end;

const
  { 结构签名 }
  C_ZIP_LOCAL_SIG      = $04034B50;
  C_ZIP_CENTRAL_SIG    = $02014B50;
  C_ZIP_EOCD_SIG       = $06054B50;
  C_ZIP64_EOCD_SIG     = $06064B50;
  C_ZIP64_EOCD_LOC_SIG = $07064B50;

  { Zip64 extended information extra field id }
  C_ZIP64_EXTRA_ID = $0001;

  { 版本与标志 }
  C_ZIP_VERSION_DEFAULT = 20;     { PKZIP 2.0 基线 }
  C_ZIP_VERSION_ZIP64   = 45;
  C_ZIP_FLAG_ENCRYPTED  = $0001;
  C_ZIP_FLAG_UTF8       = $0800;  { general purpose flag bit 11 }

  { 方法码 }
  C_ZIP_METHOD_STORE   = 0;
  C_ZIP_METHOD_DEFLATE = 8;

  C_ZIP_MADE_BY_HOST_UNIX = 3 shl 8; { version made by：host = Unix }

  { ZIP32 经典字段宽度上限；超出即启用 Zip64 结构 }
  C_ZIP_MAX_ENTRIES32  = 65535;
  C_ZIP_MAX_SIZE32     = $FFFFFFFF;
  C_ZIP_MAX_NAME_BYTES = High(Word);

  { DOS 时间可表达区间 }
  C_DOS_MIN_YEAR = 1980;
  C_DOS_MAX_YEAR = 2107;

  { unix mode 高 16 位：S_IFREG|0644 与 S_IFDIR|0755 }
  C_ZIP_EXTERNAL_ATTR_REGULAR   = $81A4 shl 16;
  C_ZIP_EXTERNAL_ATTR_DIRECTORY = ($41ED shl 16) or $0010;

{** 名称安全谓词：非空、非绝对路径、无盘符前缀、无反斜杠、无 '..' 段。
    尾随 '/'（目录条目）合法。 *}
function IsSafeZipEntryName(const AName: string): Boolean;

{** 同 IsSafeZipEntryName，不满足时 raise EArgumentError（写端入参校验用）。 *}
procedure ValidateZipEntryName(const AName: string);

{** unix 秒 → DOS 日期/时间字。越界钳制到 [1980-01-01, 2107-12-31 23:59:58]。 *}
procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);

{** DOS 纪元下限（1980-01-01T00:00:00Z）对应的 unix 秒；确定性时间戳默认值。 *}
function DosMinUnixSec: Int64; inline;

{** DOS 日期/时间字 → unix 秒。 *}
function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64;

implementation

uses
  nextpas.core.exception,
  nextpas.core.time.date;

function IsSafeZipEntryName(const AName: string): Boolean;
var
  LI, LSegStart: Integer;
begin
  Result := False;
  if AName = '' then
    Exit;
  if Length(AName) > C_ZIP_MAX_NAME_BYTES then
    Exit;
  if AName[1] = '/' then
    Exit;
  if (Length(AName) >= 2) and (AName[2] = ':') and
     (UpCase(AName[1]) in ['A'..'Z']) then
    Exit;
  LSegStart := 1;
  for LI := 1 to Length(AName) + 1 do
  begin
    if (LI <= Length(AName)) and (AName[LI] <> '/') then
    begin
      if AName[LI] = '\' then
        Exit;
      Continue;
    end;
    { 段边界：[LSegStart, LI-1]；空段（如尾随 '/'）合法 }
    if (LI - LSegStart = 2) and (AName[LSegStart] = '.') and
       (AName[LSegStart + 1] = '.') then
      Exit;
    LSegStart := LI + 1;
  end;
  Result := True;
end;

procedure ValidateZipEntryName(const AName: string);
begin
  if AName = '' then
    raise EArgumentError.Create('zip entry name must not be empty');
  if Length(AName) > C_ZIP_MAX_NAME_BYTES then
    raise EArgumentError.Create('zip entry name exceeds ' +
      IntToStr(C_ZIP_MAX_NAME_BYTES) + ' bytes');
  if not IsSafeZipEntryName(AName) then
    raise EArgumentError.Create('zip entry name is not safe: ' + AName);
end;

procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);
var
  LMinSec, LMaxSec, LRem: Int64;
  LD: TDate;
begin
  LMinSec := Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400;
  LMaxSec := Int64(TDate.Create(C_DOS_MAX_YEAR, 12, 31).ToUnixDays) * 86400 + 86399;
  if AUnixSec < LMinSec then
    AUnixSec := LMinSec
  else if AUnixSec > LMaxSec then
    AUnixSec := LMaxSec;
  LD := TDate.FromUnixDays(Integer(AUnixSec div 86400));
  LRem := AUnixSec mod 86400;
  ADosDate := Word(((LD.GetYear - C_DOS_MIN_YEAR) shl 9) or
    (LD.GetMonth shl 5) or LD.GetDay);
  ADosTime := Word(((LRem div 3600) shl 11) or
    (((LRem mod 3600) div 60) shl 5) or ((LRem mod 60) div 2));
end;

function DosMinUnixSec: Int64;
begin
  Result := Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400;
end;

function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64;
var
  LYear, LMonth, LDay, LHour, LMin, LSec: Integer;
  LD: TDate;
begin
  LYear := C_DOS_MIN_YEAR + Integer(ADosDate shr 9);
  LMonth := Integer((ADosDate shr 5) and $0F);
  LDay := Integer(ADosDate and $1F);
  LHour := Integer(ADosTime shr 11);
  LMin := Integer((ADosTime shr 5) and $3F);
  LSec := Integer((ADosTime and $1F) shl 1);
  { 越界钳制：非法年/月/日回落到 DOS 纪元下限，避免 TDate raise }
  if not TDate.TryCreate(LYear, LMonth, LDay, LD) then
    LD := TDate.Create(C_DOS_MIN_YEAR, 1, 1);
  Result := Int64(LD.ToUnixDays) * 86400 + LHour * 3600 + LMin * 60 + LSec;
end;

end.
