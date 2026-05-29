program test_openssl_bio;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestResult(const TestName: string; Passed: Boolean);
begin
  Write('  [', TestName, '] ... ');
  if Passed then
  begin
    WriteLn('PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(TestsFailed);
  end;
end;

procedure TestMemoryBIO;
var
  Bio: PBIO;
  Buffer: array[0..255] of AnsiChar;
  Written, Read: Integer;
  TestData: AnsiString;
begin
  WriteLn('Testing Memory BIO:');
  
  TestData := 'Hello, OpenSSL BIO!';
  
  // Test BIO_s_mem
  TestResult('BIO_s_mem function available', Assigned(BIO_s_mem));
  
  // Test BIO_new
  if Assigned(BIO_s_mem) then
  begin
    Bio := BIO_new(BIO_s_mem());
    TestResult('BIO_new(BIO_s_mem)', Assigned(Bio));
    
    if Assigned(Bio) then
    begin
      // Test BIO_write
      if Assigned(BIO_write) then
      begin
        Written := BIO_write(Bio, @TestData[1], Length(TestData));
        TestResult('BIO_write', Written = Length(TestData));
        
        // Test BIO_read
        if Assigned(BIO_read) then
        begin
          FillChar(Buffer, SizeOf(Buffer), 0);
          Read := BIO_read(Bio, @Buffer[0], SizeOf(Buffer));
          TestResult('BIO_read', Read = Length(TestData));
          
          // Test data integrity
          TestResult('Data integrity', CompareMem(@Buffer[0], @TestData[1], Length(TestData)));
        end
        else
          TestResult('BIO_read available', False);
      end
      else
        TestResult('BIO_write available', False);
      
      // Test BIO_free
      if Assigned(BIO_free) then
      begin
        BIO_free(Bio);
        TestResult('BIO_free', True);
      end;
    end;
  end;
  
  WriteLn;
end;

procedure TestMemoryBuffer;
var
  Bio: PBIO;
  Buffer: array[0..255] of AnsiChar;
  TestData: AnsiString;
  Read: Integer;
begin
  WriteLn('Testing Memory Buffer BIO:');
  
  TestData := 'BIO Memory Buffer Test';
  
  // Test BIO_new_mem_buf
  if Assigned(BIO_new_mem_buf) then
  begin
    Bio := BIO_new_mem_buf(@TestData[1], Length(TestData));
    TestResult('BIO_new_mem_buf', Assigned(Bio));
    
    if Assigned(Bio) then
    begin
      // Read from buffer
      if Assigned(BIO_read) then
      begin
        FillChar(Buffer, SizeOf(Buffer), 0);
        Read := BIO_read(Bio, @Buffer[0], SizeOf(Buffer));
        TestResult('Read from mem_buf', Read = Length(TestData));
        TestResult('Mem_buf data integrity', CompareMem(@Buffer[0], @TestData[1], Length(TestData)));
      end;
      
      if Assigned(BIO_free) then
        BIO_free(Bio);
    end;
  end
  else
    TestResult('BIO_new_mem_buf available', False);
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL BIO Module Unit Test');
  WriteLn('============================');
  WriteLn;
  
  // Load OpenSSL
  Write('Loading OpenSSL libraries... ');
  try
    LoadOpenSSLCore;
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Load BIO module
  Write('Loading BIO module... ');
  LoadOpenSSLBIO;
  if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestMemoryBIO;
    TestMemoryBuffer;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  // Print summary
  WriteLn('Test Summary:');
  WriteLn('=============');
  WriteLn('Tests Passed: ', TestsPassed);
  WriteLn('Tests Failed: ', TestsFailed);
  WriteLn('Total Tests:  ', TestsPassed + TestsFailed);
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('All tests PASSED! ✓');
  end
  else
  begin
    WriteLn;
    WriteLn('Some tests FAILED! ✗');
    Halt(1);
  end;
  
  // Cleanup
  UnloadOpenSSLBIO;
  UnloadOpenSSLCore;
end.