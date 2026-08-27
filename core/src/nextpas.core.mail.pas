unit nextpas.core.mail;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail 门面（L3）。
 * 聚合邮件域公共 API：地址/消息载体类型；SMTP 客户端与服务器会话；
 * IMAP 服务器会话。
 * 消费方默认只 uses 本单元。
 *}

interface

uses
  nextpas.core.mail.base,
  nextpas.core.mail.smtp,
  nextpas.core.mail.smtp.server,
  nextpas.core.mail.imap.base,
  nextpas.core.mail.imap.server,
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
  ISmtpAuthHook = nextpas.core.mail.smtp.server.ISmtpAuthHook;
  ISmtpTlsUpgrade = nextpas.core.mail.smtp.server.ISmtpTlsUpgrade;
  ISmtpAuthedMailGate = nextpas.core.mail.smtp.server.ISmtpAuthedMailGate;

  { imap 服务器会话 }
  TImapSessionPhase = nextpas.core.mail.imap.base.TImapSessionPhase;
  TImapMailboxSnapshot = nextpas.core.mail.imap.base.TImapMailboxSnapshot;
  TImapMailRow = nextpas.core.mail.imap.base.TImapMailRow;
  TImapSearchPred = nextpas.core.mail.imap.base.TImapSearchPred;
  TImapAuthResult = nextpas.core.mail.imap.base.TImapAuthResult;
  TImapRevocationStatus = nextpas.core.mail.imap.base.TImapRevocationStatus;
  IImapLoginCheck = nextpas.core.mail.imap.base.IImapLoginCheck;
  IImapRevocationCheck = nextpas.core.mail.imap.base.IImapRevocationCheck;
  IImapMailboxStore = nextpas.core.mail.imap.base.IImapMailboxStore;
  TImapServerConfig = nextpas.core.mail.imap.base.TImapServerConfig;
  TMailImapServerEvent = nextpas.core.mail.imap.server.TMailImapServerEvent;
  IImapServerSink = nextpas.core.mail.imap.server.IImapServerSink;
  TMailImapServerSession = nextpas.core.mail.imap.server.TMailImapServerSession;

const
  { smtp 服务器会话事件枚举值（FPC 枚举值不随类型别名传播，须显式 re-export） }
  msseMessage = nextpas.core.mail.smtp.server.msseMessage;
  msseTimeout = nextpas.core.mail.smtp.server.msseTimeout;
  msseOverflow = nextpas.core.mail.smtp.server.msseOverflow;
  msseClosed = nextpas.core.mail.smtp.server.msseClosed;
  msseAuthed = nextpas.core.mail.smtp.server.msseAuthed;

  { imap 服务器会话事件枚举值 }
  iiseLogin = nextpas.core.mail.imap.server.iiseLogin;
  iiseLogout = nextpas.core.mail.imap.server.iiseLogout;
  iiseClosed = nextpas.core.mail.imap.server.iiseClosed;
  iiseOverflow = nextpas.core.mail.imap.server.iiseOverflow;
  iiseTimeout = nextpas.core.mail.imap.server.iiseTimeout;

implementation

end.