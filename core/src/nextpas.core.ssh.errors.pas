unit nextpas.core.ssh.errors;

{** nextpas.core.ssh - 异常类型。
 *
 * 统一异常入口 ESSHError，通过 Kind 区分失败类别；
 * 调用方按 core 惯例写直线代码，边界处统一捕获。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  { SSH 失败类别 }
  TSshErrorKind = (
    sekProtocol,     { 违反协议：帧损坏、字段越界、非法消息序 }
    sekDisconnect,   { 对端主动断开（SSH_MSG_DISCONNECT）}
    sekNegotiation,  { 双方无共同算法 }
    sekHostKey,      { 主机密钥校验失败 / known_hosts 不匹配 }
    sekAuth,         { 认证被拒绝 }
    sekKeyFormat,    { 密钥容器解析失败 }
    sekCrypto,       { AEAD/MAC 校验失败、加解密错误 }
    sekTimeout,      { 等待对端消息超时 }
    sekIO,           { 底层读写失败 / 对端关闭连接 }
    sekUnsupported   { 明确不支持的功能（如加密私钥容器）}
  );

  { SSH 模块统一异常 }
  ESSHError = class(Exception)
  private
    FKind: TSshErrorKind;
  public
    constructor Create(AKind: TSshErrorKind; const AMsg: string); reintroduce;
    property Kind: TSshErrorKind read FKind;
  end;

{ 错误类别的稳定名称（日志/测试断言用）}
function SshErrorKindName(AKind: TSshErrorKind): string;

implementation

constructor ESSHError.Create(AKind: TSshErrorKind; const AMsg: string);
begin
  inherited Create(AMsg);
  FKind := AKind;
end;

function SshErrorKindName(AKind: TSshErrorKind): string;
const
  NAMES: array[TSshErrorKind] of string = (
    'protocol', 'disconnect', 'negotiation', 'hostkey', 'auth',
    'key-format', 'crypto', 'timeout', 'io', 'unsupported'
  );
begin
  Result := NAMES[AKind];
end;

end.
