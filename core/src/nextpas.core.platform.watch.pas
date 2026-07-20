unit nextpas.core.platform.watch;

{$I nextpas.core.settings.inc}

interface

const
  {** @desc 最大监视文件描述符数量 *}
  PLATFORM_WATCH_MAX_FDS = 256;
  {** @desc Windows multi-dir slots (fs.watch multi Add). *}
  PLATFORM_WATCH_WIN_MAX = 8;
  PLATFORM_WATCH_WIN_BUF = 8192;

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

{$IFDEF NEXTPAS_WINDOWS}
  {** Per-directory RDCW state; OVERLAPPED address must stay fixed. *}
  TPlatformWinWatchSlot = record
    DirHandle: Pointer;
    NotifyEvent: Pointer;
    OverlappedRaw: array[0..31] of Byte;
    Buf: array[0..PLATFORM_WATCH_WIN_BUF - 1] of Byte;
    PendLen: Int32;
    PendPos: Int32;
    Pending: Boolean;
    Active: Boolean;
  end;
{$ENDIF}

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
  {$IFDEF NEXTPAS_WINDOWS}
    Slots: array[0..PLATFORM_WATCH_WIN_MAX - 1] of TPlatformWinWatchSlot;
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

{** @desc 移除监视（Linux: inotify wd；kqueue: watch fd）
    @return 0 成功，否则错误码 *}
function platform_watch_remove(var AWatcher: TPlatformWatcher;
  const AWd: Int32): Int32;

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

function platform_watch_remove(var AWatcher: TPlatformWatcher;
  const AWd: Int32): Int32;
begin
  if AWd < 0 then
    Exit(PLATFORM_ERR_INVALID);
  if AWatcher.Fd < 0 then
    Exit(PLATFORM_ERR_BADF);
  if inotify_rm_watch(AWatcher.Fd, AWd) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
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

function platform_watch_remove(var AWatcher: TPlatformWatcher;
  const AWd: Int32): Int32;
var
  I, J: Int32;
begin
  if AWd < 0 then
    Exit(PLATFORM_ERR_INVALID);
  for I := 0 to AWatcher.WatchCount - 1 do
    if AWatcher.WatchFds[I] = AWd then
    begin
      close(AWd);
      for J := I to AWatcher.WatchCount - 2 do
        AWatcher.WatchFds[J] := AWatcher.WatchFds[J + 1];
      Dec(AWatcher.WatchCount);
      Exit(0);
    end;
  Result := PLATFORM_ERR_NOENT;
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
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;

function WinWatchHandleInvalid(AHandle: HANDLE): Boolean; inline;
begin
  Result := (AHandle = nil) or (AHandle = HANDLE(PtrInt(-1)));
end;

function TPlatformWatcher.IsValid: Boolean;
var
  I: Int32;
begin
  Result := False;
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    if Slots[I].Active then
      Exit(True);
end;

function TPlatformWatcher.IsInvalid: Boolean;
begin
  Result := not IsValid;
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

{ Batch-15 S1–S3 + multi-dir slots (Batch-23). }

const
  WIN_WATCH_NOTIFY_FILTER =
    FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME or
    FILE_NOTIFY_CHANGE_ATTRIBUTES or FILE_NOTIFY_CHANGE_SIZE or
    FILE_NOTIFY_CHANGE_LAST_WRITE;

function WinWatchSlotOvl(var ASlot: TPlatformWinWatchSlot): LPOVERLAPPED; inline;
begin
  Result := LPOVERLAPPED(@ASlot.OverlappedRaw[0]);
end;

procedure WinWatchClearSlot(var ASlot: TPlatformWinWatchSlot);
begin
  FillChar(ASlot, SizeOf(ASlot), 0);
  ASlot.DirHandle := Pointer(HANDLE(PtrInt(-1)));
  ASlot.Active := False;
end;

function WinWatchArmSlot(var ASlot: TPlatformWinWatchSlot): Int32;
var
  LBytes: DWORD;
  LOvl: LPOVERLAPPED;
  LErr: DWORD;
begin
  LOvl := WinWatchSlotOvl(ASlot);
  FillChar(LOvl^, SizeOf(OVERLAPPED), 0);
  LOvl^.hEvent := HANDLE(ASlot.NotifyEvent);
  LBytes := 0;
  ASlot.PendLen := 0;
  ASlot.PendPos := 0;
  if ReadDirectoryChangesW(
       HANDLE(ASlot.DirHandle),
       @ASlot.Buf[0],
       DWORD(SizeOf(ASlot.Buf)),
       False,
       WIN_WATCH_NOTIFY_FILTER,
       @LBytes,
       LOvl,
       nil) then
  begin
    ASlot.Pending := False;
    ASlot.PendLen := Int32(LBytes);
    ASlot.PendPos := 0;
    Result := 0;
  end
  else
  begin
    LErr := GetLastError;
    if LErr = ERROR_IO_PENDING then
    begin
      ASlot.Pending := True;
      Result := 0;
    end
    else if LErr = ERROR_NOTIFY_ENUM_DIR then
    begin
      ASlot.Pending := False;
      Result := PLATFORM_ERR_AGAIN;
    end
    else
      Result := platform_get_last_error;
  end;
end;

function WinWatchMapSlotIoError(var ASlot: TPlatformWinWatchSlot): Int32;
var
  LErr: DWORD;
  LArm: Int32;
begin
  LErr := GetLastError;
  ASlot.Pending := False;
  ASlot.PendLen := 0;
  ASlot.PendPos := 0;
  if LErr = ERROR_NOTIFY_ENUM_DIR then
  begin
    LArm := WinWatchArmSlot(ASlot);
    if LArm <> 0 then
      Exit(LArm);
    Exit(PLATFORM_ERR_AGAIN);
  end;
  Result := platform_get_last_error;
end;

function WinWatchDecodeSlot(var ASlot: TPlatformWinWatchSlot; AWd: Int32;
  out AEvent: TPlatformWatchEvent): Boolean;
var
  LBase: PByte;
  LNext: DWORD;
  LAction: DWORD;
  LNameBytes: DWORD;
  LNameW: array[0..260] of WideChar;
  LChars: Int32;
  LUtf8: AnsiString;
  I: Int32;
begin
  Result := False;
  FillChar(AEvent, SizeOf(AEvent), 0);
  AEvent.Wd := AWd;
  if ASlot.PendPos + 12 > ASlot.PendLen then
    Exit;
  LBase := @ASlot.Buf[ASlot.PendPos];
  LNext := PDWORD(LBase)^;
  LAction := PDWORD(LBase + 4)^;
  LNameBytes := PDWORD(LBase + 8)^;
  if (LNameBytes > 520) or
     (ASlot.PendPos + 12 + Int32(LNameBytes) > ASlot.PendLen) then
    Exit;

  case LAction of
    FILE_ACTION_ADDED, FILE_ACTION_RENAMED_NEW_NAME:
      AEvent.Created := True;
    FILE_ACTION_REMOVED, FILE_ACTION_RENAMED_OLD_NAME:
      AEvent.Deleted := True;
    FILE_ACTION_MODIFIED:
      AEvent.Modified := True;
  end;

  if LNameBytes > 0 then
  begin
    LChars := Int32(LNameBytes) div SizeOf(WideChar);
    if LChars > 260 then
      LChars := 260;
    Move((LBase + 12)^, LNameW[0], LChars * SizeOf(WideChar));
    LNameW[LChars] := #0;
    LUtf8 := platform_windows_wide_to_utf8(@LNameW[0]);
    I := 0;
    while (I < 255) and (I < Length(LUtf8)) do
    begin
      AEvent.Name[I] := LUtf8[I + 1];
      Inc(I);
    end;
    AEvent.Name[I] := #0;
    AEvent.NameLen := I;
  end;

  if LNext = 0 then
    ASlot.PendPos := ASlot.PendLen
  else
    Inc(ASlot.PendPos, Int32(LNext));
  Result := True;
end;

procedure WinWatchCloseSlot(var ASlot: TPlatformWinWatchSlot);
var
  LDir, LEvt: HANDLE;
  LOvl: LPOVERLAPPED;
begin
  if not ASlot.Active then
    Exit;
  LDir := HANDLE(ASlot.DirHandle);
  LEvt := HANDLE(ASlot.NotifyEvent);
  if not WinWatchHandleInvalid(LDir) then
  begin
    LOvl := WinWatchSlotOvl(ASlot);
    CancelIoEx(LDir, LOvl);
    CloseHandle(LDir);
  end;
  if (LEvt <> nil) and (LEvt <> HANDLE(PtrInt(-1))) then
    CloseHandle(LEvt);
  WinWatchClearSlot(ASlot);
end;

function platform_watch_create(out AWatcher: TPlatformWatcher): Int32;
var
  I: Int32;
begin
  FillChar(AWatcher, SizeOf(AWatcher), 0);
  AWatcher.Fd := -1;
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    WinWatchClearSlot(AWatcher.Slots[I]);
  Result := 0;
end;

function platform_watch_add(var AWatcher: TPlatformWatcher; const APath: PAnsiChar): Int32;
var
  LPath: UnicodeString;
  LHandle, LEvent: HANDLE;
  LSlot, LArm: Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(PLATFORM_ERR_INVALID);

  LSlot := -1;
  for LArm := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    if not AWatcher.Slots[LArm].Active then
    begin
      LSlot := LArm;
      Break;
    end;
  if LSlot < 0 then
    Exit(PLATFORM_ERR_NOSPC);

  LHandle := CreateFileW(
    PWideChar(LPath),
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
    nil);
  if WinWatchHandleInvalid(LHandle) then
    Exit(platform_get_last_error);

  LEvent := CreateEventW(nil, False, False, nil);
  if (LEvent = nil) or (LEvent = HANDLE(PtrInt(-1))) then
  begin
    Result := platform_get_last_error;
    CloseHandle(LHandle);
    Exit;
  end;

  WinWatchClearSlot(AWatcher.Slots[LSlot]);
  AWatcher.Slots[LSlot].DirHandle := Pointer(LHandle);
  AWatcher.Slots[LSlot].NotifyEvent := Pointer(LEvent);
  AWatcher.Slots[LSlot].Active := True;
  AWatcher.Fd := 0;
  LArm := WinWatchArmSlot(AWatcher.Slots[LSlot]);
  if LArm <> 0 then
  begin
    WinWatchCloseSlot(AWatcher.Slots[LSlot]);
    Exit(LArm);
  end;
  Result := LSlot + 1; { positive wd for fs.watch path map }
end;

function platform_watch_remove(var AWatcher: TPlatformWatcher;
  const AWd: Int32): Int32;
var
  LSlot: Int32;
begin
  if AWd < 1 then
    Exit(PLATFORM_ERR_INVALID);
  LSlot := AWd - 1;
  if (LSlot < 0) or (LSlot >= PLATFORM_WATCH_WIN_MAX) then
    Exit(PLATFORM_ERR_INVALID);
  if not AWatcher.Slots[LSlot].Active then
    Exit(0); { idempotent }
  WinWatchCloseSlot(AWatcher.Slots[LSlot]);
  Result := 0;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher;
  out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
var
  I, LCount, LIdx, LArm: Int32;
  LMs, LWait, LBytes: DWORD;
  LHandles: array[0..PLATFORM_WATCH_WIN_MAX - 1] of HANDLE;
  LMap: array[0..PLATFORM_WATCH_WIN_MAX - 1] of Int32;
  LOvl: LPOVERLAPPED;
  LSlot: ^TPlatformWinWatchSlot;
begin
  FillChar(AEvent, SizeOf(AEvent), 0);
  if AWatcher.IsInvalid then
    Exit(PLATFORM_ERR_INVALID);

  { Drain residual on any active slot first. }
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    if AWatcher.Slots[I].Active and
       (AWatcher.Slots[I].PendPos < AWatcher.Slots[I].PendLen) then
    begin
      if WinWatchDecodeSlot(AWatcher.Slots[I], I + 1, AEvent) then
        Exit(1);
      AWatcher.Slots[I].PendPos := 0;
      AWatcher.Slots[I].PendLen := 0;
    end;

  { Re-arm slots that are not pending and have no residual. }
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    if AWatcher.Slots[I].Active and (not AWatcher.Slots[I].Pending) and
       (AWatcher.Slots[I].PendLen = 0) then
    begin
      LArm := WinWatchArmSlot(AWatcher.Slots[I]);
      if LArm <> 0 then
        Exit(LArm);
      if (AWatcher.Slots[I].PendLen > 0) and
         WinWatchDecodeSlot(AWatcher.Slots[I], I + 1, AEvent) then
        Exit(1);
    end;

  LCount := 0;
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    if AWatcher.Slots[I].Active and AWatcher.Slots[I].Pending then
    begin
      LHandles[LCount] := HANDLE(AWatcher.Slots[I].NotifyEvent);
      LMap[LCount] := I;
      Inc(LCount);
    end;
  if LCount = 0 then
    Exit(0);

  if ATimeoutMs < 0 then
    LMs := INFINITE
  else if ATimeoutMs = 0 then
    LMs := 0
  else if ATimeoutMs > High(DWORD) then
    LMs := INFINITE
  else
    LMs := DWORD(ATimeoutMs);

  LWait := WaitForMultipleObjects(DWORD(LCount), @LHandles[0], False, LMs);
  if LWait = WAIT_TIMEOUT then
    Exit(0);
  if LWait >= WAIT_OBJECT_0 + DWORD(LCount) then
    Exit(platform_get_last_error);

  LIdx := Int32(LWait - WAIT_OBJECT_0);
  I := LMap[LIdx];
  LSlot := @AWatcher.Slots[I];
  LOvl := WinWatchSlotOvl(LSlot^);
  LBytes := 0;
  if not GetOverlappedResult(HANDLE(LSlot^.DirHandle), LOvl, @LBytes, False) then
    Exit(WinWatchMapSlotIoError(LSlot^));
  LSlot^.Pending := False;
  LSlot^.PendLen := Int32(LBytes);
  LSlot^.PendPos := 0;

  if not WinWatchDecodeSlot(LSlot^, I + 1, AEvent) then
  begin
    LSlot^.PendLen := 0;
    LSlot^.PendPos := 0;
    LArm := WinWatchArmSlot(LSlot^);
    if LArm <> 0 then
      Exit(LArm);
    Exit(0);
  end;

  if LSlot^.PendPos >= LSlot^.PendLen then
  begin
    LSlot^.PendLen := 0;
    LSlot^.PendPos := 0;
    LArm := WinWatchArmSlot(LSlot^);
    if LArm <> 0 then
      Exit(LArm);
  end;
  Result := 1;
end;

function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
var
  I: Int32;
begin
  for I := 0 to PLATFORM_WATCH_WIN_MAX - 1 do
    WinWatchCloseSlot(AWatcher.Slots[I]);
  AWatcher.Fd := -1;
  Result := 0;
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

function platform_watch_remove(var AWatcher: TPlatformWatcher;
  const AWd: Int32): Int32;
begin
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_watch_poll(var AWatcher: TPlatformWatcher; out AEvent: TPlatformWatchEvent; ATimeoutMs: Int64): Int32;
begin FillChar(AEvent, SizeOf(AEvent), 0); Result := 0; end;
function platform_watch_close(var AWatcher: TPlatformWatcher): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
