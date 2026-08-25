program test_vfs_memtree;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.vfs;

var
  T: TTestSuite;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then Exit;
  if Length(AA) = 0 then Exit(True);
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then Exit;
  Result := True;
end;

{ 固定样例树：index.html / assets/app.js / assets/lib/x.js / docs/readme.md }
function MakeSample: IVfs;
var
  B: TVfsTreeBuilder;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('index.html', BytesOf('<html>ok</html>'), 100, $DEADBEEF);
    B.AddFile('assets/app.js', BytesOf('app();'), 200, UInt32($DEADBEF0));
    B.AddFile('assets/lib/x.js', BytesOf('libx();'), 300);
    B.AddFile('docs/readme.md', BytesOf('# readme'), 400);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

{ ── 用例 ── }

procedure TestStatFile;
var
  Fs: IVfs;
  SI: TStatInfo;
begin
  Fs := MakeSample;
  SI := Fs.Stat('assets/app.js');
  Check((not SI.Info.IsDir) and (SI.Info.Size = 6), 'stat file size');
  Check(SI.Info.ModTime = 200, 'stat file modtime');
  Check(SI.ContentHash = UInt32($DEADBEF0), 'stat file hash');
end;

procedure TestRootAndListSorted;
var
  Fs: IVfs;
  SI: TStatInfo;
  L: TEntryArray;
begin
  Fs := MakeSample;
  SI := Fs.Stat('.');
  Check(SI.Info.IsDir and VfsIsRoot(SI.Info.Name), 'root is dir named .');
  L := Fs.List('.');
  Check(SizeUInt(Length(L)) = 3, 'root children count');
  Check(L[0].Name = 'assets', 'sorted [0]=assets');
  Check(L[0].IsDir, '[0] is dir');
  Check(L[1].Name = 'docs', 'sorted [1]=docs');
  Check(L[1].IsDir, '[1] is dir');
  Check(L[2].Name = 'index.html', 'sorted [2]=index.html');
  Check(not L[2].IsDir, '[2] is file');
end;

procedure TestListNested;
var
  Fs: IVfs;
  L: TEntryArray;
begin
  Fs := MakeSample;
  L := Fs.List('assets');
  Check(SizeUInt(Length(L)) = 2, 'assets children count');
  Check(L[0].Name = 'assets/app.js', 'nested [0]');
  Check(not L[0].IsDir, 'app.js is file');
  Check((L[1].Name = 'assets/lib') and L[1].IsDir, 'nested [1] lib dir');
  L := Fs.List('assets/lib');
  Check((SizeUInt(Length(L)) = 1) and (L[0].Name = 'assets/lib/x.js'),
    'deep list single file');
end;

procedure TestOpenReadSeekReadAt;
var
  Fs: IVfs;
  S: IStream;
  RA: IReaderAt;
  Buf: TBytes;
  Got: SizeUInt;
begin
  Fs := MakeSample;
  S := Fs.OpenRead('index.html');
  SetLength(Buf, 15);
  Got := S.Read(Buf[0], 5);
  Check(Got = 5, 'stream read first 5');
  Check(SameBytes(Copy(Buf, 0, 5), BytesOf('<html')), 'first bytes content');
  Check(S.Seek(0, soBeginning) = 0, 'seek beginning returns 0');
  Got := S.Read(Buf[0], 15);
  Check(Got = 15, 'stream read all after rewind');
  Check(SameBytes(Copy(Buf, 0, 15), BytesOf('<html>ok</html>')),
    'full content after rewind');
  if S.QueryInterface(IReaderAt, RA) = 0 then
  begin
    Got := RA.ReadAt(Buf[0], 9, 6);
    Check(Got = 9, 'readerat read tail');
    Check(SameBytes(Copy(Buf, 0, 9), BytesOf('ok</html>')), 'readerat offset bytes');
  end
  else
    Check(False, 'memtree stream should expose IReaderAt');
  S.Close;
end;

procedure TestOpenDirRaises;
var
  Fs: IVfs;
  Got: Boolean;
begin
  Fs := MakeSample;
  Got := False;
  try
    Fs.OpenRead('assets');
  except
    on E: EVfsIsADirectory do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'open dir raises is-a-directory');
  Got := False;
  try
    Fs.OpenRead('.');
  except
    on E: EVfsIsADirectory do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'open root raises is-a-directory');
end;

procedure TestListOnFileRaises;
var
  Fs: IVfs;
  Got: Boolean;
begin
  Fs := MakeSample;
  Got := False;
  try
    Fs.List('index.html');
  except
    on E: EVfsNotADirectory do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'list on file raises not-a-directory');
end;

procedure TestMissingNotFoundContext;
var
  Fs: IVfs;
  Got: Boolean;
begin
  Fs := MakeSample;
  Got := False;
  try
    Fs.Stat('no/such.txt');
  except
    on E: EVfsNotFound do
      Got := (E.Op = 'stat') and (E.Path = 'no/such.txt');
    on E: Exception do ;
  end;
  Check(Got, 'missing stat raises not-found with op/path');
end;

procedure TestInvalidPaths;
const
  BAD: array[0..4] of string = ('a/../b', '/x', 'a//b', '', 'a/');
var
  Fs: IVfs;
  I: Integer;
  GotStat, GotOpen, GotList: Boolean;
begin
  Fs := MakeSample;
  for I := Low(BAD) to High(BAD) do
  begin
    GotStat := False; GotOpen := False; GotList := False;
    try Fs.Stat(BAD[I]); except on E: EVfsInvalidPath do GotStat := True; on E: Exception do ; end;
    try Fs.OpenRead(BAD[I]); except on E: EVfsInvalidPath do GotOpen := True; on E: Exception do ; end;
    try Fs.List(BAD[I]); except on E: EVfsInvalidPath do GotList := True; on E: Exception do ; end;
    Check(GotStat and GotOpen and GotList,
      'invalid path rejected everywhere: [' + BAD[I] + ']');
  end;
end;

procedure TestDuplicateFreezeRaises;
var
  B: TVfsTreeBuilder;
  Got: Boolean;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('same.txt', BytesOf('a'), 0);
    B.AddFile('same.txt', BytesOf('b'), 0);
    Got := False;
    try
      B.Freeze;
    except
      on E: EVfsError do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'duplicate freeze raises');
  finally
    B.Free;
  end;
end;

procedure TestOverlapFreezeRaises;
var
  B: TVfsTreeBuilder;
  Got: Boolean;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('a', BytesOf('file'), 0);
    B.AddFile('a/b', BytesOf('under'), 0);
    Got := False;
    try
      B.Freeze;
    except
      on E: EVfsError do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'file/dir overlap freeze raises');
  finally
    B.Free;
  end;
end;

var
  G_Walk: array[0..15] of string;
  G_WalkN: Integer;

procedure CollectWalk(const APath: string; const AInfo: TEntryInfo;
  var AStop: Boolean);
begin
  if G_WalkN <= High(G_Walk) then
  begin
    G_Walk[G_WalkN] := APath;
    Inc(G_WalkN);
  end;
end;

procedure TestWalkLexicographic;
var
  Fs: IVfs;
  Joined: string;
  I: Integer;
const
  EXPECT: array[0..7] of string = (
    '.', 'assets', 'assets/app.js', 'assets/lib',
    'assets/lib/x.js', 'docs', 'docs/readme.md', 'index.html');
begin
  Fs := MakeSample;
  G_WalkN := 0;
  VfsWalk(Fs, '.',
    procedure(const APath: string; const AInfo: TEntryInfo; var AStop: Boolean)
    begin
      CollectWalk(APath, AInfo, AStop);
    end);
  Check(G_WalkN = 8, 'walk visited all nodes');
  Joined := '';
  for I := 0 to G_WalkN - 1 do
    Joined := Joined + '|' + G_Walk[I];
  Check(
    (Joined = '|.|assets|assets/app.js|assets/lib|assets/lib/x.js|docs'
      + '|docs/readme.md|index.html'),
    'walk lexicographic preorder');
  for I := 0 to 7 do
    if G_Walk[I] <> EXPECT[I] then
    begin
      Check(False, 'walk mismatch at #' + Char(Ord('0') + I));
      Exit;
    end;
  Check(True, 'walk exact sequence');
end;

procedure CollectWalkStopAfterFirst(const APath: string;
  const AInfo: TEntryInfo; var AStop: Boolean);
begin
  G_Walk[G_WalkN] := APath;
  Inc(G_WalkN);
  if G_WalkN >= 2 then
    AStop := True;
end;

procedure TestWalkStop;
var
  Fs: IVfs;
begin
  Fs := MakeSample;
  G_WalkN := 0;
  VfsWalk(Fs, '.',
    procedure(const APath: string; const AInfo: TEntryInfo; var AStop: Boolean)
    begin
      CollectWalkStopAfterFirst(APath, AInfo, AStop);
    end);
  Check(G_WalkN = 2, 'walk stop halts traversal early');
  Check(G_Walk[0] = '.', 'walk stop root first');
  Check(G_Walk[1] = 'assets', 'walk stop first child lexical');
end;

procedure TestCaseSensitive;
var
  Fs: IVfs;
begin
  Fs := MakeSample;
  Check(Fs.CaseSensitive, 'memtree case sensitive');
  Check(not Fs.Exists('INDEX.HTML'), 'case mismatch not found');
end;

procedure TestFrozenBuilderRejectsAdd;
var
  B: TVfsTreeBuilder;
  Got: Boolean;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.Freeze;
    Got := False;
    try
      B.AddFile('late.txt', nil, 0, 0);
    except
      on E: EVfsClosed do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'frozen builder rejects add');
  finally
    B.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.vfs.memtree');
  T.Test('stat file', @TestStatFile);
  T.Test('root stat and sorted list', @TestRootAndListSorted);
  T.Test('nested list dedup dirs', @TestListNested);
  T.Test('open read seek readat', @TestOpenReadSeekReadAt);
  T.Test('open dir/root raises', @TestOpenDirRaises);
  T.Test('list on file raises', @TestListOnFileRaises);
  T.Test('missing raises with context', @TestMissingNotFoundContext);
  T.Test('invalid paths rejected everywhere', @TestInvalidPaths);
  T.Test('duplicate freeze raises', @TestDuplicateFreezeRaises);
  T.Test('overlap freeze raises', @TestOverlapFreezeRaises);
  T.Test('walk lexicographic preorder', @TestWalkLexicographic);
  T.Test('walk stop', @TestWalkStop);
  T.Test('case sensitive', @TestCaseSensitive);
  T.Test('frozen builder rejects add', @TestFrozenBuilderRejectsAdd);
  if not T.Run then Halt(1);
end.
