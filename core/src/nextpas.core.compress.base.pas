unit nextpas.core.compress.base;

{$I nextpas.core.settings.inc}

interface

uses
  zlib;

type
  TCompressionLevel = (
    clNone,
    clFastest,
    clDefault,
    clBest
  );

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

implementation

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

end.
