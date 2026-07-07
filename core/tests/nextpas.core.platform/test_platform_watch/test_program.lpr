program test_platform_watch;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.watch,
  nextpas.core.platform.error;

var
  T: TTestSuite;

procedure TestWatchCreate;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  Check(LWatcher.Fd > -1, 'fd must be positive');
  platform_watch_close(LWatcher);
end;

procedure TestWatchCreateNilGuard;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  FillChar(LWatcher, SizeOf(LWatcher), 0);
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  platform_watch_close(LWatcher);
end;

procedure TestWatchAddNilPath;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  LRes := platform_watch_add(LWatcher, nil);
  Check(LRes = PLATFORM_ERR_INVALID, 'nil path must return invalid');
  platform_watch_close(LWatcher);
end;

procedure TestWatchAddInvalidPath;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  LRes := platform_watch_add(LWatcher, '/nonexistent/path/that/does/not/exist');
  Check(LRes > 0, 'invalid path must return errno');
  platform_watch_close(LWatcher);
end;

procedure TestWatchPollTimeout;
var
  LWatcher: TPlatformWatcher;
  LEvent: TPlatformWatchEvent;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  LRes := platform_watch_poll(LWatcher, LEvent, 10);
  Check(LRes = 0, 'poll timeout must succeed');
  platform_watch_close(LWatcher);
end;

procedure TestWatchClose;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  LRes := platform_watch_close(LWatcher);
  Check(LRes = 0, 'close must succeed');
  Check(LWatcher.Fd = -1, 'fd must be -1 after close');
end;

procedure TestWatchCloseIdempotent;
var
  LWatcher: TPlatformWatcher;
  LRes: Int32;
begin
  LRes := platform_watch_create(LWatcher);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create must succeed');
  LRes := platform_watch_close(LWatcher);
  Check(LRes = 0, 'first close must succeed');
  LRes := platform_watch_close(LWatcher);
  Check(LRes = PLATFORM_ERR_BADF, 'second close must return PLATFORM_ERR_BADF (already closed)');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.watch');
  T.Test('create watcher', @TestWatchCreate);
  T.Test('create watcher nil guard', @TestWatchCreateNilGuard);
  T.Test('add nil path returns invalid', @TestWatchAddNilPath);
  T.Test('add invalid path returns error', @TestWatchAddInvalidPath);
  T.Test('poll timeout', @TestWatchPollTimeout);
  T.Test('close watcher', @TestWatchClose);
  T.Test('close idempotent', @TestWatchCloseIdempotent);
  if not T.Run then Halt(1);
end.
