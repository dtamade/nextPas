{**
 * nextpas.core.tls.dane - DANE (DNS-based Authentication of Named Entities) Support
 *
 * Implements RFC 6698 DANE TLSA for DNS-based certificate authentication.
 * Provides an additional layer of security by validating certificates against
 * DNS TLSA records published in DNSSEC-signed zones.
 *
 * ldns 库是可选依赖。如果 ldns 不可用：
 * - QueryTLSARecords 返回 False 并记录警告
 * - VerifyDNSSEC 返回 False
 * - GetDNSSECStatus 返回 "ldns library not available"
 *
 * @author fafafa.ssl team
 * @version 1.1.0
 * @since 2026-01-31
 *}
unit nextpas.core.tls.dane;

{$mode objfpc}{$H+}

interface

uses nextpas.core.text.conv, nextpas.core.tls.base, nextpas.core.tls.openssl.base;

type
  {**
   * DANE TLSA Certificate Usage
   * RFC 6698 Section 2.1.1
   *}
  TDANEUsage = (
    duCAConstraint = 0,        // CA constraint (PKIX-TA)
    duServiceCertConstraint = 1, // Service certificate constraint (PKIX-EE)
    duTrustAnchorAssertion = 2,  // Trust anchor assertion (DANE-TA)
    duDomainIssuedCert = 3       // Domain-issued certificate (DANE-EE)
  );

  {**
   * DANE TLSA Selector
   * RFC 6698 Section 2.1.2
   *}
  TDANESelector = (
    dsFullCertificate = 0,  // Full certificate
    dsSubjectPublicKeyInfo = 1  // SubjectPublicKeyInfo (SPKI)
  );

  {**
   * DANE TLSA Matching Type
   * RFC 6698 Section 2.1.3
   *}
  TDANEMatchingType = (
    dmExact = 0,      // Exact match (no hash)
    dmSHA256 = 1,     // SHA-256 hash
    dmSHA512 = 2      // SHA-512 hash
  );

  {**
   * DANE TLSA Record
   * Represents a single TLSA record from DNS
   *}
  TDANETLSARecord = record
    Usage: TDANEUsage;
    Selector: TDANESelector;
    MatchingType: TDANEMatchingType;
    CertificateData: TBytes;  // Certificate or hash data
    TTL: Integer;             // Time to live
    Retrieved: TDateTime;     // When record was retrieved
  end;

  {**
   * DANE Validation Result
   *}
  TDANEValidationResult = record
    Success: Boolean;
    MatchedRecord: TDANETLSARecord;
    MatchedRecordIndex: Integer;
    ErrorMessage: string;
    DNSSECValid: Boolean;
    RecordsFound: Integer;
  end;

  {**
   * DANE TLSA Validator
   * Validates certificates against DNS TLSA records
   *}
  TDANEValidator = class
  private
    FRecords: array of TDANETLSARecord;
    FDomain: string;
    FPort: Word;
    FRequireDNSSEC: Boolean;
    FEnableCache: Boolean;
    FCacheTimeout: Integer;  // Seconds
    FLastDNSSECStatus: string;

    function ExtractCertificateData(ACert: PX509; ASelector: TDANESelector): TBytes;
    function HashData(const AData: TBytes; AMatchingType: TDANEMatchingType): TBytes;
    function CompareData(const AData1, AData2: TBytes): Boolean;
    function ValidateAgainstRecord(ACert: PX509; const ARecord: TDANETLSARecord): Boolean;
    function IsCacheValid(const ARecord: TDANETLSARecord): Boolean;

  public
    constructor Create(const ADomain: string; APort: Word);
    destructor Destroy; override;

    {** Query DNS for TLSA records
        @param ADomain Domain name
        @param APort Port number
        @returns True if records were found *}
    function QueryTLSARecords(const ADomain: string; APort: Word): Boolean;

    {** Add a TLSA record manually (for testing or caching)
        @param AUsage Certificate usage
        @param ASelector Selector type
        @param AMatchingType Matching type
        @param AData Certificate data or hash *}
    procedure AddTLSARecord(AUsage: TDANEUsage; ASelector: TDANESelector;
      AMatchingType: TDANEMatchingType; const AData: TBytes);

    {** Validate certificate against TLSA records
        @param ACert Certificate to validate
        @returns True if certificate matches any TLSA record *}
    function ValidateCertificate(ACert: PX509): Boolean;

    {** Validate certificate with detailed result
        @param ACert Certificate to validate
        @param AResult Detailed validation result
        @returns True if certificate matches any TLSA record *}
    function ValidateCertificateEx(ACert: PX509; out AResult: TDANEValidationResult): Boolean;

    {** Validate certificate chain against TLSA records
        @param ACertChain Array of certificates in chain
        @returns True if any certificate in chain matches *}
    function ValidateCertificateChain(const ACertChain: array of PX509): Boolean;

    {** Clear all cached TLSA records *}
    procedure ClearRecords;

    {** Get number of TLSA records
        @returns Number of records *}
    function GetRecordCount: Integer;

    {** Get TLSA record information as string
        @returns Human-readable record information *}
    function GetRecordInfo: string;

    {** Domain name for TLSA lookup *}
    property Domain: string read FDomain write FDomain;

    {** Port number for TLSA lookup *}
    property Port: Word read FPort write FPort;

    {** Require DNSSEC validation
        If True, TLSA records without valid DNSSEC will be rejected
        Default: True *}
    property RequireDNSSEC: Boolean read FRequireDNSSEC write FRequireDNSSEC;

    {** Enable TLSA record caching
        Default: True *}
    property EnableCache: Boolean read FEnableCache write FEnableCache;

    {** Cache timeout in seconds
        Default: 3600 (1 hour) *}
    property CacheTimeout: Integer read FCacheTimeout write FCacheTimeout;
  end;

  {**
   * DANE TLSA Validator with extended features
   * Includes support for DNSSEC validation and record caching
   *}
  TDANEValidatorEx = class(TDANEValidator)
  private
    FDNSResolver: string;
    FDNSTimeout: Integer;
    FLastDNSSECStatusCode: Integer;  // 0=unknown, 1=secure, 2=insecure, 3=bogus

  public
    constructor Create(const ADomain: string; APort: Word);

    {** Set custom DNS resolver
        @param AResolver DNS resolver address (e.g., '8.8.8.8') *}
    procedure SetDNSResolver(const AResolver: string);

    {** Set DNS query timeout
        @param ATimeout Timeout in milliseconds *}
    procedure SetDNSTimeout(ATimeout: Integer);

    {** Verify DNSSEC chain
        @returns True if DNSSEC chain is valid *}
    function VerifyDNSSEC: Boolean;

    {** Get DNSSEC validation status
        @returns Human-readable DNSSEC status *}
    function GetDNSSECStatus: string;
  end;

implementation

uses nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.errors, nextpas.core.tls.exceptions, nextpas.core.tls.logging, nextpas.core.tls.encoding, nextpas.core.tls.dns.ldns;

{ TDANEValidator }

constructor TDANEValidator.Create(const ADomain: string; APort: Word);
begin
  inherited Create;
  FDomain := ADomain;
  FPort := APort;
  FRequireDNSSEC := True;
  FEnableCache := True;
  FCacheTimeout := 3600;  // 1 hour
  FLastDNSSECStatus := '';
  SetLength(FRecords, 0);
end;

destructor TDANEValidator.Destroy;
begin
  ClearRecords;
  inherited Destroy;
end;

function TDANEValidator.ExtractCertificateData(ACert: PX509; ASelector: TDANESelector): TBytes;
var
  DataLen: Integer;
  PubKey: PEVP_PKEY;
  P: PByte;
begin
  Result := nil;

  if ACert = nil then
    Exit;

  case ASelector of
    dsFullCertificate:
    begin
      // Extract full certificate in DER format
      DataLen := i2d_X509(ACert, nil);
      if DataLen <= 0 then
        Exit;

      SetLength(Result, DataLen);
      P := @Result[0];
      i2d_X509(ACert, @P);
    end;

    dsSubjectPublicKeyInfo:
    begin
      // Extract SPKI (Subject Public Key Info)
      PubKey := X509_get_pubkey(ACert);
      if PubKey = nil then
        Exit;

      try
        DataLen := i2d_PUBKEY(PubKey, nil);
        if DataLen <= 0 then
          Exit;

        SetLength(Result, DataLen);
        P := @Result[0];
        i2d_PUBKEY(PubKey, @P);
      finally
        EVP_PKEY_free(PubKey);
      end;
    end;
  end;
end;

function TDANEValidator.HashData(const AData: TBytes; AMatchingType: TDANEMatchingType): TBytes;
var
  Ctx: PEVP_MD_CTX;
  Digest: array[0..63] of Byte;  // Max 64 bytes for SHA-512
  DigestLen: Cardinal;
  MD: PEVP_MD;
begin
  Result := nil;

  if Length(AData) = 0 then
    Exit;

  case AMatchingType of
    dmExact:
    begin
      // No hashing, return data as-is
      Result := Copy(AData, 0, Length(AData));
      Exit;
    end;

    dmSHA256:
      MD := EVP_sha256();

    dmSHA512:
      MD := EVP_sha512();
  end;

  Ctx := EVP_MD_CTX_new();
  if Ctx = nil then
    Exit;

  try
    if EVP_DigestInit_ex(Ctx, MD, nil) <= 0 then
      Exit;

    if EVP_DigestUpdate(Ctx, @AData[0], Length(AData)) <= 0 then
      Exit;

    DigestLen := 64;
    if EVP_DigestFinal_ex(Ctx, @Digest[0], DigestLen) <= 0 then
      Exit;

    SetLength(Result, DigestLen);
    Move(Digest[0], Result[0], DigestLen);
  finally
    EVP_MD_CTX_free(Ctx);
  end;
end;

function TDANEValidator.CompareData(const AData1, AData2: TBytes): Boolean;
var
  i: Integer;
begin
  Result := False;

  if Length(AData1) <> Length(AData2) then
    Exit;

  if Length(AData1) = 0 then
    Exit;

  // Constant-time comparison to prevent timing attacks
  Result := True;
  for i := 0 to High(AData1) do
    if AData1[i] <> AData2[i] then
      Result := False;
end;

function TDANEValidator.ValidateAgainstRecord(ACert: PX509; const ARecord: TDANETLSARecord): Boolean;
var
  CertData: TBytes;
  HashedData: TBytes;
begin
  Result := False;

  // Extract certificate data based on selector
  CertData := ExtractCertificateData(ACert, ARecord.Selector);
  if Length(CertData) = 0 then
  begin
    TSecurityLog.Error('DANE', 'Failed to extract certificate data');
    Exit;
  end;

  // Hash data if needed
  HashedData := HashData(CertData, ARecord.MatchingType);
  if Length(HashedData) = 0 then
  begin
    TSecurityLog.Error('DANE', 'Failed to hash certificate data');
    Exit;
  end;

  // Compare with TLSA record data
  Result := CompareData(HashedData, ARecord.CertificateData);

  if Result then
    TSecurityLog.Info('DANE', Format('Certificate matched TLSA record (usage=%d, selector=%d, matching=%d)',
      [Ord(ARecord.Usage), Ord(ARecord.Selector), Ord(ARecord.MatchingType)]))
  else
    TSecurityLog.Debug('DANE', 'Certificate did not match TLSA record');
end;

function TDANEValidator.IsCacheValid(const ARecord: TDANETLSARecord): Boolean;
var
  Age: Integer;
begin
  if not FEnableCache then
  begin
    Result := False;
    Exit;
  end;

  Age := Round((Now - ARecord.Retrieved) * 86400);  // Convert to seconds
  Result := Age < FCacheTimeout;
end;

function TDANEValidator.QueryTLSARecords(const ADomain: string; APort: Word): Boolean;
var
  LdnsRecords: TLdnsTLSARecordArray;
  DNSSECStatus: TDNSSECStatus;
  i: Integer;
  Rec: TDANETLSARecord;
begin
  Result := False;

  // 检查 ldns 是否可用
  if not IsLdnsLoaded then
  begin
    if not LoadLdns then
    begin
      TSecurityLog.Warning('DANE', 'ldns library not available, DNS TLSA query disabled');
      FLastDNSSECStatus := 'ldns library not available';
      Exit(False);
    end;
  end;

  // 更新域名和端口
  FDomain := ADomain;
  FPort := APort;

  // 清除旧记录
  ClearRecords;

  // 使用 ldns 查询 TLSA 记录
  TSecurityLog.Info('DANE', Format('Querying TLSA records for %s:%d', [ADomain, APort]));

  if not QueryDNSTLSA(ADomain, APort, 'tcp', LdnsRecords, DNSSECStatus) then
  begin
    TSecurityLog.Warning('DANE', Format('Failed to query TLSA records for %s:%d', [ADomain, APort]));
    FLastDNSSECStatus := 'DNS query failed';
    Exit(False);
  end;

  // 检查 DNSSEC 状态
  FLastDNSSECStatus := DNSSECStatusToStr(DNSSECStatus);
  TSecurityLog.Info('DANE', Format('DNSSEC status: %s', [FLastDNSSECStatus]));

  // 如果要求 DNSSEC 验证，检查状态
  if FRequireDNSSEC and (DNSSECStatus <> dnssecSecure) then
  begin
    TSecurityLog.Warning('DANE', 'DNSSEC validation required but not secure, rejecting records');
    Exit(False);
  end;

  // 没有找到记录
  if Length(LdnsRecords) = 0 then
  begin
    TSecurityLog.Info('DANE', Format('No TLSA records found for %s:%d', [ADomain, APort]));
    Exit(True);  // 查询成功，只是没有记录
  end;

  // 转换 ldns 记录到 DANE 记录
  for i := 0 to High(LdnsRecords) do
  begin
    // 检查 Usage 值是否有效 (0-3)
    if LdnsRecords[i].Usage > 3 then
    begin
      TSecurityLog.Warning('DANE', Format('Invalid TLSA usage value: %d, skipping', [LdnsRecords[i].Usage]));
      Continue;
    end;

    // 检查 Selector 值是否有效 (0-1)
    if LdnsRecords[i].Selector > 1 then
    begin
      TSecurityLog.Warning('DANE', Format('Invalid TLSA selector value: %d, skipping', [LdnsRecords[i].Selector]));
      Continue;
    end;

    // 检查 MatchingType 值是否有效 (0-2)
    if LdnsRecords[i].MatchingType > 2 then
    begin
      TSecurityLog.Warning('DANE', Format('Invalid TLSA matching type value: %d, skipping', [LdnsRecords[i].MatchingType]));
      Continue;
    end;

    Rec.Usage := TDANEUsage(LdnsRecords[i].Usage);
    Rec.Selector := TDANESelector(LdnsRecords[i].Selector);
    Rec.MatchingType := TDANEMatchingType(LdnsRecords[i].MatchingType);
    Rec.TTL := LdnsRecords[i].TTL;
    Rec.Retrieved := Now;

    // 复制证书数据
    SetLength(Rec.CertificateData, Length(LdnsRecords[i].CertData));
    if Length(LdnsRecords[i].CertData) > 0 then
      Move(LdnsRecords[i].CertData[0], Rec.CertificateData[0], Length(LdnsRecords[i].CertData));

    SetLength(FRecords, Length(FRecords) + 1);
    FRecords[High(FRecords)] := Rec;

    TSecurityLog.Info('DANE', Format('Added TLSA record: usage=%d, selector=%d, matching=%d, data=%d bytes',
      [Ord(Rec.Usage), Ord(Rec.Selector), Ord(Rec.MatchingType), Length(Rec.CertificateData)]));
  end;

  Result := Length(FRecords) > 0;
  TSecurityLog.Info('DANE', Format('Loaded %d TLSA records for %s:%d', [Length(FRecords), ADomain, APort]));
end;

procedure TDANEValidator.AddTLSARecord(AUsage: TDANEUsage; ASelector: TDANESelector;
  AMatchingType: TDANEMatchingType; const AData: TBytes);
var
  Rec: TDANETLSARecord;
begin
  Rec.Usage := AUsage;
  Rec.Selector := ASelector;
  Rec.MatchingType := AMatchingType;
  SetLength(Rec.CertificateData, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Rec.CertificateData[0], Length(AData));
  Rec.TTL := FCacheTimeout;
  Rec.Retrieved := Now;

  SetLength(FRecords, Length(FRecords) + 1);
  FRecords[High(FRecords)] := Rec;

  TSecurityLog.Info('DANE', Format('Added TLSA record (usage=%d, selector=%d, matching=%d)',
    [Ord(AUsage), Ord(ASelector), Ord(AMatchingType)]));
end;

function TDANEValidator.ValidateCertificate(ACert: PX509): Boolean;
var
  i: Integer;
begin
  Result := False;

  if ACert = nil then
    Exit;

  if Length(FRecords) = 0 then
  begin
    TSecurityLog.Warning('DANE', 'No TLSA records available for validation');
    Exit;
  end;

  // Try to match against any TLSA record
  for i := 0 to High(FRecords) do
  begin
    if not IsCacheValid(FRecords[i]) then
      Continue;

    if ValidateAgainstRecord(ACert, FRecords[i]) then
    begin
      Result := True;
      Exit;
    end;
  end;

  TSecurityLog.Warning('DANE', 'Certificate did not match any TLSA records');
end;

function TDANEValidator.ValidateCertificateEx(ACert: PX509; out AResult: TDANEValidationResult): Boolean;
var
  i: Integer;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.Success := False;
  AResult.MatchedRecordIndex := -1;
  AResult.RecordsFound := Length(FRecords);
  AResult.DNSSECValid := SameText(Trim(FLastDNSSECStatus), DNSSECStatusToStr(dnssecSecure));

  Result := False;

  if ACert = nil then
  begin
    AResult.ErrorMessage := 'Certificate is nil';
    Exit;
  end;

  if Length(FRecords) = 0 then
  begin
    AResult.ErrorMessage := 'No TLSA records available';
    Exit;
  end;

  // Try to match against any TLSA record
  for i := 0 to High(FRecords) do
  begin
    if not IsCacheValid(FRecords[i]) then
      Continue;

    if ValidateAgainstRecord(ACert, FRecords[i]) then
    begin
      AResult.Success := True;
      AResult.MatchedRecord := FRecords[i];
      AResult.MatchedRecordIndex := i;
      Result := True;
      Exit;
    end;
  end;

  AResult.ErrorMessage := 'Certificate did not match any TLSA records';
end;

function TDANEValidator.ValidateCertificateChain(const ACertChain: array of PX509): Boolean;
var
  i: Integer;
begin
  Result := False;

  if Length(ACertChain) = 0 then
    Exit;

  // Try to validate any certificate in the chain
  for i := 0 to High(ACertChain) do
  begin
    if ValidateCertificate(ACertChain[i]) then
    begin
      Result := True;
      TSecurityLog.Info('DANE', Format('Certificate chain validated at position %d', [i]));
      Exit;
    end;
  end;

  TSecurityLog.Warning('DANE', 'No certificate in chain matched TLSA records');
end;

procedure TDANEValidator.ClearRecords;
begin
  SetLength(FRecords, 0);
  TSecurityLog.Info('DANE', 'Cleared all TLSA records');
end;

function TDANEValidator.GetRecordCount: Integer;
begin
  Result := Length(FRecords);
end;

function TDANEValidator.GetRecordInfo: string;
var
  i: Integer;
  Rec: TDANETLSARecord;
  UsageStr, SelectorStr, MatchingStr: string;
begin
  Result := Format('DANE TLSA Validator: %d records for %s:%d' + LineEnding,
    [Length(FRecords), FDomain, FPort]);

  for i := 0 to High(FRecords) do
  begin
    Rec := FRecords[i];

    case Rec.Usage of
      duCAConstraint: UsageStr := 'CA Constraint';
      duServiceCertConstraint: UsageStr := 'Service Cert Constraint';
      duTrustAnchorAssertion: UsageStr := 'Trust Anchor Assertion';
      duDomainIssuedCert: UsageStr := 'Domain-Issued Cert';
    end;

    case Rec.Selector of
      dsFullCertificate: SelectorStr := 'Full Certificate';
      dsSubjectPublicKeyInfo: SelectorStr := 'SPKI';
    end;

    case Rec.MatchingType of
      dmExact: MatchingStr := 'Exact';
      dmSHA256: MatchingStr := 'SHA-256';
      dmSHA512: MatchingStr := 'SHA-512';
    end;

    Result := Result + Format('  [%d] %s / %s / %s (%d bytes)' + LineEnding,
      [i, UsageStr, SelectorStr, MatchingStr, Length(Rec.CertificateData)]);
  end;
end;

{ TDANEValidatorEx }

constructor TDANEValidatorEx.Create(const ADomain: string; APort: Word);
begin
  inherited Create(ADomain, APort);
  FDNSResolver := '';  // Use system default
  FDNSTimeout := 5000;  // 5 seconds
  FLastDNSSECStatusCode := 0;  // Unknown
end;

procedure TDANEValidatorEx.SetDNSResolver(const AResolver: string);
begin
  FDNSResolver := AResolver;
  TSecurityLog.Info('DANE', Format('DNS resolver set to: %s', [AResolver]));
end;

procedure TDANEValidatorEx.SetDNSTimeout(ATimeout: Integer);
begin
  FDNSTimeout := ATimeout;
  TSecurityLog.Info('DANE', Format('DNS timeout set to: %d ms', [ATimeout]));
end;

function TDANEValidatorEx.VerifyDNSSEC: Boolean;
var
  DNSSECStatus: TDNSSECStatus;
begin
  Result := False;

  // 检查 ldns 是否可用
  if not IsLdnsLoaded then
  begin
    if not LoadLdns then
    begin
      TSecurityLog.Warning('DANE', 'ldns library not available, DNSSEC verification disabled');
      FLastDNSSECStatusCode := 0;  // Unknown
      Exit(False);
    end;
  end;

  // 验证 DNSSEC 链
  TSecurityLog.Info('DANE', Format('Verifying DNSSEC for domain: %s', [FDomain]));

  DNSSECStatus := VerifyDNSSECChain(FDomain, LDNS_RR_TYPE_TLSA);

  case DNSSECStatus of
    dnssecSecure:
    begin
      FLastDNSSECStatusCode := 1;
      TSecurityLog.Info('DANE', 'DNSSEC verification successful');
      Result := True;
    end;

    dnssecInsecure:
    begin
      FLastDNSSECStatusCode := 2;
      TSecurityLog.Warning('DANE', 'Domain is not DNSSEC signed (insecure)');
      Result := False;
    end;

    dnssecBogus:
    begin
      FLastDNSSECStatusCode := 3;
      TSecurityLog.Error('DANE', 'DNSSEC verification failed (bogus)');
      Result := False;
    end;

    else
    begin
      FLastDNSSECStatusCode := 0;
      TSecurityLog.Warning('DANE', 'DNSSEC status indeterminate');
      Result := False;
    end;
  end;
end;

function TDANEValidatorEx.GetDNSSECStatus: string;
begin
  // 检查 ldns 是否可用
  if not IsLdnsLoaded then
  begin
    if not LoadLdns then
    begin
      Result := 'ldns library not available';
      Exit;
    end;
  end;

  // 根据上次验证结果返回状态
  case FLastDNSSECStatusCode of
    0: Result := 'DNSSEC status: Unknown (not verified yet)';
    1: Result := 'DNSSEC status: Secure (validated)';
    2: Result := 'DNSSEC status: Insecure (not signed)';
    3: Result := 'DNSSEC status: Bogus (validation failed)';
  else
    Result := 'DNSSEC status: Unknown';
  end;

  // 如果有缓存的状态信息，附加它
  if FLastDNSSECStatus <> '' then
    Result := Result + ' - ' + FLastDNSSECStatus;
end;

end.
