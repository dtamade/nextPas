program test_fs_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test;

var
  TmpDir, FilePath, RenamedPath: string;
  SplitDir, SplitBase: string;
  F: IFile;
  Info: TFileInfo;
  LRunner: TTestRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('fs.facade');
  TmpDir := PathJoin([GetTempDir, 'nextpas_fs_facade_gate']);

  LSuite.Test('MkdirAll through facade', procedure begin
    if Exists(TmpDir) then RemoveAll(TmpDir);
    CheckTrue(MkdirAll(TmpDir), 'MkdirAll should succeed');
  end);

  LSuite.Test('Create and write file', procedure begin
    FilePath := PathJoin([TmpDir, 'sample.txt']);
    F := Create(FilePath, PermDefault);
    F.Write(PAnsiChar('hello')^, 5);
    F.Close;
    CheckEqual(5, Length(ReadFile(FilePath)));
  end);

  LSuite.Test('Exists and IsFile', procedure begin
    RenamedPath := PathJoin([TmpDir, 'renamed.txt']);
    WriteFile(RenamedPath, ReadFile(FilePath));
    CheckTrue(Exists(RenamedPath), 'Exists through facade');
    CheckTrue(IsFile(RenamedPath), 'IsFile through facade');
  end);

  LSuite.Test('Stat and Lstat', procedure begin
    Info := Stat(RenamedPath);
    CheckEqual(Int64(5), Info.Size);
    Info := Lstat(RenamedPath);
    CheckTrue(Info.FileType = ftRegular, 'Lstat through facade');
  end);

  LSuite.Test('PathBase and PathSplit', procedure begin
    CheckEqual('renamed.txt', PathBase(RenamedPath));
    PathSplit(RenamedPath, SplitDir, SplitBase);
    CheckEqual(TmpDir, SplitDir);
    CheckEqual('renamed.txt', SplitBase);
  end);

  LSuite.Test('PathWithoutExt and PathRelative', procedure begin
    CheckEqual(PathJoin([TmpDir, 'renamed']),
      PathWithoutExt(RenamedPath));
    CheckEqual('renamed.txt',
      PathRelative(TmpDir, RenamedPath));
  end);

  LSuite.Test('SameFileName and GetTempDir', procedure begin
    CheckTrue(SameFileName(RenamedPath, RenamedPath),
      'SameFileName through facade');
    CheckTrue(GetTempDir <> '', 'GetTempDir through facade');
  end);

  LSuite.Test('Remove file', procedure begin
    CheckTrue(Remove(RenamedPath), 'Remove through facade');
  end);

  LSuite.SetTeardown(procedure begin
    if Exists(TmpDir) then RemoveAll(TmpDir);
  end);

  LRunner := TTestRunner.Create('nextpas.core.fs');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
