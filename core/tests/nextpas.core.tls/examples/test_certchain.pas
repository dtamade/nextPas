program test_certchain;

{$mode objfpc}{$H+}


uses
  nextpas.core.tls.openssl.backed,
  tls_test_sockets,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.certchain, nextpas.core.base.utils, nextpas.core.exception, nextpas.core.text.format, nextpas.core.time;

procedure TestCertificateChainValidation;
var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ClientConn: ISSLClientConnection;
  CertVerify: ISSLCertificateVerification;
  Socket: TSocketHandle;
  PeerCert: ISSLCertificate;
  CertChain: TSSLCertificateArray;
  ChainVerifier: ISSLCertificateChainVerifier;
  VerifyResult: TChainVerifyResult;
  CertInfo: TSSLCertificateInfo;
  i: Integer;
  NetErr: string;
begin
  WriteLn('=== 测试证书链验证功能 ===');
  WriteLn;

  // 初始化网络
  if not InitNetwork(NetErr) then
  begin
    WriteLn('错误: 无法初始化网络: ', NetErr);
    Exit;
  end;

  try
    // 初始化 SSL 库
    WriteLn('初始化 SSL 库...');
    {$IFDEF WINDOWS}
    SSLLib := TSSLFactory.GetLibraryInstance(sslWinSSL);
    {$ELSE}
    SSLLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    {$ENDIF}
    if not SSLLib.Initialize then
    begin
      WriteLn('错误: 无法初始化 SSL 库');
      Exit;
    end;

    // 创建 SSL 上下文
    WriteLn('创建 SSL 上下文...');
    Context := SSLLib.CreateContext(sslCtxClient);
    Context.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    // 创建 TCP 连接
    WriteLn('连接到 www.google.com:443...');
    try
      Socket := ConnectTCP('www.google.com', 443);
    except
      on E: Exception do
      begin
        WriteLn('错误: 无法连接到服务器: ', E.Message);
        Exit;
      end;
    end;

    WriteLn('TCP 连接成功建立');

    // 创建 SSL 连接
    WriteLn('创建 SSL 连接...');
    Connection := Context.CreateConnection(Socket);
    ClientConn := Connection as ISSLClientConnection;
    ClientConn.SetServerName('www.google.com');

    // 执行 SSL 握手
    WriteLn('执行 SSL 握手...');
    if not Connection.Connect then
    begin
      WriteLn('错误: SSL 握手失败');
      CloseSocket(Socket);
      Exit;
    end;

    WriteLn('SSL 握手成功完成！');
    WriteLn;

    // 获取对端证书
    WriteLn('获取服务器证书...');
    PeerCert := Connection.GetPeerCertificate;
    if PeerCert = nil then
    begin
      WriteLn('错误: 无法获取服务器证书');
      CloseSocket(Socket);
      Exit;
    end;

    // 显示证书信息
    CertInfo := PeerCert.GetInfo;
    WriteLn('服务器证书信息:');
    WriteLn('  Subject: ', CertInfo.Subject);
    WriteLn('  Issuer: ', CertInfo.Issuer);
    WriteLn('  Serial Number: ', CertInfo.SerialNumber);
    WriteLn('  Not Before: ', DateTimeToStr(CertInfo.NotBefore));
    WriteLn('  Not After: ', DateTimeToStr(CertInfo.NotAfter));
    WriteLn('  Signature Algorithm: ', CertInfo.SignatureAlgorithm);
    WriteLn;

    // 获取证书链
    WriteLn('获取证书链...');
    if not Supports(Connection, ISSLCertificateVerification, CertVerify) then
    begin
      WriteLn('错误: 连接未暴露 ISSLCertificateVerification');
      CloseSocket(Socket);
      Exit;
    end;
    CertChain := CertVerify.GetPeerCertificateChain;
    WriteLn('证书链长度: ', Length(CertChain));

    // 显示证书链中每个证书的信息
    if Length(CertChain) > 0 then
    begin
      WriteLn('证书链详细信息:');
      for i := 0 to High(CertChain) do
      begin
        CertInfo := CertChain[i].GetInfo;
        WriteLn(TextFormat('  [%d] Subject: %s', [i, CertInfo.Subject]));
        WriteLn(TextFormat('      Issuer: %s', [CertInfo.Issuer]));
      end;
    end;
    WriteLn;

    // 创建证书链验证器
    WriteLn('创建证书链验证器...');
    ChainVerifier := TSSLCertificateChainVerifier.Create;

    // 设置验证选项（使用默认选项）
    ChainVerifier.SetOptions(DefaultChainVerifyOptions);

    // 验证单个证书（将自动构建证书链）
    WriteLn('验证服务器证书...');
    VerifyResult := ChainVerifier.VerifyCertificate(PeerCert, 'www.google.com');

    // 显示验证结果
    WriteLn;
    WriteLn('=== 证书链验证结果 ===');
    WriteLn('  有效性: ', VerifyResult.IsValid);
    WriteLn('  错误代码: ', VerifyResult.ErrorCode);
    WriteLn('  错误消息: ', VerifyResult.ErrorMessage);
    WriteLn('  链长度: ', VerifyResult.ChainLength);
    WriteLn('  信任的根证书: ', VerifyResult.TrustedRoot);
    WriteLn('  自签名: ', VerifyResult.SelfSigned);
    WriteLn('  主机名匹配: ', VerifyResult.HostnameMatch);

    if Assigned(VerifyResult.Warnings) then
    begin
      if Length(VerifyResult.Warnings) > 0 then
      begin
        WriteLn('  警告:');
        for i := 0 to Length(VerifyResult.Warnings) - 1 do
          WriteLn('    - ', VerifyResult.Warnings[i]);
      end;
    end;
    WriteLn;

    // 测试不同的验证选项
    WriteLn('测试严格验证选项...');
    ChainVerifier.SetOptions(StrictChainVerifyOptions);
    VerifyResult := ChainVerifier.VerifyCertificate(PeerCert, 'www.google.com');
    WriteLn('  严格验证结果: ', VerifyResult.IsValid);
    if not VerifyResult.IsValid then
      WriteLn('  错误: ', VerifyResult.ErrorMessage);
    if Assigned(VerifyResult.Warnings) then
    WriteLn;

    // 测试主机名不匹配的情况
    WriteLn('测试主机名不匹配...');
    ChainVerifier.SetOptions(DefaultChainVerifyOptions);
    VerifyResult := ChainVerifier.VerifyCertificate(PeerCert, 'www.example.com');
    WriteLn('  主机名验证结果: ', VerifyResult.IsValid);
    if not VerifyResult.IsValid then
      WriteLn('  错误: ', VerifyResult.ErrorMessage);
    if Assigned(VerifyResult.Warnings) then
    WriteLn;

    // 测试允许自签名证书
    WriteLn('测试允许自签名证书选项...');
    ChainVerifier.SetOptions([cvoCheckTime, cvoCheckSignature, cvoAllowSelfSigned]);
    VerifyResult := ChainVerifier.VerifyCertificate(PeerCert, 'www.google.com');
    WriteLn('  允许自签名结果: ', VerifyResult.IsValid);
    if Assigned(VerifyResult.Warnings) then

    // 关闭连接
    WriteLn;
    WriteLn('关闭 SSL 连接...');
    Connection.Shutdown;
    CloseSocket(Socket);

    WriteLn;
    WriteLn('=== 测试完成 ===');
  finally
    CleanupNetwork;
  end;
end;

begin
  try
    TestCertificateChainValidation;
  except
    on E: Exception do
    begin
      WriteLn('发生异常: ', E.ClassName, ': ', E.Message);
    end;
  end;

end.
