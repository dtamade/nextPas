unit nextpas.core.platform.watch;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformWatcher = record
    Fd: Int32;
  end;

  TPlatformWatchEvent = record
    Name: array[0..255] of AnsiChar;
    NameLen: Int32;
    IsDir: Boolean;
    Modified: Boolean;
    Created: Boolean;
    Deleted: Boolean;
  end;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
function platform_watch_add(var AWatcher: TPlatformWatcher;
  const APath: PAnsiChar): Int32;
function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int32): Int32;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin
  AWatcher.Fd := inotify_init1(IN_NONBLOCK);
  if AWatcher.Fd < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_watch_add(var AWatcher: TPlatformWatcher;
  const APath: PAnsiChar): Int32;
var
  LWd: Int32;
begin
  LWd := inotify_add_watch(AWatcher.Fd, APath,
    IN_MODIFY or IN_CREATE or IN_DELETE or IN_MOVED_FROM or IN_MOVED_TO);
  if LWd < 0 then
    Result := platform_get_errno
  else
    Result := LWd;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int32): Int32;
type
  TInotifyEvent = packed record
    wd: Int32;
    mask: UInt32;
    cookie: UInt32;
    len: UInt32;
  end;
var
  LBuf: array[0..4095] of Byte;
  LRead: PtrInt;
  LEvt: ^TInotifyEvent;
  LName: PAnsiChar;
  I: Int32;
  LPollFd: record fd: Int32; events: Int16; revents: Int16; end;
begin
  FillChar(AEvent, SizeOf(AEvent), 0);

  if ATimeoutMs <> 0 then
  begin
    LPollFd.fd := AWatcher.Fd;
    LPollFd.events := 1; // POLLIN
    LPollFd.revents := 0;
    if poll(@LPollFd, 1, ATimeoutMs) <= 0 then
      Exit(0); // no events
  end;

  LRead := read(AWatcher.Fd, @LBuf[0], 4096);
  if LRead <= 0 then
    Exit(0);

  LEvt := @LBuf[0];
  AEvent.Modified := (LEvt^.mask and IN_MODIFY) <> 0;
  AEvent.Created := (LEvt^.mask and (IN_CREATE or IN_MOVED_TO)) <> 0;
  AEvent.Deleted := (LEvt^.mask and (IN_DELETE or IN_MOVED_FROM)) <> 0;
  AEvent.IsDir := (LEvt^.mask and IN_ISDIR) <> 0;

  if LEvt^.len > 0 then
  begin
    LName := PAnsiChar(@LBuf[SizeOf(TInotifyEvent)]);
    I := 0;
    while (I < 255) and (I < Int32(LEvt^.len)) and (LName[I] <> #0) do
    begin
      AEvent.Name[I] := LName[I];
      Inc(I);
    end;
    AEvent.Name[I] := #0;
    AEvent.NameLen := I;
  end;
  Result := 1;
end;

function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin
  if AWatcher.Fd >= 0 then
  begin
    close(AWatcher.Fd);
    AWatcher.Fd := -1;
    Result := 0;
  end
  else
    Result := -1;
end;
{$ENDIF}

{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin AWatcher.Fd := -1; Result := -1; end;
function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
begin Result := -1; end;
function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int32): Int32;
begin FillChar(AEvent, SizeOf(AEvent), 0); Result := 0; end;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin Result := -1; end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin AWatcher.Fd := -1; Result := -1; end;
function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
begin Result := -1; end;
function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int32): Int32;
begin FillChar(AEvent, SizeOf(AEvent), 0); Result := 0; end;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin Result := -1; end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin AWatcher.Fd := -1; Result := -1; end;
function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
begin Result := -1; end;
function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int32): Int32;
begin FillChar(AEvent, SizeOf(AEvent), 0); Result := 0; end;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin Result := -1; end;
{$ENDIF}

end.
