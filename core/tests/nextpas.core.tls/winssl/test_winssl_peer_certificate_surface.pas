program test_winssl_peer_certificate_surface;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  nextpas.core.platform.socket,
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  Total: Integer;
  Passed: Integer;
  Failed: Integer;
  Section: string;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

function ResolvePeerCertHost: string;
begin
  Result := Trim(GetEnvironmentVariable('NEXTPAS_WINSSL_PEER_CERT_HOST'));
  if Result = '' then
    Result := 'api.github.com';
end;

function EnvEnabled(const AName: string): Boolean;
var
  LValue: string;
begin
  LValue := LowerCase(Trim(GetEnvironmentVariable(AName)));
  Result := (LValue = '1') or (LValue = 'true') or
    (LValue = 'yes') or (LValue = 'on');
end;

procedure BeginSection(const AName: string);
begin
  Section := AName;
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

procedure Check(const AName: string; AOk: Boolean; const ADetails: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', AName, ': ');
  if AOk then
  begin
    Inc(Passed);
    WriteLn('PASS');
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL');
    if ADetails <> '' then
      WriteLn('    ', ADetails);
  end;
end;

function NormalizeDN(const AValue: string): string;
begin
  Result := Trim(UpperCase(AValue));
  Result := StringReplace(Result, ',', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function InitWinsock: Boolean;
begin
  Result := True;
end;

procedure CleanupWinsock;
begin
end;

function ConnectToHost(const AHost: string; APort: Word;
  out ASocket: TPlatformSocket): Boolean;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := False;
  ASocket := PLATFORM_INVALID_SOCKET;

  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(AHost)), LIP) <> 0 then
    Exit;
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    ASocket) <> 0 then
    Exit;

  platform_socket_set_timeout(ASocket, PLATFORM_SO_RCVTIMEO, 10000);
  platform_socket_set_timeout(ASocket, PLATFORM_SO_SNDTIMEO, 10000);

  platform_sockaddr_ipv4(APort, LIP, LAddr);

  Result := platform_socket_connect(ASocket, @LAddr.Storage[0],
    LAddr.Len) = 0;
  if not Result then
    platform_socket_close(ASocket);
end;

function FindCertificateIndexByFingerprint(const AChain: TSSLCertificateArray;
  const AFingerprint: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AFingerprint = '' then
    Exit;

  for I := 0 to High(AChain) do
    if (AChain[I] <> nil) and
       SameText(AChain[I].GetFingerprintSHA256, AFingerprint) then
      Exit(I);
end;

function FindIssuerIndex(const ALeaf: ISSLCertificate;
  const AChain: TSSLCertificateArray): Integer;
var
  I: Integer;
  LTargetIssuer: string;
  LLeafFingerprint: string;
begin
  Result := -1;
  if ALeaf = nil then
    Exit;

  LTargetIssuer := NormalizeDN(ALeaf.GetIssuer);
  if LTargetIssuer = '' then
    Exit;

  LLeafFingerprint := ALeaf.GetFingerprintSHA256;
  for I := 0 to High(AChain) do
    if (AChain[I] <> nil) and
       (not SameText(AChain[I].GetFingerprintSHA256, LLeafFingerprint)) and
       (NormalizeDN(AChain[I].GetSubject) = LTargetIssuer) then
      Exit(I);
end;

procedure TestPeerCertificateIssuerLinkSurface(const AHost: string);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TPlatformSocket;
  LPeerCert: ISSLCertificate;
  LPeerIssuer: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LLeafIndex: Integer;
  LIssuerIndex: Integer;
  LChainLeafIssuer: ISSLCertificate;
begin
  BeginSection('WinSSL peer certificate surface');

  if not EnvEnabled('NEXTPAS_RUN_NETWORK_TESTS') then
  begin
    Check('skip network test (NEXTPAS_RUN_NETWORK_TESTS!=1)', True);
    Exit;
  end;

  if not InitWinsock then
  begin
    Check('initialize Winsock', False);
    Exit;
  end;

  try
    LLib := CreateWinSSLLibrary;
    Check('create WinSSL library', LLib <> nil);
    if LLib = nil then
      Exit;

    Check('initialize WinSSL library', LLib.Initialize, LLib.GetLastErrorString);
    if not LLib.Initialize then
      Exit;

    LCtx := LLib.CreateContext(sslCtxClient);
    Check('create client context', LCtx <> nil);
    if LCtx = nil then
      Exit;

    LSocket := PLATFORM_INVALID_SOCKET;
    if not ConnectToHost(AHost, 443, LSocket) then
    begin
      Check('TCP connect', False, AHost);
      Exit;
    end;

    try
      LConn := LCtx.CreateConnection(THandle(LSocket.Value));
      Check('create client connection', LConn <> nil);
      if LConn = nil then
        Exit;

      (LConn as ISSLClientConnection).SetServerName(AHost);
      Check('TLS handshake completes', LConn.Connect, AHost);
      if not LConn.IsConnected then
        Exit;

      LPeerCert := LConn.GetPeerCertificate;
      Check('peer leaf certificate should exist', LPeerCert <> nil);
      if LPeerCert = nil then
        Exit;

      LChain := LConn.GetPeerCertificateChain;
      Check('peer certificate chain should contain at least leaf+issuer',
        Length(LChain) >= 2,
        Format('host=%s chain_length=%d', [AHost, Length(LChain)]));
      if Length(LChain) < 2 then
        Exit;

      LLeafIndex := FindCertificateIndexByFingerprint(LChain,
        LPeerCert.GetFingerprintSHA256);
      Check('peer leaf certificate should appear inside the returned chain',
        LLeafIndex >= 0,
        Format('peer_fp=%s chain_length=%d',
          [LPeerCert.GetFingerprintSHA256, Length(LChain)]));
      if LLeafIndex < 0 then
        Exit;

      LIssuerIndex := FindIssuerIndex(LPeerCert, LChain);
      Check('returned chain should include the peer issuer certificate',
        LIssuerIndex >= 0,
        Format('peer_subject=%s peer_issuer=%s',
          [LPeerCert.GetSubject, LPeerCert.GetIssuer]));
      if LIssuerIndex < 0 then
        Exit;

      LPeerIssuer := LPeerCert.GetIssuerCertificate;
      Check('peer leaf certificate should preserve issuer link',
        LPeerIssuer <> nil);
      if LPeerIssuer <> nil then
        Check('peer leaf issuer link should match the issuer chain entry',
          SameText(LPeerIssuer.GetFingerprintSHA256,
            LChain[LIssuerIndex].GetFingerprintSHA256),
          Format('peer_issuer_fp=%s chain_issuer_fp=%s',
            [LPeerIssuer.GetFingerprintSHA256,
             LChain[LIssuerIndex].GetFingerprintSHA256]));

      LChainLeafIssuer := LChain[LLeafIndex].GetIssuerCertificate;
      Check('peer chain leaf entry should preserve issuer link',
        LChainLeafIssuer <> nil);
      if LChainLeafIssuer <> nil then
        Check('peer chain leaf issuer link should match the issuer chain entry',
          SameText(LChainLeafIssuer.GetFingerprintSHA256,
            LChain[LIssuerIndex].GetFingerprintSHA256),
          Format('chain_leaf_issuer_fp=%s chain_issuer_fp=%s',
            [LChainLeafIssuer.GetFingerprintSHA256,
             LChain[LIssuerIndex].GetFingerprintSHA256]));

      LConn.Shutdown;
    finally
      if LSocket.IsValid then
        platform_socket_close(LSocket);
    end;
  finally
    CleanupWinsock;
  end;
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;

  WriteLn('Testing WinSSL peer certificate surface...');
  TestPeerCertificateIssuerLinkSurface(ResolvePeerCertHost);

  WriteLn;
  WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
