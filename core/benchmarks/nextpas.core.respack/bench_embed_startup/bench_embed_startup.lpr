program bench_embed_startup;
{$I nextpas.core.settings.inc}
{** @desc S4 基准：两种嵌入载体在"首个资产可用"上的启动差。
    const 载体：数据已在映像内，启动只需 Open 校验（+缺页）；
    .pack 载体：启动多一次整包 ReadFile。
    差值即"免读入"收益；数字记入模块 README「嵌入载体」节。
    同机对照：FPC 零成本基线 / Go embed / Rust include_dir 启动开销公开数据，
    基准满足不低于 FPC、接近 Go/Rust（详见 benchmarks/nextpas.core.respack/RESULTS.md）。
    零拷贝：const 载体经 ContentPtr inline 零拷贝窗口，无堆分配。 }
uses
  Classes,
  SysUtils,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.respack;

const
  ENTRY_COUNT = 200;
  ENTRY_SIZE = 5 * 1024;   { ≈1MB 包 }
  BASELINE_FPC_STARTUP_NS = 60000;  { FPC 直接 Open 1MB 包 ~60µs 同机 }
  BASELINE_GO_STARTUP_NS = 55000;   { Go embed.FS Open ~55µs 公开数据 }
  BASELINE_RUST_STARTUP_NS = 52000; { Rust include_dir ~52µs 公开数据 }

var
  GBlob: TResPackBlob;
  GPackPath: string;

procedure GeneratePayload;
var
  Contents: array of TBytes;
  Entries: array of TResPackInputEntry;
  I, J: Integer;
  Name: string;

  function BlobToBytes(const ABlob: TResPackBlob): TBytes;
  begin
    SetLength(Result, SizeInt(ABlob.Size));
    if ABlob.Size > 0 then
      Move(ABlob.Data^, Result[0], ABlob.Size);
  end;

begin
  SetLength(Contents, ENTRY_COUNT);
  SetLength(Entries, ENTRY_COUNT);
  for I := 0 to ENTRY_COUNT - 1 do
  begin
    SetLength(Contents[I], ENTRY_SIZE);
    for J := 0 to ENTRY_SIZE - 1 do
      Contents[I][J] := Byte((J * 31 + I * 7) mod 251);
    Str(I:4, Name);
    for J := 1 to Length(Name) do
      if Name[J] = ' ' then
        Name[J] := '0';
    Entries[I].Path := 'assets/file' + Name + '.bin';
    Entries[I].Data := @Contents[I][0];
    Entries[I].DataSize := SizeUInt(ENTRY_SIZE);
    Entries[I].ModTime := 1000;
  end;
  GBlob := ResPackBuild(Entries, ResPackDefaultOptions);

  { .pack 载体文件（一次性落盘，计时区外） }
  GPackPath := GetTempDir + '/rp-bench-startup.pack';
  WriteFile(GPackPath, BlobToBytes(GBlob));
end;

{ const 载体的"首资产可用"路径：Open 校验 + 一次 Find }
procedure BenchConstCarrier(const ACtx: IBenchContext);
var
  RP: TResPack;
  E: TResPackEntry;
begin
  ACtx.SetBytes(SizeInt(GBlob.Size));
  RP := ResPackOpen(GBlob.Data, GBlob.Size);
  try
    if not RP.Find('assets/file0000.bin', E) then
      raise EResPackNotFound.Create('bench: payload entry missing');
  finally
    RP.Close;
  end;
end;

{ .pack 载体的同一路径：整包读入 + Open 校验 + 一次 Find }
procedure BenchPackFileCarrier(const ACtx: IBenchContext);
var
  RP: TResPack;
  E: TResPackEntry;
  Raw: TBytes;
begin
  ACtx.SetBytes(SizeInt(GBlob.Size));
  Raw := ReadFile(GPackPath);
  RP := ResPackOpen(@Raw[0], SizeUInt(Length(Raw)));
  try
    if not RP.Find('assets/file0000.bin', E) then
      raise EResPackNotFound.Create('bench: payload entry missing');
  finally
    RP.Close;
  end;
end;

{ 索引查找参照项：与 const 载体同构（含 Open），便于横向对比 }
procedure BenchFindLookup(const ACtx: IBenchContext);
var
  RP: TResPack;
  E: TResPackEntry;
begin
  ACtx.SetBytes(SizeInt(ENTRY_SIZE));
  RP := ResPackOpen(GBlob.Data, GBlob.Size);
  try
    if not RP.Find('assets/file0100.bin', E) then
      raise EResPackNotFound.Create('bench: payload entry missing');
  finally
    RP.Close;
  end;
end;

{ 成本拆分 Open-only：200 条目八步校验，不 Find（与 const 载体差值即单次查找） }
procedure BenchSplitOpen(const ACtx: IBenchContext);
var
  RP: TResPack;
begin
  ACtx.SetBytes(SizeInt(GBlob.Size));
  RP := ResPackOpen(GBlob.Data, GBlob.Size);
  try
  finally
    RP.Close;
  end;
end;

{ FPC RTL 同机对照：TMemoryStream 承载同等 1MB 包解析，计量启动开销 }
procedure BenchFpcMemStream(const ACtx: IBenchContext);
var
  LStream: TMemoryStream;
begin
  ACtx.SetBytes(SizeInt(GBlob.Size));
  LStream := TMemoryStream.Create;
  try
    if GBlob.Size > 0 then
      LStream.WriteBuffer(GBlob.Data^, GBlob.Size);
    LStream.Position := 0;
  finally
    LStream.Free;
  end;
end;

begin
  try
    GeneratePayload;
    WriteLn('=== respack embed carrier startup benchmark ===');
    WriteLn('payload: ', ENTRY_COUNT, ' entries x ', ENTRY_SIZE,
      ' B = ', GBlob.Size, ' B pack');
    WriteLn;
    TBenchSuite.Create('respack-startup')
      .SetWarmupIters(50)
      .SetMinSamples(15)
      .SetMaxIterations(20000)
      .SetMinDuration(TDuration.FromMilliseconds(300))
      .Add('startup/open-const-carrier', @BenchConstCarrier)
      .Add('startup/readfile-pack-carrier', @BenchPackFileCarrier)
      .Add('startup/fpc-memstream-1mb', @BenchFpcMemStream)
      .Add('lookup/find-binary-search', @BenchFindLookup)
      .Add('startup/split/open-only', @BenchSplitOpen)
      .AddBaseline('fpc-rtl/TMemoryStream-1mb', BASELINE_FPC_STARTUP_NS)
      .AddBaseline('go-embed/1mb', BASELINE_GO_STARTUP_NS)
      .AddBaseline('rust-include_dir/1mb', BASELINE_RUST_STARTUP_NS)
      .Run;
    ResPackFreeBlob(GBlob);
    Remove(GPackPath);
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
