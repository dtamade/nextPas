unit nextpas.core.zlib.base;

{**
 * @desc nextpas.core.zlib.base - zlib 基础类型与契约常量
 *
 * 拥有 S1 稳定词汇：错误类型 EZlibError、Adler-32 常量与 Deflate 级别
 * 枚举及 zlib 整型映射。零 paszlib 拷贝；级别映射复用
 * nextpas.core.compress.base 的 LevelToZlib 语义，表驱动 O(1)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.compress.base;

const
  { Adler-32 契约：RFC1950 §8.2，初始值 1，模 65521，NMAX 分块 }
  ZLIB_ADLER_INIT = LongWord(1);
  ZLIB_ADLER_MOD = LongWord(65521);
  ZLIB_ADLER_NMAX = SizeUInt(5552);

  { 窗口位宽：15=zlib 包装，-15=裸流（与 compress.deflate/gzip 一致） }
  ZLIB_WINDOW_BITS_DEFAULT = 15;
  ZLIB_WINDOW_BITS_RAW = -15;

  { 单源解压上限：别名自 compress.base GZIP_MAX_DECOMPRESS_BYTES，单源 32 MiB }
  ZLIB_MAX_DECOMPRESS_BYTES = nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES;

  { zlib 头合法性掩码，供后续实现复用（不含逻辑，仅载体） }
  ZLIB_CMF_DEFLATED = Byte($08);
  ZLIB_CMF_WINDOW_MASK = Byte($F0);

type
  { Deflate 压缩级别：与 compress.TCompressionLevel 同语义，独立枚举保持
    模块边界，Ord 索引表驱动映射到 zlib 整型，避免分支漂移。 }
  TZlibLevel = (
    zlNone,
    zlFastest,
    zlDefault,
    zlBest
  );

  { Adler-32 校验模式：默认增量更新，NoHeader 用于裸流场景复用 }
  TZlibAdlerMode = (
    zaDefault,
    zaNoHeader
  );

  TZlibErrorCode = (
    zecInvalidArgument,
    zecCorruptStream,
    zecTruncated,
    zecUnsupported,
    zecLimitExceeded,
    zecInternal
  );

  { EZlibError - zlib 域错误，Category 映射到 ecInvalidArgument/ecIO 等 }
  EZlibError = class(ENextPasError)
  private
    FCode: TZlibErrorCode;
  public
    constructor Create(ACode: TZlibErrorCode; const AMessage: string); overload;
    constructor CreateFmt(ACode: TZlibErrorCode; const AMessage: string;
      const AArgs: array of const); overload;
    property Code: TZlibErrorCode read FCode;
  end;

{ 级别到 zlib 整型：复用 compress.base 语义，表驱动 O(1) }
function ZlibLevelToZlib(const ALevel: TZlibLevel): Int32; inline;
function ZlibLevelToCompressOrd(const ALevel: TZlibLevel): Integer; inline;
function TryZlibLevelFromOrd(AOrd: Integer; out ALevel: TZlibLevel): Boolean; inline;

{ Adler 辅助：增量更新语义与 Crc32Update 对齐，首次传 ZLIB_ADLER_INIT }
function ZlibAdlerUpdate(AAdler: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord;

implementation

uses
  SysUtils;

constructor EZlibError.Create(ACode: TZlibErrorCode; const AMessage: string);
var
  LCat: TErrorCategory;
begin
  case ACode of
    zecInvalidArgument: LCat := ecInvalidArgument;
    zecCorruptStream: LCat := ecIO;
    zecTruncated: LCat := ecIO;
    zecUnsupported: LCat := ecNotSupported;
    zecLimitExceeded: LCat := ecResourceExhausted;
  else
    LCat := ecInternal;
  end;
  inherited Create(AMessage, LCat);
  FCode := ACode;
end;

constructor EZlibError.CreateFmt(ACode: TZlibErrorCode; const AMessage: string;
  const AArgs: array of const);
var
  LCat: TErrorCategory;
begin
  case ACode of
    zecInvalidArgument: LCat := ecInvalidArgument;
    zecCorruptStream: LCat := ecIO;
    zecTruncated: LCat := ecIO;
    zecUnsupported: LCat := ecNotSupported;
    zecLimitExceeded: LCat := ecResourceExhausted;
  else
    LCat := ecInternal;
  end;
  inherited CreateFmt(AMessage, LCat, AArgs);
  FCode := ACode;
end;

function ZlibLevelToZlib(const ALevel: TZlibLevel): Int32; inline;
begin
  Result := nextpas.core.compress.base.LevelToZlib(TCompressionLevel(Ord(ALevel)));
end;

function ZlibLevelToCompressOrd(const ALevel: TZlibLevel): Integer; inline;
begin
  Result := Ord(ALevel);
end;

function TryZlibLevelFromOrd(AOrd: Integer; out ALevel: TZlibLevel): Boolean; inline;
begin
  Result := (AOrd >= Ord(Low(TZlibLevel))) and (AOrd <= Ord(High(TZlibLevel)));
  if Result then
    ALevel := TZlibLevel(AOrd);
end;

function ZlibAdlerUpdate(AAdler: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord;
var
  P: PByte;
  LA, LB: LongWord;
  LK: SizeUInt;
begin
  if (ALen = 0) or (AData = nil) then
    Exit(AAdler);
  LA := AAdler and $FFFF;
  LB := (AAdler shr 16) and $FFFF;
  P := PByte(AData);
  while ALen > 0 do
  begin
    if ALen < ZLIB_ADLER_NMAX then
      LK := ALen
    else
      LK := ZLIB_ADLER_NMAX;
    Dec(ALen, LK);
    while LK >= 16 do
    begin
      LA := LA + P[0]; LB := LB + LA;
      LA := LA + P[1]; LB := LB + LA;
      LA := LA + P[2]; LB := LB + LA;
      LA := LA + P[3]; LB := LB + LA;
      LA := LA + P[4]; LB := LB + LA;
      LA := LA + P[5]; LB := LB + LA;
      LA := LA + P[6]; LB := LB + LA;
      LA := LA + P[7]; LB := LB + LA;
      LA := LA + P[8]; LB := LB + LA;
      LA := LA + P[9]; LB := LB + LA;
      LA := LA + P[10]; LB := LB + LA;
      LA := LA + P[11]; LB := LB + LA;
      LA := LA + P[12]; LB := LB + LA;
      LA := LA + P[13]; LB := LB + LA;
      LA := LA + P[14]; LB := LB + LA;
      LA := LA + P[15]; LB := LB + LA;
      Inc(P, 16);
      Dec(LK, 16);
    end;
    while LK >= 4 do
    begin
      LA := LA + P[0]; LB := LB + LA;
      LA := LA + P[1]; LB := LB + LA;
      LA := LA + P[2]; LB := LB + LA;
      LA := LA + P[3]; LB := LB + LA;
      Inc(P, 4);
      Dec(LK, 4);
    end;
    while LK > 0 do
    begin
      LA := LA + P^;
      LB := LB + LA;
      Inc(P);
      Dec(LK);
    end;
    LA := LA mod ZLIB_ADLER_MOD;
    LB := LB mod ZLIB_ADLER_MOD;
  end;
  Result := (LB shl 16) or LA;
end;

end.
