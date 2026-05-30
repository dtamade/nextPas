unit nextpas.core.compress.base;

{$I nextpas.core.settings.inc}

interface

type
  TCompressionLevel = (
    clNone,
    clFastest,
    clDefault,
    clBest
  );

const
  COMPRESS_BUF_SIZE = 32768;

  GZIP_MAGIC_1 = $1F;
  GZIP_MAGIC_2 = $8B;
  GZIP_METHOD_DEFLATE = 8;

implementation

end.
