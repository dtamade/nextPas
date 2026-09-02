program test_vfs_conformance;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.respack,
  nextpas.core.vfs;

{ fstest.TestFS 对等物：同一夹具树分别以 memtree / embedded / os 构造，
  同一组属性过程跑三遍（INV-V7）；sub 视图对每个后端再跑一轮（P7）；
  embedded 附加零拷贝断言（P8）。
  夹具：5 文件（含中文文件名、深嵌套、空文件），2 个中间目录。 }

type
  TEvfsErrorClass = class of EVfsError;

const
  FIX_COUNT = 5;
  WALK_EXPECT = '|.|assets|assets/app.js|assets/lib|assets/lib/x.js'
    + '|docs|docs/指南.md|empty.txt|index.html';
  ROOT_CHILDREN = 4;
  SUB_CHILDREN = 2;

var
  T: TTestSuite;
  G_FixPath: array[0..FIX_COUNT - 1] of string;
  G_FixMod: array[0..FIX_COUNT - 1] of Int64;
  G_TmpDir: string;
  G_EmbeddedBlob: TResPackBlob;
  G_Fs: IVfs;          { 被测实例 }
  G_Label: string;     { 断言消息前缀 }
  G_Visited: string;

{ ── 夹具 ── }

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

function SameFixture(const ABuf: TBytes; const AI: Integer): Boolean;
var
  J: Integer;
  FB: TBytes;
begin
  FB := FixBytes(AI);
  if Length(ABuf) <> Length(FB) then
    Exit(False);
  for J := 0 to Length(FB) - 1 do
    if ABuf[J] <> FB[J] then
      Exit(False);
  Result := True;
end;

procedure BuildOsTree;
var
  I: Integer;
begin
  G_TmpDir := '/tmp/nextpas_vfs_conformance';
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
  { 输入缓冲仅在 Build 同步消费期间需要持活 }
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

{ ── 属性电池 ── }

function LastSeg(const APath: string): string;
var
  I: Integer;
begin
  Result := APath;
  for I := Length(APath) downto 1 do
    if APath[I] = '/' then
      Exit(Copy(APath, I + 1, MaxInt));
end;

procedure StatProc; begin G_Fs.Stat('nope.bin'); end;
procedure OpenMissingProc; begin G_Fs.OpenRead('nope.bin'); end;
procedure OpenDirProc; begin G_Fs.OpenRead('assets'); end;
procedure ListFileProc; begin G_Fs.List('index.html'); end;
procedure InvStatProc; begin G_Fs.Stat('/x'); end;
procedure InvOpenProc; begin G_Fs.OpenRead('a//b'); end;
procedure InvListProc; begin G_Fs.List('a/../b'); end;

procedure ExpectErr(AProc: TTestProc; const ACls: TEvfsErrorClass;
  const AMsg: string);
var
  OK: Boolean;
begin
  OK := False;
  try
    AProc();
  except
    on E: Exception do
      OK := E is ACls;
  end;
  if not OK then
    Check(False, AMsg + ' (accepted or wrong class)');
  Check(True, AMsg);
end;

procedure WalkCollect(const APath: string; const AInfo: TEntryInfo;
  var AStop: Boolean);
begin
  G_Visited := G_Visited + '|' + APath;
end;

procedure PropRootAndWalk;
var
  L: TEntryArray;
  I, J: SizeUInt;
  Found: Boolean;
const
  ROOTS: array[0..ROOT_CHILDREN - 1] of string =
    ('assets', 'docs', 'empty.txt', 'index.html');
begin
  L := G_Fs.List('.');
  Check(SizeUInt(Length(L)) = ROOT_CHILDREN, G_Label + 'P1 root children count');
  for I := 0 to ROOT_CHILDREN - 1 do
  begin
    Found := False;
    for J := 0 to SizeUInt(Length(L)) - 1 do
      if L[J].Name = ROOTS[I] then
        Found := True;
    Check(Found, G_Label + 'P1 root contains ' + ROOTS[I]);
  end;
  for I := 1 to SizeUInt(Length(L)) - 1 do
    Check(VfsNameCompare(L[I - 1].Name, L[I].Name) <= 0,
      G_Label + 'P1 list sorted');

  G_Visited := '';
  VfsWalk(G_Fs, '.', @WalkCollect);
  Check(G_Visited = WALK_EXPECT, G_Label + 'P1 walk exact sequence');
end;

procedure PropChildNamesLegal;
var
  Dirs: array[0..2] of string;
  L: TEntryArray;
  I, D: Integer;
  Seg: string;
begin
  Dirs[0] := '.';
  Dirs[1] := 'assets';
  Dirs[2] := 'assets/lib';
  for D := Low(Dirs) to High(Dirs) do
  begin
    L := G_Fs.List(Dirs[D]);
    for I := 0 to Length(L) - 1 do
    begin
      Seg := LastSeg(L[I].Name);
      Check((Length(Seg) > 0) and (Seg <> '.') and (Seg <> '..')
        and (Pos('/', Seg) = 0),
        G_Label + 'P2 child name legal: ' + L[I].Name);
    end;
  end;
end;

procedure PropStatListConsistent;
var
  Dirs: array[0..2] of string;
  L: TEntryArray;
  SI: TStatInfo;
  I, D: Integer;
begin
  Dirs[0] := '.';
  Dirs[1] := 'assets';
  Dirs[2] := 'assets/lib';
  for D := Low(Dirs) to High(Dirs) do
  begin
    L := G_Fs.List(Dirs[D]);
    for I := 0 to Length(L) - 1 do
    begin
      SI := G_Fs.Stat(L[I].Name);
      Check((not VfsIsRoot(L[I].Name)) or SI.Info.IsDir,
        G_Label + 'P3 root is dir');
      Check(SI.Info.IsDir = L[I].IsDir,
        G_Label + 'P3 isdir match: ' + L[I].Name);
      if not SI.Info.IsDir then
      begin
        Check(SI.Info.Size = L[I].Size,
          G_Label + 'P3 size match: ' + L[I].Name);
        Check(SI.Info.ModTime = L[I].ModTime,
          G_Label + 'P3 modtime match: ' + L[I].Name);
      end;
    end;
  end;
end;

procedure PropContentsExact;
var
  S: IStream;
  RA: IReaderAt;
  Buf: TBytes;
  Got: SizeUInt;
  I: Integer;
begin
  for I := 0 to FIX_COUNT - 1 do
  begin
    S := G_Fs.OpenRead(G_FixPath[I]);
    try
      SetLength(Buf, Length(FixBytes(I)));
      if Length(Buf) > 0 then
      begin
        Got := S.Read(Buf[0], SizeUInt(Length(Buf)));
        Check(Got = SizeUInt(Length(Buf)),
          G_Label + 'P4 read size: ' + G_FixPath[I]);
      end;
      Check(SameFixture(Buf, I), G_Label + 'P4 bytes equal: ' + G_FixPath[I]);
      if Length(Buf) > 0 then
        Check(S.Read(Buf[0], 1) = 0, G_Label + 'P4 eof: ' + G_FixPath[I]);

      { INV-V12：流 SHOULD 支持 positioned 读，三后端一致 }
      if Length(Buf) > 0 then
      begin
        if S.QueryInterface(IReaderAt, RA) = 0 then
        begin
          Got := RA.ReadAt(Buf[0], SizeUInt(Length(Buf)), 0);
          Check(Got = SizeUInt(Length(Buf)),
            G_Label + 'V12 readat size: ' + G_FixPath[I]);
          Check(SameFixture(Buf, I),
            G_Label + 'V12 readat bytes: ' + G_FixPath[I]);
        end
        else
          Check(False, G_Label + 'V12 stream lacks IReaderAt');
      end;
    finally
      S.Close;
    end;
  end;
end;

procedure PropErrors;
begin
  ExpectErr(@StatProc, EVfsNotFound, G_Label + 'P4 missing stat NotFound');
  ExpectErr(@OpenMissingProc, EVfsNotFound, G_Label + 'P4 missing open NotFound');
  ExpectErr(@OpenDirProc, EVfsIsADirectory, G_Label + 'P6 open dir IsADirectory');
  ExpectErr(@ListFileProc, EVfsNotADirectory, G_Label + 'P6 list file NotADirectory');
  ExpectErr(@InvStatProc, EVfsInvalidPath, G_Label + 'P5 invalid stat');
  ExpectErr(@InvOpenProc, EVfsInvalidPath, G_Label + 'P5 invalid open');
  ExpectErr(@InvListProc, EVfsInvalidPath, G_Label + 'P5 invalid list');
end;

procedure RunBattery(const ALabel: string);
begin
  G_Label := ALabel + ': ';
  PropRootAndWalk;
  PropChildNamesLegal;
  PropStatListConsistent;
  PropContentsExact;
  PropErrors;
end;

{ ── 各后端用例 ── }

procedure RunMemtree;
begin
  G_Fs := MakeMemtreeVfs;
  try
    RunBattery('memtree');
    Check(G_Fs.CaseSensitive, 'memtree: case sensitive true');
  finally
    G_Fs := nil;
  end;
end;

procedure RunEmbedded;
begin
  G_Fs := MakeEmbeddedVfs;
  try
    RunBattery('embedded');
    Check(G_Fs.CaseSensitive, 'embedded: case sensitive true');
  finally
    G_Fs := nil;   { AOwnsBlob=True ⇒ 此处归还 blob；heaptrc 判零泄漏 }
  end;
end;

procedure RunOsSetup;
begin
  BuildOsTree;
end;

procedure RunOs;
begin
  G_Fs := CreateOsVfs(G_TmpDir);
  try
    RunBattery('os');
    {$IFDEF NEXTPAS_WINDOWS}
    Check(not G_Fs.CaseSensitive, 'os: case insensitive on windows');
    {$ELSE}
    Check(G_Fs.CaseSensitive, 'os: case sensitive on posix');
    {$ENDIF}
  finally
    G_Fs := nil;
  end;
end;

{ ── P7：sub 视图往返（对每个后端） ── }

const
  SUB_WALK = '|.|app.js|lib|lib/x.js';

procedure SubOpenLibProc; begin G_Fs.OpenRead('lib'); end;
procedure SubListFileProc; begin G_Fs.List('app.js'); end;
procedure SubMissingProc; begin G_Fs.Stat('missing.txt'); end;

procedure SubBattery(const ALabel: string);
var
  L: TEntryArray;
  S: IStream;
  Buf: TBytes;
  SI: TStatInfo;
begin
  Check(G_Fs.Exists('app.js'), ALabel + 'sub exists file');
  Check(G_Fs.Exists('lib'), ALabel + 'sub exists dir');
  Check(not G_Fs.Exists('../docs'), ALabel + 'sub cannot see outside');

  SI := G_Fs.Stat('.');
  Check(SI.Info.IsDir, ALabel + 'sub root is dir');
  SI := G_Fs.Stat('app.js');
  Check((not SI.Info.IsDir) and (SI.Info.Size = Length('console.log(1);')),
    ALabel + 'sub stat file size');

  L := G_Fs.List('.');
  Check(SizeUInt(Length(L)) = SUB_CHILDREN, ALabel + 'sub root children');
  Check(L[0].Name = 'app.js', ALabel + 'sub sorted [0]');
  Check(L[1].Name = 'lib', ALabel + 'sub sorted [1]');

  S := G_Fs.OpenRead('app.js');
  try
    SetLength(Buf, 15);
    Check(S.Read(Buf[0], 15) = 15, ALabel + 'sub read content');
  finally
    S.Close;
  end;

  G_Visited := '';
  VfsWalk(G_Fs, '.', @WalkCollect);
  Check(G_Visited = SUB_WALK, ALabel + 'sub walk exact sequence');

  ExpectErr(@SubOpenLibProc, EVfsIsADirectory, ALabel + 'sub open dir');
  ExpectErr(@SubListFileProc, EVfsNotADirectory, ALabel + 'sub list file');
  ExpectErr(@SubMissingProc, EVfsNotFound, ALabel + 'sub missing stat');
end;

procedure RunSubMemtree;
begin
  G_Fs := CreateSubVfs(MakeMemtreeVfs, 'assets');
  try
    SubBattery('sub/memtree');
  finally
    G_Fs := nil;
  end;
end;

procedure RunSubEmbedded;
begin
  G_Fs := CreateSubVfs(MakeEmbeddedVfs, 'assets');
  try
    SubBattery('sub/embedded');
  finally
    G_Fs := nil;
  end;
end;

procedure RunSubOs;
begin
  BuildOsTree;
  G_Fs := CreateSubVfs(CreateOsVfs(G_TmpDir), 'assets');
  try
    SubBattery('sub/os');
  finally
    G_Fs := nil;
  end;
  RemoveOsTree;
end;

{ ── P8：embedded 零拷贝地址断言（专属） ── }

procedure RunEmbeddedZeroCopy;
var
  Fs: IVfs;
  SI: TStatInfo;
  RP: TResPack;
  E: TResPackEntry;
  Ptr: PByte;
begin
  Fs := MakeEmbeddedVfs;
  try
    SI := Fs.Stat('index.html');
    Check(SI.Info.Size = 15, 'P8 embedded index.html size');
    RP := TResPack.Open(G_EmbeddedBlob.Data, G_EmbeddedBlob.Size);
    if RP.Find('index.html', E) then
    begin
      Ptr := RP.ContentPtr(E);
      { 读取窗口必须落在 blob 地址空间内——零拷贝的物理证据 }
      Check(Ptr >= G_EmbeddedBlob.Data, 'P8 window base within blob');
      Check(Ptr + UInt64(E.Size)
        <= G_EmbeddedBlob.Data + UInt64(G_EmbeddedBlob.Size),
        'P8 window end within blob');
    end
    else
      Check(False, 'P8 pack lookup failed');
  finally
    Fs := nil;
  end;
end;

{ ── 注册与执行 ── }

begin
  InitFixture;
  BuildOsTree;

  T := TTestSuite.Create('nextpas.core.vfs.conformance');
  T.Test('memtree battery', @RunMemtree);
  T.Test('embedded battery', @RunEmbedded);
  T.Test('embedded P8 zero-copy', @RunEmbeddedZeroCopy);
  T.Test('os battery', @RunOs);
  T.Test('sub memtree battery', @RunSubMemtree);
  T.Test('sub embedded battery', @RunSubEmbedded);
  T.Test('sub os battery', @RunSubOs);

  if not T.Run then
  begin
    RemoveOsTree;
    Halt(1);
  end;
  RemoveOsTree;
end.
