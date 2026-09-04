program bench_memtree;
{$I nextpas.core.settings.inc}
{** @desc memtree 独立热点基准：List/Walk/OpenRead 热路径，inline 零拷贝 bytes.ops 单源补充 bench_hotspots 的 per-backend 独立证据。 }
uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.vfs,
  nextpas.core.bytes.ops;

const FILE_COUNT = 64; FILE_SIZE = 4096;
var GMem, GSub: IVfs; GSink: UInt64;

function ZeroPad4(const AVal: Integer): string; inline;
var LName: string; LJ: Integer;
begin Str(AVal:4,LName); for LJ:=1 to Length(LName) do if LName[LJ]=' ' then LName[LJ]:='0'; Result:=LName; end;

procedure BuildMem;
var B: TVfsTreeBuilder; LI,LJ: Integer; LData: TBytes;
begin
  B:=TVfsTreeBuilder.Create; try
    for LI:=0 to FILE_COUNT-1 do
    begin SetLength(LData,FILE_SIZE); for LJ:=0 to FILE_SIZE-1 do LData[LJ]:=Byte((LJ*31+LI*7) mod 251);
      B.AddFile('assets/file'+ZeroPad4(LI)+'.bin',LData,1700000000); end;
    GMem:=B.Freeze; finally B.Free; end;
  GSub:=CreateSubVfs(GMem,'assets');
end;

procedure BenchListRoot(const ACtx: IBenchContext); var L:TEntryArray; begin L:=GMem.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)=0 then raise Exception.Create('mem list root'); end;
procedure BenchListAssets(const ACtx: IBenchContext); var L:TEntryArray; begin L:=GMem.List('assets'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('mem list assets'); end;
procedure BenchListSub(const ACtx: IBenchContext); var L:TEntryArray; begin L:=GSub.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('mem sub list'); end;
procedure BenchOpen(const ACtx: IBenchContext); var D:TBytes; begin D:=VfsReadAllBytes(GMem,'assets/file0000.bin'); ACtx.SetBytes(Length(D)); GSink:=GSink xor UInt64(Length(D)); if Length(D)<>FILE_SIZE then raise Exception.Create('mem open'); end;
procedure BenchWalk(const ACtx: IBenchContext); var C:Integer; begin C:=0; VfsWalk(GMem,'.',procedure(const APath:string; const AInfo:TEntryInfo; var AStop:Boolean) begin Inc(C); GSink:=GSink xor UInt64(Length(APath)); end); if C=0 then raise Exception.Create('mem walk'); end;
procedure BenchStat(const ACtx: IBenchContext); var SI:TStatInfo; begin SI:=GMem.Stat('assets/file0000.bin'); ACtx.SetBytes(SI.Info.Size); if SI.Info.Size<>FILE_SIZE then raise Exception.Create('mem stat'); end;

begin
  try BuildMem; WriteLn('=== vfs memtree hotspots (List/Walk/OpenRead) ===');
    TBenchSuite.Create('vfs-memtree').SetWarmupIters(20).SetMinSamples(10)
      .Add('Stat/memtree/file',@BenchStat)
      .Add('List/memtree/root',@BenchListRoot)
      .Add('List/memtree/assets',@BenchListAssets)
      .Add('List/sub/memtree',@BenchListSub)
      .Add('OpenRead/memtree/4k',@BenchOpen)
      .Add('Walk/memtree/full',@BenchWalk).Run;
    GMem:=nil; GSub:=nil;
  except on E:Exception do begin WriteLn('bench: ',E.Message); Halt(1); end; end;
end.
