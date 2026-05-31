program test_bio_simple;

{******************************************************************************}
{  BIO Simple Integration Tests                                                }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestBIOMemoryBasic;
var
  bio: PBIO;
  method: PBIO_METHOD;
begin
  WriteLn;
  WriteLn('=== Memory BIO Creation and Destruction ===');

  method := BIO_s_mem();
  Runner.Check('Get memory BIO method', method <> nil);

  bio := BIO_new(method);
  Runner.Check('Create memory BIO', bio <> nil);

  if bio <> nil then
    Runner.Check('Free memory BIO', BIO_free(bio) = 1);
end;

procedure TestBIOMemoryReadWrite;
var
  bio: PBIO;
  test_data: AnsiString;
  read_buf: array[0..255] of AnsiChar;
  bytes_written, bytes_read, pending: Integer;
begin
  WriteLn;
  WriteLn('=== Memory BIO Write and Read ===');

  test_data := 'Hello BIO World!';

  bio := BIO_new(BIO_s_mem());
  Runner.Check('Create memory BIO', bio <> nil);
  if bio = nil then Exit;

  bytes_written := BIO_write(bio, PAnsiChar(test_data), Length(test_data));
  Runner.Check('Write to memory BIO', bytes_written = Length(test_data),
          Format('%d bytes written', [bytes_written]));

  pending := BIO_pending(bio);
  Runner.Check('Check pending data', pending = Length(test_data),
          Format('%d bytes pending', [pending]));

  FillChar(read_buf, SizeOf(read_buf), 0);
  bytes_read := BIO_read(bio, @read_buf[0], SizeOf(read_buf));
  Runner.Check('Read from memory BIO', bytes_read = Length(test_data),
          Format('%d bytes read', [bytes_read]));

  BIO_free(bio);
end;

procedure TestBIOMemoryPutsGets;
var
  bio: PBIO;
  test_line: AnsiString;
  read_buf: array[0..255] of AnsiChar;
  bytes_written, bytes_read: Integer;
begin
  WriteLn;
  WriteLn('=== Memory BIO write/read line test ===');

  test_line := 'Test Line';

  bio := BIO_new(BIO_s_mem());
  Runner.Check('Create memory BIO', bio <> nil);
  if bio = nil then Exit;

  // Use BIO_write instead of BIO_puts (which is not exported)
  bytes_written := BIO_write(bio, PAnsiChar(test_line), Length(test_line));
  Runner.Check('Write line data', bytes_written > 0, Format('%d bytes', [bytes_written]));

  FillChar(read_buf, SizeOf(read_buf), 0);
  bytes_read := BIO_read(bio, @read_buf[0], SizeOf(read_buf));
  Runner.Check('Read line data', bytes_read > 0, Format('%d bytes', [bytes_read]));

  BIO_free(bio);
end;

procedure TestBIOMemoryReset;
var
  bio: PBIO;
  test_data: AnsiString;
  pending: Integer;
const
  BIO_CTRL_RESET = 1;
begin
  WriteLn;
  WriteLn('=== Memory BIO Reset ===');

  test_data := 'Test Data';

  bio := BIO_new(BIO_s_mem());
  Runner.Check('Create memory BIO', bio <> nil);
  if bio = nil then Exit;

  Runner.Check('Write data', BIO_write(bio, PAnsiChar(test_data), Length(test_data)) = Length(test_data));

  pending := BIO_pending(bio);
  Runner.Check('Data pending before reset', pending = Length(test_data));

  // Use BIO_ctrl directly for reset (BIO_reset is a macro)
  Runner.Check('Reset BIO', BIO_ctrl(bio, BIO_CTRL_RESET, 0, nil) >= 0);

  pending := BIO_pending(bio);
  Runner.Check('Data pending after reset', pending = 0, Format('%d bytes', [pending]));

  BIO_free(bio);
end;

procedure TestBIOMemoryFromBuffer;
var
  bio: PBIO;
  test_data: AnsiString;
  read_buf: array[0..255] of AnsiChar;
  bytes_read: Integer;
begin
  WriteLn;
  WriteLn('=== Memory BIO from Buffer ===');

  test_data := 'Read-only buffer data';

  bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  Runner.Check('Create memory BIO from buffer', bio <> nil);
  if bio = nil then Exit;

  FillChar(read_buf, SizeOf(read_buf), 0);
  bytes_read := BIO_read(bio, @read_buf[0], SizeOf(read_buf));
  Runner.Check('Read from buffer BIO', bytes_read = Length(test_data),
          Format('%d bytes', [bytes_read]));

  // Check EOF by trying to read again (should return 0 or -1)
  bytes_read := BIO_read(bio, @read_buf[0], SizeOf(read_buf));
  Runner.Check('Check EOF (read returns <= 0)', bytes_read <= 0);

  BIO_free(bio);
end;

procedure TestBIONull;
var
  bio: PBIO;
  test_data: AnsiString;
  bytes_written: Integer;
begin
  WriteLn;
  WriteLn('=== Null BIO ===');

  test_data := 'Data to nowhere';

  bio := BIO_new(BIO_s_null());
  Runner.Check('Create null BIO', bio <> nil);
  if bio = nil then Exit;

  bytes_written := BIO_write(bio, PAnsiChar(test_data), Length(test_data));
  Runner.Check('Write to null BIO', bytes_written = Length(test_data),
          Format('%d bytes discarded', [bytes_written]));

  BIO_free(bio);
end;

procedure TestBIOChain;
var
  bio1, bio2, result_bio: PBIO;
begin
  WriteLn;
  WriteLn('=== BIO Chain (Push/Pop) ===');

  bio1 := BIO_new(BIO_s_mem());
  bio2 := BIO_new(BIO_s_mem());
  Runner.Check('Create two memory BIOs', (bio1 <> nil) and (bio2 <> nil));

  if (bio1 = nil) or (bio2 = nil) then
  begin
    if bio1 <> nil then BIO_free(bio1);
    if bio2 <> nil then BIO_free(bio2);
    Exit;
  end;

  result_bio := BIO_push(bio1, bio2);
  Runner.Check('Push bio2 onto bio1', result_bio <> nil);

  result_bio := BIO_pop(bio1);
  Runner.Check('Pop from chain', result_bio <> nil);

  BIO_free(bio1);
  BIO_free(bio2);
end;

begin
  WriteLn('BIO Module Integration Test');
  WriteLn('============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBIO]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Ensure BIO functions are loaded
    LoadOpenSSLBIO;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestBIOMemoryBasic;
    TestBIOMemoryReadWrite;
    TestBIOMemoryPutsGets;
    TestBIOMemoryReset;
    TestBIOMemoryFromBuffer;
    TestBIONull;
    TestBIOChain;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
