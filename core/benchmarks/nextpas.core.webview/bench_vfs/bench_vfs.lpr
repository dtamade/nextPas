program bench_vfs;
{** @desc bench: VFS→IWebviewAssetProvider 适配器热路径基线。
       计时前硬校验正确性（假失败 = 假基准），暴露大文件/404 退化曲线。
       框架：nextpas.core.bench，禁自定义计时与内循环。 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.exception,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.base,
  nextpas.core.vfs,
  nextpas.core.vfs.memtree,
  nextpas.core.webview.intf,
  nextpas.core.webview.vfs;

var
  GSmallVfs, GLargeVfs: IVfs;
  GSmallProvider, GLargeProvider: IWebviewAssetProvider;
  GSinkBytes: SizeUInt = 0;

function StrBytes(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

procedure Setup;
var
  B: TVfsTreeBuilder;
  I: Integer;
  LBig: TBytes;
begin
  B := TVfsTreeBuilder.Create;
  B.AddFile('index.html', StrBytes('<html>hello webview</html>'), 0);
  B.AddFile('js/app.js', StrBytes('console.log("hi")'), 0);
  B.AddFile('style.css', StrBytes('body{margin:0}'), 0);
  B.AddFile('data.json', StrBytes('{"k":1}'), 0);
  GSmallVfs := B.Freeze;
  B.Free;
  GSmallProvider := CreateVfsAssetProvider(GSmallVfs);

  SetLength(LBig, 1024 * 1024);
  for I := 0 to High(LBig) do
    LBig[I] := Byte(I and $FF);
  B := TVfsTreeBuilder.Create;
  B.AddFile('large.bin', LBig, 0);
  B.AddFile('index.html', StrBytes('<html>large</html>'), 0);
  GLargeVfs := B.Freeze;
  B.Free;
  GLargeProvider := CreateVfsAssetProvider(GLargeVfs);
end;

procedure CheckSetup;
var
  B: TBytes;
  M: string;
begin
  if not GSmallProvider.TryResolve('index.html', B, M) then
    raise Exception.Create('setup check: index.html must resolve');
  if GSmallProvider.TryResolve('missing.txt', B, M) then
    raise Exception.Create('setup check: missing must 404');
  if not GSmallProvider.TryResolve('app/index.html', B, M) then
    raise Exception.Create('setup check: app/index.html fallback must hit');
  if not GLargeProvider.TryResolve('large.bin', B, M) then
    raise Exception.Create('setup check: large.bin must resolve');
  if Length(B) <> 1024 * 1024 then
    raise Exception.Create('setup check: large.bin size mismatch');
end;

procedure BenchSmallHit(const ACtx: IBenchContext);
var
  B: TBytes;
  M: string;
begin
  GSmallProvider.TryResolve('index.html', B, M);
  GSinkBytes := GSinkBytes + Length(B) + Length(M);
end;

procedure BenchStripFallback(const ACtx: IBenchContext);
var
  B: TBytes;
  M: string;
begin
  GSmallProvider.TryResolve('app/index.html', B, M);
  GSinkBytes := GSinkBytes + Length(B);
end;

procedure BenchMiss404(const ACtx: IBenchContext);
var
  B: TBytes;
  M: string;
begin
  GSmallProvider.TryResolve('missing.txt', B, M);
  GSinkBytes := GSinkBytes + Length(M);
end;

procedure BenchLarge1M(const ACtx: IBenchContext);
var
  B: TBytes;
  M: string;
begin
  GLargeProvider.TryResolve('large.bin', B, M);
  GSinkBytes := GSinkBytes + Length(B);
end;

var
  LSuite: IBenchSuite;
begin
  Setup;
  CheckSetup;
  LSuite := TBenchSuite.Create('vfs-provider');
  LSuite.Add('SmallHit/index.html', @BenchSmallHit);
  LSuite.Add('Fallback/app/index.html', @BenchStripFallback);
  LSuite.Add('Miss404', @BenchMiss404);
  LSuite.Add('LargeHit/1M', @BenchLarge1M);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('sink=', GSinkBytes);
end.
