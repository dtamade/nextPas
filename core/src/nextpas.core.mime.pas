unit nextpas.core.mime;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mime - MIME 格式层门面（L2）。
 * re-export 子单元类型 + inline 转发函数；调用方只需 uses 本单元。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.mime.base,
  nextpas.core.mime.parser,
  nextpas.core.mime.builder,
  nextpas.core.mime.header,
  nextpas.core.io.intf;

const
  { 常量（base） }
  MEDIA_TEXT_PLAIN = nextpas.core.mime.base.MEDIA_TEXT_PLAIN;
  MEDIA_TEXT_HTML = nextpas.core.mime.base.MEDIA_TEXT_HTML;
  MEDIA_MULTIPART_MIXED = nextpas.core.mime.base.MEDIA_MULTIPART_MIXED;
  MEDIA_MULTIPART_ALTERNATIVE = nextpas.core.mime.base.MEDIA_MULTIPART_ALTERNATIVE;
  MEDIA_MULTIPART_RELATED = nextpas.core.mime.base.MEDIA_MULTIPART_RELATED;
  MEDIA_MULTIPART_DIGEST = nextpas.core.mime.base.MEDIA_MULTIPART_DIGEST;
  MEDIA_APPLICATION_OCTET = nextpas.core.mime.base.MEDIA_APPLICATION_OCTET;
  ENC_7BIT = nextpas.core.mime.base.ENC_7BIT;
  ENC_8BIT = nextpas.core.mime.base.ENC_8BIT;
  ENC_BINARY = nextpas.core.mime.base.ENC_BINARY;
  ENC_QUOTED_PRINTABLE = nextpas.core.mime.base.ENC_QUOTED_PRINTABLE;
  ENC_BASE64 = nextpas.core.mime.base.ENC_BASE64;
  PARAM_BOUNDARY = nextpas.core.mime.base.PARAM_BOUNDARY;
  PARAM_CHARSET = nextpas.core.mime.base.PARAM_CHARSET;
  PARAM_FILENAME = nextpas.core.mime.base.PARAM_FILENAME;
  DISPOSITION_ATTACHMENT = nextpas.core.mime.base.DISPOSITION_ATTACHMENT;
  DISPOSITION_INLINE = nextpas.core.mime.base.DISPOSITION_INLINE;
  MIME_DEFAULT_MAX_BYTES = 67108864;
  MIME_DEFAULT_MAX_DEPTH = 32;

type
  EMimeError = nextpas.core.mime.base.EMimeError;
  EMimeParseError = nextpas.core.mime.base.EMimeParseError;
  EMimeEncodeError = nextpas.core.mime.base.EMimeEncodeError;
  EMimeLimitError = nextpas.core.mime.base.EMimeLimitError;

  TMimeParameter = nextpas.core.mime.base.TMimeParameter;
  TMimeParameterArray = nextpas.core.mime.base.TMimeParameterArray;
  TMimeHeader = nextpas.core.mime.base.TMimeHeader;
  TMimeHeaderArray = nextpas.core.mime.base.TMimeHeaderArray;
  TMimeContentType = nextpas.core.mime.base.TMimeContentType;
  TMimeContentDisposition = nextpas.core.mime.base.TMimeContentDisposition;

  TMimeIssueKind = nextpas.core.mime.parser.TMimeIssueKind;
  TMimeIssue = nextpas.core.mime.parser.TMimeIssue;
  TMimeIssueArray = nextpas.core.mime.parser.TMimeIssueArray;
  TMimePart = nextpas.core.mime.parser.TMimePart;
  TMimeMessage = nextpas.core.mime.parser.TMimeMessage;

const
  { 枚举值 re-export（FPC 枚举值不随类型别名传播） }
  miNone = nextpas.core.mime.parser.miNone;
  miBadEncoding = nextpas.core.mime.parser.miBadEncoding;
  miBadDate = nextpas.core.mime.parser.miBadDate;
  miTruncatedMultipart = nextpas.core.mime.parser.miTruncatedMultipart;
  miBadHeader = nextpas.core.mime.parser.miBadHeader;
  miBadAddress = nextpas.core.mime.parser.miBadAddress;
  miUnknownTransferEncoding = nextpas.core.mime.parser.miUnknownTransferEncoding;
  miTooDeep = nextpas.core.mime.parser.miTooDeep;

{ --- header（RFC 2047/2231/折叠） --- }

function EncodeHeaderText(const AValue: string; const ACharset: string = 'UTF-8'): string; inline;
function DecodeHeaderText(const AValue: string): string; inline;
function EncodeParameterValue(const AValue: string): string; inline;
function DecodeParameterValue(const AValue: string): string; inline;
function UnfoldHeaderValue(const AValue: string): string; inline;
function SanitizeHeaderValue(const AValue: string): string; inline;
function IsAscii(const AValue: string): Boolean; inline;

{ --- parser --- }

function ParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string): Boolean; inline;
function TryParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string; out AIssues: TMimeIssueArray): Boolean; inline;
function ParseParameters(const AValue: string; out AParams: TMimeParameterArray): Boolean; inline;
function ParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean; inline;
procedure ParseContentDisposition(const AValue: string; out ADisp: TMimeContentDisposition); inline;
function HeaderValue(const AHeaders: TMimeHeaderArray; const AName: string): string; inline;
function DecodeBase64(const AEncoded: string; out AData: TBytes): Boolean; inline;
function DecodeQuotedPrintable(const AEncoded: string; out AData: TBytes): Boolean; inline;
function DecodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes; inline;
function ParseMessage(const AData: TBytes;
  const AMaxBytes: Int64 = 67108864;
  const AMaxDepth: Integer = 32): TMimeMessage; inline;
function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AIssues: TMimeIssueArray): Boolean; inline;
function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AError: string): Boolean; inline;
function IsValidBoundary(const ABoundary: string): Boolean; inline;

{ --- builder --- }

function EncodeBase64(const AData: TBytes): string; inline;
function EncodeQuotedPrintable(const AData: TBytes): string; inline;
function EncodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes; inline;
function GenerateBoundary: string; inline;
function BuildMessage(const AMsg: TMimeMessage): TBytes; inline;
procedure BuildMessageToStream(const AMsg: TMimeMessage; const AWriter: IStream); inline;

implementation

{ --- header --- }

function EncodeHeaderText(const AValue: string; const ACharset: string = 'UTF-8'): string;
begin
  Result := nextpas.core.mime.header.EncodeHeaderText(AValue, ACharset);
end;

function DecodeHeaderText(const AValue: string): string;
begin
  Result := nextpas.core.mime.header.DecodeHeaderText(AValue);
end;

function EncodeParameterValue(const AValue: string): string;
begin
  Result := nextpas.core.mime.header.EncodeParameterValue(AValue);
end;

function DecodeParameterValue(const AValue: string): string;
begin
  Result := nextpas.core.mime.header.DecodeParameterValue(AValue);
end;

function UnfoldHeaderValue(const AValue: string): string;
begin
  Result := nextpas.core.mime.header.UnfoldHeaderValue(AValue);
end;

function SanitizeHeaderValue(const AValue: string): string;
begin
  Result := nextpas.core.mime.header.SanitizeHeaderValue(AValue);
end;

function IsAscii(const AValue: string): Boolean;
begin
  Result := nextpas.core.mime.header.IsAscii(AValue);
end;

{ --- parser --- }

function ParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string): Boolean;
begin
  Result := nextpas.core.mime.parser.ParseHeaders(ARaw, AHeaders, ABody);
end;

function TryParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string; out AIssues: TMimeIssueArray): Boolean;
begin
  Result := nextpas.core.mime.parser.TryParseHeaders(ARaw, AHeaders, ABody, AIssues);
end;

function ParseParameters(const AValue: string; out AParams: TMimeParameterArray): Boolean;
begin
  Result := nextpas.core.mime.parser.ParseParameters(AValue, AParams);
end;

function ParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
begin
  Result := nextpas.core.mime.parser.ParseContentType(AValue, ACT);
end;

procedure ParseContentDisposition(const AValue: string; out ADisp: TMimeContentDisposition);
begin
  nextpas.core.mime.parser.ParseContentDisposition(AValue, ADisp);
end;

function HeaderValue(const AHeaders: TMimeHeaderArray; const AName: string): string;
begin
  Result := nextpas.core.mime.parser.HeaderValue(AHeaders, AName);
end;

function DecodeBase64(const AEncoded: string; out AData: TBytes): Boolean;
begin
  Result := nextpas.core.mime.parser.DecodeBase64(AEncoded, AData);
end;

function DecodeQuotedPrintable(const AEncoded: string; out AData: TBytes): Boolean;
begin
  Result := nextpas.core.mime.parser.DecodeQuotedPrintable(AEncoded, AData);
end;

function DecodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;
begin
  Result := nextpas.core.mime.parser.DecodeTransferEncoding(AEncoding, AData);
end;

function ParseMessage(const AData: TBytes;
  const AMaxBytes: Int64 = 67108864;
  const AMaxDepth: Integer = 32): TMimeMessage;
begin
  Result := nextpas.core.mime.parser.ParseMessage(AData, AMaxBytes, AMaxDepth);
end;

function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AIssues: TMimeIssueArray): Boolean;
begin
  Result := nextpas.core.mime.parser.TryParseMessage(AData, AMsg, AIssues);
end;

function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AError: string): Boolean;
begin
  Result := nextpas.core.mime.parser.TryParseMessage(AData, AMsg, AError);
end;

function IsValidBoundary(const ABoundary: string): Boolean;
begin
  Result := nextpas.core.mime.parser.IsValidBoundary(ABoundary);
end;

{ --- builder --- }

function EncodeBase64(const AData: TBytes): string;
begin
  Result := nextpas.core.mime.builder.EncodeBase64(AData);
end;

function EncodeQuotedPrintable(const AData: TBytes): string;
begin
  Result := nextpas.core.mime.builder.EncodeQuotedPrintable(AData);
end;

function EncodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;
begin
  Result := nextpas.core.mime.builder.EncodeTransferEncoding(AEncoding, AData);
end;

function GenerateBoundary: string;
begin
  Result := nextpas.core.mime.builder.GenerateBoundary;
end;

function BuildMessage(const AMsg: TMimeMessage): TBytes;
begin
  Result := nextpas.core.mime.builder.BuildMessage(AMsg);
end;

procedure BuildMessageToStream(const AMsg: TMimeMessage; const AWriter: IStream);
begin
  nextpas.core.mime.builder.BuildMessageToStream(AMsg, AWriter);
end;

end.