unit nextpas.core.net.async.tls;
{**
 * Async TLS client stream over TAsyncLoop (epoll/kqueue/IOCP) — memory-BIO
 * pump, zero threads, zero blocking syscalls on the loop thread.
 *
 * CONTRACT (non-blocking TLS over mem BIOs):
 * - OpenSSL never touches the fd. rbio/wbio are memory BIOs with
 *   eof_return=-1: an EMPTY mem BIO must surface as SSL_ERROR_WANT_READ,
 *   never as EOF/SYSCALL (BIO_set_mem_eof_return,
 *   nextpas.core.tls.openssl.api.bio).
 * - Handshake state machine: SSL_do_handshake → WANT_READ → AsyncRecv →
 *   BIO_write(rbio) → retry; wbio ciphertext → BIO_read(wbio) → AsyncSend
 *   (short-write aware) → retry. Fully callback driven. Handshake-phase
 *   socket IO honors Options.HandshakeDeadline (Infinite = no timeout;
 *   a default-initialized deadline is NOT Infinite — set it explicitly).
 * - TLS 1.3 post-handshake: the server may send NewSessionTicket right
 *   after Finished. A data-phase SSL_write can therefore return WANT_READ;
 *   the pump arms a recv and resumes — this is neither error nor EOF.
 * - Data-phase write: SSL_MODE_ENABLE_PARTIAL_WRITE +
 *   SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER are forced on whichever CTX is
 *   used; short writes continue internally until the whole buffer flushes,
 *   then one completion callback fires with the total length. Buffer
 *   ownership follows IAsyncTcpStream rules (caller holds ABuf valid until
 *   the callback; the TLS layer may reference it across retries).
 *   AsyncWriteTimeout accepts but does not enforce a data-phase deadline
 *   mid-flush (handshake deadline is fully enforced).
 * - Data-phase read: SSL_ERROR_ZERO_RETURN (close_notify) or underlying
 *   TCP EOF deliver 0 (EOF); other SSL errors deliver ASYNC_TLS_ERR_IO.
 * - Read-pending and write-pending are independent: a recv completion only
 *   feeds rbio; a pending write survives concurrent reads (NST race).
 * - Fail-closed handshake: failure delivers nil stream + negative code;
 *   nothing half-open escapes to the caller. Plaintext submitted before
 *   the callback fires is a caller bug (no queueing before handshake).
 *
 * Error codes (callback convention): 0 = ok, otherwise negative:
 *   ASYNC_TLS_ERR_IO        underlying stream / submit / pump failure
 *   ASYNC_TLS_ERR_HANDSHAKE TLS protocol failure (alert, cert, internal)
 *
 * Scope: client sessions only (upgrade an existing stream, or dial +
 * upgrade). Server-side async support lands with the TLS listener work.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.async.base, nextpas.core.async.loop,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.tls.openssl.base;

const
  { 底层流读写/提交失败、对端在挂起期间断开 }
  ASYNC_TLS_ERR_IO = -3001;
  { TLS 协议层失败：alert、证书、状态机内部错误 }
  ASYNC_TLS_ERR_HANDSHAKE = -3002;

type
  { 异步 TLS 客户端选项。Ctx=nil 时按 VerifyPeer 惰性建进程级共享默认
    ctx；Ctx<>nil 时以调用方 ctx 的证书校验设置为准（VerifyPeer 字段
    被忽略），单元仍会强制 PARTIAL_WRITE|MOVING_WRITE_BUFFER mode。
    注意：HandshakeDeadline 无缺省值魔法——用 DefaultAsyncTlsClientOptions
    或显式设 TDeadline.Infinite，零初始化记录表示「已过期」。 }
  TAsyncTlsClientOptions = record
    { SNI 主机名；空串 = 不发送（AsyncTlsConnect 回退填 Host） }
    ServerName: string;
    { 仅影响内部共享 ctx：True = 校验链并加载系统信任库；False = 不校验
      （代理节点场景显式关闭）。缺省 True（安全默认）。 }
    VerifyPeer: Boolean;
    { 握手阶段（含底层拨号）绝对期限；Infinite = 不设超时 }
    HandshakeDeadline: TDeadline;
    { 高级：外部共享 SSL_CTX。调用方持有生命周期，须存活到回调之后。 }
    Ctx: PSSL_CTX;
  end;

  { 异步握手完成回调：AError=0 时 AStream 为就绪 TLS 流；失败时
    AStream=nil 且 AError<0。事件循环线程回调，一次。 }
  TAsyncTlsConnectCallback = procedure(AStream: IAsyncTcpStream;
    AError: Int32; AContext: Pointer);

function DefaultAsyncTlsClientOptions: TAsyncTlsClientOptions;

{ 在既有已连接流上做非阻塞 TLS 客户端握手（升级）。
  False = 同步提交失败且不回调；True = 结果经回调交付。
  提交成功后 AStream 所有权移交状态机，调用方不得再使用。 }
function AsyncTlsUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsClientOptions;
  ACallback: TAsyncTlsConnectCallback; AContext: Pointer = nil): Boolean;

{ 拨号 + 升级一步到位（AsyncTcpDial Happy-Eyeballs + TLS 握手共用
  HandshakeDeadline）。SNI 缺省取 AHost。返回语义同 AsyncTlsUpgrade。 }
function AsyncTlsConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsClientOptions;
  ACallback: TAsyncTlsConnectCallback; AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.sync.once, nextpas.core.sync.intf,
  nextpas.core.io.base, nextpas.core.io.intf,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.dial,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.loader;

const
  { TLS record 最大 16KB：网络侧单次收发缓冲 }
  cTlsNetBufSize = 16384;

{ ======== OpenSSL 装载与共享默认 ctx ======== }

procedure EnsureOpenSslModules;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    LoadOpenSSLCore;
  if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
    LoadOpenSSLBIO;
  if not TOpenSSLLoader.IsModuleLoaded(osmSSL) then
    LoadOpenSSLSSL;
end;

procedure BuildClientModes(ACtx: PSSL_CTX; AVerifyPeer: Boolean);
begin
  { 短写续发 + 跨重试移动缓冲是本泵的正确性前提，外部 ctx 同样强制开启 }
  SSL_CTX_ctrl(ACtx, SSL_CTRL_MODE,
    SSL_MODE_ENABLE_PARTIAL_WRITE or SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER, nil);
  if AVerifyPeer then
  begin
    SSL_CTX_set_verify(ACtx, SSL_VERIFY_PEER, nil);
    if SSL_CTX_set_default_verify_paths(ACtx) <> 1 then
    begin
      SSL_CTX_free(ACtx);
      raise EInvalidOperationError.Create(
        'async tls: cannot load default verify paths');
    end;
  end
  else
    SSL_CTX_set_verify(ACtx, SSL_VERIFY_NONE, nil);
end;

function NewClientCtx(AVerifyPeer: Boolean): PSSL_CTX;
var
  LMeth: PSSL_METHOD;
begin
  EnsureOpenSslModules;
  LMeth := TLS_client_method();
  if LMeth = nil then
    raise EInvalidOperationError.Create(
      'async tls: TLS_client_method unavailable');
  Result := SSL_CTX_new(LMeth);
  if Result = nil then
    raise EInvalidOperationError.Create('async tls: SSL_CTX_new failed');
  BuildClientModes(Result, AVerifyPeer);
end;

var
  GDefaultCtxNoVerify: PSSL_CTX = nil;
  GDefaultCtxVerify: PSSL_CTX = nil;
  GOnceNoVerify: IOnce;
  GOnceVerify: IOnce;

procedure BuildNoVerifyCtx;
begin
  GDefaultCtxNoVerify := NewClientCtx(False);
end;

procedure BuildVerifyCtx;
begin
  GDefaultCtxVerify := NewClientCtx(True);
end;

function SharedClientCtx(AVerifyPeer: Boolean): PSSL_CTX;
begin
  if AVerifyPeer then
  begin
    GOnceVerify.Do_(@BuildVerifyCtx);
    Result := GDefaultCtxVerify;
  end
  else
  begin
    GOnceNoVerify.Do_(@BuildNoVerifyCtx);
    Result := GDefaultCtxNoVerify;
  end;
end;

function DefaultAsyncTlsClientOptions: TAsyncTlsClientOptions;
begin
  Result.ServerName := '';
  Result.VerifyPeer := True;
  Result.HandshakeDeadline := TDeadline.Infinite;
  Result.Ctx := nil;
end;

{ ======== 握手上下文与流类型 ======== }

type
  PTlsHsCtx = ^TTlsHsCtx;
  TTlsHsCtx = record
    Loop: TAsyncLoop;
    Ssl: PSSL;
    CtxRef: PSSL_CTX;      { 不拥有：外部或进程共享，见接口注释 }
    Stream: IAsyncTcpStream;
    Fd: PtrInt;
    ServerName: string;
    OnReady: TAsyncTlsConnectCallback;
    OnReadyCtx: Pointer;
    Deadline: TDeadline;
    RxBuf: array[0..cTlsNetBufSize - 1] of Byte;
    TxBuf: TBytes;
    TxOff: Integer;
    TxLen: Integer;
    RecvArmed: Boolean;
    SendArmed: Boolean;
    Finished: Boolean;
  end;

  { TLS 流：memory-BIO 模式。握手完成后由 HandshakeDone 创建，
    对外呈现完整 IAsyncTcpStream 面；fd 仅经 NativeSocketHandle 暴露
    作观测用途——调用方绕过本层直读写 fd 会破坏 TLS 分帧。 }
  TAsyncTlsStream = class(TInterfacedObject, IReader, IWriter,
    IReadWriteCloser, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime,
    IAsyncTcpStream)
  private
    FSsl: PSSL;
    FLoop: TAsyncLoop;
    FStream: IAsyncTcpStream;
    FFd: PtrInt;
    FNetRxBuf: array[0..cTlsNetBufSize - 1] of Byte;
    FNetTxBuf: TBytes;
    FTxOff: Integer;
    FTxLen: Integer;
    FRecvArmed: Boolean;
    FSendArmed: Boolean;
    FPumping: Boolean;
    FReadDeadline: TDeadline;
    FHasReadDeadline: Boolean;
    { 读挂起状态（单挂起：同方向重复提交是调用方 bug） }
    FReadBuf: Pointer;
    FReadLen: UInt32;
    FReadCb: TIoCompletion;
    FReadCbCtx: Pointer;
    { 写挂起状态 }
    FWriteBuf: PByte;
    FWriteLen: Integer;
    FWriteTotal: Integer;
    FWriteCb: TIoCompletion;
    FWriteCbCtx: Pointer;
    function ArmRecv: Boolean;
    function ArmSend: Boolean;
    procedure Pump;
    { 先摘回调再调用：允许完成回调内立即发起下一读/写，
      避免「调用后再置 nil」抹掉嵌套请求 }
    procedure DeliverRead(AResult: Int32);
    procedure DeliverWrite(AResult: Int32);
  public
    constructor Create(ASsl: PSSL; const AStream: IAsyncTcpStream;
      ALoop: TAsyncLoop);
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

procedure HandshakeStep(ACtx: Pointer); forward;
procedure HsRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure HsSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure StreamRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;

{ ======== 握手状态机 ======== }

procedure FreeHsCtx(ACtx: PTlsHsCtx);
begin
  if ACtx = nil then
    Exit;
  if ACtx^.Ssl <> nil then
  begin
    SSL_free(ACtx^.Ssl);
    ACtx^.Ssl := nil;
  end;
  ACtx^.Stream := nil;
  ACtx^.Loop := nil;
  Dispose(ACtx);
end;

{ 同步提交失败路径：静默释放，不回调（契约：False = 未回调） }
procedure FreeHsCtxSilent(ACtx: PTlsHsCtx);
begin
  if ACtx <> nil then
    ACtx^.Finished := True;
  FreeHsCtx(ACtx);
end;

procedure HandshakeFail(ACtx: PTlsHsCtx; AErr: Int32);
var
  LCb: TAsyncTlsConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  if Assigned(LCb) then
    LCb(nil, AErr, LCbCtx);
  FreeHsCtx(ACtx);
end;

procedure HandshakeDone(ACtx: PTlsHsCtx);
var
  LTls: TAsyncTlsStream;
  LCb: TAsyncTlsConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LTls := TAsyncTlsStream.Create(ACtx^.Ssl, ACtx^.Stream, ACtx^.Loop);
  ACtx^.Ssl := nil;
  ACtx^.Stream := nil;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  FreeHsCtx(ACtx);
  if Assigned(LCb) then
    LCb(LTls as IAsyncTcpStream, 0, LCbCtx);
end;

{ 握手期密文冲刷：带 deadline 的短写续发 }

function HsArmSend(ACtx: PTlsHsCtx): Boolean;
var
  LLeft: Integer;
begin
  Result := False;
  if (ACtx = nil) or (ACtx^.Loop = nil) then
    Exit;
  LLeft := ACtx^.TxLen - ACtx^.TxOff;
  if LLeft <= 0 then
    Exit(True);
  ACtx^.SendArmed := True;
  if ACtx^.Deadline.IsInfinite then
    Result := ACtx^.Loop.AsyncSend(ACtx^.Fd, @ACtx^.TxBuf[ACtx^.TxOff],
      UInt32(LLeft), 0, @HsSendCb, ACtx)
  else
    Result := ACtx^.Loop.AsyncSendTimeout(ACtx^.Fd,
      @ACtx^.TxBuf[ACtx^.TxOff], UInt32(LLeft), 0, ACtx^.Deadline,
      @HsSendCb, ACtx);
  if not Result then
    ACtx^.SendArmed := False;
end;

procedure HsSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTlsHsCtx;
begin
  LCtx := PTlsHsCtx(AContext);
  if LCtx = nil then
    Exit;
  if AResult < 0 then
  begin
    LCtx^.SendArmed := False;
    HandshakeFail(LCtx, ASYNC_TLS_ERR_IO);
    Exit;
  end;
  Inc(LCtx^.TxOff, AResult);
  if LCtx^.TxOff < LCtx^.TxLen then
  begin
    if not HsArmSend(LCtx) then
      HandshakeFail(LCtx, ASYNC_TLS_ERR_IO);
    Exit;
  end;
  LCtx^.SendArmed := False;
  HandshakeStep(LCtx);
end;

procedure HsRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTlsHsCtx;
  LN: Integer;
begin
  LCtx := PTlsHsCtx(AContext);
  if LCtx = nil then
    Exit;
  LCtx^.RecvArmed := False;
  if AResult <= 0 then
  begin
    HandshakeFail(LCtx, ASYNC_TLS_ERR_IO);
    Exit;
  end;
  LN := BIO_write(SSL_get_rbio(LCtx^.Ssl), @LCtx^.RxBuf[0], AResult);
  if LN <> AResult then
  begin
    HandshakeFail(LCtx, ASYNC_TLS_ERR_HANDSHAKE);
    Exit;
  end;
  HandshakeStep(LCtx);
end;

procedure HandshakeStep(ACtx: Pointer);
var
  LCtx: PTlsHsCtx;
  LRet: Integer;
  LErr: Integer;
  LPending: Integer;
begin
  LCtx := PTlsHsCtx(ACtx);
  if (LCtx = nil) or (LCtx^.Ssl = nil) or LCtx^.Finished then
    Exit;
  { 密文冲刷挂起期间禁止重入（send 完成回调会再进本过程） }
  if LCtx^.SendArmed then
    Exit;

  LRet := SSL_do_handshake(LCtx^.Ssl);

  LPending := BIO_pending(SSL_get_wbio(LCtx^.Ssl));
  if LPending > 0 then
  begin
    SetLength(LCtx^.TxBuf, LPending);
    BIO_read(SSL_get_wbio(LCtx^.Ssl), @LCtx^.TxBuf[0], LPending);
    LCtx^.TxOff := 0;
    LCtx^.TxLen := LPending;
    if not HsArmSend(LCtx) then
      HandshakeFail(LCtx, ASYNC_TLS_ERR_IO);
    Exit;
  end;

  if LRet = 1 then
  begin
    HandshakeDone(LCtx);
    Exit;
  end;

  LErr := SSL_get_error(LCtx^.Ssl, LRet);
  if (LErr = SSL_ERROR_WANT_READ) or (LErr = SSL_ERROR_WANT_WRITE) then
  begin
    { WANT_WRITE 由下一轮 send 回调驱动；读方向始终要挂上 }
    if LCtx^.RecvArmed then
      Exit;
    LCtx^.RecvArmed := True;
    if LCtx^.Deadline.IsInfinite then
      LRet := Ord(LCtx^.Loop.AsyncRecv(LCtx^.Fd, @LCtx^.RxBuf[0],
        cTlsNetBufSize, 0, @HsRecvCb, LCtx))
    else
      LRet := Ord(LCtx^.Loop.AsyncRecvTimeout(LCtx^.Fd, @LCtx^.RxBuf[0],
        cTlsNetBufSize, 0, LCtx^.Deadline, @HsRecvCb, LCtx));
    if LRet = 0 then
    begin
      LCtx^.RecvArmed := False;
      HandshakeFail(LCtx, ASYNC_TLS_ERR_IO);
    end;
    Exit;
  end;

  HandshakeFail(LCtx, ASYNC_TLS_ERR_HANDSHAKE);
end;

{ 底层流就绪 → 建 SSL 对象（mem BIO，eof_return=-1）→ 启动状态机 }

procedure BeginTlsOnStream(LCtx: PTlsHsCtx; const AStream: IAsyncTcpStream);
var
  LRbio, LWbio: PBIO;
begin
  LCtx^.Stream := AStream;
  LCtx^.Fd := PtrInt((AStream as ITcpSocketRuntime).NativeSocketHandle);

  LCtx^.Ssl := SSL_new(LCtx^.CtxRef);
  if LCtx^.Ssl = nil then
  begin
    HandshakeFail(LCtx, ASYNC_TLS_ERR_HANDSHAKE);
    Exit;
  end;

  LRbio := BIO_new(BIO_s_mem());
  LWbio := BIO_new(BIO_s_mem());
  if (LRbio = nil) or (LWbio = nil) then
  begin
    if LRbio <> nil then
      BIO_free(LRbio);
    if LWbio <> nil then
      BIO_free(LWbio);
    HandshakeFail(LCtx, ASYNC_TLS_ERR_HANDSHAKE);
    Exit;
  end;
  { 空 mem BIO 必须 eof_return=-1，否则 SSL_read/handshake 把空缓冲当
    EOF 而非 WANT_READ（见单元头契约） }
  BIO_set_mem_eof_return(LRbio, -1);
  BIO_set_mem_eof_return(LWbio, -1);
  SSL_set_bio(LCtx^.Ssl, LRbio, LWbio);

  SSL_set_connect_state(LCtx^.Ssl);

  if LCtx^.ServerName <> '' then
    SSL_set_tlsext_host_name(LCtx^.Ssl,
      PAnsiChar(AnsiString(LCtx^.ServerName)));

  HandshakeStep(LCtx);
end;

procedure ConnectDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
var
  LCtx: PTlsHsCtx;
begin
  LCtx := PTlsHsCtx(AContext);
  if LCtx = nil then
    Exit;
  if AError <> 0 then
  begin
    { 拨号失败原样透传 dial 域负错误码（超时/拒绝等语义保留） }
    HandshakeFail(LCtx, AError);
    Exit;
  end;
  BeginTlsOnStream(LCtx, AStream);
end;

{ ======== 工厂入口 ======== }

procedure FillHsCtx(LCtx: PTlsHsCtx; ALoop: TAsyncLoop;
  const AOptions: TAsyncTlsClientOptions; const AServerName: string;
  AOnReady: TAsyncTlsConnectCallback; AOnReadyCtx: Pointer);
begin
  FillChar(LCtx^, SizeOf(LCtx^), 0);
  LCtx^.Loop := ALoop;
  LCtx^.ServerName := AServerName;
  LCtx^.OnReady := AOnReady;
  LCtx^.OnReadyCtx := AOnReadyCtx;
  LCtx^.Deadline := AOptions.HandshakeDeadline;
  if AOptions.Ctx <> nil then
    LCtx^.CtxRef := AOptions.Ctx
  else
    LCtx^.CtxRef := SharedClientCtx(AOptions.VerifyPeer);
end;

function AsyncTlsUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsClientOptions;
  ACallback: TAsyncTlsConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PTlsHsCtx;
begin
  Result := False;
  if (AStream = nil) or not Assigned(ACallback) then
    Exit;
  LCtx := nil;
  try
    New(LCtx);
    FillHsCtx(LCtx, ALoop, AOptions, AOptions.ServerName, ACallback,
      AContext);
  except
    Dispose(LCtx);
    raise;
  end;
  BeginTlsOnStream(LCtx, AStream);
  Result := True;
end;

function AsyncTlsConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsClientOptions;
  ACallback: TAsyncTlsConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PTlsHsCtx;
  LOpts: TAsyncTcpDialOptions;
begin
  Result := False;
  if (AHost = '') or not Assigned(ACallback) then
    Exit;
  LCtx := nil;
  try
    New(LCtx);
    if AOptions.ServerName <> '' then
      FillHsCtx(LCtx, ALoop, AOptions, AOptions.ServerName, ACallback,
        AContext)
    else
      FillHsCtx(LCtx, ALoop, AOptions, AHost, ACallback, AContext);
  except
    Dispose(LCtx);
    raise;
  end;
  LOpts := DefaultAsyncTcpDialOptions;
  LOpts.NoDelay := True;
  LOpts.OverallDeadline := AOptions.HandshakeDeadline;
  if not AsyncTcpDial(ALoop, AHost, APort, LOpts, @ConnectDialDone, LCtx)
  then
    FreeHsCtxSilent(LCtx)
  else
    Result := True;
end;

{ ======== TAsyncTlsStream ======== }

constructor TAsyncTlsStream.Create(ASsl: PSSL; const AStream: IAsyncTcpStream;
  ALoop: TAsyncLoop);
begin
  inherited Create;
  FSsl := ASsl;
  FStream := AStream;
  FLoop := ALoop;
  if AStream <> nil then
    FFd := PtrInt((AStream as ITcpSocketRuntime).NativeSocketHandle)
  else
    FFd := 0;
end;

destructor TAsyncTlsStream.Destroy;
begin
  if FSsl <> nil then
  begin
    { quiet shutdown：不阻塞等对端 close_notify，事件循环内安全 }
    SSL_set_quiet_shutdown(FSsl, 1);
    SSL_shutdown(FSsl);
    SSL_free(FSsl);
    FSsl := nil;
  end;
  FStream := nil;
  FLoop := nil;
  inherited Destroy;
end;

{ ---- ITcpStream 委托底层流 ---- }

function TAsyncTlsStream.LocalAddr: TNetAddress;
begin
  if FStream <> nil then
    Result := FStream.LocalAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TAsyncTlsStream.RemoteAddr: TNetAddress;
begin
  if FStream <> nil then
    Result := FStream.RemoteAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

procedure TAsyncTlsStream.Close;
begin
  if FSsl <> nil then
  begin
    SSL_set_quiet_shutdown(FSsl, 1);
    SSL_shutdown(FSsl);
  end;
  if FStream <> nil then
    FStream.Close;
end;

procedure TAsyncTlsStream.Shutdown;
begin
  if FSsl <> nil then
    SSL_shutdown(FSsl);
  if FStream <> nil then
    FStream.Shutdown;
end;

procedure TAsyncTlsStream.SetNoDelay(const AValue: Boolean);
begin
  if FStream <> nil then
    FStream.SetNoDelay(AValue);
end;

procedure TAsyncTlsStream.SetKeepAlive(const AValue: Boolean);
begin
  if FStream <> nil then
    FStream.SetKeepAlive(AValue);
end;

procedure TAsyncTlsStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FReadDeadline := ADeadline;
  FHasReadDeadline := True;
end;

procedure TAsyncTlsStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  { 数据面写方向 deadline 不强制（见单元头契约）；接受不生效 }
end;

procedure TAsyncTlsStream.SetCancelToken(const AToken: INetCancelToken);
begin
  if FStream <> nil then
    FStream.SetCancelToken(AToken);
end;

procedure TAsyncTlsStream.BindCancelToken(
  const AToken: IAsyncCancellationToken);
begin
  if FStream <> nil then
    FStream.BindCancelToken(AToken);
end;

{ ---- ITcpSocketRuntime / ITcpStreamRuntime（观测面） ---- }

function TAsyncTlsStream.NativeSocketHandle: PtrUInt;
begin
  Result := FFd;
end;

procedure TAsyncTlsStream.SetBlocking(const ABlocking: Boolean);
begin
  { 底层流本就非阻塞；no-op }
end;

function TAsyncTlsStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LN: Integer;
begin
  if (FSsl = nil) or (ACount = 0) then
  begin
    ARead := 0;
    Result := tsiorClosed;
    Exit;
  end;
  LN := SSL_read(FSsl, @ABuf, ACount);
  if LN > 0 then
  begin
    ARead := SizeUInt(LN);
    Result := tsiorOk;
  end
  else
  begin
    ARead := 0;
    Result := tsiorWouldBlock;
  end;
end;

function TAsyncTlsStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LN: Integer;
begin
  if (FSsl = nil) or (ACount = 0) then
  begin
    AWritten := 0;
    Result := tsiorClosed;
    Exit;
  end;
  LN := SSL_write(FSsl, @ABuf, ACount);
  if LN > 0 then
  begin
    AWritten := SizeUInt(LN);
    Result := tsiorOk;
  end
  else
  begin
    AWritten := 0;
    Result := tsiorWouldBlock;
  end;
end;

{ ---- IReader / IWriter 同步便捷面 ---- }

function TAsyncTlsStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRead: SizeUInt;
begin
  if TryRead(ABuf, ACount, LRead) = tsiorOk then
    Result := LRead
  else
    Result := 0;
end;

function TAsyncTlsStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LWritten: SizeUInt;
begin
  if TryWrite(ABuf, ACount, LWritten) = tsiorOk then
    Result := LWritten
  else
    Result := 0;
end;

{ ======== 异步完成投递（先摘再调，允许回调内立即下一跳） ======== }

procedure TAsyncTlsStream.DeliverRead(AResult: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  LCb := FReadCb;
  LCtx := FReadCbCtx;
  FReadCb := nil;
  FReadCbCtx := nil;
  if Assigned(LCb) then
    LCb(0, AResult, LCtx);
end;

procedure TAsyncTlsStream.DeliverWrite(AResult: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  LCb := FWriteCb;
  LCtx := FWriteCbCtx;
  FWriteCb := nil;
  FWriteCbCtx := nil;
  if Assigned(LCb) then
    LCb(0, AResult, LCtx);
end;

{ ======== 数据泵：WANT_READ/WRITE + 短写续发 + TLS1.3 NST 竞态 ======== }

function TAsyncTlsStream.ArmRecv: Boolean;
begin
  if FRecvArmed then
    Exit(True);
  if (FLoop = nil) or (FFd = 0) then
    Exit(False);
  FRecvArmed := True;
  if FHasReadDeadline then
    Result := FLoop.AsyncRecvTimeout(FFd, @FNetRxBuf[0], cTlsNetBufSize,
      0, FReadDeadline, @StreamRecvCb, Self)
  else
    Result := FLoop.AsyncRecv(FFd, @FNetRxBuf[0], cTlsNetBufSize,
      0, @StreamRecvCb, Self);
  if not Result then
    FRecvArmed := False;
end;

function TAsyncTlsStream.ArmSend: Boolean;
var
  LLeft: Integer;
begin
  LLeft := FTxLen - FTxOff;
  if LLeft <= 0 then
    Exit(True);
  if (FLoop = nil) or (FFd = 0) then
    Exit(False);
  FSendArmed := True;
  Result := FLoop.AsyncSend(FFd, @FNetTxBuf[FTxOff], UInt32(LLeft),
    0, @StreamSendCb, Self);
  if not Result then
    FSendArmed := False;
end;

procedure TAsyncTlsStream.Pump;
var
  LN: Integer;
  LErr: Integer;
  LPend: Integer;
begin
  if FPumping then
    Exit;
  FPumping := True;
  try
    while True do
    begin
      if FSendArmed or (FSsl = nil) then
        Exit;

      { wbio 有密文 → 冲网络（短写由 send 回调续发） }
      LPend := BIO_pending(SSL_get_wbio(FSsl));
      if LPend > 0 then
      begin
        SetLength(FNetTxBuf, LPend);
        BIO_read(SSL_get_wbio(FSsl), @FNetTxBuf[0], LPend);
        FTxOff := 0;
        FTxLen := LPend;
        if not ArmSend then
        begin
          if Assigned(FWriteCb) then
            DeliverWrite(ASYNC_TLS_ERR_IO)
          else if Assigned(FReadCb) then
            DeliverRead(ASYNC_TLS_ERR_IO);
        end;
        Exit;
      end;

      { 写方向：SSL_write 短写推进，WANT_READ 挂读后重试（NST 竞态） }
      if Assigned(FWriteCb) and (FWriteLen > 0) then
      begin
        LN := SSL_write(FSsl, FWriteBuf, FWriteLen);
        if LN > 0 then
        begin
          FWriteBuf := FWriteBuf + LN;
          Dec(FWriteLen, LN);
          Continue;
        end;
        LErr := SSL_get_error(FSsl, LN);
        if (LErr = SSL_ERROR_WANT_READ) or (LErr = SSL_ERROR_WANT_WRITE) then
        begin
          if LErr = SSL_ERROR_WANT_READ then
          begin
            if not ArmRecv then
              DeliverWrite(ASYNC_TLS_ERR_IO);
            Exit;
          end;
          Continue;
        end;
        DeliverWrite(ASYNC_TLS_ERR_IO);
        Exit;
      end;

      { 写全量送达 → 一次性完成回调 }
      if Assigned(FWriteCb) and (FWriteLen = 0) then
      begin
        DeliverWrite(FWriteTotal);
        Continue;
      end;

      { 读方向：ZERO_RETURN=EOF，WANT_READ/WRITE 挂 fd 后重试 }
      if Assigned(FReadCb) then
      begin
        LN := SSL_read(FSsl, FReadBuf, FReadLen);
        if LN > 0 then
        begin
          DeliverRead(LN);
          Continue;
        end;
        LErr := SSL_get_error(FSsl, LN);
        if LErr = SSL_ERROR_ZERO_RETURN then
        begin
          DeliverRead(0);
          Exit;
        end;
        if (LErr = SSL_ERROR_WANT_READ) or (LErr = SSL_ERROR_WANT_WRITE) then
        begin
          if LErr = SSL_ERROR_WANT_READ then
          begin
            if not ArmRecv then
              DeliverRead(ASYNC_TLS_ERR_IO);
            Exit;
          end;
          Continue;
        end;
        DeliverRead(ASYNC_TLS_ERR_IO);
        Exit;
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
  LS: TAsyncTlsStream;
  LN: Integer;
begin
  LS := TAsyncTlsStream(AContext);
  if LS = nil then
    Exit;
  LS.FRecvArmed := False;
  { 对端断开：读挂起交付 EOF/错误；写挂起期间对端断开按 IO 错误收敛 }
  if AResult <= 0 then
  begin
    if Assigned(LS.FReadCb) then
    begin
      if AResult = 0 then
        LS.DeliverRead(0)
      else
        LS.DeliverRead(AResult);
    end
    else if Assigned(LS.FWriteCb) then
      LS.DeliverWrite(ASYNC_TLS_ERR_IO);
    Exit;
  end;
  LN := BIO_write(SSL_get_rbio(LS.FSsl), @LS.FNetRxBuf[0], AResult);
  if LN <> AResult then
  begin
    if Assigned(LS.FReadCb) then
      LS.DeliverRead(ASYNC_TLS_ERR_IO)
    else if Assigned(LS.FWriteCb) then
      LS.DeliverWrite(ASYNC_TLS_ERR_IO);
    Exit;
  end;
  LS.Pump;
end;

procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LS: TAsyncTlsStream;
begin
  LS := TAsyncTlsStream(AContext);
  if LS = nil then
    Exit;
  if AResult < 0 then
  begin
    LS.FSendArmed := False;
    if Assigned(LS.FWriteCb) then
      LS.DeliverWrite(AResult)
    else if Assigned(LS.FReadCb) then
      LS.DeliverRead(AResult);
    Exit;
  end;
  Inc(LS.FTxOff, AResult);
  if LS.FTxOff < LS.FTxLen then
  begin
    if not LS.ArmSend then
    begin
      LS.FSendArmed := False;
      if Assigned(LS.FWriteCb) then
        LS.DeliverWrite(ASYNC_TLS_ERR_IO)
      else if Assigned(LS.FReadCb) then
        LS.DeliverRead(ASYNC_TLS_ERR_IO);
    end;
    Exit;
  end;
  LS.FSendArmed := False;
  LS.Pump;
end;

{ ---- IAsyncTcpStream ---- }

function TAsyncTlsStream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  Pump;
  Result := True;
end;

function TAsyncTlsStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncRead(ABuf, ALen, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncTlsStream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  FWriteBuf := ABuf;
  FWriteLen := ALen;
  FWriteTotal := ALen;
  FWriteCb := ACallback;
  FWriteCbCtx := AContext;
  Pump;
  Result := True;
end;

function TAsyncTlsStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncTlsStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  FReadDeadline := ADeadline;
  FHasReadDeadline := True;
  Result := AsyncRead(ABuf, ALen, ACallback, AContext);
end;

function TAsyncTlsStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  { deadline 接受不强制（见单元头契约） }
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

initialization
  GOnceNoVerify := CreateOnce;
  GOnceVerify := CreateOnce;

finalization
  if GDefaultCtxNoVerify <> nil then
  begin
    SSL_CTX_free(GDefaultCtxNoVerify);
    GDefaultCtxNoVerify := nil;
  end;
  if GDefaultCtxVerify <> nil then
  begin
    SSL_CTX_free(GDefaultCtxVerify);
    GDefaultCtxVerify := nil;
  end;

end.
