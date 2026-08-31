unit nextpas.core.ssh.kex.curve25519;

{** nextpas.core.ssh - curve25519-sha256 客户端密钥交换。
 *
 * 输入序与计算遵循 draft-ietf-curdle-ssh-curves §4（与 RFC 4253 通用 KEX 相同）：
 *   H = HASH(V_C || V_S || I_C || I_S || K_S || e || f || K)
 * 主机密钥验签不在本单元：ProcessReply 返回全部材料，由 session 校验
 * （known_hosts / 指纹策略属于会话层职责）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.kex;

type
  { 可插拔 KEX 算法契约：新算法（DH group14、ecdh-nistp 等）实现此接口后
    即可接入会话层，无需改动握手编排代码。}
  ISshKeyExchange = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000003}']
    { 协商选定的 KEX 名称 }
    function AlgorithmName: string;
    { 我方 INIT 载荷（含消息号字节）}
    function BuildInitPayload: TBytes;
    { 解析服务方 REPLY 载荷并完成共享秘密与 H 计算。
      AVc/AVs 为双方版本串；AMyKexInit/APeerKexInit 为双方 KEXINIT 完整载荷。}
    function ProcessReply(const APayload: TBytes;
      const AVc, AVs: string;
      const AMyKexInit, APeerKexInit: TBytes;
      out AK, AH, AServerHostKeyBlob, AServerSigBlob: TBytes): Boolean;
  end;

  { curve25519 交换产物（ProcessReply 的具名形式）}
  TSshKexCurve25519Result = record
    SharedSecret: TBytes;      { X25519 共享秘密 magnitude（作为 mpint 输入）}
    ExchangeHashH: TBytes;     { SHA-256 交换散列 }
    ServerHostKeyBlob: TBytes; { 服务方公钥 blob }
    ServerSigBlob: TBytes;     { 服务方签名 blob（string alg + string sig）}
  end;

  { 客户端 curve25519-sha256 交换器 }
  TSshKexCurve25519 = class(TInterfacedObject, ISshKeyExchange)
  private
    FPriv: TBytes;
    FPub: TBytes;
  public
    constructor Create;
    destructor Destroy; override;

    function AlgorithmName: string;
    property ClientEphemeral: TBytes read FPub;

    { SSH_MSG_KEX_ECDH_INIT 载荷（含消息号字节）}
    function BuildInitPayload: TBytes;

    { 解析 SSH_MSG_KEX_ECDH_REPLY 载荷并完成共享秘密与 H 计算。
      全零共享秘密视为协议攻击，抛 sekProtocol。*}
    function ProcessReply(const APayload: TBytes;
      const AVc, AVs: string;
      const AMyKexInit, APeerKexInit: TBytes;
      out AK, AH, AServerHostKeyBlob, AServerSigBlob: TBytes): Boolean;

    { 具名产物形式（内部复用 ProcessReply）}
    function ProcessReplyNamed(const APayload: TBytes;
      const AVc, AVs: string;
      const AMyKexInit, APeerKexInit: TBytes): TSshKexCurve25519Result;
  end;

{ RFC 4253 §8 交换哈希输入：string(V_C)||string(V_S)||string(I_C)||
  string(I_S)||string(K_S)||mpint(e)||mpint(f)||mpint(K)。
  独立导出：环回 mock 服务端必须与客户端共用同一构造，防止两端各自
  手拼导致 H 漂移（回环镜像同错不可见）。}
function SshBuildCurve25519HashInput(const AVc, AVs: string;
  const AClientKexInit, AServerKexInit, AHostKeyBlob,
  AClientEphemeral, AServerEphemeral, ASharedSecret: TBytes): TBytes;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.hash,
  nextpas.core.mem.secure;

{ 无符号拼接 }
function ConcatAll(const AParts: array of TBytes): TBytes;
var
  I: Integer;
  LTot, LPos: SizeUInt;
begin
  Result := nil;
  LTot := 0;
  for I := 0 to High(AParts) do
    Inc(LTot, SizeUInt(Length(AParts[I])));
  SetLength(Result, LTot);
  LPos := 0;
  for I := 0 to High(AParts) do
  begin
    if Length(AParts[I]) > 0 then
    begin
      Move(AParts[I][0], Result[LPos], SizeUInt(Length(AParts[I])));
      Inc(LPos, SizeUInt(Length(AParts[I])));
    end;
  end;
end;

constructor TSshKexCurve25519.Create;
begin
  inherited Create;
  GenerateX25519KeyPair(FPriv, FPub);
end;

destructor TSshKexCurve25519.Destroy;
begin
  SecureZeroBytes(FPriv);
  SecureZeroBytes(FPub);
  inherited;
end;

function SshBuildCurve25519HashInput(const AVc, AVs: string;
  const AClientKexInit, AServerKexInit, AHostKeyBlob,
  AClientEphemeral, AServerEphemeral, ASharedSecret: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  { 全部字段按线类型编码：V/I/K_S/e/f 为 string（含 uint32 长度前缀），K 为 mpint }
  LW := TsshWriter.Create(2048);
  try
    LW.PutStringText(AVc);
    LW.PutStringText(AVs);
    LW.PutStringBytes(AClientKexInit);
    LW.PutStringBytes(AServerKexInit);
    LW.PutStringBytes(AHostKeyBlob);
    LW.PutStringBytes(AClientEphemeral);
    LW.PutStringBytes(AServerEphemeral);
    LW.PutMPInt(ASharedSecret);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function TSshKexCurve25519.AlgorithmName: string;
begin
  Result := 'curve25519-sha256';
end;

function TSshKexCurve25519.BuildInitPayload: TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(128);
  try
    LW.PutByte(SSH_MSG_KEX_ECDH_INIT);
    LW.PutStringBytes(FPub);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function TSshKexCurve25519.ProcessReply(const APayload: TBytes;
  const AVc, AVs: string;
  const AMyKexInit, APeerKexInit: TBytes;
  out AK, AH, AServerHostKeyBlob, AServerSigBlob: TBytes): Boolean;
var
  LResult: TSshKexCurve25519Result;
begin
  LResult := ProcessReplyNamed(APayload, AVc, AVs, AMyKexInit, APeerKexInit);
  AK := LResult.SharedSecret;
  AH := LResult.ExchangeHashH;
  AServerHostKeyBlob := LResult.ServerHostKeyBlob;
  AServerSigBlob := LResult.ServerSigBlob;
  Result := True;
end;

function TSshKexCurve25519.ProcessReplyNamed(const APayload: TBytes;
  const AVc, AVs: string;
  const AMyKexInit, APeerKexInit: TBytes): TSshKexCurve25519Result;
var
  LR: TsshReader;
  LW: TsshWriter;
  LServerEphemeral, LShared, LHashInput: TBytes;
  LX25519Err: AnsiString;
begin
  LR := TsshReader.Create(APayload);
  try
    if LR.ReadByte <> SSH_MSG_KEX_ECDH_REPLY then
      raise ESSHError.Create(sekProtocol, 'ssh kex: payload is not KEX_ECDH_REPLY');
    Result.ServerHostKeyBlob := LR.ReadStringBytes;
    LServerEphemeral := LR.ReadStringBytes;
    Result.ServerSigBlob := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  if Length(LServerEphemeral) <> 32 then
    raise ESSHError.Create(sekProtocol, 'ssh kex: server ephemeral not 32 bytes');
  if not TryX25519ComputeSharedSecret(FPriv, LServerEphemeral, LShared,
    LX25519Err) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: x25519 failed: '
      + string(LX25519Err));
  if IsZeroBytes(LShared) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: all-zero shared secret rejected');

  Result.SharedSecret := LShared;
  LHashInput := SshBuildCurve25519HashInput(AVc, AVs, AMyKexInit, APeerKexInit,
    Result.ServerHostKeyBlob, FPub, LServerEphemeral, LShared);
  Result.ExchangeHashH := SHA256(LHashInput);
end;

end.
