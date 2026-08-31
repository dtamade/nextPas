program bench_transform;
{$I nextpas.core.settings.inc}
{** @desc 变换装饰器基准：固化 daAuto 4K 头部预判与单次读取收益。 }
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.vfs,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.compressed,
  nextpas.core.compress;

var
  GInnerLarge, GInnerGz: IVfs;
  GDecLarge, GDecGz: IVfs;
  GLarge: TBytes;

procedure BuildFixtures;
var
  B: TVfsTreeBuilder;
  Raw, Gz: TBytes;
  I: Integer;
begin
  SetLength(GLarge, 1024 * 1024);
  for I := 0 to High(GLarge) do GLarge[I] := Byte(Ord('A') + (I mod 26));
  GLarge[0] := Ord('X'); GLarge[1] := Ord('Y');
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('large.bin', GLarge, 100);
    GInnerLarge := B.Freeze;
  finally
    B.Free;
  end;
  GDecLarge := CreateDecompressingVfs(GInnerLarge, daAuto);
  SetLength(Raw, 64 * 1024);
  for I := 0 to High(Raw) do Raw[I] := Byte(I mod 251);
  Gz := GzipCompress(Raw);
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('gz.bin', Gz, 200);
    GInnerGz := B.Freeze;
  finally
    B.Free;
  end;
  GDecGz := CreateDecompressingVfs(GInnerGz, daAuto);
end;

procedure BenchStatLargeNonGzip(const ACtx: IBenchContext);
var LInfo: TStatInfo;
begin
  LInfo := GDecLarge.Stat('large.bin');
  ACtx.SetBytes(LInfo.Info.Size);
  if LInfo.Info.Size <> Int64(Length(GLarge)) then
    raise Exception.Create('bench: large Stat size mismatch');
end;

procedure BenchStatGzDecompress(const ACtx: IBenchContext);
var LInfo: TStatInfo;
begin
  LInfo := GDecGz.Stat('gz.bin');
  ACtx.SetBytes(LInfo.Info.Size);
  if LInfo.Info.Size <= 0 then
    raise Exception.Create('bench: gz Stat size invalid');
end;

procedure BenchOpenLargeNonGzip(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GDecLarge, 'large.bin');
  ACtx.SetBytes(Int64(Length(D)));
  if Length(D) <> Length(GLarge) then
    raise Exception.Create('bench: large Open size mismatch');
end;

procedure BenchOpenGzDecompress(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GDecGz, 'gz.bin');
  ACtx.SetBytes(Int64(Length(D)));
  if Length(D) = 0 then
    raise Exception.Create('bench: gz Open empty');
end;

begin
  try
    BuildFixtures;
    WriteLn('=== vfs transform benchmark (daAuto header peek + single-read) ===');
    TBenchSuite.Create('vfs-transform')
      .SetWarmupIters(20)
      .SetMinSamples(10)
      .Add('Stat/large-non-gzip/header-peek', @BenchStatLargeNonGzip)
      .Add('Stat/gz/decompress', @BenchStatGzDecompress)
      .Add('Open/large-non-gzip/passthrough', @BenchOpenLargeNonGzip)
      .Add('Open/gz/decompress', @BenchOpenGzDecompress)
      .Run;
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
