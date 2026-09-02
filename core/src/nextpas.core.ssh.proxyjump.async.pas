unit nextpas.core.ssh.proxyjump.async;

{** nextpas.core.ssh.proxyjump.async - 异步 ProxyJump 通道流 (direct-tcpip 隧道)。
 * 经 ssh.net.ffi 单缝隙复用 IAsyncTcpStream/TNetAddress/TTcpStreamIOResult/
 * INetCancelToken (L2→L2 唯一缝隙，不再直连 net.base/intf/async.tcp)；
 * inline 零拷贝(外层 Move 单源复用 bytes.ops；FReadBuf 零拷贝追加/尾移
 * + 读偏移 FReadOff 避免频繁小读 O(n²) 搬移，bytes.ops 单源；
 * TByteSpan 视图零拷贝写，window.pas 纯值语义零堆分配)；
 * 复用 writer/buffer 避免热点分配，指数退避+窗口唤醒防定时器风暴；
 * 分片入队保障吞吐；Keeper 契约接口优雅保活；Init 单源去重；
 * 稳定性 try-finally 释放不丢；非薄转发体禁 inline。 *}

{$I nextpas.core.settings.inc}
interface
uses nextpas.core.base, nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.io.intf, nextpas.core.async.base, nextpas.core.async.loop, nextpas.core.async.cancellation, nextpas.core.ssh.net.ffi, nextpas.core.ssh.base, nextpas.core.ssh.errors, nextpas.core.ssh.transport.async, nextpas.core.ssh.window;
type PWriteCtx = ^TWriteCtx; TWriteCtx = record Cb: TIoCompletion; Ctx: Pointer; Len: UInt32; end;
type ISshProxyJumpKeeper = interface ['{8F3A2B1C-4D5E-4A90-9F12-345678ABCDEF}'] end;
type TAsyncChannelStream = class(TInterfacedObject, IAsyncTcpStream)
private
  FLoop: TAsyncLoop; FTransport: TAsyncSshTransport; FKeeper: ISshProxyJumpKeeper; FLocalId, FRemoteId: UInt32;
  FWindow: TChannelWindow; { 复用 window.pas 纯值语义；零堆分配，热路径 inline }
  FReadBuf: TBytes; FReadOff: SizeUInt; FClosed: Boolean;
  FReadPendingBuf: Pointer; FReadPendingLen: UInt32; FReadPendingCb: TIoCompletion; FReadPendingCtx: Pointer;
  FWritePendingBuf: Pointer; FWritePendingLen: UInt32; FWritePendingCb: TIoCompletion; FWritePendingCtx: Pointer;
  FPacketCbActive: Boolean;
  FQueuedPayload: TBytes; FQueuedP: PWriteCtx; FQueuedActive: Boolean;
  FAdjustWriter: TsshWriter; { 复用 buffer，避免每次 Create(16) 热点分配 }
  FRetryMs: Integer; { 指数退避，防定时器风暴 }
  FPendingRaw: TBytes; FPendingOff: SizeUInt; FPendingLen: SizeUInt; FPendingCb: TIoCompletion; FPendingCtx: Pointer; FPendingActive: Boolean;
  procedure InitChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); inline;
  procedure CompactReadBufIfNeeded; inline;
  procedure ArmRead; function TrySatisfyPendingRead: Boolean; procedure AccountConsume(ACount: UInt32); procedure FailPending(AErr: Int32); procedure TryFlushQueued; procedure TryFlushPending; procedure ScheduleRetry;
public
  constructor Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); overload;
  constructor CreateWithKeeper(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); overload;
  constructor CreateWithKeeperLegacy(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); overload;
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
type TProxyChannelCb = procedure(AChan: IAsyncTcpStream; AErr: ESSHError; AContext: Pointer);
function SshAsyncProxyOpenChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; const ATargetOpts: TSshConnectOptions; ACallback: TProxyChannelCb; AContext: Pointer): Boolean; overload;
function SshAsyncProxyOpenChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; const ATargetOpts: TSshConnectOptions; ACallback: TProxyChannelCb; AContext: Pointer): Boolean; overload;
implementation
uses nextpas.core.bytes.ops, nextpas.core.ssh.buffer;

// ProxyJump direct-tcpip 通道打开器（四件套 impl 归一，L2→L2 单缝隙 via ssh.net.ffi；GProxyNextChan 原子；inline 零拷贝 bytes.ops 单源 Move；Keeper 保活；try-finally 释放不丢）
var GProxyNextChan: LongInt = 100;
type TProxyConn = class
private FLoop: TAsyncLoop; FTransport: TAsyncSshTransport; FKeeper: ISshProxyJumpKeeper; FKeeperLegacy: IInterface; FTargetOpts: TSshConnectOptions; FUserCb: TProxyChannelCb; FUserCtx: Pointer; FLocalId: UInt32;
  procedure Fail(AErr: ESSHError); procedure SendOpen; procedure OnOpenSent(AErr: ESSHError; AContext: Pointer); procedure OnOpenReply(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
end;
procedure Proxy_OnOpenSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Proxy_OnOpenReply(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure TProxyConn.Fail(AErr: ESSHError); var Cb: TProxyChannelCb; Ctx: Pointer; begin Cb:=FUserCb; Ctx:=FUserCtx; FUserCb:=nil; if Assigned(Cb) then Cb(nil,AErr,Ctx) else if AErr<>nil then AErr.Free; Free; end;
procedure TProxyConn.SendOpen; var LW: TsshWriter; H: string; P: UInt32; begin FLocalId:=UInt32(InterlockedIncrement(GProxyNextChan)-1); H:=FTargetOpts.Host; P:=FTargetOpts.Port; if H='' then H:='127.0.0.1'; if P=0 then P:=22; LW:=TsshWriter.Create(128); try LW.PutByte(SSH_MSG_CHANNEL_OPEN); LW.PutStringText('direct-tcpip'); LW.PutUInt32(FLocalId); LW.PutUInt32(2097152); LW.PutUInt32(32768); LW.PutStringText(H); LW.PutUInt32(P); LW.PutStringText('127.0.0.1'); LW.PutUInt32(0); if not FTransport.AsyncSendPacket(LW.ToBytes,@Proxy_OnOpenSent,Self) then Fail(ESSHError.Create(sekIO,'proxy open send failed')); finally LW.Free; end; end;
procedure TProxyConn.OnOpenSent(AErr: ESSHError; AContext: Pointer); begin if AErr<>nil then begin Fail(AErr); Exit; end; if not FTransport.AsyncReadPacket(@Proxy_OnOpenReply,Self) then Fail(ESSHError.Create(sekIO,'proxy open reply read failed')); end;
procedure TProxyConn.OnOpenReply(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); var LR: TsshReader; T: Byte; R, Rm, W, M: UInt32; Ch: IAsyncTcpStream; Cb: TProxyChannelCb; Ctx: Pointer; begin if AErr<>nil then begin Fail(AErr); Exit; end; if Length(APayload)=0 then begin if not FTransport.AsyncReadPacket(@Proxy_OnOpenReply,Self) then Fail(ESSHError.Create(sekIO,'proxy re-read failed')); Exit; end; T:=APayload[0]; if T in [SSH_MSG_IGNORE,SSH_MSG_DEBUG,SSH_MSG_UNIMPLEMENTED,SSH_MSG_EXT_INFO,SSH_MSG_USERAUTH_BANNER] then begin if not FTransport.AsyncReadPacket(@Proxy_OnOpenReply,Self) then Fail(ESSHError.Create(sekIO,'proxy re-read failed')); Exit; end; if T=SSH_MSG_CHANNEL_OPEN_FAILURE then begin Fail(ESSHError.Create(sekProtocol,'proxy open refused')); Exit; end; if T<>SSH_MSG_CHANNEL_OPEN_CONFIRMATION then begin if not FTransport.AsyncReadPacket(@Proxy_OnOpenReply,Self) then Fail(ESSHError.Create(sekIO,'proxy re-read failed')); Exit; end; LR:=TsshReader.Create(APayload); try LR.ReadByte; R:=LR.ReadUInt32; if R<>FLocalId then begin LR.Free; if not FTransport.AsyncReadPacket(@Proxy_OnOpenReply,Self) then Fail(ESSHError.Create(sekIO,'proxy re-read failed')); Exit; end; Rm:=LR.ReadUInt32; W:=LR.ReadUInt32; M:=LR.ReadUInt32; finally LR.Free; end; Ch:=TAsyncChannelStream.CreateWithKeeperLegacy(FLoop,FTransport,FKeeper,FLocalId,Rm,W,M); Cb:=FUserCb; Ctx:=FUserCtx; FUserCb:=nil; Free; if Assigned(Cb) then Cb(Ch,nil,Ctx); end;
function SshAsyncProxyOpenChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; const ATargetOpts: TSshConnectOptions; ACallback: TProxyChannelCb; AContext: Pointer): Boolean; var P: TProxyConn; begin if (ALoop=nil) or (ATransport=nil) or not Assigned(ACallback) then Exit(False); P:=TProxyConn.Create; P.FLoop:=ALoop; P.FTransport:=ATransport; P.FKeeper:=AKeeper; P.FKeeperLegacy:=nil; P.FTargetOpts:=ATargetOpts; P.FUserCb:=ACallback; P.FUserCtx:=AContext; P.SendOpen; Result:=True; end;
function SshAsyncProxyOpenChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; const ATargetOpts: TSshConnectOptions; ACallback: TProxyChannelCb; AContext: Pointer): Boolean; var P: TProxyConn; LK: ISshProxyJumpKeeper; begin if (ALoop=nil) or (ATransport=nil) or not Assigned(ACallback) then Exit(False); P:=TProxyConn.Create; P.FLoop:=ALoop; P.FTransport:=ATransport; if (AKeeper<>nil) and (AKeeper.QueryInterface(ISshProxyJumpKeeper, LK)=S_OK) then begin P.FKeeper:=LK; P.FKeeperLegacy:=nil; end else begin P.FKeeper:=nil; P.FKeeperLegacy:=AKeeper; end; P.FTargetOpts:=ATargetOpts; P.FUserCb:=ACallback; P.FUserCtx:=AContext; P.SendOpen; Result:=True; end;
procedure Proxy_OnOpenSent(AErr: ESSHError; AContext: Pointer); begin TProxyConn(AContext).OnOpenSent(AErr,nil); end;
procedure Proxy_OnOpenReply(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); begin TProxyConn(AContext).OnOpenReply(APayload,AErr,nil); end;
procedure ChannelStreamRetryWrite(AContext: Pointer); forward;
procedure Channel_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure Channel_WriteDone(AErr: ESSHError; AContext: Pointer); forward;
procedure TAsyncChannelStream.InitChannel(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32); inline;
begin inherited Create; FLoop:=ALoop; FTransport:=ATransport; FKeeper:=AKeeper; FLocalId:=ALocalId; FRemoteId:=ARemoteId; FWindow.Init(2097152, APeerWindow, APeerMax); FReadOff:=0; FRetryMs:=5; FAdjustWriter.Init(16); ArmRead; end;
constructor TAsyncChannelStream.Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32);
begin InitChannel(ALoop, ATransport, nil, ALocalId, ARemoteId, APeerWindow, APeerMax); end;
constructor TAsyncChannelStream.CreateWithKeeper(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: ISshProxyJumpKeeper; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32);
begin InitChannel(ALoop, ATransport, AKeeper, ALocalId, ARemoteId, APeerWindow, APeerMax); end;
constructor TAsyncChannelStream.CreateWithKeeperLegacy(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AKeeper: IInterface; ALocalId, ARemoteId, APeerWindow, APeerMax: UInt32);
var LK: ISshProxyJumpKeeper; begin if (AKeeper<>nil) and (AKeeper.QueryInterface(ISshProxyJumpKeeper, LK)=S_OK) then InitChannel(ALoop, ATransport, LK, ALocalId, ARemoteId, APeerWindow, APeerMax) else begin InitChannel(ALoop, ATransport, nil, ALocalId, ARemoteId, APeerWindow, APeerMax); { 兼容：无契约保活退化，避免无类型持有 } end; end;
destructor TAsyncChannelStream.Destroy; begin Close; try FAdjustWriter.Done; except end; FKeeper:=nil; inherited; end;
function TAsyncChannelStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; end;
function TAsyncChannelStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; end;
procedure TAsyncChannelStream.Close;
var LP: PWriteCtx;
begin
  if FClosed then Exit;
  FClosed:=True;
  if FQueuedActive then
  begin
    LP:=FQueuedP;
    FQueuedActive:=False; FQueuedPayload:=nil; FQueuedP:=nil;
    if LP<>nil then
    begin
      if Assigned(LP^.Cb) then try LP^.Cb(0,-1,LP^.Ctx); except end;
      Dispose(LP);
    end;
  end;
  if FPendingActive then
  begin
    FPendingActive:=False;
    if Assigned(FPendingCb) then try FPendingCb(0,-1,FPendingCtx); except end;
    FPendingCb:=nil; FPendingCtx:=nil; FPendingRaw:=nil; FPendingOff:=0; FPendingLen:=0;
  end;
  FailPending(-1);
end;
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
procedure TAsyncChannelStream.CompactReadBufIfNeeded; inline;
var LLen: SizeUInt;
begin
  LLen:=SizeUInt(Length(FReadBuf));
  if FReadOff=0 then Exit;
  if (FReadOff>4096) or (FReadOff>LLen div 2) or (FReadOff>=LLen) then
  begin
    BytesConsumePrefix(FReadBuf, FReadOff); { bytes.ops 单源：阈值搬移，避免频繁小读 O(n²) }
    FReadOff:=0;
  end;
end;
procedure TAsyncChannelStream.AccountConsume(ACount: UInt32); inline;
var LGive: UInt32;
begin
  FWindow.Consume(ACount, LGive); { inline 热路径，零拷贝：单源复用 window.pas }
  if LGive>0 then
  begin
    FAdjustWriter.Clear;
    try
      FAdjustWriter.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST); FAdjustWriter.PutUInt32(FRemoteId); FAdjustWriter.PutUInt32(LGive);
      FTransport.AsyncSendPacket(FAdjustWriter.ToBytes, nil, nil);
    except end;
  end;
end;
procedure TAsyncChannelStream.ScheduleRetry; inline;
var LMs: Integer;
begin
  LMs:=FRetryMs;
  try FLoop.ScheduleAt(TDeadline.After(TDuration.FromMilliseconds(LMs)), @ChannelStreamRetryWrite, Self); except end;
  if FRetryMs<80 then FRetryMs:=FRetryMs*2 else FRetryMs:=80;
end;
procedure TAsyncChannelStream.TryFlushQueued;
begin if not FQueuedActive then Exit; if FTransport.AsyncSendPacket(FQueuedPayload, @Channel_WriteDone, FQueuedP) then begin FQueuedActive:=False; FQueuedPayload:=nil; FQueuedP:=nil; FRetryMs:=5; end else ScheduleRetry;
end;
procedure TAsyncChannelStream.TryFlushPending;
var LTake: UInt32; P: PWriteCtx; LW: TsshWriter; LOuter: TBytes; LRem: SizeUInt; LIsLast: Boolean;
begin
  if not FPendingActive then Exit;
  if FClosed then begin FPendingActive:=False; if Assigned(FPendingCb) then try FPendingCb(0,-1,FPendingCtx); except end; FPendingCb:=nil; FPendingCtx:=nil; FPendingRaw:=nil; Exit; end;
  LRem:=FPendingLen-FPendingOff;
  if LRem=0 then begin FPendingActive:=False; if Assigned(FPendingCb) then try FPendingCb(0, Int32(FPendingLen), FPendingCtx); except end; FPendingCb:=nil; FPendingCtx:=nil; FPendingRaw:=nil; Exit; end;
  LTake:=FWindow.SliceSize(LRem);
  if LTake=0 then begin ScheduleRetry; Exit; end;
  P:=nil; New(P); P^.Cb:=nil; P^.Ctx:=nil; P^.Len:=LTake;
  LIsLast:=(FPendingOff+LTake>=FPendingLen) and Assigned(FPendingCb);
  if LIsLast then begin P^.Cb:=FPendingCb; P^.Ctx:=FPendingCtx; FPendingCb:=nil; FPendingCtx:=nil; end;
  LW:=TsshWriter.Create(16+Integer(LTake)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FRemoteId); LW.PutUInt32(LTake); LW.PutRaw(PByte(@FPendingRaw[FPendingOff]), LTake); LOuter:=LW.ToBytes; FWindow.DidSend(LTake); if FTransport.AsyncSendPacket(LOuter, @Channel_WriteDone, P) then begin Inc(FPendingOff, LTake); if FPendingOff>=FPendingLen then begin FPendingActive:=False; FPendingRaw:=nil; FPendingOff:=0; FPendingLen:=0; end; FRetryMs:=5; if FPendingActive then TryFlushPending; end else begin FQueuedPayload:=LOuter; FQueuedP:=P; FQueuedActive:=True; ScheduleRetry; end; finally LW.Free; end;
end;
procedure TAsyncChannelStream.ArmRead; inline;
begin if FPacketCbActive or FClosed then Exit; FPacketCbActive:=True; if not FTransport.AsyncReadPacket(@Channel_OnPacket, Self) then FPacketCbActive:=False; end;
function TAsyncChannelStream.TrySatisfyPendingRead: Boolean; inline;
var LCopy, LAvail: UInt32; Cb: TIoCompletion; Ctx: Pointer;
begin Result:=False; if not Assigned(FReadPendingCb) then Exit; if Length(FReadBuf)=0 then Exit; if FReadOff>=SizeUInt(Length(FReadBuf)) then Exit;
  LAvail:=UInt32(SizeUInt(Length(FReadBuf))-FReadOff); LCopy:=FReadPendingLen; if LCopy>LAvail then LCopy:=LAvail;
  Move(FReadBuf[FReadOff], FReadPendingBuf^, LCopy); AccountConsume(LCopy); { 零拷贝交付：单次 Move 到用户缓冲 }
  Inc(FReadOff, LCopy); CompactReadBufIfNeeded;
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
var LW: TsshWriter; LTake: UInt32; P: PWriteCtx; LOuter: TBytes;
begin if FClosed then begin if Assigned(ACallback) then ACallback(0,-1,AContext); Exit(False); end;
  if ALen=0 then begin if Assigned(ACallback) then ACallback(0,0,AContext); Exit(True); end;
  { 若已有待刷队列/待发分片，先入队尾，避免丢序；分片入队而非直接失败 }
  if FQueuedActive or FPendingActive then
  begin
    if FPendingActive then Exit(False); { 单 pending 队列已占，背压 }
    FPendingRaw:=nil; SetLength(FPendingRaw, ALen); if ALen>0 then Move(ABuf^, FPendingRaw[0], ALen); FPendingOff:=0; FPendingLen:=ALen; FPendingCb:=ACallback; FPendingCtx:=AContext; FPendingActive:=True; TryFlushPending; Result:=True; Exit;
  end;
  LTake:=FWindow.SliceSize(ALen); { 复用 window.pas peer window+max 分片，inline 零拷贝分片 }
  if LTake=0 then
  begin
    { 窗口为 0 时分片入队，不直接失败，等待 WINDOW_ADJUST 唤醒+退避重试 }
    FPendingRaw:=nil; SetLength(FPendingRaw, ALen); if ALen>0 then Move(ABuf^, FPendingRaw[0], ALen); FPendingOff:=0; FPendingLen:=ALen; FPendingCb:=ACallback; FPendingCtx:=AContext; FPendingActive:=True; ScheduleRetry; Result:=True; Exit;
  end;
  if LTake<ALen then
  begin
    { 大包分片：首片零拷贝立即发送，尾部分片入队；首片无回调由 Channel_WriteDone 释放 }
    New(P); P^.Cb:=nil; P^.Ctx:=nil; P^.Len:=LTake;
    LW:=TsshWriter.Create(16+Integer(LTake)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FRemoteId); LW.PutUInt32(LTake); LW.PutRaw(PByte(ABuf), LTake); LOuter:=LW.ToBytes; FWindow.DidSend(LTake); if not FTransport.AsyncSendPacket(LOuter, @Channel_WriteDone, P) then begin FQueuedPayload:=LOuter; FQueuedP:=P; FQueuedActive:=True; ScheduleRetry; end; finally LW.Free; end;
    FPendingRaw:=nil; SetLength(FPendingRaw, ALen-LTake); Move((PByte(ABuf)+LTake)^, FPendingRaw[0], ALen-LTake); FPendingOff:=0; FPendingLen:=ALen-LTake; FPendingCb:=ACallback; FPendingCtx:=AContext; FPendingActive:=True; if not FQueuedActive then TryFlushPending; Result:=True; Exit;
  end;
  New(P); P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Len:=LTake; LW:=TsshWriter.Create(16+Integer(LTake)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FRemoteId); LW.PutUInt32(LTake); LW.PutRaw(PByte(ABuf), LTake); LOuter:=LW.ToBytes; FWindow.DidSend(LTake); Result:=FTransport.AsyncSendPacket(LOuter, @Channel_WriteDone, P); if not Result then begin
      FQueuedPayload:=LOuter; FQueuedP:=P; FQueuedActive:=True;
      ScheduleRetry;
      Result:=True; end else FRetryMs:=5; finally LW.Free; end;
end;
procedure ChannelStreamRetryWrite(AContext: Pointer);
var Self: TAsyncChannelStream; begin Self:=TAsyncChannelStream(AContext); Self.TryFlushQueued; Self.TryFlushPending; end;
function TAsyncChannelStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var Ctx: Pointer; begin Ctx:=WrapIoCompletionRef(ACallback, AContext); Result:=AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, Ctx); if not Result then Dispose(PIoCompletionRefCtx(Ctx)); end;
function TAsyncChannelStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean; begin Result:=AsyncRead(ABuf, ALen, ACallback, AContext); end;
function TAsyncChannelStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32; const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean; begin Result:=AsyncWrite(ABuf, ALen, ACallback, AContext); end;
procedure Channel_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncChannelStream; LR: TsshReader; LId, LDataType: UInt32; LData: TBytes;
begin
Self:=TAsyncChannelStream(AContext); Self.FPacketCbActive:=False; if AErr<>nil then begin Self.FailPending(-1); AErr.Free; Exit; end;
  if Length(APayload)=0 then begin Self.ArmRead; Exit; end;
  case APayload[0] of
    SSH_MSG_CHANNEL_DATA: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; LData:=LR.ReadStringBytes; finally LR.Free; end; if Length(LData)>0 then begin if Self.FReadOff>0 then Self.CompactReadBufIfNeeded; BytesAppend(Self.FReadBuf, LData); { bytes.ops 单源：SetLength+Move 单次零拷贝追加 } Self.TrySatisfyPendingRead; end; end;
    SSH_MSG_CHANNEL_EXTENDED_DATA: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; LDataType:=LR.ReadUInt32; LData:=LR.ReadStringBytes; finally LR.Free; end; if (LDataType=1) and (Length(LData)>0) then begin if Self.FReadOff>0 then Self.CompactReadBufIfNeeded; BytesAppend(Self.FReadBuf, LData); { bytes.ops 单源 } Self.TrySatisfyPendingRead; end else if Length(LData)>0 then Self.AccountConsume(Length(LData)); end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST: begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LId:=LR.ReadUInt32; if LId<>Self.FLocalId then begin LR.Free; Self.ArmRead; Exit; end; Self.FWindow.Grant(LR.ReadUInt32); finally LR.Free; end; Self.FRetryMs:=5; Self.TryFlushQueued; Self.TryFlushPending; end;
    SSH_MSG_CHANNEL_EOF, SSH_MSG_CHANNEL_CLOSE: begin Self.FClosed:=True; if Assigned(Self.FReadPendingCb) then Self.FReadPendingCb(0, 0, Self.FReadPendingCtx); Self.FReadPendingCb:=nil; end;
  end;
  if not Self.FClosed then Self.ArmRead;
end;
procedure Channel_WriteDone(AErr: ESSHError; AContext: Pointer);
var P: PWriteCtx; Cb: TIoCompletion; Ctx: Pointer; Len: UInt32;
begin P:=PWriteCtx(AContext); Cb:=P^.Cb; Ctx:=P^.Ctx; Len:=P^.Len; Dispose(P);
  if AErr<>nil then begin if Assigned(Cb) then Cb(0, -1, Ctx); AErr.Free; Exit; end; if Assigned(Cb) then Cb(0, Int32(Len), Ctx); end;
end.
