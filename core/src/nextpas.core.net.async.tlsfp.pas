unit nextpas.core.net.async.tlsfp;
{**
 * Async TLS 1.3 client stream over TAsyncLoop — 纯 Pascal 协议栈，
 * 零 OpenSSL、零第三方代理运行时（对齐 proxy888 最高规则 S1 自写协议基线）。
 *
 * 组成：密码学与线材构件全部复用 core 既有单元（tls13.clienthello /
 * parser / wire / recordcrypto / aead / keyschedule / finished /
 * appschedule / recordsealer / servercertificate），本单元只补缺失的
 * 一块：非阻塞记录泵 + 事件循环状态机。
 *
 * CONTRACT（与 nextpas.core.net.async.tls 同构，差异点见下）：
 * - 流面铁律：底层收发一律经 IAsyncTcpStream.AsyncRead/AsyncWrite，
 *   不触碰裸 fd（可用假流做密闭测试；可叠加在变换流之上）。
 * - 握手期绝对期限 Options.HandshakeDeadline（Infinite = 不设超时；
 *   零初始化表示「已过期」——用 DefaultAsyncTlsFpClientOptions 或显式
 *   TDeadline.Infinite）。超时交付 ASYNC_TLSFP_ERR_IO。
 * - 失败一次性交付：AStream=nil 且 AError<0；半开连接不外漏。
 *   提交返回 False 仅表示同步提交失败且【未】回调；True = 结果经回调。
 * - 数据相：读挂起与写挂起互相独立；同方向重复提交是调用方 bug；
 *   写整段封队冲刷完成后回调一次总长；底层负错误码原样透传（保留
 *   取消/超时域语义），解密失败/协议错交付本单元负码。
 * - 读返回 0 = EOF（close_notify 或对端 TCP EOF）；fatal alert 与解密
 *   失败不可降级为 EOF。
 * - Close 尽力发送 close_notify 后关底层（不等对端，quiet-shutdown）。
 *
 * v1 明示的能力边界（fail-closed，绝不假装支持）：
 * - 仅 TLS 1.3（服务器拒绝 1.3 即失败，无 1.2 回退）；密钥交换仅
 *   X25519；HelloRetryRequest / PSK 恢复 / 客户端证书（收到
 *   CertificateRequest 即失败）/ VerifyPeer=True（链信任库 + 主机名）
 *   均未支持，触发即显式失败。
 * - 后握手消息仅容忍 NewSessionTicket（忽略，v1 不做会话恢复）与
 *   KeyUpdate（update_requested 时按 RFC 8446 §4.6.3 轮换本端写密钥）；
 *   其余类型显式失败。
 *
 * Error codes: 0 = ok，否则负值：
 *   ASYNC_TLSFP_ERR_IO        底层流/提交失败、握手超时、解密失败
 *   ASYNC_TLSFP_ERR_HANDSHAKE TLS 协议层失败（alert、非法消息、边界）
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.async.base, nextpas.core.async.loop,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.net.async.tcp;

const
  { 底层流读写/提交失败、握手超时、解密失败 }
  ASYNC_TLSFP_ERR_IO = -3201;
  { TLS 协议层失败：alert、非法消息、不支持的对端选择 }
  ASYNC_TLSFP_ERR_HANDSHAKE = -3202;

type
  { 异步纯 Pas TLS 客户端选项。VerifyPeer=True 当前显式不支持
    （fail-closed：提交即抛错，避免「部分校验」假象）。 }
  TAsyncTlsFpClientOptions = record
    { SNI 主机名；空串 = 不发送（AsyncTlsFpConnect 回退填 Host） }
    ServerName: string;
    { 预留；当前必须 False }
    VerifyPeer: Boolean;
    { 握手阶段（含底层拨号）绝对期限；Infinite = 不设超时 }
    HandshakeDeadline: TDeadline;
  end;

  { 异步握手完成回调：AError=0 时 AStream 为就绪 TLS 流；失败时
    AStream=nil 且 AError<0。事件循环线程回调，一次。 }
  TAsyncTlsFpConnectCallback = procedure(AStream: IAsyncTcpStream;
    AError: Int32; AContext: Pointer);

function DefaultAsyncTlsFpClientOptions: TAsyncTlsFpClientOptions;

{ 在既有已连接流上做非阻塞纯 Pas TLS1.3 客户端握手（升级）。
  False = 同步提交失败且不回调；True = 结果经回调交付。
  提交成功后 AStream 所有权移交状态机，调用方不得再使用。 }
function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer = nil): Boolean;

{ 拨号 + 升级一步到位（AsyncTcpDial Happy-Eyeballs + TLS 握手共用
  HandshakeDeadline）。SNI 缺省取 AHost。返回语义同 AsyncTlsFpUpgrade。 }
function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.system.sysutils,
  nextpas.core.mem.secure,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.x25519,
  nextpas.core.io.intf,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.dial,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.recordsealer,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify;

const
  { 单次网络读块大小（≥ 最大 TLS 密文记录 16KB+256） }
  cNetReadChunk = 16640;
  { 单条记录载荷上限（5B 头之外） }
  cMaxRecordPayload = 16384 + 256;
  { 单条握手消息上限（证书链可达数十 KB，1MB 已远超合理面） }
  cMaxHandshakeMessage = 1 shl 20;
  { 应用相单记录明文片上限：TLSInnerPlaintext ≤ 16384 含 ct 尾字节 }
  cMaxAppFragment = 16383;
  { 未组帧网络缓冲上限（约 2 条最大记录，超出即协议错） }
  cMaxNetInBuf = 2 * (5 + cMaxRecordPayload);
  { 握手期记录预算（防对端灌包） }
  cMaxFlightRecords = 96;
  { 后握手缓冲上限 }
  cMaxPostHsBuf = 4 * cMaxHandshakeMessage;

type
  TFpHsState = (hsSendCH, hsRecvSH, hsRecvFlight, hsFlushFin);

  PFpHsCtx = ^TFpHsCtx;
  TFpHsCtx = record
    Loop: TAsyncLoop;
    Stream: IAsyncTcpStream;
    Timer: TAsyncTimerHandle;
    ServerName: string;
    OnReady: TAsyncTlsFpConnectCallback;
    OnReadyCtx: Pointer;
    Deadline: TDeadline;
    State: TFpHsState;
    { 客户端 X25519 私钥（收尾清零） }
    Priv: TBytes;
    { ClientHello 握手消息体（transcript 首项） }
    CHBody: TBytes;
    Transcript: TBytes;
    Suite: Word;
    Secrets: TTLS13HandshakeSecrets;
    ServerFinKey: TBytes;
    ClientFinKey: TBytes;
    SrvSeq: QWord;
    CliSeq: QWord;
    { 原始网络字节累积（按记录组帧） }
    NetIn: TBytes;
    { ServerHello 相明文握手流 }
    HsBuf: TBytes;
    { 加密飞行相已解密握手消息流 }
    EncBuf: TBytes;
    AppSecrets: TTLS13ApplicationSecrets;
    { server flight 结构断言：FINISHED 时三者必须全真（v1 无 PSK） }
    SeenEncryptedExtensions: Boolean;
    SeenCert: Boolean;
    SeenCertVerify: Boolean;
    CertRequested: Boolean;
    { 待冲刷密文（客户端飞行） }
    TxBytes: TBytes;
    TxOff: Integer;
    SendArmed: Boolean;
    RecvArmed: Boolean;
    Pumping: Boolean;
    Finished: Boolean;
  end;

  { 数据相 TLS 流：对外完整 IAsyncTcpStream 面；内部以
    TTLS13RecordSealer/Opener 承载应用相加解密。fd 仅经
    NativeSocketHandle 透传作观测用途——绕过本层直读写 fd 会破坏
    TLS 分帧。读挂起与写挂起各一槽，互相独立。 }
  TFpTlsStream = class(TInterfacedObject, IReader, IWriter,
    IReadWriteCloser, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime,
    IAsyncTcpStream)
  private
    FInner: IAsyncTcpStream;
    FLoop: TAsyncLoop;
    FSuite: Word;
    FApp: TTLS13ApplicationSecrets;
    FSealer: TTLS13RecordSealer;
    FOpener: TTLS13RecordOpener;
    FNetIn: TBytes;
    FPlainOut: TBytes;
    FPostHs: TBytes;
    FNetTx: TBytes;
    FNetTxOff: Integer;
    FRecvArmed: Boolean;
    FSendArmed: Boolean;
    FPumping: Boolean;
    FEofIn: Boolean;
    FDead: Boolean;
    FCloseNotifySent: Boolean;
    { 读挂起槽 }
    FReadBuf: Pointer;
    FReadLen: UInt32;
    FReadCb: TIoCompletion;
    FReadCbCtx: Pointer;
    FReadPending: Boolean;
    { 写挂起槽 }
    FWriteTotal: Integer;
    FWriteCb: TIoCompletion;
    FWriteCbCtx: Pointer;
    FWritePending: Boolean;
    { 读挂起是否带期限（决定底层臂挂形态） }
    FHasReadDeadlineReq: Boolean;
    FReadDeadlineReq: TDeadline;
    function ArmNetRecv: Boolean;
    function ArmNetSend: Boolean;
    { 组帧并开启记录进 FPlainOut；>0=新增明文字节数，
      0=需更多网络字节，<0=致命（协议/解密） }
    function OpenAvailableRecords: Integer;
    function HandleOpenedRecord(const APayload: TBytes): Integer;
    procedure FeedPostHandshake(const AFragment: TBytes;
      out AFatal: Boolean);
    procedure DeliverRead(AResult: Int32);
    procedure DeliverWrite(AResult: Int32);
    { 明文按 ≤16KB 片封队到 FNetTx }
    procedure SealPlainToQueue(const APlain: TBytes);
    { 已冲尽时压实发送队列（防长连接无限增长） }
    procedure CompactTxIfDrained;
    procedure Pump;
  public
    constructor Create(ASuite: Word; const AApp: TTLS13ApplicationSecrets;
      const AInner: IAsyncTcpStream; ALoop: TAsyncLoop;
      const ANetInSeed, APostHsSeed: TBytes);
    destructor Destroy; override;
    { IReader }
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    { IWriter }
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    { IReadWriteCloser }
    procedure Close;
    { ITcpStream }
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    { ITcpStreamRuntime }
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    { IAsyncTcpStream }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncWrite(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
  end;

{ ======== 静态回调前向声明 ======== }

procedure FpHsStep(ACtx: Pointer); forward;
procedure FpRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure FpSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure FpTimerCb(AContext: Pointer); forward;
procedure FpDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer); forward;
procedure StreamRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;

{ ======== 通用小件 ======== }

function FpTranscriptHash(ASuite: Word; const AT: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA384(ASuite) then
    Exit(SHA384(AT));
  Result := SHA256(AT);
end;

procedure AppendBytesTo(var ADest: TBytes; const ASrc: TBytes);
var
  LBase: Integer;
begin
  if Length(ASrc) = 0 then
    Exit;
  LBase := Length(ADest);
  SetLength(ADest, LBase + Length(ASrc));
  Move(ASrc[0], ADest[LBase], Length(ASrc));
end;

{ 从 ABuf 组一条完整记录：1=取出（从缓冲移除），0=需要更多字节，
  <0=协议错（类型非法或超限） }
function FpTryFrameRecord(var ABuf: TBytes; out ACt: Byte;
  out APayload: TBytes): Integer;
var
  LHeader: TTLSRecordHeader;
  LHeaderBytes: TBytes;
  LTotal: Integer;
begin
  Result := 0;
  ACt := 0;
  SetLength(APayload, 0);
  if Length(ABuf) < 5 then
    Exit;
  SetLength(LHeaderBytes, 5);
  Move(ABuf[0], LHeaderBytes[0], 5);
  if not ParseTLSRecordHeader(LHeaderBytes, LHeader) then
    Exit(-1);
  case LHeader.ContentType of
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC,
    TLS_CONTENT_TYPE_ALERT,
    TLS_CONTENT_TYPE_HANDSHAKE,
    TLS_CONTENT_TYPE_APPLICATION_DATA: ;
  else
    Exit(-1);
  end;
  if LHeader.Length > cMaxRecordPayload then
    Exit(-1);
  LTotal := 5 + Integer(LHeader.Length);
  if Length(ABuf) < LTotal then
    Exit;
  ACt := LHeader.ContentType;
  SetLength(APayload, Integer(LHeader.Length));
  if LHeader.Length > 0 then
    Move(ABuf[5], APayload[0], LHeader.Length);
  Move(ABuf[LTotal], ABuf[0], Length(ABuf) - LTotal);
  SetLength(ABuf, Length(ABuf) - LTotal);
  Result := 1;
end;

{ 从握手消息流弹出一条完整消息：1=弹出，0=需要更多，<0=超限 }
function FpTryPopHandshake(var ABuf: TBytes; out AMessage: TBytes): Integer;
var
  LLen: Cardinal;
begin
  Result := 0;
  SetLength(AMessage, 0);
  if Length(ABuf) < 4 then
    Exit;
  LLen := ReadUInt24(ABuf, 1);
  if LLen > cMaxHandshakeMessage then
    Exit(-1);
  if Length(ABuf) < 4 + Integer(LLen) then
    Exit;
  SetLength(AMessage, 4 + Integer(LLen));
  Move(ABuf[0], AMessage[0], 4 + Integer(LLen));
  Move(ABuf[4 + Integer(LLen)], ABuf[0],
    Length(ABuf) - (4 + Integer(LLen)));
  SetLength(ABuf, Length(ABuf) - (4 + Integer(LLen)));
  Result := 1;
end;

{ 用客户端握手密钥封一条记录（Certificate/Finished 飞行）。
  失败抛错（仅内存/AEAD 内部错，调用点统一转握手失败）。 }
function FpSealClientHandshakeRecord(ACtx: PFpHsCtx; const ABody: TBytes;
  ACT: Byte): TBytes;
var
  LInner, LNonce, LAAD, LEncrypted: TBytes;
  LError: string;
begin
  LInner := BuildTLS13InnerPlaintext(ABody, ACT);
  LNonce := BuildTLS13RecordNonce(ACtx^.Secrets.ClientHandshakeIV,
    ACtx^.CliSeq);
  LAAD := BuildTLS13RecordAAD(
    Word(Length(LInner) + TLS13AEADTagLength(ACtx^.Suite)));
  if not TryTLS13AEADEncrypt(ACtx^.Suite,
    ACtx^.Secrets.ClientHandshakeKey, LNonce, LAAD, LInner, LEncrypted,
    LError) then
    raise EInvalidOperationError.Create('tlsfp: seal client flight: ' +
      LError);
  if not IncrementTLS13Sequence(ACtx^.CliSeq) then
    raise EInvalidOperationError.Create('tlsfp: client sequence overflow');
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA,
    LEncrypted);
end;

procedure BuildClientFlight(ACtx: PFpHsCtx);
var
  LTranscript: TBytes;
  LHash: TBytes;
  LVerify: TBytes;
  LFinished: TBytes;
  LRecord: TBytes;
begin
  { Finished 输入哈希覆盖 CH..SF }
  LTranscript := Copy(ACtx^.Transcript, 0, Length(ACtx^.Transcript));
  LHash := FpTranscriptHash(ACtx^.Suite, LTranscript);
  LVerify := TLS13ComputeFinishedVerifyDataForCipherSuite(ACtx^.Suite,
    ACtx^.ClientFinKey, LHash);

  SetLength(LFinished, 4 + Length(LVerify));
  LFinished[0] := TLS_HANDSHAKE_TYPE_FINISHED;
  LFinished[1] := Byte((Length(LVerify) shr 16) and $FF);
  LFinished[2] := Byte((Length(LVerify) shr 8) and $FF);
  LFinished[3] := Byte(Length(LVerify) and $FF);
  if Length(LVerify) > 0 then
    Move(LVerify[0], LFinished[4], Length(LVerify));

  SetLength(ACtx^.TxBytes, 0);
  if ACtx^.CertRequested then
  begin
    { 空 Certificate：type||len(4)||ctx_len(0)||list_len(0)，8 字节 }
    LRecord := FpSealClientHandshakeRecord(ACtx,
      TBytes.Create(TLS_HANDSHAKE_TYPE_CERTIFICATE, 0, 0, 4,
        0, 0, 0, 0), TLS_CONTENT_TYPE_HANDSHAKE);
    AppendBytesTo(ACtx^.TxBytes, LRecord);
  end;
  LRecord := FpSealClientHandshakeRecord(ACtx, LFinished,
    TLS_CONTENT_TYPE_HANDSHAKE);
  AppendBytesTo(ACtx^.TxBytes, LRecord);
  ACtx^.TxOff := 0;

  { resumption_master_secret 输入 = Hash(CH..CF)；v1 不恢复会话，
    保留正确派生供后续批次扩展 }
  AppendBytesTo(LTranscript, LFinished);
  ACtx^.AppSecrets.ResumptionTranscriptHash :=
    FpTranscriptHash(ACtx^.Suite, LTranscript);
end;

{ ======== 握手上下文生命周期 ======== }

procedure CancelHsTimer(ACtx: PFpHsCtx);
begin
  if (ACtx <> nil) and (ACtx^.Loop <> nil) and ACtx^.Timer.IsValid then
  begin
    ACtx^.Loop.CancelTimer(ACtx^.Timer);
    ACtx^.Timer := TAsyncTimerHandle.None;
  end;
end;

procedure FreeHsCtx(ACtx: PFpHsCtx);
begin
  if ACtx = nil then
    Exit;
  CancelHsTimer(ACtx);
  ClearTLS13HandshakeSecrets(ACtx^.Secrets);
  ClearTLS13ApplicationSecrets(ACtx^.AppSecrets);
  SecureZeroBytes(ACtx^.Priv);
  SecureZeroBytes(ACtx^.ServerFinKey);
  SecureZeroBytes(ACtx^.ClientFinKey);
  ACtx^.Stream := nil;
  ACtx^.Loop := nil;
  Dispose(ACtx);
end;

{ 同步提交失败路径：静默释放，不回调（契约：False = 未回调） }
procedure FreeHsCtxSilent(ACtx: PFpHsCtx);
begin
  if ACtx <> nil then
    ACtx^.Finished := True;
  FreeHsCtx(ACtx);
end;

procedure FpFail(ACtx: PFpHsCtx; AErr: Int32);
var
  LCb: TAsyncTlsFpConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  FreeHsCtx(ACtx);
  if Assigned(LCb) then
    LCb(nil, AErr, LCbCtx);
end;

procedure FpDone(ACtx: PFpHsCtx);
var
  LStream: TFpTlsStream;
  LCb: TAsyncTlsFpConnectCallback;
  LCbCtx: Pointer;
  LNetInSeed: TBytes;
  LPostHsSeed: TBytes;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  CancelHsTimer(ACtx);
  { 未组帧残余与已解密未消费握手片段移交数据相 }
  LNetInSeed := ACtx^.NetIn;
  LPostHsSeed := ACtx^.EncBuf;
  LStream := TFpTlsStream.Create(ACtx^.Suite, ACtx^.AppSecrets,
    ACtx^.Stream, ACtx^.Loop, LNetInSeed, LPostHsSeed);
  ACtx^.Stream := nil;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  FreeHsCtx(ACtx);
  if Assigned(LCb) then
    LCb(LStream as IAsyncTcpStream, 0, LCbCtx);
end;

{ ======== 接收处理 ======== }

procedure HandleServerHelloMessage(ACtx: PFpHsCtx; const AMsg: TBytes);
var
  LShared: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LError: string;
begin
  if not TryParseServerHelloFromHandshake(AMsg, LInfo) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  { v1 无 TLS1.2 回退：fail-closed }
  if LInfo.SelectedVersion <> $0304 then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  { HelloRetryRequest：v1 不支持 }
  if (Length(LInfo.ServerRandom) = 32) and
     CompareMem(@LInfo.ServerRandom[0], @TLS13_HRR_RANDOM[0], 32) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  { v1 无 PSK：服务器选择 pre_shared_key 即失败 }
  if LInfo.HasPreSharedKey then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  { v1 仅 X25519 key share }
  if (not LInfo.HasKeyShare) or
     (LInfo.KeyShareGroup <> TLS13_GROUP_X25519) or
     (Length(LInfo.PeerKeyShare) <> 32) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  if not TLS13AEADIsSupported(LInfo.SelectedCipherSuite) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  try
    LShared := X25519ComputeSharedSecret(ACtx^.Priv, LInfo.PeerKeyShare);
  except
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  ACtx^.Suite := LInfo.SelectedCipherSuite;
  SetLength(ACtx^.Transcript, 0);
  AppendBytesTo(ACtx^.Transcript, ACtx^.CHBody);
  AppendBytesTo(ACtx^.Transcript, AMsg);
  if not TryDeriveTLS13HandshakeSecrets(ACtx^.Suite, LShared,
    ACtx^.Transcript, ACtx^.Secrets, LError) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  ACtx^.ServerFinKey := TLS13FinishedKeyForCipherSuite(ACtx^.Suite,
    ACtx^.Secrets.ServerHandshakeTrafficSecret);
  ACtx^.ClientFinKey := TLS13FinishedKeyForCipherSuite(ACtx^.Suite,
    ACtx^.Secrets.ClientHandshakeTrafficSecret);
  ACtx^.SrvSeq := 0;
  ACtx^.CliSeq := 0;
  ACtx^.State := hsRecvFlight;
end;

procedure HandleEncryptedFlightRecord(ACtx: PFpHsCtx;
  const APayload: TBytes);
var
  LAAD, LNonce, LPlaintext: TBytes;
  LFrag: TBytes;
  LInnerCt: Byte;
  LMsg: TBytes;
  LMsgType: Byte;
  LMsgLen: Cardinal;
  LVerify: TBytes;
  LHash: TBytes;
  LEEInfo: TTLS13EncryptedExtensionsInfo;
  LCerts: TTLS13CertificateArray;
  LScheme: Word;
  LSig: TBytes;
  LError: string;
begin
  LAAD := BuildTLS13RecordAAD(Word(Length(APayload)));
  LNonce := BuildTLS13RecordNonce(ACtx^.Secrets.ServerHandshakeIV,
    ACtx^.SrvSeq);
  if not IncrementTLS13Sequence(ACtx^.SrvSeq) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  if not TryTLS13AEADDecrypt(ACtx^.Suite,
    ACtx^.Secrets.ServerHandshakeKey, LNonce, LAAD, APayload, LPlaintext,
    LError) then
  begin
    { 解密失败 = 密钥不符或遭篡改：协议层失败，不可降级 }
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  if not TryParseTLS13InnerPlaintext(LPlaintext, LFrag, LInnerCt) then
  begin
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    Exit;
  end;
  case LInnerCt of
    TLS_CONTENT_TYPE_HANDSHAKE:
      begin
        AppendBytesTo(ACtx^.EncBuf, LFrag);
        while FpTryPopHandshake(ACtx^.EncBuf, LMsg) = 1 do
        begin
          LMsgType := LMsg[0];
          if LMsgType = TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS then
          begin
            if not TryParseTLS13EncryptedExtensions(LMsg, LEEInfo,
              LError) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            { v1 不发 early_data：服务器宣称接受即协议错 }
            if LEEInfo.HasEarlyData then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.SeenEncryptedExtensions := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE then
          begin
            if not TryParseTLS13ServerCertificateHandshake(LMsg, LCerts,
              LError) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.SeenCert := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_REQUEST then
          begin
            { v1 无客户端证书材料：fail-closed（见单元头能力边界） }
            FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
            Exit;
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY then
          begin
            { 结构合法性必查（transcript 完整性依赖其长度域可信）；
              签名验证属信任决策，VerifyPeer=False 时跳过 —— 与
              OpenSSL SSL_VERIFY_NONE 语义一致 }
            if not TryParseTLS13CertificateVerifyHandshake(LMsg, LScheme,
              LSig, LError) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.SeenCertVerify := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_FINISHED then
          begin
            { RFC 8446 §4.4.1-4.4.3：v1 无 PSK，server flight 必含
              EE+CERT+CV；缺失即结构不完整 fail-closed（无 CV 绑定
              等于 transcript 未被服务器签名）。乱序/重复消息由
              FINISHED 的 transcript HMAC 自动判负，无需顺序机。 }
            if not (ACtx^.SeenEncryptedExtensions and
                    ACtx^.SeenCert and ACtx^.SeenCertVerify) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            LMsgLen := ReadUInt24(LMsg, 1);
            if LMsgLen <> Cardinal(ACtx^.Secrets.HashSize) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            SetLength(LVerify, Integer(LMsgLen));
            if Integer(LMsgLen) > 0 then
              Move(LMsg[4], LVerify[0], Integer(LMsgLen));
            LHash := FpTranscriptHash(ACtx^.Suite, ACtx^.Transcript);
            if not TLS13VerifyFinishedForCipherSuite(ACtx^.Suite,
              ACtx^.Secrets.ServerHandshakeTrafficSecret, LHash,
              LVerify) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            AppendBytesTo(ACtx^.Transcript, LMsg);

            { 应用密钥派生输入 = Hash(CH..SF)，不含客户端 Finished }
            if not TryDeriveTLS13ApplicationSecrets(ACtx^.Suite,
              ACtx^.Secrets.HandshakeSecret, ACtx^.Transcript,
              ACtx^.AppSecrets, LError) then
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            try
              BuildClientFlight(ACtx);
            except
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.State := hsFlushFin;
            { 返回让泵转去冲刷客户端飞行；NetIn 余量随 FpDone 移交 }
            Exit;
          end
          else
          begin
            { 未知握手消息：fail-closed }
            FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
            Exit;
          end;
        end;
        if Length(ACtx^.EncBuf) > cMaxPostHsBuf then
        begin
          FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
          Exit;
        end;
      end;
    TLS_CONTENT_TYPE_ALERT:
      FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
      ; { middlebox 兼容记录：忽略 }
  else
    FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
  end;
end;

{ 泵尽 NetIn 可组帧记录；False = 已失败/已完成（终止泵） }
function FpPumpRecords(ACtx: PFpHsCtx): Boolean;
var
  LCt: Byte;
  LPayload: TBytes;
  LFrameRes, LPumped: Integer;
  LMsg: TBytes;
begin
  Result := True;
  if ACtx^.Pumping then
    Exit(True);
  ACtx^.Pumping := True;
  try
    LPumped := 0;
    while (ACtx^.State <> hsFlushFin) and not ACtx^.Finished do
    begin
      LFrameRes := FpTryFrameRecord(ACtx^.NetIn, LCt, LPayload);
      if LFrameRes < 0 then
      begin
        FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
        Exit(False);
      end;
      if LFrameRes = 0 then
        Break;
      Inc(LPumped);
      if (LPumped > cMaxFlightRecords) or
         (Length(ACtx^.NetIn) > cMaxNetInBuf) then
      begin
        FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
        Exit(False);
      end;
      if ACtx^.State = hsRecvSH then
      begin
        case LCt of
          TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC: ; { 忽略 }
          TLS_CONTENT_TYPE_ALERT:
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit(False);
            end;
          TLS_CONTENT_TYPE_HANDSHAKE:
            begin
              AppendBytesTo(ACtx^.HsBuf, LPayload);
              while FpTryPopHandshake(ACtx^.HsBuf, LMsg) = 1 do
              begin
                if LMsg[0] <> TLS_HANDSHAKE_TYPE_SERVER_HELLO then
                begin
                  FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
                  Exit(False);
                end;
                HandleServerHelloMessage(ACtx, LMsg);
                if ACtx^.Finished or (ACtx^.State = hsRecvFlight) then
                  Break;
              end;
              if Length(ACtx^.HsBuf) > cMaxHandshakeMessage then
              begin
                FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
                Exit(False);
              end;
            end;
          TLS_CONTENT_TYPE_APPLICATION_DATA:
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit(False);
            end;
        end;
      end
      else if ACtx^.State = hsRecvFlight then
      begin
        case LCt of
          TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC: ; { 忽略 }
          TLS_CONTENT_TYPE_ALERT:
            begin
              FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
              Exit(False);
            end;
          TLS_CONTENT_TYPE_APPLICATION_DATA:
            HandleEncryptedFlightRecord(ACtx, LPayload);
        else
          begin
            { 握手密钥相不允许明文 handshake 记录 }
            FpFail(ACtx, ASYNC_TLSFP_ERR_HANDSHAKE);
            Exit(False);
          end;
        end;
      end;
    end;
  finally
    ACtx^.Pumping := False;
  end;
end;

{ ======== 握手 IO 臂挂 ======== }

procedure FpArmRecv(ACtx: PFpHsCtx);
var
  LRx: PByte;
begin
  if (ACtx = nil) or ACtx^.Finished or ACtx^.RecvArmed then
    Exit;
  SetLength(ACtx^.NetIn, Length(ACtx^.NetIn) + cNetReadChunk);
  LRx := @ACtx^.NetIn[Length(ACtx^.NetIn) - cNetReadChunk];
  ACtx^.RecvArmed := True;
  if ACtx^.Stream.AsyncRead(LRx, cNetReadChunk, @FpRecvCb, ACtx) then
    Exit;
  ACtx^.RecvArmed := False;
  SetLength(ACtx^.NetIn, Length(ACtx^.NetIn) - cNetReadChunk);
  FpFail(ACtx, ASYNC_TLSFP_ERR_IO);
end;

procedure FpArmSend(ACtx: PFpHsCtx);
var
  LLeft: Integer;
begin
  if (ACtx = nil) or ACtx^.Finished or ACtx^.SendArmed then
    Exit;
  LLeft := Length(ACtx^.TxBytes) - ACtx^.TxOff;
  if LLeft <= 0 then
  begin
    if ACtx^.State = hsFlushFin then
      FpDone(ACtx);
    Exit;
  end;
  ACtx^.SendArmed := True;
  if ACtx^.Stream.AsyncWrite(@ACtx^.TxBytes[ACtx^.TxOff], UInt32(LLeft),
    @FpSendCb, ACtx) then
    Exit;
  ACtx^.SendArmed := False;
  FpFail(ACtx, ASYNC_TLSFP_ERR_IO);
end;

{ ======== 握手回调 ======== }

procedure FpRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PFpHsCtx;
begin
  LCtx := PFpHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.RecvArmed := False;
  if AResult <= 0 then
  begin
    { 握手期对端 EOF/传输错误都是失败 }
    if AResult = 0 then
      FpFail(LCtx, ASYNC_TLSFP_ERR_IO)
    else
      FpFail(LCtx, AResult); { 底层域负码透传（取消/超时语义保留） }
    Exit;
  end;
  { 有效字节已在 NetIn 尾部（臂挂时预扩容），收缩到实际长度 }
  SetLength(LCtx^.NetIn,
    Length(LCtx^.NetIn) - cNetReadChunk + AResult);
  if not FpPumpRecords(LCtx) then
    Exit;
  if LCtx^.Finished then
    Exit;
  if LCtx^.State = hsFlushFin then
  begin
    FpArmSend(LCtx);
    Exit;
  end;
  FpArmRecv(LCtx);
end;

procedure FpSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PFpHsCtx;
begin
  LCtx := PFpHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.SendArmed := False;
  if AResult <= 0 then
  begin
    if AResult = 0 then
      FpFail(LCtx, ASYNC_TLSFP_ERR_IO)
    else
      FpFail(LCtx, AResult);
    Exit;
  end;
  Inc(LCtx^.TxOff, AResult);
  if LCtx^.State = hsFlushFin then
  begin
    if LCtx^.TxOff >= Length(LCtx^.TxBytes) then
      FpDone(LCtx)
    else
      FpArmSend(LCtx);
    Exit;
  end;
  { ClientHello 冲完 → 收 ServerHello }
  FpArmRecv(LCtx);
end;

procedure FpTimerCb(AContext: Pointer);
var
  LCtx: PFpHsCtx;
begin
  LCtx := PFpHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.Timer := TAsyncTimerHandle.None;
  FpFail(LCtx, ASYNC_TLSFP_ERR_IO);
end;

procedure FpHsStep(ACtx: Pointer);
var
  LCtx: PFpHsCtx;
  LCHRecord: TBytes;
begin
  LCtx := PFpHsCtx(ACtx);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  if LCtx^.State <> hsSendCH then
    Exit;
  LCHRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE,
    LCtx^.CHBody);
  LCtx^.TxBytes := LCHRecord;
  LCtx^.TxOff := 0;
  LCtx^.State := hsRecvSH;
  FpArmSend(LCtx);
end;

procedure FpDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
var
  LCtx: PFpHsCtx;
begin
  LCtx := PFpHsCtx(AContext);
  if LCtx = nil then
    Exit;
  if AError <> 0 then
  begin
    { 拨号失败原样透传 dial 域负错误码（超时/拒绝等语义保留） }
    FpFail(LCtx, AError);
    Exit;
  end;
  LCtx^.Stream := AStream;
  FpHsStep(LCtx);
end;

{ ======== 工厂入口 ======== }

function DefaultAsyncTlsFpClientOptions: TAsyncTlsFpClientOptions;
begin
  Result.ServerName := '';
  Result.VerifyPeer := False;
  Result.HandshakeDeadline := TDeadline.Infinite;
end;

{ 公共初始化：X25519 keypair + ClientHello（失败静默释放并 re-raise）}
function AllocHsCtx(const ALoop: TAsyncLoop;
  const AServerName: string; const ADeadline: TDeadline;
  AOnReady: TAsyncTlsFpConnectCallback; AOnReadyCtx: Pointer
  ): PFpHsCtx;
var
  LPub: TBytes;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.Loop := ALoop;
  Result^.ServerName := AServerName;
  Result^.OnReady := AOnReady;
  Result^.OnReadyCtx := AOnReadyCtx;
  Result^.Deadline := ADeadline;
  Result^.Timer := TAsyncTimerHandle.None;
  Result^.State := hsSendCH;
  InitTLS13HandshakeSecrets(Result^.Secrets);
  InitTLS13ApplicationSecrets(Result^.AppSecrets);
  try
    GenerateX25519KeyPair(Result^.Priv, LPub);
    Result^.CHBody := BuildTLS13ClientHelloHandshake(AServerName, '',
      LPub);
  except
    FreeHsCtxSilent(Result);
    raise;
  end;
  if Length(Result^.CHBody) = 0 then
  begin
    FreeHsCtxSilent(Result);
    Result := nil;
  end;
end;

function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PFpHsCtx;
begin
  Result := False;
  { fail-closed 声明最先校验：即便其它参数也不合法，也不得静默降级 }
  if AOptions.VerifyPeer then
    raise EInvalidOperationError.Create(
      'tlsfp: peer chain verification is not supported yet ' +
      '(fail-closed); use VerifyPeer=False');
  if (AStream = nil) or not Assigned(ACallback) then
    Exit;

  LCtx := AllocHsCtx(ALoop, AOptions.ServerName,
    AOptions.HandshakeDeadline, ACallback, AContext);
  if LCtx = nil then
    Exit;
  LCtx^.Stream := AStream;
  if not LCtx^.Deadline.IsInfinite then
    LCtx^.Timer := ALoop.Schedule(LCtx^.Deadline.Remaining, @FpTimerCb,
      LCtx);
  FpHsStep(LCtx);
  { 同步失败已在 FpFail 回调；此后结果一律经回调交付 }
  Result := True;
end;

function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsFpClientOptions;
  ACallback: TAsyncTlsFpConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PFpHsCtx;
  LOpts: TAsyncTcpDialOptions;
  LServerName: string;
begin
  Result := False;
  { fail-closed 声明最先校验：即便其它参数也不合法，也不得静默降级 }
  if AOptions.VerifyPeer then
    raise EInvalidOperationError.Create(
      'tlsfp: peer chain verification is not supported yet ' +
      '(fail-closed); use VerifyPeer=False');
  if (AHost = '') or not Assigned(ACallback) then
    Exit;
  if AOptions.ServerName <> '' then
    LServerName := AOptions.ServerName
  else
    LServerName := AHost;

  LCtx := AllocHsCtx(ALoop, LServerName, AOptions.HandshakeDeadline,
    ACallback, AContext);
  if LCtx = nil then
    Exit;
  if not LCtx^.Deadline.IsInfinite then
    LCtx^.Timer := ALoop.Schedule(LCtx^.Deadline.Remaining, @FpTimerCb,
      LCtx);

  LOpts := DefaultAsyncTcpDialOptions;
  LOpts.NoDelay := True;
  LOpts.OverallDeadline := AOptions.HandshakeDeadline;
  if not AsyncTcpDial(ALoop, AHost, APort, LOpts, @FpDialDone, LCtx) then
    FreeHsCtxSilent(LCtx)
  else
    Result := True;
end;

{ ======== TFpTlsStream：数据相 ======== }

constructor TFpTlsStream.Create(ASuite: Word;
  const AApp: TTLS13ApplicationSecrets; const AInner: IAsyncTcpStream;
  ALoop: TAsyncLoop; const ANetInSeed, APostHsSeed: TBytes);
begin
  inherited Create;
  FSuite := ASuite;
  FApp := AApp;
  FInner := AInner;
  FLoop := ALoop;
  FNetIn := ANetInSeed;
  FPostHs := APostHsSeed;
  FOpener.Init(FSuite, FApp.ServerApplicationKey,
    FApp.ServerApplicationIV);
  FSealer.Init(FSuite, FApp.ClientApplicationKey,
    FApp.ClientApplicationIV);
end;

destructor TFpTlsStream.Destroy;
begin
  { quiet-shutdown：不阻塞等对端；密钥即刻清零 }
  FSealer.Clear;
  FOpener.Clear;
  ClearTLS13ApplicationSecrets(FApp);
  FInner := nil;
  FLoop := nil;
  inherited Destroy;
end;

{ ---- 后握手消息 ---- }

procedure TFpTlsStream.FeedPostHandshake(const AFragment: TBytes;
  out AFatal: Boolean);
var
  LMsg: TBytes;
  LMsgType: Byte;
  LErr: string;
begin
  AFatal := False;
  AppendBytesTo(FPostHs, AFragment);
  while FpTryPopHandshake(FPostHs, LMsg) = 1 do
  begin
    LMsgType := LMsg[0];
    if LMsgType = TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET then
      Continue; { v1 不缓存会话票据：忽略 }
    if LMsgType = TLS_HANDSHAKE_TYPE_KEY_UPDATE then
    begin
      if (Length(LMsg) >= 5) and (LMsg[4] = 1) then
      begin
        { update_requested：必须轮换本端写密钥（RFC 8446 §4.6.3） }
        if not TryUpdateTLS13ClientApplicationWriteKeys(FApp, LErr) then
        begin
          AFatal := True;
          Exit;
        end;
        FSealer.Init(FSuite, FApp.ClientApplicationKey,
          FApp.ClientApplicationIV);
      end;
      Continue;
    end;
    { 其余后握手消息类型 fail-closed }
    AFatal := True;
    Exit;
  end;
  if Length(FPostHs) > cMaxPostHsBuf then
    AFatal := True;
end;

function TFpTlsStream.HandleOpenedRecord(const APayload: TBytes): Integer;
var
  LFrag: TBytes;
  LInnerCt: Byte;
  LFatal: Boolean;
  LError: string;
begin
  Result := 0;
  if not FOpener.Open(APayload, LFrag, LInnerCt, LError) then
    Exit(-1);
  case LInnerCt of
    TLS_CONTENT_TYPE_APPLICATION_DATA:
      begin
        AppendBytesTo(FPlainOut, LFrag);
        Result := Length(LFrag);
      end;
    TLS_CONTENT_TYPE_HANDSHAKE:
      begin
        FeedPostHandshake(LFrag, LFatal);
        if LFatal then
          Exit(-1);
      end;
    TLS_CONTENT_TYPE_ALERT:
      begin
        { fatal → 致命；close_notify/warning → 读侧 EOF }
        if (Length(LFrag) >= 2) and (LFrag[0] = 2) then
          Exit(-1);
        FEofIn := True;
      end;
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
      ; { 兼容：忽略 }
  else
    Exit(-1);
  end;
end;

function TFpTlsStream.OpenAvailableRecords: Integer;
var
  LCt: Byte;
  LPayload: TBytes;
  LFrameRes, LRes: Integer;
begin
  Result := 0;
  while not FEofIn and not FDead do
  begin
    if Length(FNetIn) > cMaxNetInBuf then
    begin
      FDead := True;
      Exit(-1);
    end;
    LFrameRes := FpTryFrameRecord(FNetIn, LCt, LPayload);
    if LFrameRes < 0 then
    begin
      FDead := True;
      Exit(-1);
    end;
    if LFrameRes = 0 then
      Exit;
    if LCt = TLS_CONTENT_TYPE_APPLICATION_DATA then
    begin
      LRes := HandleOpenedRecord(LPayload);
      if LRes < 0 then
      begin
        FDead := True;
        Exit(-1);
      end;
      Inc(Result, LRes);
      if Result > 0 then
        Exit; { 攒到一批先交付，避免饿死读方 }
    end
    else if LCt = TLS_CONTENT_TYPE_ALERT then
    begin
      { 应用相的明文 alert 记录 = 对端异常（正常 alert 走加密内嵌） }
      FDead := True;
      Exit(-1);
    end;
    { CCS 记录：忽略 }
  end;
end;

{ ---- 挂起交付与泵 ---- }

procedure TFpTlsStream.DeliverRead(AResult: Int32);
var
  LCB: TIoCompletion;
  LCtx: Pointer;
  LBuf: Pointer;
begin
  LBuf := FReadBuf;
  LCB := FReadCb;
  LCtx := FReadCbCtx;
  FReadPending := False;
  FReadBuf := nil;
  FReadLen := 0;
  FReadCb := nil;
  FReadCbCtx := nil;
  FHasReadDeadlineReq := False;
  if Assigned(LCB) then
    LCB(UInt64(PtrUInt(LBuf)), AResult, LCtx);
end;

procedure TFpTlsStream.DeliverWrite(AResult: Int32);
var
  LCB: TIoCompletion;
  LCtx: Pointer;
begin
  LCB := FWriteCb;
  LCtx := FWriteCbCtx;
  FWritePending := False;
  FWriteTotal := 0;
  FWriteCb := nil;
  FWriteCbCtx := nil;
  if Assigned(LCB) then
    LCB(0, AResult, LCtx);
end;

procedure TFpTlsStream.Pump;
const
  { 单次泵内迭代上限：合法路径每迭代必有进展（明文递减/记录消耗/
    臂挂后返回等待回调）。若未来出现未知病态零进展交错，在此
    毫秒级掐断转干净失败——绝不无限自旋阻塞事件循环（自旋会连
    定时器回调一起饿死，看门狗失效）。合法大数据单次泵封顶
    ~400MB（10 万次 x 4KB 读块），绰绰有余。 }
  cMaxPumpIterations = 100000;
var
  LCopy: SizeUInt;
  LRes: Integer;
  LIters: Integer;
begin
  if FPumping then
    Exit;
  FPumping := True;
  try
    if not FDead then
      ArmNetSend; { 有已封密文就先冲 }

    LIters := 0;
    while True do
    begin
      Inc(LIters);
      if LIters > cMaxPumpIterations then
      begin
        WriteLn(ErrOutput, '[tlsfp] pump iteration cap exceeded: plain=',
          Length(FPlainOut), ' netin=', Length(FNetIn), ' eof=', FEofIn,
          ' readpending=', FReadPending);
        FDead := True;
        if FReadPending then
          DeliverRead(ASYNC_TLSFP_ERR_IO);
        if FWritePending then
          DeliverWrite(ASYNC_TLSFP_ERR_IO);
        Exit;
      end;
      if FDead then
      begin
        if FReadPending then
          DeliverRead(ASYNC_TLSFP_ERR_IO);
        Exit;
      end;
      if Length(FPlainOut) > 0 then
      begin
        if not FReadPending then
        begin
          Exit;
        end;
        LCopy := FReadLen;
        if LCopy > SizeUInt(Length(FPlainOut)) then
          LCopy := SizeUInt(Length(FPlainOut));
        Move(FPlainOut[0], FReadBuf^, LCopy);
        Move(FPlainOut[LCopy], FPlainOut[0],
          Length(FPlainOut) - LCopy);
        SetLength(FPlainOut, Length(FPlainOut) - LCopy);
        WriteLn(ErrOutput, '[t] deliver ', LCopy);
        DeliverRead(Int32(LCopy));
        Continue;
      end;
      if FEofIn then
      begin
        if not FReadPending then
        begin
          Exit;
        end;
        DeliverRead(0);
        Continue;
      end;
      WriteLn(ErrOutput, '[t] gate armed=', FRecvArmed);
      if FRecvArmed then
        Exit; { 臂挂接收未完成：FNetIn 尾部是未初始化暂存区，不可解析；
                新字节只会经回调收缩后进入，届时再泵 }
      LRes := OpenAvailableRecords;
      if LRes < 0 then
      begin
        if FReadPending then
          DeliverRead(ASYNC_TLSFP_ERR_IO);
        Exit;
      end;
      if LRes > 0 then
        Continue;
      if not FRecvArmed then
      begin
        if not ArmNetRecv then
        begin
          if FReadPending then
            DeliverRead(ASYNC_TLSFP_ERR_IO);
          Exit;
        end;
      end;
      Exit;
    end;
  finally
    FPumping := False;
  end;
end;

procedure StreamRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LSelf: TFpTlsStream;
begin
  LSelf := TFpTlsStream(AContext);
  if LSelf = nil then
    Exit;
  LSelf.FRecvArmed := False;
  if AResult < 0 then
  begin
    { 底层负码透传（含取消/超时域语义） }
    LSelf.FDead := True;
    if LSelf.FReadPending then
      LSelf.DeliverRead(AResult);
    if LSelf.FWritePending then
      LSelf.DeliverWrite(ASYNC_TLSFP_ERR_IO);
    Exit;
  end;
  if AResult = 0 then
  begin
    { 对端 TCP EOF：半关闭，读侧置 EOF；存量整记录仍可在 Pump 中消化 }
    LSelf.FEofIn := True;
  end
  else
  begin
    SetLength(LSelf.FNetIn,
      Length(LSelf.FNetIn) - cNetReadChunk + AResult);
  end;
  LSelf.Pump;
end;

procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LSelf: TFpTlsStream;
begin
  LSelf := TFpTlsStream(AContext);
  if LSelf = nil then
    Exit;
  LSelf.FSendArmed := False;
  if AResult <= 0 then
  begin
    LSelf.FDead := True;
    if LSelf.FWritePending then
      LSelf.DeliverWrite(ASYNC_TLSFP_ERR_IO);
    Exit;
  end;
  Inc(LSelf.FNetTxOff, AResult);
  LSelf.CompactTxIfDrained;
  if (LSelf.FNetTxOff >= Length(LSelf.FNetTx)) and
     LSelf.FWritePending then
    LSelf.DeliverWrite(Int32(LSelf.FWriteTotal))
  else
    LSelf.Pump;
end;

function TFpTlsStream.ArmNetRecv: Boolean;
var
  LRx: PByte;
begin
  Result := False;
  if FRecvArmed or FDead then
    Exit;
  SetLength(FNetIn, Length(FNetIn) + cNetReadChunk);
  LRx := @FNetIn[Length(FNetIn) - cNetReadChunk];
  FRecvArmed := True;
  { 读挂起带期限时走底层超时形态（到期由底层交付其域内负码） }
  if FHasReadDeadlineReq then
  begin
    if FInner.AsyncReadTimeout(LRx, cNetReadChunk, FReadDeadlineReq,
      @StreamRecvCb, Self) then
      Exit(True);
  end
  else if FInner.AsyncRead(LRx, cNetReadChunk, @StreamRecvCb, Self) then
    Exit(True);
  FRecvArmed := False;
  SetLength(FNetIn, Length(FNetIn) - cNetReadChunk);
end;

function TFpTlsStream.ArmNetSend: Boolean;
var
  LLeft: Integer;
begin
  Result := False;
  if FSendArmed or FDead then
    Exit;
  LLeft := Length(FNetTx) - FNetTxOff;
  if LLeft <= 0 then
    Exit(True);
  FSendArmed := True;
  if FInner.AsyncWrite(@FNetTx[FNetTxOff], UInt32(LLeft), @StreamSendCb,
    Self) then
    Exit(True);
  FSendArmed := False;
end;

{ ---- 明文封队（写方向） ---- }

procedure TFpTlsStream.SealPlainToQueue(const APlain: TBytes);
var
  LSeg, LRecord: TBytes;
  LOffset, LTake: Integer;
  LErr: string;
begin
  LOffset := 0;
  while LOffset < Length(APlain) do
  begin
    LTake := Length(APlain) - LOffset;
    if LTake > cMaxAppFragment then
      LTake := cMaxAppFragment;
    LSeg := Copy(APlain, LOffset, LTake);
    if not FSealer.Seal(LSeg, TLS_CONTENT_TYPE_APPLICATION_DATA,
      LRecord, LErr) then
      raise EInvalidOperationError.Create('tlsfp: seal app data: ' +
        LErr);
    AppendBytesTo(FNetTx, LRecord);
    Inc(LOffset, LTake);
  end;
end;

procedure TFpTlsStream.CompactTxIfDrained;
begin
  if (FNetTxOff >= Length(FNetTx)) and (Length(FNetTx) > 0) and
     not FWritePending then
  begin
    FNetTx := nil;
    FNetTxOff := 0;
  end;
end;

{ ---- IReader/IWriter（同步便捷面） ---- }

function TFpTlsStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if TryRead(ABuf, ACount, Result) <> tsiorOk then
    Result := 0;
end;

function TFpTlsStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  { 同步面不支持记录化写入（异步栈契约）：请走 AsyncWrite }
  Result := 0;
end;

{ ---- IReadWriteCloser ---- }

procedure TFpTlsStream.Close;
var
  LAlert: TBytes;
  LRecord: TBytes;
  LErr: string;
begin
  if not FCloseNotifySent and not FDead then
  begin
    FCloseNotifySent := True;
    LAlert := TBytes.Create(1, 0); { warning + close_notify }
    if FSealer.Seal(LAlert, TLS_CONTENT_TYPE_ALERT, LRecord, LErr) then
    begin
      AppendBytesTo(FNetTx, LRecord);
      ArmNetSend; { 尽力冲刷；不等对端 }
    end;
  end;
  FDead := True;
  if FInner <> nil then
  begin
    FInner.Close;
    FInner := nil;
  end;
  if FReadPending then
    DeliverRead(ASYNC_TLSFP_ERR_IO);
  if FWritePending then
    DeliverWrite(ASYNC_TLSFP_ERR_IO);
end;

{ ---- ITcpStream 委托底层流 ---- }

function TFpTlsStream.LocalAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.LocalAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TFpTlsStream.RemoteAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.RemoteAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

procedure TFpTlsStream.Shutdown;
begin
  if FInner <> nil then
    FInner.Shutdown;
end;

procedure TFpTlsStream.SetNoDelay(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetNoDelay(AValue);
end;

procedure TFpTlsStream.SetKeepAlive(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetKeepAlive(AValue);
end;

procedure TFpTlsStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  if FInner <> nil then
    FInner.SetReadDeadline(ADeadline);
end;

procedure TFpTlsStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  if FInner <> nil then
    FInner.SetWriteDeadline(ADeadline);
end;

procedure TFpTlsStream.SetCancelToken(const AToken: INetCancelToken);
begin
  if FInner <> nil then
    FInner.SetCancelToken(AToken);
end;

procedure TFpTlsStream.BindCancelToken(
  const AToken: IAsyncCancellationToken);
begin
  if FInner <> nil then
    FInner.BindCancelToken(AToken);
end;

{ ---- ITcpSocketRuntime ---- }

function TFpTlsStream.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
  if FInner <> nil then
    Result := (FInner as ITcpSocketRuntime).NativeSocketHandle;
end;

procedure TFpTlsStream.SetBlocking(const ABlocking: Boolean);
begin
  if FInner <> nil then
    (FInner as ITcpSocketRuntime).SetBlocking(ABlocking);
end;

{ ---- ITcpStreamRuntime ---- }

function TFpTlsStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LN: SizeUInt;
begin
  ARead := 0;
  if FDead then
    Exit(tsiorClosed);
  if Length(FPlainOut) = 0 then
  begin
    if OpenAvailableRecords < 0 then
      Exit(tsiorClosed);
  end;
  if Length(FPlainOut) > 0 then
  begin
    LN := ACount;
    if LN > SizeUInt(Length(FPlainOut)) then
      LN := SizeUInt(Length(FPlainOut));
    Move(FPlainOut[0], ABuf, LN);
    Move(FPlainOut[LN], FPlainOut[0], Length(FPlainOut) - LN);
    SetLength(FPlainOut, Length(FPlainOut) - LN);
    ARead := LN;
    Exit(tsiorOk);
  end;
  if FEofIn then
    Exit(tsiorClosed);
  Exit(tsiorWouldBlock);
end;

function TFpTlsStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LView: TBytes;
begin
  AWritten := 0;
  if FDead then
    Exit(tsiorClosed);
  if ACount = 0 then
    Exit(tsiorOk);
  { 有未冲尽残留时不再追加（避免跨调用字节序歧义）：先冲完再来 }
  if FNetTxOff < Length(FNetTx) then
    Exit(tsiorWouldBlock);
  SetLength(LView, ACount);
  Move(ABuf, LView[0], ACount);
  try
    SealPlainToQueue(LView);
  except
    FDead := True;
    Exit(tsiorClosed);
  end;
  FNetTxOff := 0;
  ArmNetSend;
  if FNetTxOff < Length(FNetTx) then
    Exit(tsiorWouldBlock);
  CompactTxIfDrained;
  AWritten := ACount;
  Exit(tsiorOk);
end;

{ ---- IAsyncTcpStream ---- }

function TFpTlsStream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FReadPending then
    Exit; { 单挂起契约：重复提交是调用方 bug }
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSFP_ERR_IO, AContext);
    Exit(True);
  end;
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  FReadPending := True;
  FHasReadDeadlineReq := False;
  Pump;
  Result := True;
end;

function TFpTlsStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LWrap: Pointer;
begin
  LWrap := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncRead(ABuf, ALen, @IoCompletionRefWrapper, LWrap);
  if not Result then
    Dispose(PIoCompletionRefCtx(LWrap));
end;

function TFpTlsStream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LView: TBytes;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FWritePending then
    Exit; { 单挂起契约 }
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSFP_ERR_IO, AContext);
    Exit(True);
  end;
  { 整段先封队（dataplane 缓冲有界，瞬态 ~1.06× 可接受）；
    冲刷完成后一次回调总长。缓冲所有权：调用方持有至回调，
    本层立即拷贝成记录队列，不引用调用方内存跨重试。
    先压实已冲尽的残留队列：否则下面的 off 重置会指向旧记录，
    重发即对端序列号错乱（实测 sing-box bad record MAC）。 }
  if FNetTxOff < Length(FNetTx) then
  begin
    { 前序写未冲尽（close_notify 残留等）：拒绝重复提交 }
    Exit;
  end;
  FNetTx := nil;
  FNetTxOff := 0;
  SetLength(LView, ALen);
  Move(ABuf^, LView[0], ALen);
  try
    SealPlainToQueue(LView);
  except
    FDead := True;
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSFP_ERR_IO, AContext);
    Exit(True);
  end;
  FWriteTotal := Integer(ALen);
  FWriteCb := ACallback;
  FWriteCbCtx := AContext;
  FWritePending := True;
  Pump;
  Result := True;
end;

function TFpTlsStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LWrap: Pointer;
begin
  LWrap := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, LWrap);
  if not Result then
    Dispose(PIoCompletionRefCtx(LWrap));
end;

function TFpTlsStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FReadPending then
    Exit;
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSFP_ERR_IO, AContext);
    Exit(True);
  end;
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  FReadPending := True;
  { 先吃存量；不足则带期限挂底层读（到期由底层交付其域内负码） }
  FHasReadDeadlineReq := True;
  FReadDeadlineReq := ADeadline;
  Pump;
  if FReadPending and (Length(FPlainOut) = 0) and not FEofIn and
     not FDead and not FRecvArmed then
    DeliverRead(ASYNC_TLSFP_ERR_IO); { 臂挂失败 }
  Result := True;
end;

function TFpTlsStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  { 与 net.async.tls 一致：接受但不在冲刷中途强断（握手期才全强制） }
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

end.
