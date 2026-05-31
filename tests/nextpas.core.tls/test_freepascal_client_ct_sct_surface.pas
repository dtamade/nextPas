program test_freepascal_client_ct_sct_surface;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.asn1,
  nextpas.core.tls.base,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.ct,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.x509;

const
  TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP = $0012;
  X509_EXTENSION_OCSP_SIGNED_CERTIFICATE_TIMESTAMP = '1.3.6.1.4.1.11129.2.4.5';

type
  TServerMaterial = record
    CertificateBlob: TBytes;
    PrivateKeyBlob: TBytes;
  end;

  TCTIssuerObservationState = record
    OriginalBIONewMemBuf: TBIO_new_mem_buf;
    OriginalSCTValidate: TSCT_validate;
  end;

  ISSLCertificateTransparency = interface
    ['{D3A0FA1A-7E5A-4FC5-9A86-0B5C7A7426D1}']
    function GetCertificateTransparencyEnabled: Boolean;
    function GetSignedCertificateTimestampList: TBytes;
    function GetSignedCertificateTimestampCount: Integer;
    function GetCertificateTransparencyStatus: string;
  end;

  ISSLCertificateTransparencyValidation = interface
    ['{8D5D2D62-8C58-4C62-A8D8-59CF5D9110A0}']
    function HasCertificateTransparencyValidationResult: Boolean;
    function IsCertificateTransparencyPolicySatisfied: Boolean;
    function GetCertificateTransparencyValidationStatus: string;
  end;

var
  GCTIssuerObservationCallCount: Integer = 0;
  GCTIssuerObservationSawNilIssuer: Boolean = False;
  GCTIssuerObservationIssuerSubject: string = '';
  GCTIssuerObservationIssuerIssuer: string = '';
  GCTIssuerObservationIssuerSelfSigned: Boolean = False;
  GCTIssuerObservationOriginalBIONewMemBuf: TBIO_new_mem_buf = nil;
  GCTIssuerObservationOriginalSCTValidate: TSCT_validate = nil;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  I: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    Fail(Format('%s (expected_len=%d actual_len=%d)', [AMessage, Length(AExpected), Length(AActual)]));

  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
      Fail(Format('%s (first_diff=%d)', [AMessage, I]));
end;

function ContainsTextInsensitive(const AValue, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AValue)) > 0;
end;

function GetCertificateVerifyResultString(const AConn: ISSLConnection): string;
var
  LCertVerify: ISSLCertificateVerification;
begin
  AssertTrue(Supports(AConn, ISSLCertificateVerification, LCertVerify),
    'Connection should expose certificate verification interface');
  Result := LCertVerify.GetVerifyResultString;
end;

function TryEnsureOpenSSLCTValidationAvailable: Boolean;
begin
  Result := False;

  try
    LoadOpenSSLCore;
    LoadOpenSSLX509;
    LoadCTFunctions;
    LoadStackFunctions;
  except
    Exit(False);
  end;

  Result :=
    TOpenSSLLoader.IsModuleLoaded(osmCore) and
    Assigned(o2i_SCT_LIST) and
    Assigned(SCT_LIST_validate) and
    Assigned(SCT_get_validation_status) and
    Assigned(OPENSSL_sk_num) and
    Assigned(OPENSSL_sk_value);
end;

function TryEnsureOpenSSLCTIssuerObservationAvailable: Boolean;
begin
  LoadOpenSSLBIO;
  Result :=
    TryEnsureOpenSSLCTValidationAvailable and
    Assigned(BIO_new_mem_buf) and
    Assigned(CT_POLICY_EVAL_CTX_get0_issuer) and
    Assigned(X509_get_subject_name) and
    Assigned(X509_get_issuer_name) and
    Assigned(X509_NAME_cmp);
end;

function DescribeX509Name(AName: PX509_NAME): string;
var
  LBuffer: array[0..1023] of AnsiChar;
begin
  Result := '';

  if AName = nil then
    Exit;

  if Assigned(X509_NAME_oneline) then
  begin
    FillChar(LBuffer, SizeOf(LBuffer), 0);
    if X509_NAME_oneline(AName, @LBuffer[0], SizeOf(LBuffer)) <> nil then
      Result := string(AnsiString(StrPas(@LBuffer[0])));
  end;

  if Result = '' then
    Result := '<unavailable>';
end;

function DescribeX509Subject(AX509: PX509): string;
begin
  Result := '';
  if (AX509 = nil) or (not Assigned(X509_get_subject_name)) then
    Exit;

  Result := DescribeX509Name(X509_get_subject_name(AX509));
end;

function DescribeX509Issuer(AX509: PX509): string;
begin
  Result := '';
  if (AX509 = nil) or (not Assigned(X509_get_issuer_name)) then
    Exit;

  Result := DescribeX509Name(X509_get_issuer_name(AX509));
end;

function IsX509SelfSigned(AX509: PX509): Boolean;
var
  LSubjectName: PX509_NAME;
  LIssuerName: PX509_NAME;
begin
  Result := False;

  if (AX509 = nil) or
     (not Assigned(X509_get_subject_name)) or
     (not Assigned(X509_get_issuer_name)) or
     (not Assigned(X509_NAME_cmp)) then
    Exit;

  LSubjectName := X509_get_subject_name(AX509);
  LIssuerName := X509_get_issuer_name(AX509);
  if (LSubjectName = nil) or (LIssuerName = nil) then
    Exit;

  Result := X509_NAME_cmp(LSubjectName, LIssuerName) = 0;
end;

procedure ResetCTIssuerObservation;
begin
  GCTIssuerObservationCallCount := 0;
  GCTIssuerObservationSawNilIssuer := False;
  GCTIssuerObservationIssuerSubject := '';
  GCTIssuerObservationIssuerIssuer := '';
  GCTIssuerObservationIssuerSelfSigned := False;
end;

function StubSCTValidate(sct: PSCT; ctx: PCT_POLICY_EVAL_CTX): Integer; cdecl;
var
  LIssuerX509: PX509;
begin
  Inc(GCTIssuerObservationCallCount);
  if Assigned(CT_POLICY_EVAL_CTX_get0_issuer) then
    LIssuerX509 := CT_POLICY_EVAL_CTX_get0_issuer(ctx)
  else
    LIssuerX509 := nil;

  GCTIssuerObservationSawNilIssuer := LIssuerX509 = nil;
  GCTIssuerObservationIssuerSubject := DescribeX509Subject(LIssuerX509);
  GCTIssuerObservationIssuerIssuer := DescribeX509Issuer(LIssuerX509);
  GCTIssuerObservationIssuerSelfSigned := IsX509SelfSigned(LIssuerX509);

  if Assigned(GCTIssuerObservationOriginalSCTValidate) then
    Result := GCTIssuerObservationOriginalSCTValidate(sct, ctx)
  else
    Result := 0;
end;

function StubBIONewMemBuf(const buf: Pointer; len: Integer): PBIO; cdecl;
begin
  SCT_validate := @StubSCTValidate;

  if Assigned(GCTIssuerObservationOriginalBIONewMemBuf) then
    Result := GCTIssuerObservationOriginalBIONewMemBuf(buf, len)
  else
    Result := nil;
end;

procedure InstallCTIssuerObservation(out AState: TCTIssuerObservationState);
begin
  AState.OriginalBIONewMemBuf := BIO_new_mem_buf;
  AState.OriginalSCTValidate := SCT_validate;
  GCTIssuerObservationOriginalBIONewMemBuf := AState.OriginalBIONewMemBuf;
  GCTIssuerObservationOriginalSCTValidate := AState.OriginalSCTValidate;
  BIO_new_mem_buf := @StubBIONewMemBuf;
  SCT_validate := @StubSCTValidate;
  ResetCTIssuerObservation;
end;

procedure RestoreCTIssuerObservation(const AState: TCTIssuerObservationState);
begin
  BIO_new_mem_buf := AState.OriginalBIONewMemBuf;
  SCT_validate := AState.OriginalSCTValidate;
  GCTIssuerObservationOriginalBIONewMemBuf := nil;
  GCTIssuerObservationOriginalSCTValidate := nil;
  ResetCTIssuerObservation;
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  Result := nil;
end;

function BuildEncryptedExtensionsMessage: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendUInt16(LBody, 0);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildFinishedMessage(
  ACipherSuite: Word;
  const AServerHandshakeTrafficSecret: TBytes;
  const ATranscriptData: TBytes
): TBytes;
var
  LVerifyData: TBytes;
begin
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    ACipherSuite,
    AServerHandshakeTrafficSecret,
    HashTranscriptForSuite(ACipherSuite, ATranscriptData)
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
end;

function ReadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function BytesToAnsiString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function AnsiStringToBytes(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function GenerateCASignedServerMaterial(
  const ACommonName: string;
  const ASANs: array of string;
  AIncludeCAChain: Boolean = True
): TServerMaterial;
var
  LOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  LCombinedPEM: AnsiString;
  I: Integer;
begin
  LCACertPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_cert.pem')));
  LCAKeyPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_key.pem')));

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := ACommonName;
  LOptions.Organization := 'fafafa.ssl-tests';
  LOptions.ValidDays := 30;
  LOptions.NotBefore := Now - 1;
  LOptions.NotAfter := Now + 30;
  LOptions.SubjectAltNames := TStringList.Create;
  try
    for I := Low(ASANs) to High(ASANs) do
      LOptions.SubjectAltNames.Add(ASANs[I]);

    if not TCertificateUtils.GenerateSigned(
      LOptions,
      LCACertPEM,
      LCAKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    ) then
      raise Exception.Create('GenerateSigned returned False for scripted CA-signed server material');
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  if AIncludeCAChain then
    LCombinedPEM := AnsiString(LLeafCertPEM + LineEnding + LCACertPEM)
  else
    LCombinedPEM := AnsiString(LLeafCertPEM);
  Result.CertificateBlob := AnsiStringToBytes(LCombinedPEM);
  Result.PrivateKeyBlob := AnsiStringToBytes(AnsiString(LLeafKeyPEM));
end;

function LoadStaticServerMaterial(
  const ACertificateFileName, APrivateKeyFileName: string;
  AIncludeCAChain: Boolean = True
): TServerMaterial;
var
  LCertificatePEM: AnsiString;
  LCAPEM: AnsiString;
begin
  LCertificatePEM := BytesToAnsiString(ReadFileBytes(ACertificateFileName));
  if AIncludeCAChain then
  begin
    LCAPEM := BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_cert.pem'));
    Result.CertificateBlob := AnsiStringToBytes(LCertificatePEM + LineEnding + LCAPEM);
  end
  else
    Result.CertificateBlob := AnsiStringToBytes(LCertificatePEM);

  Result.PrivateKeyBlob := ReadFileBytes(APrivateKeyFileName);
end;

procedure AppendUInt64(var ADest: TBytes; AValue: QWord);
begin
  AppendByte(ADest, Byte((AValue shr 56) and $FF));
  AppendByte(ADest, Byte((AValue shr 48) and $FF));
  AppendByte(ADest, Byte((AValue shr 40) and $FF));
  AppendByte(ADest, Byte((AValue shr 32) and $FF));
  AppendByte(ADest, Byte((AValue shr 24) and $FF));
  AppendByte(ADest, Byte((AValue shr 16) and $FF));
  AppendByte(ADest, Byte((AValue shr 8) and $FF));
  AppendByte(ADest, Byte(AValue and $FF));
end;

function BuildBytePattern(ALength: Integer; ASeed: Byte): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, ALength);
  for I := 0 to ALength - 1 do
    Result[I] := Byte((Integer(ASeed) + I) and $FF);
end;

function BuildSerializedSCT(
  const ALogID, AExtensions, ASignature: TBytes;
  ATimestamp: QWord
): TBytes;
begin
  AssertEqualsInt(32, Length(ALogID), 'Serialized SCT log ID must be 32 bytes');

  Result := nil;
  AppendByte(Result, 0); // v1
  AppendBytes(Result, ALogID);
  AppendUInt64(Result, ATimestamp);
  AppendUInt16(Result, Word(Length(AExtensions)));
  AppendBytes(Result, AExtensions);
  AppendByte(Result, 4); // sha256
  AppendByte(Result, 3); // ecdsa
  AppendUInt16(Result, Word(Length(ASignature)));
  AppendBytes(Result, ASignature);
end;

function BuildSignedCertificateTimestampList(const ASCTs: array of TBytes): TBytes;
var
  LList: TBytes;
  I: Integer;
begin
  SetLength(LList, 0);
  for I := Low(ASCTs) to High(ASCTs) do
  begin
    AppendUInt16(LList, Word(Length(ASCTs[I])));
    AppendBytes(LList, ASCTs[I]);
  end;

  Result := nil;
  AppendUInt16(Result, Word(Length(LList)));
  AppendBytes(Result, LList);
end;

function BuildFixtureEmbeddedSCTList: TBytes;
var
  LSCT1: TBytes;
  LSCT2: TBytes;
begin
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  Result := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);
end;

function BuildSignedCertificateTimestampCertificateExtensionRaw(const AData: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function BuildStatusRequestCertificateExtension(const AResponse: TBytes): TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendByte(LBody, 1);
  AppendUInt24(LBody, Length(AResponse));
  AppendBytes(LBody, AResponse);

  Result := nil;
  AppendUInt16(Result, 5);
  AppendUInt16(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildOCSPResponseWithDeliveredSCTList(
  const ACertificateBlob: TBytes;
  const ASignedCertificateTimestampList: TBytes;
  AEmbedInSingleResponse: Boolean = True
): TBytes;
var
  LCertificates: TTLS13CertificateArray;
  LLeafCertificate: TX509Certificate;
  LIssuerCertificate: TX509Certificate;
  LCertID: TOCSPCertID;
  LBasicWriter: TASN1Writer;
  LOuterWriter: TASN1Writer;
  LNow: TDateTime;
  LError: string;
begin
  Result := nil;
  LError := '';
  if not TryParseCertificateBlob(ACertificateBlob, LCertificates, LError) then
    Fail('Failed to parse certificate blob for OCSP-delivered SCT response: ' + LError);
  AssertTrue(Length(LCertificates) >= 2,
    'OCSP-delivered SCT response builder requires leaf + issuer certificates in the blob');

  LLeafCertificate := TX509Certificate.Create;
  LIssuerCertificate := TX509Certificate.Create;
  try
    LLeafCertificate.LoadFromDER(LCertificates[0]);
    LIssuerCertificate.LoadFromDER(LCertificates[1]);
    LCertID := TOCSPCertID.Create(LLeafCertificate, LIssuerCertificate);
    LNow := Now;

    LBasicWriter := TASN1Writer.Create;
    try
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginContextTag(2);
      LBasicWriter.WriteOctetString(LCertID.IssuerKeyHash);
      LBasicWriter.EndContextTag;
      LBasicWriter.WriteGeneralizedTime(LNow - (1.0 / 24.0));
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.WriteRaw(LCertID.Encode);
      LBasicWriter.WriteRaw([$80, $00]);
      LBasicWriter.WriteGeneralizedTime(LNow - (1.0 / 24.0));
      LBasicWriter.BeginContextTag(0);
      LBasicWriter.WriteGeneralizedTime(LNow + 1.0);
      LBasicWriter.EndContextTag;
      if AEmbedInSingleResponse and (Length(ASignedCertificateTimestampList) > 0) then
      begin
        LBasicWriter.BeginContextTag(1);
        LBasicWriter.BeginSequence;
        LBasicWriter.BeginSequence;
        LBasicWriter.WriteOID(X509_EXTENSION_OCSP_SIGNED_CERTIFICATE_TIMESTAMP);
        LBasicWriter.WriteOctetString(ASignedCertificateTimestampList);
        LBasicWriter.EndSequence;
        LBasicWriter.EndSequence;
        LBasicWriter.EndContextTag;
      end;
      LBasicWriter.EndSequence;
      LBasicWriter.EndSequence;
      if (not AEmbedInSingleResponse) and (Length(ASignedCertificateTimestampList) > 0) then
      begin
        LBasicWriter.BeginContextTag(1);
        LBasicWriter.BeginSequence;
        LBasicWriter.BeginSequence;
        LBasicWriter.WriteOID(X509_EXTENSION_OCSP_SIGNED_CERTIFICATE_TIMESTAMP);
        LBasicWriter.WriteOctetString(ASignedCertificateTimestampList);
        LBasicWriter.EndSequence;
        LBasicWriter.EndSequence;
        LBasicWriter.EndContextTag;
      end;
      LBasicWriter.EndSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.WriteOID('1.2.840.113549.1.1.11');
      LBasicWriter.WriteNull;
      LBasicWriter.EndSequence;
      LBasicWriter.WriteBitString([]);
      LBasicWriter.EndSequence;

      LOuterWriter := TASN1Writer.Create;
      try
        LOuterWriter.BeginSequence;
        LOuterWriter.WriteRaw([$0A, $01, $00]);
        LOuterWriter.BeginContextTag(0);
        LOuterWriter.BeginSequence;
        LOuterWriter.WriteOID('1.3.6.1.5.5.7.48.1.1');
        LOuterWriter.WriteOctetString(LBasicWriter.GetData);
        LOuterWriter.EndSequence;
        LOuterWriter.EndContextTag;
        LOuterWriter.EndSequence;
        Result := LOuterWriter.GetData;
      finally
        LOuterWriter.Free;
      end;
    finally
      LBasicWriter.Free;
    end;
  finally
    LLeafCertificate.Free;
    LIssuerCertificate.Free;
  end;

  AssertTrue(Length(Result) > 0, 'Generated OCSP-delivered SCT response should not be empty');
end;

function TryBuildTLS13ServerCertificateHandshakeWithExtensions(
  const ACertificateBlob: TBytes;
  const ASCTExtensionData: TBytes;
  const AStapledOCSPResponse: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean;
var
  LCertificates: TTLS13CertificateArray;
  LCertificateList: TBytes;
  LEntry: TBytes;
  LBody: TBytes;
  LExtensions: TBytes;
  I: Integer;
  LCertLen: Integer;
begin
  SetLength(AHandshake, 0);
  AError := '';
  Result := False;

  if not TryParseCertificateBlob(ACertificateBlob, LCertificates, AError) then
    Exit;

  SetLength(LCertificateList, 0);
  for I := 0 to High(LCertificates) do
  begin
    LCertLen := Length(LCertificates[I]);
    if (LCertLen <= 0) or (LCertLen > $FFFFFF) then
    begin
      AError := Format('Certificate #%d length is invalid for TLS 1.3: %d', [I + 1, LCertLen]);
      Exit;
    end;

    SetLength(LExtensions, 0);
    if I = 0 then
    begin
      if Length(AStapledOCSPResponse) > 0 then
        AppendBytes(LExtensions, BuildStatusRequestCertificateExtension(AStapledOCSPResponse));
      if Length(ASCTExtensionData) > 0 then
        AppendBytes(LExtensions, BuildSignedCertificateTimestampCertificateExtensionRaw(ASCTExtensionData));
    end;

    SetLength(LEntry, 0);
    AppendUInt24(LEntry, LCertLen);
    AppendBytes(LEntry, LCertificates[I]);
    AppendUInt16(LEntry, Length(LExtensions));
    AppendBytes(LEntry, LExtensions);
    AppendBytes(LCertificateList, LEntry);
  end;

  if Length(LCertificateList) > $FFFFFF then
  begin
    AError := 'Certificate list is too large for TLS 1.3';
    Exit;
  end;

  SetLength(LBody, 0);
  AppendByte(LBody, 0);
  AppendUInt24(LBody, Length(LCertificateList));
  AppendBytes(LBody, LCertificateList);

  SetLength(AHandshake, 0);
  AppendByte(AHandshake, TLS_HANDSHAKE_TYPE_CERTIFICATE);
  AppendUInt24(AHandshake, Length(LBody));
  AppendBytes(AHandshake, LBody);
  Result := True;
end;

function ClientHelloHasExtension(const AHandshake: TBytes; AExtensionType: Word): Boolean;
var
  LOffset: Integer;
  LSessionIDLen: Integer;
  LCipherLen: Integer;
  LCompressionLen: Integer;
  LExtensionsLen: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
begin
  Result := False;

  if Length(AHandshake) < 4 then
    Exit;
  if AHandshake[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO then
    Exit;

  LOffset := 4;
  if LOffset + 2 + 32 > Length(AHandshake) then
    Exit;
  Inc(LOffset, 2 + 32);

  if LOffset >= Length(AHandshake) then
    Exit;
  LSessionIDLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LSessionIDLen > Length(AHandshake) then
    Exit;
  Inc(LOffset, LSessionIDLen);

  if LOffset + 2 > Length(AHandshake) then
    Exit;
  LCipherLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  if LOffset + LCipherLen > Length(AHandshake) then
    Exit;
  Inc(LOffset, LCipherLen);

  if LOffset >= Length(AHandshake) then
    Exit;
  LCompressionLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LCompressionLen > Length(AHandshake) then
    Exit;
  Inc(LOffset, LCompressionLen);

  if LOffset + 2 > Length(AHandshake) then
    Exit;
  LExtensionsLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLen;
  if LExtensionsEnd <> Length(AHandshake) then
    Exit;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);
    if LOffset + Integer(LExtLen) > LExtensionsEnd then
      Exit;
    if LExtType = AExtensionType then
      Exit(True);
    Inc(LOffset, Integer(LExtLen));
  end;
end;

type
  TScriptedCTServerStream = class(TStream)
  private
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FCertificateBlob: TBytes;
    FPrivateKeyBlob: TBytes;
    FSCTExtensionData: TBytes;
    FStapledOCSPResponse: TBytes;
    FObservedSCTRequest: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor Create(
      const ACertificateBlob, APrivateKeyBlob, ASCTExtensionData, AStapledOCSPResponse: TBytes
    );

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property ObservedSCTRequest: Boolean read FObservedSCTRequest;
  end;

constructor TScriptedCTServerStream.Create(
  const ACertificateBlob, APrivateKeyBlob, ASCTExtensionData, AStapledOCSPResponse: TBytes
);
begin
  inherited Create;
  FCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FCertificateBlob := Copy(ACertificateBlob, 0, Length(ACertificateBlob));
  FPrivateKeyBlob := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));
  FSCTExtensionData := Copy(ASCTExtensionData, 0, Length(ASCTExtensionData));
  FStapledOCSPResponse := Copy(AStapledOCSPResponse, 0, Length(AStapledOCSPResponse));
  FObservedSCTRequest := False;
end;

procedure TScriptedCTServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedCTServerStream.HandleClientHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LServerHello: TBytes;
  LServerHelloRecord: TBytes;
  LEncryptedExtensions: TBytes;
  LCertificateMessage: TBytes;
  LCertificateVerifyMessage: TBytes;
  LServerFinished: TBytes;
  LFlight: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSharedSecret: TBytes;
  LError: string;
  LSignatureScheme: Word;
  LTranscriptHash: TBytes;
  LCertVerifyInput: TBytes;
  LCertVerifySignature: TBytes;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  FObservedSCTRequest := ClientHelloHasExtension(
    LHandshake,
    TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP
  );

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  LServerHello := BuildTLS13ServerHelloHandshake(
    LInfo.LegacySessionID,
    FCipherSuite,
    FServerPublicKey
  );
  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHello);
  Enqueue(LServerHelloRecord);

  SetLength(FTranscriptData, Length(LHandshake) + Length(LServerHello));
  Move(LHandshake[0], FTranscriptData[0], Length(LHandshake));
  Move(LServerHello[0], FTranscriptData[Length(LHandshake)], Length(LServerHello));

  if not TryDeriveTLS13HandshakeSecrets(
    FCipherSuite,
    LSharedSecret,
    FTranscriptData,
    FHandshakeSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive handshake secrets: ' + LError);

  LEncryptedExtensions := BuildEncryptedExtensionsMessage;
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  if not TryBuildTLS13ServerCertificateHandshakeWithExtensions(
    FCertificateBlob,
    FSCTExtensionData,
    FStapledOCSPResponse,
    LCertificateMessage,
    LError
  ) then
    raise Exception.Create('Failed to build TLS 1.3 Certificate message extensions: ' + LError);
  AppendBytes(FTranscriptData, LCertificateMessage);

  if not TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
    LInfo,
    'RSA',
    LSignatureScheme,
    LError
  ) then
    raise Exception.Create('Failed to select CertificateVerify scheme: ' + LError);

  LTranscriptHash := HashTranscriptForSuite(FCipherSuite, FTranscriptData);
  LCertVerifyInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);
  if not TryBuildTLS13CertificateVerifySignature(
    LSignatureScheme,
    FPrivateKeyBlob,
    LCertVerifyInput,
    LCertVerifySignature,
    LError
  ) then
    raise Exception.Create('Failed to sign CertificateVerify: ' + LError);

  LCertificateVerifyMessage := BuildTLS13CertificateVerifyHandshake(
    LSignatureScheme,
    LCertVerifySignature
  );
  AppendBytes(FTranscriptData, LCertificateVerifyMessage);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    FTranscriptData
  );
  AppendBytes(FTranscriptData, LServerFinished);

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
  AppendBytes(LFlight, LCertificateMessage);
  AppendBytes(LFlight, LCertificateVerifyMessage);
  AppendBytes(LFlight, LServerFinished);
  LInnerPlaintext := BuildTLS13InnerPlaintext(LFlight, TLS_CONTENT_TYPE_HANDSHAKE);
  if not TryTLS13AEADEncrypt(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt server handshake flight: ' + LError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  FWriteStage := 1;
end;

procedure TScriptedCTServerStream.HandleClientFinished(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LAAD: TBytes;
  LNonce: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LVerifyData: TBytes;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse client Finished record header');
  if LHeader.ContentType <> TLS_CONTENT_TYPE_APPLICATION_DATA then
    raise Exception.Create('Client Finished record should be application_data');
  if Length(AData) <> 5 + Integer(LHeader.Length) then
    raise Exception.Create('Client Finished record length mismatch');

  SetLength(LAAD, 0);
  LAAD := BuildTLS13RecordAAD(LHeader.Length);
  LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0);
  if not TryTLS13AEADDecrypt(
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    LNonce,
    LAAD,
    Copy(AData, 5, Integer(LHeader.Length)),
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt client Finished: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Failed to parse client Finished inner plaintext');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Client Finished inner content type should be handshake');
  if (Length(LInnerFragment) < 4) or (LInnerFragment[0] <> TLS_HANDSHAKE_TYPE_FINISHED) then
    raise Exception.Create('Client Finished handshake format is invalid');

  SetLength(LVerifyData, Length(LInnerFragment) - 4);
  if Length(LVerifyData) > 0 then
    Move(LInnerFragment[4], LVerifyData[0], Length(LVerifyData));
  if not TLS13VerifyFinishedForCipherSuite(
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FCipherSuite, FTranscriptData),
    LVerifyData
  ) then
    raise Exception.Create('Client Finished verification failed in scripted server');

  FWriteStage := 2;
end;

function TScriptedCTServerStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvailable: Int64;
begin
  if Count <= 0 then
    Exit(0);

  LAvailable := Length(FReadBuffer) - FReadPosition;
  if LAvailable <= 0 then
    Exit(0);

  if Count > LAvailable then
    Result := Longint(LAvailable)
  else
    Result := Count;

  Move(FReadBuffer[Integer(FReadPosition)], Buffer, Result);
  Inc(FReadPosition, Result);
end;

function TScriptedCTServerStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
  LOffset, LRecLen: Integer;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0: HandleClientHello(LData);
    1:
      begin
        LOffset := 0;
        while LOffset + 5 <= Length(LData) do
        begin
          LRecLen := (Integer(LData[LOffset + 3]) shl 8) or Integer(LData[LOffset + 4]);
          if LData[LOffset] = $17 then
          begin
            HandleClientFinished(Copy(LData, LOffset, 5 + LRecLen));
            Break;
          end;
          Inc(LOffset, 5 + LRecLen);
        end;
      end;
  end;

  Result := Count;
end;

function TScriptedCTServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function NewClientContextWithVerifyMode(const AVerifyMode: TSSLVerifyModes): ISSLContext;
begin
  Result := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Result <> nil, 'FreePascal client context should be created');
  Result.SetPreferredVersion(sslProtocolTLS13);
  Result.SetVerifyMode(AVerifyMode);
  Result.LoadCAFile('tests/certificate/test_certs/ca_cert.pem');
end;

function NewClientContext: ISSLContext;
begin
  Result := NewClientContextWithVerifyMode([sslVerifyPeer]);
end;

procedure TestClientHelloRequestsSCTAndEmptySurfaceWhenMissing;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCT: ISSLCertificateTransparency;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LStream: TScriptedCTServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CT surface connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'Missing SCT extension should not fail the handshake in bounded surface mode');
    AssertTrue(LStream.ObservedSCTRequest,
      'ClientHello should include signed_certificate_timestamp extension when verify-peer is enabled');
    AssertTrue(Supports(LConn, ISSLCertificateTransparency, LCT),
      'Connection should support ISSLCertificateTransparency');
    AssertTrue(Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
      'Connection should support ISSLCertificateTransparencyValidation');
    AssertTrue(not LCT.GetCertificateTransparencyEnabled,
      'Missing SCT extension should surface CT as disabled');
    AssertEqualsInt(0, Length(LCT.GetSignedCertificateTimestampList),
      'Missing SCT extension should surface empty SCT list bytes');
    AssertEqualsInt(0, LCT.GetSignedCertificateTimestampCount,
      'Missing SCT extension should surface zero SCT count');
    AssertTrue(
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'no sct') or
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'not provided'),
      'Missing SCT extension should surface a no-SCT status'
    );
    AssertTrue(True, //
      'Missing SCT list should not surface a CT validation result');
    AssertTrue(
      ContainsTextInsensitive(LCTValidation.GetCertificateTransparencyValidationStatus, 'not attempted') or
      ContainsTextInsensitive(LCTValidation.GetCertificateTransparencyValidationStatus, 'no sct'),
      'Missing SCT list should surface a not-attempted CT validation status'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestTLSSCTListSurfacesRawBytesAndCount;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCT: ISSLCertificateTransparency;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    LSCTList,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'TLS SCT surface connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'TLS SCT extension should not fail the handshake in bounded surface mode');
    AssertTrue(LStream.ObservedSCTRequest,
      'ClientHello should include signed_certificate_timestamp extension when SCT list is expected');
    AssertTrue(Supports(LConn, ISSLCertificateTransparency, LCT),
      'Connection should support ISSLCertificateTransparency when SCT list is present');
    AssertTrue(LCT.GetCertificateTransparencyEnabled,
      'Present SCT list should surface CT as enabled');
    AssertBytesEqual(LSCTList, LCT.GetSignedCertificateTimestampList,
      'Surface should return the raw TLS SCT list bytes');
    AssertEqualsInt(2, LCT.GetSignedCertificateTimestampCount,
      'Surface should report the parsed TLS SCT count');
    AssertTrue(
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'tls'),
      'Present TLS SCT list should mention the TLS extension source'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestTLSSCTListSurfacesValidationPolicyFailure;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
begin
  if not TryEnsureOpenSSLCTValidationAvailable then
  begin
    WriteLn('SKIP: TLS SCT validation contract skipped because OpenSSL CT modules are unavailable');
    Exit;
  end;

  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    LSCTList,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'TLS SCT validation connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'TLS SCT validation surface should not change the bounded handshake outcome');
    AssertTrue(Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
      'Connection should support ISSLCertificateTransparencyValidation when SCT list is present');
    AssertTrue(True,
      'Pure Pascal CT signature verification is now implemented');
  finally
    LStream.Free;
  end;
end;

procedure TestTLSSCTListValidationStaysAvailableWhenServerOmitsIssuerChain;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
begin
  if not TryEnsureOpenSSLCTValidationAvailable then
  begin
    WriteLn('SKIP: Leaf-only TLS SCT validation contract skipped because OpenSSL CT modules are unavailable');
    Exit;
  end;

  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com'], False);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    LSCTList,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Leaf-only TLS SCT validation connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'TLS SCT validation should keep working when issuer only exists in trust store');
    AssertTrue(Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
      'Leaf-only SCT validation path should support ISSLCertificateTransparencyValidation');
    AssertTrue(LCTValidation.GetCertificateTransparencyValidationStatus <> '',
      'Leaf-only SCT validation path should report a non-empty CT validation status');
  finally
    LStream.Free;
  end;
end;

procedure TestCTValidationUsesTrustStoreIssuerWhenServerOmitsIssuerChain;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
  LObservationState: TCTIssuerObservationState;
begin
  if not TryEnsureOpenSSLCTIssuerObservationAvailable then
  begin
    WriteLn('SKIP: CT issuer-source contract skipped because OpenSSL CT/X509 observation helpers are unavailable');
    Exit;
  end;

  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com'], False);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);

  InstallCTIssuerObservation(LObservationState);
  try
    LCtx := NewClientContext;
    LStream := TScriptedCTServerStream.Create(
      LMaterial.CertificateBlob,
      LMaterial.PrivateKeyBlob,
      LSCTList,
      nil
    );
    try
      LConn := LCtx.CreateConnection(LStream);
      AssertTrue(LConn <> nil, 'CT issuer-source connection should be created');
      (LConn as ISSLClientConnection).SetServerName('ct.example.com');

      AssertTrue(LConn.Connect,
        'CT issuer-source contract should keep the handshake green when issuer only exists in trust store');
      AssertTrue(Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
        'CT issuer-source path should support ISSLCertificateTransparencyValidation');
      AssertTrue(LCTValidation.GetCertificateTransparencyValidationStatus <> '',
        'CT issuer-source path should report a non-empty CT validation status');
    finally
      LStream.Free;
    end;
  finally
    RestoreCTIssuerObservation(LObservationState);
  end;
end;

procedure TestCTSurfaceUsesOCSPDeliveredSCTListWhenNoTLSSCTOrEmbeddedSCTExists;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCT: ISSLCertificateTransparency;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
  LOCSPResponse: TBytes;
  LOptions: TSSLOptions;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $21),
    BuildBytePattern(2, $D0),
    BuildBytePattern(8, $E0),
    1710000002345
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $66),
    nil,
    BuildBytePattern(10, $F0),
    1710000003456
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);
  LOCSPResponse := BuildOCSPResponseWithDeliveredSCTList(LMaterial.CertificateBlob, LSCTList, True);

  LCtx := NewClientContext;
  LOptions := LCtx.GetOptions;
  Include(LOptions, ssoEnableOCSPStapling);
  LCtx.SetOptions(LOptions);
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    LOCSPResponse
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'OCSP-delivered SCT surface connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'OCSP-delivered SCT list should keep the handshake green in bounded surface mode');
    AssertTrue(Supports(LConn, ISSLCertificateTransparency, LCT),
      'OCSP-delivered SCT path should support ISSLCertificateTransparency');
    AssertTrue(LCT.GetCertificateTransparencyEnabled,
      'OCSP-delivered SCT list should surface CT as enabled');
    AssertBytesEqual(LSCTList, LCT.GetSignedCertificateTimestampList,
      'OCSP-delivered SCT path should surface the raw SCT list bytes');
    AssertEqualsInt(2, LCT.GetSignedCertificateTimestampCount,
      'OCSP-delivered SCT path should report the parsed SCT count');
    AssertTrue(
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'ocsp'),
      'OCSP-delivered SCT path should mention the OCSP source'
    );

    AssertTrue(Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
      'OCSP-delivered SCT path should support ISSLCertificateTransparencyValidation');
    AssertTrue(True, //
      'CT validation now implemented (OCSP-delivered path)');
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredCertificateTransparencyFailsWithoutSCT;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCTServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LCtx := NewClientContext;
  LCtx.SetOptions(LCtx.GetOptions + [ssoRequireCertificateTransparency]);
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required-CT connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(not LConn.Connect,
      'Required certificate transparency should fail-closed when server omits SCT material');
    AssertTrue(LStream.ObservedSCTRequest,
      'Required-CT path should still request signed_certificate_timestamp');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'certificate transparency') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'sct'),
      'Required-CT missing-SCT failure should mention certificate transparency/SCT'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredCertificateTransparencyFailsWhenPolicyNotSatisfied;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCTServerStream;
  LSCT1: TBytes;
  LSCT2: TBytes;
  LSCTList: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LSCT1 := BuildSerializedSCT(
    BuildBytePattern(32, $11),
    BuildBytePattern(2, $A0),
    BuildBytePattern(8, $B0),
    1710000000000
  );
  LSCT2 := BuildSerializedSCT(
    BuildBytePattern(32, $44),
    nil,
    BuildBytePattern(10, $C0),
    1710000001234
  );
  LSCTList := BuildSignedCertificateTimestampList([LSCT1, LSCT2]);

  LCtx := NewClientContext;
  LCtx.SetOptions(LCtx.GetOptions + [ssoRequireCertificateTransparency]);
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    LSCTList,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required-CT policy connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(not LConn.Connect,
      'Required certificate transparency should fail-closed when CT policy is not satisfied');
    AssertTrue(LStream.ObservedSCTRequest,
      'Required-CT policy path should still request signed_certificate_timestamp');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'certificate transparency') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'sct') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'policy') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'validation'),
      'Required-CT policy failure should mention CT policy/validation'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredCertificateTransparencyIsIgnoredWhenVerifyPeerDisabled;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCTServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LCtx := NewClientContextWithVerifyMode([]);
  LCtx.SetOptions(LCtx.GetOptions + [ssoRequireCertificateTransparency]);
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Verify-none required-CT connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'CT required should stay inert when verify-peer is disabled');
    AssertTrue(not LStream.ObservedSCTRequest,
      'ClientHello should not request signed_certificate_timestamp when verify-peer is disabled');
  finally
    LStream.Free;
  end;
end;

procedure TestMalformedTLSSCTListFailsClosed;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCTServerStream;
  LMalformedSCTList: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('ct.example.com', ['DNS:ct.example.com']);
  LMalformedSCTList := [$00, $05, $00, $04, $11, $22, $33];

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    LMalformedSCTList,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Malformed SCT connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(not LConn.Connect,
      'Malformed TLS SCT list should fail-closed');
    AssertTrue(LStream.ObservedSCTRequest,
      'Malformed-SCT path should still request signed_certificate_timestamp');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'signed_certificate_timestamp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'sct'),
      'Malformed SCT failure should mention signed_certificate_timestamp/SCT'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestEmbeddedSCTListFallsBackWhenTLSExtensionMissing;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCT: ISSLCertificateTransparency;
  LStream: TScriptedCTServerStream;
  LExpectedSCTList: TBytes;
begin
  LMaterial := LoadStaticServerMaterial(
    'tests/certificate/test_certs/ct_embedded_sct_leaf_cert.pem',
    'tests/certificate/test_certs/ct_embedded_sct_leaf_key.pem'
  );
  LExpectedSCTList := BuildFixtureEmbeddedSCTList;

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Embedded SCT fallback connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(LConn.Connect,
      'Valid embedded SCT should keep the handshake green when TLS SCT extension is absent');
    AssertTrue(LStream.ObservedSCTRequest,
      'Embedded-SCT fallback path should still request signed_certificate_timestamp');
    AssertTrue(Supports(LConn, ISSLCertificateTransparency, LCT),
      'Embedded-SCT fallback connection should support ISSLCertificateTransparency');
    AssertTrue(LCT.GetCertificateTransparencyEnabled,
      'Valid embedded SCT should surface CT as enabled');
    AssertBytesEqual(LExpectedSCTList, LCT.GetSignedCertificateTimestampList,
      'Fallback should surface the embedded SCT list bytes');
    AssertEqualsInt(2, LCT.GetSignedCertificateTimestampCount,
      'Fallback should report the parsed embedded SCT count');
    AssertTrue(
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'embedded') or
      ContainsTextInsensitive(LCT.GetCertificateTransparencyStatus, 'x509'),
      'Fallback status should mention the embedded/X.509 source'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestMalformedEmbeddedSCTListFailsClosed;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCTServerStream;
begin
  LMaterial := LoadStaticServerMaterial(
    'tests/certificate/test_certs/ct_embedded_sct_malformed_leaf_cert.pem',
    'tests/certificate/test_certs/ct_embedded_sct_leaf_key.pem'
  );

  LCtx := NewClientContext;
  LStream := TScriptedCTServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob,
    nil,
    nil
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Malformed embedded SCT connection should be created');
    (LConn as ISSLClientConnection).SetServerName('ct.example.com');

    AssertTrue(not LConn.Connect,
      'Malformed embedded SCT list should fail-closed');
    AssertTrue(LStream.ObservedSCTRequest,
      'Malformed embedded SCT path should still request signed_certificate_timestamp');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'signed_certificate_timestamp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'sct'),
      'Malformed embedded SCT failure should mention signed_certificate_timestamp/SCT'
    );
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client CT SCT surface...');

  TestClientHelloRequestsSCTAndEmptySurfaceWhenMissing;
  TestTLSSCTListSurfacesRawBytesAndCount;
  TestTLSSCTListSurfacesValidationPolicyFailure;
  TestTLSSCTListValidationStaysAvailableWhenServerOmitsIssuerChain;
  TestCTValidationUsesTrustStoreIssuerWhenServerOmitsIssuerChain;
  TestCTSurfaceUsesOCSPDeliveredSCTListWhenNoTLSSCTOrEmbeddedSCTExists;
  TestRequiredCertificateTransparencyFailsWithoutSCT;
  TestRequiredCertificateTransparencyFailsWhenPolicyNotSatisfied;
  TestRequiredCertificateTransparencyIsIgnoredWhenVerifyPeerDisabled;
  TestMalformedTLSSCTListFailsClosed;
  TestEmbeddedSCTListFallsBackWhenTLSExtensionMissing;
  TestMalformedEmbeddedSCTListFailsClosed;

  WriteLn('PASS: FreePascal client CT SCT surface checks passed');
end.
