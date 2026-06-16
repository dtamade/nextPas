program test_platform_watch;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.platform.watch,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

function ExtractBetween(const ASource, AStartToken, AEndToken: string): string;
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
begin
  LStartPos := Pos(AStartToken, ASource);
  Check(LStartPos > 0, 'source range start should exist: ' + AStartToken);
  LEndPos := Pos(AEndToken, Copy(ASource, LStartPos + Length(AStartToken),
    Length(ASource)));
  Check(LEndPos > 0, 'source range end should exist: ' + AEndToken);
  Result := Copy(ASource, LStartPos, Length(AStartToken) + LEndPos - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestCreateClose;
var
  W: TPlatformWatcher;
begin
  Check(platform_watch_create(W) = 0, 'create');
  Check(W.Fd >= 0, 'fd valid');
  Check(platform_watch_close(W) = 0, 'close');
end;

procedure TestAddWatch;
var
  W: TPlatformWatcher;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test', 493);
  Check(platform_watch_create(W) = 0, 'create');
  R := platform_watch_add(W, '/tmp/nextpas_watch_test');
  Check(R >= 0, 'add returns wd >= 0');
  platform_watch_close(W);
  platform_file_rmdir('/tmp/nextpas_watch_test');
end;

procedure TestDetectCreate;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test2', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test2');

  platform_file_open('/tmp/nextpas_watch_test2/new.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H);

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got event');
  Check(Evt.NameLen > 0, 'event has name');

  platform_watch_close(W);
  platform_file_unlink('/tmp/nextpas_watch_test2/new.txt');
  platform_file_rmdir('/tmp/nextpas_watch_test2');
end;

procedure TestNoEvent;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test3', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test3');
  R := platform_watch_poll(W, Evt, 10);
  Check(R = 0, 'no event with short timeout');
  platform_watch_close(W);
  platform_file_rmdir('/tmp/nextpas_watch_test3');
end;

procedure TestDoubleClose;
var
  W: TPlatformWatcher;
begin
  Check(platform_watch_create(W) = 0, 'create');
  Check(platform_watch_close(W) = 0, 'close first');
  Check(platform_watch_close(W) <> 0, 'close second error');
end;

procedure TestWindowsWatchSourceContract;
var
  LWatch: string;
  LWindowsBranch: string;
begin
  LWatch := LoadSourceText('src/nextpas.core.platform.watch.pas');
  LWindowsBranch := ExtractBetween(LWatch, '{$ifdef nextpas_windows}',
    '{$if not defined(nextpas_linux) and not defined(nextpas_macos)');

  CheckContains(LWindowsBranch, 'error_not_supported',
    'Windows watch branch must expose stable unsupported semantics');
  CheckContains(LWindowsBranch, '-int32(error_not_supported)',
    'Windows watch poll must not report unsupported as a ready event');
  CheckContains(LWindowsBranch, 'aevent',
    'Windows watch poll must keep the event out parameter deterministic');
  CheckAbsent(LWindowsBranch, 'result := -1',
    'Windows watch branch must not remain bare -1 stubs');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.watch');
  T.Run('create/close', @TestCreateClose);
  T.Run('add watch', @TestAddWatch);
  T.Run('detect file create', @TestDetectCreate);
  T.Run('no event timeout', @TestNoEvent);
  T.Run('double close', @TestDoubleClose);
  T.Run('Windows watch source contract', @TestWindowsWatchSourceContract);
  T.Summary;
end.
