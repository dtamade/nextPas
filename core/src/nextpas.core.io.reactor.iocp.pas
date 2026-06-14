unit nextpas.core.io.reactor.iocp;

{$I nextpas.core.settings.inc}

{$IFDEF NEXTPAS_WINDOWS}
interface

uses nextpas.core.platform.windows.base;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TIocpOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opClose
  );

  TIocpReactor = record
  private
    FPort: PtrUInt;
    FMaxEvents: UInt32;
    FRunning: Int32;
    FPendingHead: Pointer;
    FPendingCount: UInt32;
    FAssociatedHead: Pointer;
    FNextUserData: UInt64;
  public
    class function Create(AMaxEvents: UInt32 = 64): TIocpReactor; static;
    procedure Close;
    function IsValid: Boolean; inline;

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
    function AsyncClose(AFd: PtrInt;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
    function HasPending: Boolean;
  end;

implementation

uses nextpas.core.atomic, nextpas.core.platform.windows.ffi;

type
  PIocpPendingOp = ^TIocpPendingOp;
  TIocpPendingOp = record
    Overlapped: OVERLAPPED;
    Kind: TIocpOpKind;
    Handle: HANDLE;
    WSABuf: WSABUF;
    SocketFlags: DWORD;
    Callback: TIoCompletion;
    Context: Pointer;
    UserData: UInt64;
    Next: PIocpPendingOp;
  end;

  PIocpAssociatedHandle = ^TIocpAssociatedHandle;
  TIocpAssociatedHandle = record
    Handle: HANDLE;
    Next: PIocpAssociatedHandle;
  end;

function IocpHandleFromFd(AFd: PtrInt): HANDLE; inline;
begin
  Result := HANDLE(AFd);
end;

function IocpFail(ACallback: TIoCompletion; AContext: Pointer;
  AUserData: UInt64; AError: DWORD): Boolean;
begin
  if Assigned(ACallback) then
  begin
    ACallback(AUserData, -Int32(AError), AContext);
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
  Inc(AReactor.FPendingCount);
end;

procedure IocpUnlinkOp(var AReactor: TIocpReactor; AOp: PIocpPendingOp);
var
  LCurrent, LPrevious: PIocpPendingOp;
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
      if AReactor.FPendingCount > 0 then
        Dec(AReactor.FPendingCount);
      Exit;
    end;
    LPrevious := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
end;

procedure IocpFreeOp(var AReactor: TIocpReactor; AOp: PIocpPendingOp);
begin
  if AOp = nil then
    Exit;
  IocpUnlinkOp(AReactor, AOp);
  AOp^.Callback := nil;
  AOp^.Context := nil;
  AOp^.Next := nil;
  Dispose(AOp);
end;

procedure IocpReleasePendingOps(var AReactor: TIocpReactor; AError: DWORD);
var
  LOp, LNext: PIocpPendingOp;
  LCallback: TIoCompletion;
  LContext: Pointer;
  LUserData: UInt64;
  LDone: DWORD;
  LFlags: DWORD;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  LOp := PIocpPendingOp(AReactor.FPendingHead);
  AReactor.FPendingHead := nil;
  AReactor.FPendingCount := 0;
  LHasException := False;
  LExceptionMessage := '';
  while LOp <> nil do
  begin
    LNext := LOp^.Next;
    LDone := 0;
    LFlags := 0;
    CancelIoEx(LOp^.Handle, @LOp^.Overlapped);
    case LOp^.Kind of
      opSend, opRecv:
        begin
          LFlags := LOp^.SocketFlags;
          WSAGetOverlappedResult(TSocket(PtrUInt(LOp^.Handle)), @LOp^.Overlapped, @LDone, True, @LFlags);
        end;
    else
      GetOverlappedResult(LOp^.Handle, @LOp^.Overlapped, @LDone, True);
    end;
    LCallback := LOp^.Callback;
    LContext := LOp^.Context;
    LUserData := LOp^.UserData;
    try
      try
        if Assigned(LCallback) then
          LCallback(LUserData, -Int32(AError), LContext);
      except
        on E: Exception do
        begin
          if not LHasException then
          begin
            LHasException := True;
            LExceptionMessage := E.Message;
          end;
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

function IocpHasAssociatedHandle(const AReactor: TIocpReactor;
  AHandle: HANDLE): Boolean;
var
  LNode: PIocpAssociatedHandle;
begin
  LNode := PIocpAssociatedHandle(AReactor.FAssociatedHead);
  while LNode <> nil do
  begin
    if LNode^.Handle = AHandle then
      Exit(True);
    LNode := LNode^.Next;
  end;
  Result := False;
end;

procedure IocpRememberAssociatedHandle(var AReactor: TIocpReactor;
  AHandle: HANDLE);
var
  LNode: PIocpAssociatedHandle;
begin
  New(LNode);
  LNode^.Handle := AHandle;
  LNode^.Next := PIocpAssociatedHandle(AReactor.FAssociatedHead);
  AReactor.FAssociatedHead := LNode;
end;

procedure IocpReleaseAssociatedHandles(var AReactor: TIocpReactor);
var
  LNode, LNext: PIocpAssociatedHandle;
begin
  LNode := PIocpAssociatedHandle(AReactor.FAssociatedHead);
  AReactor.FAssociatedHead := nil;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    Dispose(LNode);
    LNode := LNext;
  end;
end;

function IocpEnsureAssociatedHandle(var AReactor: TIocpReactor;
  AHandle: HANDLE; out AError: DWORD): Boolean;
begin
  if (AReactor.FPort = 0) or (AHandle = nil) or
     (AHandle = HANDLE(PtrInt(INVALID_HANDLE_VALUE))) then
  begin
    AError := ERROR_INVALID_HANDLE;
    Exit(False);
  end;

  if IocpHasAssociatedHandle(AReactor, AHandle) then
    Exit(True);

  if CreateIoCompletionPort(AHandle, HANDLE(AReactor.FPort), 0,
     AReactor.FMaxEvents) = nil then
  begin
    AError := GetLastError;
    Exit(False);
  end;

  IocpRememberAssociatedHandle(AReactor, AHandle);
  Result := True;
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
  AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
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
  LOp^.SocketFlags := DWORD(AFlags);
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
begin
  if AOverlapped = nil then
    Exit(False);

  LOp := PIocpPendingOp(AOverlapped);
  if ASucceeded then
    LResult := Int32(ABytes)
  else
    LResult := -Int32(GetLastError);

  IocpUnlinkOp(AReactor, LOp);
  try
    if Assigned(LOp^.Callback) then
      LOp^.Callback(LOp^.UserData, LResult, LOp^.Context);
  finally
    IocpFreeOp(AReactor, LOp);
  end;
  Result := True;
end;

class function TIocpReactor.Create(AMaxEvents: UInt32): TIocpReactor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FMaxEvents := AMaxEvents;
  AtomicStore32(Result.FRunning, 0, moRelease);
  Result.FPort := PtrUInt(CreateIoCompletionPort(HANDLE(INVALID_HANDLE_VALUE),
    nil, 0, AMaxEvents));
end;

procedure TIocpReactor.Close;
var
  LPort: PtrUInt;
begin
  AtomicStore32(FRunning, 0, moRelease);
  LPort := FPort;
  FPort := 0;
  FMaxEvents := 0;
  try
    IocpReleasePendingOps(Self, ERROR_OPERATION_ABORTED);
  finally
    IocpReleaseAssociatedHandles(Self);
    if LPort <> 0 then
      CloseHandle(HANDLE(LPort));
  end;
end;

function TIocpReactor.IsValid: Boolean;
begin
  Result := FPort <> 0;
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
begin
  Result := IocpUnsupportedAsync;
end;

function TIocpReactor.AsyncConnect(AFd: PtrInt; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := IocpUnsupportedAsync;
end;

function TIocpReactor.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitSocketOp(Self, opSend, AFd, ABuf, ALen, AFlags,
    ACallback, AContext);
end;

function TIocpReactor.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := IocpSubmitSocketOp(Self, opRecv, AFd, ABuf, ALen, AFlags,
    ACallback, AContext);
end;

function TIocpReactor.AsyncClose(AFd: PtrInt;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := IocpUnsupportedAsync;
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
  Result := FPendingCount > 0;
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

procedure TIocpReactor.Run;
var
  LBytes: DWORD;
  LKey: ULONG_PTR;
  LOverlapped: LPOVERLAPPED;
  LOk: BOOL;
begin
  if FPort = 0 then
    Exit;

  AtomicStore32(FRunning, 1, moRelease);
  try
    while AtomicLoad32(FRunning, moAcquire) <> 0 do
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
    AtomicStore32(FRunning, 0, moRelease);
  end;
end;

procedure TIocpReactor.Stop;
begin
  AtomicStore32(FRunning, 0, moRelease);
  if FPort <> 0 then
    PostQueuedCompletionStatus(HANDLE(FPort), 0, 0, nil);
end;

function TIocpReactor.Flush: Int32;
begin
  Result := 0;
end;

end.
{$ELSE}
interface
implementation
end.
{$ENDIF}
