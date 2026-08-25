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
  Entries: TResPackInputArray;
  B: TResPackBlob;
  RP: TResPack;
  FoundRoot, FoundSub, FoundDeep: Boolean;
  I: SizeUInt;
begin
  SetupTree;
  try
    Entries := ResPackEntriesFromDir(G_Dir);
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
  Entries: TResPackInputArray;
  N: SizeUInt;
begin
  SetupTree;
  try
    Entries := ResPackEntriesFromDir(G_Dir,
      function(const ARelativePath: string): Boolean
      begin
        Result := Pos('.css', ARelativePath) > 0;
      end);
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
  Entries: TResPackInputArray;
  I: SizeUInt;
  LinkIn: Boolean;
begin
  SetupTree;
  try
    Symlink('root.txt', G_Dir + '/link.txt');
    Entries := ResPackEntriesFromDir(G_Dir);
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

procedure TestNotADirectoryRaises;
var
  Got: Boolean;
  Entries: TResPackInputArray;
begin
  Got := False;
  try
    Entries := ResPackEntriesFromDir('/definitely/not/here');
  except
    on E: EResPackDirSourceFailed do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'missing dir raises dirsource error');
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.dirsource');
  T.Test('relative recursive names', @TestRelativeRecursive);
  T.Test('include predicate filters', @TestIncludeFilter);
  T.Test('symlink skipped', @TestSymlinkSkipped);
  T.Test('missing dir raises', @TestNotADirectoryRaises);
  if not T.Run then Halt(1);
end.
