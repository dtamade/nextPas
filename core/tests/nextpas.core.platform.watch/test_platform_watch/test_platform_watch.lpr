program test_platform_watch;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.watch');
  T.Run('create/close', @TestCreateClose);
  T.Run('add watch', @TestAddWatch);
  T.Run('detect file create', @TestDetectCreate);
  T.Run('no event timeout', @TestNoEvent);
  T.Run('double close', @TestDoubleClose);
  T.Summary;
end.
