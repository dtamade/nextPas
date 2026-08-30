unit nextpas.core.ssh.proxyjump.async;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.base, nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.io.intf, nextpas.core.net.base, nextpas.core.net.intf, nextpas.core.async.base, nextpas.core.async.loop, nextpas.core.async.cancellation, nextpas.core.net.async.tcp, nextpas.core.ssh.base, nextpas.core.ssh.errors, nextpas.core.ssh.transport.async;
type PWriteCtx = ^TWriteCtx; TWriteCtx = record Cb: TIoCompletion; Ctx: Pointer; Len: UInt32; end;
type TAsyncChannelStream = class(TInterfacedObject, IAsyncTcpStream)
private
  FLoop: TAsyncLoop; FTransport: TAsyncSshTransport; FKeeper: IInterface; FLocalId, FRemoteId, FOurWindow, FPeerWindow, FPeerMax, FInitWindow: UInt32;
  FReadBuf: TBytes; FClosed: Boolean;
  FReadPendingBuf: Pointer; FReadPendingLen: UInt32; FReadPendingCb: TIoCompletion; FReadPendingCtx: Pointer;
  FWritePendingBuf: Pointer; FWritePendingLen: UInt32; FWritePendingCb: TIoCompletion; FWritePendingCtx: Pointer;
  FPacketCbActive: Boolean;
  FQueuedPayload: TBytes; FQueuedP: PWriteCtx; FQueuedActive: Boolean;
  procedure ArmRead; function TrySatisfyPendingRead: Boolean; procedure AccountConsume(ACount: UInt32); procedure FailPending(AErr: Int32); procedure TryFlushQueued;
public
  constructor Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); overload;
  constructor CreateWithKeeper(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); overload;
  destructor Destroy; override;
  function Read(var ABuf; const ACount: SizeUInt): SizeUInt; function Write(const ABuf; const ACount: SizeUInt): SizeUInt; procedure Close;
  function LocalAddr: TNetAddress; function RemoteAddr: TNetAddress; procedure Shutdown; procedure SetNoDelay(const AValue: Boolean); procedure SetKeepAlive(const AValue: Boolean);
  procedure SetReadDeadline(const ADeadline: TDeadline); procedure SetWriteDeadline(const ADeadline: TDeadline); procedure SetCancelToken(const AToken: INetCancelToken); procedure BindCancelToken(const AToken: IAsyncCancellationToken);
  function NativeSocketHandle: PtrUInt; procedure SetBlocking(const ABlocking: Boolean);
  function TryRead(var ABuf; const ACount: SizeUInt; out ARead: SizeUInt): TTcpStreamIOResult; function TryWrite(const ABuf; const ACount: SizeUInt; out AWritten: SizeUInt): TTcpStreamIOResult;
  function AsyncRead(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean; function AsyncReadRef(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
  function AsyncWrite(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean; function AsyncWriteRef(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
  function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean; function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
end;
implementation
uses nextpas.core.ssh.buffer;
procedure ChannelStreamRetryWrite(AContext: Pointer); forward;
procedure Channel_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure Channel_WriteDone(AErr: ESSHError; AContext: Pointer); forward;
constructor TAsyncChannelStream.Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32);
begin inherited Create; FLoop:=ALoop; FTransport:=ATransport; FLocalId:=ALocalId; FRemoteId:=ARemoteId; FPeerWindow:=APeerWindow; FPeerMax:=APeerMax; FInitWindow:=2097152; FOurWindow:=FInitWindow; ArmRead; end;
constructor TAsyncChannelStream.CreateWithKeeper(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32);
begin inherited Create; FLoop:=ALoop; FTransport:=ATransport; FKeeper:=AKeeper; FLocalId:=ALocalId; FRemoteId:=ARemoteId; FPeerWindow:=APeerWindow; FPeerMax:=APeerMax; FInitWindow:=2097152; FOurWindow:=FInitWindow; ArmRead; end;
destructor TAsyncChannelStream.Destroy; begin Close; FKeeper:=nil; inherited; end;
function TAsyncChannelStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; end;
function TAsyncChannelStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; end;
procedure TAsyncChannelStream.Close; begin FClosed:=True; end;
function TAsyncChannelStream.LocalAddr: TNetAddress; begin FillChar(Result,0,SizeOf(Result)); end;
function TAsyncChannelStream.RemoteAddr: TNetAddress; begin FillChar(Result,0,SizeOf(Result)); end;
procedure TAsyncChannelStream.Shutdown; begin Close; end;
procedure TAsyncChannelStream.SetNoDelay(const AValue: Boolean); begin end;
procedure TAsyncChannelStream.SetKeepAlive(const AValue: Boolean); begin end;
procedure TAsyncChannelStream.SetReadDeadline(const ADeadline: TDeadline); begin end;
procedure TAsyncChannelStream.SetWriteDeadline(const ADeadline: TDeadline); begin end;
procedure TAsyncChannelStream.SetCancelToken(const AToken: INetCancelToken); begin end;
procedure TAsyncChannelStream.BindCancelToken(const AToken: IAsyncCancellationToken); begin end;
function TAsyncChannelStream.NativeSocketHandle: PtrUInt; begin Result:=0; end;
procedure TAsyncChannelStream.SetBlocking(const ABlocking: Boolean); begin end;
function TAsyncChannelStream.TryRead(var ABuf; const ACount: SizeUInt; out ARead: SizeUInt): TTcpStreamIOResult; begin ARead:=0; Result:=tsiorWouldBlock; end;
function TAsyncChannelStream.TryWrite(const ABuf; const ACount: SizeUInt; out AWritten: SizeUInt): TTcpStreamIOResult; begin AWritten:=0; if FClosed then Result:=tsiorClosed else Result:=tsiorWouldBlock; end;
procedure TAsyncChannelStream.FailPending(AErr: Int32); begin if Assigned(FReadPendingCb) then begin FReadPendingCb(0, AErr, FReadPendingCtx); FReadPendingCb:=nil; FReadPendingCtx:=nil; FReadPendingBuf:=nil; end; if Assigned(FWritePendingCb) then begin FWritePendingCb(0, AErr, FWritePendingCtx); FWritePendingCb:=nil; FWritePendingCtx:=nil; FWritePendingBuf:=nil; end; end;
procedure TAsyncChannelStream.AccountConsume(ACount: UInt32);
var LGive: UInt32; LW: TsshWriter;
begin if ACount>FOurWindow then begin LGive:=FOurWindow; FOurWindow:=0; end else begin Dec(FOurWindow, ACount); LGive:=0; end;
  if FOurWindow <= FInitWindow div 2 then begin Inc(LGive, FInitWindow - FOurWindow); FOurWindow:=FInitWindow; end;
  if LGive>0 then begin LW:=TsshWriter.Create(16); try LW.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST); LW.PutUInt32(FRemoteId); LW.PutUInt32(LGive); FTransport.AsyncSendPacket(LW.ToBytes, nil, nil); finally LW.Free; end; end;
end;

procedure TAsyncChannelStream.TryFlushQueued;
begin if not FQueuedActive then Exit; if FTransport.AsyncSendPacket(FQueuedPayload, @Channel_WriteDone, FQueuedP) then begin FQueuedActive:=False; FQueuedPayload:=nil; FQueuedP:=nil; end else try FLoop.ScheduleAt(TDeadline.After(TDuration.FromMilliseconds(5)), @ChannelStreamRetryWrite, Self); except end;
end;
procedure TAsyncChannelStream.ArmRead;
begin if FPacketCbActive or FClosed then Exit; FPacketCbActive:=True; if not FTransport.AsyncReadPacket(@Channel_OnPacket, Self) then FPacketCbActive:=False; end;
function TAsyncChannelStream.TrySatisfyPendingRead: Boolean;
var LCopy, LBufLen: UInt32; Cb: TIoCompletion; Ctx: Pointer;
begin Result:=False; if not Assigned(FReadPendingCb) then Exit; if Length(FReadBuf)=0 then Exit;
  LBufLen:=Length(FReadBuf); LCopy:=FReadPendingLen; if LCopy>LBufLen then LCopy:=LBufLen;
  Move(FReadBuf[0], FReadPendingBuf^, LCopy); AccountConsume(LCopy);
  if LCopy<LBufLen then begin Move(FReadBuf[LCopy], FReadBuf[0], LBufLen-LCopy); SetLength(FReadBuf, LBufLen-LCopy); end else SetLength(FReadBuf,0);
  Cb:=FReadPendingCb; Ctx:=FReadPendingCtx; FReadPendingCb:=nil; FReadPendingCtx:=nil; FReadPendingBuf:=nil; Cb(0, Int32(LCopy), Ctx); Result:=True;
end;
function TAsyncChannelStream.AsyncRead(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin if Assigned(FReadPendingCb) then Exit(False); if ALen=0 then begin if Assigned(ACallback) then ACallback(0,0,AContext); Exit(True); end;
  FReadPendingBuf:=ABuf; FReadPendingLen:=ALen; FReadPendingCb:=ACallback; FReadPendingCtx:=AContext;
  if not TrySatisfyPendingRead then ArmRead; Result:=True;
end;
function TAsyncChannelStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var Ctx: Pointer; begin Ctx:=WrapIoCompletionRef(ACallback, AContext); Result:=AsyncRead(ABuf, ALen, @IoCompletionRefWrapper, Ctx); if not Result then Dispose(PIoCompletionRefCtx(Ctx)); end;
function TAsyncChannelStream.AsyncWrite(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LW: TsshWriter; LChunk: TBytes; LTake: UInt32; P: PWriteCtx; LOuter: TBytes;
begin if FClosed then begin if Assigned(ACallback) then ACallback(0,-1,AContext); Exit(False); end;
  if FQueuedActive then Exit(False);
  if ALen=0 then begin if Assigned(ACallback) then ACallback(0,0,AContext); Exit(True); end;
  LTake:=ALen; if LTake>FPeerWindow then LTake:=FPeerWindow; if LTake>FPeerMax then LTake:=FPeerMax; if LTake=0 then Exit(False);
  SetLength(LChunk, LTake); Move(ABuf^, LChunk[0], LTake); New(P); P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Len:=LTake; LW:=TsshWriter.Create(16+Integer(LTake)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FRemoteId); LW.PutUInt32(LTake); LW.PutRaw(LChunk); LOuter:=LW.ToBytes; Dec(FPeerWindow, LTake); Result:=FTransport.AsyncSendPacket(LOuter, @Channel_WriteDone, P); if not Result then begin
      FQueuedPayload:=LOuter; FQueuedP:=P; FQueuedActive:=True;
      try FLoop.ScheduleAt(TDeadline.After(TDuration.FromMilliseconds(5)), @ChannelStreamRetryWrite, Self); except Dispose(P); Inc(FPeerWindow, LTake); if Assigned(ACallback) then ACallback(0,-1,AContext); Exit(False); end;
      Result:=True; end; finally LW.Free; end;
end;
procedure ChannelStreamRetryWrite(AContext: Pointer);
begin TAsyncChannelStream(AContext).TryFlushQueued; end;
function TAsyncChannelStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var Ctx: Pointer; begin Ctx:=WrapIoCompletionRef(ACallback, AContext); Result:=AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, Ctx); if not Result then Dispose(PIoCompletionRefCtx(Ctx)); end;
function TAsyncChannelStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean; begin Result:=AsyncRead(ABuf, ALen, ACallback, AContext); end;
function TAsyncChannelStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean; begin Result:=AsyncWrite(ABuf, ALen, ACallback, AContext); end;
procedure Channel_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncChannelStream; LR: TsshReader; LId, LDataType: UInt32; LData: TBytes; LOld: Integer;
begin
Self:=TAsyncChannelStream(AContext); Self.FPacketCbActive:=False; if AErr<>nil then begin Self.FailPending(-1); AErr.Free; Exit; end;
  if Length(APayload)=0 then begin Self.ArmRead; Exit; end;
  case APayload[0] of
    SSH_MSG_CHANNEL_DATA: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; LData:=LR.ReadStringBytes; finally LR.Free; end; if Length(LData)>0 then begin LOld:=Length(Self.FReadBuf); SetLength(Self.FReadBuf, LOld+Length(LData)); Move(LData[0], Self.FReadBuf[LOld], Length(LData)); Self.TrySatisfyPendingRead; end; end;
    SSH_MSG_CHANNEL_EXTENDED_DATA: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; LDataType:=LR.ReadUInt32; LData:=LR.ReadStringBytes; finally LR.Free; end; if (LDataType=1) and (Length(LData)>0) then begin LOld:=Length(Self.FReadBuf); SetLength(Self.FReadBuf, LOld+Length(LData)); Move(LData[0], Self.FReadBuf[LOld], Length(LData)); Self.TrySatisfyPendingRead; end else if Length(LData)>0 then Self.AccountConsume(Length(LData)); end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; Self.FPeerWindow:=Self.FPeerWindow+LR.ReadUInt32; finally LR.Free; end; end;
    SSH_MSG_CHANNEL_EOF, SSH_MSG_CHANNEL_CLOSE: begin Self.FClosed:=True; if Assigned(Self.FReadPendingCb) then Self.FReadPendingCb(0, 0, Self.FReadPendingCtx); Self.FReadPendingCb:=nil; end;
  end;
  if not Self.FClosed then Self.ArmRead;
end;
procedure Channel_WriteDone(AErr: ESSHError; AContext: Pointer);
var P: PWriteCtx; Cb: TIoCompletion; Ctx: Pointer; Len: UInt32;
begin P:=PWriteCtx(AContext); Cb:=P^.Cb; Ctx:=P^.Ctx; Len:=P^.Len; Dispose(P);
  if AErr<>nil then begin if Assigned(Cb) then Cb(0, -1, Ctx); AErr.Free; Exit; end; if Assigned(Cb) then Cb(0, Int32(Len), Ctx); end;
end.
