unit nextpas.core.platform.watch;

{$I nextpas.core.settings.inc}

interface

const
  {** @desc 最大监视文件描述符数量 *}
  PLATFORM_WATCH_MAX_FDS = 256;

type
  {** @desc 文件系统监视事件 *}
  TPlatformWatchEvent = record
    Name: array[0..255] of AnsiChar;
    NameLen: Int32;
    Wd: Int32;  { watch descriptor / platform id for L2 path map }
    IsDir: Boolean;
    Modified: Boolean;
    Created: Boolean;
    Deleted: Boolean;
    {** @desc 检查是否有任何事件
        @return True 如果有任何事件 *}
    function HasAnyEvent: Boolean; inline;
    {** @desc 检查是否为文件修改事件
        @return True 如果是修改事件 *}
    function IsFileModified: Boolean; inline;
    {** @desc 检查是否为目录修改事件
        @return True 如果是目录修改事件 *}
    function IsDirModified: Boolean; inline;
    {** @desc 检查是否为创建事件
        @return True 如果是创建事件 *}
    function IsCreated: Boolean; inline;
    {** @desc 检查是否为删除事件
        @return True 如果是删除事件 *}
    function IsDeleted: Boolean; inline;
    {** @desc 获取文件名字符串（带长度）
        @return 文件名字符串切片 *}
    function NameStr: AnsiString;
  end;

  {** @desc 文件系统监视器（平台无关封装） *}
  TPlatformWatcher = record
    Fd: Int32;
  {$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
    WatchFds: array[0..PLATFORM_WATCH_MAX_FDS - 1] of Int32;
    WatchCount: Int32;
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
    { Residual inotify read buffer — do not drop multi-event batches (R30). }
    PendBuf: array[0..4095] of Byte;
    PendLen: Int32;
    PendPos: Int32;
  {$ENDIF}
    {** @desc 检查监视器是否有效
        @return True 如果监视器有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查监视器是否无效
        @return True 如果监视器无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 添加监视路径
        @param APath 要监视的路径
        @return 0 成功，否则返回错误码 *}
    function Add(const APath: PAnsiChar): Int32;
    {** @desc 等待文件系统事件
        @param AEvent 输出事件信息
        @param ATimeoutMs 超时时间（毫秒，-1 表示无限等待）
        @return 0 成功，PLATFORM_ERR_TIMEDOUT 超时 *}
    function Poll(out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
    {** @desc 关闭监视器
        @return 0 成功，否则返回错误码 *}
    function Close: Int32;
  end;

{** @desc 创建文件系统监视器
    @param AWatcher 输出监视器句柄
    @return 0 成功，否则返回错误码 *}
function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;

{** @desc 添加监视路径
    @param AWatcher 监视器句柄
    @param APath 要监视的路径
    @return 0 成功，否则返回错误码 *}
function platform_watch_add(var AWatcher: TPlatformWatcher;
  const APath: PAnsiChar): Int32;

{** @desc 等待文件系统事件
    @param AWatcher 监视器句柄
    @param AEvent 输出事件信息
    @param ATimeoutMs 超时时间（毫秒，-1 表示无限等待）
    @return 0 成功，PLATFORM_ERR_TIMEDOUT 超时 *}
function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;

{** @desc 关闭监视器
    @param AWatcher 监视器句柄（置为无效）
    @return 0 成功，否则返回错误码 *}
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.errno,
  nextpas.core.platform.error,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;

function TPlatformWatcher.IsValid: Boolean;
begin
  Result := Fd >= 0;
end;

function TPlatformWatcher.IsInvalid: Boolean;
begin
  Result := Fd < 0;
end;

function TPlatformWatcher.Add(const APath: PAnsiChar): Int32;
begin
  Result := platform_watch_add(Self, APath);
end;

function TPlatformWatcher.Poll(out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin
  Result := platform_watch_poll(Self, AEvent, ATimeoutMs);
end;

function TPlatformWatcher.Close: Int32;
begin
  Result := platform_watch_close(Self);
end;

function TPlatformWatchEvent.HasAnyEvent: Boolean;
begin
  Result := Modified or Created or Deleted;
end;

function TPlatformWatchEvent.IsFileModified: Boolean;
begin
  Result := Modified and (not IsDir);
end;

function TPlatformWatchEvent.IsDirModified: Boolean;
begin
  Result := Modified and IsDir;
end;

function TPlatformWatchEvent.IsCreated: Boolean;
begin
  Result := Created;
end;

function TPlatformWatchEvent.IsDeleted: Boolean;
begin
  Result := Deleted;
end;

function TPlatformWatchEvent.NameStr: AnsiString;
begin
  SetString(Result, PAnsiChar(@Name[0]), NameLen);
end;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin
  FillChar(AWatcher, SizeOf(AWatcher), 0);
  AWatcher.Fd := inotify_init1(IN_NONBLOCK);
  if AWatcher.Fd < 0 then
    Result := platform_get_errno
  else
  begin
    AWatcher.PendLen := 0;
    AWatcher.PendPos := 0;
    Result := 0;
  end;
end;

function platform_watch_add(var AWatcher: TPlatformWatcher;
  const APath: PAnsiChar): Int32;
var
  LWd: Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  LWd := inotify_add_watch(AWatcher.Fd, APath,
    IN_MODIFY or IN_CREATE or IN_DELETE or IN_MOVED_FROM or IN_MOVED_TO);
  if LWd < 0 then
    Result := platform_get_errno
  else
    Result := LWd;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
type
  TInotifyEvent = packed record
    wd: Int32;
    mask: UInt32;
    cookie: UInt32;
    len: UInt32;
  end;
var
  LRead: PtrInt;
  LEvt: ^TInotifyEvent;
  LName: PAnsiChar;
  I: Int32;
  LNeed: Int32;
  LPollFd: record fd: Int32; events: Int16; revents: Int16; end;

  function DecodeAtPos: Boolean;
  begin
    Result := False;
    if AWatcher.PendPos + SizeOf(TInotifyEvent) > AWatcher.PendLen then
      Exit;
    LEvt := @AWatcher.PendBuf[AWatcher.PendPos];
    LNeed := SizeOf(TInotifyEvent) + Int32(LEvt^.len);
    if (LNeed < SizeOf(TInotifyEvent)) or
       (AWatcher.PendPos + LNeed > AWatcher.PendLen) then
      Exit;
    FillChar(AEvent, SizeOf(AEvent), 0);
    AEvent.Wd := LEvt^.wd;
    AEvent.Modified := (LEvt^.mask and IN_MODIFY) <> 0;
    AEvent.Created := (LEvt^.mask and (IN_CREATE or IN_MOVED_TO)) <> 0;
    AEvent.Deleted := (LEvt^.mask and (IN_DELETE or IN_MOVED_FROM)) <> 0;
    AEvent.IsDir := (LEvt^.mask and IN_ISDIR) <> 0;
    if LEvt^.len > 0 then
    begin
      LName := PAnsiChar(@AWatcher.PendBuf[AWatcher.PendPos + SizeOf(TInotifyEvent)]);
      I := 0;
      while (I < 255) and (I < Int32(LEvt^.len)) and (LName[I] <> #0) do
      begin
        AEvent.Name[I] := LName[I];
        Inc(I);
      end;
      AEvent.Name[I] := #0;
      AEvent.NameLen := I;
    end;
    Inc(AWatcher.PendPos, LNeed);
    if AWatcher.PendPos >= AWatcher.PendLen then
    begin
      AWatcher.PendPos := 0;
      AWatcher.PendLen := 0;
    end;
    Result := True;
  end;

begin
  FillChar(AEvent, SizeOf(AEvent), 0);

  { Drain residual multi-event batch first (R30). }
  if AWatcher.PendPos < AWatcher.PendLen then
  begin
    if DecodeAtPos then
      Exit(1);
    { corrupt residual — drop }
    AWatcher.PendPos := 0;
    AWatcher.PendLen := 0;
  end;

  if ATimeoutMs <> 0 then
  begin
    LPollFd.fd := AWatcher.Fd;
    LPollFd.events := 1; // POLLIN
    LPollFd.revents := 0;
    if poll(@LPollFd, 1, ATimeoutMs) <= 0 then
      Exit(0); // no events
  end;

  LRead := read(AWatcher.Fd, @AWatcher.PendBuf[0], SizeOf(AWatcher.PendBuf));
  if LRead <= 0 then
    Exit(0);
  AWatcher.PendLen := Int32(LRead);
  AWatcher.PendPos := 0;
  if DecodeAtPos then
    Result := 1
  else
  begin
    AWatcher.PendPos := 0;
    AWatcher.PendLen := 0;
    Result := 0;
  end;
end;

function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin
  AWatcher.PendLen := 0;
  AWatcher.PendPos := 0;
  if AWatcher.Fd >= 0 then
  begin
    close(AWatcher.Fd);
    AWatcher.Fd := -1;
    Result := 0;
  end
  else
    Result := PLATFORM_ERR_BADF;
end;
{$ENDIF}

{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.errno,
  nextpas.core.platform.error,
{$IFDEF NEXTPAS_MACOS}
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;
{$ELSE}
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;
{$ENDIF}

function TPlatformWatcher.IsValid: Boolean;
begin
  Result := Fd >= 0;
end;

function TPlatformWatcher.IsInvalid: Boolean;
begin
  Result := Fd < 0;
end;

function TPlatformWatcher.Add(const APath: PAnsiChar): Int32;
begin
  Result := platform_watch_add(Self, APath);
end;

function TPlatformWatcher.Poll(out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin
  Result := platform_watch_poll(Self, AEvent, ATimeoutMs);
end;

function TPlatformWatcher.Close: Int32;
begin
  Result := platform_watch_close(Self);
end;

function TPlatformWatchEvent.HasAnyEvent: Boolean;
begin
  Result := Modified or Created or Deleted;
end;

function TPlatformWatchEvent.IsFileModified: Boolean;
begin
  Result := Modified and (not IsDir);
end;

function TPlatformWatchEvent.IsDirModified: Boolean;
begin
  Result := Modified and IsDir;
end;

function TPlatformWatchEvent.IsCreated: Boolean;
begin
  Result := Created;
end;

function TPlatformWatchEvent.IsDeleted: Boolean;
begin
  Result := Deleted;
end;

function TPlatformWatchEvent.NameStr: AnsiString;
begin
  SetString(Result, PAnsiChar(@Name[0]), NameLen);
end;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin
  FillChar(AWatcher, SizeOf(AWatcher), 0);
  AWatcher.Fd := kqueue;
  if AWatcher.Fd < 0 then
  begin
    AWatcher.Fd := -1;
    Result := platform_get_errno;
  end
  else
  begin
    AWatcher.WatchCount := 0;
    Result := 0;
  end;
end;

function platform_watch_add(var AWatcher: TPlatformWatcher;
  const APath: PAnsiChar): Int32;
var
  LFd: Int32;
  LChange: TKEvent;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if AWatcher.WatchCount >= PLATFORM_WATCH_MAX_FDS then
    Exit(PLATFORM_ERR_NOSPC);
  LFd := open(APath, O_RDONLY, 0);
  if LFd < 0 then
    Exit(platform_get_errno);

  FillChar(LChange, SizeOf(LChange), 0);
  LChange.Ident := PtrUInt(LFd);
  LChange.Filter := EVFILT_VNODE;
  LChange.Flags := EV_ADD or EV_CLEAR;
  LChange.FFlags := NOTE_WRITE or NOTE_DELETE or NOTE_RENAME or NOTE_EXTEND or NOTE_ATTRIB;
  LChange.uData := nil;

  if kevent(AWatcher.Fd, @LChange, 1, nil, 0, nil) < 0 then
  begin
    close(LFd);
    Exit(platform_get_errno);
  end;

  AWatcher.WatchFds[AWatcher.WatchCount] := LFd;
  Inc(AWatcher.WatchCount);
  Result := LFd;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
var
  LEvent: TKEvent;
  LTimeout: TTimeSpec;
  LTimeoutPtr: Pointer;
  LRet: Int32;
begin
  FillChar(AEvent, SizeOf(AEvent), 0);

  if ATimeoutMs >= 0 then
  begin
    LTimeout.tv_sec := ATimeoutMs div 1000;
    LTimeout.tv_nsec := (ATimeoutMs mod 1000) * 1000000;
    LTimeoutPtr := @LTimeout;
  end
  else
    LTimeoutPtr := nil;

  FillChar(LEvent, SizeOf(LEvent), 0);
  LRet := kevent(AWatcher.Fd, nil, 0, @LEvent, 1, LTimeoutPtr);
  if LRet <= 0 then
    Exit(0);

  if (LEvent.Flags and EV_ERROR) <> 0 then
    Exit(0);

  AEvent.Wd := Int32(LEvent.Ident);
  AEvent.Modified := (LEvent.FFlags and (NOTE_WRITE or NOTE_EXTEND)) <> 0;
  AEvent.Deleted := (LEvent.FFlags and NOTE_DELETE) <> 0;
  AEvent.Created := (LEvent.FFlags and NOTE_WRITE) <> 0;
  AEvent.IsDir := True;
  Result := 1;
end;

function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
var
  I: Int32;
begin
  for I := 0 to AWatcher.WatchCount - 1 do
    if AWatcher.WatchFds[I] >= 0 then
      close(AWatcher.WatchFds[I]);
  if AWatcher.Fd >= 0 then
  begin
    close(AWatcher.Fd);
    AWatcher.Fd := -1;
  end;
  AWatcher.WatchCount := 0;
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base;

function TPlatformWatcher.IsValid: Boolean;
begin
  Result := Fd >= 0;
end;

function TPlatformWatcher.IsInvalid: Boolean;
begin
  Result := Fd < 0;
end;

function TPlatformWatcher.Add(const APath: PAnsiChar): Int32;
begin
  Result := platform_watch_add(Self, APath);
end;

function TPlatformWatcher.Poll(out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin
  Result := platform_watch_poll(Self, AEvent, ATimeoutMs);
end;

function TPlatformWatcher.Close: Int32;
begin
  Result := platform_watch_close(Self);
end;

function TPlatformWatchEvent.HasAnyEvent: Boolean;
begin Result := Modified or Created or Deleted; end;
function TPlatformWatchEvent.IsFileModified: Boolean;
begin Result := Modified and (not IsDir); end;
function TPlatformWatchEvent.IsDirModified: Boolean;
begin Result := Modified and IsDir; end;
function TPlatformWatchEvent.IsCreated: Boolean;
begin Result := Created; end;
function TPlatformWatchEvent.IsDeleted: Boolean;
begin Result := Deleted; end;
function TPlatformWatchEvent.NameStr: AnsiString;
begin SetString(Result, PAnsiChar(@Name[0]), NameLen); end;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin
  AWatcher.Fd := -1;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
begin
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin
  FillChar(AEvent, SizeOf(AEvent), 0);
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin
  AWatcher.Fd := -1;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function TPlatformWatchEvent.HasAnyEvent: Boolean;
begin Result := Modified or Created or Deleted; end;
function TPlatformWatchEvent.IsFileModified: Boolean;
begin Result := Modified and (not IsDir); end;
function TPlatformWatchEvent.IsDirModified: Boolean;
begin Result := Modified and IsDir; end;
function TPlatformWatchEvent.NameStr: AnsiString;
begin SetString(Result, PAnsiChar(@Name[0]), NameLen); end;
function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
begin AWatcher.Fd := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin FillChar(AEvent, SizeOf(AEvent), 0); Result := 0; end;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
