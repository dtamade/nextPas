unit nextpas.core.ssh.auth;

{** nextpas.core.ssh - 用户认证载荷构造（RFC 4252）。
 *
 * 纯载荷构造/解析；流程编排属于 session 单元。
 * 签名数据 = session_id || SSH_MSG_USERAUTH_REQUEST || user || service
 *          || algname || pubkeyblob（RFC 4252 §7）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.buffer;

{ SSH_MSG_SERVICE_REQUEST "ssh-userauth" }
function SshBuildServiceRequest: TBytes;

{ publickey 认证：待签名串（不含消息号字节）}
function SshAuthSignedData(const ASessionId: TBytes; const AUser, AAlgName: string;
  const APubBlob: TBytes): TBytes;

{ password 认证请求 }
function SshBuildAuthPassword(const AUser, APassword: string): TBytes;

{ publickey 探测请求（不带签名，want_reply 语义由调用方控制）}
function SshBuildAuthPubKeyProbe(const AUser, AAlgName: string;
  const APubBlob: TBytes): TBytes;

{ publickey 完整请求（带签名）}
function SshBuildAuthPubKeySigned(const AUser, AAlgName: string;
  const APubBlob, ASig: TBytes): TBytes;

{ ed25519 签名 blob：string("ssh-ed25519") + string(64B) }
function SshBuildEd25519SigBlob(const ASig64: TBytes): TBytes;

implementation

function PayloadWriter: TsshWriter;
begin
  Result := TsshWriter.Create(128);
end;

function SshBuildServiceRequest: TBytes;
var
  LW: TsshWriter;
begin
  LW := PayloadWriter;
  try
    LW.PutByte(SSH_MSG_SERVICE_REQUEST);
    LW.PutStringText(SSH_SERVICE_USERAUTH);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshAuthSignedData(const ASessionId: TBytes; const AUser, AAlgName: string;
  const APubBlob: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := PayloadWriter;
  try
    LW.PutStringBytes(ASessionId);   { RFC 4252 §7：string(session_id) 带长度前缀 }
    LW.PutByte(SSH_MSG_USERAUTH_REQUEST);
    LW.PutStringText(AUser);
    LW.PutStringText(SSH_SERVICE_CONNECTION);
    LW.PutStringText('publickey');
    LW.PutBoolean(True);
    LW.PutStringText(AAlgName);
    LW.PutStringBytes(APubBlob);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshBuildAuthPassword(const AUser, APassword: string): TBytes;
var
  LW: TsshWriter;
begin
  LW := PayloadWriter;
  try
    LW.PutByte(SSH_MSG_USERAUTH_REQUEST);
    LW.PutStringText(AUser);
    LW.PutStringText(SSH_SERVICE_CONNECTION);
    LW.PutStringText('password');
    LW.PutBoolean(False);          { 不改密 }
    LW.PutStringText(APassword);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshBuildAuthPubKeyProbe(const AUser, AAlgName: string;
  const APubBlob: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := PayloadWriter;
  try
    LW.PutByte(SSH_MSG_USERAUTH_REQUEST);
    LW.PutStringText(AUser);
    LW.PutStringText(SSH_SERVICE_CONNECTION);
    LW.PutStringText('publickey');
    LW.PutBoolean(False);          { 无签名探测 }
    LW.PutStringText(AAlgName);
    LW.PutStringBytes(APubBlob);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshBuildAuthPubKeySigned(const AUser, AAlgName: string;
  const APubBlob, ASig: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := PayloadWriter;
  try
    LW.PutByte(SSH_MSG_USERAUTH_REQUEST);
    LW.PutStringText(AUser);
    LW.PutStringText(SSH_SERVICE_CONNECTION);
    LW.PutStringText('publickey');
    LW.PutBoolean(True);
    LW.PutStringText(AAlgName);
    LW.PutStringBytes(APubBlob);
    LW.PutStringBytes(ASig);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshBuildEd25519SigBlob(const ASig64: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  if Length(ASig64) <> 64 then
    raise Exception.Create('ssh auth: ed25519 signature must be 64 bytes');
  LW := PayloadWriter;
  try
    LW.PutStringText('ssh-ed25519');
    LW.PutStringBytes(ASig64);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

end.
