program bench_zip;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.compress.intf,
  nextpas.core.bytes.builder,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.checksum.crc32,
  nextpas.core.text.format,
  nextpas.core.exception;

const
  { 小文件面：容器开销（每条目头/central/解析）为主 }
  FILE_COUNT = 2000;
  FILE_SIZE = 512;
  SMALL_ITERS = 5;
  { 大单文件面：deflate 载荷吞吐为主 }
  BIG_SIZE = 1024 * 1024;
  BIG_ITERS = 20;

var
  GFiles: array of TBytes;
  GBlob: TBytes;
  GArchive: TBytes;
  GBigArchive: TBytes;

procedure GenerateData;
var
  LI, LJ: Integer;
begin
  SetLength(GFiles, FILE_COUNT);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    SetLength(GFiles[LI], FILE_SIZE);
    for LJ := 0 to FILE_SIZE - 1 do
      GFiles[LI][LJ] := Byte((LJ * 7 + LI) mod 251);
  end;
  SetLength(GBlob, BIG_SIZE);
  for LI := 0 to BIG_SIZE - 1 do
    GBlob[LI] := Byte((LI * 7 + LI div 256) mod 251);
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes; const ALabel: string);
var
  LI: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    raise EInvalidOperationError.Create(ALabel + ': length mismatch');
  for LI := 0 to High(AExpected) do
    if AExpected[LI] <> AActual[LI] then
      raise EInvalidOperationError.Create(ALabel + ': byte mismatch at ' + IntToStr(LI));
end;

function EntryName(AIndex: Integer): string;
var
  LS: string;
  LJ: Integer;
begin
  Str(AIndex:4, LS);
  for LJ := 1 to Length(LS) do
    if LS[LJ] = ' ' then
      LS[LJ] := '0';
  Result := 'f/' + LS + '.bin';
end;

{ 全部小文件打成一个 deflate 归档 }
function BuildManyArchive: TBytes;
var
  LW: IZipWriter;
  LI: Integer;
begin
  LW := NewZipWriter;
  for LI := 0 to FILE_COUNT - 1 do
    LW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
  Result := LW.Finish;
end;

{ 丢弃字节的 sink：流式输出基准用 }
type
  TNullWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TNullWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

{ 收集字节到内存的 sink：流式输出正确性预检用 }
type
  TCollectBench = class(TInterfacedObject, IWriter)
  private
    FBuf: IBytesBuilder;
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Bytes: TBytes;
  end;

constructor TCollectBench.Create;
begin
  inherited Create;
  FBuf := CreateBytesBuilder(65536);
end;

function TCollectBench.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount > 0 then
    FBuf.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

function TCollectBench.Bytes: TBytes;
begin
  Result := FBuf.ToBytes;
end;

{ 向已绑定输出端的写器追加全部条目（与 BuildManyArchive 同输入同序） }
procedure BuildManyEntriesInto(const AW: IZipWriter);
var
  LI: Integer;
begin
  for LI := 0 to FILE_COUNT - 1 do
    AW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
end;

{ 绑定后逐条目透传的打包；返回写入总字节数供校验 }
function BuildManyArchiveTo(const ASink: IWriter): UInt64;
var
  LW: IZipWriter;
begin
  LW := NewZipWriter;
  LW.StreamOutputTo(ASink);
  BuildManyEntriesInto(LW);
  Result := LW.FinishTo(ASink);
end;

procedure BenchPackManyDeflate;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LTotal, LRatio: Double;
begin
  GArchive := BuildManyArchive;
  LTotal := Int64(FILE_COUNT) * FILE_SIZE;
  LRatio := Length(GArchive) / LTotal * 100;

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS do
    GArchive := BuildManyArchive;
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip pack %4d files   %8.0f entries/s  %6.1f MB/s  ratio=%.1f%%', [
    FILE_COUNT,
    (Int64(FILE_COUNT) * SMALL_ITERS) / LElapsed,
    (LTotal * SMALL_ITERS / 1048576.0) / LElapsed,
    LRatio]));
end;

{ 正确性预检（不计时）：与缓冲式 Finish 字节级一致。
  注意：sink 以裸对象引用持有时（rc=0），写器是唯一接口持有者——必须在
  写器存活期内取走结果；写器出作用域即释放 sink }
function StreamOutParitySample: TBytes;
var
  LW: IZipWriter;
  LCol: TCollectBench;
begin
  LCol := TCollectBench.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LCol);
  BuildManyEntriesInto(LW);
  LW.FinishTo(LCol);
  Result := LCol.Bytes;
end;

{ 流式输出打包：绑定 sink 后逐条目透传，无整档二次物化 }
procedure BenchStreamOut;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LTotal: Double;
  LNull: IWriter;
  LPiped: TBytes;
begin
  LPiped := StreamOutParitySample;
  CheckBytesEqual(GArchive, LPiped, 'stream-out parity');

  LTotal := Int64(FILE_COUNT) * FILE_SIZE;
  LNull := TNullWriter.Create;

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS do
  begin
    if BuildManyArchiveTo(LNull) <> UInt64(Length(GArchive)) then
      raise EInvalidOperationError.Create('stream-out total mismatch');
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip stream-out      %8.0f entries/s  %6.1f MB/s', [
    (Int64(FILE_COUNT) * SMALL_ITERS) / LElapsed,
    (LTotal * SMALL_ITERS / 1048576.0) / LElapsed]));
end;

{ 加密面：AES-256 AE-2 封框（压缩+CTR+HMAC+盐派生）与解封全路径，
  1MB 大文件口径与 BenchBigRoundtrip 对齐；先做 parity 预检 }
procedure BenchAesBigRoundtrip;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: IZipWriter;
  LR: IZipReader;
  LOpts: TZipAddOptions;
  LROpts: TZipReadOptions;
  LEnc, LGot: TBytes;

  function StrBytes(const AStr: string): TBytes;
  var
    LJ: Integer;
  begin
    SetLength(Result, Length(AStr));
    for LJ := 1 to Length(AStr) do
      Result[LJ - 1] := Ord(AStr[LJ]);
  end;

begin
  LW := NewZipWriter;
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.Password := StrBytes('bench-password');
  LOpts.AesStrength := 3;
  LW.AddEntryWithOptions('big.bin', GBlob, LOpts);
  LEnc := LW.Finish;

  LROpts := DefaultZipReadOptions;
  LROpts.Password := StrBytes('bench-password');
  LR := NewZipReaderWithOptions(LEnc, LROpts);
  LGot := LR.ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'aes big roundtrip parity');

  { 计时：写端 = deflate + 封框加密 }
  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LW := NewZipWriter;
    LW.AddEntryWithOptions('big.bin', GBlob, LOpts);
    LEnc := LW.Finish;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip aes256 pack     %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));

  { 计时：读端 = 解封认证 + inflate }
  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LR := NewZipReaderWithOptions(LEnc, LROpts);
    LGot := LR.ExtractToBytesByName('big.bin');
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip aes256 extract  %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));
end;

{ 描述符直写 vs 暂存流：同输入 1MB deflate，先做提取 parity }
procedure BenchDescriptorDirectVsStaged;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LZip, LGot: TBytes;
begin
  LO := DefaultZipAddOptions;
  LO.Method := zmDeflate;
  LO.DataDescriptor := True;

  LW := NewZipWriter;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(GBlob[0], Length(GBlob));
  LS.Close;
  LZip := LW.Finish;
  LGot := NewZipReader(LZip).ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'descriptor direct parity');

  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LW := NewZipWriter;
    LS := LW.AddEntryStream('big.bin', LO);
    LS.Write(GBlob[0], Length(GBlob));
    LS.Close;
    LZip := LW.Finish;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip descriptor pack %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));

  LO.DataDescriptor := False;
  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LW := NewZipWriter;
    LS := LW.AddEntryStream('big.bin', LO);
    LS.Write(GBlob[0], Length(GBlob));
    LS.Close;
    LZip := LW.Finish;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip staged pack     %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));
end;

procedure BenchOpenParse;
var  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LR: IZipReader;
begin
  LR := NewZipReader(GArchive);
  if LR.EntryCount <> FILE_COUNT then
    raise EInvalidOperationError.Create('parse benchmark: entry count mismatch');

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS * 10 do
    LR := NewZipReader(GArchive);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip open (parse CD) %8.0f opens/s  %9.0f entries/s', [
    (SMALL_ITERS * 10) / LElapsed,
    (Int64(FILE_COUNT) * SMALL_ITERS * 10) / LElapsed]));
end;

procedure BenchExtractAll;
var
  LI, LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LR: IZipReader;
  LGot: TBytes;
  LCrc: LongWord;
  LTotal: Double;
begin
  LR := NewZipReader(GArchive);
  LCrc := 0;
  for LJ := 0 to FILE_COUNT - 1 do
  begin
    LGot := LR.ExtractToBytes(LJ);
    CheckBytesEqual(GFiles[LJ], LGot, 'extract-all verify');
    LCrc := Crc32OfBytes(LGot);  { 末条目 CRC，防剔除 }
  end;
  if LCrc = 0 then
    raise EInvalidOperationError.Create('unreachable');
  LTotal := Int64(FILE_COUNT) * FILE_SIZE;

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS * 10 do
    for LJ := 0 to FILE_COUNT - 1 do
      LGot := LR.ExtractToBytes(LJ);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip extract all     %8.0f entries/s  %6.1f MB/s', [
    (Int64(FILE_COUNT) * SMALL_ITERS * 10) / LElapsed,
    (LTotal * SMALL_ITERS * 10 / 1048576.0) / LElapsed]));
end;

procedure BenchBigRoundtrip;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: IZipWriter;
  LR: IZipReader;
  LGot: TBytes;
  LRatio: Double;
begin
  LW := NewZipWriter;
  LW.AddEntryDeflate('big.bin', GBlob);
  GBigArchive := LW.Finish;
  LRatio := Length(GBigArchive) / Length(GBlob) * 100;
  LR := NewZipReader(GBigArchive);
  LGot := LR.ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'big roundtrip verify');

  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LW := NewZipWriter;
    LW.AddEntryDeflate('big.bin', GBlob);
    GBigArchive := LW.Finish;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip write 1MB entry %6.1f MB/s  ratio=%.1f%%', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed, LRatio]));

  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LR := NewZipReader(GBigArchive);
    LGot := LR.ExtractToBytes(0);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip read 1MB entry  %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));
end;

procedure BenchSequential;
var
  LI, LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LR: IZipReader;
  LSeq: ISequentialZipReader;
  LInfo: TZipEntryInfo;
  LStream: IDecompressReader;
  LBuf: array[0..65535] of Byte;
  LTotal: Double;
  LGot: TBytes;
begin
  { 正确性：顺序读与内存读 1MB 条目一致 }
  LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GBigArchive) as IReader);
  if not LSeq.Next(LInfo) then
    raise EInvalidOperationError.Create('sequential bench: no entry');
  LStream := LSeq.Open;
  SetLength(LGot, 0);
  repeat
    LJ := LStream.Read(LBuf[0], SizeOf(LBuf));
    if LJ > 0 then
    begin
      SetLength(LGot, Length(LGot) + Integer(LJ));
      Move(LBuf[0], LGot[Length(LGot)-Integer(LJ)], LJ);
    end;
  until LJ = 0;
  LStream.Close;
  LR := NewZipReader(GBigArchive);
  CheckBytesEqual(LR.ExtractToBytes(0), LGot, 'sequential 1MB verify');

  { 计时：2000 文件顺序流式提取 }
  LTotal := Int64(FILE_COUNT) * FILE_SIZE;
  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS do
  begin
    LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GArchive) as IReader);
    while LSeq.Next(LInfo) do
    begin
      LStream := LSeq.Open;
      repeat LJ := LStream.Read(LBuf[0], SizeOf(LBuf)); until LJ = 0;
      LStream.Close;
    end;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip seq extract all %8.0f entries/s  %6.1f MB/s', [
    (Int64(FILE_COUNT) * SMALL_ITERS) / LElapsed,
    (LTotal * SMALL_ITERS / 1048576.0) / LElapsed]));

  { 计时：1MB 单条目顺序提取 }
  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GBigArchive) as IReader);
    LSeq.Next(LInfo);
    LStream := LSeq.Open;
    repeat LJ := LStream.Read(LBuf[0], SizeOf(LBuf)); until LJ = 0;
    LStream.Close;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip seq read 1MB    %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));
end;

begin
  GenerateData;
  WriteLn(TextFormat('=== Pascal zip benchmark (%d files x %dB + 1MB blob) ===',
    [FILE_COUNT, FILE_SIZE]));
  WriteLn;
  BenchPackManyDeflate;
  BenchStreamOut;
  BenchOpenParse;
  BenchExtractAll;
  WriteLn;
  BenchBigRoundtrip;
  BenchAesBigRoundtrip;
  BenchDescriptorDirectVsStaged;
  BenchSequential;
  WriteLn;
  WriteLn('done.');
end.
