unit nextpas.core.tls.asn1;

{$mode objfpc}{$H+}
{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$modeswitch advancedrecords}

{
  ASN.1/DER 解析器 - 纯 Pascal 实现

  用于解析 X.509 证书、PKCS 等格式的底层模块。
  支持 DER (Distinguished Encoding Rules) 编码。

  基本结构: TLV (Tag-Length-Value)
  - Tag: 数据类型标识
  - Length: 值的长度
  - Value: 实际数据

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.vec,
  nextpas.core.io.intf,
  nextpas.core.exception,
  nextpas.core.system.classes;

const
  // ========================================================================
  // ASN.1 标签类 (Tag Class) - 高2位
  // ========================================================================
  ASN1_CLASS_UNIVERSAL       = $00;  // 通用类型
  ASN1_CLASS_APPLICATION     = $40;  // 应用类型
  ASN1_CLASS_CONTEXT         = $80;  // 上下文类型
  ASN1_CLASS_PRIVATE         = $C0;  // 私有类型
  ASN1_CLASS_MASK            = $C0;

  // ========================================================================
  // ASN.1 结构标志 (Constructed) - 第5位
  // ========================================================================
  ASN1_CONSTRUCTED           = $20;  // 构造类型（包含子元素）
  ASN1_PRIMITIVE             = $00;  // 原始类型

  // ========================================================================
  // ASN.1 通用类型标签 (Universal Tags)
  // ========================================================================
  ASN1_TAG_EOC               = $00;  // End-of-Contents
  ASN1_TAG_BOOLEAN           = $01;  // 布尔值
  ASN1_TAG_INTEGER           = $02;  // 整数
  ASN1_TAG_BIT_STRING        = $03;  // 位串
  ASN1_TAG_OCTET_STRING      = $04;  // 字节串
  ASN1_TAG_NULL              = $05;  // 空值
  ASN1_TAG_OID               = $06;  // 对象标识符
  ASN1_TAG_OBJECT_DESCRIPTOR = $07;  // 对象描述符
  ASN1_TAG_EXTERNAL          = $08;  // 外部类型
  ASN1_TAG_REAL              = $09;  // 实数
  ASN1_TAG_ENUMERATED        = $0A;  // 枚举
  ASN1_TAG_EMBEDDED_PDV      = $0B;  // 嵌入PDV
  ASN1_TAG_UTF8STRING        = $0C;  // UTF-8字符串
  ASN1_TAG_RELATIVE_OID      = $0D;  // 相对OID
  ASN1_TAG_TIME              = $0E;  // 时间 (ASN.1 2008)
  // $0F 保留
  ASN1_TAG_SEQUENCE          = $10;  // 序列 (通常与 CONSTRUCTED 组合 = $30)
  ASN1_TAG_SET               = $11;  // 集合 (通常与 CONSTRUCTED 组合 = $31)
  ASN1_TAG_NUMERICSTRING     = $12;  // 数字字符串
  ASN1_TAG_PRINTABLESTRING   = $13;  // 可打印字符串
  ASN1_TAG_T61STRING         = $14;  // T61字符串 (TeletexString)
  ASN1_TAG_VIDEOTEXSTRING    = $15;  // 视频文本字符串
  ASN1_TAG_IA5STRING         = $16;  // IA5字符串 (ASCII)
  ASN1_TAG_UTCTIME           = $17;  // UTC时间
  ASN1_TAG_GENERALIZEDTIME   = $18;  // 通用时间
  ASN1_TAG_GRAPHICSTRING     = $19;  // 图形字符串
  ASN1_TAG_VISIBLESTRING     = $1A;  // 可见字符串
  ASN1_TAG_GENERALSTRING     = $1B;  // 通用字符串
  ASN1_TAG_UNIVERSALSTRING   = $1C;  // 通用字符串 (4字节)
  ASN1_TAG_CHARACTERSTRING   = $1D;  // 字符字符串
  ASN1_TAG_BMPSTRING         = $1E;  // BMP字符串 (2字节 Unicode)

  // 组合标签
  ASN1_TAG_SEQUENCE_OF       = ASN1_TAG_SEQUENCE or ASN1_CONSTRUCTED;  // $30
  ASN1_TAG_SET_OF            = ASN1_TAG_SET or ASN1_CONSTRUCTED;       // $31

type
  // ========================================================================
  // 异常类型
  // ========================================================================
  EASN1Exception = class(Exception);
  EASN1ParseException = class(EASN1Exception);
  EASN1InvalidDataException = class(EASN1Exception);

  // ========================================================================
  // ASN.1 标签类
  // ========================================================================
  TASN1TagClass = (
    asn1Universal,      // 通用类型
    asn1Application,    // 应用类型
    asn1Context,        // 上下文类型
    asn1Private         // 私有类型
  );

  // ========================================================================
  // ASN.1 标签信息
  // ========================================================================
  TASN1Tag = record
    TagClass: TASN1TagClass;  // 标签类
    Constructed: Boolean;      // 是否构造类型
    TagNumber: Cardinal;       // 标签号
    RawByte: Byte;            // 原始字节（单字节标签）

    function IsSequence: Boolean;
    function IsSet: Boolean;
    function IsContextTag(ANumber: Integer): Boolean;
    function ToString: string;
  end;

  // ========================================================================
  // ASN.1 节点 - 表示解析后的 DER 元素
  // ========================================================================
  TASN1Node = class;
  TASN1NodeList = class;

  TASN1Node = class
  private
    FTag: TASN1Tag;
    FHeaderLength: Integer;     // 标签+长度字段的总长度
    FContentLength: Int64;      // 内容长度
    FContentOffset: Int64;      // 内容在数据流中的偏移
    FRawData: TBytes;           // 原始数据（仅叶节点）
    FChildren: TASN1NodeList;   // 子节点（构造类型）
    FParent: TASN1Node;
  public
    constructor Create;
    destructor Destroy; override;

    // 属性
    property Tag: TASN1Tag read FTag write FTag;
    property HeaderLength: Integer read FHeaderLength write FHeaderLength;
    property ContentLength: Int64 read FContentLength write FContentLength;
    property ContentOffset: Int64 read FContentOffset write FContentOffset;
    property RawData: TBytes read FRawData write FRawData;
    property Children: TASN1NodeList read FChildren;
    property Parent: TASN1Node read FParent write FParent;

    // 总长度（头部+内容）
    function TotalLength: Int64;

    // 子节点访问
    function ChildCount: Integer;
    function GetChild(AIndex: Integer): TASN1Node;
    function FirstChild: TASN1Node;
    function LastChild: TASN1Node;

    // 类型检查
    function IsSequence: Boolean;
    function IsSet: Boolean;
    function IsInteger: Boolean;
    function IsOID: Boolean;
    function IsBitString: Boolean;
    function IsOctetString: Boolean;
    function IsUTF8String: Boolean;
    function IsPrintableString: Boolean;
    function IsIA5String: Boolean;
    function IsUTCTime: Boolean;
    function IsGeneralizedTime: Boolean;
    function IsNull: Boolean;
    function IsBoolean: Boolean;
    function IsContextTag(ANumber: Integer): Boolean;

    // 值提取
    function AsInteger: Int64;
    function AsBigInteger: TBytes;  // 大整数，返回原始字节
    function AsOID: string;         // 点分十进制 OID
    function AsString: string;      // 字符串类型
    function AsBoolean: Boolean;
    function AsDateTime: TDateTime;
    function AsBitString: TBytes;   // 位串内容
    function AsOctetString: TBytes; // 字节串内容

    // 调试
    function Dump(AIndent: Integer = 0): string;
  end;

  // ========================================================================
  // ASN.1 节点列表
  // ========================================================================
  TASN1NodeList = class
  private
    FList: specialize TVec<TASN1Node>;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TASN1Node;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(ANode: TASN1Node);
    procedure Clear;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TASN1Node read GetItem; default;
  end;

  // ========================================================================
  // ASN.1/DER 解析器
  // ========================================================================
  TASN1Reader = class
  private
    FData: TBytes;
    FPosition: Int64;
    FDataLength: Int64;

    function ReadByte: Byte;
    function PeekByte: Byte;
    function ReadTag: TASN1Tag;
    function ReadLengthField: Int64;
    function ReadBytes(ACount: Int64): TBytes;
    procedure Skip(ACount: Int64);
    function EOF: Boolean;
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AStream: IStream); overload;
    destructor Destroy; override;

    // 解析整个数据
    function Parse: TASN1Node;

    // 解析下一个节点
    function ParseNode: TASN1Node;

    // 当前位置
    property Position: Int64 read FPosition;
    property DataLength: Int64 read FDataLength;
  end;

  // ========================================================================
  // ASN.1/DER 生成器
  // ========================================================================
  TASN1Writer = class
  private
    FStream: nextpas.core.io.intf.IStream;
    FPositionStack: array of Int64;  // 用于跟踪序列/集合的起始位置
    FTagStack: array of Byte;        // 保存对应的标签

    procedure WriteTag(ATag: Byte);
    procedure WriteLength(ALength: Int64);
    procedure WriteBytes(const AData: TBytes);
    procedure PushPosition(ATag: Byte);
    procedure PopAndWriteLength;
  public
    constructor Create;
    destructor Destroy; override;

    // 写入原始类型
    procedure WriteNull;
    procedure WriteBoolean(AValue: Boolean);
    procedure WriteInteger(AValue: Int64);
    procedure WriteBigInteger(const AValue: TBytes);
    procedure WriteOID(const AOID: string);
    procedure WriteOctetString(const AData: TBytes);
    procedure WriteBitString(const AData: TBytes; AUnusedBits: Byte = 0);
    procedure WriteUTF8String(const AValue: string);
    procedure WritePrintableString(const AValue: string);
    procedure WriteIA5String(const AValue: string);
    procedure WriteUTCTime(AValue: TDateTime);
    procedure WriteGeneralizedTime(AValue: TDateTime);

    // 写入构造类型
    procedure BeginSequence;
    procedure EndSequence;
    procedure BeginSet;
    procedure EndSet;
    procedure BeginContextTag(ANumber: Integer; AConstructed: Boolean = True);
    procedure EndContextTag;

    // 写入原始数据
    procedure WriteRaw(const AData: TBytes);

    // 获取结果
    function GetData: TBytes;
    procedure Clear;
  end;

// ========================================================================
// 辅助函数
// ========================================================================

// OID 解析和格式化
function ParseOID(const AData: TBytes): string;
function EncodeOID(const AOID: string): TBytes;

// 常用 OID 名称
function OIDToName(const AOID: string): string;
function NameToOID(const AName: string): string;

// 标签名称
function TagToString(ATag: Byte): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.time,
  nextpas.core.text.conv,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.text.strings;


// ========================================================================
// 常用 OID 定义
// ========================================================================
type
  TOIDEntry = record
    OID: string;
    Name: string;
  end;

const
  OID_TABLE: array[0..53] of TOIDEntry = (
    // X.500 属性类型
    (OID: '2.5.4.3';  Name: 'CN'),              // CommonName
    (OID: '2.5.4.4';  Name: 'SN'),              // Surname
    (OID: '2.5.4.5';  Name: 'serialNumber'),
    (OID: '2.5.4.6';  Name: 'C'),               // Country
    (OID: '2.5.4.7';  Name: 'L'),               // Locality
    (OID: '2.5.4.8';  Name: 'ST'),              // State
    (OID: '2.5.4.9';  Name: 'street'),
    (OID: '2.5.4.10'; Name: 'O'),               // Organization
    (OID: '2.5.4.11'; Name: 'OU'),              // OrganizationalUnit
    (OID: '2.5.4.12'; Name: 'title'),
    (OID: '2.5.4.17'; Name: 'postalCode'),
    (OID: '2.5.4.42'; Name: 'GN'),              // GivenName
    (OID: '2.5.4.43'; Name: 'initials'),
    (OID: '2.5.4.46'; Name: 'dnQualifier'),
    (OID: '2.5.4.65'; Name: 'pseudonym'),

    // 证书扩展
    (OID: '2.5.29.14'; Name: 'subjectKeyIdentifier'),
    (OID: '2.5.29.15'; Name: 'keyUsage'),
    (OID: '2.5.29.17'; Name: 'subjectAltName'),
    (OID: '2.5.29.18'; Name: 'issuerAltName'),
    (OID: '2.5.29.19'; Name: 'basicConstraints'),
    (OID: '2.5.29.31'; Name: 'cRLDistributionPoints'),
    (OID: '2.5.29.32'; Name: 'certificatePolicies'),
    (OID: '2.5.29.35'; Name: 'authorityKeyIdentifier'),
    (OID: '2.5.29.37'; Name: 'extKeyUsage'),

    // 签名算法
    (OID: '1.2.840.113549.1.1.1';  Name: 'rsaEncryption'),
    (OID: '1.2.840.113549.1.1.5';  Name: 'sha1WithRSAEncryption'),
    (OID: '1.2.840.113549.1.1.11'; Name: 'sha256WithRSAEncryption'),
    (OID: '1.2.840.113549.1.1.12'; Name: 'sha384WithRSAEncryption'),
    (OID: '1.2.840.113549.1.1.13'; Name: 'sha512WithRSAEncryption'),
    (OID: '1.2.840.10045.4.3.2';   Name: 'ecdsa-with-SHA256'),
    (OID: '1.2.840.10045.4.3.3';   Name: 'ecdsa-with-SHA384'),
    (OID: '1.2.840.10045.4.3.4';   Name: 'ecdsa-with-SHA512'),
    (OID: '1.3.101.112';           Name: 'Ed25519'),
    (OID: '1.3.101.113';           Name: 'Ed448'),

    // 哈希算法
    (OID: '1.3.14.3.2.26';        Name: 'sha1'),
    (OID: '2.16.840.1.101.3.4.2.1'; Name: 'sha256'),
    (OID: '2.16.840.1.101.3.4.2.2'; Name: 'sha384'),
    (OID: '2.16.840.1.101.3.4.2.3'; Name: 'sha512'),

    // 椭圆曲线
    (OID: '1.2.840.10045.2.1';    Name: 'ecPublicKey'),
    (OID: '1.2.840.10045.3.1.7';  Name: 'prime256v1'),
    (OID: '1.3.132.0.34';         Name: 'secp384r1'),
    (OID: '1.3.132.0.35';         Name: 'secp521r1'),

    // PKCS
    (OID: '1.2.840.113549.1.7.1'; Name: 'data'),
    (OID: '1.2.840.113549.1.7.2'; Name: 'signedData'),
    (OID: '1.2.840.113549.1.9.1'; Name: 'emailAddress'),

    // Extended Key Usage
    (OID: '1.3.6.1.5.5.7.3.1'; Name: 'serverAuth'),
    (OID: '1.3.6.1.5.5.7.3.2'; Name: 'clientAuth'),
    (OID: '1.3.6.1.5.5.7.3.3'; Name: 'codeSigning'),
    (OID: '1.3.6.1.5.5.7.3.4'; Name: 'emailProtection'),
    (OID: '1.3.6.1.5.5.7.3.8'; Name: 'timeStamping'),
    (OID: '1.3.6.1.5.5.7.3.9'; Name: 'OCSPSigning'),

    // Authority Info Access
    (OID: '1.3.6.1.5.5.7.1.1';  Name: 'authorityInfoAccess'),
    (OID: '1.3.6.1.5.5.7.48.1'; Name: 'ocsp'),
    (OID: '1.3.6.1.5.5.7.48.2'; Name: 'caIssuers')
  );

// ========================================================================
// TASN1Tag
// ========================================================================

function TASN1Tag.IsSequence: Boolean;
begin
  Result := (TagClass = asn1Universal) and (TagNumber = ASN1_TAG_SEQUENCE) and Constructed;
end;

function TASN1Tag.IsSet: Boolean;
begin
  Result := (TagClass = asn1Universal) and (TagNumber = ASN1_TAG_SET) and Constructed;
end;

function TASN1Tag.IsContextTag(ANumber: Integer): Boolean;
begin
  Result := (TagClass = asn1Context) and (Integer(TagNumber) = ANumber);
end;

function TASN1Tag.ToString: string;
begin
  if TagClass = asn1Universal then
    Result := TagToString(TagNumber)
  else if TagClass = asn1Context then
    Result := nextpas.core.text.conv.Format('[%d]', [TagNumber])
  else if TagClass = asn1Application then
    Result := nextpas.core.text.conv.Format('[APPLICATION %d]', [TagNumber])
  else
    Result := nextpas.core.text.conv.Format('[PRIVATE %d]', [TagNumber]);

  if Constructed then
    Result := Result + ' CONSTRUCTED';
end;

// ========================================================================
// TASN1Node
// ========================================================================

constructor TASN1Node.Create;
begin
  inherited Create;
  FChildren := TASN1NodeList.Create;
  FParent := nil;
end;

destructor TASN1Node.Destroy;
begin
  inherited Destroy;
end;

function TASN1Node.TotalLength: Int64;
begin
  Result := FHeaderLength + FContentLength;
end;

function TASN1Node.ChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TASN1Node.GetChild(AIndex: Integer): TASN1Node;
begin
  Result := FChildren[AIndex];
end;

function TASN1Node.FirstChild: TASN1Node;
begin
  if FChildren.Count > 0 then
    Result := FChildren[0]
  else
    Result := nil;
end;

function TASN1Node.LastChild: TASN1Node;
begin
  if FChildren.Count > 0 then
    Result := FChildren[FChildren.Count - 1]
  else
    Result := nil;
end;

function TASN1Node.IsSequence: Boolean;
begin
  Result := FTag.IsSequence;
end;

function TASN1Node.IsSet: Boolean;
begin
  Result := FTag.IsSet;
end;

function TASN1Node.IsInteger: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_INTEGER);
end;

function TASN1Node.IsOID: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_OID);
end;

function TASN1Node.IsBitString: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_BIT_STRING);
end;

function TASN1Node.IsOctetString: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_OCTET_STRING);
end;

function TASN1Node.IsUTF8String: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_UTF8STRING);
end;

function TASN1Node.IsPrintableString: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_PRINTABLESTRING);
end;

function TASN1Node.IsIA5String: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_IA5STRING);
end;

function TASN1Node.IsUTCTime: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_UTCTIME);
end;

function TASN1Node.IsGeneralizedTime: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_GENERALIZEDTIME);
end;

function TASN1Node.IsNull: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_NULL);
end;

function TASN1Node.IsBoolean: Boolean;
begin
  Result := (FTag.TagClass = asn1Universal) and (FTag.TagNumber = ASN1_TAG_BOOLEAN);
end;

function TASN1Node.IsContextTag(ANumber: Integer): Boolean;
begin
  Result := FTag.IsContextTag(ANumber);
end;

function TASN1Node.AsInteger: Int64;
var
  I: Integer;
  Negative: Boolean;
begin
  if Length(FRawData) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  // 检查符号位
  Negative := (FRawData[0] and $80) <> 0;

  if Negative then
  begin
    // 负数：补码
    Result := -1;
    for I := 0 to Length(FRawData) - 1 do
      Result := (Result shl 8) or FRawData[I];
  end
  else
  begin
    Result := 0;
    for I := 0 to Length(FRawData) - 1 do
      Result := (Result shl 8) or FRawData[I];
  end;
end;

function TASN1Node.AsBigInteger: TBytes;
begin
  Result := Copy(FRawData, 0, Length(FRawData));
end;

function TASN1Node.AsOID: string;
begin
  Result := ParseOID(FRawData);
end;

function TASN1Node.AsString: string;

begin
  if Length(FRawData) = 0 then
  begin
    Result := '';
    Exit;
  end;

  case FTag.TagNumber of
    ASN1_TAG_UTF8STRING:
      Result := AnsiString(UTF8BytesToString(FRawData));
    ASN1_TAG_BMPSTRING:
      Result := AnsiString(BigEndianUnicodeBytesToString(FRawData));
    ASN1_TAG_UNIVERSALSTRING:
      // 4字节 Unicode - 简化处理
      Result := AnsiString(UTF8BytesToString(FRawData));
    else
      // PrintableString, IA5String, VisibleString 等使用 ASCII
      Result := AnsiString(ASCIIBytesToString(FRawData));
  end;
end;

function TASN1Node.AsBoolean: Boolean;
begin
  if Length(FRawData) = 0 then
    Result := False
  else
    Result := FRawData[0] <> 0;
end;

function TASN1Node.AsDateTime: TDateTime;
var
  S: string;
  Year, Month, Day, Hour, Min, Sec: Word;
begin
  S := AnsiString(ASCIIBytesToString(FRawData));

  if FTag.TagNumber = ASN1_TAG_UTCTIME then
  begin
    // YYMMDDhhmmssZ
    if Length(S) >= 12 then
    begin
      Year := StrToIntDef(Copy(S, 1, 2), 0);
      // Y2K 处理：00-49 -> 2000-2049, 50-99 -> 1950-1999
      if Year < 50 then
        Year := Year + 2000
      else
        Year := Year + 1900;
      Month := StrToIntDef(Copy(S, 3, 2), 1);
      Day := StrToIntDef(Copy(S, 5, 2), 1);
      Hour := StrToIntDef(Copy(S, 7, 2), 0);
      Min := StrToIntDef(Copy(S, 9, 2), 0);
      Sec := StrToIntDef(Copy(S, 11, 2), 0);
      Result := EncodeDate(Year, Month, Day) + EncodeTime(Hour, Min, Sec, 0);
    end
    else
      Result := 0;
  end
  else if FTag.TagNumber = ASN1_TAG_GENERALIZEDTIME then
  begin
    // YYYYMMDDhhmmssZ
    if Length(S) >= 14 then
    begin
      Year := StrToIntDef(Copy(S, 1, 4), 0);
      Month := StrToIntDef(Copy(S, 5, 2), 1);
      Day := StrToIntDef(Copy(S, 7, 2), 1);
      Hour := StrToIntDef(Copy(S, 9, 2), 0);
      Min := StrToIntDef(Copy(S, 11, 2), 0);
      Sec := StrToIntDef(Copy(S, 13, 2), 0);
      Result := EncodeDate(Year, Month, Day) + EncodeTime(Hour, Min, Sec, 0);
    end
    else
      Result := 0;
  end
  else
    Result := 0;
end;

function TASN1Node.AsBitString: TBytes;
begin
  if Length(FRawData) < 1 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 返回实际的位串数据（跳过第一个未使用位数字节）
  Result := Copy(FRawData, 1, Length(FRawData) - 1);
end;

function TASN1Node.AsOctetString: TBytes;
begin
  Result := Copy(FRawData, 0, Length(FRawData));
end;

function TASN1Node.Dump(AIndent: Integer): string;
var
  Indent: string;
  I: Integer;
  ValueStr: string;
begin
  Indent := StringOfChar(' ', AIndent * 2);

  Result := Indent + FTag.ToString;
  Result := Result + nextpas.core.text.conv.Format(' (len=%d)', [FContentLength]);

  // 显示值
  if not FTag.Constructed then
  begin
    case FTag.TagNumber of
      ASN1_TAG_INTEGER:
        if Length(FRawData) <= 8 then
          ValueStr := IntToStr(AsInteger)
        else
          ValueStr := nextpas.core.text.conv.Format('(big integer, %d bytes)', [Length(FRawData)]);
      ASN1_TAG_OID:
        ValueStr := AsOID + ' (' + OIDToName(AsOID) + ')';
      ASN1_TAG_BOOLEAN:
        if AsBoolean then ValueStr := 'TRUE' else ValueStr := 'FALSE';
      ASN1_TAG_NULL:
        ValueStr := 'NULL';
      ASN1_TAG_UTCTIME, ASN1_TAG_GENERALIZEDTIME:
        ValueStr := nextpas.core.time.DateTimeToStr(AsDateTime);
      ASN1_TAG_UTF8STRING, ASN1_TAG_PRINTABLESTRING, ASN1_TAG_IA5STRING,
      ASN1_TAG_VISIBLESTRING, ASN1_TAG_T61STRING, ASN1_TAG_BMPSTRING:
        ValueStr := '"' + AsString + '"';
      ASN1_TAG_BIT_STRING:
        ValueStr := nextpas.core.text.conv.Format('(%d bytes, unused=%d)', [Length(FRawData)-1, FRawData[0]]);
      ASN1_TAG_OCTET_STRING:
        ValueStr := nextpas.core.text.conv.Format('(%d bytes)', [Length(FRawData)]);
      else
        if Length(FRawData) > 0 then
          ValueStr := nextpas.core.text.conv.Format('(%d bytes)', [Length(FRawData)])
        else
          ValueStr := '';
    end;

    if ValueStr <> '' then
      Result := Result + ' : ' + ValueStr;
  end;

  Result := Result + LineEnding;

  // 递归显示子节点
  for I := 0 to FChildren.Count - 1 do
    Result := Result + FChildren[I].Dump(AIndent + 1);
end;

// ========================================================================
// TASN1NodeList
// ========================================================================

constructor TASN1NodeList.Create;
begin
  inherited Create;
  FList := specialize TVec<TASN1Node>.Create;
end;

destructor TASN1NodeList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TASN1NodeList.Add(ANode: TASN1Node);
begin
  FList.Push(ANode);
end;

procedure TASN1NodeList.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.GetCount - 1 do
    FList.Get(I).Free;
  FList.Clear;
end;

function TASN1NodeList.GetCount: Integer;
begin
  Result := FList.GetCount;
end;

function TASN1NodeList.GetItem(AIndex: Integer): TASN1Node;
begin
  Result := FList.Get(AIndex);
end;

// ========================================================================
// TASN1Reader
// ========================================================================

constructor TASN1Reader.Create(const AData: TBytes);
begin
  inherited Create;
  FDataLength := Length(AData);
  SetLength(FData, FDataLength);
  if FDataLength > 0 then
    Move(AData[0], FData[0], FDataLength);
  FPosition := 0;
end;

constructor TASN1Reader.Create(AStream: IStream);
begin
  inherited Create;
  FDataLength := AStream.Size - AStream.Position;
  SetLength(FData, FDataLength);
  if FDataLength > 0 then
    AStream.Read(FData[0], FDataLength);
  FPosition := 0;
end;

destructor TASN1Reader.Destroy;
begin
  FData := nil;
  inherited Destroy;
end;

function TASN1Reader.ReadByte: Byte;
begin
  if FPosition >= FDataLength then
    raise EASN1ParseException.Create('Unexpected end of data');
  Result := FData[FPosition];
  Inc(FPosition);
end;

function TASN1Reader.PeekByte: Byte;
begin
  if FPosition >= FDataLength then
    raise EASN1ParseException.Create('Unexpected end of data');
  Result := FData[FPosition];
end;

function TASN1Reader.ReadTag: TASN1Tag;
var
  B: Byte;
begin
  B := ReadByte;
  Result.RawByte := B;

  // 解析标签类
  case B and ASN1_CLASS_MASK of
    ASN1_CLASS_UNIVERSAL:    Result.TagClass := asn1Universal;
    ASN1_CLASS_APPLICATION:  Result.TagClass := asn1Application;
    ASN1_CLASS_CONTEXT:      Result.TagClass := asn1Context;
    ASN1_CLASS_PRIVATE:      Result.TagClass := asn1Private;
  end;

  // 解析构造标志
  Result.Constructed := (B and ASN1_CONSTRUCTED) <> 0;

  // 解析标签号
  Result.TagNumber := B and $1F;

  // 长格式标签号（多字节）
  if Result.TagNumber = $1F then
  begin
    Result.TagNumber := 0;
    repeat
      B := ReadByte;
      Result.TagNumber := (Result.TagNumber shl 7) or (B and $7F);
    until (B and $80) = 0;
  end;
end;

function TASN1Reader.ReadLengthField: Int64;
var
  B: Byte;
  NumOctets, I: Integer;
begin
  B := ReadByte;

  if (B and $80) = 0 then
  begin
    // 短格式: 长度在一个字节内
    Result := B;
  end
  else if B = $80 then
  begin
    // 不定长度（BER，DER 不使用）
    Result := -1;
  end
  else
  begin
    // 长格式: B and $7F = 后续长度字节数
    NumOctets := B and $7F;
    if NumOctets > 8 then
      raise EASN1ParseException.Create('Length field too long');

    Result := 0;
    for I := 1 to NumOctets do
    begin
      B := ReadByte;
      Result := (Result shl 8) or B;
    end;
  end;
end;

function TASN1Reader.ReadBytes(ACount: Int64): TBytes;
begin
  if FPosition + ACount > FDataLength then
    raise EASN1ParseException.Create('Unexpected end of data');

  SetLength(Result, ACount);
  if ACount > 0 then
  begin
    Move(FData[FPosition], Result[0], ACount);
    Inc(FPosition, ACount);
  end;
end;

procedure TASN1Reader.Skip(ACount: Int64);
begin
  if FPosition + ACount > FDataLength then
    raise EASN1ParseException.Create('Unexpected end of data');
  Inc(FPosition, ACount);
end;

function TASN1Reader.EOF: Boolean;
begin
  Result := FPosition >= FDataLength;
end;

function TASN1Reader.Parse: TASN1Node;
begin
  FPosition := 0;
  Result := ParseNode;
end;

function TASN1Reader.ParseNode: TASN1Node;
var
  StartPos: Int64;
  Child: TASN1Node;
  NodeStack: array of record
    Node: TASN1Node;
    EndPos: Int64;
  end;
  StackTop: Integer;
  CurrentNode: TASN1Node;
  CurrentEndPos: Int64;
  TempTag: TASN1Tag;
  TempLength: Int64;
  TempHeaderLen: Integer;
  TempContentOffset: Int64;
begin
  // 使用显式栈来避免递归（Free Pascal 递归 + 成员变量访问有问题）
  Result := nil;
  SetLength(NodeStack, 0);
  StackTop := -1;

  if EOF then
    Exit;

  // 创建根节点
  Result := TASN1Node.Create;
  try
    StartPos := FPosition;

    // 读取根节点的标签和长度
    Result.FTag := ReadTag;
    Result.FContentLength := ReadLengthField;
    Result.FHeaderLength := FPosition - StartPos;
    Result.FContentOffset := FPosition;

    if Result.FContentLength < 0 then
      raise EASN1ParseException.Create('Indefinite length not supported in DER');

    if FPosition + Result.FContentLength > FDataLength then
      raise EASN1ParseException.Create('Content length exceeds data size');

    if not Result.FTag.Constructed then
    begin
      // 根节点是原始类型
      Result.FRawData := ReadBytes(Result.FContentLength);
      Exit;
    end;

    // 根节点是构造类型，使用迭代处理
    // 初始化栈
    SetLength(NodeStack, 1);
    StackTop := 0;
    NodeStack[0].Node := Result;
    NodeStack[0].EndPos := FPosition + Result.FContentLength;

    while StackTop >= 0 do
    begin
      CurrentNode := NodeStack[StackTop].Node;
      CurrentEndPos := NodeStack[StackTop].EndPos;

      if FPosition >= CurrentEndPos then
      begin
        Dec(StackTop);
        Continue;
      end;

      StartPos := FPosition;
      TempTag := ReadTag;
      TempLength := ReadLengthField;
      TempHeaderLen := FPosition - StartPos;
      TempContentOffset := FPosition;

      if TempLength < 0 then
        raise EASN1ParseException.Create('Indefinite length not supported in DER');

      if FPosition + TempLength > FDataLength then
        raise EASN1ParseException.Create('Content length exceeds data size');

      Child := TASN1Node.Create;
      Child.FTag := TempTag;
      Child.FContentLength := TempLength;
      Child.FHeaderLength := TempHeaderLen;
      Child.FContentOffset := TempContentOffset;
      Child.FParent := CurrentNode;
      CurrentNode.FChildren.Add(Child);

      if TempTag.Constructed then
      begin
        Inc(StackTop);
        if StackTop > 128 then
          raise EASN1ParseException.Create('ASN.1 nesting depth exceeds maximum (128)');
        if StackTop >= Length(NodeStack) then
          SetLength(NodeStack, Length(NodeStack) * 2 + 1);
        NodeStack[StackTop].Node := Child;
        NodeStack[StackTop].EndPos := FPosition + TempLength;
      end
      else
      begin
        Child.FRawData := ReadBytes(TempLength);
      end;
    end;
  except
    Result := nil;
    raise;
  end;
end;

// ========================================================================
// TASN1Writer
// ========================================================================

constructor TASN1Writer.Create;
begin
  inherited Create;
  FStream := CreateBytesStream;
end;

destructor TASN1Writer.Destroy;
begin
  FStream := nil;
  inherited Destroy;
end;

procedure TASN1Writer.WriteTag(ATag: Byte);
begin
  FStream.Write(ATag, SizeOf(ATag));
end;

procedure TASN1Writer.WriteLength(ALength: Int64);
var
  LenBytes: array[0..7] of Byte;
  NumBytes, I: Integer;
  Temp: Int64;
begin
  if ALength < 128 then
  begin
    // 短格式
    LenBytes[0] := Byte(ALength);
    FStream.Write(LenBytes[0], SizeOf(Byte));
  end
  else
  begin
    // 长格式
    Temp := ALength;
    NumBytes := 0;
    while Temp > 0 do
    begin
      LenBytes[NumBytes] := Byte(Temp and $FF);
      Temp := Temp shr 8;
      Inc(NumBytes);
    end;

    LenBytes[0] := $80 or NumBytes;
    FStream.Write(LenBytes[0], SizeOf(Byte));
    for I := NumBytes - 1 downto 0 do
      FStream.Write(LenBytes[I], SizeOf(Byte));
  end;
end;

procedure TASN1Writer.WriteBytes(const AData: TBytes);
begin
  if Length(AData) > 0 then
    FStream.Write(AData[0], Length(AData));
end;

procedure TASN1Writer.PushPosition(ATag: Byte);
var
  Len: Integer;
  Placeholder: array[0..4] of Byte;
begin
  // 写入标签
  WriteTag(ATag);
  // 保存当前位置（长度字段开始的位置）
  Len := Length(FPositionStack);
  SetLength(FPositionStack, Len + 1);
  SetLength(FTagStack, Len + 1);
  FPositionStack[Len] := FStream.Position;
  FTagStack[Len] := ATag;
  FStream.Write(Placeholder[0], SizeOf(Placeholder));
end;

procedure TASN1Writer.PopAndWriteLength;
var
  StackLen: Integer;
  StartPos, EndPos, ContentLen: Int64;
  LengthBytes: array[0..4] of Byte;
  LengthSize: Integer;
  ContentData: TBytes;
  PrefixData: TBytes;
  SuffixData: TBytes;
  ReaderAt: IReaderAt;
  WriterAt: IWriterAt;
  NewStream: nextpas.core.io.intf.IStream;
  PrefixLen: Int64;
  SuffixLen: Int64;
  NewPos: Int64;
begin
  StackLen := Length(FPositionStack);
  if StackLen = 0 then
    Exit;

  // 弹出栈顶位置
  StartPos := FPositionStack[StackLen - 1];
  SetLength(FPositionStack, StackLen - 1);
  SetLength(FTagStack, StackLen - 1);

  // 计算内容长度
  EndPos := FStream.Position;
  ContentLen := EndPos - StartPos - 5;  // 减去占位符长度

  // 编码长度
  if ContentLen < 128 then
  begin
    LengthBytes[0] := Byte(ContentLen);
    LengthSize := 1;
  end
  else if ContentLen <= $FF then
  begin
    LengthBytes[0] := $81;
    LengthBytes[1] := Byte(ContentLen);
    LengthSize := 2;
  end
  else if ContentLen <= $FFFF then
  begin
    LengthBytes[0] := $82;
    LengthBytes[1] := Byte(ContentLen shr 8);
    LengthBytes[2] := Byte(ContentLen);
    LengthSize := 3;
  end
  else if ContentLen <= $FFFFFF then
  begin
    LengthBytes[0] := $83;
    LengthBytes[1] := Byte(ContentLen shr 16);
    LengthBytes[2] := Byte(ContentLen shr 8);
    LengthBytes[3] := Byte(ContentLen);
    LengthSize := 4;
  end
  else
  begin
    LengthBytes[0] := $84;
    LengthBytes[1] := Byte(ContentLen shr 24);
    LengthBytes[2] := Byte(ContentLen shr 16);
    LengthBytes[3] := Byte(ContentLen shr 8);
    LengthBytes[4] := Byte(ContentLen);
    LengthSize := 5;
  end;

  // 读取内容
  SetLength(ContentData, ContentLen);
  if ContentLen > 0 then
  begin
    if not Supports(FStream, IReaderAt, ReaderAt) then
      raise EASN1InvalidDataException.Create('ASN.1 writer stream does not support ReadAt');
    if ReaderAt.ReadAt(ContentData[0], ContentLen, StartPos + 5) <> SizeUInt(ContentLen) then
      raise EASN1ParseException.Create('Unexpected end of writer content while backfilling length');
  end;

  if LengthSize = 5 then
  begin
    if not Supports(FStream, IWriterAt, WriterAt) then
      raise EASN1InvalidDataException.Create('ASN.1 writer stream does not support WriteAt');
    if WriterAt.WriteAt(LengthBytes[0], LengthSize, StartPos) <> SizeUInt(LengthSize) then
      raise EASN1ParseException.Create('Failed to backfill ASN.1 length');
    FStream.Position := EndPos;
    Exit;
  end;

  PrefixLen := StartPos;
  SuffixLen := FStream.Size - EndPos;
  NewStream := CreateBytesStream;

  if PrefixLen > 0 then
  begin
    SetLength(PrefixData, PrefixLen);
    if not Supports(FStream, IReaderAt, ReaderAt) then
      raise EASN1InvalidDataException.Create('ASN.1 writer stream does not support ReadAt');
    if ReaderAt.ReadAt(PrefixData[0], PrefixLen, 0) <> SizeUInt(PrefixLen) then
      raise EASN1ParseException.Create('Unexpected end of ASN.1 prefix while rebuilding stream');
    NewStream.Write(PrefixData[0], PrefixLen);
  end;

  NewStream.Write(LengthBytes[0], LengthSize);
  if ContentLen > 0 then
    NewStream.Write(ContentData[0], ContentLen);

  if SuffixLen > 0 then
  begin
    SetLength(SuffixData, SuffixLen);
    if ReaderAt.ReadAt(SuffixData[0], SuffixLen, EndPos) <> SizeUInt(SuffixLen) then
      raise EASN1ParseException.Create('Unexpected end of ASN.1 suffix while rebuilding stream');
    NewStream.Write(SuffixData[0], SuffixLen);
  end;

  NewPos := StartPos + LengthSize + ContentLen;
  FStream := NewStream;
  FStream.Position := NewPos;
end;

procedure TASN1Writer.WriteNull;
begin
  WriteTag(ASN1_TAG_NULL);
  WriteLength(0);
end;

procedure TASN1Writer.WriteBoolean(AValue: Boolean);
begin
  WriteTag(ASN1_TAG_BOOLEAN);
  WriteLength(1);
  if AValue then
    WriteTag($FF)
  else
    WriteTag($00);
end;

procedure TASN1Writer.WriteInteger(AValue: Int64);
var
  Data: TBytes;
  Negative: Boolean;
  Temp: UInt64;
  I, Len: Integer;
begin
  Negative := AValue < 0;

  if AValue = 0 then
  begin
    SetLength(Data, 1);
    Data[0] := 0;
  end
  else
  begin
    if Negative then
      Temp := UInt64(AValue)
    else
      Temp := UInt64(AValue);

    // 计算需要的字节数
    Len := 0;
    while Temp > 0 do
    begin
      Inc(Len);
      Temp := Temp shr 8;
    end;

    SetLength(Data, Len);
    Temp := UInt64(AValue);
    for I := Len - 1 downto 0 do
    begin
      Data[I] := Byte(Temp and $FF);
      Temp := Temp shr 8;
    end;

    // 确保正数的最高位不是1（否则会被解释为负数）
    if (not Negative) and ((Data[0] and $80) <> 0) then
    begin
      SetLength(Data, Length(Data) + 1);
      Move(Data[0], Data[1], Length(Data) - 1);
      Data[0] := 0;
    end;
  end;

  WriteTag(ASN1_TAG_INTEGER);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteBigInteger(const AValue: TBytes);
var
  Data: TBytes;
begin
  if Length(AValue) = 0 then
  begin
    SetLength(Data, 1);
    Data[0] := 0;
  end
  else if (AValue[0] and $80) <> 0 then
  begin
    // 需要前导零
    SetLength(Data, Length(AValue) + 1);
    Data[0] := 0;
    Move(AValue[0], Data[1], Length(AValue));
  end
  else
    Data := Copy(AValue, 0, Length(AValue));

  WriteTag(ASN1_TAG_INTEGER);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteOID(const AOID: string);
var
  Data: TBytes;
begin
  Data := EncodeOID(AOID);
  WriteTag(ASN1_TAG_OID);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteOctetString(const AData: TBytes);
begin
  WriteTag(ASN1_TAG_OCTET_STRING);
  WriteLength(Length(AData));
  WriteBytes(AData);
end;

procedure TASN1Writer.WriteBitString(const AData: TBytes; AUnusedBits: Byte);
begin
  WriteTag(ASN1_TAG_BIT_STRING);
  WriteLength(Length(AData) + 1);
  FStream.Write(AUnusedBits, SizeOf(AUnusedBits));
  WriteBytes(AData);
end;

procedure TASN1Writer.WriteUTF8String(const AValue: string);
var
  Data: TBytes;
begin
  Data := StringToUTF8Bytes(AValue);
  WriteTag(ASN1_TAG_UTF8STRING);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WritePrintableString(const AValue: string);
var
  Data: TBytes;
begin
  Data := StringToASCIIBytes(AValue);
  WriteTag(ASN1_TAG_PRINTABLESTRING);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteIA5String(const AValue: string);
var
  Data: TBytes;
begin
  Data := StringToASCIIBytes(AValue);
  WriteTag(ASN1_TAG_IA5STRING);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteUTCTime(AValue: TDateTime);
var
  Y, M, D, H, Mi, S, MS: Word;
  TimeStr: string;
  Data: TBytes;
begin
  DecodeDate(AValue, Y, M, D);
  DecodeTime(AValue, H, Mi, S, MS);

  // UTCTime: YYMMDDhhmmssZ
  TimeStr := nextpas.core.text.conv.Format('%.2d%.2d%.2d%.2d%.2d%.2dZ', [Y mod 100, M, D, H, Mi, S]);
  Data := StringToASCIIBytes(TimeStr);

  WriteTag(ASN1_TAG_UTCTIME);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.WriteGeneralizedTime(AValue: TDateTime);
var
  Y, M, D, H, Mi, S, MS: Word;
  TimeStr: string;
  Data: TBytes;
begin
  DecodeDate(AValue, Y, M, D);
  DecodeTime(AValue, H, Mi, S, MS);

  // GeneralizedTime: YYYYMMDDhhmmssZ
  TimeStr := nextpas.core.text.conv.Format('%.4d%.2d%.2d%.2d%.2d%.2dZ', [Y, M, D, H, Mi, S]);
  Data := StringToASCIIBytes(TimeStr);

  WriteTag(ASN1_TAG_GENERALIZEDTIME);
  WriteLength(Length(Data));
  WriteBytes(Data);
end;

procedure TASN1Writer.BeginSequence;
begin
  PushPosition(ASN1_TAG_SEQUENCE_OF);
end;

procedure TASN1Writer.EndSequence;
begin
  PopAndWriteLength;
end;

procedure TASN1Writer.BeginSet;
begin
  PushPosition(ASN1_TAG_SET_OF);
end;

procedure TASN1Writer.EndSet;
begin
  PopAndWriteLength;
end;

procedure TASN1Writer.BeginContextTag(ANumber: Integer; AConstructed: Boolean);
var
  Tag: Byte;
begin
  Tag := ASN1_CLASS_CONTEXT or Byte(ANumber and $1F);
  if AConstructed then
    Tag := Tag or ASN1_CONSTRUCTED;
  PushPosition(Tag);
end;

procedure TASN1Writer.EndContextTag;
begin
  PopAndWriteLength;
end;

procedure TASN1Writer.WriteRaw(const AData: TBytes);
begin
  WriteBytes(AData);
end;

function TASN1Writer.GetData: TBytes;
begin
  SetLength(Result, FStream.Size);
  if FStream.Size > 0 then
  begin
    FStream.Position := 0;
    IoReadFull(FStream, Result[0], SizeUInt(FStream.Size));
  end;
end;

procedure TASN1Writer.Clear;
begin
  FStream := CreateBytesStream;
  SetLength(FPositionStack, 0);
  SetLength(FTagStack, 0);
end;

// ========================================================================
// 辅助函数实现
// ========================================================================

function ParseOID(const AData: TBytes): string;
var
  I: Integer;
  Value: Cardinal;
  First, Second: Cardinal;
begin
  if Length(AData) = 0 then
  begin
    Result := '';
    Exit;
  end;

  // 第一个字节编码前两个组件: first * 40 + second
  First := AData[0] div 40;
  Second := AData[0] mod 40;

  // 修正: 如果 first >= 2，second 可能大于 39
  if First > 2 then
  begin
    Second := Second + (First - 2) * 40;
    First := 2;
  end;

  Result := IntToStr(First) + '.' + IntToStr(Second);

  // 解析后续组件（变长编码）
  I := 1;
  while I < Length(AData) do
  begin
    Value := 0;
    while (I < Length(AData)) and ((AData[I] and $80) <> 0) do
    begin
      Value := (Value shl 7) or (AData[I] and $7F);
      Inc(I);
    end;
    if I < Length(AData) then
    begin
      Value := (Value shl 7) or AData[I];
      Inc(I);
    end;
    Result := Result + '.' + IntToStr(Value);
  end;
end;

function EncodeOID(const AOID: string): TBytes;
var
  Parts: TStringArray;
  I: Integer;
  First, Second, Value: Cardinal;
  TempBytes: array of Byte;
  ResultStream: nextpas.core.io.intf.IStream;
  ByteWriter: IByteWriter;

  procedure EncodeComponent(AValue: Cardinal);
  var
    J, Count: Integer;
  begin
    if AValue = 0 then
    begin
      ByteWriter.WriteByte(0);
    end
    else
    begin
      // 计算需要的字节数
      Count := 0;
      Value := AValue;
      while Value > 0 do
      begin
        Inc(Count);
        Value := Value shr 7;
      end;

      SetLength(TempBytes, Count);
      for J := Count - 1 downto 0 do
      begin
        TempBytes[J] := Byte(AValue and $7F);
        if J < Count - 1 then
          TempBytes[J] := TempBytes[J] or $80;
        AValue := AValue shr 7;
      end;

      ResultStream.Write(TempBytes[0], Count);
    end;
  end;

begin
  ResultStream := CreateBytesStream;
  if not Supports(ResultStream, IByteWriter, ByteWriter) then
    raise EASN1InvalidDataException.Create('ASN.1 OID encoder requires byte-writable stream');
  Parts := StringsSplit(AOID, '.', True);

  if Length(Parts) < 2 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 编码前两个组件
  First := StrToIntDef(Parts[0], 0);
  Second := StrToIntDef(Parts[1], 0);
  ByteWriter.WriteByte(Byte(First * 40 + Second));

  // 编码后续组件
  for I := 2 to Length(Parts) - 1 do
  begin
    Value := StrToIntDef(Parts[I], 0);
    EncodeComponent(Value);
  end;

  SetLength(Result, ResultStream.Size);
  ResultStream.Position := 0;
  if ResultStream.Size > 0 then
    IoReadFull(ResultStream, Result[0], SizeUInt(ResultStream.Size));
end;

function OIDToName(const AOID: string): string;
var
  I: Integer;
begin
  for I := Low(OID_TABLE) to High(OID_TABLE) do
  begin
    if OID_TABLE[I].OID = AOID then
    begin
      Result := OID_TABLE[I].Name;
      Exit;
    end;
  end;
  Result := AOID;  // 未知 OID 返回原始值
end;

function NameToOID(const AName: string): string;
var
  I: Integer;
  UpperName: string;
begin
  UpperName := UpperCase(AName);
  for I := Low(OID_TABLE) to High(OID_TABLE) do
  begin
    if UpperCase(OID_TABLE[I].Name) = UpperName then
    begin
      Result := OID_TABLE[I].OID;
      Exit;
    end;
  end;
  Result := '';  // 未找到
end;

function TagToString(ATag: Byte): string;
begin
  case ATag of
    ASN1_TAG_EOC:             Result := 'EOC';
    ASN1_TAG_BOOLEAN:         Result := 'BOOLEAN';
    ASN1_TAG_INTEGER:         Result := 'INTEGER';
    ASN1_TAG_BIT_STRING:      Result := 'BIT STRING';
    ASN1_TAG_OCTET_STRING:    Result := 'OCTET STRING';
    ASN1_TAG_NULL:            Result := 'NULL';
    ASN1_TAG_OID:             Result := 'OBJECT IDENTIFIER';
    ASN1_TAG_OBJECT_DESCRIPTOR: Result := 'ObjectDescriptor';
    ASN1_TAG_EXTERNAL:        Result := 'EXTERNAL';
    ASN1_TAG_REAL:            Result := 'REAL';
    ASN1_TAG_ENUMERATED:      Result := 'ENUMERATED';
    ASN1_TAG_EMBEDDED_PDV:    Result := 'EMBEDDED PDV';
    ASN1_TAG_UTF8STRING:      Result := 'UTF8String';
    ASN1_TAG_RELATIVE_OID:    Result := 'RELATIVE-OID';
    ASN1_TAG_SEQUENCE:        Result := 'SEQUENCE';
    ASN1_TAG_SET:             Result := 'SET';
    ASN1_TAG_NUMERICSTRING:   Result := 'NumericString';
    ASN1_TAG_PRINTABLESTRING: Result := 'PrintableString';
    ASN1_TAG_T61STRING:       Result := 'T61String';
    ASN1_TAG_VIDEOTEXSTRING:  Result := 'VideotexString';
    ASN1_TAG_IA5STRING:       Result := 'IA5String';
    ASN1_TAG_UTCTIME:         Result := 'UTCTime';
    ASN1_TAG_GENERALIZEDTIME: Result := 'GeneralizedTime';
    ASN1_TAG_GRAPHICSTRING:   Result := 'GraphicString';
    ASN1_TAG_VISIBLESTRING:   Result := 'VisibleString';
    ASN1_TAG_GENERALSTRING:   Result := 'GeneralString';
    ASN1_TAG_UNIVERSALSTRING: Result := 'UniversalString';
    ASN1_TAG_CHARACTERSTRING: Result := 'CHARACTER STRING';
    ASN1_TAG_BMPSTRING:       Result := 'BMPString';
  else
    Result := nextpas.core.text.conv.Format('TAG(0x%.2X)', [ATag]);
  end;
end;

end.
