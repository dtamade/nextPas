program bench_compress;
{$I nextpas.core.settings.inc}
{$Q-}{$R-}
uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.compress;
const
  DATA_SIZE = 1024 * 1024;
var
  GData: TBytes;
  GDeflateCompressed: TBytes;
  GGzipCompressed: TBytes;
  GLz4Compressed: TBytes;
procedure InitData;
var LI: Integer;
begin
  SetLength(GData, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GData[LI] := Byte((LI * 7 + LI div 256) mod 251);
  GDeflateCompressed := DeflateCompress(GData);
  GGzipCompressed := GzipCompress(GData);
  GLz4Compressed := Lz4Compress(GData);
end;
procedure BenchDeflateCompress(const ACtx: IBenchContext);
var LCompressed: TBytes;
begin LCompressed := DeflateCompress(GData); ACtx.SetBytes(DATA_SIZE); end;
procedure BenchGzipCompress(const ACtx: IBenchContext);
var LCompressed: TBytes;
begin LCompressed := GzipCompress(GData); ACtx.SetBytes(DATA_SIZE); end;
procedure BenchLz4Compress(const ACtx: IBenchContext);
var LCompressed: TBytes;
begin LCompressed := Lz4Compress(GData); ACtx.SetBytes(DATA_SIZE); end;
procedure BenchDeflateDecompress(const ACtx: IBenchContext);
var LDecompressed: TBytes;
begin LDecompressed := DeflateDecompress(GDeflateCompressed); ACtx.SetBytes(DATA_SIZE); end;
procedure BenchGzipDecompress(const ACtx: IBenchContext);
var LDecompressed: TBytes;
begin LDecompressed := GzipDecompress(GGzipCompressed); ACtx.SetBytes(DATA_SIZE); end;
procedure BenchLz4Decompress(const ACtx: IBenchContext);
var LDecompressed: TBytes;
begin LDecompressed := Lz4Decompress(GLz4Compressed, DATA_SIZE); ACtx.SetBytes(DATA_SIZE); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('compress');
  LSuite
    .Add('Deflate/Compress/1MB', @BenchDeflateCompress)
    .Add('Deflate/Decompress/1MB', @BenchDeflateDecompress)
    .Add('Gzip/Compress/1MB', @BenchGzipCompress)
    .Add('Gzip/Decompress/1MB', @BenchGzipDecompress)
    .Add('LZ4/Compress/1MB', @BenchLz4Compress)
    .Add('LZ4/Decompress/1MB', @BenchLz4Decompress);
  WriteLn(LSuite.Run.PrintToConsole);
end.
