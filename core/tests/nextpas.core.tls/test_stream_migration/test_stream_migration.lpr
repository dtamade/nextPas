program test_stream_migration;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.asn1,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.cert.pinning,
  nextpas.core.tls.crl,
  nextpas.core.tls.ct.log,
  nextpas.core.tls.debug.utils,
  nextpas.core.tls.ocsp.cache;

const
  CERT_ADVANCED_PATH = 'core/src/nextpas.core.tls.cert.advanced.pas';
  CT_LOG_PATH = 'core/src/nextpas.core.tls.ct.log.pas';
  CRL_PATH = 'core/src/nextpas.core.tls.crl.pas';
  OCSP_CACHE_PATH = 'core/src/nextpas.core.tls.ocsp.cache.pas';
  ASN1_PATH = 'core/src/nextpas.core.tls.asn1.pas';
  CERT_PINNING_PATH = 'core/src/nextpas.core.tls.cert.pinning.pas';
  DEBUG_UTILS_PATH = 'core/src/nextpas.core.tls.debug.utils.pas';

  VALID_CRL_PEM =
    '-----BEGIN X509 CRL-----'#10 +
    'MIIBjTB3AgEBMA0GCSqGSIb3DQEBCwUAMDQxEDAOBgNVBAMMB1Rlc3QgQ0ExEzAR'#10 +
    'BgNVBAoMCmZhZmFmYS5zc2wxCzAJBgNVBAYTAlVTFw0yNjAzMjAxNTI5NDZaFw0y'#10 +
    'NjA0MTkxNTI5NDZaoA8wDTALBgNVHRQEBAICEAAwDQYJKoZIhvcNAQELBQADggEB'#10 +
    'ACLaEDdVdaNeX3pTi8a2QjBKXDhZhr3sphOOr+4jGq2BrM4nd3Y/AzSLeykWtch7'#10 +
    'tWtNT0BoNpPP63zD7qkUx3BS9qT/ATFuikWflP2cG3NzMXPLzjdcVF2LJCJf64VI'#10 +
    'FOjEW1F6MDGp0Rciwjj9X52IePexvrmGqHVnDsvn1KVWNEiIP4THom01tUeHn186'#10 +
    '8uLIjDgJ4DD7rSbR+OH1H6d8Dhh14yGBz6xVMA/BaCzTcRKH4VpUKgrw6wPKZAIy'#10 +
    'RAAm1DGds5Z9gTqELwYJVHwv2UpdESsCGIYs7kOuyj+2MYyHhGNEPbUer3IZ7OZN'#10 +
    'A0+1F8BNBBFon7Ehk2j/F6c='#10 +
    '-----END X509 CRL-----';

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

procedure Check(ACondition: Boolean; const AName: string; const ADetail: string = '');
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

function LoadText(const AFileName: string): string;
var
  LStream: TStringList;
begin
  LStream := TStringList.Create;
  try
    LStream.LoadFromFile(AFileName);
    Result := LStream.Text;
  finally
    LStream.Free;
  end;
end;

function TempFileName(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    APrefix + '_' + IntToStr(GetProcessID) + '_' + IntToStr(Random(1000000));
end;

procedure DeleteIfExists(const AFileName: string);
begin
  if FileExists(AFileName) then
    DeleteFile(AFileName);
end;

procedure TestSourceMigrationContracts;
var
  LText: string;
begin
  WriteLn;
  WriteLn('=== Source migration contracts ===');

  LText := LoadText(CERT_ADVANCED_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'cert.advanced removed TFileStream',
    'TFileStream is still present in ' + CERT_ADVANCED_PATH);

  LText := LoadText(CT_LOG_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'ct.log removed TFileStream',
    'TFileStream is still present in ' + CT_LOG_PATH);
  Check(Pos('Classes', LText) = 0,
    'ct.log removed Classes uses',
    'Classes is still present in ' + CT_LOG_PATH);

  LText := LoadText(CRL_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'crl removed TFileStream',
    'TFileStream is still present in ' + CRL_PATH);

  LText := LoadText(OCSP_CACHE_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'ocsp.cache removed TFileStream',
    'TFileStream is still present in ' + OCSP_CACHE_PATH);

  LText := LoadText(ASN1_PATH);
  Check(Pos('TMemoryStream', LText) = 0,
    'asn1 removed TMemoryStream',
    'TMemoryStream is still present in ' + ASN1_PATH);

  LText := LoadText(CERT_PINNING_PATH);
  Check(Pos('TStringStream', LText) = 0,
    'cert.pinning removed TStringStream',
    'TStringStream is still present in ' + CERT_PINNING_PATH);

  LText := LoadText(DEBUG_UTILS_PATH);
  Check(Pos('class(TMemoryStream)', LText) = 0,
    'debug.utils removed TMemoryStream inheritance',
    'TSSLMemoryStream still inherits from TMemoryStream');
end;

procedure TestASN1WriterRoundTrip;
var
  LWriter: TASN1Writer;
  LData: TBytes;
  LReader: TASN1Reader;
  LRoot: TASN1Node;
begin
  WriteLn;
  WriteLn('=== ASN.1 roundtrip ===');

  LWriter := TASN1Writer.Create;
  try
    LWriter.BeginSequence;
    LWriter.WriteInteger(42);
    LWriter.WriteUTF8String('stream-migration');
    LWriter.EndSequence;
    LData := LWriter.GetData;
  finally
    LWriter.Free;
  end;

  Check(Length(LData) > 0, 'asn1 writer emitted bytes');

  LReader := TASN1Reader.Create(LData);
  try
    LRoot := LReader.Parse;
    try
      Check(LRoot.IsSequence, 'asn1 parsed sequence');
      Check(LRoot.ChildCount = 2, 'asn1 sequence child count');
      if LRoot.ChildCount >= 2 then
      begin
        Check(LRoot.GetChild(0).AsInteger = 42, 'asn1 integer roundtrip');
        Check(LRoot.GetChild(1).AsString = 'stream-migration', 'asn1 string roundtrip');
      end;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

procedure TestCertificatePinningBase64RoundTrip;
const
  PIN_BASE64 = 'X3pGTSOuJeEVw989IJ/cEtXUEmy52zs1TZQrU06KUKg=';
var
  LPin: TCertificatePin;
begin
  WriteLn;
  WriteLn('=== Certificate pinning Base64 roundtrip ===');

  LPin := TCertificatePin.FromBase64(PIN_BASE64, ptPublicKey, 'stream migration pin');
  Check(LPin.ToBase64 = PIN_BASE64, 'cert pinning base64 roundtrip', LPin.ToBase64);
end;

procedure TestSSLMemoryStreamBehavior;
var
  LStream: TSSLMemoryStream;
  LBytes: TBytes;
begin
  WriteLn;
  WriteLn('=== TSSLMemoryStream behavior ===');

  LStream := TSSLMemoryStream.Create('migration');
  try
    LStream.WriteByte($12);
    LStream.WriteWord($3456);
    LStream.WriteDWord($789ABCDE);
    LStream.WriteString('ok');

    Check(LStream.Size > 0, 'ssl memory stream size tracks writes');
    LStream.Position := 0;
    Check(LStream.PeekByte = $12, 'ssl memory stream peek byte');
    Check(LStream.ReadByte = $12, 'ssl memory stream read byte');
    Check(LStream.ReadWord = $3456, 'ssl memory stream read word');
    Check(LStream.ReadDWord = $789ABCDE, 'ssl memory stream read dword');
    Check(LStream.ReadString(2) = 'ok', 'ssl memory stream read string');
    Check(LStream.RemainingBytes = 0, 'ssl memory stream remaining bytes');

    LStream.Position := 0;
    LBytes := LStream.ReadBytes(LStream.Size);
    Check(Length(LBytes) = LStream.Size, 'ssl memory stream read bytes count');
    Check(Pos('12', UpperCase(LStream.GetHexDump)) > 0, 'ssl memory stream hex dump');
  finally
    LStream.Free;
  end;
end;

procedure TestOCSPCacheFileRoundTrip;
var
  LCache: TOCSPResponseCache;
  LReloaded: TOCSPResponseCache;
  LSerial: TBytes;
  LResponse: TBytes;
  LLoaded: TBytes;
  LFileName: string;
begin
  WriteLn;
  WriteLn('=== OCSP cache file roundtrip ===');

  SetLength(LSerial, 3);
  LSerial[0] := 1;
  LSerial[1] := 2;
  LSerial[2] := 3;

  SetLength(LResponse, 4);
  LResponse[0] := $30;
  LResponse[1] := $82;
  LResponse[2] := $00;
  LResponse[3] := $01;

  LFileName := TempFileName('nextpas_tls_ocsp_cache.bin');
  DeleteIfExists(LFileName);

  LCache := TOCSPResponseCache.Create;
  try
    LCache.Put(LSerial, LResponse, Now, Now + 1);
    Check(LCache.SaveToFile(LFileName), 'ocsp cache save to file');
  finally
    LCache.Free;
  end;

  LReloaded := TOCSPResponseCache.Create;
  try
    Check(LReloaded.LoadFromFile(LFileName), 'ocsp cache load from file');
    Check(LReloaded.Get(LSerial, LLoaded), 'ocsp cache entry reloaded');
    Check(Length(LLoaded) = Length(LResponse), 'ocsp cache response length');
  finally
    LReloaded.Free;
    DeleteIfExists(LFileName);
  end;
end;

procedure TestCTLogFileRoundTrip;
var
  LText: TStringList;
  LReloaded: TCTLogClient;
  LSourceFileName: string;
  LSavedFileName: string;
  LJSON: string;
  LLogs: TCTLogList;
begin
  WriteLn;
  WriteLn('=== CT log file roundtrip ===');

  LJSON :=
    '{' +
      '"logs":[' +
        '{"log_id":"abc","key":"def","url":"https://ct.example","description":"Example","operator":"Ops","mmd":86400,"usable":true}' +
      ']' +
    '}';

  LSourceFileName := TempFileName('nextpas_tls_ct_logs_source.json');
  LSavedFileName := TempFileName('nextpas_tls_ct_logs_saved.json');
  DeleteIfExists(LSourceFileName);
  DeleteIfExists(LSavedFileName);

  LText := TStringList.Create;
  try
    LText.Text := LJSON;
    LText.SaveToFile(LSourceFileName);
  finally
    LText.Free;
  end;

  LReloaded := TCTLogClient.Create;
  try
    Check(LReloaded.LoadFromFile(LSourceFileName), 'ct log load from file');
    Check(LReloaded.SaveToFile(LSavedFileName), 'ct log save to file');
    LLogs := LReloaded.GetAllLogs;
    Check(Length(LLogs) = 1, 'ct log reloaded entry count');
    if Length(LLogs) = 1 then
      Check(LLogs[0].URL = 'https://ct.example', 'ct log reloaded url', LLogs[0].URL);
  finally
    LReloaded.Free;
    DeleteIfExists(LSourceFileName);
    DeleteIfExists(LSavedFileName);
  end;
end;

procedure TestCRLLoadFromFile;
var
  LCRL: TX509CRL;
  LFileName: string;
  LText: TStringList;
begin
  WriteLn;
  WriteLn('=== CRL load from file ===');

  LFileName := TempFileName('nextpas_tls_test.crl');
  DeleteIfExists(LFileName);
  LText := TStringList.Create;
  try
    LText.Text := VALID_CRL_PEM;
    LText.SaveToFile(LFileName);
  finally
    LText.Free;
  end;

  LCRL := TX509CRL.Create;
  try
    try
      LCRL.LoadFromFile(LFileName);
      Check(True, 'crl load from file');
    except
      on E: Exception do
        Check(False, 'crl load from file', E.ClassName + ': ' + E.Message);
    end;
  finally
    LCRL.Free;
    DeleteIfExists(LFileName);
  end;
end;

procedure TestPKCS12FileRoundTrip;
var
  LKeyPair: IKeyPairWithCertificate;
  LOptions: TPKCS12Options;
  LFileName: string;
  LCert: ICertificate;
  LKey: IPrivateKey;
begin
  WriteLn;
  WriteLn('=== PKCS12 file roundtrip ===');

  LKeyPair := TCertificate.CreateSelfSigned('stream-migration.local');
  Check(LKeyPair <> nil, 'pkcs12 keypair fixture');
  if LKeyPair = nil then
    Exit;

  LOptions := DefaultPKCS12Options;
  LOptions.Password := 'stream-migration';
  LOptions.FriendlyName := 'stream-migration';

  LFileName := TempFileName('nextpas_tls_pkcs12.p12');
  DeleteIfExists(LFileName);
  try
    Check(
      TPKCS12Manager.CreatePKCS12ToFile(
        LKeyPair.Certificate,
        LKeyPair.PrivateKey,
        LFileName,
        LOptions
      ),
      'pkcs12 save to file'
    );

    LCert := nil;
    LKey := nil;
    Check(
      TPKCS12Manager.LoadFromPKCS12File(
        LFileName,
        LOptions.Password,
        LCert,
        LKey
      ),
      'pkcs12 load from file'
    );
    Check(LCert <> nil, 'pkcs12 loaded certificate');
    Check(LKey <> nil, 'pkcs12 loaded key');
  finally
    DeleteIfExists(LFileName);
  end;
end;

begin
  Randomize;

  TestSourceMigrationContracts;
  TestASN1WriterRoundTrip;
  TestCertificatePinningBase64RoundTrip;
  TestSSLMemoryStreamBehavior;
  TestOCSPCacheFileRoundTrip;
  TestCTLogFileRoundTrip;
  TestCRLLoadFromFile;
  TestPKCS12FileRoundTrip;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
