unit nextpas.core.compress;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress.deflate,
  nextpas.core.compress.gzip,
  nextpas.core.compress.lz4;

type
  TCompressionLevel = nextpas.core.compress.base.TCompressionLevel;
  ICompressWriter = nextpas.core.compress.intf.ICompressWriter;
  IDecompressReader = nextpas.core.compress.intf.IDecompressReader;

function DeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter; inline;
function DeflateReader(const ASrc: IReader): IDecompressReader; inline;
function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function DeflateDecompress(const AData: TBytes): TBytes; inline;
function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function GzipDecompress(const AData: TBytes): TBytes; inline;
function Lz4Compress(const AData: TBytes): TBytes; inline;
function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes; inline;

implementation

function DeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateWriter(ADst, ALevel);
end;

function DeflateReader(const ASrc: IReader): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateReader(ASrc);
end;

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateCompress(AData, ALevel);
end;

function DeflateDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateDecompress(AData);
end;

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.gzip.GzipCompress(AData, ALevel);
end;

function GzipDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.gzip.GzipDecompress(AData);
end;

function Lz4Compress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.lz4.Lz4Compress(AData);
end;

function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
begin
  Result := nextpas.core.compress.lz4.Lz4Decompress(AData, AOriginalSize);
end;

end.
