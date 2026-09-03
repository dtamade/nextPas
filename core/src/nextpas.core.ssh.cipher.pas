unit nextpas.core.ssh.cipher;

{** nextpas.core.ssh.cipher - 二进制包加密门面（四件套 facade）。
 *  纯 re-export + 工厂薄转发；分支与 Copy 切片已下沉至 cipher.factory 实现层，
 *  守 base←intf←impl←facade 边界；实现按族拆至 chacha/gcm/etm/none 单源（<800 行软上限）。
 *  性能：工厂 inline 薄转发、FWriteBuf move 语义单次分配零拷贝（Result:=FWriteBuf; FWriteBuf:=nil）消除 COW 隐藏全量拷贝；
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
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender; inline;
function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver; inline;

function SshCipherSupported(const ACipher: string): Boolean; inline;
function SshMacSupported(const AMac: string): Boolean; inline;
function SshCipherKeySize(const ACipher: string): Integer; inline;
function SshCipherIvSize(const ACipher: string): Integer; inline;
function SshMacKeySize(const AMac: string): Integer; inline;
function SshCipherRequiresMac(const ACipher: string): Boolean; inline;

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes; inline;

implementation

uses
  nextpas.core.ssh.cipher.factory,
  nextpas.core.ssh.cipher.etm;

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

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes; inline;
begin
  Result := nextpas.core.ssh.cipher.etm.SshAesCtrCrypt(AKey, AIV, AInput);
end;

function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender; inline;
begin
  Result := nextpas.core.ssh.cipher.factory.CreateSshPacketSender(ACipher, AMac, AKey, AIV, AMacKey);
end;

function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver; inline;
begin
  Result := nextpas.core.ssh.cipher.factory.CreateSshPacketReceiver(ACipher, AMac, AKey, AIV, AMacKey);
end;

end.
