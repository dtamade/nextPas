program test_openssl_connection_info_cipher_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.connection;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GLegacyCipherName: AnsiString = 'ECDHE-RSA-AES128-SHA256';
  GTLS13CipherName: AnsiString = 'TLS_AES_128_GCM_SHA256';

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function StubSSLGetCurrentCipherNonNil(const ssl: PSSL): PSSL_CIPHER; cdecl;
begin
  Result := PSSL_CIPHER(Pointer(PtrUInt(1)));
end;

function StubSSLCipherGetBits(const cipher: PSSL_CIPHER; alg_bits: PInteger): Integer; cdecl;
begin
  if alg_bits <> nil then
    alg_bits^ := 0;
  Result := 0;
end;

function StubSSLCipherGetProtocolId(const cipher: PSSL_CIPHER): UInt16; cdecl;
begin
  Result := $1301;
end;

function StubSSLCipherGetId(const cipher: PSSL_CIPHER): UInt32; cdecl;
begin
  Result := $03001301;
end;

function StubSSLCipherGetDigestNid(const cipher: PSSL_CIPHER): Integer; cdecl;
begin
  Result := 42;
end;

function StubSSLCipherIsNotAead(const cipher: PSSL_CIPHER): Integer; cdecl;
begin
  Result := 0;
end;

function StubSSLCipherIsAead(const cipher: PSSL_CIPHER): Integer; cdecl;
begin
  Result := 1;
end;

function StubEVPGetDigestByNid(nid: Integer): PEVP_MD; cdecl;
begin
  Result := PEVP_MD(Pointer(PtrUInt(2)));
end;

function StubEVPMDGetSize(const md: PEVP_MD): Integer; cdecl;
begin
  Result := 32;
end;

function StubSSLCipherGetNameLegacyNonAead(const cipher: PSSL_CIPHER): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GLegacyCipherName);
end;

function StubSSLCipherGetNameTLS13Aead(const cipher: PSSL_CIPHER): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GTLS13CipherName);
end;

procedure WarmupStreamConnectionConstructor(AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);
    if LConn = nil then
      raise Exception.Create('stream connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

function CaptureFreshConnectionInfo(AContext: ISSLContext): TSSLConnectionInfo;
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
  LManagedByInterface: Boolean;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  LConnInfoAccess := nil;
  LManagedByInterface := False;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);
    if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
      raise Exception.Create('OpenSSL connection does not expose ISSLConnectionInfo');
    LManagedByInterface := True;
    Result := LConnInfoAccess.GetConnectionInfo;
  finally
    if LManagedByInterface then
      LConn := nil
    else if Assigned(LConn) then
      LConn.Free;
    LConnInfoAccess := nil;
    LStream.Free;
  end;
end;

procedure AssertConnectionInfoSafeDegrade(
  const AName: string;
  AContext: ISSLContext;
  const AExpected: TSSLConnectionInfo
);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
  LManagedByInterface: Boolean;
  LRaised: Boolean;
  LInfo: TSSLConnectionInfo;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  LConnInfoAccess := nil;
  LManagedByInterface := False;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    FillChar(LInfo, SizeOf(LInfo), 0);
    LDetail := '';
    try
      if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
        raise Exception.Create('OpenSSL connection does not expose ISSLConnectionInfo');
      LManagedByInterface := True;
      LInfo := LConnInfoAccess.GetConnectionInfo;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should preserve ProtocolVersion baseline',
      LInfo.ProtocolVersion = AExpected.ProtocolVersion,
      'expected GetConnectionInfo to preserve inherited protocol baseline');
    AssertTrue(AName + ' should preserve CipherSuite baseline',
      LInfo.CipherSuite = AExpected.CipherSuite,
      'expected GetConnectionInfo to preserve inherited cipher baseline');
    AssertTrue(AName + ' should preserve KeySize baseline',
      LInfo.KeySize = AExpected.KeySize,
      'expected GetConnectionInfo to preserve inherited key-size baseline');
    AssertTrue(AName + ' should preserve ServerName baseline',
      LInfo.ServerName = AExpected.ServerName,
      'expected GetConnectionInfo to preserve inherited server-name baseline');
  finally
    if LManagedByInterface then
      LConn := nil
    else if Assigned(LConn) then
      LConn.Free;
    LConnInfoAccess := nil;
    LStream.Free;
  end;
end;

procedure AssertConnectionInfoCipherSuiteId(
  const AName: string;
  AContext: ISSLContext;
  const AExpectedCipherSuiteId: Word
);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
  LManagedByInterface: Boolean;
  LRaised: Boolean;
  LInfo: TSSLConnectionInfo;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  LConnInfoAccess := nil;
  LManagedByInterface := False;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    FillChar(LInfo, SizeOf(LInfo), 0);
    LDetail := '';
    try
      if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
        raise Exception.Create('OpenSSL connection does not expose ISSLConnectionInfo');
      LManagedByInterface := True;
      LInfo := LConnInfoAccess.GetConnectionInfo;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should set CipherSuiteId',
      LInfo.CipherSuiteId = AExpectedCipherSuiteId,
      Format('expected CipherSuiteId %.4x but got %.4x',
        [AExpectedCipherSuiteId, LInfo.CipherSuiteId]));
  finally
    if LManagedByInterface then
      LConn := nil
    else if Assigned(LConn) then
      LConn.Free;
    LConnInfoAccess := nil;
    LStream.Free;
  end;
end;

procedure AssertConnectionInfoMacSize(
  const AName: string;
  AContext: ISSLContext;
  const AExpectedMacSize: Integer
);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
  LManagedByInterface: Boolean;
  LRaised: Boolean;
  LInfo: TSSLConnectionInfo;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  LConnInfoAccess := nil;
  LManagedByInterface := False;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    FillChar(LInfo, SizeOf(LInfo), 0);
    LDetail := '';
    try
      if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
        raise Exception.Create('OpenSSL connection does not expose ISSLConnectionInfo');
      LManagedByInterface := True;
      LInfo := LConnInfoAccess.GetConnectionInfo;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should set MacSize',
      LInfo.MacSize = AExpectedMacSize,
      Format('expected MacSize %d but got %d', [AExpectedMacSize, LInfo.MacSize]));
  finally
    if LManagedByInterface then
      LConn := nil
    else if Assigned(LConn) then
      LConn.Free;
    LConnInfoAccess := nil;
    LStream.Free;
  end;
end;

procedure TestGetConnectionInfoShouldDegradeSafelyWhenCipherHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LBaselineInfo: TSSLConnectionInfo;
  LOriginalSSLGetCurrentCipher: TSSL_get_current_cipher;
  LOriginalSSLCipherGetName: TSSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits: TSSL_CIPHER_get_bits;
  LOriginalSSLCipherGetProtocolId: TSSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId: TSSL_CIPHER_get_id;
  LOriginalSSLCipherIsAead: TSSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid: TSSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid: TEVP_get_digestbynid;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection info cipher guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection info cipher contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);
  LBaselineInfo := CaptureFreshConnectionInfo(LContext);

  LOriginalSSLGetCurrentCipher := SSL_get_current_cipher;
  LOriginalSSLCipherGetName := SSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits := SSL_CIPHER_get_bits;
  LOriginalSSLCipherGetProtocolId := SSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId := SSL_CIPHER_get_id;
  LOriginalSSLCipherIsAead := SSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid := SSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid := EVP_get_digestbynid;
  try
    SSL_get_current_cipher := nil;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
    SSL_CIPHER_get_bits := LOriginalSSLCipherGetBits;
    SSL_CIPHER_get_protocol_id := LOriginalSSLCipherGetProtocolId;
    SSL_CIPHER_get_id := LOriginalSSLCipherGetId;
    SSL_CIPHER_is_aead := LOriginalSSLCipherIsAead;
    SSL_CIPHER_get_digest_nid := LOriginalSSLCipherGetDigestNid;
    EVP_get_digestbynid := LOriginalEVPGetDigestByNid;
    AssertConnectionInfoSafeDegrade(
      'GetConnectionInfo when SSL_get_current_cipher is unavailable',
      LContext,
      LBaselineInfo
    );

    SSL_get_current_cipher := @StubSSLGetCurrentCipherNonNil;
    SSL_CIPHER_get_name := nil;
    SSL_CIPHER_get_bits := @StubSSLCipherGetBits;
    SSL_CIPHER_get_protocol_id := nil;
    SSL_CIPHER_get_id := nil;
    SSL_CIPHER_is_aead := nil;
    SSL_CIPHER_get_digest_nid := nil;
    EVP_get_digestbynid := nil;
    AssertConnectionInfoSafeDegrade(
      'GetConnectionInfo when SSL_CIPHER_get_name is unavailable',
      LContext,
      LBaselineInfo
    );
  finally
    SSL_get_current_cipher := LOriginalSSLGetCurrentCipher;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
    SSL_CIPHER_get_bits := LOriginalSSLCipherGetBits;
    SSL_CIPHER_get_protocol_id := LOriginalSSLCipherGetProtocolId;
    SSL_CIPHER_get_id := LOriginalSSLCipherGetId;
    SSL_CIPHER_is_aead := LOriginalSSLCipherIsAead;
    SSL_CIPHER_get_digest_nid := LOriginalSSLCipherGetDigestNid;
    EVP_get_digestbynid := LOriginalEVPGetDigestByNid;
  end;
end;

procedure TestGetConnectionInfoShouldPreferProtocolIdThenFallbackToCipherId;
var
  LContext: ISSLContext;
  LOriginalSSLGetCurrentCipher: TSSL_get_current_cipher;
  LOriginalSSLCipherGetName: TSSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits: TSSL_CIPHER_get_bits;
  LOriginalSSLCipherGetProtocolId: TSSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId: TSSL_CIPHER_get_id;
  LOriginalSSLCipherIsAead: TSSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid: TSSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid: TEVP_get_digestbynid;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection info cipher-suite id truth ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection info cipher-suite id contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLGetCurrentCipher := SSL_get_current_cipher;
  LOriginalSSLCipherGetName := SSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits := SSL_CIPHER_get_bits;
  LOriginalSSLCipherGetProtocolId := SSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId := SSL_CIPHER_get_id;
  LOriginalSSLCipherIsAead := SSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid := SSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid := EVP_get_digestbynid;
  try
    SSL_get_current_cipher := @StubSSLGetCurrentCipherNonNil;
    SSL_CIPHER_get_name := nil;
    SSL_CIPHER_get_bits := @StubSSLCipherGetBits;
    SSL_CIPHER_is_aead := nil;
    SSL_CIPHER_get_digest_nid := nil;
    EVP_get_digestbynid := nil;

    SSL_CIPHER_get_protocol_id := @StubSSLCipherGetProtocolId;
    SSL_CIPHER_get_id := nil;
    AssertConnectionInfoCipherSuiteId(
      'GetConnectionInfo should prefer SSL_CIPHER_get_protocol_id when available',
      LContext,
      $1301
    );

    SSL_CIPHER_get_protocol_id := nil;
    SSL_CIPHER_get_id := @StubSSLCipherGetId;
    AssertConnectionInfoCipherSuiteId(
      'GetConnectionInfo should fall back to SSL_CIPHER_get_id low word',
      LContext,
      $1301
    );
  finally
    SSL_get_current_cipher := LOriginalSSLGetCurrentCipher;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
    SSL_CIPHER_get_bits := LOriginalSSLCipherGetBits;
    SSL_CIPHER_get_protocol_id := LOriginalSSLCipherGetProtocolId;
    SSL_CIPHER_get_id := LOriginalSSLCipherGetId;
    SSL_CIPHER_is_aead := LOriginalSSLCipherIsAead;
    SSL_CIPHER_get_digest_nid := LOriginalSSLCipherGetDigestNid;
    EVP_get_digestbynid := LOriginalEVPGetDigestByNid;
  end;
end;

procedure TestGetConnectionInfoMacSizeTruth;
var
  LContext: ISSLContext;
  LOriginalSSLGetCurrentCipher: TSSL_get_current_cipher;
  LOriginalSSLCipherGetName: TSSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits: TSSL_CIPHER_get_bits;
  LOriginalSSLCipherIsAead: TSSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid: TSSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid: TEVP_get_digestbynid;
  LOriginalEVPMDGetSize: TEVP_MD_get_size;
  LOriginalSSLCipherGetProtocolId: TSSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId: TSSL_CIPHER_get_id;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection info mac-size truth ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection info mac-size contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLGetCurrentCipher := SSL_get_current_cipher;
  LOriginalSSLCipherGetName := SSL_CIPHER_get_name;
  LOriginalSSLCipherGetBits := SSL_CIPHER_get_bits;
  LOriginalSSLCipherIsAead := SSL_CIPHER_is_aead;
  LOriginalSSLCipherGetDigestNid := SSL_CIPHER_get_digest_nid;
  LOriginalEVPGetDigestByNid := EVP_get_digestbynid;
  LOriginalEVPMDGetSize := EVP_MD_get_size;
  LOriginalSSLCipherGetProtocolId := SSL_CIPHER_get_protocol_id;
  LOriginalSSLCipherGetId := SSL_CIPHER_get_id;
  try
    SSL_get_current_cipher := @StubSSLGetCurrentCipherNonNil;
    SSL_CIPHER_get_bits := @StubSSLCipherGetBits;
    SSL_CIPHER_get_protocol_id := nil;
    SSL_CIPHER_get_id := nil;

    SSL_CIPHER_get_name := @StubSSLCipherGetNameLegacyNonAead;
    SSL_CIPHER_is_aead := nil;
    SSL_CIPHER_get_digest_nid := nil;
    EVP_get_digestbynid := nil;
    EVP_MD_get_size := nil;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should degrade safely when non-AEAD MacSize helpers are unavailable',
      LContext,
      0
    );

    SSL_CIPHER_get_name := @StubSSLCipherGetNameLegacyNonAead;
    SSL_CIPHER_is_aead := @StubSSLCipherIsNotAead;
    SSL_CIPHER_get_digest_nid := @StubSSLCipherGetDigestNid;
    EVP_get_digestbynid := @StubEVPGetDigestByNid;
    EVP_MD_get_size := @StubEVPMDGetSize;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should derive legacy non-AEAD MacSize from digest truth',
      LContext,
      32
    );

    SSL_CIPHER_get_name := @StubSSLCipherGetNameTLS13Aead;
    SSL_CIPHER_is_aead := @StubSSLCipherIsAead;
    SSL_CIPHER_get_digest_nid := @StubSSLCipherGetDigestNid;
    EVP_get_digestbynid := @StubEVPGetDigestByNid;
    EVP_MD_get_size := @StubEVPMDGetSize;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should keep shared AEAD MacSize when digest truth differs',
      LContext,
      16
    );
  finally
    SSL_get_current_cipher := LOriginalSSLGetCurrentCipher;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
    SSL_CIPHER_get_bits := LOriginalSSLCipherGetBits;
    SSL_CIPHER_is_aead := LOriginalSSLCipherIsAead;
    SSL_CIPHER_get_digest_nid := LOriginalSSLCipherGetDigestNid;
    EVP_get_digestbynid := LOriginalEVPGetDigestByNid;
    EVP_MD_get_size := LOriginalEVPMDGetSize;
    SSL_CIPHER_get_protocol_id := LOriginalSSLCipherGetProtocolId;
    SSL_CIPHER_get_id := LOriginalSSLCipherGetId;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Info Cipher Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection info cipher contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestGetConnectionInfoShouldDegradeSafelyWhenCipherHelpersAreUnavailable;

    if SkippedTests = 0 then
      TestGetConnectionInfoShouldPreferProtocolIdThenFallbackToCipherId;

    if SkippedTests = 0 then
      TestGetConnectionInfoMacSizeTruth;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
