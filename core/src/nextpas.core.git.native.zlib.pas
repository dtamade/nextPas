unit nextpas.core.git.native.zlib;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.git.native.base;

{ Git stores loose objects and pack payloads in zlib wrapper format (RFC1950).
  The compress module's Deflate* functions already emit/accept full zlib
  streams (header + deflate + adler32), so this unit only adds git-flavored
  error mapping and stream-boundary reporting over them. }

function GitZlibAdler32(const AData: TBytes): UInt32;
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

uses zlib;

const
  CBufSize = 16384;

type
  { Read view over a byte region; the underlying memory must outlive the reader }
  TBytesSliceReader = class(TInterfacedObject, IReader)
  private
    FData: PByte;
    FLen: SizeUInt;
    FPos: SizeUInt;
  public
    constructor Create(AData: PByte; ACount, AOffset: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    property Position: SizeUInt read FPos;
  end;

constructor TBytesSliceReader.Create(AData: PByte; ACount, AOffset: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FLen := ACount;
  if AOffset > FLen then
    raise EGitError.Create('zlib stream start out of range');
  FPos := AOffset;
end;

function TBytesSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
begin
  if FPos >= FLen then
    Exit(0);
  Avail := FLen - FPos;
  if ACount < Avail then
    Avail := ACount;
  Move((FData + FPos)^, ABuf, Avail);
  Inc(FPos, Avail);
  Result := Avail;
end;

function GitZlibAdler32(const AData: TBytes): UInt32;
var
  I: SizeInt;
  A, B: UInt32;
begin
  A := 1;
  B := 0;
  for I := 0 to Length(AData) - 1 do
  begin
    A := (A + AData[I]) mod 65521;
    B := (B + A) mod 65521;
  end;
  Result := (B shl 16) or A;
end;

function GitZlibCompress(const AData: TBytes): TBytes;
begin
  // DeflateCompress emits a complete zlib stream (header + deflate + adler32)
  Result := DeflateCompress(AData);
end;

procedure ValidateZlibHeaderAt(AData: PByte; ACount, AStart: SizeUInt);
var
  Cmf, Flg: Byte;
begin
  if ACount < AStart + 2 then
    raise EGitError.Create('truncated zlib stream');
  Cmf := AData[AStart];
  Flg := AData[AStart + 1];
  if (Cmf and $0F) <> $08 then
    raise EGitError.Create('zlib stream is not deflate');
  if ((Cardinal(Cmf) shl 8) or Flg) mod 31 <> 0 then
    raise EGitError.Create('corrupt zlib header');
  if (Flg and $20) <> 0 then
    raise EGitError.Create('zlib preset dictionary unsupported');
end;

function GitZlibDecompressPtr(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
var
  Strm: z_stream;
  Ret: Integer;
  OutBuf: array[0..CBufSize - 1] of Byte;
  Total: SizeInt;
  InSize: LongWord;
begin
  ValidateZlibHeaderAt(AData, ACount, AStart);
  Result := nil;
  FillChar(Strm, SizeOf(Strm), 0);
  Strm.next_in := pBytef(AData + AStart);
  InSize := LongWord(ACount - AStart);
  if InSize > High(LongWord) then
    raise EGitError.Create('zlib stream too large');
  Strm.avail_in := InSize;
  if inflateInit(Strm) <> Z_OK then
    raise EGitError.Create('inflateInit failed');
  try
    Total := 0;
    repeat
      Strm.next_out := @OutBuf[0];
      Strm.avail_out := CBufSize;
      Ret := inflate(Strm, Z_NO_FLUSH);
      if (Ret <> Z_OK) and (Ret <> Z_STREAM_END) and (Ret <> Z_BUF_ERROR) then
      begin
        if Ret = Z_DATA_ERROR then
          raise EGitError.Create('corrupt zlib payload: data error');
        raise EGitError.CreateFmt('corrupt zlib payload: inflate %d', [Ret]);
      end;
      if CBufSize - Strm.avail_out > 0 then
      begin
        SetLength(Result, Total + (CBufSize - Strm.avail_out));
        Move(OutBuf[0], Result[Total], CBufSize - Strm.avail_out);
        Inc(Total, CBufSize - Strm.avail_out);
      end;
      if Ret = Z_STREAM_END then Break;
      if (Ret = Z_BUF_ERROR) and (Strm.avail_in = 0) then
        raise EGitError.Create('corrupt zlib payload: truncated stream');
    until False;
    AEndPos := AStart + SizeUInt(Strm.total_in);
  except
    on E: EIOError do
      raise EGitError.Create('corrupt zlib payload: ' + E.Message);
  end;
  inflateEnd(Strm);
end;

function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  if Length(AData) = 0 then
    raise EGitError.Create('truncated zlib stream');
  Result := GitZlibDecompressPtr(PByte(AData), SizeUInt(Length(AData)),
    AStart, AEndPos);
end;

end.
