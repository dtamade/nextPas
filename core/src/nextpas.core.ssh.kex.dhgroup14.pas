unit nextpas.core.ssh.kex.dhgroup14;

{** nextpas.core.ssh - diffie-hellman-group14-sha256 客户端密钥交换。
 *
 * RFC 3526 §3 (2048-bit MODP Group 14, g=2) + RFC 4253 §8 交换散列。
 * p 为 256 字节素数，g=2；指数私钥 32 字节随机（256-bit），兼顾安全性与
 * 性能（与 OpenSSH 默认一致）。共享秘密 K 经 bigint 模幂，H = SHA256(
 *   V_C || V_S || I_C || I_S || K_S || e || f || K )，其中 e/f/K 为 mpint。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.kex;

function SshDHGroup14Prime: TBytes;
function SshDHGroup14Generator: TBytes;

{ RFC 4253 §8 交换哈希输入（DH group14 专用：e/f/K 为 mpint）}
function SshBuildDHGroup14HashInput(const AVc, AVs: string;
  const AClientKexInit, AServerKexInit, AHostKeyBlob,
  AClientE, AServerF, ASharedK: TBytes): TBytes;

type
  TSshKexDHGroup14Result = record
    SharedSecret: TBytes;
    ExchangeHashH: TBytes;
    ServerHostKeyBlob: TBytes;
    ServerSigBlob: TBytes;
  end;

  TSshKexDHGroup14 = class
  private
    FPriv: TBytes;
    FPub: TBytes;
    FPrime: TBytes;
    FGenerator: TBytes;
  public
    constructor Create;
    destructor Destroy; override;

    function AlgorithmName: string;
    property ClientE: TBytes read FPub;

    function BuildInitPayload: TBytes;

    function ProcessReply(const APayload: TBytes;
      const AVc, AVs: string;
      const AMyKexInit, APeerKexInit: TBytes;
      out AK, AH, AServerHostKeyBlob, AServerSigBlob: TBytes): Boolean;

    function ProcessReplyNamed(const APayload: TBytes;
      const AVc, AVs: string;
      const AMyKexInit, APeerKexInit: TBytes): TSshKexDHGroup14Result;
  end;

implementation

uses
  nextpas.core.crypto.random,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bigint,
  nextpas.core.mem.secure,
  nextpas.core.bytes.ops;

var
  GPrime: TBytes;
  GPrimeValid: Boolean;
  GGen: TBytes;
  GGenValid: Boolean;

function SshDHGroup14Prime: TBytes;
const
  P_HEX =
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1'
  + '29024E088A67CC74020BBEA63B139B22514A08798E3404DD'
  + 'EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF';
var
  I: Integer;

  function HexVal(C: Char): Byte; inline;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := 0;
    end;
  end;

begin
  // perf: cached 256-byte prime, single hex parse, zero-copy CoW share
  if GPrimeValid then
  begin
    Result := GPrime;
    Exit;
  end;
  SetLength(GPrime, Length(P_HEX) div 2);
  for I := 0 to High(GPrime) do
    GPrime[I] := (HexVal(P_HEX[2*I+1]) shl 4) or HexVal(P_HEX[2*I+2]);
  GPrimeValid := True;
  Result := GPrime;
end;

function SshDHGroup14Generator: TBytes;
begin
  // perf: single-byte g=2 cached, zero-copy CoW share
  if GGenValid then
  begin
    Result := GGen;
    Exit;
  end;
  SetLength(GGen, 1);
  GGen[0] := 2;
  GGenValid := True;
  Result := GGen;
end;

function SshBuildDHGroup14HashInput(const AVc, AVs: string;
  const AClientKexInit, AServerKexInit, AHostKeyBlob,
  AClientE, AServerF, ASharedK: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(2048);
  try
    LW.PutStringText(AVc);
    LW.PutStringText(AVs);
    LW.PutStringBytes(AClientKexInit);
    LW.PutStringBytes(AServerKexInit);
    LW.PutStringBytes(AHostKeyBlob);
    LW.PutMPInt(AClientE);
    LW.PutMPInt(AServerF);
    LW.PutMPInt(ASharedK);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

destructor TSshKexDHGroup14.Destroy;
begin
  SecureZeroBytes(FPriv);
  SecureZeroBytes(FPub);
  inherited;
end;

constructor TSshKexDHGroup14.Create;
var
  LPub: TBytes;
  LErr: string;
begin
  inherited Create;
  FPrime := SshDHGroup14Prime;
  FGenerator := SshDHGroup14Generator;
  FPriv := GenerateSecureRandomBytes(32);
  if (Length(FPriv) = 0) or IsZeroBytes(FPriv) then
  begin
    FPriv[0] := $7F;
    FPriv[High(FPriv)] := $01;
  end;
  if not TryBigIntModExpFromUnsignedBytes(FGenerator, FPriv, FPrime, LPub, LErr) then
    raise ESSHError.Create(sekCrypto, 'ssh kex dh group14: pub compute failed: ' + LErr);
  FPub := LPub;
end;

function TSshKexDHGroup14.AlgorithmName: string;
begin
  Result := 'diffie-hellman-group14-sha256';
end;

function TSshKexDHGroup14.BuildInitPayload: TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(512);
  try
    LW.PutByte(SSH_MSG_KEX_ECDH_INIT);
    LW.PutMPInt(FPub);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function TSshKexDHGroup14.ProcessReply(const APayload: TBytes;
  const AVc, AVs: string;
  const AMyKexInit, APeerKexInit: TBytes;
  out AK, AH, AServerHostKeyBlob, AServerSigBlob: TBytes): Boolean;
var
  LRes: TSshKexDHGroup14Result;
begin
  LRes := ProcessReplyNamed(APayload, AVc, AVs, AMyKexInit, APeerKexInit);
  AK := LRes.SharedSecret;
  AH := LRes.ExchangeHashH;
  AServerHostKeyBlob := LRes.ServerHostKeyBlob;
  AServerSigBlob := LRes.ServerSigBlob;
  Result := True;
end;

function TSshKexDHGroup14.ProcessReplyNamed(const APayload: TBytes;
  const AVc, AVs: string;
  const AMyKexInit, APeerKexInit: TBytes): TSshKexDHGroup14Result;
var
  LR: TsshReader;
  LServerF, LShared, LHashInput: TBytes;
  LPrime, LGen: TBytes;
  LErr: string;
begin
  LR := TsshReader.Create(APayload);
  try
    if LR.ReadByte <> SSH_MSG_KEX_ECDH_REPLY then
      raise ESSHError.Create(sekProtocol, 'ssh kex: payload is not KEXDH_REPLY');
    Result.ServerHostKeyBlob := LR.ReadStringBytes;
    LServerF := LR.ReadMPInt;
    Result.ServerSigBlob := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  if Length(LServerF) = 0 then
    raise ESSHError.Create(sekProtocol, 'ssh kex: server f empty');
  // perf: single fetch cached prime/gen, zero-copy CoW, bytes.ops single source
  LGen := SshDHGroup14Generator;
  LPrime := SshDHGroup14Prime;
  if (nextpas.core.bytes.ops.CompareUnsigned(LServerF, LGen) <= 0)
    or (nextpas.core.bytes.ops.CompareUnsigned(LServerF, LPrime) >= 0) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: server f out of range');
  if IsZeroBytes(LServerF) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: server f all zero');

  if not TryBigIntModExpFromUnsignedBytes(LServerF, FPriv, LPrime, LShared, LErr) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: dh shared compute failed: ' + LErr);
  if IsZeroBytes(LShared) then
    raise ESSHError.Create(sekProtocol, 'ssh kex: all-zero shared secret rejected');
  if nextpas.core.bytes.ops.CompareUnsigned(LShared, LPrime) >= 0 then
    raise ESSHError.Create(sekProtocol, 'ssh kex: shared secret out of range');

  Result.SharedSecret := LShared;
  LHashInput := SshBuildDHGroup14HashInput(AVc, AVs, AMyKexInit, APeerKexInit,
    Result.ServerHostKeyBlob, FPub, LServerF, LShared);
  Result.ExchangeHashH := SHA256(LHashInput);
end;

initialization
  GPrimeValid := False;
  GGenValid := False;

finalization
  GPrime := nil;
  GGen := nil;

end.
