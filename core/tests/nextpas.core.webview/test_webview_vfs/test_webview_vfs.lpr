program test_webview_vfs;
{ VFS 适配器门禁：纯 Pascal，无引擎依赖。
  覆盖：nil 校验、二进制安全读取、MIME 快表、前缀容错（全路径/剥首段双试）、
  空/非法路径、与 TWebviewAssetsImpl 协同的 mount 前缀无感性。
  heaptrc 0 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.vfs,
  nextpas.core.vfs.memtree,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.vfs;

function StrBytes(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

procedure TestNilVfsRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    CreateVfsAssetProvider(nil);
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'nil vfs must raise EWebviewInvalidState');
end;

procedure TestDirectHit;
var
  Bld: TVfsTreeBuilder;
  V: IVfs;
  P: IWebviewAssetProvider;
  B: TBytes;
  M: string;
begin
  Bld := TVfsTreeBuilder.Create;
  Bld.AddFile('index.html', StrBytes('<h1>hi</h1>'), 0);
  Bld.AddFile('js/app.js', StrBytes('console.log(1)'), 0);
  V := Bld.Freeze;
  Bld.Free;
  P := CreateVfsAssetProvider(V);
  Check(P.TryResolve('index.html', B, M), 'direct hit');
  Check(SameBytes(B, StrBytes('<h1>hi</h1>')), 'bytes equal');
  Check(M = 'text/html; charset=utf-8', 'mime html');

  Check(P.TryResolve('js/app.js', B, M), 'nested hit');
  Check(M = 'application/javascript; charset=utf-8', 'mime js');

  Check(not P.TryResolve('missing.txt', B, M), 'missing 404');
end;

procedure TestStripFirstSegmentFallback;
var
  Bld: TVfsTreeBuilder;
  V: IVfs;
  P: IWebviewAssetProvider;
  B: TBytes;
  M: string;
begin
  Bld := TVfsTreeBuilder.Create;
  Bld.AddFile('index.html', StrBytes('ok'), 0);
  V := Bld.Freeze;
  Bld.Free;
  P := CreateVfsAssetProvider(V);
  { bridge 透传全路径 "app/index.html" 时，适配器剥首段回退命中 }
  Check(P.TryResolve('app/index.html', B, M), 'strip fallback hit');
  Check(SameBytes(B, StrBytes('ok')), 'fallback bytes');
  Check(P.TryResolve('/app/index.html', B, M), 'leading slash stripped');
  Check(P.TryResolve('index.html', B, M), 'direct still hit');
end;

procedure TestMimeTable;
var
  Bld: TVfsTreeBuilder;
  V: IVfs;
  P: IWebviewAssetProvider;
  B: TBytes;
  M: string;
begin
  Bld := TVfsTreeBuilder.Create;
  Bld.AddFile('a.css', StrBytes('x'), 0);
  Bld.AddFile('a.json', StrBytes('{}'), 0);
  Bld.AddFile('a.bin', StrBytes(#0#1#2), 0);
  Bld.AddFile('a.svg', StrBytes('<svg/>'), 0);
  Bld.AddFile('a.avif', StrBytes('x'), 0);
  Bld.AddFile('a.woff2', StrBytes('x'), 0);
  Bld.AddFile('a.mp4', StrBytes('x'), 0);
  Bld.AddFile('a.pdf', StrBytes('x'), 0);
  Bld.AddFile('a.ts', StrBytes('x'), 0);
  V := Bld.Freeze;
  Bld.Free;
  P := CreateVfsAssetProvider(V);
  Check(P.TryResolve('a.css', B, M) and (M = 'text/css; charset=utf-8'), 'css mime');
  Check(P.TryResolve('a.json', B, M) and (M = 'application/json; charset=utf-8'), 'json mime');
  Check(P.TryResolve('a.bin', B, M) and (M = 'application/octet-stream'), 'octet fallback');
  Check(P.TryResolve('a.svg', B, M) and (M = 'image/svg+xml'), 'svg mime');
  Check(P.TryResolve('a.avif', B, M) and (M = 'image/avif'), 'avif mime');
  Check(P.TryResolve('a.woff2', B, M) and (M = 'font/woff2'), 'woff2 mime');
  Check(P.TryResolve('a.mp4', B, M) and (M = 'video/mp4'), 'mp4 mime');
  Check(P.TryResolve('a.pdf', B, M) and (M = 'application/pdf'), 'pdf mime');
  Check(P.TryResolve('a.ts', B, M) and (M = 'video/mp2t'), 'ts mime');
end;

procedure TestEmptyAndLeadingSlash;
var
  Bld: TVfsTreeBuilder;
  V: IVfs;
  P: IWebviewAssetProvider;
  B: TBytes;
  M: string;
begin
  Bld := TVfsTreeBuilder.Create;
  Bld.AddFile('index.html', StrBytes('ok'), 0);
  V := Bld.Freeze;
  Bld.Free;
  P := CreateVfsAssetProvider(V);
  Check(not P.TryResolve('', B, M), 'empty 404');
  Check(not P.TryResolve('/', B, M), 'slash only 404');
  Check(not P.TryResolve('///', B, M), 'slashes only 404');
end;

procedure TestViaAssetsImpl;
var
  Bld: TVfsTreeBuilder;
  V: IVfs;
  P: IWebviewAssetProvider;
  A: IWebviewAssets;
  B: TBytes;
  M: string;
begin
  Bld := TVfsTreeBuilder.Create;
  Bld.AddFile('index.html', StrBytes('asset'), 0);
  V := Bld.Freeze;
  Bld.Free;
  P := CreateVfsAssetProvider(V);
  A := TWebviewAssetsImpl.Create(False);
  A.MountEmbedded('', P);
  Check(A.TryResolve('index.html', B, M), 'assets mount hit');
  Check(A.TryResolve('/index.html', B, M), 'assets leading slash');
  Check(A.TryResolve('app/index.html', B, M), 'assets via prefix fallback');
  Check(not A.TryResolve('missing', B, M), 'assets 404');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.vfs');
  T.Test('nil vfs raises', @TestNilVfsRaises);
  T.Test('direct hit', @TestDirectHit);
  T.Test('strip first segment fallback', @TestStripFirstSegmentFallback);
  T.Test('mime table', @TestMimeTable);
  T.Test('empty and leading slash', @TestEmptyAndLeadingSlash);
  T.Test('via assets impl', @TestViaAssetsImpl);
  if not T.Run then Halt(1);
end.
