program test_cert_time_utc_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.cert.builder.impl,
  nextpas.core.tls.certchain;

type
  TMockCertificate = class(TInterfacedObject, ISSLCertificate)
  private
    FInfo: TSSLCertificateInfo;
    FIssuerCertificate: ISSLCertificate;
  public
    constructor Create(ANotBefore, ANotAfter: TDateTime);

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

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

function BuildFreshOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'cert-time-utc-contract.local';
  Result.Organization := 'nextpas core';
  Result.ValidDays := 1;
  // 这里故意使用当前本地时间生成“应当现在有效”的证书。
  // 真正被验证的契约是消费侧必须按 UTC 判断这些 ASN.1/X.509 时间。
  Result.NotBefore := Now - (1.0 / 24.0);
  Result.NotAfter := Now + (1.0 / 24.0);
end;

procedure TestCertificateValidityUsesUtcTime;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
  LInfo: TCertInfo;
  LCertificate: TCertificateImpl;
  LVerifier: TSSLCertificateChainVerifier;
  LMockCert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== 证书有效期 UTC 契约测试 ===');

  LOptions := BuildFreshOptions;
  Check(TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM),
    '生成当前有效的测试证书');

  LInfo := TCertificateUtils.GetInfo(LCertPEM);
  try
    Check(LInfo.NotBefore < DateTimeUtcNow,
      '生成证书的 NotBefore 应早于当前 UTC 时间');
    Check(LInfo.NotAfter > DateTimeUtcNow,
      '生成证书的 NotAfter 应晚于当前 UTC 时间');

    LCertificate := TCertificateImpl.Create(LCertPEM);
    try
      Check(not LCertificate.IsExpired,
        'TCertificateImpl.IsExpired 应按 UTC 判断为未过期');
      Check(LCertificate.IsValidAt(DateTimeUtcNow),
        'TCertificateImpl.IsValidAt(DateTimeUtcNow) 应为真');
    finally
      LCertificate.Free;
    end;

    Check(TCertificateUtils.IsValid(LCertPEM),
      'TCertificateUtils.IsValid 应按 UTC 判断为有效');

    LVerifier := TSSLCertificateChainVerifier.Create;
    try
      LMockCert := TMockCertificate.Create(LInfo.NotBefore, LInfo.NotAfter);
      Check(LVerifier.CheckCertificateTime(LMockCert),
        'TSSLCertificateChainVerifier.CheckCertificateTime 应按 UTC 判断为有效');
    finally
      LVerifier.Free;
    end;
  finally
    LInfo.SubjectAltNames.Free;
  end;
end;

{ TMockCertificate }

constructor TMockCertificate.Create(ANotBefore, ANotAfter: TDateTime);
begin
  inherited Create;
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.Subject := 'CN=mock-cert-time-utc-contract.local';
  FInfo.Issuer := 'CN=mock-cert-time-utc-contract.local';
  FInfo.SerialNumber := '01';
  FInfo.NotBefore := ANotBefore;
  FInfo.NotAfter := ANotAfter;
end;

function TMockCertificate.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromStream(AStream: TStream): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromPEM(const APEM: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToFile(const AFileName: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToStream(AStream: TStream): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToPEM: string;
begin
  Result := '';
end;

function TMockCertificate.SaveToDER: TBytes;
begin
  Result := nil;
end;

function TMockCertificate.GetInfo: TSSLCertificateInfo;
begin
  Result := FInfo;
end;

function TMockCertificate.GetSubject: string;
begin
  Result := FInfo.Subject;
end;

function TMockCertificate.GetIssuer: string;
begin
  Result := FInfo.Issuer;
end;

function TMockCertificate.GetSerialNumber: string;
begin
  Result := FInfo.SerialNumber;
end;

function TMockCertificate.GetNotBefore: TDateTime;
begin
  Result := FInfo.NotBefore;
end;

function TMockCertificate.GetNotAfter: TDateTime;
begin
  Result := FInfo.NotAfter;
end;

function TMockCertificate.GetPublicKey: string;
begin
  Result := '';
end;

function TMockCertificate.GetPublicKeyAlgorithm: string;
begin
  Result := '';
end;

function TMockCertificate.GetSignatureAlgorithm: string;
begin
  Result := '';
end;

function TMockCertificate.GetVersion: Integer;
begin
  Result := 3;
end;

function TMockCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
begin
  Result := False;
end;

function TMockCertificate.VerifyEx(ACAStore: ISSLCertificateStore;
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  Result := False;
end;

function TMockCertificate.VerifyHostname(const AHostname: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.IsExpired: Boolean;
begin
  Result := False;
end;

function TMockCertificate.IsSelfSigned: Boolean;
begin
  Result := True;
end;

function TMockCertificate.IsCA: Boolean;
begin
  Result := False;
end;

function TMockCertificate.GetDaysUntilExpiry: Integer;
begin
  Result := Trunc(FInfo.NotAfter - Date);
end;

function TMockCertificate.GetSubjectCN: string;
begin
  Result := FInfo.Subject;
end;

function TMockCertificate.GetExtension(const AOID: string): string;
begin
  Result := '';
end;

function TMockCertificate.GetSubjectAltNames: TSSLStringArray;
begin
  Result := nil;
end;

function TMockCertificate.GetKeyUsage: TSSLStringArray;
begin
  Result := nil;
end;

function TMockCertificate.GetExtendedKeyUsage: TSSLStringArray;
begin
  Result := nil;
end;

function TMockCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  Result := '';
end;

function TMockCertificate.GetFingerprintSHA1: string;
begin
  Result := '';
end;

function TMockCertificate.GetFingerprintSHA256: string;
begin
  Result := '';
end;

procedure TMockCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCertificate := ACert;
end;

function TMockCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCertificate;
end;

function TMockCertificate.Clone: ISSLCertificate;
begin
  Result := TMockCertificate.Create(FInfo.NotBefore, FInfo.NotAfter);
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls 证书时间 UTC 契约测试');
  WriteLn('========================================');

  TestCertificateValidityUsesUtcTime;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
