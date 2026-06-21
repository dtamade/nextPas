unit nextpas.core.tls.x509;

{$mode objfpc}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$modeswitch advancedrecords}

{
  X.509 证书解析器 - 纯 Pascal 实现

  基于 nextpas.core.tls.asn1 模块解析 X.509 v3 证书。
  支持 DER 和 PEM 格式。

  X.509 证书结构 (RFC 5280):
  Certificate ::= SEQUENCE [
    tbsCertificate       TBSCertificate,
    signatureAlgorithm   AlgorithmIdentifier,
    signatureValue       BIT STRING
  ]

  TBSCertificate ::= SEQUENCE [
    version         [0]  EXPLICIT Version DEFAULT v1,
    serialNumber         CertificateSerialNumber,
    signature            AlgorithmIdentifier,
    issuer               Name,
    validity             Validity,
    subject              Name,
    subjectPublicKeyInfo SubjectPublicKeyInfo,
    issuerUniqueID  [1]  IMPLICIT UniqueIdentifier OPTIONAL,
    subjectUniqueID [2]  IMPLICIT UniqueIdentifier OPTIONAL,
    extensions      [3]  EXPLICIT Extensions OPTIONAL
  ]

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.system.classes,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.time,
  nextpas.core.tls.asn1;

type
  // ========================================================================
  // 异常类型
  // ========================================================================
  EX509Exception = class(Exception);
  EX509ParseException = class(EX509Exception);

  // 字符串数组类型（避免与 SysUtils 冲突）
  TX509StringArray = array of string;

  // ========================================================================
  // X.509 版本
  // ========================================================================
  TX509Version = (
    x509v1 = 0,
    x509v2 = 1,
    x509v3 = 2
  );

  // ========================================================================
  // 算法标识符
  // ========================================================================
  TX509AlgorithmIdentifier = record
    OID: string;
    Name: string;
    Parameters: TBytes;  // 可选参数

    function ToString: string;
  end;

  // ========================================================================
  // X.500 名称属性
  // ========================================================================
  TX509NameAttribute = record
    OID: string;
    Name: string;   // 短名称 (CN, O, OU, etc.)
    Value: string;
  end;

  TX509NameAttributes = array of TX509NameAttribute;

  // ========================================================================
  // X.500 名称 (DN)
  // ========================================================================
  TX509Name = record
    Attributes: TX509NameAttributes;

    function GetAttribute(const AOIDOrName: string): string;
    function CommonName: string;
    function Organization: string;
    function OrganizationalUnit: string;
    function Country: string;
    function State: string;
    function Locality: string;
    function EmailAddress: string;
    function ToString: string;
  end;

  // ========================================================================
  // 有效期
  // ========================================================================
  TX509Validity = record
    NotBefore: TDateTime;
    NotAfter: TDateTime;

    function IsValid: Boolean;
    function IsValidAt(ATime: TDateTime): Boolean;
    function ToString: string;
  end;

  // ========================================================================
  // 公钥信息
  // ========================================================================
  TX509PublicKeyInfo = record
    Algorithm: TX509AlgorithmIdentifier;
    PublicKey: TBytes;      // 原始公钥数据
    KeyType: string;        // RSA, ECDSA, etc.
    KeySize: Integer;       // 密钥大小 (bits)

    // RSA 特有
    RSAModulus: TBytes;
    RSAExponent: TBytes;

    // ECDSA 特有
    ECCurve: string;
    ECPoint: TBytes;

    function ToString: string;
  end;

  // ========================================================================
  // 扩展基类
  // ========================================================================
  TX509Extension = record
    OID: string;
    Name: string;
    Critical: Boolean;
    Value: TBytes;

    function ToString: string;
  end;

  TX509Extensions = array of TX509Extension;

  // ========================================================================
  // 密钥用途
  // ========================================================================
  TX509KeyUsage = set of (
    kuDigitalSignature,
    kuNonRepudiation,
    kuKeyEncipherment,
    kuDataEncipherment,
    kuKeyAgreement,
    kuKeyCertSign,
    kuCRLSign,
    kuEncipherOnly,
    kuDecipherOnly
  );

  // ========================================================================
  // 扩展密钥用途
  // ========================================================================
  TX509ExtKeyUsage = set of (
    ekuServerAuth,
    ekuClientAuth,
    ekuCodeSigning,
    ekuEmailProtection,
    ekuTimeStamping,
    ekuOCSPSigning
  );

  // ========================================================================
  // 基本约束
  // ========================================================================
  TX509BasicConstraints = record
    IsCA: Boolean;
    PathLenConstraint: Integer;  // -1 表示无限制
    HasPathLen: Boolean;
  end;

  // ========================================================================
  // 主题替代名称类型
  // ========================================================================
  TX509SANType = (
    sanOtherName,
    sanRFC822Name,     // Email
    sanDNSName,
    sanX400Address,
    sanDirectoryName,
    sanEdiPartyName,
    sanURI,
    sanIPAddress,
    sanRegisteredID
  );

  TX509SubjectAltName = record
    SANType: TX509SANType;
    Value: string;
  end;

  TX509SubjectAltNames = array of TX509SubjectAltName;

  // ========================================================================
  // X.509 证书
  // ========================================================================
  TX509Certificate = class
  private
    FVersion: TX509Version;
    FSerialNumber: TBytes;
    FSignatureAlgorithm: TX509AlgorithmIdentifier;
    FIssuer: TX509Name;
    FValidity: TX509Validity;
    FSubject: TX509Name;
    FPublicKeyInfo: TX509PublicKeyInfo;
    FExtensions: TX509Extensions;
    FSignature: TBytes;
    FRawTBSCertificate: TBytes;  // 用于签名验证
    FRawCertificate: TBytes;

    // 解析后的扩展
    FKeyUsage: TX509KeyUsage;
    FExtKeyUsage: TX509ExtKeyUsage;
    FBasicConstraints: TX509BasicConstraints;
    FSubjectAltNames: TX509SubjectAltNames;
    FSubjectKeyIdentifier: TBytes;
    FAuthorityKeyIdentifier: TBytes;

    procedure ParseFromASN1(ARoot: TASN1Node);
    procedure ParseTBSCertificate(ATBSNode: TASN1Node);
    procedure ParseName(ANameNode: TASN1Node; out AName: TX509Name);
    procedure ParseValidity(AValidityNode: TASN1Node);
    procedure ParsePublicKeyInfo(APKINode: TASN1Node);
    procedure ParseExtensions(AExtNode: TASN1Node);
    procedure ParseExtension(AExtNode: TASN1Node; var AExt: TX509Extension);
    procedure ProcessKnownExtensions;
  public
    constructor Create;
    destructor Destroy; override;

    // 加载证书
    procedure LoadFromDER(const AData: TBytes);
    procedure LoadFromPEM(const APEMData: string);
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromStream(AStream: TStream);

    // 基本信息
    property Version: TX509Version read FVersion;
    property SerialNumber: TBytes read FSerialNumber;
    property SignatureAlgorithm: TX509AlgorithmIdentifier read FSignatureAlgorithm;
    property Issuer: TX509Name read FIssuer;
    property Validity: TX509Validity read FValidity;
    property Subject: TX509Name read FSubject;
    property PublicKeyInfo: TX509PublicKeyInfo read FPublicKeyInfo;
    property Extensions: TX509Extensions read FExtensions;
    property Signature: TBytes read FSignature;

    // 解析后的扩展
    property KeyUsage: TX509KeyUsage read FKeyUsage;
    property ExtKeyUsage: TX509ExtKeyUsage read FExtKeyUsage;
    property BasicConstraints: TX509BasicConstraints read FBasicConstraints;
    property SubjectAltNames: TX509SubjectAltNames read FSubjectAltNames;
    property SubjectKeyIdentifier: TBytes read FSubjectKeyIdentifier;
    property AuthorityKeyIdentifier: TBytes read FAuthorityKeyIdentifier;

    // 原始数据
    property RawTBSCertificate: TBytes read FRawTBSCertificate;
    property RawCertificate: TBytes read FRawCertificate;

    // 便捷方法
    function SerialNumberAsHex: string;
    function IsCA: Boolean;
    function IsSelfSigned: Boolean;
    function IsValidNow: Boolean;
    function GetDNSNames: TX509StringArray;

    // 调试
    function Dump: string;
  end;

implementation

uses
  nextpas.core.text.strings;

// ========================================================================
// Base64 解码辅助函数 (必须在使用前声明)
// ========================================================================

function DecodeBase64(const AInput: string): TBytes;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, J, Value: Integer;
  C: Char;
  Pad: Integer;
  DecodeTable: array[0..127] of Integer;
begin
  // 初始化解码表
  for I := 0 to 127 do
    DecodeTable[I] := -1;
  for I := 1 to Length(Base64Chars) do
    DecodeTable[Ord(Base64Chars[I])] := I - 1;

  // 计算输出长度
  Pad := 0;
  if (Length(AInput) > 0) and (AInput[Length(AInput)] = '=') then
    Inc(Pad);
  if (Length(AInput) > 1) and (AInput[Length(AInput) - 1] = '=') then
    Inc(Pad);

  SetLength(Result, (Length(AInput) * 3) div 4 - Pad);

  J := 0;
  I := 1;
  while I <= Length(AInput) - 3 do
  begin
    // 读取4个字符
    Value := 0;
    C := AInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := DecodeTable[Ord(C)] shl 18;
    Inc(I);

    C := AInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := Value or (DecodeTable[Ord(C)] shl 12);
    Inc(I);

    C := AInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or (DecodeTable[Ord(C)] shl 6);
    end;
    Inc(I);

    C := AInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or DecodeTable[Ord(C)];
    end;
    Inc(I);

    // 输出3个字节
    if J < Length(Result) then
    begin
      Result[J] := Byte((Value shr 16) and $FF);
      Inc(J);
    end;
    if J < Length(Result) then
    begin
      Result[J] := Byte((Value shr 8) and $FF);
      Inc(J);
    end;
    if J < Length(Result) then
    begin
      Result[J] := Byte(Value and $FF);
      Inc(J);
    end;
  end;
end;

// ========================================================================
// TX509AlgorithmIdentifier
// ========================================================================

function TX509AlgorithmIdentifier.ToString: string;
begin
  if Name <> '' then
    Result := Name
  else
    Result := OID;
end;

// ========================================================================
// TX509Name
// ========================================================================

function TX509Name.GetAttribute(const AOIDOrName: string): string;
var
  I: Integer;
  UpperName: string;
begin
  Result := '';
  UpperName := UpperCase(AOIDOrName);

  for I := 0 to High(Attributes) do
  begin
    if (Attributes[I].OID = AOIDOrName) or
      (UpperCase(Attributes[I].Name) = UpperName) then
    begin
      Result := Attributes[I].Value;
      Exit;
    end;
  end;
end;

function TX509Name.CommonName: string;
begin
  Result := GetAttribute('CN');
end;

function TX509Name.Organization: string;
begin
  Result := GetAttribute('O');
end;

function TX509Name.OrganizationalUnit: string;
begin
  Result := GetAttribute('OU');
end;

function TX509Name.Country: string;
begin
  Result := GetAttribute('C');
end;

function TX509Name.State: string;
begin
  Result := GetAttribute('ST');
end;

function TX509Name.Locality: string;
begin
  Result := GetAttribute('L');
end;

function TX509Name.EmailAddress: string;
begin
  Result := GetAttribute('emailAddress');
end;

function TX509Name.ToString: string;
var
  I: Integer;
begin
  Result := '';
  for I := High(Attributes) downto 0 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Attributes[I].Name + '=' + Attributes[I].Value;
  end;
end;

// ========================================================================
// TX509Validity
// ========================================================================

function TX509Validity.IsValid: Boolean;
begin
  Result := IsValidAt(nextpas.core.time.DateTimeUtcNow);
end;

function TX509Validity.IsValidAt(ATime: TDateTime): Boolean;
begin
  Result := (ATime >= NotBefore) and (ATime <= NotAfter);
end;

function TX509Validity.ToString: string;
begin
  Result := nextpas.core.text.conv.Format('Not Before: %s, Not After: %s',
    [nextpas.core.time.DateTimeToStr(NotBefore), nextpas.core.time.DateTimeToStr(NotAfter)]);
end;

// ========================================================================
// TX509PublicKeyInfo
// ========================================================================

function TX509PublicKeyInfo.ToString: string;
begin
  Result := nextpas.core.text.conv.Format('%s (%d bits)', [KeyType, KeySize]);
end;

// ========================================================================
// TX509Extension
// ========================================================================

function TX509Extension.ToString: string;
begin
  if Critical then
    Result := nextpas.core.text.conv.Format('%s (critical)', [Name])
  else
    Result := Name;
end;

// ========================================================================
// TX509Certificate
// ========================================================================

constructor TX509Certificate.Create;
begin
  inherited Create;
  FVersion := x509v1;
  FBasicConstraints.PathLenConstraint := -1;
end;

destructor TX509Certificate.Destroy;
begin
  FRawTBSCertificate := nil;
  FRawCertificate := nil;
  inherited Destroy;
end;

procedure TX509Certificate.LoadFromDER(const AData: TBytes);
var
  Reader: TASN1Reader;
  Root: TASN1Node;
begin
  FRawCertificate := Copy(AData, 0, Length(AData));

  Reader := TASN1Reader.Create(AData);
  try
    Root := Reader.Parse;
    if Root = nil then
      raise EX509ParseException.Create('Failed to parse certificate');
    ParseFromASN1(Root);
  finally
    Root.Free;
    Reader.Free;
  end;
end;

procedure TX509Certificate.LoadFromPEM(const APEMData: string);
var
  StartMarker, EndMarker: string;
  StartPos, EndPos: Integer;
  Base64Data: string;
  DERData: TBytes;
  I: Integer;
  Line: string;
  Lines: TStringArray;
begin
  StartMarker := '-----BEGIN CERTIFICATE-----';
  EndMarker := '-----END CERTIFICATE-----';

  StartPos := Pos(StartMarker, APEMData);
  if StartPos = 0 then
    raise EX509ParseException.Create('Invalid PEM format: BEGIN marker not found');

  EndPos := Pos(EndMarker, APEMData);
  if EndPos = 0 then
    raise EX509ParseException.Create('Invalid PEM format: END marker not found');

  // 提取 Base64 内容
  Base64Data := Copy(APEMData, StartPos + Length(StartMarker),
    EndPos - StartPos - Length(StartMarker));

  // 移除空白字符
  Lines := StringsParseLines(Base64Data);
  Base64Data := '';
  for I := 0 to Length(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);
    if Line <> '' then
      Base64Data := Base64Data + Line;
  end;

  // Base64 解码
  DERData := DecodeBase64(Base64Data);

  LoadFromDER(DERData);
end;

procedure TX509Certificate.LoadFromFile(const AFileName: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TX509Certificate.LoadFromStream(AStream: TStream);
var
  Data: TBytes;
  FirstByte: Byte;
begin
  AStream.Position := 0;
  SetLength(Data, AStream.Size);
  if AStream.Size > 0 then
  begin
    AStream.ReadBuffer(Data[0], AStream.Size);

    // 检测格式
    FirstByte := Data[0];
    if FirstByte = $30 then
      // DER 格式 (以 SEQUENCE 开头)
      LoadFromDER(Data)
    else if (FirstByte = Ord('-')) or (FirstByte = Ord('M')) then
      // PEM 格式 (以 "-----" 或 "M" (Base64) 开头)
      LoadFromPEM(ASCIIBytesToString(Data))
    else
      raise EX509ParseException.Create('Unknown certificate format');
  end;
end;

procedure TX509Certificate.ParseFromASN1(ARoot: TASN1Node);
var
  TBSNode, SigAlgNode, SigNode: TASN1Node;
begin
  // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
  if not ARoot.IsSequence then
    raise EX509ParseException.Create('Certificate must be a SEQUENCE');

  if ARoot.ChildCount < 3 then
    raise EX509ParseException.Create('Certificate must have at least 3 elements');

  TBSNode := ARoot.GetChild(0);
  SigAlgNode := ARoot.GetChild(1);
  SigNode := ARoot.GetChild(2);

  // 提取原始 TBS 数据用于签名验证
  // TBS 数据包括标签、长度和内容
  if (Length(FRawCertificate) > 0) and (TBSNode.TotalLength > 0) then
  begin
    // TBS 起始位置 = 内容偏移 - 头部长度
    // TBS 长度 = 头部长度 + 内容长度
    SetLength(FRawTBSCertificate, TBSNode.TotalLength);
    Move(FRawCertificate[TBSNode.ContentOffset - TBSNode.HeaderLength],
      FRawTBSCertificate[0],
      TBSNode.TotalLength);
  end;

  // 解析 TBSCertificate
  ParseTBSCertificate(TBSNode);

  // 解析签名算法
  if SigAlgNode.IsSequence and (SigAlgNode.ChildCount >= 1) then
  begin
    if SigAlgNode.GetChild(0).IsOID then
    begin
      FSignatureAlgorithm.OID := SigAlgNode.GetChild(0).AsOID;
      FSignatureAlgorithm.Name := OIDToName(FSignatureAlgorithm.OID);
    end;
  end;

  // 解析签名值
  if SigNode.IsBitString then
    FSignature := SigNode.AsBitString;

  // 处理已知扩展
  ProcessKnownExtensions;
end;

procedure TX509Certificate.ParseTBSCertificate(ATBSNode: TASN1Node);
var
  Index: Integer;
  Child: TASN1Node;
begin
  if not ATBSNode.IsSequence then
    raise EX509ParseException.Create('TBSCertificate must be a SEQUENCE');

  Index := 0;

  // 版本 [0] EXPLICIT (可选)
  if (ATBSNode.ChildCount > Index) and
    ATBSNode.GetChild(Index).IsContextTag(0) then
  begin
    Child := ATBSNode.GetChild(Index);
    if Child.ChildCount > 0 then
      FVersion := TX509Version(Child.GetChild(0).AsInteger);
    Inc(Index);
  end
  else
    FVersion := x509v1;

  // 序列号
  if ATBSNode.ChildCount > Index then
  begin
    FSerialNumber := ATBSNode.GetChild(Index).AsBigInteger;
    Inc(Index);
  end;

  // 签名算法 (在 TBS 内)
  if ATBSNode.ChildCount > Index then
  begin
    Child := ATBSNode.GetChild(Index);
    if Child.IsSequence and (Child.ChildCount >= 1) then
    begin
      if Child.GetChild(0).IsOID then
      begin
        FSignatureAlgorithm.OID := Child.GetChild(0).AsOID;
        FSignatureAlgorithm.Name := OIDToName(FSignatureAlgorithm.OID);
      end;
    end;
    Inc(Index);
  end;

  // 颁发者
  if ATBSNode.ChildCount > Index then
  begin
    ParseName(ATBSNode.GetChild(Index), FIssuer);
    Inc(Index);
  end;

  // 有效期
  if ATBSNode.ChildCount > Index then
  begin
    ParseValidity(ATBSNode.GetChild(Index));
    Inc(Index);
  end;

  // 主题
  if ATBSNode.ChildCount > Index then
  begin
    ParseName(ATBSNode.GetChild(Index), FSubject);
    Inc(Index);
  end;

  // 公钥信息
  if ATBSNode.ChildCount > Index then
  begin
    ParsePublicKeyInfo(ATBSNode.GetChild(Index));
    Inc(Index);
  end;

  // 扩展 [3] EXPLICIT (v3)
  while Index < ATBSNode.ChildCount do
  begin
    Child := ATBSNode.GetChild(Index);
    if Child.IsContextTag(3) then
    begin
      // 扩展
      if Child.ChildCount > 0 then
        ParseExtensions(Child.GetChild(0));
    end;
    Inc(Index);
  end;
end;

procedure TX509Certificate.ParseName(ANameNode: TASN1Node; out AName: TX509Name);
var
  I, J: Integer;
  RDNNode, AVANode: TASN1Node;
  Attr: TX509NameAttribute;
begin
  SetLength(AName.Attributes, 0);

  if not ANameNode.IsSequence then
    Exit;

  for I := 0 to ANameNode.ChildCount - 1 do
  begin
    RDNNode := ANameNode.GetChild(I);
    if not RDNNode.IsSet then
      Continue;

    for J := 0 to RDNNode.ChildCount - 1 do
    begin
      AVANode := RDNNode.GetChild(J);
      if not AVANode.IsSequence then
        Continue;
      if AVANode.ChildCount < 2 then
        Continue;

      if AVANode.GetChild(0).IsOID then
      begin
        Attr.OID := AVANode.GetChild(0).AsOID;
        Attr.Name := OIDToName(Attr.OID);
        Attr.Value := AVANode.GetChild(1).AsString;

        SetLength(AName.Attributes, Length(AName.Attributes) + 1);
        AName.Attributes[High(AName.Attributes)] := Attr;
      end;
    end;
  end;
end;

procedure TX509Certificate.ParseValidity(AValidityNode: TASN1Node);
begin
  if not AValidityNode.IsSequence then
    Exit;
  if AValidityNode.ChildCount < 2 then
    Exit;

  FValidity.NotBefore := AValidityNode.GetChild(0).AsDateTime;
  FValidity.NotAfter := AValidityNode.GetChild(1).AsDateTime;
end;

procedure TX509Certificate.ParsePublicKeyInfo(APKINode: TASN1Node);
var
  AlgNode, KeyNode: TASN1Node;
  KeyData: TBytes;
  Reader: TASN1Reader;
  RSAKey: TASN1Node;
begin
  if not APKINode.IsSequence then
    Exit;
  if APKINode.ChildCount < 2 then
    Exit;

  AlgNode := APKINode.GetChild(0);
  KeyNode := APKINode.GetChild(1);

  // 解析算法
  if AlgNode.IsSequence and (AlgNode.ChildCount >= 1) then
  begin
    if AlgNode.GetChild(0).IsOID then
    begin
      FPublicKeyInfo.Algorithm.OID := AlgNode.GetChild(0).AsOID;
      FPublicKeyInfo.Algorithm.Name := OIDToName(FPublicKeyInfo.Algorithm.OID);
    end;

    // EC 曲线参数
    if (AlgNode.ChildCount >= 2) and AlgNode.GetChild(1).IsOID then
      FPublicKeyInfo.ECCurve := OIDToName(AlgNode.GetChild(1).AsOID);
  end;

  // 解析公钥
  if KeyNode.IsBitString then
  begin
    FPublicKeyInfo.PublicKey := KeyNode.AsBitString;

    // 确定密钥类型
    case FPublicKeyInfo.Algorithm.OID of
      '1.2.840.113549.1.1.1':  // rsaEncryption
      begin
        FPublicKeyInfo.KeyType := 'RSA';

        // 解析 RSA 公钥 (SEQUENCE { modulus, exponent })
        KeyData := FPublicKeyInfo.PublicKey;
        if Length(KeyData) > 0 then
        begin
          Reader := TASN1Reader.Create(KeyData);
          try
            RSAKey := Reader.Parse;
            if (RSAKey <> nil) and RSAKey.IsSequence and (RSAKey.ChildCount >= 2) then
            begin
              FPublicKeyInfo.RSAModulus := RSAKey.GetChild(0).AsBigInteger;
              FPublicKeyInfo.RSAExponent := RSAKey.GetChild(1).AsBigInteger;
              FPublicKeyInfo.KeySize := Length(FPublicKeyInfo.RSAModulus) * 8;
              // 调整前导零
              if (Length(FPublicKeyInfo.RSAModulus) > 0) and
                (FPublicKeyInfo.RSAModulus[0] = 0) then
                FPublicKeyInfo.KeySize := FPublicKeyInfo.KeySize - 8;
            end;
          finally
          end;
        end;
      end;

      '1.2.840.10045.2.1':  // ecPublicKey
      begin
        FPublicKeyInfo.KeyType := 'ECDSA';
        FPublicKeyInfo.ECPoint := FPublicKeyInfo.PublicKey;

        // 根据曲线确定密钥大小
        case FPublicKeyInfo.ECCurve of
          'prime256v1': FPublicKeyInfo.KeySize := 256;
          'secp384r1': FPublicKeyInfo.KeySize := 384;
          'secp521r1': FPublicKeyInfo.KeySize := 521;
        else
          FPublicKeyInfo.KeySize := (Length(FPublicKeyInfo.ECPoint) - 1) * 4;
        end;
      end;

      '1.3.101.112':  // Ed25519
      begin
        FPublicKeyInfo.KeyType := 'Ed25519';
        FPublicKeyInfo.KeySize := Length(FPublicKeyInfo.PublicKey) * 8;
      end;

      '1.3.101.113':  // Ed448
      begin
        FPublicKeyInfo.KeyType := 'Ed448';
        FPublicKeyInfo.KeySize := Length(FPublicKeyInfo.PublicKey) * 8;
      end;
    else
      FPublicKeyInfo.KeyType := 'Unknown';
    end;
  end;
end;

procedure TX509Certificate.ParseExtensions(AExtNode: TASN1Node);
var
  I: Integer;
begin
  if not AExtNode.IsSequence then
    Exit;

  SetLength(FExtensions, AExtNode.ChildCount);
  for I := 0 to AExtNode.ChildCount - 1 do
  begin
    ParseExtension(AExtNode.GetChild(I), FExtensions[I]);
  end;
end;

procedure TX509Certificate.ParseExtension(AExtNode: TASN1Node; var AExt: TX509Extension);
var
  Index: Integer;
begin
  if not AExtNode.IsSequence then
    Exit;

  Index := 0;

  // OID
  if AExtNode.ChildCount > Index then
  begin
    if AExtNode.GetChild(Index).IsOID then
    begin
      AExt.OID := AExtNode.GetChild(Index).AsOID;
      AExt.Name := OIDToName(AExt.OID);
    end;
    Inc(Index);
  end;

  // Critical (可选)
  AExt.Critical := False;
  if (AExtNode.ChildCount > Index) and AExtNode.GetChild(Index).IsBoolean then
  begin
    AExt.Critical := AExtNode.GetChild(Index).AsBoolean;
    Inc(Index);
  end;

  // Value (OCTET STRING)
  if (AExtNode.ChildCount > Index) and AExtNode.GetChild(Index).IsOctetString then
  begin
    AExt.Value := AExtNode.GetChild(Index).AsOctetString;
  end;
end;

procedure TX509Certificate.ProcessKnownExtensions;
var
  I: Integer;
  Reader: TASN1Reader;
  Node, Child: TASN1Node;
  KeyUsageBits: TBytes;
  BitValue: Integer;
  J: Integer;
  SAN: TX509SubjectAltName;
  SegValue: Word;
  IPv6Value: string;
begin
  for I := 0 to High(FExtensions) do
  begin
    case FExtensions[I].OID of
      '2.5.29.15':  // keyUsage
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsBitString then
            begin
              KeyUsageBits := Node.AsBitString;
              if Length(KeyUsageBits) > 0 then
              begin
                BitValue := KeyUsageBits[0];
                if (BitValue and $80) <> 0 then Include(FKeyUsage, kuDigitalSignature);
                if (BitValue and $40) <> 0 then Include(FKeyUsage, kuNonRepudiation);
                if (BitValue and $20) <> 0 then Include(FKeyUsage, kuKeyEncipherment);
                if (BitValue and $10) <> 0 then Include(FKeyUsage, kuDataEncipherment);
                if (BitValue and $08) <> 0 then Include(FKeyUsage, kuKeyAgreement);
                if (BitValue and $04) <> 0 then Include(FKeyUsage, kuKeyCertSign);
                if (BitValue and $02) <> 0 then Include(FKeyUsage, kuCRLSign);
                if (BitValue and $01) <> 0 then Include(FKeyUsage, kuEncipherOnly);
              end;
            end;
          finally
          end;
        end;
      end;

      '2.5.29.19':  // basicConstraints
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsSequence then
            begin
              // CA flag
              if (Node.ChildCount > 0) and Node.GetChild(0).IsBoolean then
                FBasicConstraints.IsCA := Node.GetChild(0).AsBoolean;
              // Path length
              if (Node.ChildCount > 1) and Node.GetChild(1).IsInteger then
              begin
                FBasicConstraints.HasPathLen := True;
                FBasicConstraints.PathLenConstraint := Node.GetChild(1).AsInteger;
              end;
            end;
          finally
          end;
        end;
      end;

      '2.5.29.17':  // subjectAltName
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsSequence then
            begin
              for J := 0 to Node.ChildCount - 1 do
              begin
                Child := Node.GetChild(J);
                SAN.Value := '';

                if Child.IsContextTag(2) then  // dNSName
                begin
                  SAN.SANType := sanDNSName;
                  SAN.Value := Child.AsString;
                end
                else if Child.IsContextTag(1) then  // rfc822Name (email)
                begin
                  SAN.SANType := sanRFC822Name;
                  SAN.Value := Child.AsString;
                end
                else if Child.IsContextTag(6) then  // uniformResourceIdentifier
                begin
                  SAN.SANType := sanURI;
                  SAN.Value := Child.AsString;
                end
                else if Child.IsContextTag(7) then  // iPAddress
                begin
                  SAN.SANType := sanIPAddress;
                  // 转换 IP 地址
                  if Length(Child.RawData) = 4 then
                    SAN.Value := nextpas.core.text.conv.Format('%d.%d.%d.%d',
                      [Child.RawData[0], Child.RawData[1], Child.RawData[2], Child.RawData[3]])
                  else if Length(Child.RawData) = 16 then
                  begin
                    IPv6Value := '';
                    for BitValue := 0 to 7 do
                    begin
                      SegValue := (Word(Child.RawData[BitValue * 2]) shl 8) or
                        Word(Child.RawData[BitValue * 2 + 1]);
                      if BitValue > 0 then
                        IPv6Value := IPv6Value + ':';
                      IPv6Value := IPv6Value + nextpas.core.text.conv.IntToHex(SegValue, 1);
                    end;
                    SAN.Value := IPv6Value;
                  end;
                end;

                if SAN.Value <> '' then
                begin
                  SetLength(FSubjectAltNames, Length(FSubjectAltNames) + 1);
                  FSubjectAltNames[High(FSubjectAltNames)] := SAN;
                end;
              end;
            end;
          finally
          end;
        end;
      end;

      '2.5.29.14':  // subjectKeyIdentifier
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsOctetString then
              FSubjectKeyIdentifier := Node.AsOctetString;
          finally
          end;
        end;
      end;

      '2.5.29.35':  // authorityKeyIdentifier
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsSequence then
            begin
              if (Node.ChildCount > 0) and Node.GetChild(0).IsContextTag(0) then
                FAuthorityKeyIdentifier := Node.GetChild(0).RawData;
            end;
          finally
          end;
        end;
      end;

      '2.5.29.37':  // extKeyUsage
      begin
        if Length(FExtensions[I].Value) > 0 then
        begin
          Reader := TASN1Reader.Create(FExtensions[I].Value);
          try
            Node := Reader.Parse;
            if (Node <> nil) and Node.IsSequence then
            begin
              for J := 0 to Node.ChildCount - 1 do
              begin
                if Node.GetChild(J).IsOID then
                begin
                  case Node.GetChild(J).AsOID of
                    '1.3.6.1.5.5.7.3.1': Include(FExtKeyUsage, ekuServerAuth);
                    '1.3.6.1.5.5.7.3.2': Include(FExtKeyUsage, ekuClientAuth);
                    '1.3.6.1.5.5.7.3.3': Include(FExtKeyUsage, ekuCodeSigning);
                    '1.3.6.1.5.5.7.3.4': Include(FExtKeyUsage, ekuEmailProtection);
                    '1.3.6.1.5.5.7.3.8': Include(FExtKeyUsage, ekuTimeStamping);
                    '1.3.6.1.5.5.7.3.9': Include(FExtKeyUsage, ekuOCSPSigning);
                  end;
                end;
              end;
            end;
          finally
          end;
        end;
      end;
    end;
  end;
end;

function TX509Certificate.SerialNumberAsHex: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FSerialNumber) do
    Result := Result + nextpas.core.text.conv.IntToHex(FSerialNumber[I], 2);
end;

function TX509Certificate.IsCA: Boolean;
begin
  Result := FBasicConstraints.IsCA;
end;

function TX509Certificate.IsSelfSigned: Boolean;
begin
  Result := FIssuer.ToString = FSubject.ToString;
end;

function TX509Certificate.IsValidNow: Boolean;
begin
  Result := FValidity.IsValid;
end;

function TX509Certificate.GetDNSNames: TX509StringArray;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to High(FSubjectAltNames) do
    if FSubjectAltNames[I].SANType = sanDNSName then
      Inc(Count);

  SetLength(Result, Count);
  Count := 0;
  for I := 0 to High(FSubjectAltNames) do
    if FSubjectAltNames[I].SANType = sanDNSName then
    begin
      Result[Count] := FSubjectAltNames[I].Value;
      Inc(Count);
    end;
end;

function TX509Certificate.Dump: string;
var
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('X.509 Certificate');
    SB.AppendLine('=================');
    SB.AppendLine('');

    SB.AppendLine('Version: v' + IntToStr(Ord(FVersion) + 1));
    SB.AppendLine('Serial Number: ' + SerialNumberAsHex);
    SB.AppendLine('Signature Algorithm: ' + FSignatureAlgorithm.ToString);
    SB.AppendLine('');

    SB.AppendLine('Issuer: ' + FIssuer.ToString);
    SB.AppendLine('Subject: ' + FSubject.ToString);
    SB.AppendLine('');

    SB.AppendLine('Validity:');
    SB.AppendLine('  Not Before: ' + nextpas.core.time.DateTimeToStr(FValidity.NotBefore));
    SB.AppendLine('  Not After: ' + nextpas.core.time.DateTimeToStr(FValidity.NotAfter));
    SB.AppendLine('');

    SB.AppendLine('Public Key:');
    SB.AppendLine('  Algorithm: ' + FPublicKeyInfo.Algorithm.ToString);
    SB.AppendLine('  Key Type: ' + FPublicKeyInfo.KeyType);
    SB.AppendLine('  Key Size: ' + IntToStr(FPublicKeyInfo.KeySize) + ' bits');
    SB.AppendLine('');

    if Length(FExtensions) > 0 then
    begin
      SB.AppendLine('Extensions:');
      for I := 0 to High(FExtensions) do
        SB.AppendLine('  ' + FExtensions[I].ToString);
      SB.AppendLine('');
    end;

    if Length(FSubjectAltNames) > 0 then
    begin
      SB.AppendLine('Subject Alternative Names:');
      for I := 0 to High(FSubjectAltNames) do
        SB.AppendLine('  ' + FSubjectAltNames[I].Value);
    end;

    Result := SB.ToString;
  finally
  end;
end;

end.
