unit nextpas.core.compress.base;

{** @desc 压缩基座：语义类型与单源常量/容量辅助，L0 纯度实现。
  FFI 边界隔离：zlib 的 Z_* 常量与 z_stream/deflate/inflate 声明收口在
  nextpas.core.compress.zlib.ffi（.lz4/.bzip2 同理），本单元仅映射
  TCompressionLevel → level 数值与提供 GZIP_MAX/COMPRESS_BUF 单源，复用
  limits/GZIP_MAX/ValidPath 单源纪律，不新增重复，守住 L0 与 FPC RTL 隔离。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  TCompressionLevel = (
    clNone,
    clFastest,
    clDefault,
    clBest
  );

  { Deflate typed error codes — single source for git.native.zlib mapping.
    Zero string parsing: owner emits code, consumer switches on code. }
  TDeflateErrorCode = (
    decTruncated,           // truncated stream
    decInvalidHeader,       // invalid zlib header (bad method)
    decInvalidWindowBits,   // window bits >7
    decCorruptHeader,       // header check bits fail (mod 31)
    decPresetDictionary,    // preset dict bit set
    decStreamTooLarge,      // input exceeds High(LongWord)
    decCorruptStream,       // Z_DATA_ERROR payload
    decTrailingBytes,       // trailing bytes after stream
    decLimitExceeded,       // decompressed size exceeds limit
    decDestTooSmall,        // dest buffer too small
    decNilInput,            // nil input pointer
    decInternal             // generic inflate/deflate failure
  );

  { Typed deflate error — subclass of EIOError so existing `on E: EIOError`
    catches still work; Code enables string-free mapping. }
  EDeflateError = class(EIOError)
  private
    FCode: TDeflateErrorCode;
  public
    constructor Create(ACode: TDeflateErrorCode; const AMessage: string); overload;
    constructor CreateFmt(ACode: TDeflateErrorCode; const AMessage: string;
      const AArgs: array of const); overload;
    property Code: TDeflateErrorCode read FCode;
  end;

const
  COMPRESS_BUF_SIZE = 32768;
  LZ4_MAX_INPUT_SIZE = $7E000000;

  GZIP_MAGIC_1 = $1F;
  GZIP_MAGIC_2 = $8B;
  GZIP_METHOD_DEFLATE = 8;
  GZIP_MAX_DECOMPRESS_BYTES = 32 * 1024 * 1024;

function LevelToZlib(const ALevel: TCompressionLevel): Int32; inline;
function CompressNextCapacity(const ACurrent, AMaxOutputSize: SizeUInt): SizeUInt; inline;
function CompressInitialDecompressCapacity(const AInputLen, AMaxOutputSize: SizeUInt): SizeUInt; inline;
function CompressInitialInflateCapacity(const AInputLen, AMaxOutputSize: SizeUInt; const AHint: SizeUInt = 0): SizeUInt; inline;
function CompressInitialCompressCapacity(const AInputLen: SizeUInt): SizeUInt; inline;

implementation

const
  Z_NO_COMPRESSION = 0;
  Z_BEST_SPEED = 1;
  Z_BEST_COMPRESSION = 9;
  Z_DEFAULT_COMPRESSION = -1;

function LevelToZlib(const ALevel: TCompressionLevel): Int32;
begin
  case ALevel of
    clNone: Result := Z_NO_COMPRESSION;
    clFastest: Result := Z_BEST_SPEED;
    clBest: Result := Z_BEST_COMPRESSION;
  otherwise
    Result := Z_DEFAULT_COMPRESSION;
  end;
end;

function CompressNextCapacity(const ACurrent, AMaxOutputSize: SizeUInt): SizeUInt;
begin
  if ACurrent >= AMaxOutputSize then
    Exit(0);
  if ACurrent > AMaxOutputSize div 2 then
    Result := AMaxOutputSize
  else
    Result := ACurrent shl 1;
end;

function CompressInitialDecompressCapacity(const AInputLen, AMaxOutputSize: SizeUInt): SizeUInt;
begin
  Result := AInputLen shl 2;
  if (Result < AInputLen) or (Result > AMaxOutputSize) then
    Result := AMaxOutputSize;
end;

function CompressInitialInflateCapacity(const AInputLen, AMaxOutputSize: SizeUInt; const AHint: SizeUInt): SizeUInt;
begin
  Result := AInputLen shl 2;
  if AHint > Result then
    Result := AHint;
  if Result < 64 then
    Result := 64;
  if Result > AMaxOutputSize then
    Result := AMaxOutputSize;
end;

function CompressInitialCompressCapacity(const AInputLen: SizeUInt): SizeUInt; inline;
begin
  // perf: single source bound for zlib Z_SYNC_FLUSH (compressBound + sync marker): L + L/1000 + 128 covers 1% + 12 + flush empty block, avoids per-packet repeat SetLength growth for large packets/bomb (amortized O(1)); L0 pure, no FFI, overflow clamped
  Result := AInputLen + (AInputLen div 1000) + 128;
  if Result < AInputLen then
    Result := High(SizeUInt);
  if Result < 128 then
    Result := 128;
end;

constructor EDeflateError.Create(ACode: TDeflateErrorCode; const AMessage: string);
begin
  inherited Create(AMessage);
  FCode := ACode;
end;

constructor EDeflateError.CreateFmt(ACode: TDeflateErrorCode; const AMessage: string;
  const AArgs: array of const);
begin
  inherited CreateFmt(AMessage, AArgs);
  FCode := ACode;
end;

end.
