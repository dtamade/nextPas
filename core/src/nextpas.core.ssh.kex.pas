unit nextpas.core.ssh.kex;

{** nextpas.core.ssh - KEXINIT 协商与密钥推导。
 *
 * 算法选择遵循 RFC 4253 §7.1：逐字段取"客户端列表中第一个也出现在服务端列表"
 * 的算法。KDF 遵循 RFC 4253 §7.2 的 HASH 扩展链。
 *
 * 本模块现代集合只用 SHA-256 做 KDF（curve25519-sha256）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.errors;

const
  { 我方算法提案（数组顺序即优先级）}
  SSH_OFFER_KEX_ALGS: array[0..2] of string =
    ('curve25519-sha256', 'curve25519-sha256@libssh.org',
     'diffie-hellman-group14-sha256');

  SSH_OFFER_HOSTKEY_ALGS: array[0..3] of string =
    ('ssh-ed25519', 'ecdsa-sha2-nistp256', 'rsa-sha2-512', 'rsa-sha2-256');

  SSH_OFFER_CIPHER_ALGS: array[0..5] of string =
    ('chacha20-poly1305@openssh.com',
     'aes256-gcm@openssh.com', 'aes128-gcm@openssh.com',
     'aes256-ctr', 'aes192-ctr', 'aes128-ctr');

  SSH_OFFER_MAC_ALGS: array[0..1] of string =
    ('hmac-sha2-512-etm@openssh.com', 'hmac-sha2-256-etm@openssh.com');

  SSH_OFFER_COMP_ALGS: array[0..0] of string = ('none');
  SSH_OFFER_COMP_ALGS_COMPRESS: array[0..2] of string =
    ('zlib@openssh.com', 'zlib', 'none');

type
  { 对端 KEXINIT 各字段的名称列表 }
  TSshPeerKexInit = record
    KexAlgs: TStringArray;
    HostKeyAlgs: TStringArray;
    EncCs: TStringArray;
    EncSc: TStringArray;
    MacCs: TStringArray;
    MacSc: TStringArray;
    CompCs: TStringArray;
    CompSc: TStringArray;
  end;

  { 协商结果（各字段为最终选定算法名）}
  TSshNegotiated = record
    KexAlg: string;
    HostKeyAlg: string;
    EncCs: string;
    EncSc: string;
    MacCs: string;
    MacSc: string;
    CompCs: string;
    CompSc: string;
  end;

{** 构造我方 SSH_MSG_KEXINIT 载荷（消息号字节由 transport 加）。
 * ACookie 为 16 字节随机数；返回的载荷同时用于 H 计算，调用方需保留。*}
function SshBuildKexInitPayload(const ACookie: TBytes): TBytes;
function SshBuildKexInitPayloadEx(const ACookie: TBytes; ACompress: Boolean): TBytes;

{** 解析对端 KEXINIT 载荷（不含消息号字节）。*}
function SshParseKexInit(const APayload: TBytes): TSshPeerKexInit;

{** 双方全字段协商；任一关键字段无交集抛 sekNegotiation。
 * AEAD cipher 下 MAC 字段允许无交集（结果置空串）。*}
function SshNegotiate(const APeer: TSshPeerKexInit): TSshNegotiated;
function SshNegotiateEx(const APeer: TSshPeerKexInit; ACompress: Boolean): TSshNegotiated;

{** RFC 4253 §7.2 KDF：HASH(K || H || X || session_id)，不足再接 HASH(K || H || prev)。*}
function SshKdfSha256(const AKMpint, AH: TBytes; AX: Byte;
  const ASessionId: TBytes; ALen: Integer): TBytes;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hash,
  nextpas.core.ssh.cipher;

function SshPickFirstMatch(const AClientOffer: array of string;
  const AServerList: TStringArray): string;
var
  I, J: Integer;
begin
  for I := 0 to High(AClientOffer) do
    for J := 0 to High(AServerList) do
      if AClientOffer[I] = AServerList[J] then
        Exit(AClientOffer[I]);
  Result := '';
end;

function SshBuildKexInitPayload(const ACookie: TBytes): TBytes;
begin
  Result := SshBuildKexInitPayloadEx(ACookie, False);
end;

function SshBuildKexInitPayloadEx(const ACookie: TBytes; ACompress: Boolean): TBytes;
var
  LW: TsshWriter;
begin
  if Length(ACookie) <> 16 then
    raise ESSHError.Create(sekProtocol, 'ssh kex: cookie must be 16 bytes');
  LW := TsshWriter.Create(512);
  try
    LW.PutByte(SSH_MSG_KEXINIT);
    LW.PutRaw(ACookie);
    LW.PutNameList(SSH_OFFER_KEX_ALGS);
    LW.PutNameList(SSH_OFFER_HOSTKEY_ALGS);
    LW.PutNameList(SSH_OFFER_CIPHER_ALGS);
    LW.PutNameList(SSH_OFFER_CIPHER_ALGS);
    LW.PutNameList(SSH_OFFER_MAC_ALGS);
    LW.PutNameList(SSH_OFFER_MAC_ALGS);
    if ACompress then
    begin
      LW.PutNameList(SSH_OFFER_COMP_ALGS_COMPRESS);
      LW.PutNameList(SSH_OFFER_COMP_ALGS_COMPRESS);
    end
    else
    begin
      LW.PutNameList(SSH_OFFER_COMP_ALGS);
      LW.PutNameList(SSH_OFFER_COMP_ALGS);
    end;
    LW.PutStringText('');
    LW.PutStringText('');
    LW.PutBoolean(False);
    LW.PutUInt32(0);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SshParseKexInit(const APayload: TBytes): TSshPeerKexInit;
var
  LR: TsshReader;
begin
  LR := TsshReader.Create(APayload);
  try
    if LR.ReadByte <> SSH_MSG_KEXINIT then
      raise ESSHError.Create(sekProtocol, 'ssh kex: payload is not KEXINIT');
    LR.Skip(16);                              { cookie：RFC 4253 §7.1 定长 16 字节 }
    Result.KexAlgs := LR.ReadNameList;
    Result.HostKeyAlgs := LR.ReadNameList;
    Result.EncCs := LR.ReadNameList;
    Result.EncSc := LR.ReadNameList;
    Result.MacCs := LR.ReadNameList;
    Result.MacSc := LR.ReadNameList;
    Result.CompCs := LR.ReadNameList;
    Result.CompSc := LR.ReadNameList;
    LR.ReadStringBytes;                       { languages c2s }
    LR.ReadStringBytes;                       { languages s2c }
    LR.ReadBoolean;                           { first_kex_packet_follows }
    LR.ReadUInt32;                            { reserved }
  finally
    LR.Free;
  end;
end;

procedure RequireAlg(var AField: string; const AWhat: string);
begin
  if AField = '' then
    raise ESSHError.Create(sekNegotiation, 'ssh kex: no mutual ' + AWhat);
end;

function SshNegotiate(const APeer: TSshPeerKexInit): TSshNegotiated;
begin
  Result := SshNegotiateEx(APeer, False);
end;

function SshNegotiateEx(const APeer: TSshPeerKexInit; ACompress: Boolean): TSshNegotiated;
begin
  Result.KexAlg := SshPickFirstMatch(SSH_OFFER_KEX_ALGS, APeer.KexAlgs);
  RequireAlg(Result.KexAlg, 'key exchange algorithm');
  Result.HostKeyAlg := SshPickFirstMatch(SSH_OFFER_HOSTKEY_ALGS, APeer.HostKeyAlgs);
  RequireAlg(Result.HostKeyAlg, 'host key algorithm');
  Result.EncCs := SshPickFirstMatch(SSH_OFFER_CIPHER_ALGS, APeer.EncCs);
  RequireAlg(Result.EncCs, 'client-to-server cipher');
  Result.EncSc := SshPickFirstMatch(SSH_OFFER_CIPHER_ALGS, APeer.EncSc);
  RequireAlg(Result.EncSc, 'server-to-client cipher');
  Result.MacCs := SshPickFirstMatch(SSH_OFFER_MAC_ALGS, APeer.MacCs);
  Result.MacSc := SshPickFirstMatch(SSH_OFFER_MAC_ALGS, APeer.MacSc);
  if (Result.MacCs = '') and SshCipherRequiresMac(Result.EncCs) then
    RequireAlg(Result.MacCs, 'client-to-server mac');
  if (Result.MacSc = '') and SshCipherRequiresMac(Result.EncSc) then
    RequireAlg(Result.MacSc, 'server-to-client mac');
  if ACompress then
  begin
    Result.CompCs := SshPickFirstMatch(SSH_OFFER_COMP_ALGS_COMPRESS, APeer.CompCs);
    Result.CompSc := SshPickFirstMatch(SSH_OFFER_COMP_ALGS_COMPRESS, APeer.CompSc);
  end
  else
  begin
    Result.CompCs := SshPickFirstMatch(SSH_OFFER_COMP_ALGS, APeer.CompCs);
    Result.CompSc := SshPickFirstMatch(SSH_OFFER_COMP_ALGS, APeer.CompSc);
  end;
  RequireAlg(Result.CompCs, 'client-to-server compression');
  RequireAlg(Result.CompSc, 'server-to-client compression');
end;

function SshKdfSha256(const AKMpint, AH: TBytes; AX: Byte;
  const ASessionId: TBytes; ALen: Integer): TBytes;
var
  LInput, LBlock, LPrev: TBytes;

  function Min64(A, B: Int64): Int64; inline;
  begin
    if A < B then
      Result := A
    else
      Result := B;
  end;

begin
  Result := nil;
  if ALen <= 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(LInput, 1);
  LInput[0] := AX;
  LPrev := SHA256(BytesConcatMany([AKMpint, AH, LInput, ASessionId]));
  Result := Copy(LPrev, 0, Min64(ALen, Length(LPrev)));
  while Length(Result) < ALen do
  begin
    LBlock := SHA256(BytesConcatMany([AKMpint, AH, LPrev]));
    BytesAppend(Result, LBlock);
    LPrev := LBlock;
  end;
  if Length(Result) > ALen then
    SetLength(Result, ALen);
end;

end.
