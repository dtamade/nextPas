program test_vfs_facade;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.respack,
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
  { AOwnsBlob=True：VFS 归还 blob，gate 不再 FreeBlob }
  Result := CreateEmbeddedVfs(G_EmbeddedBlob.Data, G_EmbeddedBlob.Size, True);
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

  if not T.Run then Halt(1);
end.
