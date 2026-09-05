program test_respack_dirsource;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.respack,
  nextpas.core.respack.base;

var
  T: TTestSuite;
  G_Dir: string;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

procedure SetupTree;
begin
  G_Dir := GetTempDir + '/rp-dirsrc-test';
  RemoveAll(G_Dir);
  MkdirAll(G_Dir + '/sub/deep');
  WriteFile(G_Dir + '/root.txt', BytesOf('root-content'));
  WriteFile(G_Dir + '/sub/b.bin', BytesOf('bee'));
  WriteFile(G_Dir + '/sub/deep/c.css', BytesOf('body{}'));
end;

procedure TestRelativeRecursive;
var
  DE: TResPackDirEntries;
  Entries: TResPackInputArray;
  B: TResPackBlob;
  RP: TResPack;
  FoundRoot, FoundSub, FoundDeep: Boolean;
  I: SizeUInt;
begin
  SetupTree;
  try
    DE := ResPackEntriesFromDir(G_Dir);
    Entries := DE.Entries;
    Check(Length(Entries) = 3, 'dirsource count');
    B := ResPackBuild(Entries, ResPackDefaultOptions);
    RP := ResPackOpen(B.Data, B.Size);
    FoundRoot := False; FoundSub := False; FoundDeep := False;
    for I := 0 to RP.Count - 1 do
    begin
      if RP.PathOf(RP.EntryAt(I)) = 'root.txt' then FoundRoot := True;
      if RP.PathOf(RP.EntryAt(I)) = 'sub/b.bin' then FoundSub := True;
      if RP.PathOf(RP.EntryAt(I)) = 'sub/deep/c.css' then FoundDeep := True;
    end;
    Check(FoundRoot and FoundSub and FoundDeep, 'relative paths recursive');
    ResPackFreeBlob(B);
  finally
    RemoveAll(G_Dir);
  end;
end;

procedure TestIncludeFilter;
var
  DE: TResPackDirEntries;
  Entries: TResPackInputArray;
  N: SizeUInt;
begin
  SetupTree;
  try
    DE := ResPackEntriesFromDir(G_Dir,
      function(const ARelativePath: string): Boolean
      begin
        Result := Pos('.css', ARelativePath) > 0;
      end);
    Entries := DE.Entries;
    N := SizeUInt(Length(Entries));
    Check(N = 1, 'include filter keeps css only');
    if N = 1 then
      Check(Entries[0].Path = 'sub/deep/c.css', 'filter kept right file');
  finally
    RemoveAll(G_Dir);
  end;
end;

procedure TestSymlinkSkipped;
var
  DE: TResPackDirEntries;
  Entries: TResPackInputArray;
  I: SizeUInt;
  LinkIn: Boolean;
begin
  SetupTree;
  try
    Symlink('root.txt', G_Dir + '/link.txt');
    DE := ResPackEntriesFromDir(G_Dir);
    Entries := DE.Entries;
    LinkIn := False;
    for I := 0 to SizeUInt(Length(Entries)) - 1 do
      if Entries[I].Path = 'link.txt' then
        LinkIn := True;
    Check(not LinkIn, 'symlink excluded from pack entries');
    Check(SizeUInt(Length(Entries)) = 3, 'regular files still counted');
  finally
    RemoveAll(G_Dir);
  end;
end;

procedure TestModTimeAndSizeCarried;
var
  DE: TResPackDirEntries;
begin
  { 回归：walk 回调不携带 Size/ModTime，dirsource 需显式 Stat 补齐。
    mtime 是 http.static 条件请求（S5）的输入，丢失即静默退化 }
  SetupTree;
  try
    DE := ResPackEntriesFromDir(G_Dir);
    Check(SizeUInt(Length(DE.Entries)) = 3, 'tree enumerated');
    if SizeUInt(Length(DE.Entries)) > 0 then
      Check(DE.Entries[0].ModTime > 0, 'entry modtime carried from fs');
  finally
    RemoveAll(G_Dir);
  end;
end;

function PtrBytes(const AP: PByte; const ALen: SizeUInt): TBytes;
begin
  Result := nil;
  SetLength(Result, SizeInt(ALen));
  if ALen > 0 then
    Move(AP^, Result[0], ALen);
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: SizeInt;
begin
  Result := Length(AA) = Length(AB);
  if not Result then
    Exit;
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit(False);
end;

procedure CheckBuildFromDirRoundtrip(const ALabel: string; const ADedup: Boolean);
var
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  E, EA, EB: TResPackEntry;
  I: SizeUInt;
  Prev, P: string;
  Want, Got: TBytes;
begin
  { 真实入口往返：目录树（含空文件/unicode 名/重复内容）→ BuildFromDir →
    blob 内字节与磁盘文件逐字节一致；输入无序，断言索引有序 }
  WriteFile(G_Dir + '/empty.txt', BytesOf(''));
  WriteFile(G_Dir + '/uni-€.txt', BytesOf('unicode-payload'));
  WriteFile(G_Dir + '/dup1.bin', BytesOf('same-content'));
  WriteFile(G_Dir + '/sub/dup2.bin', BytesOf('same-content'));
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := ADedup;
  B := ResPackBuildFromDir(G_Dir, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    try
      Check(RP.Count = 7, ALabel + ': all seven files packed');
      Prev := '';
      for I := 0 to RP.Count - 1 do
      begin
        E := RP.EntryAt(I);
        P := RP.PathOf(E);
        Check((Prev = '') or (Prev < P), ALabel + ': index sorted');
        Prev := P;
        Want := ReadFile(G_Dir + '/' + P);
        Got := PtrBytes(RP.ContentPtr(E), E.Size);
        Check(SameBytes(Want, Got), ALabel + ': byte-equal ' + P);
        if not SameBytes(Want, Got) then
          Exit;
      end;
      if ADedup then
      begin
        Check(RP.Find('dup1.bin', E), ALabel + ': dup1 found');
        P := RP.PathOf(E);
        Got := PtrBytes(RP.ContentPtr(E), E.Size);
        Check(SameBytes(BytesOf('same-content'), Got), ALabel + ': dedup content intact');
        if RP.Find('dup1.bin', EA) and RP.Find('sub/dup2.bin', EB) then
          Check(EA.DataOffset = EB.DataOffset, ALabel + ': dedup shares one slot');
      end;    finally
      RP.Close;
    end;
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestBuildFromDirRoundtrip;
begin
  SetupTree;
  try
    CheckBuildFromDirRoundtrip('plain', False);
  finally
    RemoveAll(G_Dir);
  end;
  SetupTree;
  try
    CheckBuildFromDirRoundtrip('dedup', True);
  finally
    RemoveAll(G_Dir);
  end;
end;

procedure TestNotADirectoryRaises;var
  Got: Boolean;
  DE: TResPackDirEntries;
  Entries: TResPackInputArray;
begin
  Got := False;
  try
    DE := ResPackEntriesFromDir('/definitely/not/here');
    Entries := DE.Entries;
  except
    on E: EResPackDirSourceFailed do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'missing dir raises dirsource error');
end;

var
  { 目录流式收集全局锚点：匿名 WriteProc 捕获全局；转存局部后立即置 nil，
    heaptrc 零泄漏由显式释放证明 }
  G_DirStreamBuf: TBytes;

{ 目录三路径一致：BuildFromDir == BuildStreamFromDir 分段输出 ==
  BuildStreamSizeFromDir 预取（plain/dedup 两模式，含空文件/unicode/重复内容） }
procedure CheckDirStreamIdentity(const ALabel: string; const ADedup: Boolean);
var
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  SSize: UInt64;
  Streamed: TBytes;
begin
  WriteFile(G_Dir + '/empty.txt', BytesOf(''));
  WriteFile(G_Dir + '/uni-€.txt', BytesOf('unicode-payload'));
  WriteFile(G_Dir + '/dup1.bin', BytesOf('same-content'));
  WriteFile(G_Dir + '/sub/dup2.bin', BytesOf('same-content'));
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := ADedup;
  B := ResPackBuildFromDir(G_Dir, Opts);
  try
    SSize := ResPackBuildStreamSizeFromDir(G_Dir, Opts);
    Check(SSize = UInt64(B.Size), ALabel + ': dir size precompute equals build');
    G_DirStreamBuf := nil;
    try
      ResPackBuildStreamFromDir(G_Dir, Opts,
        procedure(const AData: PByte; const ASize: SizeUInt)
        var
          Old: SizeUInt;
        begin
          if ASize = 0 then Exit;
          Old := SizeUInt(Length(G_DirStreamBuf));
          SetLength(G_DirStreamBuf, Old + ASize);
          Move(AData^, G_DirStreamBuf[Old], ASize);
        end);
      Streamed := G_DirStreamBuf;
      G_DirStreamBuf := nil;
      try
        Check(SizeUInt(Length(Streamed)) = B.Size,
          ALabel + ': dir stream length equals build size');
        Check(SameBytes(PtrBytes(B.Data, B.Size), Streamed),
          ALabel + ': dir stream bytes identical to build');
      finally
        Streamed := nil;
      end;
    finally
      G_DirStreamBuf := nil;
    end;
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestDirStreamIdentity;
begin
  SetupTree;
  try
    CheckDirStreamIdentity('dir plain', False);
  finally
    RemoveAll(G_Dir);
  end;
  SetupTree;
  try
    CheckDirStreamIdentity('dir dedup', True);
  finally
    RemoveAll(G_Dir);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.dirsource');
  T.Test('relative recursive names', @TestRelativeRecursive);
  T.Test('include predicate filters', @TestIncludeFilter);
  T.Test('symlink skipped', @TestSymlinkSkipped);
  T.Test('modtime and size carried', @TestModTimeAndSizeCarried);
  T.Test('missing dir raises', @TestNotADirectoryRaises);
  T.Test('build from dir roundtrip', @TestBuildFromDirRoundtrip);
  T.Test('dir stream identity', @TestDirStreamIdentity);
  if not T.Run then Halt(1);
end.
