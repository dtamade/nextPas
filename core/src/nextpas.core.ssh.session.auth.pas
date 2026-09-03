unit nextpas.core.ssh.session.auth;

{** nextpas.core.ssh - 会话认证单源（密码 / 私钥 / agent 回退）。
 *
 * 职责：USERAUTH 载荷构造与 probe→sign 时序、ed25519 / rsa-sha2-512
 * 分发、agent 枚举与逐身份尝试。单源复用 ssh.auth / ssh.keys / ssh.rsa /
 * bytes.ops；try-finally 保证 TsshReader Free，失败抛 sekAuth。
 * 性能：薄转发 inline，零拷贝 SpanEqual / Move；CRT 优先直通。
 * 稳定性：ListIdentities 失败抛 sekAuth，空身份抛 sekAuth。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.agent;

procedure SshAuthAuthenticateWithPassword(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; var AAuthenticated: Boolean;
  const AUser, APassword: string);

procedure SshAuthAuthenticateWithPrivateKeyData(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AContent, APassphrase: string);

procedure SshAuthAuthenticateWithAgent(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string; const APath: string);

procedure SshAuthAuthenticateWithAgentOn(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AAgentIO: IReadWriteCloser);

procedure SshAuthAuthenticateWithAgentClient(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AAgent: TSshAgentClient);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.ssh.auth,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.rsa,
  nextpas.core.ssh.session.handshake;

const
  SSH_ALG_ED25519 = 'ssh-ed25519';

procedure SshAuthAuthenticateWithPassword(ATransport: TSshClientTransport;
  const ANegotiated: TSshNegotiated; var AAuthenticated: Boolean;
  const AUser, APassword: string);
var
  LR: TsshReader;
  LMsg: TBytes;
begin
  ATransport.SendPacket(SshBuildAuthPassword(AUser, APassword));
  LMsg := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
  if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
  begin
    AAuthenticated := True;
    SshHandshakeTryEnableDelayedCompression(ATransport, ANegotiated, AAuthenticated);
  end
  else
  begin
    LR := TsshReader.Create(LMsg);
    try
      LR.ReadByte;
      LR.ReadStringText;
    finally
      LR.Free;
    end;
    raise ESSHError.Create(sekAuth,
      'ssh session: password rejected for user "' + AUser + '"');
  end;
end;

procedure SshAuthAuthenticateWithPrivateKeyData(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AContent, APassphrase: string);
var
  LR: TsshReader;
  LMsg: TBytes;
  LKey: TSshPrivateKey;
  LPubBlob, LSignedData, LSig64, LSigRaw, LSigBlob: TBytes;
  LAlgName: string;

  procedure AwaitSuccessOrRaise(const AWhat: string);
  begin
    LMsg := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
    if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
      AAuthenticated := True
    else
    begin
      LR := TsshReader.Create(LMsg);
      try
        LR.ReadByte;
        LR.ReadStringText;
      finally
        LR.Free;
      end;
      raise ESSHError.Create(sekAuth, 'ssh session: ' + AWhat + ' rejected');
    end;
  end;

begin
  if not SshLoadPrivateKey(AContent, LKey, LPubBlob, APassphrase) then
    raise ESSHError.Create(sekKeyFormat, 'ssh session: private key parse failed');

  case LKey.Kind of
    hkEd25519:
      begin
        LAlgName := SSH_ALG_ED25519;
        LSignedData := SshAuthSignedData(ASessionId, AActiveUser, LAlgName, LPubBlob);
        if not Ed25519Sign(LKey.Ed25519Seed, LSignedData, LSig64) then
          raise ESSHError.Create(sekCrypto, 'ssh session: ed25519 sign failed');
        LSigBlob := SshBuildEd25519SigBlob(LSig64);
      end;
    hkRsa:
      begin
        LAlgName := SSH_RSA_SIG_SHA512;
        LSignedData := SshAuthSignedData(ASessionId, AActiveUser, LAlgName, LPubBlob);
        if LKey.RsaHasCrt then
        begin
          if not RsaSignPkcs1v15Crt(LKey.RsaN, LKey.RsaD, LKey.RsaP, LKey.RsaQ,
            LKey.RsaIqmp, SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw) then
            if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData),
              DIGEST_INFO_SHA512, LSigRaw) then
              raise ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed');
        end
        else
          if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData),
            DIGEST_INFO_SHA512, LSigRaw) then
            raise ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed');
        LSigBlob := SshBuildRsaSigBlob(LSigRaw, LAlgName);
      end;
  else
    raise ESSHError.Create(sekUnsupported,
      'ssh session: unsupported private key kind');
  end;

  ATransport.SendPacket(
    SshBuildAuthPubKeySigned(AActiveUser, LAlgName, LPubBlob, LSigBlob));
  AwaitSuccessOrRaise('publickey');
  SshHandshakeTryEnableDelayedCompression(ATransport, ANegotiated, AAuthenticated);
end;

procedure SshAuthAuthenticateWithAgent(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string; const APath: string);
var
  LAgent: TSshAgentClient;
begin
  if APath = '' then
    raise ESSHError.Create(sekIO, 'ssh session: agent socket path empty');
  LAgent := SshAgentConnect(APath);
  try
    SshAuthAuthenticateWithAgentClient(ATransport, ASessionId, ANegotiated, AAuthenticated, AActiveUser, LAgent);
  finally
    LAgent.Free;
  end;
end;

procedure SshAuthAuthenticateWithAgentOn(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AAgentIO: IReadWriteCloser);
var
  LAgent: TSshAgentClient;
begin
  LAgent := TSshAgentClient.Create(AAgentIO);
  try
    SshAuthAuthenticateWithAgentClient(ATransport, ASessionId, ANegotiated, AAuthenticated, AActiveUser, LAgent);
  finally
    LAgent.Free;
  end;
end;

procedure SshAuthAuthenticateWithAgentClient(ATransport: TSshClientTransport;
  const ASessionId: TBytes; const ANegotiated: TSshNegotiated;
  var AAuthenticated: Boolean; const AActiveUser: string;
  const AAgent: TSshAgentClient);
var
  LIds: TSshAgentIdentityArray;
  I: Integer;
  LAlgName: string;
  LSignedData, LSigBlob: TBytes;
  LFlags: UInt32;
  LMsg: TBytes;
begin
  if not AAgent.ListIdentities(LIds) then
    raise ESSHError.Create(sekAuth, 'ssh session: agent list failed');
  if Length(LIds) = 0 then
    raise ESSHError.Create(sekAuth, 'ssh session: agent has no identities');
  for I := 0 to High(LIds) do
  begin
    LAlgName := LIds[I].AlgName;
    if LAlgName = '' then Continue;
    ATransport.SendPacket(SshBuildAuthPubKeyProbe(AActiveUser, LAlgName, LIds[I].Blob));
    LMsg := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE, SSH_MSG_USERAUTH_PK_OK]);
    if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    begin
      AAuthenticated := True;
      SshHandshakeTryEnableDelayedCompression(ATransport, ANegotiated, AAuthenticated);
      Exit;
    end;
    if LMsg[0] = SSH_MSG_USERAUTH_FAILURE then Continue;
    LFlags := SshAgentKeyBlobToSignFlags(LIds[I].Blob);
    LSignedData := SshAuthSignedData(ASessionId, AActiveUser, LAlgName, LIds[I].Blob);
    if not AAgent.Sign(LIds[I].Blob, LSignedData, LFlags, LSigBlob) then Continue;
    ATransport.SendPacket(SshBuildAuthPubKeySigned(AActiveUser, LAlgName, LIds[I].Blob, LSigBlob));
    LMsg := SshHandshakeExpectOneOf(ATransport, [SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
    if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    begin
      AAuthenticated := True;
      SshHandshakeTryEnableDelayedCompression(ATransport, ANegotiated, AAuthenticated);
      Exit;
    end;
  end;
  raise ESSHError.Create(sekAuth, 'ssh session: agent publickey rejected');
end;

end.
