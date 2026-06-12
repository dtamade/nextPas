program test_compress_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  zlib,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress,
  nextpas.core.compress.deflate,
  nextpas.core.compress.gzip,
  nextpas.core.compress.lz4,
  nextpas.core.compress.lz4.native,
  nextpas.core.compress.zlib.ffi;

var
  T: TTestRunner;

type
  TOneByteReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TCountingReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FReadCount: SizeUInt;
    FMaxChunk: SizeUInt;
  public
    constructor Create(const AData: TBytes; const AMaxChunk: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    property ReadCount: SizeUInt read FReadCount;
  end;

  TFailingReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FReadCount: SizeUInt;
    FMaxChunk: SizeUInt;
    FFailOnRead: SizeUInt;
    FFailed: Boolean;
  public
    constructor Create(const AData: TBytes; const AMaxChunk,
      AFailOnRead: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TShortWriter = class(TInterfacedObject, IWriter)
  private
    FFullWritesRemaining: SizeUInt;
  public
    constructor Create(const AFullWritesBeforeShort: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TRaisingWriter = class(TInterfacedObject, IWriter)
  private
    FWritesBeforeFailure: SizeUInt;
  public
    constructor Create(const AWritesBeforeFailure: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TOneByteReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
  FPosition := 0;
end;

function TOneByteReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (ACount = 0) or (FPosition >= SizeUInt(Length(FData))) then
    Exit(0);
  PByte(@ABuf)^ := FData[FPosition];
  Inc(FPosition);
  Result := 1;
end;

constructor TCountingReader.Create(const AData: TBytes; const AMaxChunk: SizeUInt);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
  FPosition := 0;
  FReadCount := 0;
  FMaxChunk := AMaxChunk;
end;

function TCountingReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  Inc(FReadCount);
  if (ACount = 0) or (FPosition >= SizeUInt(Length(FData))) then
    Exit(0);
  LAvailable := SizeUInt(Length(FData)) - FPosition;
  Result := ACount;
  if Result > FMaxChunk then
    Result := FMaxChunk;
  if Result > LAvailable then
    Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

constructor TFailingReader.Create(const AData: TBytes; const AMaxChunk,
  AFailOnRead: SizeUInt);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
  FPosition := 0;
  FReadCount := 0;
  FMaxChunk := AMaxChunk;
  FFailOnRead := AFailOnRead;
  FFailed := False;
end;

function TFailingReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  if FFailed then
    raise EIOError.Create('source read failed');

  Inc(FReadCount);
  if (FFailOnRead <> 0) and (FReadCount >= FFailOnRead) then
  begin
    FFailed := True;
    raise EIOError.Create('source read failed');
  end;

  if FPosition >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvailable := SizeUInt(Length(FData)) - FPosition;
  Result := ACount;
  if Result > FMaxChunk then
    Result := FMaxChunk;
  if Result > LAvailable then
    Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

constructor TShortWriter.Create(const AFullWritesBeforeShort: SizeUInt);
begin
  inherited Create;
  FFullWritesRemaining := AFullWritesBeforeShort;
end;

function TShortWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  if FFullWritesRemaining > 0 then
  begin
    Dec(FFullWritesRemaining);
    Exit(ACount);
  end;
  Result := ACount - 1;
end;

constructor TRaisingWriter.Create(const AWritesBeforeFailure: SizeUInt);
begin
  inherited Create;
  FWritesBeforeFailure := AWritesBeforeFailure;
end;

function TRaisingWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  if FWritesBeforeFailure = 0 then
    raise EIOError.Create('sink write failed');
  Dec(FWritesBeforeFailure);
  Result := ACount;
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes; const ALabel: string);
var
  LI: SizeInt;
begin
  CheckEqual(Int64(Length(AExpected)), Int64(Length(AActual)),
    ALabel + ' length');
  if Length(AExpected) <> Length(AActual) then
    Exit;
  for LI := 0 to High(AExpected) do
    if AExpected[LI] <> AActual[LI] then
    begin
      Check(False, ALabel + ' mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, ALabel + ' bytes');
end;

procedure CheckMalformedLz4RawBlockRejected(const AData: TBytes;
  const AOriginalSize: Int32; const AExpectedPureError, APureLabel,
  AFacadeLabel, ANativeLabel: string);
var
  LGotPure: Boolean;
  LGotFacade: Boolean;
  LGotNative: Boolean;
begin
  LGotPure := False;
  try
    nextpas.core.compress.lz4.Lz4Decompress(AData, AOriginalSize);
  except
    on E: EIOError do
      LGotPure := Pos(AExpectedPureError, E.Message) > 0;
  end;
  Check(LGotPure, APureLabel);

  LGotFacade := False;
  try
    nextpas.core.compress.Lz4Decompress(AData, AOriginalSize);
  except
    on E: EIOError do
      LGotFacade := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos(AExpectedPureError, E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGotFacade, AFacadeLabel);

  LGotNative := False;
  try
    nextpas.core.compress.lz4.native.NativeLz4Decompress(AData, AOriginalSize);
  except
    on E: EIOError do
      LGotNative := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos(AExpectedPureError, E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGotNative, ANativeLabel);
end;

{ === A. Boundary Size Tests === }

procedure TestDeflate63Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 63);
  FillChar(LSrc[0], 63, $AB);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(63), Int64(Length(LD)), 'deflate 63 bytes');
  Check(LD[0] = $AB, 'content correct');
end;

procedure TestDeflate64Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 64);
  FillChar(LSrc[0], 64, $CD);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(64), Int64(Length(LD)), 'deflate 64 bytes');
end;

procedure TestDeflate65Bytes;
var LSrc, LC, LD: TBytes;
begin
  SetLength(LSrc, 65);
  FillChar(LSrc[0], 65, $EF);
  LC := DeflateCompress(LSrc);
  LD := DeflateDecompress(LC);
  CheckEqual(Int64(65), Int64(Length(LD)), 'deflate 65 bytes');
end;

procedure TestNativeZlibVersionAvailable;
var
  LVersion: PAnsiChar;
begin
  LVersion := NativeZlibVersion;
  Check(LVersion <> nil, 'native zlib version pointer is non-nil');
  Check(LVersion[0] <> #0, 'native zlib version string is non-empty');
end;

procedure TestLz4_1to3Bytes;
var LSrc, LC, LD: TBytes;
    LI: Int32;
begin
  for LI := 1 to 3 do
  begin
    SetLength(LSrc, LI);
    FillChar(LSrc[0], LI, Byte(LI));
    LC := Lz4Compress(LSrc);
    Check(Length(LC) > 0, 'lz4 ' + IntToStr(LI) + ' bytes compresses');
    LD := Lz4Decompress(LC, LI);
    CheckEqual(Int64(LI), Int64(Length(LD)), 'lz4 ' + IntToStr(LI) + ' round-trip');
    Check(LD[0] = Byte(LI), 'lz4 ' + IntToStr(LI) + ' content');
  end;
end;

procedure TestLz4_4Bytes;
var LSrc, LC, LD: TBytes;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  LC := Lz4Compress(LSrc);
  LD := Lz4Decompress(LC, 4);
  CheckEqual(Int64(4), Int64(Length(LD)), 'lz4 4 bytes');
  Check((LD[0]=1) and (LD[3]=4), 'lz4 4 content');
end;

procedure TestLz4RandomData;
var LSrc, LC, LD: TBytes;
    LI: Int32;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to 4095 do
    LSrc[LI] := Byte(Random(256));
  LC := Lz4Compress(LSrc);
  Check(Length(LC) > 0, 'random compresses');
  Check(SizeUInt(Length(LC)) <= Lz4CompressBound(4096), 'within bound');
  LD := Lz4Decompress(LC, 4096);
  CheckEqual(Int64(4096), Int64(Length(LD)), 'random round-trip len');
  for LI := 0 to 4095 do
    if LSrc[LI] <> LD[LI] then
    begin
      Check(False, 'random mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'random data matches');
end;

procedure TestLz4CompressBoundRejectsOutOfRangeInput;
const
  LZ4_MAX_INPUT_SIZE = $7E000000;
var
  LBound, LHugeInputSize: SizeUInt;
  LGot: Boolean;
begin
  LBound := Lz4CompressBound(SizeUInt(LZ4_MAX_INPUT_SIZE));
  Check(LBound > SizeUInt(LZ4_MAX_INPUT_SIZE), 'lz4 max input has compression bound');

  LGot := False;
  try
    Lz4CompressBound(SizeUInt(LZ4_MAX_INPUT_SIZE) + 1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 bound rejects input above max');

  LGot := False;
  LHugeInputSize := High(SizeUInt);
  try
    Lz4CompressBound(LHugeInputSize);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 bound rejects overflow-sized input');
end;

{ === B. Security/Malformed Input Tests === }

procedure TestLz4MalformedOffsetBeforeStart;
var LC: TBytes;
    LGot: Boolean;
begin
  // Token: 0 literals, 4 match length, offset=1 but dst=0
  LC := TBytes.Create(
    $04,       // token: litLen=0, matchLen=0+4=4
    $01, $00   // offset=1 (but nothing written yet)
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    on E: EIOError do
      LGot := Pos('lz4: offset before start', E.Message) > 0;
  end;
  Check(LGot, 'lz4 offset before start has stable error');
end;

procedure TestLz4MalformedZeroOffset;
var LC: TBytes;
    LGot: Boolean;
begin
  // 1 literal byte, then offset=0
  LC := TBytes.Create(
    $10,       // token: litLen=1, matchLen=0+4=4
    $AA,       // literal
    $00, $00   // offset=0 (invalid)
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    on E: EIOError do
      LGot := Pos('lz4: zero offset', E.Message) > 0;
  end;
  Check(LGot, 'lz4 zero offset has stable error');
end;

procedure TestLz4MalformedLengthOverflow;
var LC: TBytes;
    LGot: Boolean;
begin
  // Token with litLen=15, then 255 255 255... (should hit overflow guard)
  LC := TBytes.Create(
    $F0,       // token: litLen=15, matchLen=0
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  // keep adding to litLen
  );
  LGot := False;
  try
    Lz4Decompress(LC, 100);
  except
    on E: EIOError do
      LGot := Pos('lz4: literal length overflow', E.Message) > 0;
  end;
  Check(LGot, 'lz4 literal length overflow has stable error');
end;

procedure TestLz4MalformedOriginalSizeMetadata;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LGot := False;
  try
    Lz4Decompress(nil, 1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 empty payload with nonzero original size raises');

  LGot := False;
  try
    Lz4Decompress(nil, -1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 negative original size raises');

  LC := Lz4Compress(TBytes.Create(1, 2, 3, 4));
  LGot := False;
  try
    Lz4Decompress(LC, 0);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 non-empty payload with zero original size raises');
end;

procedure TestLz4EmptyDecodeContract;
var
  LD: TBytes;
begin
  LD := nextpas.core.compress.Lz4Decompress(nil, 0);
  CheckEqual(Int64(0), Int64(Length(LD)),
    'root facade lz4 empty decode returns empty bytes');

  LD := nextpas.core.compress.lz4.Lz4Decompress(nil, 0);
  CheckEqual(Int64(0), Int64(Length(LD)),
    'pure lz4 empty decode returns empty bytes');

  LD := nextpas.core.compress.lz4.native.NativeLz4Decompress(nil, 0);
  CheckEqual(Int64(0), Int64(Length(LD)),
    'native lz4 wrapper empty decode returns empty bytes');
end;

procedure TestLz4MalformedBranchErrorModel;

  procedure CheckLz4Error(const AData: TBytes; const AOriginalSize: Int32;
    const AExpected: string; const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      Lz4Decompress(AData, AOriginalSize);
    except
      on E: EIOError do
        LGot := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGot, 'lz4 ' + ALabel + ' has stable error');

    LGot := False;
    try
      nextpas.core.compress.Lz4Decompress(AData, AOriginalSize);
    except
      on E: EIOError do
        LGot := (Pos(AExpected, E.Message) > 0) or
          (Pos('lz4 native: decompress failed', E.Message) > 0) or
          (Pos('lz4 native: size mismatch', E.Message) > 0);
    end;
    Check(LGot, 'root facade lz4 ' + ALabel + ' has stable error');

    LGot := False;
    try
      nextpas.core.compress.lz4.native.NativeLz4Decompress(AData, AOriginalSize);
    except
      on E: EIOError do
        LGot := (Pos(AExpected, E.Message) > 0) or
          (Pos('lz4 native: decompress failed', E.Message) > 0) or
          (Pos('lz4 native: size mismatch', E.Message) > 0);
    end;
    Check(LGot, 'native lz4 wrapper ' + ALabel +
      ' accepts documented error');
  end;

begin
  CheckLz4Error(TBytes.Create($F0), 16,
    'lz4: truncated literal length', 'truncated literal length');
  CheckLz4Error(TBytes.Create($50, $AA), 8,
    'lz4: literal overflow', 'literal overflow');
  CheckLz4Error(TBytes.Create($00, $01), 8,
    'lz4: truncated offset', 'truncated offset');
  CheckLz4Error(TBytes.Create($1F, $AA, $01, $00), 32,
    'lz4: truncated match length', 'truncated match length');
  CheckLz4Error(TBytes.Create($1F, $AA, $01, $00, $00), 16,
    'lz4: match length overflow', 'match length overflow');
  CheckLz4Error(TBytes.Create($14, $AA, $01, $00), 4,
    'lz4: output overflow', 'output overflow');
  CheckLz4Error(TBytes.Create($10, $AA), 2,
    'lz4: decompressed size mismatch', 'decompressed size mismatch');
end;

procedure TestLz4RejectsOverLimitOriginalSize;
const
  LZ4_MAX_INPUT_SIZE = $7E000000;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LC := Lz4Compress(TBytes.Create(1, 2, 3, 4));

  LGot := False;
  try
    Lz4Decompress(LC, LZ4_MAX_INPUT_SIZE + 1);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 over-limit original size raises before allocation');
end;

procedure TestLz4DecompressOutputLimitRejectsMetadataAboveCap;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LC := TBytes.Create($00);

  LGot := False;
  try
    nextpas.core.compress.lz4.Lz4DecompressWithMaxOutputSize(LC,
      256 * 1024 * 1024 + 1, 64 * 1024 * 1024);
  except
    LGot := True;
  end;
  Check(LGot, 'lz4 bounded decode rejects declared size above cap before allocation');
end;

procedure TestNativeLz4DecompressOutputLimitRejectsMetadataAboveCap;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LC := TBytes.Create($00);

  LGot := False;
  try
    nextpas.core.compress.lz4.native.NativeLz4DecompressWithMaxOutputSize(LC,
      256 * 1024 * 1024 + 1, 64 * 1024 * 1024);
  except
    LGot := True;
  end;
  Check(LGot, 'native lz4 bounded decode rejects declared size above cap before allocation');
end;

procedure TestRootFacadeLz4BoundAndMetadataParity;
type
  TLz4MetadataCase = (
    lmcEmptyInputNonzeroOriginalSize,
    lmcNegativeOriginalSize,
    lmcNonEmptyInputZeroOriginalSize,
    lmcBoundedDeclaredSizeAboveCap
  );
var
  LCompressed: TBytes;
  LGot: Boolean;
  LRootBound: SizeUInt;
  LPureBound: SizeUInt;

  procedure CheckBoundParity(const AInputSize: SizeUInt; const ALabel: string);
  begin
    LRootBound := nextpas.core.compress.Lz4CompressBound(AInputSize);
    LPureBound := nextpas.core.compress.lz4.Lz4CompressBound(AInputSize);
    CheckEqual(Int64(LPureBound), Int64(LRootBound),
      'root facade lz4 bound parity ' + ALabel);
  end;

  procedure CheckRootFacadeError(const AExpectedPure, AExpectedNative,
    ALabel: string; const ACase: TLz4MetadataCase);
  var
    LMessage: string;
  begin
    LGot := False;
    LMessage := '';
    try
      case ACase of
        lmcEmptyInputNonzeroOriginalSize:
          nextpas.core.compress.Lz4Decompress(nil, 1);
        lmcNegativeOriginalSize:
          nextpas.core.compress.Lz4Decompress(nil, -1);
        lmcNonEmptyInputZeroOriginalSize:
          nextpas.core.compress.Lz4Decompress(LCompressed, 0);
        lmcBoundedDeclaredSizeAboveCap:
          nextpas.core.compress.Lz4DecompressWithMaxOutputSize(
            TBytes.Create($00), 256 * 1024 * 1024 + 1, 64 * 1024 * 1024);
      end;
    except
      on E: EIOError do
      begin
        LMessage := E.Message;
        LGot := (Pos(AExpectedPure, E.Message) > 0) or
          (Pos(AExpectedNative, E.Message) > 0);
      end;
    end;
    Check(LGot, 'root facade lz4 ' + ALabel +
      ' has stable metadata error: ' + LMessage);
  end;

begin
  CheckBoundParity(0, 'empty input');
  CheckBoundParity(1, 'single byte');
  CheckBoundParity(255, 'extension boundary');
  CheckBoundParity(SizeUInt(LZ4_MAX_INPUT_SIZE), 'max input');

  LGot := False;
  try
    nextpas.core.compress.Lz4CompressBound(SizeUInt(LZ4_MAX_INPUT_SIZE) + 1);
  except
    on E: EIOError do
      LGot := Pos('lz4: input size exceeds limit', E.Message) > 0;
  end;
  Check(LGot, 'root facade lz4 bound rejects input above max');

  LCompressed := nextpas.core.compress.Lz4Compress(TBytes.Create(1, 2, 3, 4));
  CheckRootFacadeError('lz4: empty input with nonzero original size',
    'lz4 native: empty input with nonzero original size',
    'empty input with nonzero original size',
    lmcEmptyInputNonzeroOriginalSize);
  CheckRootFacadeError('lz4: invalid original size',
    'lz4 native: invalid original size', 'negative original size',
    lmcNegativeOriginalSize);
  CheckRootFacadeError('lz4: non-empty input with zero original size',
    'lz4 native: non-empty input with zero original size',
    'non-empty input with zero original size',
    lmcNonEmptyInputZeroOriginalSize);
  CheckRootFacadeError('lz4: decompressed size exceeds limit',
    'lz4 native: decompressed size exceeds limit',
    'bounded declared size above cap', lmcBoundedDeclaredSizeAboveCap);
end;

procedure TestRootFacadeLz4BoundedMalformedParity;

  procedure CheckBoundedMalformed(const AData: TBytes;
    const AOriginalSize: Int32; const AExpectedPureError,
    ALabel: string);
  var
    LGot: Boolean;
    LMessage: string;
  begin
    LGot := False;
    LMessage := '';
    try
      nextpas.core.compress.Lz4DecompressWithMaxOutputSize(AData,
        AOriginalSize, SizeUInt(AOriginalSize));
    except
      on E: EIOError do
      begin
        LMessage := E.Message;
        LGot := (Pos('unsupported frame/header', E.Message) = 0) and
          ((Pos(AExpectedPureError, E.Message) > 0) or
          (Pos('lz4 native: decompress failed', E.Message) > 0) or
          (Pos('lz4 native: size mismatch', E.Message) > 0));
      end;
    end;
    Check(LGot, 'root facade bounded lz4 ' + ALabel +
      ' keeps malformed decode error: ' + LMessage);
  end;

  procedure CheckBoundedFrameHeader(const AData: TBytes; const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      nextpas.core.compress.Lz4DecompressWithMaxOutputSize(AData, 1, 1);
    except
      on E: EIOError do
        LGot := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGot, 'root facade bounded lz4 rejects ' + ALabel +
      ' as unsupported');
  end;

begin
  CheckBoundedMalformed(TBytes.Create($F0), 16,
    'lz4: truncated literal length', 'truncated literal length');
  CheckBoundedMalformed(TBytes.Create($50, $AA), 8,
    'lz4: literal overflow', 'literal overflow');
  CheckBoundedMalformed(TBytes.Create($00, $01), 8,
    'lz4: truncated offset', 'truncated offset');
  CheckBoundedMalformed(TBytes.Create($1F, $AA, $01, $00), 32,
    'lz4: truncated match length', 'truncated match length');
  CheckBoundedMalformed(TBytes.Create($1F, $AA, $01, $00, $00), 16,
    'lz4: match length overflow', 'match length overflow');
  CheckBoundedMalformed(TBytes.Create($14, $AA, $01, $00), 4,
    'lz4: output overflow', 'output overflow');
  CheckBoundedMalformed(TBytes.Create($10, $AA), 2,
    'lz4: decompressed size mismatch', 'decompressed size mismatch');

  CheckBoundedFrameHeader(TBytes.Create($04, $22, $4D, $18, $60, $40, $82, $00),
    'standard frame header');
  CheckBoundedFrameHeader(TBytes.Create($50, $2A, $4D, $18, 0, 0, 0, 0),
    'skippable frame header');
  CheckBoundedFrameHeader(TBytes.Create($02, $21, $4C, $18, 0, 0, 0, 0),
    'legacy frame header');
end;

procedure TestNativeLz4OriginalSizeMismatch;
var
  LSrc, LC: TBytes;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 3, 3, 7);
  LC := nextpas.core.compress.lz4.native.NativeLz4Compress(LSrc);

  LGot := False;
  try
    nextpas.core.compress.lz4.native.NativeLz4Decompress(LC, Length(LSrc) + 1);
  except
    on E: EIOError do
      {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
      LGot := Pos('lz4 native: size mismatch', E.Message) > 0;
      {$ELSE}
      LGot := Pos('lz4: decompressed size mismatch', E.Message) > 0;
      {$ENDIF}
  end;
  Check(LGot, 'native lz4 original-size mismatch has stable error');
end;

procedure TestLz4FrameHeaderRejectedAsUnsupported;

  procedure CheckFrameHeader(const AFrame: TBytes; const ALabel: string);
  var
    LGotPure: Boolean;
    LGotNative: Boolean;
  begin
    LGotPure := False;
    try
      nextpas.core.compress.lz4.Lz4Decompress(AFrame, 1);
    except
      on E: EIOError do
        LGotPure := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGotPure, 'pure lz4 rejects ' + ALabel + ' as unsupported');

    LGotNative := False;
    try
      nextpas.core.compress.lz4.native.NativeLz4Decompress(AFrame, 1);
    except
      on E: EIOError do
        LGotNative := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGotNative, 'native lz4 wrapper rejects ' + ALabel + ' as unsupported');
  end;
begin
  CheckFrameHeader(TBytes.Create($04, $22, $4D, $18, $60, $40, $82, $00),
    'standard frame header');
  CheckFrameHeader(TBytes.Create($50, $2A, $4D, $18, 0, 0, 0, 0),
    'skippable frame header');
  CheckFrameHeader(TBytes.Create($02, $21, $4C, $18, 0, 0, 0, 0),
    'legacy frame header');
end;

procedure TestLz4TruncatedFrameMagicRejectedAsUnsupported;

  procedure CheckTruncatedFrameMagic(const AFrame: TBytes; const ALabel: string);
  var
    LGotPure: Boolean;
    LGotNative: Boolean;
    LGotFacade: Boolean;
  begin
    LGotPure := False;
    try
      nextpas.core.compress.lz4.Lz4Decompress(AFrame, 1);
    except
      on E: EIOError do
        LGotPure := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGotPure, 'pure lz4 rejects ' + ALabel + ' as unsupported');

    LGotNative := False;
    try
      nextpas.core.compress.lz4.native.NativeLz4Decompress(AFrame, 1);
    except
      on E: EIOError do
        LGotNative := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGotNative, 'native lz4 wrapper rejects ' + ALabel +
      ' as unsupported');

    LGotFacade := False;
    try
      nextpas.core.compress.Lz4Decompress(AFrame, 1);
    except
      on E: EIOError do
        LGotFacade := Pos('unsupported frame/header', E.Message) > 0;
    end;
    Check(LGotFacade, 'root facade lz4 rejects ' + ALabel +
      ' as unsupported');
  end;
begin
  CheckTruncatedFrameMagic(TBytes.Create($04, $22, $4D, $18),
    'truncated standard frame magic');
  CheckTruncatedFrameMagic(TBytes.Create($50, $2A, $4D, $18),
    'truncated skippable frame magic');
  CheckTruncatedFrameMagic(TBytes.Create($02, $21, $4C, $18),
    'truncated legacy frame magic');
end;

procedure TestLz4RawBlockSkippableMagicLiteralPrefixAccepted;
var
  LRaw, LD: TBytes;
begin
  LRaw := TBytes.Create($50, $2A, $4D, $18, $00, $01);

  LD := nextpas.core.compress.lz4.Lz4Decompress(LRaw, 5);
  CheckEqual(Int64(5), Int64(Length(LD)),
    'pure lz4 raw block with skippable magic literal prefix length');
  Check((LD[0] = $2A) and (LD[1] = $4D) and (LD[2] = $18) and
    (LD[3] = $00) and (LD[4] = $01),
    'pure lz4 raw block with skippable magic literal prefix content');

  LD := nextpas.core.compress.lz4.native.NativeLz4Decompress(LRaw, 5);
  CheckEqual(Int64(5), Int64(Length(LD)),
    'native lz4 raw block with skippable magic literal prefix length');
  Check((LD[0] = $2A) and (LD[1] = $4D) and (LD[2] = $18) and
    (LD[3] = $00) and (LD[4] = $01),
    'native lz4 raw block with skippable magic literal prefix content');
end;

procedure TestLz4MalformedRawBlockMagicLiteralPrefixKeepsDecodeError;
var
  LRaw: TBytes;
  LGotPure: Boolean;
  LGotNative: Boolean;
begin
  LRaw := TBytes.Create($50, $2A, $4D, $18, $00);

  LGotPure := False;
  try
    nextpas.core.compress.lz4.Lz4Decompress(LRaw, 5);
  except
    on E: EIOError do
      LGotPure := Pos('lz4: literal overflow', E.Message) > 0;
  end;
  Check(LGotPure,
    'pure lz4 malformed raw block magic literal prefix keeps raw error');

  LGotNative := False;
  try
    nextpas.core.compress.lz4.native.NativeLz4Decompress(LRaw, 5);
  except
    on E: EIOError do
      LGotNative := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos('literal overflow', E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGotNative,
    'native lz4 wrapper malformed raw block magic literal prefix keeps decode error');

  LRaw := TBytes.Create($50, $2A, $4D, $18, $00, $01, $00, $00);

  LGotPure := False;
  try
    nextpas.core.compress.lz4.Lz4Decompress(LRaw, 5);
  except
    on E: EIOError do
      LGotPure := Pos('lz4: zero offset', E.Message) > 0;
  end;
  Check(LGotPure,
    'pure lz4 skippable magic threshold collision keeps raw error');

  LGotNative := False;
  try
    nextpas.core.compress.lz4.native.NativeLz4Decompress(LRaw, 5);
  except
    on E: EIOError do
      LGotNative := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos('zero offset', E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGotNative,
    'native lz4 wrapper skippable magic threshold collision keeps decode error');
end;

procedure TestLz4MalformedBlockEndingWithMatchRejected;
var
  LRaw: TBytes;
begin
  LRaw := TBytes.Create(
    $40,
    Ord('A'), Ord('B'), Ord('C'), Ord('D'),
    $04, $00
  );
  CheckMalformedLz4RawBlockRejected(LRaw, 8,
    'lz4: final literal tail missing',
    'pure lz4 rejects block ending with match',
    'root facade lz4 rejects block ending with match',
    'native lz4 wrapper rejects block ending with match');
end;

procedure TestLz4MalformedNearEndMatchRejected;
var
  LRaw: TBytes;
begin
  LRaw := TBytes.Create(
    $50,
    Ord('A'), Ord('B'), Ord('C'), Ord('D'), Ord('E'),
    $05, $00,
    $50,
    Ord('F'), Ord('G'), Ord('H'), Ord('I'), Ord('J')
  );
  CheckMalformedLz4RawBlockRejected(LRaw, 14,
    'lz4: final match too close to end',
    'pure lz4 rejects last match inside final match limit',
    'root facade lz4 rejects last match inside final match limit',
    'native lz4 wrapper rejects last match inside final match limit');
end;

procedure TestRootFacadeLz4FrameRawBlockBoundary;
var
  LRaw, LD: TBytes;
  LGot: Boolean;
begin
  LGot := False;
  try
    nextpas.core.compress.Lz4Decompress(
      TBytes.Create($04, $22, $4D, $18, $60, $40, $82, $00), 1);
  except
    on E: EIOError do
      LGot := Pos('unsupported frame/header', E.Message) > 0;
  end;
  Check(LGot, 'root facade lz4 rejects standard frame header');

  LGot := False;
  try
    nextpas.core.compress.Lz4Decompress(
      TBytes.Create($50, $2A, $4D, $18, 0, 0, 0, 0), 1);
  except
    on E: EIOError do
      LGot := Pos('unsupported frame/header', E.Message) > 0;
  end;
  Check(LGot, 'root facade lz4 rejects skippable frame header');

  LRaw := TBytes.Create($50, $2A, $4D, $18, $00, $01);
  LD := nextpas.core.compress.Lz4Decompress(LRaw, 5);
  CheckEqual(Int64(5), Int64(Length(LD)),
    'root facade lz4 raw block with skippable magic literal prefix length');
  Check((LD[0] = $2A) and (LD[1] = $4D) and (LD[2] = $18) and
    (LD[3] = $00) and (LD[4] = $01),
    'root facade lz4 raw block with skippable magic literal prefix content');

  LGot := False;
  try
    nextpas.core.compress.Lz4Decompress(
      TBytes.Create($50, $2A, $4D, $18, $00), 5);
  except
    on E: EIOError do
      LGot := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos('literal overflow', E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGot,
    'root facade lz4 malformed raw block magic literal prefix keeps decode error');

  LGot := False;
  try
    nextpas.core.compress.Lz4Decompress(
      TBytes.Create($50, $2A, $4D, $18, $00, $01, $00, $00), 5);
  except
    on E: EIOError do
      LGot := (Pos('unsupported frame/header', E.Message) = 0) and
        ((Pos('zero offset', E.Message) > 0) or
        (Pos('lz4 native: decompress failed', E.Message) > 0));
  end;
  Check(LGot,
    'root facade lz4 skippable magic threshold collision keeps decode error');
end;

procedure TestLz4PureEncoderBlockEndsWithLiteralTail;
var
  LSrc, LC, LD: TBytes;
  LSrcPos, LDstPos: Int32;
  LToken, LLitLen, LMatchLen: Int32;
  LOffset: UInt16;
  LFinalLiteralLen: Int32;
  LLastMatchStart: Int32;
  LI: Int32;
begin
  SetLength(LSrc, 16);
  FillChar(LSrc[0], Length(LSrc), $41);

  LC := nextpas.core.compress.lz4.Lz4Compress(LSrc);
  LD := nextpas.core.compress.lz4.Lz4Decompress(LC, Length(LSrc));
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)),
    'pure lz4 conformance fixture round-trips');

  LSrcPos := 0;
  LDstPos := 0;
  LFinalLiteralLen := -1;
  LLastMatchStart := -1;
  while LSrcPos < Length(LC) do
  begin
    LToken := LC[LSrcPos];
    Inc(LSrcPos);
    LLitLen := LToken shr 4;
    if LLitLen = 15 then
      repeat
        Check(LSrcPos < Length(LC), 'lz4 conformance literal length is complete');
        LLitLen := LLitLen + LC[LSrcPos];
        Inc(LSrcPos);
      until LC[LSrcPos - 1] <> 255;

    Check(LSrcPos + LLitLen <= Length(LC),
      'lz4 conformance literal bytes fit compressed block');
    Inc(LSrcPos, LLitLen);
    Inc(LDstPos, LLitLen);
    if LSrcPos >= Length(LC) then
    begin
      LFinalLiteralLen := LLitLen;
      Break;
    end;

    Check(LSrcPos + 2 <= Length(LC),
      'lz4 conformance match offset is complete');
    LOffset := UInt16(LC[LSrcPos]) or (UInt16(LC[LSrcPos + 1]) shl 8);
    Inc(LSrcPos, 2);
    Check(LOffset <> 0, 'lz4 conformance offset is nonzero');

    LLastMatchStart := LDstPos;
    LMatchLen := (LToken and $0F) + 4;
    if (LToken and $0F) = 15 then
      repeat
        Check(LSrcPos < Length(LC), 'lz4 conformance match length is complete');
        LMatchLen := LMatchLen + LC[LSrcPos];
        Inc(LSrcPos);
      until LC[LSrcPos - 1] <> 255;
    Inc(LDstPos, LMatchLen);
  end;

  CheckEqual(Int64(Length(LSrc)), Int64(LDstPos),
    'lz4 conformance parser reaches declared output size');
  Check(LFinalLiteralLen >= 5,
    'pure lz4 block keeps the last five input bytes as final literals');
  Check((LLastMatchStart < 0) or (LLastMatchStart <= Length(LSrc) - 12),
    'pure lz4 last match starts at least twelve bytes before end');
  for LI := 0 to High(LSrc) do
    if LD[LI] <> LSrc[LI] then
    begin
      Check(False, 'pure lz4 conformance fixture mismatch at ' + IntToStr(LI));
      Exit;
    end;
end;

procedure TestGzipWrongCRC;
var LSrc, LC: TBytes;
    LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  LC := GzipCompress(LSrc);
  // Zero out CRC (bytes at len-8..len-5)
  LC[Length(LC)-8] := 0;
  LC[Length(LC)-7] := 0;
  LC[Length(LC)-6] := 0;
  LC[Length(LC)-5] := 0;
  LGot := False;
  try
    GzipDecompress(LC);
  except
    on E: EIOError do
      LGot := Pos('gzip: CRC32 mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip wrong CRC has stable error');
end;

procedure TestGzipWrongSize;
var LSrc, LC: TBytes;
    LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5);
  LC := GzipCompress(LSrc);
  // Corrupt size field (last 4 bytes) to wrong value
  LC[Length(LC)-4] := 99;
  LGot := False;
  try
    GzipDecompress(LC);
  except
    on E: EIOError do
      LGot := Pos('gzip: size mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip wrong size has stable error');
end;

procedure TestGzipSingleMemberIntegrityBoundedParity;

  procedure StoreTrailerSize(var AData: TBytes; const ASize: UInt32);
  var
    LOffset: SizeInt;
  begin
    LOffset := Length(AData) - 4;
    AData[LOffset] := Byte(ASize);
    AData[LOffset + 1] := Byte(ASize shr 8);
    AData[LOffset + 2] := Byte(ASize shr 16);
    AData[LOffset + 3] := Byte(ASize shr 24);
  end;

  function GzipWithWrongCrc(const ASource: TBytes): TBytes;
  var
    LOffset: SizeInt;
  begin
    Result := GzipCompress(ASource);
    LOffset := Length(Result) - 8;
    Result[LOffset] := Result[LOffset] xor $FF;
  end;

  function GzipWithWrongSize(const ASource: TBytes): TBytes;
  begin
    Result := GzipCompress(ASource);
    StoreTrailerSize(Result, UInt32(Length(ASource) - 1));
  end;

  procedure CheckIntegrityError(const AData: TBytes; const AExpectedError,
    AOneShotLabel, ABoundedLabel, AStreamLabel, ABoundedStreamLabel: string);
  var
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotBounded: Boolean;
    LGotStream: Boolean;
    LGotBoundedStream: Boolean;
  begin
    LGotOneShot := False;
    try
      GzipDecompress(AData);
    except
      on E: EIOError do
        LGotOneShot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotOneShot, AOneShotLabel);

    LGotBounded := False;
    try
      GzipDecompressWithMaxOutputSize(AData, 8);
    except
      on E: EIOError do
        LGotBounded := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotBounded, ABoundedLabel);

    LGotStream := False;
    try
      LReader := GzipReader(CreateBytesStreamFrom(AData) as IReader);
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotStream, AStreamLabel);

    LGotBoundedStream := False;
    try
      LReader := GzipReaderWithMaxOutputSize(
        CreateBytesStreamFrom(AData) as IReader, 8);
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotBoundedStream := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotBoundedStream, ABoundedStreamLabel);
  end;

var
  LSrc: TBytes;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  CheckIntegrityError(GzipWithWrongCrc(LSrc), 'gzip: CRC32 mismatch',
    'gzip one-shot single-member CRC has stable error',
    'gzip bounded single-member CRC has stable error',
    'gzip stream single-member CRC has stable error',
    'gzip bounded stream single-member CRC has stable error');
  CheckIntegrityError(GzipWithWrongSize(LSrc), 'gzip: size mismatch',
    'gzip one-shot single-member size has stable error',
    'gzip bounded single-member size has stable error',
    'gzip stream single-member size has stable error',
    'gzip bounded stream single-member size has stable error');
end;

procedure TestGzipTruncatedHeader;
var LC: TBytes;
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotStream: Boolean;
begin
  LC := TBytes.Create($1F, $8B, $08); // only 3 bytes of header
  LGotOneShot := False;
  try
    GzipDecompress(LC);
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotOneShot, 'gzip one-shot truncated header has stable error');

  LGotStream := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream truncated header has stable error');
end;

procedure TestGzipEmptyEncodedInputErrorModel;
var
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotBounded: Boolean;
  LGotStream: Boolean;
  LGotBoundedStream: Boolean;
begin
  LGotOneShot := False;
  try
    GzipDecompress(nil);
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotOneShot,
    'gzip one-shot empty encoded input has stable error');

  LGotBounded := False;
  try
    GzipDecompressWithMaxOutputSize(nil, 0);
  except
    on E: EIOError do
      LGotBounded := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotBounded,
    'gzip bounded one-shot empty encoded input has stable error');

  LGotStream := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(nil) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotStream,
    'gzip stream empty encoded input has stable error');

  LGotBoundedStream := False;
  try
    LReader := GzipReaderWithMaxOutputSize(
      CreateBytesStreamFrom(nil) as IReader, 0);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotBoundedStream := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotBoundedStream,
    'gzip bounded stream empty encoded input has stable error');
end;

procedure TestGzipTruncatedTrailer;
var LSrc, LC: TBytes;
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotStream: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3);
  LC := GzipCompress(LSrc);
  // Remove last 4 bytes (partial trailer)
  SetLength(LC, Length(LC) - 4);
  LGotOneShot := False;
  try
    GzipDecompress(LC);
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGotOneShot, 'gzip one-shot truncated trailer has stable error');

  LGotStream := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream truncated trailer has stable error');
end;

procedure TestGzipFixedHeaderErrorModel;

  procedure CheckGzipHeaderError(const AData: TBytes; const AExpected: string;
    const ALabel: string);
  var
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotBounded: Boolean;
    LGotStream: Boolean;
  begin
    LGotOneShot := False;
    try
      GzipDecompress(AData);
    except
      on E: EIOError do
        LGotOneShot := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotOneShot, 'gzip one-shot ' + ALabel + ' has stable error');

    LGotBounded := False;
    try
      GzipDecompressWithMaxOutputSize(AData, 1024);
    except
      on E: EIOError do
        LGotBounded := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotBounded, 'gzip bounded one-shot ' + ALabel +
      ' has stable error');

    LGotStream := False;
    try
      LReader := GzipReader(CreateBytesStreamFrom(AData) as IReader);
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotStream, 'gzip stream ' + ALabel + ' has stable error');
  end;

begin
  CheckGzipHeaderError(TBytes.Create($00, $00, $08, $00, 0, 0, 0, 0, 0, $FF,
    $03, $00, 0, 0, 0, 0, 0, 0, 0, 0),
    'gzip: invalid magic', 'invalid magic');
  CheckGzipHeaderError(TBytes.Create($1F, $8B, $09, $00, 0, 0, 0, 0, 0, $FF,
    $03, $00, 0, 0, 0, 0, 0, 0, 0, 0),
    'gzip: unsupported method', 'unsupported method');
  CheckGzipHeaderError(TBytes.Create($1F, $8B, $08, $20, 0, 0, 0, 0, 0, $FF,
    $03, $00, 0, 0, 0, 0, 0, 0, 0, 0),
    'gzip: invalid flags', 'reserved flag $20');
  CheckGzipHeaderError(TBytes.Create($1F, $8B, $08, $40, 0, 0, 0, 0, 0, $FF,
    $03, $00, 0, 0, 0, 0, 0, 0, 0, 0),
    'gzip: invalid flags', 'reserved flag $40');
  CheckGzipHeaderError(TBytes.Create($1F, $8B, $08, $80, 0, 0, 0, 0, 0, $FF,
    $03, $00, 0, 0, 0, 0, 0, 0, 0, 0),
    'gzip: invalid flags', 'reserved flag $80');
end;

procedure TestGzipOptionalHeaderTruncationErrorModel;

  procedure CheckGzipError(const AData: TBytes; const AExpected: string;
    const ALabel: string);
  var
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotBounded: Boolean;
    LGotStream: Boolean;
  begin
    LGotOneShot := False;
    try
      GzipDecompress(AData);
    except
      on E: EIOError do
        LGotOneShot := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotOneShot, 'gzip one-shot ' + ALabel + ' has stable error');

    LGotBounded := False;
    try
      GzipDecompressWithMaxOutputSize(AData, 1024);
    except
      on E: EIOError do
        LGotBounded := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotBounded, 'gzip bounded one-shot ' + ALabel +
      ' has stable error');

    LGotStream := False;
    try
      LReader := GzipReader(CreateBytesStreamFrom(AData) as IReader);
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotStream, 'gzip stream ' + ALabel + ' has stable error');
  end;

begin
  CheckGzipError(TBytes.Create($1F, $8B, $08, $04, 0, 0, 0, 0, 0, $FF,
    $14, $00, $AA, $BB, $CC, $DD, $EE, $AB, $BC, $CD),
    'gzip: truncated FEXTRA', 'truncated FEXTRA');
  CheckGzipError(TBytes.Create($1F, $8B, $08, $08, 0, 0, 0, 0, 0, $FF,
    Ord('n'), Ord('p'), Ord('x'), Ord('x'), Ord('x'), Ord('x'),
    Ord('x'), Ord('x'), Ord('x'), Ord('x')),
    'gzip: truncated FNAME', 'truncated FNAME');
  CheckGzipError(TBytes.Create($1F, $8B, $08, $10, 0, 0, 0, 0, 0, $FF,
    Ord('n'), Ord('p'), Ord('x'), Ord('x'), Ord('x'), Ord('x'),
    Ord('x'), Ord('x'), Ord('x'), Ord('x')),
    'gzip: truncated FCOMMENT', 'truncated FCOMMENT');
  CheckGzipError(TBytes.Create($1F, $8B, $08, $02, 0, 0, 0, 0, 0, $FF),
    'gzip: truncated header', 'truncated FHCRC empty');
  CheckGzipError(TBytes.Create($1F, $8B, $08, $02, 0, 0, 0, 0, 0, $FF,
    $00),
    'gzip: truncated header', 'truncated FHCRC one byte');
  CheckGzipError(TBytes.Create($1F, $8B, $08, $04, 0, 0, 0, 0, 0, $FF,
    $00, $00, $03, $00, 0, 0, 0, 0),
    'gzip: truncated trailer', 'FEXTRA followed by truncated trailer');
end;

procedure TestGzipOptionalHeaderFieldLimit;
const
  LONG_FIELD_SIZE = 65537;

  function BuildLongHeader(const AFlag: Byte): TBytes;
  var
    LI: SizeInt;
  begin
    Result := nil;
    SetLength(Result, 10 + LONG_FIELD_SIZE + 1);
    Result[0] := $1F;
    Result[1] := $8B;
    Result[2] := $08;
    Result[3] := AFlag;
    Result[4] := 0;
    Result[5] := 0;
    Result[6] := 0;
    Result[7] := 0;
    Result[8] := 0;
    Result[9] := $FF;
    for LI := 10 to 10 + LONG_FIELD_SIZE - 1 do
      Result[LI] := Ord('x');
    Result[10 + LONG_FIELD_SIZE] := 0;
  end;

  procedure CheckGzipFieldLimit(const AData: TBytes; const ALabel: string);
  var
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotBounded: Boolean;
    LGotStream: Boolean;
  begin
    LGotOneShot := False;
    try
      GzipDecompress(AData);
    except
      on E: EIOError do
        LGotOneShot := Pos('gzip: header field exceeds limit', E.Message) > 0;
    end;
    Check(LGotOneShot, 'gzip one-shot ' + ALabel +
      ' header field cap has stable error');

    LGotBounded := False;
    try
      GzipDecompressWithMaxOutputSize(AData, 1024);
    except
      on E: EIOError do
        LGotBounded := Pos('gzip: header field exceeds limit', E.Message) > 0;
    end;
    Check(LGotBounded, 'gzip bounded one-shot ' + ALabel +
      ' header field cap has stable error');

    LGotStream := False;
    try
      LReader := GzipReader(TOneByteReader.Create(AData));
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos('gzip: header field exceeds limit', E.Message) > 0;
    end;
    Check(LGotStream, 'gzip stream ' + ALabel +
      ' header field cap has stable error');
  end;

begin
  CheckGzipFieldLimit(BuildLongHeader($08), 'FNAME');
  CheckGzipFieldLimit(BuildLongHeader($10), 'FCOMMENT');
end;

procedure TestGzipCorruptPayloadErrorModel;
const
  EXPECTED_ERROR = 'gzip: corrupt stream';
var
  LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotBounded: Boolean;
  LGotStream: Boolean;
begin
  LBad := TBytes.Create(
    $1F, $8B, $08, $00, 0, 0, 0, 0, 0, $FF,
    $07,
    0, 0, 0, 0, 0, 0, 0, 0
  );

  LGotOneShot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos(EXPECTED_ERROR, E.Message) > 0;
  end;
  Check(LGotOneShot, 'gzip one-shot corrupt payload has stable error');

  LGotBounded := False;
  try
    GzipDecompressWithMaxOutputSize(LBad, 1024);
  except
    on E: EIOError do
      LGotBounded := Pos(EXPECTED_ERROR, E.Message) > 0;
  end;
  Check(LGotBounded, 'gzip bounded corrupt payload has stable error');

  LGotStream := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos(EXPECTED_ERROR, E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream corrupt payload has stable error');
end;

procedure TestGzipRejectsBytesBeforeTrailer;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LTrailerOfs: SizeUInt;
begin
  LSrc := TBytes.Create(1, 1, 2, 3, 5, 8, 13, 21);
  LC := GzipCompress(LSrc);
  LTrailerOfs := SizeUInt(Length(LC) - 8);

  SetLength(LBad, Length(LC) + 3);
  Move(LC[0], LBad[0], LTrailerOfs);
  LBad[LTrailerOfs] := $DE;
  LBad[LTrailerOfs + 1] := $AD;
  LBad[LTrailerOfs + 2] := $7A;
  Move(LC[LTrailerOfs], LBad[LTrailerOfs + 3], 8);

  LGot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGot := Pos('gzip: CRC32 mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip one-shot bytes before trailer reports integrity error');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    on E: EIOError do
      LGot := Pos('gzip: CRC32 mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip stream bytes before trailer reports integrity error');
end;

procedure TestGzipRejectsTrailingBytesAfterTrailer;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotStream: Boolean;
begin
  LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);
  LC := GzipCompress(LSrc);

  SetLength(LBad, Length(LC) + 3);
  Move(LC[0], LBad[0], Length(LC));
  LBad[Length(LC)] := $DE;
  LBad[Length(LC) + 1] := $AD;
  LBad[Length(LC) + 2] := $7A;

  LGotOneShot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: trailing bytes after trailer', E.Message) > 0;
  end;
  Check(LGotOneShot, 'gzip one-shot rejects bytes after trailer');

  LGotStream := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    on E: EIOError do
      LGotStream := Pos('gzip: trailing bytes after trailer', E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream rejects bytes after trailer');

  LGotStream := False;
  try
    LReader := GzipReader(TOneByteReader.Create(LBad));
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    on E: EIOError do
      LGotStream := Pos('gzip: trailing bytes after trailer', E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream rejects bytes after trailer after chunk boundary');
end;

procedure TestGzipConcatenatedMembers;
var
  LFirst: TBytes;
  LSecond: TBytes;
  LThird: TBytes;
  LConcat: TBytes;
  LOut: TBytes;
  LReader: IDecompressReader;
begin
  LFirst := GzipCompress(TBytes.Create(1, 2, 3));
  LSecond := GzipCompress(TBytes.Create(4, 5));
  SetLength(LConcat, Length(LFirst) + Length(LSecond));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));

  LOut := GzipDecompress(LConcat);
  CheckBytesEqual(TBytes.Create(1, 2, 3, 4, 5), LOut,
    'gzip one-shot concatenated members');

  LReader := GzipReader(CreateBytesStreamFrom(LConcat) as IReader);
  LOut := IoReadAll(LReader as IReader);
  CheckBytesEqual(TBytes.Create(1, 2, 3, 4, 5), LOut,
    'gzip stream concatenated members');
  LReader.Close;

  LFirst := GzipCompress(TBytes.Create(1, 2, 3));
  LSecond := GzipCompress(nil);
  LThird := GzipCompress(TBytes.Create(4, 5));
  SetLength(LConcat, Length(LFirst) + Length(LSecond) + Length(LThird));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));
  Move(LThird[0], LConcat[Length(LFirst) + Length(LSecond)], Length(LThird));

  LOut := GzipDecompressWithMaxOutputSize(LConcat, 5);
  CheckBytesEqual(TBytes.Create(1, 2, 3, 4, 5), LOut,
    'gzip one-shot bounded concatenated members with empty member');

  LReader := GzipReaderWithMaxOutputSize(CreateBytesStreamFrom(LConcat) as IReader,
    5);
  LOut := IoReadAll(LReader as IReader);
  CheckBytesEqual(TBytes.Create(1, 2, 3, 4, 5), LOut,
    'gzip stream bounded concatenated members with empty member');
  LReader.Close;
end;

procedure TestGzipConcatenatedMembersCumulativeOutputCap;
var
  LFirstPayload: TBytes;
  LSecondPayload: TBytes;
  LFirst: TBytes;
  LSecond: TBytes;
  LConcat: TBytes;
  LOut: TBytes;
  LReader: IDecompressReader;
  LSentinel: Byte;
  LRead: SizeUInt;
  LGotOneShot: Boolean;
  LGotStream: Boolean;
begin
  LFirstPayload := TBytes.Create(1, 2, 3);
  LSecondPayload := TBytes.Create(4, 5);
  LFirst := GzipCompress(LFirstPayload);
  LSecond := GzipCompress(LSecondPayload);
  SetLength(LConcat, Length(LFirst) + Length(LSecond));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));

  LGotOneShot := False;
  try
    GzipDecompressWithMaxOutputSize(LConcat, Length(LFirstPayload));
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGotOneShot,
    'gzip one-shot concatenated members reject cumulative output above cap');

  LReader := GzipReaderWithMaxOutputSize(CreateBytesStreamFrom(LConcat) as IReader,
    Length(LFirstPayload));
  SetLength(LOut, Length(LFirstPayload));
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(Length(LFirstPayload)), Int64(LRead),
    'gzip stream concatenated members first member reaches exact cap');
  CheckBytesEqual(LFirstPayload, LOut,
    'gzip stream concatenated members first member bytes');

  LGotStream := False;
  LSentinel := $A5;
  try
    (LReader as IReader).Read(LSentinel, 1);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGotStream,
    'gzip stream concatenated members reject cumulative output above cap');
  CheckEqual(Int64($A5), Int64(LSentinel),
    'gzip stream concatenated cap error preserves caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LSentinel, 1)),
    'gzip stream concatenated cap error leaves reader terminal');
  LReader.Close;
  LReader.Close;
end;

procedure TestGzipConcatenatedTrailerSizeAboveRemainingCapReportsOutputLimit;
var
  LFirstPayload: TBytes;
  LFirst, LSecond, LConcat: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotStream: Boolean;
  LI: SizeInt;
begin
  SetLength(LFirstPayload, 64);
  for LI := 0 to High(LFirstPayload) do
    LFirstPayload[LI] := Byte((LI * 17 + 9) mod 251);

  LFirst := GzipCompress(LFirstPayload);
  LSecond := GzipCompress(nil);
  LSecond[Length(LSecond) - 4] := 1;
  LSecond[Length(LSecond) - 3] := 0;
  LSecond[Length(LSecond) - 2] := 0;
  LSecond[Length(LSecond) - 1] := 0;

  SetLength(LConcat, Length(LFirst) + Length(LSecond));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));

  LGotOneShot := False;
  try
    GzipDecompressWithMaxOutputSize(LConcat, Length(LFirstPayload));
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGotOneShot,
    'gzip one-shot concatenated member trailer size above remaining cap reports output limit');

  LGotStream := False;
  LReader := GzipReaderWithMaxOutputSize(CreateBytesStreamFrom(LConcat) as IReader,
    Length(LFirstPayload));
  try
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGotStream,
    'gzip stream concatenated member trailer size above remaining cap reports output limit');
  LReader.Close;
  LReader.Close;
end;

procedure TestGzipConcatenatedCorruptSecondMemberErrorModel;
var
  LFirst: TBytes;
  LSecond: TBytes;

  function ConcatSecondMember(const ASecond: TBytes): TBytes;
  begin
    Result := nil;
    SetLength(Result, Length(LFirst) + Length(ASecond));
    Move(LFirst[0], Result[0], Length(LFirst));
    if Length(ASecond) > 0 then
      Move(ASecond[0], Result[Length(LFirst)], Length(ASecond));
  end;

  procedure CheckSecondMemberError(const ASecond: TBytes;
    const AExpected, ALabel: string);
  var
    LConcat: TBytes;
    LReader: IDecompressReader;
    LByte: Byte;
    LGotOneShot: Boolean;
    LGotBounded: Boolean;
    LGotStream: Boolean;
  begin
    LConcat := ConcatSecondMember(ASecond);

    LGotOneShot := False;
    try
      GzipDecompress(LConcat);
    except
      on E: EIOError do
        LGotOneShot := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotOneShot, 'gzip one-shot concatenated second member ' +
      ALabel + ' has stable error');

    LGotBounded := False;
    try
      GzipDecompressWithMaxOutputSize(LConcat, 1024);
    except
      on E: EIOError do
        LGotBounded := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotBounded, 'gzip bounded concatenated second member ' +
      ALabel + ' has stable error');

    LGotStream := False;
    LReader := GzipReader(TOneByteReader.Create(LConcat));
    try
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos(AExpected, E.Message) > 0;
    end;
    Check(LGotStream, 'gzip stream concatenated second member ' +
      ALabel + ' has stable error');
    CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
      'gzip stream concatenated second member ' + ALabel +
      ' error leaves reader terminal');
    LReader.Close;
    LReader.Close;
  end;

  function GzipFixedHeaderPrefix(const ALen: SizeUInt): TBytes;
  const
    FullHeader: array[0..9] of Byte =
      ($1F, $8B, $08, 0, 0, 0, 0, 0, 0, $FF);
  var
    LI: SizeUInt;
  begin
    Result := nil;
    if ALen = 0 then
      Exit;
    SetLength(Result, ALen);
    for LI := 0 to ALen - 1 do
      Result[LI] := FullHeader[LI];
  end;

  procedure CheckFixedHeaderLengthMatrix;
  var
    LLen: SizeUInt;
  begin
    for LLen := 2 to 9 do
      CheckSecondMemberError(GzipFixedHeaderPrefix(LLen),
        'gzip: header too short',
        'fixed-header length matrix ' + IntToStr(LLen));
    Check(True, 'gzip concatenated second member fixed-header length matrix');
  end;

begin
  LFirst := GzipCompress(TBytes.Create(1, 2, 3));

  LSecond := GzipCompress(TBytes.Create(4, 5));
  LSecond[2] := $09;
  CheckSecondMemberError(LSecond, 'gzip: unsupported method',
    'unsupported method');

  LSecond := GzipCompress(TBytes.Create(4, 5));
  LSecond[3] := LSecond[3] or $20;
  CheckSecondMemberError(LSecond, 'gzip: invalid flags',
    'reserved flags');

  CheckSecondMemberError(
    TBytes.Create($1F, $8B, $08, $04, 0, 0, 0, 0, 0, $FF, $04),
    'gzip: truncated FEXTRA', 'truncated FEXTRA');

  CheckSecondMemberError(
    TBytes.Create($1F, $8B, $08, $02, 0, 0, 0, 0, 0, $FF, 0, 0),
    'gzip: header CRC mismatch', 'bad FHCRC');

  LSecond := GzipCompress(TBytes.Create(4, 5));
  LSecond[Length(LSecond) - 8] := LSecond[Length(LSecond) - 8] xor $FF;
  CheckSecondMemberError(LSecond, 'gzip: CRC32 mismatch', 'wrong CRC');

  LSecond := GzipCompress(TBytes.Create(4, 5));
  LSecond[Length(LSecond) - 4] := LSecond[Length(LSecond) - 4] xor $FF;
  CheckSecondMemberError(LSecond, 'gzip: size mismatch', 'wrong size');

  CheckSecondMemberError(TBytes.Create($1F, $8B, $08),
    'gzip: header too short', 'truncated fixed header');
  CheckFixedHeaderLengthMatrix;
  CheckSecondMemberError(TBytes.Create($1F),
    'gzip: trailing bytes after trailer',
    'single magic byte remains trailing bytes');
  CheckSecondMemberError(TBytes.Create($1F, 0),
    'gzip: trailing bytes after trailer',
    'partial magic remains trailing bytes');
  CheckSecondMemberError(TBytes.Create($DE, $AD, $7A),
    'gzip: trailing bytes after trailer',
    'ordinary garbage remains trailing bytes');
end;

procedure TestGzipConcatenatedTruncatedSecondMemberTrailerDeferredValidation;
var
  LFirstPayload: TBytes;
  LSecondPayload: TBytes;
  LFirst: TBytes;
  LSecond: TBytes;
  LConcat: TBytes;
  LReader: IDecompressReader;
  LOut: TBytes;
  LByte: Byte;
  LRead: SizeUInt;
  LGot: Boolean;
begin
  LFirstPayload := TBytes.Create(1, 2, 3);
  LSecondPayload := TBytes.Create(4, 5);
  LFirst := GzipCompress(LFirstPayload);
  LSecond := GzipCompress(LSecondPayload);
  SetLength(LSecond, Length(LSecond) - 4);
  SetLength(LConcat, Length(LFirst) + Length(LSecond));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));

  LGot := False;
  try
    GzipDecompress(LConcat);
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGot,
    'gzip one-shot concatenated truncated second member trailer has stable error');

  LGot := False;
  try
    GzipDecompressWithMaxOutputSize(LConcat,
      Length(LFirstPayload) + Length(LSecondPayload));
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGot,
    'gzip bounded one-shot concatenated truncated second member trailer has stable error');

  LReader := GzipReader(TOneByteReader.Create(LConcat));
  SetLength(LOut, Length(LFirstPayload));
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(Length(LFirstPayload)), Int64(LRead),
    'gzip stream concatenated truncated second member trailer first payload read');
  CheckBytesEqual(LFirstPayload, LOut,
    'gzip stream concatenated truncated second member trailer first payload bytes');

  SetLength(LOut, Length(LSecondPayload));
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(Length(LSecondPayload)), Int64(LRead),
    'gzip stream concatenated truncated second member trailer second payload read');
  CheckBytesEqual(LSecondPayload, LOut,
    'gzip stream concatenated truncated second member trailer second payload bytes');

  LGot := False;
  LByte := $A5;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGot,
    'gzip stream concatenated truncated second member trailer raises on next read');
  CheckEqual(Int64($A5), Int64(LByte),
    'gzip stream concatenated truncated second member trailer preserves caller byte');
  LByte := $5A;
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip stream concatenated truncated second member trailer leaves reader terminal');
  CheckEqual(Int64($5A), Int64(LByte),
    'gzip stream concatenated truncated second member trailer terminal read preserves caller byte');
  LReader.Close;
  LReader.Close;
end;

procedure TestGzipBoundedReaderConcatenatedTruncatedSecondMemberHeader;
var
  LFirstPayload: TBytes;
  LFirst: TBytes;
  LSecond: TBytes;
  LConcat: TBytes;
  LReader: IDecompressReader;
  LOut: TBytes;
  LByte: Byte;
  LRead: SizeUInt;
  LGot: Boolean;
begin
  LFirstPayload := TBytes.Create(1, 2, 3);
  LFirst := GzipCompress(LFirstPayload);
  LSecond := TBytes.Create($1F, $8B, $08);
  SetLength(LConcat, Length(LFirst) + Length(LSecond));
  Move(LFirst[0], LConcat[0], Length(LFirst));
  Move(LSecond[0], LConcat[Length(LFirst)], Length(LSecond));

  LReader := GzipReaderWithMaxOutputSize(CreateBytesStreamFrom(LConcat) as IReader,
    Length(LFirstPayload));
  SetLength(LOut, Length(LFirstPayload));
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(Length(LFirstPayload)), Int64(LRead),
    'gzip bounded reader concatenated truncated second member header first member read');
  CheckBytesEqual(LFirstPayload, LOut,
    'gzip bounded reader concatenated truncated second member header first member bytes');

  LGot := False;
  LByte := $A5;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGot,
    'gzip bounded reader concatenated truncated second member header reports short header');
  CheckEqual(Int64($A5), Int64(LByte),
    'gzip bounded reader concatenated truncated second member header preserves caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip bounded reader concatenated truncated second member header leaves reader terminal');
  LReader.Close;
  LReader.Close;
end;

procedure TestGzipRejectsTruncatedNextMemberHeaderAfterTrailer;
var
  LGood: TBytes;
  LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotBounded: Boolean;
  LGotStream: Boolean;
  LByte: Byte;
begin
  LGood := GzipCompress(TBytes.Create(1, 2, 3));
  SetLength(LBad, Length(LGood) + 3);
  Move(LGood[0], LBad[0], Length(LGood));
  LBad[Length(LGood)] := $1F;
  LBad[Length(LGood) + 1] := $8B;
  LBad[Length(LGood) + 2] := $08;

  LGotOneShot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotOneShot, 'gzip one-shot rejects truncated next member header');

  LGotBounded := False;
  try
    GzipDecompressWithMaxOutputSize(LBad, 3);
  except
    on E: EIOError do
      LGotBounded := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotBounded, 'gzip bounded one-shot rejects truncated next member header');

  LGotStream := False;
  LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
  try
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('gzip: header too short', E.Message) > 0;
  end;
  Check(LGotStream, 'gzip stream rejects truncated next member header');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip stream truncated next member error leaves terminal reader');
  LReader.Close;
  LReader.Close;
end;

procedure TestGzipReservedFlagsRejected;
const
  RESERVED_FLAGS: array[0..2] of Byte = ($20, $40, $80);
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LI: Integer;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  for LI := Low(RESERVED_FLAGS) to High(RESERVED_FLAGS) do
  begin
    LC := GzipCompress(LSrc);
    LC[3] := LC[3] or RESERVED_FLAGS[LI];

    LGot := False;
    try
      GzipDecompress(LC);
    except
      LGot := True;
    end;
    Check(LGot, 'gzip one-shot reserved flag $' + IntToHex(RESERVED_FLAGS[LI], 2) + ' raises');

    LGot := False;
    try
      LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
      IoReadAll(LReader as IReader);
      LReader.Close;
    except
      LGot := True;
    end;
    Check(LGot, 'gzip stream reserved flag $' + IntToHex(RESERVED_FLAGS[LI], 2) + ' raises');
  end;
end;

procedure TestGzipHeaderCrcRejected;
var
  LSrc, LC, LD, LWithHeaderCrc, LWithNameAndHeaderCrc: TBytes;
  LReader: IDecompressReader;
  LHeaderCRC: UInt16;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4);
  LC := GzipCompress(LSrc);

  SetLength(LWithHeaderCrc, Length(LC) + 2);
  Move(LC[0], LWithHeaderCrc[0], 10);
  LWithHeaderCrc[3] := LWithHeaderCrc[3] or $02;
  LHeaderCRC := UInt16(crc32(0, @LWithHeaderCrc[0], 10));
  LWithHeaderCrc[10] := Byte(LHeaderCRC);
  LWithHeaderCrc[11] := Byte(LHeaderCRC shr 8);
  Move(LC[10], LWithHeaderCrc[12], Length(LC) - 10);

  LD := GzipDecompress(LWithHeaderCrc);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip one-shot valid header CRC length');
  Check((LD[0] = LSrc[0]) and (LD[High(LD)] = LSrc[High(LSrc)]),
    'gzip one-shot valid header CRC content');

  LReader := GzipReader(CreateBytesStreamFrom(LWithHeaderCrc) as IReader);
  LD := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip stream valid header CRC length');
  Check((LD[0] = LSrc[0]) and (LD[High(LD)] = LSrc[High(LSrc)]),
    'gzip stream valid header CRC content');

  SetLength(LWithNameAndHeaderCrc, Length(LC) + 5);
  Move(LC[0], LWithNameAndHeaderCrc[0], 10);
  LWithNameAndHeaderCrc[3] := LWithNameAndHeaderCrc[3] or $0A;
  LWithNameAndHeaderCrc[10] := Ord('n');
  LWithNameAndHeaderCrc[11] := Ord('p');
  LWithNameAndHeaderCrc[12] := 0;
  LHeaderCRC := UInt16(crc32(0, @LWithNameAndHeaderCrc[0], 13));
  LWithNameAndHeaderCrc[13] := Byte(LHeaderCRC);
  LWithNameAndHeaderCrc[14] := Byte(LHeaderCRC shr 8);
  Move(LC[10], LWithNameAndHeaderCrc[15], Length(LC) - 10);

  LD := GzipDecompress(LWithNameAndHeaderCrc);
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip one-shot FNAME header CRC length');

  LReader := GzipReader(CreateBytesStreamFrom(LWithNameAndHeaderCrc) as IReader);
  LD := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip stream FNAME header CRC length');

  LC := Copy(LWithHeaderCrc, 0, Length(LWithHeaderCrc));
  LC[10] := LC[10] xor $FF;

  LGot := False;
  try
    GzipDecompress(LC);
  except
    on E: EIOError do
      LGot := Pos('gzip: header CRC mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip one-shot header CRC has stable error');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    on E: EIOError do
      LGot := Pos('gzip: header CRC mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip stream header CRC has stable error');
end;

procedure TestGzipOptionalHeaderAllFieldsRoundTrip;

  procedure AppendByte(var AData: TBytes; const AByte: Byte);
  var
    LLen: SizeInt;
  begin
    LLen := Length(AData);
    SetLength(AData, LLen + 1);
    AData[LLen] := AByte;
  end;

  procedure AppendNullTerminated(var AData: TBytes; const AText: AnsiString);
  var
    LI: SizeInt;
  begin
    for LI := 1 to Length(AText) do
      AppendByte(AData, Ord(AText[LI]));
    AppendByte(AData, 0);
  end;

  procedure AppendTail(var AData: TBytes; const ASource: TBytes;
    const AOffset: SizeInt);
  var
    LLen: SizeInt;
    LCount: SizeInt;
  begin
    LCount := Length(ASource) - AOffset;
    LLen := Length(AData);
    SetLength(AData, LLen + LCount);
    if LCount > 0 then
      Move(ASource[AOffset], AData[LLen], LCount);
  end;

  function BuildAllFieldsMember(const ABase: TBytes;
    out AHeaderCrcOffset: SizeInt): TBytes;
  const
    ALL_OPTIONAL_HEADER_FLAGS = $1E;
    EXTRA_LEN = 4;
  var
    LHeaderCRC: UInt16;
  begin
    Result := nil;
    SetLength(Result, 10);
    Move(ABase[0], Result[0], 10);
    Result[3] := ALL_OPTIONAL_HEADER_FLAGS;

    AppendByte(Result, EXTRA_LEN);
    AppendByte(Result, 0);
    AppendByte(Result, Ord('n'));
    AppendByte(Result, Ord('p'));
    AppendByte(Result, Ord('x'));
    AppendByte(Result, 1);
    AppendNullTerminated(Result, 'nextpas.bin');
    AppendNullTerminated(Result, 'all optional fields');

    AHeaderCrcOffset := Length(Result);
    LHeaderCRC := UInt16(crc32(0, @Result[0], AHeaderCrcOffset));
    AppendByte(Result, Byte(LHeaderCRC));
    AppendByte(Result, Byte(LHeaderCRC shr 8));
    AppendTail(Result, ABase, 10);
  end;

var
  LSrc, LBase, LWithAllFields, LBadHeaderCRC, LOut: TBytes;
  LReader: IDecompressReader;
  LHeaderCrcOffset: SizeInt;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 1, 2, 3, 5, 8, 13, 21, 34, 55);
  LBase := GzipCompress(LSrc);
  LWithAllFields := BuildAllFieldsMember(LBase, LHeaderCrcOffset);

  LOut := GzipDecompress(LWithAllFields);
  CheckBytesEqual(LSrc, LOut, 'gzip one-shot all optional header fields');

  LOut := GzipDecompressWithMaxOutputSize(LWithAllFields, Length(LSrc));
  CheckBytesEqual(LSrc, LOut,
    'gzip bounded one-shot all optional header fields');

  LReader := GzipReader(TOneByteReader.Create(LWithAllFields));
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckBytesEqual(LSrc, LOut,
    'gzip one-byte stream all optional header fields');

  LBadHeaderCRC := Copy(LWithAllFields, 0, Length(LWithAllFields));
  LBadHeaderCRC[LHeaderCrcOffset] := LBadHeaderCRC[LHeaderCrcOffset] xor $FF;

  LGot := False;
  try
    GzipDecompress(LBadHeaderCRC);
  except
    on E: EIOError do
      LGot := Pos('gzip: header CRC mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip one-shot all optional header fields reject bad FHCRC');

  LGot := False;
  try
    LReader := GzipReader(TOneByteReader.Create(LBadHeaderCRC));
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('gzip: header CRC mismatch', E.Message) > 0;
  end;
  Check(LGot, 'gzip stream all optional header fields reject bad FHCRC');
end;

procedure TestGzipTruncatedPayloadRaisesOnRead;
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LI: Integer;
begin
  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 13 + 7) mod 251);
  LC := GzipCompress(LSrc);
  SetLength(LC, 16);

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LC) as IReader);
    IoReadAll(LReader as IReader);
  except
    LGot := True;
  end;
  Check(LGot, 'gzip truncated payload raises during read');
end;

{ === C. Streaming Boundary Tests === }

procedure TestDeflateStreamByteByByte;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 256);
  for LI := 0 to 255 do LSrc[LI] := Byte(LI);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  // Write byte by byte
  for LI := 0 to 255 do
    LWriter.Write(LSrc[LI], 1);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(256), Int64(Length(LOut)), 'byte-by-byte length');
  for LI := 0 to 255 do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'byte-by-byte mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'byte-by-byte matches');
end;

procedure TestDeflateCrossApiRoundTrip;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc: TBytes;
  LCompressed: TBytes;
  LOut: TBytes;
  LI: SizeInt;
  LWritten: SizeUInt;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 31 + 17) mod 251);

  LCompressed := DeflateCompress(LSrc);
  LReader := DeflateReader(CreateBytesStreamFrom(LCompressed) as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckBytesEqual(LSrc, LOut, 'one-shot DeflateCompress to streaming DeflateReader');

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWritten := LWriter.Write(LSrc[0], 127);
  CheckEqual(Int64(127), Int64(LWritten), 'streaming DeflateWriter first chunk');
  LWritten := LWriter.Write(LSrc[127], SizeUInt(Length(LSrc)) - 127);
  CheckEqual(Int64(Length(LSrc) - 127), Int64(LWritten),
    'streaming DeflateWriter second chunk');
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LCompressed := IoReadAll(LBuf as IReader);
  LOut := DeflateDecompress(LCompressed);
  CheckBytesEqual(LSrc, LOut, 'streaming DeflateWriter to one-shot DeflateDecompress');
end;

procedure TestGzipCrossApiRoundTrip;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc: TBytes;
  LCompressed: TBytes;
  LOut: TBytes;
  LI: SizeInt;
  LWritten: SizeUInt;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 37 + 19) mod 251);

  LCompressed := GzipCompress(LSrc);
  LReader := GzipReader(CreateBytesStreamFrom(LCompressed) as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckBytesEqual(LSrc, LOut, 'one-shot GzipCompress to streaming GzipReader');

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWritten := LWriter.Write(LSrc[0], 127);
  CheckEqual(Int64(127), Int64(LWritten), 'streaming GzipWriter first chunk');
  LWritten := LWriter.Write(LSrc[127], SizeUInt(Length(LSrc)) - 127);
  CheckEqual(Int64(Length(LSrc) - 127), Int64(LWritten),
    'streaming GzipWriter second chunk');
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LCompressed := IoReadAll(LBuf as IReader);
  LOut := GzipDecompress(LCompressed);
  CheckBytesEqual(LSrc, LOut, 'streaming GzipWriter to one-shot GzipDecompress');
end;

procedure TestGzipStreamByteByByte;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LOut: TBytes;
  LI: Integer;
begin
  SetLength(LSrc, 128);
  for LI := 0 to 127 do LSrc[LI] := Byte(LI * 2);

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  for LI := 0 to 127 do
    LWriter.Write(LSrc[LI], 1);
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(128), Int64(Length(LOut)), 'gzip byte-by-byte length');
  Check(LOut[0] = 0, 'gzip byte-by-byte first');
  Check(LOut[127] = 254, 'gzip byte-by-byte last');
end;

procedure TestGzipStreamOneByteReaderLifecycle;
var
  LSrc, LCompressed, LOut: TBytes;
  LReader: IDecompressReader;
  LI: Integer;
begin
  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 17 + 3) mod 251);

  LCompressed := GzipCompress(LSrc);
  LReader := GzipReader(TOneByteReader.Create(LCompressed));
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(Length(LSrc)), Int64(Length(LOut)), 'gzip one-byte reader length');
  for LI := 0 to High(LSrc) do
    if LSrc[LI] <> LOut[LI] then
    begin
      Check(False, 'gzip one-byte reader mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, 'gzip one-byte reader round-trip');
end;

procedure TestStreamingSmallInputZeroWriteAndRepeatedEOFMatrix;
const
  CASE_SIZES: array[0..4] of SizeInt = (0, 1, 2, 3, 65);

  procedure CheckCodec(const AUseGzip: Boolean; const ASize: SizeInt);
  var
    LBuf: IStream;
    LWriter: ICompressWriter;
    LReader: IDecompressReader;
    LSrc, LOut: TBytes;
    LReadBuf: array[0..4] of Byte;
    LLabel: string;
    LSentinel: Byte;
    LI: SizeInt;
    LPos, LChunk, LOutLen, LOldLen, LRead: SizeUInt;
  begin
    if AUseGzip then
      LLabel := 'gzip'
    else
      LLabel := 'deflate';
    LLabel := LLabel + ' small input ' + IntToStr(ASize);

    SetLength(LSrc, ASize);
    for LI := 0 to High(LSrc) do
      LSrc[LI] := Byte((LI * 37 + ASize) mod 251);

    LBuf := CreateBytesStream;
    if AUseGzip then
      LWriter := GzipWriter(LBuf as IWriter)
    else
      LWriter := DeflateWriter(LBuf as IWriter);

    FillChar(LReadBuf, SizeOf(LReadBuf), $5A);
    CheckEqual(Int64(0), Int64(LWriter.Write(LReadBuf[0], 0)),
      LLabel + ' zero-write before payload returns 0');

    LPos := 0;
    while LPos < SizeUInt(Length(LSrc)) do
    begin
      LChunk := SizeUInt(Length(LSrc)) - LPos;
      if LChunk > 3 then
        LChunk := 3;
      CheckEqual(Int64(LChunk),
        Int64(LWriter.Write(LSrc[SizeInt(LPos)], LChunk)),
        LLabel + ' chunk write returns full count');
      CheckEqual(Int64(0), Int64(LWriter.Write(LReadBuf[0], 0)),
        LLabel + ' zero-write between chunks returns 0');
      Inc(LPos, LChunk);
    end;

    CheckEqual(Int64(0), Int64(LWriter.Write(LReadBuf[0], 0)),
      LLabel + ' zero-write after payload returns 0');
    LWriter.Close;

    LBuf.Seek(0, soBeginning);
    if AUseGzip then
      LReader := GzipReader(LBuf as IReader)
    else
      LReader := DeflateReader(LBuf as IReader);

    LOut := nil;
    LOutLen := 0;
    repeat
      FillChar(LReadBuf, SizeOf(LReadBuf), $CC);
      LRead := (LReader as IReader).Read(LReadBuf[0],
        SizeUInt(SizeOf(LReadBuf)));
      if LRead = 0 then
        Break;
      LOldLen := LOutLen;
      Inc(LOutLen, LRead);
      SetLength(LOut, LOutLen);
      Move(LReadBuf[0], LOut[LOldLen], LRead);
    until False;

    CheckBytesEqual(LSrc, LOut, LLabel + ' manual streaming output');

    LSentinel := $A5;
    LRead := (LReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      LLabel + ' repeated EOF first read returns 0');
    CheckEqual(Int64($A5), Int64(LSentinel),
      LLabel + ' repeated EOF first read preserves sentinel');

    LRead := (LReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      LLabel + ' repeated EOF second read returns 0');
    CheckEqual(Int64($A5), Int64(LSentinel),
      LLabel + ' repeated EOF second read preserves sentinel');

    LReader.Close;
    LReader.Close;
  end;

var
  LI: SizeInt;
begin
  for LI := Low(CASE_SIZES) to High(CASE_SIZES) do
  begin
    CheckCodec(False, CASE_SIZES[LI]);
    CheckCodec(True, CASE_SIZES[LI]);
  end;
end;

procedure TestStreamingReaderCorruptErrorLeavesTerminalMatrix;

  procedure CheckTerminalAfterError(const AReader: IDecompressReader;
    const AExpectedError, ALabel: string);
  var
    LBuf: array[0..6] of Byte;
    LSentinel: Byte;
    LGot: Boolean;
    LRead: SizeUInt;
  begin
    LGot := False;
    try
      repeat
        LRead := (AReader as IReader).Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      until LRead = 0;
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' raises stable error');

    LSentinel := $A5;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after error returns 0');
    CheckEqual(Int64($A5), Int64(LSentinel),
      ALabel + ' read after error preserves sentinel');

    AReader.Close;
    AReader.Close;
  end;

  function DeflateCorruptPayload: TBytes;
  var
    LSrc: TBytes;
  begin
    LSrc := TBytes.Create(1, 2, 3, 5, 8, 13, 21, 34, 55, 89);
    Result := DeflateCompress(LSrc);
    Result[Length(Result) div 2] := Result[Length(Result) div 2] xor $FF;
  end;

  function GzipCorruptPayload: TBytes;
  begin
    Result := TBytes.Create(
      $1F, $8B, $08, $00, 0, 0, 0, 0, 0, $FF,
      $07,
      0, 0, 0, 0, 0, 0, 0, 0
    );
  end;

  function GzipWrongCrc: TBytes;
  var
    LSrc: TBytes;
  begin
    LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
    Result := GzipCompress(LSrc);
    Result[Length(Result) - 8] := 0;
    Result[Length(Result) - 7] := 0;
    Result[Length(Result) - 6] := 0;
    Result[Length(Result) - 5] := 0;
  end;

  function GzipWrongSize: TBytes;
  var
    LSrc: TBytes;
  begin
    LSrc := TBytes.Create(1, 2, 3, 4, 5);
    Result := GzipCompress(LSrc);
    Result[Length(Result) - 4] := 99;
  end;

  function GzipTrailingBytes: TBytes;
  var
    LSrc, LC: TBytes;
  begin
    LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);
    LC := GzipCompress(LSrc);
    Result := nil;
    SetLength(Result, Length(LC) + 3);
    Move(LC[0], Result[0], Length(LC));
    Result[Length(LC)] := $DE;
    Result[Length(LC) + 1] := $AD;
    Result[Length(LC) + 2] := $7A;
  end;

begin
  CheckTerminalAfterError(
    DeflateReader(CreateBytesStreamFrom(DeflateCorruptPayload) as IReader),
    'deflate: corrupt stream', 'deflate corrupt payload');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipCorruptPayload) as IReader),
    'gzip: corrupt stream', 'gzip corrupt payload');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipWrongCrc) as IReader),
    'gzip: CRC32 mismatch', 'gzip wrong CRC');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipWrongSize) as IReader),
    'gzip: size mismatch', 'gzip wrong size');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipTrailingBytes) as IReader),
    'gzip: trailing bytes after trailer', 'gzip trailing bytes');
end;

procedure TestStreamingReaderDeferredValidationAfterPayload;

  procedure AppendByte(var AData: TBytes; const AByte: Byte);
  var
    LOldLen: SizeInt;
  begin
    LOldLen := Length(AData);
    SetLength(AData, LOldLen + 1);
    AData[LOldLen] := AByte;
  end;

  function DeflateWithTrailingBytes(const ASource: TBytes): TBytes;
  begin
    Result := DeflateCompress(ASource);
    AppendByte(Result, $99);
  end;

  function DeflateWithWrongChecksum(const ASource: TBytes): TBytes;
  begin
    Result := DeflateCompress(ASource);
    Result[Length(Result) - 1] := Result[Length(Result) - 1] xor $FF;
  end;

  function GzipWithWrongCrc(const ASource: TBytes): TBytes;
  var
    LCrcOffset: SizeInt;
  begin
    Result := GzipCompress(ASource);
    LCrcOffset := Length(Result) - 8;
    Result[LCrcOffset] := Result[LCrcOffset] xor $FF;
  end;

  function GzipWithWrongSize(const ASource: TBytes): TBytes;
  var
    LSizeOffset: SizeInt;
  begin
    Result := GzipCompress(ASource);
    LSizeOffset := Length(Result) - 4;
    Result[LSizeOffset] := Result[LSizeOffset] xor $FF;
  end;

  function GzipWithWrongSizeWithinCap(const ASource: TBytes): TBytes;
  var
    LSizeOffset: SizeInt;
    LWrongSize: UInt32;
  begin
    Result := GzipCompress(ASource);
    LSizeOffset := Length(Result) - 4;
    LWrongSize := UInt32(Length(ASource) - 1);
    Result[LSizeOffset] := Byte(LWrongSize);
    Result[LSizeOffset + 1] := Byte(LWrongSize shr 8);
    Result[LSizeOffset + 2] := Byte(LWrongSize shr 16);
    Result[LSizeOffset + 3] := Byte(LWrongSize shr 24);
  end;

  function GzipWithTruncatedTrailer(const ASource: TBytes): TBytes;
  begin
    Result := GzipCompress(ASource);
    SetLength(Result, Length(Result) - 4);
  end;

  function DeflateWithCorruptPayloadAfterPartialOutput(const ASource: TBytes): TBytes;
  var
    LLen: UInt16;
    LNLen: UInt16;
    LDataOffset: SizeInt;
  begin
    Result := nil;
    LLen := UInt16(Length(ASource));
    LNLen := not LLen;
    SetLength(Result, 2 + 5 + Length(ASource) + 1);
    Result[0] := $78;
    Result[1] := $01;
    Result[2] := $00;
    Result[3] := Byte(LLen);
    Result[4] := Byte(LLen shr 8);
    Result[5] := Byte(LNLen);
    Result[6] := Byte(LNLen shr 8);
    LDataOffset := 7;
    Move(ASource[0], Result[LDataOffset], Length(ASource));
    Result[LDataOffset + Length(ASource)] := $07;
  end;

  function GzipWithCorruptPayloadAfterPartialOutput(const ASource: TBytes): TBytes;
  var
    LLen: UInt16;
    LNLen: UInt16;
    LDataOffset: SizeInt;
  begin
    Result := nil;
    LLen := UInt16(Length(ASource));
    LNLen := not LLen;
    SetLength(Result, 10 + 5 + Length(ASource) + 1);
    Result[0] := $1F;
    Result[1] := $8B;
    Result[2] := $08;
    Result[3] := $00;
    Result[4] := $00;
    Result[5] := $00;
    Result[6] := $00;
    Result[7] := $00;
    Result[8] := $00;
    Result[9] := $FF;
    Result[10] := $00;
    Result[11] := Byte(LLen);
    Result[12] := Byte(LLen shr 8);
    Result[13] := Byte(LNLen);
    Result[14] := Byte(LNLen shr 8);
    LDataOffset := 15;
    Move(ASource[0], Result[LDataOffset], Length(ASource));
    Result[LDataOffset + Length(ASource)] := $07;
  end;

  function GzipWithTrailingBytes(const ASource: TBytes): TBytes;
  begin
    Result := GzipCompress(ASource);
    AppendByte(Result, $DE);
  end;

  procedure CheckDeferredValidation(const AReader: IDecompressReader;
    const AExpectedPayload: TBytes; const AExpectedError, ALabel: string);
  var
    LOut: TBytes;
    LSentinel: Byte;
    LRead: SizeUInt;
    LGotError: Boolean;
  begin
    SetLength(LOut, Length(AExpectedPayload));
    LRead := (AReader as IReader).Read(LOut[0], Length(LOut));
    CheckEqual(Int64(Length(AExpectedPayload)), Int64(LRead),
      ALabel + ' returns payload before validation');
    CheckBytesEqual(AExpectedPayload, LOut, ALabel + ' payload bytes');

    LSentinel := $C3;
    LRead := (AReader as IReader).Read(LSentinel, 0);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' zero-count read before validation returns 0');
    CheckEqual(Int64($C3), Int64(LSentinel),
      ALabel + ' zero-count read before validation preserves sentinel');

    LSentinel := $A5;
    LGotError := False;
    try
      (AReader as IReader).Read(LSentinel, 1);
    except
      on E: EIOError do
        LGotError := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotError, ALabel + ' raises on next read');
    CheckEqual(Int64($A5), Int64(LSentinel),
      ALabel + ' error read preserves sentinel');

    LSentinel := $5A;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after error returns 0');
    CheckEqual(Int64($5A), Int64(LSentinel),
      ALabel + ' read after error preserves sentinel');

    AReader.Close;
    AReader.Close;
  end;

  procedure CheckBoundedDeferredValidationPreservesCallerTail(
    const AReader: IDecompressReader; const AExpectedPayload: TBytes;
    const AExpectedError, ALabel: string);
  var
    LBuf: array[0..63] of Byte;
    LSentinel: Byte;
    LRead: SizeUInt;
    LGotError: Boolean;
    LI: SizeInt;
  begin
    FillChar(LBuf, SizeOf(LBuf), $CC);
    LRead := (AReader as IReader).Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(Int64(Length(AExpectedPayload)), Int64(LRead),
      ALabel + ' returns payload before validation');
    for LI := 0 to SizeInt(LRead) - 1 do
      if LBuf[LI] <> AExpectedPayload[LI] then
      begin
        Check(False, ALabel + ' payload mismatch at ' + IntToStr(LI));
        Break;
      end;
    for LI := SizeInt(LRead) to High(LBuf) do
      if LBuf[LI] <> $CC then
      begin
        Check(False, ALabel + ' caller tail changed at ' + IntToStr(LI));
        Break;
      end;

    LSentinel := $C3;
    LRead := (AReader as IReader).Read(LSentinel, 0);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' zero-count read before validation returns 0');
    CheckEqual(Int64($C3), Int64(LSentinel),
      ALabel + ' zero-count read before validation preserves sentinel');

    LSentinel := $A5;
    LGotError := False;
    try
      (AReader as IReader).Read(LSentinel, 1);
    except
      on E: EIOError do
        LGotError := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotError, ALabel + ' raises on next read');
    CheckEqual(Int64($A5), Int64(LSentinel),
      ALabel + ' error read preserves sentinel');

    LSentinel := $5A;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after error returns 0');
    CheckEqual(Int64($5A), Int64(LSentinel),
      ALabel + ' read after error preserves sentinel');

    AReader.Close;
    AReader.Close;
  end;

  procedure CheckDeferredCorruptPayloadAfterProducedBytes(const AReader: IDecompressReader;
    const AExpectedPayload: TBytes; const AExpectedError, ALabel: string);
  var
    LBuf: array[0..2047] of Byte;
    LSentinel: Byte;
    LRead: SizeUInt;
    LGotError: Boolean;
    LI: SizeInt;
  begin
    FillChar(LBuf, SizeOf(LBuf), $CC);
    LRead := (AReader as IReader).Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(Int64(Length(AExpectedPayload)), Int64(LRead),
      ALabel + ' returns produced bytes before corrupt error');
    for LI := 0 to SizeInt(LRead) - 1 do
      if LBuf[LI] <> AExpectedPayload[LI] then
      begin
        Check(False, ALabel + ' payload mismatch at ' + IntToStr(LI));
        Break;
      end;
    if LRead < SizeUInt(SizeOf(LBuf)) then
      CheckEqual(Int64($CC), Int64(LBuf[LRead]),
        ALabel + ' does not write beyond returned byte count');

    LSentinel := $C3;
    LRead := (AReader as IReader).Read(LSentinel, 0);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' zero-count read before deferred corrupt error returns 0');
    CheckEqual(Int64($C3), Int64(LSentinel),
      ALabel + ' zero-count read before deferred corrupt error preserves sentinel');

    LSentinel := $A5;
    LGotError := False;
    try
      (AReader as IReader).Read(LSentinel, 1);
    except
      on E: EIOError do
        LGotError := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGotError, ALabel + ' raises corrupt stream on next read');
    CheckEqual(Int64($A5), Int64(LSentinel),
      ALabel + ' error read preserves sentinel');

    LSentinel := $5A;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after corrupt error returns 0');
    CheckEqual(Int64($5A), Int64(LSentinel),
      ALabel + ' read after corrupt error preserves sentinel');

    AReader.Close;
    AReader.Close;
  end;

  procedure CheckCloseClearsDeferredCorruptPayload(const AReader: IDecompressReader;
    const AExpectedPayload: TBytes; const ALabel: string);
  var
    LBuf: array[0..2047] of Byte;
    LSentinel: Byte;
    LRead: SizeUInt;
  begin
    FillChar(LBuf, SizeOf(LBuf), $CC);
    LRead := (AReader as IReader).Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(Int64(Length(AExpectedPayload)), Int64(LRead),
      ALabel + ' returns produced bytes before close');
    AReader.Close;
    AReader.Close;

    LSentinel := $5A;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after close returns 0');
    CheckEqual(Int64($5A), Int64(LSentinel),
      ALabel + ' read after close preserves sentinel');
  end;

var
  LSrc: TBytes;
  LI: SizeInt;
begin
  LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);

  CheckDeferredValidation(
    DeflateReader(CreateBytesStreamFrom(DeflateWithTrailingBytes(LSrc)) as IReader),
    LSrc, 'deflate: trailing bytes after stream',
    'deflate trailing bytes after payload read raises on next read');
  CheckDeferredValidation(
    DeflateReader(CreateBytesStreamFrom(DeflateWithWrongChecksum(LSrc)) as IReader),
    LSrc, 'deflate: corrupt stream',
    'deflate checksum after payload read raises on next read');
  CheckDeferredValidation(
    GzipReader(CreateBytesStreamFrom(GzipWithTrailingBytes(LSrc)) as IReader),
    LSrc, 'gzip: trailing bytes after trailer',
    'gzip trailing bytes after payload read raises on next read');
  CheckDeferredValidation(
    GzipReader(CreateBytesStreamFrom(GzipWithWrongCrc(LSrc)) as IReader),
    LSrc, 'gzip: CRC32 mismatch',
    'gzip CRC after payload read raises on next read');
  CheckDeferredValidation(
    GzipReader(CreateBytesStreamFrom(GzipWithWrongSize(LSrc)) as IReader),
    LSrc, 'gzip: size mismatch',
    'gzip size after payload read raises on next read');
  CheckDeferredValidation(
    GzipReader(CreateBytesStreamFrom(GzipWithTruncatedTrailer(LSrc)) as IReader),
    LSrc, 'gzip: truncated trailer',
    'gzip truncated trailer after payload read raises on next read');

  CheckBoundedDeferredValidationPreservesCallerTail(
    DeflateReaderWithMaxOutputSize(
      CreateBytesStreamFrom(DeflateWithWrongChecksum(LSrc)) as IReader,
      Length(LSrc)),
    LSrc, 'deflate: corrupt stream',
    'deflate bounded checksum after oversized payload read preserves tail');
  CheckBoundedDeferredValidationPreservesCallerTail(
    GzipReaderWithMaxOutputSize(
      CreateBytesStreamFrom(GzipWithWrongCrc(LSrc)) as IReader,
      Length(LSrc)),
    LSrc, 'gzip: CRC32 mismatch',
    'gzip bounded CRC after oversized payload read preserves tail');
  CheckBoundedDeferredValidationPreservesCallerTail(
    GzipReaderWithMaxOutputSize(
      CreateBytesStreamFrom(GzipWithWrongSizeWithinCap(LSrc)) as IReader,
      Length(LSrc)),
    LSrc, 'gzip: size mismatch',
    'gzip bounded size after oversized payload read preserves tail');

  SetLength(LSrc, 1024);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 17 + 31) and $FF);
  CheckDeferredCorruptPayloadAfterProducedBytes(
    DeflateReader(CreateBytesStreamFrom(DeflateWithCorruptPayloadAfterPartialOutput(
      LSrc)) as IReader),
    LSrc, 'deflate: corrupt stream',
    'deflate corrupt payload after partial output raises on next read');
  CheckCloseClearsDeferredCorruptPayload(
    DeflateReader(CreateBytesStreamFrom(DeflateWithCorruptPayloadAfterPartialOutput(
      LSrc)) as IReader),
    LSrc,
    'deflate close after deferred corrupt payload suppresses pending error');
  CheckDeferredCorruptPayloadAfterProducedBytes(
    GzipReader(CreateBytesStreamFrom(GzipWithCorruptPayloadAfterPartialOutput(
      LSrc)) as IReader),
    LSrc, 'gzip: corrupt stream',
    'gzip corrupt payload after partial output raises on next read');
  CheckCloseClearsDeferredCorruptPayload(
    GzipReader(CreateBytesStreamFrom(GzipWithCorruptPayloadAfterPartialOutput(
      LSrc)) as IReader),
    LSrc,
    'gzip close after deferred corrupt payload suppresses pending error');
end;

procedure TestStreamingReaderTruncatedErrorLeavesTerminalMatrix;

  procedure CheckTerminalAfterError(const AReader: IDecompressReader;
    const AExpectedError, ALabel: string);
  var
    LBuf: array[0..6] of Byte;
    LSentinel: Byte;
    LGot: Boolean;
    LRead: SizeUInt;
  begin
    LGot := False;
    try
      repeat
        LRead := (AReader as IReader).Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      until LRead = 0;
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' raises stable error');

    LSentinel := $A5;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after error returns 0');
    CheckEqual(Int64($A5), Int64(LSentinel),
      ALabel + ' read after error preserves sentinel');

    AReader.Close;
    AReader.Close;
  end;

  function DeflateTruncatedPayload: TBytes;
  var
    LSrc: TBytes;
  begin
    LSrc := TBytes.Create(1, 2, 3, 5, 8, 13, 21, 34, 55, 89);
    Result := DeflateCompress(LSrc);
    SetLength(Result, Length(Result) - 1);
  end;

  function DeflateHeaderOnlyPayload: TBytes;
  begin
    Result := TBytes.Create($78, $9C);
  end;

  function GzipTruncatedPayload: TBytes;
  var
    LSrc: TBytes;
  begin
    SetLength(LSrc, 1024);
    FillChar(LSrc[0], Length(LSrc), $37);
    Result := GzipCompress(LSrc);
    SetLength(Result, 16);
  end;

  function GzipTruncatedTrailer: TBytes;
  var
    LSrc: TBytes;
  begin
    LSrc := TBytes.Create(1, 2, 3);
    Result := GzipCompress(LSrc);
    SetLength(Result, Length(Result) - 4);
  end;

begin
  CheckTerminalAfterError(
    DeflateReader(CreateBytesStreamFrom(DeflateTruncatedPayload) as IReader),
    'deflate: truncated stream', 'deflate truncated payload');
  CheckTerminalAfterError(
    DeflateReader(CreateBytesStreamFrom(DeflateHeaderOnlyPayload) as IReader),
    'deflate: truncated stream', 'deflate header-only payload');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipTruncatedPayload) as IReader),
    'gzip: truncated stream', 'gzip truncated payload');
  CheckTerminalAfterError(
    GzipReader(CreateBytesStreamFrom(GzipTruncatedTrailer) as IReader),
    'gzip: truncated trailer', 'gzip truncated trailer');
end;

procedure TestGzipReaderPartialCloseIsReleaseOnly;
var
  LSrc, LCompressed: TBytes;
  LReader: IDecompressReader;
  LCounting: TCountingReader;
  LByte: Byte;
  LBeforeCloseReadCount: SizeUInt;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  LCompressed := GzipCompress(LSrc);
  LCounting := TCountingReader.Create(LCompressed, 1);
  LReader := GzipReader(LCounting);

  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip partial close setup reads one byte');
  LBeforeCloseReadCount := LCounting.ReadCount;

  LGot := False;
  try
    LReader.Close;
  except
    LGot := True;
  end;
  Check(not LGot, 'gzip partial close is release-only');
  CheckEqual(Int64(LBeforeCloseReadCount), Int64(LCounting.ReadCount),
    'gzip partial close does not reread source');
end;

procedure TestDeflateReaderPartialCloseIsReleaseOnly;
var
  LSrc, LCompressed: TBytes;
  LReader: IDecompressReader;
  LCounting: TCountingReader;
  LByte: Byte;
  LBeforeCloseReadCount: SizeUInt;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  LCompressed := DeflateCompress(LSrc);
  LCounting := TCountingReader.Create(LCompressed, 1);
  LReader := DeflateReader(LCounting);

  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate partial close setup reads one byte');
  LBeforeCloseReadCount := LCounting.ReadCount;

  LGot := False;
  try
    LReader.Close;
  except
    LGot := True;
  end;
  Check(not LGot, 'deflate partial close is release-only');
  CheckEqual(Int64(LBeforeCloseReadCount), Int64(LCounting.ReadCount),
    'deflate partial close does not reread source');
end;

procedure TestStreamingReaderCloseBeforeFirstReadIsReleaseOnly;

  procedure CheckCloseBeforeRead(const AReader: IDecompressReader;
    const ACounting: TCountingReader; const ALabel: string);
  var
    LBeforeCloseReadCount: SizeUInt;
    LSentinel: Byte;
    LRead: SizeUInt;
    LGot: Boolean;
  begin
    LBeforeCloseReadCount := ACounting.ReadCount;

    LGot := False;
    try
      AReader.Close;
      AReader.Close;
    except
      LGot := True;
    end;
    Check(not LGot, ALabel + ' close-before-read is release-only');
    CheckEqual(Int64(LBeforeCloseReadCount), Int64(ACounting.ReadCount),
      ALabel + ' close-before-read does not drain source');

    LSentinel := $A6;
    LRead := (AReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after close-before-read returns 0');
    CheckEqual(Int64($A6), Int64(LSentinel),
      ALabel + ' read after close-before-read preserves sentinel');
  end;

var
  LSrc, LCompressed: TBytes;
  LCounting: TCountingReader;
begin
  LSrc := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);

  LCompressed := DeflateCompress(LSrc);
  LCounting := TCountingReader.Create(LCompressed, 1);
  CheckCloseBeforeRead(DeflateReader(LCounting), LCounting, 'deflate reader');

  LCompressed := GzipCompress(LSrc);
  LCounting := TCountingReader.Create(LCompressed, 1);
  CheckCloseBeforeRead(GzipReader(LCounting), LCounting, 'gzip reader');
end;

procedure TestStreamingWriterCloseReportsShortWrite;
var
  LWriter: ICompressWriter;
  LByte: Byte;
  LGotDeflate: Boolean;
  LGotGzip: Boolean;
  LGotGzipHeader: Boolean;
  LGotGzipTrailer: Boolean;
begin
  LByte := $5A;

  LWriter := DeflateWriter(TShortWriter.Create(1));
  LWriter.Write(LByte, 1);
  LGotDeflate := False;
  try
    LWriter.Close;
  except
    on E: EIOError do
      LGotDeflate := Pos('deflate: short write', E.Message) > 0;
  end;
  Check(LGotDeflate, 'deflate explicit close reports short write');

  LWriter := GzipWriter(TShortWriter.Create(1));
  LWriter.Write(LByte, 1);
  LGotGzip := False;
  try
    LWriter.Close;
  except
    on E: EIOError do
      LGotGzip := Pos('gzip: short write', E.Message) > 0;
  end;
  Check(LGotGzip, 'gzip explicit close reports short write');

  LGotGzipHeader := False;
  try
    LWriter := GzipWriter(TShortWriter.Create(0));
  except
    on E: EIOError do
      LGotGzipHeader := Pos('gzip: short write', E.Message) > 0;
  end;
  Check(LGotGzipHeader, 'gzip header short write uses gzip error model');

  LWriter := GzipWriter(TShortWriter.Create(2));
  LGotGzipTrailer := False;
  try
    LWriter.Close;
  except
    on E: EIOError do
      LGotGzipTrailer := Pos('gzip: short write', E.Message) > 0;
  end;
  Check(LGotGzipTrailer, 'gzip trailer short write uses gzip error model');
end;

procedure TestStreamingWriterReleaseIsNonThrowing;
var
  LWriter: ICompressWriter;
  LByte: Byte;
  LGotDeflate: Boolean;
  LGotGzip: Boolean;
begin
  LByte := $5A;

  LGotDeflate := False;
  try
    LWriter := DeflateWriter(TShortWriter.Create(1));
    LWriter.Write(LByte, 1);
    LWriter := nil;
  except
    on E: EIOError do
      LGotDeflate := True;
  end;
  Check(not LGotDeflate, 'deflate writer release is non-throwing');

  LGotGzip := False;
  try
    LWriter := GzipWriter(TShortWriter.Create(1));
    LWriter.Write(LByte, 1);
    LWriter := nil;
  except
    on E: EIOError do
      LGotGzip := True;
  end;
  Check(not LGotGzip, 'gzip writer release is non-throwing');
end;

procedure TestStreamingWriterFlushPreservesContinuation;

  procedure CheckCodec(const AUseGzip: Boolean; const ALabel: string);
  const
    FIRST_CHUNK_SIZE = 83;
  var
    LBuf: IStream;
    LWriter: ICompressWriter;
    LReader: IDecompressReader;
    LSrc: TBytes;
    LOut: TBytes;
    LSentinel: Byte;
    LRead: SizeUInt;
    LI: SizeInt;
  begin
    SetLength(LSrc, 257);
    for LI := 0 to High(LSrc) do
      LSrc[LI] := Byte((LI * 29 + 11) mod 251);

    LBuf := CreateBytesStream;
    if AUseGzip then
      LWriter := GzipWriter(LBuf as IWriter)
    else
      LWriter := DeflateWriter(LBuf as IWriter);

    CheckEqual(Int64(FIRST_CHUNK_SIZE),
      Int64(LWriter.Write(LSrc[0], FIRST_CHUNK_SIZE)),
      ALabel + ' first write returns full count');
    LWriter.Flush;
    CheckEqual(Int64(Length(LSrc) - FIRST_CHUNK_SIZE),
      Int64(LWriter.Write(LSrc[FIRST_CHUNK_SIZE],
        SizeUInt(Length(LSrc) - FIRST_CHUNK_SIZE))),
      ALabel + ' write after flush returns full count');
    LWriter.Flush;
    LWriter.Close;

    LBuf.Seek(0, soBeginning);
    if AUseGzip then
      LReader := GzipReader(LBuf as IReader)
    else
      LReader := DeflateReader(LBuf as IReader);
    LOut := IoReadAll(LReader as IReader);
    CheckBytesEqual(LSrc, LOut, ALabel + ' flush continuation payload');

    LSentinel := $C7;
    LRead := (LReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' read after flush continuation EOF returns 0');
    CheckEqual(Int64($C7), Int64(LSentinel),
      ALabel + ' read after flush continuation EOF preserves sentinel');
    LRead := (LReader as IReader).Read(LSentinel, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' repeated EOF after flush continuation returns 0');
    LReader.Close;
    LReader.Close;
  end;

begin
  CheckCodec(False, 'deflate writer flush continuation');
  CheckCodec(True, 'gzip writer flush continuation');
end;

procedure TestStreamingWriterPayloadFlushAfterClose;

  procedure CheckCodec(const AUseGzip, AFlushBeforeClose: Boolean;
    const ALabel, AFlushAfterCloseLabel: string);
  var
    LBuf: IStream;
    LWriter: ICompressWriter;
    LReader: IDecompressReader;
    LSrc: TBytes;
    LOut: TBytes;
    LGot: Boolean;
    LI: SizeInt;
  begin
    SetLength(LSrc, 97);
    for LI := 0 to High(LSrc) do
      LSrc[LI] := Byte((LI * 37 + 19) mod 251);

    LBuf := CreateBytesStream;
    if AUseGzip then
      LWriter := GzipWriter(LBuf as IWriter)
    else
      LWriter := DeflateWriter(LBuf as IWriter);

    CheckEqual(Int64(Length(LSrc)),
      Int64(LWriter.Write(LSrc[0], SizeUInt(Length(LSrc)))),
      ALabel + ' write returns full count');
    if AFlushBeforeClose then
      LWriter.Flush;
    LWriter.Close;
    LWriter.Close;

    LGot := False;
    try
      LWriter.Flush;
    except
      on E: EIOError do
        if AUseGzip then
          LGot := Pos('gzip: flush after close', E.Message) > 0
        else
          LGot := Pos('deflate: flush after close', E.Message) > 0;
    end;
    Check(LGot, AFlushAfterCloseLabel);

    LBuf.Seek(0, soBeginning);
    if AUseGzip then
      LReader := GzipReader(LBuf as IReader)
    else
      LReader := DeflateReader(LBuf as IReader);
    LOut := IoReadAll(LReader as IReader);
    CheckBytesEqual(LSrc, LOut, ALabel + ' payload round-trip after close');
  end;

begin
  CheckCodec(False, False, 'deflate payload',
    'deflate payload writer flush-after-close uses stable error');
  CheckCodec(False, True, 'deflate flushed payload',
    'deflate flushed payload writer flush-after-close uses stable error');
  CheckCodec(True, False, 'gzip payload',
    'gzip payload writer flush-after-close uses stable error');
  CheckCodec(True, True, 'gzip flushed payload',
    'gzip flushed payload writer flush-after-close uses stable error');
end;

procedure TestStreamingCloseLifecycleContract;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LData: TBytes;
  LCompressed: TBytes;
  LOut: array[0..7] of Byte;
  LByte: Byte;
  LRead: SizeUInt;
  LGotDeflate: Boolean;
  LGotGzip: Boolean;
begin
  LByte := $5A;

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Close;
  LWriter.Close;
  Check(True, 'deflate writer close is idempotent');
  LGotDeflate := False;
  try
    LWriter.Write(LByte, 1);
  except
    on E: EIOError do
      LGotDeflate := Pos('deflate: write after close', E.Message) > 0;
  end;
  Check(LGotDeflate, 'deflate writer write-after-close uses stable error');
  LGotDeflate := False;
  try
    LWriter.Write(LByte, 0);
  except
    on E: EIOError do
      LGotDeflate := Pos('deflate: write after close', E.Message) > 0;
  end;
  Check(LGotDeflate, 'deflate writer zero-write-after-close uses stable error');
  LGotDeflate := False;
  try
    LWriter.Flush;
  except
    on E: EIOError do
      LGotDeflate := Pos('deflate: flush after close', E.Message) > 0;
  end;
  Check(LGotDeflate, 'deflate writer flush-after-close uses stable error');

  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Close;
  LWriter.Close;
  Check(True, 'gzip writer close is idempotent');
  LGotGzip := False;
  try
    LWriter.Write(LByte, 1);
  except
    on E: EIOError do
      LGotGzip := Pos('gzip: write after close', E.Message) > 0;
  end;
  Check(LGotGzip, 'gzip writer write-after-close uses stable error');
  LGotGzip := False;
  try
    LWriter.Write(LByte, 0);
  except
    on E: EIOError do
      LGotGzip := Pos('gzip: write after close', E.Message) > 0;
  end;
  Check(LGotGzip, 'gzip writer zero-write-after-close uses stable error');
  LGotGzip := False;
  try
    LWriter.Flush;
  except
    on E: EIOError do
      LGotGzip := Pos('gzip: flush after close', E.Message) > 0;
  end;
  Check(LGotGzip, 'gzip writer flush-after-close uses stable error');

  LData := TBytes.Create(1, 2, 3, 4);
  LCompressed := DeflateCompress(LData);
  LReader := DeflateReader(CreateBytesStreamFrom(LCompressed) as IReader);
  LReader.Close;
  LReader.Close;
  Check(True, 'deflate reader close is idempotent');
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(0), Int64(LRead), 'deflate reader read-after-close returns 0');

  LCompressed := GzipCompress(LData);
  LReader := GzipReader(CreateBytesStreamFrom(LCompressed) as IReader);
  LReader.Close;
  LReader.Close;
  Check(True, 'gzip reader close is idempotent');
  LRead := (LReader as IReader).Read(LOut[0], SizeUInt(Length(LOut)));
  CheckEqual(Int64(0), Int64(LRead), 'gzip reader read-after-close returns 0');
end;

procedure TestStreamingWriterFailedCloseLeavesTerminal;
var
  LWriter: ICompressWriter;
  LByte: Byte;
  LGotShortWrite: Boolean;
  LGotWriteAfterClose: Boolean;
  LGotUnexpected: Boolean;
begin
  LByte := $5A;

  LWriter := DeflateWriter(TShortWriter.Create(1));
  LWriter.Write(LByte, 1);
  LGotShortWrite := False;
  try
    LWriter.Close;
  except
    on E: EIOError do
      LGotShortWrite := Pos('deflate: short write', E.Message) > 0;
  end;
  Check(LGotShortWrite, 'deflate failed close reports short write');

  LGotUnexpected := False;
  try
    LWriter.Close;
    LWriter.Flush;
  except
    LGotUnexpected := True;
  end;
  Check(not LGotUnexpected, 'deflate writer failed close leaves terminal');

  LGotWriteAfterClose := False;
  try
    LWriter.Write(LByte, 1);
  except
    on E: EIOError do
      LGotWriteAfterClose := Pos('deflate: write after close', E.Message) > 0;
  end;
  Check(LGotWriteAfterClose,
    'deflate writer failed close keeps write-after-close error');

  LGotUnexpected := False;
  try
    LWriter := nil;
  except
    LGotUnexpected := True;
  end;
  Check(not LGotUnexpected, 'deflate writer failed close release is non-throwing');

  LWriter := GzipWriter(TShortWriter.Create(2));
  LGotShortWrite := False;
  try
    LWriter.Close;
  except
    on E: EIOError do
      LGotShortWrite := Pos('gzip: short write', E.Message) > 0;
  end;
  Check(LGotShortWrite, 'gzip failed close reports short write');

  LGotUnexpected := False;
  try
    LWriter.Close;
    LWriter.Flush;
  except
    LGotUnexpected := True;
  end;
  Check(not LGotUnexpected, 'gzip writer failed close leaves terminal');

  LGotWriteAfterClose := False;
  try
    LWriter.Write(LByte, 1);
  except
    on E: EIOError do
      LGotWriteAfterClose := Pos('gzip: write after close', E.Message) > 0;
  end;
  Check(LGotWriteAfterClose,
    'gzip writer failed close keeps write-after-close error');

  LGotUnexpected := False;
  try
    LWriter := nil;
  except
    LGotUnexpected := True;
  end;
  Check(not LGotUnexpected, 'gzip writer failed close release is non-throwing');
end;

procedure TestStreamingWriterFailedPayloadWriteLeavesTerminal;

  procedure BuildPayload(var AData: TBytes);
  const
    PAYLOAD_SIZE = 3 * COMPRESS_BUF_SIZE;
  var
    LI: SizeInt;
    LSeed: UInt32;
  begin
    SetLength(AData, PAYLOAD_SIZE);
    LSeed := $13579BDF;
    for LI := 0 to High(AData) do
    begin
      {$PUSH}{$Q-}{$R-}
      LSeed := LSeed * UInt32(1664525) + UInt32(1013904223);
      {$POP}
      AData[LI] := Byte(LSeed shr 24);
    end;
  end;

  procedure CheckFailedPayloadWriteLeavesTerminal(const AWriter: ICompressWriter;
    const AExpectedShortWrite, AExpectedWriteAfterClose, ALabel: string);
  var
    LSrc: TBytes;
    LByte: Byte;
    LGotShortWrite: Boolean;
    LGotWriteAfterClose: Boolean;
    LGotUnexpected: Boolean;
  begin
    BuildPayload(LSrc);
    LByte := $5A;

    LGotShortWrite := False;
    try
      AWriter.Write(LSrc[0], SizeUInt(Length(LSrc)));
    except
      on E: EIOError do
        LGotShortWrite := Pos(AExpectedShortWrite, E.Message) > 0;
    end;
    Check(LGotShortWrite, ALabel + ' failed payload write reports short write');

    LGotWriteAfterClose := False;
    try
      AWriter.Write(LByte, 1);
    except
      on E: EIOError do
        LGotWriteAfterClose := Pos(AExpectedWriteAfterClose, E.Message) > 0;
    end;
    Check(LGotWriteAfterClose,
      ALabel + ' failed payload write keeps write-after-close error');

    LGotUnexpected := False;
    try
      AWriter.Close;
      AWriter.Flush;
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected,
      ALabel + ' failed payload write leaves terminal close');
  end;

begin
  CheckFailedPayloadWriteLeavesTerminal(DeflateWriter(TShortWriter.Create(1),
    clNone),
    'deflate: short write', 'deflate: write after close', 'deflate writer');
  CheckFailedPayloadWriteLeavesTerminal(GzipWriter(TShortWriter.Create(2),
    clNone),
    'gzip: short write', 'gzip: write after close', 'gzip writer');
end;

procedure TestStreamingWriterRaisedSinkFailureLeavesTerminal;

  procedure BuildPayload(var AData: TBytes);
  const
    PAYLOAD_SIZE = 3 * COMPRESS_BUF_SIZE;
  var
    LI: SizeInt;
    LSeed: UInt32;
  begin
    SetLength(AData, PAYLOAD_SIZE);
    LSeed := $2468ACE1;
    for LI := 0 to High(AData) do
    begin
      {$PUSH}{$Q-}{$R-}
      LSeed := LSeed * UInt32(1103515245) + UInt32(12345);
      {$POP}
      AData[LI] := Byte(LSeed shr 24);
    end;
  end;

  procedure CheckRaisedSinkFailureLeavesTerminal(var AWriter: ICompressWriter;
    const AExpectedWriteAfterClose, ALabel: string);
  var
    LSrc: TBytes;
    LByte: Byte;
    LGotSinkFailure: Boolean;
    LGotWriteAfterClose: Boolean;
    LGotUnexpected: Boolean;
  begin
    BuildPayload(LSrc);
    LByte := $5A;

    LGotSinkFailure := False;
    try
      AWriter.Write(LSrc[0], SizeUInt(Length(LSrc)));
    except
      on E: EIOError do
        LGotSinkFailure := Pos('sink write failed', E.Message) > 0;
    end;
    Check(LGotSinkFailure, ALabel + ' reports raised sink write failure');

    LGotWriteAfterClose := False;
    try
      AWriter.Write(LByte, 1);
    except
      on E: EIOError do
        LGotWriteAfterClose := Pos(AExpectedWriteAfterClose, E.Message) > 0;
    end;
    Check(LGotWriteAfterClose,
      ALabel + ' failed raised sink write keeps write-after-close error');

    LGotUnexpected := False;
    try
      AWriter.Close;
      AWriter.Flush;
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected,
      ALabel + ' failed raised sink write leaves terminal close');

    LGotUnexpected := False;
    try
      AWriter := nil;
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected,
      ALabel + ' failed raised sink write release is non-throwing');
  end;

var
  LDeflateWriter: ICompressWriter;
  LGzipWriter: ICompressWriter;
  LWriter: ICompressWriter;
  LGotHeaderFailure: Boolean;
begin
  LDeflateWriter := DeflateWriter(TRaisingWriter.Create(1), clNone);
  CheckRaisedSinkFailureLeavesTerminal(LDeflateWriter,
    'deflate: write after close', 'deflate writer');
  LGzipWriter := GzipWriter(TRaisingWriter.Create(2), clNone);
  CheckRaisedSinkFailureLeavesTerminal(LGzipWriter,
    'gzip: write after close', 'gzip writer');

  LGotHeaderFailure := False;
  try
    LWriter := GzipWriter(TRaisingWriter.Create(0));
  except
    on E: EIOError do
      LGotHeaderFailure := Pos('sink write failed', E.Message) > 0;
  end;
  Check(LGotHeaderFailure,
    'gzip writer raised sink failure during header propagates source error');
end;

procedure TestStreamingWriterFailedFlushLeavesTerminal;

  procedure CheckFailedFlushLeavesTerminal(const AWriter: ICompressWriter;
    const AExpectedShortWrite, AExpectedWriteAfterClose, ALabel: string);
  var
    LByte: Byte;
    LGotShortWrite: Boolean;
    LGotWriteAfterClose: Boolean;
    LGotUnexpected: Boolean;
  begin
    LByte := $5A;
    AWriter.Write(LByte, 1);

    LGotShortWrite := False;
    try
      AWriter.Flush;
    except
      on E: EIOError do
        LGotShortWrite := Pos(AExpectedShortWrite, E.Message) > 0;
    end;
    Check(LGotShortWrite, ALabel + ' failed flush reports short write');

    LGotWriteAfterClose := False;
    try
      AWriter.Write(LByte, 0);
    except
      on E: EIOError do
        LGotWriteAfterClose := Pos(AExpectedWriteAfterClose, E.Message) > 0;
    end;
    Check(LGotWriteAfterClose,
      ALabel + ' failed flush leaves zero-write after-close error');

    LGotUnexpected := False;
    try
      AWriter.Close;
      AWriter.Flush;
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected, ALabel + ' failed flush leaves terminal close');
  end;

begin
  CheckFailedFlushLeavesTerminal(DeflateWriter(TShortWriter.Create(1)),
    'deflate: short write', 'deflate: write after close', 'deflate writer');
  CheckFailedFlushLeavesTerminal(GzipWriter(TShortWriter.Create(1)),
    'gzip: short write', 'gzip: write after close', 'gzip writer');
end;

procedure TestStreamingReaderFailedReadLeavesTerminal;

  procedure CheckFailedReadLeavesTerminal(const AReader: IDecompressReader;
    const ALabel: string);
  var
    LByte: Byte;
    LReadAfterError: SizeUInt;
    LGotSourceFailure: Boolean;
    LGotUnexpected: Boolean;
  begin
    LGotSourceFailure := False;
    try
      IoReadAll(AReader as IReader);
    except
      on E: EIOError do
        LGotSourceFailure := Pos('source read failed', E.Message) > 0;
    end;
    Check(LGotSourceFailure, ALabel + ' reports source read failure');

    LReadAfterError := 0;
    LGotUnexpected := False;
    try
      LReadAfterError := (AReader as IReader).Read(LByte, 1);
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected, ALabel + ' read after failed read is non-throwing');
    if not LGotUnexpected then
      CheckEqual(Int64(0), Int64(LReadAfterError),
        ALabel + ' read after failed read returns 0');

    LGotUnexpected := False;
    try
      AReader.Close;
      AReader.Close;
    except
      LGotUnexpected := True;
    end;
    Check(not LGotUnexpected, ALabel + ' failed read leaves close idempotent');
  end;

var
  LSrc, LCompressed: TBytes;
  LI: SizeInt;
  LReader: IDecompressReader;
begin
  SetLength(LSrc, 4096);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 97 + 31) mod 251);

  LCompressed := DeflateCompress(LSrc);
  LReader := DeflateReader(TFailingReader.Create(LCompressed, 7, 4));
  CheckFailedReadLeavesTerminal(LReader, 'deflate reader');

  LCompressed := GzipCompress(LSrc);
  LReader := GzipReader(TFailingReader.Create(LCompressed, 7, 4));
  CheckFailedReadLeavesTerminal(LReader, 'gzip reader');
end;

procedure TestStreamingFactoryRejectsNilEndpoints;
var
  LWriter: IWriter;
  LReader: IReader;
  LCompressWriter: ICompressWriter;
  LDecompressReader: IDecompressReader;
  LGot: Boolean;
begin
  LWriter := nil;
  LReader := nil;

  LGot := False;
  try
    LCompressWriter := DeflateWriter(LWriter);
  except
    on E: EArgumentError do
      LGot := Pos('deflate: writer is nil', E.Message) > 0;
  end;
  Check(LGot, 'deflate writer factory rejects nil writer');

  LGot := False;
  try
    LDecompressReader := DeflateReader(LReader);
  except
    on E: EArgumentError do
      LGot := Pos('deflate: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'deflate reader factory rejects nil reader');

  LGot := False;
  try
    LCompressWriter := GzipWriter(LWriter);
  except
    on E: EArgumentError do
      LGot := Pos('gzip: writer is nil', E.Message) > 0;
  end;
  Check(LGot, 'gzip writer factory rejects nil writer');

  LGot := False;
  try
    LDecompressReader := GzipReader(LReader);
  except
    on E: EArgumentError do
      LGot := Pos('gzip: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'gzip reader factory rejects nil reader');
end;

procedure TestStreamingBoundedReaderRejectsNilEndpoints;
var
  LReader: IReader;
  LDecompressReader: IDecompressReader;
  LGot: Boolean;
begin
  LReader := nil;

  LGot := False;
  try
    LDecompressReader := DeflateReaderWithMaxOutputSize(LReader, 1024);
  except
    on E: EArgumentError do
      LGot := Pos('deflate: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'root facade deflate bounded reader rejects nil endpoint');

  LGot := False;
  try
    LDecompressReader := nextpas.core.compress.deflate.
      CreateDeflateReaderWithMaxOutputSize(LReader, 1024);
  except
    on E: EArgumentError do
      LGot := Pos('deflate: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'deflate subunit bounded reader rejects nil endpoint');

  LGot := False;
  try
    LDecompressReader := GzipReaderWithMaxOutputSize(LReader, 1024);
  except
    on E: EArgumentError do
      LGot := Pos('gzip: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'root facade gzip bounded reader rejects nil endpoint');

  LGot := False;
  try
    LDecompressReader := nextpas.core.compress.gzip.
      CreateGzipReaderWithMaxOutputSize(LReader, 1024);
  except
    on E: EArgumentError do
      LGot := Pos('gzip: reader is nil', E.Message) > 0;
  end;
  Check(LGot, 'gzip subunit bounded reader rejects nil endpoint');
end;

procedure TestDeflateEmptyStream;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LOut: TBytes;
begin
  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Close; // close without writing

  LBuf.Seek(0, soBeginning);
  LReader := DeflateReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;

  CheckEqual(Int64(0), Int64(Length(LOut)), 'deflate empty stream');
end;

procedure TestGzipEmptyStream;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LOut: TBytes;
  LByte: Byte;
begin
  LBuf := CreateBytesStream;
  LWriter := GzipWriter(LBuf as IWriter);
  LWriter.Close;
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  LReader := GzipReader(LBuf as IReader);
  LOut := IoReadAll(LReader as IReader);
  CheckEqual(Int64(0), Int64(Length(LOut)), 'gzip empty stream length');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip empty stream read after EOF returns 0');
  LReader.Close;
  LReader.Close;
end;

procedure TestDeflateEmptyOneShotStreamContract;
var
  LCompressed: TBytes;
  LOut: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
begin
  LCompressed := DeflateCompress(nil);
  Check(Length(LCompressed) > 0,
    'deflate empty input produces a zlib-wrapped stream');

  LOut := DeflateDecompress(LCompressed);
  CheckEqual(Int64(0), Int64(Length(LOut)),
    'deflate empty stream decompresses to empty bytes');

  LReader := DeflateReader(CreateBytesStreamFrom(LCompressed) as IReader);
  LOut := IoReadAll(LReader as IReader);
  LReader.Close;
  CheckEqual(Int64(0), Int64(Length(LOut)),
    'deflate one-shot empty stream is readable by streaming reader');

  LGot := False;
  try
    DeflateDecompress(nil);
  except
    on E: EIOError do
      LGot := Pos('deflate:', E.Message) > 0;
  end;
  Check(LGot, 'deflate empty encoded input raises a deflate error');
end;

procedure TestDeflateInvalidZlibHeaderErrorModel;
  procedure CheckInvalidHeader(const AFirst, ASecond: Byte; const ALabel: string);
  var
    LBad: TBytes;
    LReader: IDecompressReader;
    LGotOneShot: Boolean;
    LGotZeroCap: Boolean;
    LGotStream: Boolean;
  begin
    LBad := TBytes.Create(AFirst, ASecond, $00, $00);

    LGotOneShot := False;
    try
      DeflateDecompress(LBad);
    except
      on E: EIOError do
        LGotOneShot := Pos('deflate: invalid zlib header', E.Message) > 0;
    end;
    Check(LGotOneShot,
      'deflate one-shot invalid zlib header has stable error: ' + ALabel);

    LGotZeroCap := False;
    try
      DeflateDecompressWithMaxOutputSize(LBad, 0);
    except
      on E: EIOError do
        LGotZeroCap := Pos('deflate: invalid zlib header', E.Message) > 0;
    end;
    Check(LGotZeroCap,
      'deflate zero-cap invalid zlib header has stable error: ' + ALabel);

    LGotStream := False;
    try
      LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGotStream := Pos('deflate: invalid zlib header', E.Message) > 0;
    end;
    Check(LGotStream,
      'deflate stream invalid zlib header has stable error: ' + ALabel);
  end;
begin
  CheckInvalidHeader($79, $18, 'bad compression method');
  CheckInvalidHeader($88, $1C, 'bad window size');
  CheckInvalidHeader($78, $9D, 'bad header check bits');
end;

procedure TestDeflateShortZlibHeaderErrorModel;
var
  LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotZeroCap: Boolean;
  LGotStream: Boolean;
begin
  LBad := TBytes.Create($78);

  LGotOneShot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGotOneShot, 'deflate one-shot short zlib header has stable error');

  LGotZeroCap := False;
  try
    DeflateDecompressWithMaxOutputSize(LBad, 0);
  except
    on E: EIOError do
      LGotZeroCap := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGotZeroCap, 'deflate zero-cap short zlib header has stable error');

  LGotStream := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGotStream, 'deflate stream short zlib header has stable error');
end;

procedure TestDeflateSplitZlibHeaderErrorModel;

  procedure CheckSplitHeader(const AData: TBytes; const AExpectedError,
    ALabel: string);
  var
    LReader: IDecompressReader;
    LGot: Boolean;
  begin
    LGot := False;
    try
      LReader := DeflateReader(TOneByteReader.Create(AData));
      IoReadAll(LReader as IReader);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, 'deflate split zlib header has stable error: ' + ALabel);
  end;

begin
  CheckSplitHeader(TBytes.Create($79, $18, $00, $00),
    'deflate: invalid zlib header', 'bad compression method');
  CheckSplitHeader(TBytes.Create($88, $1C, $00, $00),
    'deflate: invalid zlib header', 'bad window size');
  CheckSplitHeader(TBytes.Create($78, $9D, $00, $00),
    'deflate: invalid zlib header', 'bad header check bits');
  CheckSplitHeader(TBytes.Create($78, $20),
    'deflate: preset dictionary not supported', 'preset dictionary');
  CheckSplitHeader(TBytes.Create($78),
    'deflate: truncated stream', 'single byte header');
end;

procedure TestDeflatePresetDictionaryHeaderErrorModel;
var
  LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotZeroCap: Boolean;
  LGotStream: Boolean;
begin
  LBad := TBytes.Create($78, $20);

  LGotOneShot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('deflate: preset dictionary not supported',
        E.Message) > 0;
  end;
  Check(LGotOneShot,
    'deflate one-shot preset dictionary header has stable error');

  LGotZeroCap := False;
  try
    DeflateDecompressWithMaxOutputSize(LBad, 0);
  except
    on E: EIOError do
      LGotZeroCap := Pos('deflate: preset dictionary not supported',
        E.Message) > 0;
  end;
  Check(LGotZeroCap,
    'deflate zero-cap preset dictionary header has stable error');

  LGotStream := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('deflate: preset dictionary not supported',
        E.Message) > 0;
  end;
  Check(LGotStream,
    'deflate stream preset dictionary header has stable error');
end;

procedure TestDeflateCorruptPayloadErrorModel;
var
  LSrc, LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotBounded: Boolean;
  LGotStream: Boolean;
begin
  LSrc := TBytes.Create(1, 2, 3, 5, 8, 13, 21, 34, 55, 89);
  LBad := DeflateCompress(LSrc);
  LBad[Length(LBad) div 2] := LBad[Length(LBad) div 2] xor $FF;

  LGotOneShot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotOneShot, 'deflate one-shot corrupt payload has stable error');

  LGotBounded := False;
  try
    DeflateDecompressWithMaxOutputSize(LBad, Length(LSrc) * 2);
  except
    on E: EIOError do
      LGotBounded := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotBounded, 'deflate bounded corrupt payload has stable error');

  LGotStream := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotStream, 'deflate stream corrupt payload has stable error');
end;

procedure TestDeflateChecksumOnlyCorruptionErrorModel;
var
  LSrc, LBad: TBytes;
  LReader: IDecompressReader;
  LGotOneShot: Boolean;
  LGotBounded: Boolean;
  LGotStream: Boolean;
begin
  LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);
  LBad := DeflateCompress(LSrc);
  LBad[Length(LBad) - 1] := LBad[Length(LBad) - 1] xor $FF;

  LGotOneShot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGotOneShot := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotOneShot,
    'deflate one-shot checksum-only corruption has stable error');

  LGotBounded := False;
  try
    DeflateDecompressWithMaxOutputSize(LBad, Length(LSrc) * 2);
  except
    on E: EIOError do
      LGotBounded := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotBounded,
    'deflate bounded checksum-only corruption has stable error');

  LGotStream := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGotStream := Pos('deflate: corrupt stream', E.Message) > 0;
  end;
  Check(LGotStream,
    'deflate stream checksum-only corruption has stable error');
end;

procedure TestDeflateTruncatedStreamRaises;
var
  LBuf: IStream;
  LWriter: ICompressWriter;
  LReader: IDecompressReader;
  LSrc, LRaw: TBytes;
  LGot: Boolean;
  LI: Integer;
begin
  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 9 + 1) mod 253);

  LBuf := CreateBytesStream;
  LWriter := DeflateWriter(LBuf as IWriter);
  LWriter.Write(LSrc[0], Length(LSrc));
  LWriter.Close;

  LBuf.Seek(0, soBeginning);
  SetLength(LRaw, LBuf.Size);
  LBuf.Read(LRaw[0], Length(LRaw));
  SetLength(LRaw, Length(LRaw) - 1);

  LGot := False;
  try
    LBuf := CreateBytesStreamFrom(LRaw);
    LReader := DeflateReader(LBuf as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'deflate truncated stream raises');
end;

procedure TestDeflateRejectsTrailingBytes;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(2, 7, 1, 8, 2, 8, 1, 8);
  LC := DeflateCompress(LSrc);

  SetLength(LBad, Length(LC) + 3);
  Move(LC[0], LBad[0], Length(LC));
  LBad[Length(LC)] := $DE;
  LBad[Length(LC) + 1] := $AD;
  LBad[Length(LC) + 2] := $7A;

  LGot := False;
  try
    DeflateDecompress(LBad);
  except
    LGot := True;
  end;
  Check(LGot, 'deflate one-shot rejects trailing bytes');

  LGot := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'deflate stream rejects trailing bytes');

  LGot := False;
  try
    LReader := DeflateReader(TOneByteReader.Create(LBad));
    IoReadAll(LReader as IReader);
    LReader.Close;
  except
    LGot := True;
  end;
  Check(LGot, 'deflate stream rejects trailing bytes after chunk boundary');
end;

procedure TestDeflateTrailingBytesLeavesReaderTerminal;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LByte: Byte;
  LReadAfterError: SizeUInt;
  LGot: Boolean;
begin
  LSrc := TBytes.Create(3, 1, 4, 1, 5, 9, 2, 6);
  LC := DeflateCompress(LSrc);
  SetLength(LBad, Length(LC) + 1);
  Move(LC[0], LBad[0], Length(LC));
  LBad[Length(LC)] := $99;

  LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
  LGot := False;
  try
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('deflate: trailing bytes after stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate stream trailing bytes raises stable error');

  LReadAfterError := (LReader as IReader).Read(LByte, 1);
  CheckEqual(Int64(0), Int64(LReadAfterError),
    'deflate stream trailing-bytes error leaves reader terminal');
  LReader.Close;
end;

procedure TestOneShotTruncatedPayloadContracts;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
  LI: Int32;
  LTrailerOfs: SizeUInt;
begin
  LBad := TBytes.Create($78, $9C);

  LGot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGot := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate one-shot header-only payload has stable error');

  LGot := False;
  try
    DeflateDecompressWithMaxOutputSize(LBad, 0);
  except
    on E: EIOError do
      LGot := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate zero-cap header-only payload has stable error');

  LGot := False;
  try
    LReader := DeflateReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate stream header-only payload has stable error');

  LBad := TBytes.Create($1F, $8B, $08, $00, 0, 0, 0, 0, 0, $FF, $03);

  LGot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'gzip one-shot raw deflate payload has stable error');

  LGot := False;
  try
    LReader := GzipReader(CreateBytesStreamFrom(LBad) as IReader);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'gzip stream raw deflate payload has stable error');

  SetLength(LSrc, 512);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 37 + 11) and $FF);

  LC := DeflateCompress(LSrc);
  LBad := Copy(LC, 0, Length(LC));
  SetLength(LBad, Length(LBad) - 1);
  LGot := False;
  try
    DeflateDecompress(LBad);
  except
    on E: EIOError do
      LGot := Pos('deflate: truncated stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate one-shot truncated valid stream has stable error');

  LC := GzipCompress(LSrc);
  LTrailerOfs := SizeUInt(Length(LC) - 8);
  Check(LTrailerOfs > 10, 'gzip test fixture has compressed payload');
  SetLength(LBad, Length(LC) - 1);
  Move(LC[0], LBad[0], LTrailerOfs - 1);
  Move(LC[LTrailerOfs], LBad[LTrailerOfs - 1], 8);

  LGot := False;
  try
    GzipDecompress(LBad);
  except
    on E: EIOError do
      LGot := Pos('gzip: truncated trailer', E.Message) > 0;
  end;
  Check(LGot,
    'gzip one-shot truncated payload with preserved trailer has stable error');
end;

procedure TestDeflateOutputLimitErrorModel;
var
  LSrc, LC, LD, LEmpty: TBytes;
  procedure CheckDeflateLimitError(const AMaxOutputSize: SizeUInt;
    const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      DeflateDecompressWithMaxOutputSize(LC, AMaxOutputSize);
    except
      on E: EIOError do
        LGot := Pos('deflate: decompressed size exceeds limit',
          E.Message) > 0;
    end;
    Check(LGot, ALabel);
  end;
begin
  LEmpty := TBytes.Create($78, $9C, $03, $00, $00, $00, $00, $01);
  LD := DeflateDecompressWithMaxOutputSize(LEmpty, 0);
  CheckEqual(Int64(0), Int64(Length(LD)), 'deflate empty output fits zero cap');

  SetLength(LSrc, 512);
  FillChar(LSrc[0], Length(LSrc), $A5);
  LC := DeflateCompress(LSrc);

  LD := DeflateDecompressWithMaxOutputSize(LC, Length(LSrc));
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'deflate exact output cap succeeds');

  CheckDeflateLimitError(Length(LSrc) - 1,
    'deflate one-shot output limit reports stable error below exact size');
  CheckDeflateLimitError(0,
    'deflate non-empty output reports stable error for zero cap');
end;

procedure TestGzipOutputLimitErrorModel;
var
  LSrc, LC, LD: TBytes;
  procedure CheckGzipLimitError(const AData: TBytes;
    const AMaxOutputSize: SizeUInt; const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(AData,
        AMaxOutputSize);
    except
      on E: EIOError do
        LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
    end;
    Check(LGot, ALabel);
  end;
begin
  LD := nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(
    GzipCompress(nil), 0);
  CheckEqual(Int64(0), Int64(Length(LD)), 'gzip empty output fits zero cap');

  SetLength(LSrc, 512);
  FillChar(LSrc[0], Length(LSrc), $5A);
  LC := GzipCompress(LSrc);

  LD := nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(LC,
    Length(LSrc));
  CheckEqual(Int64(Length(LSrc)), Int64(Length(LD)), 'gzip exact output cap succeeds');

  CheckGzipLimitError(LC, Length(LSrc) - 1,
    'gzip one-shot output limit reports stable error below exact size');
  CheckGzipLimitError(LC, 0,
    'gzip non-empty output reports stable error for zero cap');
end;

procedure TestGzipTrailerOutputLimitErrorModel;
var
  LC: TBytes;
  LGot: Boolean;
begin
  LC := GzipCompress(nil);
  LC[Length(LC) - 4] := $00;
  LC[Length(LC) - 3] := $02;
  LC[Length(LC) - 2] := $00;
  LC[Length(LC) - 1] := $00;

  LGot := False;
  try
    nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(LC, 64);
  except
    on E: EIOError do
      LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGot,
    'gzip bounded decode reports stable error for trailer size above cap');
end;

procedure TestGzipStreamingTrailerSizeAboveCapReportsOutputLimit;
var
  LC: TBytes;
  LReader: IDecompressReader;
  LByte: Byte;
  LRead: SizeUInt;
  LGot: Boolean;
begin
  LC := GzipCompress(nil);
  LC[Length(LC) - 4] := 65;
  LC[Length(LC) - 3] := 0;
  LC[Length(LC) - 2] := 0;
  LC[Length(LC) - 1] := 0;

  LReader := GzipReaderWithMaxOutputSize(CreateBytesStreamFrom(LC) as IReader,
    64);
  LGot := False;
  try
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGot,
    'gzip streaming trailer size above cap reports output limit');

  LByte := $A5;
  LRead := (LReader as IReader).Read(LByte, 1);
  CheckEqual(Int64(0), Int64(LRead),
    'gzip streaming trailer cap error leaves reader terminal');
  CheckEqual(Int64($A5), Int64(LByte),
    'gzip streaming trailer cap error preserves caller byte');
  LReader.Close;
  LReader.Close;
end;

procedure TestStreamingReaderOutputLimitErrorModel;
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;
  LGot: Boolean;
begin
  SetLength(LSrc, 512);
  FillChar(LSrc[0], Length(LSrc), $3C);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  LGot := False;
  try
    LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
      CreateBytesStreamFrom(LC) as IReader, 64);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('deflate: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGot, 'deflate streaming reader enforces output cap');

  LC := nextpas.core.compress.GzipCompress(LSrc);
  LGot := False;
  try
    LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
      CreateBytesStreamFrom(LC) as IReader, 64);
    IoReadAll(LReader as IReader);
  except
    on E: EIOError do
      LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGot, 'gzip streaming reader enforces output cap');
end;

procedure TestStreamingReaderOutputLimitIsCumulativeAcrossReads;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LBuf: array[0..31] of Byte;
  LByte: Byte;
  LRead: SizeUInt;
  LGot: Boolean;
begin
  SetLength(LSrc, 80);
  FillChar(LSrc[0], Length(LSrc), $4D);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, 64);
  LRead := (LReader as IReader).Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(32), Int64(LRead),
    'deflate bounded reader first chunk remains under cap');
  LRead := (LReader as IReader).Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(32), Int64(LRead),
    'deflate bounded reader reaches cap across reads');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('deflate: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGot, 'deflate bounded reader rejects cumulative output above cap');
  CheckEqual(Int64($EE), Int64(LByte),
    'deflate bounded reader does not write bytes beyond cap');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate bounded reader is terminal after cumulative cap failure');
  LReader.Close;

  LC := nextpas.core.compress.GzipCompress(LSrc);
  LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, 64);
  LRead := (LReader as IReader).Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(32), Int64(LRead),
    'gzip bounded reader first chunk remains under cap');
  LRead := (LReader as IReader).Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(32), Int64(LRead),
    'gzip bounded reader reaches cap across reads');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGot, 'gzip bounded reader rejects cumulative output above cap');
  CheckEqual(Int64($EE), Int64(LByte),
    'gzip bounded reader does not write bytes beyond cap');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip bounded reader is terminal after cumulative cap failure');
  LReader.Close;

  SetLength(LSrc, 65);
  FillChar(LSrc[0], Length(LSrc), $31);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, Length(LSrc));
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate exact cap first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate exact cap second chunk');
  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate exact cap final byte');
  LByte := $EE;
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate exact cap validates EOF');
  CheckEqual(Int64($EE), Int64(LByte),
    'deflate exact cap EOF does not write caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate exact cap read-after-EOF remains terminal');
  LReader.Close;
  LReader.Close;

  LC := nextpas.core.compress.GzipCompress(LSrc);
  LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, Length(LSrc));
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip exact cap first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip exact cap second chunk');
  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip exact cap final byte');
  LByte := $EE;
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip exact cap validates EOF and trailer');
  CheckEqual(Int64($EE), Int64(LByte),
    'gzip exact cap EOF does not write caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip exact cap read-after-EOF remains terminal');
  LReader.Close;
  LReader.Close;

  SetLength(LSrc, 65);
  FillChar(LSrc[0], Length(LSrc), $73);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  LBad := Copy(LC, 0, Length(LC));
  SetLength(LBad, Length(LBad) + 1);
  LBad[High(LBad)] := $7E;
  LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LBad) as IReader, 64);
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate trailing cap priority first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate trailing cap priority reaches cap');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('deflate: decompressed size exceeds limit',
        E.Message) > 0;
  end;
  Check(LGot, 'deflate bounded reader reports limit before trailing bytes');
  CheckEqual(Int64($EE), Int64(LByte),
    'deflate trailing cap priority does not write beyond cap');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate trailing cap priority leaves reader terminal');
  LReader.Close;

  LC := nextpas.core.compress.GzipCompress(LSrc);
  LBad := Copy(LC, 0, Length(LC));
  SetLength(LBad, Length(LBad) + 1);
  LBad[High(LBad)] := $7E;
  LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LBad) as IReader, 64);
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip trailing cap priority first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip trailing cap priority reaches cap');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
  end;
  Check(LGot, 'gzip bounded reader reports limit before trailing bytes');
  CheckEqual(Int64($EE), Int64(LByte),
    'gzip trailing cap priority does not write beyond cap');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip trailing cap priority leaves reader terminal');
  LReader.Close;
end;

procedure TestBoundedReaderPartialRemainingCapPreservesCallerTail;

  procedure CheckCodec(const AReader: IDecompressReader;
    const AExpectedError, ALabel, APreservesTailLabel: string);
  var
    LFirst: array[0..31] of Byte;
    LTail: array[0..63] of Byte;
    LByte: Byte;
    LRead: SizeUInt;
    LGot: Boolean;
    LTailPreserved: Boolean;
    LI: SizeInt;
  begin
    FillChar(LFirst, SizeOf(LFirst), $CC);
    LRead := (AReader as IReader).Read(LFirst[0], SizeUInt(SizeOf(LFirst)));
    CheckEqual(Int64(32), Int64(LRead), ALabel + ' first chunk');
    for LI := 0 to High(LFirst) do
      CheckEqual(Int64($41), Int64(LFirst[LI]),
        ALabel + ' first chunk byte ' + IntToStr(LI));

    FillChar(LTail, SizeOf(LTail), $CC);
    LRead := (AReader as IReader).Read(LTail[0], SizeUInt(SizeOf(LTail)));
    CheckEqual(Int64(1), Int64(LRead), ALabel + ' partial remaining cap read');
    CheckEqual(Int64($41), Int64(LTail[0]),
      ALabel + ' writes only returned byte');
    LTailPreserved := True;
    for LI := 1 to High(LTail) do
      if LTail[LI] <> $CC then
      begin
        LTailPreserved := False;
        Break;
      end;
    Check(LTailPreserved, APreservesTailLabel);

    LByte := $EE;
    LGot := False;
    try
      (AReader as IReader).Read(LByte, 1);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' reports output limit after cap');
    CheckEqual(Int64($EE), Int64(LByte),
      ALabel + ' output-limit read preserves caller byte');
    CheckEqual(Int64(0), Int64((AReader as IReader).Read(LByte, 1)),
      ALabel + ' leaves reader terminal');
    AReader.Close;
    AReader.Close;
  end;

var
  LSrc, LC: TBytes;
begin
  SetLength(LSrc, 65);
  FillChar(LSrc[0], Length(LSrc), $41);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  CheckCodec(nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, 33),
    'deflate: decompressed size exceeds limit',
    'deflate bounded partial cap',
    'deflate bounded partial cap preserves caller tail');

  LC := nextpas.core.compress.GzipCompress(LSrc);
  CheckCodec(nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, 33),
    'gzip: decompressed size exceeds limit',
    'gzip bounded partial cap',
    'gzip bounded partial cap preserves caller tail');
end;

procedure TestBoundedExactCapRejectsTrailingBytes;
var
  LSrc, LC, LBad: TBytes;
  LReader: IDecompressReader;
  LBuf: array[0..31] of Byte;
  LByte: Byte;
  LGot: Boolean;
begin
  SetLength(LSrc, 65);
  FillChar(LSrc[0], Length(LSrc), $61);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  SetLength(LBad, Length(LC) + 1);
  Move(LC[0], LBad[0], Length(LC));
  LBad[High(LBad)] := $7E;

  LGot := False;
  try
    nextpas.core.compress.DeflateDecompressWithMaxOutputSize(LBad, Length(LSrc));
  except
    on E: EIOError do
      LGot := Pos('deflate: trailing bytes after stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate bounded exact cap still rejects trailing bytes');

  LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LBad) as IReader, Length(LSrc));
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate bounded trailing exact cap first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'deflate bounded trailing exact cap second chunk');
  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate bounded trailing exact cap final byte');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('deflate: trailing bytes after stream', E.Message) > 0;
  end;
  Check(LGot, 'deflate bounded reader exact cap reports trailing bytes');
  CheckEqual(Int64($EE), Int64(LByte),
    'deflate bounded reader exact cap trailing error preserves caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'deflate bounded reader exact cap trailing error leaves terminal');
  LReader.Close;

  LC := nextpas.core.compress.GzipCompress(LSrc);
  SetLength(LBad, Length(LC) + 1);
  Move(LC[0], LBad[0], Length(LC));
  LBad[High(LBad)] := $7E;

  LGot := False;
  try
    nextpas.core.compress.GzipDecompressWithMaxOutputSize(LBad, Length(LSrc));
  except
    on E: EIOError do
      LGot := Pos('gzip: trailing bytes after trailer', E.Message) > 0;
  end;
  Check(LGot, 'gzip bounded exact cap still rejects trailing bytes');

  LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LBad) as IReader, Length(LSrc));
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip bounded trailing exact cap first chunk');
  CheckEqual(Int64(32), Int64((LReader as IReader).Read(LBuf[0],
    SizeUInt(Length(LBuf)))), 'gzip bounded trailing exact cap second chunk');
  CheckEqual(Int64(1), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip bounded trailing exact cap final byte');
  LGot := False;
  LByte := $EE;
  try
    (LReader as IReader).Read(LByte, 1);
  except
    on E: EIOError do
      LGot := Pos('gzip: trailing bytes after trailer', E.Message) > 0;
  end;
  Check(LGot, 'gzip bounded reader exact cap reports trailing bytes');
  CheckEqual(Int64($EE), Int64(LByte),
    'gzip bounded reader exact cap trailing error preserves caller byte');
  CheckEqual(Int64(0), Int64((LReader as IReader).Read(LByte, 1)),
    'gzip bounded reader exact cap trailing error leaves terminal');
  LReader.Close;
end;

procedure TestBoundedHighExpansionLimitPath;
const
  HighExpansionSize = 1024 * 1024;
  OutputCap = 64 * 1024;
var
  LSrc, LC: TBytes;
  LReader: IDecompressReader;

  procedure CheckStreamingLimitError(const AReader: IDecompressReader;
    const AExpectedError, ALabel: string);
  var
    LByte: Byte;
    LRead: SizeUInt;
    LGot: Boolean;
  begin
    LGot := False;
    try
      IoReadAll(AReader as IReader);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel);

    LByte := $A5;
    LRead := (AReader as IReader).Read(LByte, 1);
    CheckEqual(Int64(0), Int64(LRead), ALabel + ' leaves reader terminal');
    CheckEqual(Int64($A5), Int64(LByte),
      ALabel + ' preserves caller byte after error');
    AReader.Close;
    AReader.Close;
  end;

  procedure CheckDeflateOneShotLimitError(const ACompressed: TBytes;
    const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      nextpas.core.compress.DeflateDecompressWithMaxOutputSize(ACompressed,
        OutputCap);
    except
      on E: EIOError do
        LGot := Pos('deflate: decompressed size exceeds limit',
          E.Message) > 0;
    end;
    Check(LGot, ALabel);
  end;

  procedure CheckGzipOneShotLimitError(const ACompressed: TBytes;
    const ALabel: string);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      nextpas.core.compress.GzipDecompressWithMaxOutputSize(ACompressed,
        OutputCap);
    except
      on E: EIOError do
        LGot := Pos('gzip: decompressed size exceeds limit', E.Message) > 0;
    end;
    Check(LGot, ALabel);
  end;

begin
  SetLength(LSrc, HighExpansionSize);
  FillChar(LSrc[0], Length(LSrc), $00);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  Check(SizeUInt(Length(LC)) < OutputCap,
    'deflate high-expansion fixture stays below output cap');
  CheckDeflateOneShotLimitError(LC,
    'deflate high-expansion one-shot rejects above cap');
  LReader := nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, OutputCap);
  CheckStreamingLimitError(LReader, 'deflate: decompressed size exceeds limit',
    'deflate high-expansion streaming rejects above cap');

  LC := nextpas.core.compress.GzipCompress(LSrc);
  Check(SizeUInt(Length(LC)) < OutputCap,
    'gzip high-expansion fixture stays below output cap');
  CheckGzipOneShotLimitError(LC,
    'gzip high-expansion one-shot rejects above cap');
  LReader := nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, OutputCap);
  CheckStreamingLimitError(LReader, 'gzip: decompressed size exceeds limit',
    'gzip high-expansion streaming rejects above cap');
end;

procedure TestBoundedHighExpansionPartialRemainingCapPreservesCallerTail;
const
  HighExpansionSize = 1024 * 1024;
  OutputCap = 64 * 1024;

  procedure CheckCodec(const AReader: IDecompressReader;
    const AExpectedError, ALabel, ASecondReadLabel,
    APreservesTailLabel: string);
  var
    LScratch: TBytes;
    LTail: array[0..63] of Byte;
    LByte: Byte;
    LRead: SizeUInt;
    LGot: Boolean;
    LTailPreserved: Boolean;
    LI: SizeInt;
  begin
    SetLength(LScratch, OutputCap);
    FillChar(LScratch[0], Length(LScratch), $CC);
    LRead := (AReader as IReader).Read(LScratch[0],
      SizeUInt(Length(LScratch)));
    CheckEqual(Int64(OutputCap), Int64(LRead), ALabel + ' first read reaches cap');

    FillChar(LTail, SizeOf(LTail), $CC);
    LRead := (AReader as IReader).Read(LTail[0], SizeUInt(SizeOf(LTail)));
    CheckEqual(Int64(1), Int64(LRead), ASecondReadLabel);
    CheckEqual(Int64(0), Int64(LTail[0]),
      ALabel + ' writes only returned byte');
    LTailPreserved := True;
    for LI := 1 to High(LTail) do
      if LTail[LI] <> $CC then
      begin
        LTailPreserved := False;
        Break;
      end;
    Check(LTailPreserved, APreservesTailLabel);

    LGot := False;
    LByte := $EE;
    try
      (AReader as IReader).Read(LByte, 1);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' reports output limit after partial cap');
    CheckEqual(Int64($EE), Int64(LByte),
      ALabel + ' output-limit read preserves caller byte');
    CheckEqual(Int64(0), Int64((AReader as IReader).Read(LByte, 1)),
      ALabel + ' leaves reader terminal');
    AReader.Close;
    AReader.Close;
  end;

var
  LSrc, LC: TBytes;
begin
  SetLength(LSrc, HighExpansionSize);
  FillChar(LSrc[0], Length(LSrc), $00);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  Check(SizeUInt(Length(LC)) < OutputCap,
    'deflate high-expansion partial-cap fixture stays below output cap');
  CheckCodec(nextpas.core.compress.DeflateReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, OutputCap + 1),
    'deflate: decompressed size exceeds limit',
    'deflate high-expansion partial cap',
    'deflate high-expansion partial cap second read',
    'deflate high-expansion partial cap preserves caller tail');

  LC := nextpas.core.compress.GzipCompress(LSrc);
  Check(SizeUInt(Length(LC)) < OutputCap,
    'gzip high-expansion partial-cap fixture stays below output cap');
  CheckCodec(nextpas.core.compress.GzipReaderWithMaxOutputSize(
    CreateBytesStreamFrom(LC) as IReader, OutputCap + 1),
    'gzip: decompressed size exceeds limit',
    'gzip high-expansion partial cap',
    'gzip high-expansion partial cap second read',
    'gzip high-expansion partial cap preserves caller tail');
end;

procedure TestBoundedHighExpansionFailureLoopReleasesState;
const
  HighExpansionSize = 1024 * 1024;
  OutputCap = 64 * 1024;
  LoopCount = 32;
var
  LSrc, LDeflate, LGzip: TBytes;
  LI: Integer;

  procedure CheckOneShotLimitError(const ACompressed: TBytes;
    const AExpectedError, ALabel: string;
    const AUseGzip: Boolean);
  var
    LGot: Boolean;
  begin
    LGot := False;
    try
      if AUseGzip then
        nextpas.core.compress.GzipDecompressWithMaxOutputSize(ACompressed,
          OutputCap)
      else
        nextpas.core.compress.DeflateDecompressWithMaxOutputSize(ACompressed,
          OutputCap);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' iteration ' + IntToStr(LI));
  end;

  procedure CheckStreamingLimitError(const AReader: IDecompressReader;
    const AExpectedError, ALabel: string);
  var
    LByte: Byte;
    LRead: SizeUInt;
    LGot: Boolean;
  begin
    LGot := False;
    try
      IoReadAll(AReader as IReader);
    except
      on E: EIOError do
        LGot := Pos(AExpectedError, E.Message) > 0;
    end;
    Check(LGot, ALabel + ' iteration ' + IntToStr(LI));

    LByte := $C3;
    LRead := (AReader as IReader).Read(LByte, 1);
    CheckEqual(Int64(0), Int64(LRead),
      ALabel + ' leaves reader terminal iteration ' + IntToStr(LI));
    CheckEqual(Int64($C3), Int64(LByte),
      ALabel + ' preserves caller byte iteration ' + IntToStr(LI));
    AReader.Close;
    AReader.Close;
  end;

begin
  SetLength(LSrc, HighExpansionSize);
  FillChar(LSrc[0], Length(LSrc), $00);
  LDeflate := nextpas.core.compress.DeflateCompress(LSrc);
  LGzip := nextpas.core.compress.GzipCompress(LSrc);

  Check(SizeUInt(Length(LDeflate)) < OutputCap,
    'deflate high-expansion failure-loop fixture stays below output cap');
  Check(SizeUInt(Length(LGzip)) < OutputCap,
    'gzip high-expansion failure-loop fixture stays below output cap');

  for LI := 1 to LoopCount do
  begin
    CheckOneShotLimitError(LDeflate,
      'deflate: decompressed size exceeds limit',
      'deflate high-expansion one-shot cap failure loop', False);
    CheckOneShotLimitError(LGzip, 'gzip: decompressed size exceeds limit',
      'gzip high-expansion one-shot cap failure loop', True);

    CheckStreamingLimitError(
      nextpas.core.compress.DeflateReaderWithMaxOutputSize(
        CreateBytesStreamFrom(LDeflate) as IReader, OutputCap),
      'deflate: decompressed size exceeds limit',
      'deflate high-expansion streaming cap failure loop');
    CheckStreamingLimitError(
      nextpas.core.compress.GzipReaderWithMaxOutputSize(
        CreateBytesStreamFrom(LGzip) as IReader, OutputCap),
      'gzip: decompressed size exceeds limit',
      'gzip high-expansion streaming cap failure loop');
  end;
end;

procedure TestRootFacadeBoundedDecompressHelpers;
var
  LSrc, LC, LD: TBytes;
  LGot: Boolean;
  LI: Int32;
begin
  SetLength(LSrc, 257);
  for LI := 0 to High(LSrc) do
    LSrc[LI] := Byte((LI * 17 + 11) mod 251);

  LC := nextpas.core.compress.DeflateCompress(LSrc);
  LD := nextpas.core.compress.DeflateDecompressWithMaxOutputSize(LC,
    Length(LSrc));
  CheckBytesEqual(LSrc, LD, 'root facade deflate bounded exact cap');
  LGot := False;
  try
    nextpas.core.compress.DeflateDecompressWithMaxOutputSize(LC,
      Length(LSrc) - 1);
  except
    LGot := True;
  end;
  Check(LGot, 'root facade deflate bounded cap rejects undersized cap');

  LC := nextpas.core.compress.GzipCompress(LSrc);
  LD := nextpas.core.compress.GzipDecompressWithMaxOutputSize(LC,
    Length(LSrc));
  CheckBytesEqual(LSrc, LD, 'root facade gzip bounded exact cap');
  LGot := False;
  try
    nextpas.core.compress.GzipDecompressWithMaxOutputSize(LC,
      Length(LSrc) - 1);
  except
    LGot := True;
  end;
  Check(LGot, 'root facade gzip bounded cap rejects undersized cap');

  LC := nextpas.core.compress.Lz4Compress(LSrc);
  LD := nextpas.core.compress.Lz4DecompressWithMaxOutputSize(LC,
    Length(LSrc), Length(LSrc));
  CheckBytesEqual(LSrc, LD, 'root facade lz4 bounded exact cap');
  LGot := False;
  try
    nextpas.core.compress.Lz4DecompressWithMaxOutputSize(LC,
      Length(LSrc), Length(LSrc) - 1);
  except
    LGot := True;
  end;
  Check(LGot, 'root facade lz4 bounded cap rejects undersized cap');
end;

{ === D. Stress/Lifecycle Tests === }

procedure TestCompressDecompressCycle1000;
var
  LSrc, LC, LD: TBytes;
  LI: Int32;
begin
  SetLength(LSrc, 100);
  for LI := 0 to 99 do LSrc[LI] := Byte(LI);
  for LI := 1 to 1000 do
  begin
    LC := DeflateCompress(LSrc);
    LD := DeflateDecompress(LC);
    if Length(LD) <> 100 then
    begin
      Check(False, 'cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '1000 deflate cycles ok');
end;

procedure TestLz4Cycle1000;
var
  LSrc, LC, LD: TBytes;
  LI: Int32;
begin
  SetLength(LSrc, 64);
  for LI := 0 to 63 do LSrc[LI] := Byte(LI * 3);
  for LI := 1 to 1000 do
  begin
    LC := Lz4Compress(LSrc);
    LD := Lz4Decompress(LC, 64);
    if Length(LD) <> 64 then
    begin
      Check(False, 'lz4 cycle ' + IntToStr(LI) + ' failed');
      Exit;
    end;
  end;
  Check(True, '1000 lz4 cycles ok');
end;

{ === E. Interop Verification === }

procedure TestGzipNilRoundTrip;
var LC, LD: TBytes;
begin
  LC := GzipCompress(nil);
  Check(Length(LC) = 20, 'nil gzip = 20 bytes');
  LD := GzipDecompress(LC);
  CheckEqual(Int64(0), Int64(Length(LD)), 'nil gzip decompresses to empty');
end;

procedure TestDeflateAllLevels;
var
  LSrc, LC, LD: TBytes;
  LLevel: TCompressionLevel;
  LI: Int32;
begin
  SetLength(LSrc, 512);
  for LI := 0 to 511 do LSrc[LI] := Byte(LI mod 100);
  for LLevel := clNone to clBest do
  begin
    LC := DeflateCompress(LSrc, LLevel);
    LD := DeflateDecompress(LC);
    CheckEqual(Int64(512), Int64(Length(LD)), 'level ' + IntToStr(Ord(LLevel)));
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.compress.audit');
  T.Run('Deflate 63 bytes', @TestDeflate63Bytes);
  T.Run('Deflate 64 bytes', @TestDeflate64Bytes);
  T.Run('Deflate 65 bytes', @TestDeflate65Bytes);
  T.Run('Native zlib version available', @TestNativeZlibVersionAvailable);
  T.Run('LZ4 1-3 bytes', @TestLz4_1to3Bytes);
  T.Run('LZ4 4 bytes', @TestLz4_4Bytes);
  T.Run('LZ4 random data', @TestLz4RandomData);
  T.Run('LZ4 compress bound rejects out-of-range input', @TestLz4CompressBoundRejectsOutOfRangeInput);
  T.Run('LZ4 offset before start', @TestLz4MalformedOffsetBeforeStart);
  T.Run('LZ4 zero offset', @TestLz4MalformedZeroOffset);
  T.Run('LZ4 length overflow', @TestLz4MalformedLengthOverflow);
  T.Run('LZ4 malformed original size metadata', @TestLz4MalformedOriginalSizeMetadata);
  T.Run('LZ4 empty decode contract', @TestLz4EmptyDecodeContract);
  T.Run('LZ4 malformed branch error model',
    @TestLz4MalformedBranchErrorModel);
  T.Run('LZ4 over-limit original size', @TestLz4RejectsOverLimitOriginalSize);
  T.Run('LZ4 bounded decode output limit',
    @TestLz4DecompressOutputLimitRejectsMetadataAboveCap);
  T.Run('Native LZ4 bounded decode output limit',
    @TestNativeLz4DecompressOutputLimitRejectsMetadataAboveCap);
  T.Run('Root facade LZ4 bound and metadata parity',
    @TestRootFacadeLz4BoundAndMetadataParity);
  T.Run('Root facade bounded LZ4 malformed parity',
    @TestRootFacadeLz4BoundedMalformedParity);
  T.Run('Native LZ4 original-size mismatch',
    @TestNativeLz4OriginalSizeMismatch);
  T.Run('LZ4 frame header unsupported',
    @TestLz4FrameHeaderRejectedAsUnsupported);
  T.Run('LZ4 truncated frame magic unsupported',
    @TestLz4TruncatedFrameMagicRejectedAsUnsupported);
  T.Run('LZ4 raw block skippable magic literal prefix',
    @TestLz4RawBlockSkippableMagicLiteralPrefixAccepted);
  T.Run('LZ4 malformed raw block magic literal prefix',
    @TestLz4MalformedRawBlockMagicLiteralPrefixKeepsDecodeError);
  T.Run('LZ4 malformed block ending with match',
    @TestLz4MalformedBlockEndingWithMatchRejected);
  T.Run('LZ4 malformed near-end match',
    @TestLz4MalformedNearEndMatchRejected);
  T.Run('Root facade LZ4 frame/raw-block boundary',
    @TestRootFacadeLz4FrameRawBlockBoundary);
  T.Run('LZ4 pure encoder block ends with literal tail',
    @TestLz4PureEncoderBlockEndsWithLiteralTail);
  T.Run('Gzip wrong CRC', @TestGzipWrongCRC);
  T.Run('Gzip wrong size', @TestGzipWrongSize);
  T.Run('Gzip single-member integrity bounded parity',
    @TestGzipSingleMemberIntegrityBoundedParity);
  T.Run('Gzip truncated header', @TestGzipTruncatedHeader);
  T.Run('Gzip empty encoded input error model',
    @TestGzipEmptyEncodedInputErrorModel);
  T.Run('Gzip truncated trailer', @TestGzipTruncatedTrailer);
  T.Run('Gzip fixed header error model',
    @TestGzipFixedHeaderErrorModel);
  T.Run('Gzip optional header truncation error model',
    @TestGzipOptionalHeaderTruncationErrorModel);
  T.Run('Gzip optional header field limit',
    @TestGzipOptionalHeaderFieldLimit);
  T.Run('Gzip corrupt payload error model',
    @TestGzipCorruptPayloadErrorModel);
  T.Run('Gzip rejects bytes before trailer', @TestGzipRejectsBytesBeforeTrailer);
  T.Run('Gzip rejects bytes after trailer', @TestGzipRejectsTrailingBytesAfterTrailer);
  T.Run('Gzip concatenated members', @TestGzipConcatenatedMembers);
  T.Run('Gzip concatenated members cumulative output cap',
    @TestGzipConcatenatedMembersCumulativeOutputCap);
  T.Run('Gzip concatenated trailer remaining cap output limit',
    @TestGzipConcatenatedTrailerSizeAboveRemainingCapReportsOutputLimit);
  T.Run('Gzip concatenated corrupt second member error model',
    @TestGzipConcatenatedCorruptSecondMemberErrorModel);
  T.Run('Gzip concatenated truncated second member trailer deferred validation',
    @TestGzipConcatenatedTruncatedSecondMemberTrailerDeferredValidation);
  T.Run('Gzip bounded reader concatenated truncated second member header',
    @TestGzipBoundedReaderConcatenatedTruncatedSecondMemberHeader);
  T.Run('Gzip truncated next member header',
    @TestGzipRejectsTruncatedNextMemberHeaderAfterTrailer);
  T.Run('Gzip reserved flags', @TestGzipReservedFlagsRejected);
  T.Run('Gzip header CRC', @TestGzipHeaderCrcRejected);
  T.Run('Gzip optional header all fields roundtrip',
    @TestGzipOptionalHeaderAllFieldsRoundTrip);
  T.Run('Gzip truncated payload read', @TestGzipTruncatedPayloadRaisesOnRead);
  T.Run('Deflate stream byte-by-byte', @TestDeflateStreamByteByByte);
  T.Run('Deflate cross-API roundtrip', @TestDeflateCrossApiRoundTrip);
  T.Run('Gzip cross-API roundtrip', @TestGzipCrossApiRoundTrip);
  T.Run('Gzip stream byte-by-byte', @TestGzipStreamByteByByte);
  T.Run('Gzip one-byte reader lifecycle', @TestGzipStreamOneByteReaderLifecycle);
  T.Run('Streaming small input zero-write repeated EOF matrix',
    @TestStreamingSmallInputZeroWriteAndRepeatedEOFMatrix);
  T.Run('Streaming reader corrupt error leaves terminal matrix',
    @TestStreamingReaderCorruptErrorLeavesTerminalMatrix);
  T.Run('Streaming reader deferred validation after payload',
    @TestStreamingReaderDeferredValidationAfterPayload);
  T.Run('Streaming reader truncated error leaves terminal matrix',
    @TestStreamingReaderTruncatedErrorLeavesTerminalMatrix);
  T.Run('Deflate partial close release-only',
    @TestDeflateReaderPartialCloseIsReleaseOnly);
  T.Run('Gzip partial close release-only', @TestGzipReaderPartialCloseIsReleaseOnly);
  T.Run('Streaming reader close before first read is release-only',
    @TestStreamingReaderCloseBeforeFirstReadIsReleaseOnly);
  T.Run('Streaming writer close reports short write',
    @TestStreamingWriterCloseReportsShortWrite);
  T.Run('Streaming writer release is non-throwing',
    @TestStreamingWriterReleaseIsNonThrowing);
  T.Run('Streaming writer flush preserves continuation',
    @TestStreamingWriterFlushPreservesContinuation);
  T.Run('Streaming writer payload flush after close',
    @TestStreamingWriterPayloadFlushAfterClose);
  T.Run('Streaming close lifecycle contract',
    @TestStreamingCloseLifecycleContract);
  T.Run('Streaming writer failed close leaves terminal',
    @TestStreamingWriterFailedCloseLeavesTerminal);
  T.Run('Streaming writer failed payload write leaves terminal',
    @TestStreamingWriterFailedPayloadWriteLeavesTerminal);
  T.Run('Streaming writer raised sink failure leaves terminal',
    @TestStreamingWriterRaisedSinkFailureLeavesTerminal);
  T.Run('Streaming writer failed flush leaves terminal',
    @TestStreamingWriterFailedFlushLeavesTerminal);
  T.Run('Streaming reader failed read leaves terminal',
    @TestStreamingReaderFailedReadLeavesTerminal);
  T.Run('Streaming factory rejects nil endpoints',
    @TestStreamingFactoryRejectsNilEndpoints);
  T.Run('Streaming bounded reader rejects nil endpoints',
    @TestStreamingBoundedReaderRejectsNilEndpoints);
  T.Run('Deflate empty stream', @TestDeflateEmptyStream);
  T.Run('Gzip empty stream', @TestGzipEmptyStream);
  T.Run('Deflate empty one-shot stream contract',
    @TestDeflateEmptyOneShotStreamContract);
  T.Run('Deflate invalid zlib header error model',
    @TestDeflateInvalidZlibHeaderErrorModel);
  T.Run('Deflate short zlib header error model',
    @TestDeflateShortZlibHeaderErrorModel);
  T.Run('Deflate split zlib header error model',
    @TestDeflateSplitZlibHeaderErrorModel);
  T.Run('Deflate preset dictionary header error model',
    @TestDeflatePresetDictionaryHeaderErrorModel);
  T.Run('Deflate corrupt payload error model',
    @TestDeflateCorruptPayloadErrorModel);
  T.Run('Deflate checksum-only corruption error model',
    @TestDeflateChecksumOnlyCorruptionErrorModel);
  T.Run('Deflate truncated stream', @TestDeflateTruncatedStreamRaises);
  T.Run('Deflate trailing bytes', @TestDeflateRejectsTrailingBytes);
  T.Run('Deflate trailing bytes terminal reader',
    @TestDeflateTrailingBytesLeavesReaderTerminal);
  T.Run('One-shot truncated payload contracts',
    @TestOneShotTruncatedPayloadContracts);
  T.Run('Deflate output limit error model', @TestDeflateOutputLimitErrorModel);
  T.Run('Gzip output limit error model', @TestGzipOutputLimitErrorModel);
  T.Run('Gzip trailer output limit error model',
    @TestGzipTrailerOutputLimitErrorModel);
  T.Run('Gzip streaming trailer size above cap reports output limit',
    @TestGzipStreamingTrailerSizeAboveCapReportsOutputLimit);
  T.Run('Streaming reader output limit error model',
    @TestStreamingReaderOutputLimitErrorModel);
  T.Run('Streaming reader output limit is cumulative across reads',
    @TestStreamingReaderOutputLimitIsCumulativeAcrossReads);
  T.Run('Bounded reader partial remaining cap preserves caller tail',
    @TestBoundedReaderPartialRemainingCapPreservesCallerTail);
  T.Run('Bounded exact cap rejects trailing bytes',
    @TestBoundedExactCapRejectsTrailingBytes);
  T.Run('Bounded high-expansion limit path',
    @TestBoundedHighExpansionLimitPath);
  T.Run('Bounded high-expansion partial cap preserves caller tail',
    @TestBoundedHighExpansionPartialRemainingCapPreservesCallerTail);
  T.Run('Bounded high-expansion failure loop releases state',
    @TestBoundedHighExpansionFailureLoopReleasesState);
  T.Run('Root facade bounded decompress helpers',
    @TestRootFacadeBoundedDecompressHelpers);
  T.Run('Deflate 1000 cycles', @TestCompressDecompressCycle1000);
  T.Run('LZ4 1000 cycles', @TestLz4Cycle1000);
  T.Run('Gzip nil round-trip', @TestGzipNilRoundTrip);
  T.Run('Deflate all levels', @TestDeflateAllLevels);
  T.Summary;
end.
