{
  nextpas.core.tls.winssl.certificate - WinSSL 证书实现
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-06
  
  描述:
    实现 ISSLCertificate 接口的 WinSSL 后端。
    封装 Windows 证书上下文 (PCCERT_CONTEXT) 操作。
}

unit nextpas.core.tls.winssl.certificate;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  Windows, SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.utils,
  nextpas.core.tls.winssl.native_handle,
  nextpas.core.tls.utils;

type
  { TWinSSLCertificate - Windows 证书类 }
  TWinSSLCertificate = class(TInterfacedObject, ISSLCertificate, ISSLNativeHandleAccess)
  private
    FCertContext: PCCERT_CONTEXT;
    FOwnsContext: Boolean;
    FIssuerCert: ISSLCertificate;  // 颁发者证书引用

    function GetCertInfo: PCERT_INFO;
    function BinaryToHexString(const AData: PByte; ASize: DWORD): string;
    function CalculateFingerprint(AHashType: TSSLHash): string;
    
  public
    constructor Create(ACertContext: PCCERT_CONTEXT; AOwnsContext: Boolean = True);
    destructor Destroy; override;
    
    { ISSLCertificate - 加载和保存 }
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromStream(AStream: TStream): Boolean;
    function LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
    function LoadFromPEM(const APEM: string): Boolean;
    function LoadFromDER(const ADER: TBytes): Boolean;
    
    function SaveToFile(const AFileName: string): Boolean;
    function SaveToStream(AStream: TStream): Boolean;
    function SaveToPEM: string;
    function SaveToDER: TBytes;
    
    { ISSLCertificate - 证书信息 }
    function GetInfo: TSSLCertificateInfo;
    function GetSubject: string;
    function GetIssuer: string;
    function GetSerialNumber: string;
    function GetNotBefore: TDateTime;
    function GetNotAfter: TDateTime;
    function GetPublicKey: string;
    function GetPublicKeyAlgorithm: string;
    function GetSignatureAlgorithm: string;
    function GetVersion: Integer;
    
    { ISSLCertificate - 证书验证 }
    function Verify(ACAStore: ISSLCertificateStore): Boolean;
    function VerifyEx(ACAStore: ISSLCertificateStore; 
      AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
    function VerifyHostname(const AHostname: string): Boolean;
    function IsExpired: Boolean;
    function IsSelfSigned: Boolean;
    function IsCA: Boolean;

    { ISSLCertificate - 便利方法 }
    function GetDaysUntilExpiry: Integer;
    function GetSubjectCN: string;

    { ISSLCertificate - 证书扩展 }
    function GetExtension(const AOID: string): string;
    function GetSubjectAltNames: TSSLStringArray;
    function GetKeyUsage: TSSLStringArray;
    function GetExtendedKeyUsage: TSSLStringArray;
    
    { ISSLCertificate - 指纹 }
    function GetFingerprint(AHashType: TSSLHash): string;
    function GetFingerprintSHA1: string;
    function GetFingerprintSHA256: string;
    
    { ISSLCertificate - 证书链 }
    procedure SetIssuerCertificate(ACert: ISSLCertificate);
    function GetIssuerCertificate: ISSLCertificate;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    function Clone: ISSLCertificate;
  end;

{ 工厂函数 }
function CreateWinSSLCertificateFromContext(ACertContext: PCCERT_CONTEXT; AOwnsContext: Boolean = True): ISSLCertificate;

implementation

uses
  nextpas.core.tls.asn1,
  nextpas.core.tls.x509,
  nextpas.core.tls.crypto.hash;

// StringsToArray 已移至 nextpas.core.tls.utils（Phase 3.2）

// ============================================================================
// 工厂函数
// ============================================================================

function CreateWinSSLCertificateFromContext(ACertContext: PCCERT_CONTEXT; AOwnsContext: Boolean = True): ISSLCertificate;
begin
  Result := TWinSSLCertificate.Create(ACertContext, AOwnsContext);
end;

function TryLoadParsedWinSSLCertificate(ACert: TWinSSLCertificate;
  out AParser: TX509Certificate): Boolean;
var
  LDER: TBytes;
begin
  AParser := nil;
  Result := False;

  if (ACert = nil) or (ACert.FCertContext = nil) then
    Exit;

  LDER := ACert.SaveToDER;
  if Length(LDER) = 0 then
    Exit;

  AParser := TX509Certificate.Create;
  try
    AParser.LoadFromDER(LDER);
    Result := True;
  except
    FreeAndNil(AParser);
    Result := False;
  end;
end;

// ============================================================================
// TWinSSLCertificate - 构造和析构
// ============================================================================

constructor TWinSSLCertificate.Create(ACertContext: PCCERT_CONTEXT; AOwnsContext: Boolean = True);
begin
  inherited Create;
  FCertContext := ACertContext;
  FOwnsContext := AOwnsContext;
end;

destructor TWinSSLCertificate.Destroy;
begin
  if FOwnsContext and (FCertContext <> nil) then
    CertFreeCertificateContext(FCertContext);
  inherited Destroy;
end;

// ============================================================================
// 内部辅助方法
// ============================================================================

function TWinSSLCertificate.GetCertInfo: PCERT_INFO;
begin
  if FCertContext <> nil then
    Result := FCertContext^.pCertInfo
  else
    Result := nil;
end;

function CertNameBlobToX500String(AName: PCERT_NAME_BLOB): string;
var
  LSize: DWORD;
  LWritten: DWORD;
  LBuffer: UnicodeString;
begin
  Result := '';
  if (AName = nil) or (AName^.cbData = 0) or (AName^.pbData = nil) then
    Exit;

  LSize := CertNameToStrW(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    AName,
    CERT_X500_NAME_STR or CERT_NAME_STR_COMMA_FLAG,
    nil,
    0
  );
  if LSize <= 1 then
    Exit;

  SetLength(LBuffer, LSize);
  LWritten := CertNameToStrW(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    AName,
    CERT_X500_NAME_STR or CERT_NAME_STR_COMMA_FLAG,
    PWideChar(LBuffer),
    LSize
  );
  if LWritten <= 1 then
    Exit;

  SetLength(LBuffer, LWritten - 1);
  Result := UTF8Encode(WideString(LBuffer));
end;

function HasServerAuthUsage(const AUsage: TSSLStringArray): Boolean;
var
  I: Integer;
  LUsage: string;
begin
  Result := False;
  for I := 0 to High(AUsage) do
  begin
    LUsage := Trim(AUsage[I]);
    if SameText(LUsage, 'serverAuth') or
      SameText(LUsage, '1.3.6.1.5.5.7.3.1') then
      Exit(True);
  end;
end;

function X509KeyUsageToBitfield(const AUsage: TX509KeyUsage): Word;
begin
  Result := 0;
  if kuDigitalSignature in AUsage then
    Result := Result or $0080;
  if kuNonRepudiation in AUsage then
    Result := Result or $0040;
  if kuKeyEncipherment in AUsage then
    Result := Result or $0020;
  if kuDataEncipherment in AUsage then
    Result := Result or $0010;
  if kuKeyAgreement in AUsage then
    Result := Result or $0008;
  if kuKeyCertSign in AUsage then
    Result := Result or $0004;
  if kuCRLSign in AUsage then
    Result := Result or $0002;
  if kuEncipherOnly in AUsage then
    Result := Result or $0001;
  if kuDecipherOnly in AUsage then
    Result := Result or $8000;
end;

function X509KeyUsageToStrings(const AUsage: TX509KeyUsage): TSSLStringArray;

  procedure AddToResult(const AValue: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AValue;
  end;

begin
  SetLength(Result, 0);
  if kuDigitalSignature in AUsage then
    AddToResult('digitalSignature');
  if kuNonRepudiation in AUsage then
    AddToResult('nonRepudiation');
  if kuKeyEncipherment in AUsage then
    AddToResult('keyEncipherment');
  if kuDataEncipherment in AUsage then
    AddToResult('dataEncipherment');
  if kuKeyAgreement in AUsage then
    AddToResult('keyAgreement');
  if kuKeyCertSign in AUsage then
    AddToResult('keyCertSign');
  if kuCRLSign in AUsage then
    AddToResult('cRLSign');
  if kuEncipherOnly in AUsage then
    AddToResult('encipherOnly');
  if kuDecipherOnly in AUsage then
    AddToResult('decipherOnly');
end;

function X509ExtKeyUsageToStrings(const AUsage: TX509ExtKeyUsage): TSSLStringArray;

  procedure AddToResult(const AValue: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AValue;
  end;

begin
  SetLength(Result, 0);
  if ekuServerAuth in AUsage then
    AddToResult('serverAuth');
  if ekuClientAuth in AUsage then
    AddToResult('clientAuth');
  if ekuCodeSigning in AUsage then
    AddToResult('codeSigning');
  if ekuEmailProtection in AUsage then
    AddToResult('emailProtection');
  if ekuTimeStamping in AUsage then
    AddToResult('timeStamping');
  if ekuOCSPSigning in AUsage then
    AddToResult('OCSPSigning');
end;

function X509SubjectAltNamesToStrings(
  const ASANs: TX509SubjectAltNames): TSSLStringArray;
var
  I: Integer;
begin
  SetLength(Result, Length(ASANs));
  for I := 0 to High(ASANs) do
    Result[I] := ASANs[I].Value;
end;

function FormatHexError(const AValue: DWORD): string;
begin
  Result := '0x' + IntToHex(AValue, 8);
end;

function AlgorithmOIDToDisplayName(AOID: LPCSTR): string;
begin
  Result := '';
  if AOID = nil then
    Exit;

  Result := OIDToName(string(AOID));
  if Result = '' then
    Result := string(AOID);
end;

function CreateChainEngineForStore(
  ACAStore: ISSLCertificateStore;
  const ACaller: string;
  out AChainEngine: HCERTCHAINENGINE;
  out AAdditionalStore: HCERTSTORE
): Boolean;
var
  LStoreHandle: HCERTSTORE;
  LEngineConfig: CERT_CHAIN_ENGINE_CONFIG;
begin
  AChainEngine := nil;
  AAdditionalStore := nil;
  Result := True;

  if ACAStore = nil then
    Exit;

  LStoreHandle := HCERTSTORE(GetNativeHandleSafe(ACAStore, ACaller));
  if LStoreHandle = nil then
    Exit(False);

  FillChar(LEngineConfig, SizeOf(LEngineConfig), 0);
  LEngineConfig.cbSize := SizeOf(LEngineConfig);
  LEngineConfig.hExclusiveRoot := LStoreHandle;
  LEngineConfig.dwExclusiveFlags := CERT_CHAIN_EXCLUSIVE_ENABLE_CA_FLAG;
  AAdditionalStore := LStoreHandle;

  Result := CertCreateCertificateChainEngine(@LEngineConfig, @AChainEngine);
end;

function TWinSSLCertificate.BinaryToHexString(const AData: PByte; ASize: DWORD): string;
var
  i: Integer;
  p: PByte;
begin
  Result := '';
  if (AData = nil) or (ASize = 0) then
    Exit;
  
  p := AData;
  for i := 0 to ASize - 1 do
  begin
    if i > 0 then
      Result := Result + ':';
    Result := Result + IntToHex(p^, 2);
    Inc(p);
  end;
end;

function TWinSSLCertificate.CalculateFingerprint(AHashType: TSSLHash): string;
var
  HashAlg: ALG_ID;
  Hash: array[0..63] of Byte;
  HashSize: DWORD;
begin
  Result := '';
  
  if FCertContext = nil then
    Exit;
  
  // 选择哈希算法
  case AHashType of
    sslHashSHA1: HashAlg := CALG_SHA1;
    sslHashSHA256: HashAlg := CALG_SHA_256;
    sslHashSHA384: HashAlg := CALG_SHA_384;
    sslHashSHA512: HashAlg := CALG_SHA_512;
    sslHashMD5: HashAlg := CALG_MD5;
  else
    Exit;
  end;
  
  HashSize := SizeOf(Hash);
  
  // 计算证书哈希
  if CryptHashCertificate(0, HashAlg, 0, 
                          FCertContext^.pbCertEncoded, 
                          FCertContext^.cbCertEncoded,
                          @Hash[0], @HashSize) then
  begin
    Result := BinaryToHexString(@Hash[0], HashSize);
  end;
end;

// ============================================================================
// ISSLCertificate - 加载和保存
// ============================================================================

function TWinSSLCertificate.LoadFromFile(const AFileName: string): Boolean;
var
  FileStream: TFileStream;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := LoadFromStream(FileStream);
    finally
      FileStream.Free;
    end;
  except
    Result := False;
  end;
end;

function TWinSSLCertificate.LoadFromStream(AStream: TStream): Boolean;
var
  Data: TBytes;
  Size: Int64;
  LPEMText: RawByteString;
begin
  Result := False;
  Size := AStream.Size - AStream.Position;
  if Size <= 0 then
    Exit;
  
  SetLength(Data, Size);
  AStream.Read(Data[0], Size);
  Result := LoadFromDER(Data);
  if Result then
    Exit;

  // WinSSL current public certificate surface should accept PEM certificate files too.
  // If DER loading fails, fall back to PEM text decoding before giving up.
  if Length(Data) > 0 then
  begin
    SetString(LPEMText, PAnsiChar(@Data[0]), Length(Data));
    if Pos('-----BEGIN CERTIFICATE-----', string(LPEMText)) > 0 then
      Result := LoadFromPEM(string(LPEMText));
  end;
end;

function TWinSSLCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
var
  NewContext: PCCERT_CONTEXT;
begin
  Result := False;
  
  if (AData = nil) or (ASize <= 0) then
    Exit;
  
  NewContext := CertCreateCertificateContext(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    AData,
    ASize
  );
  
  if NewContext <> nil then
  begin
    if FOwnsContext and (FCertContext <> nil) then
      CertFreeCertificateContext(FCertContext);
    
    FCertContext := NewContext;
    FOwnsContext := True;
    Result := True;
  end;
end;

function TWinSSLCertificate.LoadFromPEM(const APEM: string): Boolean;
var
  DERData: TBytes;
  DERSize: DWORD;
  PEMStr: AnsiString;
begin
  Result := False;

  if APEM = '' then
    Exit;

  // Convert PEM string to AnsiString for CryptStringToBinaryA
  PEMStr := UTF8Encode(APEM);

  // First call to get the size
  if not CryptStringToBinaryA(
    PAnsiChar(PEMStr),
    Length(PEMStr),
    CRYPT_STRING_BASE64HEADER,
    nil,
    @DERSize,
    nil,
    nil
  ) then
    Exit;

  // Allocate buffer and decode
  SetLength(DERData, DERSize);
  if CryptStringToBinaryA(
    PAnsiChar(PEMStr),
    Length(PEMStr),
    CRYPT_STRING_BASE64HEADER,
    @DERData[0],
    @DERSize,
    nil,
    nil
  ) then
  begin
    SetLength(DERData, DERSize);
    Result := LoadFromDER(DERData);
  end;
end;

function TWinSSLCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  if Length(ADER) > 0 then
    Result := LoadFromMemory(@ADER[0], Length(ADER))
  else
    Result := False;
end;

function TWinSSLCertificate.SaveToFile(const AFileName: string): Boolean;
var
  FileStream: TFileStream;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmCreate);
    try
      Result := SaveToStream(FileStream);
    finally
      FileStream.Free;
    end;
  except
    Result := False;
  end;
end;

function TWinSSLCertificate.SaveToStream(AStream: TStream): Boolean;
var
  Data: TBytes;
begin
  Data := SaveToDER;
  if Length(Data) > 0 then
  begin
    AStream.Write(Data[0], Length(Data));
    Result := True;
  end
  else
    Result := False;
end;

function TWinSSLCertificate.SaveToPEM: string;
var
  DERData: TBytes;
  PEMData: PAnsiChar;
  PEMSize: DWORD;
  PEMStr: AnsiString;
begin
  Result := '';

  if FCertContext = nil then
    Exit;

  DERData := SaveToDER;
  if Length(DERData) = 0 then
    Exit;

  // First call to get the size
  if not CryptBinaryToStringA(
    @DERData[0],
    Length(DERData),
    CRYPT_STRING_BASE64HEADER,
    nil,
    @PEMSize
  ) then
    Exit;

  // Allocate buffer and encode
  GetMem(PEMData, PEMSize);
  try
    if CryptBinaryToStringA(
      @DERData[0],
      Length(DERData),
      CRYPT_STRING_BASE64HEADER,
      PEMData,
      @PEMSize
    ) then
    begin
      SetString(PEMStr, PEMData, PEMSize - 1); // -1 to exclude null terminator
      Result := UTF8Decode(PEMStr);
    end;
  finally
    FreeMem(PEMData);
  end;
end;

function TWinSSLCertificate.SaveToDER: TBytes;
begin
  if (FCertContext <> nil) and (FCertContext^.cbCertEncoded > 0) then
  begin
    SetLength(Result, FCertContext^.cbCertEncoded);
    Move(FCertContext^.pbCertEncoded^, Result[0], FCertContext^.cbCertEncoded);
  end
  else
    SetLength(Result, 0);
end;

// ============================================================================
// ISSLCertificate - 证书信息
// ============================================================================

function TWinSSLCertificate.GetInfo: TSSLCertificateInfo;
var
  LParser: TX509Certificate;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  if FCertContext = nil then
    Exit;
  
  Result.Subject := GetSubject;
  Result.Issuer := GetIssuer;
  Result.SerialNumber := GetSerialNumber;
  Result.NotBefore := GetNotBefore;
  Result.NotAfter := GetNotAfter;
  Result.FingerprintSHA1 := GetFingerprintSHA1;
  Result.FingerprintSHA256 := GetFingerprintSHA256;
  Result.Version := GetVersion;
  Result.PathLength := -1;
  Result.PathLenConstraint := -1;
  Result.KeyUsage := 0;

  if TryLoadParsedWinSSLCertificate(Self, LParser) then
  begin
    try
      Result.PublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.Name;
      if Result.PublicKeyAlgorithm = '' then
        Result.PublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.OID;

      Result.SignatureAlgorithm := LParser.SignatureAlgorithm.Name;
      if Result.SignatureAlgorithm = '' then
        Result.SignatureAlgorithm := LParser.SignatureAlgorithm.OID;

      Result.PublicKeySize := LParser.PublicKeyInfo.KeySize;
      Result.IsCA := LParser.IsCA;
      Result.PathLenConstraint := LParser.BasicConstraints.PathLenConstraint;
      Result.PathLength := LParser.BasicConstraints.PathLenConstraint;
      Result.KeyUsage := X509KeyUsageToBitfield(LParser.KeyUsage);
      Result.SubjectAltNames := X509SubjectAltNamesToStrings(LParser.SubjectAltNames);
    finally
      LParser.Free;
    end;
  end
  else
  begin
    Result.PublicKeyAlgorithm := GetPublicKeyAlgorithm;
    Result.SignatureAlgorithm := GetSignatureAlgorithm;
    Result.IsCA := IsCA;
    Result.SubjectAltNames := GetSubjectAltNames;
  end;
end;

function TWinSSLCertificate.GetSubject: string;
var
  LCertInfo: PCERT_INFO;
begin
  Result := '';

  LCertInfo := GetCertInfo;
  if LCertInfo = nil then
    Exit;

  Result := CertNameBlobToX500String(@LCertInfo^.Subject);
end;

function TWinSSLCertificate.GetIssuer: string;
var
  LCertInfo: PCERT_INFO;
begin
  Result := '';

  LCertInfo := GetCertInfo;
  if LCertInfo = nil then
    Exit;

  Result := CertNameBlobToX500String(@LCertInfo^.Issuer);
end;

function TWinSSLCertificate.GetSerialNumber: string;
var
  CertInfo: PCERT_INFO;
  i: Integer;
begin
  Result := '';
  
  CertInfo := GetCertInfo;
  if CertInfo = nil then
    Exit;
  
  // 序列号以小端序存储,需要反转
  for i := Integer(CertInfo^.SerialNumber.cbData) - 1 downto 0 do
  begin
    if i < Integer(CertInfo^.SerialNumber.cbData) - 1 then
      Result := Result + ':';
    Result := Result + IntToHex(PByte(CertInfo^.SerialNumber.pbData)[i], 2);
  end;
end;

function TWinSSLCertificate.GetNotBefore: TDateTime;
var
  CertInfo: PCERT_INFO;
  SysTime: TSystemTime;
begin
  Result := 0;
  
  CertInfo := GetCertInfo;
  if CertInfo = nil then
    Exit;
  
  if FileTimeToSystemTime(CertInfo^.NotBefore, SysTime) then
    Result := SystemTimeToDateTime(SysTime);
end;

function TWinSSLCertificate.GetNotAfter: TDateTime;
var
  CertInfo: PCERT_INFO;
  SysTime: TSystemTime;
begin
  Result := 0;
  
  CertInfo := GetCertInfo;
  if CertInfo = nil then
    Exit;
  
  if FileTimeToSystemTime(CertInfo^.NotAfter, SysTime) then
    Result := SystemTimeToDateTime(SysTime);
end;

function TWinSSLCertificate.GetPublicKey: string;
begin
  Result := GetPublicKeyAlgorithm;
end;

function TWinSSLCertificate.GetPublicKeyAlgorithm: string;
var
  CertInfo: PCERT_INFO;
begin
  Result := '';
  
  CertInfo := GetCertInfo;
  if CertInfo = nil then
    Exit;

  Result := AlgorithmOIDToDisplayName(
    CertInfo^.SubjectPublicKeyInfo.Algorithm.pszObjId);
end;

function TWinSSLCertificate.GetSignatureAlgorithm: string;
var
  CertInfo: PCERT_INFO;
begin
  Result := '';
  
  CertInfo := GetCertInfo;
  if CertInfo = nil then
    Exit;

  Result := AlgorithmOIDToDisplayName(CertInfo^.SignatureAlgorithm.pszObjId);
end;

function TWinSSLCertificate.GetVersion: Integer;
var
  CertInfo: PCERT_INFO;
begin
  Result := 0;
  
  CertInfo := GetCertInfo;
  if CertInfo <> nil then
    Result := CertInfo^.dwVersion + 1; // Windows 使用 0-based 版本号
end;

// ============================================================================
// ISSLCertificate - 证书验证
// ============================================================================

function TWinSSLCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
var
  ChainPara: CERT_CHAIN_PARA;
  ChainContext: PCCERT_CHAIN_CONTEXT;
  ChainEngine: HCERTCHAINENGINE;
  AdditionalStore: HCERTSTORE;
  PolicyPara: CERT_CHAIN_POLICY_PARA;
  PolicyStatus: CERT_CHAIN_POLICY_STATUS;
begin
  Result := False;

  if FCertContext = nil then
    Exit;

  // 初始化证书链参数
  FillChar(ChainPara, SizeOf(ChainPara), 0);
  ChainPara.cbSize := SizeOf(ChainPara);
  ChainContext := nil;
  ChainEngine := nil;
  AdditionalStore := nil;

  if not CreateChainEngineForStore(
    ACAStore,
    'TWinSSLCertificate.Verify',
    ChainEngine,
    AdditionalStore
  ) then
    Exit;

  // 构建证书链
  if not CertGetCertificateChain(
    ChainEngine,            // 使用默认或自定义链引擎
    FCertContext,           // 要验证的证书
    nil,                    // 使用当前时间
    AdditionalStore,        // 同一个 custom store 继续参与建链
    @ChainPara,             // 链参数
    0,                      // 标志
    nil,                    // 保留
    @ChainContext           // 输出链上下文
  ) then
  begin
    if ChainEngine <> nil then
      CertFreeCertificateChainEngine(ChainEngine);
    Exit;
  end;

  try
    // 初始化策略参数
    FillChar(PolicyPara, SizeOf(PolicyPara), 0);
    PolicyPara.cbSize := SizeOf(PolicyPara);
    PolicyPara.dwFlags := 0;

    // 初始化策略状态
    FillChar(PolicyStatus, SizeOf(PolicyStatus), 0);
    PolicyStatus.cbSize := SizeOf(PolicyStatus);

    // 验证证书链策略（基本约束、密钥用途等）
    if CertVerifyCertificateChainPolicy(
      CERT_CHAIN_POLICY_BASE,     // 基本验证策略
      ChainContext,               // 证书链
      @PolicyPara,                // 策略参数
      @PolicyStatus               // 策略状态输出
    ) then
    begin
      // 检查验证结果
      Result := (PolicyStatus.dwError = 0);

      // 如果失败，可以通过 PolicyStatus.dwError 获取错误代码
      // 常见错误码：
      // TRUST_E_CERT_SIGNATURE: 签名无效
      // CERT_E_EXPIRED: 证书已过期
      // CERT_E_UNTRUSTEDROOT: 不受信任的根证书
      // CERT_E_WRONG_USAGE: 密钥用途不正确
    end;

  finally
    // 释放证书链上下文
    CertFreeCertificateChain(ChainContext);
    if ChainEngine <> nil then
      CertFreeCertificateChainEngine(ChainEngine);
  end;
end;

function TWinSSLCertificate.VerifyEx(ACAStore: ISSLCertificateStore; 
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
var
  LChainPara: CERT_CHAIN_PARA;
  LChainContext: PCCERT_CHAIN_CONTEXT;
  LChainEngine: HCERTCHAINENGINE;
  LAdditionalStore: HCERTSTORE;
  LPolicyPara: CERT_CHAIN_POLICY_PARA;
  LPolicyStatus: CERT_CHAIN_POLICY_STATUS;
  LChainFlags: DWORD;
  LExtendedKeyUsage: TSSLStringArray;
  LNativePolicyError: DWORD;
  LOverrideApplied: Boolean;
begin
  // 初始化返回值
  AResult.Success := False;
  AResult.ErrorCode := 0;
  AResult.ErrorMessage := '';
  AResult.ChainStatus := 0;
  AResult.RevocationStatus := 0;
  AResult.DetailedInfo := '';
  Result := False;

  if FCertContext = nil then
  begin
    AResult.ErrorCode := ERROR_INVALID_PARAMETER;
    AResult.ErrorMessage := 'Certificate context is nil';
    Exit;
  end;

  // 初始化证书链参数
  FillChar(LChainPara, SizeOf(LChainPara), 0);
  LChainPara.cbSize := SizeOf(LChainPara);
  LChainContext := nil;
  LChainEngine := nil;
  LAdditionalStore := nil;

  // 根据标志配置链验证
  LChainFlags := 0;
  
  if (sslCertVerifyCheckRevocation in AFlags) or
    (sslCertVerifyCheckOCSP in AFlags) then
    LChainFlags := LChainFlags or CERT_CHAIN_REVOCATION_CHECK_CHAIN;
    
  if sslCertVerifyCheckCRL in AFlags then
    LChainFlags := LChainFlags or CERT_CHAIN_REVOCATION_CHECK_END_CERT;

  if not CreateChainEngineForStore(
    ACAStore,
    'TWinSSLCertificate.VerifyEx',
    LChainEngine,
    LAdditionalStore
  ) then
  begin
    AResult.ErrorCode := GetLastError;
    AResult.ErrorMessage := 'Failed to create certificate chain engine';
    Exit;
  end;

  // 构建证书链
  if not CertGetCertificateChain(
    LChainEngine,           // 使用默认或自定义链引擎
    FCertContext,           // 要验证的证书
    nil,                    // 使用当前时间
    LAdditionalStore,       // 同一个 custom store 继续参与建链
    @LChainPara,            // 链参数
    LChainFlags,            // 验证标志
    nil,                    // 保留
    @LChainContext          // 输出链上下文
  ) then
  begin
    AResult.ErrorCode := GetLastError;
    AResult.ErrorMessage := 'Failed to build certificate chain';
    if LChainEngine <> nil then
      CertFreeCertificateChainEngine(LChainEngine);
    Exit;
  end;

  try
    // 记录链状态
    if LChainContext <> nil then
      AResult.ChainStatus := LChainContext^.TrustStatus.dwErrorStatus;

    // 初始化策略参数
    FillChar(LPolicyPara, SizeOf(LPolicyPara), 0);
    LPolicyPara.cbSize := SizeOf(LPolicyPara);
    LPolicyPara.dwFlags := 0;
    LOverrideApplied := False;

    // 初始化策略状态
    FillChar(LPolicyStatus, SizeOf(LPolicyStatus), 0);
    LPolicyStatus.cbSize := SizeOf(LPolicyStatus);

    // 验证证书链策略
    if CertVerifyCertificateChainPolicy(
      CERT_CHAIN_POLICY_BASE,     // 基本验证策略
      LChainContext,               // 证书链
      @LPolicyPara,                // 策略参数
      @LPolicyStatus               // 策略状态输出
    ) then
    begin
      LNativePolicyError := LPolicyStatus.dwError;
      AResult.ErrorCode := LNativePolicyError;
      AResult.ChainStatus := LNativePolicyError;
      
      // 检查验证结果
      if (LNativePolicyError <> 0) and
        (sslCertVerifyIgnoreExpiry in AFlags) and
        (LNativePolicyError = DWORD(CERT_E_EXPIRED)) then
      begin
        LOverrideApplied := True;
        LNativePolicyError := 0;
      end
      else if (LNativePolicyError <> 0) and
        (sslCertVerifyAllowSelfSigned in AFlags) and
        IsSelfSigned and
        (LNativePolicyError = DWORD(CERT_E_UNTRUSTEDROOT)) then
      begin
        LOverrideApplied := True;
        LNativePolicyError := 0;
      end;

      if LNativePolicyError = 0 then
      begin
        if sslCertVerifyStrictChain in AFlags then
        begin
          LExtendedKeyUsage := GetExtendedKeyUsage;
          if not HasServerAuthUsage(LExtendedKeyUsage) then
          begin
            AResult.Success := False;
            AResult.ErrorCode := CERT_E_WRONG_USAGE;
            AResult.ChainStatus := CERT_E_WRONG_USAGE;
            AResult.ErrorMessage := 'Strict chain verification requires serverAuth extended key usage';
            AResult.DetailedInfo :=
              'sslCertVerifyStrictChain requested but the leaf certificate is missing serverAuth extended key usage';
            Exit;
          end;
        end;

        AResult.Success := True;
        AResult.ErrorCode := 0;
        AResult.ChainStatus := 0;
        if not LOverrideApplied then
          AResult.ErrorMessage := 'Certificate verified successfully';
        Result := True;
      end
      else
      begin
        // 生成友好的错误消息
        case LNativePolicyError of
          CERT_E_EXPIRED:
            AResult.ErrorMessage := 'Certificate has expired';
          CERT_E_UNTRUSTEDROOT:
            AResult.ErrorMessage := 'Certificate chain to untrusted root';
          CERT_E_WRONG_USAGE:
            AResult.ErrorMessage := 'Certificate has wrong usage';
          CERT_E_REVOKED:
            begin
              AResult.ErrorMessage := 'Certificate has been revoked';
              AResult.RevocationStatus := 1;
            end;
          CERT_E_REVOCATION_FAILURE:
            begin
              AResult.ErrorMessage := 'Revocation check failed';
              AResult.RevocationStatus := 2;
            end;
          TRUST_E_CERT_SIGNATURE:
            AResult.ErrorMessage := 'Certificate signature is invalid';
          CERT_E_CN_NO_MATCH:
            AResult.ErrorMessage := 'Certificate common name does not match';
          CERT_E_INVALID_NAME:
            AResult.ErrorMessage := 'Certificate name is invalid';
        else
          AResult.ErrorMessage :=
            'Certificate verification failed (Error: ' +
            FormatHexError(LNativePolicyError) + ')';
        end;
      end;
    end
    else
    begin
      AResult.ErrorCode := GetLastError;
      AResult.ErrorMessage := 'Certificate chain policy verification failed';
    end;

  finally
    // 释放证书链上下文
    CertFreeCertificateChain(LChainContext);
    if LChainEngine <> nil then
      CertFreeCertificateChainEngine(LChainEngine);
  end;
end;

function TWinSSLCertificate.VerifyHostname(const AHostname: string): Boolean;
var
  SANs: TSSLStringArray;
  i: Integer;
  CN, Entry: string;
  HostIsIP, EntryIsIP: Boolean;
  HasRelevantSAN: Boolean;

  function MatchWildcard(const APattern, AHostname: string): Boolean;
  var
    PatternParts, HostParts: TStringList;
    j: Integer;
  begin
    Result := False;

    // 精确匹配
    if SameText(APattern, AHostname) then
    begin
      Result := True;
      Exit;
    end;

    // 通配符匹配 (*.example.com)
    if (Pos('*.', APattern) = 1) then
    begin
      PatternParts := TStringList.Create;
      HostParts := TStringList.Create;
      try
        PatternParts.Delimiter := '.';
        PatternParts.DelimitedText := APattern;

        HostParts.Delimiter := '.';
        HostParts.DelimitedText := AHostname;

        // 域名级数必须相同
        if PatternParts.Count = HostParts.Count then
        begin
          Result := True;
          // 从第二级开始比较（跳过通配符）
          for j := 1 to PatternParts.Count - 1 do
          begin
            if not SameText(PatternParts[j], HostParts[j]) then
            begin
              Result := False;
              Break;
            end;
          end;
        end;
      finally
        PatternParts.Free;
        HostParts.Free;
      end;
    end;
  end;

  function IsHostnamePattern(const AValue: string): Boolean;
  var
    LValue: string;
  begin
    LValue := Trim(AValue);
    Result := TSSLUtils.IsValidHostname(LValue) or
      ((Length(LValue) > 2) and (Copy(LValue, 1, 2) = '*.') and
       TSSLUtils.IsValidHostname(Copy(LValue, 3, MaxInt)));
  end;

begin
  Result := False;

  if (FCertContext = nil) or (AHostname = '') then
    Exit;

  HostIsIP := TSSLUtils.IsIPAddress(AHostname);
  HasRelevantSAN := False;

  // 先检查 SAN。只有当证书没有与目标类型对应的 SAN 条目时，
  // 才允许回退到 Common Name。
  SANs := GetSubjectAltNames;
  for i := 0 to High(SANs) do
  begin
    Entry := Trim(SANs[i]);
    if Entry = '' then
      Continue;

    EntryIsIP := TSSLUtils.IsIPAddress(Entry);

    if HostIsIP then
    begin
      if EntryIsIP then
      begin
        HasRelevantSAN := True;
        if SameText(Entry, AHostname) then
        begin
          Result := True;
          Exit;
        end;
      end;
      Continue;
    end;

    // 只针对域名进行通配符匹配，忽略 IP 及其他条目（email/URI 等）
    if EntryIsIP then
      Continue;
    if not IsHostnamePattern(Entry) then
      Continue;

    HasRelevantSAN := True;
    if MatchWildcard(Entry, AHostname) then
    begin
      Result := True;
      Exit;
    end;
  end;

  if HasRelevantSAN then
    Exit(False);

  // 如果没有 SAN 或未匹配，检查 Common Name (CN)
  CN := GetSubject;

  // 从 Subject 中提取 CN
  // 简化处理：GetSubject 可能已返回简化的名称
  // 如果返回的是完整 DN，需要解析
  if Pos('CN=', CN) > 0 then
  begin
    CN := Copy(CN, Pos('CN=', CN) + 3, Length(CN));
    if Pos(',', CN) > 0 then
      CN := Copy(CN, 1, Pos(',', CN) - 1);
    CN := Trim(CN);
  end;

  // 尝试匹配 CN
  if HostIsIP then
  begin
    Result := SameText(CN, AHostname);
    Exit;
  end;

  if not TSSLUtils.IsValidHostname(CN) then
    Exit;

  Result := MatchWildcard(CN, AHostname);
end;

function TWinSSLCertificate.IsExpired: Boolean;
var
  CurrentTime: TDateTime;
begin
  CurrentTime := Now();
  Result := (GetNotBefore > CurrentTime) or (GetNotAfter < CurrentTime);
end;

function TWinSSLCertificate.IsSelfSigned: Boolean;
begin
  Result := GetSubject = GetIssuer;
end;

function TWinSSLCertificate.IsCA: Boolean;
var
  ExtInfo: PCERT_EXTENSION;
  BasicConstraints: PCERT_BASIC_CONSTRAINTS2_INFO;
  BasicConstraintsSize: DWORD;
begin
  Result := False;

  if FCertContext = nil then
    Exit;

  // 查找 Basic Constraints 扩展
  ExtInfo := CertFindExtension(
    szOID_BASIC_CONSTRAINTS2,
    GetCertInfo^.cExtension,
    GetCertInfo^.rgExtension
  );

  if ExtInfo = nil then
  begin
    // 尝试旧版本的 Basic Constraints (不常见)
    ExtInfo := CertFindExtension(
      szOID_BASIC_CONSTRAINTS,
      GetCertInfo^.cExtension,
      GetCertInfo^.rgExtension
    );
  end;

  if ExtInfo = nil then
    Exit;

  // 解码 Basic Constraints 扩展
  BasicConstraintsSize := 0;
  if not CryptDecodeObject(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    szOID_BASIC_CONSTRAINTS2,
    ExtInfo^.Value.pbData,
    ExtInfo^.Value.cbData,
    0,
    nil,
    @BasicConstraintsSize
  ) then
    Exit;

  GetMem(BasicConstraints, BasicConstraintsSize);
  try
    if CryptDecodeObject(
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      szOID_BASIC_CONSTRAINTS2,
      ExtInfo^.Value.pbData,
      ExtInfo^.Value.cbData,
      0,
      BasicConstraints,
      @BasicConstraintsSize
    ) then
    begin
      Result := BasicConstraints^.fCA;
    end;
  finally
    FreeMem(BasicConstraints);
  end;
end;

// ============================================================================
// ISSLCertificate - 便利方法
// ============================================================================

function TWinSSLCertificate.GetDaysUntilExpiry: Integer;
var
  ExpiryDate: TDateTime;
begin
  // 返回证书到期天数，已过期返回负数
  if FCertContext = nil then
  begin
    Result := -MaxInt;  // 无效证书返回极小值
    Exit;
  end;

  ExpiryDate := GetNotAfter;
  if ExpiryDate = 0 then
  begin
    Result := -MaxInt;  // 无法获取到期日期
    Exit;
  end;

  Result := Trunc(ExpiryDate - Now);
end;

function TWinSSLCertificate.GetSubjectCN: string;
var
  Buffer: array[0..255] of WideChar;
  Size: DWORD;
  OID: PAnsiChar;
begin
  Result := '';

  if FCertContext = nil then
    Exit;

  // 使用 CERT_NAME_ATTR_TYPE 配合 szOID_COMMON_NAME 直接获取 CN
  // 这比解析 Subject 字符串更可靠
  OID := szOID_COMMON_NAME;
  Size := CertGetNameStringW(
    FCertContext,
    CERT_NAME_ATTR_TYPE,
    0,
    @OID,
    @Buffer[0],
    Length(Buffer)
  );

  if Size > 1 then
    Result := WideCharToString(@Buffer[0]);
end;

// ============================================================================
// ISSLCertificate - 证书扩展
// ============================================================================

function TWinSSLCertificate.GetExtension(const AOID: string): string;
var
  LParser: TX509Certificate;
  LTargetOID: string;
  I: Integer;
begin
  Result := '';

  LTargetOID := Trim(AOID);
  if (FCertContext = nil) or (LTargetOID = '') then
    Exit;

  if not TryLoadParsedWinSSLCertificate(Self, LParser) then
    Exit;

  try
    for I := 0 to High(LParser.Extensions) do
    begin
      if SameText(LParser.Extensions[I].OID, LTargetOID) then
      begin
        if Length(LParser.Extensions[I].Value) > 0 then
          Result := HashToHex(LParser.Extensions[I].Value)
        else
          Result := LParser.Extensions[I].Name;
        Exit;
      end;
    end;
  finally
    LParser.Free;
  end;
end;

function TWinSSLCertificate.GetSubjectAltNames: TSSLStringArray;
var
  LParser: TX509Certificate;
  ExtInfo: PCERT_EXTENSION;
  AltNameInfo: PCERT_ALT_NAME_INFO;
  AltNameInfoSize: DWORD;
  j: DWORD;
  AltName: PCERT_ALT_NAME_ENTRY;
  Addr4, Addr6: PByte;
  SegValue: Word;
  IpStr: string;
  k: Integer;

  procedure AddToResult(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

begin
  SetLength(Result, 0);

  if FCertContext = nil then
    Exit;

  if TryLoadParsedWinSSLCertificate(Self, LParser) then
  begin
    try
      Result := X509SubjectAltNamesToStrings(LParser.SubjectAltNames);
      Exit;
    finally
      LParser.Free;
    end;
  end;

  // 查找 Subject Alternative Name 扩展
  ExtInfo := CertFindExtension(
    szOID_SUBJECT_ALT_NAME2,
    GetCertInfo^.cExtension,
    GetCertInfo^.rgExtension
  );

  if ExtInfo = nil then
    Exit;

  // 解码扩展
  AltNameInfoSize := 0;
  if not CryptDecodeObject(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    szOID_SUBJECT_ALT_NAME2,
    ExtInfo^.Value.pbData,
    ExtInfo^.Value.cbData,
    0,
    nil,
    @AltNameInfoSize
  ) then
    Exit;

  GetMem(AltNameInfo, AltNameInfoSize);
  try
    if CryptDecodeObject(
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      szOID_SUBJECT_ALT_NAME2,
      ExtInfo^.Value.pbData,
      ExtInfo^.Value.cbData,
      0,
      AltNameInfo,
      @AltNameInfoSize
    ) then
    begin
      // 提取每个备用名称
      for j := 0 to AltNameInfo^.cAltEntry - 1 do
      begin
        AltName := @AltNameInfo^.rgAltEntry[j];
        if AltName^.dwAltNameChoice = CERT_ALT_NAME_DNS_NAME then
        begin
          AddToResult(WideCharToString(AltName^.pwszDNSName));
        end
        else if AltName^.dwAltNameChoice = CERT_ALT_NAME_RFC822_NAME then
        begin
          AddToResult(WideCharToString(AltName^.pwszRfc822Name));
        end
        else if AltName^.dwAltNameChoice = CERT_ALT_NAME_URL then
        begin
          AddToResult(WideCharToString(AltName^.pwszURL));
        end
        else if AltName^.dwAltNameChoice = CERT_ALT_NAME_IP_ADDRESS then
        begin
          if AltName^.IPAddress.cbData = 4 then
          begin
            Addr4 := AltName^.IPAddress.pbData;
            if Addr4 <> nil then
              AddToResult(Format('%d.%d.%d.%d', [Addr4[0], Addr4[1], Addr4[2], Addr4[3]]));
          end
          else if AltName^.IPAddress.cbData = 16 then
          begin
            Addr6 := AltName^.IPAddress.pbData;
            if Addr6 <> nil then
            begin
              IpStr := '';
              for k := 0 to 7 do
              begin
                SegValue := (Word(Addr6[k * 2]) shl 8) or Word(Addr6[k * 2 + 1]);
                if k > 0 then
                  IpStr := IpStr + ':';
                IpStr := IpStr + IntToHex(SegValue, 1);
              end;
              if IpStr <> '' then
                AddToResult(IpStr);
            end;
          end;
        end;
      end;
    end;
  finally
    FreeMem(AltNameInfo);
  end;
end;

function TWinSSLCertificate.GetKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
  ExtInfo: PCERT_EXTENSION;
  KeyUsageInfo: PCRYPT_BIT_BLOB;
  KeyUsageSize: DWORD;
  KeyUsageBits: Byte;

  procedure AddToResult(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

begin
  SetLength(Result, 0);

  if FCertContext = nil then
    Exit;

  if TryLoadParsedWinSSLCertificate(Self, LParser) then
  begin
    try
      Result := X509KeyUsageToStrings(LParser.KeyUsage);
      Exit;
    finally
      LParser.Free;
    end;
  end;

  // 查找 Key Usage 扩展
  ExtInfo := CertFindExtension(
    szOID_KEY_USAGE,
    GetCertInfo^.cExtension,
    GetCertInfo^.rgExtension
  );

  if ExtInfo = nil then
    Exit;

  // 解码 Key Usage 扩展
  KeyUsageSize := 0;
  if not CryptDecodeObject(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    szOID_KEY_USAGE,
    ExtInfo^.Value.pbData,
    ExtInfo^.Value.cbData,
    0,
    nil,
    @KeyUsageSize
  ) then
    Exit;

  GetMem(KeyUsageInfo, KeyUsageSize);
  try
    if CryptDecodeObject(
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      szOID_KEY_USAGE,
      ExtInfo^.Value.pbData,
      ExtInfo^.Value.cbData,
      0,
      KeyUsageInfo,
      @KeyUsageSize
    ) then
    begin
      if KeyUsageInfo^.cbData > 0 then
      begin
        KeyUsageBits := PByte(KeyUsageInfo^.pbData)^;

        // 解析密钥用途位
        if (KeyUsageBits and $80) <> 0 then AddToResult('digitalSignature');
        if (KeyUsageBits and $40) <> 0 then AddToResult('nonRepudiation');
        if (KeyUsageBits and $20) <> 0 then AddToResult('keyEncipherment');
        if (KeyUsageBits and $10) <> 0 then AddToResult('dataEncipherment');
        if (KeyUsageBits and $08) <> 0 then AddToResult('keyAgreement');
        if (KeyUsageBits and $04) <> 0 then AddToResult('keyCertSign');
        if (KeyUsageBits and $02) <> 0 then AddToResult('cRLSign');
        if (KeyUsageBits and $01) <> 0 then AddToResult('encipherOnly');

        // 第二个字节（如果存在）
        if KeyUsageInfo^.cbData > 1 then
        begin
          KeyUsageBits := PByte(KeyUsageInfo^.pbData + 1)^;
          if (KeyUsageBits and $80) <> 0 then AddToResult('decipherOnly');
        end;
      end;
    end;
  finally
    FreeMem(KeyUsageInfo);
  end;
end;

function TWinSSLCertificate.GetExtendedKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
  ExtInfo: PCERT_EXTENSION;
  EnhKeyUsage: PCERT_ENHKEY_USAGE;
  EnhKeyUsageSize: DWORD;
  i: DWORD;
  OIDStr: string;

  procedure AddToResult(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

begin
  SetLength(Result, 0);

  if FCertContext = nil then
    Exit;

  if TryLoadParsedWinSSLCertificate(Self, LParser) then
  begin
    try
      Result := X509ExtKeyUsageToStrings(LParser.ExtKeyUsage);
      Exit;
    finally
      LParser.Free;
    end;
  end;

  // 查找 Extended Key Usage 扩展
  ExtInfo := CertFindExtension(
    szOID_ENHANCED_KEY_USAGE,
    GetCertInfo^.cExtension,
    GetCertInfo^.rgExtension
  );

  if ExtInfo = nil then
    Exit;

  // 解码 Extended Key Usage 扩展
  EnhKeyUsageSize := 0;
  if not CryptDecodeObject(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    szOID_ENHANCED_KEY_USAGE,
    ExtInfo^.Value.pbData,
    ExtInfo^.Value.cbData,
    0,
    nil,
    @EnhKeyUsageSize
  ) then
    Exit;

  GetMem(EnhKeyUsage, EnhKeyUsageSize);
  try
    if CryptDecodeObject(
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      szOID_ENHANCED_KEY_USAGE,
      ExtInfo^.Value.pbData,
      ExtInfo^.Value.cbData,
      0,
      EnhKeyUsage,
      @EnhKeyUsageSize
    ) then
    begin
      // 提取每个 OID
      for i := 0 to EnhKeyUsage^.cUsageIdentifier - 1 do
      begin
        OIDStr := string(EnhKeyUsage^.rgpszUsageIdentifier[i]);
        if OIDStr = szOID_PKIX_KP_SERVER_AUTH then
          AddToResult('serverAuth')
        else if OIDStr = szOID_PKIX_KP_CLIENT_AUTH then
          AddToResult('clientAuth')
        else if OIDStr = szOID_PKIX_KP_CODE_SIGNING then
          AddToResult('codeSigning')
        else if OIDStr = szOID_PKIX_KP_EMAIL_PROTECTION then
          AddToResult('emailProtection')
        else if OIDStr = '1.3.6.1.5.5.7.3.8' then
          AddToResult('timeStamping')
        else if OIDStr = '1.3.6.1.5.5.7.3.9' then
          AddToResult('OCSPSigning');
      end;
    end;
  finally
    FreeMem(EnhKeyUsage);
  end;
end;

// ============================================================================
// ISSLCertificate - 指纹
// ============================================================================

function TWinSSLCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  Result := CalculateFingerprint(AHashType);
end;

function TWinSSLCertificate.GetFingerprintSHA1: string;
begin
  Result := CalculateFingerprint(sslHashSHA1);
end;

function TWinSSLCertificate.GetFingerprintSHA256: string;
begin
  Result := CalculateFingerprint(sslHashSHA256);
end;

// ============================================================================
// ISSLCertificate - 证书链
// ============================================================================

procedure TWinSSLCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCert := ACert;
end;

function TWinSSLCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCert;
end;

// ============================================================================
// ISSLNativeHandleAccess implementation
// ============================================================================

function TWinSSLCertificate.GetNativeHandle: Pointer;
begin
  Result := FCertContext;
end;

function TWinSSLCertificate.GetBackendType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TWinSSLCertificate.IsNativeHandleValid: Boolean;
begin
  Result := (FCertContext <> nil);
end;

function TWinSSLCertificate.Clone: ISSLCertificate;
var
  DupContext: PCCERT_CONTEXT;
  LClone: TWinSSLCertificate;
begin
  if FCertContext <> nil then
  begin
    DupContext := CertDuplicateCertificateContext(FCertContext);
    LClone := TWinSSLCertificate.Create(DupContext, True);
    LClone.FIssuerCert := FIssuerCert;
    Result := LClone;
  end
  else
    Result := nil;
end;

end.
