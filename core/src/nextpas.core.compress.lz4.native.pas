unit nextpas.core.compress.lz4.native;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.compress.base;

function NativeLz4Compress(const AData: TBytes): TBytes;
function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
function NativeLz4DecompressWithMaxOutputSize(const AData: TBytes;
  const AOriginalSize: Int32; const AMaxOutputSize: SizeUInt): TBytes;
function NativeLz4CompressBound(const AInputSize: Int32): Int32;

implementation

uses
  nextpas.core.errors,
  nextpas.core.compress.lz4
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  , nextpas.core.compress.lz4.ffi
  {$ENDIF}
  ;

function IsLz4FrameHeader(const AData: TBytes): Boolean; inline;
var
  LMagic: UInt32;
  LSkippableSize: UInt32;
begin
  if Length(AData) < 4 then
    Exit(False);
  LMagic := UInt32(AData[0]) or (UInt32(AData[1]) shl 8) or
    (UInt32(AData[2]) shl 16) or (UInt32(AData[3]) shl 24);
  if LMagic = $184D2204 then
    Exit(True);
  if LMagic = $184C2102 then
    Exit(True);
  if (LMagic and $FFFFFFF0) = $184D2A50 then
  begin
    if Length(AData) = 4 then
      Exit(True);
    if Length(AData) < 8 then
      Exit(False);
    LSkippableSize := UInt32(AData[4]) or (UInt32(AData[5]) shl 8) or
      (UInt32(AData[6]) shl 16) or (UInt32(AData[7]) shl 24);
    Exit(SizeUInt(Length(AData)) - 8 >= SizeUInt(LSkippableSize));
  end;
  Result := False;
end;

{$IFDEF NEXTPAS_USE_LZ4_NATIVE}

function NativeLz4CompressBound(const AInputSize: Int32): Int32;
begin
  if AInputSize < 0 then
    raise EIOError.Create('lz4 native: invalid input size');
  if SizeUInt(AInputSize) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: input size exceeds limit');
  Result := LZ4_compressBound(AInputSize);
  if Result <= 0 then
    raise EIOError.Create('lz4 native: invalid compression bound');
end;

function NativeLz4Compress(const AData: TBytes): TBytes;
var
  LBound, LCompressed: Int32;
begin
  if Length(AData) = 0 then
  begin
    Result := nil;
    Exit;
  end;
  if SizeUInt(Length(AData)) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: input size exceeds limit');
  LBound := NativeLz4CompressBound(Int32(Length(AData)));
  SetLength(Result, LBound);
  LCompressed := LZ4_compress_default(@AData[0], @Result[0], Length(AData), LBound);
  if LCompressed <= 0 then
    raise EIOError.Create('lz4 native: compress failed');
  SetLength(Result, LCompressed);
end;

function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
begin
  Result := NativeLz4DecompressWithMaxOutputSize(AData, AOriginalSize, LZ4_MAX_INPUT_SIZE);
end;

function NativeLz4DecompressWithMaxOutputSize(const AData: TBytes;
  const AOriginalSize: Int32; const AMaxOutputSize: SizeUInt): TBytes;
var
  LDecompressed: Int32;

  procedure RaiseAfterClearingResult(const AMessage: string);
  begin
    SetLength(Result, 0);
    raise EIOError.Create(AMessage);
  end;

begin
  if AOriginalSize < 0 then
    raise EIOError.Create('lz4 native: invalid original size');
  if SizeUInt(AOriginalSize) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: original size exceeds limit');
  if SizeUInt(AOriginalSize) > AMaxOutputSize then
    raise EIOError.Create('lz4 native: decompressed size exceeds limit');
  if Length(AData) = 0 then
  begin
    if AOriginalSize <> 0 then
      raise EIOError.Create('lz4 native: empty input with nonzero original size');
    Result := nil;
    Exit;
  end;
  if AOriginalSize = 0 then
  begin
    if IsLz4FrameHeader(AData) then
      raise EIOError.Create('lz4: unsupported frame/header');
    raise EIOError.Create('lz4 native: non-empty input with zero original size');
  end;
  if SizeUInt(Length(AData)) > SizeUInt(High(Int32)) then
    raise EIOError.Create('lz4: compressed input size exceeds limit');
  if IsLz4FrameHeader(AData) then
    raise EIOError.Create('lz4: unsupported frame/header');
  SetLength(Result, AOriginalSize);
  LDecompressed := LZ4_decompress_safe(@AData[0], @Result[0], Length(AData), AOriginalSize);
  if LDecompressed < 0 then
  begin
    if IsLz4FrameHeader(AData) then
      RaiseAfterClearingResult('lz4: unsupported frame/header');
    RaiseAfterClearingResult('lz4 native: decompress failed');
  end;
  if LDecompressed <> AOriginalSize then
    RaiseAfterClearingResult('lz4 native: size mismatch');
end;

{$ELSE}

function NativeLz4CompressBound(const AInputSize: Int32): Int32;
begin
  if AInputSize < 0 then
    raise EIOError.Create('lz4 native: invalid input size');
  if SizeUInt(AInputSize) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: input size exceeds limit');
  Result := Int32(nextpas.core.compress.lz4.Lz4CompressBound(AInputSize));
end;

function NativeLz4Compress(const AData: TBytes): TBytes;
begin
  if SizeUInt(Length(AData)) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: input size exceeds limit');
  Result := nextpas.core.compress.lz4.Lz4Compress(AData);
end;

function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
begin
  Result := NativeLz4DecompressWithMaxOutputSize(AData, AOriginalSize, LZ4_MAX_INPUT_SIZE);
end;

function NativeLz4DecompressWithMaxOutputSize(const AData: TBytes;
  const AOriginalSize: Int32; const AMaxOutputSize: SizeUInt): TBytes;
begin
  if AOriginalSize < 0 then
    raise EIOError.Create('lz4 native: invalid original size');
  if SizeUInt(AOriginalSize) > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: original size exceeds limit');
  if SizeUInt(AOriginalSize) > AMaxOutputSize then
    raise EIOError.Create('lz4 native: decompressed size exceeds limit');
  if Length(AData) = 0 then
  begin
    if AOriginalSize <> 0 then
      raise EIOError.Create('lz4 native: empty input with nonzero original size');
    Result := nil;
    Exit;
  end;
  if AOriginalSize = 0 then
  begin
    if IsLz4FrameHeader(AData) then
      raise EIOError.Create('lz4: unsupported frame/header');
    raise EIOError.Create('lz4 native: non-empty input with zero original size');
  end;
  if SizeUInt(Length(AData)) > SizeUInt(High(Int32)) then
    raise EIOError.Create('lz4: compressed input size exceeds limit');
  if IsLz4FrameHeader(AData) then
    raise EIOError.Create('lz4: unsupported frame/header');
  Result := nextpas.core.compress.lz4.Lz4DecompressWithMaxOutputSize(
    AData, AOriginalSize, AMaxOutputSize);
end;

{$ENDIF}

end.
