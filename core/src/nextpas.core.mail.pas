unit nextpas.core.mail;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail 门面（L3）。
 * 聚合邮件域公共 API：地址/消息载体类型；SMTP/IMAP 客户端随批次扩展。
 * 消费方默认只 uses 本单元。
 *}

interface

uses
  nextpas.core.mail.base;

type
  TMailAddress = nextpas.core.mail.base.TMailAddress;
  TMailAddressArray = nextpas.core.mail.base.TMailAddressArray;
  TMailAttachment = nextpas.core.mail.base.TMailAttachment;
  TMailMessage = nextpas.core.mail.base.TMailMessage;

implementation

end.