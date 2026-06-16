unit nextpas.core.tls.ocsp;

{$mode objfpc}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$modeswitch advancedrecords}

{
  OCSP (Online Certificate Status Protocol) 纯 Pascal 实现

  基于 RFC 6960 实现 OCSP 请求/响应处理。
  使用 nextpas.core.tls.asn1 和 nextpas.core.tls.x509 模块。

  OCSP 用于在线查询证书吊销状态，比 CRL 更高效。

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses SysUtils, nextpas.core.tls.asn1, nextpas.core.tls.x509, nextpas.core.crypto.hash;

type
  // ========================================================================
  // OCSP 状态
  // ========================================================================
  TOCSPCertStatus = (
    ocspGood,           // 证书有效
    ocspRevoked,        // 证书已吊销
    ocspUnknown         // 状态未知
  );

  // ========================================================================
  // OCSP 响应状态
  // ========================================================================
  TOCSPResponseStatus = (
    ocsprsSuccessful,        // 响应成功
    ocsprsMalformedRequest,  // 请求格式错误
    ocsprsInternalError,     // 内部错误
    ocsprsTryLater,          // 稍后重试
    ocsprsSignatureRequired, // 需要签名
    ocsprsUnauthorized       // 未授权
  );

  // ========================================================================
  // 吊销原因
  // ========================================================================
  TOCSPRevokeReason = (
    ocsprrUnspecified,         // 未指定
    ocsprrKeyCompromise,       // 密钥泄露
    ocsprrCACompromise,        // CA 泄露
    ocsprrAffiliationChanged,  // 从属关系变更
    ocsprrSuperseded,          // 被取代
    ocsprrCessationOfOperation,// 停止运营
    ocsprrCertificateHold,     // 证书暂停
    ocsprrRemoveFromCRL,       // 从 CRL 移除
    ocsprrPrivilegeWithdrawn,  // 权限撤回
    ocsprrAACompromise         // AA 泄露
  );

  // ========================================================================
  // OCSP 证书 ID
  // ========================================================================
  TOCSPCertID = record
    HashAlgorithm: string;      // 哈希算法 OID
    IssuerNameHash: TBytes;     // 颁发者名称哈希
    IssuerKeyHash: TBytes;      // 颁发者公钥哈希
    SerialNumber: TBytes;       // 证书序列号

    function Encode: TBytes;
    class function Decode(ANode: TASN1Node): TOCSPCertID; static;
    class function Create(ACert, AIssuerCert: TX509Certificate;
      AHashAlg: THashAlgorithm = haSHA1): TOCSPCertID; static;
  end;

  // ========================================================================
  // OCSP 单个响应
  // ========================================================================
  TOCSPSingleResponse = record
    CertID: TOCSPCertID;
    CertStatus: TOCSPCertStatus;
    ThisUpdate: TDateTime;
    NextUpdate: TDateTime;
    HasNextUpdate: Boolean;
    RevokedTime: TDateTime;
    RevokeReason: TOCSPRevokeReason;
    SignedCertificateTimestampList: TBytes;
    SignedCertificateTimestampCount: Integer;
    HasSignedCertificateTimestampList: Boolean;
  end;

  TOCSPSingleResponseArray = array of TOCSPSingleResponse;

  // ========================================================================
  // OCSP 请求
  // ========================================================================
  TOCSPRequest = class
  private
    FCertIDs: array of TOCSPCertID;
    FNonce: TBytes;
    FUseNonce: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddCertificate(ACert, AIssuerCert: TX509Certificate);
    procedure AddCertID(const ACertID: TOCSPCertID);
    procedure GenerateNonce;

    function Encode: TBytes;

    property UseNonce: Boolean read FUseNonce write FUseNonce;
    property Nonce: TBytes read FNonce;
  end;

  // ========================================================================
  // OCSP 响应
  // ========================================================================
  TOCSPResponse = class
  private
    FResponseStatus: TOCSPResponseStatus;
    FResponses: TOCSPSingleResponseArray;
    FProducedAt: TDateTime;
    FResponderID: string;
    FNonce: TBytes;
    FRawResponse: TBytes;
    FSignedCertificateTimestampList: TBytes;
    FSignedCertificateTimestampCount: Integer;
    FHasSignedCertificateTimestampList: Boolean;
    FRawTBSResponseData: TBytes;
    FSignatureAlgOID: string;
    FSignatureAlgName: string;
    FSignature: TBytes;
    FEmbeddedCertsDER: array of TBytes;

    procedure ParseBasicOCSPResponse(ANode: TASN1Node);
    procedure ParseResponseData(ANode: TASN1Node);
    procedure ParseSingleResponse(ANode: TASN1Node; var AResp: TOCSPSingleResponse);
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromDER(const AData: TBytes);

    function GetCertStatus(const ACertID: TOCSPCertID): TOCSPCertStatus;
    function FindResponse(const ACertID: TOCSPCertID): Integer;
    function TryGetSignedCertificateTimestampList(
      out ASignedCertificateTimestampList: TBytes;
      out ASignedCertificateTimestampCount: Integer
    ): Boolean; overload;
    function TryGetSignedCertificateTimestampList(
      const ACertID: TOCSPCertID;
      out ASignedCertificateTimestampList: TBytes;
      out ASignedCertificateTimestampCount: Integer
    ): Boolean; overload;

    property ResponseStatus: TOCSPResponseStatus read FResponseStatus;
    property Responses: TOCSPSingleResponseArray read FResponses;
    property ProducedAt: TDateTime read FProducedAt;
    property ResponderID: string read FResponderID;
    property Nonce: TBytes read FNonce;
    property SignedCertificateTimestampList: TBytes read FSignedCertificateTimestampList;
    property SignedCertificateTimestampCount: Integer read FSignedCertificateTimestampCount;
    property HasSignedCertificateTimestampList: Boolean read FHasSignedCertificateTimestampList;
    property RawTBSResponseData: TBytes read FRawTBSResponseData;
    property SignatureAlgOID: string read FSignatureAlgOID;
    property SignatureValue: TBytes read FSignature;
  end;

// ========================================================================
// 辅助函数
// ========================================================================

// 从证书中提取 OCSP URL
function GetOCSPURLFromCertificate(ACert: TX509Certificate): string;

// 比较两个 CertID 是否相同
function CompareCertID(const A, B: TOCSPCertID): Boolean;

// OCSP 状态转字符串
function OCSPStatusToString(AStatus: TOCSPCertStatus): string;
function OCSPResponseStatusToString(AStatus: TOCSPResponseStatus): string;

implementation

// ========================================================================
// OID 常量
// ========================================================================
const
  OID_OCSP_BASIC = '1.3.6.1.5.5.7.48.1.1';  // id-pkix-ocsp-basic
  OID_OCSP_NONCE = '1.3.6.1.5.5.7.48.1.2';  // id-pkix-ocsp-nonce
  OID_OCSP_SIGNED_CERTIFICATE_TIMESTAMP = '1.3.6.1.4.1.11129.2.4.5';
  OID_AIA = '1.3.6.1.5.5.7.1.1';            // Authority Info Access
  OID_OCSP = '1.3.6.1.5.5.7.48.1';          // OCSP access method

// ========================================================================
// 辅助函数: SCT list parsing
// ========================================================================

function ReadUInt16BE(const AData: TBytes; AOffset: Integer): Word;
begin
  Result := (Word(AData[AOffset]) shl 8) or Word(AData[AOffset + 1]);
end;

function TryParseSignedCertificateTimestampListBytes(
  const AData: TBytes;
  out ACount: Integer
): Boolean;
var
  LListLength: Integer;
  LOffset: Integer;
  LSCTLength: Integer;
begin
  ACount := 0;
  Result := False;

  if Length(AData) < 2 then
    Exit;

  LListLength := ReadUInt16BE(AData, 0);
  if (LListLength <= 0) or (Length(AData) <> 2 + LListLength) then
    Exit;

  LOffset := 2;
  while LOffset < Length(AData) do
  begin
    if LOffset + 2 > Length(AData) then
      Exit(False);

    LSCTLength := ReadUInt16BE(AData, LOffset);
    Inc(LOffset, 2);
    if (LSCTLength <= 0) or (LOffset + LSCTLength > Length(AData)) then
      Exit(False);

    Inc(ACount);
    Inc(LOffset, LSCTLength);
  end;

  Result := ACount > 0;
end;

function TryExtractSignedCertificateTimestampExtension(
  AExtNode: TASN1Node;
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer
): Boolean;
var
  LValueIndex: Integer;
  LExtensionOID: string;
  LRawValue: TBytes;
begin
  SetLength(ASignedCertificateTimestampList, 0);
  ASignedCertificateTimestampCount := 0;
  Result := False;

  if (AExtNode = nil) or (not AExtNode.IsSequence) or (AExtNode.ChildCount < 2) then
    Exit;

  LExtensionOID := AExtNode.GetChild(0).AsOID;
  if LExtensionOID <> OID_OCSP_SIGNED_CERTIFICATE_TIMESTAMP then
    Exit;

  LValueIndex := 1;
  if (AExtNode.ChildCount > 2) and AExtNode.GetChild(1).IsBoolean then
    LValueIndex := 2;
  if AExtNode.ChildCount <= LValueIndex then
    Exit;

  LRawValue := AExtNode.GetChild(LValueIndex).AsOctetString;
  if not TryParseSignedCertificateTimestampListBytes(LRawValue, ASignedCertificateTimestampCount) then
    Exit;

  ASignedCertificateTimestampList := Copy(LRawValue);
  Result := True;
end;

// ========================================================================
// 辅助函数: DER 编码
// ========================================================================

{ 将 TBytes 包装为 DER SEQUENCE }
function WrapInSequence(const AContent: TBytes): TBytes;
var
  LenBytes: TBytes;
  ContentLen, TotalLen: Integer;
  Offset: Integer;
begin
  ContentLen := Length(AContent);

  // 计算长度字段
  if ContentLen < 128 then
  begin
    SetLength(LenBytes, 1);
    LenBytes[0] := Byte(ContentLen);
  end
  else if ContentLen < 256 then
  begin
    SetLength(LenBytes, 2);
    LenBytes[0] := $81;
    LenBytes[1] := Byte(ContentLen);
  end
  else if ContentLen < 65536 then
  begin
    SetLength(LenBytes, 3);
    LenBytes[0] := $82;
    LenBytes[1] := Byte(ContentLen shr 8);
    LenBytes[2] := Byte(ContentLen and $FF);
  end
  else
  begin
    SetLength(LenBytes, 4);
    LenBytes[0] := $83;
    LenBytes[1] := Byte(ContentLen shr 16);
    LenBytes[2] := Byte((ContentLen shr 8) and $FF);
    LenBytes[3] := Byte(ContentLen and $FF);
  end;

  TotalLen := 1 + Length(LenBytes) + ContentLen;
  SetLength(Result, TotalLen);

  Result[0] := $30;  // SEQUENCE tag
  Move(LenBytes[0], Result[1], Length(LenBytes));
  Offset := 1 + Length(LenBytes);
  if ContentLen > 0 then
    Move(AContent[0], Result[Offset], ContentLen);
end;

{ 将 TBytes 包装为 DER OCTET STRING }
function WrapInOctetString(const AContent: TBytes): TBytes;
var
  LenBytes: TBytes;
  ContentLen, TotalLen: Integer;
  Offset: Integer;
begin
  ContentLen := Length(AContent);

  if ContentLen < 128 then
  begin
    SetLength(LenBytes, 1);
    LenBytes[0] := Byte(ContentLen);
  end
  else if ContentLen < 256 then
  begin
    SetLength(LenBytes, 2);
    LenBytes[0] := $81;
    LenBytes[1] := Byte(ContentLen);
  end
  else
  begin
    SetLength(LenBytes, 3);
    LenBytes[0] := $82;
    LenBytes[1] := Byte(ContentLen shr 8);
    LenBytes[2] := Byte(ContentLen and $FF);
  end;

  TotalLen := 1 + Length(LenBytes) + ContentLen;
  SetLength(Result, TotalLen);

  Result[0] := $04;  // OCTET STRING tag
  Move(LenBytes[0], Result[1], Length(LenBytes));
  Offset := 1 + Length(LenBytes);
  if ContentLen > 0 then
    Move(AContent[0], Result[Offset], ContentLen);
end;

{ 将 TBytes 包装为 DER context tag }
function WrapInContextTag(ATagNumber: Integer; const AContent: TBytes;
  AConstructed: Boolean = True): TBytes;
var
  Tag: Byte;
  LenBytes: TBytes;
  ContentLen, TotalLen: Integer;
  Offset: Integer;
begin
  ContentLen := Length(AContent);

  Tag := $80 or Byte(ATagNumber and $1F);  // Context class
  if AConstructed then
    Tag := Tag or $20;  // Constructed

  if ContentLen < 128 then
  begin
    SetLength(LenBytes, 1);
    LenBytes[0] := Byte(ContentLen);
  end
  else if ContentLen < 256 then
  begin
    SetLength(LenBytes, 2);
    LenBytes[0] := $81;
    LenBytes[1] := Byte(ContentLen);
  end
  else
  begin
    SetLength(LenBytes, 3);
    LenBytes[0] := $82;
    LenBytes[1] := Byte(ContentLen shr 8);
    LenBytes[2] := Byte(ContentLen and $FF);
  end;

  TotalLen := 1 + Length(LenBytes) + ContentLen;
  SetLength(Result, TotalLen);

  Result[0] := Tag;
  Move(LenBytes[0], Result[1], Length(LenBytes));
  Offset := 1 + Length(LenBytes);
  if ContentLen > 0 then
    Move(AContent[0], Result[Offset], ContentLen);
end;

{ 连接多个 TBytes 数组 }
function ConcatBytes(const AArrays: array of TBytes): TBytes;
var
  TotalLen, Offset, I: Integer;
begin
  TotalLen := 0;
  for I := Low(AArrays) to High(AArrays) do
    Inc(TotalLen, Length(AArrays[I]));

  SetLength(Result, TotalLen);
  Offset := 0;
  for I := Low(AArrays) to High(AArrays) do
  begin
    if Length(AArrays[I]) > 0 then
    begin
      Move(AArrays[I][0], Result[Offset], Length(AArrays[I]));
      Inc(Offset, Length(AArrays[I]));
    end;
  end;
end;

{ 编码 AlgorithmIdentifier }
function EncodeAlgorithmIdentifier(const AOID: string): TBytes;
var
  OIDBytes, NullBytes, Content: TBytes;
begin
  // AlgorithmIdentifier ::= SEQUENCE {
  //   algorithm   OBJECT IDENTIFIER,
  //   parameters  ANY DEFINED BY algorithm OPTIONAL }

  OIDBytes := EncodeOID(AOID);

  // 为 OID 添加标签
  SetLength(Result, 2 + Length(OIDBytes));
  Result[0] := $06;  // OBJECT IDENTIFIER tag
  Result[1] := Length(OIDBytes);
  Move(OIDBytes[0], Result[2], Length(OIDBytes));
  OIDBytes := Result;

  // NULL 参数
  SetLength(NullBytes, 2);
  NullBytes[0] := $05;
  NullBytes[1] := $00;

  Content := ConcatBytes([OIDBytes, NullBytes]);
  Result := WrapInSequence(Content);
end;

{ 编码 INTEGER (大整数) }
function EncodeBigInteger(const AValue: TBytes): TBytes;
var
  NeedPadding: Boolean;
  DataLen: Integer;
begin
  if Length(AValue) = 0 then
  begin
    SetLength(Result, 3);
    Result[0] := $02;  // INTEGER tag
    Result[1] := $01;  // Length
    Result[2] := $00;  // Value
    Exit;
  end;

  // 检查是否需要前导零（避免被解释为负数）
  NeedPadding := (AValue[0] and $80) <> 0;

  DataLen := Length(AValue);
  if NeedPadding then
    Inc(DataLen);

  if DataLen < 128 then
  begin
    SetLength(Result, 2 + DataLen);
    Result[0] := $02;
    Result[1] := DataLen;
    if NeedPadding then
    begin
      Result[2] := $00;
      Move(AValue[0], Result[3], Length(AValue));
    end
    else
      Move(AValue[0], Result[2], Length(AValue));
  end
  else if DataLen < 256 then
  begin
    SetLength(Result, 3 + DataLen);
    Result[0] := $02;
    Result[1] := $81;
    Result[2] := DataLen;
    if NeedPadding then
    begin
      Result[3] := $00;
      Move(AValue[0], Result[4], Length(AValue));
    end
    else
      Move(AValue[0], Result[3], Length(AValue));
  end
  else
  begin
    SetLength(Result, 4 + DataLen);
    Result[0] := $02;
    Result[1] := $82;
    Result[2] := Byte(DataLen shr 8);
    Result[3] := Byte(DataLen and $FF);
    if NeedPadding then
    begin
      Result[4] := $00;
      Move(AValue[0], Result[5], Length(AValue));
    end
    else
      Move(AValue[0], Result[4], Length(AValue));
  end;
end;

{ 编码 TX509Name 为 DER 格式的 Name }
function EncodeName(const AName: TX509Name): TBytes;
var
  I: Integer;
  RDNs: array of TBytes;
  AttrValue, AttrType, AttrSeq, RDNSet: TBytes;
  OIDBytes, ValueBytes: TBytes;
  StringTag: Byte;
begin
  // Name ::= SEQUENCE OF RelativeDistinguishedName
  // RelativeDistinguishedName ::= SET OF AttributeTypeAndValue
  // AttributeTypeAndValue ::= SEQUENCE {
  //   type   AttributeType,
  //   value  AttributeValue }

  SetLength(RDNs, Length(AName.Attributes));

  for I := 0 to High(AName.Attributes) do
  begin
    // 编码 OID
    OIDBytes := EncodeOID(AName.Attributes[I].OID);
    SetLength(AttrType, 2 + Length(OIDBytes));
    AttrType[0] := $06;
    AttrType[1] := Length(OIDBytes);
    Move(OIDBytes[0], AttrType[2], Length(OIDBytes));

    // 编码值 (使用 UTF8String)
    ValueBytes := nextpas.core.text.conv.StringToUTF8Bytes(AName.Attributes[I].Value));
    StringTag := $0C;  // UTF8String

    if Length(ValueBytes) < 128 then
    begin
      SetLength(AttrValue, 2 + Length(ValueBytes));
      AttrValue[0] := StringTag;
      AttrValue[1] := Length(ValueBytes);
      if Length(ValueBytes) > 0 then
        Move(ValueBytes[0], AttrValue[2], Length(ValueBytes));
    end
    else
    begin
      SetLength(AttrValue, 3 + Length(ValueBytes));
      AttrValue[0] := StringTag;
      AttrValue[1] := $81;
      AttrValue[2] := Length(ValueBytes);
      if Length(ValueBytes) > 0 then
        Move(ValueBytes[0], AttrValue[3], Length(ValueBytes));
    end;

    // AttributeTypeAndValue SEQUENCE
    AttrSeq := WrapInSequence(ConcatBytes([AttrType, AttrValue]));

    // RDN SET
    RDNSet := AttrSeq;
    SetLength(RDNs[I], 1 + 1 + Length(RDNSet));
    RDNs[I][0] := $31;  // SET tag
    RDNs[I][1] := Length(RDNSet);
    Move(RDNSet[0], RDNs[I][2], Length(RDNSet));
  end;

  // Name SEQUENCE
  Result := WrapInSequence(ConcatBytes(RDNs));
end;

{ 将字节数组转换为十六进制字符串 }
function BytesToHex(const ABytes: TBytes): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(ABytes) * 2);
  for I := 0 to High(ABytes) do
  begin
    Result[I * 2 + 1] := HexChars[(ABytes[I] shr 4) and $0F];
    Result[I * 2 + 2] := HexChars[ABytes[I] and $0F];
  end;
end;

// ========================================================================
// TOCSPCertID
// ========================================================================

function TOCSPCertID.Encode: TBytes;
var
  AlgIdBytes, IssuerNameHashBytes, IssuerKeyHashBytes, SerialBytes: TBytes;
  Content: TBytes;
begin
  // CertID ::= SEQUENCE {
  //   hashAlgorithm       AlgorithmIdentifier,
  //   issuerNameHash      OCTET STRING,
  //   issuerKeyHash       OCTET STRING,
  //   serialNumber        CertificateSerialNumber }

  // 编码 AlgorithmIdentifier
  AlgIdBytes := EncodeAlgorithmIdentifier(HashAlgorithm);

  // 编码 issuerNameHash (OCTET STRING)
  IssuerNameHashBytes := WrapInOctetString(IssuerNameHash);

  // 编码 issuerKeyHash (OCTET STRING)
  IssuerKeyHashBytes := WrapInOctetString(IssuerKeyHash);

  // 编码 serialNumber (INTEGER)
  SerialBytes := EncodeBigInteger(SerialNumber);

  // 组合为 SEQUENCE
  Content := ConcatBytes([AlgIdBytes, IssuerNameHashBytes,
                          IssuerKeyHashBytes, SerialBytes]);
  Result := WrapInSequence(Content);
end;

class function TOCSPCertID.Decode(ANode: TASN1Node): TOCSPCertID;
var
  AlgNode: TASN1Node;
begin
  FillChar(Result, SizeOf(Result), 0);

  if not ANode.IsSequence then
    Exit;
  if ANode.ChildCount < 4 then
    Exit;

  // hashAlgorithm
  AlgNode := ANode.GetChild(0);
  if AlgNode.IsSequence and (AlgNode.ChildCount >= 1) then
    Result.HashAlgorithm := AlgNode.GetChild(0).AsOID;

  // issuerNameHash
  if ANode.GetChild(1).IsOctetString then
    Result.IssuerNameHash := ANode.GetChild(1).AsOctetString;

  // issuerKeyHash
  if ANode.GetChild(2).IsOctetString then
    Result.IssuerKeyHash := ANode.GetChild(2).AsOctetString;

  // serialNumber
  Result.SerialNumber := ANode.GetChild(3).AsBigInteger;
end;

class function TOCSPCertID.Create(ACert, AIssuerCert: TX509Certificate;
  AHashAlg: THashAlgorithm): TOCSPCertID;
var
  IssuerNameDER: TBytes;
  IssuerKeyDER: TBytes;
begin
  FillChar(Result, SizeOf(Result), 0);

  // 设置哈希算法 OID
  case AHashAlg of
    haSHA1:   Result.HashAlgorithm := '1.3.14.3.2.26';
    haSHA256: Result.HashAlgorithm := '2.16.840.1.101.3.4.2.1';
    haSHA384: Result.HashAlgorithm := '2.16.840.1.101.3.4.2.2';
    haSHA512: Result.HashAlgorithm := '2.16.840.1.101.3.4.2.3';
  else
    Result.HashAlgorithm := '1.3.14.3.2.26'; // 默认 SHA-1
  end;

  // 计算颁发者名称哈希
  // RFC 6960: 使用颁发者证书 Subject 的 DER 编码
  IssuerNameDER := EncodeName(AIssuerCert.Subject);

  // 计算颁发者公钥哈希
  // 需要使用 SubjectPublicKeyInfo 中的公钥位串
  IssuerKeyDER := AIssuerCert.PublicKeyInfo.PublicKey;

  case AHashAlg of
    haSHA1:
    begin
      Result.IssuerNameHash := SHA1(IssuerNameDER);
      Result.IssuerKeyHash := SHA1(IssuerKeyDER);
    end;
    haSHA256:
    begin
      Result.IssuerNameHash := SHA256(IssuerNameDER);
      Result.IssuerKeyHash := SHA256(IssuerKeyDER);
    end;
    haSHA384:
    begin
      Result.IssuerNameHash := SHA384(IssuerNameDER);
      Result.IssuerKeyHash := SHA384(IssuerKeyDER);
    end;
    haSHA512:
    begin
      Result.IssuerNameHash := SHA512(IssuerNameDER);
      Result.IssuerKeyHash := SHA512(IssuerKeyDER);
    end;
  else
    Result.IssuerNameHash := SHA1(IssuerNameDER);
    Result.IssuerKeyHash := SHA1(IssuerKeyDER);
  end;

  // 复制序列号
  Result.SerialNumber := Copy(ACert.SerialNumber, 0, Length(ACert.SerialNumber));
end;

// ========================================================================
// TOCSPRequest
// ========================================================================

constructor TOCSPRequest.Create;
begin
  inherited Create;
  SetLength(FCertIDs, 0);
  SetLength(FNonce, 0);
  FUseNonce := True;
end;

destructor TOCSPRequest.Destroy;
begin
  inherited Destroy;
end;

procedure TOCSPRequest.AddCertificate(ACert, AIssuerCert: TX509Certificate);
begin
  AddCertID(TOCSPCertID.Create(ACert, AIssuerCert));
end;

procedure TOCSPRequest.AddCertID(const ACertID: TOCSPCertID);
begin
  SetLength(FCertIDs, Length(FCertIDs) + 1);
  FCertIDs[High(FCertIDs)] := ACertID;
end;

procedure TOCSPRequest.GenerateNonce;
var
  I: Integer;
begin
  SetLength(FNonce, 16);
  for I := 0 to 15 do
    FNonce[I] := Random(256);
end;

function TOCSPRequest.Encode: TBytes;
var
  I: Integer;
  RequestList, TBSRequest: TBytes;
  CertIDBytes: TBytes;
  Requests: array of TBytes;
  NonceExt, NonceOID, NonceValue, ExtContent, Extensions: TBytes;
begin
  // OCSPRequest ::= SEQUENCE {
  //   tbsRequest     TBSRequest,
  //   optionalSignature [0] EXPLICIT Signature OPTIONAL }
  //
  // TBSRequest ::= SEQUENCE {
  //   version            [0] EXPLICIT Version DEFAULT v1,
  //   requestorName      [1] EXPLICIT GeneralName OPTIONAL,
  //   requestList        SEQUENCE OF Request,
  //   requestExtensions  [2] EXPLICIT Extensions OPTIONAL }
  //
  // Request ::= SEQUENCE {
  //   reqCert     CertID,
  //   singleRequestExtensions [0] EXPLICIT Extensions OPTIONAL }

  // 生成 nonce
  if FUseNonce and (Length(FNonce) = 0) then
    GenerateNonce;

  // 编码每个请求
  SetLength(Requests, Length(FCertIDs));
  for I := 0 to High(FCertIDs) do
  begin
    // Request ::= SEQUENCE { reqCert CertID }
    CertIDBytes := FCertIDs[I].Encode;
    Requests[I] := WrapInSequence(CertIDBytes);
  end;

  // requestList: SEQUENCE OF Request
  RequestList := WrapInSequence(ConcatBytes(Requests));

  // 构建 TBSRequest
  if FUseNonce and (Length(FNonce) > 0) then
  begin
    // 编码 nonce 扩展
    // Extension ::= SEQUENCE {
    //   extnID      OBJECT IDENTIFIER,
    //   critical    BOOLEAN DEFAULT FALSE,
    //   extnValue   OCTET STRING }

    // OID for nonce
    NonceOID := EncodeOID(OID_OCSP_NONCE);
    SetLength(Result, 2 + Length(NonceOID));
    Result[0] := $06;  // OBJECT IDENTIFIER tag
    Result[1] := Length(NonceOID);
    Move(NonceOID[0], Result[2], Length(NonceOID));
    NonceOID := Result;

    // nonce value wrapped in OCTET STRING (twice - for extension value)
    NonceValue := WrapInOctetString(WrapInOctetString(FNonce));

    // Extension SEQUENCE
    NonceExt := WrapInSequence(ConcatBytes([NonceOID, NonceValue]));

    // Extensions SEQUENCE
    ExtContent := WrapInSequence(NonceExt);

    // [2] EXPLICIT Extensions
    Extensions := WrapInContextTag(2, ExtContent, True);

    // TBSRequest: requestList + requestExtensions
    TBSRequest := WrapInSequence(ConcatBytes([RequestList, Extensions]));
  end
  else
  begin
    // TBSRequest: requestList only
    TBSRequest := WrapInSequence(RequestList);
  end;

  // OCSPRequest: TBSRequest (no signature)
  Result := WrapInSequence(TBSRequest);
end;

// ========================================================================
// TOCSPResponse
// ========================================================================

constructor TOCSPResponse.Create;
begin
  inherited Create;
  FResponseStatus := ocsprsInternalError;
  SetLength(FResponses, 0);
  FProducedAt := 0;
  FResponderID := '';
  SetLength(FNonce, 0);
  SetLength(FSignedCertificateTimestampList, 0);
  FSignedCertificateTimestampCount := 0;
  FHasSignedCertificateTimestampList := False;
end;

destructor TOCSPResponse.Destroy;
begin
  inherited Destroy;
end;

procedure TOCSPResponse.LoadFromDER(const AData: TBytes);
var
  Reader: TASN1Reader;
  Root, StatusNode, BytesNode, ResponseNode: TASN1Node;
  ResponseOID: string;
begin
  FRawResponse := Copy(AData, 0, Length(AData));

  Reader := TASN1Reader.Create(AData);
  try
    Root := Reader.Parse;
    if Root = nil then
      Exit;

    try
      // OCSPResponse ::= SEQUENCE {
      //   responseStatus   OCSPResponseStatus,
      //   responseBytes    [0] EXPLICIT ResponseBytes OPTIONAL }

      if not Root.IsSequence then
        Exit;

      // responseStatus
      if Root.ChildCount >= 1 then
      begin
        StatusNode := Root.GetChild(0);
        case StatusNode.AsInteger of
          0: FResponseStatus := ocsprsSuccessful;
          1: FResponseStatus := ocsprsMalformedRequest;
          2: FResponseStatus := ocsprsInternalError;
          3: FResponseStatus := ocsprsTryLater;
          5: FResponseStatus := ocsprsSignatureRequired;
          6: FResponseStatus := ocsprsUnauthorized;
        end;
      end;

      // responseBytes (可选)
      if (Root.ChildCount >= 2) and Root.GetChild(1).IsContextTag(0) then
      begin
        BytesNode := Root.GetChild(1);
        if BytesNode.ChildCount >= 1 then
        begin
          ResponseNode := BytesNode.GetChild(0);
          if ResponseNode.IsSequence and (ResponseNode.ChildCount >= 2) then
          begin
            // ResponseBytes ::= SEQUENCE {
            //   responseType   OBJECT IDENTIFIER,
            //   response       OCTET STRING }
            ResponseOID := ResponseNode.GetChild(0).AsOID;
            if ResponseOID = OID_OCSP_BASIC then
            begin
              // 解析 BasicOCSPResponse
              ParseBasicOCSPResponse(ResponseNode.GetChild(1));
            end;
          end;
        end;
      end;
    finally
      Root.Free;
    end;
  finally
    Reader.Free;
  end;
end;

procedure TOCSPResponse.ParseBasicOCSPResponse(ANode: TASN1Node);
var
  Reader: TASN1Reader;
  BasicRoot, TBSNode, SigAlgNode, SigNode, CertsNode, CertSeq: TASN1Node;
  BasicData: TBytes;
  I: Integer;
begin
  if ANode.IsOctetString then
    BasicData := ANode.AsOctetString
  else
    Exit;

  Reader := TASN1Reader.Create(BasicData);
  try
    BasicRoot := Reader.Parse;
    if BasicRoot = nil then
      Exit;

    try
      if not BasicRoot.IsSequence then
        Exit;

      if BasicRoot.ChildCount >= 1 then
      begin
        TBSNode := BasicRoot.GetChild(0);
        FRawTBSResponseData := TBSNode.RawData;
        ParseResponseData(TBSNode);
      end;

      if BasicRoot.ChildCount >= 2 then
      begin
        SigAlgNode := BasicRoot.GetChild(1);
        if SigAlgNode.IsSequence and (SigAlgNode.ChildCount >= 1) then
        begin
          FSignatureAlgOID := SigAlgNode.GetChild(0).AsOID;
          FSignatureAlgName := FSignatureAlgOID;
        end;
      end;

      if BasicRoot.ChildCount >= 3 then
      begin
        SigNode := BasicRoot.GetChild(2);
        FSignature := SigNode.AsBitString;
      end;

      if BasicRoot.ChildCount >= 4 then
      begin
        CertsNode := BasicRoot.GetChild(3);
        if (CertsNode.ChildCount >= 1) then
        begin
          CertSeq := CertsNode.GetChild(0);
          if CertSeq.IsSequence then
          begin
            SetLength(FEmbeddedCertsDER, CertSeq.ChildCount);
            for I := 0 to CertSeq.ChildCount - 1 do
              FEmbeddedCertsDER[I] := CertSeq.GetChild(I).RawData;
          end;
        end;
      end;
    finally
      BasicRoot.Free;
    end;
  finally
    Reader.Free;
  end;
end;

procedure TOCSPResponse.ParseResponseData(ANode: TASN1Node);
var
  I, J, Index: Integer;
  Child, ResponsesNode, ExtSeqNode, ExtNode: TASN1Node;
  NameNode, RDNNode, AVNode: TASN1Node;
  NameStr: string;
  ExtOID: string;
  LSignedCertificateTimestampList: TBytes;
  LSignedCertificateTimestampCount: Integer;
begin
  // ResponseData ::= SEQUENCE {
  //   version            [0] EXPLICIT Version DEFAULT v1,
  //   responderID        ResponderID,
  //   producedAt         GeneralizedTime,
  //   responses          SEQUENCE OF SingleResponse,
  //   responseExtensions [1] EXPLICIT Extensions OPTIONAL }

  if not ANode.IsSequence then
    Exit;

  Index := 0;

  // version (可选)
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsContextTag(0) then
    Inc(Index);

  // responderID
  // ResponderID ::= CHOICE {
  //   byName   [1] Name,
  //   byKey    [2] KeyHash }
  if ANode.ChildCount > Index then
  begin
    Child := ANode.GetChild(Index);
    if Child.IsContextTag(1) then
    begin
      // byName - 解析 Name (DN)
      FResponderID := 'byName:';
      // Name 是 SEQUENCE OF RelativeDistinguishedName
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.GetChild(0);
        if NameNode.IsSequence then
        begin
          NameStr := '';
          for I := 0 to NameNode.ChildCount - 1 do
          begin
            RDNNode := NameNode.GetChild(I);
            // RDN 是 SET OF AttributeTypeAndValue
            if RDNNode.ChildCount > 0 then
            begin
              AVNode := RDNNode.GetChild(0);
              // AttributeTypeAndValue 是 SEQUENCE { type, value }
              if AVNode.IsSequence and (AVNode.ChildCount >= 2) then
              begin
                if NameStr <> '' then
                  NameStr := NameStr + ',';
                NameStr := NameStr + OIDToName(AVNode.GetChild(0).AsOID) + '=' + AVNode.GetChild(1).AsString;
              end;
            end;
          end;
          FResponderID := 'byName:' + NameStr;
        end;
      end;
    end
    else if Child.IsContextTag(2) then
    begin
      // byKey - 解析 KeyHash (OCTET STRING)
      if Child.ChildCount > 0 then
        FResponderID := 'byKey:' + BytesToHex(Child.GetChild(0).AsOctetString)
      else
        FResponderID := 'byKey';
    end;
    Inc(Index);
  end;

  // producedAt
  if ANode.ChildCount > Index then
  begin
    FProducedAt := ANode.GetChild(Index).AsDateTime;
    Inc(Index);
  end;

  // responses
  if ANode.ChildCount > Index then
  begin
    ResponsesNode := ANode.GetChild(Index);
    if ResponsesNode.IsSequence then
    begin
      SetLength(FResponses, ResponsesNode.ChildCount);
      for I := 0 to ResponsesNode.ChildCount - 1 do
      begin
        FillChar(FResponses[I], SizeOf(TOCSPSingleResponse), 0);
        ParseSingleResponse(ResponsesNode.GetChild(I), FResponses[I]);
      end;
    end;
    Inc(Index);
  end;

  // responseExtensions (可选)
  // [1] EXPLICIT Extensions
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsContextTag(1) then
  begin
    Child := ANode.GetChild(Index);
    // Extensions ::= SEQUENCE OF Extension
    if Child.ChildCount > 0 then
    begin
      ExtSeqNode := Child.GetChild(0);
      if ExtSeqNode.IsSequence then
      begin
        for I := 0 to ExtSeqNode.ChildCount - 1 do
        begin
          ExtNode := ExtSeqNode.GetChild(I);
          // Extension ::= SEQUENCE {
          //   extnID      OBJECT IDENTIFIER,
          //   critical    BOOLEAN DEFAULT FALSE,
          //   extnValue   OCTET STRING }
          if ExtNode.IsSequence and (ExtNode.ChildCount >= 2) then
          begin
            ExtOID := ExtNode.GetChild(0).AsOID;
            if ExtOID = OID_OCSP_NONCE then
            begin
              // 提取 nonce 值
              // extnValue 是 OCTET STRING 包含另一个 OCTET STRING
              J := 1;
              // 跳过可选的 critical BOOLEAN
              if (ExtNode.ChildCount > 2) and ExtNode.GetChild(1).IsBoolean then
                J := 2;
              if ExtNode.ChildCount > J then
              begin
                FNonce := ExtNode.GetChild(J).AsOctetString;
                // 如果 nonce 仍然是 OCTET STRING 包装的，需要再解析一次
                if (Length(FNonce) > 2) and (FNonce[0] = $04) then
                begin
                  // 跳过 OCTET STRING 标签和长度
                  if FNonce[1] < 128 then
                    FNonce := Copy(FNonce, 2, FNonce[1])
                  else if FNonce[1] = $81 then
                    FNonce := Copy(FNonce, 3, FNonce[2]);
                end;
              end;
            end
            else if TryExtractSignedCertificateTimestampExtension(
              ExtNode,
              LSignedCertificateTimestampList,
              LSignedCertificateTimestampCount
            ) then
            begin
              FSignedCertificateTimestampList := Copy(LSignedCertificateTimestampList);
              FSignedCertificateTimestampCount := LSignedCertificateTimestampCount;
              FHasSignedCertificateTimestampList := True;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TOCSPResponse.ParseSingleResponse(ANode: TASN1Node; var AResp: TOCSPSingleResponse);
var
  Index: Integer;
  CertStatusNode, Child, ExtSeqNode, ExtNode: TASN1Node;
  I: Integer;
  LSignedCertificateTimestampList: TBytes;
  LSignedCertificateTimestampCount: Integer;
begin
  // SingleResponse ::= SEQUENCE {
  //   certID           CertID,
  //   certStatus       CertStatus,
  //   thisUpdate       GeneralizedTime,
  //   nextUpdate       [0] EXPLICIT GeneralizedTime OPTIONAL,
  //   singleExtensions [1] EXPLICIT Extensions OPTIONAL }

  if not ANode.IsSequence then
    Exit;

  Index := 0;

  // certID
  if ANode.ChildCount > Index then
  begin
    AResp.CertID := TOCSPCertID.Decode(ANode.GetChild(Index));
    Inc(Index);
  end;

  // certStatus
  if ANode.ChildCount > Index then
  begin
    CertStatusNode := ANode.GetChild(Index);

    // CertStatus ::= CHOICE {
    //   good        [0] IMPLICIT NULL,
    //   revoked     [1] IMPLICIT RevokedInfo,
    //   unknown     [2] IMPLICIT UnknownInfo }

    if CertStatusNode.IsContextTag(0) then
      AResp.CertStatus := ocspGood
    else if CertStatusNode.IsContextTag(1) then
    begin
      AResp.CertStatus := ocspRevoked;
      // RevokedInfo ::= SEQUENCE {
      //   revocationTime     GeneralizedTime,
      //   revocationReason   [0] EXPLICIT CRLReason OPTIONAL }
      if CertStatusNode.ChildCount >= 1 then
        AResp.RevokedTime := CertStatusNode.GetChild(0).AsDateTime;
      if CertStatusNode.ChildCount >= 2 then
        AResp.RevokeReason := TOCSPRevokeReason(CertStatusNode.GetChild(1).AsInteger);
    end
    else if CertStatusNode.IsContextTag(2) then
      AResp.CertStatus := ocspUnknown;

    Inc(Index);
  end;

  // thisUpdate
  if ANode.ChildCount > Index then
  begin
    AResp.ThisUpdate := ANode.GetChild(Index).AsDateTime;
    Inc(Index);
  end;

  // nextUpdate (可选)
  AResp.HasNextUpdate := False;
  AResp.HasSignedCertificateTimestampList := False;
  SetLength(AResp.SignedCertificateTimestampList, 0);
  AResp.SignedCertificateTimestampCount := 0;
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsContextTag(0) then
  begin
    if ANode.GetChild(Index).ChildCount > 0 then
    begin
      AResp.NextUpdate := ANode.GetChild(Index).GetChild(0).AsDateTime;
      AResp.HasNextUpdate := True;
    end;
    Inc(Index);
  end;

  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsContextTag(1) then
  begin
    Child := ANode.GetChild(Index);
    if Child.ChildCount > 0 then
    begin
      ExtSeqNode := Child.GetChild(0);
      if ExtSeqNode.IsSequence then
      begin
        for I := 0 to ExtSeqNode.ChildCount - 1 do
        begin
          ExtNode := ExtSeqNode.GetChild(I);
          if TryExtractSignedCertificateTimestampExtension(
            ExtNode,
            LSignedCertificateTimestampList,
            LSignedCertificateTimestampCount
          ) then
          begin
            AResp.SignedCertificateTimestampList := Copy(LSignedCertificateTimestampList);
            AResp.SignedCertificateTimestampCount := LSignedCertificateTimestampCount;
            AResp.HasSignedCertificateTimestampList := True;
            Break;
          end;
        end;
      end;
    end;
  end;
end;

function TOCSPResponse.GetCertStatus(const ACertID: TOCSPCertID): TOCSPCertStatus;
var
  Idx: Integer;
begin
  Idx := FindResponse(ACertID);
  if Idx >= 0 then
    Result := FResponses[Idx].CertStatus
  else
    Result := ocspUnknown;
end;

function TOCSPResponse.FindResponse(const ACertID: TOCSPCertID): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FResponses) do
  begin
    if CompareCertID(FResponses[I].CertID, ACertID) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function TOCSPResponse.TryGetSignedCertificateTimestampList(
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer
): Boolean;
var
  I: Integer;
begin
  SetLength(ASignedCertificateTimestampList, 0);
  ASignedCertificateTimestampCount := 0;

  for I := 0 to High(FResponses) do
  begin
    if FResponses[I].HasSignedCertificateTimestampList then
    begin
      ASignedCertificateTimestampList := Copy(FResponses[I].SignedCertificateTimestampList);
      ASignedCertificateTimestampCount := FResponses[I].SignedCertificateTimestampCount;
      Exit(True);
    end;
  end;

  if FHasSignedCertificateTimestampList then
  begin
    ASignedCertificateTimestampList := Copy(FSignedCertificateTimestampList);
    ASignedCertificateTimestampCount := FSignedCertificateTimestampCount;
    Exit(True);
  end;

  Result := False;
end;

function TOCSPResponse.TryGetSignedCertificateTimestampList(
  const ACertID: TOCSPCertID;
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer
): Boolean;
var
  LResponseIndex: Integer;
begin
  SetLength(ASignedCertificateTimestampList, 0);
  ASignedCertificateTimestampCount := 0;

  LResponseIndex := FindResponse(ACertID);
  if (LResponseIndex >= 0) and FResponses[LResponseIndex].HasSignedCertificateTimestampList then
  begin
    ASignedCertificateTimestampList := Copy(FResponses[LResponseIndex].SignedCertificateTimestampList);
    ASignedCertificateTimestampCount := FResponses[LResponseIndex].SignedCertificateTimestampCount;
    Exit(True);
  end;

  Result := TryGetSignedCertificateTimestampList(
    ASignedCertificateTimestampList,
    ASignedCertificateTimestampCount
  );
end;

// ========================================================================
// 辅助函数实现
// ========================================================================

function GetOCSPURLFromCertificate(ACert: TX509Certificate): string;
var
  I, J: Integer;
  Ext: TX509Extension;
  Reader: TASN1Reader;
  Node, AccessNode: TASN1Node;
  AccessMethod: string;
begin
  Result := '';

  // 查找 Authority Information Access 扩展
  for I := 0 to High(ACert.Extensions) do
  begin
    Ext := ACert.Extensions[I];
    if Ext.OID = OID_AIA then
    begin
      // 解析 AIA 扩展
      if Length(Ext.Value) = 0 then
        Continue;

      Reader := TASN1Reader.Create(Ext.Value);
      try
        Node := Reader.Parse;
        if Node = nil then
          Continue;

        try
          // AuthorityInfoAccessSyntax ::= SEQUENCE SIZE (1..MAX) OF AccessDescription
          // AccessDescription ::= SEQUENCE {
          //   accessMethod    OBJECT IDENTIFIER,
          //   accessLocation  GeneralName }
          if not Node.IsSequence then
            Continue;

          for J := 0 to Node.ChildCount - 1 do
          begin
            AccessNode := Node.GetChild(J);
            if not AccessNode.IsSequence then
              Continue;
            if AccessNode.ChildCount < 2 then
              Continue;

            AccessMethod := AccessNode.GetChild(0).AsOID;
            if AccessMethod = OID_OCSP then
            begin
              // accessLocation 是 GeneralName
              // uniformResourceIdentifier [6] IA5String
              if AccessNode.GetChild(1).IsContextTag(6) then
              begin
                Result := AccessNode.GetChild(1).AsString;
                Exit;
              end;
            end;
          end;
        finally
          Node.Free;
        end;
      finally
        Reader.Free;
      end;
    end;
  end;
end;

function CompareCertID(const A, B: TOCSPCertID): Boolean;
var
  I: Integer;
begin
  Result := False;

  // 比较哈希算法
  if A.HashAlgorithm <> B.HashAlgorithm then
    Exit;

  // 比较颁发者名称哈希
  if Length(A.IssuerNameHash) <> Length(B.IssuerNameHash) then
    Exit;
  for I := 0 to High(A.IssuerNameHash) do
    if A.IssuerNameHash[I] <> B.IssuerNameHash[I] then
      Exit;

  // 比较颁发者公钥哈希
  if Length(A.IssuerKeyHash) <> Length(B.IssuerKeyHash) then
    Exit;
  for I := 0 to High(A.IssuerKeyHash) do
    if A.IssuerKeyHash[I] <> B.IssuerKeyHash[I] then
      Exit;

  // 比较序列号
  if Length(A.SerialNumber) <> Length(B.SerialNumber) then
    Exit;
  for I := 0 to High(A.SerialNumber) do
    if A.SerialNumber[I] <> B.SerialNumber[I] then
      Exit;

  Result := True;
end;

{$WARN 6018 OFF}
function OCSPStatusToString(AStatus: TOCSPCertStatus): string;
begin
  case AStatus of
    ocspGood:    Result := 'Good';
    ocspRevoked: Result := 'Revoked';
    ocspUnknown: Result := 'Unknown';
  else
    Result := 'Invalid';
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function OCSPResponseStatusToString(AStatus: TOCSPResponseStatus): string;
begin
  case AStatus of
    ocsprsSuccessful:        Result := 'Successful';
    ocsprsMalformedRequest:  Result := 'Malformed Request';
    ocsprsInternalError:     Result := 'Internal Error';
    ocsprsTryLater:          Result := 'Try Later';
    ocsprsSignatureRequired: Result := 'Signature Required';
    ocsprsUnauthorized:      Result := 'Unauthorized';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

end.
