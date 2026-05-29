program test_txt_db_helper_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.txt_db;

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

function WriteTempTextFile(const AFileName, AContent: string): Boolean;
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(AFileName));
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LBytes := UTF8String(AContent);
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[1], Length(LBytes));
    Result := True;
  finally
    LStream.Free;
  end;
end;

procedure TestTXTDBHelpersShouldDegradeWhenBIOFileHelpersAreUnavailable;
var
  LOriginalBIONewFile: TBIO_new_file;
  LOriginalBIOFree: TBIO_free;
  LTempFile: string;
  LReadRaised: Boolean;
  LWriteRaised: Boolean;
  LReadDetail: string;
  LWriteDetail: string;
  LReadResult: PTXT_DB;
  LWriteResult: Boolean;
begin
  WriteLn;
  WriteLn('=== TXT_DB helper BIO guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_txt_db_helper_bio_contract.txt';
  if not WriteTempTextFile(LTempFile, 'contract-data') then
  begin
    MarkSkip('TXT_DB helper BIO guard', 'failed to create temp file');
    Exit;
  end;

  LOriginalBIONewFile := BIO_new_file;
  LOriginalBIOFree := BIO_free;
  BIO_new_file := nil;
  BIO_free := nil;

  LReadRaised := False;
  LWriteRaised := False;
  LReadDetail := '';
  LWriteDetail := '';
  LReadResult := nil;
  LWriteResult := False;

  try
    try
      LReadResult := TXTDBReadFromFile(LTempFile, 1);
    except
      on E: Exception do
      begin
        LReadRaised := True;
        LReadDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    try
      LWriteResult := TXTDBWriteToFile(PTXT_DB(Pointer(1)), LTempFile + '.out');
    except
      on E: Exception do
      begin
        LWriteRaised := True;
        LWriteDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_new_file := LOriginalBIONewFile;
    BIO_free := LOriginalBIOFree;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
    if FileExists(LTempFile + '.out') then
      DeleteFile(LTempFile + '.out');
  end;

  AssertTrue(
    'TXTDBReadFromFile should not raise when BIO file helpers are unavailable',
    not LReadRaised,
    LReadDetail
  );
  AssertTrue(
    'TXTDBReadFromFile should return nil when BIO file helpers are unavailable',
    LReadResult = nil,
    'expected nil TXT_DB result when BIO_new_file/BIO_free are unavailable'
  );
  AssertTrue(
    'TXTDBWriteToFile should not raise when BIO file helpers are unavailable',
    not LWriteRaised,
    LWriteDetail
  );
  AssertTrue(
    'TXTDBWriteToFile should return False when BIO file helpers are unavailable',
    not LWriteResult,
    'expected False write result when BIO_new_file/BIO_free are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('TXT_DB Helper BIO Contract Test');
  WriteLn('========================================');

  try
    TestTXTDBHelpersShouldDegradeWhenBIOFileHelpersAreUnavailable;

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
