unit nextpas.core.zip.base;
{**
 * @desc ZIP 基本类型与共享契约：方法枚举、条目元数据、签名/上限常量、
 *       条目名安全谓词、unix 模式助手、读选项与 DOS 互转。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  {** @desc 条目压缩方法（central/local 的 method 字段已知子集） *}
  EZipLimitError = class(EIOError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EZipAuthError = class(EParseError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  TZipMethod = (
    zmStore,
    zmDeflate
  );

  {** @desc central directory 单条目元数据（尺寸/偏移为 Zip64 宽度） *}
  TZipEntryInfo = record
    Name: string;                { 归档内存储的原始名字节（UTF-8 约定） }
    Method: TZipMethod;          { 已知方法；未知方法保持 zmStore，看 MethodCode }
    MethodCode: Word;            { 原始 method 字段值；加密条目为解密后的真实方法 }
    Crc32: LongWord;
    CompressedSize: UInt64;
    UncompressedSize: UInt64;
    ModTimeUnixSec: Int64;
    LocalHeaderOffset: UInt64;
    IsDirectory: Boolean;
    ExternalAttrs: LongWord;     { central 的外部属性原值；unix 模式在高 16 位 }
    IsSymlink: Boolean;          { unix 模式位判定 S_IFLNK }
    IsEncrypted: Boolean;        { general purpose flag bit 0 }
    AesVersion: Word;            { WinZip AES 版本：0=非 AES 条目，1=AE-1，2=AE-2 }
    AesStrengthCode: Byte;       { WinZip AES 强度码：1/2/3 = AES-128/192/256 }
  end;

const
  { 结构签名 }
  C_ZIP_LOCAL_SIG      = $04034B50;
  C_ZIP_CENTRAL_SIG    = $02014B50;
  C_ZIP_EOCD_SIG       = $06054B50;
  C_ZIP64_EOCD_SIG     = $06064B50;
  C_ZIP64_EOCD_LOC_SIG = $07064B50;
  C_ZIP_DESCRIPTOR_SIG = $08074B50;

  { Zip64 extended information extra field id }
  C_ZIP64_EXTRA_ID = $0001;

  { 版本与标志 }
  C_ZIP_VERSION_DEFAULT = 20;     { PKZIP 2.0 基线 }
  C_ZIP_VERSION_ZIP64   = 45;
  C_ZIP_FLAG_ENCRYPTED  = $0001;
  C_ZIP_FLAG_DESCRIPTOR = $0008;  { bit3：数据描述符（流式写） }
  C_ZIP_FLAG_UTF8       = $0800;  { general purpose flag bit 11 }

  { 方法码 }
  C_ZIP_METHOD_STORE   = 0;
  C_ZIP_METHOD_DEFLATE = 8;
  { WinZip AES 加密条目的 wire 方法码；真实方法在 0x9901 extra 内 }
  C_ZIP_METHOD_WINZIP_AES = 99;

  { 版本 needed：WinZip AES 条目最低 51（APPNOTE 约定） }
  C_ZIP_VERSION_AES = 51;

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

  { unix 文件类型位（外部属性高字内） }
  C_ZIP_UNIX_MODE_SYMLINK = $A000;

  { DOS 纪元 unix 边界常量（1980-01-01 00:00:00Z / 2107-12-31 23:59:59Z），单源常量化去 TDate 构造 }
  C_DOS_MIN_UNIX = Int64(315532800);
  C_DOS_MAX_UNIX = Int64(4354819199);

  { 单条目解压默认上限与描述符扫描缓冲上限 }
  C_ZIP_DEFAULT_MAX_OUTPUT     = SizeUInt(1) shl 30;
  C_ZIP_DEFAULT_MAX_DESCRIPTOR = SizeUInt(512) * 1024 * 1024;

type
  {** 读选项：MaxOutputSize 为单条目上限（0=默认1GiB），MaxTotalOutputSize 跨条目总量，MaxDescriptorBuffer 描述符扫描上限，Password 为 AES 口令 *}
  TZipReadOptions = record
    MaxOutputSize: SizeUInt;
    MaxTotalOutputSize: UInt64;
    MaxDescriptorBuffer: SizeUInt;
    Password: TBytes;
  end;

{** 名称安全谓词：非空、非绝对路径、无盘符前缀、无反斜杠、无 '..' 段。
    尾随 '/'（目录条目）合法。 *}
function IsSafeZipEntryName(const AName: string): Boolean;

{** 同 IsSafeZipEntryName，不满足时 raise EArgumentError（写端入参校验用）。 *}
procedure ValidateZipEntryName(const AName: string);

{** unix 秒 → DOS 日期/时间字。越界钳制到 [1980-01-01, 2107-12-31 23:59:58]。 *}
procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);

{** DOS 纪元下限（1980-01-01T00:00:00Z）对应的 unix 秒；确定性时间戳默认值。 *}
function DosMinUnixSec: Int64; inline;

{** DOS 纪元上限（2107-12-31T23:59:59Z）对应的 unix 秒；钳制上界。 *}
function DosMaxUnixSec: Int64; inline;

{** 从外部属性高 16 位取 unix 模式字（S_IFMT|rwx）。 *}
function ZipUnixModeOf(const AEntry: TZipEntryInfo): Word; inline;

{** 由 posix 权限位（低 12 位）构造常规文件的 unix 模式字。 *}
function ZipRegularMode(APermissionBits: Word): Word; inline;

{** 由 posix 权限位（低 12 位）构造目录的 unix 模式字。 *}
function ZipDirectoryMode(APermissionBits: Word): Word; inline;

{** DOS 日期/时间字 → unix 秒。 *}
function UnixFromDosDateTime(ADosDate, ADosTime: Word): Int64;

function DefaultZipReadOptions: TZipReadOptions; inline;
function NormalizeZipReadOptions(const AOptions: TZipReadOptions): TZipReadOptions; inline;
function TryZipMethodFromCode(ACode: Word; out AMethod: TZipMethod): Boolean; inline;

implementation

uses
  nextpas.core.bytes.pathvalid,
  nextpas.core.time.date;

class function EZipLimitError.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;
constructor EZipLimitError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;
class function EZipAuthError.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;
constructor EZipAuthError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

function IsSafeZipEntryName(const AName: string): Boolean; inline;
begin
  Result := nextpas.core.bytes.pathvalid.IsSafeArchiveEntryName(AName, C_ZIP_MAX_NAME_BYTES);
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
  LRem: Int64;
  LD: TDate;
begin
  if AUnixSec < C_DOS_MIN_UNIX then
    AUnixSec := C_DOS_MIN_UNIX
  else if AUnixSec > C_DOS_MAX_UNIX then
    AUnixSec := C_DOS_MAX_UNIX;
  LD := TDate.FromUnixDays(Integer(AUnixSec div 86400));
  LRem := AUnixSec mod 86400;
  ADosDate := Word(((LD.GetYear - C_DOS_MIN_YEAR) shl 9) or
    (LD.GetMonth shl 5) or LD.GetDay);
  ADosTime := Word(((LRem div 3600) shl 11) or
    (((LRem mod 3600) div 60) shl 5) or ((LRem mod 60) div 2));
end;

function DosMinUnixSec: Int64; inline;
begin
  Result := C_DOS_MIN_UNIX;
end;

function DosMaxUnixSec: Int64; inline;
begin
  Result := C_DOS_MAX_UNIX;
end;

function ZipUnixModeOf(const AEntry: TZipEntryInfo): Word;
begin
  Result := Word(AEntry.ExternalAttrs shr 16);
end;

function ZipRegularMode(APermissionBits: Word): Word;
begin
  { S_IFREG | 权限位 }
  Result := $8000 or (APermissionBits and $0FFF);
end;

function ZipDirectoryMode(APermissionBits: Word): Word;
begin
  { S_IFDIR | 权限位 }
  Result := $4000 or (APermissionBits and $0FFF);
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
  { 越界钳制：非法年/月/日回落到 DOS 纪元下限，避免 TDate raise（零 Create 验证） }
  if not TDate.TryCreate(LYear, LMonth, LDay, LD) then
    LD := TDate.FromUnixDays(Integer(C_DOS_MIN_UNIX div 86400));
  Result := Int64(LD.ToUnixDays) * 86400 + LHour * 3600 + LMin * 60 + LSec;
end;

function DefaultZipReadOptions: TZipReadOptions;
begin
  Result.MaxOutputSize := C_ZIP_DEFAULT_MAX_OUTPUT;
  Result.MaxTotalOutputSize := 0;
  Result.MaxDescriptorBuffer := C_ZIP_DEFAULT_MAX_DESCRIPTOR;
  Result.Password := nil;
end;

function NormalizeZipReadOptions(const AOptions: TZipReadOptions): TZipReadOptions;
begin
  Result := AOptions;
  if Result.MaxOutputSize = 0 then
    Result.MaxOutputSize := C_ZIP_DEFAULT_MAX_OUTPUT;
  if Result.MaxDescriptorBuffer = 0 then
    Result.MaxDescriptorBuffer := C_ZIP_DEFAULT_MAX_DESCRIPTOR;
end;

function TryZipMethodFromCode(ACode: Word; out AMethod: TZipMethod): Boolean;
begin
  if ACode = C_ZIP_METHOD_STORE then
  begin
    AMethod := zmStore;
    Exit(True);
  end;
  if ACode = C_ZIP_METHOD_DEFLATE then
  begin
    AMethod := zmDeflate;
    Exit(True);
  end;
  Result := False;
end;

end.
