unit nextpas.core.ssh.errors;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.base, nextpas.core.exception;
type TSshErrorKind=(sekProtocol,sekDisconnect,sekNegotiation,sekHostKey,sekAuth,sekKeyFormat,sekCrypto,sekTimeout,sekIO,sekSftp,sekBusy,sekUnsupported);
ESSHError=class(Exception) private FKind:TSshErrorKind; public constructor Create(AKind:TSshErrorKind; const AMsg:string); reintroduce; property Kind:TSshErrorKind read FKind; end;
function SshErrorKindName(AKind:TSshErrorKind):string; implementation constructor ESSHError.Create(AKind:TSshErrorKind; const AMsg:string); begin inherited Create(AMsg); FKind:=AKind; end; function SshErrorKindName(AKind:TSshErrorKind):string; const NAMES:array[TSshErrorKind] of string=('protocol','disconnect','negotiation','hostkey','auth','key-format','crypto','timeout','io','sftp','busy','unsupported'); begin Result:=NAMES[AKind]; end; end.
