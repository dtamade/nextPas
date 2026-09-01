unit nextpas.core.git.native.zlib;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.git.native.base,
  nextpas.core.checksum.adler32;

{ Git stores loose objects and pack payloads in zlib wrapper format (RFC1950).
  The compress module's Deflate* functions already emit/accept full zlib
  streams (header + deflate + adler32), so this unit only adds git-flavored
  error mapping and stream-boundary reporting over them. }

function GitZlibAdler32(const AData: TBytes): UInt32; inline; overload;
function GitZlibAdler32(AData: PByte; ACount: SizeUInt): UInt32; inline; overload;
function GitZlibCompress(const AData: TBytes): TBytes;
{ Inflate the zlib stream starting at AStart. AEndPos receives the offset just
  past the Adler-32 trailer, so callers can locate the trailer bytes. }
function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
{ Pointer-based variant over mmapped or otherwise externally owned memory.
  AData must stay valid while the returned bytes are used. }
function GitZlibDecompressPtr(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;

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

function GitZlibCompress(const AData: TBytes): TBytes;
begin
  Result := DeflateCompress(AData);
end;

function MapDeflateError(const E: Exception): EGitError;
begin
  if Pos('truncated stream', E.Message) > 0 then
    Result := EGitError.Create('truncated zlib stream')
  else if Pos('invalid zlib header', E.Message) > 0 then
    Result := EGitError.Create('zlib stream is not deflate')
  else if Pos('invalid window bits', E.Message) > 0 then
    Result := EGitError.Create('corrupt zlib header')
  else if Pos('corrupt zlib header', E.Message) > 0 then
    Result := EGitError.Create('corrupt zlib header')
  else if Pos('preset dictionary', E.Message) > 0 then
    Result := EGitError.Create('zlib preset dictionary unsupported')
  else if Pos('zlib stream too large', E.Message) > 0 then
    Result := EGitError.Create('zlib stream too large')
  else if Pos('corrupt stream', E.Message) > 0 then
    Result := EGitError.Create('corrupt zlib payload: data error')
  else
    Result := EGitError.Create('corrupt zlib payload: ' + E.Message);
end;

function GitZlibDecompressPtr(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  try
    Result := DeflateDecompressPtrWithEndPos(AData, ACount, AStart, AEndPos);
  except
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create('corrupt zlib payload: ' + E.Message);
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
    on E: EIOError do
      raise MapDeflateError(E);
    on E: Exception do
      raise EGitError.Create(E.Message);
  end;
end;

end.
