program bench_os;
{$I nextpas.core.settings.inc}
{** @desc os 独立热点基准：List/Walk/OpenRead 热路径，fs seam 句柄开销 inline 零拷贝 bytes.ops 单源补充 per-backend 独立证据。 }
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.vfs,
  nextpas.core.fs;

const FILE_COUNT=64; FILE_SIZE=4096;
var GOs,GSub:IVfs; GTmp:string; GSink:UInt64;

function ZeroPad4(const AVal:Integer):string; inline;
var LName:string; LJ:Integer; begin Str(AVal:4,LName); for LJ:=1 to Length(LName) do if LName[LJ]=' ' then LName[LJ]:='0'; Result:=LName; end;

procedure BuildOs;
var LI,LJ:Integer; LData:TBytes;
begin
  GTmp:=nextpas.core.fs.GetTempDir+'nextpas_vfs_os_'+ZeroPad4(0);
  nextpas.core.fs.RemoveAll(GTmp); nextpas.core.fs.MkdirAll(GTmp+'/assets');
  SetLength(LData,FILE_SIZE);
  for LI:=0 to FILE_COUNT-1 do
  begin for LJ:=0 to FILE_SIZE-1 do LData[LJ]:=Byte((LJ*31+LI*7) mod 251);
    nextpas.core.fs.WriteFile(GTmp+'/assets/file'+ZeroPad4(LI)+'.bin',LData); end;
  GOs:=CreateOsVfs(GTmp); GSub:=CreateSubVfs(GOs,'assets');
end;

procedure BenchListRoot(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GOs.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)=0 then raise Exception.Create('os list root'); end;
procedure BenchListAssets(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GOs.List('assets'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('os list assets'); end;
procedure BenchListSub(const ACtx:IBenchContext); var L:TEntryArray; begin L:=GSub.List('.'); GSink:=GSink xor UInt64(Length(L)); if Length(L)<>FILE_COUNT then raise Exception.Create('os sub list'); end;
procedure BenchOpen(const ACtx:IBenchContext); var D:TBytes; begin D:=VfsReadAllBytes(GOs,'assets/file0000.bin'); ACtx.SetBytes(Length(D)); GSink:=GSink xor UInt64(Length(D)); if Length(D)<>FILE_SIZE then raise Exception.Create('os open'); end;
procedure BenchWalk(const ACtx:IBenchContext); var C:Integer; begin C:=0; VfsWalk(GOs,'.',procedure(const APath:string; const AInfo:TEntryInfo; var AStop:Boolean) begin Inc(C); GSink:=GSink xor UInt64(Length(APath)); end); if C=0 then raise Exception.Create('os walk'); end;
procedure BenchStat(const ACtx:IBenchContext); var SI:TStatInfo; begin SI:=GOs.Stat('assets/file0000.bin'); ACtx.SetBytes(SI.Info.Size); if SI.Info.Size<>FILE_SIZE then raise Exception.Create('os stat'); end;

begin
  try BuildOs; WriteLn('=== vfs os hotspots (List/Walk/OpenRead) ===');
    TBenchSuite.Create('vfs-os').SetWarmupIters(20).SetMinSamples(10)
      .Add('Stat/os/file',@BenchStat)
      .Add('List/os/root',@BenchListRoot)
      .Add('List/os/assets',@BenchListAssets)
      .Add('List/sub/os',@BenchListSub)
      .Add('OpenRead/os/4k',@BenchOpen)
      .Add('Walk/os/full',@BenchWalk).Run;
    if GTmp<>'' then nextpas.core.fs.RemoveAll(GTmp); GOs:=nil; GSub:=nil;
  except on E:Exception do begin WriteLn('bench: ',E.Message); if GTmp<>'' then try nextpas.core.fs.RemoveAll(GTmp); except end; Halt(1); end; end;
end.
