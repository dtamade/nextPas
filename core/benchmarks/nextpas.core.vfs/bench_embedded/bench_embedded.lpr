program bench_embedded;
{$I nextpas.core.settings.inc}
{** @desc embedded 独立热点基准：List/Walk/OpenRead 热路径，零拷贝切片 + 64槽 SpinLock 池化 inline 复用 bytes.ops 单源。 }
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.vfs,
  nextpas.core.respack;

const FILE_COUNT=64; FILE_SIZE=4096;
var GEmb,GSub:IVfs; GBlob:TResPackBlob; GSink:UInt64;

function ZeroPad4(const AVal:Integer):string; inline;
var LName:string; LJ:Integer; begin Str(AVal:4,LName); for LJ:=1 to Length(LName) do if LName[LJ]=' ' then LName[LJ]:='0'; Result:=LName; end;

procedure BuildEmb;
var LEntries:array of TResPackInputEntry; LContents:array of TBytes; LI,LJ:Integer;
begin
  SetLength(LContents,FILE_COUNT); SetLength(LEntries,FILE_COUNT);
  for LI:=0 to FILE_COUNT-1 do
  begin SetLength(LContents[LI],FILE_SIZE); for LJ:=0 to FILE_SIZE-1 do LContents[LI][LJ]:=Byte((LJ*31+LI*7) mod 251);
    LEntries[LI].Path:='assets/file'+ZeroPad4(LI)+'.bin'; LEntries[LI].Data:=@LContents[LI][0]; LEntries[LI].DataSize:=SizeUInt(FILE_SIZE); LEntries[LI].ModTime:=1700000000; end;
  GBlob:=ResPackBuild(LEntries,ResPackDefaultOptions);
  GEmb:=CreateEmbeddedVfsOwned(GBlob.Data,GBlob.Size); GSub:=CreateSubVfs(GEmb,'assets');
end;

procedure BenchListRoot(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GEmb.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)=0 then raise Exception.Create('emb list root'); end;
procedure BenchListAssets(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GEmb.List('assets'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('emb list assets'); end;
procedure BenchListSub(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GSub.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('emb sub list'); end;
procedure BenchOpen(const ACtx:IBenchContext); var D:TBytes; begin D:=VfsReadAllBytes(GEmb,'assets/file0000.bin'); ACtx.SetBytes(Length(D)); GSink:=GSink xor UInt64(Length(D)); if Length(D)<>FILE_SIZE then raise Exception.Create('emb open'); end;
procedure BenchWalk(const ACtx:IBenchContext); var C:Integer; begin C:=0; VfsWalk(GEmb,'.',procedure(const APath:string; const AInfo:TEntryInfo; var AStop:Boolean) begin Inc(C); GSink:=GSink xor UInt64(Length(APath)); end); if C=0 then raise Exception.Create('emb walk'); end;
procedure BenchStat(const ACtx:IBenchContext); var SI:TStatInfo; begin SI:=GEmb.Stat('assets/file0000.bin'); ACtx.SetBytes(SI.Info.Size); if SI.Info.Size<>FILE_SIZE then raise Exception.Create('emb stat'); end;

begin
  try BuildEmb; WriteLn('=== vfs embedded hotspots (List/Walk/OpenRead) ===');
    TBenchSuite.Create('vfs-embedded').SetWarmupIters(20).SetMinSamples(10)
      .Add('Stat/embedded/file',@BenchStat)
      .Add('List/embedded/root',@BenchListRoot)
      .Add('List/embedded/assets',@BenchListAssets)
      .Add('List/sub/embedded',@BenchListSub)
      .Add('OpenRead/embedded/4k',@BenchOpen)
      .Add('Walk/embedded/full',@BenchWalk).Run;
    GEmb:=nil; GSub:=nil;
  except on E:Exception do begin WriteLn('bench: ',E.Message); Halt(1); end; end;
end.
