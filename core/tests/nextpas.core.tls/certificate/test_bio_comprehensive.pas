program test_bio_comprehensive;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.api.bio;

var
  TestsPassed, TestsFailed: Integer;

procedure RunTest(const TestName: string; Passed: Boolean);
begin
  if Passed then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure Test_BIO_new_mem_buf;
var
  bio: PBIO;
  data: AnsiString;
begin
  data := 'Hello OpenSSL BIO!';
  bio := BIO_new_mem_buf(PAnsiChar(data), Length(data));
  RunTest('BIO_new_mem_buf创建内存BIO', bio <> nil);
  if bio <> nil then
    BIO_free(bio);
end;

procedure Test_BIO_s_mem;
var
  bio: PBIO;
  written: Integer;
  data: AnsiString;
begin
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    data := 'Test data for memory BIO';
    written := BIO_write(bio, PAnsiChar(data), Length(data));
    RunTest('BIO_write写入数据', written = Length(data));
    BIO_free(bio);
  end
  else
    RunTest('BIO_write写入数据', False);
end;

procedure Test_BIO_read_write;
var
  bio: PBIO;
  written, read_count: Integer;
  write_data, read_data: AnsiString;
  buffer: array[0..255] of AnsiChar;
begin
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    write_data := 'OpenSSL BIO Read/Write Test';
    written := BIO_write(bio, PAnsiChar(write_data), Length(write_data));
    
    FillChar(buffer, SizeOf(buffer), 0);
    read_count := BIO_read(bio, @buffer[0], SizeOf(buffer));
    
    SetString(read_data, buffer, read_count);
    RunTest('BIO读写数据一致性', read_data = write_data);
    
    BIO_free(bio);
  end
  else
    RunTest('BIO读写数据一致性', False);
end;

procedure Test_BIO_gets_puts;
var
  bio: PBIO;
  test_str: AnsiString;
  buffer: array[0..255] of AnsiChar;
  read_str: AnsiString;
begin
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    test_str := 'BIO_puts test string';
    BIO_puts(bio, PAnsiChar(test_str));
    
    FillChar(buffer, SizeOf(buffer), 0);
    BIO_gets(bio, @buffer[0], SizeOf(buffer));
    
    read_str := string(buffer);
    RunTest('BIO_puts/gets字符串操作', Pos(test_str, read_str) > 0);
    
    BIO_free(bio);
  end
  else
    RunTest('BIO_puts/gets字符串操作', False);
end;

procedure Test_BIO_ctrl_pending;
var
  bio: PBIO;
  data: AnsiString;
  pending: Integer;
begin
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    data := 'Test pending data';
    BIO_write(bio, PAnsiChar(data), Length(data));
    
    pending := BIO_ctrl_pending(bio);
    RunTest('BIO_ctrl_pending检测待读取数据', pending = Length(data));
    
    BIO_free(bio);
  end
  else
    RunTest('BIO_ctrl_pending检测待读取数据', False);
end;

procedure Test_BIO_reset;
var
  bio: PBIO;
  data: AnsiString;
  pending_before, pending_after: Integer;
begin
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    data := 'Data to reset';
    BIO_write(bio, PAnsiChar(data), Length(data));
    pending_before := BIO_ctrl_pending(bio);
    
    BIO_reset(bio);
    pending_after := BIO_ctrl_pending(bio);
    
    RunTest('BIO_reset重置BIO', (pending_before > 0) and (pending_after = 0));
    
    BIO_free(bio);
  end
  else
    RunTest('BIO_reset重置BIO', False);
end;

begin
  WriteLn('========================================');
  WriteLn('  OpenSSL BIO Module Test');
  WriteLn('========================================');
  WriteLn;
  
  TestsPassed := 0;
  TestsFailed := 0;
  
  if not LoadOpenSSLLibrary then
  begin
    WriteLn('ERROR: 无法加载 OpenSSL 库');
    Halt(1);
  end;
  
  try
    WriteLn('运行 BIO 测试...');
    WriteLn;
    
    Test_BIO_new_mem_buf;
    Test_BIO_s_mem;
    Test_BIO_read_write;
    Test_BIO_gets_puts;
    Test_BIO_ctrl_pending;
    Test_BIO_reset;
    
    WriteLn;
    WriteLn('========================================');
    WriteLn('  测试结果');
    WriteLn('========================================');
    WriteLn('通过: ', TestsPassed);
    WriteLn('失败: ', TestsFailed);
    WriteLn('总计: ', TestsPassed + TestsFailed);
    if (TestsPassed + TestsFailed) > 0 then
      WriteLn('成功率: ', ((TestsPassed * 100) div (TestsPassed + TestsFailed)):3, '%');
    WriteLn;
    
    if TestsFailed = 0 then
    begin
      WriteLn('✓ 所有测试通过!');
      Halt(0);
    end
    else
    begin
      WriteLn('✗ 部分测试失败!');
      Halt(1);
    end;
    
  finally
    UnloadOpenSSLLibrary;
  end;
end.
