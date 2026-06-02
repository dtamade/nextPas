program test_tls12_session_resume;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.session;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestTLS12SessionCreate;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LSessionID, LMasterSecret: TBytes;
  LTLS12: IFreePascalTLS12ResumptionSession;
begin
  WriteLn('TestTLS12SessionCreate');

  SetLength(LSessionID, 32);
  SetLength(LMasterSecret, 48);
  FillChar(LSessionID[0], 32, $AA);
  FillChar(LMasterSecret[0], 48, $BB);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureTLS12Resumption(
    $C02F, 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
    LSessionID, LMasterSecret,
    Now, 3600);
  LSession := LObj;

  Check(LSession.GetProtocolVersion = sslProtocolTLS12, 'Protocol is TLS 1.2');
  Check(LSession.GetCipherName = 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256', 'Cipher name');
  Check(LSession.IsValid, 'Session is valid');
  Check(LSession.IsResumable, 'Session is resumable');
  Check(LSession.GetID <> '', 'Session has ID');

  Check(Supports(LSession, IFreePascalTLS12ResumptionSession, LTLS12), 'Supports TLS12 interface');
  Check(Length(LTLS12.GetTLS12SessionID) = 32, 'Session ID is 32 bytes');
  Check(Length(LTLS12.GetTLS12MasterSecret) = 48, 'Master secret is 48 bytes');
  Check(LTLS12.GetTLS12CipherSuite = $C02F, 'Cipher suite matches');
end;

procedure TestTLS12SessionExpiry;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LSessionID, LMasterSecret: TBytes;
begin
  WriteLn('TestTLS12SessionExpiry');

  SetLength(LSessionID, 32);
  SetLength(LMasterSecret, 48);
  FillChar(LSessionID[0], 32, $CC);
  FillChar(LMasterSecret[0], 48, $DD);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureTLS12Resumption(
    $C030, 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
    LSessionID, LMasterSecret,
    IncSecond(Now, -7200), 3600);
  LSession := LObj;

  Check(not LSession.IsValid, 'Expired session is not valid');
  Check(not LSession.IsResumable, 'Expired session is not resumable');
end;

procedure TestTLS12SessionClone;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LClone: ISSLSession;
  LSessionID, LMasterSecret: TBytes;
  LTLS12: IFreePascalTLS12ResumptionSession;
begin
  WriteLn('TestTLS12SessionClone');

  SetLength(LSessionID, 32);
  SetLength(LMasterSecret, 48);
  FillChar(LSessionID[0], 32, $EE);
  FillChar(LMasterSecret[0], 48, $FF);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureTLS12Resumption(
    $C02F, 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
    LSessionID, LMasterSecret,
    Now, 3600);
  LObj.BoundServerName := 'example.com';
  LSession := LObj;

  LClone := LSession.Clone;
  Check(LClone <> nil, 'Clone is not nil');
  Check(LClone.GetProtocolVersion = sslProtocolTLS12, 'Clone protocol');
  Check(LClone.IsValid, 'Clone is valid');
  Check(LClone.IsResumable, 'Clone is resumable');

  Check(Supports(LClone, IFreePascalTLS12ResumptionSession, LTLS12), 'Clone supports TLS12');
  Check(Length(LTLS12.GetTLS12SessionID) = 32, 'Clone session ID');
  Check(Length(LTLS12.GetTLS12MasterSecret) = 48, 'Clone master secret');
end;

procedure TestTLS13SessionStillWorks;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LTicketNonce, LTicket, LPSK: TBytes;
  LResumption: IFreePascalResumptionSession;
begin
  WriteLn('TestTLS13SessionStillWorks');

  SetLength(LTicketNonce, 8);
  SetLength(LTicket, 64);
  SetLength(LPSK, 32);
  FillChar(LTicketNonce[0], 8, $11);
  FillChar(LTicket[0], 64, $22);
  FillChar(LPSK[0], 32, $33);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureResumption(
    $1301, 'TLS_AES_128_GCM_SHA256',
    LTicketNonce, LTicket, LPSK,
    7200, 12345, Now, 3600, 16384);
  LSession := LObj;

  Check(LSession.GetProtocolVersion = sslProtocolTLS13, 'TLS 1.3 protocol');
  Check(LSession.IsValid, 'TLS 1.3 session valid');
  Check(LSession.IsResumable, 'TLS 1.3 session resumable');
  Check(Supports(LSession, IFreePascalResumptionSession, LResumption), 'Supports resumption');
  Check(Length(LResumption.GetResumptionPSK) = 32, 'PSK length');
  Check(LResumption.GetMaxEarlyDataSize = 16384, 'Early data size');
end;

procedure TestTLS12SerializeDeserialize;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LRestored: TFreePascalSession;
  LRestoredIntf: ISSLSession;
  LSessionID, LMasterSecret, LData: TBytes;
  LTLS12: IFreePascalTLS12ResumptionSession;
begin
  WriteLn('TestTLS12SerializeDeserialize');

  SetLength(LSessionID, 32);
  SetLength(LMasterSecret, 48);
  FillChar(LSessionID[0], 32, $AA);
  FillChar(LMasterSecret[0], 48, $BB);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureTLS12Resumption(
    $C02F, 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
    LSessionID, LMasterSecret,
    Now, 3600);
  LObj.BoundServerName := 'test.example.com';
  LSession := LObj;

  LData := LSession.Serialize;
  Check(Length(LData) > 0, 'Serialize produces data');

  LRestored := TFreePascalSession.Create;
  Check(LRestored.Deserialize(LData), 'Deserialize succeeds');
  LRestoredIntf := LRestored;

  Check(LRestoredIntf.GetProtocolVersion = sslProtocolTLS12, 'Restored protocol');
  Check(LRestoredIntf.GetCipherName = 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256', 'Restored cipher');
  Check(LRestoredIntf.IsValid, 'Restored is valid');
  Check(LRestoredIntf.IsResumable, 'Restored is resumable');

  Check(Supports(LRestoredIntf, IFreePascalTLS12ResumptionSession, LTLS12), 'Restored supports TLS12');
  Check(Length(LTLS12.GetTLS12SessionID) = 32, 'Restored session ID length');
  Check(LTLS12.GetTLS12CipherSuite = $C02F, 'Restored cipher suite');
  LData := LTLS12.GetTLS12SessionID;
  Check(CompareMem(@LSessionID[0], @LData[0], 32), 'Session ID matches');
  LData := LTLS12.GetTLS12MasterSecret;
  Check(CompareMem(@LMasterSecret[0], @LData[0], 48), 'Master secret matches');
end;

procedure TestTLS13SerializeDeserialize;
var
  LSession: ISSLSession;
  LObj: TFreePascalSession;
  LRestored: TFreePascalSession;
  LRestoredIntf: ISSLSession;
  LTicketNonce, LTicket, LPSK, LData: TBytes;
  LResumption: IFreePascalResumptionSession;
begin
  WriteLn('TestTLS13SerializeDeserialize');

  SetLength(LTicketNonce, 8);
  SetLength(LTicket, 64);
  SetLength(LPSK, 32);
  FillChar(LTicketNonce[0], 8, $44);
  FillChar(LTicket[0], 64, $55);
  FillChar(LPSK[0], 32, $66);

  LObj := TFreePascalSession.Create;
  LObj.ConfigureResumption($1301, 'TLS_AES_128_GCM_SHA256',
    LTicketNonce, LTicket, LPSK, 7200, 99999, Now, 3600, 8192);
  LObj.BoundServerName := 'tls13.example.com';
  LSession := LObj;

  LData := LSession.Serialize;
  Check(Length(LData) > 0, 'TLS13 serialize');

  LRestored := TFreePascalSession.Create;
  Check(LRestored.Deserialize(LData), 'TLS13 deserialize');
  LRestoredIntf := LRestored;

  Check(LRestoredIntf.GetProtocolVersion = sslProtocolTLS13, 'TLS13 restored protocol');
  Check(LRestoredIntf.IsValid, 'TLS13 restored valid');
  Check(LRestoredIntf.IsResumable, 'TLS13 restored resumable');
  Check(Supports(LRestoredIntf, IFreePascalResumptionSession, LResumption), 'TLS13 supports resumption');
  Check(Length(LResumption.GetResumptionPSK) = 32, 'TLS13 PSK length');
  Check(LResumption.GetMaxEarlyDataSize = 8192, 'TLS13 early data size');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestTLS12SessionCreate;
  TestTLS12SessionExpiry;
  TestTLS12SessionClone;
  TestTLS13SessionStillWorks;
  TestTLS12SerializeDeserialize;
  TestTLS13SerializeDeserialize;

  WriteLn;
  WriteLn('TLS 1.2 Session Resume tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
