program test_freepascal_tls13_early_data;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, DateUtils, Process,
  {$IFDEF UNIX}BaseUnix, Unix,{$ENDIF}
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.posthandshake,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.freepascal.earlydatareplay,
  nextpas.core.tls.freepascal.earlydatareplay.dirstore,
  nextpas.core.tls.freepascal.earlydatareplay.fileprovider,
  nextpas.core.tls.freepascal.session;

type
  TScriptedServerMode = (ssmInitial, ssmResumedAccept, ssmResumedReject);
  TScriptedClientMode = (scmInitial, scmResumedAccept, scmResumedReject);

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
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

function RequireSessionResumption(
  const AConn: ISSLConnection;
  const AMessage: string
): ISSLSessionResumption;
begin
  AssertTrue(Supports(AConn, ISSLSessionResumption, Result), AMessage);
end;

procedure AssertSessionReused(const AConn: ISSLConnection; const AMessage: string);
begin
  AssertTrue(
    RequireSessionResumption(
      AConn,
      AMessage + ' (connection should expose ISSLSessionResumption owner path)'
    ).IsSessionReused,
    AMessage
  );
end;

const
  TEST_FILE_REPLAY_PROVIDER_VERSION = 1;
  TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION = 99;
  TEST_INVALID_REPLAY_PROVIDER_ENTRY_COUNT = 100001;
  TEST_INVALID_REPLAY_PROVIDER_KEY_LENGTH = 4097;
  REPLAY_PROVIDER_TRAILING_GARBAGE_BYTES: array[0..3] of Byte = ($BA, $D0, $0D, $42);
  REPLAY_PROVIDER_DIRECTORY_TRAILING_GARBAGE_BYTES: array[0..2] of Byte = ($DE, $AD, $21);
  TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER = 'installer';
  TEST_REPLAY_PROVIDER_CONTEXT_PATH_DEFAULT = 'default_shipped_path';
  TEST_REPLAY_PROVIDER_CONTEXT_PATH_BUILDER = 'builder';
  TEST_REPLAY_PROVIDER_CONTEXT_PATH_FACTORY = 'factory';
  TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE = 'directory_store';
  TEST_REPLAY_PROVIDER_EXPECT_REJECT = 'reject';
  TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY = 'reject_only';
  TEST_REPLAY_PROVIDER_EXPECT_ACCEPT_THEN_REJECT = 'accept_then_reject';
  TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE = '--hold-replay-provider-lock';
  TEST_REPLAY_PROVIDER_RUNTIME_CRASH_ACCEPT_MODE = '--runtime-crash-accept';
  TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE = '--runtime-replay-probe';
  TEST_REPLAY_PROVIDER_SIMULATED_CRASH_EXIT_CODE = 86;

var
  GDefaultReplayStoreBaselineDirectory: string = '';

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AppendHandshakeBytes(var ADest: TBytes; const ASource: TBytes);
var
  LOldLen: Integer;
begin
  if Length(ASource) = 0 then
    Exit;

  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + Length(ASource));
  Move(ASource[0], ADest[LOldLen], Length(ASource));
end;

procedure AppendVector16(var ADest: TBytes; const AValue: TBytes);
begin
  AppendUInt16(ADest, Word(Length(AValue)));
  AppendBytes(ADest, AValue);
end;

function TryPopHandshakeMessage(var ABuffer: TBytes; out AMessage: TBytes): Boolean;
var
  LBodyLen: Cardinal;
  LTotalLen: Integer;
  LRemainLen: Integer;
  LTemp: TBytes;
begin
  SetLength(AMessage, 0);
  Result := False;

  if Length(ABuffer) < 4 then
    Exit;

  LBodyLen := ReadUInt24(ABuffer, 1);
  if LBodyLen > Cardinal(High(Integer) - 4) then
    Exit;

  LTotalLen := 4 + Integer(LBodyLen);
  if Length(ABuffer) < LTotalLen then
    Exit;

  SetLength(AMessage, LTotalLen);
  Move(ABuffer[0], AMessage[0], LTotalLen);

  LRemainLen := Length(ABuffer) - LTotalLen;
  if LRemainLen > 0 then
  begin
    SetLength(LTemp, LRemainLen);
    Move(ABuffer[LTotalLen], LTemp[0], LRemainLen);
    ABuffer := LTemp;
  end
  else
    SetLength(ABuffer, 0);

  Result := True;
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  Result := nil;
end;

function BuildEncryptedExtensionsMessage(AAcceptEarlyData: Boolean): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
begin
  SetLength(LExtensions, 0);
  if AAcceptEarlyData then
  begin
    AppendUInt16(LExtensions, TLS_EXTENSION_EARLY_DATA);
    AppendUInt16(LExtensions, 0);
  end;

  SetLength(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildFinishedMessage(
  ACipherSuite: Word;
  const AHandshakeTrafficSecret: TBytes;
  const ATranscriptData: TBytes
): TBytes;
var
  LVerifyData: TBytes;
begin
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    ACipherSuite,
    AHandshakeTrafficSecret,
    HashTranscriptForSuite(ACipherSuite, ATranscriptData)
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
end;

function BuildNewSessionTicketMessage(
  ATicketLifetime, ATicketAgeAdd: Cardinal;
  const ATicketNonce, ATicket: TBytes;
  AMaxEarlyDataSize: Cardinal
): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
begin
  SetLength(LBody, 0);
  AppendByte(LBody, Byte((ATicketLifetime shr 24) and $FF));
  AppendByte(LBody, Byte((ATicketLifetime shr 16) and $FF));
  AppendByte(LBody, Byte((ATicketLifetime shr 8) and $FF));
  AppendByte(LBody, Byte(ATicketLifetime and $FF));

  AppendByte(LBody, Byte((ATicketAgeAdd shr 24) and $FF));
  AppendByte(LBody, Byte((ATicketAgeAdd shr 16) and $FF));
  AppendByte(LBody, Byte((ATicketAgeAdd shr 8) and $FF));
  AppendByte(LBody, Byte(ATicketAgeAdd and $FF));

  AppendByte(LBody, Byte(Length(ATicketNonce)));
  AppendBytes(LBody, ATicketNonce);
  AppendVector16(LBody, ATicket);

  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS_EXTENSION_EARLY_DATA);
  AppendUInt16(LExtensions, 4);
  AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 24) and $FF));
  AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 16) and $FF));
  AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 8) and $FF));
  AppendByte(LExtensions, Byte(AMaxEarlyDataSize and $FF));

  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildServerHelloWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word
): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
  LExt: TBytes;
  LRandom: TBytes;
begin
  SetLength(LRandom, 32);
  FillChar(LRandom[0], Length(LRandom), $66);

  SetLength(LExtensions, 0);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_SUPPORTED_VERSIONS);
  AppendUInt16(LExt, 2);
  AppendUInt16(LExt, TLS13_VERSION);
  AppendBytes(LExtensions, LExt);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_KEY_SHARE);
  AppendUInt16(LExt, Word(4 + Length(AServerKeyShare)));
  AppendUInt16(LExt, TLS13_GROUP_X25519);
  AppendUInt16(LExt, Word(Length(AServerKeyShare)));
  AppendBytes(LExt, AServerKeyShare);
  AppendBytes(LExtensions, LExt);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_PRE_SHARED_KEY);
  AppendUInt16(LExt, 2);
  AppendUInt16(LExt, ASelectedIdentity);
  AppendBytes(LExtensions, LExt);

  SetLength(LBody, 0);
  AppendUInt16(LBody, TLS_LEGACY_VERSION);
  AppendBytes(LBody, LRandom);
  AppendByte(LBody, Byte(Length(ALegacySessionID)));
  AppendBytes(LBody, ALegacySessionID);
  AppendUInt16(LBody, ACipherSuite);
  AppendByte(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

type
  TScriptedEarlyDataServerStream = class(TStream)
  private
    FMode: TScriptedServerMode;
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FEarlySecrets: TTLS13EarlyDataSecrets;
    FApplicationSecrets: TTLS13ApplicationSecrets;
    FPendingSession: IFreePascalResumptionSession;
    FEarlySeq: QWord;
    FHandshakeSeq: QWord;
    FEarlyPhaseOffered: Boolean;
    FEarlyPhaseDone: Boolean;
    FObservedEndOfEarlyData: Boolean;
    FCapturedEarlyData: TBytes;
    FObservedClientEarlyDataStatus: TSSLEarlyDataStatus;
    FObservedClientEarlyDataLimit: Cardinal;
    FCapturedSession: ISSLSession;

    procedure Enqueue(const AData: TBytes);
    procedure AppendCapturedEarlyData(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientPostHello(const AData: TBytes);
  public
    constructor CreateInitial(ACipherSuite: Word);
    constructor CreateResumed(const ASession: ISSLSession; AAcceptEarlyData: Boolean);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property CapturedEarlyData: TBytes read FCapturedEarlyData;
    property ObservedEndOfEarlyData: Boolean read FObservedEndOfEarlyData;
    property ObservedClientEarlyDataStatus: TSSLEarlyDataStatus read FObservedClientEarlyDataStatus;
    property ObservedClientEarlyDataLimit: Cardinal read FObservedClientEarlyDataLimit;
    property CapturedSession: ISSLSession read FCapturedSession;
  end;

constructor TScriptedEarlyDataServerStream.CreateInitial(ACipherSuite: Word);
begin
  inherited Create;
  FMode := ssmInitial;
  FCipherSuite := ACipherSuite;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  InitTLS13EarlyDataSecrets(FEarlySecrets);
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  FPendingSession := nil;
  FEarlySeq := 0;
  FHandshakeSeq := 0;
  FEarlyPhaseOffered := False;
  FEarlyPhaseDone := False;
  FObservedEndOfEarlyData := False;
  SetLength(FCapturedEarlyData, 0);
  FObservedClientEarlyDataStatus := sslEarlyDataNone;
  FObservedClientEarlyDataLimit := 0;
  FCapturedSession := nil;
end;

constructor TScriptedEarlyDataServerStream.CreateResumed(const ASession: ISSLSession; AAcceptEarlyData: Boolean);
begin
  CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  if AAcceptEarlyData then
    FMode := ssmResumedAccept
  else
    FMode := ssmResumedReject;
  if not Supports(ASession, IFreePascalResumptionSession, FPendingSession) then
    raise Exception.Create('Resumed early-data test requires FreePascal resumption session');
end;

procedure TScriptedEarlyDataServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedEarlyDataServerStream.AppendCapturedEarlyData(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FCapturedEarlyData);
  SetLength(FCapturedEarlyData, LOldLen + Length(AData));
  Move(AData[0], FCapturedEarlyData[LOldLen], Length(AData));
end;

procedure TScriptedEarlyDataServerStream.HandleClientHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LServerHello: TBytes;
  LServerHelloRecord: TBytes;
  LEncryptedExtensions: TBytes;
  LServerFinished: TBytes;
  LFlight: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSharedSecret: TBytes;
  LError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  FEarlyPhaseOffered := LInfo.HasEarlyData;

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  if FMode = ssmInitial then
    LServerHello := BuildTLS13ServerHelloHandshake(
      LInfo.LegacySessionID,
      FCipherSuite,
      FServerPublicKey
    )
  else
    LServerHello := BuildServerHelloWithSelectedPSK(
      LInfo.LegacySessionID,
      FCipherSuite,
      FServerPublicKey,
      0
    );

  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHello);
  Enqueue(LServerHelloRecord);

  SetLength(FTranscriptData, Length(LHandshake) + Length(LServerHello));
  Move(LHandshake[0], FTranscriptData[0], Length(LHandshake));
  Move(LServerHello[0], FTranscriptData[Length(LHandshake)], Length(LServerHello));

  if FMode = ssmInitial then
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive handshake secrets: ' + LError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FPendingSession.GetResumptionPSK,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LError);

    if FEarlyPhaseOffered then
    begin
      if not TryDeriveTLS13ClientEarlyDataSecrets(
        FCipherSuite,
        FPendingSession.GetResumptionPSK,
        LHandshake,
        FEarlySecrets,
        LError
      ) then
        raise Exception.Create('Failed to derive client early-data secrets: ' + LError);
      FObservedClientEarlyDataLimit := FPendingSession.GetMaxEarlyDataSize;
    end;
  end;

  LEncryptedExtensions := BuildEncryptedExtensionsMessage(
    (FMode = ssmResumedAccept) and FEarlyPhaseOffered
  );
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    FTranscriptData
  );

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
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
  AppendBytes(FTranscriptData, LServerFinished);

end;

procedure TScriptedEarlyDataServerStream.HandleClientPostHello(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LBuffer: TBytes;
  LMessage: TBytes;
  LVerifyData: TBytes;
  LTicketNonce: TBytes;
  LTicket: TBytes;
  LTicketMessage: TBytes;
  LTicketPlaintext: TBytes;
  LTicketEncrypted: TBytes;
  LTicketRecord: TBytes;
  LResumptionPSK: TBytes;
  LResumptionTranscript: TBytes;
  LSession: TFreePascalSession;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse post-ClientHello record');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Post-ClientHello record is truncated');
  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if FEarlyPhaseOffered and (not FEarlyPhaseDone) and FEarlySecrets.Valid then
  begin
    if TryTLS13AEADDecrypt(
      FCipherSuite,
      FEarlySecrets.ClientEarlyKey,
      BuildTLS13RecordNonce(FEarlySecrets.ClientEarlyIV, FEarlySeq),
      BuildTLS13RecordAAD(LHeader.Length),
      LPayload,
      LPlaintext,
      LError
    ) and
       TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) and
       (LInnerContentType = TLS_CONTENT_TYPE_APPLICATION_DATA) then
    begin
      if FMode = ssmResumedAccept then
        AppendCapturedEarlyData(LInnerFragment);
      Inc(FEarlySeq);
      Exit;
    end;
  end;

  if not TryTLS13AEADDecrypt(
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FHandshakeSeq),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt client handshake record: ' + LError);
  Inc(FHandshakeSeq);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in client handshake record');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Client handshake record carried unexpected inner content type');

  LBuffer := LInnerFragment;
  while TryPopHandshakeMessage(LBuffer, LMessage) do
  begin
    case LMessage[0] of
      TLS_HANDSHAKE_TYPE_END_OF_EARLY_DATA:
        begin
          if FMode <> ssmResumedAccept then
            raise Exception.Create('Server reject path must not receive EndOfEarlyData');
          FObservedEndOfEarlyData := True;
          FEarlyPhaseDone := True;
          AppendHandshakeBytes(FTranscriptData, LMessage);
        end;

      TLS_HANDSHAKE_TYPE_FINISHED:
        begin
          if not FEarlyPhaseDone and FEarlyPhaseOffered and (FMode = ssmResumedAccept) then
            raise Exception.Create('Accepted early-data path must send EndOfEarlyData before Finished');
          SetLength(LVerifyData, Length(LMessage) - 4);
          if Length(LVerifyData) > 0 then
            Move(LMessage[4], LVerifyData[0], Length(LVerifyData));
          if not TLS13VerifyFinishedForCipherSuite(
            FCipherSuite,
            FHandshakeSecrets.ClientHandshakeTrafficSecret,
            HashTranscriptForSuite(FCipherSuite, FTranscriptData),
            LVerifyData
          ) then
            raise Exception.Create('Client Finished verification failed');

          { Derive application secrets BEFORE appending Client Finished
            because RFC 8446 requires Transcript-Hash(CH..SF) only. }
          if FMode = ssmInitial then
          begin
            if not TryDeriveTLS13ApplicationSecrets(
              FCipherSuite,
              FHandshakeSecrets.HandshakeSecret,
              FTranscriptData,
              FApplicationSecrets,
              LError
            ) then
              raise Exception.Create('Failed to derive initial application secrets: ' + LError);

            LTicketNonce := [$01, $02, $03];
            LTicket := [$AA, $BB, $CC, $DD, $EE, $FF];
            LTicketMessage := BuildNewSessionTicketMessage(7200, $01020304, LTicketNonce, LTicket, 8);
            LTicketPlaintext := BuildTLS13InnerPlaintext(LTicketMessage, TLS_CONTENT_TYPE_HANDSHAKE);
            if not TryTLS13AEADEncrypt(
              FCipherSuite,
              FApplicationSecrets.ServerApplicationKey,
              BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 0),
              BuildTLS13RecordAAD(Word(Length(LTicketPlaintext) + TLS13AEADTagLength(FCipherSuite))),
              LTicketPlaintext,
              LTicketEncrypted,
              LError
            ) then
              raise Exception.Create('Failed to encrypt NewSessionTicket record: ' + LError);
            LTicketRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LTicketEncrypted);
            Enqueue(LTicketRecord);


            { RFC 8446: resumption_master_secret uses Hash(CH..CF) }
            LResumptionTranscript := Copy(FTranscriptData, 0, Length(FTranscriptData));
            AppendHandshakeBytes(LResumptionTranscript, LMessage);
            FApplicationSecrets.ResumptionTranscriptHash := HashTranscriptForSuite(
              FCipherSuite, LResumptionTranscript
            );
            LResumptionPSK := TLS13DeriveResumptionPSKFromTranscriptHash(
              FApplicationSecrets.CipherSuite,
              FApplicationSecrets.MasterSecret,
              FApplicationSecrets.ResumptionTranscriptHash,
              LTicketNonce
            );
            LSession := TFreePascalSession.Create;
            LSession.ConfigureResumption(
              FApplicationSecrets.CipherSuite,
              TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite),
              LTicketNonce,
              LTicket,
              LResumptionPSK,
              7200,
              $01020304,
              Now,
              7200,
              8
            );
            FCapturedSession := LSession;
          end;
          AppendHandshakeBytes(FTranscriptData, LMessage);
        end;
    else
      AppendHandshakeBytes(FTranscriptData, LMessage);
    end;
  end;
end;

function TScriptedEarlyDataServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedEarlyDataServerStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  if Length(FTranscriptData) = 0 then
    HandleClientHello(LData)
  else
    HandleClientPostHello(LData);

  Result := Count;
end;

function TScriptedEarlyDataServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

type
  TScriptedEarlyDataClientStream = class(TStream)
  private
    FMode: TScriptedClientMode;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FClientPrivateKey: TBytes;
    FClientPublicKey: TBytes;
    FClientHelloHandshake: TBytes;
    FTranscriptData: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FEarlySecrets: TTLS13EarlyDataSecrets;
    FApplicationSecrets: TTLS13ApplicationSecrets;
    FResumeSession: IFreePascalResumptionSession;
    FResumeBaseSession: ISSLSession;
    FEarlyData: TBytes;
    FObservedServerAcceptedEarlyData: Boolean;
    FCapturedSession: ISSLSession;

    procedure Enqueue(const AData: TBytes);
    procedure PrepareClientHello;
    procedure HandleServerHello(const AData: TBytes);
    procedure HandleServerHandshakeFlight(const AData: TBytes);
    procedure HandleServerPostHandshake(const AData: TBytes);
  public
    constructor CreateInitial;
    constructor CreateResumed(const ASession: ISSLSession; const AEarlyData: TBytes;
      AAcceptEarlyData: Boolean);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property ObservedServerAcceptedEarlyData: Boolean read FObservedServerAcceptedEarlyData;
    property CapturedSession: ISSLSession read FCapturedSession;
  end;

constructor TScriptedEarlyDataClientStream.CreateInitial;
begin
  inherited Create;
  FMode := scmInitial;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  InitTLS13EarlyDataSecrets(FEarlySecrets);
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  SetLength(FEarlyData, 0);
  FObservedServerAcceptedEarlyData := False;
  FCapturedSession := nil;
  PrepareClientHello;
end;

constructor TScriptedEarlyDataClientStream.CreateResumed(const ASession: ISSLSession;
  const AEarlyData: TBytes; AAcceptEarlyData: Boolean);
begin
  CreateInitial;
  if AAcceptEarlyData then
    FMode := scmResumedAccept
  else
    FMode := scmResumedReject;
  FResumeBaseSession := ASession;
  if not Supports(ASession, IFreePascalResumptionSession, FResumeSession) then
    raise Exception.Create('Resumed early-data scripted client requires FreePascal session');
  FEarlyData := Copy(AEarlyData, 0, Length(AEarlyData));
  PrepareClientHello;
end;

procedure TScriptedEarlyDataClientStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedEarlyDataClientStream.PrepareClientHello;
var
  LPskOffer: TTLS13ClientHelloPSKOffer;
  LSessionAgeMs: Int64;
  LPartialHandshake: TBytes;
  LClientHelloRecord: TBytes;
  LEarlyPlaintext: TBytes;
  LEarlyEncrypted: TBytes;
  LEarlyRecord: TBytes;
  LError: string;
begin
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  SetLength(FTranscriptData, 0);
  FObservedServerAcceptedEarlyData := False;
  FCapturedSession := nil;

  GenerateX25519KeyPair(FClientPrivateKey, FClientPublicKey);

  if FMode = scmInitial then
    FClientHelloHandshake := BuildTLS13ClientHelloHandshake('localhost', '', FClientPublicKey)
  else
  begin
    FillChar(LPskOffer, SizeOf(LPskOffer), 0);
    LSessionAgeMs := MilliSecondsBetween(Now, FResumeBaseSession.GetCreationTime);
    if LSessionAgeMs < 0 then
      LSessionAgeMs := 0;

    LPskOffer.Valid := True;
    LPskOffer.Identity := FResumeSession.GetTicket;
    LPskOffer.ObfuscatedTicketAge :=
      Cardinal((QWord(LSessionAgeMs) + QWord(FResumeSession.GetTicketAgeAdd)) and $FFFFFFFF);
    LPskOffer.AllowEarlyData := Length(FEarlyData) > 0;

    FClientHelloHandshake := BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
      'localhost',
      '',
      FClientPublicKey,
      FResumeSession.GetCipherSuite,
      LPskOffer.Identity,
      LPskOffer.ObfuscatedTicketAge,
      FResumeSession.GetResumptionPSK,
      LPartialHandshake,
      LPskOffer.AllowEarlyData
    );

    if Length(FEarlyData) > 0 then
    begin
      if not TryDeriveTLS13ClientEarlyDataSecrets(
        FResumeSession.GetCipherSuite,
        FResumeSession.GetResumptionPSK,
        FClientHelloHandshake,
        FEarlySecrets,
        LError
      ) then
        raise Exception.Create('Failed to derive scripted client early-data secrets: ' + LError);
    end;
  end;

  LClientHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, FClientHelloHandshake);
  Enqueue(LClientHelloRecord);

  if (FMode <> scmInitial) and (Length(FEarlyData) > 0) then
  begin
    LEarlyPlaintext := BuildTLS13InnerPlaintext(FEarlyData, TLS_CONTENT_TYPE_APPLICATION_DATA);
    if not TryTLS13AEADEncrypt(
      FResumeSession.GetCipherSuite,
      FEarlySecrets.ClientEarlyKey,
      BuildTLS13RecordNonce(FEarlySecrets.ClientEarlyIV, 0),
      BuildTLS13RecordAAD(Word(Length(LEarlyPlaintext) + TLS13AEADTagLength(FResumeSession.GetCipherSuite))),
      LEarlyPlaintext,
      LEarlyEncrypted,
      LError
    ) then
      raise Exception.Create('Failed to encrypt scripted client early-data record: ' + LError);
    LEarlyRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEarlyEncrypted);
    Enqueue(LEarlyRecord);
  end;
end;

procedure TScriptedEarlyDataClientStream.HandleServerHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LSharedSecret: TBytes;
  LError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ServerHello');
  if not TryParseServerHelloFromHandshake(LHandshake, LInfo) then
    raise Exception.Create('Failed to parse ServerHello');

  LSharedSecret := X25519ComputeSharedSecret(FClientPrivateKey, LInfo.PeerKeyShare);
  SetLength(FTranscriptData, Length(FClientHelloHandshake) + Length(LHandshake));
  Move(FClientHelloHandshake[0], FTranscriptData[0], Length(FClientHelloHandshake));
  Move(LHandshake[0], FTranscriptData[Length(FClientHelloHandshake)], Length(LHandshake));

  if FMode = scmInitial then
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      LInfo.SelectedCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive initial handshake secrets: ' + LError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      LInfo.SelectedCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FResumeSession.GetResumptionPSK,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LError);
  end;
end;

procedure TScriptedEarlyDataClientStream.HandleServerHandshakeFlight(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LBuffer: TBytes;
  LMessage: TBytes;
  LEEInfo: TTLS13EncryptedExtensionsInfo;
  LVerifyData: TBytes;
  LClientFlight: TBytes;
  LTranscriptForClientFinished: TBytes;
  LFinishedMessage: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse server handshake flight header');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Server handshake flight is truncated');
  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FHandshakeSecrets.CipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server handshake flight: ' + LError);
  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server flight');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server handshake flight should carry handshake content');

  LBuffer := LInnerFragment;
  while TryPopHandshakeMessage(LBuffer, LMessage) do
  begin
    if LMessage[0] = TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS then
    begin
      if not TryParseTLS13EncryptedExtensions(LMessage, LEEInfo, LError) then
        raise Exception.Create('Failed to parse EncryptedExtensions: ' + LError);
      FObservedServerAcceptedEarlyData := LEEInfo.HasEarlyData;
      AppendHandshakeBytes(FTranscriptData, LMessage);
    end
    else if LMessage[0] = TLS_HANDSHAKE_TYPE_FINISHED then
    begin
      SetLength(LVerifyData, Length(LMessage) - 4);
      if Length(LVerifyData) > 0 then
        Move(LMessage[4], LVerifyData[0], Length(LVerifyData));
      if not TLS13VerifyFinishedForCipherSuite(
        FHandshakeSecrets.CipherSuite,
        FHandshakeSecrets.ServerHandshakeTrafficSecret,
        HashTranscriptForSuite(FHandshakeSecrets.CipherSuite, FTranscriptData),
        LVerifyData
      ) then
        raise Exception.Create('Server Finished verification failed');
      AppendHandshakeBytes(FTranscriptData, LMessage);
    end
    else
      AppendHandshakeBytes(FTranscriptData, LMessage);
  end;

  SetLength(LClientFlight, 0);
  if (FMode <> scmInitial) and (Length(FEarlyData) > 0) and FObservedServerAcceptedEarlyData then
    AppendHandshakeBytes(LClientFlight, BuildTLS13EndOfEarlyDataHandshake);

  LTranscriptForClientFinished := Copy(FTranscriptData, 0, Length(FTranscriptData));
  AppendBytes(LTranscriptForClientFinished, LClientFlight);
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    FHandshakeSecrets.CipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FHandshakeSecrets.CipherSuite, LTranscriptForClientFinished)
  );
  SetLength(LFinishedMessage, 0);
  AppendByte(LFinishedMessage, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(LFinishedMessage, Length(LVerifyData));
  AppendBytes(LFinishedMessage, LVerifyData);
  AppendHandshakeBytes(LClientFlight, LFinishedMessage);

  LInnerPlaintext := BuildTLS13InnerPlaintext(LClientFlight, TLS_CONTENT_TYPE_HANDSHAKE);
  if not TryTLS13AEADEncrypt(
    FHandshakeSecrets.CipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FHandshakeSecrets.CipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt scripted client handshake flight: ' + LError);
  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);

  { Derive application secrets BEFORE appending Client Finished to transcript
    because RFC 8446 requires Transcript-Hash(CH..SF) only. }
  if not TryDeriveTLS13ApplicationSecrets(
    FHandshakeSecrets.CipherSuite,
    FHandshakeSecrets.HandshakeSecret,
    FTranscriptData,
    FApplicationSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive scripted client application secrets: ' + LError);

  if (FMode <> scmInitial) and (Length(FEarlyData) > 0) and FObservedServerAcceptedEarlyData then
    AppendHandshakeBytes(FTranscriptData, BuildTLS13EndOfEarlyDataHandshake);
  AppendHandshakeBytes(FTranscriptData, LFinishedMessage);

  { RFC 8446 Section 7.1: resumption_master_secret uses Hash(CH..CF) }
  FApplicationSecrets.ResumptionTranscriptHash := HashTranscriptForSuite(
    FHandshakeSecrets.CipherSuite, FTranscriptData
  );
end;

procedure TScriptedEarlyDataClientStream.HandleServerPostHandshake(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LTicket: TTLS13NewSessionTicket;
  LResumptionPSK: TBytes;
  LSession: TFreePascalSession;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse server post-handshake record');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Server post-handshake record truncated');
  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FHandshakeSecrets.CipherSuite,
    FApplicationSecrets.ServerApplicationKey,
    BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server post-handshake: ' + LError);
  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server post-handshake');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server post-handshake should carry handshake content');
  if not TryParseTLS13NewSessionTicket(LInnerFragment, LTicket, LError) then
    raise Exception.Create('Failed to parse NewSessionTicket: ' + LError);

  LResumptionPSK := TLS13DeriveResumptionPSKFromTranscriptHash(
    FApplicationSecrets.CipherSuite,
    FApplicationSecrets.MasterSecret,
    FApplicationSecrets.ResumptionTranscriptHash,
    LTicket.TicketNonce
  );

  LSession := TFreePascalSession.Create;
  LSession.ConfigureResumption(
    FApplicationSecrets.CipherSuite,
    TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite),
    LTicket.TicketNonce,
    LTicket.Ticket,
    LResumptionPSK,
    LTicket.TicketLifetime,
    LTicket.TicketAgeAdd,
    Now,
    Integer(LTicket.TicketLifetime),
    LTicket.MaxEarlyDataSize
  );
  FCapturedSession := LSession;
end;

function TScriptedEarlyDataClientStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedEarlyDataClientStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0:
      begin
        HandleServerHello(LData);
        FWriteStage := 1;
      end;
    1:
      begin
        HandleServerHandshakeFlight(LData);
        FWriteStage := 2;
      end;
  else
    HandleServerPostHandshake(LData);
  end;

  Result := Count;
end;

function TScriptedEarlyDataClientStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function BytesOf(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function BuildManualSession(const ALabel: AnsiString; AMaxEarlyDataSize: Cardinal): ISSLSession;
var
  LSession: TFreePascalSession;
  LTicket: TBytes;
  LPSK: TBytes;
begin
  LSession := TFreePascalSession.Create;
  LTicket := BytesOf('ticket-' + ALabel);
  LPSK := BytesOf('0123456789abcdef0123456789abcdef');
  LSession.ConfigureResumption(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    'TLS_CHACHA20_POLY1305_SHA256',
    [$01, $02, $03],
    LTicket,
    LPSK,
    7200,
    $01020304,
    Now,
    7200,
    AMaxEarlyDataSize
  );
  Result := LSession;
end;

function BuildManualSessionWithTiming(
  const ALabel: AnsiString;
  AMaxEarlyDataSize: Cardinal;
  ATicketLifetime: Cardinal;
  ACreationTime: TDateTime;
  ATimeout: Integer
): ISSLSession;
var
  LSession: TFreePascalSession;
  LTicket: TBytes;
  LPSK: TBytes;
begin
  LSession := TFreePascalSession.Create;
  LTicket := BytesOf('ticket-' + ALabel);
  LPSK := BytesOf('0123456789abcdef0123456789abcdef');
  LSession.ConfigureResumption(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    'TLS_CHACHA20_POLY1305_SHA256',
    [$01, $02, $03],
    LTicket,
    LPSK,
    ATicketLifetime,
    $01020304,
    ACreationTime,
    ATimeout,
    AMaxEarlyDataSize
  );
  Result := LSession;
end;

type
  TRejectingReplayLedger = class(TInterfacedObject, IFreePascalEarlyDataReplayLedger)
  private
    FAcquireCalls: Integer;
    FLastSession: ISSLSession;
  public
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
    property AcquireCalls: Integer read FAcquireCalls;
    property LastSession: ISSLSession read FLastSession;
  end;

  TReplayStoreFailureMode = (
    rsfmNone,
    rsfmRaiseOnGuard,
    rsfmRaiseOnLoad,
    rsfmRaiseOnSave,
    rsfmFalseOnGuard,
    rsfmFalseOnLoad,
    rsfmFalseOnSave
  );

  TNoopReplayStoreGuard = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStoreGuard)
  end;

  TSharedReplayEntryStore = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStore)
  private
    FEntries: TFreePascalEarlyDataReplayStoreEntries;
    FFailureMode: TReplayStoreFailureMode;
  public
    constructor Create(AFailureMode: TReplayStoreFailureMode = rsfmNone);

    function AcquireUpdateGuard(
      out AGuard: IFreePascalEarlyDataReplayStoreGuard
    ): Boolean;
    function LoadEntries(
      out AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    function SaveEntries(
      const AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
  end;

  TScriptedExistingMainReplaceFailureReplayStore = class(
    TFreePascalFileEarlyDataReplayStore)
  private
    FMainFileName: string;
    FTempFileName: string;
    FBackupFileName: string;
    FTempToMainRenameAttempts: Integer;
  protected
    function RenameFileAt(
      const ASourceFileName: string;
      const ADestFileName: string
    ): Boolean; override;
  public
    constructor Create(const AFileName: string);
  end;

  TScriptedBackupRestoreFailureReplayStore = class(
    TFreePascalFileEarlyDataReplayStore)
  private
    FMainFileName: string;
    FTempFileName: string;
    FBackupFileName: string;
    FTempToMainRenameAttempts: Integer;
  protected
    function RenameFileAt(
      const ASourceFileName: string;
      const ADestFileName: string
    ): Boolean; override;
  public
    constructor Create(const AFileName: string);
  end;

  TScriptedBackupCleanupDeleteFailureReplayStore = class(
    TFreePascalFileEarlyDataReplayStore)
  private
    FMainFileName: string;
    FTempFileName: string;
    FBackupFileName: string;
    FTempToMainRenameAttempts: Integer;
  protected
    function DeleteFileAt(const AFileName: string): Boolean; override;
    function RenameFileAt(
      const ASourceFileName: string;
      const ADestFileName: string
    ): Boolean; override;
  public
    constructor Create(const AFileName: string);
  end;

  TScriptedTempWriteOpenDeniedReplayStore = class(
    TFreePascalFileEarlyDataReplayStore)
  private
    FTempFileName: string;
  protected
    function OpenWriteFileStream(const AFileName: string): TFileStream; override;
  public
    constructor Create(const AFileName: string);
  end;

  TScriptedBackupPromotionRenameDeniedReplayStore = class(
    TFreePascalFileEarlyDataReplayStore)
  private
    FMainFileName: string;
    FTempFileName: string;
    FBackupFileName: string;
  protected
    function RenameFileAt(
      const ASourceFileName: string;
      const ADestFileName: string
    ): Boolean; override;
  public
    constructor Create(const AFileName: string);
  end;

  TScriptedBackupCleanupDeleteFailureDirectoryReplayStore = class(
    TFreePascalDirectoryEarlyDataReplayStore)
  private
    FBackupDirectoryName: string;
  protected
    function RemovePathTree(const APath: string): Boolean; override;
  public
    constructor Create(const ADirectoryName: string);
  end;

  TScriptedExistingMainReplaceFailureDirectoryReplayStore = class(
    TFreePascalDirectoryEarlyDataReplayStore)
  private
    FMainDirectoryName: string;
    FTempDirectoryName: string;
    FBackupDirectoryName: string;
    FTempToMainRenameAttempts: Integer;
  protected
    function RenamePathAt(
      const ASourcePath: string;
      const ADestPath: string
    ): Boolean; override;
  public
    constructor Create(const ADirectoryName: string);
  end;

  TScriptedBackupRestoreFailureDirectoryReplayStore = class(
    TFreePascalDirectoryEarlyDataReplayStore)
  private
    FMainDirectoryName: string;
    FTempDirectoryName: string;
    FBackupDirectoryName: string;
    FTempToMainRenameAttempts: Integer;
  protected
    function RenamePathAt(
      const ASourcePath: string;
      const ADestPath: string
    ): Boolean; override;
  public
    constructor Create(const ADirectoryName: string);
  end;

  TScriptedTempPromotionRenameDeniedDirectoryReplayStore = class(
    TFreePascalDirectoryEarlyDataReplayStore)
  private
    FMainDirectoryName: string;
    FTempDirectoryName: string;
  protected
    function RenamePathAt(
      const ASourcePath: string;
      const ADestPath: string
    ): Boolean; override;
  public
    constructor Create(const ADirectoryName: string);
  end;

  TScriptedBackupPromotionRenameDeniedDirectoryReplayStore = class(
    TFreePascalDirectoryEarlyDataReplayStore)
  private
    FMainDirectoryName: string;
    FBackupDirectoryName: string;
  protected
    function RenamePathAt(
      const ASourcePath: string;
      const ADestPath: string
    ): Boolean; override;
  public
    constructor Create(const ADirectoryName: string);
  end;

  TSharedReplayProviderEntry = record
    Key: string;
    ExpiresAt: TDateTime;
  end;

  TSharedReplayProviderStore = class
  private
    FEntries: array of TSharedReplayProviderEntry;

    procedure PruneExpired(ANow: TDateTime);
  public
    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
  end;

  TExplodingReplayProviderStore = class
  public
    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
  end;

  TExplodingManagedReplayProvider = class(TInterfacedObject,
    IFreePascalEarlyDataReplayProvider,
    IFreePascalManagedReplayProvider)
  private
    FAcquireCalls: Integer;
    FClearCalls: Integer;
    FSetCapacityCalls: Integer;
    FLastCapacity: Integer;
  public
    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);

    property AcquireCalls: Integer read FAcquireCalls;
    property ClearCalls: Integer read FClearCalls;
    property SetCapacityCalls: Integer read FSetCapacityCalls;
    property LastCapacity: Integer read FLastCapacity;
  end;

function TRejectingReplayLedger.TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
begin
  Inc(FAcquireCalls);
  FLastSession := ASession;
  Result := False;
end;

constructor TSharedReplayEntryStore.Create(AFailureMode: TReplayStoreFailureMode);
begin
  inherited Create;
  FFailureMode := AFailureMode;
  SetLength(FEntries, 0);
end;

constructor TScriptedExistingMainReplaceFailureReplayStore.Create(
  const AFileName: string
);
begin
  inherited Create(AFileName);
  FMainFileName := AFileName;
  FTempFileName := AFileName + '.tmp';
  FBackupFileName := AFileName + '.bak';
  FTempToMainRenameAttempts := 0;
end;

function TScriptedExistingMainReplaceFailureReplayStore.RenameFileAt(
  const ASourceFileName: string;
  const ADestFileName: string
): Boolean;
begin
  if (ASourceFileName = FTempFileName) and (ADestFileName = FMainFileName) then
  begin
    Inc(FTempToMainRenameAttempts);
    if FTempToMainRenameAttempts <= 2 then
      Exit(False);
  end;

  Result := inherited RenameFileAt(ASourceFileName, ADestFileName);
  if Result and (ASourceFileName = FBackupFileName) and (ADestFileName = FMainFileName) then
    FTempToMainRenameAttempts := 2;
end;

constructor TScriptedBackupRestoreFailureReplayStore.Create(
  const AFileName: string
);
begin
  inherited Create(AFileName);
  FMainFileName := AFileName;
  FTempFileName := AFileName + '.tmp';
  FBackupFileName := AFileName + '.bak';
  FTempToMainRenameAttempts := 0;
end;

function TScriptedBackupRestoreFailureReplayStore.RenameFileAt(
  const ASourceFileName: string;
  const ADestFileName: string
): Boolean;
begin
  if (ASourceFileName = FTempFileName) and (ADestFileName = FMainFileName) then
  begin
    Inc(FTempToMainRenameAttempts);
    if FTempToMainRenameAttempts <= 2 then
      Exit(False);
  end;

  if (ASourceFileName = FBackupFileName) and (ADestFileName = FMainFileName) then
    Exit(False);

  Result := inherited RenameFileAt(ASourceFileName, ADestFileName);
end;

constructor TScriptedBackupCleanupDeleteFailureReplayStore.Create(
  const AFileName: string
);
begin
  inherited Create(AFileName);
  FMainFileName := AFileName;
  FTempFileName := AFileName + '.tmp';
  FBackupFileName := AFileName + '.bak';
  FTempToMainRenameAttempts := 0;
end;

function TScriptedBackupCleanupDeleteFailureReplayStore.DeleteFileAt(
  const AFileName: string
): Boolean;
begin
  if AFileName = FBackupFileName then
    Exit(False);

  Result := inherited DeleteFileAt(AFileName);
end;

function TScriptedBackupCleanupDeleteFailureReplayStore.RenameFileAt(
  const ASourceFileName: string;
  const ADestFileName: string
): Boolean;
begin
  if (ASourceFileName = FTempFileName) and (ADestFileName = FMainFileName) then
  begin
    Inc(FTempToMainRenameAttempts);
    if FTempToMainRenameAttempts = 1 then
      Exit(False);
  end;

  Result := inherited RenameFileAt(ASourceFileName, ADestFileName);
end;

constructor TScriptedTempWriteOpenDeniedReplayStore.Create(
  const AFileName: string
);
begin
  inherited Create(AFileName);
  FTempFileName := AFileName + '.tmp';
end;

function TScriptedTempWriteOpenDeniedReplayStore.OpenWriteFileStream(
  const AFileName: string
): TFileStream;
begin
  if AFileName = FTempFileName then
    raise Exception.Create('Scripted replay-store temp write open denied');

  Result := inherited OpenWriteFileStream(AFileName);
end;

constructor TScriptedBackupPromotionRenameDeniedReplayStore.Create(
  const AFileName: string
);
begin
  inherited Create(AFileName);
  FMainFileName := AFileName;
  FTempFileName := AFileName + '.tmp';
  FBackupFileName := AFileName + '.bak';
end;

function TScriptedBackupPromotionRenameDeniedReplayStore.RenameFileAt(
  const ASourceFileName: string;
  const ADestFileName: string
): Boolean;
begin
  if (ASourceFileName = FTempFileName) and (ADestFileName = FMainFileName) then
    Exit(False);

  if (ASourceFileName = FMainFileName) and (ADestFileName = FBackupFileName) then
    Exit(False);

  Result := inherited RenameFileAt(ASourceFileName, ADestFileName);
end;

constructor TScriptedBackupCleanupDeleteFailureDirectoryReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create(ADirectoryName);
  FBackupDirectoryName := ADirectoryName + '.bakdir';
end;

function TScriptedBackupCleanupDeleteFailureDirectoryReplayStore.RemovePathTree(
  const APath: string
): Boolean;
begin
  if APath = FBackupDirectoryName then
    Exit(False);

  Result := inherited RemovePathTree(APath);
end;

constructor TScriptedExistingMainReplaceFailureDirectoryReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create(ADirectoryName);
  FMainDirectoryName := ADirectoryName;
  FTempDirectoryName := ADirectoryName + '.tmpdir';
  FBackupDirectoryName := ADirectoryName + '.bakdir';
  FTempToMainRenameAttempts := 0;
end;

function TScriptedExistingMainReplaceFailureDirectoryReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  if (ASourcePath = FTempDirectoryName) and (ADestPath = FMainDirectoryName) then
  begin
    Inc(FTempToMainRenameAttempts);
    if FTempToMainRenameAttempts = 1 then
      Exit(False);
  end;

  Result := inherited RenamePathAt(ASourcePath, ADestPath);
end;

constructor TScriptedBackupRestoreFailureDirectoryReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create(ADirectoryName);
  FMainDirectoryName := ADirectoryName;
  FTempDirectoryName := ADirectoryName + '.tmpdir';
  FBackupDirectoryName := ADirectoryName + '.bakdir';
  FTempToMainRenameAttempts := 0;
end;

function TScriptedBackupRestoreFailureDirectoryReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  if (ASourcePath = FTempDirectoryName) and (ADestPath = FMainDirectoryName) then
  begin
    Inc(FTempToMainRenameAttempts);
    if FTempToMainRenameAttempts = 1 then
      Exit(False);
  end;

  if (ASourcePath = FBackupDirectoryName) and (ADestPath = FMainDirectoryName) then
    Exit(False);

  Result := inherited RenamePathAt(ASourcePath, ADestPath);
end;

constructor TScriptedTempPromotionRenameDeniedDirectoryReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create(ADirectoryName);
  FMainDirectoryName := ADirectoryName;
  FTempDirectoryName := ADirectoryName + '.tmpdir';
end;

function TScriptedTempPromotionRenameDeniedDirectoryReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  if (ASourcePath = FTempDirectoryName) and (ADestPath = FMainDirectoryName) then
    Exit(False);

  Result := inherited RenamePathAt(ASourcePath, ADestPath);
end;

constructor TScriptedBackupPromotionRenameDeniedDirectoryReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create(ADirectoryName);
  FMainDirectoryName := ADirectoryName;
  FBackupDirectoryName := ADirectoryName + '.bakdir';
end;

function TScriptedBackupPromotionRenameDeniedDirectoryReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  if (ASourcePath = FMainDirectoryName) and (ADestPath = FBackupDirectoryName) then
    Exit(False);

  Result := inherited RenamePathAt(ASourcePath, ADestPath);
end;

function TSharedReplayEntryStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
begin
  AGuard := nil;

  case FFailureMode of
    rsfmRaiseOnGuard:
      raise Exception.Create('Exploding replay store guard should be fail-closed');
    rsfmFalseOnGuard:
      Exit(False);
    rsfmNone, rsfmRaiseOnLoad, rsfmRaiseOnSave, rsfmFalseOnLoad, rsfmFalseOnSave:
      begin
      end;
  end;

  AGuard := TNoopReplayStoreGuard.Create;
  Result := True;
end;

function TSharedReplayEntryStore.LoadEntries(
  out AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  I: Integer;
begin
  SetLength(AEntries, 0);

  case FFailureMode of
    rsfmRaiseOnLoad:
      raise Exception.Create('Exploding replay store load should be fail-closed');
    rsfmFalseOnLoad:
      Exit(False);
    rsfmNone, rsfmRaiseOnGuard, rsfmRaiseOnSave, rsfmFalseOnGuard, rsfmFalseOnSave:
      begin
      end;
  end;

  SetLength(AEntries, Length(FEntries));
  for I := 0 to High(FEntries) do
    AEntries[I] := FEntries[I];
  Result := True;
end;

function TSharedReplayEntryStore.SaveEntries(
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  I: Integer;
begin
  case FFailureMode of
    rsfmRaiseOnSave:
      raise Exception.Create('Exploding replay store save should be fail-closed');
    rsfmFalseOnSave:
      Exit(False);
    rsfmNone, rsfmRaiseOnGuard, rsfmRaiseOnLoad, rsfmFalseOnGuard, rsfmFalseOnLoad:
      begin
      end;
  end;

  SetLength(FEntries, Length(AEntries));
  for I := 0 to High(AEntries) do
    FEntries[I] := AEntries[I];
  Result := True;
end;

procedure TSharedReplayProviderStore.PruneExpired(ANow: TDateTime);
var
  I: Integer;
  LWriteIndex: Integer;
begin
  LWriteIndex := 0;
  for I := 0 to High(FEntries) do
    if (FEntries[I].Key <> '') and
       ((FEntries[I].ExpiresAt <= 0) or (FEntries[I].ExpiresAt > ANow)) then
    begin
      if LWriteIndex <> I then
        FEntries[LWriteIndex] := FEntries[I];
      Inc(LWriteIndex);
    end;
  SetLength(FEntries, LWriteIndex);
end;

function TSharedReplayProviderStore.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AKey = '' then
    Exit;

  PruneExpired(ANow);
  for I := 0 to High(FEntries) do
    if FEntries[I].Key = AKey then
      Exit;

  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)].Key := AKey;
  FEntries[High(FEntries)].ExpiresAt := AExpiresAt;
  Result := True;
end;

function TExplodingReplayProviderStore.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
begin
  Result := False;
  raise Exception.Create('Exploding replay provider should be fail-closed');
end;

function TExplodingManagedReplayProvider.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
begin
  Inc(FAcquireCalls);
  Result := AKey <> '';
end;

procedure TExplodingManagedReplayProvider.Clear;
begin
  Inc(FClearCalls);
  raise Exception.Create('Exploding managed replay provider Clear should be swallowed');
end;

procedure TExplodingManagedReplayProvider.SetCapacity(ACapacity: Integer);
begin
  Inc(FSetCapacityCalls);
  FLastCapacity := ACapacity;
  raise Exception.Create('Exploding managed replay provider SetCapacity should be swallowed');
end;

function BuildReplayProviderStoreFilePath(const AName: string): string;
var
  LDir: string;
begin
  LDir := IncludeTrailingPathDelimiter('tmp/freepascal_tls13_early_data_replay_provider');
  AssertTrue(ForceDirectories(LDir),
    'Replay provider temp directory should be creatable');
  Result := LDir + AName + '_' + IntToStr(Int64(GetTickCount64)) + '.bin';
end;

function BuildReplayProviderStoreDirectoryPath(const AName: string): string;
var
  LDir: string;
begin
  LDir := IncludeTrailingPathDelimiter('tmp/freepascal_tls13_early_data_replay_store_dirs');
  AssertTrue(ForceDirectories(LDir),
    'Directory replay-store temp directory should be creatable');
  Result := LDir + AName + '_' + IntToStr(Int64(GetTickCount64)) + '.store';
end;

procedure CleanupReplayProviderStoreDirectory(const ADirectoryName: string); forward;

procedure InitializeDefaultReplayStoreBaselineDirectoryForTesting;
begin
  if GDefaultReplayStoreBaselineDirectory <> '' then
    Exit;

  GDefaultReplayStoreBaselineDirectory := BuildReplayProviderStoreDirectoryPath(
    'default_shipped_path_process'
  );
  CleanupReplayProviderStoreDirectory(GDefaultReplayStoreBaselineDirectory);
  SetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting(
    GDefaultReplayStoreBaselineDirectory
  );
end;

procedure PrepareDefaultReplayStoreDirectoryForTesting(
  const ADirectoryName: string
);
begin
  SetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting(ADirectoryName);
end;

procedure ResetDefaultReplayStoreDirectoryForTesting;
begin
  if GDefaultReplayStoreBaselineDirectory <> '' then
    SetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting(
      GDefaultReplayStoreBaselineDirectory
    )
  else
    ResetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting;
end;

function BuildReplayProviderLockFilePath(const AFileName: string): string;
begin
  if AFileName = '' then
    Exit('');
  Result := AFileName + '.lock';
end;

function BuildReplayProviderMarkerFilePath(const AFileName, ASuffix: string): string;
begin
  if (AFileName = '') or (ASuffix = '') then
    Exit('');
  Result := AFileName + '.' + ASuffix;
end;

procedure TouchFile(const AFileName: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
  finally
    LStream.Free;
  end;
end;

procedure DeleteFileIfExists(const AFileName: string);
begin
  if (AFileName <> '') and FileExists(AFileName) then
    DeleteFile(AFileName);
end;

procedure RemoveReplayProviderPathIfExists(const APath: string);
begin
  if APath = '' then
    Exit;

  if FileExists(APath) then
    DeleteFile(APath)
  else if DirectoryExists(APath) then
    RemoveDir(APath);
end;

function RemoveReplayProviderPathTree(const APath: string): Boolean;
var
  LSearchRec: TSearchRec;
  LEntryPath: string;
begin
  Result := False;

  if APath = '' then
    Exit(True);
  if FileExists(APath) then
    Exit(DeleteFile(APath));
  if not DirectoryExists(APath) then
    Exit(True);

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, LSearchRec) = 0 then
  begin
    repeat
      if (LSearchRec.Name = '.') or (LSearchRec.Name = '..') then
        Continue;

      LEntryPath := IncludeTrailingPathDelimiter(APath) + LSearchRec.Name;
      if not RemoveReplayProviderPathTree(LEntryPath) then
      begin
        FindClose(LSearchRec);
        Exit(False);
      end;
    until FindNext(LSearchRec) <> 0;
    FindClose(LSearchRec);
  end;

  Result := RemoveDir(APath);
end;

procedure WriteBytesToFile(const AFileName: string; const AData: TBytes);
var
  LStream: TFileStream;
begin
  AssertTrue((AFileName <> '') and ForceDirectories(ExtractFileDir(AFileName)),
    'Byte-file helper should create its temp directory');
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      LStream.WriteBuffer(AData[0], Length(AData));
  finally
    LStream.Free;
  end;
end;

function ReadBytesFromFile(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  AssertTrue((AFileName <> '') and FileExists(AFileName),
    'Byte-file helper should only read existing files');
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
      LStream.ReadBuffer(Result[0], Length(Result));
  finally
    LStream.Free;
  end;
end;

function WaitForFileExists(const AFileName: string; ATimeoutMs: Integer): Boolean;
var
  LDeadline: QWord;
begin
  Result := False;
  if AFileName = '' then
    Exit;

  LDeadline := GetTickCount64 + QWord(ATimeoutMs);
  repeat
    if FileExists(AFileName) then
      Exit(True);
    Sleep(10);
  until GetTickCount64 >= LDeadline;

  Result := FileExists(AFileName);
end;

procedure CleanupReplayProviderStoreFiles(const AFileName: string);
begin
  RemoveReplayProviderPathIfExists(AFileName);
  RemoveReplayProviderPathIfExists(AFileName + '.tmp');
  RemoveReplayProviderPathIfExists(AFileName + '.bak');
  RemoveReplayProviderPathIfExists(BuildReplayProviderLockFilePath(AFileName));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(AFileName, 'ready'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(AFileName, 'release'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(AFileName, 'session.bin'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(AFileName, 'graceful'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(AFileName, 'context_path'));
end;

procedure CleanupReplayProviderStoreDirectory(const ADirectoryName: string);
begin
  RemoveReplayProviderPathTree(ADirectoryName);
  RemoveReplayProviderPathTree(ADirectoryName + '.tmpdir');
  RemoveReplayProviderPathTree(ADirectoryName + '.bakdir');
  RemoveReplayProviderPathIfExists(BuildReplayProviderLockFilePath(ADirectoryName));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(ADirectoryName, 'ready'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(ADirectoryName, 'release'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(ADirectoryName, 'session.bin'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(ADirectoryName, 'graceful'));
  RemoveReplayProviderPathIfExists(BuildReplayProviderMarkerFilePath(ADirectoryName, 'context_path'));
end;

procedure RunReplayProviderLockHolderMode(
  const AFileName: string;
  const AReadyFileName: string;
  const AReleaseFileName: string
);
{$IFDEF UNIX}
var
  LLockFileName: string;
  LLockStream: TFileStream;
begin
  LLockFileName := BuildReplayProviderLockFilePath(AFileName);
  AssertTrue((AFileName <> '') and (AReadyFileName <> '') and (AReleaseFileName <> ''),
    'Replay-provider lock-holder helper requires store/ready/release file names');
  AssertTrue(ForceDirectories(ExtractFileDir(AFileName)),
    'Replay-provider lock-holder helper should create its temp directory');

  if not FileExists(LLockFileName) then
    TouchFile(LLockFileName);

  LLockStream := TFileStream.Create(LLockFileName, fmOpenReadWrite or fmShareDenyNone);
  try
    AssertTrue(FpFlock(LLockStream.Handle, LOCK_EX) = 0,
      'Replay-provider lock-holder helper should acquire the sidecar advisory lock');
    TouchFile(AReadyFileName);
    AssertTrue(WaitForFileExists(AReleaseFileName, 5000),
      'Replay-provider lock-holder helper should receive a release marker');
    AssertTrue(FpFlock(LLockStream.Handle, LOCK_UN) = 0,
      'Replay-provider lock-holder helper should release the sidecar advisory lock');
  finally
    LLockStream.Free;
  end;
end;
{$ELSE}
begin
  TouchFile(AReadyFileName);
  AssertTrue(WaitForFileExists(AReleaseFileName, 5000),
    'Replay-provider lock-holder helper should receive a release marker');
end;
{$ENDIF}

procedure PrepareServerContextForEarlyData(ACtx: ISSLContext); forward;
function CaptureServerIssuedSession(ACtx: ISSLContext): ISSLSession; forward;
function BuildBuilderFileBackedReplayStoreServerContext(const AFileName: string): ISSLContext; forward;
function BuildFactoryFileBackedReplayStoreServerContext(const AFileName: string): ISSLContext; forward;
function BuildRuntimeReplayProbeServerContext(
  const AFileName: string;
  const AContextPath: string
): ISSLContext; forward;
function RuntimeReplayProbeCanonicalStoreExists(
  const AStoreName: string;
  const AContextPath: string
): Boolean; forward;

procedure RunReplayProviderRuntimeCrashAcceptMode(
  const AFileName: string;
  const ASessionFileName: string;
  const AReadyFileName: string;
  const AContextPath: string = ''
);
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache: IFreePascalResumptionCache;
  LReplaySession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
begin
  AssertTrue((AFileName <> '') and (ASessionFileName <> '') and (AReadyFileName <> ''),
    'Runtime crash-accept helper requires replay-store, session file, and ready marker names');

  LSerialized := ReadBytesFromFile(ASessionFileName);
  AssertTrue(Length(LSerialized) > 0,
    'Runtime crash-accept helper should load a serialized captured session');

  LReplaySession := TFreePascalSession.Create;
  AssertTrue(LReplaySession.Deserialize(LSerialized),
    'Runtime crash-accept helper should deserialize the captured session');

  LCtx := BuildRuntimeReplayProbeServerContext(AFileName, AContextPath);
  AssertTrue(LCtx <> nil,
    'Runtime crash-accept helper should create a FreePascal server context');

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Runtime crash-accept helper should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalResumptionCache, LResumptionCache),
    'Runtime crash-accept helper should expose resumption cache seam');
  LResumptionCache.StoreResumptionSession(LReplaySession);

  LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('CRASH'), True);
  try
    LConn := LCtx.CreateConnection(LAcceptStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Runtime crash-accept helper connection should expose early-data interface');
    AssertTrue(LConn.Accept,
      'Runtime crash-accept helper should accept resumed early-data before the simulated crash');
    AssertSessionReused(LConn,
      'Runtime crash-accept helper should still reuse the serialized cached session');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        'Runtime crash-accept helper should accept early-data before the simulated crash');
    AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
      'Runtime crash-accept helper should advertise accepted early-data before the simulated crash');
  finally
    LAcceptStream.Free;
  end;

  AssertTrue(RuntimeReplayProbeCanonicalStoreExists(AFileName, AContextPath),
    'Runtime crash-accept helper should materialize canonical replay-store state before the simulated crash');
  TouchFile(AReadyFileName);
  Halt(TEST_REPLAY_PROVIDER_SIMULATED_CRASH_EXIT_CODE);
end;

function BuildRuntimeReplayProbeServerContext(
  const AFileName: string;
  const AContextPath: string
): ISSLContext;
var
  LEarlyCtx: ISSLEarlyDataContext;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LStore: IFreePascalEarlyDataReplayStore;
  LNormalizedContextPath: string;
begin
  LNormalizedContextPath := LowerCase(Trim(AContextPath));
  if LNormalizedContextPath = '' then
    LNormalizedContextPath := TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER then
  begin
    Result := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertTrue(Result <> nil,
      'Runtime replay probe helper should create an installer-based FreePascal server context');
    PrepareServerContextForEarlyData(Result);

    AssertTrue(Supports(Result, ISSLEarlyDataContext, LEarlyCtx),
      'Runtime replay probe helper installer path should expose early-data context interface');
    if Supports(Result, ISSLEarlyDataContext, LEarlyCtx) then
    begin
      LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
      LEarlyCtx.SetServerMaxEarlyDataSize(8);
    end;

    AssertTrue(Supports(Result, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
      'Runtime replay probe helper installer path should expose backend-private file-backed replay installer seam');
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(AFileName),
      'Runtime replay probe helper installer path should install the file-backed replay ledger in the new process');
    Exit;
  end;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DEFAULT then
  begin
    PrepareDefaultReplayStoreDirectoryForTesting(AFileName);
    Result := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertTrue(Result <> nil,
      'Runtime replay probe helper default shipped path should create a FreePascal server context');
    PrepareServerContextForEarlyData(Result);

    AssertTrue(Supports(Result, ISSLEarlyDataContext, LEarlyCtx),
      'Runtime replay probe helper default shipped path should expose early-data context interface');
    if Supports(Result, ISSLEarlyDataContext, LEarlyCtx) then
    begin
      LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
      LEarlyCtx.SetServerMaxEarlyDataSize(8);
    end;
    Exit;
  end;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_BUILDER then
  begin
    Result := BuildBuilderFileBackedReplayStoreServerContext(AFileName);
    AssertTrue(Result <> nil,
      'Runtime replay probe helper builder path should create a FreePascal server context');
    Exit;
  end;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_FACTORY then
  begin
    Result := BuildFactoryFileBackedReplayStoreServerContext(AFileName);
    AssertTrue(Result <> nil,
      'Runtime replay probe helper factory path should create a FreePascal server context');
    Exit;
  end;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE then
  begin
    Result := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertTrue(Result <> nil,
      'Runtime replay probe helper directory-store path should create a FreePascal server context');
    PrepareServerContextForEarlyData(Result);

    AssertTrue(Supports(Result, ISSLEarlyDataContext, LEarlyCtx),
      'Runtime replay probe helper directory-store path should expose early-data context interface');
    if Supports(Result, ISSLEarlyDataContext, LEarlyCtx) then
    begin
      LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
      LEarlyCtx.SetServerMaxEarlyDataSize(8);
    end;

    LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(AFileName);
    AssertTrue(InstallStoreBackedReplayLedger(Result, LStore),
      'Runtime replay probe helper directory-store path should install the directory-backed replay ledger in the new process');
    Exit;
  end;

  Fail('Runtime replay probe helper does not support context path "' + AContextPath + '"');
end;

function RuntimeReplayProbeStoreStateExists(
  const AStoreName: string;
  const AContextPath: string
): Boolean;
var
  LNormalizedContextPath: string;
begin
  LNormalizedContextPath := LowerCase(Trim(AContextPath));
  if LNormalizedContextPath = '' then
    LNormalizedContextPath := TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE then
    Exit(
      DirectoryExists(AStoreName) or
      DirectoryExists(AStoreName + '.tmpdir') or
      DirectoryExists(AStoreName + '.bakdir')
    );

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DEFAULT then
    Exit(
      DirectoryExists(AStoreName) or
      DirectoryExists(AStoreName + '.tmpdir') or
      DirectoryExists(AStoreName + '.bakdir')
    );

  Result := FileExists(AStoreName) or
    FileExists(AStoreName + '.tmp') or
    FileExists(AStoreName + '.bak');
end;

function RuntimeReplayProbeCanonicalStoreExists(
  const AStoreName: string;
  const AContextPath: string
): Boolean;
var
  LNormalizedContextPath: string;
begin
  LNormalizedContextPath := LowerCase(Trim(AContextPath));
  if LNormalizedContextPath = '' then
    LNormalizedContextPath := TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER;

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE then
    Exit(DirectoryExists(AStoreName));

  if LNormalizedContextPath = TEST_REPLAY_PROVIDER_CONTEXT_PATH_DEFAULT then
    Exit(DirectoryExists(AStoreName));

  Result := FileExists(AStoreName);
end;

procedure RunReplayProviderRuntimeReplayProbeMode(
  const AFileName: string;
  const ASessionFileName: string;
  const AContextPath: string = '';
  const AContextPathMarkerFileName: string = '';
  const AFirstAttemptExpectation: string = TEST_REPLAY_PROVIDER_EXPECT_REJECT
);
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache: IFreePascalResumptionCache;
  LReplaySession: ISSLSession;
  LFreshSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LReplayStream: TScriptedEarlyDataClientStream;
  LReplayRejectStream: TScriptedEarlyDataClientStream;
  LFreshAcceptStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
  LNormalizedContextPath: string;
  LNormalizedExpectation: string;
begin
  AssertTrue((AFileName <> '') and (ASessionFileName <> ''),
    'Runtime replay probe helper requires replay-store and session file names');

  LSerialized := ReadBytesFromFile(ASessionFileName);
  AssertTrue(Length(LSerialized) > 0,
    'Runtime replay probe helper should load a serialized captured session');
  LNormalizedExpectation := LowerCase(Trim(AFirstAttemptExpectation));
  if LNormalizedExpectation = '' then
    LNormalizedExpectation := TEST_REPLAY_PROVIDER_EXPECT_REJECT;
  AssertTrue(
    (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT) or
    (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY) or
    (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_ACCEPT_THEN_REJECT),
    'Runtime replay probe helper should receive a supported first-attempt expectation');
  if (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT) or
     (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY) then
    AssertTrue(RuntimeReplayProbeStoreStateExists(AFileName, AContextPath),
      'Runtime replay probe helper should observe persisted replay-store state from the parent process');

  LReplaySession := TFreePascalSession.Create;
  AssertTrue(LReplaySession.Deserialize(LSerialized),
    'Runtime replay probe helper should deserialize the captured session');

  LCtx := BuildRuntimeReplayProbeServerContext(AFileName, AContextPath);
  AssertTrue(LCtx <> nil,
    'Runtime replay probe helper should create a FreePascal server context');
  if AContextPathMarkerFileName <> '' then
  begin
    LNormalizedContextPath := LowerCase(Trim(AContextPath));
    if LNormalizedContextPath = '' then
      LNormalizedContextPath := TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER;
    WriteBytesToFile(AContextPathMarkerFileName, BytesOf(LNormalizedContextPath));
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Runtime replay probe helper should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalResumptionCache, LResumptionCache),
    'Runtime replay probe helper should expose resumption cache seam');
  LResumptionCache.StoreResumptionSession(LReplaySession);

  if (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT) or
     (LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY) then
  begin
    LReplayStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PONG'), False);
    try
      LConn := LCtx.CreateConnection(LReplayStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Runtime replay probe helper connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Runtime replay probe helper should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Runtime replay probe helper should still reuse the serialized cached session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Runtime replay probe helper should reject replay after process restart');
      AssertTrue(not LReplayStream.ObservedServerAcceptedEarlyData,
        'Runtime replay probe helper should suppress accepted early-data signalling on replay');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Runtime replay probe helper should not surface discarded replayed early bytes through Read');
    finally
      LReplayStream.Free;
    end;

    if LNormalizedExpectation = TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY then
    begin
      LReplayAccess.ResetEarlyDataReplayLedger;
      Exit;
    end;
  end
  else
  begin
    LReplayStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PONG'), True);
    try
      LConn := LCtx.CreateConnection(LReplayStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Runtime replay probe helper accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Runtime replay probe helper should accept the first resumed attempt on a fresh child boundary');
      AssertSessionReused(LConn,
        'Runtime replay probe helper should still reuse the serialized cached session on the fresh child boundary');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Runtime replay probe helper should accept the first resumed attempt on a different child boundary');
      AssertTrue(LReplayStream.ObservedServerAcceptedEarlyData,
        'Runtime replay probe helper should advertise accepted early-data on the fresh child boundary');
    finally
      LReplayStream.Free;
    end;

    AssertTrue(RuntimeReplayProbeCanonicalStoreExists(AFileName, AContextPath),
      'Runtime replay probe helper should materialize the child replay-store boundary after the first accepted attempt');

    LResumptionCache.StoreResumptionSession(LReplaySession);
    LReplayRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('REPL'), False);
    try
      LConn := LCtx.CreateConnection(LReplayRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Runtime replay probe helper rejected connection should expose early-data interface after the child boundary is materialized');
      AssertTrue(LConn.Accept,
        'Runtime replay probe helper should still complete the second resumed handshake on the child boundary');
      AssertSessionReused(LConn,
        'Runtime replay probe helper should still reuse the serialized cached session on the second attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Runtime replay probe helper should reject the second resumed attempt after materializing the child boundary truth');
      AssertTrue(not LReplayRejectStream.ObservedServerAcceptedEarlyData,
        'Runtime replay probe helper should suppress accepted early-data signalling on the second attempt');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Runtime replay probe helper should not surface discarded early bytes through Read after the child boundary is materialized');
    finally
      LReplayRejectStream.Free;
    end;
  end;

  LFreshSession := CaptureServerIssuedSession(LCtx);
  AssertTrue(LFreshSession <> nil,
    'Runtime replay probe helper should still capture a fresh resumable session after replay rejection');
  LResumptionCache.StoreResumptionSession(LFreshSession);

  LFreshAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LFreshSession, BytesOf('FRESH'), True);
  try
    LConn := LCtx.CreateConnection(LFreshAcceptStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Runtime replay probe helper fresh connection should expose early-data interface');
    AssertTrue(LConn.Accept,
      'Runtime replay probe helper should still accept a fresh resumed early-data attempt after restart');
    AssertSessionReused(LConn,
      'Runtime replay probe helper should still reuse the fresh session after restart');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        'Runtime replay probe helper should not poison fresh resumed early-data after replay rejection');
    AssertTrue(LFreshAcceptStream.ObservedServerAcceptedEarlyData,
      'Runtime replay probe helper should still advertise accepted early-data for a fresh session after restart');
  finally
    LFreshAcceptStream.Free;
  end;
  LReplayAccess.ResetEarlyDataReplayLedger;
end;

function HandleReplayProviderChildMode: Boolean;
begin
  Result := False;
  if ParamCount < 1 then
    Exit;

  if ParamStr(1) = TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE then
  begin
    AssertTrue(ParamCount >= 4,
      'Replay-provider lock-holder mode requires store/ready/release file names');
    RunReplayProviderLockHolderMode(ParamStr(2), ParamStr(3), ParamStr(4));
    Exit(True);
  end;

  if ParamStr(1) = TEST_REPLAY_PROVIDER_RUNTIME_CRASH_ACCEPT_MODE then
  begin
    AssertTrue(ParamCount >= 4,
      'Runtime crash-accept mode requires replay-store, session file, and ready marker names');
    if ParamCount >= 6 then
      RunReplayProviderRuntimeCrashAcceptMode(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(6))
    else
      RunReplayProviderRuntimeCrashAcceptMode(ParamStr(2), ParamStr(3), ParamStr(4));
    if ParamCount >= 5 then
      TouchFile(ParamStr(5));
    Exit(True);
  end;

  if ParamStr(1) = TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE then
  begin
    AssertTrue(ParamCount >= 3,
      'Runtime replay probe mode requires replay-store and session file names');
    if ParamCount >= 6 then
      RunReplayProviderRuntimeReplayProbeMode(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6))
    else if ParamCount >= 5 then
      RunReplayProviderRuntimeReplayProbeMode(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5))
    else if ParamCount >= 4 then
      RunReplayProviderRuntimeReplayProbeMode(ParamStr(2), ParamStr(3), ParamStr(4))
    else
      RunReplayProviderRuntimeReplayProbeMode(ParamStr(2), ParamStr(3));
    Exit(True);
  end;
end;

function BytesToLowerHex(const AValue: TBytes): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(AValue) * 2);
  for I := 0 to High(AValue) do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[(AValue[I] shr 4) and $0F];
    Result[I * 2 + 2] := HEX_DIGITS[AValue[I] and $0F];
  end;
end;

function ResolveSessionReplayKey(ASession: ISSLSession): string;
var
  LResumptionSession: IFreePascalResumptionSession;
begin
  Result := '';
  if (ASession = nil) or
     (not Supports(ASession, IFreePascalResumptionSession, LResumptionSession)) then
    Exit;

  Result := BytesToLowerHex(LResumptionSession.GetTicket);
end;

procedure WriteReplayProviderStoreHeader(
  const AFileName: string;
  AVersion: Integer;
  ACount: Integer
);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LStream.WriteBuffer(AVersion, SizeOf(Integer));
    LStream.WriteBuffer(ACount, SizeOf(Integer));
  finally
    LStream.Free;
  end;
end;

procedure WriteReplayProviderStoreSingleEntry(
  const AFileName: string;
  AVersion: Integer;
  const AKey: string;
  AExpiresAt: TDateTime
);
var
  LStream: TFileStream;
  LCount: Integer;
  LKeyLength: Integer;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LCount := 1;
    AssertTrue(LCount = 1, 'Replay-provider store single-entry helper must keep count = 1');
    LKeyLength := Length(AKey);
    LStream.WriteBuffer(AVersion, SizeOf(Integer));
    LStream.WriteBuffer(LCount, SizeOf(Integer));
    LStream.WriteBuffer(LKeyLength, SizeOf(Integer));
    if LKeyLength > 0 then
      LStream.WriteBuffer(AKey[1], LKeyLength);
    LStream.WriteBuffer(AExpiresAt, SizeOf(TDateTime));
  finally
    LStream.Free;
  end;
end;

procedure WriteReplayProviderTruncatedStoreFile(
  const AFileName: string;
  AVersion: Integer;
  const AKey: string
);
var
  LStream: TFileStream;
  LCount: Integer;
  LKeyLength: Integer;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LCount := 1;
    AssertTrue(LCount = 1, 'Replay-provider truncated-store helper must keep count = 1');
    LKeyLength := Length(AKey);
    LStream.WriteBuffer(AVersion, SizeOf(Integer));
    LStream.WriteBuffer(LCount, SizeOf(Integer));
    LStream.WriteBuffer(LKeyLength, SizeOf(Integer));
    if LKeyLength > 0 then
      LStream.WriteBuffer(AKey[1], LKeyLength);
  finally
    LStream.Free;
  end;
end;

procedure WriteReplayProviderInvalidKeyLengthStoreFile(
  const AFileName: string;
  AVersion: Integer;
  AInvalidKeyLength: Integer
);
var
  LStream: TFileStream;
  LCount: Integer;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LCount := 1;
    AssertTrue(LCount = 1, 'Replay-provider invalid-key-length helper must keep count = 1');
    LStream.WriteBuffer(AVersion, SizeOf(Integer));
    LStream.WriteBuffer(LCount, SizeOf(Integer));
    LStream.WriteBuffer(AInvalidKeyLength, SizeOf(Integer));
  finally
    LStream.Free;
  end;
end;

procedure WriteReplayProviderTrailingGarbageStoreFile(
  const AFileName: string;
  AVersion: Integer;
  const AKey: string
);
var
  LStream: TFileStream;
begin
  WriteReplayProviderStoreSingleEntry(AFileName, AVersion, AKey, 600.0);
  LStream := TFileStream.Create(AFileName, fmOpenReadWrite);
  try
    AssertTrue(REPLAY_PROVIDER_TRAILING_GARBAGE_BYTES[0] = $BA,
      'Replay-provider trailing garbage helper must keep the fixed byte tail');
    LStream.Seek(0, soFromEnd);
    LStream.WriteBuffer(
      REPLAY_PROVIDER_TRAILING_GARBAGE_BYTES[0],
      SizeOf(REPLAY_PROVIDER_TRAILING_GARBAGE_BYTES)
    );
  finally
    LStream.Free;
  end;
end;

function EncodeDirectoryReplayStoreKey(const AKey: string): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
  LByte: Byte;
begin
  SetLength(Result, Length(AKey) * 2);
  for I := 1 to Length(AKey) do
  begin
    LByte := Byte(AKey[I]);
    Result[(I - 1) * 2 + 1] := HEX_DIGITS[(LByte shr 4) and $0F];
    Result[(I - 1) * 2 + 2] := HEX_DIGITS[LByte and $0F];
  end;
end;

procedure WriteDirectoryReplayStoreEntry(
  const ADirectoryName: string;
  const AKey: string;
  AVersion: Integer;
  AExpiresAt: TDateTime
);
var
  LFileName: string;
  LStream: TFileStream;
begin
  AssertTrue((ADirectoryName <> '') and ForceDirectories(ADirectoryName),
    'Directory replay-store entry helper should create the store directory');
  LFileName := IncludeTrailingPathDelimiter(ADirectoryName) +
    EncodeDirectoryReplayStoreKey(AKey) + '.entry';
  LStream := TFileStream.Create(LFileName, fmCreate);
  try
    LStream.WriteBuffer(AVersion, SizeOf(Integer));
    LStream.WriteBuffer(AExpiresAt, SizeOf(TDateTime));
  finally
    LStream.Free;
  end;
end;

procedure WriteCorruptDirectoryReplayStoreEntry(
  const ADirectoryName: string;
  const AKey: string;
  const AMode: string
);
var
  LFileName: string;
  LStream: TFileStream;
  LVersion: Integer;
begin
  AssertTrue((ADirectoryName <> '') and ForceDirectories(ADirectoryName),
    'Corrupt directory replay-store entry helper should create the store directory');
  LFileName := IncludeTrailingPathDelimiter(ADirectoryName) +
    EncodeDirectoryReplayStoreKey(AKey) + '.entry';

  if AMode = 'invalid_version' then
  begin
    LVersion := TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION;
    AssertTrue(LVersion = TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      'Corrupt directory replay-store invalid-version helper must keep the fixed version');
    LStream := TFileStream.Create(LFileName, fmCreate);
    try
      LStream.WriteBuffer(LVersion, SizeOf(Integer));
      LStream.WriteBuffer(LVersion, SizeOf(Integer));
    finally
      LStream.Free;
    end;
    Exit;
  end;

  if AMode = 'trailing_garbage' then
  begin
    WriteDirectoryReplayStoreEntry(
      ADirectoryName,
      AKey,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      IncSecond(Now, 600)
    );
    LStream := TFileStream.Create(LFileName, fmOpenReadWrite);
    try
      AssertTrue(REPLAY_PROVIDER_DIRECTORY_TRAILING_GARBAGE_BYTES[0] = $DE,
        'Corrupt directory replay-store trailing-garbage helper must keep the fixed byte tail');
      LStream.Seek(0, soFromEnd);
      LStream.WriteBuffer(
        REPLAY_PROVIDER_DIRECTORY_TRAILING_GARBAGE_BYTES[0],
        SizeOf(REPLAY_PROVIDER_DIRECTORY_TRAILING_GARBAGE_BYTES)
      );
    finally
      LStream.Free;
    end;
    Exit;
  end;

  Fail('Unsupported corrupt directory replay-store mode "' + AMode + '"');
end;

procedure MoveCanonicalReplayStoreToBackupFallback(
  const AFileName: string;
  const ALabel: string
);
var
  LBackupFileName: string;
  LTempFileName: string;
begin
  LBackupFileName := AFileName + '.bak';
  LTempFileName := AFileName + '.tmp';

  DeleteFileIfExists(LBackupFileName);
  DeleteFileIfExists(LTempFileName);
  AssertTrue(FileExists(AFileName),
    ALabel + ' should materialize canonical main replay store file before switching to .bak fallback');
  AssertTrue(RenameFile(AFileName, LBackupFileName),
    ALabel + ' should move the canonical main replay store file to the backup fallback path');
  AssertTrue(not FileExists(AFileName),
    ALabel + ' should leave canonical main replay store file absent for .bak fallback setup');
  AssertTrue(not FileExists(LTempFileName),
    ALabel + ' should keep the temp replay store file absent for .bak fallback setup');
  AssertTrue(FileExists(LBackupFileName),
    ALabel + ' should materialize the backup fallback replay store file');
end;

procedure MoveCanonicalReplayStoreDirectoryToFallback(
  const ADirectoryName: string;
  const AFallbackSuffix: string;
  const ALabel: string
);
var
  LFallbackDirectoryName: string;
begin
  LFallbackDirectoryName := ADirectoryName + AFallbackSuffix;
  RemoveReplayProviderPathTree(LFallbackDirectoryName);

  AssertTrue(DirectoryExists(ADirectoryName),
    ALabel + ' should materialize canonical main directory replay truth before switching to fallback');
  AssertTrue(RenameFile(ADirectoryName, LFallbackDirectoryName),
    ALabel + ' should move the canonical main directory replay truth to the requested fallback path');
  AssertTrue(not DirectoryExists(ADirectoryName),
    ALabel + ' should keep the canonical main directory replay truth absent during fallback setup');
  AssertTrue(DirectoryExists(LFallbackDirectoryName),
    ALabel + ' should materialize the requested directory replay fallback path');
end;

procedure WriteCorruptReplayProviderBackupFallbackStore(
  const AFileName: string;
  const AReplayKey: string;
  const AMode: string
);
begin
  if AMode = 'invalid_version' then
    WriteReplayProviderStoreHeader(
      AFileName,
      TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      0
    )
  else if AMode = 'truncated' then
    WriteReplayProviderTruncatedStoreFile(
      AFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      AReplayKey
    )
  else if AMode = 'invalid_count' then
    WriteReplayProviderStoreHeader(
      AFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_ENTRY_COUNT
    )
  else if AMode = 'invalid_key_length' then
    WriteReplayProviderInvalidKeyLengthStoreFile(
      AFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_KEY_LENGTH
    )
  else if AMode = 'trailing_garbage' then
    WriteReplayProviderTrailingGarbageStoreFile(
      AFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      AReplayKey
    )
  else
    Fail('Unsupported replay-store backup corruption mode "' + AMode + '"');
end;

procedure PrepareServerContextForEarlyData(ACtx: ISSLContext);
begin
  AssertTrue(ACtx <> nil, 'Server context should be created');
  ACtx.SetPreferredVersion(sslProtocolTLS13);
  ACtx.SetSessionCacheMode(True);
  ACtx.SetSessionTimeout(7200);
  ACtx.SetSessionCacheSize(8);
  ACtx.LoadCertificate('tests/certificate/test_certs/signer_cert.pem');
  ACtx.LoadPrivateKey('tests/certificate/test_certs/signer_key.pem');
end;

function CaptureServerIssuedSession(ACtx: ISSLContext): ISSLSession;
var
  LConn: ISSLConnection;
  LStream: TScriptedEarlyDataClientStream;
begin
  LStream := TScriptedEarlyDataClientStream.CreateInitial;
  try
    LConn := ACtx.CreateConnection(LStream);
    AssertTrue(LConn.Accept, 'Initial server accept should succeed before ticket capture');
    Result := LStream.CapturedSession;
    AssertTrue(Result <> nil, 'Initial server accept should capture a resumable session');
  finally
    LStream.Free;
  end;
end;

function BuildAcceptingEarlyDataServerContext: ISSLContext;
var
  LEarlyCtx: ISSLEarlyDataContext;
begin
  Result := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(Result <> nil,
    'Runtime early-data helper should create a FreePascal server context');
  PrepareServerContextForEarlyData(Result);

  AssertTrue(Supports(Result, ISSLEarlyDataContext, LEarlyCtx),
    'Runtime early-data helper should expose early-data context interface');
  if Supports(Result, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
end;

function BuildInstallerFileBackedReplayStoreServerContext(const AFileName: string): ISSLContext;
var
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
begin
  Result := BuildAcceptingEarlyDataServerContext;
  AssertTrue(Supports(Result, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Installer runtime helper should expose backend-private file-backed replay installer seam');
  AssertTrue(LInstaller.InstallFileBackedReplayLedger(AFileName),
    'Installer runtime helper should install a file-backed replay ledger');
end;

function BuildDirectoryReplayStoreServerContext(
  const ADirectoryName: string
): ISSLContext;
var
  LStore: IFreePascalEarlyDataReplayStore;
begin
  Result := BuildAcceptingEarlyDataServerContext;
  LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(ADirectoryName);
  AssertTrue(InstallStoreBackedReplayLedger(Result, LStore),
    'Directory replay-store runtime helper should install a directory-backed replay ledger');
end;

procedure StoreResumptionSessionInContext(
  ACtx: ISSLContext;
  ASession: ISSLSession;
  const ALabel: string
);
var
  LResumptionCache: IFreePascalResumptionCache;
begin
  AssertTrue(ACtx <> nil,
    ALabel + ' should have a server context');
  AssertTrue(ASession <> nil,
    ALabel + ' should have a resumable session');
  AssertTrue(Supports(ACtx, IFreePascalResumptionCache, LResumptionCache),
    ALabel + ' should expose resumption cache seam');
  LResumptionCache.StoreResumptionSession(ASession);
end;

procedure AssertResumedEarlyDataAcceptedAtRuntime(
  ACtx: ISSLContext;
  ASession: ISSLSession;
  const AEarlyData: TBytes;
  const ALabel: string
);
var
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LStream: TScriptedEarlyDataClientStream;
begin
  StoreResumptionSessionInContext(ACtx, ASession, ALabel);

  LStream := TScriptedEarlyDataClientStream.CreateResumed(ASession, AEarlyData, True);
  try
    LConn := ACtx.CreateConnection(LStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      ALabel + ' connection should expose early-data interface');
    AssertTrue(LConn.Accept,
      ALabel + ' should keep the resumed handshake running');
    AssertSessionReused(LConn,
      ALabel + ' should reuse the cached session');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        ALabel + ' should accept early-data');
    AssertTrue(LStream.ObservedServerAcceptedEarlyData,
      ALabel + ' should advertise accepted early-data');
  finally
    LStream.Free;
  end;
end;

procedure AssertResumedEarlyDataRejectedAtRuntime(
  ACtx: ISSLContext;
  ASession: ISSLSession;
  const AEarlyData: TBytes;
  const ALabel: string
);
var
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  StoreResumptionSessionInContext(ACtx, ASession, ALabel);

  LStream := TScriptedEarlyDataClientStream.CreateResumed(ASession, AEarlyData, False);
  try
    LConn := ACtx.CreateConnection(LStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      ALabel + ' connection should expose early-data interface');
    AssertTrue(LConn.Accept,
      ALabel + ' should keep the resumed handshake running');
    AssertSessionReused(LConn,
      ALabel + ' should reuse the cached session');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        ALabel + ' should reject early-data');
    AssertTrue(not LStream.ObservedServerAcceptedEarlyData,
      ALabel + ' should suppress accepted early-data signalling');
    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(0, LRead,
      ALabel + ' should not surface discarded early bytes through Read');
  finally
    LStream.Free;
  end;
end;

function GetSessionMaxEarlyDataSize(ASession: ISSLSession): Cardinal;
var
  LSessionInfo: IFreePascalResumptionSession;
begin
  AssertTrue(Supports(ASession, IFreePascalResumptionSession, LSessionInfo),
    'Captured session should expose FreePascal resumption internals');
  Result := LSessionInfo.GetMaxEarlyDataSize;
end;

procedure TestClientEarlyDataAcceptedAndRejected;
var
  LInitialCtx: ISSLContext;
  LResumedCtx: ISSLContext;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LEarlyCtx: ISSLEarlyDataContext;
  LInitialStream: TScriptedEarlyDataServerStream;
  LAcceptStream: TScriptedEarlyDataServerStream;
  LRejectStream: TScriptedEarlyDataServerStream;
  LSession: ISSLSession;
  LRes: TSSLOperationResult;
begin
  LInitialCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LInitialCtx <> nil, 'Initial client context should be created');
  LInitialCtx.SetPreferredVersion(sslProtocolTLS13);
  LInitialCtx.SetVerifyMode([]);
  LInitialStream := TScriptedEarlyDataServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LConn := LInitialCtx.CreateConnection(LInitialStream);
    (LConn as ISSLClientConnection).SetServerName('example.com');
    AssertTrue(LConn.Connect, 'Initial handshake should succeed for early-data capture');
    LSession := RequireSessionResumption(
      LConn,
      'Initial handshake connection should expose session-resumption owner path'
    ).GetSession;
    AssertTrue(LSession <> nil, 'Initial handshake should capture resumable session');
  finally
    LInitialStream.Free;
  end;

  LResumedCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Supports(LResumedCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Resumed client context should expose early-data context interface');
  if Supports(LResumedCtx, ISSLEarlyDataContext, LEarlyCtx) then
    LEarlyCtx.SetClientEarlyDataEnabled(True);
  LResumedCtx.SetPreferredVersion(sslProtocolTLS13);
  LResumedCtx.SetVerifyMode([]);

  LAcceptStream := TScriptedEarlyDataServerStream.CreateResumed(LSession, True);
  try
    LConn := LResumedCtx.CreateConnection(LAcceptStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Resumed client connection should expose early-data connection interface');
    RequireSessionResumption(
      LConn,
      'Resumed client connection should expose session-resumption owner path'
    ).SetSession(LSession);
    (LConn as ISSLClientConnection).SetServerName('example.com');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      LRes := LEarlyConn.SetEarlyData(BytesOf('PING'));
      AssertTrue(LRes.IsOk, 'SetEarlyData should accept queued bytes on enabled resumed client');
      AssertEqualsInt(8, LEarlyConn.GetEarlyDataLimit,
        'Queued client should expose max_early_data_size from session');
    end;
    AssertTrue(LConn.Connect, 'Resumed client handshake with accepted early data should succeed');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        'Accepted early-data client should report accepted status');
    AssertTrue(BytesEqual(BytesOf('PING'), LAcceptStream.CapturedEarlyData),
      'Scripted server should observe queued early application data');
    AssertTrue(LAcceptStream.ObservedEndOfEarlyData,
      'Accepted early-data path should send EndOfEarlyData before Finished');
  finally
    LAcceptStream.Free;
  end;

  LRejectStream := TScriptedEarlyDataServerStream.CreateResumed(LSession, False);
  try
    LConn := LResumedCtx.CreateConnection(LRejectStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Rejected-path client connection should expose early-data connection interface');
    RequireSessionResumption(
      LConn,
      'Rejected-path client connection should expose session-resumption owner path'
    ).SetSession(LSession);
    (LConn as ISSLClientConnection).SetServerName('example.com');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      LRes := LEarlyConn.SetEarlyData(BytesOf('NOPE'));
      AssertTrue(LRes.IsOk, 'SetEarlyData should queue bytes before rejected handshake');
    end;
    AssertTrue(LConn.Connect, 'Rejected early-data client handshake should still succeed');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        'Rejected early-data client should report rejected status');
    AssertTrue(Length(LRejectStream.CapturedEarlyData) = 0,
      'Reject path should not surface early application data to scripted server');
    AssertTrue(not LRejectStream.ObservedEndOfEarlyData,
      'Reject path should not send EndOfEarlyData');
  finally
    LRejectStream.Free;
  end;
end;

procedure TestConnectorClientEarlyDataAcceptedAndRejected;
var
  LInitialCtx: ISSLContext;
  LResumedCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LEarlyConn: ISSLEarlyDataConnection;
  LInitialStream: TScriptedEarlyDataServerStream;
  LAcceptStream: TScriptedEarlyDataServerStream;
  LRejectStream: TScriptedEarlyDataServerStream;
  LSession: ISSLSession;
  LConnector: TSSLConnector;
  LTLSStream: TSSLStream;
begin
  LInitialCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LInitialCtx <> nil, 'Initial connector client context should be created');
  LInitialCtx.SetPreferredVersion(sslProtocolTLS13);
  LInitialCtx.SetVerifyMode([]);
  LInitialStream := TScriptedEarlyDataServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LTLSStream := TSSLConnector.FromContext(LInitialCtx)
      .ConnectStream(LInitialStream, 'example.com');
    try
      LSession := RequireSessionResumption(
        LTLSStream.Connection,
        'Initial connector handshake connection should expose session-resumption owner path'
      ).GetSession;
      AssertTrue(LSession <> nil, 'Initial connector handshake should capture resumable session');
    finally
      LTLSStream.Free;
    end;
  finally
    LInitialStream.Free;
  end;

  LResumedCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Supports(LResumedCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Connector resumed client context should expose early-data context interface');
  if Supports(LResumedCtx, ISSLEarlyDataContext, LEarlyCtx) then
    LEarlyCtx.SetClientEarlyDataEnabled(True);
  LResumedCtx.SetPreferredVersion(sslProtocolTLS13);
  LResumedCtx.SetVerifyMode([]);

  LAcceptStream := TScriptedEarlyDataServerStream.CreateResumed(LSession, True);
  LTLSStream := nil;
  try
    LConnector := TSSLConnector.FromContext(LResumedCtx)
      .WithSession(LSession)
      .WithEarlyData(BytesOf('PING'));
    LTLSStream := LConnector.ConnectStream(LAcceptStream, 'example.com');
    AssertTrue(LTLSStream <> nil, 'Connector accepted early-data handshake should succeed');
    AssertTrue(Supports(LTLSStream.Connection, ISSLEarlyDataConnection, LEarlyConn),
      'Connector accepted-path connection should expose early-data connection interface');
    if Supports(LTLSStream.Connection, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        'Connector accepted-path client should report accepted early-data status');
    AssertTrue(BytesEqual(BytesOf('PING'), LAcceptStream.CapturedEarlyData),
      'Connector accepted-path should queue early application data before connect');
    AssertTrue(LAcceptStream.ObservedEndOfEarlyData,
      'Connector accepted-path should still send EndOfEarlyData before Finished');
  finally
    LTLSStream.Free;
    LAcceptStream.Free;
  end;

  LRejectStream := TScriptedEarlyDataServerStream.CreateResumed(LSession, False);
  LTLSStream := nil;
  try
    LConnector := TSSLConnector.FromContext(LResumedCtx)
      .WithSession(LSession)
      .WithEarlyData(BytesOf('NOPE'));
    LTLSStream := LConnector.ConnectStream(LRejectStream, 'example.com');
    AssertTrue(LTLSStream <> nil, 'Connector rejected early-data handshake should still succeed');
    AssertTrue(Supports(LTLSStream.Connection, ISSLEarlyDataConnection, LEarlyConn),
      'Connector rejected-path connection should expose early-data connection interface');
    if Supports(LTLSStream.Connection, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        'Connector rejected-path client should report rejected early-data status');
    AssertTrue(Length(LRejectStream.CapturedEarlyData) = 0,
      'Connector reject path should not surface early application data to the scripted server');
    AssertTrue(not LRejectStream.ObservedEndOfEarlyData,
      'Connector reject path should not send EndOfEarlyData');
  finally
    LTLSStream.Free;
    LRejectStream.Free;
  end;
end;

procedure TestClientEarlyDataPreconditions;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LTransport: TMemoryStream;
  LRes: TSSLOperationResult;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'Precondition client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LTransport := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LTransport);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Client connection should expose early-data connection interface for precondition checks');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      LRes := LEarlyConn.SetEarlyData(BytesOf('PING'));
      AssertTrue(LRes.IsErr, 'SetEarlyData should reject when client early data is disabled');
    end;
  finally
    LTransport.Free;
  end;

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Client context should expose early-data context interface for precondition checks');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    LEarlyCtx.SetClientEarlyDataEnabled(True);

  LTransport := TMemoryStream.Create;
  LSession := BuildManualSession('zero-limit', 0);
  try
    LConn := LCtx.CreateConnection(LTransport);
    RequireSessionResumption(
      LConn,
      'Enabled client connection should expose session-resumption owner path'
    ).SetSession(LSession);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Enabled client connection should expose early-data connection interface');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      LRes := LEarlyConn.SetEarlyData(BytesOf('PING'));
      AssertTrue(LRes.IsErr, 'SetEarlyData should reject sessions without max_early_data_size');
    end;
  finally
    LTransport.Free;
  end;
end;

procedure TestServerAcceptRejectAndReplayPolicy;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LStream1: TScriptedEarlyDataClientStream;
  LStream2: TScriptedEarlyDataClientStream;
  LStream3: TScriptedEarlyDataClientStream;
  LSession: ISSLSession;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil, 'Server context should be created for early-data policy tests');
  PrepareServerContextForEarlyData(LCtx);
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Server context should expose early-data context optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  LStream1 := TScriptedEarlyDataClientStream.CreateInitial;
  try
    LConn := LCtx.CreateConnection(LStream1);
    AssertTrue(LConn.Accept, 'Initial server accept should succeed before early-data resumption tests');
    LSession := LStream1.CapturedSession;
    AssertTrue(LSession <> nil, 'Initial server accept should yield resumable session with early-data limit');
    AssertEqualsInt(8, GetSessionMaxEarlyDataSize(LSession),
      'Accept policy should issue tickets with the configured max early-data size');
  finally
    LStream1.Free;
  end;

  LStream2 := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
  try
    LConn := LCtx.CreateConnection(LStream2);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Accepted server connection should expose early-data connection interface');
    AssertTrue(LConn.Accept, 'Accepted early-data server handshake should succeed');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
        'Accepted server connection should report accepted early-data status');
    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(4, LRead, 'Accepted server connection should surface buffered early data through Read');
    AssertTrue((LBuf[0] = $50) and (LBuf[1] = $49) and (LBuf[2] = $4E) and (LBuf[3] = $47),
      'Accepted server early-data bytes should equal PING');
    AssertTrue(LStream2.ObservedServerAcceptedEarlyData,
      'Scripted client should observe early_data extension in EncryptedExtensions');
  finally
    LStream2.Free;
  end;

  LStream3 := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
  try
    LConn := LCtx.CreateConnection(LStream3);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Replay-rejected server connection should expose early-data connection interface');
    AssertTrue(LConn.Accept, 'Replay-rejected early-data server handshake should still resume successfully');
    AssertSessionReused(LConn,
      'Replay-rejected early-data attempt should still complete resumed handshake');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        'Replay-rejected server connection should report rejected early-data status');
    AssertTrue(not LStream3.ObservedServerAcceptedEarlyData,
      'Replay-rejected scripted client should not observe early_data extension');
    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(0, LRead, 'Replay-rejected server should not expose discarded early bytes through Read');
  finally
    LStream3.Free;
  end;
end;

procedure TestServerTicketIssuancePolicyAndMaxSize;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  PrepareServerContextForEarlyData(LCtx);
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Reject-policy server context should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerReject);
    LEarlyCtx.SetServerMaxEarlyDataSize(9);
  end;
  LSession := CaptureServerIssuedSession(LCtx);
  AssertEqualsInt(0, GetSessionMaxEarlyDataSize(LSession),
    'Reject policy should issue tickets with max_early_data_size = 0');

  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  PrepareServerContextForEarlyData(LCtx);
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Issue-only server context should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerIssueOnly);
    LEarlyCtx.SetServerMaxEarlyDataSize(6);
  end;
  LSession := CaptureServerIssuedSession(LCtx);
  AssertEqualsInt(6, GetSessionMaxEarlyDataSize(LSession),
    'Issue-only policy should issue tickets with the configured max_early_data_size');
end;

procedure TestServerIssueOnlyRejectsResumedEarlyData;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LSession: ISSLSession;
  LStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  PrepareServerContextForEarlyData(LCtx);
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Issue-only server context should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerIssueOnly);
    LEarlyCtx.SetServerMaxEarlyDataSize(6);
  end;

  LSession := CaptureServerIssuedSession(LCtx);
  AssertEqualsInt(6, GetSessionMaxEarlyDataSize(LSession),
    'Issue-only policy should still issue early-data-capable tickets');

  LStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), False);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Issue-only resumed server connection should expose early-data interface');
    AssertTrue(LConn.Accept, 'Issue-only resumed handshake should still succeed');
    AssertSessionReused(LConn,
      'Issue-only resumed handshake should still reuse the session');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        'Issue-only policy should reject resumed early data');
    AssertTrue(not LStream.ObservedServerAcceptedEarlyData,
      'Issue-only policy should not signal accepted early data to the client');
    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(0, LRead, 'Issue-only policy should not surface resumed early-data bytes');
  finally
    LStream.Free;
  end;
end;

procedure TestClientConfiguredEarlyDataLimit;
var
  LServerCtx: ISSLContext;
  LClientCtx: ISSLContext;
  LServerEarlyCtx: ISSLEarlyDataContext;
  LClientEarlyCtx: ISSLEarlyDataContext;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LSession: ISSLSession;
  LTransport: TMemoryStream;
  LRes: TSSLOperationResult;
begin
  LServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  PrepareServerContextForEarlyData(LServerCtx);
  AssertTrue(Supports(LServerCtx, ISSLEarlyDataContext, LServerEarlyCtx),
    'Custom-limit server context should expose early-data context interface');
  if Supports(LServerCtx, ISSLEarlyDataContext, LServerEarlyCtx) then
  begin
    LServerEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LServerEarlyCtx.SetServerMaxEarlyDataSize(3);
  end;
  LSession := CaptureServerIssuedSession(LServerCtx);
  AssertEqualsInt(3, GetSessionMaxEarlyDataSize(LSession),
    'Accept policy should issue tickets with the configured custom max size');

  LClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Supports(LClientCtx, ISSLEarlyDataContext, LClientEarlyCtx),
    'Client context should expose early-data context interface for custom-limit tests');
  if Supports(LClientCtx, ISSLEarlyDataContext, LClientEarlyCtx) then
    LClientEarlyCtx.SetClientEarlyDataEnabled(True);
  LClientCtx.SetPreferredVersion(sslProtocolTLS13);

  LTransport := TMemoryStream.Create;
  try
    LConn := LClientCtx.CreateConnection(LTransport);
    RequireSessionResumption(
      LConn,
      'Configured-limit client connection should expose session-resumption owner path'
    ).SetSession(LSession);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Configured-limit client connection should expose early-data interface');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      LRes := LEarlyConn.SetEarlyData(BytesOf('PING'));
      AssertTrue(LRes.IsErr,
        'SetEarlyData should reject payloads that exceed the configured ticket limit');
    end;
  finally
    LTransport.Free;
  end;
end;

procedure TestReplayLedgerSessionValidity;
var
  LCtx: ISSLContext;
  LReplayLedger: IFreePascalEarlyDataReplayLedger;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LValidSession: ISSLSession;
  LExpiredSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil, 'Server context should be created for replay-ledger validity tests');
  LCtx.SetSessionCacheMode(True);
  LCtx.SetSessionCacheSize(8);
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Server context should expose replay-ledger access seam');
  LReplayLedger := LReplayAccess.GetEarlyDataReplayLedger;
  AssertTrue(LReplayLedger <> nil,
    'Replay-ledger access seam should expose the default in-memory ledger');
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedger, LReplayLedger),
    'Server context should expose internal early-data replay ledger');

  LValidSession := BuildManualSession('ledger-valid', 8);
  AssertTrue(LReplayLedger.TryAcquireEarlyDataSession(LValidSession),
    'Valid early-data session should acquire replay ledger entry once');
  AssertTrue(not LReplayLedger.TryAcquireEarlyDataSession(LValidSession),
    'Replaying the same valid session should be rejected');

  LExpiredSession := BuildManualSessionWithTiming(
    'ledger-expired',
    8,
    1,
    IncSecond(Now, -10),
    7200
  );
  AssertTrue(not LReplayLedger.TryAcquireEarlyDataSession(LExpiredSession),
    'Expired early-data session should be rejected before entering replay ledger');

  LFreshSession := BuildManualSession('ledger-fresh', 8);
  AssertTrue(LReplayLedger.TryAcquireEarlyDataSession(LFreshSession),
    'Expired replay attempts must not pollute the ledger for fresh valid sessions');
end;

procedure TestDefaultReplayLedgerTracksSessionCacheSettings;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger: IFreePascalEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Default replay-ledger cache-sync test should create a FreePascal server context');
  LCtx.SetSessionCacheMode(True);
  LCtx.SetSessionCacheSize(8);
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Default replay-ledger cache-sync test should expose replay-ledger access seam');

  LLedger := LReplayAccess.GetEarlyDataReplayLedger;
  AssertTrue(LLedger <> nil,
    'Default replay-ledger cache-sync test should expose the default replay ledger');

  LSession := BuildManualSession('default-ledger-cache-sync', 8);
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
    'Default replay ledger should accept the first valid session acquire before cache setting transitions');

  LCtx.SetSessionCacheMode(False);
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
    'Default replay ledger should inherit disabled session-cache state');

  LCtx.SetSessionCacheMode(True);
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
    'Re-enabling session cache should clear default replay truth so the same session can acquire again');

  LCtx.SetSessionCacheSize(0);
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
    'Setting session cache size to zero should disable default replay acquisition');

  LCtx.SetSessionCacheSize(8);
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
    'Restoring session cache size should restore default replay acquisition for the same session');
end;

procedure TestDefaultReplayStoreRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger1: IFreePascalEarlyDataReplayLedger;
  LLedger2: IFreePascalEarlyDataReplayLedger;
  LDirectoryName: string;
  LSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('default_shipped_path');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  PrepareDefaultReplayStoreDirectoryForTesting(LDirectoryName);
  try
    LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Default durable replay-store test should create both FreePascal server contexts');
    PrepareServerContextForEarlyData(LCtx1);
    PrepareServerContextForEarlyData(LCtx2);

    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Default durable replay-store first context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Default durable replay-store second context should expose replay-ledger access seam');

    LLedger1 := LReplayAccess1.GetEarlyDataReplayLedger;
    LLedger2 := LReplayAccess2.GetEarlyDataReplayLedger;
    AssertTrue((LLedger1 <> nil) and (LLedger2 <> nil),
      'Default durable replay-store test should expose active replay ledgers on both contexts');

    LSession := BuildManualSession('default-durable-cross-context', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Default durable replay-store should accept the first valid session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Default durable replay-store should materialize the canonical replay-store directory');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Default durable replay-store should reject replay across server contexts without explicit config');
  finally
    ResetDefaultReplayStoreDirectoryForTesting;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDefaultReplayStoreRetainsReplayTruthAcrossProcessRestart;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSessionFileName: string;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LFreshAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('default_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'session.bin');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  PrepareDefaultReplayStoreDirectoryForTesting(LDirectoryName);
  try
    LCtx := BuildAcceptingEarlyDataServerContext;
    AssertTrue(LCtx <> nil,
      'Default durable runtime restart test should create a FreePascal server context');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Default durable runtime restart test should expose replay-ledger access seam');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Default durable runtime restart test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Default durable runtime restart accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Default durable replay-store should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Default durable runtime restart test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Default durable replay-store should still accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Default durable replay-store should advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(DirectoryExists(LDirectoryName),
      'Default durable runtime restart test should materialize the replay-store directory before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Default durable runtime restart test should materialize the serialized session marker before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LDirectoryName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DEFAULT);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Default durable runtime replay probe should exit cleanly after rejecting replay in a new process');
    finally
      LProcess.Free;
    end;

    LFreshSession := CaptureServerIssuedSession(LCtx);
    LFreshAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(
      LFreshSession,
      BytesOf('PONG'),
      True
    );
    try
      LConn := LCtx.CreateConnection(LFreshAcceptStream);
      AssertTrue(LConn.Accept,
        'Default durable replay-store should still accept a fresh resumed session after restart replay rejection');
    finally
      LFreshAcceptStream.Free;
    end;
  finally
    ResetDefaultReplayStoreDirectoryForTesting;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestReplaceableReplayLedgerRejectsFirstUseEarlyData;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LCustomLedger: TRejectingReplayLedger;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LInitialStream: TScriptedEarlyDataClientStream;
  LReplayStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil, 'Server context should be created for replaceable replay-ledger tests');
  PrepareServerContextForEarlyData(LCtx);
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Server context should expose early-data context interface for replaceable replay-ledger tests');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Server context should expose replay-ledger access seam for replaceable replay-ledger tests');

  LCustomLedger := TRejectingReplayLedger.Create;
  LReplayAccess.SetEarlyDataReplayLedger(LCustomLedger);
  AssertTrue(LReplayAccess.GetEarlyDataReplayLedger <> nil,
    'Replay-ledger access seam should expose the injected custom ledger');

  LInitialStream := TScriptedEarlyDataClientStream.CreateInitial;
  try
    LConn := LCtx.CreateConnection(LInitialStream);
    AssertTrue(LConn.Accept, 'Initial server accept should succeed before custom replay-ledger resumed test');
    LSession := LInitialStream.CapturedSession;
    AssertTrue(LSession <> nil, 'Initial server accept should yield resumable session for custom replay-ledger test');
  finally
    LInitialStream.Free;
  end;

  LReplayStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), False);
  try
    LConn := LCtx.CreateConnection(LReplayStream);
    AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'Replaceable replay-ledger connection should expose early-data interface');
    AssertTrue(LConn.Accept, 'Custom replay-ledger rejected early-data server handshake should still succeed');
    AssertSessionReused(LConn,
      'Custom replay-ledger rejected early-data attempt should still complete resumed handshake');
    if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
        'Custom replay-ledger should be able to reject first-use resumed early data');
    AssertEqualsInt(1, LCustomLedger.AcquireCalls,
      'Custom replay-ledger should be consulted exactly once for the resumed early-data attempt');
    AssertTrue(LCustomLedger.LastSession <> nil,
      'Custom replay-ledger should receive the cached resumable session');
    AssertTrue(LCustomLedger.LastSession.IsResumable,
      'Custom replay-ledger should receive a resumable cached session');
    AssertTrue(not LReplayStream.ObservedServerAcceptedEarlyData,
      'Custom replay-ledger rejection should suppress accepted early-data signalling');
    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(0, LRead,
      'Custom replay-ledger rejection should not surface early-data bytes through Read');
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    LReplayStream.Free;
  end;
end;

procedure TestProviderBackedReplayLedgerCoordinatesAcrossLedgers;
var
  LStore: TSharedReplayProviderStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LValidSession: ISSLSession;
  LExpiredSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LStore := TSharedReplayProviderStore.Create;
  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);

    LValidSession := BuildManualSession('provider-valid', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LValidSession),
      'Provider-backed ledger should accept first acquire for a fresh valid session');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LValidSession),
      'Shared provider-backed ledger should reject replay across independent ledger instances');

    LExpiredSession := BuildManualSessionWithTiming(
      'provider-expired',
      8,
      1,
      IncSecond(Now, -10),
      7200
    );
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExpiredSession),
      'Expired session should be rejected before entering shared provider state');

    LFreshSession := BuildManualSession('provider-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Expired provider-backed replay attempts must not pollute fresh valid sessions');
  finally
    LStore.Free;
  end;
end;

procedure TestProviderBackedReplayLedgerRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LStore: TSharedReplayProviderStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Provider-backed replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam');

  LStore := TSharedReplayProviderStore.Create;
  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    LReplayAccess1.SetEarlyDataReplayLedger(LLedger1);
    LReplayAccess2.SetEarlyDataReplayLedger(LLedger2);

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Provider-backed accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Provider-backed shared replay state should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'First resumed early-data attempt should remain accepted with shared provider-backed replay state');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'First resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Provider-backed replay-rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Provider-backed replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Provider-backed replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Shared provider-backed replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Provider-backed cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Provider-backed cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

procedure TestCallbackReplayProviderFailsClosedOnProviderExceptions;
var
  LStore: TExplodingReplayProviderStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LRaised: Boolean;
begin
  LStore := TExplodingReplayProviderStore.Create;
  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    LSession := BuildManualSession('provider-explodes', 8);

    LRaised := False;
    try
      AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
        'Exploding callback-backed replay provider should fail closed instead of accepting early-data replay state');
    except
      on E: Exception do
      begin
        LRaised := True;
        Fail('Exploding callback-backed replay provider should not escape exception: ' + E.Message);
      end;
    end;
    AssertTrue(not LRaised,
      'Exploding callback-backed replay provider should not raise after fail-closed acquire');
  finally
    LStore.Free;
  end;
end;

procedure TestStoreBackedReplayProviderPreservesReplayTruthAcrossProviderRebuild;
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LValidSession: ISSLSession;
  LExpiredSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LStore := TFreePascalSharedInMemoryReplayStore.Create;
  LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

  LValidSession := BuildManualSession('store-backed-provider-valid', 8);
  AssertTrue(LLedger1.TryAcquireEarlyDataSession(LValidSession),
    'Store-backed replay provider should accept first acquire for a fresh valid session');

  LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
  AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LValidSession),
    'Rebuilt store-backed replay provider should preserve shared replay truth and reject replay');

  LExpiredSession := BuildManualSessionWithTiming(
    'store-backed-provider-expired',
    8,
    1,
    IncSecond(Now, -10),
    7200
  );
  AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExpiredSession),
    'Expired session should still be rejected before entering store-backed replay state');

  LFreshSession := BuildManualSession('store-backed-provider-fresh', 8);
  AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
    'Rebuilt store-backed replay provider should still accept fresh valid sessions after replay rejection');
end;

procedure TestStoreBackedReplayProviderClearsSharedTruthAcrossDisableAndReenable;
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LStore := TFreePascalSharedInMemoryReplayStore.Create;
  LProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);

  LSession := BuildManualSession('store-backed-provider-disable-clear', 8);
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
    'Shared in-memory store-backed ledger should accept the first valid session acquire');

  LLedger.SetEnabled(False);
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
    'Disabled shared in-memory store-backed ledger should reject acquire attempts');

  LLedger.SetEnabled(True);
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
    'Re-enabled shared in-memory store-backed ledger should clear replay truth so the same session can acquire again');
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
    'Re-enabled shared in-memory store-backed ledger should reject replay again after reacquiring the same session');
end;

procedure TestStoreBackedReplayProviderEvictsOldestEntryAtCapacityAcrossRebuild;
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession1: ISSLSession;
  LSession2: ISSLSession;
  LSession3: ISSLSession;
begin
  LStore := TFreePascalSharedInMemoryReplayStore.Create;
  LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 2);

  LSession1 := BuildManualSession('store-backed-provider-capacity-1', 8);
  LSession2 := BuildManualSession('store-backed-provider-capacity-2', 8);
  LSession3 := BuildManualSession('store-backed-provider-capacity-3', 8);

  AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession1),
    'Capacity-bound shared in-memory store-backed ledger should accept session1');
  AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession2),
    'Capacity-bound shared in-memory store-backed ledger should accept session2');
  AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession3),
    'Capacity-bound shared in-memory store-backed ledger should accept session3');

  LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 2);
  AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession2),
    'Rebuilt capacity-bound shared in-memory store-backed ledger should still retain session2 replay truth');
  AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession3),
    'Rebuilt capacity-bound shared in-memory store-backed ledger should still retain session3 replay truth');
  AssertTrue(LLedger2.TryAcquireEarlyDataSession(LSession1),
    'Rebuilt capacity-bound shared in-memory store-backed ledger should evict the oldest entry so session1 can acquire again');
end;

procedure AssertStoreBackedReplayFailureModeFailsClosed(
  AFailureMode: TReplayStoreFailureMode;
  const ALabel: string
);
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LRaised: Boolean;
begin
  LStore := TSharedReplayEntryStore.Create(AFailureMode);
  LProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
  LSession := BuildManualSession('store-backed-provider-fail-closed', 8);

  LRaised := False;
  try
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession), ALabel);
  except
    on E: Exception do
    begin
      LRaised := True;
      Fail(ALabel + ' (unexpected exception: ' + E.Message + ')');
    end;
  end;
  AssertTrue(not LRaised,
    ALabel + ' (store-backed replay provider should not escape exceptions)');
end;

procedure TestStoreBackedReplayProviderFailsClosedOnStoreFailures;
begin
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmRaiseOnGuard,
    'Exploding replay-store guard should be fail-closed'
  );
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmRaiseOnLoad,
    'Exploding replay-store load should be fail-closed'
  );
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmRaiseOnSave,
    'Exploding replay-store save should be fail-closed'
  );
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmFalseOnGuard,
    'Replay-store guard returning False should fail closed'
  );
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmFalseOnLoad,
    'Replay-store load returning False should fail closed'
  );
  AssertStoreBackedReplayFailureModeFailsClosed(
    rsfmFalseOnSave,
    'Replay-store save returning False should fail closed'
  );
end;

procedure TestStoreBackedReplayInstallHelperRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LStore: IFreePascalEarlyDataReplayStore;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Store-backed helper replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface for store-backed helper tests');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface for store-backed helper tests');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for store-backed helper tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for store-backed helper tests');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for store-backed helper tests');

  LStore := TFreePascalSharedInMemoryReplayStore.Create;
  try
    AssertTrue(not InstallStoreBackedReplayLedger(nil, LStore),
      'Store-backed replay install helper should fail closed for nil context');
    AssertTrue(not InstallStoreBackedReplayLedger(LCtx1, nil),
      'Store-backed replay install helper should fail closed for nil store');
    AssertTrue(InstallStoreBackedReplayLedger(LCtx1, LStore),
      'Store-backed replay install helper should install shared replay store into the first context');
    AssertTrue(InstallStoreBackedReplayLedger(LCtx2, LStore),
      'Store-backed replay install helper should install shared replay store into the second context');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Store-backed helper accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Store-backed helper should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Store-backed helper first resumed early-data attempt should remain accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Store-backed helper first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Store-backed helper rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Store-backed helper replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Store-backed helper replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Store-backed helper replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Store-backed helper cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Store-backed helper cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
  end;
end;

procedure AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
  AFailureMode: TReplayStoreFailureMode;
  const ALabel: string
);
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LStore: IFreePascalEarlyDataReplayStore;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LReplayStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
  LRaised: Boolean;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Store-backed helper fail-closed runtime test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Store-backed helper fail-closed runtime test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Store-backed helper fail-closed runtime test should expose replay-ledger access seam');

  LStore := TSharedReplayEntryStore.Create(AFailureMode);
  try
    AssertTrue(InstallStoreBackedReplayLedger(LCtx, LStore),
      'Store-backed helper should still install replay store for fail-closed runtime validation');

    LSession := CaptureServerIssuedSession(LCtx);
    LReplayStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('BANG'), False);
    try
      LConn := LCtx.CreateConnection(LReplayStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Store-backed helper fail-closed runtime connection should expose early-data interface');

      LRaised := False;
      try
        AssertTrue(LConn.Accept, ALabel + ' should reject early-data without aborting resumed handshake');
      except
        on E: Exception do
        begin
          LRaised := True;
          Fail(ALabel + ' should not abort handshake with exception: ' + E.Message);
        end;
      end;
      AssertTrue(not LRaised,
        ALabel + ' should keep resumed handshake running');

      AssertSessionReused(LConn,
        ALabel + ' should still reuse the cached session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          ALabel + ' should fail closed by rejecting early-data');
      AssertTrue(not LReplayStream.ObservedServerAcceptedEarlyData,
        ALabel + ' should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        ALabel + ' should not surface discarded early bytes through Read');
    finally
      LReplayStream.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
  end;
end;

procedure TestStoreBackedReplayInstallHelperFailsClosedOnStoreFailures;
begin
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmRaiseOnGuard,
    'Exploding replay-store guard through store-backed helper runtime path'
  );
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmRaiseOnLoad,
    'Exploding replay-store load through store-backed helper runtime path'
  );
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmRaiseOnSave,
    'Exploding replay-store save through store-backed helper runtime path'
  );
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmFalseOnGuard,
    'Replay-store guard returning False through store-backed helper runtime path'
  );
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmFalseOnLoad,
    'Replay-store load returning False through store-backed helper runtime path'
  );
  AssertStoreBackedReplayInstallHelperFailureModeFailsClosedAtRuntime(
    rsfmFalseOnSave,
    'Replay-store save returning False through store-backed helper runtime path'
  );
end;

procedure TestDirectoryReplayStorePreservesReplayTruthAcrossProviderRebuild;
var
  LDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LValidSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('direct_rebuild');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

    LValidSession := BuildManualSession('directory-store-provider-valid', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LValidSession),
      'Directory-backed replay store should accept first acquire for a fresh valid session');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Directory-backed replay store should materialize its store directory after first acquire');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LValidSession),
      'Rebuilt directory-backed replay store should preserve replay truth and reject replay');

    LFreshSession := BuildManualSession('directory-store-provider-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Rebuilt directory-backed replay store should still accept fresh valid sessions after replay rejection');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStorePrunesExpiredPersistedEntriesAfterRebuild;
var
  LDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LReplayKey: string;
begin
  LSession := BuildManualSession('directory-store-prune', 8);
  LReplayKey := ResolveSessionReplayKey(LSession);
  AssertTrue(LReplayKey <> '',
    'Directory replay-store prune test should derive a replay key from the resumable session');

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('expired_prune');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    WriteDirectoryReplayStoreEntry(
      LDirectoryName,
      LReplayKey,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      IncSecond(Now, -10)
    );

    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Expired directory replay-store entry should be pruned before a fresh acquire after rebuild');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Fresh replay truth written after pruning an expired directory entry should still reject replay on the next rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreInstallHelperUsesReplayTruthAtRuntime;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_cross_context');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx1 := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    LCtx2 := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      LSession := CaptureServerIssuedSession(LCtx1);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx1,
        LSession,
        BytesOf('DIR1'),
        'Directory-backed replay store should allow the first resumed early-data attempt at runtime'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx2,
        LSession,
        BytesOf('DIR2'),
        'Directory-backed replay store should reject replay across rebuilt runtime contexts'
      );
    finally
      if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
        LReplayAccess1.ResetEarlyDataReplayLedger;
      if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
        LReplayAccess2.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnCorruptEntryAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LBlockedSession: ISSLSession;
  LRecoveredSession: ISSLSession;
  LReplayKey: string;
  LDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);
  LRecoveredSession := CaptureServerIssuedSession(LCaptureCtx);
  LReplayKey := ResolveSessionReplayKey(LBlockedSession);
  AssertTrue(LReplayKey <> '',
    'Directory replay-store corruption runtime test should derive a replay key from the resumable session');

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_corrupt_entry');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    WriteCorruptDirectoryReplayStoreEntry(
      LDirectoryName,
      LReplayKey,
      'trailing_garbage'
    );

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('FAIL'),
        'Corrupt directory replay-store entry through runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    CleanupReplayProviderStoreDirectory(LDirectoryName);
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LRecoveredSession,
        BytesOf('GOOD'),
        'Directory replay-store runtime path should recover after removing the corrupt entry'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnUnreadableStoreDirectoryAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LDirectoryName: string;
begin
  {$IFNDEF UNIX}
  Exit;
  {$ENDIF}

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_unreadable_directory');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    AssertTrue(ForceDirectories(LDirectoryName),
      'Unreadable directory replay-store runtime test should create the canonical store directory');
    AssertTrue(FpChmod(PChar(LDirectoryName), 0) = 0,
      'Unreadable directory replay-store runtime test should remove directory permissions');

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('LIST'),
        'Unreadable directory replay-store through runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    FpChmod(PChar(LDirectoryName), 448);
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreCleansTempDirAfterSnapshotWriteFailure;
var
  LStore: IFreePascalEarlyDataReplayStore;
  LEntries: TFreePascalEarlyDataReplayStoreEntries;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LOversizeKey: string;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('snapshot_write_failure_cleanup');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    SetLength(LEntries, 2);
    LEntries[0].Key := 'fresh';
    LEntries[0].ExpiresAt := IncSecond(Now, 600);
    LOversizeKey := StringOfChar('x', TEST_INVALID_REPLAY_PROVIDER_KEY_LENGTH);
    LEntries[1].Key := LOversizeKey;
    LEntries[1].ExpiresAt := IncSecond(Now, 600);

    AssertTrue(not LStore.SaveEntries(LEntries),
      'Directory replay-store should fail closed when snapshot writing hits an oversize key');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Directory replay-store should clean up the staging .tmpdir after snapshot write failure');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Directory replay-store should not materialize the canonical store directory after snapshot write failure');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedWhileCrossProcessLockIsHeld;
{$IFNDEF UNIX}
begin
  WriteLn('[SKIP] directory-store cross-process lock contention contract is Unix-only');
end;
{$ELSE}
var
  LDirectoryName: string;
  LReadyFileName: string;
  LReleaseFileName: string;
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LProcess: TProcess;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('directory-store-cross-process-lock-held', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('cross_process_lock_held');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'ready');
  LReleaseFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'release');
  CleanupReplayProviderStoreDirectory(LDirectoryName);

  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := ParamStr(0);
    LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE);
    LProcess.Parameters.Add(LDirectoryName);
    LProcess.Parameters.Add(LReadyFileName);
    LProcess.Parameters.Add(LReleaseFileName);
    LProcess.Options := [];
    LProcess.Execute;

    AssertTrue(WaitForFileExists(LReadyFileName, 5000),
      'Directory replay-store helper should signal when the sidecar lock is held');

    LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Active cross-process directory replay-store lock should fail closed instead of accepting early-data replay state');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Directory replay-store should not materialize canonical directory state while the cross-process lock is held');

    TouchFile(LReleaseFileName);
    LProcess.WaitOnExit;
    AssertEqualsInt(0, LProcess.ExitCode,
      'Directory replay-store lock-holder helper should exit cleanly after release');

    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Blocked directory replay-store session should still acquire after the cross-process lock is released');
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Directory replay-store should still reject replay after materializing truth following lock release');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Directory replay-store should materialize canonical directory state again after release');
  finally
    if (LReleaseFileName <> '') and (not FileExists(LReleaseFileName)) then
      TouchFile(LReleaseFileName);
    try
      LProcess.WaitOnExit;
    except
    end;
    LProcess.Free;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;
{$ENDIF}

procedure TestDirectoryReplayStoreIgnoresOrphanLockFileAcrossProviderRebuild;
var
  LDirectoryName: string;
  LLockFileName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('directory-store-orphan-lock-file', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('orphan_lock_file');
  LLockFileName := BuildReplayProviderLockFilePath(LDirectoryName);
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LLockFileName);

    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Orphan directory replay-store lock file without an active holder should not block a fresh acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after orphan directory replay-store lock file should materialize canonical directory state');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Orphan directory replay-store lock file should not prevent replay truth from surviving provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreRecoversReplayTruthFromOrphanTempDirectoryAcrossProviderRebuild;
var
  LDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('orphan_tempdir_live');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

    LSession := BuildManualSession('directory-store-orphan-tempdir-live', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory replay-store orphan .tmpdir recovery test should first materialize canonical replay truth');
    MoveCanonicalReplayStoreDirectoryToFallback(
      LDirectoryName,
      '.tmpdir',
      'Directory replay-store orphan .tmpdir recovery test'
    );

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Orphan directory .tmpdir replay truth should still reject replay across provider rebuild');

    LFreshSession := BuildManualSession('directory-store-orphan-tempdir-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Fresh session should still be acquirable after orphan directory .tmpdir replay recovery');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after orphan directory .tmpdir replay recovery should re-materialize canonical directory state');
    AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
      'Fresh acquire after orphan directory .tmpdir replay recovery should clean the consumed .tmpdir fallback');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStorePreservesTempDirResidueAcrossRepeatedReplayRejects;
var
  LDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('orphan_tempdir_residue');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

    LSession := BuildManualSession('directory-store-orphan-tempdir-residue', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory replay-store .tmpdir residue test should first materialize canonical replay truth');
    MoveCanonicalReplayStoreDirectoryToFallback(
      LDirectoryName,
      '.tmpdir',
      'Directory replay-store .tmpdir residue test'
    );

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'First replay reject from directory replay-store .tmpdir residue should keep rejecting the original session');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Pure replay reject from directory replay-store .tmpdir residue should keep canonical directory state absent');
    AssertTrue(DirectoryExists(LDirectoryName + '.tmpdir'),
      'Pure replay reject from directory replay-store .tmpdir residue should preserve the live fallback directory');

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(not LLedger3.TryAcquireEarlyDataSession(LSession),
      'Repeated provider rebuild should still reject replay from the same directory replay-store .tmpdir residue');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Repeated replay reject from directory replay-store .tmpdir residue should still keep canonical directory state absent');
    AssertTrue(DirectoryExists(LDirectoryName + '.tmpdir'),
      'Repeated replay reject from directory replay-store .tmpdir residue should still preserve the live fallback directory');

    LFreshSession := BuildManualSession('directory-store-orphan-tempdir-residue-fresh', 8);
    AssertTrue(LLedger3.TryAcquireEarlyDataSession(LFreshSession),
      'Fresh session should still be acquirable after repeated directory replay-store .tmpdir residue replay rejects');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after repeated directory replay-store .tmpdir residue replay rejects should re-materialize canonical directory state');
    AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
      'Fresh acquire after repeated directory replay-store .tmpdir residue replay rejects should consume the fallback .tmpdir');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreRecoversReplayTruthFromBackupDirectoryAcrossProviderRebuild;
var
  LDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('backupdir_live');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

    LSession := BuildManualSession('directory-store-backupdir-live', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory replay-store .bakdir recovery test should first materialize canonical replay truth');
    MoveCanonicalReplayStoreDirectoryToFallback(
      LDirectoryName,
      '.bakdir',
      'Directory replay-store .bakdir recovery test'
    );

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Directory replay-store .bakdir fallback should still reject replay across provider rebuild');

    LFreshSession := BuildManualSession('directory-store-backupdir-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Fresh session should still be acquirable after directory replay-store .bakdir recovery');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after directory replay-store .bakdir recovery should re-materialize canonical directory state');
    AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
      'Fresh acquire after directory replay-store .bakdir recovery should clean the consumed .bakdir fallback');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackup;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LResidueSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LExistingSession := BuildManualSession('dir-bak-residue-existing', 8);
  LResidueSession := BuildManualSession('dir-bak-residue-accepted', 8);
  LBlockedSession := BuildManualSession('dir-bak-residue-blocked', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('bakdir_cleanup_delete_failure_residue');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical directory replay truth before scripted .bakdir cleanup failure');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Initial acquire should materialize canonical directory replay truth before scripted .bakdir cleanup failure');

    LScriptedStore := TScriptedBackupCleanupDeleteFailureDirectoryReplayStore.Create(LDirectoryName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(LScriptedLedger.TryAcquireEarlyDataSession(LResidueSession),
      'Directory .bakdir cleanup failure should still accept the fresh session after canonical main replacement succeeds');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Directory .bakdir cleanup failure should keep canonical directory replay truth after the successful replacement');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Directory .bakdir cleanup failure should still clean up the temp directory after the successful replacement');
    AssertTrue(DirectoryExists(LBackupDirectoryName),
      'Directory .bakdir cleanup failure should leave a stale backup residue when cleanup delete fails');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Directory .bakdir cleanup failure should preserve the original replay truth immediately');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LResidueSession),
      'Directory .bakdir cleanup failure should persist the fresh accepted replay truth through the canonical main directory');

    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Undeletable stale directory .bakdir residue on the next save should fail closed');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Undeletable stale directory .bakdir residue on the next save should preserve canonical directory replay truth');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Undeletable stale directory .bakdir residue on the next save should not leave a temp directory behind');
    AssertTrue(DirectoryExists(LBackupDirectoryName),
      'Undeletable stale directory .bakdir residue on the next save should preserve the stale backup artifact');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after stale directory .bakdir residue should still reject the original replay truth');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LResidueSession),
      'Provider rebuild after stale directory .bakdir residue should still reject the fresh replay truth materialized before the cleanup failure');
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after stale directory .bakdir residue should still accept the blocked session once stale backup cleanup succeeds');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after stale directory .bakdir residue should keep canonical directory replay truth materialized');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Successful recovery after stale directory .bakdir residue should consume the backup artifact');

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(not LLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after stale directory .bakdir residue recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStorePreservesExistingTruthAcrossBackupAssistedReplaceFailure;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LExistingSession := BuildManualSession('dir-replace-failed-existing', 8);
  LBlockedSession := BuildManualSession('dir-replace-failed-blocked', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('backup_assisted_replace_failure_truth_preservation');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical directory replay truth before scripted backup-assisted replace failure');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Initial acquire should materialize canonical directory replay truth before scripted backup-assisted replace failure');

    LScriptedStore := TScriptedExistingMainReplaceFailureDirectoryReplayStore.Create(LDirectoryName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Backup-assisted directory replace failure should fail closed while preserving canonical replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Backup-assisted directory replace failure should preserve the canonical directory replay truth');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Backup-assisted directory replace failure should clean up the temp directory');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Backup-assisted directory replace failure should restore old truth without leaving a backup artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Backup-assisted directory replace failure should preserve the original replay truth immediately');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after backup-assisted directory replace failure should still reject the original replay truth');
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after backup-assisted directory replace failure should still accept the fresh blocked session');

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(not LLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after directory replace recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreRecoversReplayTruthFromBackupAfterRestoreFailure;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LExistingSession := BuildManualSession('dir-restore-failed-existing', 8);
  LBlockedSession := BuildManualSession('dir-restore-failed-blocked', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('backup_restore_failure_recovery');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical directory replay truth before scripted backup restore failure');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Initial acquire should materialize canonical directory replay truth before scripted backup restore failure');

    LScriptedStore := TScriptedBackupRestoreFailureDirectoryReplayStore.Create(LDirectoryName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Directory backup restore failure should fail closed for the fresh blocked session');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Directory backup restore failure should leave the canonical main directory missing after restore fails');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Directory backup restore failure should clean up the temp directory');
    AssertTrue(DirectoryExists(LBackupDirectoryName),
      'Directory backup restore failure should preserve the backup directory artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Directory backup restore failure should still reject the original replay truth through the backup artifact');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after directory backup restore failure should still reject the original replay truth from the backup artifact');
    AssertTrue(DirectoryExists(LBackupDirectoryName),
      'Replay rejection after directory backup restore failure should not consume the backup artifact');
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after directory backup restore failure should still accept the fresh blocked session');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Fresh acquire after directory backup restore failure should materialize the canonical main directory again');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Successful recovery after directory backup restore failure should consume the backup artifact');

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(not LLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after directory backup restore recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnDeterministicTempPromotionRenameDeniedAndRecovers;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LNormalStore1: IFreePascalEarlyDataReplayStore;
  LNormalStore2: IFreePascalEarlyDataReplayStore;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LBlockedSession: ISSLSession;
begin
  LBlockedSession := BuildManualSession('dir-temp-promotion-denied', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('temp_promotion_rename_denied_failclosed');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LScriptedStore := TScriptedTempPromotionRenameDeniedDirectoryReplayStore.Create(LDirectoryName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Deterministic directory temp-promotion rename denial should fail closed for a fresh blocked session');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Deterministic directory temp-promotion rename denial should keep the canonical main directory absent');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Deterministic directory temp-promotion rename denial should clean up the temp directory');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Deterministic directory temp-promotion rename denial should not create a backup artifact');

    LNormalStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LNormalProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LNormalStore1);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after deterministic directory temp-promotion rename denial should still accept the blocked session');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovery after deterministic directory temp-promotion rename denial should materialize the canonical main directory');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Recovery after deterministic directory temp-promotion rename denial should not leave a backup artifact');

    LNormalStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LNormalProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LNormalStore2);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after deterministic directory temp-promotion rename denial recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnDeterministicBackupPromotionRenameDeniedAndRecovers;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LExistingSession := BuildManualSession('dir-backup-promotion-denied-existing', 8);
  LBlockedSession := BuildManualSession('dir-backup-promotion-denied-blocked', 8);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('backup_promotion_rename_denied_preserves_main_truth');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical directory replay truth before deterministic backup-promotion denial');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Initial acquire should materialize canonical directory replay truth before deterministic backup-promotion denial');

    LScriptedStore := TScriptedBackupPromotionRenameDeniedDirectoryReplayStore.Create(LDirectoryName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Deterministic directory backup-promotion denial should fail closed while preserving canonical main replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Deterministic directory backup-promotion denial should preserve the canonical main directory');
    AssertTrue(not DirectoryExists(LTempDirectoryName),
      'Deterministic directory backup-promotion denial should clean up the temp directory');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Deterministic directory backup-promotion denial should not leave a backup artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Deterministic directory backup-promotion denial should preserve the original replay truth immediately');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after deterministic directory backup-promotion denial should still reject the original replay truth');
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after deterministic directory backup-promotion denial should still accept the fresh blocked session');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Recovery after deterministic directory backup-promotion denial should not leave a backup artifact');

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(not LLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after deterministic directory backup-promotion denial recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnCorruptFallbackDirectoriesAcrossProviderRebuild;
  procedure AssertCorruptFallbackDirectoryFailsClosed(
    const ASuffix: string;
    const AFallbackSuffix: string;
    const AMode: string;
    const ALabel: string
  );
  var
    LDirectoryName: string;
    LFallbackDirectoryName: string;
    LStore1: IFreePascalEarlyDataReplayStore;
    LStore2: IFreePascalEarlyDataReplayStore;
    LProvider1: IFreePascalEarlyDataReplayProvider;
    LProvider2: IFreePascalEarlyDataReplayProvider;
    LLedger1: IFreePascalManagedEarlyDataReplayLedger;
    LLedger2: IFreePascalManagedEarlyDataReplayLedger;
    LExistingSession: ISSLSession;
    LBlockedSession: ISSLSession;
    LReplayKey: string;
  begin
    LExistingSession := BuildManualSession('dirfc-' + ASuffix + '-e', 8);
    LBlockedSession := BuildManualSession('dirfc-' + ASuffix + '-b', 8);
    LReplayKey := ResolveSessionReplayKey(LExistingSession);
    AssertTrue(LReplayKey <> '',
      ALabel + ' should derive a replay key for directory fallback corruption setup');

    LDirectoryName := BuildReplayProviderStoreDirectoryPath('fallback_corrupt_' + ASuffix);
    LFallbackDirectoryName := LDirectoryName + AFallbackSuffix;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
    try
      LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
      LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
      LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
      AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
        ALabel + ' should materialize canonical main directory replay truth before corrupting the fallback path');

      MoveCanonicalReplayStoreDirectoryToFallback(LDirectoryName, AFallbackSuffix, ALabel);
      WriteCorruptDirectoryReplayStoreEntry(LFallbackDirectoryName, LReplayKey, AMode);

      LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
      LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
      LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
      AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
        ALabel + ' should fail closed for a fresh blocked session through the corrupt directory fallback path');
      AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
        ALabel + ' should not mis-restore the original replay truth through the corrupt directory fallback path');
      AssertTrue(not DirectoryExists(LDirectoryName),
        ALabel + ' should keep canonical main directory state absent when the fallback directory is corrupt');
      AssertTrue(DirectoryExists(LFallbackDirectoryName),
        ALabel + ' should preserve the corrupt directory fallback artifact');
    finally
      CleanupReplayProviderStoreDirectory(LDirectoryName);
    end;
  end;
begin
  AssertCorruptFallbackDirectoryFailsClosed(
    'tempdir_invalid_version',
    '.tmpdir',
    'invalid_version',
    'Invalid-version .tmpdir fallback replay directory'
  );
  AssertCorruptFallbackDirectoryFailsClosed(
    'tempdir_trailing_garbage',
    '.tmpdir',
    'trailing_garbage',
    'Trailing-garbage .tmpdir fallback replay directory'
  );
  AssertCorruptFallbackDirectoryFailsClosed(
    'bakdir_invalid_version',
    '.bakdir',
    'invalid_version',
    'Invalid-version .bakdir fallback replay directory'
  );
  AssertCorruptFallbackDirectoryFailsClosed(
    'bakdir_trailing_garbage',
    '.bakdir',
    'trailing_garbage',
    'Trailing-garbage .bakdir fallback replay directory'
  );
end;

procedure TestDirectoryReplayStoreFailsClosedWhenCorruptTempFallbackShadowsHealthyBackupFallback;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LStore3: IFreePascalEarlyDataReplayStore;
  LStore4: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LProvider3: IFreePascalEarlyDataReplayProvider;
  LProvider4: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LLedger4: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LReplayKey: string;
begin
  LExistingSession := BuildManualSession('dirdf-existing', 8);
  LBlockedSession := BuildManualSession('dirdf-blocked', 8);
  LReplayKey := ResolveSessionReplayKey(LExistingSession);
  AssertTrue(LReplayKey <> '',
    'Dual fallback conflict setup should derive a replay key for the existing directory replay truth');

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('dual_fallback_conflict');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Dual fallback conflict setup should first materialize canonical directory replay truth');

    MoveCanonicalReplayStoreDirectoryToFallback(
      LDirectoryName,
      '.bakdir',
      'Dual fallback conflict setup'
    );
    WriteCorruptDirectoryReplayStoreEntry(
      LTempDirectoryName,
      LReplayKey,
      'invalid_version'
    );

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Corrupt preferred directory .tmpdir fallback should fail closed instead of silently falling back to healthy .bakdir for a fresh blocked session');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Corrupt preferred directory .tmpdir fallback should keep the original replay truth fail closed while healthy .bakdir is shadowed');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Corrupt preferred directory .tmpdir fallback should keep canonical directory state absent');
    AssertTrue(DirectoryExists(LTempDirectoryName),
      'Corrupt preferred directory .tmpdir fallback should preserve the corrupt preferred fallback artifact');
    AssertTrue(DirectoryExists(LBackupDirectoryName),
      'Corrupt preferred directory .tmpdir fallback should preserve the healthy shadowed .bakdir artifact');

    RemoveReplayProviderPathTree(LTempDirectoryName);

    LStore3 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider3 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore3);
    LLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider3, True, 8);
    AssertTrue(LLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Removing the corrupt preferred directory .tmpdir fallback should re-open the blocked session through the healthy .bakdir truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovering from a corrupt preferred directory .tmpdir fallback should re-materialize canonical directory state');
    AssertTrue(not DirectoryExists(LBackupDirectoryName),
      'Recovering from a corrupt preferred directory .tmpdir fallback should consume the healthy .bakdir fallback');

    LStore4 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider4 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore4);
    LLedger4 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider4, True, 8);
    AssertTrue(not LLedger4.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after recovering from a corrupt preferred directory .tmpdir fallback should still preserve the original replay truth');
    AssertTrue(not LLedger4.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after recovering from a corrupt preferred directory .tmpdir fallback should still reject the recovered blocked session');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnFilesystemPathBlockersAndRecovers;
var
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LStore1: IFreePascalEarlyDataReplayStore;
  LStore2: IFreePascalEarlyDataReplayStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LSession := BuildManualSession('dirblk-main', 8);
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('main_path_file_blocker');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LDirectoryName);

    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Regular-file canonical main directory path should fail closed');
    AssertTrue(FileExists(LDirectoryName),
      'Regular-file canonical main directory path should preserve the blocker file');
    AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
      'Regular-file canonical main directory path should not materialize a staging .tmpdir');
    AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
      'Regular-file canonical main directory path should not materialize a backup .bakdir');

    RemoveReplayProviderPathIfExists(LDirectoryName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a regular-file canonical main directory blocker should re-open the same session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovered canonical main directory blocker should materialize canonical directory state');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after recovering a regular-file canonical main directory blocker should still reject replay');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LSession := BuildManualSession('dirblk-tmp', 8);
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('tempdir_path_file_blocker');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LTempDirectoryName);

    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Regular-file directory replay-store .tmpdir blocker should fail closed');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Regular-file directory replay-store .tmpdir blocker should not materialize canonical directory state');
    AssertTrue(FileExists(LTempDirectoryName),
      'Regular-file directory replay-store .tmpdir blocker should preserve the blocker file');
    AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
      'Regular-file directory replay-store .tmpdir blocker should not materialize a backup .bakdir');

    RemoveReplayProviderPathIfExists(LTempDirectoryName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a regular-file directory replay-store .tmpdir blocker should re-open the same session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovered directory replay-store .tmpdir blocker should materialize canonical directory state');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after recovering a regular-file directory replay-store .tmpdir blocker should still reject replay');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LSession := BuildManualSession('dirblk-bak', 8);
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('bakdir_path_file_blocker');
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LBackupDirectoryName);

    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Regular-file directory replay-store .bakdir blocker should fail closed on first acquire');
    AssertTrue(not DirectoryExists(LDirectoryName),
      'Regular-file directory replay-store .bakdir blocker should keep canonical directory state absent');
    AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
      'Regular-file directory replay-store .bakdir blocker should not materialize a staging .tmpdir');
    AssertTrue(FileExists(LBackupDirectoryName),
      'Regular-file directory replay-store .bakdir blocker should preserve the blocker file');

    RemoveReplayProviderPathIfExists(LBackupDirectoryName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a regular-file directory replay-store .bakdir blocker should re-open the same session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovered directory replay-store .bakdir blocker should materialize canonical directory state');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after recovering a regular-file directory replay-store .bakdir blocker should still reject replay');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LExistingSession := BuildManualSession('dirblk-tmp-e', 8);
  LBlockedSession := BuildManualSession('dirblk-tmp-b', 8);
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('tempdir_update_file_blocker');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Directory replay-store .tmpdir update blocker test should first materialize canonical replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Directory replay-store .tmpdir update blocker test should materialize canonical directory state before blocking updates');

    TouchFile(LTempDirectoryName);

    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Regular-file directory replay-store .tmpdir blocker should fail closed while updating existing replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Regular-file directory replay-store .tmpdir blocker should preserve canonical directory state on failed update');
    AssertTrue(FileExists(LTempDirectoryName),
      'Regular-file directory replay-store .tmpdir blocker should preserve the blocker file on failed update');
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Regular-file directory replay-store .tmpdir blocker should preserve the original replay truth immediately');

    RemoveReplayProviderPathIfExists(LTempDirectoryName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Removing a regular-file directory replay-store .tmpdir blocker should re-open the blocked session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovered directory replay-store .tmpdir update blocker should keep canonical directory state materialized');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after recovering a directory replay-store .tmpdir blocker should still preserve the original replay truth');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after recovering a directory replay-store .tmpdir blocker should still reject the recovered blocked session');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LExistingSession := BuildManualSession('dirblk-bak-e', 8);
  LBlockedSession := BuildManualSession('dirblk-bak-b', 8);
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('bakdir_update_file_blocker');
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LStore1 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider1 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore1);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Directory replay-store .bakdir update blocker test should first materialize canonical replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Directory replay-store .bakdir update blocker test should materialize canonical directory state before blocking updates');

    TouchFile(LBackupDirectoryName);

    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Regular-file directory replay-store .bakdir blocker should fail closed while updating existing replay truth');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Regular-file directory replay-store .bakdir blocker should preserve canonical directory state on failed update');
    AssertTrue(FileExists(LBackupDirectoryName),
      'Regular-file directory replay-store .bakdir blocker should preserve the blocker file on failed update');
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Regular-file directory replay-store .bakdir blocker should preserve the original replay truth immediately');

    RemoveReplayProviderPathIfExists(LBackupDirectoryName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Removing a regular-file directory replay-store .bakdir blocker should re-open the blocked session acquire');
    AssertTrue(DirectoryExists(LDirectoryName),
      'Recovered directory replay-store .bakdir update blocker should keep canonical directory state materialized');

    LStore2 := TFreePascalDirectoryEarlyDataReplayStore.Create(LDirectoryName);
    LProvider2 := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore2);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after recovering a directory replay-store .bakdir blocker should still preserve the original replay truth');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after recovering a directory replay-store .bakdir blocker should still reject the recovered blocked session');
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedWhileCrossProcessLockIsHeldAtRuntime;
{$IFNDEF UNIX}
begin
  WriteLn('[SKIP] runtime directory replay-store lock contention contract is Unix-only');
end;
{$ELSE}
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LReadyFileName: string;
  LReleaseFileName: string;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LRejectStream: TScriptedEarlyDataClientStream;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_lock_contention');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'ready');
  LReleaseFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'release');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      LSession := CaptureServerIssuedSession(LCtx);

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE);
        LProcess.Parameters.Add(LDirectoryName);
        LProcess.Parameters.Add(LReadyFileName);
        LProcess.Parameters.Add(LReleaseFileName);
        LProcess.Options := [];
        LProcess.Execute;

        AssertTrue(WaitForFileExists(LReadyFileName, 5000),
          'Runtime directory replay-store lock helper should signal when the sidecar lock is held');

        LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('LOCK'), False);
        try
          LConn := LCtx.CreateConnection(LRejectStream);
          AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
            'Runtime directory lock-contention rejected connection should expose early-data interface');
          AssertTrue(LConn.Accept,
            'Runtime directory lock-contention should still complete resumed handshake while failing closed');
          AssertSessionReused(LConn,
            'Runtime directory lock-contention should still reuse the cached session');
          if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
            AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
              'Runtime directory lock-contention should fail closed by rejecting early-data');
          AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
            'Runtime directory lock-contention should suppress accepted early-data signalling while the cross-process lock is held');
          LRead := LConn.Read(LBuf, SizeOf(LBuf));
          AssertEqualsInt(0, LRead,
            'Runtime directory lock-contention should not surface discarded early bytes through Read');
        finally
          LRejectStream.Free;
        end;
        AssertTrue(not DirectoryExists(LDirectoryName),
          'Runtime directory lock-contention should fail closed before materializing canonical directory state');

        TouchFile(LReleaseFileName);
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Runtime directory lock-contention helper should exit cleanly after release');

        LFreshSession := CaptureServerIssuedSession(LCtx);
        LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LFreshSession, BytesOf('OPEN'), True);
        try
          LConn := LCtx.CreateConnection(LAcceptStream);
          AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
            'Runtime directory lock-contention fresh connection should expose early-data interface');
          AssertTrue(LConn.Accept,
            'Runtime directory lock-contention should still accept a fresh resumed early-data attempt after release');
          AssertSessionReused(LConn,
            'Runtime directory lock-contention should still reuse the fresh session after release');
          if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
            AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
              'Runtime directory lock-contention should re-open fresh early-data acceptance after release');
          AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
            'Runtime directory lock-contention should advertise accepted early-data again after release');
        finally
          LAcceptStream.Free;
        end;
        AssertTrue(DirectoryExists(LDirectoryName),
          'Runtime directory lock-contention should materialize canonical directory state again after release');
      finally
        if (LReleaseFileName <> '') and (not FileExists(LReleaseFileName)) then
          TouchFile(LReleaseFileName);
        try
          LProcess.WaitOnExit;
        except
        end;
        LProcess.Free;
      end;
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;
{$ENDIF}

procedure TestDirectoryReplayStoreRetainsReplayTruthAcrossProcessRestartFromOrphanTempDirectory;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LProcess: TProcess;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_orphan_tempdir_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'context_path');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Runtime directory orphan .tmpdir restart test should serialize the captured resumable session');
      WriteBytesToFile(LSessionFileName, LSerialized);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TEMP'),
        'Runtime directory orphan .tmpdir restart test should first materialize canonical replay truth'
      );
      MoveCanonicalReplayStoreDirectoryToFallback(
        LDirectoryName,
        '.tmpdir',
        'Runtime directory orphan .tmpdir restart test'
      );

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
        LProcess.Parameters.Add(LDirectoryName);
        LProcess.Parameters.Add(LSessionFileName);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE);
        LProcess.Parameters.Add(LContextPathMarkerFileName);
        LProcess.Options := [];
        LProcess.Execute;
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Runtime directory orphan .tmpdir replay probe should exit cleanly after rejecting replay in a new process');
        AssertTrue(DirectoryExists(LDirectoryName),
          'Runtime directory orphan .tmpdir replay probe should re-materialize canonical directory state');
        AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
          'Runtime directory orphan .tmpdir replay probe should consume the fallback .tmpdir');
        AssertTrue(FileExists(LContextPathMarkerFileName),
          'Runtime directory orphan .tmpdir replay probe should materialize a context-path marker');
        LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
        AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE), LMarkerBytes),
          'Runtime directory orphan .tmpdir replay probe should record the requested directory-store context path');
      finally
        LProcess.Free;
      end;
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnCorruptFallbackDirectoriesAtRuntime;
  procedure AssertRuntimeCorruptFallbackDirectoryFailsClosed(
    const ASuffix: string;
    const AFallbackSuffix: string;
    const AMode: string;
    const AEarlyData: TBytes;
    const ALabel: string
  );
  var
    LCaptureCtx: ISSLContext;
    LCtx: ISSLContext;
    LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
    LExistingSession: ISSLSession;
    LBlockedSession: ISSLSession;
    LReplayKey: string;
    LDirectoryName: string;
    LFallbackDirectoryName: string;
  begin
    LCaptureCtx := BuildAcceptingEarlyDataServerContext;
    LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
    LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);
    LReplayKey := ResolveSessionReplayKey(LExistingSession);
    AssertTrue(LReplayKey <> '',
      ALabel + ' should derive a replay key for directory fallback corruption runtime setup');

    LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_fallback_corrupt_' + ASuffix);
    LFallbackDirectoryName := LDirectoryName + AFallbackSuffix;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
    try
      LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
      try
        AssertResumedEarlyDataAcceptedAtRuntime(
          LCtx,
          LExistingSession,
          BytesOf('EONE'),
          ALabel + ' should materialize canonical directory replay truth before corrupting the fallback path'
        );
      finally
        if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
          LReplayAccess.ResetEarlyDataReplayLedger;
      end;

      MoveCanonicalReplayStoreDirectoryToFallback(LDirectoryName, AFallbackSuffix, ALabel);
      WriteCorruptDirectoryReplayStoreEntry(LFallbackDirectoryName, LReplayKey, AMode);

      LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
      try
        AssertResumedEarlyDataRejectedAtRuntime(
          LCtx,
          LBlockedSession,
          AEarlyData,
          ALabel + ' through directory runtime path'
        );
        AssertResumedEarlyDataRejectedAtRuntime(
          LCtx,
          LExistingSession,
          BytesOf('EPRV'),
          ALabel + ' should not mis-restore the original replay truth through directory runtime path'
        );
        AssertTrue(not DirectoryExists(LDirectoryName),
          ALabel + ' should keep canonical main directory state absent when runtime falls back to a corrupt directory');
        AssertTrue(DirectoryExists(LFallbackDirectoryName),
          ALabel + ' should preserve the corrupt directory fallback artifact at runtime');
      finally
        if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
          LReplayAccess.ResetEarlyDataReplayLedger;
      end;
    finally
      CleanupReplayProviderStoreDirectory(LDirectoryName);
    end;
  end;
begin
  AssertRuntimeCorruptFallbackDirectoryFailsClosed(
    'tempdir_invalid_version',
    '.tmpdir',
    'invalid_version',
    BytesOf('TIV!'),
    'Invalid-version .tmpdir fallback replay directory'
  );
  AssertRuntimeCorruptFallbackDirectoryFailsClosed(
    'tempdir_trailing_garbage',
    '.tmpdir',
    'trailing_garbage',
    BytesOf('TTG!'),
    'Trailing-garbage .tmpdir fallback replay directory'
  );
  AssertRuntimeCorruptFallbackDirectoryFailsClosed(
    'bakdir_invalid_version',
    '.bakdir',
    'invalid_version',
    BytesOf('BIV!'),
    'Invalid-version .bakdir fallback replay directory'
  );
  AssertRuntimeCorruptFallbackDirectoryFailsClosed(
    'bakdir_trailing_garbage',
    '.bakdir',
    'trailing_garbage',
    BytesOf('BTG!'),
    'Trailing-garbage .bakdir fallback replay directory'
  );
end;

procedure TestDirectoryReplayStoreFailsClosedWhenCorruptTempFallbackShadowsHealthyBackupFallbackAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LReplayKey: string;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);
  LReplayKey := ResolveSessionReplayKey(LExistingSession);
  AssertTrue(LReplayKey <> '',
    'Runtime dual fallback conflict setup should derive a replay key for the existing directory replay truth');

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_dual_fallback_conflict');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('DONE'),
        'Runtime dual fallback conflict setup should first materialize canonical directory replay truth'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    MoveCanonicalReplayStoreDirectoryToFallback(
      LDirectoryName,
      '.bakdir',
      'Runtime dual fallback conflict setup'
    );
    WriteCorruptDirectoryReplayStoreEntry(
      LTempDirectoryName,
      LReplayKey,
      'invalid_version'
    );

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('DFBL'),
        'Corrupt preferred directory .tmpdir fallback should fail closed instead of silently falling back to healthy .bakdir through runtime path'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('DFEX'),
        'Corrupt preferred directory .tmpdir fallback should keep the original runtime replay truth fail closed while healthy .bakdir is shadowed'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Runtime dual fallback conflict should keep canonical directory state absent while corrupt .tmpdir shadows healthy .bakdir');
      AssertTrue(DirectoryExists(LTempDirectoryName),
        'Runtime dual fallback conflict should preserve the corrupt preferred .tmpdir artifact');
      AssertTrue(DirectoryExists(LBackupDirectoryName),
        'Runtime dual fallback conflict should preserve the healthy shadowed .bakdir artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathTree(LTempDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('DFOK'),
        'Removing the corrupt preferred directory .tmpdir fallback should re-open the blocked runtime session through the healthy .bakdir truth'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime recovery from a corrupt preferred directory .tmpdir fallback should re-materialize canonical directory state');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime recovery from a corrupt preferred directory .tmpdir fallback should consume the healthy .bakdir fallback');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('DFR1'),
        'Runtime rebuild after recovering from a corrupt preferred directory .tmpdir fallback should still preserve the original replay truth'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('DFR2'),
        'Runtime rebuild after recovering from a corrupt preferred directory .tmpdir fallback should still reject the recovered blocked session'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnFilesystemPathBlockersAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_main_path_file_blocker');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('MBLK'),
        'Regular-file canonical main directory blocker through directory runtime path'
      );
      AssertTrue(FileExists(LDirectoryName),
        'Regular-file canonical main directory blocker should preserve the blocker file at runtime');
      AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
        'Regular-file canonical main directory blocker should not materialize a staging .tmpdir at runtime');
      AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
        'Regular-file canonical main directory blocker should not materialize a backup .bakdir at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('MOK!'),
        'Recovered canonical main directory blocker through directory runtime path'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovered canonical main directory blocker should materialize canonical directory state at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('MRPY'),
        'Replay truth after recovering a canonical main directory blocker through directory runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_tempdir_path_file_blocker');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LTempDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TBLK'),
        'Regular-file directory replay-store .tmpdir blocker through runtime path'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Regular-file directory replay-store .tmpdir blocker should keep canonical directory state absent at runtime');
      AssertTrue(FileExists(LTempDirectoryName),
        'Regular-file directory replay-store .tmpdir blocker should preserve the blocker file at runtime');
      AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
        'Regular-file directory replay-store .tmpdir blocker should not materialize a backup .bakdir at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LTempDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TOK!'),
        'Recovered directory replay-store .tmpdir blocker through runtime path'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovered directory replay-store .tmpdir blocker should materialize canonical directory state at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TRPY'),
        'Replay truth after recovering a directory replay-store .tmpdir blocker through runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_bakdir_path_file_blocker');
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    TouchFile(LBackupDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('BBLK'),
        'Regular-file directory replay-store .bakdir blocker through runtime path'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Regular-file directory replay-store .bakdir blocker should keep canonical directory state absent at runtime');
      AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
        'Regular-file directory replay-store .bakdir blocker should not materialize a staging .tmpdir at runtime');
      AssertTrue(FileExists(LBackupDirectoryName),
        'Regular-file directory replay-store .bakdir blocker should preserve the blocker file at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LBackupDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('BOK!'),
        'Recovered directory replay-store .bakdir blocker through runtime path'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovered directory replay-store .bakdir blocker should materialize canonical directory state at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('BRPY'),
        'Replay truth after recovering a directory replay-store .bakdir blocker through runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_tempdir_update_file_blocker');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Directory replay-store .tmpdir update blocker runtime test should first materialize canonical replay truth'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    TouchFile(LTempDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TUPD'),
        'Regular-file directory replay-store .tmpdir blocker should fail closed while updating existing runtime replay truth'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('TPRV'),
        'Regular-file directory replay-store .tmpdir blocker should preserve the original runtime replay truth'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Regular-file directory replay-store .tmpdir blocker should preserve canonical directory state at runtime');
      AssertTrue(FileExists(LTempDirectoryName),
        'Regular-file directory replay-store .tmpdir blocker should preserve the blocker file on failed runtime update');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LTempDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TOPN'),
        'Recovered directory replay-store .tmpdir blocker should re-open the blocked runtime session'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovered directory replay-store .tmpdir blocker should keep canonical directory state materialized at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('TER1'),
        'Recovered directory replay-store .tmpdir blocker should still preserve the original runtime replay truth after rebuild'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TER2'),
        'Recovered directory replay-store .tmpdir blocker should still reject the recovered blocked runtime session after rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_bakdir_update_file_blocker');
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('BONE'),
        'Directory replay-store .bakdir update blocker runtime test should first materialize canonical replay truth'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    TouchFile(LBackupDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BUPD'),
        'Regular-file directory replay-store .bakdir blocker should fail closed while updating existing runtime replay truth'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('BPRV'),
        'Regular-file directory replay-store .bakdir blocker should preserve the original runtime replay truth'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Regular-file directory replay-store .bakdir blocker should preserve canonical directory state at runtime');
      AssertTrue(FileExists(LBackupDirectoryName),
        'Regular-file directory replay-store .bakdir blocker should preserve the blocker file on failed runtime update');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LBackupDirectoryName);

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOPN'),
        'Recovered directory replay-store .bakdir blocker should re-open the blocked runtime session'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovered directory replay-store .bakdir blocker should keep canonical directory state materialized at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('BER1'),
        'Recovered directory replay-store .bakdir blocker should still preserve the original runtime replay truth after rebuild'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BER2'),
        'Recovered directory replay-store .bakdir blocker should still reject the recovered blocked runtime session after rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStorePreservesTempDirResidueAcrossRepeatedReplayOnlyRestarts;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;

  procedure RunReplayProbe(const AExpectation: string; const ALabel: string);
  var
    LProcess: TProcess;
  begin
    DeleteFileIfExists(LContextPathMarkerFileName);
    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LDirectoryName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE);
      LProcess.Parameters.Add(LContextPathMarkerFileName);
      LProcess.Parameters.Add(AExpectation);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        ALabel + ' should exit cleanly');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        ALabel + ' should materialize a context-path marker');
      LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
      AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE), LMarkerBytes),
        ALabel + ' should record the requested directory-store context path');
    finally
      LProcess.Free;
    end;
  end;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_orphan_tempdir_residue_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'context_path');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Runtime directory .tmpdir residue restart test should serialize the captured resumable session');
      WriteBytesToFile(LSessionFileName, LSerialized);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('RESI'),
        'Runtime directory .tmpdir residue restart test should first materialize canonical replay truth'
      );
      MoveCanonicalReplayStoreDirectoryToFallback(
        LDirectoryName,
        '.tmpdir',
        'Runtime directory .tmpdir residue restart test'
      );

      RunReplayProbe(
        TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY,
        'First runtime directory .tmpdir residue replay-only probe'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'First runtime directory .tmpdir residue replay-only probe should keep canonical directory state absent');
      AssertTrue(DirectoryExists(LDirectoryName + '.tmpdir'),
        'First runtime directory .tmpdir residue replay-only probe should preserve the live fallback .tmpdir');

      RunReplayProbe(
        TEST_REPLAY_PROVIDER_EXPECT_REJECT_ONLY,
        'Second runtime directory .tmpdir residue replay-only probe'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Second runtime directory .tmpdir residue replay-only probe should still keep canonical directory state absent');
      AssertTrue(DirectoryExists(LDirectoryName + '.tmpdir'),
        'Second runtime directory .tmpdir residue replay-only probe should still preserve the live fallback .tmpdir');

      RunReplayProbe(
        TEST_REPLAY_PROVIDER_EXPECT_REJECT,
        'Recovery runtime directory .tmpdir residue replay probe'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Recovery runtime directory .tmpdir residue replay probe should re-materialize canonical directory state');
      AssertTrue(not DirectoryExists(LDirectoryName + '.tmpdir'),
        'Recovery runtime directory .tmpdir residue replay probe should consume the fallback .tmpdir');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreRetainsReplayTruthAcrossProcessRestartFromBackupDirectory;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LProcess: TProcess;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_backupdir_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'context_path');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Runtime directory .bakdir restart test should serialize the captured resumable session');
      WriteBytesToFile(LSessionFileName, LSerialized);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('BAK1'),
        'Runtime directory .bakdir restart test should first materialize canonical replay truth'
      );
      MoveCanonicalReplayStoreDirectoryToFallback(
        LDirectoryName,
        '.bakdir',
        'Runtime directory .bakdir restart test'
      );

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
        LProcess.Parameters.Add(LDirectoryName);
        LProcess.Parameters.Add(LSessionFileName);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE);
        LProcess.Parameters.Add(LContextPathMarkerFileName);
        LProcess.Options := [];
        LProcess.Execute;
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Runtime directory .bakdir replay probe should exit cleanly after rejecting replay in a new process');
        AssertTrue(DirectoryExists(LDirectoryName),
          'Runtime directory .bakdir replay probe should re-materialize canonical directory state');
        AssertTrue(not DirectoryExists(LDirectoryName + '.bakdir'),
          'Runtime directory .bakdir replay probe should consume the fallback .bakdir');
        AssertTrue(FileExists(LContextPathMarkerFileName),
          'Runtime directory .bakdir replay probe should materialize a context-path marker');
        LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
        AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE), LMarkerBytes),
          'Runtime directory .bakdir replay probe should record the requested directory-store context path');
      finally
        LProcess.Free;
      end;
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackupAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LResidueSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LResidueSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_bakdir_cleanup_delete_failure_residue');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted .bakdir cleanup failure'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted .bakdir cleanup failure');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupCleanupDeleteFailureDirectoryReplayStore.Create(LDirectoryName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted directory store for .bakdir cleanup delete-failure runtime validation');
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RONE'),
        'Directory .bakdir cleanup failure through the store-backed runtime path should still accept early-data after canonical main replacement succeeds'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime directory .bakdir cleanup failure should keep canonical directory replay truth after the successful replacement');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Runtime directory .bakdir cleanup failure should still clean up the temp directory after the successful replacement');
      AssertTrue(DirectoryExists(LBackupDirectoryName),
        'Runtime directory .bakdir cleanup failure should leave a stale backup artifact when cleanup delete fails');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime directory .bakdir cleanup failure should preserve the original replay truth immediately'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RPRV'),
        'Runtime directory .bakdir cleanup failure should persist the fresh accepted replay truth through the canonical main directory'
      );

      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Undeletable stale directory .bakdir residue on the next runtime save should fail closed'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Undeletable stale directory .bakdir residue on the next runtime save should preserve canonical directory replay truth');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Undeletable stale directory .bakdir residue on the next runtime save should not leave a temp directory behind');
      AssertTrue(DirectoryExists(LBackupDirectoryName),
        'Undeletable stale directory .bakdir residue on the next runtime save should preserve the stale backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Runtime rebuild after stale directory .bakdir residue should still reject the original replay truth'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RAGN'),
        'Runtime rebuild after stale directory .bakdir residue should still reject the fresh replay truth materialized before the cleanup failure'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Runtime rebuild after stale directory .bakdir residue should still accept the blocked session once stale backup cleanup succeeds'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Fresh runtime acquire after stale directory .bakdir residue should keep canonical directory replay truth materialized');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Successful runtime recovery after stale directory .bakdir residue should consume the backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after stale directory .bakdir residue recovery should still replay-reject after runtime rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStorePreservesExistingTruthAcrossBackupAssistedReplaceFailureAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_backup_assisted_replace_failure_truth_preservation');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted backup-assisted replace failure'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted backup-assisted replace failure');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedExistingMainReplaceFailureDirectoryReplayStore.Create(LDirectoryName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted directory store for backup-assisted replace runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Backup-assisted directory replace failure through store-backed runtime path should reject early-data without losing old truth'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime backup-assisted directory replace failure should preserve the canonical main directory');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Runtime backup-assisted directory replace failure should clean up the temp directory');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime backup-assisted directory replace failure should not leave a backup artifact after restoring old truth');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime backup-assisted directory replace failure should preserve the original replay truth immediately'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Runtime rebuild after backup-assisted directory replace failure should still reject the original replay truth'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Runtime rebuild after backup-assisted directory replace failure should still accept the fresh blocked session'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after directory replace recovery should still replay-reject after runtime rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreRecoversReplayTruthFromBackupAfterRestoreFailureAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_backup_restore_failure_recovery');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted backup restore failure'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Initial runtime acquire should materialize canonical directory replay truth before scripted backup restore failure');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupRestoreFailureDirectoryReplayStore.Create(LDirectoryName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted directory store for backup restore failure runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Directory backup restore failure through store-backed runtime path should reject early-data without dropping old truth'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Runtime directory backup restore failure should leave the canonical main directory missing after restore fails');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Runtime directory backup restore failure should clean up the temp directory');
      AssertTrue(DirectoryExists(LBackupDirectoryName),
        'Runtime directory backup restore failure should preserve the backup directory artifact');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime directory backup restore failure should still reject the original replay truth through the backup artifact'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Runtime rebuild after directory backup restore failure should still reject the original replay truth'
      );
      AssertTrue(DirectoryExists(LBackupDirectoryName),
        'Runtime replay rejection after directory backup restore failure should not consume the backup artifact');
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Runtime rebuild after directory backup restore failure should still accept the fresh blocked session'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime recovery after directory backup restore failure should materialize the canonical main directory again');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime recovery after directory backup restore failure should consume the backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after runtime directory backup restore recovery should still replay-reject after rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnDeterministicTempPromotionRenameDeniedAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_temp_promotion_rename_denied_failclosed');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedTempPromotionRenameDeniedDirectoryReplayStore.Create(LDirectoryName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted directory store for deterministic temp-promotion rename denial runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Deterministic directory temp-promotion rename denial through the store-backed runtime path should reject early-data'
      );
      AssertTrue(not DirectoryExists(LDirectoryName),
        'Runtime deterministic directory temp-promotion rename denial should keep the canonical main directory absent');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Runtime deterministic directory temp-promotion rename denial should clean up the temp directory');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime deterministic directory temp-promotion rename denial should not create a backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Runtime rebuild after deterministic directory temp-promotion rename denial should still accept the blocked session'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime recovery after deterministic directory temp-promotion rename denial should materialize the canonical main directory');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime recovery after deterministic directory temp-promotion rename denial should not leave a backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after deterministic directory temp-promotion rename denial recovery should still replay-reject after runtime rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestDirectoryReplayStoreFailsClosedOnDeterministicBackupPromotionRenameDeniedAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LDirectoryName: string;
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_backup_promotion_rename_denied_preserves_main_truth');
  LTempDirectoryName := LDirectoryName + '.tmpdir';
  LBackupDirectoryName := LDirectoryName + '.bakdir';
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical directory replay truth before deterministic backup-promotion denial'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Initial runtime acquire should materialize canonical directory replay truth before deterministic backup-promotion denial');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupPromotionRenameDeniedDirectoryReplayStore.Create(LDirectoryName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted directory store for deterministic backup-promotion denial runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Deterministic directory backup-promotion denial through the store-backed runtime path should reject early-data without losing old truth'
      );
      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime deterministic directory backup-promotion denial should preserve the canonical main directory');
      AssertTrue(not DirectoryExists(LTempDirectoryName),
        'Runtime deterministic directory backup-promotion denial should clean up the temp directory');
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime deterministic directory backup-promotion denial should not leave a backup artifact');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime deterministic directory backup-promotion denial should preserve the original replay truth immediately'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Runtime rebuild after deterministic directory backup-promotion denial should still reject the original replay truth'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Runtime rebuild after deterministic directory backup-promotion denial should still accept the fresh blocked session'
      );
      AssertTrue(not DirectoryExists(LBackupDirectoryName),
        'Runtime recovery after deterministic directory backup-promotion denial should not leave a backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after deterministic directory backup-promotion denial recovery should still replay-reject after runtime rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestCallbackReplayProviderPreservesReplayTruthAcrossProviderRebuild;
var
  LStore: TSharedReplayProviderStore;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LValidSession: ISSLSession;
  LExpiredSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LStore := TSharedReplayProviderStore.Create;
  try
    LProvider1 := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    LValidSession := BuildManualSession('callback-provider-rebuild-valid', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LValidSession),
      'First callback-backed provider instance should accept first acquire for a fresh valid session');

    LProvider2 := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LValidSession),
      'Rebuilt callback-backed provider should preserve shared replay truth and reject replay');

    LExpiredSession := BuildManualSessionWithTiming(
      'callback-provider-rebuild-expired',
      8,
      1,
      IncSecond(Now, -10),
      7200
    );
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExpiredSession),
      'Expired session should still be rejected before entering rebuilt callback-backed provider state');

    LFreshSession := BuildManualSession('callback-provider-rebuild-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Rebuilt callback-backed provider should still accept fresh valid sessions after replay rejection');
  finally
    LStore.Free;
  end;
end;

procedure TestCallbackReplayProviderLifecycleDoesNotWipeSharedTruth;
var
  LStore: TSharedReplayProviderStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LDisableSession: ISSLSession;
  LCapacitySession: ISSLSession;
  LDisabledFreshSession: ISSLSession;
  LZeroCapacityFreshSession: ISSLSession;
  LRestoredFreshSession: ISSLSession;
begin
  LStore := TSharedReplayProviderStore.Create;
  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);

    LDisableSession := BuildManualSession('callback-provider-lifecycle-disable', 8);
    LCapacitySession := BuildManualSession('callback-provider-lifecycle-capacity', 8);
    LDisabledFreshSession := BuildManualSession('callback-provider-lifecycle-disabled-fresh', 8);
    LZeroCapacityFreshSession := BuildManualSession('callback-provider-lifecycle-zero-capacity-fresh', 8);
    LRestoredFreshSession := BuildManualSession('callback-provider-lifecycle-restored-fresh', 8);

    AssertTrue(LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'Callback-backed provider should accept the first valid session acquire before lifecycle toggles');

    LLedger.SetEnabled(False);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisabledFreshSession),
      'Disabled callback-backed ledger should reject acquires via the local enabled gate');

    LLedger.SetEnabled(True);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'Re-enabled callback-backed ledger should retain shared replay truth and reject prior replay');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LCapacitySession),
      'Re-enabled callback-backed ledger should still accept a fresh session after replay retention');

    LLedger.SetCapacity(0);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LZeroCapacityFreshSession),
      'Zero-capacity callback-backed ledger should reject acquires via the local capacity gate');

    LLedger.SetCapacity(8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'Restored callback-backed capacity should not wipe replay truth learned before disable/reenable');
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LCapacitySession),
      'Restored callback-backed capacity should not wipe replay truth learned before capacity zeroing');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LRestoredFreshSession),
      'Restored callback-backed capacity should re-open the local gate for fresh sessions');
  finally
    LStore.Free;
  end;
end;

procedure TestFileBackedReplayProviderPersistsAcrossProviderRebuild;
var
  LFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LValidSession: ISSLSession;
  LExpiredSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LFileName := BuildReplayProviderStoreFilePath('direct');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);

    LValidSession := BuildManualSession('file-provider-valid', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LValidSession),
      'File-backed provider should accept first acquire for a fresh valid session');
    AssertTrue(FileExists(LFileName),
      'File-backed provider should persist replay state after first acquire');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LValidSession),
      'File-backed provider should reject replay after provider and ledger rebuild');

    LExpiredSession := BuildManualSessionWithTiming(
      'file-provider-expired',
      8,
      1,
      IncSecond(Now, -10),
      7200
    );
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExpiredSession),
      'Expired session should be rejected before entering file-backed provider state');

    LFreshSession := BuildManualSession('file-provider-fresh', 8);
    AssertTrue(LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Expired file-backed replay attempts must not pollute fresh valid sessions');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderLifecycleDoesNotWipePersistedTruth;
var
  LFileName: string;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LDisableSession: ISSLSession;
  LCapacitySession: ISSLSession;
  LDisabledFreshSession: ISSLSession;
  LZeroCapacityFreshSession: ISSLSession;
  LRestoredFreshSession: ISSLSession;
begin
  LFileName := BuildReplayProviderStoreFilePath('lifecycle_persistence');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);

    LDisableSession := BuildManualSession('file-provider-lifecycle-disable', 8);
    LCapacitySession := BuildManualSession('file-provider-lifecycle-capacity', 8);
    LDisabledFreshSession := BuildManualSession('file-provider-lifecycle-disabled-fresh', 8);
    LZeroCapacityFreshSession := BuildManualSession('file-provider-lifecycle-zero-capacity-fresh', 8);
    LRestoredFreshSession := BuildManualSession('file-provider-lifecycle-restored-fresh', 8);

    AssertTrue(LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'File-backed provider should accept the first valid session acquire before lifecycle toggles');
    AssertTrue(FileExists(LFileName),
      'File-backed provider should persist replay truth before lifecycle toggles are exercised');

    LLedger.SetEnabled(False);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisabledFreshSession),
      'Disabled file-backed ledger should reject acquires via the local enabled gate');

    LLedger.SetEnabled(True);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'Re-enabled file-backed ledger should retain persisted replay truth and reject prior replay');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LCapacitySession),
      'Re-enabled file-backed ledger should still accept a fresh session after replay retention');

    LLedger.SetCapacity(0);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LZeroCapacityFreshSession),
      'Zero-capacity file-backed ledger should reject acquires via the local capacity gate');

    LLedger.SetCapacity(8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisableSession),
      'Restored file-backed capacity should not wipe replay truth learned before disable/reenable');
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LCapacitySession),
      'Restored file-backed capacity should not wipe replay truth learned before capacity zeroing');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LRestoredFreshSession),
      'Restored file-backed capacity should re-open the local gate for fresh sessions');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestManagedReplayProviderHookExceptionsStaySwallowedAndLocalGatesAuthoritative;
var
  LExplodingProviderImpl: TExplodingManagedReplayProvider;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LClearCallsBeforeDisable: Integer;
  LSetCapacityCallsBeforeZero: Integer;
  LSetCapacityCallsBeforeRestore: Integer;
  LInitialSession: ISSLSession;
  LDisabledSession: ISSLSession;
  LReenabledSession: ISSLSession;
  LZeroCapacitySession: ISSLSession;
  LRestoredCapacitySession: ISSLSession;
begin
  LExplodingProviderImpl := TExplodingManagedReplayProvider.Create;
  LProvider := LExplodingProviderImpl;
  LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);

  LInitialSession := BuildManualSession('managed-hook-swallow-initial', 8);
  LDisabledSession := BuildManualSession('managed-hook-swallow-disabled', 8);
  LReenabledSession := BuildManualSession('managed-hook-swallow-reenabled', 8);
  LZeroCapacitySession := BuildManualSession('managed-hook-swallow-zero-capacity', 8);
  LRestoredCapacitySession := BuildManualSession('managed-hook-swallow-restored-capacity', 8);

  AssertTrue(LLedger.TryAcquireEarlyDataSession(LInitialSession),
    'Exploding managed-hook provider should still be reachable through normal acquires');
  AssertEqualsInt(1, LExplodingProviderImpl.AcquireCalls,
    'Initial managed-hook provider acquire should reach the provider once');

  LClearCallsBeforeDisable := LExplodingProviderImpl.ClearCalls;
  try
    LLedger.SetEnabled(False);
  except
    on E: Exception do
      Fail('Managed replay provider Clear exception should stay swallowed across SetEnabled(False): ' + E.Message);
  end;
  AssertEqualsInt(LClearCallsBeforeDisable + 1, LExplodingProviderImpl.ClearCalls,
    'SetEnabled(False) should still attempt the managed Clear hook exactly once');
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisabledSession),
    'Disabled managed-hook ledger should reject acquires via the local enabled gate');
  AssertEqualsInt(1, LExplodingProviderImpl.AcquireCalls,
    'Disabled managed-hook ledger should reject before consulting the provider');

  try
    LLedger.SetEnabled(True);
  except
    on E: Exception do
      Fail('Managed replay provider Clear exception should stay swallowed across SetEnabled(True): ' + E.Message);
  end;
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LReenabledSession),
    'Re-enabled managed-hook ledger should consult the provider again after the local gate is restored');
  AssertEqualsInt(2, LExplodingProviderImpl.AcquireCalls,
    'Re-enabled managed-hook ledger should resume provider calls after the local gate is restored');

  LSetCapacityCallsBeforeZero := LExplodingProviderImpl.SetCapacityCalls;
  try
    LLedger.SetCapacity(0);
  except
    on E: Exception do
      Fail('Managed replay provider SetCapacity exception should stay swallowed across SetCapacity(0): ' + E.Message);
  end;
  AssertEqualsInt(LSetCapacityCallsBeforeZero + 1, LExplodingProviderImpl.SetCapacityCalls,
    'Managed SetCapacity hook should still be attempted when capacity is forced to zero');
  AssertTrue(not LLedger.TryAcquireEarlyDataSession(LZeroCapacitySession),
    'Zero-capacity managed-hook ledger should reject acquires via the local capacity gate');
  AssertEqualsInt(2, LExplodingProviderImpl.AcquireCalls,
    'Zero-capacity managed-hook ledger should reject before consulting the provider');

  LSetCapacityCallsBeforeRestore := LExplodingProviderImpl.SetCapacityCalls;
  try
    LLedger.SetCapacity(8);
  except
    on E: Exception do
      Fail('Managed replay provider SetCapacity exception should stay swallowed across SetCapacity(8): ' + E.Message);
  end;
  AssertEqualsInt(LSetCapacityCallsBeforeRestore + 1, LExplodingProviderImpl.SetCapacityCalls,
    'Managed SetCapacity hook should still be attempted when capacity is restored');
  AssertEqualsInt(8, LExplodingProviderImpl.LastCapacity,
    'Managed SetCapacity hook should still observe the restored capacity value');
  AssertTrue(LLedger.TryAcquireEarlyDataSession(LRestoredCapacitySession),
    'Restored managed-hook capacity should re-open the local gate for provider acquires');
  AssertEqualsInt(3, LExplodingProviderImpl.AcquireCalls,
    'Restored managed-hook capacity should resume provider calls after the local gate is restored');
end;

procedure TestFileBackedReplayProviderRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'File-backed replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam');

  LFileName := BuildReplayProviderStoreFilePath('cross_context');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    LReplayAccess1.SetEarlyDataReplayLedger(LLedger1);
    LReplayAccess2.SetEarlyDataReplayLedger(LLedger2);

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'File-backed accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'File-backed provider should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'First resumed early-data attempt should remain accepted with file-backed replay state');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'First resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'File-backed replay-rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'File-backed replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'File-backed replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'File-backed replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'File-backed cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'File-backed cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedOnCorruptStores;
var
  LFileName: string;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-corrupt', 8);

  LFileName := BuildReplayProviderStoreFilePath('invalid_version');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LFileName,
      TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      0
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Invalid-version replay store should fail closed instead of accepting early-data replay state');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('truncated');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderTruncatedStoreFile(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      ResolveSessionReplayKey(LSession)
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Truncated replay store should fail closed instead of accepting early-data replay state');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('invalid_count');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_ENTRY_COUNT
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Oversize replay-store entry count should fail closed');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('invalid_key_length');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderInvalidKeyLengthStoreFile(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_KEY_LENGTH
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Oversize replay-store key length should fail closed');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedWhileCrossProcessLockIsHeld;
{$IFNDEF UNIX}
begin
  WriteLn('[SKIP] cross-process replay-store lock contention contract is Unix-only');
end;
{$ELSE}
var
  LFileName: string;
  LReadyFileName: string;
  LReleaseFileName: string;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LProcess: TProcess;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-cross-process-lock-held', 8);
  LFreshSession := BuildManualSession('file-provider-cross-process-after-release', 8);

  LFileName := BuildReplayProviderStoreFilePath('cross_process_lock_held');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LFileName, 'ready');
  LReleaseFileName := BuildReplayProviderMarkerFilePath(LFileName, 'release');
  CleanupReplayProviderStoreFiles(LFileName);

  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := ParamStr(0);
    LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE);
    LProcess.Parameters.Add(LFileName);
    LProcess.Parameters.Add(LReadyFileName);
    LProcess.Parameters.Add(LReleaseFileName);
    LProcess.Options := [];
    LProcess.Execute;

    AssertTrue(WaitForFileExists(LReadyFileName, 5000),
      'Cross-process replay-provider helper should signal when the sidecar lock is held');

    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Active cross-process replay-store lock should fail closed instead of accepting early-data replay state');

    TouchFile(LReleaseFileName);
    LProcess.WaitOnExit;
    AssertEqualsInt(0, LProcess.ExitCode,
      'Cross-process replay-provider lock-holder helper should exit cleanly after release');

    AssertTrue(LLedger.TryAcquireEarlyDataSession(LFreshSession),
      'Fresh acquire should succeed again after the cross-process replay-store lock is released');
  finally
    if (LReleaseFileName <> '') and (not FileExists(LReleaseFileName)) then
      TouchFile(LReleaseFileName);
    try
      LProcess.WaitOnExit;
    except
    end;
    LProcess.Free;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;
{$ENDIF}

procedure TestFileBackedReplayProviderIgnoresOrphanLockFileWithoutActiveLock;
var
  LFileName: string;
  LLockFileName: string;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-orphan-lock-file', 8);

  LFileName := BuildReplayProviderStoreFilePath('orphan_lock_file');
  LLockFileName := BuildReplayProviderLockFilePath(LFileName);
  CleanupReplayProviderStoreFiles(LFileName);
  try
    TouchFile(LLockFileName);

    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Orphan replay-store lock file without an active holder should not block a fresh acquire');
    AssertTrue(FileExists(LFileName),
      'Fresh acquire after orphan replay-store lock file should still materialize canonical main store file');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderRecoversReplayTruthFromOrphanTempStore;
var
  LFileName: string;
  LTempFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
  LReplayKey: string;
begin
  LSession := BuildManualSession('file-provider-orphan-temp-live', 8);
  LReplayKey := ResolveSessionReplayKey(LSession);
  AssertTrue(LReplayKey <> '',
    'Replay key helper should derive a ticket-based key for orphan temp recovery tests');

  LFileName := BuildReplayProviderStoreFilePath('orphan_temp_live');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreSingleEntry(
      LTempFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      LReplayKey,
      IncSecond(Now, 30)
    );
    AssertTrue(not FileExists(LFileName),
      'Canonical replay-store file should stay absent for orphan temp recovery test setup');

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Orphan temp replay store should still reject replay when canonical main file is missing');

    LFreshSession := BuildManualSession('file-provider-orphan-temp-fresh', 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LFreshSession),
      'Fresh session should still be acquirable after orphan temp replay recovery');
    AssertTrue(FileExists(LFileName),
      'Fresh acquire after orphan temp replay recovery should materialize canonical main replay store file');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LFreshSession),
      'Replay state saved after orphan temp recovery should still reject replay after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedOnCorruptOrphanTempStores;
var
  LFileName: string;
  LTempFileName: string;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-corrupt-orphan-temp', 8);

  LFileName := BuildReplayProviderStoreFilePath('orphan_temp_invalid_version');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LTempFileName,
      TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      0
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Invalid-version orphan temp replay store should fail closed instead of being ignored');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('orphan_temp_truncated');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderTruncatedStoreFile(
      LTempFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      ResolveSessionReplayKey(LSession)
    );
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider, True, 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Truncated orphan temp replay store should fail closed instead of being ignored');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedOnCorruptBackupFallbackStores;
  procedure AssertCorruptBackupFallbackFailsClosed(
    const ASuffix: string;
    const AMode: string;
    const ALabel: string
  );
  var
    LFileName: string;
    LTempFileName: string;
    LBackupFileName: string;
    LProvider1: IFreePascalEarlyDataReplayProvider;
    LProvider2: IFreePascalEarlyDataReplayProvider;
    LLedger1: IFreePascalManagedEarlyDataReplayLedger;
    LLedger2: IFreePascalManagedEarlyDataReplayLedger;
    LExistingSession: ISSLSession;
    LBlockedSession: ISSLSession;
    LReplayKey: string;
  begin
    LExistingSession := BuildManualSession('file-provider-corrupt-backup-' + ASuffix + '-existing', 8);
    LBlockedSession := BuildManualSession('file-provider-corrupt-backup-' + ASuffix + '-blocked', 8);
    LReplayKey := ResolveSessionReplayKey(LExistingSession);
    AssertTrue(LReplayKey <> '',
      ALabel + ' should derive a replay key for backup fallback corruption setup');

    LFileName := BuildReplayProviderStoreFilePath('backup_fallback_' + ASuffix);
    LTempFileName := LFileName + '.tmp';
    LBackupFileName := LFileName + '.bak';
    CleanupReplayProviderStoreFiles(LFileName);
    try
      LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
      LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
      AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
        ALabel + ' should materialize canonical main replay truth before corrupting the backup fallback path');

      MoveCanonicalReplayStoreToBackupFallback(LFileName, ALabel);
      WriteCorruptReplayProviderBackupFallbackStore(LBackupFileName, LReplayKey, AMode);

      LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
      LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
      AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
        ALabel + ' should fail closed for a fresh blocked session through the corrupt .bak fallback path');
      AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
        ALabel + ' should not mis-restore the original replay truth through the corrupt .bak fallback path');
      AssertTrue(not FileExists(LFileName),
        ALabel + ' should keep canonical main replay-store file absent when .bak fallback is corrupt');
      AssertTrue(not FileExists(LTempFileName),
        ALabel + ' should not leave a temp replay-store file behind when .bak fallback is corrupt');
      AssertTrue(FileExists(LBackupFileName),
        ALabel + ' should preserve the corrupt .bak fallback artifact');
    finally
      CleanupReplayProviderStoreFiles(LFileName);
    end;
  end;
begin
  AssertCorruptBackupFallbackFailsClosed(
    'invalid_version',
    'invalid_version',
    'Invalid-version .bak fallback replay store'
  );
  AssertCorruptBackupFallbackFailsClosed(
    'truncated',
    'truncated',
    'Truncated .bak fallback replay store'
  );
  AssertCorruptBackupFallbackFailsClosed(
    'invalid_count',
    'invalid_count',
    'Oversize entry-count .bak fallback replay store'
  );
  AssertCorruptBackupFallbackFailsClosed(
    'invalid_key_length',
    'invalid_key_length',
    'Oversize key-length .bak fallback replay store'
  );
  AssertCorruptBackupFallbackFailsClosed(
    'trailing_garbage',
    'trailing_garbage',
    'Trailing-garbage .bak fallback replay store'
  );
end;

procedure TestFileBackedReplayProviderFailsClosedOnFilesystemPathBlockersAndRecovers;
var
  LFileName: string;
  LTempFileName: string;
  LLockFileName: string;
  LBlockedParentPath: string;
  LNestedFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-lock-path-directory-blocker', 8);
  LFileName := BuildReplayProviderStoreFilePath('lock_path_directory_blocker');
  LLockFileName := BuildReplayProviderLockFilePath(LFileName);
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LLockFileName);
  try
    AssertTrue(ForceDirectories(LLockFileName),
      'Directory-occupied replay-store lock path test should create the blocker directory');

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory-occupied replay-store lock path should fail closed');
    AssertTrue(not FileExists(LFileName),
      'Directory-occupied replay-store lock path should not materialize canonical main store file');

    RemoveReplayProviderPathIfExists(LLockFileName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a directory-occupied replay-store lock path should re-open the same session acquire');
    AssertTrue(FileExists(LFileName),
      'Removing a directory-occupied replay-store lock path should materialize canonical main store file');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after removing a directory-occupied lock path should still reject replay');
  finally
    RemoveReplayProviderPathIfExists(LLockFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LSession := BuildManualSession('file-provider-temp-path-directory-blocker', 8);
  LFileName := BuildReplayProviderStoreFilePath('temp_path_directory_blocker');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LTempFileName);
  try
    AssertTrue(ForceDirectories(LTempFileName),
      'Directory-occupied replay-store temp path test should create the blocker directory');

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory-occupied replay-store temp path should fail closed');
    AssertTrue(not FileExists(LFileName),
      'Directory-occupied replay-store temp path should not materialize canonical main store file');

    RemoveReplayProviderPathIfExists(LTempFileName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a directory-occupied replay-store temp path should re-open the same session acquire');
    AssertTrue(FileExists(LFileName),
      'Removing a directory-occupied replay-store temp path should materialize canonical main store file');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after removing a directory-occupied temp path should still reject replay');
  finally
    RemoveReplayProviderPathIfExists(LTempFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LSession := BuildManualSession('file-provider-parent-path-file-blocker', 8);
  LBlockedParentPath := BuildReplayProviderStoreFilePath('parent_path_file_blocker');
  LNestedFileName := IncludeTrailingPathDelimiter(LBlockedParentPath) + 'store.bin';
  CleanupReplayProviderStoreFiles(LNestedFileName);
  RemoveReplayProviderPathIfExists(LBlockedParentPath);
  try
    TouchFile(LBlockedParentPath);

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LNestedFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Replay-store parent path occupied by a file should fail closed');
    AssertTrue(not FileExists(LNestedFileName),
      'Replay-store parent path occupied by a file should not materialize canonical main store file');

    RemoveReplayProviderPathIfExists(LBlockedParentPath);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a file-occupied replay-store parent path should re-open the same session acquire');
    AssertTrue(FileExists(LNestedFileName),
      'Removing a file-occupied replay-store parent path should materialize canonical main store file');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LNestedFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after removing a file-occupied parent path should still reject replay');
  finally
    CleanupReplayProviderStoreFiles(LNestedFileName);
    RemoveReplayProviderPathIfExists(LBlockedParentPath);
  end;
end;

procedure TestFileBackedReplayProviderPreservesExistingReplayTruthAcrossTempPathWriteFailureAndRecovers;
var
  LFileName: string;
  LTempFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LExpectedBytes: TBytes;
begin
  LExistingSession := BuildManualSession('file-provider-temp-write-preserve-existing', 8);
  LBlockedSession := BuildManualSession('file-provider-temp-write-blocked-fresh', 8);

  LFileName := BuildReplayProviderStoreFilePath('temp_write_failure_preserves_existing_truth');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LTempFileName);
  try
    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay store file before temp-path write failure');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay store file before temp-path write failure');
    LExpectedBytes := ReadBytesFromFile(LFileName);

    AssertTrue(ForceDirectories(LTempFileName),
      'Temp-path write failure preservation test should create the temp-path blocker directory');

    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Directory-occupied replay-store temp path should fail closed while preserving existing replay truth');
    AssertTrue(FileExists(LFileName),
      'Directory-occupied replay-store temp path should preserve the existing canonical main replay store file');
    AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
      'Directory-occupied replay-store temp path should keep canonical main replay-store bytes unchanged on failed update');

    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Existing replay truth should still reject replay after a temp-path write failure');

    RemoveReplayProviderPathIfExists(LTempFileName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LBlockedSession),
      'Removing a directory-occupied replay-store temp path should re-open the blocked session acquire');
    AssertTrue(FileExists(LFileName),
      'Recovered temp-path write failure should keep the canonical main replay store file materialized');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Replay truth materialized after recovering a temp-path write failure should still reject replay after provider rebuild');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Recovered temp-path write failure should still preserve the original replay truth after provider rebuild');
  finally
    RemoveReplayProviderPathIfExists(LTempFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedOnCanonicalMainPathRenameBoundaryAndRecovers;
var
  LFileName: string;
  LTempFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('file-provider-main-path-rename-boundary', 8);

  LFileName := BuildReplayProviderStoreFilePath('canonical_main_path_rename_boundary');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LFileName);
  try
    AssertTrue(ForceDirectories(LFileName),
      'Canonical main-path rename-boundary test should create the blocker directory');

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(not LLedger1.TryAcquireEarlyDataSession(LSession),
      'Directory-occupied canonical replay-store path should fail closed at the temp-to-main rename boundary');
    AssertTrue(DirectoryExists(LFileName),
      'Directory-occupied canonical replay-store path should stay blocked after a rename-boundary failure');
    AssertTrue(not FileExists(LTempFileName),
      'Canonical main-path rename-boundary failure should clean up the temporary replay-store file');

    RemoveReplayProviderPathIfExists(LFileName);

    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Removing a directory-occupied canonical replay-store path should re-open the same session acquire');
    AssertTrue(FileExists(LFileName),
      'Recovered canonical main-path rename boundary should materialize the canonical replay-store file');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Replay truth materialized after recovering a canonical main-path rename boundary should still reject replay');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
    RemoveReplayProviderPathIfExists(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderPreservesExistingTruthAcrossExistingMainReplaceFallbackFailure;
var
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LNormalProvider3: IFreePascalEarlyDataReplayProvider;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LExpectedBytes: TBytes;
begin
  LExistingSession := BuildManualSession('file-provider-existing-main-preserved', 8);
  LBlockedSession := BuildManualSession('file-provider-existing-main-blocked', 8);

  LFileName := BuildReplayProviderStoreFilePath('existing_main_replace_fallback_truth_preservation');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LNormalProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay truth before scripted existing-main replace failure');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay-store file before scripted existing-main replace failure');
    LExpectedBytes := ReadBytesFromFile(LFileName);

    LScriptedStore := TScriptedExistingMainReplaceFailureReplayStore.Create(LFileName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Existing-main replace fallback failure should fail closed while preserving canonical replay truth');
    AssertTrue(FileExists(LFileName),
      'Existing-main replace fallback failure should preserve the canonical replay-store file');
    AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
      'Existing-main replace fallback failure should keep canonical replay-store bytes unchanged');
    AssertTrue(not FileExists(LTempFileName),
      'Existing-main replace fallback failure should clean up the temp replay-store file');
    AssertTrue(not FileExists(LBackupFileName),
      'Existing-main replace fallback failure should restore the old replay truth without leaving a backup artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Existing-main replace fallback failure should preserve the original replay truth immediately');

    LNormalProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after existing-main replace fallback failure should still reject the original replay truth');
    AssertTrue(LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after existing-main replace fallback failure should still accept the fresh blocked session');

    LNormalProvider3 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider3, True, 8);
    AssertTrue(not LNormalLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderRecoversReplayTruthFromBackupAfterRestoreFailure;
var
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LNormalProvider3: IFreePascalEarlyDataReplayProvider;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
begin
  LExistingSession := BuildManualSession('file-provider-backup-restore-failed-existing', 8);
  LBlockedSession := BuildManualSession('file-provider-backup-restore-failed-blocked', 8);

  LFileName := BuildReplayProviderStoreFilePath('backup_restore_failure_recovery');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LNormalProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay truth before scripted backup restore failure');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay-store file before scripted backup restore failure');

    LScriptedStore := TScriptedBackupRestoreFailureReplayStore.Create(LFileName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Backup restore failure should fail closed for the fresh blocked session');
    AssertTrue(not FileExists(LFileName),
      'Backup restore failure should leave the canonical main replay-store file missing after restore fails');
    AssertTrue(not FileExists(LTempFileName),
      'Backup restore failure should still clean up the temp replay-store file');
    AssertTrue(FileExists(LBackupFileName),
      'Backup restore failure should preserve the backup replay-store artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Backup restore failure should still reject the original replay truth through the same scripted store');

    LNormalProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after backup restore failure should still reject the original replay truth from the backup artifact');
    AssertTrue(FileExists(LBackupFileName),
      'Replay rejection after backup restore failure should not consume the backup artifact');
    AssertTrue(LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after backup restore failure should still accept the fresh blocked session');
    AssertTrue(FileExists(LFileName),
      'Fresh acquire after backup restore failure should materialize the canonical replay-store file again');
    AssertTrue(not FileExists(LBackupFileName),
      'Successful recovery after backup restore failure should consume the backup artifact');

    LNormalProvider3 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider3, True, 8);
    AssertTrue(not LNormalLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after backup restore recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackup;
var
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LNormalProvider3: IFreePascalEarlyDataReplayProvider;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LResidueSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LExpectedBytes: TBytes;
begin
  LExistingSession := BuildManualSession('file-provider-bak-residue-existing', 8);
  LResidueSession := BuildManualSession('file-provider-bak-residue-accepted', 8);
  LBlockedSession := BuildManualSession('file-provider-bak-residue-blocked', 8);

  LFileName := BuildReplayProviderStoreFilePath('backup_cleanup_delete_failure_residue');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LNormalProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay truth before scripted backup cleanup delete failure');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay-store file before scripted backup cleanup delete failure');

    LScriptedStore := TScriptedBackupCleanupDeleteFailureReplayStore.Create(LFileName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(LScriptedLedger.TryAcquireEarlyDataSession(LResidueSession),
      'Backup cleanup delete failure should still accept the fresh session after canonical main replacement succeeds');
    AssertTrue(FileExists(LFileName),
      'Backup cleanup delete failure should keep the canonical replay-store file after the successful replacement');
    AssertTrue(not FileExists(LTempFileName),
      'Backup cleanup delete failure should still clean up the temp replay-store file after the successful replacement');
    AssertTrue(FileExists(LBackupFileName),
      'Backup cleanup delete failure should leave a stale backup residue when cleanup delete fails');
    LExpectedBytes := ReadBytesFromFile(LFileName);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Backup cleanup delete failure should preserve the original replay truth immediately');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LResidueSession),
      'Backup cleanup delete failure should persist the fresh accepted replay truth through the canonical main file');

    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Undeletable stale backup residue on the next save should fail closed');
    AssertTrue(FileExists(LFileName),
      'Undeletable stale backup residue on the next save should preserve the canonical replay-store file');
    AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
      'Undeletable stale backup residue on the next save should keep canonical replay-store bytes unchanged');
    AssertTrue(not FileExists(LTempFileName),
      'Undeletable stale backup residue on the next save should not leave a temp replay-store file behind');
    AssertTrue(FileExists(LBackupFileName),
      'Undeletable stale backup residue on the next save should preserve the stale backup artifact');

    LNormalProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after stale backup residue should still reject the original replay truth');
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LResidueSession),
      'Provider rebuild after stale backup residue should still reject the fresh replay truth materialized before the cleanup failure');
    AssertTrue(LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after stale backup residue should still accept the blocked session once stale backup cleanup succeeds');
    AssertTrue(FileExists(LFileName),
      'Fresh acquire after stale backup residue should keep the canonical replay-store file materialized');
    AssertTrue(not FileExists(LBackupFileName),
      'Successful recovery after stale backup residue should consume the backup artifact');

    LNormalProvider3 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider3, True, 8);
    AssertTrue(not LNormalLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after stale backup residue recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderPreservesExistingTruthAcrossDeterministicTempWriteOpenDeniedAndRecovers;
var
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LNormalProvider3: IFreePascalEarlyDataReplayProvider;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LExpectedBytes: TBytes;
begin
  LExistingSession := BuildManualSession('file-provider-temp-open-denied-existing', 8);
  LBlockedSession := BuildManualSession('file-provider-temp-open-denied-blocked', 8);

  LFileName := BuildReplayProviderStoreFilePath('temp_write_open_denied_preserves_existing_truth');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LNormalProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay truth before deterministic temp write-open denial');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay-store file before deterministic temp write-open denial');
    LExpectedBytes := ReadBytesFromFile(LFileName);

    LScriptedStore := TScriptedTempWriteOpenDeniedReplayStore.Create(LFileName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Deterministic temp write-open denial should fail closed while preserving canonical replay truth');
    AssertTrue(FileExists(LFileName),
      'Deterministic temp write-open denial should preserve the canonical replay-store file');
    AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
      'Deterministic temp write-open denial should keep canonical replay-store bytes unchanged');
    AssertTrue(not FileExists(LTempFileName),
      'Deterministic temp write-open denial should not leave a temp replay-store file behind');
    AssertTrue(not FileExists(LBackupFileName),
      'Deterministic temp write-open denial should not create a backup artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Deterministic temp write-open denial should preserve the original replay truth immediately');

    LNormalProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after deterministic temp write-open denial should still reject the original replay truth');
    AssertTrue(LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after deterministic temp write-open denial should still accept the fresh blocked session');
    AssertTrue(not FileExists(LBackupFileName),
      'Recovery after deterministic temp write-open denial should not introduce a backup artifact');

    LNormalProvider3 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider3, True, 8);
    AssertTrue(not LNormalLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after deterministic temp write-open denial recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderFailsClosedOnDeterministicBackupPromotionRenameDeniedAndRecovers;
var
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LNormalProvider1: IFreePascalEarlyDataReplayProvider;
  LScriptedProvider: IFreePascalEarlyDataReplayProvider;
  LNormalProvider2: IFreePascalEarlyDataReplayProvider;
  LNormalProvider3: IFreePascalEarlyDataReplayProvider;
  LNormalLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedLedger: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LNormalLedger3: IFreePascalManagedEarlyDataReplayLedger;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LExpectedBytes: TBytes;
begin
  LExistingSession := BuildManualSession('file-provider-backup-promotion-denied-existing', 8);
  LBlockedSession := BuildManualSession('file-provider-backup-promotion-denied-blocked', 8);

  LFileName := BuildReplayProviderStoreFilePath('backup_promotion_rename_denied_preserves_main_truth');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LNormalProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider1, True, 8);
    AssertTrue(LNormalLedger1.TryAcquireEarlyDataSession(LExistingSession),
      'Initial acquire should materialize canonical main replay truth before deterministic backup-promotion denial');
    AssertTrue(FileExists(LFileName),
      'Initial acquire should materialize canonical main replay-store file before deterministic backup-promotion denial');
    LExpectedBytes := ReadBytesFromFile(LFileName);

    LScriptedStore := TScriptedBackupPromotionRenameDeniedReplayStore.Create(LFileName);
    LScriptedProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LScriptedStore);
    LScriptedLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LScriptedProvider, True, 8);
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LBlockedSession),
      'Deterministic backup-promotion denial should fail closed while preserving canonical main replay truth');
    AssertTrue(FileExists(LFileName),
      'Deterministic backup-promotion denial should preserve the canonical replay-store file');
    AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
      'Deterministic backup-promotion denial should keep canonical replay-store bytes unchanged');
    AssertTrue(not FileExists(LTempFileName),
      'Deterministic backup-promotion denial should clean up the temp replay-store file');
    AssertTrue(not FileExists(LBackupFileName),
      'Deterministic backup-promotion denial should not leave a backup artifact');
    AssertTrue(not LScriptedLedger.TryAcquireEarlyDataSession(LExistingSession),
      'Deterministic backup-promotion denial should preserve the original replay truth immediately');

    LNormalProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider2, True, 8);
    AssertTrue(not LNormalLedger2.TryAcquireEarlyDataSession(LExistingSession),
      'Provider rebuild after deterministic backup-promotion denial should still reject the original replay truth');
    AssertTrue(LNormalLedger2.TryAcquireEarlyDataSession(LBlockedSession),
      'Provider rebuild after deterministic backup-promotion denial should still accept the fresh blocked session');
    AssertTrue(not FileExists(LBackupFileName),
      'Recovery after deterministic backup-promotion denial should not leave a backup artifact');

    LNormalProvider3 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LNormalLedger3 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LNormalProvider3, True, 8);
    AssertTrue(not LNormalLedger3.TryAcquireEarlyDataSession(LBlockedSession),
      'Fresh blocked session accepted after deterministic backup-promotion denial recovery should still replay-reject after provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFileBackedReplayProviderPrunesExpiredPersistedEntriesAfterRebuild;
var
  LFileName: string;
  LProvider1: IFreePascalEarlyDataReplayProvider;
  LProvider2: IFreePascalEarlyDataReplayProvider;
  LLedger1: IFreePascalManagedEarlyDataReplayLedger;
  LLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LSession: ISSLSession;
  LReplayKey: string;
begin
  LSession := BuildManualSession('file-provider-prune', 8);
  LReplayKey := ResolveSessionReplayKey(LSession);
  AssertTrue(LReplayKey <> '',
    'Replay key helper should derive a ticket-based key for prune tests');

  LFileName := BuildReplayProviderStoreFilePath('expired_prune');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreSingleEntry(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      LReplayKey,
      IncSecond(Now, -10)
    );

    LProvider1 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger1 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider1, True, 8);
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Expired persisted replay entry should be pruned before a fresh acquire after provider rebuild');

    LProvider2 := TFreePascalFileEarlyDataReplayProvider.Create(LFileName);
    LLedger2 := TFreePascalProviderBackedEarlyDataReplayLedger.Create(LProvider2, True, 8);
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Fresh replay state written after prune should still reject replay on the next provider rebuild');
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestDirectoryReplayStoreRetainsExistingAndAcceptedReplayTruthAcrossCrashWindowRestart;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LDirectoryName: string;
  LSessionFileName: string;
  LReadyFileName: string;
  LGracefulFileName: string;
  LContextPathMarkerFileName: string;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LCrashProcess: TProcess;
  LReplayProcess: TProcess;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LDirectoryName := BuildReplayProviderStoreDirectoryPath('runtime_crash_update_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'session.bin');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'ready');
  LGracefulFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'graceful');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LDirectoryName, 'context_path');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EXST'),
        'Runtime directory crash-update test should first materialize existing canonical replay truth'
      );

      LSerialized := LBlockedSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Runtime directory crash-update test should serialize the blocked resumable session for the crash child');
      WriteBytesToFile(LSessionFileName, LSerialized);

      LCrashProcess := TProcess.Create(nil);
      try
        LCrashProcess.Executable := ParamStr(0);
        LCrashProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_CRASH_ACCEPT_MODE);
        LCrashProcess.Parameters.Add(LDirectoryName);
        LCrashProcess.Parameters.Add(LSessionFileName);
        LCrashProcess.Parameters.Add(LReadyFileName);
        LCrashProcess.Parameters.Add(LGracefulFileName);
        LCrashProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE);
        LCrashProcess.Options := [];
        LCrashProcess.Execute;

        AssertTrue(WaitForFileExists(LReadyFileName, 5000),
          'Runtime directory crash-update test should observe the child accept marker before the simulated crash');
        LCrashProcess.WaitOnExit;
        AssertTrue(not FileExists(LGracefulFileName),
          'Runtime directory crash-update child should not reach the graceful child-mode return path after the simulated crash');
      finally
        try
          LCrashProcess.WaitOnExit;
        except
        end;
        LCrashProcess.Free;
      end;

      AssertTrue(DirectoryExists(LDirectoryName),
        'Runtime directory crash-update test should preserve canonical directory replay truth across simulated crash restart');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildDirectoryReplayStoreServerContext(LDirectoryName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('ERPY'),
        'Runtime directory crash-update restart should still preserve the original replay truth after the child crash'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LReplayProcess := TProcess.Create(nil);
    try
      LReplayProcess.Executable := ParamStr(0);
      LReplayProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LReplayProcess.Parameters.Add(LDirectoryName);
      LReplayProcess.Parameters.Add(LSessionFileName);
      LReplayProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE);
      LReplayProcess.Parameters.Add(LContextPathMarkerFileName);
      LReplayProcess.Options := [];
      LReplayProcess.Execute;
      LReplayProcess.WaitOnExit;
      AssertEqualsInt(0, LReplayProcess.ExitCode,
        'Runtime directory crash-update replay probe should exit cleanly after rejecting the just-accepted blocked session in a new process');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        'Runtime directory crash-update replay probe should materialize a context-path marker');
      LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
      AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_DIRECTORY_STORE), LMarkerBytes),
        'Runtime directory crash-update replay probe should record the requested directory-store context path');
    finally
      try
        LReplayProcess.WaitOnExit;
      except
      end;
      LReplayProcess.Free;
    end;
  finally
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestart;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LSessionFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Restart durability runtime test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Restart durability runtime test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Restart durability runtime test should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Restart durability runtime test should expose backend-private file-backed replay installer seam');

  LFileName := BuildReplayProviderStoreFilePath('runtime_restart_durability');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  CleanupReplayProviderStoreFiles(LFileName);
  if FileExists(LSessionFileName) then
    DeleteFile(LSessionFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Restart durability runtime test should install a file-backed replay ledger');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Restart durability runtime test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Restart durability accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Restart durability runtime test should accept the first resumed early-data attempt before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Restart durability runtime test should accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Restart durability runtime test should advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;
    AssertTrue(FileExists(LFileName),
      'Restart durability runtime test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Restart durability runtime test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Restart durability runtime replay probe should exit cleanly after rejecting replay in a new process');
    finally
      LProcess.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    if FileExists(LSessionFileName) then
      DeleteFile(LSessionFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestartThroughBuilderContext;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Installer-parent/builder-child runtime durability test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Installer-parent/builder-child runtime durability test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Installer-parent/builder-child runtime durability test should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Installer-parent/builder-child runtime durability test should expose backend-private file-backed replay installer seam');

  LFileName := BuildReplayProviderStoreFilePath('installer_parent_builder_child_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LFileName, 'context_path');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Installer-parent/builder-child runtime durability test should install a file-backed replay ledger');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Installer-parent/builder-child runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer-parent/builder-child accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Installer-parent/builder-child runtime durability test should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Installer-parent/builder-child runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Installer-parent/builder-child runtime durability test should still accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Installer-parent/builder-child runtime durability test should advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Installer-parent/builder-child runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Installer-parent/builder-child runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_BUILDER);
      LProcess.Parameters.Add(LContextPathMarkerFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Installer-parent/builder-child runtime replay probe should exit cleanly after rejecting replay in a new process');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        'Installer-parent/builder-child runtime replay probe should materialize a context-path marker');
      LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
      AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_BUILDER), LMarkerBytes),
        'Installer-parent/builder-child runtime replay probe should record the requested builder public path');
    finally
      LProcess.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestartThroughFactoryContext;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Installer-parent/factory-child runtime durability test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Installer-parent/factory-child runtime durability test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Installer-parent/factory-child runtime durability test should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Installer-parent/factory-child runtime durability test should expose backend-private file-backed replay installer seam');

  LFileName := BuildReplayProviderStoreFilePath('installer_parent_factory_child_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LFileName, 'context_path');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Installer-parent/factory-child runtime durability test should install a file-backed replay ledger');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Installer-parent/factory-child runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer-parent/factory-child accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Installer-parent/factory-child runtime durability test should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Installer-parent/factory-child runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Installer-parent/factory-child runtime durability test should still accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Installer-parent/factory-child runtime durability test should advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Installer-parent/factory-child runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Installer-parent/factory-child runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_FACTORY);
      LProcess.Parameters.Add(LContextPathMarkerFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Installer-parent/factory-child runtime replay probe should exit cleanly after rejecting replay in a new process');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        'Installer-parent/factory-child runtime replay probe should materialize a context-path marker');
      LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
      AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_FACTORY), LMarkerBytes),
        'Installer-parent/factory-child runtime replay probe should record the requested factory public path');
    finally
      LProcess.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossTinyRestartLoop;
var
  LRound: Integer;
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LSessionFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  for LRound := 1 to 3 do
  begin
    LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertTrue(LCtx <> nil,
      'Tiny restart loop runtime test should create a FreePascal server context for each round');
    PrepareServerContextForEarlyData(LCtx);

    AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
      'Tiny restart loop runtime test should expose early-data context interface for each round');
    if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    begin
      LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
      LEarlyCtx.SetServerMaxEarlyDataSize(8);
    end;

    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Tiny restart loop runtime test should expose replay-ledger access seam for each round');
    AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
      'Tiny restart loop runtime test should expose backend-private file-backed replay installer seam for each round');

    LFileName := BuildReplayProviderStoreFilePath(
      'runtime_tiny_restart_loop_round_' + IntToStr(LRound));
    LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
    CleanupReplayProviderStoreFiles(LFileName);
    try
      AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
        'Tiny restart loop runtime test should install a file-backed replay ledger for each round');

      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Tiny restart loop runtime test should serialize the captured resumable session for each round');
      WriteBytesToFile(LSessionFileName, LSerialized);

      LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(
        LSession,
        BytesOf('PING' + IntToStr(LRound)),
        True);
      try
        LConn := LCtx.CreateConnection(LAcceptStream);
        AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
          'Tiny restart loop accepted connection should expose early-data interface');
        AssertTrue(LConn.Accept,
          'Tiny restart loop runtime test should accept the first resumed early-data attempt before restart in each round');
        AssertSessionReused(LConn,
          'Tiny restart loop runtime test should reuse the captured session before restart in each round');
        if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
          AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
            'Tiny restart loop runtime test should accept the first resumed early-data attempt before restart in each round');
        AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
          'Tiny restart loop runtime test should advertise accepted early-data before restart in each round');
      finally
        LAcceptStream.Free;
      end;

      AssertTrue(FileExists(LFileName),
        'Tiny restart loop runtime test should materialize the replay-store file before restart in each round');
      AssertTrue(FileExists(LSessionFileName),
        'Tiny restart loop runtime test should materialize the serialized session file before restart in each round');

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
        LProcess.Parameters.Add(LFileName);
        LProcess.Parameters.Add(LSessionFileName);
        LProcess.Options := [];
        LProcess.Execute;
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Tiny restart loop runtime replay probe should exit cleanly after rejecting replay in a new process for each round');
      finally
        LProcess.Free;
      end;
    finally
      LReplayAccess.ResetEarlyDataReplayLedger;
      CleanupReplayProviderStoreFiles(LFileName);
    end;
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossCrashWindowRestart;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LSessionFileName: string;
  LReadyFileName: string;
  LGracefulFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LCrashProcess: TProcess;
  LReplayProcess: TProcess;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Crash-window runtime test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Crash-window runtime test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Crash-window runtime test should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Crash-window runtime test should expose backend-private file-backed replay installer seam');

  LFileName := BuildReplayProviderStoreFilePath('runtime_crash_window_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LFileName, 'ready');
  LGracefulFileName := BuildReplayProviderMarkerFilePath(LFileName, 'graceful');
  CleanupReplayProviderStoreFiles(LFileName);
  DeleteFileIfExists(LSessionFileName);
  DeleteFileIfExists(LGracefulFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Crash-window runtime test should install a file-backed replay ledger');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Crash-window runtime test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LCrashProcess := TProcess.Create(nil);
    try
      LCrashProcess.Executable := ParamStr(0);
      LCrashProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_CRASH_ACCEPT_MODE);
      LCrashProcess.Parameters.Add(LFileName);
      LCrashProcess.Parameters.Add(LSessionFileName);
      LCrashProcess.Parameters.Add(LReadyFileName);
      LCrashProcess.Parameters.Add(LGracefulFileName);
      LCrashProcess.Options := [];
      LCrashProcess.Execute;

      AssertTrue(WaitForFileExists(LReadyFileName, 5000),
        'Crash-window runtime test should observe the child accept marker before the simulated crash');
      LCrashProcess.WaitOnExit;
      AssertTrue(not FileExists(LGracefulFileName),
        'Crash-window runtime child should not reach the graceful child-mode return path after the simulated crash');
    finally
      try
        LCrashProcess.WaitOnExit;
      except
      end;
      LCrashProcess.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Crash-window runtime test should preserve the materialized replay-store file across simulated crash restart');

    LReplayProcess := TProcess.Create(nil);
    try
      LReplayProcess.Executable := ParamStr(0);
      LReplayProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LReplayProcess.Parameters.Add(LFileName);
      LReplayProcess.Parameters.Add(LSessionFileName);
      LReplayProcess.Options := [];
      LReplayProcess.Execute;
      LReplayProcess.WaitOnExit;
      AssertEqualsInt(0, LReplayProcess.ExitCode,
        'Crash-window runtime replay probe should exit cleanly after rejecting replay in a new process after simulated crash restart');
    finally
      try
        LReplayProcess.WaitOnExit;
      except
      end;
      LReplayProcess.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    DeleteFileIfExists(LSessionFileName);
    DeleteFileIfExists(LGracefulFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerFailsClosedWhileCrossProcessLockIsHeldAtRuntime;
{$IFNDEF UNIX}
begin
  WriteLn('[SKIP] runtime cross-process replay-store lock contention contract is Unix-only');
end;
{$ELSE}
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LFileName: string;
  LReadyFileName: string;
  LReleaseFileName: string;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LRejectStream: TScriptedEarlyDataClientStream;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Runtime lock-contention test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Runtime lock-contention test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Runtime lock-contention test should expose replay-ledger access seam');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Runtime lock-contention test should expose backend-private file-backed replay installer seam');

  LFileName := BuildReplayProviderStoreFilePath('runtime_lock_contention');
  LReadyFileName := BuildReplayProviderMarkerFilePath(LFileName, 'ready');
  LReleaseFileName := BuildReplayProviderMarkerFilePath(LFileName, 'release');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Runtime lock-contention test should install a file-backed replay ledger');
    LSession := CaptureServerIssuedSession(LCtx);

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_LOCK_HOLDER_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LReadyFileName);
      LProcess.Parameters.Add(LReleaseFileName);
      LProcess.Options := [];
      LProcess.Execute;

      AssertTrue(WaitForFileExists(LReadyFileName, 5000),
        'Runtime lock-contention helper should signal when the sidecar lock is held');

      LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('LOCK'), False);
      try
        LConn := LCtx.CreateConnection(LRejectStream);
        AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
          'Runtime lock-contention rejected connection should expose early-data interface');
        AssertTrue(LConn.Accept,
          'Runtime lock-contention should still complete resumed handshake while failing closed');
        AssertSessionReused(LConn,
          'Runtime lock-contention should still reuse the cached session');
        if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
          AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
            'Runtime lock-contention should fail closed by rejecting early-data');
        AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
          'Runtime lock-contention should suppress accepted early-data signalling while the cross-process lock is held');
        LRead := LConn.Read(LBuf, SizeOf(LBuf));
        AssertEqualsInt(0, LRead,
          'Runtime lock-contention should not surface discarded early bytes through Read');
      finally
        LRejectStream.Free;
      end;
      AssertTrue(not FileExists(LFileName),
        'Runtime lock-contention should fail closed before materializing canonical replay-store state');

      TouchFile(LReleaseFileName);
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Runtime lock-contention helper should exit cleanly after release');

      LFreshSession := CaptureServerIssuedSession(LCtx);
      LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LFreshSession, BytesOf('OPEN'), True);
      try
        LConn := LCtx.CreateConnection(LAcceptStream);
        AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
          'Runtime lock-contention fresh connection should expose early-data interface');
        AssertTrue(LConn.Accept,
          'Runtime lock-contention should still accept a fresh resumed early-data attempt after release');
        AssertSessionReused(LConn,
          'Runtime lock-contention should still reuse the fresh session after release');
        if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
          AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
            'Runtime lock-contention should re-open fresh early-data acceptance after release');
        AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
          'Runtime lock-contention should advertise accepted early-data again after release');
      finally
        LAcceptStream.Free;
      end;
      AssertTrue(FileExists(LFileName),
        'Runtime lock-contention should materialize canonical replay-store state again after release');
    finally
      if (LReleaseFileName <> '') and (not FileExists(LReleaseFileName)) then
        TouchFile(LReleaseFileName);
      try
        LProcess.WaitOnExit;
      except
      end;
      LProcess.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;
{$ENDIF}

procedure TestContextFileBackedReplayInstallerLifecycle;
var
  LCtx: ISSLContext;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger: IFreePascalEarlyDataReplayLedger;
  LFileName1: string;
  LFileName2: string;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Lifecycle installer test should create a FreePascal server context');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'FreePascal server context should expose backend-private file-backed replay installer seam');
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Lifecycle installer test should expose replay-ledger access seam');

  LFileName1 := BuildReplayProviderStoreFilePath('context_install_lifecycle_a');
  LFileName2 := BuildReplayProviderStoreFilePath('context_install_lifecycle_b');
  CleanupReplayProviderStoreFiles(LFileName1);
  CleanupReplayProviderStoreFiles(LFileName2);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName1),
      'Installer seam should install a file-backed replay ledger into the context');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Installed file-backed replay ledger should be observable through replay-ledger access seam');

    LSession := BuildManualSession('context-installer-lifecycle', 8);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Installed file-backed replay ledger should accept first acquire for a fresh session');
    AssertTrue(FileExists(LFileName1),
      'Installing and using file-backed replay ledger should create the first replay store file');

    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName2),
      'Installer seam should allow reinstalling a different replay store file');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Reinstalling to a different replay store should isolate persisted replay truth');
    AssertTrue(FileExists(LFileName2),
      'Reinstalling a different replay store should materialize the second file after first acquire');

    LReplayAccess.ResetEarlyDataReplayLedger;
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Resetting replay ledger should restore a usable default ledger');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Reset should return replay acquisition to the default in-memory ledger');

    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName1),
      'Installer seam should allow returning to the original replay store file');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Reinstalling the original replay store should recover persisted replay truth and reject replay');
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName1);
    CleanupReplayProviderStoreFiles(LFileName2);
  end;
end;

procedure TestContextFileBackedReplayInstallerTracksSessionCacheSettings;
var
  LCtx: ISSLContext;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger: IFreePascalEarlyDataReplayLedger;
  LFileName: string;
  LDisabledSession: ISSLSession;
  LZeroCapacitySession: ISSLSession;
  LRestoredCapacitySession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Session-cache sync installer test should create a FreePascal server context');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
    'Session-cache sync installer test should expose backend-private file-backed replay installer seam');
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Session-cache sync installer test should expose replay-ledger access seam');

  LCtx.SetSessionCacheMode(False);
  LCtx.SetSessionCacheSize(8);

  LFileName := BuildReplayProviderStoreFilePath('context_install_cache_sync');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName),
      'Installer seam should install file-backed replay ledger even when session cache is disabled');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Installed ledger should remain addressable through replay-ledger access seam');

    LDisabledSession := BuildManualSession('context-installer-disabled', 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisabledSession),
      'Installed file-backed replay ledger should inherit disabled session-cache state');

    LCtx.SetSessionCacheMode(True);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LDisabledSession),
      'Re-enabling session cache should re-enable the installed file-backed replay ledger');

    LCtx.SetSessionCacheSize(0);
    LZeroCapacitySession := BuildManualSession('context-installer-zero-capacity', 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LZeroCapacitySession),
      'Setting session cache size to zero should disable installed file-backed replay acquisition');

    LCtx.SetSessionCacheSize(8);
    LRestoredCapacitySession := BuildManualSession('context-installer-restored-capacity', 8);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LRestoredCapacitySession),
      'Restoring session cache size should restore installed file-backed replay acquisition');
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LInstaller1: IFreePascalContextEarlyDataReplayInstaller;
  LInstaller2: IFreePascalContextEarlyDataReplayInstaller;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Installer-based replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for installer tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for installer tests');
  AssertTrue(Supports(LCtx1, IFreePascalContextEarlyDataReplayInstaller, LInstaller1),
    'First server context should expose backend-private file-backed replay installer seam');
  AssertTrue(Supports(LCtx2, IFreePascalContextEarlyDataReplayInstaller, LInstaller2),
    'Second server context should expose backend-private file-backed replay installer seam');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for installer tests');

  LFileName := BuildReplayProviderStoreFilePath('install_helper_cross_context');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller1.InstallFileBackedReplayLedger(LFileName),
      'Backend-private installer seam should install a file-backed replay ledger into the first context');
    AssertTrue(LInstaller2.InstallFileBackedReplayLedger(LFileName),
      'Backend-private installer seam should install a file-backed replay ledger into the second context');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer-backed accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Installer-backed file provider should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'First resumed early-data attempt should remain accepted with installer-backed replay state');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Installer-backed first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer-backed replay-rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Installer-backed replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Installer-backed replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Installer-backed replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Installer-backed cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Installer-backed cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossLocalGateToggles;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LInstaller1: IFreePascalContextEarlyDataReplayInstaller;
  LInstaller2: IFreePascalContextEarlyDataReplayInstaller;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LManagedLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LReplaySession: ISSLSession;
  LDisabledGateSession: ISSLSession;
  LZeroCapacitySession: ISSLSession;
  LRestoredFreshSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LDisabledStream: TScriptedEarlyDataClientStream;
  LReplayRejectStream: TScriptedEarlyDataClientStream;
  LZeroCapacityStream: TScriptedEarlyDataClientStream;
  LReplayRejectAfterRestoreStream: TScriptedEarlyDataClientStream;
  LRestoredAcceptStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Installer runtime parity test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface for installer runtime parity tests');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface for installer runtime parity tests');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalContextEarlyDataReplayInstaller, LInstaller1),
    'First server context should expose backend-private file-backed replay installer seam for runtime parity tests');
  AssertTrue(Supports(LCtx2, IFreePascalContextEarlyDataReplayInstaller, LInstaller2),
    'Second server context should expose backend-private file-backed replay installer seam for runtime parity tests');
  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for installer runtime parity tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for installer runtime parity tests');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for installer runtime parity tests');

  LFileName := BuildReplayProviderStoreFilePath('install_helper_runtime_lifecycle');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    AssertTrue(LInstaller1.InstallFileBackedReplayLedger(LFileName),
      'Installer runtime parity test should install a file-backed replay ledger into the first context');
    AssertTrue(LInstaller2.InstallFileBackedReplayLedger(LFileName),
      'Installer runtime parity test should install a file-backed replay ledger into the second context');
    AssertTrue(Supports(LReplayAccess2.GetEarlyDataReplayLedger, IFreePascalManagedEarlyDataReplayLedger, LManagedLedger2),
      'Second installer-backed runtime parity context should expose a managed replay-ledger gate');

    LReplaySession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LReplaySession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Installer runtime parity should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Installer runtime parity first resumed early-data attempt should remain accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Installer runtime parity first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LDisabledGateSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LDisabledGateSession);

    LManagedLedger2.SetEnabled(False);
    LDisabledStream := TScriptedEarlyDataClientStream.CreateResumed(LDisabledGateSession, BytesOf('LOCK'), False);
    try
      LConn := LCtx2.CreateConnection(LDisabledStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity disabled-gate connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Disabled installer-backed runtime path should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Disabled installer-backed runtime path should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Disabled installer-backed runtime path should reject early-data through the local gate');
      AssertTrue(not LDisabledStream.ObservedServerAcceptedEarlyData,
        'Disabled installer-backed runtime path should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Disabled installer-backed runtime path should not surface discarded early bytes through Read');
    finally
      LDisabledStream.Free;
    end;

    LManagedLedger2.SetEnabled(True);
    LReplayRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LReplayRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity replay-rejected connection after re-enable should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Re-enabled installer-backed runtime path should still complete resumed handshake for replay rejection');
      AssertSessionReused(LConn,
        'Re-enabled installer-backed runtime path should still reuse the replayed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Re-enabled installer-backed runtime path should retain replay truth and reject replay');
      AssertTrue(not LReplayRejectStream.ObservedServerAcceptedEarlyData,
        'Re-enabled installer-backed runtime path should suppress accepted early-data signalling on replay');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Re-enabled installer-backed runtime path should not surface replayed early bytes through Read');
    finally
      LReplayRejectStream.Free;
    end;

    LZeroCapacitySession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LZeroCapacitySession);

    LManagedLedger2.SetCapacity(0);
    LZeroCapacityStream := TScriptedEarlyDataClientStream.CreateResumed(LZeroCapacitySession, BytesOf('ZERO'), False);
    try
      LConn := LCtx2.CreateConnection(LZeroCapacityStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity zero-capacity connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Zero-capacity installer-backed runtime path should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Zero-capacity installer-backed runtime path should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Zero-capacity installer-backed runtime path should reject early-data through the local capacity gate');
      AssertTrue(not LZeroCapacityStream.ObservedServerAcceptedEarlyData,
        'Zero-capacity installer-backed runtime path should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Zero-capacity installer-backed runtime path should not surface discarded early bytes through Read');
    finally
      LZeroCapacityStream.Free;
    end;

    LManagedLedger2.SetCapacity(8);
    LReplayRejectAfterRestoreStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('KEEP'), False);
    try
      LConn := LCtx2.CreateConnection(LReplayRejectAfterRestoreStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity replay-rejected connection after capacity restore should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Restored installer-backed runtime path should still complete resumed handshake for replay rejection');
      AssertSessionReused(LConn,
        'Restored installer-backed runtime path should still reuse the replayed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Restored installer-backed runtime path should keep replay truth instead of wiping it');
      AssertTrue(not LReplayRejectAfterRestoreStream.ObservedServerAcceptedEarlyData,
        'Restored installer-backed runtime path should suppress accepted early-data signalling on replay');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Restored installer-backed runtime path should not surface replayed early bytes through Read');
    finally
      LReplayRejectAfterRestoreStream.Free;
    end;

    LRestoredFreshSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LRestoredFreshSession);
    LRestoredAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LRestoredFreshSession, BytesOf('FRESH'), True);
    try
      LConn := LCtx2.CreateConnection(LRestoredAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Installer runtime parity restored fresh connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Restored installer-backed runtime path should allow fresh resumed early-data again');
      AssertSessionReused(LConn,
        'Restored installer-backed runtime path should still reuse the fresh resumed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Restored installer-backed runtime path should re-open the local gate for fresh sessions');
      AssertTrue(LRestoredAcceptStream.ObservedServerAcceptedEarlyData,
        'Restored installer-backed runtime path should advertise accepted early-data for a fresh session');
    finally
      LRestoredAcceptStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerFailsClosedOnCorruptStoresAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_invalid_version');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LFileName,
      TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      0
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('FAIL'),
        'Invalid-version replay store through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('runtime_truncated');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderTruncatedStoreFile(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      ResolveSessionReplayKey(LSession)
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TRNC'),
        'Truncated replay store through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('runtime_invalid_count');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_ENTRY_COUNT
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('CNT!'),
        'Oversize replay-store entry count through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('runtime_invalid_key_length');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderInvalidKeyLengthStoreFile(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      TEST_INVALID_REPLAY_PROVIDER_KEY_LENGTH
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('KEY!'),
        'Oversize replay-store key length through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerFailsClosedOnCorruptOrphanTempStoresAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_orphan_temp_invalid_version');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreHeader(
      LTempFileName,
      TEST_INVALID_FILE_REPLAY_PROVIDER_VERSION,
      0
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TMP!'),
        'Invalid-version orphan temp replay store through installer runtime path'
      );
      AssertTrue(not FileExists(LFileName),
        'Invalid-version orphan temp replay store should fail closed before materializing canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LFileName := BuildReplayProviderStoreFilePath('runtime_orphan_temp_truncated');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderTruncatedStoreFile(
      LTempFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      ResolveSessionReplayKey(LSession)
    );
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TMPR'),
        'Truncated orphan temp replay store through installer runtime path'
      );
      AssertTrue(not FileExists(LFileName),
        'Truncated orphan temp replay store should fail closed before materializing canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerFailsClosedOnCorruptBackupFallbackStoresAtRuntime;
  procedure AssertRuntimeCorruptBackupFallbackFailsClosed(
    const ASuffix: string;
    const AMode: string;
    const AEarlyData: TBytes;
    const ALabel: string
  );
  var
    LCaptureCtx: ISSLContext;
    LCtx: ISSLContext;
    LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
    LExistingSession: ISSLSession;
    LBlockedSession: ISSLSession;
    LReplayKey: string;
    LFileName: string;
    LTempFileName: string;
    LBackupFileName: string;
  begin
    LCaptureCtx := BuildAcceptingEarlyDataServerContext;
    LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
    LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);
    LReplayKey := ResolveSessionReplayKey(LExistingSession);
    AssertTrue(LReplayKey <> '',
      ALabel + ' should derive a replay key for backup fallback corruption runtime setup');

    LFileName := BuildReplayProviderStoreFilePath('runtime_backup_fallback_' + ASuffix);
    LTempFileName := LFileName + '.tmp';
    LBackupFileName := LFileName + '.bak';
    CleanupReplayProviderStoreFiles(LFileName);
    try
      LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
      try
        AssertResumedEarlyDataAcceptedAtRuntime(
          LCtx,
          LExistingSession,
          BytesOf('EONE'),
          ALabel + ' should materialize canonical replay truth before corrupting the .bak fallback path'
        );
      finally
        if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
          LReplayAccess.ResetEarlyDataReplayLedger;
      end;

      MoveCanonicalReplayStoreToBackupFallback(LFileName, ALabel);
      WriteCorruptReplayProviderBackupFallbackStore(LBackupFileName, LReplayKey, AMode);

      LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
      try
        AssertResumedEarlyDataRejectedAtRuntime(
          LCtx,
          LBlockedSession,
          AEarlyData,
          ALabel + ' through installer runtime path'
        );
        AssertResumedEarlyDataRejectedAtRuntime(
          LCtx,
          LExistingSession,
          BytesOf('EPRV'),
          ALabel + ' should not mis-restore the original replay truth through installer runtime path'
        );
        AssertTrue(not FileExists(LFileName),
          ALabel + ' should keep canonical main replay-store file absent when installer runtime falls back to corrupt .bak');
        AssertTrue(not FileExists(LTempFileName),
          ALabel + ' should not leave a temp replay-store file behind when installer runtime falls back to corrupt .bak');
        AssertTrue(FileExists(LBackupFileName),
          ALabel + ' should preserve the corrupt .bak fallback artifact at runtime');
      finally
        if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
          LReplayAccess.ResetEarlyDataReplayLedger;
      end;
    finally
      CleanupReplayProviderStoreFiles(LFileName);
    end;
  end;
begin
  AssertRuntimeCorruptBackupFallbackFailsClosed(
    'invalid_version',
    'invalid_version',
    BytesOf('BAK!'),
    'Invalid-version .bak fallback replay store'
  );
  AssertRuntimeCorruptBackupFallbackFailsClosed(
    'truncated',
    'truncated',
    BytesOf('TRNC'),
    'Truncated .bak fallback replay store'
  );
  AssertRuntimeCorruptBackupFallbackFailsClosed(
    'invalid_count',
    'invalid_count',
    BytesOf('CNT!'),
    'Oversize entry-count .bak fallback replay store'
  );
  AssertRuntimeCorruptBackupFallbackFailsClosed(
    'invalid_key_length',
    'invalid_key_length',
    BytesOf('KEY!'),
    'Oversize key-length .bak fallback replay store'
  );
  AssertRuntimeCorruptBackupFallbackFailsClosed(
    'trailing_garbage',
    'trailing_garbage',
    BytesOf('JUNK'),
    'Trailing-garbage .bak fallback replay store'
  );
end;

procedure TestContextFileBackedReplayInstallerFailsClosedOnFilesystemPathBlockersAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LLockFileName: string;
  LBlockedParentPath: string;
  LNestedFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_lock_path_directory_blocker');
  LLockFileName := BuildReplayProviderLockFilePath(LFileName);
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LLockFileName);
  try
    AssertTrue(ForceDirectories(LLockFileName),
      'Runtime directory-occupied replay-store lock path test should create the blocker directory');

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('LKBL'),
        'Directory-occupied replay-store lock path through installer runtime path'
      );
      AssertTrue(not FileExists(LFileName),
        'Directory-occupied replay-store lock path should fail closed before materializing canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LLockFileName);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('LKOK'),
        'Recovered replay-store lock path through installer runtime path'
      );
      AssertTrue(FileExists(LFileName),
        'Recovered replay-store lock path should materialize canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('LKRP'),
        'Replay truth after recovering a directory-occupied replay-store lock path through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    RemoveReplayProviderPathIfExists(LLockFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_temp_path_directory_blocker');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LTempFileName);
  try
    AssertTrue(ForceDirectories(LTempFileName),
      'Runtime directory-occupied replay-store temp path test should create the blocker directory');

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TPBL'),
        'Directory-occupied replay-store temp path through installer runtime path'
      );
      AssertTrue(not FileExists(LFileName),
        'Directory-occupied replay-store temp path should fail closed before materializing canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LTempFileName);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TPOK'),
        'Recovered replay-store temp path through installer runtime path'
      );
      AssertTrue(FileExists(LFileName),
        'Recovered replay-store temp path should materialize canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('TPRP'),
        'Replay truth after recovering a directory-occupied replay-store temp path through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    RemoveReplayProviderPathIfExists(LTempFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;

  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LBlockedParentPath := BuildReplayProviderStoreFilePath('runtime_parent_path_file_blocker');
  LNestedFileName := IncludeTrailingPathDelimiter(LBlockedParentPath) + 'store.bin';
  CleanupReplayProviderStoreFiles(LNestedFileName);
  RemoveReplayProviderPathIfExists(LBlockedParentPath);
  try
    TouchFile(LBlockedParentPath);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LNestedFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('PRBL'),
        'Replay-store parent path occupied by a file through installer runtime path'
      );
      AssertTrue(not FileExists(LNestedFileName),
        'Replay-store parent path occupied by a file should fail closed before materializing canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LBlockedParentPath);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LNestedFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('PROK'),
        'Recovered replay-store parent path through installer runtime path'
      );
      AssertTrue(FileExists(LNestedFileName),
        'Recovered replay-store parent path should materialize canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LNestedFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('PRRP'),
        'Replay truth after recovering a file-occupied replay-store parent path through installer runtime path'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LNestedFileName);
    RemoveReplayProviderPathIfExists(LBlockedParentPath);
  end;
end;

procedure TestContextFileBackedReplayInstallerPreservesExistingReplayTruthAcrossTempPathWriteFailureAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LExpectedBytes: TBytes;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_temp_write_failure_preserves_existing_truth');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LTempFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical main replay-store truth before temp-path write failure'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical main replay-store file before temp-path write failure');
      LExpectedBytes := ReadBytesFromFile(LFileName);

      AssertTrue(ForceDirectories(LTempFileName),
        'Runtime temp-path write-failure preservation test should create the temp-path blocker directory');

      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TBLK'),
        'Directory-occupied replay-store temp path through installer runtime path while preserving existing replay truth'
      );
      AssertTrue(FileExists(LFileName),
        'Runtime temp-path write failure should preserve the existing canonical main replay-store file');
      AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
        'Runtime temp-path write failure should keep canonical main replay-store bytes unchanged on failed update');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Existing runtime replay truth should still reject replay after a temp-path write failure'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LTempFileName);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TOK!'),
        'Recovered replay-store temp path through installer runtime path after preserving existing replay truth'
      );
      AssertTrue(FileExists(LFileName),
        'Recovered runtime temp-path write failure should keep the canonical main replay-store file materialized');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('TRPL'),
        'Replay truth materialized after recovering a runtime temp-path write failure should still reject replay'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Recovered runtime temp-path write failure should still preserve the original replay truth'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    RemoveReplayProviderPathIfExists(LTempFileName);
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerFailsClosedOnCanonicalMainPathRenameBoundaryAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_canonical_main_path_rename_boundary');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  RemoveReplayProviderPathIfExists(LFileName);
  try
    AssertTrue(ForceDirectories(LFileName),
      'Runtime canonical main-path rename-boundary test should create the blocker directory');

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('RBLK'),
        'Directory-occupied canonical replay-store path through installer runtime path at the temp-to-main rename boundary'
      );
      AssertTrue(DirectoryExists(LFileName),
        'Runtime canonical replay-store path should stay blocked after a rename-boundary failure');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime canonical main-path rename-boundary failure should clean up the temporary replay-store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    RemoveReplayProviderPathIfExists(LFileName);

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('ROK!'),
        'Recovered canonical replay-store path through installer runtime path after a rename-boundary failure'
      );
      AssertTrue(FileExists(LFileName),
        'Recovered runtime canonical main-path rename boundary should materialize the canonical replay-store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('RRPL'),
        'Replay truth materialized after recovering a runtime canonical main-path rename boundary should still reject replay'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
    RemoveReplayProviderPathIfExists(LFileName);
  end;
end;

procedure TestStoreBackedReplayInstallHelperPreservesExistingTruthAcrossExistingMainReplaceFallbackFailureAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LExpectedBytes: TBytes;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_existing_main_replace_fallback_truth_preservation');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical replay truth before scripted existing-main replace failure'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical replay-store file before scripted existing-main replace failure');
      LExpectedBytes := ReadBytesFromFile(LFileName);
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedExistingMainReplaceFailureReplayStore.Create(LFileName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted file store for existing-main replace fallback runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Existing-main replace fallback failure through store-backed runtime path should reject early-data without losing old truth'
      );
      AssertTrue(FileExists(LFileName),
        'Runtime existing-main replace fallback failure should preserve the canonical replay-store file');
      AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
        'Runtime existing-main replace fallback failure should keep canonical replay-store bytes unchanged');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime existing-main replace fallback failure should clean up the temp replay-store file');
      AssertTrue(not FileExists(LBackupFileName),
        'Runtime existing-main replace fallback failure should not leave a backup artifact after restoring old truth');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime existing-main replace fallback failure should preserve the original replay truth immediately'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Installer runtime rebuild after existing-main replace fallback failure should still reject the original replay truth'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Installer runtime rebuild after existing-main replace fallback failure should still accept the fresh blocked session'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after runtime recovery should still replay-reject after installer rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestStoreBackedReplayInstallHelperRecoversReplayTruthFromBackupAfterRestoreFailureAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_backup_restore_failure_recovery');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical replay truth before scripted backup restore failure'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical replay-store file before scripted backup restore failure');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupRestoreFailureReplayStore.Create(LFileName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted file store for backup restore failure runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Backup restore failure through store-backed runtime path should reject early-data without dropping old truth'
      );
      AssertTrue(not FileExists(LFileName),
        'Runtime backup restore failure should leave the canonical replay-store file missing after restore fails');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime backup restore failure should clean up the temp replay-store file');
      AssertTrue(FileExists(LBackupFileName),
        'Runtime backup restore failure should preserve the backup replay-store artifact');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime backup restore failure should still reject the original replay truth through the backup artifact'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Installer runtime rebuild after backup restore failure should still reject the original replay truth'
      );
      AssertTrue(FileExists(LBackupFileName),
        'Installer runtime replay rejection after backup restore failure should not consume the backup artifact');
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Installer runtime rebuild after backup restore failure should still accept the fresh blocked session'
      );
      AssertTrue(FileExists(LFileName),
        'Installer runtime recovery after backup restore failure should materialize the canonical replay-store file again');
      AssertTrue(not FileExists(LBackupFileName),
        'Installer runtime recovery after backup restore failure should consume the backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after runtime backup restore recovery should still replay-reject after installer rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestStoreBackedReplayInstallHelperLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackupAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LResidueSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LExpectedBytes: TBytes;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LResidueSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_backup_cleanup_delete_failure_residue');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical replay truth before scripted backup cleanup delete failure'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical replay-store file before scripted backup cleanup delete failure');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupCleanupDeleteFailureReplayStore.Create(LFileName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted file store for backup cleanup delete-failure runtime validation');
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RONE'),
        'Backup cleanup delete failure through the store-backed runtime path should still accept early-data after canonical main replacement succeeds'
      );
      AssertTrue(FileExists(LFileName),
        'Runtime backup cleanup delete failure should keep the canonical replay-store file after the successful replacement');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime backup cleanup delete failure should still clean up the temp replay-store file after the successful replacement');
      AssertTrue(FileExists(LBackupFileName),
        'Runtime backup cleanup delete failure should leave a stale backup artifact when cleanup delete fails');
      LExpectedBytes := ReadBytesFromFile(LFileName);
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime backup cleanup delete failure should preserve the original replay truth immediately'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RPRV'),
        'Runtime backup cleanup delete failure should persist the fresh accepted replay truth through the canonical main file'
      );

      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Undeletable stale backup residue on the next runtime save should fail closed'
      );
      AssertTrue(FileExists(LFileName),
        'Undeletable stale backup residue on the next runtime save should preserve the canonical replay-store file');
      AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
        'Undeletable stale backup residue on the next runtime save should keep canonical replay-store bytes unchanged');
      AssertTrue(not FileExists(LTempFileName),
        'Undeletable stale backup residue on the next runtime save should not leave a temp replay-store file behind');
      AssertTrue(FileExists(LBackupFileName),
        'Undeletable stale backup residue on the next runtime save should preserve the stale backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Installer runtime rebuild after stale backup residue should still reject the original replay truth'
      );
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LResidueSession,
        BytesOf('RAGN'),
        'Installer runtime rebuild after stale backup residue should still reject the fresh replay truth materialized before the cleanup failure'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Installer runtime rebuild after stale backup residue should still accept the blocked session once stale backup cleanup succeeds'
      );
      AssertTrue(FileExists(LFileName),
        'Fresh runtime acquire after stale backup residue should keep the canonical replay-store file materialized');
      AssertTrue(not FileExists(LBackupFileName),
        'Successful runtime recovery after stale backup residue should consume the backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after stale backup residue recovery should still replay-reject after installer rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestStoreBackedReplayInstallHelperPreservesExistingTruthAcrossDeterministicTempWriteOpenDeniedAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LExpectedBytes: TBytes;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_temp_write_open_denied_preserves_existing_truth');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical replay truth before deterministic temp write-open denial'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical replay-store file before deterministic temp write-open denial');
      LExpectedBytes := ReadBytesFromFile(LFileName);
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedTempWriteOpenDeniedReplayStore.Create(LFileName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted file store for deterministic temp write-open denial runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Deterministic temp write-open denial through the store-backed runtime path should reject early-data without losing old truth'
      );
      AssertTrue(FileExists(LFileName),
        'Runtime deterministic temp write-open denial should preserve the canonical replay-store file');
      AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
        'Runtime deterministic temp write-open denial should keep canonical replay-store bytes unchanged');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime deterministic temp write-open denial should not leave a temp replay-store file behind');
      AssertTrue(not FileExists(LBackupFileName),
        'Runtime deterministic temp write-open denial should not create a backup artifact');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime deterministic temp write-open denial should preserve the original replay truth immediately'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Installer runtime rebuild after deterministic temp write-open denial should still reject the original replay truth'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Installer runtime rebuild after deterministic temp write-open denial should still accept the fresh blocked session'
      );
      AssertTrue(not FileExists(LBackupFileName),
        'Runtime recovery after deterministic temp write-open denial should not create a backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after deterministic temp write-open denial recovery should still replay-reject after installer rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestStoreBackedReplayInstallHelperFailsClosedOnDeterministicBackupPromotionRenameDeniedAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LScriptedStore: IFreePascalEarlyDataReplayStore;
  LExistingSession: ISSLSession;
  LBlockedSession: ISSLSession;
  LFileName: string;
  LTempFileName: string;
  LBackupFileName: string;
  LExpectedBytes: TBytes;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LExistingSession := CaptureServerIssuedSession(LCaptureCtx);
  LBlockedSession := CaptureServerIssuedSession(LCaptureCtx);

  LFileName := BuildReplayProviderStoreFilePath('runtime_backup_promotion_rename_denied_preserves_main_truth');
  LTempFileName := LFileName + '.tmp';
  LBackupFileName := LFileName + '.bak';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EONE'),
        'Initial runtime acquire should materialize canonical replay truth before deterministic backup-promotion denial'
      );
      AssertTrue(FileExists(LFileName),
        'Initial runtime acquire should materialize canonical replay-store file before deterministic backup-promotion denial');
      LExpectedBytes := ReadBytesFromFile(LFileName);
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildAcceptingEarlyDataServerContext;
    try
      LScriptedStore := TScriptedBackupPromotionRenameDeniedReplayStore.Create(LFileName);
      AssertTrue(InstallStoreBackedReplayLedger(LCtx, LScriptedStore),
        'Store-backed helper should install scripted file store for deterministic backup-promotion denial runtime validation');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BLOK'),
        'Deterministic backup-promotion denial through the store-backed runtime path should reject early-data without losing old truth'
      );
      AssertTrue(FileExists(LFileName),
        'Runtime deterministic backup-promotion denial should preserve the canonical replay-store file');
      AssertTrue(BytesEqual(LExpectedBytes, ReadBytesFromFile(LFileName)),
        'Runtime deterministic backup-promotion denial should keep canonical replay-store bytes unchanged');
      AssertTrue(not FileExists(LTempFileName),
        'Runtime deterministic backup-promotion denial should clean up the temp replay-store file');
      AssertTrue(not FileExists(LBackupFileName),
        'Runtime deterministic backup-promotion denial should not leave a backup artifact');
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EPRV'),
        'Runtime deterministic backup-promotion denial should preserve the original replay truth immediately'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LExistingSession,
        BytesOf('EAGN'),
        'Installer runtime rebuild after deterministic backup-promotion denial should still reject the original replay truth'
      );
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BOK!'),
        'Installer runtime rebuild after deterministic backup-promotion denial should still accept the fresh blocked session'
      );
      AssertTrue(not FileExists(LBackupFileName),
        'Runtime recovery after deterministic backup-promotion denial should not leave a backup artifact');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LBlockedSession,
        BytesOf('BRPL'),
        'Fresh blocked session accepted after deterministic backup-promotion denial recovery should still replay-reject after installer rebuild'
      );
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRecoversReplayTruthFromOrphanTempStoreAtRuntime;
var
  LCaptureCtx: ISSLContext;
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFreshSession: ISSLSession;
  LReplayKey: string;
  LFileName: string;
  LTempFileName: string;
begin
  LCaptureCtx := BuildAcceptingEarlyDataServerContext;
  LSession := CaptureServerIssuedSession(LCaptureCtx);
  LReplayKey := ResolveSessionReplayKey(LSession);
  AssertTrue(LReplayKey <> '',
    'Runtime orphan temp recovery test should derive a ticket-based replay key');

  LFileName := BuildReplayProviderStoreFilePath('runtime_orphan_temp_live');
  LTempFileName := LFileName + '.tmp';
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreSingleEntry(
      LTempFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      LReplayKey,
      IncSecond(Now, 30)
    );
    AssertTrue(not FileExists(LFileName),
      'Runtime orphan temp recovery test should keep canonical main replay store file absent during setup');

    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx,
        LSession,
        BytesOf('ORPH'),
        'Live orphan temp replay store through installer runtime path'
      );

      LFreshSession := CaptureServerIssuedSession(LCtx);
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LFreshSession,
        BytesOf('FRESH'),
        'Fresh resumed early-data after orphan temp recovery through installer runtime path'
      );
      AssertTrue(FileExists(LFileName),
        'Fresh resumed early-data after orphan temp recovery should materialize canonical main replay store file');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerIgnoresOrphanLockFileWithoutActiveHolderAtRuntime;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName: string;
  LLockFileName: string;
begin
  LFileName := BuildReplayProviderStoreFilePath('runtime_orphan_lock_file');
  LLockFileName := BuildReplayProviderLockFilePath(LFileName);
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LFileName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      TouchFile(LLockFileName);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('LOCK'),
        'Orphan replay-store lock file through installer runtime path'
      );
      AssertTrue(FileExists(LFileName),
        'Orphan replay-store lock file should still allow canonical main replay store materialization at runtime');
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeSwitchesReplayTruthBoundaryAcrossStorePathReinstall;
var
  LCtx: ISSLContext;
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LFileName1: string;
  LFileName2: string;
begin
  LFileName1 := BuildReplayProviderStoreFilePath('runtime_install_lifecycle_a');
  LFileName2 := BuildReplayProviderStoreFilePath('runtime_install_lifecycle_b');
  CleanupReplayProviderStoreFiles(LFileName1);
  CleanupReplayProviderStoreFiles(LFileName2);
  try
    LCtx := BuildAcceptingEarlyDataServerContext;
    AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayInstaller, LInstaller),
      'Runtime path-swap installer test should expose backend-private file-backed replay installer seam');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Runtime path-swap installer test should expose replay-ledger access seam');

    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName1),
      'Runtime path-swap installer test should install the first replay store file');
    LSession := CaptureServerIssuedSession(LCtx);
    AssertResumedEarlyDataAcceptedAtRuntime(
      LCtx,
      LSession,
      BytesOf('AONE'),
      'First replay-store boundary through installer runtime path'
    );
    AssertTrue(FileExists(LFileName1),
      'First replay-store boundary should materialize the first replay store file after early-data acceptance');

    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName2),
      'Runtime path-swap installer test should switch to the second replay store file');
    AssertResumedEarlyDataAcceptedAtRuntime(
      LCtx,
      LSession,
      BytesOf('BTWO'),
      'Second replay-store boundary after reinstall through installer runtime path'
    );
    AssertTrue(FileExists(LFileName2),
      'Second replay-store boundary should materialize the second replay store file after early-data acceptance');

    AssertTrue(LInstaller.InstallFileBackedReplayLedger(LFileName1),
      'Runtime path-swap installer test should allow switching back to the first replay store file');
    AssertResumedEarlyDataRejectedAtRuntime(
      LCtx,
      LSession,
      BytesOf('AAGN'),
      'Reinstalling the first replay-store boundary through installer runtime path'
    );
  finally
    if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
      LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName1);
    CleanupReplayProviderStoreFiles(LFileName2);
  end;
end;

procedure TestContextFileBackedReplayInstallerTreatsRelativeAndAbsoluteStorePathsAsOneBoundaryAtRuntime;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LRelativeFileName: string;
  LAbsoluteFileName: string;
begin
  LRelativeFileName := BuildReplayProviderStoreFilePath('runtime_relative_absolute_identity');
  LAbsoluteFileName := ExpandFileName(LRelativeFileName);
  AssertTrue(LRelativeFileName <> LAbsoluteFileName,
    'Relative/absolute replay-store identity test should observe distinct path representations');

  CleanupReplayProviderStoreFiles(LRelativeFileName);
  try
    LCtx1 := BuildInstallerFileBackedReplayStoreServerContext(LRelativeFileName);
    try
      LSession := CaptureServerIssuedSession(LCtx1);
      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx1,
        LSession,
        BytesOf('RELA'),
        'Relative replay-store boundary through installer runtime path'
      );
      AssertTrue(FileExists(LRelativeFileName),
        'Relative replay-store boundary should materialize the replay-store file after early-data acceptance');
    finally
      if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
        LReplayAccess1.ResetEarlyDataReplayLedger;
    end;

    LCtx2 := BuildInstallerFileBackedReplayStoreServerContext(LAbsoluteFileName);
    try
      AssertResumedEarlyDataRejectedAtRuntime(
        LCtx2,
        LSession,
        BytesOf('ABSO'),
        'Absolute replay-store alias through installer runtime path'
      );
    finally
      if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
        LReplayAccess2.ResetEarlyDataReplayLedger;
    end;
  finally
    CleanupReplayProviderStoreFiles(LRelativeFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeConvergesReplayTruthAcrossEquivalentStorePathRepresentations;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LParentFileName: string;
  LChildFileName: string;
  LSessionFileName: string;
  LProcess: TProcess;
begin
  LParentFileName := BuildReplayProviderStoreFilePath('runtime_equivalent_store_path_parent');
  LChildFileName := ExpandFileName(LParentFileName);
  LSessionFileName := BuildReplayProviderMarkerFilePath(LParentFileName, 'session.bin');
  AssertTrue(LParentFileName <> LChildFileName,
    'Equivalent store-path runtime test should observe distinct parent and child path representations');

  CleanupReplayProviderStoreFiles(LParentFileName);
  DeleteFileIfExists(LSessionFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LParentFileName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Equivalent store-path runtime test should serialize the captured resumable session');
      WriteBytesToFile(LSessionFileName, LSerialized);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('PATH'),
        'Equivalent store-path parent boundary through installer runtime path'
      );
      AssertTrue(FileExists(LParentFileName),
        'Equivalent store-path runtime test should materialize the parent replay-store file before child replay probe');

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
        LProcess.Parameters.Add(LChildFileName);
        LProcess.Parameters.Add(LSessionFileName);
        LProcess.Options := [];
        LProcess.Execute;
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Equivalent store-path runtime replay probe should exit cleanly after converging on the same replay truth boundary');
      finally
        LProcess.Free;
      end;
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    DeleteFileIfExists(LSessionFileName);
    CleanupReplayProviderStoreFiles(LParentFileName);
  end;
end;

procedure TestContextFileBackedReplayInstallerRuntimeIsolatesReplayTruthAcrossDifferentStoreFiles;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LMarkerBytes: TBytes;
  LParentFileName: string;
  LChildFileName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LProcess: TProcess;
begin
  LParentFileName := BuildReplayProviderStoreFilePath('runtime_boundary_parent');
  LChildFileName := BuildReplayProviderStoreFilePath('runtime_boundary_child');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LParentFileName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LChildFileName, 'context_path');

  CleanupReplayProviderStoreFiles(LParentFileName);
  CleanupReplayProviderStoreFiles(LChildFileName);
  DeleteFileIfExists(LSessionFileName);
  try
    LCtx := BuildInstallerFileBackedReplayStoreServerContext(LParentFileName);
    try
      LSession := CaptureServerIssuedSession(LCtx);
      LSerialized := LSession.Serialize;
      AssertTrue(Length(LSerialized) > 0,
        'Different-store boundary runtime test should serialize the captured resumable session');
      WriteBytesToFile(LSessionFileName, LSerialized);

      AssertResumedEarlyDataAcceptedAtRuntime(
        LCtx,
        LSession,
        BytesOf('AONE'),
        'Parent replay-store boundary A through installer runtime path'
      );
      AssertTrue(FileExists(LParentFileName),
        'Different-store boundary runtime test should materialize the parent replay-store file before child boundary probe');

      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := ParamStr(0);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
        LProcess.Parameters.Add(LChildFileName);
        LProcess.Parameters.Add(LSessionFileName);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER);
        LProcess.Parameters.Add(LContextPathMarkerFileName);
        LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_EXPECT_ACCEPT_THEN_REJECT);
        LProcess.Options := [];
        LProcess.Execute;
        LProcess.WaitOnExit;
        AssertEqualsInt(0, LProcess.ExitCode,
          'Different-store boundary runtime replay probe should exit cleanly after accepting then rejecting the same session on the child boundary');
        AssertTrue(FileExists(LChildFileName),
          'Different-store boundary runtime probe should materialize the child replay-store file after the first accepted attempt');
        AssertTrue(FileExists(LContextPathMarkerFileName),
          'Different-store boundary runtime replay probe should materialize a context-path marker');
        LMarkerBytes := ReadBytesFromFile(LContextPathMarkerFileName);
        AssertTrue(BytesEqual(BytesOf(TEST_REPLAY_PROVIDER_CONTEXT_PATH_INSTALLER), LMarkerBytes),
          'Different-store boundary runtime replay probe should still record the installer context path');
      finally
        LProcess.Free;
      end;
    finally
      if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
        LReplayAccess.ResetEarlyDataReplayLedger;
    end;
  finally
    DeleteFileIfExists(LSessionFileName);
    CleanupReplayProviderStoreFiles(LParentFileName);
    CleanupReplayProviderStoreFiles(LChildFileName);
  end;
end;

procedure TestContextCustomReplayProviderInstallerLifecycle;
var
  LCtx: ISSLContext;
  LInstaller: IFreePascalContextEarlyDataReplayProviderInstaller;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger: IFreePascalEarlyDataReplayLedger;
  LStore1: TSharedReplayProviderStore;
  LStore2: TSharedReplayProviderStore;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Custom provider installer lifecycle test should create a FreePascal server context');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayProviderInstaller, LInstaller),
    'FreePascal server context should expose backend-private custom replay-provider installer seam');
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Custom provider installer lifecycle test should expose replay-ledger access seam');

  LStore1 := TSharedReplayProviderStore.Create;
  LStore2 := TSharedReplayProviderStore.Create;
  try
    AssertTrue(LInstaller.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore1.TryAcquireReplayKey)),
      'Custom provider installer seam should install the first callback-backed replay provider');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Installed custom replay-provider ledger should be observable through replay-ledger access seam');

    LSession := BuildManualSession('context-custom-installer-lifecycle', 8);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Installed custom replay-provider ledger should accept first acquire for a fresh session');

    AssertTrue(LInstaller.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore2.TryAcquireReplayKey)),
      'Custom provider installer seam should allow reinstalling a different callback-backed provider');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Reinstalling a different custom provider should isolate replay truth');

    LReplayAccess.ResetEarlyDataReplayLedger;
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Resetting replay ledger should restore a usable default ledger after custom provider install');
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LSession),
      'Reset after custom provider install should return replay acquisition to the default in-memory ledger');

    AssertTrue(LInstaller.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore1.TryAcquireReplayKey)),
      'Custom provider installer seam should allow returning to the original callback-backed provider');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LSession),
      'Reinstalling the original custom provider should recover replay truth and reject replay');
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    LStore2.Free;
    LStore1.Free;
  end;
end;

procedure TestContextCustomReplayProviderInstallerTracksSessionCacheSettings;
var
  LCtx: ISSLContext;
  LInstaller: IFreePascalContextEarlyDataReplayProviderInstaller;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger: IFreePascalEarlyDataReplayLedger;
  LStore: TSharedReplayProviderStore;
  LDisabledSession: ISSLSession;
  LZeroCapacitySession: ISSLSession;
  LRestoredCapacitySession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Custom provider cache-sync test should create a FreePascal server context');
  AssertTrue(Supports(LCtx, IFreePascalContextEarlyDataReplayProviderInstaller, LInstaller),
    'Custom provider cache-sync test should expose backend-private custom replay-provider installer seam');
  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Custom provider cache-sync test should expose replay-ledger access seam');

  LCtx.SetSessionCacheMode(False);
  LCtx.SetSessionCacheSize(8);

  LStore := TSharedReplayProviderStore.Create;
  try
    AssertTrue(LInstaller.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey)),
      'Custom provider installer seam should install callback-backed replay provider even when session cache is disabled');
    LLedger := LReplayAccess.GetEarlyDataReplayLedger;
    AssertTrue(LLedger <> nil,
      'Installed custom provider-backed ledger should remain observable through replay-ledger access seam');

    LDisabledSession := BuildManualSession('context-custom-installer-disabled', 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LDisabledSession),
      'Installed custom provider-backed ledger should inherit disabled session-cache state');

    LCtx.SetSessionCacheMode(True);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LDisabledSession),
      'Re-enabling session cache should re-enable installed custom provider-backed replay acquisition');

    LCtx.SetSessionCacheSize(0);
    LZeroCapacitySession := BuildManualSession('context-custom-installer-zero-capacity', 8);
    AssertTrue(not LLedger.TryAcquireEarlyDataSession(LZeroCapacitySession),
      'Setting session cache size to zero should disable installed custom provider-backed replay acquisition');

    LCtx.SetSessionCacheSize(8);
    LRestoredCapacitySession := BuildManualSession('context-custom-installer-restored-capacity', 8);
    AssertTrue(LLedger.TryAcquireEarlyDataSession(LRestoredCapacitySession),
      'Restoring session cache size should restore installed custom provider-backed replay acquisition');
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

procedure TestContextCustomReplayProviderInstallerRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LInstaller1: IFreePascalContextEarlyDataReplayProviderInstaller;
  LInstaller2: IFreePascalContextEarlyDataReplayProviderInstaller;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LStore: TSharedReplayProviderStore;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Custom provider installer replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface for custom provider installer tests');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface for custom provider installer tests');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for custom provider installer tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for custom provider installer tests');
  AssertTrue(Supports(LCtx1, IFreePascalContextEarlyDataReplayProviderInstaller, LInstaller1),
    'First server context should expose backend-private custom replay-provider installer seam');
  AssertTrue(Supports(LCtx2, IFreePascalContextEarlyDataReplayProviderInstaller, LInstaller2),
    'Second server context should expose backend-private custom replay-provider installer seam');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for custom provider installer tests');

  LStore := TSharedReplayProviderStore.Create;
  try
    AssertTrue(LInstaller1.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey)),
      'Custom provider installer seam should install shared replay provider into the first context');
    AssertTrue(LInstaller2.InstallReplayProviderBackedLedger(
      TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey)),
      'Custom provider installer seam should install shared replay provider into the second context');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Custom provider installer accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Custom provider installer should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'First resumed early-data attempt should remain accepted with custom provider installer replay state');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Custom provider installer first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Custom provider installer rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Custom provider installer replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Custom provider installer replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Custom provider installer replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Custom provider installer cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Custom provider installer cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

procedure TestCallbackReplayProviderInstallHelperRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LStore: TSharedReplayProviderStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Callback helper replay cross-context test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface for callback helper tests');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface for callback helper tests');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for callback helper tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for callback helper tests');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for callback helper tests');

  LStore := TSharedReplayProviderStore.Create;
  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(@LStore.TryAcquireReplayKey);
    AssertTrue(not InstallReplayProviderBackedLedger(nil, LProvider),
      'Generic replay-provider install helper should fail closed for nil context');
    AssertTrue(not InstallReplayProviderBackedLedger(LCtx1, nil),
      'Generic replay-provider install helper should fail closed for nil provider');
    AssertTrue(InstallCallbackBackedReplayLedger(LCtx1, @LStore.TryAcquireReplayKey),
      'Callback replay-provider install helper should install shared replay provider into the first context');
    AssertTrue(InstallCallbackBackedReplayLedger(LCtx2, @LStore.TryAcquireReplayKey),
      'Callback replay-provider install helper should install shared replay provider into the second context');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Callback helper should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Callback helper first resumed early-data attempt should remain accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Callback helper first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Callback helper replay rejection across contexts should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Callback helper replay rejection across contexts should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Callback helper replay state should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Callback helper cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Callback helper cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

procedure TestCallbackReplayProviderInstallHelperRuntimeRetainsReplayTruthAcrossLocalGateToggles;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LManagedLedger2: IFreePascalManagedEarlyDataReplayLedger;
  LResumptionCache2: IFreePascalResumptionCache;
  LStore: TSharedReplayProviderStore;
  LReplaySession: ISSLSession;
  LDisabledGateSession: ISSLSession;
  LZeroCapacitySession: ISSLSession;
  LRestoredFreshSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LDisabledStream: TScriptedEarlyDataClientStream;
  LReplayRejectStream: TScriptedEarlyDataClientStream;
  LZeroCapacityStream: TScriptedEarlyDataClientStream;
  LReplayRejectAfterRestoreStream: TScriptedEarlyDataClientStream;
  LRestoredAcceptStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
    'Callback helper runtime parity test should create both server contexts');
  PrepareServerContextForEarlyData(LCtx1);
  PrepareServerContextForEarlyData(LCtx2);

  AssertTrue(Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx),
    'First server context should expose early-data context interface for callback helper runtime parity tests');
  if Supports(LCtx1, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;
  AssertTrue(Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx),
    'Second server context should expose early-data context interface for callback helper runtime parity tests');
  if Supports(LCtx2, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    'First server context should expose replay-ledger access seam for callback helper runtime parity tests');
  AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    'Second server context should expose replay-ledger access seam for callback helper runtime parity tests');
  AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
    'Second server context should expose resumption cache seam for callback helper runtime parity tests');

  LStore := TSharedReplayProviderStore.Create;
  try
    AssertTrue(InstallCallbackBackedReplayLedger(LCtx1, @LStore.TryAcquireReplayKey),
      'Callback helper runtime parity test should install the shared callback-backed provider into the first context');
    AssertTrue(InstallCallbackBackedReplayLedger(LCtx2, @LStore.TryAcquireReplayKey),
      'Callback helper runtime parity test should install the shared callback-backed provider into the second context');
    AssertTrue(Supports(LReplayAccess2.GetEarlyDataReplayLedger, IFreePascalManagedEarlyDataReplayLedger, LManagedLedger2),
      'Second callback-helper runtime parity context should expose a managed replay-ledger gate');

    LReplaySession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LReplaySession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Callback helper runtime parity should still allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Callback helper runtime parity first resumed early-data attempt should remain accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Callback helper runtime parity first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LDisabledGateSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LDisabledGateSession);

    LManagedLedger2.SetEnabled(False);
    LDisabledStream := TScriptedEarlyDataClientStream.CreateResumed(LDisabledGateSession, BytesOf('LOCK'), False);
    try
      LConn := LCtx2.CreateConnection(LDisabledStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity disabled-gate connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Disabled callback helper runtime path should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Disabled callback helper runtime path should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Disabled callback helper runtime path should reject early-data through the local gate');
      AssertTrue(not LDisabledStream.ObservedServerAcceptedEarlyData,
        'Disabled callback helper runtime path should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Disabled callback helper runtime path should not surface discarded early bytes through Read');
    finally
      LDisabledStream.Free;
    end;

    LManagedLedger2.SetEnabled(True);
    LReplayRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LReplayRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity replay-rejected connection after re-enable should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Re-enabled callback helper runtime path should still complete resumed handshake for replay rejection');
      AssertSessionReused(LConn,
        'Re-enabled callback helper runtime path should still reuse the replayed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Re-enabled callback helper runtime path should retain replay truth and reject replay');
      AssertTrue(not LReplayRejectStream.ObservedServerAcceptedEarlyData,
        'Re-enabled callback helper runtime path should suppress accepted early-data signalling on replay');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Re-enabled callback helper runtime path should not surface replayed early bytes through Read');
    finally
      LReplayRejectStream.Free;
    end;

    LZeroCapacitySession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LZeroCapacitySession);

    LManagedLedger2.SetCapacity(0);
    LZeroCapacityStream := TScriptedEarlyDataClientStream.CreateResumed(LZeroCapacitySession, BytesOf('ZERO'), False);
    try
      LConn := LCtx2.CreateConnection(LZeroCapacityStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity zero-capacity connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Zero-capacity callback helper runtime path should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Zero-capacity callback helper runtime path should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Zero-capacity callback helper runtime path should reject early-data through the local capacity gate');
      AssertTrue(not LZeroCapacityStream.ObservedServerAcceptedEarlyData,
        'Zero-capacity callback helper runtime path should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Zero-capacity callback helper runtime path should not surface discarded early bytes through Read');
    finally
      LZeroCapacityStream.Free;
    end;

    LManagedLedger2.SetCapacity(8);
    LReplayRejectAfterRestoreStream := TScriptedEarlyDataClientStream.CreateResumed(LReplaySession, BytesOf('KEEP'), False);
    try
      LConn := LCtx2.CreateConnection(LReplayRejectAfterRestoreStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity replay-rejected connection after capacity restore should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Restored callback helper runtime path should still complete resumed handshake for replay rejection');
      AssertSessionReused(LConn,
        'Restored callback helper runtime path should still reuse the replayed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Restored callback helper runtime path should keep replay truth instead of wiping it');
      AssertTrue(not LReplayRejectAfterRestoreStream.ObservedServerAcceptedEarlyData,
        'Restored callback helper runtime path should suppress accepted early-data signalling on replay');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Restored callback helper runtime path should not surface replayed early bytes through Read');
    finally
      LReplayRejectAfterRestoreStream.Free;
    end;

    LRestoredFreshSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LRestoredFreshSession);
    LRestoredAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LRestoredFreshSession, BytesOf('FRESH'), True);
    try
      LConn := LCtx2.CreateConnection(LRestoredAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper runtime parity restored fresh connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Restored callback helper runtime path should allow fresh resumed early-data again');
      AssertSessionReused(LConn,
        'Restored callback helper runtime path should still reuse the fresh resumed session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Restored callback helper runtime path should re-open the local gate for fresh sessions');
      AssertTrue(LRestoredAcceptStream.ObservedServerAcceptedEarlyData,
        'Restored callback helper runtime path should advertise accepted early-data for a fresh session');
    finally
      LRestoredAcceptStream.Free;
    end;
  finally
    LReplayAccess1.ResetEarlyDataReplayLedger;
    LReplayAccess2.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

procedure TestCallbackReplayProviderInstallHelperFailsClosedOnProviderExceptions;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LStore: TExplodingReplayProviderStore;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LReplayStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
  LRaised: Boolean;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil,
    'Callback helper fail-closed runtime test should create a FreePascal server context');
  PrepareServerContextForEarlyData(LCtx);

  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Callback helper fail-closed runtime test should expose early-data context interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    LEarlyCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
    LEarlyCtx.SetServerMaxEarlyDataSize(8);
  end;

  AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
    'Callback helper fail-closed runtime test should expose replay-ledger access seam');

  LStore := TExplodingReplayProviderStore.Create;
  try
    AssertTrue(InstallCallbackBackedReplayLedger(LCtx, @LStore.TryAcquireReplayKey),
      'Callback helper should still install exploding replay provider for fail-closed runtime validation');

    LSession := CaptureServerIssuedSession(LCtx);
    LReplayStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('BANG'), False);
    try
      LConn := LCtx.CreateConnection(LReplayStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Callback helper fail-closed runtime connection should expose early-data interface');

      LRaised := False;
      try
        AssertTrue(LConn.Accept,
          'Exploding callback-backed replay provider should reject early-data without aborting resumed handshake');
      except
        on E: Exception do
        begin
          LRaised := True;
          Fail('Exploding callback-backed replay provider should not abort handshake with exception: ' + E.Message);
        end;
      end;
      AssertTrue(not LRaised,
        'Exploding callback-backed replay provider should keep resumed handshake running');

      AssertSessionReused(LConn,
        'Exploding callback-backed replay provider should still reuse the cached session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Exploding callback-backed replay provider should fail closed by rejecting early-data');
      AssertTrue(not LReplayStream.ObservedServerAcceptedEarlyData,
        'Exploding callback-backed replay provider should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Exploding callback-backed replay provider should not surface discarded early bytes through Read');
    finally
      LReplayStream.Free;
    end;
  finally
    LReplayAccess.ResetEarlyDataReplayLedger;
    LStore.Free;
  end;
end;

function BuildBuilderFileBackedReplayStoreServerContext(const AFileName: string): ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithTLS13
    .WithVerifyNone
    .WithCertificate('tests/certificate/test_certs/signer_cert.pem')
    .WithPrivateKey('tests/certificate/test_certs/signer_key.pem')
    .WithSessionCache(True)
    .WithSessionTimeout(7200)
    .WithServerEarlyDataPolicy(sslEarlyDataServerAccept)
    .WithServerMaxEarlyDataSize(8)
    .WithServerEarlyDataReplayStoreFile(AFileName)
    .BuildServer;
end;

function BuildFactoryFileBackedReplayStoreServerContext(const AFileName: string): ISSLContext;
var
  LConfig: TSSLConfig;
begin
  LConfig := CreateDefaultConfig(sslCtxServer);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxServer;
  LConfig.PreferredVersion := sslProtocolTLS13;
  LConfig.ProtocolVersions := [sslProtocolTLS13];
  LConfig.VerifyMode := [];
  LConfig.CertificateFile := 'tests/certificate/test_certs/signer_cert.pem';
  LConfig.PrivateKeyFile := 'tests/certificate/test_certs/signer_key.pem';
  LConfig.SessionCacheSize := 8;
  LConfig.SessionTimeout := 7200;
  Include(LConfig.Options, ssoEnableSessionCache);
  LConfig.ServerEarlyDataPolicy := sslEarlyDataServerAccept;
  LConfig.ServerMaxEarlyDataSize := 8;
  LConfig.ServerEarlyDataReplayStoreFile := AFileName;
  Result := TSSLFactory.CreateContext(LConfig);
end;

function BuildBuilderDirectoryReplayStoreServerContext(const ADirectoryName: string): ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithTLS13
    .WithVerifyNone
    .WithCertificate('tests/certificate/test_certs/signer_cert.pem')
    .WithPrivateKey('tests/certificate/test_certs/signer_key.pem')
    .WithSessionCache(True)
    .WithSessionTimeout(7200)
    .WithServerEarlyDataPolicy(sslEarlyDataServerAccept)
    .WithServerMaxEarlyDataSize(8)
    .WithServerEarlyDataReplayStoreDirectory(ADirectoryName)
    .BuildServer;
end;

function BuildFactoryDirectoryReplayStoreServerContext(const ADirectoryName: string): ISSLContext;
var
  LConfig: TSSLConfig;
begin
  LConfig := CreateDefaultConfig(sslCtxServer);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxServer;
  LConfig.PreferredVersion := sslProtocolTLS13;
  LConfig.ProtocolVersions := [sslProtocolTLS13];
  LConfig.VerifyMode := [];
  LConfig.CertificateFile := 'tests/certificate/test_certs/signer_cert.pem';
  LConfig.PrivateKeyFile := 'tests/certificate/test_certs/signer_key.pem';
  LConfig.SessionCacheSize := 8;
  LConfig.SessionTimeout := 7200;
  Include(LConfig.Options, ssoEnableSessionCache);
  LConfig.ServerEarlyDataPolicy := sslEarlyDataServerAccept;
  LConfig.ServerMaxEarlyDataSize := 8;
  LConfig.ServerEarlyDataReplayStoreDirectory := ADirectoryName;
  Result := TSSLFactory.CreateContext(LConfig);
end;

procedure TestBuilderFileBackedReplayStoreRejectsCrossContextReplayThroughFactoryContext;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LFileName := BuildReplayProviderStoreFilePath('builder_factory_cross_context');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx1 := BuildBuilderFileBackedReplayStoreServerContext(LFileName);
    LCtx2 := BuildFactoryFileBackedReplayStoreServerContext(LFileName);

    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Mixed builder/factory replay-store test should create both FreePascal server contexts');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Builder-built first context should expose replay-ledger access seam for mixed public-path replay tests');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Factory-built second context should expose replay-ledger access seam for mixed public-path replay tests');
    AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
      'Factory-built second context should expose resumption cache seam for mixed public-path replay tests');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed builder/factory accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-built file-backed replay store should still allow the first resumed early-data attempt before the factory context observes replay');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Builder-built first resumed early-data attempt should remain accepted in mixed public-path replay tests');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Builder-built first resumed early-data attempt should still advertise accepted early-data in mixed public-path replay tests');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed builder/factory rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Factory-built mixed public-path replay rejection should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Factory-built mixed public-path replay rejection should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Factory-built context should reject replayed early-data previously accepted by the builder-built context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Mixed builder/factory replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Mixed builder/factory replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFactoryConfigFileBackedReplayStoreRejectsCrossContextReplayThroughBuilderContext;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LFileName := BuildReplayProviderStoreFilePath('factory_builder_cross_context');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx1 := BuildFactoryFileBackedReplayStoreServerContext(LFileName);
    LCtx2 := BuildBuilderFileBackedReplayStoreServerContext(LFileName);

    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Mixed factory/builder replay-store test should create both FreePascal server contexts');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Factory-built first context should expose replay-ledger access seam for mixed public-path replay tests');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Builder-built second context should expose replay-ledger access seam for mixed public-path replay tests');
    AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
      'Builder-built second context should expose resumption cache seam for mixed public-path replay tests');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed factory/builder accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Factory-built file-backed replay store should still allow the first resumed early-data attempt before the builder context observes replay');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Factory-built first resumed early-data attempt should remain accepted in mixed public-path replay tests');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Factory-built first resumed early-data attempt should still advertise accepted early-data in mixed public-path replay tests');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed factory/builder rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-built mixed public-path replay rejection should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Builder-built mixed public-path replay rejection should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Builder-built context should reject replayed early-data previously accepted by the factory-built context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Mixed factory/builder replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Mixed factory/builder replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestBuilderDirectoryReplayStoreRejectsCrossContextReplayThroughFactoryContext;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LDirectoryName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('builder_factory_directory_cross_context');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx1 := BuildBuilderDirectoryReplayStoreServerContext(LDirectoryName);
    LCtx2 := BuildFactoryDirectoryReplayStoreServerContext(LDirectoryName);

    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Mixed builder/factory directory replay-store test should create both FreePascal server contexts');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Builder-built directory first context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Factory-built directory second context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
      'Factory-built directory second context should expose resumption cache seam');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('DPNG'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Builder-built directory accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-built directory replay store should allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Builder-built directory first resumed early-data attempt should still be accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Builder-built directory first resumed early-data attempt should still advertise accepted early-data');
      AssertTrue(DirectoryExists(LDirectoryName),
        'Builder-built directory first resumed early-data attempt should materialize the replay store directory');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('DRPL'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Factory-built directory rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Factory-built directory replay rejection should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Factory-built directory replay rejection should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Factory-built directory context should reject replayed early-data previously accepted by the builder-built context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Mixed builder/factory directory replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Mixed builder/factory directory replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestFactoryConfigDirectoryReplayStoreRejectsCrossContextReplayThroughBuilderContext;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LDirectoryName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LDirectoryName := BuildReplayProviderStoreDirectoryPath('factory_builder_directory_cross_context');
  CleanupReplayProviderStoreDirectory(LDirectoryName);
  try
    LCtx1 := BuildFactoryDirectoryReplayStoreServerContext(LDirectoryName);
    LCtx2 := BuildBuilderDirectoryReplayStoreServerContext(LDirectoryName);

    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Mixed factory/builder directory replay-store test should create both FreePascal server contexts');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Factory-built directory first context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Builder-built directory second context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
      'Builder-built directory second context should expose resumption cache seam');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('DFA1'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Factory-built directory accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Factory-built directory replay store should allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Factory-built directory first resumed early-data attempt should still be accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Factory-built directory first resumed early-data attempt should still advertise accepted early-data');
      AssertTrue(DirectoryExists(LDirectoryName),
        'Factory-built directory first resumed early-data attempt should materialize the replay store directory');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('DFR2'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Builder-built directory rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-built directory replay rejection should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Builder-built directory replay rejection should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Builder-built directory context should reject replayed early-data previously accepted by the factory-built context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Mixed factory/builder directory replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Mixed factory/builder directory replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreDirectory(LDirectoryName);
  end;
end;

procedure TestPublicPathFileBackedReplayStorePrunesExpiredPersistedEntriesAcrossBuilderAndFactoryContexts;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger1: IFreePascalEarlyDataReplayLedger;
  LLedger2: IFreePascalEarlyDataReplayLedger;
  LFileName: string;
  LSession: ISSLSession;
  LReplayKey: string;
begin
  LSession := BuildManualSession('public-path-expired-prune', 8);
  LReplayKey := ResolveSessionReplayKey(LSession);
  AssertTrue(LReplayKey <> '',
    'Replay key helper should derive a ticket-based key for mixed public-path prune tests');

  LFileName := BuildReplayProviderStoreFilePath('public_path_expired_prune');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    WriteReplayProviderStoreSingleEntry(
      LFileName,
      TEST_FILE_REPLAY_PROVIDER_VERSION,
      LReplayKey,
      IncSecond(Now, -10)
    );

    LCtx1 := BuildBuilderFileBackedReplayStoreServerContext(LFileName);
    AssertTrue(LCtx1 <> nil,
      'Mixed public-path prune test should create a builder-built server context');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Builder-built context should expose replay-ledger access seam for mixed public-path prune tests');
    LLedger1 := LReplayAccess1.GetEarlyDataReplayLedger;
    AssertTrue(LLedger1 <> nil,
      'Builder-built context should expose an installed replay ledger for mixed public-path prune tests');
    AssertTrue(LLedger1.TryAcquireEarlyDataSession(LSession),
      'Builder-built public replay ledger should prune expired persisted entry before a fresh acquire');

    LCtx2 := BuildFactoryFileBackedReplayStoreServerContext(LFileName);
    AssertTrue(LCtx2 <> nil,
      'Mixed public-path prune test should create a factory-built server context after the builder acquires the session');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Factory-built context should expose replay-ledger access seam for mixed public-path prune tests');
    LLedger2 := LReplayAccess2.GetEarlyDataReplayLedger;
    AssertTrue(LLedger2 <> nil,
      'Factory-built context should expose an installed replay ledger for mixed public-path prune tests');
    AssertTrue(not LLedger2.TryAcquireEarlyDataSession(LSession),
      'Factory-built public replay ledger should still observe the fresh replay state written after prune');
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestBuilderFileBackedReplayStoreRejectsCrossContextReplay;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LResumptionCache2: IFreePascalResumptionCache;
  LFileName: string;
  LSession: ISSLSession;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LRejectStream: TScriptedEarlyDataClientStream;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
  LCertPEM: string;
  LKeyPEM: string;
begin
  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'builder-early-data.local',
    'fafafa.ssl',
    30,
    LCertPEM,
    LKeyPEM
  ) then
    Fail('Builder replay-store test should generate a self-signed certificate');

  LFileName := BuildReplayProviderStoreFilePath('builder_cross_context');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx1 := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithTLS13
      .WithVerifyNone
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithSessionCache(True)
      .WithSessionTimeout(7200)
      .WithServerEarlyDataPolicy(sslEarlyDataServerAccept)
      .WithServerMaxEarlyDataSize(8)
      .WithServerEarlyDataReplayStoreFile(LFileName)
      .BuildServer;
    LCtx2 := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithTLS13
      .WithVerifyNone
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithSessionCache(True)
      .WithSessionTimeout(7200)
      .WithServerEarlyDataPolicy(sslEarlyDataServerAccept)
      .WithServerMaxEarlyDataSize(8)
      .WithServerEarlyDataReplayStoreFile(LFileName)
      .BuildServer;

    AssertTrue((LCtx1 <> nil) and (LCtx2 <> nil),
      'Builder replay-store test should create both FreePascal server contexts');
    AssertTrue(Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
      'Builder-built first context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
      'Builder-built second context should expose replay-ledger access seam');
    AssertTrue(Supports(LCtx2, IFreePascalResumptionCache, LResumptionCache2),
      'Builder-built second context should expose resumption cache seam');

    LSession := CaptureServerIssuedSession(LCtx1);
    LResumptionCache2.StoreResumptionSession(LSession);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx1.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Builder replay-store accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-configured file-backed replay store should allow the first resumed early-data attempt');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Builder-configured first resumed early-data attempt should still be accepted');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Builder-configured first resumed early-data attempt should still advertise accepted early-data');
    finally
      LAcceptStream.Free;
    end;

    LRejectStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PONG'), False);
    try
      LConn := LCtx2.CreateConnection(LRejectStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Builder replay-store rejected connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-configured cross-context replay rejection should still complete resumed handshake');
      AssertSessionReused(LConn,
        'Builder-configured cross-context replay rejection should still reuse the session');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataRejected,
          'Builder-configured replay store should reject the second resumed early-data attempt on another context');
      AssertTrue(not LRejectStream.ObservedServerAcceptedEarlyData,
        'Builder-configured cross-context replay rejection should suppress accepted early-data signalling');
      LRead := LConn.Read(LBuf, SizeOf(LBuf));
      AssertEqualsInt(0, LRead,
        'Builder-configured cross-context replay rejection should not surface discarded early bytes through Read');
    finally
      LRejectStream.Free;
    end;
  finally
    if Supports(LCtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
      LReplayAccess1.ResetEarlyDataReplayLedger;
    if Supports(LCtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
      LReplayAccess2.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestBuilderFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestart;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LFileName: string;
  LSessionFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LFileName := BuildReplayProviderStoreFilePath('builder_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithTLS13
      .WithVerifyNone
      .WithCertificate('tests/certificate/test_certs/signer_cert.pem')
      .WithPrivateKey('tests/certificate/test_certs/signer_key.pem')
      .WithSessionCache(True)
      .WithSessionTimeout(7200)
      .WithServerEarlyDataPolicy(sslEarlyDataServerAccept)
      .WithServerMaxEarlyDataSize(8)
      .WithServerEarlyDataReplayStoreFile(LFileName)
      .BuildServer;

    AssertTrue(LCtx <> nil,
      'Builder runtime durability test should create a FreePascal server context');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Builder runtime durability test should expose replay-ledger access seam');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Builder runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Builder runtime durability accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Builder-configured file-backed replay store should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Builder runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Builder-configured first resumed early-data attempt should still be accepted before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Builder-configured first resumed early-data attempt should still advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Builder runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Builder runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Builder runtime replay probe should exit cleanly after rejecting replay in a new process');
    finally
      LProcess.Free;
    end;
  finally
    if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
      LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFactoryConfigFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestart;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LConfig: TSSLConfig;
  LFileName: string;
  LSessionFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LFileName := BuildReplayProviderStoreFilePath('factory_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LConfig := CreateDefaultConfig(sslCtxServer);
    LConfig.LibraryType := sslFreePascal;
    LConfig.ContextType := sslCtxServer;
    LConfig.PreferredVersion := sslProtocolTLS13;
    LConfig.ProtocolVersions := [sslProtocolTLS13];
    LConfig.VerifyMode := [];
    LConfig.CertificateFile := 'tests/certificate/test_certs/signer_cert.pem';
    LConfig.PrivateKeyFile := 'tests/certificate/test_certs/signer_key.pem';
    LConfig.SessionCacheSize := 8;
    LConfig.SessionTimeout := 7200;
    Include(LConfig.Options, ssoEnableSessionCache);
    LConfig.ServerEarlyDataPolicy := sslEarlyDataServerAccept;
    LConfig.ServerMaxEarlyDataSize := 8;
    LConfig.ServerEarlyDataReplayStoreFile := LFileName;

    LCtx := TSSLFactory.CreateContext(LConfig);

    AssertTrue(LCtx <> nil,
      'Factory one-shot runtime durability test should create a FreePascal server context');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Factory one-shot runtime durability test should expose replay-ledger access seam');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Factory one-shot runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Factory one-shot runtime durability accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Factory one-shot configured file-backed replay store should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Factory one-shot runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Factory one-shot configured first resumed early-data attempt should still be accepted before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Factory one-shot configured first resumed early-data attempt should still advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Factory one-shot runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Factory one-shot runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Factory one-shot runtime replay probe should exit cleanly after rejecting replay in a new process');
    finally
      LProcess.Free;
    end;
  finally
    if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
      LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestBuilderFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestartThroughFactoryContext;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LFileName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LFileName := BuildReplayProviderStoreFilePath('builder_parent_factory_child_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LFileName, 'context_path');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildBuilderFileBackedReplayStoreServerContext(LFileName);

    AssertTrue(LCtx <> nil,
      'Mixed builder-parent/factory-child runtime durability test should create a FreePascal server context');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Mixed builder-parent/factory-child runtime durability test should expose replay-ledger access seam');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Mixed builder-parent/factory-child runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed builder-parent/factory-child accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Mixed builder-parent/factory-child runtime durability test should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Mixed builder-parent/factory-child runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Mixed builder-parent/factory-child runtime durability test should still accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Mixed builder-parent/factory-child runtime durability test should still advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Mixed builder-parent/factory-child runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Mixed builder-parent/factory-child runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_FACTORY);
      LProcess.Parameters.Add(LContextPathMarkerFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Mixed builder-parent/factory-child runtime replay probe should exit cleanly after rejecting replay in a new process');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        'Mixed builder-parent/factory-child runtime replay probe should prove the child used the requested factory public path');
    finally
      LProcess.Free;
    end;
  finally
    if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
      LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

procedure TestFactoryConfigFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestartThroughBuilderContext;
var
  LCtx: ISSLContext;
  LReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LFileName: string;
  LSessionFileName: string;
  LContextPathMarkerFileName: string;
  LSession: ISSLSession;
  LSerialized: TBytes;
  LConn: ISSLConnection;
  LEarlyConn: ISSLEarlyDataConnection;
  LAcceptStream: TScriptedEarlyDataClientStream;
  LProcess: TProcess;
begin
  LFileName := BuildReplayProviderStoreFilePath('factory_parent_builder_child_runtime_restart');
  LSessionFileName := BuildReplayProviderMarkerFilePath(LFileName, 'session.bin');
  LContextPathMarkerFileName := BuildReplayProviderMarkerFilePath(LFileName, 'context_path');
  CleanupReplayProviderStoreFiles(LFileName);
  try
    LCtx := BuildFactoryFileBackedReplayStoreServerContext(LFileName);

    AssertTrue(LCtx <> nil,
      'Mixed factory-parent/builder-child runtime durability test should create a FreePascal server context');
    AssertTrue(Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess),
      'Mixed factory-parent/builder-child runtime durability test should expose replay-ledger access seam');

    LSession := CaptureServerIssuedSession(LCtx);
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0,
      'Mixed factory-parent/builder-child runtime durability test should serialize the captured resumable session');
    WriteBytesToFile(LSessionFileName, LSerialized);

    LAcceptStream := TScriptedEarlyDataClientStream.CreateResumed(LSession, BytesOf('PING'), True);
    try
      LConn := LCtx.CreateConnection(LAcceptStream);
      AssertTrue(Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'Mixed factory-parent/builder-child accepted connection should expose early-data interface');
      AssertTrue(LConn.Accept,
        'Mixed factory-parent/builder-child runtime durability test should accept the first resumed early-data attempt before restart');
      AssertSessionReused(LConn,
        'Mixed factory-parent/builder-child runtime durability test should reuse the captured session before restart');
      if Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
        AssertTrue(LEarlyConn.GetEarlyDataStatus = sslEarlyDataAccepted,
          'Mixed factory-parent/builder-child runtime durability test should still accept the first resumed early-data attempt before restart');
      AssertTrue(LAcceptStream.ObservedServerAcceptedEarlyData,
        'Mixed factory-parent/builder-child runtime durability test should still advertise accepted early-data before restart');
    finally
      LAcceptStream.Free;
    end;

    AssertTrue(FileExists(LFileName),
      'Mixed factory-parent/builder-child runtime durability test should materialize the file-backed replay store before process restart');
    AssertTrue(FileExists(LSessionFileName),
      'Mixed factory-parent/builder-child runtime durability test should materialize the serialized session file before process restart');

    LProcess := TProcess.Create(nil);
    try
      LProcess.Executable := ParamStr(0);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_RUNTIME_REPLAY_MODE);
      LProcess.Parameters.Add(LFileName);
      LProcess.Parameters.Add(LSessionFileName);
      LProcess.Parameters.Add(TEST_REPLAY_PROVIDER_CONTEXT_PATH_BUILDER);
      LProcess.Parameters.Add(LContextPathMarkerFileName);
      LProcess.Options := [];
      LProcess.Execute;
      LProcess.WaitOnExit;
      AssertEqualsInt(0, LProcess.ExitCode,
        'Mixed factory-parent/builder-child runtime replay probe should exit cleanly after rejecting replay in a new process');
      AssertTrue(FileExists(LContextPathMarkerFileName),
        'Mixed factory-parent/builder-child runtime replay probe should prove the child used the requested builder public path');
    finally
      LProcess.Free;
    end;
  finally
    if Supports(LCtx, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess) then
      LReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayProviderStoreFiles(LFileName);
  end;
end;

begin
  InitializeDefaultReplayStoreBaselineDirectoryForTesting;

  if HandleReplayProviderChildMode then
    Halt(0);

  WriteLn('Testing FreePascal TLS 1.3 early-data contract...');

  TestClientEarlyDataAcceptedAndRejected;
  TestConnectorClientEarlyDataAcceptedAndRejected;
  TestClientEarlyDataPreconditions;
  TestServerAcceptRejectAndReplayPolicy;
  TestServerTicketIssuancePolicyAndMaxSize;
  TestServerIssueOnlyRejectsResumedEarlyData;
  TestClientConfiguredEarlyDataLimit;
  TestReplayLedgerSessionValidity;
  TestDefaultReplayLedgerTracksSessionCacheSettings;
  TestDefaultReplayStoreRejectsCrossContextReplay;
  TestDefaultReplayStoreRetainsReplayTruthAcrossProcessRestart;
  TestReplaceableReplayLedgerRejectsFirstUseEarlyData;
  TestProviderBackedReplayLedgerCoordinatesAcrossLedgers;
  TestProviderBackedReplayLedgerRejectsCrossContextReplay;
  TestStoreBackedReplayProviderPreservesReplayTruthAcrossProviderRebuild;
  TestStoreBackedReplayProviderClearsSharedTruthAcrossDisableAndReenable;
  TestStoreBackedReplayProviderEvictsOldestEntryAtCapacityAcrossRebuild;
  TestStoreBackedReplayProviderFailsClosedOnStoreFailures;
  TestStoreBackedReplayInstallHelperRejectsCrossContextReplay;
  TestStoreBackedReplayInstallHelperFailsClosedOnStoreFailures;
  TestDirectoryReplayStorePreservesReplayTruthAcrossProviderRebuild;
  TestDirectoryReplayStorePrunesExpiredPersistedEntriesAfterRebuild;
  TestDirectoryReplayStoreInstallHelperUsesReplayTruthAtRuntime;
  TestDirectoryReplayStoreFailsClosedOnCorruptEntryAtRuntime;
  TestDirectoryReplayStoreFailsClosedOnUnreadableStoreDirectoryAtRuntime;
  TestDirectoryReplayStoreCleansTempDirAfterSnapshotWriteFailure;
  TestDirectoryReplayStoreFailsClosedWhileCrossProcessLockIsHeld;
  TestDirectoryReplayStoreIgnoresOrphanLockFileAcrossProviderRebuild;
  TestDirectoryReplayStoreRecoversReplayTruthFromOrphanTempDirectoryAcrossProviderRebuild;
  TestDirectoryReplayStorePreservesTempDirResidueAcrossRepeatedReplayRejects;
  TestDirectoryReplayStoreRecoversReplayTruthFromBackupDirectoryAcrossProviderRebuild;
  TestDirectoryReplayStoreLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackup;
  TestDirectoryReplayStorePreservesExistingTruthAcrossBackupAssistedReplaceFailure;
  TestDirectoryReplayStoreRecoversReplayTruthFromBackupAfterRestoreFailure;
  TestDirectoryReplayStoreFailsClosedOnDeterministicTempPromotionRenameDeniedAndRecovers;
  TestDirectoryReplayStoreFailsClosedOnDeterministicBackupPromotionRenameDeniedAndRecovers;
  TestDirectoryReplayStoreFailsClosedOnCorruptFallbackDirectoriesAcrossProviderRebuild;
  TestDirectoryReplayStoreFailsClosedWhenCorruptTempFallbackShadowsHealthyBackupFallback;
  TestDirectoryReplayStoreFailsClosedOnFilesystemPathBlockersAndRecovers;
  TestDirectoryReplayStoreFailsClosedWhileCrossProcessLockIsHeldAtRuntime;
  TestDirectoryReplayStoreRetainsReplayTruthAcrossProcessRestartFromOrphanTempDirectory;
  TestDirectoryReplayStorePreservesTempDirResidueAcrossRepeatedReplayOnlyRestarts;
  TestDirectoryReplayStoreRetainsReplayTruthAcrossProcessRestartFromBackupDirectory;
  TestDirectoryReplayStoreLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackupAtRuntime;
  TestDirectoryReplayStorePreservesExistingTruthAcrossBackupAssistedReplaceFailureAtRuntime;
  TestDirectoryReplayStoreRecoversReplayTruthFromBackupAfterRestoreFailureAtRuntime;
  TestDirectoryReplayStoreFailsClosedOnDeterministicTempPromotionRenameDeniedAtRuntime;
  TestDirectoryReplayStoreFailsClosedOnDeterministicBackupPromotionRenameDeniedAtRuntime;
  TestDirectoryReplayStoreRetainsExistingAndAcceptedReplayTruthAcrossCrashWindowRestart;
  TestDirectoryReplayStoreFailsClosedOnCorruptFallbackDirectoriesAtRuntime;
  TestDirectoryReplayStoreFailsClosedWhenCorruptTempFallbackShadowsHealthyBackupFallbackAtRuntime;
  TestDirectoryReplayStoreFailsClosedOnFilesystemPathBlockersAtRuntime;
  TestCallbackReplayProviderFailsClosedOnProviderExceptions;
  TestCallbackReplayProviderPreservesReplayTruthAcrossProviderRebuild;
  TestCallbackReplayProviderLifecycleDoesNotWipeSharedTruth;
  TestFileBackedReplayProviderPersistsAcrossProviderRebuild;
  TestFileBackedReplayProviderLifecycleDoesNotWipePersistedTruth;
  TestManagedReplayProviderHookExceptionsStaySwallowedAndLocalGatesAuthoritative;
  TestFileBackedReplayProviderRejectsCrossContextReplay;
  TestFileBackedReplayProviderFailsClosedOnCorruptStores;
  TestFileBackedReplayProviderFailsClosedOnCorruptBackupFallbackStores;
  TestFileBackedReplayProviderFailsClosedWhileCrossProcessLockIsHeld;
  TestFileBackedReplayProviderIgnoresOrphanLockFileWithoutActiveLock;
  TestFileBackedReplayProviderRecoversReplayTruthFromOrphanTempStore;
  TestFileBackedReplayProviderFailsClosedOnCorruptOrphanTempStores;
  TestFileBackedReplayProviderFailsClosedOnFilesystemPathBlockersAndRecovers;
  TestFileBackedReplayProviderPreservesExistingReplayTruthAcrossTempPathWriteFailureAndRecovers;
  TestFileBackedReplayProviderFailsClosedOnCanonicalMainPathRenameBoundaryAndRecovers;
  TestFileBackedReplayProviderPreservesExistingTruthAcrossExistingMainReplaceFallbackFailure;
  TestFileBackedReplayProviderRecoversReplayTruthFromBackupAfterRestoreFailure;
  TestFileBackedReplayProviderLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackup;
  TestFileBackedReplayProviderPreservesExistingTruthAcrossDeterministicTempWriteOpenDeniedAndRecovers;
  TestFileBackedReplayProviderFailsClosedOnDeterministicBackupPromotionRenameDeniedAndRecovers;
  TestFileBackedReplayProviderPrunesExpiredPersistedEntriesAfterRebuild;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestart;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestartThroughBuilderContext;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossProcessRestartThroughFactoryContext;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossTinyRestartLoop;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossCrashWindowRestart;
  TestContextFileBackedReplayInstallerFailsClosedWhileCrossProcessLockIsHeldAtRuntime;
  TestContextFileBackedReplayInstallerLifecycle;
  TestContextFileBackedReplayInstallerTracksSessionCacheSettings;
  TestContextFileBackedReplayInstallerRejectsCrossContextReplay;
  TestContextFileBackedReplayInstallerRuntimeRetainsReplayTruthAcrossLocalGateToggles;
  TestContextFileBackedReplayInstallerFailsClosedOnCorruptStoresAtRuntime;
  TestContextFileBackedReplayInstallerFailsClosedOnCorruptBackupFallbackStoresAtRuntime;
  TestContextFileBackedReplayInstallerFailsClosedOnCorruptOrphanTempStoresAtRuntime;
  TestContextFileBackedReplayInstallerFailsClosedOnFilesystemPathBlockersAtRuntime;
  TestContextFileBackedReplayInstallerPreservesExistingReplayTruthAcrossTempPathWriteFailureAtRuntime;
  TestContextFileBackedReplayInstallerFailsClosedOnCanonicalMainPathRenameBoundaryAtRuntime;
  TestStoreBackedReplayInstallHelperPreservesExistingTruthAcrossExistingMainReplaceFallbackFailureAtRuntime;
  TestStoreBackedReplayInstallHelperRecoversReplayTruthFromBackupAfterRestoreFailureAtRuntime;
  TestStoreBackedReplayInstallHelperLeavesBackupResidueAfterCleanupFailureAndFailsClosedOnUndeletableStaleBackupAtRuntime;
  TestStoreBackedReplayInstallHelperPreservesExistingTruthAcrossDeterministicTempWriteOpenDeniedAtRuntime;
  TestStoreBackedReplayInstallHelperFailsClosedOnDeterministicBackupPromotionRenameDeniedAtRuntime;
  TestContextFileBackedReplayInstallerRecoversReplayTruthFromOrphanTempStoreAtRuntime;
  TestContextFileBackedReplayInstallerIgnoresOrphanLockFileWithoutActiveHolderAtRuntime;
  TestContextFileBackedReplayInstallerRuntimeSwitchesReplayTruthBoundaryAcrossStorePathReinstall;
  TestContextFileBackedReplayInstallerTreatsRelativeAndAbsoluteStorePathsAsOneBoundaryAtRuntime;
  TestContextFileBackedReplayInstallerRuntimeConvergesReplayTruthAcrossEquivalentStorePathRepresentations;
  TestContextFileBackedReplayInstallerRuntimeIsolatesReplayTruthAcrossDifferentStoreFiles;
  TestContextCustomReplayProviderInstallerLifecycle;
  TestContextCustomReplayProviderInstallerTracksSessionCacheSettings;
  TestContextCustomReplayProviderInstallerRejectsCrossContextReplay;
  TestCallbackReplayProviderInstallHelperRejectsCrossContextReplay;
  TestCallbackReplayProviderInstallHelperRuntimeRetainsReplayTruthAcrossLocalGateToggles;
  TestCallbackReplayProviderInstallHelperFailsClosedOnProviderExceptions;
  TestBuilderFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestart;
  TestFactoryConfigFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestart;
  TestBuilderFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestartThroughFactoryContext;
  TestFactoryConfigFileBackedReplayStoreRetainsReplayTruthAcrossProcessRestartThroughBuilderContext;
  TestBuilderFileBackedReplayStoreRejectsCrossContextReplayThroughFactoryContext;
  TestFactoryConfigFileBackedReplayStoreRejectsCrossContextReplayThroughBuilderContext;
  TestBuilderDirectoryReplayStoreRejectsCrossContextReplayThroughFactoryContext;
  TestFactoryConfigDirectoryReplayStoreRejectsCrossContextReplayThroughBuilderContext;
  TestPublicPathFileBackedReplayStorePrunesExpiredPersistedEntriesAcrossBuilderAndFactoryContexts;
  TestBuilderFileBackedReplayStoreRejectsCrossContextReplay;

  WriteLn('✅ FreePascal TLS 1.3 early-data checks passed');
end.
