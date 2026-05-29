program test_encoding_base64_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.encoding,
  nextpas.core.tls.openssl.api.bio;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

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

procedure WarmupEncodingHelpers;
var
  LEncoded: string;
  LDecoded: TBytes;
begin
  LEncoded := TEncodingUtils.Base64Encode(BytesOf('abc'));
  LDecoded := TEncodingUtils.Base64Decode('YWJj');
  if (LEncoded = '') or (Length(LDecoded) <> 3) then
    raise Exception.Create('failed to warm up encoding helpers');
end;

procedure AssertControlledEncodeFailure(const AName: string);
var
  LRaised: Boolean;
  LIsCryptoError: Boolean;
  LDetail: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryEncoded: string;
begin
  LRaised := False;
  LIsCryptoError := False;
  LDetail := '';

  try
    TEncodingUtils.Base64Encode(BytesOf('abc'));
  except
    on E: Exception do
    begin
      LRaised := True;
      LIsCryptoError := E is ESSLCryptoError;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  LTryEncoded := 'sentinel';
  try
    LTryResult := TEncodingUtils.TryBase64Encode(BytesOf('abc'), LTryEncoded);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := True;
    end;
  end;

  AssertTrue(AName + ' should raise a controlled crypto error', LRaised and LIsCryptoError, LDetail);
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult, 'expected TryBase64Encode to return False');
  AssertTrue(AName + ' Try wrapper should clear output', LTryEncoded = '', 'expected TryBase64Encode output to be empty');
end;

procedure AssertControlledDecodeFailure(const AName: string);
var
  LRaised: Boolean;
  LIsCryptoError: Boolean;
  LDetail: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryDecoded: TBytes;
begin
  LRaised := False;
  LIsCryptoError := False;
  LDetail := '';

  try
    TEncodingUtils.Base64Decode('YWJj');
  except
    on E: Exception do
    begin
      LRaised := True;
      LIsCryptoError := E is ESSLCryptoError;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  SetLength(LTryDecoded, 1);
  LTryDecoded[0] := 42;
  try
    LTryResult := TEncodingUtils.TryBase64Decode('YWJj', LTryDecoded);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := True;
    end;
  end;

  AssertTrue(AName + ' should raise a controlled crypto error', LRaised and LIsCryptoError, LDetail);
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult, 'expected TryBase64Decode to return False');
  AssertTrue(AName + ' Try wrapper should clear output', Length(LTryDecoded) = 0, 'expected TryBase64Decode output to be empty');
end;

procedure TestEncodingHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LOriginalBIOPush: TBIO_push;
  LOriginalBIOFreeAll: TBIO_free_all;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIORead: TBIO_read;
begin
  WriteLn;
  WriteLn('=== Encoding Base64 BIO guard ===');

  WarmupEncodingHelpers;

  LOriginalBIOPush := BIO_push;
  LOriginalBIOFreeAll := BIO_free_all;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIORead := BIO_read;

  BIO_push := nil;
  try
    AssertControlledEncodeFailure('Base64Encode when BIO_push is unavailable');
  finally
    BIO_push := LOriginalBIOPush;
  end;

  BIO_free_all := nil;
  try
    AssertControlledEncodeFailure('Base64Encode when BIO_free_all is unavailable');
  finally
    BIO_free_all := LOriginalBIOFreeAll;
  end;

  BIO_new_mem_buf := nil;
  try
    AssertControlledDecodeFailure('Base64Decode when BIO_new_mem_buf is unavailable');
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_read := nil;
  try
    AssertControlledDecodeFailure('Base64Decode when BIO_read is unavailable');
  finally
    BIO_read := LOriginalBIORead;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Encoding Base64 BIO Contract Test');
  WriteLn('========================================');

  try
    if not Assigned(BIO_new) or
       not Assigned(BIO_f_base64) then
    begin
      try
        WarmupEncodingHelpers;
      except
        on E: Exception do
        begin
          MarkSkip('encoding base64 bio contract', 'failed to initialize encoding helpers: ' + E.Message);
        end;
      end;
    end;

    if SkippedTests = 0 then
      TestEncodingHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
