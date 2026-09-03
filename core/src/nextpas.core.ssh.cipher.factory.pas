unit nextpas.core.ssh.cipher.factory;

{** nextpas.core.ssh.cipher.factory - 包加密工厂实现（四件套 impl 层）。
 *  归拢 CreateSshPacketSender/Receiver 的分支与密钥切片逻辑，门面仅 inline 薄转发，
 *  守 base←intf←impl←facade 边界；分支与 Copy 切片下沉至实现层，门面零逻辑。
 *  性能：工厂内 Copy 为必要截断单次分配（SshCipherKeySize 定长 <64B），其余路径 FWriteBuf move 语义单次分配零拷贝由各实现侧（chacha/gcm/etm/none）经 bytes.ops BytesEnsureCapacity + bytes.binary inline 保证；inline 薄转发消除调用开销。
 *  稳定性：不支持算法抛 sekNegotiation，不泄漏；密钥材料由各实现 SecureZero/Done 负责清零。
 *  单源：密钥判定与尺寸表单源 base，FWriteBuf/bytes.ops/bytes.binary 单源由实现侧保证，工厂不复制逻辑；缺能力反哺 bytes.ops/crypto/hash。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.intf;

function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;

implementation

uses
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.cipher.none,
  nextpas.core.ssh.cipher.chacha,
  nextpas.core.ssh.cipher.gcm,
  nextpas.core.ssh.cipher.etm,
  nextpas.core.ssh.errors;

function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
begin
  if ACipher = '' then
    Exit(CreateNoneSender);
  if not nextpas.core.ssh.cipher.base.SshCipherSupported(ACipher) then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
  if nextpas.core.ssh.cipher.base.IsChachaName(ACipher) then
    Result := CreateChachaSender(AKey)
  else if nextpas.core.ssh.cipher.base.IsGcmName(ACipher) then
    Result := CreateGcmSender(Copy(AKey, 0, nextpas.core.ssh.cipher.base.SshCipherKeySize(ACipher)), AIV)
  else
    Result := CreateCtrEtmSender(ACipher, AMac,
      Copy(AKey, 0, nextpas.core.ssh.cipher.base.SshCipherKeySize(ACipher)), AIV, AMacKey);
end;

function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;
begin
  if ACipher = '' then
    Exit(CreateNoneReceiver);
  if not nextpas.core.ssh.cipher.base.SshCipherSupported(ACipher) then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
  if nextpas.core.ssh.cipher.base.IsChachaName(ACipher) then
    Result := CreateChachaReceiver(AKey)
  else if nextpas.core.ssh.cipher.base.IsGcmName(ACipher) then
    Result := CreateGcmReceiver(Copy(AKey, 0, nextpas.core.ssh.cipher.base.SshCipherKeySize(ACipher)), AIV)
  else
    Result := CreateCtrEtmReceiver(ACipher, AMac,
      Copy(AKey, 0, nextpas.core.ssh.cipher.base.SshCipherKeySize(ACipher)), AIV, AMacKey);
end;

end.
