unit nextpas.core.git.native.zlib;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.compress.base,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.git.native.base,
  nextpas.core.checksum.adler32;

{ Git stores loose objects and pack payloads in zlib wrapper format (RFC1950).
  Thin wrapper over compress.Deflate* (zlib) and checksum.adler32.Adler32Update
  — adds git-flavored error mapping and stream-boundary reporting, no handwritten
  deflate/adler loop. Inline thin forwards, zero-copy PByte+Len via bytes.ops
  single source, resource-free. git-native-zlib-l2-exempt }

function GitZlibAdler32(const AData: TBytes): UInt32; inline; overload;
function GitZlibAdler32(AData: PByte; ACount: SizeUInt): UInt32; inline; overload;
function GitZlibCompress(const AData: TBytes): TBytes; inline;
{ Inflate the zlib stream starting at AStart. AEndPos receives the offset just
  past the Adler-32 trailer, so callers can locate the trailer bytes. }
function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
{ Pointer-based variant over mmapped or otherwise externally owned memory.
  AData must stay valid while the returned bytes are used.
  Zero-copy: PByte+Len view, no extra alloc beyond result (delegates to
  compress DeflateDecompressPtrWithEndPos). }
function GitZlibDecompressPtr(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
{ Zero-alloc reuse variant: inflate into pre-sized ADst (bytes.ops single source).
  Caller ensures ADstLen = AExpectSize; returns actual size, no per-chunk Move. }
function GitZlibDecompressPtrToBuffer(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt; ADst: PByte; ADstLen: SizeUInt): SizeUInt;
{ Prefix variant: inflate only first ADstLen bytes (hot delta varint peek).
  Zero-copy stack buf, no alloc; returns produced bytes, never "dest too small".
  Single source via compress DeflateDecompressPtrPrefix. }
function GitZlibDecompressPrefix(AData: PByte; ACount, AStart: SizeUInt;
  ADst: PByte; ADstLen: SizeUInt; out AEndPos: SizeUInt): SizeUInt;

implementation

function GitZlibAdler32(const AData: TBytes): UInt32; inline;
begin
  if Length(AData) = 0 then
    Exit(UInt32(ADLER32_INIT));
  Result := UInt32(Adler32Update(ADLER32_INIT, PByte(AData), SizeUInt(Length(AData))));
end;

function GitZlibAdler32(AData: PByte; ACount: SizeUInt): UInt32; inline;
begin
  if (ACount = 0) or (AData = nil) then
    Exit(UInt32(ADLER32_INIT));
  Result := UInt32(Adler32Update(ADLER32_INIT, AData, ACount));
end;

function GitZlibCompress(const AData: TBytes): TBytes; inline;
begin
  { inline thin forward: single Move-free delegation to compress owner;
    no duplicate deflate logic, zero-copy via TBytes ref, resource-free. }
  Result := DeflateCompress(AData);
end;

function MapDeflateError(const E: Exception): EGitError; inline;
begin
  // typed high-level mapping: switch on TDeflateErrorCode, zero string Pos
  // perf: inline case dispatch, zero alloc beyond EGitError message, no Move
  // stability: original E freed by handler, inflateEnd in try..finally of owner
  if E is EDeflateError then
    case EDeflateError(E).Code of
      decTruncated:
        Result := EGitError.Create('truncated zlib stream');
      decInvalidHeader:
        Result := EGitError.Create('zlib stream is not deflate');
      decInvalidWindowBits,
      decCorruptHeader:
        Result := EGitError.Create('corrupt zlib header');
      decPresetDictionary:
        Result := EGitError.Create('zlib preset dictionary unsupported');
      decStreamTooLarge:
        Result := EGitError.Create('zlib stream too large');
      decCorruptStream,
      decTrailingBytes:
        Result := EGitError.Create('corrupt zlib payload: data error');
    else
      Result := EGitError.Create('corrupt zlib payload');
    end
  else
    // fallback: non-typed EIOError or future raw path — typed Code dispatch, no Pos, no E.Message concat
    Result := EGitError.Create('corrupt zlib payload');
end;

function GitZlibDecompressPtr(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  try
    Result := DeflateDecompressPtrWithEndPos(AData, ACount, AStart, AEndPos);
  except
    on E: EDeflateError do
      raise MapDeflateError(E);
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create('corrupt zlib payload');
  end;
end;

function GitZlibDecompressPtrToBuffer(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt; ADst: PByte; ADstLen: SizeUInt): SizeUInt;
begin
  try
    Result := DeflateDecompressPtrWithEndPosToBuffer(AData, ACount, AStart, AEndPos, ADst, ADstLen);
  except
    on E: EDeflateError do
      raise MapDeflateError(E);
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create('corrupt zlib payload');
  end;
end;

function GitZlibDecompressPrefix(AData: PByte; ACount, AStart: SizeUInt;
  ADst: PByte; ADstLen: SizeUInt; out AEndPos: SizeUInt): SizeUInt;
begin
  // not inline — heavy inflate prefix stays out-of-line; zero-copy PByte view
  // stability: inflateEnd in try..finally of owner, no leak on EDeflateError
  try
    Result := DeflateDecompressPtrPrefix(AData, ACount, AStart, ADst, ADstLen, AEndPos);
  except
    on E: EDeflateError do
      raise MapDeflateError(E);
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create('corrupt zlib payload');
  end;
end;

function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  if Length(AData) = 0 then
    raise EGitError.Create('truncated zlib stream');
  try
    Result := DeflateDecompressWithEndPos(AData, AStart, AEndPos);
  except
    on E: EGitError do raise;
    on E: EDeflateError do
      raise MapDeflateError(E);
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create('corrupt zlib payload');
  end;
end;

end.
