unit nextpas.core.mail.base;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail 基础类型：邮件地址、附件、消息载体。
 * 本单元只承载公共载体类型，不含任何协议/IO 逻辑（L3，依赖 L0-L2）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  { EMailError - RFC 5322 邮件语义家族根。
    继承 EParseError（ENextPasError 体系，带 Category/Inner 诊断），
    与 mime 家族（EMimeError）并列，均从语法解析错误根派生。 }
  EMailError = class(EParseError);

  { 地址语法违规（严格模式）；消息文本携带原始输入 }
  EMailAddressError = class(EMailError);

  { 头字段语义违规（地址字段格式错误等）；消息文本携带字段名 }
  EMailHeaderError = class(EMailError);

  { 消息结构解析失败；消息文本携带段位置描述 }
  EMailParseError = class(EMailError);

  { TMailAddress - RFC 5322 邮件地址（值语义 record） }
  TMailAddress = record
  public
    DisplayName: string;  { 可选 display-name（已解引号） }
    LocalPart: string;
    Domain: string;
    function Full: string;       { local@domain（小写规范化） }
    function ToString: string;   { "Display Name" <local@domain> 完整形式 }
    function IsValid: Boolean;
    function Equals(const AOther: TMailAddress): Boolean;
    class function TryParse(const AValue: string; out AAddress: TMailAddress): Boolean; static;
    class function Parse(const AValue: string): TMailAddress; static;
    class function IsValidAddress(const AValue: string): Boolean; static;
  end;

  TMailAddressArray = array of TMailAddress;

  { TMailAttachment - 邮件附件元数据 + 数据 }
  TMailAttachment = record
    FileName: string;
    ContentType: string;
    ContentId: string;    { 内嵌资源 CID（可选） }
    Data: TBytes;
    function EstimatedSize: Int64;
  end;

  { TMailMessage - 归一化邮件消息（网关/协议层共用载体） }
  TMailMessage = record
    MessageId: string;
    From: TMailAddress;
    ToList: array of TMailAddress;
    CcList: array of TMailAddress;
    ReplyToList: array of TMailAddress;
    Subject: string;
    DateUtc: Int64;         { Unix 秒（UTC）；0=未知 }
    BodyText: string;
    BodyHtml: string;
    HasAttachments: Boolean;
    Attachments: array of TMailAttachment;
    function EstimatedSize: Int64;
  end;

implementation

uses
  nextpas.core.text.conv;

const
  MAX_ADDRESS_LENGTH = 254;   { RFC 5321 限制 }
  MAX_LOCAL_LENGTH   = 64;
  MAX_DOMAIN_LENGTH  = 253;

{ 本地部分合法字符：a-z A-Z 0-9 与 .-+_ （dot-atom 务实子集） }
function IsLocalChar(const C: Char): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or
            ((C >= 'A') and (C <= 'Z')) or
            ((C >= '0') and (C <= '9')) or
            (C = '.') or (C = '-') or (C = '+') or (C = '_');
end;

{ 域名 label 合法字符：字母数字与连字符，连字符不能首尾 }
function IsDomainLabelValid(const ALabel: string): Boolean;
var
  L: Integer;
  I: Integer;
begin
  L := Length(ALabel);
  if (L < 1) or (L > 63) then
    Exit(False);
  if (ALabel[1] = '-') or (ALabel[L] = '-') then
    Exit(False);
  for I := 1 to L do
    if not (((ALabel[I] >= 'a') and (ALabel[I] <= 'z')) or
            ((ALabel[I] >= 'A') and (ALabel[I] <= 'Z')) or
            ((ALabel[I] >= '0') and (ALabel[I] <= '9')) or
            (ALabel[I] = '-')) then
      Exit(False);
  Result := True;
end;

{ 解析 "Display Name" <local@domain> / local@domain / 裸 domain（缺省不认） }
function TryParseRaw(const AValue: string; out AAddress: TMailAddress): Boolean;
var
  LValue: string;
  LAt: Integer;
  LLocal: string;
  LDomain: string;
  LDot: Integer;
  I: Integer;
  LLabelStart: Integer;
  LLabel: string;
begin
  Result := False;
  AAddress := Default(TMailAddress);

  LValue := Trim(AValue);
  if LValue = '' then
    Exit;
  if Length(LValue) > MAX_ADDRESS_LENGTH then
    Exit;

  { 带 display-name 形式： "Name" <addr> }
  LAt := Pos('<', LValue);
  if LAt > 0 then
  begin
    if LValue[Length(LValue)] <> '>' then
      Exit;
    AAddress.DisplayName := Trim(Copy(LValue, 1, LAt - 1));
    LValue := Copy(LValue, LAt + 1, Length(LValue) - LAt - 1);
    { 去 display-name 包裹引号 }
    if (Length(AAddress.DisplayName) >= 2) and
       (AAddress.DisplayName[1] = '"') and
       (AAddress.DisplayName[Length(AAddress.DisplayName)] = '"') then
      AAddress.DisplayName := Copy(AAddress.DisplayName, 2, Length(AAddress.DisplayName) - 2);
  end;

  { 单 @ 分隔 }
  LAt := 0;
  for I := 1 to Length(LValue) do
    if LValue[I] = '@' then
    begin
      if LAt <> 0 then
        Exit;  { 多个 @ }
      LAt := I;
    end;
  if LAt = 0 then
    Exit;
  LLocal := Copy(LValue, 1, LAt - 1);
  LDomain := Copy(LValue, LAt + 1, Length(LValue) - LAt);
  if (LLocal = '') or (LDomain = '') then
    Exit;
  if Length(LLocal) > MAX_LOCAL_LENGTH then
    Exit;

  { 本地部分：dot-atom，点不能连续/首尾 }
  if (LLocal[1] = '.') or (LLocal[Length(LLocal)] = '.') then
    Exit;
  for I := 1 to Length(LLocal) do
  begin
    if not IsLocalChar(LLocal[I]) then
      Exit;
    if (LLocal[I] = '.') and (I < Length(LLocal)) and (LLocal[I + 1] = '.') then
      Exit;
  end;

  { 域：IP 字面量 [1.2.3.4] 或逐 label }
  if (LDomain[1] = '[') and (LDomain[Length(LDomain)] = ']') then
  begin
    { 简化：接受四段十进制（细校验归 EParseError 调用方可选） }
    LDomain := Copy(LDomain, 2, Length(LDomain) - 2);
    if LDomain = '' then
      Exit;
  end
  else
  begin
    LLabelStart := 1;
    for I := 1 to Length(LDomain) + 1 do
    begin
      if (I > Length(LDomain)) or (LDomain[I] = '.') then
      begin
        LLabel := Copy(LDomain, LLabelStart, I - LLabelStart);
        if not IsDomainLabelValid(LLabel) then
          Exit;
        LLabelStart := I + 1;
      end;
    end;
  end;

  AAddress.LocalPart := LowerCase(LLocal);
  AAddress.Domain := LowerCase(LDomain);
  Result := True;
end;

{ TMailAddress }

function TMailAddress.Full: string;
begin
  Result := LocalPart + '@' + Domain;
end;

function TMailAddress.ToString: string;
begin
  if DisplayName <> '' then
    Result := '"' + DisplayName + '" <' + Full + '>'
  else
    Result := Full;
end;

function TMailAddress.IsValid: Boolean;
begin
  Result := (LocalPart <> '') and (Domain <> '') and IsValidAddress(Full);
end;

function TMailAddress.Equals(const AOther: TMailAddress): Boolean;
begin
  Result := (LocalPart = AOther.LocalPart) and (Domain = AOther.Domain);
end;

class function TMailAddress.TryParse(const AValue: string;
  out AAddress: TMailAddress): Boolean;
begin
  Result := TryParseRaw(AValue, AAddress);
end;

class function TMailAddress.Parse(const AValue: string): TMailAddress;
begin
  if not TryParseRaw(AValue, Result) then
    raise EMailAddressError.Create('invalid mail address: ' + AValue);
end;

class function TMailAddress.IsValidAddress(const AValue: string): Boolean;
var
  LAddr: TMailAddress;
begin
  Result := TryParseRaw(AValue, LAddr);
end;

{ TMailAttachment }

function TMailAttachment.EstimatedSize: Int64;
begin
  Result := Int64(Length(Data)) + Int64(Length(FileName)) +
    Int64(Length(ContentType)) + Int64(Length(ContentId));
end;

{ TMailMessage }

function TMailMessage.EstimatedSize: Int64;
var
  I: Integer;
begin
  Result := Int64(Length(MessageId)) + Int64(Length(Subject)) +
    Int64(Length(BodyText)) + Int64(Length(BodyHtml)) +
    Int64(Length(From.Full));
  for I := 0 to Length(ToList) - 1 do
    Result := Result + Int64(Length(ToList[I].Full));
  for I := 0 to Length(CcList) - 1 do
    Result := Result + Int64(Length(CcList[I].Full));
  for I := 0 to Length(ReplyToList) - 1 do
    Result := Result + Int64(Length(ReplyToList[I].Full));
  for I := 0 to Length(Attachments) - 1 do
    Result := Result + Attachments[I].EstimatedSize;
end;

end.