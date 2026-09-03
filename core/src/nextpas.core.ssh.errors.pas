unit nextpas.core.ssh.errors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  TSshErrorKind = (
    sekProtocol,
    sekDisconnect,
    sekNegotiation,
    sekHostKey,
    sekAuth,
    sekKeyFormat,
    sekCryptoVerify,
    sekTimeout,
    sekIO,
    sekUnsupported,
    sekSftp,
    sekLimit
  );

  { ESSHError - SSH 域根异常 (CONTRACT §3) }
  ESSHError = class(Exception)
  private
    FKind: TSshErrorKind;
    FCode: Integer;
  public
    constructor Create(AKind: TSshErrorKind; const AMsg: string); reintroduce; overload;
    constructor Create(AKind: TSshErrorKind; const AMsg: string; ACode: Integer); reintroduce; overload;
    property Kind: TSshErrorKind read FKind;
    property Code: Integer read FCode;
  end;

const
  { 兼容别名：历史词汇漂移期单源复用新词表，复用 bytes.ops 单源外单点映射 }
  sekCrypto = sekCryptoVerify;
  sekBusy = sekLimit;

function SshErrorKindName(AKind: TSshErrorKind): string; inline;

implementation

constructor ESSHError.Create(AKind: TSshErrorKind; const AMsg: string);
begin
  inherited Create(AMsg);
  FKind := AKind;
  FCode := 0;
end;

constructor ESSHError.Create(AKind: TSshErrorKind; const AMsg: string; ACode: Integer);
begin
  inherited Create(AMsg);
  FKind := AKind;
  FCode := ACode;
end;

function SshErrorKindName(AKind: TSshErrorKind): string;
const
  NAMES: array[TSshErrorKind] of string = (
    'protocol',
    'disconnect',
    'negotiation',
    'hostkey',
    'auth',
    'key-format',
    'crypto-verify',
    'timeout',
    'io',
    'unsupported',
    'sftp',
    'limit'
  );
begin
  Result := NAMES[AKind];
end;

end.
