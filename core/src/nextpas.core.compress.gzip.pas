unit nextpas.core.compress.gzip;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf;

function CreateGzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter;
function CreateGzipReader(const ASrc: IReader): IDecompressReader;

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function GzipDecompress(const AData: TBytes): TBytes;

implementation

uses
  zlib, nextpas.core.errors;

{$PUSH}{$WARN 5024 OFF}
const
  GZIP_HDR: array[0..9] of Byte = (
    $1F, $8B, $08, $00,
    $00, $00, $00, $00,
    $00, $FF
  );
{$POP}

type
  TGzipWriter = class(TInterfacedObject, IWriter, ICompressWriter)
  private
    FDst: IWriter;
    FStream: z_stream;
    FBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FCRC: UInt32;
    FSize: UInt32;
    procedure FlushOutput(AFlush: Int32);
    procedure WriteTrailer;
  public
    constructor Create(const ADst: IWriter; ALevel: Int32);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
  end;

  TGzipReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FSrc: IReader;
    FStream: z_stream;
    FInBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FDone: Boolean;
    FCRC: UInt32;
    FSize: UInt32;
  public
    constructor Create(const ASrc: IReader);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

{ TGzipWriter }

constructor TGzipWriter.Create(const ADst: IWriter; ALevel: Int32);
var
  LWritten: SizeUInt;
begin
  inherited Create;
  FDst := ADst;
  FCRC := 0;
  FSize := 0;
  LWritten := FDst.Write(GZIP_HDR[0], 10);
  if LWritten <> 10 then
    raise EIOError.Create('gzip: header write failed');
  FillChar(FStream, SizeOf(FStream), 0);
  if deflateInit2(FStream, ALevel, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('gzip: deflateInit2 failed');
  FInitialized := True;
end;

destructor TGzipWriter.Destroy;
begin
  if FInitialized then
  begin
    FInitialized := False;
    try
      FlushOutput(Z_FINISH);
      WriteTrailer;
    finally
      deflateEnd(FStream);
    end;
  end;
  inherited;
end;

procedure TGzipWriter.FlushOutput(AFlush: Int32);
var
  LHave, LWritten: SizeUInt;
begin
  repeat
    FStream.next_out := @FBuf[0];
    FStream.avail_out := COMPRESS_BUF_SIZE;
    deflate(FStream, AFlush);
    LHave := COMPRESS_BUF_SIZE - FStream.avail_out;
    if LHave > 0 then
    begin
      LWritten := FDst.Write(FBuf[0], LHave);
      if LWritten <> LHave then
        raise EIOError.Create('gzip: short write');
    end;
  until FStream.avail_out <> 0;
end;

procedure TGzipWriter.WriteTrailer;
var
  LTrailer: array[0..7] of Byte;
begin
  LTrailer[0] := Byte(FCRC);
  LTrailer[1] := Byte(FCRC shr 8);
  LTrailer[2] := Byte(FCRC shr 16);
  LTrailer[3] := Byte(FCRC shr 24);
  LTrailer[4] := Byte(FSize);
  LTrailer[5] := Byte(FSize shr 8);
  LTrailer[6] := Byte(FSize shr 16);
  LTrailer[7] := Byte(FSize shr 24);
  FDst.Write(LTrailer[0], 8);
end;

function TGzipWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then Exit(0);
  {$PUSH}{$Q-}{$R-}
  FCRC := UInt32(crc32(ULong(FCRC), @ABuf, ACount));
  Inc(FSize, UInt32(ACount));
  {$POP}
  FStream.next_in := @ABuf;
  FStream.avail_in := ACount;
  FlushOutput(Z_NO_FLUSH);
  Result := ACount;
end;

procedure TGzipWriter.Flush;
begin
  FlushOutput(Z_SYNC_FLUSH);
end;

procedure TGzipWriter.Close;
begin
  if FInitialized then
  begin
    FInitialized := False;
    try
      FlushOutput(Z_FINISH);
      WriteTrailer;
    finally
      deflateEnd(FStream);
    end;
  end;
end;

{ TGzipReader }

constructor TGzipReader.Create(const ASrc: IReader);
var
  LHdr: array[0..9] of Byte;
  LRead: SizeUInt;
  LFlags: Byte;
  LByte: Byte;
  LSkip: UInt16;
begin
  inherited Create;
  FSrc := ASrc;
  FCRC := 0;
  FSize := 0;
  FDone := False;

  LRead := FSrc.Read(LHdr[0], 10);
  if LRead < 10 then
    raise EIOError.Create('gzip: header too short');
  if (LHdr[0] <> $1F) or (LHdr[1] <> $8B) then
    raise EIOError.Create('gzip: invalid magic');
  if LHdr[2] <> $08 then
    raise EIOError.Create('gzip: unsupported method');

  LFlags := LHdr[3];
  if (LFlags and $04) <> 0 then // FEXTRA
  begin
    FSrc.Read(LByte, 1);
    LSkip := LByte;
    FSrc.Read(LByte, 1);
    LSkip := LSkip or (UInt16(LByte) shl 8);
    while LSkip > 0 do begin FSrc.Read(LByte, 1); Dec(LSkip); end;
  end;
  if (LFlags and $08) <> 0 then // FNAME
    repeat FSrc.Read(LByte, 1); until LByte = 0;
  if (LFlags and $10) <> 0 then // FCOMMENT
    repeat FSrc.Read(LByte, 1); until LByte = 0;
  if (LFlags and $02) <> 0 then // FHCRC
  begin FSrc.Read(LByte, 1); FSrc.Read(LByte, 1); end;

  FillChar(FStream, SizeOf(FStream), 0);
  if inflateInit2(FStream, -15) <> Z_OK then
    raise EIOError.Create('gzip: inflateInit2 failed');
  FInitialized := True;
end;

destructor TGzipReader.Destroy;
begin
  if FInitialized then
    inflateEnd(FStream);
  inherited;
end;

function TGzipReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRet: Int32;
  LRead: SizeUInt;
begin
  if FDone or (ACount = 0) then Exit(0);
  FStream.next_out := @ABuf;
  FStream.avail_out := ACount;
  while FStream.avail_out > 0 do
  begin
    if FStream.avail_in = 0 then
    begin
      LRead := FSrc.Read(FInBuf[0], COMPRESS_BUF_SIZE);
      if LRead = 0 then
      begin
        FDone := True;
        Break;
      end;
      FStream.next_in := @FInBuf[0];
      FStream.avail_in := LRead;
    end;
    LRet := inflate(FStream, Z_NO_FLUSH);
    if LRet = Z_STREAM_END then
    begin
      FDone := True;
      Break;
    end;
    if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      raise EIOError.Create('gzip: inflate failed (' + IntToStr(LRet) + ')');
  end;
  Result := ACount - FStream.avail_out;
  if Result > 0 then
  begin
    {$PUSH}{$Q-}{$R-}
    FCRC := UInt32(crc32(ULong(FCRC), @ABuf, Result));
    Inc(FSize, UInt32(Result));
    {$POP}
  end;
end;

procedure TGzipReader.Close;
var
  LTrailer: array[0..7] of Byte;
  LExpectedCRC, LExpectedSize: UInt32;
  LAvail, LNeed: SizeUInt;
  LNextIn: PByte;
begin
  if FInitialized then
  begin
    LAvail := FStream.avail_in;
    LNextIn := PByte(FStream.next_in);
    inflateEnd(FStream);
    FInitialized := False;

    LNeed := 8;
    if LAvail >= LNeed then
    begin
      Move(LNextIn^, LTrailer[0], 8);
    end
    else
    begin
      if LAvail > 0 then
        Move(LNextIn^, LTrailer[0], LAvail);
      LNeed := 8 - LAvail;
      if FSrc.Read(LTrailer[LAvail], LNeed) <> LNeed then
        raise EIOError.Create('gzip: truncated trailer');
    end;

    LExpectedCRC := UInt32(LTrailer[0]) or (UInt32(LTrailer[1]) shl 8) or
      (UInt32(LTrailer[2]) shl 16) or (UInt32(LTrailer[3]) shl 24);
    LExpectedSize := UInt32(LTrailer[4]) or (UInt32(LTrailer[5]) shl 8) or
      (UInt32(LTrailer[6]) shl 16) or (UInt32(LTrailer[7]) shl 24);
    if LExpectedCRC <> FCRC then
      raise EIOError.Create('gzip: CRC32 mismatch');
    if LExpectedSize <> FSize then
      raise EIOError.Create('gzip: size mismatch');
  end;
end;

{ Factory }

function CreateGzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := TGzipWriter.Create(ADst, LevelToZlib(ALevel));
end;

function CreateGzipReader(const ASrc: IReader): IDecompressReader;
begin
  Result := TGzipReader.Create(ASrc);
end;

{ One-shot }

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LStream: z_stream;
  LBuf: array[0..32767] of Byte;
  LOut: TBytes;
  LOutLen, LHave: SizeUInt;
  LCRC: UInt32;
  LSize: UInt32;
begin
  Result := nil;
  if Length(AData) = 0 then
  begin
    SetLength(Result, 20);
    Move(GZIP_HDR[0], Result[0], 10);
    Result[10] := $03; Result[11] := $00;
    FillChar(Result[12], 8, 0);
    Exit;
  end;

  LCRC := UInt32(crc32(0, @AData[0], Length(AData)));
  LSize := UInt32(Length(AData));

  FillChar(LStream, SizeOf(LStream), 0);
  if deflateInit2(LStream, LevelToZlib(ALevel), Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('gzip: deflateInit2 failed');

  LStream.next_in := @AData[0];
  LStream.avail_in := Length(AData);

  LOutLen := 0;
  SetLength(LOut, Length(AData) + 256);

  repeat
    LStream.next_out := @LBuf[0];
    LStream.avail_out := SizeOf(LBuf);
    deflate(LStream, Z_FINISH);
    LHave := SizeOf(LBuf) - LStream.avail_out;
    if LOutLen + LHave > SizeUInt(Length(LOut)) then
      SetLength(LOut, (LOutLen + LHave) * 2);
    Move(LBuf[0], LOut[LOutLen], LHave);
    Inc(LOutLen, LHave);
  until LStream.avail_out <> 0;

  deflateEnd(LStream);

  SetLength(Result, 10 + LOutLen + 8);
  Move(GZIP_HDR[0], Result[0], 10);
  if LOutLen > 0 then
    Move(LOut[0], Result[10], LOutLen);
  Result[10 + LOutLen + 0] := Byte(LCRC);
  Result[10 + LOutLen + 1] := Byte(LCRC shr 8);
  Result[10 + LOutLen + 2] := Byte(LCRC shr 16);
  Result[10 + LOutLen + 3] := Byte(LCRC shr 24);
  Result[10 + LOutLen + 4] := Byte(LSize);
  Result[10 + LOutLen + 5] := Byte(LSize shr 8);
  Result[10 + LOutLen + 6] := Byte(LSize shr 16);
  Result[10 + LOutLen + 7] := Byte(LSize shr 24);
end;

function GzipDecompress(const AData: TBytes): TBytes;
const
  MAX_DECOMPRESS_SIZE = 256 * 1024 * 1024;
var
  LStream: z_stream;
  LBuf: array[0..32767] of Byte;
  LOutLen, LHave: SizeUInt;
  LOffset: SizeUInt;
  LRet: Int32;
  LFlags: Byte;
  LExpectedCRC, LActualCRC: UInt32;
  LExpectedSize: UInt32;
  LTrailerOfs: SizeUInt;
begin
  Result := nil;
  if Length(AData) < 18 then
    raise EIOError.Create('gzip: data too short');
  if (AData[0] <> $1F) or (AData[1] <> $8B) then
    raise EIOError.Create('gzip: invalid magic');
  if AData[2] <> $08 then
    raise EIOError.Create('gzip: unsupported method');

  LFlags := AData[3];
  LOffset := 10;
  if (LFlags and $04) <> 0 then
  begin
    if LOffset + 2 > SizeUInt(Length(AData)) then
      raise EIOError.Create('gzip: truncated FEXTRA');
    LOffset := LOffset + 2 + UInt16(AData[LOffset]) + (UInt16(AData[LOffset + 1]) shl 8);
  end;
  if (LFlags and $08) <> 0 then
    while (LOffset < SizeUInt(Length(AData))) and (AData[LOffset] <> 0) do Inc(LOffset);
  if (LFlags and $08) <> 0 then Inc(LOffset);
  if (LFlags and $10) <> 0 then
    while (LOffset < SizeUInt(Length(AData))) and (AData[LOffset] <> 0) do Inc(LOffset);
  if (LFlags and $10) <> 0 then Inc(LOffset);
  if (LFlags and $02) <> 0 then
    Inc(LOffset, 2);

  if LOffset + 8 >= SizeUInt(Length(AData)) then
    raise EIOError.Create('gzip: header too large');

  FillChar(LStream, SizeOf(LStream), 0);
  LStream.next_in := @AData[LOffset];
  LStream.avail_in := SizeUInt(Length(AData)) - LOffset - 8;

  if inflateInit2(LStream, -15) <> Z_OK then
    raise EIOError.Create('gzip: inflateInit2 failed');

  LOutLen := 0;
  SetLength(Result, Length(AData) * 4);

  repeat
    LStream.next_out := @LBuf[0];
    LStream.avail_out := SizeOf(LBuf);
    LRet := inflate(LStream, Z_NO_FLUSH);
    if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) then
    begin
      inflateEnd(LStream);
      raise EIOError.Create('gzip: inflate failed (' + IntToStr(LRet) + ')');
    end;
    LHave := SizeOf(LBuf) - LStream.avail_out;
    if LOutLen + LHave > MAX_DECOMPRESS_SIZE then
    begin
      inflateEnd(LStream);
      raise EIOError.Create('gzip: decompressed size exceeds limit');
    end;
    if LOutLen + LHave > SizeUInt(Length(Result)) then
      SetLength(Result, (LOutLen + LHave) * 2);
    Move(LBuf[0], Result[LOutLen], LHave);
    Inc(LOutLen, LHave);
  until LRet = Z_STREAM_END;

  inflateEnd(LStream);
  SetLength(Result, LOutLen);

  LTrailerOfs := SizeUInt(Length(AData)) - 8;
  LExpectedCRC := UInt32(AData[LTrailerOfs]) or (UInt32(AData[LTrailerOfs + 1]) shl 8) or
    (UInt32(AData[LTrailerOfs + 2]) shl 16) or (UInt32(AData[LTrailerOfs + 3]) shl 24);
  LExpectedSize := UInt32(AData[LTrailerOfs + 4]) or (UInt32(AData[LTrailerOfs + 5]) shl 8) or
    (UInt32(AData[LTrailerOfs + 6]) shl 16) or (UInt32(AData[LTrailerOfs + 7]) shl 24);

  if LExpectedSize <> UInt32(LOutLen) then
    raise EIOError.Create('gzip: size mismatch');

  if LOutLen > 0 then
    LActualCRC := UInt32(crc32(0, @Result[0], LOutLen))
  else
    LActualCRC := 0;
  if LActualCRC <> LExpectedCRC then
    raise EIOError.Create('gzip: CRC32 mismatch');
end;

end.
