unit nextpas.core.tls.crl;

{$mode objfpc}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$modeswitch advancedrecords}

{
  CRL (Certificate Revocation List) 纯 Pascal 实现

  基于 RFC 5280 实现 X.509 CRL 解析。
  使用 nextpas.core.tls.asn1 和 nextpas.core.tls.x509 模块。

  CRL 用于发布已吊销证书的列表。

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.asn1, nextpas.core.tls.x509;

type
  // ========================================================================
  // 吊销原因 (与 OCSP 一致)
  // ========================================================================
  TCRLRevokeReason = (
    crlrrUnspecified,         // 未指定
    crlrrKeyCompromise,       // 密钥泄露
    crlrrCACompromise,        // CA 泄露
    crlrrAffiliationChanged,  // 从属关系变更
    crlrrSuperseded,          // 被取代
    crlrrCessationOfOperation,// 停止运营
    crlrrCertificateHold,     // 证书暂停
    crlrrRemoveFromCRL,       // 从 CRL 移除
    crlrrPrivilegeWithdrawn,  // 权限撤回
    crlrrAACompromise         // AA 泄露
  );

  // ========================================================================
  // 吊销条目
  // ========================================================================
  TCRLEntry = record
    SerialNumber: TBytes;      // 被吊销证书的序列号
    RevocationDate: TDateTime; // 吊销日期
    Reason: TCRLRevokeReason;  // 吊销原因 (可选)
    HasReason: Boolean;        // 是否有明确的吊销原因
    InvalidityDate: TDateTime; // 失效日期 (可选)
    HasInvalidityDate: Boolean;// 是否有失效日期
  end;

  TCRLEntryArray = array of TCRLEntry;

  // ========================================================================
  // X.509 CRL
  // ========================================================================
  TX509CRL = class
  private
    FVersion: Integer;
    FSignatureAlgorithm: string;
    FIssuer: TX509Name;
    FThisUpdate: TDateTime;
    FNextUpdate: TDateTime;
    FHasNextUpdate: Boolean;
    FEntries: TCRLEntryArray;
    FExtensions: TX509Extensions;
    FRawData: TBytes;

    procedure ParseCRL(ARoot: TASN1Node);
    procedure ParseTBSCertList(ANode: TASN1Node);
    procedure ParseRevokedCertificates(ANode: TASN1Node);
    procedure ParseCRLEntry(ANode: TASN1Node; var AEntry: TCRLEntry);
    procedure ParseEntryExtensions(ANode: TASN1Node; var AEntry: TCRLEntry);
    procedure ParseExtensions(ANode: TASN1Node);
    procedure ParseName(ANameNode: TASN1Node; out AName: TX509Name);
    function GetEntryCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    // 加载 CRL
    procedure LoadFromDER(const AData: TBytes);
    procedure LoadFromPEM(const APEMText: string);
    procedure LoadFromFile(const AFileName: string);

    // 检查证书是否被吊销
    function IsRevoked(const ASerialNumber: TBytes): Boolean;
    function IsRevokedHex(const ASerialHex: string): Boolean;
    function GetRevokedEntry(const ASerialNumber: TBytes): TCRLEntry;

    // 验证 CRL 有效期
    function IsExpired: Boolean;
    function IsValid: Boolean;  // 当前时间在有效期内

    // 属性
    property Version: Integer read FVersion;
    property SignatureAlgorithm: string read FSignatureAlgorithm;
    property Issuer: TX509Name read FIssuer;
    property ThisUpdate: TDateTime read FThisUpdate;
    property NextUpdate: TDateTime read FNextUpdate;
    property HasNextUpdate: Boolean read FHasNextUpdate;
    property Entries: TCRLEntryArray read FEntries;
    property Extensions: TX509Extensions read FExtensions;
    property EntryCount: Integer read GetEntryCount;
  end;

// ========================================================================
// 辅助函数
// ========================================================================

// 从证书中提取 CRL 分发点 URL
function GetCRLURLFromCertificate(ACert: TX509Certificate): string;
function GetCRLURLsFromCertificate(ACert: TX509Certificate): TStringArray;

// 比较序列号
function CompareSerialNumber(const A, B: TBytes): Boolean;

// 序列号转换
function SerialNumberToHex(const ASerial: TBytes): string;
function HexToSerialNumber(const AHex: string): TBytes;

// 吊销原因转字符串
function CRLRevokeReasonToString(AReason: TCRLRevokeReason): string;

implementation

uses
  nextpas.core.time;

// ========================================================================
// Forward declarations
// ========================================================================
function DecodeBase64(const AInput: string): TBytes; forward;

// ========================================================================
// OID 常量
// ========================================================================
const
  OID_CRL_DISTRIBUTION_POINTS = '2.5.29.31';
  OID_CRL_REASON = '2.5.29.21';
  OID_INVALIDITY_DATE = '2.5.29.24';
  OID_CRL_NUMBER = '2.5.29.20';
  OID_DELTA_CRL_INDICATOR = '2.5.29.27';

// ========================================================================
// TX509CRL
// ========================================================================

constructor TX509CRL.Create;
begin
  inherited Create;
  FVersion := 1;  // v1 是默认值
  FSignatureAlgorithm := '';
  FillChar(FIssuer, SizeOf(FIssuer), 0);
  SetLength(FIssuer.Attributes, 0);
  FThisUpdate := 0;
  FNextUpdate := 0;
  FHasNextUpdate := False;
  SetLength(FEntries, 0);
  SetLength(FExtensions, 0);
  SetLength(FRawData, 0);
end;

destructor TX509CRL.Destroy;
begin
  inherited Destroy;
end;

function TX509CRL.GetEntryCount: Integer;
begin
  Result := Length(FEntries);
end;

procedure TX509CRL.LoadFromDER(const AData: TBytes);
var
  Reader: TASN1Reader;
  Root: TASN1Node;
begin
  FRawData := Copy(AData, 0, Length(AData));

  Reader := TASN1Reader.Create(AData);
  try
    Root := Reader.Parse;
    if Root = nil then
      raise Exception.Create('Invalid CRL: failed to parse DER data');

    try
      ParseCRL(Root);
    finally
      Root.Free;
    end;
  finally
    Reader.Free;
  end;
end;

procedure TX509CRL.LoadFromPEM(const APEMText: string);
var
  StartPos, EndPos: Integer;
  Base64Data: string;
  DERData: TBytes;
begin
  // 查找 BEGIN 和 END 标记
  StartPos := Pos('-----BEGIN X509 CRL-----', APEMText);
  if StartPos = 0 then
    raise Exception.Create('Invalid PEM: missing BEGIN marker');

  StartPos := StartPos + Length('-----BEGIN X509 CRL-----');
  EndPos := Pos('-----END X509 CRL-----', APEMText);
  if EndPos = 0 then
    raise Exception.Create('Invalid PEM: missing END marker');

  // 提取 Base64 数据
  Base64Data := Copy(APEMText, StartPos, EndPos - StartPos);

  // 解码 Base64
  DERData := DecodeBase64(Base64Data);

  // 加载 DER 数据
  LoadFromDER(DERData);
end;

procedure TX509CRL.LoadFromFile(const AFileName: string);
var
  Stream: TFileStream;
  Data: TBytes;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Data, Stream.Size);
    if Stream.Size > 0 then
    begin
      Stream.ReadBuffer(Data[0], Stream.Size);

      // 检测格式
      if (Length(Data) > 0) and (Data[0] = $30) then
        // DER 格式
        LoadFromDER(Data)
      else
        // 假设是 PEM 格式
        LoadFromPEM(AnsiString(TEncoding.UTF8.GetString(Data)));
    end;
  finally
    Stream.Free;
  end;
end;

procedure TX509CRL.ParseCRL(ARoot: TASN1Node);
var
  TBSNode, AlgNode: TASN1Node;
begin
  // CertificateList ::= SEQUENCE {
  //   tbsCertList        TBSCertList,
  //   signatureAlgorithm AlgorithmIdentifier,
  //   signatureValue     BIT STRING }

  if not ARoot.IsSequence then
    raise Exception.Create('Invalid CRL: root is not SEQUENCE');

  if ARoot.ChildCount < 3 then
    raise Exception.Create('Invalid CRL: insufficient elements');

  // tbsCertList
  TBSNode := ARoot.GetChild(0);
  ParseTBSCertList(TBSNode);

  // signatureAlgorithm
  AlgNode := ARoot.GetChild(1);
  if AlgNode.IsSequence and (AlgNode.ChildCount >= 1) then
    FSignatureAlgorithm := AlgNode.GetChild(0).AsOID;
end;

procedure TX509CRL.ParseTBSCertList(ANode: TASN1Node);
var
  Index: Integer;
  Child: TASN1Node;
begin
  // TBSCertList ::= SEQUENCE {
  //   version              Version OPTIONAL, -- if present, MUST be v2
  //   signature            AlgorithmIdentifier,
  //   issuer               Name,
  //   thisUpdate           Time,
  //   nextUpdate           Time OPTIONAL,
  //   revokedCertificates  SEQUENCE OF SEQUENCE { ... } OPTIONAL,
  //   crlExtensions        [0] EXPLICIT Extensions OPTIONAL }

  if not ANode.IsSequence then
    raise Exception.Create('Invalid CRL: TBSCertList is not SEQUENCE');

  Index := 0;

  // version (可选) - 如果第一个元素是 INTEGER，则是版本号
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsInteger then
  begin
    FVersion := ANode.GetChild(Index).AsInteger + 1;  // 0 = v1, 1 = v2
    Inc(Index);
  end
  else
    FVersion := 1;

  // signature (AlgorithmIdentifier)
  if ANode.ChildCount > Index then
  begin
    Child := ANode.GetChild(Index);
    if Child.IsSequence and (Child.ChildCount >= 1) then
      FSignatureAlgorithm := Child.GetChild(0).AsOID;
    Inc(Index);
  end;

  // issuer
  if ANode.ChildCount > Index then
  begin
    ParseName(ANode.GetChild(Index), FIssuer);
    Inc(Index);
  end;

  // thisUpdate
  if ANode.ChildCount > Index then
  begin
    FThisUpdate := ANode.GetChild(Index).AsDateTime;
    Inc(Index);
  end;

  // nextUpdate (可选)
  FHasNextUpdate := False;
  if (ANode.ChildCount > Index) and
    (ANode.GetChild(Index).IsUTCTime or ANode.GetChild(Index).IsGeneralizedTime) then
  begin
    FNextUpdate := ANode.GetChild(Index).AsDateTime;
    FHasNextUpdate := True;
    Inc(Index);
  end;

  // revokedCertificates (可选)
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsSequence then
  begin
    ParseRevokedCertificates(ANode.GetChild(Index));
    Inc(Index);
  end;

  // crlExtensions [0] (可选)
  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsContextTag(0) then
  begin
    Child := ANode.GetChild(Index);
    if Child.ChildCount > 0 then
      ParseExtensions(Child.GetChild(0));
  end;
end;

procedure TX509CRL.ParseRevokedCertificates(ANode: TASN1Node);
var
  I: Integer;
  Entry: TCRLEntry;
begin
  if not ANode.IsSequence then
    Exit;

  SetLength(FEntries, ANode.ChildCount);

  for I := 0 to ANode.ChildCount - 1 do
  begin
    FillChar(Entry, SizeOf(Entry), 0);
    ParseCRLEntry(ANode.GetChild(I), Entry);
    FEntries[I] := Entry;
  end;
end;

procedure TX509CRL.ParseCRLEntry(ANode: TASN1Node; var AEntry: TCRLEntry);
var
  Index: Integer;
begin
  // SEQUENCE {
  //   userCertificate    CertificateSerialNumber,
  //   revocationDate     Time,
  //   crlEntryExtensions Extensions OPTIONAL }

  if not ANode.IsSequence then
    Exit;

  Index := 0;

  // userCertificate (序列号)
  if ANode.ChildCount > Index then
  begin
    AEntry.SerialNumber := ANode.GetChild(Index).AsBigInteger;
    Inc(Index);
  end;

  // revocationDate
  if ANode.ChildCount > Index then
  begin
    AEntry.RevocationDate := ANode.GetChild(Index).AsDateTime;
    Inc(Index);
  end;

  // crlEntryExtensions (可选)
  AEntry.HasReason := False;
  AEntry.Reason := crlrrUnspecified;
  AEntry.HasInvalidityDate := False;

  if (ANode.ChildCount > Index) and ANode.GetChild(Index).IsSequence then
    ParseEntryExtensions(ANode.GetChild(Index), AEntry);
end;

procedure TX509CRL.ParseEntryExtensions(ANode: TASN1Node; var AEntry: TCRLEntry);
var
  I: Integer;
  ExtNode, OIDNode, ValueNode: TASN1Node;
  ExtOID: string;
  ValueReader: TASN1Reader;
  ValueRoot: TASN1Node;
begin
  // SEQUENCE OF Extension
  // Extension ::= SEQUENCE {
  //   extnID      OBJECT IDENTIFIER,
  //   critical    BOOLEAN DEFAULT FALSE,
  //   extnValue   OCTET STRING }

  for I := 0 to ANode.ChildCount - 1 do
  begin
    ExtNode := ANode.GetChild(I);
    if not ExtNode.IsSequence then
      Continue;
    if ExtNode.ChildCount < 2 then
      Continue;

    OIDNode := ExtNode.GetChild(0);
    ExtOID := OIDNode.AsOID;

    // 获取 extnValue (跳过可选的 critical)
    if ExtNode.ChildCount >= 3 then
      ValueNode := ExtNode.GetChild(2)
    else
      ValueNode := ExtNode.GetChild(1);

    if not ValueNode.IsOctetString then
      Continue;

    // 解析扩展值
    if ExtOID = OID_CRL_REASON then
    begin
      // CRLReason ::= ENUMERATED
      ValueReader := TASN1Reader.Create(ValueNode.AsOctetString);
      try
        ValueRoot := ValueReader.Parse;
        if (ValueRoot <> nil) and (ValueRoot.Tag.TagNumber = ASN1_TAG_ENUMERATED) then
        begin
          AEntry.Reason := TCRLRevokeReason(ValueRoot.AsInteger);
          AEntry.HasReason := True;
        end;
        if ValueRoot <> nil then
          ValueRoot.Free;
      finally
        ValueReader.Free;
      end;
    end
    else if ExtOID = OID_INVALIDITY_DATE then
    begin
      // InvalidityDate ::= GeneralizedTime
      ValueReader := TASN1Reader.Create(ValueNode.AsOctetString);
      try
        ValueRoot := ValueReader.Parse;
        if ValueRoot <> nil then
        begin
          AEntry.InvalidityDate := ValueRoot.AsDateTime;
          AEntry.HasInvalidityDate := True;
          ValueRoot.Free;
        end;
      finally
        ValueReader.Free;
      end;
    end;
  end;
end;

procedure TX509CRL.ParseExtensions(ANode: TASN1Node);
var
  I: Integer;
  ExtNode: TASN1Node;
  Ext: TX509Extension;
begin
  if not ANode.IsSequence then
    Exit;

  SetLength(FExtensions, ANode.ChildCount);

  for I := 0 to ANode.ChildCount - 1 do
  begin
    ExtNode := ANode.GetChild(I);
    FillChar(Ext, SizeOf(Ext), 0);

    if ExtNode.IsSequence and (ExtNode.ChildCount >= 2) then
    begin
      Ext.OID := ExtNode.GetChild(0).AsOID;

      // critical (可选)
      if (ExtNode.ChildCount >= 3) and ExtNode.GetChild(1).IsBoolean then
      begin
        Ext.Critical := ExtNode.GetChild(1).AsBoolean;
        Ext.Value := ExtNode.GetChild(2).AsOctetString;
      end
      else
      begin
        Ext.Critical := False;
        Ext.Value := ExtNode.GetChild(1).AsOctetString;
      end;
    end;

    FExtensions[I] := Ext;
  end;
end;

procedure TX509CRL.ParseName(ANameNode: TASN1Node; out AName: TX509Name);
var
  I, J: Integer;
  RDNNode, AVANode: TASN1Node;
  Attr: TX509NameAttribute;
begin
  SetLength(AName.Attributes, 0);

  if not ANameNode.IsSequence then
    Exit;

  // Name ::= SEQUENCE OF RelativeDistinguishedName
  for I := 0 to ANameNode.ChildCount - 1 do
  begin
    RDNNode := ANameNode.GetChild(I);
    if not RDNNode.IsSet then
      Continue;

    // RelativeDistinguishedName ::= SET OF AttributeTypeAndValue
    for J := 0 to RDNNode.ChildCount - 1 do
    begin
      AVANode := RDNNode.GetChild(J);
      if not AVANode.IsSequence then
        Continue;
      if AVANode.ChildCount < 2 then
        Continue;

      // AttributeTypeAndValue ::= SEQUENCE {
      //   type   OBJECT IDENTIFIER,
      //   value  ANY }
      FillChar(Attr, SizeOf(Attr), 0);
      Attr.OID := AVANode.GetChild(0).AsOID;
      Attr.Name := OIDToName(Attr.OID);
      Attr.Value := AVANode.GetChild(1).AsString;

      SetLength(AName.Attributes, Length(AName.Attributes) + 1);
      AName.Attributes[High(AName.Attributes)] := Attr;
    end;
  end;
end;

function TX509CRL.IsRevoked(const ASerialNumber: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FEntries) do
  begin
    if CompareSerialNumber(FEntries[I].SerialNumber, ASerialNumber) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TX509CRL.IsRevokedHex(const ASerialHex: string): Boolean;
begin
  Result := IsRevoked(HexToSerialNumber(ASerialHex));
end;

function TX509CRL.GetRevokedEntry(const ASerialNumber: TBytes): TCRLEntry;
var
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  for I := 0 to High(FEntries) do
  begin
    if CompareSerialNumber(FEntries[I].SerialNumber, ASerialNumber) then
    begin
      Result := FEntries[I];
      Exit;
    end;
  end;
end;

function TX509CRL.IsExpired: Boolean;
begin
  if FHasNextUpdate then
    Result := DateTimeUtcNow > FNextUpdate
  else
    Result := False;  // 无 nextUpdate 时不认为过期
end;

function TX509CRL.IsValid: Boolean;
begin
  // ThisUpdate 必须有效 (非零) 且当前时间在 thisUpdate 之后
  Result := (FThisUpdate > 0) and (DateTimeUtcNow >= FThisUpdate) and (not IsExpired);
end;

// ========================================================================
// 辅助函数实现
// ========================================================================

function GetCRLURLFromCertificate(ACert: TX509Certificate): string;
var
  URLs: TStringArray;
begin
  URLs := GetCRLURLsFromCertificate(ACert);
  if Length(URLs) > 0 then
    Result := URLs[0]
  else
    Result := '';
end;

function GetCRLURLsFromCertificate(ACert: TX509Certificate): TStringArray;
var
  I, J: Integer;
  Ext: TX509Extension;
  Reader: TASN1Reader;
  Node, DPNode, DPNameNode, NameNode, URINode: TASN1Node;
  URLList: TStringList;
begin
  SetLength(Result, 0);
  URLList := TStringList.Create;
  try
    // 查找 CRL Distribution Points 扩展
    for I := 0 to High(ACert.Extensions) do
    begin
      Ext := ACert.Extensions[I];
      if Ext.OID = OID_CRL_DISTRIBUTION_POINTS then
      begin
        if Length(Ext.Value) = 0 then
          Continue;

        Reader := TASN1Reader.Create(Ext.Value);
        try
          Node := Reader.Parse;
          if Node = nil then
            Continue;

          try
            // CRLDistributionPoints ::= SEQUENCE SIZE (1..MAX) OF DistributionPoint
            if not Node.IsSequence then
              Continue;

            for J := 0 to Node.ChildCount - 1 do
            begin
              DPNode := Node.GetChild(J);
              if not DPNode.IsSequence then
                Continue;

              // DistributionPoint ::= SEQUENCE {
              //   distributionPoint [0] DistributionPointName OPTIONAL,
              //   reasons           [1] ReasonFlags OPTIONAL,
              //   cRLIssuer         [2] GeneralNames OPTIONAL }

              if DPNode.ChildCount < 1 then
                Continue;

              DPNameNode := DPNode.GetChild(0);
              if not DPNameNode.IsContextTag(0) then
                Continue;

              // DistributionPointName ::= CHOICE {
              //   fullName [0] GeneralNames,
              //   nameRelativeToCRLIssuer [1] RelativeDistinguishedName }

              if DPNameNode.ChildCount < 1 then
                Continue;

              NameNode := DPNameNode.GetChild(0);
              if NameNode.IsContextTag(0) then  // fullName
              begin
                // GeneralNames ::= SEQUENCE SIZE (1..MAX) OF GeneralName
                // GeneralName ::= CHOICE { ... uniformResourceIdentifier [6] IA5String ... }
                if NameNode.ChildCount > 0 then
                begin
                  URINode := NameNode.GetChild(0);
                  if URINode.IsContextTag(6) then
                    URLList.Add(URINode.AsString);
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

    // 转换为数组
    SetLength(Result, URLList.Count);
    for I := 0 to URLList.Count - 1 do
      Result[I] := URLList[I];
  finally
    URLList.Free;
  end;
end;

function CompareSerialNumber(const A, B: TBytes): Boolean;
var
  I, StartA, StartB, LenA, LenB: Integer;
begin
  Result := False;

  // 跳过前导零
  StartA := 0;
  while (StartA < Length(A) - 1) and (A[StartA] = 0) do
    Inc(StartA);

  StartB := 0;
  while (StartB < Length(B) - 1) and (B[StartB] = 0) do
    Inc(StartB);

  LenA := Length(A) - StartA;
  LenB := Length(B) - StartB;

  if LenA <> LenB then
    Exit;

  for I := 0 to LenA - 1 do
    if A[StartA + I] <> B[StartB + I] then
      Exit;

  Result := True;
end;

function SerialNumberToHex(const ASerial: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ASerial) do
    Result := Result + LowerCase(IntToHex(ASerial[I], 2));
end;

function HexToSerialNumber(const AHex: string): TBytes;
var
  I, Len: Integer;
  CleanHex: string;
begin
  // 移除空格和冒号
  CleanHex := '';
  for I := 1 to Length(AHex) do
    if AHex[I] in ['0'..'9', 'A'..'F', 'a'..'f'] then
      CleanHex := CleanHex + AHex[I];

  Len := Length(CleanHex) div 2;
  SetLength(Result, Len);

  for I := 0 to Len - 1 do
    Result[I] := StrToInt('$' + Copy(CleanHex, I * 2 + 1, 2));
end;

{$WARN 6018 OFF}
function CRLRevokeReasonToString(AReason: TCRLRevokeReason): string;
begin
  case AReason of
    crlrrUnspecified:          Result := 'Unspecified';
    crlrrKeyCompromise:        Result := 'Key Compromise';
    crlrrCACompromise:         Result := 'CA Compromise';
    crlrrAffiliationChanged:   Result := 'Affiliation Changed';
    crlrrSuperseded:           Result := 'Superseded';
    crlrrCessationOfOperation: Result := 'Cessation of Operation';
    crlrrCertificateHold:      Result := 'Certificate Hold';
    crlrrRemoveFromCRL:        Result := 'Remove from CRL';
    crlrrPrivilegeWithdrawn:   Result := 'Privilege Withdrawn';
    crlrrAACompromise:         Result := 'AA Compromise';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

// Base64 解码辅助函数 (从 nextpas.core.tls.pem 简化)
function DecodeBase64(const AInput: string): TBytes;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, J, Value: Integer;
  C: Char;
  Pad: Integer;
  DecodeTable: array[0..127] of Integer;
  CleanInput: string;
begin
  // 移除所有空白字符
  CleanInput := '';
  for I := 1 to Length(AInput) do
  begin
    C := AInput[I];
    if not (C in [#9, #10, #13, ' ']) then
      CleanInput := CleanInput + C;
  end;

  if CleanInput = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 初始化解码表
  for I := 0 to 127 do
    DecodeTable[I] := -1;
  for I := 1 to Length(Base64Chars) do
    DecodeTable[Ord(Base64Chars[I])] := I - 1;

  // 计算输出长度
  Pad := 0;
  if (Length(CleanInput) > 0) and (CleanInput[Length(CleanInput)] = '=') then
    Inc(Pad);
  if (Length(CleanInput) > 1) and (CleanInput[Length(CleanInput) - 1] = '=') then
    Inc(Pad);

  SetLength(Result, (Length(CleanInput) * 3) div 4 - Pad);

  J := 0;
  I := 1;
  while I <= Length(CleanInput) - 3 do
  begin
    Value := 0;

    C := CleanInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := DecodeTable[Ord(C)] shl 18;
    Inc(I);

    C := CleanInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := Value or (DecodeTable[Ord(C)] shl 12);
    Inc(I);

    C := CleanInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or (DecodeTable[Ord(C)] shl 6);
    end;
    Inc(I);

    C := CleanInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or DecodeTable[Ord(C)];
    end;
    Inc(I);

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

end.
