unit nextpas.core.mail;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail 门面（L3）。
 * 聚合邮件域公共 API：地址/消息载体类型；SMTP 客户端与服务器会话。
 * 消费方默认只 uses 本单元。
 *}

interface

uses
  nextpas.core.mail.base,
  nextpas.core.mail.smtp,
  nextpas.core.mail.smtp.server,
  nextpas.core.mime;

type
  TMailAddress = nextpas.core.mail.base.TMailAddress;
  TMailAddressArray = nextpas.core.mail.base.TMailAddressArray;
  TMailAttachment = nextpas.core.mail.base.TMailAttachment;
  TMailMessage = nextpas.core.mail.base.TMailMessage;

  { smtp 客户端 }
  TSmtpReply = nextpas.core.mail.smtp.TSmtpReply;
  TSmtpCapabilities = nextpas.core.mail.smtp.TSmtpCapabilities;
  TSmtpClientConfig = nextpas.core.mail.smtp.TSmtpClientConfig;
  TSmtpClient = nextpas.core.mail.smtp.TSmtpClient;

  { smtp 服务器会话 }
  TMailSmtpServerEvent = nextpas.core.mail.smtp.server.TMailSmtpServerEvent;
  TMailSmtpEnvelope = nextpas.core.mail.smtp.server.TMailSmtpEnvelope;
  TMailSmtpServerConfig = nextpas.core.mail.smtp.server.TMailSmtpServerConfig;
  TMailSmtpServerSession = nextpas.core.mail.smtp.server.TMailSmtpServerSession;
  ISmtpServerSink = nextpas.core.mail.smtp.server.ISmtpServerSink;
  ISmtpMailPolicyHook = nextpas.core.mail.smtp.server.ISmtpMailPolicyHook;

const
  { smtp 服务器会话事件枚举值（FPC 枚举值不随类型别名传播，须显式 re-export） }
  msseMessage = nextpas.core.mail.smtp.server.msseMessage;
  msseTimeout = nextpas.core.mail.smtp.server.msseTimeout;
  msseOverflow = nextpas.core.mail.smtp.server.msseOverflow;
  msseClosed = nextpas.core.mail.smtp.server.msseClosed;

implementation

end.