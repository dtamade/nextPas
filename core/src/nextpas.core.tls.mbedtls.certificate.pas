{**
 * Unit: nextpas.core.tls.mbedtls.certificate
 * Purpose: MbedTLS 证书和证书存储实现
 *
 * 实现 ISSLCertificate 和 ISSLCertificateStore 接口的 MbedTLS 后端。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.mbedtls.certificate;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils,nextpas.core.tls.base,
  nextpas.core.tls.base64,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.x509,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.native_handle,
  nextpas.core.tls.mbedtls.api;

type
  { TMbedTLSCertificate - MbedTLS 证书类 }
  TMbedTLSCertificate = class(TInterfacedObject, ISSLCertificate, ISSLNativeHandleAccess)
  private
    FX509Crt: Pmbedtls_x509_crt;
    FInfo: TSSLCertificateInfo;
    FPEMData: string;
    FDERData: TBytes;
    FIssuerCert: ISSLCertificate;
    FOwnsHandle: Boolean;

    procedure AllocateCertificate;
    procedure ResetLoadedState;
    procedure FreeCertificate;
    function TryLoadX509Parser(out AParser: TX509Certificate): Boolean;
    function TryGetParsedAlgorithmMetadata(out APublicKeyAlgorithm,
      ASignatureAlgorithm: string): Boolean;

  public
    constructor Create; overload;
    constructor Create(ACrt: Pmbedtls_x509_crt; AOwnsHandle: Boolean = False); overload;
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

  { TMbedTLSCertificateStore - MbedTLS 证书存储类 }
  TMbedTLSCertificateStore = class(TInterfacedObject, ISSLCertificateStore, ISSLNativeHandleAccess)
  private
    FCACerts: Pmbedtls_x509_crt;
    FCertificates: TInterfaceList;

    procedure AllocateStore;
    procedure FreeStore;

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
  nextpas.core.text.strings,
    Contnrs, DateUtils,
  nextpas.core.time,
  nextpas.core.tls.utils,
  nextpas.core.crypto.hash;

const
  MBEDTLS_X509_CRT_SIZE = 16384;
  MBEDTLS_X509_BADCERT_EXPIRED = $0001;
  MBEDTLS_X509_BADCERT_NOT_TRUSTED = $0008;
  MBEDTLS_X509_BADCERT_FUTURE = $0200;

function NormalizeMbedTLSCertText(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
  Result := StringReplace(Result, ' , ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ', ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' ,', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' = ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, '= ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, ' =', '=', [rfReplaceAll]);
end;

function NormalizeMbedTLSCertHex(const AValue: string): string;
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

procedure ResetCertVerifyResult(out AResult: TSSLCertVerifyResult);
begin
  AResult.Success := False;
  AResult.ErrorCode := 0;
  AResult.ErrorMessage := '';
  AResult.ChainStatus := 0;
  AResult.RevocationStatus := 0;
  AResult.DetailedInfo := '';
end;

function GetMbedTLSVerifyInfoString(const AFlags: Cardinal): string;
var
  LBuf: array[0..1023] of AnsiChar;
begin
  Result := '';
  if (AFlags = 0) or not Assigned(mbedtls_x509_crt_verify_info) then
    Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  mbedtls_x509_crt_verify_info(@LBuf[0], SizeOf(LBuf), '', AFlags);
  Result := Trim(string(LBuf));
end;

{ Helper function to extract field from MbedTLS info output }
function ExtractField(const AInfo, AFieldName: string): string;
var
  LPos, LEndPos: Integer;
  LSearchStr: string;
begin
  Result := '';
  LSearchStr := AFieldName + ' name';
  LPos := Pos(LSearchStr, AInfo);
  if LPos = 0 then
  begin
    LSearchStr := AFieldName + ':';
    LPos := Pos(LSearchStr, AInfo);
  end;

  if LPos > 0 then
  begin
    LPos := LPos + Length(LSearchStr);
    // Skip whitespace
    while (LPos <= Length(AInfo)) and (AInfo[LPos] in [' ', #9, ':']) do
      Inc(LPos);
    // Find end of line
    LEndPos := LPos;
    while (LEndPos <= Length(AInfo)) and not (AInfo[LEndPos] in [#10, #13]) do
      Inc(LEndPos);
    Result := Trim(Copy(AInfo, LPos, LEndPos - LPos));
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

{ TMbedTLSCertificate }

constructor TMbedTLSCertificate.Create;
begin
  inherited Create;
  FX509Crt := nil;
  FPEMData := '';
  SetLength(FDERData, 0);
  FIssuerCert := nil;
  FOwnsHandle := True;
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;
end;

constructor TMbedTLSCertificate.Create(ACrt: Pmbedtls_x509_crt; AOwnsHandle: Boolean);
begin
  Create;
  FX509Crt := ACrt;
  FOwnsHandle := AOwnsHandle;
end;

destructor TMbedTLSCertificate.Destroy;
begin
  if FOwnsHandle then
    FreeCertificate;
  FIssuerCert := nil;
  inherited Destroy;
end;

procedure TMbedTLSCertificate.AllocateCertificate;
begin
  if FX509Crt <> nil then
    FreeCertificate;

  GetMem(FX509Crt, MBEDTLS_X509_CRT_SIZE);
  FillChar(FX509Crt^, MBEDTLS_X509_CRT_SIZE, 0);

  if Assigned(mbedtls_x509_crt_init) then
    mbedtls_x509_crt_init(FX509Crt);

  FOwnsHandle := True;
end;

procedure TMbedTLSCertificate.ResetLoadedState;
begin
  FPEMData := '';
  SetLength(FDERData, 0);
  FIssuerCert := nil;
  Finalize(FInfo);
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.PathLenConstraint := -1;
  FInfo.PathLength := -1;

  if FX509Crt <> nil then
  begin
    if FOwnsHandle then
      FreeCertificate
    else
      FX509Crt := nil;
  end;

  FOwnsHandle := True;
end;

procedure TMbedTLSCertificate.FreeCertificate;
begin
  if FX509Crt <> nil then
  begin
    if Assigned(mbedtls_x509_crt_free) then
      mbedtls_x509_crt_free(FX509Crt);
    FreeMem(FX509Crt);
    FX509Crt := nil;
  end;
end;

function TMbedTLSCertificate.TryLoadX509Parser(
  out AParser: TX509Certificate): Boolean;
var
  LDER: TBytes;
begin
  AParser := nil;
  Result := False;

  if FX509Crt = nil then
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
    FreeAndNil(AParser);
    Result := False;
  end;
end;

function TMbedTLSCertificate.TryGetParsedAlgorithmMetadata(
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

function TMbedTLSCertificate.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := False;
  if not FileExists(AFileName) then Exit;
  if not Assigned(mbedtls_x509_crt_parse_file) then Exit;

  FPEMData := '';
  SetLength(FDERData, 0);
  AllocateCertificate;

  if mbedtls_x509_crt_parse_file(FX509Crt, PAnsiChar(AnsiString(AFileName))) = 0 then
    Result := True
  else
    FreeCertificate;
end;

function TMbedTLSCertificate.LoadFromStream(AStream: TStream): Boolean;
var
  LData: TBytes;
begin
  Result := False;
  ResetLoadedState;
  if AStream = nil then Exit;

  SetLength(LData, AStream.Size - AStream.Position);
  if Length(LData) = 0 then Exit;

  AStream.ReadBuffer(LData[0], Length(LData));
  Result := LoadFromMemory(@LData[0], Length(LData));
end;

function TMbedTLSCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
var
  LRaw: TBytes;
  LText: string;
  LPEMBuffer: TBytes;
begin
  Result := False;
  ResetLoadedState;
  if (AData = nil) or (ASize <= 0) then Exit;
  if not Assigned(mbedtls_x509_crt_parse) then Exit;

  SetLength(LRaw, ASize);
  Move(AData^, LRaw[0], ASize);
  AllocateCertificate;

  SetString(LText, PAnsiChar(@LRaw[0]), Length(LRaw));
  if TSSLUtils.IsPEMFormat(LText) then
  begin
    SetLength(LPEMBuffer, Length(LRaw) + 1);
    Move(LRaw[0], LPEMBuffer[0], Length(LRaw));
    LPEMBuffer[High(LPEMBuffer)] := 0;

    if mbedtls_x509_crt_parse(FX509Crt, @LPEMBuffer[0], Length(LPEMBuffer)) = 0 then
    begin
      FPEMData := LText;
      Result := True;
    end
    else
      FreeCertificate;
  end
  else if mbedtls_x509_crt_parse(FX509Crt, @LRaw[0], Length(LRaw)) = 0 then
  begin
    FDERData := Copy(LRaw);
    Result := True;
  end
  else
    FreeCertificate;
end;

function TMbedTLSCertificate.LoadFromPEM(const APEM: string): Boolean;
var
  LAnsi: AnsiString;
begin
  Result := False;
  ResetLoadedState;
  if APEM = '' then Exit;

  LAnsi := AnsiString(APEM);
  // MbedTLS PEM 解析需要 null 终止
  Result := LoadFromMemory(PAnsiChar(LAnsi), Length(LAnsi) + 1);
  if Result then
    FPEMData := APEM;
end;

function TMbedTLSCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  Result := False;
  ResetLoadedState;
  if Length(ADER) = 0 then Exit;

  Result := LoadFromMemory(@ADER[0], Length(ADER));
  if Result then
    FDERData := Copy(ADER);
end;

function TMbedTLSCertificate.SaveToFile(const AFileName: string): Boolean;
var
  LStream: TFileStream;
begin
  Result := False;
  if FX509Crt = nil then Exit;

  try
    LStream := TFileStream.Create(AFileName, fmCreate);
    try
      Result := SaveToStream(LStream);
    finally
    end;
  except
    Result := False;
  end;
end;

function TMbedTLSCertificate.SaveToStream(AStream: TStream): Boolean;
var
  LPEM: string;
begin
  Result := False;
  if (AStream = nil) or (FX509Crt = nil) then Exit;

  LPEM := SaveToPEM;
  if LPEM <> '' then
  begin
    AStream.WriteBuffer(LPEM[1], Length(LPEM));
    Result := True;
  end;
end;

function TMbedTLSCertificate.SaveToPEM: string;
var
  LDER: TBytes;
  LBase64: string;
  LLine: string;
  LPos, LLineLen: Integer;
begin
  // Return cached PEM if available
  if FPEMData <> '' then
  begin
    Result := FPEMData;
    Exit;
  end;

  // Convert DER to PEM
  LDER := SaveToDER;
  if Length(LDER) = 0 then
  begin
    Result := '';
    Exit;
  end;

  // Encode to Base64
  LBase64 := TBase64Utils.Encode(LDER);
  if LBase64 = '' then
  begin
    Result := '';
    Exit;
  end;

  // Build PEM format with 64-char line wrapping
  Result := '-----BEGIN CERTIFICATE-----' + LineEnding;
  LPos := 1;
  LLineLen := 64;
  while LPos <= Length(LBase64) do
  begin
    if LPos + LLineLen - 1 <= Length(LBase64) then
      LLine := Copy(LBase64, LPos, LLineLen)
    else
      LLine := Copy(LBase64, LPos, Length(LBase64) - LPos + 1);
    Result := Result + LLine + LineEnding;
    Inc(LPos, LLineLen);
  end;
  Result := Result + '-----END CERTIFICATE-----' + LineEnding;

  // Cache the result
  FPEMData := Result;
end;

function TMbedTLSCertificate.SaveToDER: TBytes;
begin
  // Return cached DER if available
  if Length(FDERData) > 0 then
  begin
    Result := Copy(FDERData);
    Exit;
  end;

  // Extract DER from native handle
  SetLength(Result, 0);
  if FX509Crt = nil then Exit;

  // Access raw DER data from MbedTLS certificate structure
  if (FX509Crt^.raw.p <> nil) and (FX509Crt^.raw.len > 0) then
  begin
    SetLength(Result, FX509Crt^.raw.len);
    Move(FX509Crt^.raw.p^, Result[0], FX509Crt^.raw.len);
    // Cache the result
    FDERData := Copy(Result);
  end;
end;

function TMbedTLSCertificate.GetInfo: TSSLCertificateInfo;
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

function TMbedTLSCertificate.GetSubject: string;
var
  LParser: TX509Certificate;
  LBuf: array[0..2047] of AnsiChar;
  LLen: Integer;
begin
  Result := '';
  if FX509Crt = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Subject.ToString;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if not Assigned(mbedtls_x509_crt_info) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := mbedtls_x509_crt_info(@LBuf[0], SizeOf(LBuf), '', FX509Crt);
  if LLen > 0 then
  begin
    // Parse subject from info output
    Result := ExtractField(string(LBuf), 'subject');
    if Result = '' then
      Result := 'Subject';  // Fallback
  end
  else
    Result := 'Subject';
end;

function TMbedTLSCertificate.GetIssuer: string;
var
  LParser: TX509Certificate;
  LBuf: array[0..2047] of AnsiChar;
  LLen: Integer;
begin
  Result := '';
  if FX509Crt = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Issuer.ToString;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if not Assigned(mbedtls_x509_crt_info) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := mbedtls_x509_crt_info(@LBuf[0], SizeOf(LBuf), '', FX509Crt);
  if LLen > 0 then
  begin
    // Parse issuer from info output
    Result := ExtractField(string(LBuf), 'issuer');
    if Result = '' then
      Result := 'Issuer';  // Fallback
  end
  else
    Result := 'Issuer';
end;

function TMbedTLSCertificate.GetSerialNumber: string;
var
  LParser: TX509Certificate;
  LBuf: array[0..4095] of AnsiChar;
  LLen: Integer;
  LInfo: string;
  LPos, LEndPos: Integer;
begin
  Result := '';
  if FX509Crt = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.SerialNumberAsHex;
      if Result <> '' then
        Exit;
    finally
    end;
  end;

  if not Assigned(mbedtls_x509_crt_info) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := mbedtls_x509_crt_info(@LBuf[0], SizeOf(LBuf), '', FX509Crt);
  if LLen <= 0 then Exit;

  LInfo := string(LBuf);
  // 查找 "serial number" 行
  LPos := Pos('serial number', LowerCase(LInfo));
  if LPos > 0 then
  begin
    // 找到冒号后的内容
    LPos := Pos(':', Copy(LInfo, LPos, Length(LInfo)));
    if LPos > 0 then
    begin
      LPos := Pos('serial number', LowerCase(LInfo)) + LPos;
      // 跳过空白
      while (LPos <= Length(LInfo)) and (LInfo[LPos] in [' ', #9, ':']) do
        Inc(LPos);
      // 找到行尾
      LEndPos := LPos;
      while (LEndPos <= Length(LInfo)) and not (LInfo[LEndPos] in [#10, #13]) do
        Inc(LEndPos);
      Result := Trim(Copy(LInfo, LPos, LEndPos - LPos));
    end;
  end;

  if Result = '' then
    Result := '0';
end;

function ParseMbedTLSDate(const ADateStr: string): TDateTime;
var
  LYear, LMonth, LDay, LHour, LMin, LSec: Word;
  LDatePart, LTimePart: string;
  LPos: Integer;
begin
  Result := 0;
  // MbedTLS 日期格式: "2024-01-15 12:30:45" 或 "Jan 15 12:30:45 2024 GMT"
  if ADateStr = '' then Exit;

  // 尝试解析 YYYY-MM-DD HH:MM:SS 格式
  LPos := Pos(' ', ADateStr);
  if LPos > 0 then
  begin
    LDatePart := Copy(ADateStr, 1, LPos - 1);
    LTimePart := Copy(ADateStr, LPos + 1, Length(ADateStr));

    // 解析日期部分
    if (Length(LDatePart) >= 10) and (LDatePart[5] = '-') and (LDatePart[8] = '-') then
    begin
      try
        LYear := StrToIntDef(Copy(LDatePart, 1, 4), 0);
        LMonth := StrToIntDef(Copy(LDatePart, 6, 2), 0);
        LDay := StrToIntDef(Copy(LDatePart, 9, 2), 0);

        // 解析时间部分
        LHour := 0; LMin := 0; LSec := 0;
        if (Length(LTimePart) >= 8) and (LTimePart[3] = ':') then
        begin
          LHour := StrToIntDef(Copy(LTimePart, 1, 2), 0);
          LMin := StrToIntDef(Copy(LTimePart, 4, 2), 0);
          LSec := StrToIntDef(Copy(LTimePart, 7, 2), 0);
        end;

        if (LYear > 0) and (LMonth in [1..12]) and (LDay in [1..31]) then
          Result := EncodeDate(LYear, LMonth, LDay) + EncodeTime(LHour, LMin, LSec, 0);
      except
        Result := 0;
      end;
    end;
  end;
end;

function TMbedTLSCertificate.GetNotBefore: TDateTime;
var
  LParser: TX509Certificate;
  LBuf: array[0..4095] of AnsiChar;
  LLen: Integer;
  LInfo, LDateStr: string;
  LPos, LEndPos: Integer;
begin
  Result := 0;
  if FX509Crt = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Validity.NotBefore;
      if Result > 0 then
        Exit;
    finally
    end;
  end;

  if not Assigned(mbedtls_x509_crt_info) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := mbedtls_x509_crt_info(@LBuf[0], SizeOf(LBuf), '', FX509Crt);
  if LLen <= 0 then Exit;

  LInfo := string(LBuf);
  // 查找 "issued on" 或 "not before"
  LPos := Pos('issued  on', LowerCase(LInfo));
  if LPos = 0 then
    LPos := Pos('not before', LowerCase(LInfo));

  if LPos > 0 then
  begin
    // 找到冒号后的内容
    LPos := LPos + 10;  // 跳过 "issued  on" 或 "not before"
    while (LPos <= Length(LInfo)) and (LInfo[LPos] in [' ', #9, ':']) do
      Inc(LPos);
    // 找到行尾
    LEndPos := LPos;
    while (LEndPos <= Length(LInfo)) and not (LInfo[LEndPos] in [#10, #13]) do
      Inc(LEndPos);
    LDateStr := Trim(Copy(LInfo, LPos, LEndPos - LPos));

    if LDateStr <> '' then
      Result := ParseMbedTLSDate(LDateStr);
  end;
end;

function TMbedTLSCertificate.GetNotAfter: TDateTime;
var
  LParser: TX509Certificate;
  LBuf: array[0..4095] of AnsiChar;
  LLen: Integer;
  LInfo, LDateStr: string;
  LPos, LEndPos: Integer;
begin
  Result := 0;
  if FX509Crt = nil then Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := LParser.Validity.NotAfter;
      if Result > 0 then
        Exit;
    finally
    end;
  end;

  if not Assigned(mbedtls_x509_crt_info) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  LLen := mbedtls_x509_crt_info(@LBuf[0], SizeOf(LBuf), '', FX509Crt);
  if LLen <= 0 then Exit;

  LInfo := string(LBuf);
  // 查找 "expires on" 或 "not after"
  LPos := Pos('expires on', LowerCase(LInfo));
  if LPos = 0 then
    LPos := Pos('not after', LowerCase(LInfo));

  if LPos > 0 then
  begin
    // 找到冒号后的内容
    LPos := LPos + 10;  // 跳过 "expires on" 或 "not after"
    while (LPos <= Length(LInfo)) and (LInfo[LPos] in [' ', #9, ':']) do
      Inc(LPos);
    // 找到行尾
    LEndPos := LPos;
    while (LEndPos <= Length(LInfo)) and not (LInfo[LEndPos] in [#10, #13]) do
      Inc(LEndPos);
    LDateStr := Trim(Copy(LInfo, LPos, LEndPos - LPos));

    if LDateStr <> '' then
      Result := ParseMbedTLSDate(LDateStr);
  end;
end;

function TMbedTLSCertificate.GetPublicKey: string;
begin
  Result := GetPublicKeyAlgorithm;
end;

function TMbedTLSCertificate.GetPublicKeyAlgorithm: string;
var
  LSignatureAlgorithm: string;
begin
  if TryGetParsedAlgorithmMetadata(Result, LSignatureAlgorithm) and (Result <> '') then
    Exit;

  Result := 'RSA';  // 默认
end;

function TMbedTLSCertificate.GetSignatureAlgorithm: string;
var
  LPublicKeyAlgorithm: string;
begin
  if TryGetParsedAlgorithmMetadata(LPublicKeyAlgorithm, Result) and (Result <> '') then
    Exit;

  Result := 'SHA256withRSA';  // 默认
end;

function TMbedTLSCertificate.GetVersion: Integer;
var
  LParser: TX509Certificate;
begin
  Result := 3;  // X.509 v3 默认值
  if FX509Crt = nil then
    Exit;

  if TryLoadX509Parser(LParser) then
  begin
    try
      Result := Ord(LParser.Version) + 1;
      Exit;
    finally
    end;
  end;
end;

function TMbedTLSCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
var
  LFlags: Cardinal;
  LCACerts: Pmbedtls_x509_crt;
begin
  Result := False;
  if FX509Crt = nil then Exit;
  if ACAStore = nil then Exit;
  if not Assigned(mbedtls_x509_crt_verify) then Exit;

  LCACerts := Pmbedtls_x509_crt(GetNativeHandleSafe(ACAStore, 'TMbedTLSCertificate.Verify'));
  if LCACerts = nil then Exit;

  LFlags := 0;
  Result := mbedtls_x509_crt_verify(FX509Crt, LCACerts, nil, nil, @LFlags, nil, nil) = 0;
end;

function TMbedTLSCertificate.VerifyEx(ACAStore: ISSLCertificateStore;
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
var
  LFlags: Cardinal;
  LEffectiveFlags: Cardinal;
  LIgnoredFlags: Cardinal;
  LCACerts: Pmbedtls_x509_crt;
  LVerifyStatus: Integer;
  LExtendedKeyUsage: TSSLStringArray;
  I: Integer;
  LHasServerAuth: Boolean;
  LErrorMessage: string;
begin
  ResetCertVerifyResult(AResult);
  Result := False;

  if FX509Crt = nil then
  begin
    AResult.ErrorCode := 1;
    AResult.ErrorMessage := 'Certificate not loaded';
    AResult.DetailedInfo := 'MbedTLS VerifyEx requires a loaded certificate';
    Exit;
  end;

  if ACAStore = nil then
  begin
    AResult.ErrorCode := 2;
    AResult.ErrorMessage := 'CA store is nil';
    AResult.DetailedInfo := 'MbedTLS VerifyEx requires a configured certificate store';
    Exit;
  end;

  if not Assigned(mbedtls_x509_crt_verify) then
  begin
    AResult.ErrorCode := 3;
    AResult.ErrorMessage := 'mbedtls_x509_crt_verify not available';
    AResult.DetailedInfo := 'MbedTLS X.509 verification API is unavailable';
    Exit;
  end;

  LCACerts := Pmbedtls_x509_crt(GetNativeHandleSafe(ACAStore, 'TMbedTLSCertificate.VerifyEx'));
  if LCACerts = nil then
  begin
    AResult.ErrorCode := 4;
    AResult.ErrorMessage := 'Invalid CA store handle';
    AResult.DetailedInfo := 'MbedTLS VerifyEx requires a native CA store handle';
    Exit;
  end;

  LFlags := 0;
  LEffectiveFlags := 0;
  LIgnoredFlags := 0;
  LVerifyStatus := mbedtls_x509_crt_verify(FX509Crt, LCACerts, nil, nil, @LFlags, nil, nil);
  LEffectiveFlags := LFlags;

  if LVerifyStatus <> 0 then
  begin
    if sslCertVerifyIgnoreExpiry in AFlags then
    begin
      LIgnoredFlags := LIgnoredFlags or
        (LEffectiveFlags and (MBEDTLS_X509_BADCERT_EXPIRED or MBEDTLS_X509_BADCERT_FUTURE));
      LEffectiveFlags := LEffectiveFlags and
        not (MBEDTLS_X509_BADCERT_EXPIRED or MBEDTLS_X509_BADCERT_FUTURE);
    end;

    if (sslCertVerifyAllowSelfSigned in AFlags) and IsSelfSigned then
    begin
      LIgnoredFlags := LIgnoredFlags or
        (LEffectiveFlags and MBEDTLS_X509_BADCERT_NOT_TRUSTED);
      LEffectiveFlags := LEffectiveFlags and not MBEDTLS_X509_BADCERT_NOT_TRUSTED;
    end;
  end;

  if (LVerifyStatus = 0) or ((LFlags <> 0) and (LEffectiveFlags = 0)) then
  begin
    if sslCertVerifyStrictChain in AFlags then
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
        AResult.ErrorCode := 5;
        AResult.ChainStatus := 2;
        AResult.ErrorMessage := 'Strict chain verification requires serverAuth extended key usage';
        AResult.DetailedInfo :=
          'sslCertVerifyStrictChain requested but the leaf certificate is missing serverAuth extended key usage';
        Exit;
      end;
    end;

    if (sslCertVerifyCheckRevocation in AFlags) or
      (sslCertVerifyCheckCRL in AFlags) or
      (sslCertVerifyCheckOCSP in AFlags) then
    begin
      AResult.ErrorCode := 6;
      AResult.RevocationStatus := 2;
      AResult.ErrorMessage := 'Certificate revocation verification is unavailable';
      AResult.DetailedInfo :=
        'MbedTLS VerifyEx has no OCSP/CRL revocation material for sslCertVerifyCheckRevocation/sslCertVerifyCheckCRL/sslCertVerifyCheckOCSP';
      Exit;
    end;

    AResult.Success := True;
    if LIgnoredFlags <> 0 then
      AResult.DetailedInfo := Format(
        'MbedTLS certificate verification passed after applying VerifyEx flag exceptions (native flags=%u, ignored=%u)',
        [LFlags, LIgnoredFlags])
    else
      AResult.DetailedInfo := 'MbedTLS certificate verification passed';
    Result := True;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorCode := Integer(LEffectiveFlags);
    if AResult.ErrorCode = 0 then
      AResult.ErrorCode := LVerifyStatus;
    AResult.ChainStatus := 1;
    LErrorMessage := GetMbedTLSVerifyInfoString(LEffectiveFlags);
    if LErrorMessage = '' then
      LErrorMessage := GetMbedTLSVerifyInfoString(LFlags);
    if LErrorMessage = '' then
      LErrorMessage := 'Certificate verification failed';
    if ((LEffectiveFlags and MBEDTLS_X509_BADCERT_NOT_TRUSTED) <> 0) and
      (Pos('not trusted', LowerCase(LErrorMessage)) = 0) then
      LErrorMessage := Trim(LErrorMessage + ' (not trusted)');
    AResult.ErrorMessage := LErrorMessage;
    if LIgnoredFlags <> 0 then
      AResult.DetailedInfo := Format(
        'MbedTLS verification flags: native=%u effective=%u ignored=%u',
        [LFlags, LEffectiveFlags, LIgnoredFlags])
    else
      AResult.DetailedInfo := Format('MbedTLS verification flags: %u', [LEffectiveFlags]);
  end;
end;

function TMbedTLSCertificate.VerifyHostname(const AHostname: string): Boolean;
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

  if (FX509Crt = nil) or (AHostname = '') then
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

function TMbedTLSCertificate.IsExpired: Boolean;
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

function TMbedTLSCertificate.IsSelfSigned: Boolean;
begin
  Result := GetSubject = GetIssuer;
end;

function TMbedTLSCertificate.IsCA: Boolean;
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

function TMbedTLSCertificate.GetDaysUntilExpiry: Integer;
var
  LNotAfter: TDateTime;
begin
  LNotAfter := GetNotAfter;
  if LNotAfter <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  Result := DaysBetween(Now, LNotAfter);
  if IsExpired then
    Result := -Result;
end;

function TMbedTLSCertificate.GetSubjectCN: string;
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

function TMbedTLSCertificate.GetExtension(const AOID: string): string;
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

function TMbedTLSCertificate.GetSubjectAltNames: TSSLStringArray;
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

function TMbedTLSCertificate.GetKeyUsage: TSSLStringArray;
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

function TMbedTLSCertificate.GetExtendedKeyUsage: TSSLStringArray;
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

function TMbedTLSCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  Result := '';
  case AHashType of
    sslHashSHA1: Result := GetFingerprintSHA1;
    sslHashSHA256: Result := GetFingerprintSHA256;
  else
    Result := GetFingerprintSHA256; // 默认使用 SHA256
  end;
end;

function TMbedTLSCertificate.GetFingerprintSHA1: string;
var
  LMdInfo: Pointer;
  LHash: array[0..19] of Byte;  // SHA1 = 20 bytes
  I: Integer;
  LDERData: PByte;
  LDERLen: Integer;
begin
  Result := '';
  if FX509Crt = nil then Exit;
  if not Assigned(mbedtls_md_info_from_type) then Exit;
  if not Assigned(mbedtls_md) then Exit;

  // Get DER data - prefer cached, fallback to native handle
  if Length(FDERData) > 0 then
  begin
    LDERData := @FDERData[0];
    LDERLen := Length(FDERData);
  end
  else if (FX509Crt^.raw.p <> nil) and (FX509Crt^.raw.len > 0) then
  begin
    LDERData := FX509Crt^.raw.p;
    LDERLen := FX509Crt^.raw.len;
  end
  else
    Exit;

  LMdInfo := mbedtls_md_info_from_type(MBEDTLS_MD_SHA1);
  if LMdInfo = nil then Exit;

  FillChar(LHash, SizeOf(LHash), 0);
  if mbedtls_md(LMdInfo, LDERData, LDERLen, @LHash[0]) = 0 then
  begin
    for I := 0 to 19 do
      Result := Result + IntToHex(LHash[I], 2);
  end;
end;

function TMbedTLSCertificate.GetFingerprintSHA256: string;
var
  LMdInfo: Pointer;
  LHash: array[0..31] of Byte;  // SHA256 = 32 bytes
  I: Integer;
  LDERData: PByte;
  LDERLen: Integer;
begin
  Result := '';
  if FX509Crt = nil then Exit;
  if not Assigned(mbedtls_md_info_from_type) then Exit;
  if not Assigned(mbedtls_md) then Exit;

  // Get DER data - prefer cached, fallback to native handle
  if Length(FDERData) > 0 then
  begin
    LDERData := @FDERData[0];
    LDERLen := Length(FDERData);
  end
  else if (FX509Crt^.raw.p <> nil) and (FX509Crt^.raw.len > 0) then
  begin
    LDERData := FX509Crt^.raw.p;
    LDERLen := FX509Crt^.raw.len;
  end
  else
    Exit;

  LMdInfo := mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  if LMdInfo = nil then Exit;

  FillChar(LHash, SizeOf(LHash), 0);
  if mbedtls_md(LMdInfo, LDERData, LDERLen, @LHash[0]) = 0 then
  begin
    for I := 0 to 31 do
      Result := Result + IntToHex(LHash[I], 2);
  end;
end;

procedure TMbedTLSCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCert := ACert;
end;

function TMbedTLSCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCert;
end;

function TMbedTLSCertificate.GetNativeHandle: Pointer;
begin
  Result := FX509Crt;
end;

function TMbedTLSCertificate.GetBackendType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSCertificate.IsNativeHandleValid: Boolean;
begin
  Result := (FX509Crt <> nil);
end;

function TMbedTLSCertificate.Clone: ISSLCertificate;
var
  LClone: TMbedTLSCertificate;
  LDER: TBytes;
begin
  Result := nil;
  LClone := TMbedTLSCertificate.Create;
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

{ TMbedTLSCertificateStore }

constructor TMbedTLSCertificateStore.Create;
begin
  inherited Create;
  FCACerts := nil;
  FCertificates := TInterfaceList.Create;
  AllocateStore;
end;

destructor TMbedTLSCertificateStore.Destroy;
begin
  Clear;
  FreeStore;
  inherited Destroy;
end;

procedure TMbedTLSCertificateStore.AllocateStore;
begin
  if FCACerts <> nil then
    FreeStore;

  GetMem(FCACerts, MBEDTLS_X509_CRT_SIZE);
  FillChar(FCACerts^, MBEDTLS_X509_CRT_SIZE, 0);

  if Assigned(mbedtls_x509_crt_init) then
    mbedtls_x509_crt_init(FCACerts);
end;

procedure TMbedTLSCertificateStore.FreeStore;
begin
  if FCACerts <> nil then
  begin
    if Assigned(mbedtls_x509_crt_free) then
      mbedtls_x509_crt_free(FCACerts);
    FreeMem(FCACerts);
    FCACerts := nil;
  end;
end;

function NormalizeMbedTLSCertFingerprint(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
  Result := StringReplace(Result, ':', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function TMbedTLSCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
var
  LTarget: string;
  LDER: TBytes;
begin
  Result := False;
  if ACert = nil then Exit;
  if Contains(ACert) then Exit;

  LTarget := NormalizeMbedTLSCertFingerprint(ACert.GetFingerprintSHA256);
  if (LTarget <> '') and (FindByFingerprint(LTarget) <> nil) then
    Exit;

  if FCACerts = nil then
    AllocateStore;

  LDER := ACert.SaveToDER;
  if (Length(LDER) > 0) and Assigned(mbedtls_x509_crt_parse) then
  begin
    if mbedtls_x509_crt_parse(FCACerts, @LDER[0], Length(LDER)) <> 0 then
      Exit(False);
  end;

  FCertificates.Add(ACert);
  Result := True;
end;

function TMbedTLSCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
var
  LIndex: Integer;
  LTarget: string;
  I: Integer;
  LExisting: ISSLCertificate;
begin
  Result := False;
  if ACert = nil then Exit;

  LIndex := FCertificates.IndexOf(ACert);
  if LIndex < 0 then
  begin
    LTarget := NormalizeMbedTLSCertFingerprint(ACert.GetFingerprintSHA256);
    if LTarget = '' then
      LTarget := NormalizeMbedTLSCertFingerprint(ACert.GetFingerprintSHA1);

    if LTarget <> '' then
    begin
      for I := 0 to Length(FCertificates) - 1 do
      begin
        LExisting := FCertificates[I] as ISSLCertificate;
        if NormalizeMbedTLSCertFingerprint(LExisting.GetFingerprintSHA256) = LTarget then
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

function TMbedTLSCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
var
  LTarget: string;
  I: Integer;
  LExisting: ISSLCertificate;
begin
  Result := False;
  if ACert = nil then
    Exit;

  if FCertificates.IndexOf(ACert) >= 0 then
    Exit(True);

  LTarget := NormalizeMbedTLSCertFingerprint(ACert.GetFingerprintSHA256);
  if LTarget = '' then
    LTarget := NormalizeMbedTLSCertFingerprint(ACert.GetFingerprintSHA1);
  if LTarget = '' then
    Exit(False);

  for I := 0 to Length(FCertificates) - 1 do
  begin
    LExisting := FCertificates[I] as ISSLCertificate;
    if NormalizeMbedTLSCertFingerprint(LExisting.GetFingerprintSHA256) = LTarget then
      Exit(True);
  end;
end;

procedure TMbedTLSCertificateStore.Clear;
begin
  FCertificates.Clear;
end;

function TMbedTLSCertificateStore.GetCount: Integer;
begin
  Result := Length(FCertificates);
end;

function TMbedTLSCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < Length(FCertificates)) then
    Result := FCertificates[AIndex] as ISSLCertificate;
end;

function TMbedTLSCertificateStore.LoadFromFile(const AFileName: string): Boolean;
var
  LCert: TMbedTLSCertificate;
begin
  Result := False;
  if not FileExists(AFileName) then Exit;

  LCert := TMbedTLSCertificate.Create;
  try
    if LCert.LoadFromFile(AFileName) then
    begin
      FCertificates.Add(LCert);
      Result := True;
    end;
  except
    raise;
  end;
end;

function TMbedTLSCertificateStore.LoadFromPath(const APath: string): Boolean;
var
  LCount: Integer;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit;

  LCount := 0;

  // 使用 MbedTLS 的路径加载功能
  if FCACerts = nil then
    AllocateStore;

  if Assigned(mbedtls_x509_crt_parse_path) then
  begin
    if mbedtls_x509_crt_parse_path(FCACerts, PAnsiChar(AnsiString(APath))) >= 0 then
      Inc(LCount);
  end;

  Result := LCount > 0;
end;

function TMbedTLSCertificateStore.LoadSystemStore: Boolean;
begin
  Result := False;
  {$IFDEF LINUX}
  if DirectoryExists('/etc/ssl/certs') then
    Result := LoadFromPath('/etc/ssl/certs')
  else if DirectoryExists('/etc/pki/tls/certs') then
    Result := LoadFromPath('/etc/pki/tls/certs');
  {$ENDIF}
  {$IFDEF DARWIN}
  if FileExists('/etc/ssl/cert.pem') then
    Result := LoadFromFile('/etc/ssl/cert.pem');
  {$ENDIF}
end;

function TMbedTLSCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeMbedTLSCertText(ASubject);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if Pos(LTarget, NormalizeMbedTLSCertText(LCert.GetSubject)) > 0 then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TMbedTLSCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeMbedTLSCertText(AIssuer);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if Pos(LTarget, NormalizeMbedTLSCertText(LCert.GetIssuer)) > 0 then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TMbedTLSCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeMbedTLSCertHex(ASerialNumber);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if NormalizeMbedTLSCertHex(LCert.GetSerialNumber) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TMbedTLSCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
var
  I: Integer;
  LCert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeMbedTLSCertFingerprint(AFingerprint);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    LCert := FCertificates[I] as ISSLCertificate;
    if NormalizeMbedTLSCertFingerprint(LCert.GetFingerprintSHA256) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;

    if NormalizeMbedTLSCertFingerprint(LCert.GetFingerprintSHA1) = LTarget then
    begin
      Result := LCert;
      Exit;
    end;
  end;
end;

function TMbedTLSCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := False;
  if ACert = nil then Exit;
  Result := ACert.Verify(Self);
end;

function TMbedTLSCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
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
  LMaxDepth := 10;

  while (LCurrent <> nil) and (Length(LChain) < LMaxDepth) do
  begin
    SetLength(LChain, Length(LChain) + 1);
    LChain[High(LChain)] := LCurrent;

    if LCurrent.IsSelfSigned then
      Break;

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

      if NormalizeMbedTLSCertFingerprint(LChain[I].GetFingerprintSHA256) =
        NormalizeMbedTLSCertFingerprint(LNext.GetFingerprintSHA256) then
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

function TMbedTLSCertificateStore.GetNativeHandle: Pointer;
begin
  Result := FCACerts;
end;

function TMbedTLSCertificateStore.GetBackendType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSCertificateStore.IsNativeHandleValid: Boolean;
begin
  Result := (FCACerts <> nil);
end;

end.
