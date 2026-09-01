unit nextpas.core.ssh.session.handshake;

{** nextpas.core.ssh - 会话握手与重协商单源。
 *
 * 职责：版本交换后 KEXINIT 协商、curve25519 / dh-group14 交换、
 * 主机密钥验签与 known_hosts 策略、密钥推导与 NEWKEYS 切换、
 * SERVICE_REQUEST 与延迟压缩激活。
 * 单源：DoHandshake / DoRekey 共用 KDF / 验签 / 压缩时机逻辑，
 * transport/async 薄包装复用；零拷贝 Move 直通，inline 薄转发。
 * 稳定性：try-finally 保证 LKexCurve/LKexDH Free，SecureZeroBytes
 * 清零 LKmpint/IV/Key/Mac。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.kex;

function SshHandshakeExpectOneOf(ATransport: TSshClientTransport;
  const AAcceptable: array of Byte): TBytes;

procedure SshHandshakeLoadKnownHostsIfNeeded(const AOptions: TSshConnectOptions;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean);

procedure SshHandshakeVerifyHostKey(const AHostKeyInfo: TSshHostKeyInfo;
  const AHostKeyBlob: TBytes; const AFingerprint: string;
  const AOptions: TSshConnectOptions; var AKnownHosts: TSshKnownHosts;
  var AKnownHostsLoaded: Boolean; const ASigAlg: string;
  const AH, ASigBlob: TBytes);

procedure SshHandshakeDeriveAndApplyNewKeys(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; const AK, AH: TBytes;
  const ASessionId: TBytes);

procedure SshHandshakeDoServiceRequest(ATransport: TSshClientTransport);

procedure SshHandshakeTryEnableDelayedCompression(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; AAuthenticated: Boolean); inline;

procedure SshHandshakeDoHandshake(ATransport: TSshClientTransport;
  const AOptions: TSshConnectOptions; var ASessionId: TBytes;
  var ANegotiated: TSshNegotiated; var AHostKeyInfo: TSshHostKeyInfo;
  var AHostKeyBlob: TBytes; var AFingerprint: string;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean);

procedure SshHandshakeDoRekey(ATransport: TSshClientTransport;
  const AOptions: TSshConnectOptions; const ASessionId: TBytes;
  var ANegotiated: TSshNegotiated; var AHostKeyInfo: TSshHostKeyInfo;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean;
  AAuthenticated: Boolean; AClosed: Boolean);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.mem.secure,
  nextpas.core.crypto.random,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.kex.dhgroup14;

function SshHandshakeExpectOneOf(ATransport: TSshClientTransport;
  const AAcceptable: array of Byte): TBytes;
var I: Integer; LFound: Boolean;
begin
  while True do
  begin
    Result := PumpMessage(ATransport);
    LFound := False;
    for I := 0 to High(AAcceptable) do
      if Result[0] = AAcceptable[I] then begin LFound := True; Break; end;
    if LFound then Exit;
  end;
end;

procedure SshHandshakeLoadKnownHostsIfNeeded(const AOptions: TSshConnectOptions;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean);
begin
  if AKnownHostsLoaded then Exit;
  AKnownHostsLoaded := True;
  if AOptions.KnownHostsFile <> '' then
  begin
    AKnownHosts := TSshKnownHosts.Create;
    AKnownHosts.LoadFromFile(AOptions.KnownHostsFile);
  end;
end;

procedure SshHandshakeVerifyHostKey(const AHostKeyInfo: TSshHostKeyInfo;
  const AHostKeyBlob: TBytes; const AFingerprint: string;
  const AOptions: TSshConnectOptions; var AKnownHosts: TSshKnownHosts;
  var AKnownHostsLoaded: Boolean; const ASigAlg: string;
  const AH, ASigBlob: TBytes);
var LInFile: Boolean;
begin
  if not SshVerifyHostSignature(AHostKeyInfo, ASigAlg, AH, ASigBlob) then
    raise ESSHError.Create(sekHostKey,
      'ssh session: host key signature invalid (' +
      SshFingerprintSHA256(AHostKeyBlob) + ')');
  SshHandshakeLoadKnownHostsIfNeeded(AOptions, AKnownHosts, AKnownHostsLoaded);
  if AKnownHosts <> nil then
  begin
    LInFile := AKnownHosts.ContainsKey(AOptions.Host, AOptions.Port, AHostKeyBlob);
    if (not LInFile) and AOptions.StrictHostKeyChecking then
      raise ESSHError.Create(sekHostKey,
        'ssh session: host key not in known_hosts (' +
        AOptions.Host + ':' + IntToStr(AOptions.Port) + ', ' +
        AFingerprint + ')');
  end;
end;

procedure SshHandshakeDeriveAndApplyNewKeys(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; const AK, AH: TBytes;
  const ASessionId: TBytes);
var
  LW: TsshWriter;
  LKmpint, LIvCs, LIvSc, LKeyCs, LKeySc, LMacCs, LMacSc, LNewKeys: TBytes;
begin
  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(AK);
    LKmpint := LW.ToBytes;
  finally
    LW.Free;
  end;
  try
    LIvCs := SshKdfSha256(LKmpint, AH, Ord('A'), ASessionId,
      SshCipherIvSize(ANegotiated.EncCs));
    LIvSc := SshKdfSha256(LKmpint, AH, Ord('B'), ASessionId,
      SshCipherIvSize(ANegotiated.EncSc));
    LKeyCs := SshKdfSha256(LKmpint, AH, Ord('C'), ASessionId,
      SshCipherKeySize(ANegotiated.EncCs));
    LKeySc := SshKdfSha256(LKmpint, AH, Ord('D'), ASessionId,
      SshCipherKeySize(ANegotiated.EncSc));
    LMacCs := SshKdfSha256(LKmpint, AH, Ord('E'), ASessionId,
      SshMacKeySize(ANegotiated.MacCs));
    LMacSc := SshKdfSha256(LKmpint, AH, Ord('F'), ASessionId,
      SshMacKeySize(ANegotiated.MacSc));
    begin
      SetLength(LNewKeys, 1); LNewKeys[0] := SSH_MSG_NEWKEYS;
      ATransport.SendPacket(LNewKeys);
    end;
    SshHandshakeExpectOneOf(ATransport, [SSH_MSG_NEWKEYS]);
    ATransport.SetNegotiatedCompression(ANegotiated);
    ATransport.ApplyNewKeys(ANegotiated,
      LIvCs, LKeyCs, LMacCs, LIvSc, LKeySc, LMacSc);
  finally
    SecureZeroBytes(LKmpint);
    SecureZeroBytes(LIvCs);
    SecureZeroBytes(LIvSc);
    SecureZeroBytes(LKeyCs);
    SecureZeroBytes(LKeySc);
    SecureZeroBytes(LMacCs);
    SecureZeroBytes(LMacSc);
  end;
end;

procedure SshHandshakeDoServiceRequest(ATransport: TSshClientTransport);
var LW: TsshWriter;
begin
  LW := TsshWriter.Create(32);
  try
    LW.PutByte(SSH_MSG_SERVICE_REQUEST);
    LW.PutStringText(SSH_SERVICE_USERAUTH);
    ATransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
  SshHandshakeExpectOneOf(ATransport, [SSH_MSG_SERVICE_ACCEPT]);
end;

procedure SshHandshakeTryEnableDelayedCompression(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; AAuthenticated: Boolean);
begin
  if AAuthenticated and (SshCompressionIsDelayed(ANegotiated.CompCs)
    or SshCompressionIsDelayed(ANegotiated.CompSc)) then
    ATransport.EnableCompression;
end;

procedure SshHandshakeDoHandshake(ATransport: TSshClientTransport;
  const AOptions: TSshConnectOptions; var ASessionId: TBytes;
  var ANegotiated: TSshNegotiated; var AHostKeyInfo: TSshHostKeyInfo;
  var AHostKeyBlob: TBytes; var AFingerprint: string;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean);
var
  LCookie, LMyInit, LPeerInit, LReply: TBytes;
  LPeer: TSshPeerKexInit;
  LNeg: TSshNegotiated;
  LK, LH, LHostBlob, LSigBlob: TBytes;
  LKexCurve: TSshKexCurve25519;
  LKexDH: TSshKexDHGroup14;
begin
  ATransport.ExchangeVersions;
  LCookie := GenerateSecureRandomBytes(16);
  LMyInit := ATransport.SendKexInitEx(LCookie, AOptions.Compress);
  LPeerInit := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEXINIT]);
  LPeer := SshParseKexInit(LPeerInit);
  LNeg := SshNegotiateEx(LPeer, AOptions.Compress);
  ANegotiated := LNeg;
  if LNeg.KexAlg = 'diffie-hellman-group14-sha256' then
  begin
    LKexDH := TSshKexDHGroup14.Create;
    try
      ATransport.SendPacket(LKexDH.BuildInitPayload);
      LReply := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEX_ECDH_REPLY]);
      LKexDH.ProcessReply(LReply, SSH_PROTOCOL_VERSION, ATransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally
      LKexDH.Free;
    end;
  end
  else
  begin
    LKexCurve := TSshKexCurve25519.Create;
    try
      ATransport.SendPacket(LKexCurve.BuildInitPayload);
      LReply := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEX_ECDH_REPLY]);
      LKexCurve.ProcessReply(LReply, SSH_PROTOCOL_VERSION, ATransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally
      LKexCurve.Free;
    end;
  end;
  AHostKeyBlob := LHostBlob;
  if not SshParseHostKey(LHostBlob, AHostKeyInfo) then
    raise ESSHError.Create(sekHostKey, 'ssh session: unsupported host key blob');
  AFingerprint := SshFingerprintSHA256(LHostBlob);
  SshHandshakeVerifyHostKey(AHostKeyInfo, AHostKeyBlob, AFingerprint, AOptions, AKnownHosts, AKnownHostsLoaded, LNeg.HostKeyAlg, LH, LSigBlob);
  ASessionId := LH;
  SshHandshakeDeriveAndApplyNewKeys(ATransport, LNeg, LK, LH, ASessionId);
  SshHandshakeDoServiceRequest(ATransport);
end;

procedure SshHandshakeDoRekey(ATransport: TSshClientTransport;
  const AOptions: TSshConnectOptions; const ASessionId: TBytes;
  var ANegotiated: TSshNegotiated; var AHostKeyInfo: TSshHostKeyInfo;
  var AKnownHosts: TSshKnownHosts; var AKnownHostsLoaded: Boolean;
  AAuthenticated: Boolean; AClosed: Boolean);
var
  LCookie, LMyInit, LPeerInit, LReply: TBytes;
  LPeer: TSshPeerKexInit;
  LNeg: TSshNegotiated;
  LK, LH, LHostBlob, LSigBlob: TBytes;
  LKexCurve: TSshKexCurve25519;
  LKexDH: TSshKexDHGroup14;
  LFingerprint: string;
begin
  if AClosed or not AAuthenticated then
    raise ESSHError.Create(sekProtocol, 'ssh session: rekey outside authenticated session');
  if ATransport.State <> tstEncrypted then
    raise ESSHError.Create(sekProtocol, 'ssh session: rekey without encryption');
  LCookie := GenerateSecureRandomBytes(16);
  LMyInit := ATransport.SendKexInitEx(LCookie, AOptions.Compress);
  LPeerInit := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEXINIT]);
  LPeer := SshParseKexInit(LPeerInit);
  LNeg := SshNegotiateEx(LPeer, AOptions.Compress);
  if LNeg.KexAlg = 'diffie-hellman-group14-sha256' then
  begin
    LKexDH := TSshKexDHGroup14.Create;
    try
      ATransport.SendPacket(LKexDH.BuildInitPayload);
      LReply := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEX_ECDH_REPLY]);
      LKexDH.ProcessReply(LReply, SSH_PROTOCOL_VERSION, ATransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally LKexDH.Free; end;
  end else
  begin
    LKexCurve := TSshKexCurve25519.Create;
    try
      ATransport.SendPacket(LKexCurve.BuildInitPayload);
      LReply := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_KEX_ECDH_REPLY]);
      LKexCurve.ProcessReply(LReply, SSH_PROTOCOL_VERSION, ATransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally LKexCurve.Free; end;
  end;
  if not SshParseHostKey(LHostBlob, AHostKeyInfo) then
    raise ESSHError.Create(sekHostKey, 'ssh session: rekey unsupported host key blob');
  LFingerprint := SshFingerprintSHA256(LHostBlob);
  SshHandshakeVerifyHostKey(AHostKeyInfo, LHostBlob, LFingerprint, AOptions, AKnownHosts, AKnownHostsLoaded, LNeg.HostKeyAlg, LH, LSigBlob);
  SshHandshakeDeriveAndApplyNewKeys(ATransport, LNeg, LK, LH, ASessionId);
  ANegotiated := LNeg;
end;

end.
