unit nextpas.core.ssh.knownhosts;

{** nextpas.core.ssh.knownhosts - KnownHosts 独立协议帧模块（S27′ 晋升）。
 *
 *  将 hostkey.pas 内的 TSshKnownHosts + 解析/验签/指纹 提升为独立门面，
 *  供 core.net 隧道复用。形态：薄 facade + inline 转发，零额外堆分配。
 *  单源：全部委托 nextpas.core.ssh.hostkey；bytes 判定经 bytes.ops/TConstantTime。
 *  perf: inline 薄转发，零拷贝视图复用 hostkey 内部 Move；无二次分配。
 *  stability: 资源由 TSshKnownHosts 持有，Create/Free 配对，异常路径 SecureZero。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.base,
  nextpas.core.ssh.hostkey;

type
  TSshKnownHostsFacade = nextpas.core.ssh.hostkey.TSshKnownHosts;
  TSshHostKeyInfoFacade = nextpas.core.ssh.hostkey.TSshHostKeyInfo;
  IHostKeyFileReaderFacade = nextpas.core.ssh.hostkey.IHostKeyFileReader;

function SshParseHostKeyKnown(const ABlob: TBytes; out AInfo: TSshHostKeyInfoFacade): Boolean; inline;
function SshVerifyHostSignatureKnown(const AInfo: TSshHostKeyInfoFacade; const AAlgName: string; const AH: TBytes; const ASigBlob: TBytes): Boolean; inline;
function SshFingerprintSHA256Known(const ABlob: TBytes): string; inline;
function SshWildMatchKnown(const APattern, AValue: string): Boolean; inline;

implementation

function SshParseHostKeyKnown(const ABlob: TBytes; out AInfo: TSshHostKeyInfoFacade): Boolean;
begin
  Result := nextpas.core.ssh.hostkey.SshParseHostKey(ABlob, AInfo);
end;

function SshVerifyHostSignatureKnown(const AInfo: TSshHostKeyInfoFacade; const AAlgName: string; const AH: TBytes; const ASigBlob: TBytes): Boolean;
begin
  Result := nextpas.core.ssh.hostkey.SshVerifyHostSignature(AInfo, AAlgName, AH, ASigBlob);
end;

function SshFingerprintSHA256Known(const ABlob: TBytes): string;
begin
  Result := nextpas.core.ssh.hostkey.SshFingerprintSHA256(ABlob);
end;

function SshWildMatchKnown(const APattern, AValue: string): Boolean;
begin
  Result := nextpas.core.ssh.hostkey.SshWildMatch(APattern, AValue);
end;

end.
