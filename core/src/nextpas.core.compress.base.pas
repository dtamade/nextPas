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

function LevelToZlib(const ALevel: TCompressionLevel): Int32; inline;

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

end.
