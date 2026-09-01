program bench_tar;
{**
 * @desc TAR 基准套件：nextpas.core.bench 规矩形态，覆盖 writer/builder/reader 全路径。
 * 小文件 200×512B 与大文件 1MiB 两档，验证 bytes 级一致后经 TBenchSuite 统计。
 *}

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.tar,
  nextpas.core.tar.base,
  nextpas.core.exception;

const
  FILE_COUNT = 2000;
  FILE_SIZE = 512;
  BIG_SIZE = 1024 * 1024;
  BENCH_PACK_COUNT = 200;

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

function EntryName(AIndex: Integer): string;
var
  LS: string;
  LJ: Integer;
begin
  Str(AIndex:4, LS);
  for LJ := 1 to Length(LS) do
    if LS[LJ] = ' ' then LS[LJ] := '0';
  Result := 'f/' + LS + '.bin';
end;

function BuildManyArchive: TBytes;
var
  S: IStream; W: TTarWriter; LI: Integer;
begin
  S := CreateBytesStream; W := TTarWriter.Create(S as IWriter);
  try
    for LI := 0 to FILE_COUNT - 1 do W.AddFile(EntryName(LI), GFiles[LI]);
    W.Finish; Result := nil; SetLength(Result, S.Size);
    if Length(Result) > 0 then begin S.Seek(0, soBeginning); S.Read(Result[0], Length(Result)); end;
  finally W.Free; end;
end;

function BuildManyArchiveBench: TBytes;
var
  S: IStream; W: TTarWriter; LI: Integer;
begin
  S := CreateBytesStream; W := TTarWriter.Create(S as IWriter);
  try
    for LI := 0 to BENCH_PACK_COUNT - 1 do W.AddFile(EntryName(LI), GFiles[LI]);
    W.Finish; Result := nil; SetLength(Result, S.Size);
    if Length(Result) > 0 then begin S.Seek(0, soBeginning); S.Read(Result[0], Length(Result)); end;
  finally W.Free; end;
end;

function StrBytes(const AStr: string): TBytes;
var LJ: Integer;
begin
  SetLength(Result, Length(AStr));
  for LJ := 1 to Length(AStr) do Result[LJ-1] := Ord(AStr[LJ]);
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes; const ALabel: string);
var LI: Integer;
begin
  if Length(AExpected) <> Length(AActual) then raise EInvalidOperationError.Create(ALabel + ': length mismatch');
  for LI := 0 to High(AExpected) do if AExpected[LI] <> AActual[LI] then raise EInvalidOperationError.Create(ALabel + ': byte mismatch at ' + IntToStr(LI));
end;

// bench funcs

procedure BenchPackMany(const ACtx: IBenchContext);
var LArc: TBytes;
begin
  LArc := BuildManyArchiveBench; BenchBlackBoxBytes(LArc[0], Length(LArc)); ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchPackMany2000(const ACtx: IBenchContext);
var LArc: TBytes;
begin
  LArc := BuildManyArchive; BenchBlackBoxBytes(LArc[0], Length(LArc)); ACtx.SetBytes(Int64(FILE_COUNT) * FILE_SIZE);
end;

procedure BenchBuilderPack(const ACtx: IBenchContext);
var B: ITarBuilder; LI: Integer; LArc: TBytes;
begin
  B := TarBuilder;
  for LI := 0 to BENCH_PACK_COUNT - 1 do B.Add(EntryName(LI), GFiles[LI]);
  LArc := B.Finish; BenchBlackBoxBytes(LArc[0], Length(LArc)); ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchOpenParse(const ACtx: IBenchContext);
var R: TTarReader; H: TTarHeader;
begin
  R := TTarReader.Create(GArchive); try while R.Next(H) do ; BenchBlackBoxPtr(Pointer(R)); finally R.Free; end; ACtx.SetBytes(0);
end;

procedure BenchExtractAll(const ACtx: IBenchContext);
var R: TTarReader; H: TTarHeader; LGot: TBytes;
begin
  R := TTarReader.Create(GArchive); try while R.Next(H) do begin LGot := R.EntryData; BenchBlackBoxBytes(LGot[0], Length(LGot)); end; finally R.Free; end; ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchExtractSlice(const ACtx: IBenchContext);
var R: TTarReader; H: TTarHeader; P: PByte; C: SizeUInt;
begin
  R := TTarReader.Create(GArchive); try while R.Next(H) do if R.EntryDataSlice(P, C) then BenchBlackBoxPtr(P); finally R.Free; end; ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchWrite1MB(const ACtx: IBenchContext);
var S: IStream; W: TTarWriter; LArc: TBytes;
begin
  S := CreateBytesStream; W := TTarWriter.Create(S as IWriter);
  try W.AddFile('big.bin', GBlob); W.Finish; SetLength(LArc, S.Size); if Length(LArc)>0 then begin S.Seek(0, soBeginning); S.Read(LArc[0], Length(LArc)); end; BenchBlackBoxBytes(LArc[0], Length(LArc)); finally W.Free; end; ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchRead1MB(const ACtx: IBenchContext);
var R: TTarReader; H: TTarHeader; LGot: TBytes;
begin
  R := TTarReader.Create(GBigArchive); try if R.Next(H) then begin LGot := R.EntryData; BenchBlackBoxBytes(LGot[0], Length(LGot)); end; finally R.Free; end; ACtx.SetBytes(BIG_SIZE);
end;

var
  LResults: IBenchResults;
  LSuit: IBenchSuite;
  R: TTarReader; H: TTarHeader; LGot: TBytes; LArc: TBytes; B: ITarBuilder; S: IStream; W: TTarWriter;
begin
  GenerateData;
  GArchive := BuildManyArchiveBench;
  // big
  S := CreateBytesStream; W := TTarWriter.Create(S as IWriter);
  try W.AddFile('big.bin', GBlob); W.Finish; SetLength(GBigArchive, S.Size); if Length(GBigArchive)>0 then begin S.Seek(0, soBeginning); S.Read(GBigArchive[0], Length(GBigArchive)); end; finally W.Free; end;
  // parity
  B := TarBuilder; B.Add('a.txt', StrBytes('hello')).Add('b.txt', StrBytes('world'));
  LArc := B.Finish;
  R := TTarReader.Create(LArc); try if not R.Next(H) then raise EInvalidOperationError.Create('parity'); finally R.Free; end;
  R := TTarReader.Create(GBigArchive); try if R.Next(H) then begin LGot := R.EntryData; CheckBytesEqual(GBlob, LGot, 'big roundtrip'); end; finally R.Free; end;

  LSuit := TBenchSuite.Create('tar')
    .SetMinDuration(TDuration.FromMilliseconds(300)).SetMinSamples(7).SetWarmupIters(1).SetMaxIterations(25)
    .Add('tar/pack/200x512B', @BenchPackMany)
    .Add('tar/builder-pack/200x512B', @BenchBuilderPack)
    .Add('tar/open/parse', @BenchOpenParse)
    .Add('tar/extract-all/200x512B', @BenchExtractAll)
    .Add('tar/extract-slice/200x512B', @BenchExtractSlice)
    .Add('tar/write/1MB', @BenchWrite1MB)
    .Add('tar/read/1MB', @BenchRead1MB);
  if GetEnvironmentVariable('TAR_BENCH_FULL') = '1' then LSuit.Add('tar/pack/2000x512B', @BenchPackMany2000);
  LResults := LSuit.Run;
  WriteLn(LResults.PrintToConsole);
  WriteLn('benchstat: ', LResults.ToBenchstat);
  try ForceDirectories('build'); ForceDirectories('../../../build'); LResults.SaveToJSON('build/bench-tar.json'); LResults.SaveToJSON('../../../build/bench-tar.json'); except on E: Exception do WriteLn('save json skipped: ', E.Message); end;
end.
