{
  nextpas.core.tls.openssl.certificate - OpenSSL 证书实现
  版本: 1.0 (简化版)
  创建: 2025-11-02
}

unit nextpas.core.tls.openssl.certificate;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.logging,  // P3-8: 添加日志支持
  nextpas.core.tls.ocsp,
  nextpas.core.tls.x509,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.native_handle,  // 原生句柄辅助函数
  nextpas.core.tls.openssl.x509.chain,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.consts;

type
  TOpenSSLCertificate = class(TInterfacedObject, ISSLCertificate, ISSLNativeHandleAccess)
  private
    FX509: PX509;
    FOwnsHandle: Boolean;
    FIssuerCert: ISSLCertificate;  // Store issuer certificate for chain building
    // P3-10/15: Extract common fingerprint computation
    function ComputeFingerprint(MD: PEVP_MD): string;
  public
    constructor Create(AX509: PX509; AOwnsHandle: Boolean = True);
    destructor Destroy; override;
    
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromStream(AStream: TStream): Boolean;
    function LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
    function LoadFromPEM(const APEM: string): Boolean;
    function LoadFromDER(const ADER: TBytes): Boolean;
    function SaveToFile(const AFileName: string): Boolean;
    function SaveToStream(AStream: TStream): Boolean;
    function SaveToPEM: string;
    function SaveToDER: TBytes;
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
    function Verify(ACAStore: ISSLCertificateStore): Boolean;
    function VerifyEx(ACAStore: ISSLCertificateStore; 
      AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
    function VerifyHostname(const AHostname: string): Boolean;
    function IsExpired: Boolean;
    function IsSelfSigned: Boolean;
    function IsCA: Boolean;
    function GetDaysUntilExpiry: Integer;
    function GetSubjectCN: string;
    function GetExtension(const AOID: string): string;
    function GetSubjectAltNames: TSSLStringArray;
    function GetKeyUsage: TSSLStringArray;
    function GetExtendedKeyUsage: TSSLStringArray;
    function GetFingerprint(AHashType: TSSLHash): string;
    function GetFingerprintSHA1: string;
    function GetFingerprintSHA256: string;
    procedure SetIssuerCertificate(ACert: ISSLCertificate);
    function GetIssuerCertificate: ISSLCertificate;
    function Clone: ISSLCertificate;

    { ISSLNativeHandleAccess }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

implementation

uses
  nextpas.core.time,
  nextpas.core.tls.utils,  // Phase 3.2 - StringsToArray 统一实现
  nextpas.core.crypto.hash;

const
  // X509_NAME print flags
  XN_FLAG_SEP_COMMA_PLUS = 1 shl 16;
  XN_FLAG_DN_REV = 1 shl 20;
  XN_FLAG_FN_SN = 0; // Short name
  XN_FLAG_ONELINE = XN_FLAG_SEP_COMMA_PLUS or XN_FLAG_DN_REV or XN_FLAG_FN_SN;

{ X509NameToString - 将 X509_NAME 转换为字符串

  此辅助函数统一处理 X509_NAME 到字符串的转换逻辑，
  避免 GetSubject 和 GetIssuer 中的代码重复。

  优先使用 X509_NAME_print_ex (RFC 2253 格式)，
  若不可用则回退到 X509_NAME_oneline。
}
function X509NameToString(AName: PX509_NAME): string;
var
  BIO: PBIO;
  Len: Integer;
  Buf: PAnsiChar;
begin
  Result := '';

  if AName = nil then
    Exit;

  // 优先使用 X509_NAME_print_ex (RFC 2253 风格)
  if Assigned(X509_NAME_print_ex) and Assigned(BIO_new) and
    Assigned(BIO_s_mem) and Assigned(BIO_free) then
  begin
    BIO := BIO_new(BIO_s_mem());
    if BIO <> nil then
    try
      if X509_NAME_print_ex(BIO, AName, 0, XN_FLAG_ONELINE) > 0 then
      begin
        Len := BIO_get_mem_data(BIO, PPAnsiChar(@Buf));
        if Len > 0 then
          SetString(Result, Buf, Len);
      end;
    finally
      BIO_free(BIO);
    end;
  end;

  // 后备方案：使用旧的 X509_NAME_oneline
  if (Result = '') and Assigned(X509_NAME_oneline) then
  begin
    Buf := X509_NAME_oneline(AName, nil, 0);
    if Buf <> nil then
    begin
      Result := string(Buf);
      if Assigned(OPENSSL_free) then
        OPENSSL_free(Buf);
    end;
  end;
end;

function IpBytesToString(AData: PByte; ALength: Integer): string;
var
  I: Integer;
  Value: Integer;
begin
  Result := '';
  if (AData = nil) or (ALength <= 0) then
    Exit;

  if ALength = 4 then
  begin
    Result := Format('%d.%d.%d.%d', [AData[0], AData[1], AData[2], AData[3]]);
    Exit;
  end;

  if ALength = 16 then
  begin
    for I := 0 to 7 do
    begin
      Value := (Integer(AData[I * 2]) shl 8) or Integer(AData[I * 2 + 1]);
      if I > 0 then
        Result := Result + ':';
      Result := Result + IntToHex(Value, 1);
    end;
    Exit;
  end;
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

function TryLoadParsedOpenSSLCertificate(ACert: TOpenSSLCertificate;
  out AParser: TX509Certificate): Boolean;
var
  LDER: TBytes;
  LPEM: string;
begin
  AParser := nil;
  Result := False;

  if (ACert = nil) or (ACert.FX509 = nil) then
    Exit;

  AParser := TX509Certificate.Create;
  try
    LDER := ACert.SaveToDER;
    if Length(LDER) > 0 then
      AParser.LoadFromDER(LDER)
    else
    begin
      LPEM := ACert.SaveToPEM;
      if LPEM = '' then
        Exit;
      AParser.LoadFromPEM(LPEM);
    end;
    Result := True;
  except
    FreeAndNil(AParser);
    Result := False;
  end;
end;

function TryGetParsedExtensionValue(const AParser: TX509Certificate;
  const AOID: string; out AValue: string): Boolean;
var
  LTargetOID: string;
  I: Integer;
begin
  AValue := '';
  Result := False;

  if AParser = nil then
    Exit;

  LTargetOID := Trim(AOID);
  if LTargetOID = '' then
    Exit;

  for I := 0 to High(AParser.Extensions) do
  begin
    if SameText(AParser.Extensions[I].OID, LTargetOID) then
    begin
      if Length(AParser.Extensions[I].Value) > 0 then
        AValue := HashToHex(AParser.Extensions[I].Value)
      else
        AValue := AParser.Extensions[I].Name;
      Exit(True);
    end;
  end;
end;

// StringsToArray 已移至 nextpas.core.tls.utils（Phase 3.2）

function HasCertificateFileBIOHelpers: Boolean;
begin
  Result := Assigned(BIO_new_file) and Assigned(BIO_free);
end;

function HasCertificateMemoryLoadBIOHelpers: Boolean;
begin
  Result := Assigned(BIO_new_mem_buf) and Assigned(BIO_free);
end;

function HasCertificateMemorySaveBIOHelpers: Boolean;
begin
  Result := Assigned(BIO_new) and Assigned(BIO_s_mem) and Assigned(BIO_free);
end;

function HasServerAuthUsage(const AUsage: TSSLStringArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AUsage) do
  begin
    if SameText(Trim(AUsage[I]), 'serverAuth') then
      Exit(True);
  end;
end;

function IsAllowSelfSignedTrustFailure(AErrorCode: Integer): Boolean;
begin
  Result :=
    (AErrorCode = X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT) or
    (AErrorCode = X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN) or
    (AErrorCode = X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY) or
    (AErrorCode = X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE);
end;

constructor TOpenSSLCertificate.Create(AX509: PX509; AOwnsHandle: Boolean = True);
begin
  inherited Create;
  FX509 := AX509;
  FOwnsHandle := AOwnsHandle;
end;

destructor TOpenSSLCertificate.Destroy;
begin
  if FOwnsHandle and (FX509 <> nil) and not OpenSSLX509_Finalizing then
  begin
    if Assigned(X509_free) then
    begin
      try
        X509_free(FX509);
      except
        // P3-8: 记录异常而不是静默忽略
        on E: Exception do
          TSecurityLog.Warning('OpenSSL', Format('Exception in TOpenSSLCertificate.Destroy: %s', [E.Message]));
      end;
    end;
  end;
  inherited;
end;

function TOpenSSLCertificate.LoadFromFile(const AFileName: string): Boolean;
var
  BIO: PBIO;
  FileNameA: AnsiString;
begin
  Result := False;
  if not HasCertificateFileBIOHelpers or not Assigned(PEM_read_bio_X509) then
    Exit;
  if not FileExists(AFileName) then Exit;
  
  FileNameA := AnsiString(AFileName);
  BIO := BIO_new_file(PAnsiChar(FileNameA), 'r');
  if BIO = nil then Exit;
  
  try
    if FOwnsHandle and (FX509 <> nil) then
      X509_free(FX509);
    
    FX509 := PEM_read_bio_X509(BIO, nil, nil, nil);
    FOwnsHandle := True;
    Result := (FX509 <> nil);
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.LoadFromStream(AStream: TStream): Boolean;
var
  Data: TBytes;
  Size: Int64;
  BIO: PBIO;
begin
  Result := False;
  if not HasCertificateMemoryLoadBIOHelpers then
    Exit;
  if not Assigned(PEM_read_bio_X509) and not Assigned(d2i_X509_bio) then
    Exit;

  // Validate stream
  if AStream = nil then
    Exit;

  Size := AStream.Size - AStream.Position;
  if Size <= 0 then
    Exit;

  SetLength(Data, Size);
  if AStream.Read(Data[0], Size) <> Size then
    Exit;

  BIO := BIO_new_mem_buf(@Data[0], Size);
  if BIO = nil then
    Exit;

  try
    if FOwnsHandle and (FX509 <> nil) then
      X509_free(FX509);

    FX509 := nil;
    if Assigned(PEM_read_bio_X509) then
      FX509 := PEM_read_bio_X509(BIO, nil, nil, nil);
    if (FX509 = nil) and Assigned(d2i_X509_bio) then
      FX509 := d2i_X509_bio(BIO, nil);

    FOwnsHandle := True;
    Result := (FX509 <> nil);
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
var
  BIO: PBIO;
begin
  Result := False;
  if not HasCertificateMemoryLoadBIOHelpers then
    Exit;
  if not Assigned(PEM_read_bio_X509) and not Assigned(d2i_X509_bio) then
    Exit;
  if (AData = nil) or (ASize <= 0) then
    Exit;

  // Free existing certificate if we own it
  if FOwnsHandle and (FX509 <> nil) then
  begin
    X509_free(FX509);
    FX509 := nil;
  end;

  // Try PEM format first
  BIO := BIO_new_mem_buf(AData, ASize);
  if BIO = nil then
    Exit;
  try
    FX509 := nil;
    if Assigned(PEM_read_bio_X509) then
      FX509 := PEM_read_bio_X509(BIO, nil, nil, nil);
  finally
    BIO_free(BIO);
  end;

  // If PEM failed, try DER format
  if (FX509 = nil) and Assigned(d2i_X509_bio) then
  begin
    BIO := BIO_new_mem_buf(AData, ASize);
    if BIO = nil then
      Exit;
    try
      FX509 := d2i_X509_bio(BIO, nil);
    finally
      BIO_free(BIO);
    end;
  end;

  FOwnsHandle := True;
  Result := (FX509 <> nil);
end;

function TOpenSSLCertificate.LoadFromPEM(const APEM: string): Boolean;
var
  PEMData: AnsiString;
  BIO: PBIO;
begin
  Result := False;
  if not HasCertificateMemoryLoadBIOHelpers or not Assigned(PEM_read_bio_X509) then
    Exit;

  PEMData := AnsiString(APEM);
  BIO := BIO_new_mem_buf(PAnsiChar(PEMData), Length(PEMData));
  if BIO = nil then
    Exit;
  try
    if FOwnsHandle and (FX509 <> nil) then
      X509_free(FX509);
    
    FX509 := PEM_read_bio_X509(BIO, nil, nil, nil);
    FOwnsHandle := True;
    Result := (FX509 <> nil);
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  if Length(ADER) > 0 then
    Result := LoadFromMemory(@ADER[0], Length(ADER))
  else
    Result := False;
end;

function TOpenSSLCertificate.SaveToFile(const AFileName: string): Boolean;
var
  BIO: PBIO;
  FileNameA: AnsiString;
begin
  Result := False;
  if (FX509 = nil) or
    not HasCertificateFileBIOHelpers or
    not Assigned(PEM_write_bio_X509) then
    Exit;
  
  FileNameA := AnsiString(AFileName);
  BIO := BIO_new_file(PAnsiChar(FileNameA), 'w');
  if BIO = nil then Exit;
  
  try
    Result := (PEM_write_bio_X509(BIO, FX509) = 1);
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.SaveToStream(AStream: TStream): Boolean;
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

function TOpenSSLCertificate.SaveToPEM: string;
var
  BIO: PBIO;
  Len: Integer;
  Buf: PAnsiChar;
begin
  Result := '';
  if (FX509 = nil) or
    not HasCertificateMemorySaveBIOHelpers or
    not Assigned(PEM_write_bio_X509) then
    Exit;
  
  BIO := BIO_new(BIO_s_mem());
  if BIO = nil then
    Exit;
  try
    if PEM_write_bio_X509(BIO, FX509) = 1 then
    begin
      Len := BIO_get_mem_data(BIO, PPAnsiChar(@Buf));
      if Len > 0 then
        SetString(Result, Buf, Len);
    end;
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.SaveToDER: TBytes;
var
  BIO: PBIO;
  Len: Integer;
  Buf: PAnsiChar;
begin
  SetLength(Result, 0);
  if FX509 = nil then
    Exit;

  if not HasCertificateMemorySaveBIOHelpers then
  begin
    try
      LoadOpenSSLCore;
    except
      Exit;
    end;
  end;

  if not Assigned(i2d_X509_bio) then
    LoadOpenSSLX509;

  if not HasCertificateMemorySaveBIOHelpers or
    not Assigned(i2d_X509_bio) then
    Exit;
  
  BIO := BIO_new(BIO_s_mem());
  if BIO = nil then
    Exit;
  try
    if i2d_X509_bio(BIO, FX509) > 0 then
    begin
      Len := BIO_get_mem_data(BIO, PPAnsiChar(@Buf));
      if Len > 0 then
      begin
        SetLength(Result, Len);
        Move(Buf^, Result[0], Len);
      end;
    end;
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLCertificate.GetInfo: TSSLCertificateInfo;
var
  LParser: TX509Certificate;
begin
  FillChar(Result, SizeOf(Result), 0);
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

  if TryLoadParsedOpenSSLCertificate(Self, LParser) then
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

function TOpenSSLCertificate.GetSubject: string;
var
  Name: PX509_NAME;
begin
  Result := '';
  if FX509 = nil then Exit;

  // 检查基本API是否加载
  if not Assigned(X509_get_subject_name) then Exit;

  try
    Name := X509_get_subject_name(FX509);
    Result := X509NameToString(Name);
  except
    on E: Exception do
    begin
      TSecurityLog.Debug('OpenSSL', Format('GetSubject failed: %s', [E.Message]));
      Result := '';
    end;
  end;
end;

function TOpenSSLCertificate.GetIssuer: string;
var
  Name: PX509_NAME;
begin
  Result := '';
  if FX509 = nil then Exit;

  // 检查基本API是否加载
  if not Assigned(X509_get_issuer_name) then Exit;

  try
    Name := X509_get_issuer_name(FX509);
    Result := X509NameToString(Name);
  except
    on E: Exception do
    begin
      TSecurityLog.Debug('OpenSSL', Format('GetIssuer failed: %s', [E.Message]));
      Result := '';
    end;
  end;
end;

function TOpenSSLCertificate.GetSerialNumber: string;
var
  SerialNum: PASN1_INTEGER;
  BN: PBIGNUM;
  HexStr: PAnsiChar;
  CertDER: TBytes;
  CertPEM: string;
  ParsedCert: TX509Certificate;
begin
  Result := '';
  
  if FX509 = nil then
    Exit;

  if not Assigned(X509_get_serialNumber) then
    LoadOpenSSLX509;
  if not Assigned(ASN1_INTEGER_to_BN) then
    LoadOpenSSLASN1(GetCryptoLibHandle);
  if not Assigned(BN_bn2hex) then
    LoadOpenSSLBN;

  if Assigned(X509_get_serialNumber) and
    Assigned(ASN1_INTEGER_to_BN) and
    Assigned(BN_bn2hex) then
  begin
    // 获取序列号
    SerialNum := X509_get_serialNumber(FX509);
    if SerialNum <> nil then
    begin
      // 转换为BIGNUM
      BN := ASN1_INTEGER_to_BN(SerialNum, nil);
      if BN <> nil then
      try
        // 转换为16进制字符串
        HexStr := BN_bn2hex(BN);
        if HexStr <> nil then
        begin
          Result := string(HexStr);
          // 释放OpenSSL分配的字符串
          if Assigned(OPENSSL_free) then
            OPENSSL_free(HexStr);
        end;
      finally
        // 释放BIGNUM
        if Assigned(BN_free) then
          BN_free(BN);
      end;
    end;
  end;

  if Result <> '' then
    Exit;

  // 某些 OpenSSL 构建下 native serial helpers 可能缺失或返回空值；
  // 回退到当前仓库已有的纯 Pascal X.509 parser，保证 public truth 仍可用。
  try
    CertDER := SaveToDER;
    ParsedCert := TX509Certificate.Create;
    try
      if Length(CertDER) > 0 then
        ParsedCert.LoadFromDER(CertDER)
      else
      begin
        CertPEM := SaveToPEM;
        if CertPEM = '' then
          Exit;
        ParsedCert.LoadFromPEM(CertPEM);
      end;
      Result := ParsedCert.SerialNumberAsHex;
    finally
      ParsedCert.Free;
    end;
  except
    Result := '';
  end;
end;

function TOpenSSLCertificate.GetNotBefore: TDateTime;
var
  ASN1Time: PASN1_TIME;
begin
  Result := 0;
  
  if FX509 = nil then
    Exit;
  
  ASN1Time := X509_get_notBefore(FX509);
  if ASN1Time = nil then
    Exit;
  
  Result := ASN1TimeToDateTime(ASN1Time);
end;

function TOpenSSLCertificate.GetNotAfter: TDateTime;
var
  ASN1Time: PASN1_TIME;
begin
  Result := 0;
  
  if FX509 = nil then
    Exit;
  
  ASN1Time := X509_get_notAfter(FX509);
  if ASN1Time = nil then
    Exit;
  
  Result := ASN1TimeToDateTime(ASN1Time);
end;

function TOpenSSLCertificate.GetPublicKey: string;
var
  PKey: PEVP_PKEY;
begin
  Result := '';
  
  if FX509 = nil then
    Exit;
  
  PKey := X509_get_pubkey(FX509);
  if PKey <> nil then
  begin
    Result := GetPublicKeyAlgorithm; // 简化实现，返回算法名
    EVP_PKEY_free(PKey);
  end;
end;

function TOpenSSLCertificate.GetPublicKeyAlgorithm: string;
var
  PKey: PEVP_PKEY;
  KeyType: Integer;
begin
  Result := '';
  
  if FX509 = nil then
    Exit;
  
  PKey := X509_get_pubkey(FX509);
  if PKey = nil then
    Exit;
  
  try
    KeyType := EVP_PKEY_id(PKey);
    case KeyType of
      EVP_PKEY_RSA: Result := 'RSA';
      EVP_PKEY_DSA: Result := 'DSA';
      EVP_PKEY_DH: Result := 'DH';
      EVP_PKEY_EC: Result := 'EC';
      EVP_PKEY_ED25519: Result := 'Ed25519';
      EVP_PKEY_ED448: Result := 'Ed448';
    else
      Result := 'Unknown';
    end;
  finally
    EVP_PKEY_free(PKey);
  end;
end;

function TOpenSSLCertificate.GetSignatureAlgorithm: string;
var
  NID: Integer;
  AlgName: PAnsiChar;
begin
  Result := '';
  
  if FX509 = nil then
    Exit;
  
  // 检查必要的API是否已加载
  if not Assigned(X509_get_signature_nid) or not Assigned(OBJ_nid2sn) then
  begin
    Result := 'SHA256withRSA'; // 降级到默认值
    Exit;
  end;
  
  // 获取签名算法的NID
  NID := X509_get_signature_nid(FX509);
  if NID <= 0 then
  begin
    Result := 'Unknown';
    Exit;
  end;
  
  // 将NID转换为短名称
  AlgName := OBJ_nid2sn(NID);
  if AlgName <> nil then
    Result := string(AlgName)
  else
    Result := Format('NID:%d', [NID]);
end;

function TOpenSSLCertificate.GetVersion: Integer;
begin
  if FX509 <> nil then
    Result := X509_get_version(FX509) + 1
  else
    Result := 0;
end;

function TOpenSSLCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
var
  Store: PX509_STORE;
  Ctx: PX509_STORE_CTX;
begin
  Result := False;
  
  if (FX509 = nil) or (ACAStore = nil) then
    Exit;

  if (not Assigned(X509_STORE_CTX_new)) or
    (not Assigned(X509_STORE_CTX_init)) or
    (not Assigned(X509_verify_cert)) or
    (not Assigned(X509_STORE_CTX_free)) then
  begin
    LoadOpenSSLX509;
    if (not Assigned(X509_STORE_CTX_new)) or
      (not Assigned(X509_STORE_CTX_init)) or
      (not Assigned(X509_verify_cert)) or
      (not Assigned(X509_STORE_CTX_free)) then
      Exit;
  end;

  // 使用辅助函数安全获取原生句柄
  Store := PX509_STORE(GetNativeHandleSafe(ACAStore, 'TOpenSSLCertificate.Verify'));
  if Store = nil then
    Exit;

  Ctx := nil;
  try
    try
      Ctx := X509_STORE_CTX_new();
    except
      on E: Exception do
      begin
        TSecurityLog.Debug('OpenSSL', Format('X509_STORE_CTX_new failed: %s', [E.Message]));
        Exit;
      end;
    end;
    if Ctx = nil then
      Exit;

    try
      if X509_STORE_CTX_init(Ctx, Store, FX509, nil) = 1 then
        Result := (X509_verify_cert(Ctx) = 1);
    except
      on E: Exception do
      begin
        TSecurityLog.Debug('OpenSSL', Format('X509_verify_cert failed: %s', [E.Message]));
        Result := False;
      end;
    end;
  finally
    if Ctx <> nil then
    begin
      try
        X509_STORE_CTX_free(Ctx);
      except
        on E: Exception do
          TSecurityLog.Warning('OpenSSL', Format('Exception freeing X509_STORE_CTX in Verify: %s', [E.Message]));
      end;
    end;
  end;
end;

function TOpenSSLCertificate.VerifyEx(ACAStore: ISSLCertificateStore; 
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
var
  Store: PX509_STORE;
  Ctx: PX509_STORE_CTX;
  Ret: Integer;
  ErrorCode: Integer;
  ErrorStr: PAnsiChar;
  OCSPUrl: string;
  IssuerX509: PX509;
  OCSPStatus: Integer;
  OCSPTimeoutSec: Integer;
  CertDER: TBytes;
  ParsedCert: TX509Certificate;
  Chain: PSTACK_OF_X509;
  LExtendedKeyUsage: TSSLStringArray;
  LPerCallVerifyFlags: Cardinal;
  LSelfSignedOverride: Boolean;
begin
  AResult.Success := False;
  AResult.ErrorCode := 0;
  AResult.ErrorMessage := '';
  AResult.ChainStatus := 0;
  AResult.RevocationStatus := 0;
  AResult.DetailedInfo := '';
  Result := False;
  
  if FX509 = nil then
  begin
    AResult.ErrorMessage := 'Certificate is nil';
    Exit;
  end;
  
  if ACAStore = nil then
  begin
    AResult.ErrorMessage := 'CA store is nil';
    Exit;
  end;

  // 使用辅助函数安全获取原生句柄
  Store := PX509_STORE(GetNativeHandleSafe(ACAStore, 'TOpenSSLCertificate.VerifyEx'));
  if Store = nil then
  begin
    AResult.ErrorMessage := 'Invalid CA store handle';
    Exit;
  end;


  if (not Assigned(X509_STORE_CTX_new)) or
    (not Assigned(X509_STORE_CTX_init)) or
    (not Assigned(X509_verify_cert)) or
    (not Assigned(X509_STORE_CTX_free)) or
    (not Assigned(X509_STORE_CTX_get_error)) or
    (not Assigned(X509_verify_cert_error_string)) then
  begin
    LoadOpenSSLX509;
    if (not Assigned(X509_STORE_CTX_new)) or
      (not Assigned(X509_STORE_CTX_init)) or
      (not Assigned(X509_verify_cert)) or
      (not Assigned(X509_STORE_CTX_free)) or
      (not Assigned(X509_STORE_CTX_get_error)) or
      (not Assigned(X509_verify_cert_error_string)) then
    begin
      AResult.ErrorMessage := 'OpenSSL X509 verification API not loaded';
      Exit;
    end;
  end;
  
  Ctx := nil;
  try
    try
      Ctx := X509_STORE_CTX_new();
    except
      AResult.ErrorMessage := 'Failed to create store context';
      Exit;
    end;
    if Ctx = nil then
    begin
      AResult.ErrorMessage := 'Failed to create store context';
      Exit;
    end;

    if X509_STORE_CTX_init(Ctx, Store, FX509, nil) = 1 then
    begin
      if Assigned(X509_STORE_CTX_get0_param) and Assigned(X509_VERIFY_PARAM_set_flags) then
      begin
        LPerCallVerifyFlags := 0;
        if sslCertVerifyIgnoreExpiry in AFlags then
          LPerCallVerifyFlags := LPerCallVerifyFlags or X509_V_FLAG_NO_CHECK_TIME;
        if LPerCallVerifyFlags <> 0 then
          X509_VERIFY_PARAM_set_flags(
            X509_STORE_CTX_get0_param(Ctx),
            LPerCallVerifyFlags
          );
      end;

      // CRL吊销检查已在下方实现（使用X509_V_FLAG_CRL_CHECK标志）
      
      // 如果需要检查吊销状态，则在验证参数上启用 CRL 检查
      if ((sslCertVerifyCheckRevocation in AFlags) or
          (sslCertVerifyCheckCRL in AFlags)) and
        Assigned(X509_STORE_CTX_get0_param) and
        Assigned(X509_VERIFY_PARAM_set_flags) then
      begin
        X509_VERIFY_PARAM_set_flags(
          X509_STORE_CTX_get0_param(Ctx),
          X509_V_FLAG_CRL_CHECK or X509_V_FLAG_CRL_CHECK_ALL
        );
      end;
      
      Ret := X509_verify_cert(Ctx);
      LSelfSignedOverride := False;

      if Ret <> 1 then
      begin
        ErrorCode := X509_STORE_CTX_get_error(Ctx);
        if (sslCertVerifyAllowSelfSigned in AFlags) and
          IsSelfSigned and
          IsAllowSelfSignedTrustFailure(ErrorCode) then
        begin
          LSelfSignedOverride := True;
          Ret := 1;
          if Assigned(X509_STORE_CTX_set_error) then
            X509_STORE_CTX_set_error(Ctx, X509_V_OK);
        end;
      end;
      
      if Ret = 1 then
      begin
        if sslCertVerifyStrictChain in AFlags then
        begin
          LExtendedKeyUsage := GetExtendedKeyUsage;
          if not HasServerAuthUsage(LExtendedKeyUsage) then
          begin
            AResult.Success := False;
            AResult.ErrorCode := X509_V_ERR_INVALID_PURPOSE;
            AResult.ErrorMessage := 'Strict chain verification requires serverAuth extended key usage';
            AResult.ChainStatus := 2;
            AResult.DetailedInfo :=
              'sslCertVerifyStrictChain requested but the leaf certificate is missing serverAuth extended key usage';
            Exit;
          end;
        end;

        // Optional OCSP revocation check (fails closed when requested)
        if sslCertVerifyCheckOCSP in AFlags then
        begin
          // Ensure OCSP APIs are loaded
          if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
            LoadOpenSSLOCSP(GetCryptoLibHandle);

          if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
          begin
            AResult.Success := False;
            AResult.ErrorCode := X509_V_ERR_OCSP_VERIFY_FAILED;
            AResult.ErrorMessage := 'OCSP verification requested but OCSP API is unavailable';
            AResult.DetailedInfo := 'Failed to load OpenSSL OCSP module';
            AResult.RevocationStatus := 2;
            Exit;
          end;

          // Determine issuer certificate (required for OCSP CertID)
          IssuerX509 := nil;
          if FIssuerCert <> nil then
          begin
            // 尝试获取发行者证书的原生句柄
            if not TryGetNativeHandle(FIssuerCert, Pointer(IssuerX509)) then
              IssuerX509 := nil;
          end;

          if IssuerX509 = nil then
          begin
            Chain := nil;
            if Assigned(X509_STORE_CTX_get0_chain) then
              Chain := X509_STORE_CTX_get0_chain(Ctx);

            if Chain <> nil then
              IssuerX509 := FindIssuerX509InChain(FX509, Chain);
          end;

          if IssuerX509 = nil then
          begin
            AResult.Success := False;
            AResult.ErrorCode := X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT;
            AResult.ErrorMessage := 'OCSP verification requires issuer certificate';
            AResult.DetailedInfo := 'Could not determine issuer certificate for OCSP request';
            AResult.RevocationStatus := 2;
            Exit;
          end;

          // Extract responder URL from certificate AIA (pure-pascal parser)
          OCSPUrl := '';
          try
            CertDER := SaveToDER;
            if Length(CertDER) > 0 then
            begin
              ParsedCert := TX509Certificate.Create;
              try
                ParsedCert.LoadFromDER(CertDER);
                OCSPUrl := GetOCSPURLFromCertificate(ParsedCert);
              finally
                ParsedCert.Free;
              end;
            end;
          except
            OCSPUrl := '';
          end;

          if OCSPUrl = '' then
          begin
            AResult.Success := False;
            AResult.ErrorCode := X509_V_ERR_OCSP_VERIFY_NEEDED;
            AResult.ErrorMessage := 'OCSP responder URL not found in certificate';
            AResult.DetailedInfo := 'sslCertVerifyCheckOCSP requested but certificate AIA has no OCSP URL';
            AResult.RevocationStatus := 2;
            Exit;
          end;

          // Perform OCSP check (supports http/https responders)
          OCSPTimeoutSec := 10;
          OCSPStatus := CheckCertificateStatus(FX509, IssuerX509, OCSPUrl, OCSPTimeoutSec, Store);

          case OCSPStatus of
            V_OCSP_CERTSTATUS_GOOD:
              ; // OK
            V_OCSP_CERTSTATUS_REVOKED:
              begin
                AResult.Success := False;
                AResult.ErrorCode := X509_V_ERR_CERT_REVOKED;
                AResult.ErrorMessage := 'Certificate has been revoked (OCSP)';
                AResult.DetailedInfo := 'OCSP responder reported certificate revoked';
                AResult.RevocationStatus := 1;
                Exit;
              end;
            V_OCSP_CERTSTATUS_UNKNOWN:
              begin
                AResult.Success := False;
                AResult.ErrorCode := X509_V_ERR_OCSP_CERT_UNKNOWN;
                AResult.ErrorMessage := 'Certificate OCSP status unknown';
                AResult.DetailedInfo := 'OCSP responder returned unknown status';
                AResult.RevocationStatus := 2;
                Exit;
              end;
          else
            AResult.Success := False;
            AResult.ErrorCode := X509_V_ERR_OCSP_VERIFY_FAILED;
            AResult.ErrorMessage := 'OCSP verification failed';
            AResult.DetailedInfo := 'OCSP request/response validation failed';
            AResult.RevocationStatus := 2;
            Exit;
          end;
        end;

        AResult.Success := True;
        AResult.ErrorCode := 0;
        AResult.ErrorMessage := 'Certificate verification successful';
        if LSelfSignedOverride then
          AResult.DetailedInfo :=
            'OpenSSL verification passed with sslCertVerifyAllowSelfSigned override for a self-signed leaf certificate'
        else
          AResult.DetailedInfo := 'OpenSSL verification passed';
        AResult.RevocationStatus := 0;
        Result := True;
      end
      else
      begin
        ErrorCode := X509_STORE_CTX_get_error(Ctx);
        ErrorStr := X509_verify_cert_error_string(ErrorCode);
        
        AResult.Success := False;
        AResult.ErrorCode := ErrorCode;
        if ErrorStr <> nil then
          AResult.ErrorMessage := string(ErrorStr)
        else
          AResult.ErrorMessage := 'Certificate verification failed';
        AResult.DetailedInfo := Format('OpenSSL error: %d - %s',
          [ErrorCode, AResult.ErrorMessage]);
        
        // 映射常见的吊销相关错误到 RevocationStatus
        if ErrorCode = X509_V_ERR_CERT_REVOKED then
          AResult.RevocationStatus := 1
        else if (ErrorCode = X509_V_ERR_UNABLE_TO_GET_CRL) or
                (ErrorCode = X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER) or
                (ErrorCode = X509_V_ERR_CRL_NOT_YET_VALID) or
                (ErrorCode = X509_V_ERR_CRL_HAS_EXPIRED) or
                (ErrorCode = X509_V_ERR_OCSP_VERIFY_NEEDED) or
                (ErrorCode = X509_V_ERR_OCSP_VERIFY_FAILED) or
                (ErrorCode = X509_V_ERR_OCSP_CERT_UNKNOWN) then
          AResult.RevocationStatus := 2
        else
          AResult.RevocationStatus := 0;
      end;
    end
    else
      AResult.ErrorMessage := 'Failed to initialize verification context';
  finally
    if Ctx <> nil then
    begin
      try
        X509_STORE_CTX_free(Ctx);
      except
        on E: Exception do
          TSecurityLog.Warning('OpenSSL', Format('Exception freeing X509_STORE_CTX in VerifyEx: %s', [E.Message]));
      end;
    end;
  end;
end;

function TOpenSSLCertificate.VerifyHostname(const AHostname: string): Boolean;
var
  Hostname: string;
  HostnameA: AnsiString;
  IsIP: Boolean;

  function NormalizeHostForVerify(const S: string): string;
  var
    LHost: string;
    P, PEnd: SizeInt;
    PortPart: string;
    I: Integer;
  begin
    LHost := Trim(S);

    // Strip IPv6 brackets: [::1]
    if (LHost <> '') and (LHost[1] = '[') then
    begin
      PEnd := Pos(']', LHost);
      if PEnd > 0 then
        LHost := Copy(LHost, 2, PEnd - 2);
    end;

    // Strip zone id: fe80::1%eth0
    P := Pos('%', LHost);
    if P > 0 then
      LHost := Copy(LHost, 1, P - 1);

    // Strip port for the host:port case (not valid for plain IPv6 without brackets)
    if (Pos(':', LHost) > 0) and (Pos(':', LHost) = LastDelimiter(':', LHost)) then
    begin
      P := Pos(':', LHost);
      PortPart := Copy(LHost, P + 1, Length(LHost) - P);
      if PortPart <> '' then
      begin
        for I := 1 to Length(PortPart) do
          if not (PortPart[I] in ['0'..'9']) then
          begin
            PortPart := '';
            Break;
          end;
        if PortPart <> '' then
          LHost := Copy(LHost, 1, P - 1);
      end;
    end;

    Result := LHost;
  end;

  function IsValidIPv4(const S: string): Boolean;
  var
    Parts: TStringArray;
    Part: string;
    Value: Integer;
    I: Integer;
  begin
    Result := False;
    Parts := S.Split(['.']);
    if Length(Parts) <> 4 then
      Exit;

    for Part in Parts do
    begin
      if Part = '' then
        Exit;

      for I := 1 to Length(Part) do
        if not (Part[I] in ['0'..'9']) then
          Exit;

      if not TryStrToInt(Part, Value) then
        Exit;
      if (Value < 0) or (Value > 255) then
        Exit;
    end;

    Result := True;
  end;

begin
  Result := False;

  if FX509 = nil then
    Exit;

  Hostname := NormalizeHostForVerify(AHostname);
  if Hostname = '' then
    Exit;

  // Ensure X509 hostname verification helpers are available
  if (not Assigned(X509_check_host)) and (not Assigned(X509_check_ip_asc)) then
    LoadOpenSSLX509;

  IsIP := IsValidIPv4(Hostname) or (Pos(':', Hostname) > 0);
  HostnameA := AnsiString(Hostname);

  if IsIP then
  begin
    if not Assigned(X509_check_ip_asc) then
      Exit(False);
    Result := (X509_check_ip_asc(FX509, PAnsiChar(HostnameA), 0) = 1);
  end
  else
  begin
    if not Assigned(X509_check_host) then
      Exit(False);
    Result := (X509_check_host(FX509, PAnsiChar(HostnameA), Length(HostnameA), 0, nil) = 1);
  end;
end;

function TOpenSSLCertificate.IsExpired: Boolean;
var
  CurrentTime: TDateTime;
begin
  Result := False;
  
  if FX509 = nil then
    Exit;
  
  CurrentTime := DateTimeUtcNow;
  Result := (CurrentTime < GetNotBefore) or (CurrentTime > GetNotAfter);
end;

function TOpenSSLCertificate.IsSelfSigned: Boolean;
var
  SubjectName, IssuerName: PX509_NAME;
begin
  Result := False;
  
  if FX509 = nil then
    Exit;
  
  // Use proper X509_NAME comparison instead of string comparison
  // String comparison is unreliable due to encoding differences and ordering
  if Assigned(X509_get_subject_name) and Assigned(X509_get_issuer_name) and 
    Assigned(X509_NAME_cmp) then
  begin
    SubjectName := X509_get_subject_name(FX509);
    IssuerName := X509_get_issuer_name(FX509);
    
    if (SubjectName <> nil) and (IssuerName <> nil) then
      Result := (X509_NAME_cmp(SubjectName, IssuerName) = 0);
  end
  else
  begin
    // Fallback to string comparison if APIs not available
    Result := (GetSubject = GetIssuer);
  end;
end;

function TOpenSSLCertificate.IsCA: Boolean;
var
  CAValue: Integer;
  Flags: UInt32;
const
  EXFLAG_CA = $10;  // CA 标志位
begin
  Result := False;
  
  if FX509 = nil then
    Exit;
  
  // 优先使用 X509_check_ca（OpenSSL 1.0.0+）
  if Assigned(X509_check_ca) then
  begin
    // Force extension caching, often needed for newly created certificates
    if Assigned(X509_check_purpose) then
      X509_check_purpose(FX509, -1, 0);
      
    CAValue := X509_check_ca(FX509);
    // Return: >= 1 means CA, 0 means not CA, -1 means error
    Result := (CAValue >= 1);
  end
  else if Assigned(X509_get_extension_flags) then
  begin
    // 备用方案：使用扩展标志（需要 OpenSSL 1.1.0+）
    Flags := X509_get_extension_flags(FX509);
    Result := (Flags and EXFLAG_CA) <> 0;
  end;
end;

function TOpenSSLCertificate.GetDaysUntilExpiry: Integer;
var
  ExpiryDate: TDateTime;
begin
  // 返回证书到期天数，已过期返回负数
  if FX509 = nil then
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

function TOpenSSLCertificate.GetSubjectCN: string;
var
  Subject: string;
  P, PEnd: Integer;
begin
  // 从 Subject DN 中提取 Common Name (CN)
  Result := '';

  if FX509 = nil then
    Exit;

  Subject := GetSubject;
  if Subject = '' then
    Exit;

  // 尝试解析 RFC 2253 格式: "CN=Example, O=Org, ..."
  // 或 OpenSSL oneline 格式: "/CN=Example/O=Org/..."

  // 格式1: "CN=" 开头或 ", CN=" 分隔
  P := Pos('CN=', Subject);
  if P = 0 then
    P := Pos('cn=', Subject);  // 小写兼容

  if P > 0 then
  begin
    // 跳过 "CN="
    Inc(P, 3);

    // 查找分隔符（逗号或斜杠）
    PEnd := P;
    while (PEnd <= Length(Subject)) do
    begin
      if Subject[PEnd] in [',', '/', '+'] then
        Break;
      Inc(PEnd);
    end;

    Result := Trim(Copy(Subject, P, PEnd - P));
    Exit;
  end;

  // 格式2: "/CN=" 格式
  P := Pos('/CN=', Subject);
  if P = 0 then
    P := Pos('/cn=', Subject);

  if P > 0 then
  begin
    Inc(P, 4);
    PEnd := P;
    while (PEnd <= Length(Subject)) and (Subject[PEnd] <> '/') do
      Inc(PEnd);

    Result := Trim(Copy(Subject, P, PEnd - P));
  end;
end;

function TOpenSSLCertificate.GetExtension(const AOID: string): string;
var
  LParser: TX509Certificate;
begin
  Result := '';

  if (FX509 = nil) or (Trim(AOID) = '') then
    Exit;

  if not TryLoadParsedOpenSSLCertificate(Self, LParser) then
    Exit;

  try
    TryGetParsedExtensionValue(LParser, AOID, Result);
  finally
    LParser.Free;
  end;
end;

function TOpenSSLCertificate.GetSubjectAltNames: TSSLStringArray;
var
  I: Integer;
  ExtStr: string;
  Names: PGENERAL_NAMES;
  Gen: PGENERAL_NAME;
  Count: Integer;
  LType: Integer;
  Val: Pointer;
  Data: PByte;
  Len: Integer;
  Crit, Idx: Integer;
  LValue: string;
  LParser: TX509Certificate;

begin
  SetLength(Result, 0);

  if FX509 = nil then
    Exit;

  if Assigned(X509_get_ext_d2i) and
    LoadStackFunctions and
    Assigned(OPENSSL_sk_num) and Assigned(OPENSSL_sk_value) and
    Assigned(GENERAL_NAME_get0_value) and Assigned(GENERAL_NAMES_free) and
    Assigned(ASN1_STRING_length) and
    (Assigned(ASN1_STRING_get0_data) or Assigned(ASN1_STRING_data)) then
  begin
    Crit := 0;
    Idx := -1;
    Names := PGENERAL_NAMES(X509_get_ext_d2i(FX509, NID_subject_alt_name, @Crit, @Idx));
    if Names <> nil then
    begin
      try
        Count := OPENSSL_sk_num(POPENSSL_STACK(Names));
        for I := 0 to Count - 1 do
        begin
          Gen := PGENERAL_NAME(OPENSSL_sk_value(POPENSSL_STACK(Names), I));
          if Gen = nil then
            Continue;

          Val := GENERAL_NAME_get0_value(Gen, @LType);
          if Val = nil then
            Continue;

          if LType = GEN_DNS then
          begin
            ExtStr := ASN1StringToString(ASN1_STRING(Val));
            if ExtStr <> '' then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[High(Result)] := ExtStr;
            end;
          end
          else if LType = GEN_EMAIL then
          begin
            ExtStr := ASN1StringToString(ASN1_STRING(Val));
            if ExtStr <> '' then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[High(Result)] := ExtStr;
            end;
          end
          else if LType = GEN_URI then
          begin
            ExtStr := ASN1StringToString(ASN1_STRING(Val));
            if ExtStr <> '' then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[High(Result)] := ExtStr;
            end;
          end
          else if LType = GEN_IPADD then
          begin
            Len := ASN1_STRING_length(ASN1_STRING(Val));
            if Len <= 0 then
              Continue;
            if Assigned(ASN1_STRING_get0_data) then
              Data := ASN1_STRING_get0_data(ASN1_STRING(Val))
            else
              Data := ASN1_STRING_data(ASN1_STRING(Val));
            if Data = nil then
              Continue;
            LValue := IpBytesToString(Data, Len);
            if LValue <> '' then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[High(Result)] := LValue;
            end;
          end;
        end;
      finally
        GENERAL_NAMES_free(Names);
      end;
      Exit;
    end;
  end;

  if not TryLoadParsedOpenSSLCertificate(Self, LParser) then
    Exit;

  try
    Result := X509SubjectAltNamesToStrings(LParser.SubjectAltNames);
  finally
    LParser.Free;
  end;
end;

function TOpenSSLCertificate.GetKeyUsage: TSSLStringArray;
var
  KUFlags: UInt32;
  LParser: TX509Certificate;

  procedure AddToResult(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

begin
  SetLength(Result, 0);

  if FX509 = nil then
    Exit;

  // 优先使用位标志接口（OpenSSL 1.1+ 提供）
  if Assigned(X509_get_key_usage) then
  begin
    KUFlags := X509_get_key_usage(FX509);
    if (KUFlags and X509v3_KU_DIGITAL_SIGNATURE) <> 0 then
      AddToResult('digitalSignature');
    if (KUFlags and X509v3_KU_NON_REPUDIATION) <> 0 then
      AddToResult('nonRepudiation');
    if (KUFlags and X509v3_KU_KEY_ENCIPHERMENT) <> 0 then
      AddToResult('keyEncipherment');
    if (KUFlags and X509v3_KU_DATA_ENCIPHERMENT) <> 0 then
      AddToResult('dataEncipherment');
    if (KUFlags and X509v3_KU_KEY_AGREEMENT) <> 0 then
      AddToResult('keyAgreement');
    if (KUFlags and X509v3_KU_KEY_CERT_SIGN) <> 0 then
      AddToResult('keyCertSign');
    if (KUFlags and X509v3_KU_CRL_SIGN) <> 0 then
      AddToResult('cRLSign');
    if (KUFlags and X509v3_KU_ENCIPHER_ONLY) <> 0 then
      AddToResult('encipherOnly');
    if (KUFlags and X509v3_KU_DECIPHER_ONLY) <> 0 then
      AddToResult('decipherOnly');
    Exit;
  end;

  if not TryLoadParsedOpenSSLCertificate(Self, LParser) then
    Exit;

  try
    Result := X509KeyUsageToStrings(LParser.KeyUsage);
  finally
    LParser.Free;
  end;
end;

function TOpenSSLCertificate.GetExtendedKeyUsage: TSSLStringArray;
var
  EKUFlags: UInt32;
  LParser: TX509Certificate;

  procedure AddToResult(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

begin
  SetLength(Result, 0);

  if FX509 = nil then
    Exit;

  // 优先使用位标志接口（XKU_*），然后再回退到文本解析
  if Assigned(X509_get_extended_key_usage) then
  begin
    EKUFlags := X509_get_extended_key_usage(FX509);
    if (EKUFlags and XKU_SSL_SERVER) <> 0 then
      AddToResult('serverAuth');
    if (EKUFlags and XKU_SSL_CLIENT) <> 0 then
      AddToResult('clientAuth');
    if (EKUFlags and XKU_SMIME) <> 0 then
      AddToResult('emailProtection');
    if (EKUFlags and XKU_CODE_SIGN) <> 0 then
      AddToResult('codeSigning');
    if (EKUFlags and XKU_OCSP_SIGN) <> 0 then
      AddToResult('OCSPSigning');
    if (EKUFlags and XKU_TIMESTAMP) <> 0 then
      AddToResult('timeStamping');
    if (EKUFlags and XKU_ANYEKU) <> 0 then
      AddToResult('anyExtendedKeyUsage');
    Exit;
  end;

  if not TryLoadParsedOpenSSLCertificate(Self, LParser) then
    Exit;

  try
    Result := X509ExtKeyUsageToStrings(LParser.ExtKeyUsage);
  finally
    LParser.Free;
  end;
end;

function TOpenSSLCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  case AHashType of
    sslHashSHA1:   Result := GetFingerprintSHA1;
    sslHashSHA256: Result := GetFingerprintSHA256;
  else
    Result := '';
  end;
end;

// P3-10/15: Extracted common fingerprint computation with optimized string building
function TOpenSSLCertificate.ComputeFingerprint(MD: PEVP_MD): string;
var
  Digest: array[0..EVP_MAX_MD_SIZE-1] of Byte;
  DigestLen: Cardinal;
  I, Pos: Integer;
  DER, P: PByte;
  DERLen: Integer;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
begin
  Result := '';

  if FX509 = nil then
    Exit;

  // Get DER encoding length
  DERLen := i2d_X509(FX509, nil);
  if DERLen <= 0 then
    Exit;

  GetMem(DER, DERLen);
  try
    P := DER;
    i2d_X509(FX509, @P);

    // Compute digest
    DigestLen := 0;
    if EVP_Digest(DER, NativeUInt(DERLen), @Digest[0], DigestLen, MD, nil) = 1 then
    begin
      // P3-10: Pre-allocate string for better performance (XX:XX:XX format)
      SetLength(Result, DigestLen * 3 - 1);
      Pos := 1;
      for I := 0 to DigestLen - 1 do
      begin
        if I > 0 then
        begin
          Result[Pos] := ':';
          Inc(Pos);
        end;
        Result[Pos] := HexChars[Digest[I] shr 4];
        Result[Pos + 1] := HexChars[Digest[I] and $0F];
        Inc(Pos, 2);
      end;
    end;
  finally
    FreeMem(DER);
  end;
end;

function TOpenSSLCertificate.GetFingerprintSHA1: string;
begin
  Result := ComputeFingerprint(EVP_sha1());
end;

function TOpenSSLCertificate.GetFingerprintSHA256: string;
begin
  Result := ComputeFingerprint(EVP_sha256());
end;

procedure TOpenSSLCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCert := ACert;
end;

function TOpenSSLCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCert;
end;

function TOpenSSLCertificate.GetNativeHandle: Pointer;
begin
  Result := FX509;
end;

function TOpenSSLCertificate.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLCertificate.IsNativeHandleValid: Boolean;
begin
  Result := (FX509 <> nil);
end;

function TOpenSSLCertificate.Clone: ISSLCertificate;
var
  LClone: TOpenSSLCertificate;
begin
  Result := nil;
  if FX509 = nil then
    Exit;

  // Increment reference count first
  X509_up_ref(FX509);
  try
    // Create new certificate wrapper - if this fails, we must decrement ref
    LClone := TOpenSSLCertificate.Create(FX509, True);
    LClone.FIssuerCert := FIssuerCert;
    Result := LClone;
  except
    // Decrement reference count on failure to prevent leak
    if Assigned(X509_free) then
      X509_free(FX509);
    raise;
  end;
end;

end.
