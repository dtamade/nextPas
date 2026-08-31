program test_net_async_tls;

{** @desc nextpas.core.net.async.tls 集成测试（C-11 反哺）：

  1. openssl-modules      OpenSSL 装载与符号面
  2. bio-handshake-sm     memory-BIO 状态机纯逻辑：首拍 WANT_READ +
                          ClientHello 进 wbio
  3. echo-small           环回 TLS 1.3：握手回调内立即写（NST 竞态），
                          小载荷回显
  4. echo-large           100KB 多记录回显（短写续发双向）
  5. eof-after-close      服务端关连接后客户端读交付 EOF(0)
  6. handshake-deadline   裸 TCP 只 accept 不应答 → 握手 deadline 触发，
                          回调 nil + 负错误码

  服务端为进程内 TLS echo（同一事件循环，TryAccept 轮询 + mem-BIO 泵），
  自签证书经 TCertificateBuilder 生成于临时目录。 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.io.intf,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.async.tcp,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.loader,
  nextpas.core.net.async.tls;

const
  cBufSize = 16384;
  cLargeLen = 100000;
  cSmallMark = 'PING-TLS13';

type
  TCaseMode = (cmSmall, cmLarge, cmEof);

var
  GLoop: TAsyncLoop;
  GListener: IAsyncTcpListener;
  GPort: UInt16;
  GMode: TCaseMode;

  { 客户端状态 }
  GCliStream: IAsyncTcpStream;
  GCliErr: Int32;
  GCliReady: Boolean;
  GTxBuf: TBytes;
  GRxGot: Integer;
  GRxTotal: Integer;
  GRxEof: Boolean;
  GRxBad: Boolean;
  GFinished: Boolean;
  GRxDummy: array[0..63] of Byte;

  { 服务端状态 }
  GSrvCtx: PSSL_CTX;
  GSrvSsl: PSSL;
  GSrvStream: IAsyncTcpStream;
  GSrvFd: PtrInt;
  GSrvRxBuf: array[0..cBufSize - 1] of Byte;
  GPendingPlain: TBytes;
  GPlainOff: Integer;
  GWireBuf: TBytes;
  GWireOff: Integer;
  GWireLen: Integer;
  GSrvHandshaken: Boolean;
  GSrvRecvArmed: Boolean;
  GSrvSendArmed: Boolean;
  GSrvPumping: Boolean;
  GSrvPeerClosed: Boolean;
  GSrvClosed: Boolean;
  GSrvCloseAfterEcho: Boolean;

  { 证书 }
  GCertReady: Boolean;
  GCertFile: string;
  GKeyFile: string;

function ExpectedByte(AIndex: Integer): Byte;
begin
  { 小载荷（small/eof）比对 marker 字面量；大载荷比对确定性数字模式 }
  if GMode = cmLarge then
    Result := Byte((AIndex * 7 + 13) mod 251)
  else
    Result := Ord(cSmallMark[AIndex + 1]);
end;

{ 服务端延迟关连接：回显完立刻关会与客户端写完成回调赛跑（RST） }
procedure SrvCloseConn; forward;

procedure DelayedCloseTick(AContext: Pointer);
begin
  SrvCloseConn;
end;

{ ======== 收尾与工具 ======== }

procedure StopCb(AContext: Pointer);
begin
  if GLoop <> nil then
    GLoop.Stop;
end;

procedure FinishCase;
begin
  if GFinished then
    Exit;
  GFinished := True;
  GLoop.Schedule(TDuration.FromMilliseconds(1), @StopCb, nil);
end;

procedure ResetGlobals;
begin
  GListener := nil;
  GCliStream := nil;
  GSrvStream := nil;
  GCliErr := 0;
  GCliReady := False;
  GRxGot := 0;
  GRxTotal := 0;
  GRxEof := False;
  GRxBad := False;
  GFinished := False;
  if GSrvSsl <> nil then
  begin
    SSL_set_quiet_shutdown(GSrvSsl, 1);
    SSL_shutdown(GSrvSsl);
    SSL_free(GSrvSsl);
    GSrvSsl := nil;
  end;
  GSrvFd := 0;
  GPendingPlain := nil;
  GPlainOff := 0;
  GWireBuf := nil;
  GWireOff := 0;
  GWireLen := 0;
  GSrvHandshaken := False;
  GSrvRecvArmed := False;
  GSrvSendArmed := False;
  GSrvPumping := False;
  GSrvPeerClosed := False;
  GSrvClosed := False;
  GSrvCloseAfterEcho := False;
end;

procedure EnsureCert;
var
  LPair: IKeyPairWithCertificate;
begin
  if GCertReady then
    Exit;
  GCertFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'pp_core_tls_test_cert.pem';
  GKeyFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'pp_core_tls_test_key.pem';
  LPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithECDSAKey('prime256v1')
    .ValidFor(1)
    .SelfSigned;
  LPair.SaveToFiles(GCertFile, GKeyFile);
  GCertReady := True;
end;

procedure EnsureOpenSsl;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    LoadOpenSSLCore;
  if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
    LoadOpenSSLBIO;
  if not TOpenSSLLoader.IsModuleLoaded(osmSSL) then
    LoadOpenSSLSSL;
end;

procedure EnsureServerCtx;
var
  LMeth: PSSL_METHOD;
begin
  if GSrvCtx <> nil then
    Exit;
  EnsureCert;
  EnsureOpenSsl;
  LMeth := TLS_server_method();
  GSrvCtx := SSL_CTX_new(LMeth);
  SSL_CTX_ctrl(GSrvCtx, SSL_CTRL_MODE,
    SSL_MODE_ENABLE_PARTIAL_WRITE or SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER, nil);
  SSL_CTX_set_verify(GSrvCtx, SSL_VERIFY_NONE, nil);
  CheckEqual(Int64(1), Int64(SSL_CTX_use_certificate_chain_file(GSrvCtx,
    PAnsiChar(AnsiString(GCertFile)))), 'server load cert');
  CheckEqual(Int64(1), Int64(SSL_CTX_use_PrivateKey_file(GSrvCtx,
    PAnsiChar(AnsiString(GKeyFile)), SSL_FILETYPE_PEM)), 'server load key');
  CheckEqual(Int64(1), Int64(SSL_CTX_check_private_key(GSrvCtx)),
    'server key matches cert');
end;

{ ======== 服务端泵（单连接 echo） ======== }

procedure ServerPump; forward;
procedure ServerRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure ServerSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;

function SrvArmRecv: Boolean;
begin
  if GSrvRecvArmed then
    Exit(True);
  GSrvRecvArmed := True;
  Result := GLoop.AsyncRecv(GSrvFd, @GSrvRxBuf[0], cBufSize, 0,
    @ServerRecvCb, nil);
  if not Result then
    GSrvRecvArmed := False;
end;

function SrvArmSend: Boolean;
var
  LLeft: Integer;
begin
  LLeft := GWireLen - GWireOff;
  if LLeft <= 0 then
    Exit(True);
  if GSrvSendArmed then
    Exit(True);
  GSrvSendArmed := True;
  Result := GLoop.AsyncSend(GSrvFd, @GWireBuf[GWireOff], UInt32(LLeft),
    0, @ServerSendCb, nil);
  if not Result then
    GSrvSendArmed := False;
end;

procedure SrvCloseConn;
begin
  if GSrvClosed then
    Exit;
  GSrvClosed := True;
  if GSrvSsl <> nil then
  begin
    SSL_set_quiet_shutdown(GSrvSsl, 1);
    SSL_shutdown(GSrvSsl);
    SSL_free(GSrvSsl);
    GSrvSsl := nil;
  end;
  if GSrvStream <> nil then
    GSrvStream.Close;
end;

procedure ServerSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
begin
  if AResult < 0 then
  begin
    GSrvSendArmed := False;
    SrvCloseConn;
    Exit;
  end;
  Inc(GWireOff, AResult);
  if GWireOff >= GWireLen then
  begin
    GWireOff := 0;
    GWireLen := 0;
    GSrvSendArmed := False;
  end;
  ServerPump;
end;

procedure ServerRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LN: Integer;
begin
  GSrvRecvArmed := False;
  if AResult <= 0 then
  begin
    { 对端断开：等队列冲完再关 }
    GSrvPeerClosed := True;
    ServerPump;
    Exit;
  end;
  LN := BIO_write(SSL_get_rbio(GSrvSsl), @GSrvRxBuf[0], AResult);
  if LN <> AResult then
  begin
    SrvCloseConn;
    Exit;
  end;
  ServerPump;
end;

procedure ServerPump;
var
  LN: Integer;
  LErr: Integer;
  LPend: Integer;
begin
  if GSrvPumping or GSrvClosed then
    Exit;
  GSrvPumping := True;
  try
    while True do
    begin
      if GSrvSendArmed then
        Exit;

      { wbio 有密文必须先冲网络——SSL_accept/write 留下输出又返回
        WANT_READ 时，不冲就是双端互等死锁 }
      LPend := BIO_pending(SSL_get_wbio(GSrvSsl));
      if LPend > 0 then
      begin
        SetLength(GWireBuf, LPend);
        BIO_read(SSL_get_wbio(GSrvSsl), @GWireBuf[0], LPend);
        GWireOff := 0;
        GWireLen := LPend;
        if not SrvArmSend then
          SrvCloseConn;
        Exit;
      end;

      { 全部送达且对端已关闭 → 关连接；EOF 用例改为回显完主动关，
        让客户端读到 EOF }
      if GSrvPeerClosed and (GPlainOff >= Length(GPendingPlain)) then
      begin
        SrvCloseConn;
        Exit;
      end;
      if GSrvCloseAfterEcho and GSrvHandshaken and (GPlainOff > 0) and
        (GPlainOff >= Length(GPendingPlain)) then
      begin
        GSrvCloseAfterEcho := False;
        GLoop.Schedule(TDuration.FromMilliseconds(30), @DelayedCloseTick,
          nil);
        Exit;
      end;

      if not GSrvHandshaken then
      begin
        LN := SSL_accept(GSrvSsl);
        LPend := BIO_pending(SSL_get_wbio(GSrvSsl));
        if LPend > 0 then
        begin
          SetLength(GWireBuf, LPend);
          BIO_read(SSL_get_wbio(GSrvSsl), @GWireBuf[0], LPend);
          GWireOff := 0;
          GWireLen := LPend;
          if not SrvArmSend then
            SrvCloseConn;
          Exit;
        end;
        if LN = 1 then
        begin
          GSrvHandshaken := True;
          Continue;
        end;
        LErr := SSL_get_error(GSrvSsl, LN);
        if (LErr = SSL_ERROR_WANT_READ) or (LErr = SSL_ERROR_WANT_WRITE) then
        begin
          if not SrvArmRecv then
            SrvCloseConn;
          Exit;
        end;
        SrvCloseConn;
        Exit;
      end;

      { 回显积压 → 密文 }
      if GPlainOff < Length(GPendingPlain) then
      begin
        LN := SSL_write(GSrvSsl, @GPendingPlain[GPlainOff],
          Length(GPendingPlain) - GPlainOff);
        if LN > 0 then
        begin
          Inc(GPlainOff, LN);
          Continue;
        end;
        LErr := SSL_get_error(GSrvSsl, LN);
        if LErr = SSL_ERROR_WANT_READ then
        begin
          if not SrvArmRecv then
            SrvCloseConn;
          Exit;
        end;
        if LErr = SSL_ERROR_WANT_WRITE then
          Continue;
        SrvCloseConn;
        Exit;
      end;

      { 收明文入回显积压 }
      LN := SSL_read(GSrvSsl, @GSrvRxBuf[0], cBufSize);
      if LN > 0 then
      begin
        SetLength(GPendingPlain, Length(GPendingPlain) + LN);
        Move(GSrvRxBuf[0], GPendingPlain[Length(GPendingPlain) - LN], LN);
        Continue;
      end;
      LErr := SSL_get_error(GSrvSsl, LN);
      if LErr = SSL_ERROR_ZERO_RETURN then
      begin
        GSrvPeerClosed := True;
        Continue;
      end;
      if (LErr = SSL_ERROR_WANT_READ) or (LErr = SSL_ERROR_WANT_WRITE) then
      begin
        if not SrvArmRecv then
          SrvCloseConn;
        Exit;
      end;
      SrvCloseConn;
      Exit;
    end;
  finally
    GSrvPumping := False;
  end;
end;

procedure PollAcceptTick(AContext: Pointer);
var
  LConn: ITcpStream;
  LRbio, LWbio: PBIO;
begin
  if (GLoop = nil) or GFinished or (GSrvStream <> nil) then
    Exit;
  if (GListener as ITcpListenerRuntime).TryAccept(LConn) = tarAccepted then
  begin
    GSrvStream := AsyncTcpStreamAdopt(GLoop, LConn);
    GSrvFd := PtrInt((GSrvStream as ITcpSocketRuntime).NativeSocketHandle);
    EnsureServerCtx;
    GSrvSsl := SSL_new(GSrvCtx);
    LRbio := BIO_new(BIO_s_mem());
    LWbio := BIO_new(BIO_s_mem());
    BIO_set_mem_eof_return(LRbio, -1);
    BIO_set_mem_eof_return(LWbio, -1);
    SSL_set_bio(GSrvSsl, LRbio, LWbio);
    SSL_set_accept_state(GSrvSsl);
    SrvArmRecv;
  end
  else
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);
end;

{ ======== 客户端回调 ======== }

procedure CliReadCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;

{ EOF 等待读：只认 0；额外资据继续等 }
procedure CliEofCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult = 0 then
    GRxEof := True
  else if (AResult > 0) and GCliStream.AsyncRead(@GRxDummy[0],
    UInt32(SizeOf(GRxDummy)), @CliEofCb, nil) then
    Exit;
  if not GRxEof then
    GRxBad := True;
  FinishCase;
end;

procedure CliWriteCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult < 0 then
  begin
    GRxBad := True;
    FinishCase;
    Exit;
  end;
  if not GCliStream.AsyncRead(@GTxBuf[GRxGot], UInt32(GRxTotal - GRxGot),
    @CliReadCb, nil) then
  begin
    GRxBad := True;
    FinishCase;
  end;
end;

procedure CliReadCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  I: Integer;
begin
  if AResult = 0 then
  begin
    GRxEof := True;
    FinishCase;
    Exit;
  end;
  if AResult < 0 then
  begin
    GRxBad := True;
    FinishCase;
    Exit;
  end;
  for I := 0 to AResult - 1 do
    if GTxBuf[GRxGot + I] <> ExpectedByte(GRxGot + I) then
    begin
      GRxBad := True;
      Break;
    end;
  GRxGot := GRxGot + AResult;
  if GRxBad then
  begin
    FinishCase;
    Exit;
  end;
  if GRxGot >= GRxTotal then
  begin
    { EOF 用例：数据收满后再读一拍，等服务端关闭交付的 EOF(0) }
    if (GMode = cmEof) and not GRxEof then
    begin
      if not GCliStream.AsyncRead(@GRxDummy[0], UInt32(SizeOf(GRxDummy)),
        @CliEofCb, nil) then
      begin
        GRxBad := True;
        FinishCase;
      end;
      Exit;
    end;
    FinishCase;
    Exit;
  end
  else if not GCliStream.AsyncRead(@GTxBuf[GRxGot],
    UInt32(GRxTotal - GRxGot), @CliReadCb, nil) then
  begin
    GRxBad := True;
    FinishCase;
  end;
end;

procedure CliReadyCb(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
begin
  if (AError <> 0) or (AStream = nil) then
  begin
    GCliErr := AError;
    FinishCase;
    Exit;
  end;
  GCliReady := True;
  GCliStream := AStream;
  { 握手回调内立即写：打 TLS1.3 NewSessionTicket 竞态 }
  if not GCliStream.AsyncWrite(@GTxBuf[0], UInt32(GRxTotal), @CliWriteCb,
    nil) then
  begin
    GRxBad := True;
    FinishCase;
  end;
end;

{ ======== 用例 ======== }

procedure RunEchoCase(AMode: TCaseMode);
var
  LOpts: TAsyncTlsClientOptions;
  I: Integer;
begin
  ResetGlobals;
  GMode := AMode;
  GSrvCloseAfterEcho := (AMode = cmEof);
  EnsureCert;
  EnsureServerCtx;
  if AMode = cmLarge then
  begin
    GRxTotal := cLargeLen;
    SetLength(GTxBuf, GRxTotal);
    for I := 0 to GRxTotal - 1 do
      GTxBuf[I] := ExpectedByte(I);
  end
  else
  begin
    GRxTotal := Length(cSmallMark);
    SetLength(GTxBuf, GRxTotal);
    for I := 0 to GRxTotal - 1 do
      GTxBuf[I] := Ord(cSmallMark[I + 1]);
  end;

  GLoop := TAsyncLoop.Create;
  try
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    { 轮询 TryAccept 的前提：listen 套接字非阻塞，否则空拍会把循环冻死 }
    (GListener as ITcpSocketRuntime).SetBlocking(False);
    GPort := GListener.LocalAddr.Port;
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);

    LOpts := DefaultAsyncTlsClientOptions;
    LOpts.VerifyPeer := False;
    LOpts.ServerName := 'localhost';
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    Check(AsyncTlsConnect(GLoop, '127.0.0.1', GPort, LOpts, @CliReadyCb,
      nil), 'connect submit');

    GLoop.Run;

    Check(GCliReady, 'client handshake done');
    Check(not GRxBad, 'no io error');
    CheckEqual(Int64(GRxTotal), Int64(GRxGot), 'all bytes echoed');
    if AMode = cmEof then
      Check(GRxEof, 'eof delivered after server close');
  finally
    ResetGlobals;
    GLoop.Free;
    GLoop := nil;
  end;
end;

procedure TestOpensslModules;
begin
  EnsureOpenSsl;
  Check(TOpenSSLLoader.IsModuleLoaded(osmCore) and
    TOpenSSLLoader.IsModuleLoaded(osmBIO) and
    TOpenSSLLoader.IsModuleLoaded(osmSSL), 'openssl modules loaded');
  Check(Assigned(TLS_client_method) and Assigned(TLS_server_method) and
    Assigned(SSL_do_handshake) and
    Assigned(SSL_CTX_use_certificate_chain_file),
    'openssl symbols present');
end;

procedure TestBioHandshakeStateMachine;
var
  LMeth: PSSL_METHOD;
  LCtx: PSSL_CTX;
  LSsl: PSSL;
  LRbio, LWbio: PBIO;
  LRet, LErr, LPending: Integer;
begin
  EnsureOpenSsl;
  LMeth := TLS_client_method();
  LCtx := SSL_CTX_new(LMeth);
  LSsl := SSL_new(LCtx);
  LRbio := BIO_new(BIO_s_mem());
  LWbio := BIO_new(BIO_s_mem());
  { 空 mem BIO 缺省读成 EOF；非阻塞契约必须 eof_return=-1 }
  BIO_set_mem_eof_return(LRbio, -1);
  BIO_set_mem_eof_return(LWbio, -1);
  SSL_set_bio(LSsl, LRbio, LWbio);
  SSL_set_connect_state(LSsl);

  LRet := SSL_do_handshake(LSsl);
  CheckEqual(Int64(-1), Int64(LRet), 'first step returns -1');
  LErr := SSL_get_error(LSsl, LRet);
  CheckEqual(Int64(SSL_ERROR_WANT_READ), Int64(LErr), 'want read');
  LPending := BIO_pending(LWbio);
  Check((LPending > 50) and (LPending <= 4096), 'client hello pending');

  SSL_free(LSsl);
  SSL_CTX_free(LCtx);
end;

procedure TestEchoSmall;
begin
  RunEchoCase(cmSmall);
end;

procedure TestEchoLarge;
begin
  RunEchoCase(cmLarge);
end;

procedure TestEofAfterClose;
begin
  RunEchoCase(cmEof);
end;

{ ======== 握手超时用例：裸 TCP 只 accept 不应答 ======== }

procedure PollAcceptTickStall(AContext: Pointer);
var
  LConn: ITcpStream;
begin
  if (GLoop = nil) or GFinished or (GSrvStream <> nil) then
    Exit;
  if (GListener as ITcpListenerRuntime).TryAccept(LConn) = tarAccepted then
    GSrvStream := AsyncTcpStreamAdopt(GLoop, LConn) { 持有但永不说话 }
  else
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTickStall,
      nil);
end;

procedure CliDeadlineCb(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
begin
  GCliReady := (AError = 0) and (AStream <> nil);
  GCliErr := AError;
  FinishCase;
end;

procedure TestHandshakeDeadline;
var
  LOpts: TAsyncTlsClientOptions;
begin
  ResetGlobals;
  GRxTotal := 0;
  GLoop := TAsyncLoop.Create;
  try
    { 裸 TCP：accept 后不应答任何字节 → 客户端握手只能等超时 }
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    (GListener as ITcpSocketRuntime).SetBlocking(False);
    GPort := GListener.LocalAddr.Port;
    GLoop.Schedule(TDuration.FromSeconds(15), @StopCb, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTickStall, nil);

    LOpts := DefaultAsyncTlsClientOptions;
    LOpts.VerifyPeer := False;
    LOpts.HandshakeDeadline := TDeadline.After(
      TDuration.FromMilliseconds(600));
    Check(AsyncTlsConnect(GLoop, '127.0.0.1', GPort, LOpts,
      @CliDeadlineCb, nil), 'connect submit');

    GLoop.Run;

    Check(not GCliReady, 'handshake did not complete');
    Check(GCliErr < 0, Format('deadline error delivered (err=%d)',
      [GCliErr]));
  finally
    ResetGlobals;
    GLoop.Free;
    GLoop := nil;
  end;
end;

var
  GSuite: TTestSuite;

begin
  GSuite := TTestSuite.Create('net_async_tls');
  GSuite.Test('OpensslModules', @TestOpensslModules);
  GSuite.Test('BioHandshakeStateMachine', @TestBioHandshakeStateMachine);
  GSuite.Test('EchoSmall', @TestEchoSmall);
  GSuite.Test('EchoLarge', @TestEchoLarge);
  GSuite.Test('EofAfterClose', @TestEofAfterClose);
  GSuite.Test('HandshakeDeadline', @TestHandshakeDeadline);
  GSuite.Run;
end.
