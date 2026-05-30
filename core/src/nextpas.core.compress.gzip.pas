unit nextpas.core.compress.gzip;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.compress.base;

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function GzipDecompress(const AData: TBytes): TBytes;

implementation

uses
  zlib, nextpas.core.errors;

const
  GZIP_HEADER: array[0..9] of Byte = (
    $1F, $8B,  // magic
    $08,       // method = deflate
    $00,       // flags
    $00, $00, $00, $00, // mtime
    $00,       // xfl
    $FF        // OS = unknown
  );

function CRC32Update(ACRC: UInt32; const ABuf; ALen: SizeUInt): UInt32;
begin
  Result := UInt32(crc32(ULong(ACRC), @ABuf, ALen));
end;

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
    Move(GZIP_HEADER[0], Result[0], 10);
    Result[10] := $03; Result[11] := $00; // empty deflate
    FillChar(Result[12], 8, 0); // CRC32=0, size=0
    Exit;
  end;

  LCRC := CRC32Update(0, AData[0], Length(AData));
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

  // Assemble: header(10) + raw deflate + trailer(8)
  SetLength(Result, 10 + LOutLen + 8);
  Move(GZIP_HEADER[0], Result[0], 10);
  if LOutLen > 0 then
    Move(LOut[0], Result[10], LOutLen);
  // CRC32 little-endian
  Result[10 + LOutLen + 0] := Byte(LCRC);
  Result[10 + LOutLen + 1] := Byte(LCRC shr 8);
  Result[10 + LOutLen + 2] := Byte(LCRC shr 16);
  Result[10 + LOutLen + 3] := Byte(LCRC shr 24);
  // Size little-endian
  Result[10 + LOutLen + 4] := Byte(LSize);
  Result[10 + LOutLen + 5] := Byte(LSize shr 8);
  Result[10 + LOutLen + 6] := Byte(LSize shr 16);
  Result[10 + LOutLen + 7] := Byte(LSize shr 24);
end;

function GzipDecompress(const AData: TBytes): TBytes;
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

  // Parse header flags and skip optional fields (RFC 1952)
  LFlags := AData[3];
  LOffset := 10;
  if (LFlags and $04) <> 0 then // FEXTRA
  begin
    if LOffset + 2 > SizeUInt(Length(AData)) then
      raise EIOError.Create('gzip: truncated FEXTRA');
    LOffset := LOffset + 2 + UInt16(AData[LOffset]) + (UInt16(AData[LOffset + 1]) shl 8);
  end;
  if (LFlags and $08) <> 0 then // FNAME
    while (LOffset < SizeUInt(Length(AData))) and (AData[LOffset] <> 0) do Inc(LOffset);
  if (LFlags and $08) <> 0 then Inc(LOffset); // skip null terminator
  if (LFlags and $10) <> 0 then // FCOMMENT
    while (LOffset < SizeUInt(Length(AData))) and (AData[LOffset] <> 0) do Inc(LOffset);
  if (LFlags and $10) <> 0 then Inc(LOffset);
  if (LFlags and $02) <> 0 then // FHCRC
    Inc(LOffset, 2);

  if LOffset + 8 >= SizeUInt(Length(AData)) then
    raise EIOError.Create('gzip: header too large');

  FillChar(LStream, SizeOf(LStream), 0);
  LStream.next_in := @AData[LOffset];
  LStream.avail_in := SizeUInt(Length(AData)) - LOffset - 8; // exclude trailer

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
    if LOutLen + LHave > SizeUInt(Length(Result)) then
      SetLength(Result, (LOutLen + LHave) * 2);
    Move(LBuf[0], Result[LOutLen], LHave);
    Inc(LOutLen, LHave);
  until LRet = Z_STREAM_END;

  inflateEnd(LStream);
  SetLength(Result, LOutLen);

  // Verify CRC32 and original size from trailer
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
