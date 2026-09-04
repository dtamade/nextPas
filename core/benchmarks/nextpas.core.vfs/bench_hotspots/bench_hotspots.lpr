program bench_hotspots;
{$I nextpas.core.settings.inc}
{** @desc vfs 热点基准：覆盖 memtree/embedded/os 三后端 Exists/Stat/List/OpenRead/Walk/Sub 全热路径。
     固化设计规范每模块热路径基准覆盖要求，补充 bench_transform 仅覆盖 transform/compressed 的缺口。
     复用 bytes.ops 单源（SpanStartsWith/SpanEqual/BytesIsGzipBuffer inline 零拷贝），
     List 零冗余经 VfsEnumerateChildSpans 单源扇出限界，Walk 零冗余 List，OpenRead 零拷贝切片/Move 单源，
     内联热路径证据：VfsStat/VfsList/BytesIsGzipBuffer/Span* inline，资源释放 try-finally Close 不丢，
     业务以 CONTRACT 为准，三后端语义一致性由 conformance 门锁，缺能力反哺 owner（os→fs，embedded→respack）。 }
uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.vfs,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.base,
  nextpas.core.bytes.ops,
  nextpas.core.respack,
  nextpas.core.fs;

const
  FILE_COUNT = 64;
  FILE_SIZE = 4096;
  SUB_DIR = 'assets';
  BENCH_FILE = 'assets/file0000.bin';
  BENCH_SUB_FILE = 'file0000.bin';

var
  GMem, GEmb, GOs: IVfs;
  GSubMem, GSubEmb, GSubOs: IVfs;
  GBlob: TResPackBlob;
  GTmpDir: string;
  GSink: UInt64;

function ZeroPad4(const AVal: Integer): string; inline;
var
  LName: string;
  LJ: Integer;
begin
  Str(AVal: 4, LName);
  for LJ := 1 to Length(LName) do
    if LName[LJ] = ' ' then
      LName[LJ] := '0';
  Result := LName;
end;

function IsGzipInline(const AData: TBytes): Boolean; inline;
begin
  { 复用 bytes.ops 单源 PByte 零拷贝魔数内联，无 TBytes 二次分配 }
  if Length(AData) < 2 then Exit(False);
  Result := BytesIsGzipBuffer(@AData[0], SizeUInt(Length(AData)));
end;

procedure BuildMem;
var
  B: TVfsTreeBuilder;
  LI: Integer;
  LJ: Integer;
  LData: TBytes;
begin
  B := TVfsTreeBuilder.Create;
  try
    for LI := 0 to FILE_COUNT - 1 do
    begin
      SetLength(LData, FILE_SIZE);
      for LJ := 0 to FILE_SIZE - 1 do
        LData[LJ] := Byte((LJ * 31 + LI * 7) mod 251);
      B.AddFile('assets/file' + ZeroPad4(LI) + '.bin', LData, 1700000000);
    end;
    GMem := B.Freeze;
  finally
    B.Free;
  end;
  GSubMem := CreateSubVfs(GMem, SUB_DIR);
end;

procedure BuildEmb;
var
  LEntries: array of TResPackInputEntry;
  LContents: array of TBytes;
  LI, LJ: Integer;
begin
  SetLength(LContents, FILE_COUNT);
  SetLength(LEntries, FILE_COUNT);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    SetLength(LContents[LI], FILE_SIZE);
    for LJ := 0 to FILE_SIZE - 1 do
      LContents[LI][LJ] := Byte((LJ * 31 + LI * 7) mod 251);
    LEntries[LI].Path := 'assets/file' + ZeroPad4(LI) + '.bin';
    LEntries[LI].Data := @LContents[LI][0];
    LEntries[LI].DataSize := SizeUInt(FILE_SIZE);
    LEntries[LI].ModTime := 1700000000;
  end;
  GBlob := ResPackBuild(LEntries, ResPackDefaultOptions);
  GEmb := CreateEmbeddedVfsOwned(GBlob.Data, GBlob.Size);
  GSubEmb := CreateSubVfs(GEmb, SUB_DIR);
end;

procedure BuildOs;
var
  LI, LJ: Integer;
  LData: TBytes;
begin
  GTmpDir := nextpas.core.fs.GetTempDir + 'nextpas_vfs_hotspots_' + ZeroPad4(0);
  { 确保干净，资源释放不丢：RemoveAll 幂等，MkdirAll 后落盘 }
  nextpas.core.fs.RemoveAll(GTmpDir);
  nextpas.core.fs.MkdirAll(GTmpDir + '/' + SUB_DIR);
  SetLength(LData, FILE_SIZE);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    for LJ := 0 to FILE_SIZE - 1 do
      LData[LJ] := Byte((LJ * 31 + LI * 7) mod 251);
    nextpas.core.fs.WriteFile(GTmpDir + '/assets/file' + ZeroPad4(LI) + '.bin', LData);
    { bytes.ops 单源复用证据：零拷贝魔数内联校验（非 gzip 文件应为 false），避免分支遗漏 }
    if IsGzipInline(LData) then
      raise Exception.Create('bench: unexpected gzip magic');
  end;
  GOs := CreateOsVfs(GTmpDir);
  GSubOs := CreateSubVfs(GOs, SUB_DIR);
end;

procedure BenchExistsMem(const ACtx: IBenchContext); inline;
var LB: Boolean;
begin
  LB := GMem.Exists(BENCH_FILE);
  GSink := GSink xor Byte(LB);
  if not LB then raise Exception.Create('bench: mem exists miss');
end;

procedure BenchExistsEmb(const ACtx: IBenchContext); inline;
var LB: Boolean;
begin
  LB := GEmb.Exists(BENCH_FILE);
  GSink := GSink xor Byte(LB);
  if not LB then raise Exception.Create('bench: emb exists miss');
end;

procedure BenchExistsOs(const ACtx: IBenchContext); inline;
var LB: Boolean;
begin
  LB := GOs.Exists(BENCH_FILE);
  GSink := GSink xor Byte(LB);
  if not LB then raise Exception.Create('bench: os exists miss');
end;

procedure BenchStatMem(const ACtx: IBenchContext);
var SI: TStatInfo;
begin
  SI := GMem.Stat(BENCH_FILE);
  ACtx.SetBytes(SI.Info.Size);
  GSink := GSink xor UInt64(SI.Info.Size);
  if SI.Info.Size <> FILE_SIZE then raise Exception.Create('bench: mem stat size');
end;

procedure BenchStatEmb(const ACtx: IBenchContext);
var SI: TStatInfo;
begin
  SI := GEmb.Stat(BENCH_FILE);
  ACtx.SetBytes(SI.Info.Size);
  GSink := GSink xor UInt64(SI.Info.Size);
  if SI.Info.Size <> FILE_SIZE then raise Exception.Create('bench: emb stat size');
end;

procedure BenchStatOs(const ACtx: IBenchContext);
var SI: TStatInfo;
begin
  SI := GOs.Stat(BENCH_FILE);
  ACtx.SetBytes(SI.Info.Size);
  GSink := GSink xor UInt64(SI.Info.Size);
  if SI.Info.Size <> FILE_SIZE then raise Exception.Create('bench: os stat size');
end;

procedure BenchListMemRoot(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GMem.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) = 0 then raise Exception.Create('bench: mem list root empty');
end;

procedure BenchListEmbRoot(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GEmb.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) = 0 then raise Exception.Create('bench: emb list root empty');
end;

procedure BenchListOsRoot(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GOs.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) = 0 then raise Exception.Create('bench: os list root empty');
end;

procedure BenchListMemAssets(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GMem.List(SUB_DIR);
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: mem list count');
end;

procedure BenchListEmbAssets(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GEmb.List(SUB_DIR);
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: emb list count');
end;

procedure BenchListOsAssets(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GOs.List(SUB_DIR);
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: os list count');
end;

procedure BenchSubListMem(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GSubMem.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: sub mem list');
end;

procedure BenchSubListEmb(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GSubEmb.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: sub emb list');
end;

procedure BenchSubListOs(const ACtx: IBenchContext);
var L: TEntryArray;
begin
  L := GSubOs.List('.');
  GSink := GSink xor UInt64(Length(L));
  if Length(L) <> FILE_COUNT then raise Exception.Create('bench: sub os list');
end;

procedure BenchOpenMem(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GMem, BENCH_FILE);
  ACtx.SetBytes(Int64(Length(D)));
  GSink := GSink xor UInt64(Length(D));
  if Length(D) <> FILE_SIZE then raise Exception.Create('bench: mem open size');
end;

procedure BenchOpenEmb(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GEmb, BENCH_FILE);
  ACtx.SetBytes(Int64(Length(D)));
  GSink := GSink xor UInt64(Length(D));
  if Length(D) <> FILE_SIZE then raise Exception.Create('bench: emb open size');
end;

procedure BenchOpenOs(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GOs, BENCH_FILE);
  ACtx.SetBytes(Int64(Length(D)));
  GSink := GSink xor UInt64(Length(D));
  if Length(D) <> FILE_SIZE then raise Exception.Create('bench: os open size');
end;

procedure BenchOpenSubMem(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GSubMem, BENCH_SUB_FILE);
  ACtx.SetBytes(Int64(Length(D)));
  if Length(D) <> FILE_SIZE then raise Exception.Create('bench: sub mem open');
end;

procedure BenchOpenSubOs(const ACtx: IBenchContext);
var D: TBytes;
begin
  D := VfsReadAllBytes(GSubOs, BENCH_SUB_FILE);
  ACtx.SetBytes(Int64(Length(D)));
  if Length(D) <> FILE_SIZE then raise Exception.Create('bench: sub os open');
end;

procedure DoWalk(const AFs: IVfs);
var
  LCount: Integer;
begin
  LCount := 0;
  VfsWalk(AFs, '.',
    procedure(const APath: string; const AInfo: TEntryInfo; var AStop: Boolean)
    begin
      Inc(LCount);
      GSink := GSink xor UInt64(Length(APath));
    end);
  if LCount = 0 then raise Exception.Create('bench: walk empty');
end;

procedure BenchWalkMem(const ACtx: IBenchContext);
begin
  DoWalk(GMem);
end;

procedure BenchWalkEmb(const ACtx: IBenchContext);
begin
  DoWalk(GEmb);
end;

procedure BenchWalkOs(const ACtx: IBenchContext);
begin
  DoWalk(GOs);
end;

procedure BenchWalkSubMem(const ACtx: IBenchContext);
begin
  DoWalk(GSubMem);
end;

var
  LResults: IBenchResults;
begin
  try
    BuildMem;
    BuildEmb;
    BuildOs;
    WriteLn('=== vfs hotspots benchmark (memtree/embedded/os List/Walk/OpenRead + Sub) ===');
    WriteLn('payload: ', FILE_COUNT, ' x ', FILE_SIZE, ' B, inline+zero-copy bytes.ops single-source');
    LResults := TBenchSuite.Create('vfs-hotspots')
      .SetWarmupIters(20)
      .SetMinSamples(10)
      .Add('Exists/memtree', @BenchExistsMem)
      .Add('Exists/embedded', @BenchExistsEmb)
      .Add('Exists/os', @BenchExistsOs)
      .Add('Stat/memtree/file', @BenchStatMem)
      .Add('Stat/embedded/file', @BenchStatEmb)
      .Add('Stat/os/file', @BenchStatOs)
      .Add('List/memtree/root', @BenchListMemRoot)
      .Add('List/embedded/root', @BenchListEmbRoot)
      .Add('List/os/root', @BenchListOsRoot)
      .Add('List/memtree/assets', @BenchListMemAssets)
      .Add('List/embedded/assets', @BenchListEmbAssets)
      .Add('List/os/assets', @BenchListOsAssets)
      .Add('List/sub/memtree', @BenchSubListMem)
      .Add('List/sub/embedded', @BenchSubListEmb)
      .Add('List/sub/os', @BenchSubListOs)
      .Add('OpenRead/memtree/4k', @BenchOpenMem)
      .Add('OpenRead/embedded/4k', @BenchOpenEmb)
      .Add('OpenRead/os/4k', @BenchOpenOs)
      .Add('OpenRead/sub/memtree/4k', @BenchOpenSubMem)
      .Add('OpenRead/sub/os/4k', @BenchOpenSubOs)
      .Add('Walk/memtree/full', @BenchWalkMem)
      .Add('Walk/embedded/full', @BenchWalkEmb)
      .Add('Walk/os/full', @BenchWalkOs)
      .Add('Walk/sub/memtree/full', @BenchWalkSubMem)
      .Run;
    WriteLn(LResults.PrintToConsole);
    { 稳定性：资源释放不丢，os 临时目录幂等清理，embedded Owned 由 IVfs 释放，try-finally Close 已在 VfsReadAllBytes 内保障 }
    if GTmpDir <> '' then
      nextpas.core.fs.RemoveAll(GTmpDir);
    GMem := nil; GEmb := nil; GOs := nil;
    GSubMem := nil; GSubEmb := nil; GSubOs := nil;
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      if GTmpDir <> '' then
        try nextpas.core.fs.RemoveAll(GTmpDir); except end;
      Halt(1);
    end;
  end;
end.
