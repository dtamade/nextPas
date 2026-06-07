program test_path;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.path;

var
  T: TTestRunner;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LSourcePath), 'source exists: ' + ARelativePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function ExtractFunctionBody(const ASource, AStartToken, ANextToken: string): string;
var
  LStart, LNext: Integer;
begin
  Result := '';
  LStart := Pos(AStartToken, ASource);
  if LStart = 0 then
    Exit;
  LNext := Pos(ANextToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  if LNext = 0 then
    Exit(Copy(ASource, LStart, Length(ASource)));
  Result := Copy(ASource, LStart, Length(AStartToken) + LNext - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage);
end;

procedure TestPathJoin;
begin
  Check(PathJoin('/home', 'user') = '/home/user', 'join basic');
  Check(PathJoin('/home/', 'user') = '/home/user', 'join trailing sep');
  Check(PathJoin('', 'file.txt') = 'file.txt', 'join empty base');
  Check(PathJoin('/dir', '') = '/dir', 'join empty child');
  Check(PathJoin('', '') = '', 'join both empty');
end;

procedure TestPathJoin3;
begin
  Check(PathJoin3('/home', 'user', 'docs') = '/home/user/docs', 'join3 basic');
end;

procedure TestPathDir;
begin
  Check(PathDir('/home/user/file.txt') = '/home/user', 'dir with file');
  Check(PathDir('file.txt') = '', 'dir no path');
  Check(PathDir('/home/user/') = '/home/user', 'dir trailing sep');
  Check(PathDir('') = '', 'dir empty');
end;

procedure TestPathBase;
begin
  Check(PathBase('/home/user/file.txt') = 'file.txt', 'base with path');
  Check(PathBase('file.txt') = 'file.txt', 'base no path');
  Check(PathBase('/home/user/') = 'user', 'base trailing sep = last component');
  Check(PathBase('') = '', 'base empty');
end;

procedure TestPathExt;
begin
  Check(PathExt('/home/file.txt') = '.txt', 'ext basic');
  Check(PathExt('archive.tar.gz') = '.gz', 'ext double');
  Check(PathExt('noext') = '', 'ext none');
  Check(PathExt('.hidden') = '', 'ext dotfile');
  Check(PathExt('') = '', 'ext empty');
end;

procedure TestPathChangeExt;
begin
  Check(PathChangeExt('/home/file.txt', '.md') = '/home/file.md', 'change ext');
  Check(PathChangeExt('file.txt', '.pas') = 'file.pas', 'change ext no path');
  Check(PathChangeExt('noext', '.txt') = 'noext.txt', 'add ext');
end;

procedure TestPathIsAbsolute;
begin
  Check(PathIsAbsolute('/home/user') = True, 'absolute unix');
  Check(PathIsAbsolute('relative/path') = False, 'relative');
  Check(PathIsAbsolute('') = False, 'empty');
end;

procedure TestPathNormalize;
begin
  Check(PathNormalize('/home/user/../docs') = '/home/docs', 'normalize ..');
  Check(PathNormalize('/home/./user') = '/home/user', 'normalize .');
  Check(PathNormalize('') = '', 'normalize empty');
end;

procedure TestPathHasExt;
begin
  Check(PathHasExt('file.txt') = True, 'has ext');
  Check(PathHasExt('noext') = False, 'no ext');
end;

procedure TestPathWithoutExt;
begin
  Check(PathWithoutExt('file.txt') = 'file', 'without ext');
  Check(PathWithoutExt('/dir/file.pas') = '/dir/file', 'without ext path');
end;

procedure TestSysUtilsCompat;
begin
  Check(ExtractFilePath('/home/user/file.txt') = '/home/user/', 'ExtractFilePath');
  Check(ExtractFileName('/home/user/file.txt') = 'file.txt', 'ExtractFileName');
  Check(ExtractFileExt('/home/user/file.txt') = '.txt', 'ExtractFileExt');
  Check(ChangeFileExt('/home/file.txt', '.md') = '/home/file.md', 'ChangeFileExt');
  Check(ExtractFilePath('file.txt') = '', 'ExtractFilePath no dir');
end;

procedure TestExtractFilePathSourceContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'path unit has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function ExtractFilePath(const AFileName: string): string;',
    'function ExtractFileName');

  CheckContains(LBody, 'PLATFORM_PATH_SEP',
    'ExtractFilePath appends platform separator');
  CheckAbsent(LBody, 'Result := LDir + ''/''',
    'ExtractFilePath does not hard-code Unix separator');
end;

begin
  T := TTestRunner.Create('nextpas.core.path');
  T.Run('PathJoin', @TestPathJoin);
  T.Run('PathJoin3', @TestPathJoin3);
  T.Run('PathDir', @TestPathDir);
  T.Run('PathBase', @TestPathBase);
  T.Run('PathExt', @TestPathExt);
  T.Run('PathChangeExt', @TestPathChangeExt);
  T.Run('PathIsAbsolute', @TestPathIsAbsolute);
  T.Run('PathNormalize', @TestPathNormalize);
  T.Run('PathHasExt', @TestPathHasExt);
  T.Run('PathWithoutExt', @TestPathWithoutExt);
  T.Run('SysUtils compat', @TestSysUtilsCompat);
  T.Run('ExtractFilePath source contract', @TestExtractFilePathSourceContract);
  T.Summary;
end.
