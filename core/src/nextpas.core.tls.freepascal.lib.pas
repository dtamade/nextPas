{**
 * Unit: nextpas.core.tls.freepascal.lib
 * Purpose: 纯 FreePascal 后端库管理实现
 *}

unit nextpas.core.tls.freepascal.lib;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.tls.base;

type
  TFreePascalSSLLibrary = class(TInterfacedObject, ISSLLibrary)
  private
    FInitialized: Boolean;
    FDefaultConfig: TSSLConfig;
    FStatistics: TSSLStatistics;
    FLastError: Integer;
    FLastErrorString: string;
    FLogCallback: TSSLLogCallback;
    FLogLevel: TSSLLogLevel;
    FCapabilitiesCache: TSSLBackendCapabilities;
    FCapabilitiesCached: Boolean;

    procedure InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure InvalidateCapabilitiesCache;
  public
    constructor Create;

    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;

    function GetLibraryType: TSSLLibraryType;
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;

    function IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const ACipherName: string): Boolean;
    function IsFeatureSupported(AFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;

    procedure SetDefaultConfig(const AConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;

    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;

    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;

    procedure SetLogCallback(ACallback: TSSLLogCallback);
    procedure Log(ALevel: TSSLLogLevel; const AMessage: string);

    function CreateContext(AType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;
  end;

function CreateFreePascalSSLLibrary: ISSLLibrary;

procedure RegisterFreePascalBackend;
procedure UnregisterFreePascalBackend;

implementation

uses
  Classes,
  nextpas.core.io.stream_adapter,
  nextpas.core.io.util,
  nextpas.core.time,
  nextpas.core.tls.context.config,
  nextpas.core.tls.exceptions,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.aesni,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.context,
  nextpas.core.tls.utils,
  nextpas.core.tls.x509,
  nextpas.core.crypto.x509verify;

const
  CSystemStorePaths: array[0..4] of string = (
    '/etc/ssl/certs',
    '/etc/pki/tls/certs',
    '/etc/pki/ca-trust/extracted/pem',
    '/usr/local/share/certs',
    '/system/etc/security/cacerts'
  );

function HasSystemCertStoreDirectories: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(CSystemStorePaths) to High(CSystemStorePaths) do
  begin
    if DirectoryExists(CSystemStorePaths[I]) then
      Exit(True);
  end;
end;

type
  TFreePascalCertificate = class(TInterfacedObject, ISSLCertificate)
  private
    FDERData: TBytes;
    FPEMData: string;
    FInfo: TSSLCertificateInfo;
    FIssuerCert: ISSLCertificate;
    function ReadAllBytes(AStream: TStream): TBytes;
    function HexNormalize(const AValue: string): string;
    function CopyBytes(const AData: TBytes): TBytes;
    procedure RebuildInfo;
    function MatchHostname(const APattern, AHost: string): Boolean;
  public
    constructor Create;

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
  end;

  TFreePascalCertificateStore = class(TInterfacedObject, ISSLCertificateStore)
  private
    FCertificates: TInterfaceList;
    function NormalizeFingerprint(const AFingerprint: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;

    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean;

    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;

    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
  end;

{ TFreePascalCertificate }

constructor TFreePascalCertificate.Create;
begin
  inherited Create;
  SetLength(FDERData, 0);
  FPEMData := '';
  FillChar(FInfo, SizeOf(FInfo), 0);
  SetLength(FInfo.SubjectAltNames, 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;
  FIssuerCert := nil;
end;

function TFreePascalCertificate.ReadAllBytes(AStream: TStream): TBytes;
begin
  SetLength(Result, 0);
  if AStream = nil then
    Exit;
  Result := IoReadAll(WrapTStream(AStream, False));
end;

function TFreePascalCertificate.HexNormalize(const AValue: string): string;
begin
  Result := UpperCase(AValue);
  Result := StringReplace(Result, ':', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function TFreePascalCertificate.CopyBytes(const AData: TBytes): TBytes;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
end;

procedure TFreePascalCertificate.RebuildInfo;
var
  LParser: TX509Certificate;
  LSource: TBytes;
  LSANs: TX509SubjectAltNames;
  I: Integer;
begin
  FillChar(FInfo, SizeOf(FInfo), 0);
  SetLength(FInfo.SubjectAltNames, 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;

  if Length(FDERData) > 0 then
    LSource := CopyBytes(FDERData)
  else if FPEMData <> '' then
  begin
    SetLength(LSource, Length(FPEMData));
    if Length(LSource) > 0 then
      Move(FPEMData[1], LSource[0], Length(LSource));
  end
  else
    SetLength(LSource, 0);

  if Length(LSource) > 0 then
  begin
    FInfo.FingerprintSHA1 := HashToHex(SHA1(LSource));
    FInfo.FingerprintSHA256 := HashToHex(SHA256(LSource));
  end;

  if (Length(FDERData) = 0) and (FPEMData = '') then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      if Length(FDERData) > 0 then
        LParser.LoadFromDER(FDERData)
      else
        LParser.LoadFromPEM(FPEMData);

      FInfo.Subject := LParser.Subject.ToString;
      FInfo.Issuer := LParser.Issuer.ToString;
      FInfo.SerialNumber := LParser.SerialNumberAsHex;
      FInfo.NotBefore := LParser.Validity.NotBefore;
      FInfo.NotAfter := LParser.Validity.NotAfter;
      FInfo.PublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.Name;
      if FInfo.PublicKeyAlgorithm = '' then
        FInfo.PublicKeyAlgorithm := LParser.PublicKeyInfo.Algorithm.OID;
      FInfo.PublicKeySize := LParser.PublicKeyInfo.KeySize;
      FInfo.SignatureAlgorithm := LParser.SignatureAlgorithm.Name;
      if FInfo.SignatureAlgorithm = '' then
        FInfo.SignatureAlgorithm := LParser.SignatureAlgorithm.OID;
      FInfo.Version := Ord(LParser.Version) + 1;
      FInfo.IsCA := LParser.IsCA;
      FInfo.PathLenConstraint := LParser.BasicConstraints.PathLenConstraint;
      FInfo.PathLength := LParser.BasicConstraints.PathLenConstraint;
      FInfo.KeyUsage := 0;
      if kuDigitalSignature in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0080;
      if kuNonRepudiation in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0040;
      if kuKeyEncipherment in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0020;
      if kuDataEncipherment in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0010;
      if kuKeyAgreement in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0008;
      if kuKeyCertSign in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0004;
      if kuCRLSign in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0002;
      if kuEncipherOnly in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $0001;
      if kuDecipherOnly in LParser.KeyUsage then
        FInfo.KeyUsage := FInfo.KeyUsage or $8000;

      LSANs := LParser.SubjectAltNames;
      SetLength(FInfo.SubjectAltNames, Length(LSANs));
      for I := 0 to High(LSANs) do
        FInfo.SubjectAltNames[I] := LSANs[I].Value;
    except
      // 保持基础字段和指纹即可
    end;
  finally
    LParser.Free;
  end;
end;

function TFreePascalCertificate.MatchHostname(const APattern, AHost: string): Boolean;
var
  LPattern: string;
  LHost: string;
  LSuffix: string;
  LPrefix: string;
begin
  LPattern := LowerCase(Trim(APattern));
  LHost := LowerCase(Trim(AHost));

  if (LPattern = '') or (LHost = '') then
    Exit(False);

  if LPattern = LHost then
    Exit(True);

  if (Length(LPattern) > 2) and (Copy(LPattern, 1, 2) = '*.') then
  begin
    LSuffix := Copy(LPattern, 2, Length(LPattern) - 1);
    if (Length(LHost) <= Length(LSuffix)) or
      (Copy(LHost, Length(LHost) - Length(LSuffix) + 1, Length(LSuffix)) <> LSuffix) then
      Exit(False);

    LPrefix := Copy(LHost, 1, Length(LHost) - Length(LSuffix));
    Result := (LPrefix <> '') and (Pos('.', LPrefix) = 0);
    Exit;
  end;

  Result := False;
end;

function TFreePascalCertificate.LoadFromFile(const AFileName: string): Boolean;
var
  LStream: TFileStream;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(LStream);
  finally
    LStream.Free;
  end;
end;

function TFreePascalCertificate.LoadFromStream(AStream: TStream): Boolean;
var
  LRaw: TBytes;
  LText: string;
begin
  Result := False;
  if AStream = nil then
    Exit;

  LRaw := ReadAllBytes(AStream);
  if Length(LRaw) = 0 then
    Exit;

  SetString(LText, PAnsiChar(@LRaw[0]), Length(LRaw));
  if TSSLUtils.IsPEMFormat(LText) then
    Result := LoadFromPEM(LText)
  else
    Result := LoadFromDER(LRaw);
end;

function TFreePascalCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
var
  LRaw: TBytes;
  LText: string;
begin
  Result := False;
  if (AData = nil) or (ASize <= 0) then
    Exit;

  SetLength(LRaw, ASize);
  Move(AData^, LRaw[0], ASize);

  SetString(LText, PAnsiChar(@LRaw[0]), Length(LRaw));
  if TSSLUtils.IsPEMFormat(LText) then
    Result := LoadFromPEM(LText)
  else
    Result := LoadFromDER(LRaw);
end;

function TFreePascalCertificate.LoadFromPEM(const APEM: string): Boolean;
var
  LDER: TBytes;
  LCertificatePEM: string;
begin
  Result := False;
  if Trim(APEM) = '' then
    Exit;

  LCertificatePEM := TSSLUtils.ExtractPEMBlock(APEM, 'CERTIFICATE');
  if Trim(LCertificatePEM) = '' then
  begin
    SetLength(FDERData, 0);
    FPEMData := '';
    RebuildInfo;
    Exit(False);
  end;

  try
    LDER := TSSLUtils.PEMToDER(LCertificatePEM);
  except
    SetLength(FDERData, 0);
    FPEMData := '';
    RebuildInfo;
    Exit(False);
  end;

  if Length(LDER) = 0 then
  begin
    SetLength(FDERData, 0);
    FPEMData := '';
    RebuildInfo;
    Exit(False);
  end;

  if not LoadFromDER(LDER) then
    Exit(False);

  FPEMData := LCertificatePEM;
  Result := True;
end;

function TFreePascalCertificate.LoadFromDER(const ADER: TBytes): Boolean;
var
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
      SetLength(FDERData, 0);
      FPEMData := '';
      RebuildInfo;
      Exit(False);
    end;
  finally
    LParser.Free;
  end;

  FDERData := CopyBytes(ADER);
  try
    FPEMData := TSSLUtils.DERToPEM(FDERData);
  except
    FPEMData := '';
  end;

  RebuildInfo;
  Result := True;
end;

function TFreePascalCertificate.SaveToFile(const AFileName: string): Boolean;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  Result := False;
  if Trim(AFileName) = '' then
    Exit;

  LBytes := SaveToDER;
  if Length(LBytes) = 0 then
  begin
    SetLength(LBytes, Length(FPEMData));
    if Length(LBytes) > 0 then
      Move(FPEMData[1], LBytes[0], Length(LBytes));
  end;

  if Length(LBytes) = 0 then
    Exit;

  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
    Result := True;
  finally
    LStream.Free;
  end;
end;

function TFreePascalCertificate.SaveToStream(AStream: TStream): Boolean;
var
  LBytes: TBytes;
begin
  Result := False;
  if AStream = nil then
    Exit;

  LBytes := SaveToDER;
  if Length(LBytes) = 0 then
  begin
    SetLength(LBytes, Length(FPEMData));
    if Length(LBytes) > 0 then
      Move(FPEMData[1], LBytes[0], Length(LBytes));
  end;

  if Length(LBytes) = 0 then
    Exit;

  AStream.WriteBuffer(LBytes[0], Length(LBytes));
  Result := True;
end;

function TFreePascalCertificate.SaveToPEM: string;
begin
  if (FPEMData = '') and (Length(FDERData) > 0) then
  begin
    try
      FPEMData := TSSLUtils.DERToPEM(FDERData);
    except
      FPEMData := '';
    end;
  end;
  Result := FPEMData;
end;

function TFreePascalCertificate.SaveToDER: TBytes;
begin
  if (Length(FDERData) = 0) and (FPEMData <> '') then
  begin
    try
      FDERData := TSSLUtils.PEMToDER(FPEMData);
    except
      SetLength(FDERData, 0);
    end;
  end;

  Result := CopyBytes(FDERData);
end;

function TFreePascalCertificate.GetInfo: TSSLCertificateInfo;
begin
  Result := FInfo;
end;

function TFreePascalCertificate.GetSubject: string;
begin
  Result := FInfo.Subject;
end;

function TFreePascalCertificate.GetIssuer: string;
begin
  Result := FInfo.Issuer;
end;

function TFreePascalCertificate.GetSerialNumber: string;
begin
  Result := FInfo.SerialNumber;
end;

function TFreePascalCertificate.GetNotBefore: TDateTime;
begin
  Result := FInfo.NotBefore;
end;

function TFreePascalCertificate.GetNotAfter: TDateTime;
begin
  Result := FInfo.NotAfter;
end;

function TFreePascalCertificate.GetPublicKey: string;
begin
  Result := GetPublicKeyAlgorithm;
end;

function TFreePascalCertificate.GetPublicKeyAlgorithm: string;
begin
  Result := FInfo.PublicKeyAlgorithm;
end;

function TFreePascalCertificate.GetSignatureAlgorithm: string;
begin
  Result := FInfo.SignatureAlgorithm;
end;

function TFreePascalCertificate.GetVersion: Integer;
begin
  Result := FInfo.Version;
end;

function TFreePascalCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
begin
  if ACAStore = nil then
    Exit(False);
  Result := ACAStore.VerifyCertificate(Self);
end;

function TFreePascalCertificate.VerifyEx(ACAStore: ISSLCertificateStore;
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
var
  LExtendedKeyUsage: TSSLStringArray;
  I: Integer;
  LHasServerAuth: Boolean;
begin
  AResult.Success := False;
  AResult.ErrorCode := 0;
  AResult.ErrorMessage := '';
  AResult.DetailedInfo := '';
  AResult.ChainStatus := 0;
  AResult.RevocationStatus := 0;

  if ACAStore = nil then
  begin
    AResult.Success := False;
    AResult.ErrorCode := 1;
    AResult.ErrorMessage := 'Certificate store is not configured';
    AResult.DetailedInfo := 'FreePascal VerifyEx requires a configured certificate store';
    Exit(False);
  end;

  Result := ACAStore.VerifyCertificate(Self);
  AResult.Success := Result;
  if Result then
  begin
    AResult.ErrorCode := 0;
    AResult.ErrorMessage := '';
    AResult.DetailedInfo := 'FreePascal certificate store verification passed';
  end
  else
  begin
    AResult.ErrorCode := 2;
    AResult.ErrorMessage := 'Certificate verification failed';
    AResult.ChainStatus := 1;
    AResult.DetailedInfo := 'FreePascal certificate store rejected the certificate chain';
  end;

  if not (sslCertVerifyIgnoreExpiry in AFlags) and IsExpired then
  begin
    Result := False;
    AResult.Success := False;
    AResult.ErrorCode := 3;
    AResult.ErrorMessage := 'Certificate is expired';
    AResult.DetailedInfo := 'Certificate validity period has ended';
    Exit;
  end;

  if (not Result) and (sslCertVerifyAllowSelfSigned in AFlags) and IsSelfSigned then
  begin
    Result := True;
    AResult.Success := True;
    AResult.ErrorCode := 0;
    AResult.ErrorMessage := '';
    AResult.ChainStatus := 0;
    AResult.DetailedInfo :=
      'FreePascal certificate verification accepted a self-signed leaf because sslCertVerifyAllowSelfSigned was requested';
  end;

  if Result and (sslCertVerifyStrictChain in AFlags) then
  begin
    LExtendedKeyUsage := GetExtendedKeyUsage;
    LHasServerAuth := False;
    for I := 0 to High(LExtendedKeyUsage) do
    begin
      if SameText(Trim(LExtendedKeyUsage[I]), 'serverAuth') then
      begin
        LHasServerAuth := True;
        Break;
      end;
    end;

    if not LHasServerAuth then
    begin
      Result := False;
      AResult.Success := False;
      AResult.ErrorCode := 4;
      AResult.ErrorMessage := 'Strict chain verification requires serverAuth extended key usage';
      AResult.ChainStatus := 2;
      AResult.DetailedInfo :=
        'sslCertVerifyStrictChain requested but the leaf certificate is missing serverAuth extended key usage';
      Exit;
    end;
  end;

  if Result and ((sslCertVerifyCheckRevocation in AFlags) or
    (sslCertVerifyCheckCRL in AFlags)) then
  begin
    Result := False;
    AResult.Success := False;
    AResult.ErrorCode := 5;
    AResult.RevocationStatus := 2;
    AResult.ErrorMessage := 'Certificate revocation/CRL verification is unavailable';
    AResult.DetailedInfo :=
      'FreePascal VerifyEx has no revocation material for sslCertVerifyCheckRevocation/sslCertVerifyCheckCRL';
    Exit;
  end;

  if Result and (sslCertVerifyCheckOCSP in AFlags) then
  begin
    Result := False;
    AResult.Success := False;
    AResult.ErrorCode := 6;
    AResult.RevocationStatus := 2;
    AResult.ErrorMessage := 'Certificate OCSP verification is unavailable';
    AResult.DetailedInfo :=
      'FreePascal VerifyEx has no certificate-level OCSP verification path for sslCertVerifyCheckOCSP';
    Exit;
  end;
end;

function TFreePascalCertificate.VerifyHostname(const AHostname: string): Boolean;
var
  LSANs: TSSLStringArray;
  I: Integer;
begin
  Result := False;
  if Trim(AHostname) = '' then
    Exit;

  LSANs := GetSubjectAltNames;
  if Length(LSANs) > 0 then
  begin
    for I := 0 to High(LSANs) do
    begin
      if MatchHostname(LSANs[I], AHostname) then
        Exit(True);
    end;
    Exit(False);
  end;

  Result := MatchHostname(GetSubjectCN, AHostname);
end;

function TFreePascalCertificate.IsExpired: Boolean;
begin
  if FInfo.NotAfter = 0 then
    Exit(False);
  Result := DateTimeUtcNow > FInfo.NotAfter;
end;

function TFreePascalCertificate.IsSelfSigned: Boolean;
var
  LX509: TX509Certificate;
  LError: string;
begin
  Result := False;
  if (FInfo.Subject = '') or (FInfo.Issuer = '') then Exit;
  if not SameText(FInfo.Subject, FInfo.Issuer) then Exit;
  if Length(FDERData) = 0 then Exit(True);
  LX509 := TX509Certificate.Create;
  try
    try
      LX509.LoadFromDER(FDERData);
    except
      Exit(True);
    end;
    Result := VerifyChainSignatureEx(LX509, LX509, LError);
  finally
    LX509.Free;
  end;
end;

function TFreePascalCertificate.IsCA: Boolean;
begin
  Result := FInfo.IsCA;
end;

function TFreePascalCertificate.GetDaysUntilExpiry: Integer;
begin
  if FInfo.NotAfter = 0 then
    Exit(0);
  Result := Trunc(FInfo.NotAfter - Now);
end;

function TFreePascalCertificate.GetSubjectCN: string;
var
  LSubject: string;
  LPos: Integer;
begin
  Result := '';
  LSubject := GetSubject;
  if LSubject = '' then
    Exit;

  LPos := Pos('CN=', UpperCase(LSubject));
  if LPos <= 0 then
    Exit;

  Result := Copy(LSubject, LPos + 3, MaxInt);
  LPos := Pos(',', Result);
  if LPos > 0 then
    Result := Copy(Result, 1, LPos - 1);

  LPos := Pos('/', Result);
  if LPos > 0 then
    Result := Copy(Result, 1, LPos - 1);

  Result := Trim(Result);
end;

function TFreePascalCertificate.GetExtension(const AOID: string): string;
var
  LParser: TX509Certificate;
  LTargetOID: string;
  I: Integer;
begin
  Result := '';
  LTargetOID := Trim(AOID);
  if LTargetOID = '' then
    Exit;

  if (Length(FDERData) = 0) and (FPEMData = '') then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      if Length(FDERData) > 0 then
        LParser.LoadFromDER(FDERData)
      else
        LParser.LoadFromPEM(FPEMData);
    except
      Exit;
    end;

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

function TFreePascalCertificate.GetSubjectAltNames: TSSLStringArray;
var
  I: Integer;
begin
  SetLength(Result, Length(FInfo.SubjectAltNames));
  for I := 0 to High(FInfo.SubjectAltNames) do
    Result[I] := FInfo.SubjectAltNames[I];
end;

function TFreePascalCertificate.GetKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
  LUsage: TX509KeyUsage;

  procedure AddToResult(const AUsage: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AUsage;
  end;

begin
  SetLength(Result, 0);

  LParser := TX509Certificate.Create;
  try
    try
      if Length(FDERData) > 0 then
        LParser.LoadFromDER(FDERData)
      else
        LParser.LoadFromPEM(FPEMData);
    except
      Exit;
    end;

    LUsage := LParser.KeyUsage;
    if kuDigitalSignature in LUsage then
      AddToResult('digitalSignature');
    if kuNonRepudiation in LUsage then
      AddToResult('nonRepudiation');
    if kuKeyEncipherment in LUsage then
      AddToResult('keyEncipherment');
    if kuDataEncipherment in LUsage then
      AddToResult('dataEncipherment');
    if kuKeyAgreement in LUsage then
      AddToResult('keyAgreement');
    if kuKeyCertSign in LUsage then
      AddToResult('keyCertSign');
    if kuCRLSign in LUsage then
      AddToResult('cRLSign');
    if kuEncipherOnly in LUsage then
      AddToResult('encipherOnly');
    if kuDecipherOnly in LUsage then
      AddToResult('decipherOnly');
  finally
    LParser.Free;
  end;
end;

function TFreePascalCertificate.GetExtendedKeyUsage: TSSLStringArray;
var
  LParser: TX509Certificate;
  LUsage: TX509ExtKeyUsage;

  procedure AddToResult(const AUsage: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AUsage;
  end;

begin
  SetLength(Result, 0);

  LParser := TX509Certificate.Create;
  try
    try
      if Length(FDERData) > 0 then
        LParser.LoadFromDER(FDERData)
      else
        LParser.LoadFromPEM(FPEMData);
    except
      Exit;
    end;

    LUsage := LParser.ExtKeyUsage;
    if ekuServerAuth in LUsage then
      AddToResult('serverAuth');
    if ekuClientAuth in LUsage then
      AddToResult('clientAuth');
    if ekuCodeSigning in LUsage then
      AddToResult('codeSigning');
    if ekuEmailProtection in LUsage then
      AddToResult('emailProtection');
    if ekuTimeStamping in LUsage then
      AddToResult('timeStamping');
    if ekuOCSPSigning in LUsage then
      AddToResult('OCSPSigning');
  finally
    LParser.Free;
  end;
end;

function TFreePascalCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  case AHashType of
    sslHashSHA1:
      Result := GetFingerprintSHA1;
    sslHashSHA256:
      Result := GetFingerprintSHA256;
    sslHashSHA384:
      Result := HashToHex(SHA384(SaveToDER));
    sslHashSHA512:
      Result := HashToHex(SHA512(SaveToDER));
  else
    Result := GetFingerprintSHA256;
  end;
end;

function TFreePascalCertificate.GetFingerprintSHA1: string;
begin
  if FInfo.FingerprintSHA1 = '' then
    FInfo.FingerprintSHA1 := HashToHex(SHA1(SaveToDER));
  Result := FInfo.FingerprintSHA1;
end;

function TFreePascalCertificate.GetFingerprintSHA256: string;
begin
  if FInfo.FingerprintSHA256 = '' then
    FInfo.FingerprintSHA256 := HashToHex(SHA256(SaveToDER));
  Result := FInfo.FingerprintSHA256;
end;

procedure TFreePascalCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCert := ACert;
end;

function TFreePascalCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCert;
end;

function TFreePascalCertificate.Clone: ISSLCertificate;
var
  LClone: TFreePascalCertificate;
  I: Integer;
begin
  LClone := TFreePascalCertificate.Create;
  LClone.FDERData := CopyBytes(FDERData);
  LClone.FPEMData := FPEMData;
  LClone.FInfo := FInfo;
  SetLength(LClone.FInfo.SubjectAltNames, Length(FInfo.SubjectAltNames));
  for I := 0 to High(FInfo.SubjectAltNames) do
    LClone.FInfo.SubjectAltNames[I] := FInfo.SubjectAltNames[I];
  LClone.FIssuerCert := FIssuerCert;
  Result := LClone;
end;

{ TFreePascalCertificateStore }

constructor TFreePascalCertificateStore.Create;
begin
  inherited Create;
  FCertificates := TInterfaceList.Create;
end;

destructor TFreePascalCertificateStore.Destroy;
begin
  FCertificates.Clear;
  FCertificates.Free;
  inherited Destroy;
end;

function TFreePascalCertificateStore.NormalizeFingerprint(const AFingerprint: string): string;
begin
  Result := UpperCase(AFingerprint);
  Result := StringReplace(Result, ':', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function TFreePascalCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
var
  LFingerprint: string;
begin
  Result := False;
  if ACert = nil then
    Exit;

  if Contains(ACert) then
    Exit;

  LFingerprint := NormalizeFingerprint(ACert.GetFingerprintSHA256);
  if (LFingerprint <> '') and (FindByFingerprint(LFingerprint) <> nil) then
    Exit;

  FCertificates.Add(ACert);
  Result := True;
end;

function TFreePascalCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
var
  LIdx: Integer;
  LFingerprint: string;
  LMatch: ISSLCertificate;
begin
  Result := False;
  if ACert = nil then
    Exit;

  LIdx := FCertificates.IndexOf(ACert);
  if LIdx < 0 then
  begin
    LFingerprint := NormalizeFingerprint(ACert.GetFingerprintSHA256);
    if LFingerprint <> '' then
    begin
      LMatch := FindByFingerprint(LFingerprint);
      if LMatch <> nil then
        LIdx := FCertificates.IndexOf(LMatch);
    end;
  end;

  if LIdx >= 0 then
  begin
    FCertificates.Delete(LIdx);
    Result := True;
  end;
end;

function TFreePascalCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
var
  LFingerprint: string;
begin
  Result := False;
  if ACert = nil then
    Exit;

  if FCertificates.IndexOf(ACert) >= 0 then
    Exit(True);

  LFingerprint := NormalizeFingerprint(ACert.GetFingerprintSHA256);
  if LFingerprint = '' then
    Exit(False);

  Result := FindByFingerprint(LFingerprint) <> nil;
end;

procedure TFreePascalCertificateStore.Clear;
begin
  FCertificates.Clear;
end;

function TFreePascalCertificateStore.GetCount: Integer;
begin
  Result := FCertificates.Count;
end;

function TFreePascalCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FCertificates.Count) then
    Result := FCertificates[AIndex] as ISSLCertificate;
end;

function TFreePascalCertificateStore.LoadFromFile(const AFileName: string): Boolean;
var
  LCert: ISSLCertificate;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;

  LCert := TFreePascalCertificate.Create;
  if not LCert.LoadFromFile(AFileName) then
    Exit;

  Result := AddCertificate(LCert);
end;

function TFreePascalCertificateStore.LoadFromPath(const APath: string): Boolean;
  function IsCertificateCandidateFile(const AFileName: string): Boolean;
  var
    LExt: string;
    I: Integer;
  begin
    LExt := LowerCase(ExtractFileExt(AFileName));
    if (LExt = '.pem') or (LExt = '.crt') or (LExt = '.cer') or (LExt = '.der') then
      Exit(True);

    if (Length(LExt) > 1) and (LExt[1] = '.') then
    begin
      Result := True;
      for I := 2 to Length(LExt) do
      begin
        if not (LExt[I] in ['0'..'9']) then
          Exit(False);
      end;
      Exit(True);
    end;

    Result := False;
  end;
var
  LSearch: TSearchRec;
  LFileName: string;
  LLoadedCount: Integer;
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit;

  LLoadedCount := 0;
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, LSearch) = 0 then
  begin
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
        Continue;
      if (LSearch.Attr and faDirectory) <> 0 then
        Continue;
      if not IsCertificateCandidateFile(LSearch.Name) then
        Continue;

      LFileName := IncludeTrailingPathDelimiter(APath) + LSearch.Name;
      if LoadFromFile(LFileName) then
        Inc(LLoadedCount);
    until FindNext(LSearch) <> 0;

    FindClose(LSearch);
  end;

  Result := LLoadedCount > 0;
end;

function TFreePascalCertificateStore.LoadSystemStore: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(CSystemStorePaths) to High(CSystemStorePaths) do
  begin
    if not DirectoryExists(CSystemStorePaths[I]) then
      Continue;

    if LoadFromPath(CSystemStorePaths[I]) then
      Exit(True);
  end;
end;

function NormalizeCertificateStoreDN(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
  Result := StringReplace(Result, ' , ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ', ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' ,', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' = ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, '= ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, ' =', '=', [rfReplaceAll]);
end;

function TFreePascalCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
  LCandidate: string;
begin
  Result := nil;
  LTarget := NormalizeCertificateStoreDN(ASubject);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    LCandidate := NormalizeCertificateStoreDN(LCert.GetSubject);
    if LCandidate = LTarget then
      Exit(LCert);
  end;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    LCandidate := NormalizeCertificateStoreDN(LCert.GetSubject);
    if Pos(LTarget, LCandidate) > 0 then
      Exit(LCert);
  end;
end;

function TFreePascalCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
  LCandidate: string;
begin
  Result := nil;
  LTarget := NormalizeCertificateStoreDN(AIssuer);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    LCandidate := NormalizeCertificateStoreDN(LCert.GetIssuer);
    if LCandidate = LTarget then
      Exit(LCert);
  end;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    LCandidate := NormalizeCertificateStoreDN(LCert.GetIssuer);
    if Pos(LTarget, LCandidate) > 0 then
      Exit(LCert);
  end;
end;

function TFreePascalCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
  function NormalizeSerial(const AValue: string): string;
  var
    I: Integer;
    LChar: Char;
  begin
    Result := '';
    for I := 1 to Length(AValue) do
    begin
      LChar := UpCase(AValue[I]);
      if LChar in ['0'..'9', 'A'..'F'] then
        Result := Result + LChar;
    end;
  end;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeSerial(ASerialNumber);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if NormalizeSerial(LCert.GetSerialNumber) = LTarget then
      Exit(LCert);
  end;
end;

function TFreePascalCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
var
  I: Integer;
  LTarget: string;
  LCert: ISSLCertificate;
begin
  Result := nil;
  LTarget := NormalizeFingerprint(AFingerprint);
  if LTarget = '' then
    Exit;

  for I := 0 to FCertificates.Count - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if NormalizeFingerprint(LCert.GetFingerprintSHA256) = LTarget then
      Exit(LCert);
  end;
end;

function TFreePascalCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
var
  LIssuer: ISSLCertificate;
  LSubjectDER, LIssuerDER: TBytes;
  LSubjectX509, LIssuerX509: TX509Certificate;
  LError: string;
begin
  Result := False;
  if ACert = nil then
    Exit;

  if ACert.IsExpired then
    Exit;

  if Contains(ACert) then
    Exit(True);

  if ACert.IsSelfSigned then
  begin
    Result := FindByFingerprint(ACert.GetFingerprintSHA256) <> nil;
    Exit;
  end;

  // Find a candidate issuer by subject DN. DN match alone proves nothing —
  // the cryptographic signature check below is mandatory to prevent a forged
  // leaf (whose issuer DN is spoofed to a trusted CA) from being accepted.
  LIssuer := FindBySubject(ACert.GetIssuer);
  if LIssuer = nil then
    Exit;

  if LIssuer.IsExpired then
    Exit;

  LSubjectDER := ACert.SaveToDER;
  LIssuerDER := LIssuer.SaveToDER;
  if (Length(LSubjectDER) = 0) or (Length(LIssuerDER) = 0) then
    Exit;

  LSubjectX509 := TX509Certificate.Create;
  try
    LIssuerX509 := TX509Certificate.Create;
    try
      try
        LSubjectX509.LoadFromDER(LSubjectDER);
        LIssuerX509.LoadFromDER(LIssuerDER);
      except
        Exit;
      end;
      if not VerifyChainSignatureEx(LSubjectX509, LIssuerX509, LError) then
        Exit;
    finally
      LIssuerX509.Free;
    end;
  finally
    LSubjectX509.Free;
  end;

  ACert.SetIssuerCertificate(LIssuer);
  Result := True;
end;

function TFreePascalCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
var
  LCurrent, LNext: ISSLCertificate;
  LIndex, I: Integer;
  LExists: Boolean;
begin
  SetLength(Result, 0);
  if ACert = nil then
    Exit;

  LCurrent := ACert;
  LIndex := 0;
  while (LCurrent <> nil) and (LIndex < 16) do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LCurrent;

    if LCurrent.IsSelfSigned then
      Break;

    LNext := LCurrent.GetIssuerCertificate;
    if LNext = nil then
      LNext := FindBySubject(LCurrent.GetIssuer);

    if LNext = nil then
      Break;

    LExists := False;
    for I := 0 to High(Result) do
    begin
      if Result[I] = LNext then
      begin
        LExists := True;
        Break;
      end;

      if NormalizeFingerprint(Result[I].GetFingerprintSHA256) =
        NormalizeFingerprint(LNext.GetFingerprintSHA256) then
      begin
        LExists := True;
        Break;
      end;
    end;
    if LExists then
      Break;

    LCurrent := LNext;
    Inc(LIndex);
  end;
end;

constructor TFreePascalSSLLibrary.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := 0;
  FLastErrorString := '';
  FLogCallback := nil;
  FLogLevel := sslLogError;

  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  FDefaultConfig.LibraryType := sslFreePascal;
  FDefaultConfig.ContextType := sslCtxClient;
  FDefaultConfig.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FDefaultConfig.PreferredVersion := sslProtocolTLS13;
  FDefaultConfig.VerifyMode := [sslVerifyPeer];
  FDefaultConfig.VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FDefaultConfig.CipherList := SSL_DEFAULT_CIPHER_LIST;
  FDefaultConfig.CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
  FDefaultConfig.Options := [ssoEnableSessionCache, ssoEnableSessionTickets, ssoEnableSNI, ssoEnableALPN];
  FDefaultConfig.BufferSize := SSL_DEFAULT_BUFFER_SIZE;
  FDefaultConfig.HandshakeTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
  FDefaultConfig.SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
  FDefaultConfig.SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FDefaultConfig.EnableCompression := False;
  FDefaultConfig.EnableSessionTickets := True;
  FDefaultConfig.EnableOCSPStapling := False;
  FDefaultConfig.LogLevel := sslLogError;
  TSSLFactory.NormalizeConfig(FDefaultConfig);

  FillChar(FStatistics, SizeOf(FStatistics), 0);
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
  FCapabilitiesCached := False;
end;

procedure TFreePascalSSLLibrary.InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if Assigned(FLogCallback) and (ALevel <= FLogLevel) then
    FLogCallback(ALevel, '[FreePascal] ' + AMessage);
end;

procedure TFreePascalSSLLibrary.InvalidateCapabilitiesCache;
begin
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;

function TFreePascalSSLLibrary.Initialize: Boolean;
begin
  FInitialized := True;
  Result := True;
end;

procedure TFreePascalSSLLibrary.Finalize;
begin
  FInitialized := False;
end;

function TFreePascalSSLLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TFreePascalSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslFreePascal;
end;

function TFreePascalSSLLibrary.GetVersionString: string;
begin
  Result := 'FreePascal Native Backend (TLS 1.3 core path)';
end;

function TFreePascalSSLLibrary.GetVersionNumber: Cardinal;
begin
  Result := 10000;
end;

function TFreePascalSSLLibrary.GetCompileFlags: string;
begin
  Result := 'PurePascal;NoExternalTLSLibrary';
end;

function TFreePascalSSLLibrary.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  case AProtocol of
    sslProtocolTLS12,
    sslProtocolTLS13:
      Result := True;
  else
    Result := False;
  end;
end;

function TFreePascalSSLLibrary.IsCipherSupported(const ACipherName: string): Boolean;
var
  LUpper: string;
begin
  LUpper := UpperCase(Trim(ACipherName));
  Result :=
    (LUpper = 'TLS_AES_256_GCM_SHA384') or
    (LUpper = 'TLS_AES_128_GCM_SHA256') or
    (LUpper = 'TLS_CHACHA20_POLY1305_SHA256');
end;

function TFreePascalSSLLibrary.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  case AFeature of
    sslFeatSNI,
    sslFeatALPN,
    sslFeatOCSPStapling,
    sslFeatCertificateTransparency,
    sslFeatSessionTickets,
    sslFeatSessionCache:
      Result := True;
  else
    Result := False;
  end;
end;

function TFreePascalSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  if FCapabilitiesCached then
    Exit(FCapabilitiesCache);

  FillChar(Result, SizeOf(Result), 0);
  Result.SupportsTLS13 := True;
  Result.SupportsECDHE := True;
  Result.SupportsChaChaPoly := True;
  Result.SupportsPEMPrivateKey := True;
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;

  Result.BackendType := sslFreePascal;
  Result.BackendImplType := sslImplNative;
  Result.BackendVersion := GetVersionString;
  Result.SupportsDTLS := False;

  Result.SNISupport := sslSupportExperimental;
  Result.ALPNSupport := sslSupportExperimental;
  Result.OCSPStaplingSupport := sslSupportExperimental;
  Result.CertTransparencySupport := sslSupportExperimental;
  Result.SessionTicketsSupport := sslSupportExperimental;
  Result.SessionCacheSupport := sslSupportExperimental;
  Result.ZeroRTTSupport := sslSupportExperimental;
  Result.EarlyDataSupport := sslSupportExperimental;
  Result.RenegotiationSupport := sslSupportDeprecated;
  Result.PostHandshakeAuthSupport := sslSupportNone;

  Result.SupportedCiphers := [sslCipherAES128GCM, sslCipherAES256GCM, sslCipherCHACHA20_POLY1305];
  Result.SupportedHashes := [sslHashSHA256, sslHashSHA384, sslHashSHA512];
  Result.SupportedKeyExchanges := [sslKexECDHE_RSA, sslKexECDHE_ECDSA];

  Result.HasHardwareAcceleration := IsAESNIAvailable;
  Result.HasSIMDOptimization := IsAESNIAvailable;
  Result.HasAssemblyOptimization := True;

  Result.RequiresExternalLibrary := False;
  Result.SupportsSystemCertStore := HasSystemCertStoreDirectories;
  Result.SupportsPKCS11 := False;
  Result.SupportsTPM := False;

  Result.HasConstantTimeOperations := True;
  Result.SupportsFIPSMode := False;
  Result.HasSecureMemoryWipe := True;

  Result.SupportsDERPrivateKey := True;
  Result.SupportsPKCS8PrivateKey := True;
  Result.SupportsPKCS12 := False;
  Result.SupportsPasswordProtectedKeys := True;  // PKCS#8 (PBES2+PBKDF2+AES-CBC) and Traditional OpenSSL PEM (DEK-Info+EVP_BytesToKey)

  Result.SupportsCustomCipherSuites := True;  // explicit supported-suite allowlists are parsed and applied by the pure Pascal runtime path
  Result.SupportsCallbacks := True;  // verify callback is wired into the FreePascal runtime path; password/info remain unsupported

  Result.CompatibilityLevel := 72;
  Result.KnownIssues :=
    '0-RTT / early data is experimental and currently relies on a local persistent anti-replay replay-store path; ' +
    'if the path is unavailable or unwritable, resumed early data is rejected fail-closed. ' +
    'Online revocation queries require an external HTTP callback; no built-in HTTP client is provided. ' +
    'TLS renegotiation is deprecated and will not be implemented (use TLS 1.3 KeyUpdate instead).';

  NormalizeLegacyCapabilityBooleans(Result);

  FCapabilitiesCache := Result;
  FCapabilitiesCached := True;
end;

procedure TFreePascalSSLLibrary.SetDefaultConfig(const AConfig: TSSLConfig);
var
  LConfig: TSSLConfig;
begin
  LConfig := AConfig;
  TSSLFactory.NormalizeConfig(LConfig);

  FLogLevel := LConfig.LogLevel;
  LConfig.LogCallback := FLogCallback;
  FDefaultConfig := LConfig;
  InvalidateCapabilitiesCache;
end;

function TFreePascalSSLLibrary.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
end;

function TFreePascalSSLLibrary.GetLastError: Integer;
begin
  Result := FLastError;
end;

function TFreePascalSSLLibrary.GetLastErrorString: string;
begin
  Result := FLastErrorString;
end;

procedure TFreePascalSSLLibrary.ClearError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

function TFreePascalSSLLibrary.GetStatistics: TSSLStatistics;
begin
  Result := FStatistics;
end;

procedure TFreePascalSSLLibrary.ResetStatistics;
begin
  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

procedure TFreePascalSSLLibrary.SetLogCallback(ACallback: TSSLLogCallback);
begin
  FLogCallback := ACallback;
  FDefaultConfig.LogCallback := ACallback;
end;

procedure TFreePascalSSLLibrary.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
  InternalLog(ALevel, AMessage);
end;

function TFreePascalSSLLibrary.CreateContext(AType: TSSLContextType): ISSLContext;
var
  LConfig: TSSLConfig;
  LVerifyMode: TSSLVerifyModes;
  Store: ISSLCertificateStore;
begin
  if not FInitialized then
    raise ESSLInitializationException.CreateWithContext(
      'Cannot create context: FreePascal library not initialized',
      sslErrNotInitialized,
      'TFreePascalSSLLibrary.CreateContext',
      0,
      sslFreePascal
    );

  LConfig := FDefaultConfig;
  LConfig.ContextType := AType;

  ValidateDirectLibraryConnectionScope(
    LConfig,
    'TFreePascalSSLLibrary.CreateContext'
  );

  if (AType = sslCtxServer) and (Trim(LConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from TFreePascalSSLLibrary.CreateContext when creating server contexts.',
      sslErrConfiguration,
      'TFreePascalSSLLibrary.CreateContext',
      0,
      sslFreePascal
    );

  ValidateContextReplayStoreConfigScope(
    LConfig,
    AType,
    'TFreePascalSSLLibrary.CreateContext'
  );
  LVerifyMode := LConfig.VerifyMode;
  if (AType = sslCtxServer) and
    (LVerifyMode = [sslVerifyPeer]) and
    (Trim(LConfig.CAFile) = '') and
    (Trim(LConfig.CAPath) = '') and
    (not LConfig.UseSystemRoots) then
    LVerifyMode := [];

  Result := TFreePascalContext.Create(Self, AType);
  if Result <> nil then
  begin
    if LConfig.ProtocolVersions <> [] then
      Result.SetProtocolVersions(LConfig.ProtocolVersions);

    if LConfig.PreferredVersion <> sslProtocolUnknown then
      Result.SetPreferredVersion(LConfig.PreferredVersion);

    Result.SetVerifyMode(LVerifyMode);

    if LConfig.VerifyDepth > 0 then
      Result.SetVerifyDepth(LConfig.VerifyDepth);

    if LConfig.CipherList <> '' then
      Result.SetCipherList(LConfig.CipherList);

    if LConfig.CipherSuites <> '' then
      Result.SetCipherSuites(LConfig.CipherSuites);

    Result.SetOptions(LConfig.Options);
    Result.SetSessionCacheSize(LConfig.SessionCacheSize);
    Result.SetSessionTimeout(LConfig.SessionTimeout);
    Result.SetSessionCacheMode(ssoEnableSessionCache in LConfig.Options);

    if LConfig.UseSystemRoots then
    begin
      Store := TSSLFactory.CreateCertificateStore(GetLibraryType);
      if Store <> nil then
      begin
        Store.LoadSystemStore;
        Result.SetCertificateStore(Store);
      end;
    end;

    if LConfig.CAFile <> '' then
      Result.LoadCAFile(LConfig.CAFile);

    if LConfig.CAPath <> '' then
      Result.LoadCAPath(LConfig.CAPath);

    if LConfig.ServerName <> '' then
      InternalLog(
        sslLogWarning,
        'TFreePascalSSLLibrary.CreateContext received TSSLConfig.ServerName as deprecated context-level ' +
        'SNI compatibility; CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
        'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).'
      );

    if LConfig.ALPNProtocols <> '' then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TFreePascalSSLLibrary.CreateContext');
  end;
end;

function TFreePascalSSLLibrary.CreateCertificate: ISSLCertificate;
begin
  if not FInitialized then
    raise ESSLInitializationException.CreateWithContext(
      'Cannot create certificate: FreePascal library not initialized',
      sslErrNotInitialized,
      'TFreePascalSSLLibrary.CreateCertificate',
      0,
      sslFreePascal
    );

  Result := TFreePascalCertificate.Create;
end;

function TFreePascalSSLLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  if not FInitialized then
    raise ESSLInitializationException.CreateWithContext(
      'Cannot create certificate store: FreePascal library not initialized',
      sslErrNotInitialized,
      'TFreePascalSSLLibrary.CreateCertificateStore',
      0,
      sslFreePascal
    );

  Result := TFreePascalCertificateStore.Create;
end;

function CreateFreePascalSSLLibrary: ISSLLibrary;
begin
  Result := TFreePascalSSLLibrary.Create;
end;

procedure RegisterFreePascalBackend;
begin
  try
    TSSLFactory.RegisterLibrary(sslFreePascal, @CreateFreePascalSSLLibrary,
      'FreePascal Native TLS Backend (in progress)', 50);
  except
  end;
end;

procedure UnregisterFreePascalBackend;
begin
  TSSLFactory.UnregisterLibrary(sslFreePascal);
end;

initialization
  RegisterFreePascalBackend;

finalization
  UnregisterFreePascalBackend;

end.
