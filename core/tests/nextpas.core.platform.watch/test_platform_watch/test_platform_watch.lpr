program test_platform_watch;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.watch,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := LowerCase(FsReadFileText(LSourcePath));
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

procedure TestAddWatchNilPath;
var
  W: TPlatformWatcher;
begin
  Check(platform_watch_create(W) = 0, 'create');
  Check(platform_watch_add(W, nil) <> 0, 'nil path returns error');
  platform_watch_close(W);
end;

procedure TestAddWatchNonExistent;
var
  W: TPlatformWatcher;
begin
  Check(platform_watch_create(W) = 0, 'create');
  Check(platform_watch_add(W, '/tmp/nonexistent_watch_dir_12345') <> 0, 'nonexistent path returns error');
  platform_watch_close(W);
end;

procedure TestDetectModify;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test4', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test4');

  // Create file first
  platform_file_open('/tmp/nextpas_watch_test4/modify.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('initial'), 7, LWritten);
  platform_file_close(H);

  // Wait a bit then modify
  platform_watch_poll(W, Evt, 100); // consume create event

  platform_file_open('/tmp/nextpas_watch_test4/modify.txt', fomWriteOnly, fcmOpenExisting, H);
  platform_file_write(H, PAnsiChar('modified'), 8, LWritten);
  platform_file_close(H);

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got modify event');
  Check(Evt.Modified, 'event is modified');

  platform_watch_close(W);
  platform_file_unlink('/tmp/nextpas_watch_test4/modify.txt');
  platform_file_rmdir('/tmp/nextpas_watch_test4');
end;

procedure TestDetectDelete;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test5', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test5');

  // Create file
  platform_file_open('/tmp/nextpas_watch_test5/delete.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H);

  // Wait a bit then delete
  platform_watch_poll(W, Evt, 100); // consume create event

  platform_file_unlink('/tmp/nextpas_watch_test5/delete.txt');

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got delete event');
  Check(Evt.Deleted, 'event is deleted');

  platform_watch_close(W);
  platform_file_rmdir('/tmp/nextpas_watch_test5');
end;

procedure TestDetectDirectoryCreate;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test6', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test6');

  platform_file_mkdir('/tmp/nextpas_watch_test6/subdir', 493);

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got directory create event');
  Check(Evt.IsDir, 'event is directory');

  platform_watch_close(W);
  platform_file_rmdir('/tmp/nextpas_watch_test6/subdir');
  platform_file_rmdir('/tmp/nextpas_watch_test6');
end;

procedure TestMultipleWatches;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test7a', 493);
  platform_file_mkdir('/tmp/nextpas_watch_test7b', 493);
  Check(platform_watch_create(W) = 0, 'create');
  Check(platform_watch_add(W, '/tmp/nextpas_watch_test7a') >= 0, 'add first watch');
  Check(platform_watch_add(W, '/tmp/nextpas_watch_test7b') >= 0, 'add second watch');

  platform_file_open('/tmp/nextpas_watch_test7a/file.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H);

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got event from first watch');

  platform_watch_close(W);
  platform_file_unlink('/tmp/nextpas_watch_test7a/file.txt');
  platform_file_rmdir('/tmp/nextpas_watch_test7a');
  platform_file_rmdir('/tmp/nextpas_watch_test7b');
end;

procedure TestPollZeroTimeout;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test8', 493);
  Check(platform_watch_create(W) = 0, 'create');
  platform_watch_add(W, '/tmp/nextpas_watch_test8');

  R := platform_watch_poll(W, Evt, 0);
  Check(R = 0, 'zero timeout returns immediately');

  platform_watch_close(W);
  platform_file_rmdir('/tmp/nextpas_watch_test8');
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

procedure TestWatchAddSameDirTwice;
var
  W: TPlatformWatcher;
  Evt: TPlatformWatchEvent;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_mkdir('/tmp/nextpas_watch_test9', 493);
  Check(platform_watch_create(W) = 0, 'create');
  Check(platform_watch_add(W, '/tmp/nextpas_watch_test9') >= 0, 'add first');
  { Adding same dir twice may succeed or return error }
  platform_watch_add(W, '/tmp/nextpas_watch_test9');

  platform_file_open('/tmp/nextpas_watch_test9/file.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H);

  R := platform_watch_poll(W, Evt, 1000);
  Check(R > 0, 'got event after double add');

  platform_watch_close(W);
  platform_file_unlink('/tmp/nextpas_watch_test9/file.txt');
  platform_file_rmdir('/tmp/nextpas_watch_test9');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.watch');
  T.Test('create/close', @TestCreateClose);
  T.Test('add watch', @TestAddWatch);
  T.Test('detect file create', @TestDetectCreate);
  T.Test('no event timeout', @TestNoEvent);
  T.Test('double close', @TestDoubleClose);
  T.Test('add watch nil path', @TestAddWatchNilPath);
  T.Test('add watch non-existent', @TestAddWatchNonExistent);
  T.Test('detect modify', @TestDetectModify);
  T.Test('detect delete', @TestDetectDelete);
  T.Test('detect directory create', @TestDetectDirectoryCreate);
  T.Test('multiple watches', @TestMultipleWatches);
  T.Test('poll zero timeout', @TestPollZeroTimeout);
  T.Test('Windows watch source contract', @TestWindowsWatchSourceContract);
  T.Test('add same dir twice', @TestWatchAddSameDirTwice);
  if not T.Run then Halt(1);
end.
