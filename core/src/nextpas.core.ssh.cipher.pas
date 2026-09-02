unit nextpas.core.ssh.cipher;

{** nextpas.core.ssh.cipher - 二进制包加密门面（四件套 facade）。
 *  纯 re-export + 工厂薄转发；实现按族拆至 chacha/gcm/etm/none 单源（<800 行软上限）。
 *  性能：FWriteBuf move 语义单次分配零拷贝（Result:=FWriteBuf; FWriteBuf:=nil）消除 COW 隐藏全量拷贝；
 *  单源 bytes.ops BytesEnsureCapacity + bytes.binary PutU32BE/U32BEOf inline；稳定性 SecureZero/Done 不丢。
 *  Owner 反哺：缺能力反哺 bytes.ops/crypto/hash，不堆 workaround。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.cipher.intf;

type
  ISshPacketSender = nextpas.core.ssh.cipher.intf.ISshPacketSender;
  ISshPacketReceiver = nextpas.core.ssh.cipher.intf.ISshPacketReceiver;

function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;

function SshCipherSupported(const ACipher: string): Boolean; inline;
function SshMacSupported(const AMac: string): Boolean; inline;
function SshCipherKeySize(const ACipher: string): Integer; inline;
function SshCipherIvSize(const ACipher: string): Integer; inline;
function SshMacKeySize(const AMac: string): Integer; inline;
function SshCipherRequiresMac(const ACipher: string): Boolean; inline;

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;

implementation

uses
  nextpas.core.ssh.cipher.none,
  nextpas.core.ssh.cipher.chacha,
  nextpas.core.ssh.cipher.gcm,
  nextpas.core.ssh.cipher.etm,
  nextpas.core.ssh.errors;

function SshCipherSupported(const ACipher: string): Boolean; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshCipherSupported(ACipher);
end;

function SshMacSupported(const AMac: string): Boolean; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshMacSupported(AMac);
end;

function SshCipherKeySize(const ACipher: string): Integer; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshCipherKeySize(ACipher);
end;

function SshCipherIvSize(const ACipher: string): Integer; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshCipherIvSize(ACipher);
end;

function SshMacKeySize(const AMac: string): Integer; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshMacKeySize(AMac);
end;

function SshCipherRequiresMac(const ACipher: string): Boolean; inline;
begin
  Result := nextpas.core.ssh.cipher.base.SshCipherRequiresMac(ACipher);
end;

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;
begin
  Result := nextpas.core.ssh.cipher.etm.SshAesCtrCrypt(AKey, AIV, AInput);
end;

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
