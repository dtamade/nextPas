program test_tsa_api;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.ts,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;

procedure AssertTrue(const Msg: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(Format('[TEST] %s... ', [Msg]));
  if Condition then
  begin
    WriteLn('✓ PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('✗ FAIL');
  end;
end;

procedure AssertNotNil(const Msg: string; P: Pointer);
begin
  AssertTrue(Msg, P <> nil);
end;

function CompareByteBuffers(const AData, BData: PByte; ALength: Integer): Boolean;
var
  I: Integer;
begin
  if ALength < 0 then
    Exit(False);

  if ALength = 0 then
    Exit(True);

  if (AData = nil) or (BData = nil) then
    Exit(False);

  for I := 0 to ALength - 1 do
  begin
    if AData[I] <> BData[I] then
      Exit(False);
  end;

  Result := True;
end;

procedure TestCreateTimestampRequest;
var
  Req: PTS_REQ;
  Nonce: PASN1_INTEGER;
  MsgImprint: PTS_MSG_IMPRINT;
  ImprintAlgo: Pointer;
  PolicyObj: PASN1_OBJECT;
  InvalidPolicyReq: PTS_REQ;
  Data: TBytes;
  PolicyOID: string;
  InvalidPolicyOID: string;
  AlgObj: PASN1_OBJECT;
  AlgType: Integer;
  AlgVal: Pointer;
  ImprintDigest: PASN1_OCTET_STRING;
  ImprintDigestLen: Integer;
  ImprintDigestData: PByte;
  ExpectedDigest: array[0..EVP_MAX_MD_SIZE - 1] of Byte;
  ExpectedDigestLen: Cardinal;
  DigestCtx: PEVP_MD_CTX;
  DigestMD: PEVP_MD;
begin
  WriteLn('=== Test CreateTimestampRequest ===');
  
  // Prepare data
  Data := TBytes.Create(1, 2, 3, 4, 5);
  PolicyOID := '1.2.3.4.5';
  
  // Create request
  Req := CreateTimestampRequest(Data, PolicyOID);
  
  AssertNotNil('Request created', Req);
  
  if Req <> nil then
  begin
    AssertTrue('TS_REQ_get_nonce available', Assigned(TS_REQ_get_nonce));
    if Assigned(TS_REQ_get_nonce) then
    begin
      Nonce := TS_REQ_get_nonce(Req);
      AssertNotNil('Request nonce created', Nonce);
    end;

    AssertTrue('TS_REQ_get_msg_imprint available', Assigned(TS_REQ_get_msg_imprint));
    AssertTrue('TS_MSG_IMPRINT_get_algo available', Assigned(TS_MSG_IMPRINT_get_algo));
    if Assigned(TS_REQ_get_msg_imprint) and Assigned(TS_MSG_IMPRINT_get_algo) then
    begin
      MsgImprint := TS_REQ_get_msg_imprint(Req);
      AssertNotNil('Request msg imprint created', MsgImprint);
      if MsgImprint <> nil then
      begin
        ImprintAlgo := TS_MSG_IMPRINT_get_algo(MsgImprint);
        AssertNotNil('Request msg imprint algorithm set', ImprintAlgo);

        AssertTrue('X509_ALGOR_get0 available', Assigned(X509_ALGOR_get0));
        AssertTrue('OBJ_obj2nid available', Assigned(OBJ_obj2nid));
        if Assigned(X509_ALGOR_get0) and Assigned(OBJ_obj2nid) and (ImprintAlgo <> nil) then
        begin
          AlgObj := nil;
          AlgType := -1;
          AlgVal := nil;
          X509_ALGOR_get0(@AlgObj, @AlgType, @AlgVal, ImprintAlgo);
          AssertNotNil('Request msg imprint algorithm object set', AlgObj);
          if AlgObj <> nil then
            AssertTrue('Request msg imprint algorithm is SHA256',
              OBJ_obj2nid(AlgObj) = NID_sha256);
        end;

        AssertTrue('TS_MSG_IMPRINT_get_msg available', Assigned(TS_MSG_IMPRINT_get_msg));
        AssertTrue('ASN1_STRING_length available', Assigned(ASN1_STRING_length));
        AssertTrue('ASN1_STRING_get0_data available', Assigned(ASN1_STRING_get0_data));

        if Assigned(TS_MSG_IMPRINT_get_msg) and Assigned(ASN1_STRING_length) and
          Assigned(ASN1_STRING_get0_data) then
        begin
          ImprintDigest := TS_MSG_IMPRINT_get_msg(MsgImprint);
          AssertNotNil('Request msg imprint digest set', ImprintDigest);

          if ImprintDigest <> nil then
          begin
            ImprintDigestLen := ASN1_STRING_length(ASN1_STRING(ImprintDigest));
            ImprintDigestData := ASN1_STRING_get0_data(ASN1_STRING(ImprintDigest));

            DigestMD := EVP_sha256();
            DigestCtx := EVP_MD_CTX_new();
            ExpectedDigestLen := 0;

            if (DigestMD <> nil) and (DigestCtx <> nil) then
            begin
              if (EVP_DigestInit_ex(DigestCtx, DigestMD, nil) = 1) and
                (EVP_DigestUpdate(DigestCtx, @Data[0], Length(Data)) = 1) and
                (EVP_DigestFinal_ex(DigestCtx, @ExpectedDigest[0], ExpectedDigestLen) = 1) then
              begin
                AssertTrue('Request msg imprint digest length matches SHA256',
                  ImprintDigestLen = Integer(ExpectedDigestLen));

                AssertTrue('Request msg imprint digest bytes match SHA256(Data)',
                  CompareByteBuffers(ImprintDigestData, @ExpectedDigest[0], ImprintDigestLen));
              end
              else
                AssertTrue('Failed to compute expected SHA256 digest', False);

              EVP_MD_CTX_free(DigestCtx);
            end
            else
              AssertTrue('EVP digest context setup failed', False);
          end;
        end;
      end;
    end;

    AssertTrue('TS_REQ_get_policy_id available', Assigned(TS_REQ_get_policy_id));
    if Assigned(TS_REQ_get_policy_id) then
    begin
      PolicyObj := TS_REQ_get_policy_id(Req);
      AssertNotNil('Request policy object set', PolicyObj);
    end;

    // Cleanup
    if Assigned(TS_REQ_free) then
      TS_REQ_free(Req);
  end;

  InvalidPolicyOID := '1.2.bad.3';
  InvalidPolicyReq := CreateTimestampRequest(Data, InvalidPolicyOID);
  AssertTrue('Invalid policy OID should reject request creation', InvalidPolicyReq = nil);
  if (InvalidPolicyReq <> nil) and Assigned(TS_REQ_free) then
    TS_REQ_free(InvalidPolicyReq);
end;

var
  SSLLib: ISSLLibrary;
begin
  WriteLn('========================================');
  WriteLn('TSA API Tests');
  WriteLn('========================================');
  
  try
    // Initialize OpenSSL
    SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Halt(1);
    end;
    WriteLn('OpenSSL initialized: ', SSLLib.GetVersionString);
    
    // Run tests
    TestCreateTimestampRequest;
    
    WriteLn('========================================');
    WriteLn('TSA API Test Summary');
    WriteLn('========================================');
    WriteLn(Format('Total tests: %d', [TotalTests]));
    WriteLn(Format('Passed: %d', [PassedTests]));
    WriteLn(Format('Failed: %d', [TotalTests - PassedTests]));
    
    if PassedTests = TotalTests then
      WriteLn('✅ ALL TSA API TESTS PASSED!')
    else
      Halt(1);
      
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
