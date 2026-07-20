program test_fs_wine;

{ L2 fs Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.path,
  nextpas.core.text.conv
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

function WineTmp: string;
begin
  Result := GetTempDir;
  if Result = '' then
    Result := 'C:\windows\temp';
  Result := PathJoin(Result, 'nextpas_fs_wine');
end;

procedure TestWriteReadRemove;
var
  LDir, LFile, LText: string;
begin
  LDir := WineTmp;
  MkdirAll(LDir);
  LFile := PathJoin(LDir, 'hello.txt');
  WriteFileText(LFile, 'wine_fs_ok');
  Check(Exists(LFile), 'file exists after write');
  LText := ReadFileText(LFile);
  Check(Pos('wine_fs_ok', LText) > 0, 'read back content');
  Remove(LFile);
  Check(not Exists(LFile), 'removed');
  RemoveAll(LDir);
end;

procedure TestMkdirAllNested;
var
  LRoot, LNest: string;
begin
  LRoot := WineTmp;
  LNest := PathJoin(PathJoin(LRoot, 'a'), 'b');
  MkdirAll(LNest);
  Check(IsDir(LNest), 'nested dir exists');
  RemoveAll(LRoot);
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('fs L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('write read remove', @TestWriteReadRemove);
  T.Test('mkdirall nested', @TestMkdirAllNested);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
