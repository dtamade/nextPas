unit nextpas.core.io.reactor.iocp;

{$I nextpas.core.settings.inc}

{$IFDEF NEXTPAS_WINDOWS}
interface

uses
  nextpas.core.io.base,
  nextpas.core.platform.windows.base;

const
  { PollOneWait timeout for a pure completion-driven wait (no timed retry). }
  IOCP_WAIT_INFINITE = DWORD($FFFFFFFF);

{ Map Windows failure codes onto the -errno convention the reactor API
  promises: callbacks deliver negative errno exactly like the epoll/io_uring
  backends, so consumers (dial, streams, tests) never branch on the host.
  Exposed for contract tests — WinSock error translation is host-independent
  and must not depend on a real refused connect completing over the network. }
function IocpMapOsError(AErr: DWORD): Int32;

type
  TIoCompletion = nextpas.core.io.base.TIoCompletion;

  { PollOneWait outcome: a completion was dispatched, the timeout elapsed
    (GQCS WAIT_TIMEOUT — the epoll_wait-timeout equivalent), or a wake
    packet arrived (Stop / PostQueuedCompletionStatus with nil overlapped). }
  TIocpPollWaitResult = (iprDispatched, iprTimeout, iprWoken);

  TIocpOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opSendTo,
    opRecvFrom,
    opClose
  );

  TIocpReactor = record
  private
    FPort: PtrUInt;
    FMaxEvents: UInt32;
    FRunning: Int32;
    FPendingHead: Pointer;
    FPendingCount: Int32;
    FPendingDone: Int32;
    FNextUserData: UInt64;
    FLastAcceptSocket: PtrInt;
    FLastConnectSocket: PtrInt;
  public
    class function Create(AMaxEvents: UInt32 = 64): TIocpReactor; static;
    procedure Close;
    function IsValid: Boolean; inline;
    function LastAcceptedSocket: PtrInt; inline;
    function LastConnectedSocket: PtrInt; inline;

    function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendTo(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvFrom(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: Pointer;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: PtrInt;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    function PollOne: Boolean;
    { Single GQCS wait with timeout; lets a caller-owned event loop mix
      completion dispatch with timed retries (writable waiters, deadlines). }
    function PollOneWait(const ATimeoutMs: DWORD): TIocpPollWaitResult;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
    function HasPending: Boolean;
    { Best-effort CancelIoEx for pending ops matching AContext.
      Does not free OVERLAPPED; completion still arrives via GQCS. }
    function TryCancelByContext(AContext: Pointer): Boolean;
  end;

implementation

uses
  nextpas.core.mem,
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.platform.windows.ffi;

const
  WSAID_ACCEPTEX: TGUID = '{b5367df1-cbac-11cf-95ca-00805f48a192}';
  { mswsock.h WSAID_CONNECTEX (FPC jwamswsock.pas agrees). A wrong GUID makes
    WSAIoctl fail silently and every Windows dial dies as ERROR_NOT_SUPPORTED. }
  WSAID_CONNECTEX: TGUID = '{25a207b9-ddf3-4660-8ee9-76e58c74063e}';
  WSA_FLAG_OVERLAPPED = $01;
  SO_UPDATE_ACCEPT_CONTEXT = $700B;
  SO_UPDATE_CONNECT_CONTEXT = $7010;
  SOL_WINSOCK = $FFFF;  { SOL_SOCKET on Windows }
  IOCP_CLOSE_PENDING_POLL_MS = 10;
  IOCP_CLOSE_PENDING_TIMEOUT_MS = 5000;

type
  TAcceptExFn = function(sListenSocket, sAcceptSocket: TSocket;
    lpOutputBuffer: Pointer; dwReceiveDataLength, dwLocalAddressLength,
    dwRemoteAddressLength: DWORD; lpdwBytesReceived: LPDWORD;
    lpOverlapped: LPOVERLAPPED): BOOL; stdcall;

  TConnectExFn = function(s: TSocket; name: Pointer; namelen: LongInt;
    lpSendBuffer: Pointer; dwSendDataLength: DWORD;
    lpdwBytesSent: LPDWORD;
    lpOverlapped: LPOVERLAPPED): BOOL; stdcall;

var
  _AcceptEx: TAcceptExFn;
  _ConnectEx: TConnectExFn;
  _WinsockExtLoaded: Boolean;
  _ConnectExAvailable: Boolean;

type
  PIocpPendingOp = ^TIocpPendingOp;
  TIocpPendingOp = record
    Overlapped: OVERLAPPED;
    Kind: TIocpOpKind;
    Handle: HANDLE;
    ListenHandle: HANDLE;   { listening socket for AcceptEx SO_UPDATE_ACCEPT_CONTEXT }
    WSABuf: WSABUF;
    SocketFlags: DWORD;
    Addr: Pointer;          { sendto destination / recvfrom source buffer }
    AddrLen: UInt32;        { sendto length }
    AddrLenPtr: Pointer;    { recvfrom in/out length (PLongInt) }
    Callback: TIoCompletion;
    Context: Pointer;
    UserData: UInt64;
    Next: PIocpPendingOp;
  end;

function IocpDispatchCompletion(var AReactor: TIocpReactor; ABytes: DWORD;
  ASucceeded: Boolean; AOverlapped: LPOVERLAPPED): Boolean; forward;

function IocpHandleFromFd(AFd: PtrInt): HANDLE; inline;
begin
  Result := HANDLE(AFd);
end;

{ Map Windows failure codes onto the Linux errno convention the reactor API
  promises: callbacks deliver negative errno exactly like the epoll/io_uring
  backends, so consumers (dial, streams, tests) never branch on the host.
  Both spaces reach here — kernel completion translations (64, 995, 1225 …)
  via GetLastError and Winsock WSAE* via WSAGetLastError. Codes without a
  confident errno peer pass through unchanged rather than lie; the raw OS
  code also stays observable via SetLastError in IocpFail. }
function IocpMapOsError(AErr: DWORD): Int32;
const
  ERROR_NETNAME_DELETED_W     = 64;    { remote hard close surfaces as this }
  ERROR_SEM_TIMEOUT_W         = 121;
  ERROR_CONNECTION_REFUSED_W  = 1225;
  ERROR_NETWORK_UNREACHABLE_W = 1231;
  ERROR_HOST_UNREACHABLE_W    = 1232;
  ERROR_CONNECTION_ABORTED_W  = 1236;
  WSAEACCES_W                 = 10013;
  WSAEINVAL_W                 = 10022;
begin
  case AErr of
    ERROR_OPERATION_ABORTED:                     { CancelIoEx / Close }
      Result := 125;                             { ECANCELED }
    ERROR_CONNECTION_REFUSED_W, DWORD(WSAECONNREFUSED):
      Result := 111;                             { ECONNREFUSED }
    ERROR_NETNAME_DELETED_W, DWORD(WSAECONNRESET), DWORD(WSAENETRESET):
      Result := 104;                             { ECONNRESET }
    ERROR_CONNECTION_ABORTED_W, DWORD(WSAECONNABORTED):
      Result := 103;                             { ECONNABORTED }
    ERROR_SEM_TIMEOUT_W, ERROR_TIMEOUT, DWORD(WSAETIMEDOUT):
      Result := 110;                             { ETIMEDOUT }
    ERROR_NETWORK_UNREACHABLE_W, DWORD(WSAENETUNREACH):
      Result := 101;                             { ENETUNREACH }
    ERROR_HOST_UNREACHABLE_W, DWORD(WSAEHOSTUNREACH):
      Result := 113;                             { EHOSTUNREACH }
    DWORD(WSAENOTCONN):
      Result := 107;                             { ENOTCONN }
    DWORD(WSAEADDRINUSE):
      Result := 98;                              { EADDRINUSE }
    DWORD(WSAEADDRNOTAVAIL):
      Result := 99;                              { EADDRNOTAVAIL }
    ERROR_INVALID_PARAMETER, WSAEINVAL_W:
      Result := 22;                              { EINVAL }
    ERROR_INVALID_HANDLE, DWORD(WSAENOTSOCK):
      Result := 9;                               { EBADF }
    ERROR_NOT_ENOUGH_MEMORY, ERROR_OUTOFMEMORY, DWORD(WSAENOBUFS):
      Result := 12;                              { ENOMEM }
    ERROR_NOT_SUPPORTED, DWORD(WSAEOPNOTSUPP):
      Result := 95;                              { EOPNOTSUPP }
    ERROR_BROKEN_PIPE:
      Result := 32;                              { EPIPE }
    ERROR_ACCESS_DENIED, WSAEACCES_W:
      Result := 13;                              { EACCES }
  else
    Result := Int32(AErr);
  end;
end;

function IocpFail(ACallback: TIoCompletion; AContext: Pointer;
  AUserData: UInt64; AError: DWORD): Boolean;
begin
  SetLastError(AError);
  if Assigned(ACallback) then
  begin
    ACallback(AUserData, -IocpMapOsError(AError), AContext);
    Result := True;
  end
  else
    Result := False;
end;

function IocpUnsupportedAsync: Boolean;
begin
  SetLastError(ERROR_NOT_SUPPORTED);
  Result := False;
end;

function IocpAllocOp(var AReactor: TIocpReactor; AKind: TIocpOpKind;
  AHandle: HANDLE; ACallback: TIoCompletion; AContext: Pointer): PIocpPendingOp;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Inc(AReactor.FNextUserData);
  if AReactor.FNextUserData = 0 then
    Inc(AReactor.FNextUserData);
  Result^.Kind := AKind;
  Result^.Handle := AHandle;
  Result^.Callback := ACallback;
  Result^.Context := AContext;
  Result^.UserData := AReactor.FNextUserData;
  Result^.Next := PIocpPendingOp(AReactor.FPendingHead);
  AReactor.FPendingHead := Result;
  atomic_store(AReactor.FPendingDone, 0, mo_release);
  atomic_fetch_add(AReactor.FPendingCount, 1, mo_acq_rel);
end;

procedure IocpUnlinkOp(var AReactor: TIocpReactor; AOp: PIocpPendingOp);
var
  LCurrent, LPrevious: PIocpPendingOp;
  LPendingCount: Int32;
begin
  LPrevious := nil;
  LCurrent := PIocpPendingOp(AReactor.FPendingHead);
  while LCurrent <> nil do
  begin
    if LCurrent = AOp then
    begin
      if LPrevious = nil then
        AReactor.FPendingHead := LCurrent^.Next
      else
        LPrevious^.Next := LCurrent^.Next;
      LPendingCount := atomic_fetch_sub(AReactor.FPendingCount, 1, mo_acq_rel) - 1;
      if LPendingCount = 0 then
        atomic_store(AReactor.FPendingDone, 1, mo_release);
      Exit;
    end;
    LPrevious := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
end;

procedure IocpFreeOp(var AReactor: TIocpReactor; AOp: PIocpPendingOp;
  AUnlink: Boolean = True);
begin
  if AOp = nil then
    Exit;
  if AUnlink then
    IocpUnlinkOp(AReactor, AOp);
  AOp^.Callback := nil;
  AOp^.Context := nil;
  AOp^.Next := nil;
  Dispose(AOp);
end;

procedure IocpCancelPendingOps(var AReactor: TIocpReactor);
var
  LOp: PIocpPendingOp;
begin
  LOp := PIocpPendingOp(AReactor.FPendingHead);
  while LOp <> nil do
  begin
    CancelIoEx(LOp^.Handle, @LOp^.Overlapped);
    LOp := LOp^.Next;
  end;
end;

function IocpWaitForPendingOps(var AReactor: TIocpReactor; APort: HANDLE;
  ATimeoutMs: DWORD): Boolean;
var
  LWaitedMs: DWORD;
  LBytes: DWORD;
  LKey: ULONG_PTR;
  LOverlapped: LPOVERLAPPED;
  LOk: BOOL;
begin
  if atomic_load(AReactor.FPendingCount, mo_acquire) = 0 then
    Exit(True);

  LWaitedMs := 0;
  while LWaitedMs < ATimeoutMs do
  begin
    if atomic_load(AReactor.FPendingDone, mo_acquire) <> 0 then
      Exit(True);
    if atomic_load(AReactor.FPendingCount, mo_acquire) = 0 then
      Exit(True);

    LBytes := 0;
    LKey := 0;
    LOverlapped := nil;
    LOk := GetQueuedCompletionStatus(APort, @LBytes, @LKey, @LOverlapped, IOCP_CLOSE_PENDING_POLL_MS);
    if LOverlapped <> nil then
      IocpDispatchCompletion(AReactor, LBytes, LOk, LOverlapped);
    Inc(LWaitedMs, IOCP_CLOSE_PENDING_POLL_MS);
  end;

  Result := atomic_load(AReactor.FPendingCount, mo_acquire) = 0;
end;

procedure IocpLoadWinsockExt;
var
  L: TSocket;
  LB: DWORD;
begin
  if _WinsockExtLoaded then Exit;
  L := winsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if L = TSocket(PtrUInt(-1)) then Exit;
  try
    WSAIoctl(L, SIO_GET_EXTENSION_FUNCTION_POINTER,
      @WSAID_ACCEPTEX, SizeOf(WSAID_ACCEPTEX),
      @_AcceptEx, SizeOf(_AcceptEx), @LB, nil, nil);
    WSAIoctl(L, SIO_GET_EXTENSION_FUNCTION_POINTER,
      @WSAID_CONNECTEX, SizeOf(WSAID_CONNECTEX),
      @_ConnectEx, SizeOf(_ConnectEx), @LB, nil, nil);
  finally
    closesocket(L);
  end;
  _WinsockExtLoaded := True;
  _ConnectExAvailable := (_ConnectEx <> nil);
end;


procedure IocpReleasePendingOps(var AReactor: TIocpReactor; AError: DWORD);
var
  LOp, LNext: PIocpPendingOp;
  LCallback: TIoCompletion;
  LContext: Pointer;
  LUserData: UInt64;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  LOp := PIocpPendingOp(AReactor.FPendingHead);
  AReactor.FPendingHead := nil;
  atomic_store(AReactor.FPendingCount, 0, mo_release);
  atomic_store(AReactor.FPendingDone, 1, mo_release);
  LHasException := False;
  LExceptionMessage := '';
  while LOp <> nil do
  begin
    LNext := LOp^.Next;
    CancelIoEx(LOp^.Handle, @LOp^.Overlapped);
    LCallback := LOp^.Callback;
    LContext := LOp^.Context;
    LUserData := LOp^.UserData;
    try
      if (LOp^.Kind = opAccept) and (LOp^.WSABuf.buf <> nil) then
      begin
        FreeMem(LOp^.WSABuf.buf, SizeUInt(LOp^.WSABuf.len));
        LOp^.WSABuf.buf := nil;
      end;
      if LOp^.Kind = opAccept then
        closesocket(TSocket(PtrUInt(LOp^.Handle)));
      try
        if Assigned(LCallback) then
          LCallback(LUserData, -IocpMapOsError(AError), LContext);
      except
        on E: Exception do
        begin
          if not LHasException then
          begin
            LHasException := True;
            LExceptionMessage := E.Message;
          end
          else
            LExceptionMessage := LExceptionMessage + LineEnding + E.Message;
        end;
      end;
    finally
      LOp^.Callback := nil;
      LOp^.Context := nil;
      LOp^.Next := nil;
      Dispose(LOp);
    end;
    LOp := LNext;
  end;
  if LHasException then
    raise Exception.Create(LExceptionMessage);
end;

function IocpEnsureAssociatedHandle(var AReactor: TIocpReactor;
  AHandle: HANDLE; out AError: DWORD): Boolean;
begin
  { Always ask the kernel — never cache "already associated" by handle value.
    The OS recycles handle values right after closesocket, so a cached entry
    can match a brand-new socket that was never associated; its completions
    then silently never post (observed as multi-attempt dial hangs until
    CancelIoEx forced ERROR_OPERATION_ABORTED). Re-associating an already
    associated handle fails with ERROR_INVALID_PARAMETER on both Windows and
    Wine, which makes this call a safe idempotency probe: treat that error
    as success. A genuinely bad handle surfaces again at overlapped submit
    with its real error. }
  AError := 0;
  if (AReactor.FPort = 0) or (AHandle = nil) or
     (AHandle = HANDLE(PtrInt(INVALID_HANDLE_VALUE))) then
  begin
    AError := ERROR_INVALID_HANDLE;
    Exit(False);
  end;

  if CreateIoCompletionPort(AHandle, HANDLE(AReactor.FPort), 0,
     AReactor.FMaxEvents) <> nil then
    Exit(True);

  AError := GetLastError;
  if AError = ERROR_INVALID_PARAMETER then
  begin
    AError := 0;
    Exit(True);
  end;
  Result := False;
end;

procedure IocpSetOffset(AOp: PIocpPendingOp; AOffset: Int64);
var
  LOffset: UInt64;
begin
  LOffset := UInt64(AOffset);
  AOp^.Overlapped.Offset := DWORD(LOffset and UInt64($FFFFFFFF));
  AOp^.Overlapped.OffsetHigh := DWORD(LOffset shr 32);
end;

function IocpSubmitFileOp(var AReactor: TIocpReactor; AKind: TIocpOpKind;
  AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LHandle: HANDLE;
  LOp: PIocpPendingOp;
  LDone: DWORD;
  LError: DWORD;
  LUserData: UInt64;
  LOk: BOOL;
begin
  if (ALen > 0) and (ABuf = nil) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));
  if AOffset < 0 then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));

  LHandle := IocpHandleFromFd(AFd);
  if not IocpEnsureAssociatedHandle(AReactor, LHandle, LError) then
    Exit(IocpFail(ACallback, AContext, 0, LError));

  LOp := IocpAllocOp(AReactor, AKind, LHandle, ACallback, AContext);
  IocpSetOffset(LOp, AOffset);
  LDone := 0;
  case AKind of
    opRead:
      LOk := ReadFile(LHandle, ABuf, ALen, @LDone, @LOp^.Overlapped);
    opWrite:
      LOk := WriteFile(LHandle, ABuf, ALen, @LDone, @LOp^.Overlapped);
  else
    LOk := False;
  end;

  if LOk then
    Exit(True);

  LError := GetLastError;
  if LError = ERROR_IO_PENDING then
    Exit(True);

  LUserData := LOp^.UserData;
  IocpFreeOp(AReactor, LOp);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function IocpSubmitSocketOp(var AReactor: TIocpReactor; AKind: TIocpOpKind;
  AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LHandle: HANDLE;
  LOp: PIocpPendingOp;
  LError: DWORD;
  LUserData: UInt64;
  LResult: LongInt;
begin
  if (ALen > 0) and (ABuf = nil) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));

  LHandle := IocpHandleFromFd(AFd);
  if not IocpEnsureAssociatedHandle(AReactor, LHandle, LError) then
    Exit(IocpFail(ACallback, AContext, 0, LError));

  LOp := IocpAllocOp(AReactor, AKind, LHandle, ACallback, AContext);
  LOp^.WSABuf.buf := PAnsiChar(ABuf);
  LOp^.WSABuf.len := ALen;
  LOp^.SocketFlags := AFlags;
  case AKind of
    opSend:
      LResult := WSASend(TSocket(PtrUInt(LHandle)), @LOp^.WSABuf, 1, nil,
        LOp^.SocketFlags, @LOp^.Overlapped, nil);
    opRecv:
      LResult := WSARecv(TSocket(PtrUInt(LHandle)), @LOp^.WSABuf, 1, nil,
        @LOp^.SocketFlags, @LOp^.Overlapped, nil);
  else
    LResult := SOCKET_ERROR;
  end;

  if LResult = 0 then
    Exit(True);

  LError := DWORD(WSAGetLastError);
  if LError = WSA_IO_PENDING then
    Exit(True);

  LUserData := LOp^.UserData;
  IocpFreeOp(AReactor, LOp);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function IocpDispatchCompletion(var AReactor: TIocpReactor; ABytes: DWORD;
  ASucceeded: Boolean; AOverlapped: LPOVERLAPPED): Boolean;
var
  LOp: PIocpPendingOp;
  LResult: Int32;
  LSock: TSocket;
begin
  if AOverlapped = nil then
    Exit(False);

  LOp := PIocpPendingOp(AOverlapped);
  if ASucceeded then
    LResult := Int32(ABytes)
  else
    LResult := -IocpMapOsError(GetLastError);

  if LOp^.Kind = opAccept then
  begin
    AReactor.FLastAcceptSocket := PtrInt(LOp^.Handle);
    { SO_UPDATE_ACCEPT_CONTEXT requires the listening socket as optval }
    LSock := TSocket(PtrUInt(LOp^.ListenHandle));
    winsock_setsockopt(TSocket(PtrUInt(LOp^.Handle)), SOL_WINSOCK,
      SO_UPDATE_ACCEPT_CONTEXT, @LSock, SizeOf(TSocket));
    if LOp^.WSABuf.buf <> nil then
    begin
      FreeMem(LOp^.WSABuf.buf, SizeUInt(LOp^.WSABuf.len));
      LOp^.WSABuf.buf := nil;
    end;
  end
  else if LOp^.Kind = opConnect then
  begin
    AReactor.FLastConnectSocket := PtrInt(LOp^.Handle);
    { SO_UPDATE_CONNECT_CONTEXT required so socket can be used with other Winsock
      extension functions. Pass nil to query the context (setsockopt with nil
      retrieves the context). }
    winsock_setsockopt(TSocket(PtrUInt(LOp^.Handle)), SOL_SOCKET,
      SO_UPDATE_CONNECT_CONTEXT, nil, 0);
  end;

  IocpUnlinkOp(AReactor, LOp);
  try
    if Assigned(LOp^.Callback) then
      LOp^.Callback(LOp^.UserData, LResult, LOp^.Context);
  finally
    IocpFreeOp(AReactor, LOp, False);
  end;
  Result := True;
end;

class function TIocpReactor.Create(AMaxEvents: UInt32): TIocpReactor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FMaxEvents := AMaxEvents;
  atomic_store(Result.FRunning, 0, mo_release);
  atomic_store(Result.FPendingDone, 1, mo_release);
  Result.FPort := PtrUInt(CreateIoCompletionPort(HANDLE(INVALID_HANDLE_VALUE),
    nil, 0, AMaxEvents));
end;

procedure TIocpReactor.Close;
var
  LPort: PtrUInt;
begin
  atomic_store(FRunning, 0, mo_release);
  LPort := FPort;
  if LPort <> 0 then
    PostQueuedCompletionStatus(HANDLE(LPort), 0, 0, nil);
  try
    if atomic_load(FPendingCount, mo_acquire) > 0 then
    begin
      IocpCancelPendingOps(Self);
      IocpWaitForPendingOps(Self, HANDLE(LPort), IOCP_CLOSE_PENDING_TIMEOUT_MS);
    end;
    IocpReleasePendingOps(Self, ERROR_OPERATION_ABORTED);
  finally
    FPort := 0;
    FMaxEvents := 0;
    if LPort <> 0 then
      CloseHandle(HANDLE(LPort));
  end;
end;

function TIocpReactor.IsValid: Boolean;
begin
  Result := FPort <> 0;
end;

function TIocpReactor.LastAcceptedSocket: PtrInt;
begin
  Result := FLastAcceptSocket;
end;

function TIocpReactor.LastConnectedSocket: PtrInt;
begin
  Result := FLastConnectSocket;
end;

function TIocpReactor.AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitFileOp(Self, opRead, AFd, ABuf, ALen, AOffset,
    ACallback, AContext);
end;

function TIocpReactor.AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitFileOp(Self, opWrite, AFd, ABuf, ALen, AOffset,
    ACallback, AContext);
end;

function TIocpReactor.AsyncAccept(AFd: PtrInt; AAddr: Pointer;
  AAddrLen: Pointer; AFlags: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
const
  ADDR_BUF_SIZE = 64;  { 2 * (sizeof(sockaddr_in) + 16) }
var
  LAcceptSock: TSocket;
  LOp: PIocpPendingOp;
  LAddrBuf: Pointer;
  LBytesRecvd: DWORD;
  LError: DWORD;
  LUserData: UInt64;
  LOk: BOOL;
begin
  IocpLoadWinsockExt;
  if _AcceptEx = nil then
    Exit(IocpUnsupportedAsync);
  if not IsValid then
    Exit(False);

  { Create accepting socket — use socket() instead of WSASocketW for
    best Wine compatibility. Winsock 2 socket() creates overlapped-capable
    sockets by default. }
  LAcceptSock := winsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if LAcceptSock = TSocket(PtrUInt(-1)) then
  begin
    LError := WSAGetLastError;
    Exit(IocpFail(ACallback, AContext, 0, LError));
  end;

  { Associate accepting socket with IOCP so post-accept read/write submits
    find it already wired to the port. }
  if not IocpEnsureAssociatedHandle(Self, HANDLE(LAcceptSock), LError) then
  begin
    closesocket(LAcceptSock);
    Exit(IocpFail(ACallback, AContext, 0, LError));
  end;

  { Ensure the listening socket is also associated with the IOCP port.
    AcceptEx completion is posted through the listening socket, not the
    accepting socket. }
  if not IocpEnsureAssociatedHandle(Self, IocpHandleFromFd(AFd), LError) then
  begin
    closesocket(LAcceptSock);
    Exit(IocpFail(ACallback, AContext, 0, LError));
  end;

  { Allocate address buffer }
  LAddrBuf := GetMem(ADDR_BUF_SIZE);
  if LAddrBuf = nil then
  begin
    closesocket(LAcceptSock);
    Exit(IocpFail(ACallback, AContext, 0, ERROR_NOT_ENOUGH_MEMORY));
  end;

  LOp := IocpAllocOp(Self, opAccept, HANDLE(LAcceptSock),
    ACallback, AContext);
  LOp^.ListenHandle := IocpHandleFromFd(AFd);
  LOp^.WSABuf.buf := LAddrBuf;
  LOp^.WSABuf.len := ADDR_BUF_SIZE;

  LOk := _AcceptEx(TSocket(AFd), LAcceptSock, LAddrBuf, 0,
    ADDR_BUF_SIZE div 2, ADDR_BUF_SIZE div 2,
    @LBytesRecvd, @LOp^.Overlapped);

  if LOk then
    Exit(True);

  LError := WSAGetLastError;
  if LError = ERROR_IO_PENDING then
    Exit(True);

  { AcceptEx failed synchronously — cleanup }
  FreeMem(LAddrBuf, ADDR_BUF_SIZE);
  LUserData := LOp^.UserData;
  IocpFreeOp(Self, LOp);
  closesocket(LAcceptSock);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function TIocpReactor.AsyncConnect(AFd: PtrInt; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
const
  { winsock2.h WSAEINVAL — bind when already bound, or other invalid state }
  WSAEINVAL_LOCAL = 10022;
var
  LHandle: HANDLE;
  LOp: PIocpPendingOp;
  LError: DWORD;
  LUserData: UInt64;
  LOk: BOOL;
  LFamily: WORD;
  LLocal4: sockaddr_in;
  LLocal6: sockaddr_in6;
  LBindRc: LongInt;
begin
  IocpLoadWinsockExt;
  if not _ConnectExAvailable then
    Exit(IocpUnsupportedAsync);

  if (AAddr = nil) or (AAddrLen = 0) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));
  if Self.FPort = 0 then
  begin
    SetLastError(ERROR_INVALID_HANDLE);
    Exit(False);
  end;

  LHandle := IocpHandleFromFd(AFd);
  if not IocpEnsureAssociatedHandle(Self, LHandle, LError) then
    Exit(IocpFail(ACallback, AContext, 0, LError));

  { ConnectEx requires a prior bind (MSDN). Dial may omit LocalAddr;
    bind wildcard of the same family. Already-bound sockets (LocalAddr) get
    WSAEINVAL — treat as success. }
  LFamily := PWORD(AAddr)^;
  LError := 0;
  if LFamily = AF_INET then
  begin
    FillChar(LLocal4, SizeOf(LLocal4), 0);
    LLocal4.sin_family := AF_INET;
    LBindRc := winsock_bind(TSocket(AFd), @LLocal4, SizeOf(LLocal4));
  end
  else if LFamily = AF_INET6 then
  begin
    FillChar(LLocal6, SizeOf(LLocal6), 0);
    LLocal6.sin6_family := AF_INET6;
    LBindRc := winsock_bind(TSocket(AFd), @LLocal6, SizeOf(LLocal6));
  end
  else
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));

  if LBindRc <> 0 then
  begin
    LError := WSAGetLastError;
    if LError <> WSAEINVAL_LOCAL then
      Exit(IocpFail(ACallback, AContext, 0, LError));
  end;

  LOp := IocpAllocOp(Self, opConnect, LHandle, ACallback, AContext);
  LOk := _ConnectEx(TSocket(AFd), AAddr, AAddrLen, nil, 0, nil, @LOp^.Overlapped);

  if LOk then
    Exit(True);

  { ConnectEx is a Winsock extension — use WSAGetLastError, not GetLastError. }
  LError := WSAGetLastError;
  if (LError = ERROR_IO_PENDING) or (LError = WSA_IO_PENDING) then
    Exit(True);

  LUserData := LOp^.UserData;
  IocpFreeOp(Self, LOp);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function TIocpReactor.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitSocketOp(Self, opSend, AFd, ABuf, ALen, UInt32(AFlags),
    ACallback, AContext);
end;

function TIocpReactor.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitSocketOp(Self, opRecv, AFd, ABuf, ALen, UInt32(AFlags),
    ACallback, AContext);
end;

function TIocpReactor.AsyncSendTo(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LHandle: HANDLE;
  LOp: PIocpPendingOp;
  LError: DWORD;
  LUserData: UInt64;
  LResult: LongInt;
begin
  if not IsValid then
    Exit(False);
  if (AAddr = nil) or (AAddrLen = 0) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));
  if (ALen > 0) and (ABuf = nil) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));

  LHandle := IocpHandleFromFd(AFd);
  if not IocpEnsureAssociatedHandle(Self, LHandle, LError) then
    Exit(IocpFail(ACallback, AContext, 0, LError));

  LOp := IocpAllocOp(Self, opSendTo, LHandle, ACallback, AContext);
  LOp^.WSABuf.buf := PAnsiChar(ABuf);
  LOp^.WSABuf.len := ALen;
  LOp^.SocketFlags := DWORD(AFlags);
  LOp^.Addr := AAddr;
  LOp^.AddrLen := AAddrLen;
  LResult := WSASendTo(TSocket(PtrUInt(LHandle)), @LOp^.WSABuf, 1, nil,
    LOp^.SocketFlags, AAddr, LongInt(AAddrLen), @LOp^.Overlapped, nil);
  if LResult = 0 then
    Exit(True);
  LError := DWORD(WSAGetLastError);
  if LError = WSA_IO_PENDING then
    Exit(True);
  LUserData := LOp^.UserData;
  IocpFreeOp(Self, LOp);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function TIocpReactor.AsyncRecvFrom(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; AAddr: Pointer; AAddrLen: Pointer;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LHandle: HANDLE;
  LOp: PIocpPendingOp;
  LError: DWORD;
  LUserData: UInt64;
  LResult: LongInt;
begin
  if not IsValid then
    Exit(False);
  if (AAddr = nil) or (AAddrLen = nil) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));
  if (ALen > 0) and (ABuf = nil) then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_PARAMETER));

  LHandle := IocpHandleFromFd(AFd);
  if not IocpEnsureAssociatedHandle(Self, LHandle, LError) then
    Exit(IocpFail(ACallback, AContext, 0, LError));

  LOp := IocpAllocOp(Self, opRecvFrom, LHandle, ACallback, AContext);
  LOp^.WSABuf.buf := PAnsiChar(ABuf);
  LOp^.WSABuf.len := ALen;
  LOp^.SocketFlags := DWORD(AFlags);
  LOp^.Addr := AAddr;
  LOp^.AddrLenPtr := AAddrLen;
  LResult := WSARecvFrom(TSocket(PtrUInt(LHandle)), @LOp^.WSABuf, 1, nil,
    @LOp^.SocketFlags, AAddr, AAddrLen, @LOp^.Overlapped, nil);
  if LResult = 0 then
    Exit(True);
  LError := DWORD(WSAGetLastError);
  if LError = WSA_IO_PENDING then
    Exit(True);
  LUserData := LOp^.UserData;
  IocpFreeOp(Self, LOp);
  Result := IocpFail(ACallback, AContext, LUserData, LError);
end;

function TIocpReactor.AsyncClose(AFd: PtrInt;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LHandle: HANDLE;
  LError: DWORD;
begin
  LHandle := IocpHandleFromFd(AFd);
  if LHandle = nil then
    Exit(IocpFail(ACallback, AContext, 0, ERROR_INVALID_HANDLE));

  CancelIoEx(LHandle, nil);
  if closesocket(TSocket(AFd)) = 0 then
    LError := 0
  else
    LError := WSAGetLastError;

  if Assigned(ACallback) then
    ACallback(0, -IocpMapOsError(LError), AContext);
  Result := True;
end;

function TIocpReactor.Poll: Int32;
var
  LCount: Int32;
begin
  LCount := 0;
  while PollOne do
    Inc(LCount);
  Result := LCount;
end;

function TIocpReactor.HasPending: Boolean;
begin
  Result := atomic_load(FPendingCount, mo_acquire) > 0;
end;

function TIocpReactor.TryCancelByContext(AContext: Pointer): Boolean;
var
  LOp: PIocpPendingOp;
  LOk: BOOL;
  LError: DWORD;
begin
  Result := False;
  if (AContext = nil) or (not IsValid) then
    Exit;

  LOp := PIocpPendingOp(FPendingHead);
  while LOp <> nil do
  begin
    if LOp^.Context = AContext then
    begin
      LOk := CancelIoEx(LOp^.Handle, @LOp^.Overlapped);
      if LOk then
        Result := True
      else
      begin
        LError := GetLastError;
        { Already completed or no matching request — still best-effort hit. }
        if (LError = ERROR_NOT_FOUND) or (LError = ERROR_OPERATION_ABORTED) then
          Result := True;
      end;
      { Keep OVERLAPPED alive until GQCS delivers the completion packet. }
    end;
    LOp := LOp^.Next;
  end;
end;

function TIocpReactor.PollOne: Boolean;
var
  LBytes: DWORD;
  LKey: ULONG_PTR;
  LOverlapped: LPOVERLAPPED;
  LOk: BOOL;
begin
  if FPort = 0 then
    Exit(False);

  LBytes := 0;
  LKey := 0;
  LOverlapped := nil;
  LOk := GetQueuedCompletionStatus(HANDLE(FPort), @LBytes, @LKey,
    @LOverlapped, 0);
  if (not LOk) and (LOverlapped = nil) then
    Exit(False);
  Result := IocpDispatchCompletion(Self, LBytes, LOk, LOverlapped);
end;

function TIocpReactor.PollOneWait(const ATimeoutMs: DWORD): TIocpPollWaitResult;
var
  LBytes: DWORD;
  LKey: ULONG_PTR;
  LOverlapped: LPOVERLAPPED;
  LOk: BOOL;
begin
  if FPort = 0 then
    Exit(iprWoken); { dead port: report as wake so the caller re-checks state }

  LBytes := 0;
  LKey := 0;
  LOverlapped := nil;
  LOk := GetQueuedCompletionStatus(HANDLE(FPort), @LBytes, @LKey,
    @LOverlapped, ATimeoutMs);
  if LOverlapped = nil then
  begin
    if (not LOk) and (GetLastError = WAIT_TIMEOUT) then
      Exit(iprTimeout);
    { Successful GQCS with nil overlapped is a posted wake packet; a failed
      GQCS with another error is surfaced as a wake so the caller can react. }
    Exit(iprWoken);
  end;
  IocpDispatchCompletion(Self, LBytes, LOk, LOverlapped);
  Result := iprDispatched;
end;

procedure TIocpReactor.Run;
var
  LBytes: DWORD;
  LKey: ULONG_PTR;
  LOverlapped: LPOVERLAPPED;
  LOk: BOOL;
begin
  if FPort = 0 then
    Exit;

  atomic_store(FRunning, 1, mo_release);
  try
    while atomic_load(FRunning, mo_acquire) <> 0 do
    begin
      LBytes := 0;
      LKey := 0;
      LOverlapped := nil;
      LOk := GetQueuedCompletionStatus(HANDLE(FPort), @LBytes, @LKey,
        @LOverlapped, INFINITE);
      if (not LOk) and (LOverlapped = nil) then
      begin
        Break;
      end;
      IocpDispatchCompletion(Self, LBytes, LOk, LOverlapped);
    end;
  finally
    atomic_store(FRunning, 0, mo_release);
  end;
end;

procedure TIocpReactor.Stop;
begin
  atomic_store(FRunning, 0, mo_release);
  if FPort <> 0 then
    PostQueuedCompletionStatus(HANDLE(FPort), 0, 0, nil);
end;

function TIocpReactor.Flush: Int32;
begin
  { IOCP submits inline in each Async* call (WSASend/WSARecv/ReadFile/etc.),
    so there is no deferred submission queue to flush. }
  Result := 0;
end;

end.
{$ELSE}
interface
implementation
end.
{$ENDIF}
