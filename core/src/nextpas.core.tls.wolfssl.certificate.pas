{**
 * Unit: nextpas.core.tls.wolfssl.certificate
 * Purpose: WolfSSL 证书和证书存储实现
 *
 * 实现 ISSLCertificate 和 ISSLCertificateStore 接口的 WolfSSL 后端。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.wolfssl.certificate;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, nextpas.core.io.intf, nextpas.core.fs.stream,
  nextpas.core.base.utils,
  nextpas.core.fs,
  nextpas.core.collections.vec,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.x509,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.native_handle,
  nextpas.core.tls.wolfssl.api;

type
  { TWolfSSLCertificate - WolfSSL 证书类 }
  TWolfSSLCertificate = class(TInterfacedObject, ISSLCertificate, ISSLNativeHandleAccess)
  private
    FX509: PWOLFSSL_X509;
    FInfo: TSSLCertificateInfo;
    FPEMData: string;
    FDERData: TBytes;
    FIssuerCert: ISSLCertificate;
    procedure ResetLoadedState;
    function LoadNativeFromDER(const ADER: TBytes): Boolean;
    function TryLoadX509Parser(out AParser: TX509Certificate): Boolean;
    function TryGetParsedAlgorithmMetadata(out APublicKeyAlgorithm,
      ASignatureAlgorithm: string): Boolean;

  public
    constructor Create; overload;
    constructor Create(AX509: PWOLFSSL_X509); overload;
    destructor Destroy; override;

    { ISSLCertificate - 加载和保存 }
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromStream(AStream: IStream): Boolean;
    function LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
    function LoadFromPEM(const APEM: string): Boolean;
    function LoadFromDER(const ADER: TBytes): Boolean;
    function SaveToFile(const AFileName: string): Boolean;
    function SaveToStream(AStream: IStream): Boolean;
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

  { TWolfSSLCertificateStore - WolfSSL 证书存储类 }
  TWolfSSLCertificateStore = class(TInterfacedObject, ISSLCertificateStore, ISSLNativeHandleAccess)
  private
    FX509Store: PWOLFSSL_X509_STORE;
    FCertificates: specialize TVec<IInterface>;

  public
    constructor Create;
    destructor Destroy; override;

    { ISSLCertificateStore - 证书管理 }
    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;

    { ISSLCertificateStore - 加载方法 }
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean;

    { ISSLCertificateStore - 查找 }
    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;

    { ISSLCertificateStore - 验证 }
    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

implementation

uses
  DateUtils,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.time,
  nextpas.core.tls.utils,
  nextpas.core.crypto.hash,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.servercertverify;

function NormalizeWolfCertText(const AValue: string): string;
begin
  Result := Trim(UpperCase(AValue));
  Result := StringReplace(Result, ',', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function NormalizeWolfCertFingerprint(const AFingerprint: string): string;
begin
  Result := Trim(UpperCase(AFingerprint));
  Result := StringReplace(Result, ':', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function NormalizeWolfCertSerial(const ASerialNumber: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '';
  for I := 1 to Length(ASerialNumber) do
  begin
    LChar := UpCase(ASerialNumber[I]);
    if LChar in ['0'..'9', 'A'..'F'] then
      Result := Result + LChar;
  end;
end;

procedure ResetCertVerifyResult(out AResult: TSSLCertVerifyResult);
begin
  AResult.Success := False;
  AResult.ErrorCode := 0;
  AResult.ErrorMessage := '';
  AResult.ChainStatus := 0;
  AResult.RevocationStatus := 0;
  AResult.DetailedInfo := '';
end;

function TryLoadParsedCertificateFromInterface(ACert: ISSLCertificate;
  out AParser: TX509Certificate; out AError: string): Boolean;
var
  LDER: TBytes;
begin
  Result := False;
  AParser := nil;
  AError := '';

  if ACert = nil then
  begin
    AError := 'Certificate is not configured';
    Exit;
  end;

  LDER := ACert.SaveToDER;
  if Length(LDER) = 0 then
  begin
    AError := 'Certificate DER material is unavailable';
    Exit;
  end;

  AParser := TX509Certificate.Create;
  try
    AParser.LoadFromDER(LDER);
    Result := True;
  except
    on E: Exception do
    begin
      AError := 'Failed to parse certificate DER: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TryMapCertificateSignatureScheme(const ASignatureOID: string;
  const AIssuerKeyInfo: TX509PublicKeyInfo; out AScheme: Word;
  out AError: string): Boolean;
begin
  Result := False;
  AError := '';

  if SameText(ASignatureOID, '1.2.840.113549.1.1.11') then
  begin
    if not SameText(AIssuerKeyInfo.KeyType, 'RSA') then
    begin
      AError := 'Issuer public key type is not RSA for sha256WithRSAEncryption';
      Exit;
    end;
    AScheme := TLS13_SIG_RSA_PKCS1_SHA256;
    Exit(True);
  end;

  if SameText(ASignatureOID, '1.2.840.113549.1.1.12') then
  begin
    if not SameText(AIssuerKeyInfo.KeyType, 'RSA') then
    begin
      AError := 'Issuer public key type is not RSA for sha384WithRSAEncryption';
      Exit;
    end;
    AScheme := TLS13_SIG_RSA_PKCS1_SHA384;
    Exit(True);
  end;

  if SameText(ASignatureOID, '1.2.840.10045.4.3.2') then
  begin
    if not SameText(AIssuerKeyInfo.KeyType, 'ECDSA') then
    begin
      AError := 'Issuer public key type is not ECDSA for ecdsa-with-SHA256';
      Exit;
    end;
    if (not SameText(AIssuerKeyInfo.ECCurve, 'prime256v1')) and
      (not SameText(AIssuerKeyInfo.ECCurve, 'secp256r1')) then
    begin
      AError := 'Issuer ECDSA curve is unsupported for ecdsa-with-SHA256';
      Exit;
    end;
    AScheme := TLS13_SIG_ECDSA_SECP256R1_SHA256;
    Exit(True);
  end;

  AError := 'Unsupported certificate signature algorithm: ' + ASignatureOID;
end;

function TryVerifyCertificateSignatureWithIssuer(ACert, AIssuer: ISSLCertificate;
  out AError: string): Boolean;
var
  LCertParser: TX509Certificate;
  LIssuerParser: TX509Certificate;
  LScheme: Word;
begin
  Result := False;
  AError := '';

  if (ACert = nil) or (AIssuer = nil) then
  begin
    AError := 'Certificate signature verification requires both certificate and issuer';
    Exit;
  end;

  if NormalizeWolfCertText(ACert.GetIssuer) <>
    NormalizeWolfCertText(AIssuer.GetSubject) then
  begin
    AError := 'Certificate issuer does not match issuer subject';
    Exit;
  end;

  if not TryLoadParsedCertificateFromInterface(ACert, LCertParser, AError) then
    Exit;
  try
    if not TryLoadParsedCertificateFromInterface(AIssuer, LIssuerParser, AError) then
      Exit;
    try
      if Length(LCertParser.RawTBSCertificate) = 0 then
      begin
        AError := 'Certificate TBS payload is unavailable';
        Exit;
      end;

      if Length(LCertParser.Signature) = 0 then
      begin
        AError := 'Certificate signature payload is unavailable';
        Exit;
      end;

      if not TryMapCertificateSignatureScheme(
        LCertParser.SignatureAlgorithm.OID,
        LIssuerParser.PublicKeyInfo,
        LScheme,
        AError
      ) then
        Exit;

      Result := TryVerifyTLS13CertificateVerifySignature(
        LScheme,
        LIssuerParser.PublicKeyInfo,
        LCertParser.RawTBSCertificate,
        LCertParser.Signature,
        AError
      );
    finally
    end;
  finally
  end;
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

{ TWolfSSLCertificate }

constructor TWolfSSLCertificate.Create;
begin
  inherited Create;
  FX509 := nil;
  FPEMData := '';
  SetLength(FDERData, 0);
  FIssuerCert := nil;
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;
end;

constructor TWolfSSLCertificate.Create(AX509: PWOLFSSL_X509);
begin
  Create;
  FX509 := AX509;
end;

destructor TWolfSSLCertificate.Destroy;
begin
  if FX509 <> nil then
  begin
    if Assigned(wolfSSL_X509_free) then
      wolfSSL_X509_free(FX509);
    FX509 := nil;
  end;
  FIssuerCert := nil;
  inherited Destroy;
end;

procedure TWolfSSLCertificate.ResetLoadedState;
begin
  FPEMData := '';
  SetLength(FDERData, 0);
  FIssuerCert := nil;
  Finalize(FInfo);
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;

  if FX509 <> nil then
  begin
    if Assigned(wolfSSL_X509_free) then
      wolfSSL_X509_free(FX509);
    FX509 := nil;
  end;
end;

function TWolfSSLCertificate.TryLoadX509Parser(
  out AParser: TX509Certificate): Boolean;
var
  LDER: TBytes;
begin
  AParser := nil;
  Result := False;

  if FX509 = nil then
    Exit;

  AParser := TX509Certificate.Create;
  try
    if Length(FDERData) > 0 then
      AParser.LoadFromDER(FDERData)
    else if FPEMData <> '' then
      AParser.LoadFromPEM(FPEMData)
    else
    begin
      LDER := SaveToDER;
      if Length(LDER) = 0 then
        Exit;
      AParser.LoadFromDER(LDER);
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function TWolfSSLCertificate.TryGetParsedAlgorithmMetadata(
  out APublicKeyAlgorithm, ASignatureAlgorithm: string): Boolean;
var
  LParser: TX509Certificate;
begin
  APublicKeyAlgorithm := '';
  ASignatureAlgorithm := '';
  Result := False;

  if not TryLoadX509Parser(LParser) then
    Exit;

  try
    APublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.Name;
    if APublicKeyAlgorithm = '' then
      APublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.OID;

    ASignatureAlgorithm := LParser.SignatureAlgorithm.Name;
    if ASignatureAlgorithm = '' then
      ASignatureAlgorithm := LParser.SignatureAlgorithm.OID;

    Result := (APublicKeyAlgorithm <> '') or (ASignatureAlgorithm <> '');
  finally
  end;
end;

function TWolfSSLCertificate.LoadNativeFromDER(const ADER: TBytes): Boolean;
var
  LX509: PWOLFSSL_X509;
  LParser: TX509Certificate;
begin
  Result := False;
  if Length(ADER) = 0 then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      LParser.LoadFromDER(ADER);
    except
      Exit;
    end;
  finally
  end;

  if not Assigned(wolfSSL_X509_d2i) then
    Exit;

  LX509 := wolfSSL_X509_d2i(nil, @ADER[0], Length(ADER));
  if LX509 = nil then
    Exit;

  if FX509 <> nil then
  begin
    if Assigned(wolfSSL_X509_free) then
      wolfSSL_X509_free(FX509);
  end;

  FX509 := LX509;
  FDERData := Copy(ADER);
  FPEMData := TSSLUtils.DERToPEM(FDERData);
  Result := True;
end;

function TWolfSSLCertificate.LoadFromFile(const AFileName: string): Boolean;
var
  LRawBytes: TBytes;
  LText: string;
  LStream: IStream;
begin
  Result := False;
  if not nextpas.core.fs.IsFile(AFileName) then Exit;
  ResetLoadedState;

  SetLength(LRawBytes, 0);
  LStream := FsOpen(AFileName, [fmRead]);
  try
    if LStream.Size > 0 then
    begin
      SetLength(LRawBytes, LStream.Size);
      LStream.Read(LRawBytes[0], Length(LRawBytes));
    end;
  finally
  end;

  if Length(LRawBytes) > 0 then
  begin
    SetString(LText, PAnsiChar(@LRawBytes[0]), Length(LRawBytes));
    if TSSLUtils.IsPEMFormat(LText) then
    begin
      try
        FDERData := TSSLUtils.PEMToDER(LText);
        FPEMData := LText;
      except
        Exit(False);
      end;
    end
    else
    begin
      FDERData := Copy(LRawBytes);
      FPEMData := TSSLUtils.DERToPEM(FDERData);
    end;
  end;

  if not Assigned(wolfSSL_X509_load_certificate_file) then Exit;

  if FX509 <> nil then
  begin
    if Assigned(wolfSSL_X509_free) then
      wolfSSL_X509_free(FX509);
    FX509 := nil;
  end;

  FX509 := wolfSSL_X509_load_certificate_file(PAnsiChar(AnsiString(AFileName)),
    WOLFSSL_FILETYPE_PEM);
  if FX509 = nil then
    FX509 := wolfSSL_X509_load_certificate_file(PAnsiChar(AnsiString(AFileName)),
      WOLFSSL_FILETYPE_ASN1);

  Result := FX509 <> nil;
end;

function TWolfSSLCertificate.LoadFromStream(AStream: IStream): Boolean;
var
  LData: TBytes;
  LText: string;
begin
  Result := False;
  ResetLoadedState;
  if AStream = nil then Exit;

  SetLength(LData, AStream.Size - AStream.Position);
  if Length(LData) = 0 then Exit;

  AStream.Read(LData[0], Length(LData));
  SetString(LText, PAnsiChar(@LData[0]), Length(LData));
  if TSSLUtils.IsPEMFormat(LText) then
    Result := LoadFromPEM(LText)
  else
    Result := LoadFromDER(LData);
end;

function TWolfSSLCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
var
  LRaw: TBytes;
  LText: string;
begin
  Result := False;
  ResetLoadedState;
  if (AData = nil) or (ASize <= 0) then Exit;
  SetLength(LRaw, ASize);
  Move(AData^, LRaw[0], ASize);

  SetString(LText, PAnsiChar(@LRaw[0]), Length(LRaw));
  if TSSLUtils.IsPEMFormat(LText) then
    Result := LoadFromPEM(LText)
  else
    Result := LoadFromDER(LRaw);
end;

function TWolfSSLCertificate.LoadFromPEM(const APEM: string): Boolean;
var
  LDER: TBytes;
begin
  Result := False;
  ResetLoadedState;
  if APEM = '' then Exit;

  if not TSSLUtils.IsPEMFormat(APEM) then
    Exit;

  try
    LDER := TSSLUtils.PEMToDER(APEM);
  except
    Exit(False);
  end;
  if Length(LDER) = 0 then
    Exit;

  Result := LoadFromDER(LDER);

  if Result then
    FPEMData := APEM;
end;

function TWolfSSLCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  Result := False;
  ResetLoadedState;
  if Length(ADER) = 0 then Exit;

  Result := LoadNativeFromDER(ADER);
end;

function TWolfSSLCertificate.SaveToFile(const AFileName: string): Boolean;
var
  LStream: IStream;
begin
  Result := False;
  if FX509 = nil then Exit;

  try
    LStream := FsCreate(AFileName);
    try
      Result := SaveToStream(LStream);
    finally
    end;
  except
    Result := False;
  end;
end;

function TWolfSSLCertificate.SaveToStream(AStream: IStream): Boolean;
var
  LPEM: string;
begin
  Result := False;
  if (AStream = nil) or (FX509 = nil) then Exit;

  LPEM := SaveToPEM;
  if LPEM <> '' then
  begin
    AStream.Write(LPEM[1], Length(LPEM));
    Result := True;
  end;
end;

function TWolfSSLCertificate.SaveToPEM: string;
begin
  Result := FPEMData;
  if (Result = '') and (Length(FDERData) > 0) then
    Result := TSSLUtils.DERToPEM(FDERData);
end;

function TWolfSSLCertificate.SaveToDER: TBytes;
var
  LDERLen: Integer;
  LDERPtr: PByte;
begin
  Result := Copy(FDERData);
  if (Length(Result) = 0) and (FX509 <> nil) and Assigned(wolfSSL_i2d_X509) then
  begin
    LDERLen := wolfSSL_i2d_X509(FX509, nil);
    if LDERLen > 0 then
    begin
      SetLength(Result, LDERLen);
      LDERPtr := @Result[0];
      if wolfSSL_i2d_X509(FX509, @LDERPtr) = LDERLen then
        FDERData := Copy(Result)
      else
        SetLength(Result, 0);
    end;
  end;

  if (Length(Result) = 0) and (FPEMData <> '') then
    Result := TSSLUtils.PEMToDER(FPEMData);
end;

function TWolfSSLCertificate.GetInfo: TSSLCertificateInfo;
var
  LParser: TX509Certificate;
begin
  Result := FInfo;
  Result.Subject := GetSubject;
  Result.Issuer := GetIssuer;
  Result.SerialNumber := GetSerialNumber;
  Result.NotBefore := GetNotBefore;
  Result.NotAfter := GetNotAfter;
  Result.Version := GetVersion;

  if TryLoadX509Parser(LParser) then
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
    end;
  end
  else
  begin
    Result.PublicKeyAlgorithm := GetPublicKeyAlgorithm;
    Result.SignatureAlgorithm := GetSignatureAlgorithm;
  end;
end;

function TWolfSSLCertificate.GetSubject: string;
var
  LParser: TX509Certificate;
  LBuf: array[0..511] of AnsiChar;
  LName: Pointer;
begin
  Result := '';
  if FX509 = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Subject.ToString;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if Assigned(wolfSSL_X509_get_subject_name) and Assigned(wolfSSL_X509_NAME_oneline) then
  begin
    LName := wolfSSL_X509_get_subject_name(FX509);
    if LName <> nil then
    begin
      FillChar(LBuf, SizeOf(LBuf), 0);
      wolfSSL_X509_NAME_oneline(LName, @LBuf[0], SizeOf(LBuf) - 1);
      Result := string(PAnsiChar(@LBuf[0]));
    end;
  end;

  if Result = '' then
    Result := 'Subject';  // 占位符
end;

function TWolfSSLCertificate.GetIssuer: string;
var
  LParser: TX509Certificate;
  LBuf: array[0..511] of AnsiChar;
  LName: Pointer;
begin
  Result := '';
  if FX509 = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Issuer.ToString;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if Assigned(wolfSSL_X509_get_issuer_name) and Assigned(wolfSSL_X509_NAME_oneline) then
  begin
    LName := wolfSSL_X509_get_issuer_name(FX509);
    if LName <> nil then
    begin
      FillChar(LBuf, SizeOf(LBuf), 0);
      wolfSSL_X509_NAME_oneline(LName, @LBuf[0], SizeOf(LBuf) - 1);
      Result := string(PAnsiChar(@LBuf[0]));
    end;
  end;

  if Result = '' then
    Result := 'Issuer';  // 占位符
end;

function TWolfSSLCertificate.GetSerialNumber: string;
var
  LParser: TX509Certificate;
begin
  Result := '';
  if FX509 = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.SerialNumberAsHex;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if Result = '' then
    Result := '0';
end;

function TWolfSSLCertificate.GetNotBefore: TDateTime;
var
  LParser: TX509Certificate;
begin
  Result := 0;
  if FPEMData = '' then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      LParser.LoadFromPEM(FPEMData);
      Result := LParser.Validity.NotBefore;
    except
      Result := 0;
    end;
  finally
  end;
end;

function TWolfSSLCertificate.GetNotAfter: TDateTime;
var
  LParser: TX509Certificate;
begin
  Result := 0;
  if FPEMData = '' then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      LParser.LoadFromPEM(FPEMData);
      Result := LParser.Validity.NotAfter;
    except
      Result := 0;
    end;
  finally
  end;
end;

function TWolfSSLCertificate.GetPublicKey: string;
begin
  Result := GetPublicKeyAlgorithm;
end;

function TWolfSSLCertificate.GetPublicKeyAlgorithm: string;
var
  LSignatureAlgorithm: string;
begin
  if TryGetParsedAlgorithmMetadata(Result, LSignatureAlgorithm) and (Result <> '') then
    Exit;

  Result := 'RSA';  // 默认
end;

function TWolfSSLCertificate.GetSignatureAlgorithm: string;
var
  LPublicKeyAlgorithm: string;
begin
  if TryGetParsedAlgorithmMetadata(LPublicKeyAlgorithm, Result) and (Result <> '') then
    Exit;

  Result := 'SHA256withRSA';  // 默认
end;

function TWolfSSLCertificate.GetVersion: Integer;
begin
  Result := 3;  // X.509 v3 默认值
  if FX509 = nil then Exit;

  if Assigned(wolfSSL_X509_get_version) then
    Result := wolfSSL_X509_get_version(FX509) + 1;  // WolfSSL 返回 0-based
end;

function TWolfSSLCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
var
  LVerifyResult: TSSLCertVerifyResult;
begin
  Result := VerifyEx(ACAStore, [], LVerifyResult);
end;

function TWolfSSLCertificate.VerifyEx(ACAStore: ISSLCertificateStore;
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
var
  LChain: TSSLCertificateArray;
  LCurrent: ISSLCertificate;
  LCurrentTime: TDateTime;
  LRoot: ISSLCertificate;
  LSignatureError: string;
  LNotBefore: TDateTime;
  LNotAfter: TDateTime;
  LKeyUsage: TSSLStringArray;
  I: Integer;
begin
  ResetCertVerifyResult(AResult);
  Result := False;

  if FX509 = nil then
  begin
    AResult.ErrorCode := 1;
    AResult.ErrorMessage := 'Certificate not loaded';
    AResult.DetailedInfo := 'WolfSSL VerifyEx requires a loaded certificate';
    Exit;
  end;

  if ACAStore = nil then
  begin
    AResult.ErrorCode := 2;
    AResult.ErrorMessage := 'Certificate store is not configured';
    AResult.DetailedInfo := 'WolfSSL VerifyEx requires a configured certificate store';
    Exit;
  end;

  LChain := ACAStore.BuildCertificateChain(Self);
  if Length(LChain) = 0 then
  begin
    AResult.ErrorCode := 3;
    AResult.ChainStatus := 1;
    AResult.ErrorMessage := 'Certificate chain could not be built';
    AResult.DetailedInfo := 'WolfSSL VerifyEx could not construct a certificate chain from the configured store';
    Exit;
  end;

  if not (sslCertVerifyIgnoreExpiry in AFlags) then
    LCurrentTime := DateTimeUtcNow;

  for I := 0 to High(LChain) do
  begin
    LCurrent := LChain[I];
    if LCurrent = nil then
    begin
      AResult.ErrorCode := 4;
      AResult.ChainStatus := 1;
      AResult.ErrorMessage := 'Certificate chain contains a nil entry';
      AResult.DetailedInfo := nextpas.core.text.conv.Format('WolfSSL VerifyEx encountered a nil chain entry at index %d', [I]);
      Exit;
    end;

    if not (sslCertVerifyIgnoreExpiry in AFlags) then
    begin
      LNotBefore := LCurrent.GetNotBefore;
      LNotAfter := LCurrent.GetNotAfter;
      if (LNotBefore <= 0) or (LNotAfter <= 0) then
      begin
        AResult.ErrorCode := 5;
        AResult.ChainStatus := 1;
        AResult.ErrorMessage := 'Certificate validity window is unavailable';
        AResult.DetailedInfo := nextpas.core.text.conv.Format('WolfSSL VerifyEx requires validity metadata for chain entry %d', [I]);
        Exit;
      end;
      if LCurrentTime < LNotBefore then
      begin
        AResult.ErrorCode := 6;
        AResult.ChainStatus := 1;
        AResult.ErrorMessage := 'Certificate is not yet valid';
        AResult.DetailedInfo := nextpas.core.text.conv.Format('WolfSSL VerifyEx rejected chain entry %d because notBefore is in the future', [I]);
        Exit;
      end;
      if LCurrentTime > LNotAfter then
      begin
        AResult.ErrorCode := 7;
        AResult.ChainStatus := 1;
        AResult.ErrorMessage := 'Certificate is expired';
        AResult.DetailedInfo := nextpas.core.text.conv.Format('WolfSSL VerifyEx rejected chain entry %d because notAfter is in the past', [I]);
        Exit;
      end;
    end;
  end;

  for I := 0 to High(LChain) - 1 do
  begin
    if not TryVerifyCertificateSignatureWithIssuer(LChain[I], LChain[I + 1], LSignatureError) then
    begin
      AResult.ErrorCode := 8;
      AResult.ChainStatus := 1;
      AResult.ErrorMessage := 'Certificate signature verification failed';
      AResult.DetailedInfo := LSignatureError;
      Exit;
    end;
  end;

  LRoot := LChain[High(LChain)];
  if ((LRoot = nil) or not ACAStore.Contains(LRoot)) and
    (not ((sslCertVerifyAllowSelfSigned in AFlags) and (LRoot <> nil) and LRoot.IsSelfSigned)) then
  begin
    AResult.ErrorCode := 9;
    AResult.ChainStatus := 1;
    AResult.ErrorMessage := 'Certificate chain does not terminate at a trusted root';
    AResult.DetailedInfo := 'WolfSSL VerifyEx requires the final chain certificate to be present in the configured store unless self-signed certificates are explicitly allowed';
    Exit;
  end;

  if sslCertVerifyStrictChain in AFlags then
  begin
    LKeyUsage := GetExtendedKeyUsage;
    if not HasServerAuthUsage(LKeyUsage) then
    begin
      AResult.ErrorCode := 10;
      AResult.ChainStatus := 2;
      AResult.ErrorMessage := 'Strict chain verification requires serverAuth extended key usage';
      AResult.DetailedInfo := 'sslCertVerifyStrictChain requested but the leaf certificate is missing serverAuth extended key usage';
      Exit;
    end;
  end;

  if (sslCertVerifyCheckRevocation in AFlags) or
    (sslCertVerifyCheckCRL in AFlags) or
    (sslCertVerifyCheckOCSP in AFlags) then
  begin
    AResult.ErrorCode := 11;
    AResult.RevocationStatus := 2;
    AResult.ErrorMessage := 'Certificate revocation verification is unavailable';
    AResult.DetailedInfo :=
      'WolfSSL VerifyEx has no OCSP/CRL revocation material for sslCertVerifyCheckRevocation/sslCertVerifyCheckCRL/sslCertVerifyCheckOCSP';
    Exit;
  end;

  Result := True;
  AResult.Success := True;
  AResult.DetailedInfo := 'WolfSSL certificate chain verification passed';
end;

function TWolfSSLCertificate.VerifyHostname(const AHostname: string): Boolean;
var
  SANs: TSSLStringArray;
  i: Integer;
  CN, Entry: string;
  HostIsIP, EntryIsIP: Boolean;
  HasRelevantSAN: Boolean;

  function MatchWildcard(const APattern, AHostname: string): Boolean;
  var
    PatternParts, HostParts: TStringArray;
    j: Integer;
  begin
    Result := False;

    // Exact match
    if SameText(APattern, AHostname) then
    begin
      Result := True;
      Exit;
    end;

    // Wildcard match (*.example.com)
    if (Pos('*.', APattern) = 1) then
    begin
      try

        // Same label count
        if Length(PatternParts) = Length(HostParts) then
        begin
          Result := True;
          // Compare from 2nd label (skip wildcard)
          for j := 1 to Length(PatternParts) - 1 do
          begin
            if not SameText(PatternParts[j], HostParts[j]) then
            begin
              Result := False;
              Break;
            end;
          end;
        end;
      finally
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

  if (FX509 = nil) or (AHostname = '') then
    Exit;

  HostIsIP := TSSLUtils.IsIPAddress(AHostname);
  HasRelevantSAN := False;

  // First check SAN entries. CN fallback is only allowed when the certificate
  // has no SAN entry of the relevant type for the requested host.
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

    // Only match hostnames (ignore IP/email/URI etc)
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

  // Fallback to CN
  CN := Trim(GetSubjectCN);
  if CN = '' then
    Exit;

  if HostIsIP then
  begin
    Result := SameText(CN, AHostname);
    Exit;
  end;

  if not TSSLUtils.IsValidHostname(CN) then
    Exit;

  Result := MatchWildcard(CN, AHostname);
end;

function TWolfSSLCertificate.IsExpired: Boolean;
var
  LNotAfter: TDateTime;
begin
  LNotAfter := GetNotAfter;
  if LNotAfter <= 0 then
  begin
    Result := False;
    Exit;
  end;

  Result := DateTimeUtcNow > LNotAfter;
end;

function TWolfSSLCertificate.IsSelfSigned: Boolean;
begin
  Result := GetSubject = GetIssuer;
end;

function TWolfSSLCertificate.IsCA: Boolean;
var
  LParser: TX509Certificate;
begin
  Result := False;
  if not TryLoadX509Parser(LParser) then
    Exit;

  try
    Result := LParser.IsCA;
  finally
  end;
end;

function TWolfSSLCertificate.GetDaysUntilExpiry: Integer;
var
  LNotAfter: TDateTime;
begin
  LNotAfter := GetNotAfter;
  if LNotAfter <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  Result := DaysBetween(nextpas.core.time.DateTimeNow, LNotAfter);
  if IsExpired then
    Result := -Result;
end;

function TWolfSSLCertificate.GetSubjectCN: string;
var
  LSubject: string;
  LPos: Integer;
begin
  Result := '';
  LSubject := GetSubject;
  LPos := Pos('CN=', LSubject);
  if LPos > 0 then
  begin
    Result := Copy(LSubject, LPos + 3, Length(LSubject));
    LPos := Pos(',', Result);
    if LPos > 0 then
      Result := Copy(Result, 1, LPos - 1);
  end;
end;

function TWolfSSLCertificate.GetExtension(const AOID: string): string;
var
  LParser: TX509Certificate;
  LTargetOID: string;
  I: Integer;
begin
  Result := '';
  LTargetOID := Trim(AOID);
  if LTargetOID = '' then
    Exit;

  if not TryLoadX509Parser(LParser) then
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
  end;
end;

function TWolfSSLCertificate.GetSubjectAltNames: TSSLStringArray;
var
  LParser: TX509Certificate;
begin
  SetLength(Result, 0);
  if not TryLoadX509Parser(LParser) then
    Exit;

  try
    Result := X509SubjectAltNamesToStrings(LParser.SubjectAltNames);
  finally
  end;
end;

function TWolfSSLCertificate.GetKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
begin
  SetLength(Result, 0);
  if not TryLoadX509Parser(LParser) then
    Exit;

  try
    Result := X509KeyUsageToStrings(LParser.KeyUsage);
  finally
  end;
end;

function TWolfSSLCertificate.GetExtendedKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
begin
  SetLength(Result, 0);
  if not TryLoadX509Parser(LParser) then
    Exit;

  try
    Result := X509ExtKeyUsageToStrings(LParser.ExtKeyUsage);
  finally
  end;
end;

function TWolfSSLCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  Result := '';
  case AHashType of
    sslHashSHA1: Result := GetFingerprintSHA1;
    sslHashSHA256: Result := GetFingerprintSHA256;
  else
    Result := '';
  end;
end;

function TWolfSSLCertificate.GetFingerprintSHA1: string;
var
  LDER: TBytes;
begin
  LDER := SaveToDER;
  if Length(LDER) = 0 then
  begin
    Result := '';
    Exit;
  end;

  Result := HashToHex(SHA1(LDER));
end;

function TWolfSSLCertificate.GetFingerprintSHA256: string;
var
  LDER: TBytes;
begin
  LDER := SaveToDER;
  if Length(LDER) = 0 then
  begin
    Result := '';
    Exit;
  end;

  Result := HashToHex(SHA256(LDER));
end;

procedure TWolfSSLCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCert := ACert;
end;

function TWolfSSLCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCert;
end;

function TWolfSSLCertificate.GetNativeHandle: Pointer;
begin
  Result := FX509;
end;

function TWolfSSLCertificate.GetBackendType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLCertificate.IsNativeHandleValid: Boolean;
begin
  Result := (FX509 <> nil);
end;

function TWolfSSLCertificate.Clone: ISSLCertificate;
var
  LClone: TWolfSSLCertificate;
  LDER: TBytes;
begin
  Result := nil;
  LClone := TWolfSSLCertificate.Create;
  try
    LClone.FInfo := FInfo;
    if Length(FDERData) > 0 then
      LDER := Copy(FDERData)
    else if FPEMData <> '' then
      LDER := TSSLUtils.PEMToDER(FPEMData)
    else
      LDER := SaveToDER;

    if Length(LDER) > 0 then
    begin
      if not LClone.LoadFromDER(LDER) then
        Exit;
      LClone.FDERData := Copy(LDER);
      if FPEMData <> '' then
        LClone.FPEMData := FPEMData
      else
        LClone.FPEMData := TSSLUtils.DERToPEM(LDER);
    end
    else
    begin
      LClone.FPEMData := FPEMData;
      LClone.FDERData := Copy(FDERData);
    end;

    LClone.FIssuerCert := FIssuerCert;
    Result := LClone;
    LClone := nil;
  finally
  end;
end;

{ TWolfSSLCertificateStore }

constructor TWolfSSLCertificateStore.Create;
begin
  inherited Create;
  if Assigned(wolfSSL_X509_STORE_new) then
    FX509Store := wolfSSL_X509_STORE_new()
  else
    FX509Store := nil;
  FCertificates := specialize TVec<IInterface>.Create;
end;

destructor TWolfSSLCertificateStore.Destroy;
begin
  Clear;
  if FX509Store <> nil then
  begin
    if Assigned(wolfSSL_X509_STORE_free) then
      wolfSSL_X509_STORE_free(FX509Store);
    FX509Store := nil;
  end;
  inherited Destroy;
end;

function TWolfSSLCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := False;
  if ACert = nil then Exit;
  if Contains(ACert) then Exit;

  FCertificates.Push(ACert);
  Result := True;
end;

function TWolfSSLCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
var
  LIndex: Integer;
  LTarget: string;
  I: Integer;
  LExisting: ISSLCertificate;
begin
  Result := False;
  if ACert = nil then Exit;

  LIndex := FCertificates.Find(ACert);
  if LIndex < 0 then
  begin
    LTarget := NormalizeWolfCertFingerprint(ACert.GetFingerprintSHA256);
    if LTarget = '' then
      LTarget := NormalizeWolfCertFingerprint(ACert.GetFingerprintSHA1);

    if LTarget <> '' then
    begin
      for I := 0 to FCertificates.GetCount - 1 do
      begin
        LExisting := FCertificates.Get(I) as ISSLCertificate;
        if NormalizeWolfCertFingerprint(LExisting.GetFingerprintSHA256) = LTarget then
        begin
          LIndex := I;
          Break;
        end;
      end;
    end;
  end;

  if LIndex >= 0 then
  begin
    FCertificates.Delete(LIndex);
    Result := True;
  end;
end;

function TWolfSSLCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
var
  LTarget: string;
  I: Integer;
  LExisting: ISSLCertificate;
begin
  Result := False;
  if ACert = nil then
    Exit;

  if FCertificates.Find(ACert) >= 0 then
    Exit(True);

  LTarget := NormalizeWolfCertFingerprint(ACert.GetFingerprintSHA256);
  if LTarget = '' then
    LTarget := NormalizeWolfCertFingerprint(ACert.GetFingerprintSHA1);
  if LTarget = '' then
    Exit(False);

  for I := 0 to FCertificates.GetCount - 1 do
  begin
    LExisting := FCertificates.Get(I) as ISSLCertificate;
    if NormalizeWolfCertFingerprint(LExisting.GetFingerprintSHA256) = LTarget then
      Exit(True);
  end;
end;

procedure TWolfSSLCertificateStore.Clear;
begin
  FCertificates.Clear;
end;

function TWolfSSLCertificateStore.GetCount: Integer;
begin
  Result := FCertificates.GetCount;
end;

function TWolfSSLCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FCertificates.GetCount) then
    Result := FCertificates.Get(AIndex) as ISSLCertificate;
end;

function TWolfSSLCertificateStore.LoadFromFile(const AFileName: string): Boolean;
var
  LCert: TWolfSSLCertificate;
begin
  Result := False;
  if not nextpas.core.fs.IsFile(AFileName) then Exit;

  LCert := TWolfSSLCertificate.Create;
  try
    if LCert.LoadFromFile(AFileName) then
    begin
      FCertificates.Push(LCert);
      Result := True;
    end;
  except
    raise;
  end;
end;

function TWolfSSLCertificateStore.LoadFromPath(const APath: string): Boolean;
var
  LSearchRec: TSearchRec;
  LCount: Integer;
begin
  Result := False;
  if not nextpas.core.fs.IsDir(APath) then Exit;

  LCount := 0;
  if FindFirst(nextpas.core.fs.PathEnsureSep(APath) + '*.pem', faAnyFile, LSearchRec) = 0 then
  begin
    try
      repeat
        if LoadFromFile(nextpas.core.fs.PathEnsureSep(APath) + LSearchRec.Name) then
          Inc(LCount);
      until FindNext(LSearchRec) <> 0;
    finally
      FindClose(LSearchRec);
    end;
  end;

  // 也加载 .crt 文件
  if FindFirst(nextpas.core.fs.PathEnsureSep(APath) + '*.crt', faAnyFile, LSearchRec) = 0 then
  begin
    try
      repeat
        if LoadFromFile(nextpas.core.fs.PathEnsureSep(APath) + LSearchRec.Name) then
          Inc(LCount);
      until FindNext(LSearchRec) <> 0;
    finally
      FindClose(LSearchRec);
    end;
  end;

  Result := LCount > 0;
end;

function TWolfSSLCertificateStore.LoadSystemStore: Boolean;
begin
  Result := False;
  {$IFDEF LINUX}
  // Linux 系统 CA 路径
  if nextpas.core.fs.IsDir('/etc/ssl/certs') then
    Result := LoadFromPath('/etc/ssl/certs')
  else if nextpas.core.fs.IsDir('/etc/pki/tls/certs') then
    Result := LoadFromPath('/etc/pki/tls/certs');
  {$ENDIF}
  {$IFDEF DARWIN}
  // macOS 系统 CA
  if nextpas.core.fs.IsFile('/etc/ssl/cert.pem') then
    Result := LoadFromFile('/etc/ssl/cert.pem');
  {$ENDIF}
end;

function TWolfSSLCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeWolfCertText(ASubject);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.GetCount - 1 do
  begin
    LCert := FCertificates.Get(I) as ISSLCertificate;
    if Pos(LTarget, NormalizeWolfCertText(LCert.GetSubject)) > 0 then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TWolfSSLCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeWolfCertText(AIssuer);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.GetCount - 1 do
  begin
    LCert := FCertificates.Get(I) as ISSLCertificate;
    if Pos(LTarget, NormalizeWolfCertText(LCert.GetIssuer)) > 0 then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TWolfSSLCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeWolfCertSerial(ASerialNumber);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.GetCount - 1 do
  begin
    LCert := FCertificates.Get(I) as ISSLCertificate;
    if NormalizeWolfCertSerial(LCert.GetSerialNumber) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TWolfSSLCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeWolfCertFingerprint(AFingerprint);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.GetCount - 1 do
  begin
    LCert := FCertificates.Get(I) as ISSLCertificate;
    if NormalizeWolfCertFingerprint(LCert.GetFingerprintSHA256) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;

    if NormalizeWolfCertFingerprint(LCert.GetFingerprintSHA1) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TWolfSSLCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := False;
  if ACert = nil then Exit;
  Result := ACert.Verify(Self);
end;

function TWolfSSLCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
var
  LChain: array of ISSLCertificate;
  LCurrent: ISSLCertificate;
  LNext: ISSLCertificate;
  LIssuer: ISSLCertificate;
  LMaxDepth: Integer;
  I: Integer;
  LExists: Boolean;
begin
  SetLength(Result, 0);
  if ACert = nil then Exit;

  SetLength(LChain, 0);
  LCurrent := ACert;
  LMaxDepth := 10;  // 防止无限循环

  while (LCurrent <> nil) and (Length(LChain) < LMaxDepth) do
  begin
    SetLength(LChain, Length(LChain) + 1);
    LChain[High(LChain)] := LCurrent;

    // 自签名证书是链的终点
    if LCurrent.IsSelfSigned then
      Break;

    // 查找颁发者
    LNext := LCurrent.GetIssuerCertificate;
    if LNext = nil then
      LNext := FindBySubject(LCurrent.GetIssuer);

    if LNext = nil then
      Break;

    LExists := False;
    for I := 0 to High(LChain) do
    begin
      if LChain[I] = LNext then
      begin
        LExists := True;
        Break;
      end;

      if NormalizeWolfCertFingerprint(LChain[I].GetFingerprintSHA256) =
        NormalizeWolfCertFingerprint(LNext.GetFingerprintSHA256) then
      begin
        LExists := True;
        Break;
      end;
    end;
    if LExists then
      Break;

    LIssuer := LNext;
    LCurrent := LIssuer;
  end;

  Result := LChain;
end;

function TWolfSSLCertificateStore.GetNativeHandle: Pointer;
begin
  Result := FX509Store;
end;

function TWolfSSLCertificateStore.GetBackendType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLCertificateStore.IsNativeHandleValid: Boolean;
begin
  Result := (FX509Store <> nil);
end;

end.
