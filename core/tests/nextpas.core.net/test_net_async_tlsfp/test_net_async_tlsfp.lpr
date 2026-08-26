program test_net_async_tlsfp;

{** @desc nextpas.core.net.async.tlsfp 集成测试：

  1. full-handshake-get   对 openssl s_server(-www) 完整 TLS1.3 握手
                          （SH/ECDHE/EE/CERT/CV/FIN + 客户端 FIN），
                          发 HTTP GET 收到真实响应体
  2. second-connection    第二条连接独立状态（序列号/密钥不串线）
  3. garbage-server       裸 TCP 服务端发非 TLS 字节 → 握手负码失败，
                          不外漏半开流
  4. dial-refused         拨号拒绝原样透传负码
  5. defaults             缺省选项字段
  6. multi-write          同一连接两次顺序 AsyncWrite（回归：发送队列
                          残留压实——旧实现第二次写会重放首条记录，
                          对端 AEAD 序列号错乱即断）
  7. seam-dispatch        经 net.async.tls.AsyncTlsConnect +
                          Backend=atbFreePascal 分发到本引擎打真机，
                          证明单一入口可选后端
  8. verify-peer-success  CA 签发证书 + 匹配主机名：全链验证 +
                          CV 签名校验通过，完整 GET
  9. verify-untrusted     不受信锚（无关自签 CA）→ 负码失败
 10. hostname-mismatch    主机名不在 SAN → 即使链可信也失败

  外部对端 = openssl s_server（Makefile test 目标拉起/回收；无 openssl
  时软跳过）。VerifyPeer 用例还需 Makefile 生成的测试 PKI（env 缺席
  即不注册）。进程内垃圾服务端走同一事件循环，无线程、无阻塞 IO。 *}

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
  nextpas.core.errors,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.tls,
  nextpas.core.net.async.tlsfp;

const
  cServerPort = 15556;
  cGetRequest: string = 'GET / HTTP/1.0' + #13#10 + #13#10;

type
  TCliPhase = (cpIdle, cpDialing, cpSending, cpReading);

var
  GLoop: TAsyncLoop;
  GFinished: Boolean;

  { 客户端状态 }
  GCliStream: IAsyncTcpStream;
  GCliErr: Int32;
  GCliReady: Boolean;
  GAcc: TBytes;
  GFoundResponse: Boolean;
  GEofEarly: Boolean;
  GSubmitOk: Boolean;
  GCbCalled: Boolean;
  { 挂起读缓冲：跨回调持有，用例收尾统一释放 }
  GRxBufPtr: PByte;
  { 分段写阶段计数（multi-write 回归） }
  GWriteStage: Integer;

  { 进程内垃圾服务端状态 }
  GListener: IAsyncTcpListener;
  GPort: UInt16;
  GSrvStream: IAsyncTcpStream;

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

function ContainsBytes(const AHaystack: TBytes;
  const ANeedle: string): Boolean;
var
  I, J, LHit: Integer;
begin
  Result := False;
  LHit := Length(ANeedle);
  if Length(AHaystack) < LHit then
    Exit;
  for I := 0 to Length(AHaystack) - LHit do
  begin
    Result := True;
    for J := 0 to LHit - 1 do
      if AHaystack[I + J] <> Ord(ANeedle[J + 1]) then
      begin
        Result := False;
        Break;
      end;
    if Result then
      Exit;
  end;
end;

procedure ResetClientState;
begin
  GCliStream := nil;
  GCliErr := 0;
  GCliReady := False;
  SetLength(GAcc, 0);
  GFoundResponse := False;
  GEofEarly := False;
  GSubmitOk := False;
  GCbCalled := False;
  GWriteStage := 0;
  { 用例间必须复位：FinishCase 靠它防止重复调度停机 }
  GFinished := False;
end;

procedure ReleaseRxBuf;
begin
  if GRxBufPtr <> nil then
  begin
    FreeMem(GRxBufPtr);
    GRxBufPtr := nil;
  end;
end;

{ ======== 客户端回调 ======== }

procedure ReadCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
const
  cCap = 262144;
begin
  if AResult < 0 then
  begin
    GCliErr := AResult;
    FinishCase;
    Exit;
  end;
  if AResult = 0 then
  begin
    if not GFoundResponse then
      GEofEarly := True;
    FinishCase;
    Exit;
  end;
  SetLength(GAcc, Length(GAcc) + AResult);
  Move(GRxBufPtr^, GAcc[Length(GAcc) - AResult], AResult);
  if ContainsBytes(GAcc, 'HTTP/1.') then
  begin
    GFoundResponse := True;
    FinishCase;
    Exit;
  end;
  if Length(GAcc) > cCap then
  begin
    GEofEarly := True;
    FinishCase;
    Exit;
  end;
  if not GCliStream.AsyncRead(GRxBufPtr, 4096, @ReadCb, nil) then
  begin
    GCliErr := ASYNC_TLSFP_ERR_IO;
    FinishCase;
  end;
end;

procedure WriteCb(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;

procedure SubmitWrite(const APart: string);
begin
  if not GCliStream.AsyncWrite(PChar(APart), Length(APart), @WriteCb,
    nil) then
  begin
    GCliErr := ASYNC_TLSFP_ERR_IO;
    FinishCase;
  end;
end;

{ 两段顺序写：第二段提交前上一段必须已冲尽并压实队列 }
procedure WriteCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LReq: string;
begin
  if AResult <= 0 then
  begin
    GCliErr := ASYNC_TLSFP_ERR_IO;
    FinishCase;
    Exit;
  end;
  LReq := cGetRequest;
  Inc(GWriteStage);
  if GWriteStage = 1 then
  begin
    SubmitWrite(Copy(LReq, 1, Length(LReq) div 2));
    Exit;
  end;
  if GWriteStage = 2 then
  begin
    SubmitWrite(Copy(LReq, Length(LReq) div 2 + 1,
      Length(LReq) - Length(LReq) div 2));
    Exit;
  end;
  GetMem(GRxBufPtr, 4096);
  if not GCliStream.AsyncRead(GRxBufPtr, 4096, @ReadCb, nil) then
  begin
    ReleaseRxBuf;
    GCliErr := ASYNC_TLSFP_ERR_IO;
    FinishCase;
  end;
end;

procedure ReadyCb(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
begin
  GCbCalled := True;
  if AError <> 0 then
  begin
    GCliErr := AError;
    GCliReady := False;
    FinishCase;
    Exit;
  end;
  GCliStream := AStream;
  GCliReady := True;
  if not GCliStream.AsyncWrite(PChar(cGetRequest),
    Length(cGetRequest), @WriteCb, nil) then
  begin
    GCliErr := ASYNC_TLSFP_ERR_IO;
    FinishCase;
  end;
end;

{ ======== 进程内垃圾服务端 ======== }

procedure SrvWriteCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
begin
  if AResult > 0 then
    GSrvStream.Shutdown;
end;

procedure PollAcceptTick(AContext: Pointer);
var
  LConn: ITcpStream;
  LGarbage: TBytes;
begin
  if GFinished then
    Exit;
  if (GSrvStream = nil) and (GListener <> nil) then
  begin
    if (GListener as ITcpListenerRuntime).TryAccept(LConn) = tarAccepted
    then
    begin
      GSrvStream := AsyncTcpStreamAdopt(GLoop, LConn);
      LGarbage := TBytes.Create(Ord('g'), Ord('a'), Ord('r'), Ord('b'),
        Ord('a'), Ord('g'), Ord('e'), 21);
      if not GSrvStream.AsyncWrite(@LGarbage[0], Length(LGarbage),
        @SrvWriteCb, nil) then
        GSrvStream := nil;
      Exit;
    end;
  end;
  GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);
end;

{ ======== 用例驱动 ======== }

procedure RunTlsGetAgainstRealServer;
var
  LOpts: TAsyncTlsFpClientOptions;
begin
  ResetClientState;
  GLoop := TAsyncLoop.Create;
  try
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    LOpts := DefaultAsyncTlsFpClientOptions;
    LOpts.ServerName := 'localhost';
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    GSubmitOk := AsyncTlsFpConnect(GLoop, '127.0.0.1', cServerPort,
      LOpts, @ReadyCb, nil);
    { 回调可能同步交付（回环极快路径）；未交付才进循环等待 }
    if GSubmitOk and not GCbCalled then
      GLoop.Run;
  finally
    ReleaseRxBuf;
    GCliStream := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

{ 经 net.async.tls 单一入口分发到纯 Pas 引擎（Backend=atbFreePascal） }
procedure RunTlsGetViaSeam;
var
  LOpts: TAsyncTlsClientOptions;
begin
  ResetClientState;
  GLoop := TAsyncLoop.Create;
  try
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    LOpts := DefaultAsyncTlsClientOptions;
    LOpts.ServerName := 'localhost';
    LOpts.VerifyPeer := False;
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    LOpts.Backend := atbFreePascal;
    GSubmitOk := AsyncTlsConnect(GLoop, '127.0.0.1', cServerPort,
      LOpts, @ReadyCb, nil);
    if GSubmitOk and not GCbCalled then
      GLoop.Run;
  finally
    ReleaseRxBuf;
    GCliStream := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

procedure RunAgainstGarbageServer;
var
  LOpts: TAsyncTlsFpClientOptions;
  LRaw: IAsyncTcpStream;
begin
  ResetClientState;
  GSrvStream := nil;
  GLoop := TAsyncLoop.Create;
  try
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    (GListener as ITcpSocketRuntime).SetBlocking(False);
    GPort := GListener.LocalAddr.Port;
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);

    LOpts := DefaultAsyncTlsFpClientOptions;
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    LRaw := AsyncTcpConnect(GLoop, '127.0.0.1', GPort);
    GSubmitOk := AsyncTlsFpUpgrade(GLoop, LRaw, LOpts, @ReadyCb, nil);
    if GSubmitOk and not GCbCalled then
      GLoop.Run;
  finally
    ReleaseRxBuf;
    GCliStream := nil;
    GSrvStream := nil;
    GListener := nil;
    LRaw := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

procedure RunDialRefused;
var
  LOpts: TAsyncTlsFpClientOptions;
begin
  ResetClientState;
  GLoop := TAsyncLoop.Create;
  try
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    LOpts := DefaultAsyncTlsFpClientOptions;
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    { 端口 1：常规权限下必然拒绝，拨号域负码透传 }
    GSubmitOk := AsyncTlsFpConnect(GLoop, '127.0.0.1', 1, LOpts,
      @ReadyCb, nil);
    if GSubmitOk and not GCbCalled then
      GLoop.Run;
  finally
    ReleaseRxBuf;
    GCliStream := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

{ ======== 用例 ======== }

{ e2e 对端可用性探测。common.mk 的 run 前置目标会在 Makefile e2e
  配方拉起 s_server 之前先执行本程序（test: run 与本地 test: 配方
  覆盖发生前置合并——make「覆盖配方」警告即此），对端缺席时这三
  个用例必须不注册，否则产生秒败 -3201 的幻影失败。 }
function TlsE2EAvailable: Boolean;
var
  LProbe: ITcpStream;
begin
  Result := False;
  try
    LProbe := NetTcpConnect('127.0.0.1', cServerPort);
    Result := LProbe <> nil;
  except
    Exit(False);
  end;
end;

procedure TestFullHandshakeGet;
begin
  RunTlsGetAgainstRealServer;
  Check(GSubmitOk, 'connect submit');
  Check(GCbCalled, 'callback delivered');
  Check(GCliReady, 'handshake done');
  CheckEqual(Int64(0), Int64(GCliErr), 'no error');
  Check(GFoundResponse, 'HTTP response recognized');
  Check(not GEofEarly, 'no premature eof');
end;

procedure TestSecondConnection;
begin
  RunTlsGetAgainstRealServer;
  Check(GCliReady, 'second handshake done');
  Check(GFoundResponse, 'second HTTP response recognized');
end;

procedure TestSeamDispatch;
begin
  RunTlsGetViaSeam;
  Check(GSubmitOk, 'seam connect submit');
  Check(GCbCalled, 'seam callback delivered');
  Check(GCliReady, 'seam handshake done');
  CheckEqual(Int64(0), Int64(GCliErr), 'seam no error');
  Check(GFoundResponse, 'seam HTTP response recognized');
end;

procedure TestGarbageServer;
begin
  RunAgainstGarbageServer;
  Check(GSubmitOk, 'upgrade submit');
  Check(GCbCalled, 'callback delivered');
  Check(not GCliReady, 'handshake rejected');
  Check(GCliErr < 0, 'negative error code');
  Check(GCliStream = nil, 'no half-open stream escapes');
end;

procedure TestDialRefused;
begin
  RunDialRefused;
  Check(GSubmitOk, 'dial submit');
  Check(GCbCalled, 'callback delivered');
  Check(not GCliReady, 'dial refused reported');
  Check(GCliErr < 0, 'negative passthrough code');
end;

{ VerifyPeer=True 的 e2e 驱动：信任锚 bundle + 期望的主机名 }
procedure RunVerifiedGet(const ATrustBundle, AServerName: string);
var
  LOpts: TAsyncTlsFpClientOptions;
begin
  ResetClientState;
  GLoop := TAsyncLoop.Create;
  try
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    LOpts := DefaultAsyncTlsFpClientOptions;
    LOpts.ServerName := AServerName;
    LOpts.VerifyPeer := True;
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));
    LOpts.TrustBundlePath := ATrustBundle;
    GSubmitOk := AsyncTlsFpConnect(GLoop, '127.0.0.1', cServerPort,
      LOpts, @ReadyCb, nil);
    if GSubmitOk and not GCbCalled then
      GLoop.Run;
  finally
    ReleaseRxBuf;
    GCliStream := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

function EnvOrEmpty(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
end;

{ VerifyPeer 成功路径：CA 签发证书 + 匹配主机名 → 完整握手 + GET }
procedure TestVerifyPeerSuccess;
var
  LBundle: string;
begin
  LBundle := EnvOrEmpty('TLSFP_TRUST_BUNDLE');
  Check(LBundle <> '', 'trust bundle env present');
  RunVerifiedGet(LBundle, 'localhost');
  Check(GSubmitOk, 'verify submit');
  Check(GCbCalled, 'verify callback delivered');
  Check(GCliReady, 'verified handshake done');
  CheckEqual(Int64(0), Int64(GCliErr), 'verify no error');
  Check(GFoundResponse, 'verified HTTP response recognized');
end;

{ 不受信锚（无关自签 CA）→ 握手负码失败，不外漏半开流 }
procedure TestVerifyUntrustedFails;
var
  LBundle: string;
begin
  LBundle := EnvOrEmpty('TLSFP_UNTRUSTED_BUNDLE');
  Check(LBundle <> '', 'untrusted bundle env present');
  RunVerifiedGet(LBundle, 'localhost');
  Check(GSubmitOk, 'untrusted submit');
  Check(GCbCalled, 'untrusted callback delivered');
  Check(not GCliReady, 'untrusted handshake rejected');
  Check(GCliErr < 0, 'untrusted negative error');
  Check(GCliStream = nil, 'untrusted no half-open stream');
end;

{ 主机名不匹配（SAN 无此名）→ 握手失败，即使链本身可信 }
procedure TestHostnameMismatchFails;
var
  LBundle: string;
begin
  LBundle := EnvOrEmpty('TLSFP_TRUST_BUNDLE');
  Check(LBundle <> '', 'mismatch trust bundle env present');
  RunVerifiedGet(LBundle, 'mismatch.invalid');
  Check(GSubmitOk, 'hostname submit');
  Check(GCbCalled, 'hostname callback delivered');
  Check(not GCliReady, 'hostname mismatch rejected');
  Check(GCliErr < 0, 'hostname mismatch negative error');
end;

procedure TestDefaults;
var
  LOpts: TAsyncTlsFpClientOptions;
begin
  LOpts := DefaultAsyncTlsFpClientOptions;
  Check(LOpts.ServerName = '', 'default server name empty');
  Check(not LOpts.VerifyPeer, 'default verify off');
  Check(LOpts.HandshakeDeadline.IsInfinite, 'default deadline infinite');
  Check(ASYNC_TLSFP_ERR_IO < 0, 'io code negative');
  Check(ASYNC_TLSFP_ERR_HANDSHAKE < 0, 'handshake code negative');
end;

var
  GSuite: TTestSuite;

begin
  GSuite := TTestSuite.Create('net_async_tlsfp');
  GSuite.Test('Defaults', @TestDefaults);
  GSuite.Test('DialRefused', @TestDialRefused);
  GSuite.Test('GarbageServer', @TestGarbageServer);
  if TlsE2EAvailable then
  begin
    GSuite.Test('FullHandshakeGet', @TestFullHandshakeGet);
    GSuite.Test('SecondConnection', @TestSecondConnection);
    GSuite.Test('SeamDispatch', @TestSeamDispatch);
    { VerifyPeer 用例需要 Makefile 生成的测试 PKI（env 缺席即跳过注册）}
    if (EnvOrEmpty('TLSFP_TRUST_BUNDLE') <> '') and
       (EnvOrEmpty('TLSFP_UNTRUSTED_BUNDLE') <> '') then
    begin
      GSuite.Test('VerifyPeerSuccess', @TestVerifyPeerSuccess);
      GSuite.Test('VerifyUntrustedFails', @TestVerifyUntrustedFails);
      GSuite.Test('HostnameMismatchFails', @TestHostnameMismatchFails);
    end;
  end;
  { 裸 Run 会吞失败退出码（门禁假绿）：失败必须 Halt(1) }
  if not GSuite.Run then
    Halt(1);
end.
