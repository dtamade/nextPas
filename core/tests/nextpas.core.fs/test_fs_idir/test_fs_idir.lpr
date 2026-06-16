program test_fs_idir;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
{$ENDIF}
  nextpas.core.fs;

var
  T: TTestRunner;
  GTmpDir: string;

procedure SetupTmpDir;
begin
  GTmpDir := '/tmp/nextpas_fs_idir_test_' + IntToStr(GetProcessID);
  nextpas.core.fs.MkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(GTmpDir);
end;

{ T1: Basic — create 3 files, iterate, count entries }

procedure TestDirIter_Basic;
var
  LIter: IDirIterator;
  LCount: Integer;
begin
  FsMkdir(GTmpDir + '/basic');
  FsWriteFile(GTmpDir + '/basic/a.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/basic/b.txt', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/basic/c.txt', TBytes.Create(3));

  LIter := FsOpenDir(GTmpDir + '/basic');
  LCount := 0;
  while LIter.Next do
  begin
    Check(Liter.Entry.Name <> '', 'Entry.Name must not be empty');
    Inc(LCount);
  end;
  LIter.Close;
  CheckEqual(Int64(3), Int64(LCount), 'basic dir has 3 entries');
end;

{ T2: Empty directory — Next returns False immediately }

procedure TestDirIter_Empty;
var
  LIter: IDirIterator;
  LResult: Boolean;
begin
  FsMkdir(GTmpDir + '/empty');
  LIter := FsOpenDir(GTmpDir + '/empty');
  LResult := LIter.Next;
  Check(not LResult, 'empty dir: Next returns False');
  LIter.Close;
end;

{ T3: Entry fields — verify Name (no path prefix) and FileType }

procedure TestDirIter_EntryFields;
var
  LIter: IDirIterator;
  LEntry: TDirEntry;
  LFoundFile, LFoundDir: Boolean;
begin
  FsMkdir(GTmpDir + '/fields');
  FsWriteFile(GTmpDir + '/fields/data.bin', TBytes.Create(1));
  FsMkdir(GTmpDir + '/fields/sub');

  LIter := FsOpenDir(GTmpDir + '/fields');
  LFoundFile := False;
  LFoundDir := False;
  while LIter.Next do
  begin
    LEntry := LIter.Entry;
    Check(Pos('/', LEntry.Name) = 0,
      'Entry.Name must not contain path separator: ' + LEntry.Name);
    Check(Pos(GTmpDir, LEntry.Name) = 0,
      'Entry.Name must not contain tmpdir prefix: ' + LEntry.Name);

    if LEntry.Name = 'data.bin' then
    begin
      Check(LEntry.FileType = ftRegular, 'data.bin is ftRegular');
      Check(not LEntry.IsDir, 'data.bin IsDir = False');
      LFoundFile := True;
    end;
    if LEntry.Name = 'sub' then
    begin
      Check(LEntry.FileType = ftDirectory, 'sub is ftDirectory');
      Check(LEntry.IsDir, 'sub IsDir = True');
      LFoundDir := True;
    end;
  end;
  LIter.Close;
  Check(LFoundFile, 'found data.bin entry');
  Check(LFoundDir, 'found sub entry');
end;

{ T4: Mixed entries — file + subdir + symlink }

{$IFDEF NEXTPAS_UNIX}
procedure TestDirIter_MixedEntries;
var
  LIter: IDirIterator;
  LEntry: TDirEntry;
  LFoundFile, LFoundDir, LFoundLink: Boolean;
begin
  FsMkdir(GTmpDir + '/mixed');
  FsWriteFile(GTmpDir + '/mixed/file.txt', TBytes.Create(1));
  FsMkdir(GTmpDir + '/mixed/child');
  if nextpas.core.platform.posix.ffi.symlink(
    PAnsiChar(GTmpDir + '/mixed/file.txt'),
    PAnsiChar(GTmpDir + '/mixed/link.txt')) <> 0 then
  begin
    Check(True, 'symlink unsupported, skip');
    Exit;
  end;

  LIter := FsOpenDir(GTmpDir + '/mixed');
  LFoundFile := False;
  LFoundDir := False;
  LFoundLink := False;
  while LIter.Next do
  begin
    LEntry := LIter.Entry;
    if LEntry.Name = 'file.txt' then
    begin
      Check(LEntry.FileType = ftRegular, 'file.txt is ftRegular');
      LFoundFile := True;
    end;
    if LEntry.Name = 'child' then
    begin
      Check(LEntry.FileType = ftDirectory, 'child is ftDirectory');
      Check(LEntry.IsDir, 'child IsDir = True');
      LFoundDir := True;
    end;
    if LEntry.Name = 'link.txt' then
    begin
      Check(LEntry.FileType = ftSymlink, 'link.txt is ftSymlink');
      LFoundLink := True;
    end;
  end;
  LIter.Close;
  Check(LFoundFile, 'found file.txt');
  Check(LFoundDir, 'found child dir');
  Check(LFoundLink, 'found link.txt');
end;
{$ENDIF}

{ T5: Deep directory — only direct children, not recursive }

procedure TestDirIter_DeepDir;
var
  LIter: IDirIterator;
  LCount: Integer;
  LNames: array of string;
  LI: Integer;
  LFoundChild: Boolean;
begin
  FsMkdirAll(GTmpDir + '/deep/l1/l2');
  FsWriteFile(GTmpDir + '/deep/a.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/deep/l1/b.txt', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/deep/l1/l2/c.txt', TBytes.Create(3));

  LIter := FsOpenDir(GTmpDir + '/deep');
  LCount := 0;
  LNames := nil;
  while LIter.Next do
  begin
    SetLength(LNames, LCount + 1);
    LNames[LCount] := LIter.Entry.Name;
    Inc(LCount);
  end;
  LIter.Close;

  CheckEqual(Int64(2), Int64(LCount),
    'deep dir returns only direct children (a.txt + l1/)');
  LFoundChild := False;
  for LI := 0 to High(LNames) do
  begin
    Check(LNames[LI] <> 'b.txt',
      'must not recurse into l1/: b.txt not found');
    Check(LNames[LI] <> 'c.txt',
      'must not recurse into l1/l2/: c.txt not found');
    if LNames[LI] = 'a.txt' then
      LFoundChild := True;
  end;
  Check(LFoundChild, 'found a.txt in deep dir');
end;

{ T6: Nonexistent directory — raises ENotFoundError }

procedure TestDirIter_NonexistentDir;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsOpenDir(GTmpDir + '/does_not_exist_xyz');
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'OpenDir nonexistent path raises ENotFoundError');
end;

{ T7: Interface reference counting — assign nil releases iterator }

procedure TestDirIter_InterfaceRelease;
var
  LIter: IDirIterator;
begin
  FsMkdir(GTmpDir + '/refcount');
  FsWriteFile(GTmpDir + '/refcount/one.txt', TBytes.Create(1));

  LIter := FsOpenDir(GTmpDir + '/refcount');
  Check(LIter <> nil, 'iterator not nil after OpenDir');
  LIter := nil;
  Check(LIter = nil, 'iterator nil after assignment');
  { heaptrc at exit will report a leak if the underlying TDirIterator
    was not freed when the interface reference went nil. }
end;

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.fs.idir');

    T.Run('DirIter_Basic: 3 files, count + name non-empty',
      @TestDirIter_Basic);
    T.Run('DirIter_Empty: empty dir returns False immediately',
      @TestDirIter_Empty);
    T.Run('DirIter_EntryFields: Name no prefix, FileType correct',
      @TestDirIter_EntryFields);
{$IFDEF NEXTPAS_UNIX}
    T.Run('DirIter_MixedEntries: file + dir + symlink FileType',
      @TestDirIter_MixedEntries);
{$ENDIF}
    T.Run('DirIter_DeepDir: only direct children, not recursive',
      @TestDirIter_DeepDir);
    T.Run('DirIter_NonexistentDir: raises ENotFoundError',
      @TestDirIter_NonexistentDir);
    T.Run('DirIter_InterfaceRelease: nil releases iterator (heaptrc)',
      @TestDirIter_InterfaceRelease);

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
