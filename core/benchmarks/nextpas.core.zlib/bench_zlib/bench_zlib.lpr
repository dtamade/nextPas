program bench_zlib;
{$I nextpas.core.settings.inc}
{$Q-}{$R-}
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.text.format,
  nextpas.core.exception,
  nextpas.core.zlib.base,
  nextpas.core.zlib.pure,
  nextpas.core.zlib.ffi,
  nextpas.core.zlib;

const
  DATA_SIZE = 1024 * 1024;
  ITER_ENC = 20;
  ITER_DEC = 50;

var
  GData: TBytes;
  GCompressed: TBytes;
  GCompressedRaw: TBytes;

procedure GenerateData;
var
  I: Integer;
begin
  SetLength(GData, DATA_SIZE);
  for I := 0 to DATA_SIZE - 1 do
    GData[I] := Byte((I * 7 + I div 256) mod 251);
  GCompressed := ZlibPureEncodeWithLevel(GData, zlDefault);
  GCompressedRaw := ZlibPureEncodeRawWithLevel(GData, zlDefault);
end;

procedure CheckBytesEqual(const A, B: TBytes; const ALabel: string);
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    raise EInvalidOperationError.Create(ALabel + ': length mismatch');
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      raise EInvalidOperationError.Create(ALabel + ': byte mismatch at ' + IntToStr(I));
end;

procedure BenchEncodePure(const ALevel: TZlibLevel; const ATag: string);
var
  I: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LEnc: TBytes;
  LRatio: Double;
begin
  LEnc := ZlibPureEncodeWithLevel(GData, ALevel);
  LRatio := Length(LEnc) / Length(GData) * 100;
  CheckBytesEqual(GData, ZlibPureDecode(LEnc), 'bench encode ' + ATag);
  LStart := TInstant.Now;
  for I := 1 to ITER_ENC do
    LEnc := ZlibPureEncodeWithLevel(GData, ALevel);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib pure encode %-8s %6.1f MB/s  ratio=%.1f%%', [ATag, (DATA_SIZE * ITER_ENC / 1048576.0) / LElapsed, LRatio]));
end;

procedure BenchDecodePure(const ATag: string);
var
  I: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LOut: TBytes;
begin
  LOut := ZlibPureDecode(GCompressed);
  CheckBytesEqual(GData, LOut, 'bench decode ' + ATag);
  LStart := TInstant.Now;
  for I := 1 to ITER_DEC do
    LOut := ZlibPureDecode(GCompressed);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib pure decode %-8s %6.1f MB/s', [ATag, (DATA_SIZE * ITER_DEC / 1048576.0) / LElapsed]));
end;

procedure BenchEncodeFfi(const ALevel: TZlibLevel; const ATag: string);
var
  I: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LEnc: TBytes;
begin
  if not ZlibFfiAvailable then Exit;
  LEnc := ZlibFfiEncode(GData, ALevel);
  CheckBytesEqual(GData, ZlibPureDecode(LEnc), 'ffi encode ' + ATag);
  LStart := TInstant.Now;
  for I := 1 to ITER_ENC do
    LEnc := ZlibFfiEncode(GData, ALevel);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib ffi  encode %-8s %6.1f MB/s', [ATag, (DATA_SIZE * ITER_ENC / 1048576.0) / LElapsed]));
end;

procedure BenchDecodeFfi(const ATag: string);
var
  I: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LOut: TBytes;
  LEnc: TBytes;
begin
  if not ZlibFfiAvailable then Exit;
  LEnc := ZlibFfiEncode(GData, zlDefault);
  LOut := ZlibFfiDecode(LEnc);
  CheckBytesEqual(GData, LOut, 'ffi decode ' + ATag);
  LStart := TInstant.Now;
  for I := 1 to ITER_DEC do
    LOut := ZlibFfiDecode(LEnc);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib ffi  decode %-8s %6.1f MB/s', [ATag, (DATA_SIZE * ITER_DEC / 1048576.0) / LElapsed]));
end;

procedure BenchRawPure;
var
  I: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LEnc, LOut: TBytes;
begin
  LEnc := ZlibPureEncodeRaw(GData);
  LOut := ZlibPureDecodeRaw(LEnc);
  CheckBytesEqual(GData, LOut, 'raw');
  LStart := TInstant.Now;
  for I := 1 to ITER_ENC do
    LEnc := ZlibPureEncodeRaw(GData);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib pure encode raw     %6.1f MB/s', [(DATA_SIZE * ITER_ENC / 1048576.0) / LElapsed]));
  LStart := TInstant.Now;
  for I := 1 to ITER_DEC do
    LOut := ZlibPureDecodeRaw(GCompressedRaw);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zlib pure decode raw     %6.1f MB/s', [(DATA_SIZE * ITER_DEC / 1048576.0) / LElapsed]));
end;

var
  LFfiOk: Boolean;
  LFfiTag: string;
begin
  GenerateData;
  LFfiOk := ZlibFfiAvailable;
  if LFfiOk then LFfiTag := 'yes' else LFfiTag := 'no';
  WriteLn(TextFormat('=== nextpas.core.zlib benchmark (1MiB x enc %d dec %d, ffi=%s) ===', [ITER_ENC, ITER_DEC, LFfiTag]));
  WriteLn;
  BenchEncodePure(zlNone, 'none');
  BenchEncodePure(zlFastest, 'fastest');
  BenchEncodePure(zlDefault, 'default');
  BenchEncodePure(zlBest, 'best');
  WriteLn;
  BenchDecodePure('default');
  if LFfiOk then BenchDecodeFfi('default');
  WriteLn;
  BenchRawPure;
  if LFfiOk then
  begin
    WriteLn;
    BenchEncodeFfi(zlNone, 'none');
    BenchEncodeFfi(zlFastest, 'fastest');
    BenchEncodeFfi(zlDefault, 'default');
    BenchEncodeFfi(zlBest, 'best');
  end;
  WriteLn;
  WriteLn('done.');
end.
