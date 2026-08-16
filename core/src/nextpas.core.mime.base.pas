unit nextpas.core.mime.base;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mime 基础类型与常量（L2 格式层）。
 * 单一职责：MIME 语法（RFC 2045/2046/2047/2231）的公共值类型与常量。
 * 本单元不承载任何解析/构建逻辑；解析在 mime.parser、构建在 mime.builder、
 * RFC 2047/2231 头编码在 mime.header。
 *
 * 与 nextpas.core.multipart 的边界：multipart 模块面向 HTTP form-data
 * （字节级分段器，"HTTP grammar only"）；本模块承载邮件 MIME 语法超集
 * （嵌套部件内嵌头 + multipart/mixed|alternative|related|digest 树）。
 * 语法层未来批次评估收敛，registry 记录分工。
 *}

interface

uses
  nextpas.core.errors;

{ 常用媒体类型（RFC 2046 §4/§5；小写规范） }
const
  MEDIA_TEXT_PLAIN            = 'text/plain';
  MEDIA_TEXT_HTML             = 'text/html';
  MEDIA_MULTIPART_MIXED       = 'multipart/mixed';
  MEDIA_MULTIPART_ALTERNATIVE = 'multipart/alternative';
  MEDIA_MULTIPART_RELATED     = 'multipart/related';
  MEDIA_MULTIPART_DIGEST      = 'multipart/digest';
  MEDIA_APPLICATION_OCTET     = 'application/octet-stream';

{ Content-Transfer-Encoding（RFC 2045 §6.2） }
const
  ENC_7BIT             = '7bit';
  ENC_8BIT             = '8bit';
  ENC_BINARY           = 'binary';
  ENC_QUOTED_PRINTABLE = 'quoted-printable';
  ENC_BASE64           = 'base64';

{ 结构化头关键字 }
const
  PARAM_BOUNDARY     = 'boundary';
  PARAM_CHARSET      = 'charset';
  PARAM_FILENAME     = 'filename';
  DISPOSITION_ATTACHMENT = 'attachment';
  DISPOSITION_INLINE     = 'inline';

{ 无界输入防护默认上限（INV-M3）：单消息最大字节数 / 嵌套部件最大深度 }
const
  MIME_DEFAULT_MAX_BYTES: Int64 = 64 * 1024 * 1024;
  MIME_DEFAULT_MAX_DEPTH  = 32;

type
  { EMimeError - RFC 2045/2046/2047/2231 家族根。
    继承 EParseError（ENextPasError 体系，带 Category/Inner 诊断），
    保证旧调用方以 EParseError 捕获零迁移；新调用方按家族精确捕获。 }
  EMimeError = class(EParseError);

  { 结构/语法违规：携带字节偏移与期望 token 于消息文本 }
  EMimeParseError = class(EMimeError);

  { RFC 2047/2231 编码失败 }
  EMimeEncodeError = class(EMimeError);

  { 超出大小/递归深度上限（INV-M3）}
  EMimeLimitError = class(EMimeError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  { 已解码参数（RFC 2231 展开后）：Name 小写归一，Value 为 UTF-8 }
  TMimeParameter = record
    Name: string;
    Value: string;
  end;
  TMimeParameterArray = array of TMimeParameter;

  { 头字段：Name 保留原始大小写（检索大小写不敏感，INV-M2），Value 已 unfold }
  TMimeHeader = record
    Name: string;
    Value: string;
  end;
  TMimeHeaderArray = array of TMimeHeader;

  { Content-Type 解析结果：media type 小写归一 }
  TMimeContentType = record
  public
    MediaType: string;
    Params: TMimeParameterArray;
    function Param(const AName: string): string;
    function CharSet: string;
    function Boundary: string;
    function Name: string;
    function IsMultipart: Boolean;
    function IsText: Boolean;
  end;

  { Content-Disposition 解析结果：disposition 小写归一 }
  TMimeContentDisposition = record
  public
    Disposition: string;
    Params: TMimeParameterArray;
    function Param(const AName: string): string;
    function FileName: string;
  end;

implementation

{ TMimeContentType }

function TMimeContentType.Param(const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(Params) - 1 do
    if LowerCase(Params[I].Name) = LowerCase(AName) then
      Exit(Params[I].Value);
  Result := '';
end;

function TMimeContentType.CharSet: string; begin Result := Param(PARAM_CHARSET); end;
function TMimeContentType.Boundary: string; begin Result := Param(PARAM_BOUNDARY); end;
function TMimeContentType.Name: string; begin Result := Param(PARAM_FILENAME); end;

function TMimeContentType.IsMultipart: Boolean;
begin
  Result := Copy(MediaType, 1, 10) = 'multipart/';
end;

function TMimeContentType.IsText: Boolean;
begin
  Result := Copy(MediaType, 1, 5) = 'text/';
end;

{ TMimeContentDisposition }

function TMimeContentDisposition.Param(const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(Params) - 1 do
    if LowerCase(Params[I].Name) = LowerCase(AName) then
      Exit(Params[I].Value);
  Result := '';
end;

function TMimeContentDisposition.FileName: string;
begin
  Result := Param(PARAM_FILENAME);
end;

{ EMimeLimitError }

class function EMimeLimitError.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;

end.