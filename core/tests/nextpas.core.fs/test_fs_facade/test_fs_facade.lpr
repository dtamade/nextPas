program test_fs_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs;

var
  TmpDir, FilePath, RenamedPath: string;
  SplitDir, SplitBase: string;
  F: IFile;
  Info: TFileInfo;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
  WriteLn('PASS: ', AMessage);
end;

begin
  TmpDir := PathJoin([GetTempDir, 'nextpas_fs_facade_gate']);
  if Exists(TmpDir) then
    RemoveAll(TmpDir);
  Check(MkdirAll(TmpDir), 'MkdirAll through facade');
  try
    FilePath := PathJoin([TmpDir, 'sample.txt']);
    RenamedPath := PathJoin([TmpDir, 'renamed.txt']);

    F := Create(FilePath, PermDefault);
    F.Write(PAnsiChar('hello')^, 5);
    F.Close;

    F := Open(FilePath, [fmRead]);
    F.Close;

    Check(Length(ReadFile(FilePath)) = 5, 'ReadFile through facade');
    WriteFile(RenamedPath, ReadFile(FilePath));
    Check(Exists(RenamedPath), 'Exists through facade');
    Check(IsFile(RenamedPath), 'IsFile through facade');

    Info := Stat(RenamedPath);
    Check(Info.Size = 5, 'Stat through facade');
    Info := Lstat(RenamedPath);
    Check(Info.FileType = ftRegular, 'Lstat through facade');

    Check(PathBase(RenamedPath) = 'renamed.txt', 'PathBase through facade');
    PathSplit(RenamedPath, SplitDir, SplitBase);
    Check(SplitDir = TmpDir, 'PathSplit dir through facade');
    Check(SplitBase = 'renamed.txt', 'PathSplit base through facade');
    Check(PathWithoutExt(RenamedPath) = PathJoin([TmpDir, 'renamed']),
      'PathWithoutExt through facade');
    Check(PathRelative(TmpDir, RenamedPath) = 'renamed.txt',
      'PathRelative through facade');
    Check(SameFileName(RenamedPath, RenamedPath),
      'SameFileName through facade');
    Check(GetTempDir <> '', 'GetTempDir through facade');
    Check(Remove(RenamedPath), 'Remove through facade');
  finally
    if Exists(TmpDir) then
      RemoveAll(TmpDir);
  end;
end.
