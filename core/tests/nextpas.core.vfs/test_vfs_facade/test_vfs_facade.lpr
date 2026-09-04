program test_vfs_facade;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.respack,
  nextpas.core.compress,
  nextpas.core.text.view,
  nextpas.core.vfs;

{ 门面层契约：consumer 只经门面函数消费任意后端。
  核心断言是"开发态/发布态工厂切换"——同一 consumer 签名函数在
  memtree/embedded/os 三后端上产出逐字符一致的树签名（README 后端矩阵承诺）；
  另覆盖便利包装（ReadAllBytes/Text/Stat/List）、VfsWalk 早停（INV-V11）
  与共享排序例程的门面出口。 }

const
  FIX_COUNT = 5;

var
  T: TTestSuite;
  G_FixPath: array[0..FIX_COUNT - 1] of string;
  G_FixMod: array[0..FIX_COUNT - 1] of Int64;
  G_TmpDir: string;
  G_EmbeddedBlob: TResPackBlob;
  G_Sig: string;
  G_Visited: Integer;

{ ── 夹具（与 conformance 同一棵树） ── }

procedure InitFixture;
begin
  G_FixPath[0] := 'assets/app.js';    G_FixMod[0] := 100;
  G_FixPath[1] := 'assets/lib/x.js';  G_FixMod[1] := 200;
  G_FixPath[2] := 'docs/指南.md';      G_FixMod[2] := 300;
  G_FixPath[3] := 'empty.txt';        G_FixMod[3] := 400;
  G_FixPath[4] := 'index.html';       G_FixMod[4] := 500;
end;

function StrToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Byte(S[I]);
end;

function FixBytes(const AI: Integer): TBytes;
begin
  case AI of
    0: Result := StrToBytes('console.log(1);');
    1: Result := StrToBytes('export default 1;');
    2: Result := StrToBytes('中文内容-指南');
    3: Result := nil;
    4: Result := StrToBytes('<html>ok</html>');
  else
    Result := nil;
  end;
end;

procedure BuildOsTree;
var
  I: Integer;
begin
  G_TmpDir := '/tmp/nextpas_vfs_facade';
  nextpas.core.fs.RemoveAll(G_TmpDir);
  nextpas.core.fs.MkdirAll(G_TmpDir + '/assets/lib');
  nextpas.core.fs.MkdirAll(G_TmpDir + '/docs');
  for I := 0 to FIX_COUNT - 1 do
    nextpas.core.fs.WriteFile(G_TmpDir + '/' + G_FixPath[I], FixBytes(I));
end;

procedure RemoveOsTree;
begin
  nextpas.core.fs.RemoveAll(G_TmpDir);
end;

{ ── 三后端构造 ── }

function MakeMemtreeVfs: IVfs;
var
  B: TVfsTreeBuilder;
  I: Integer;
begin
  B := TVfsTreeBuilder.Create;
  try
    for I := 0 to FIX_COUNT - 1 do
      B.AddFile(G_FixPath[I], FixBytes(I), G_FixMod[I]);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

function MakeEmbeddedVfs: IVfs;
var
  Inputs: TResPackInputArray;
  Bufs: array of TBytes;
  I: Integer;
begin
  SetLength(Bufs, FIX_COUNT);
  SetLength(Inputs, FIX_COUNT);
  for I := 0 to FIX_COUNT - 1 do
  begin
    Bufs[I] := FixBytes(I);
    Inputs[I] := Default(TResPackInputEntry);
    Inputs[I].Path := G_FixPath[I];
    if Length(Bufs[I]) > 0 then
      Inputs[I].Data := @Bufs[I][0]
    else
      Inputs[I].Data := nil;
    Inputs[I].DataSize := SizeUInt(Length(Bufs[I]));
    Inputs[I].ModTime := G_FixMod[I];
  end;
  G_EmbeddedBlob := ResPackBuild(Inputs, ResPackDefaultOptions);
  { Owned：VFS 归还 blob，gate 不再 FreeBlob }
  Result := CreateEmbeddedVfsOwned(G_EmbeddedBlob.Data, G_EmbeddedBlob.Size);
end;

{ ── 工具 ── }

function DecS(AValue: Integer): string;
var
  D: string;
begin
  D := '';
  repeat
    D := Char(Ord('0') + AValue mod 10) + D;
    AValue := AValue div 10;
  until AValue = 0;
  Result := D;
end;

procedure SigVisit(const APath: string; const AInfo: TEntryInfo;
  var AStop: Boolean);
begin
  { 目录 Size 是后端事实值（os=磁盘 inode 大小，memtree/embedded=0），
    不属于可移植契约；签名只取名称序、IsDir 与文件大小 }
  if AInfo.IsDir then
    G_Sig := G_Sig + '|' + APath + '=dir'
  else
    G_Sig := G_Sig + '|' + APath + '=' + DecS(AInfo.Size);
end;

{ 唯一的"consumer 代码"：只经门面 API 消费，模拟装配层换后端 }
function TreeSignature(const AFs: IVfs): string;
begin
  G_Sig := '';
  VfsWalk(AFs, '.', @SigVisit);
  Result := G_Sig;
end;

const
  TREE_SIG = '|.=dir|assets=dir|assets/app.js=15|assets/lib=dir'
    + '|assets/lib/x.js=17|docs=dir|docs/指南.md=19|empty.txt=0'
    + '|index.html=15';

{ ── 用例 ── }

procedure TestFactorySwitch;
begin
  Check(TreeSignature(MakeMemtreeVfs) = TREE_SIG,
    'factory switch: memtree signature');
  Check(TreeSignature(MakeEmbeddedVfs) = TREE_SIG,
    'factory switch: embedded signature identical');
  BuildOsTree;
  try
    Check(TreeSignature(CreateOsVfs(G_TmpDir)) = TREE_SIG,
      'factory switch: os signature identical (dev/prod promise)');
  finally
    RemoveOsTree;
  end;
end;

procedure TestReadAllBytes;
var
  FsArr: array[0..2] of IVfs;
  Labels: array[0..2] of string;
  B: TBytes;
  I: Integer;
begin
  FsArr[0] := MakeMemtreeVfs;   Labels[0] := 'memtree';
  FsArr[1] := MakeEmbeddedVfs;  Labels[1] := 'embedded';
  BuildOsTree;
  FsArr[2] := CreateOsVfs(G_TmpDir); Labels[2] := 'os';
  try
    for I := 0 to 2 do
    begin
      B := VfsReadAllBytes(FsArr[I], 'index.html');
      Check(Length(B) = 15, Labels[I] + ' readallbytes size');
      Check((B[0] = Ord('<')) and (B[14] = Ord('>')),
        Labels[I] + ' readallbytes ends');

      B := VfsReadAllBytes(FsArr[I], 'empty.txt');
      Check(Length(B) = 0, Labels[I] + ' readallbytes empty file');
    end;
  finally
    FsArr[0] := nil;
    FsArr[1] := nil;
    FsArr[2] := nil;
    RemoveOsTree;
  end;
end;

procedure TestReadAllTextUnicode;
var
  FsArr: array[0..2] of IVfs;
  I: Integer;
begin
  FsArr[0] := MakeMemtreeVfs;
  FsArr[1] := MakeEmbeddedVfs;
  BuildOsTree;
  FsArr[2] := CreateOsVfs(G_TmpDir);
  try
    for I := 0 to 2 do
      Check(VfsReadAllText(FsArr[I], 'docs/指南.md') = '中文内容-指南',
        'readalltext unicode [' + DecS(I) + ']');
  finally
    FsArr[0] := nil;
    FsArr[1] := nil;
    FsArr[2] := nil;
    RemoveOsTree;
  end;
end;

procedure TestStatListWrappers;
var
  Fs: IVfs;
  SI: TStatInfo;
  L: TEntryArray;
begin
  Fs := MakeEmbeddedVfs;
  try
    SI := VfsStat(Fs, 'assets/lib/x.js');
    Check((not SI.Info.IsDir) and (SI.Info.Size = 17)
      and (SI.Info.ModTime = 200), 'wrapper stat fields');
    SI := VfsStat(Fs, '.');
    Check(SI.Info.IsDir, 'wrapper stat root is dir');

    L := VfsList(Fs, '.');
    Check(Length(L) = 4, 'wrapper list root count');
    Check((L[0].Name = 'assets') and (L[3].Name = 'index.html'),
      'wrapper list sorted');

    L := VfsList(Fs, 'assets');
    Check(Length(L) = 2, 'wrapper list subdir count');
  finally
    Fs := nil;
  end;
end;

procedure StopAfterAssets(const APath: string; const AInfo: TEntryInfo;
  var AStop: Boolean);
begin
  Inc(G_Visited);
  if APath = 'assets' then
    AStop := True;
end;

procedure TestWalkEarlyStop;
var
  Fs: IVfs;
begin
  Fs := MakeMemtreeVfs;
  try
    G_Visited := 0;
    VfsWalk(Fs, '.', @StopAfterAssets);
    { 访问 '.' 与 'assets' 后置停：不得进入 assets 子树 }
    Check(G_Visited = 2, 'walk early stop visits exactly 2');
  finally
    Fs := nil;
  end;
end;

procedure TestSortHelperViaFacade;
var
  L: TEntryArray;
begin
  SetLength(L, 3);
  L[0].Name := 'z.txt';  L[0].IsDir := False;
  L[1].Name := 'a/b';    L[1].IsDir := True;
  L[2].Name := 'a.txt';  L[2].IsDir := False;
  VfsSortEntries(L);
  Check((L[0].Name = 'a.txt') and (L[1].Name = 'a/b') and (L[2].Name = 'z.txt'),
    'sort helper byte order (a.txt < a/b < z.txt)');
  Check(VfsNameCompare('abc', 'abd') < 0, 'name compare less');
  Check(VfsNameCompare('x', 'x') = 0, 'name compare equal');
  Check(VfsNameCompare('b', 'aZ') > 0, 'name compare byte order');
end;

{ ── 门面全入口覆盖：视图/装饰器/错误类（仅经门面 API 装配） ── }

function MakeTinyTree(const AName, AContent: string): IVfs;
var
  B: TVfsTreeBuilder;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile(AName, StrToBytes(AContent), 7);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

procedure TestSubViewViaFacade;
var
  Fs, Sub: IVfs;
  SI: TStatInfo;
  L: TEntryArray;
begin
  Fs := MakeMemtreeVfs;
  Sub := CreateSubVfs(Fs, 'assets');
  SI := VfsStat(Sub, '.');
  Check(SI.Info.IsDir, 'facade sub root is dir');
  SI := VfsStat(Sub, 'app.js');
  Check((not SI.Info.IsDir) and (SI.Info.Size = 15),
    'facade sub stat remapped');
  L := VfsList(Sub, '.');
  Check((Length(L) = 2) and (L[0].Name = 'app.js') and (L[1].Name = 'lib'),
    'facade sub list remapped+sorted');
  Check(VfsReadAllText(Sub, 'app.js') = 'console.log(1);',
    'facade sub read');
  Check(not Sub.Exists('index.html'), 'facade sub cannot see outside');
  try
    VfsStat(Sub, 'index.html');
    Check(False, 'facade sub missing must raise');
  except
    on E: EVfsNotFound do
      Check(E.Path = 'index.html', 'facade sub error path in sub view');
  end;
end;

procedure TestMountViaFacade;
var
  A, B, C, M: IVfs;
  BB, BC: TVfsTreeBuilder;
  L: TEntryArray;
begin
  A := MakeTinyTree('inner.txt', 'in-a');
  BB := TVfsTreeBuilder.Create;
  try
    BB.AddFile('inner.txt', StrToBytes('in-b'), 2);
    BB.AddFile('root.txt', StrToBytes('r'), 3);
    B := BB.Freeze;
  finally
    BB.Free;
  end;
  M := CreateMountedVfs([VfsMountEntry('a', A), VfsMountEntry('.', B)]);
  Check(VfsReadAllText(M, 'a/inner.txt') = 'in-a', 'facade mount prefix hit');
  Check(VfsReadAllText(M, 'root.txt') = 'r', 'facade mount root fallback');
  L := VfsList(M, '.');
  Check((Length(L) = 3) and (L[0].Name = 'a')
    and (L[1].Name = 'inner.txt') and (L[2].Name = 'root.txt'),
    'facade mount root merged+sorted');
  BC := TVfsTreeBuilder.Create;
  try
    BC.AddFile('deep.txt', StrToBytes('deep'), 4);
    C := BC.Freeze;
  finally
    BC.Free;
  end;
  M := CreateMountedVfs([VfsMountEntry('a', A), VfsMountEntry('a/sub', C)]);
  Check(VfsReadAllText(M, 'a/sub/deep.txt') = 'deep',
    'facade mount longest prefix wins');
  Check(VfsReadAllText(M, 'a/inner.txt') = 'in-a',
    'facade mount shorter prefix kept');
end;

procedure TestOverlayViaFacade;
var
  Base, Patch, O: IVfs;
  BB, BP: TVfsTreeBuilder;
  L: TEntryArray;
begin
  BB := TVfsTreeBuilder.Create;
  try
    BB.AddFile('cfg.txt', StrToBytes('base'), 1);
    BB.AddFile('only-base.txt', StrToBytes('b'), 2);
    Base := BB.Freeze;
  finally
    BB.Free;
  end;
  BP := TVfsTreeBuilder.Create;
  try
    BP.AddFile('cfg.txt', StrToBytes('patch'), 3);
    Patch := BP.Freeze;
  finally
    BP.Free;
  end;
  O := CreateOverlayVfs([Patch, Base]);
  Check(VfsReadAllText(O, 'cfg.txt') = 'patch',
    'facade overlay first wins');
  Check(VfsReadAllText(O, 'only-base.txt') = 'b',
    'facade overlay fallthrough');
  L := VfsList(O, '.');
  Check((Length(L) = 2) and (L[0].Name = 'cfg.txt')
    and (L[1].Name = 'only-base.txt'),
    'facade overlay list dedup+sorted');
end;

function UpperTransform(const AData: TBytes): TBytes;
var
  I: Integer;
begin
  Result := Copy(AData);
  for I := 0 to High(Result) do
    if (Result[I] >= Ord('a')) and (Result[I] <= Ord('z')) then
      Result[I] := Result[I] - 32;
end;

function HtmlHeaderPred(const AHeader: TBytes;
  const ATotalSize: Int64): Boolean;
begin
  Result := (ATotalSize <> 0) and (Length(AHeader) > 0)
    and (AHeader[0] = Ord('<'));
end;

procedure TestTransformViaFacade;
var
  Inner, Tr: IVfs;
  SI: TStatInfo;
  Tag: string;
begin
  Inner := MakeMemtreeVfs;
  Tr := CreateTransformingVfs(Inner, @UpperTransform, nil);
  Check(VfsReadAllText(Tr, 'index.html') = '<HTML>OK</HTML>',
    'facade transform open');
  SI := VfsStat(Tr, 'index.html');
  Check(SI.Info.Size = 15, 'facade transform stat size');
  Check(not (Tr as IVfsETag).TryGetETag('index.html', Tag),
    'facade transform etag disabled');
  Tr := CreateTransformingVfs(Inner, @UpperTransform, nil, @HtmlHeaderPred);
  Check(VfsReadAllText(Tr, 'index.html') = '<HTML>OK</HTML>',
    'facade transform headerpred hit');
  Check(VfsReadAllText(Tr, 'assets/app.js') = 'console.log(1);',
    'facade transform headerpred miss passthrough');
end;

procedure TestDecompressViaFacade;
var
  Inner, D: IVfs;
  B: TVfsTreeBuilder;
  Raw, Gz: TBytes;
  SI: TStatInfo;
  Got: Boolean;
begin
  Raw := StrToBytes('<html>facade gzip roundtrip 0123456789</html>');
  Gz := GzipCompress(Raw);
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('gz.txt', Gz, 30);
    B.AddFile('plain.txt', StrToBytes('plain stays'), 31);
    Inner := B.Freeze;
  finally
    B.Free;
  end;
  Check(VFS_DECOMPRESS_MAX_BYTES > 0, 'facade decompress limit re-exported');
  { 序数 tripwire：门面枚举常量与 vfs.base 声明顺序 `(daAuto, daGzip)` 锁定一致
    （源契约门文本断言声明顺序）；分支行为由下述 daGzip 强制/daAuto 自动
    用例端到端锁定，序数漂移必致其红。 }
  Check((Ord(daAuto) = 0) and (Ord(daGzip) = 1),
    'facade enum ordinals stable');
  D := CreateDecompressingVfs(Inner);
  SI := D.Stat('gz.txt');
  Check(SI.Info.Size = Int64(Length(Raw)), 'facade decompress stat size');
  Check(VfsReadAllText(D, 'gz.txt') = '<html>facade gzip roundtrip 0123456789</html>',
    'facade decompress content');
  D := CreateDecompressingVfs(Inner, daAuto);
  Check(VfsReadAllText(D, 'plain.txt') = 'plain stays',
    'facade decompress auto plain passthrough');
  D := CreateDecompressingVfs(Inner, daGzip);
  Check(VfsReadAllText(D, 'gz.txt')
    = '<html>facade gzip roundtrip 0123456789</html>',
    'facade decompress forced gzip');
  Got := False;
  try
    VfsReadAllText(D, 'plain.txt');
  except
    on E: EVfsError do Got := True;
  end;
  Check(Got, 'facade decompress forced plain must fail');
end;

procedure TestErrorClassesViaFacade;
var
  Fs: IVfs;
  S: IStream;
  LDummy: Int64;
begin
  Fs := MakeMemtreeVfs;
  try
    VfsStat(Fs, 'nope.txt');
    Check(False, 'facade notfound must raise');
  except
    on E: EVfsNotFound do
      Check((E.Op = 'stat') and (E.Path = 'nope.txt'),
        'facade notfound op/path context');
  end;
  try
    Fs.OpenRead('assets');
    Check(False, 'facade isadir must raise');
  except
    on E: EVfsIsADirectory do
      Check(E.Op = 'open', 'facade isadir op context');
  end;
  try
    VfsList(Fs, 'index.html');
    Check(False, 'facade notadir must raise');
  except
    on E: EVfsNotADirectory do
      Check(E.Op = 'list', 'facade notadir op context');
  end;
  try
    VfsStat(Fs, '/abs');
    Check(False, 'facade invalid must raise');
  except
    on E: EVfsInvalidPath do
      Check(True, 'facade invalid path class');
  end;
  Check((not Fs.Exists('nope.txt')) and (not Fs.Exists('/abs')),
    'facade exists false on missing+invalid');
  S := Fs.OpenRead('empty.txt');
  S.Close;
  try
    LDummy := S.Seek(0, soBeginning);
    Check(LDummy <> -1, 'facade closed must raise');
  except
    on E: EVfsClosed do
      Check(True, 'facade closed class after close');
  end;
end;

{ ── 视图零拷贝透传：复合视图实现 IVfsView，视图路径与字符串路径同字节 ── }

procedure CheckViewParity(const ALabel: string; const AFs: IVfs;
  const APath, AExpect: string);
var
  V: TStringView;
begin
  V := TStringView.FromStr(APath);
  Check(VfsExistsView(AFs, V) = AFs.Exists(APath),
    ALabel + ' exists parity: ' + APath);
  Check(VfsReadAllTextView(AFs, V) = AExpect,
    ALabel + ' read parity: ' + APath);
end;

procedure TestViewsViaFacade;
var
  Base, Sub, M, O, Tr, Dec: IVfs;
  V: IVfsView;
  VV: TStringView;
  Got: Boolean;
begin
  Base := MakeMemtreeVfs;
  { 结构断言：as 转换失败即红，证明非回退而是真实实现 }
  Sub := CreateSubVfs(Base, 'assets');
  V := Sub as IVfsView;
  Check(V <> nil, 'facade view: sub exposes IVfsView');
  M := CreateMountedVfs([VfsMountEntry('m', Base)]);
  V := M as IVfsView;
  Check(V <> nil, 'facade view: mount exposes IVfsView');
  O := CreateOverlayVfs([Base]);
  V := O as IVfsView;
  Check(V <> nil, 'facade view: overlay exposes IVfsView');
  Tr := CreateTransformingVfs(Base, @UpperTransform, nil);
  V := Tr as IVfsView;
  Check(V <> nil, 'facade view: transform exposes IVfsView');
  Dec := CreateDecompressingVfs(Base);
  V := Dec as IVfsView;
  Check(V <> nil, 'facade view: decompress exposes IVfsView');
  { 行为等价：视图路径与字符串路径同字节 }
  CheckViewParity('sub', Sub, 'app.js', 'console.log(1);');
  CheckViewParity('mount', M, 'm/index.html', '<html>ok</html>');
  CheckViewParity('overlay', O, 'index.html', '<html>ok</html>');
  CheckViewParity('transform', Tr, 'index.html', '<HTML>OK</HTML>');
  CheckViewParity('decompress', Dec, 'index.html', '<html>ok</html>');
  { 错误等价：缺失与非法视图路径 }
  VV := TStringView.FromStr('nope.txt');
  Check(not VfsExistsView(Sub, VV), 'facade view: sub missing false');
  Got := False;
  try
    VfsReadAllTextView(Sub, VV);
  except
    on E: EVfsNotFound do Got := E.Path = 'nope.txt';
  end;
  Check(Got, 'facade view: sub missing NotFound with sub path');
  VV := TStringView.FromStr('/abs');
  Got := False;
  try
    VfsReadAllTextView(O, VV);
  except
    on E: EVfsInvalidPath do Got := True;
  end;
  Check(Got, 'facade view: invalid path class');
end;

{ ── 注册与执行 ── }

begin
  InitFixture;

  T := TTestSuite.Create('nextpas.core.vfs.facade');
  T.Test('dev/prod factory switch', @TestFactorySwitch);
  T.Test('readallbytes three backends', @TestReadAllBytes);
  T.Test('readalltext unicode', @TestReadAllTextUnicode);
  T.Test('stat/list wrappers', @TestStatListWrappers);
  T.Test('walk early stop', @TestWalkEarlyStop);
  T.Test('sort helper via facade', @TestSortHelperViaFacade);
  T.Test('sub view via facade', @TestSubViewViaFacade);
  T.Test('mount via facade', @TestMountViaFacade);
  T.Test('overlay via facade', @TestOverlayViaFacade);
  T.Test('transform via facade', @TestTransformViaFacade);
  T.Test('decompress via facade', @TestDecompressViaFacade);
  T.Test('error classes via facade', @TestErrorClassesViaFacade);
  T.Test('views via facade', @TestViewsViaFacade);

  if not T.Run then Halt(1);
end.
