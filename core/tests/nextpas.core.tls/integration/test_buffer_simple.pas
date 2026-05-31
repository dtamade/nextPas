program test_buffer_simple;

{******************************************************************************}
{  Buffer Simple Integration Tests                                             }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.buffer,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestBufferCreateDestroy;
var
  buf: PBUF_MEM;
begin
  WriteLn;
  WriteLn('=== Buffer Creation and Destruction ===');

  buf := BUF_MEM_new();
  Runner.Check('Create buffer', buf <> nil);

  if buf <> nil then
  begin
    Runner.Check('Initial length is zero', buf^.length = 0);
    BUF_MEM_free(buf);
    Runner.Check('Free buffer', True);
  end;
end;

procedure TestBufferGrow;
var
  buf: PBUF_MEM;
  result_size: NativeUInt;
begin
  WriteLn;
  WriteLn('=== Buffer Growth ===');

  buf := BUF_MEM_new();
  Runner.Check('Create buffer', buf <> nil);
  if buf = nil then Exit;

  result_size := BUF_MEM_grow(buf, 100);
  Runner.Check('Grow buffer to 100 bytes', result_size > 0, Format('Size: %d', [result_size]));

  Runner.Check('Buffer length >= 100', buf^.length >= 100, Format('Length: %d', [buf^.length]));

  result_size := BUF_MEM_grow(buf, 200);
  Runner.Check('Grow buffer to 200 bytes', result_size > 0, Format('Size: %d', [result_size]));

  BUF_MEM_free(buf);
end;

procedure TestBufferGrowClean;
var
  buf: PBUF_MEM;
  result_size: NativeUInt;
  i: Integer;
  all_zero: Boolean;
begin
  WriteLn;
  WriteLn('=== Buffer Clean Growth ===');

  buf := BUF_MEM_new();
  Runner.Check('Create buffer', buf <> nil);
  if buf = nil then Exit;

  result_size := BUF_MEM_grow_clean(buf, 50);
  Runner.Check('Grow buffer cleanly to 50 bytes', result_size > 0, Format('Size: %d', [result_size]));

  all_zero := True;
  for i := 0 to 49 do
    if buf^.data[i] <> #0 then
    begin
      all_zero := False;
      Break;
    end;

  Runner.Check('Buffer is zeroed', all_zero);

  BUF_MEM_free(buf);
end;

procedure TestBufferWriteData;
var
  buf: PBUF_MEM;
  test_data: AnsiString;
  i: Integer;
  match: Boolean;
begin
  WriteLn;
  WriteLn('=== Buffer Data Writing ===');

  test_data := 'Hello Buffer!';

  buf := BUF_MEM_new();
  Runner.Check('Create buffer', buf <> nil);
  if buf = nil then Exit;

  Runner.Check('Grow buffer', BUF_MEM_grow(buf, Length(test_data)) > 0);

  Move(test_data[1], buf^.data^, Length(test_data));
  buf^.length := Length(test_data);

  match := True;
  for i := 1 to Length(test_data) do
    if buf^.data[i-1] <> test_data[i] then
    begin
      match := False;
      Break;
    end;

  Runner.Check('Verify written data', match, 'Content: ' + Copy(AnsiString(buf^.data), 1, buf^.length));

  BUF_MEM_free(buf);
end;

procedure TestBufferStrDup;
var
  original: AnsiString;
  duplicate: PAnsiChar;
begin
  WriteLn;
  WriteLn('=== String Duplication ===');

  if not Assigned(BUF_strdup) then
  begin
    WriteLn('SKIPPED (BUF_strdup not available)');
    Exit;
  end;

  original := 'Test String';

  duplicate := BUF_strdup(PAnsiChar(original));
  Runner.Check('Duplicate string', duplicate <> nil);

  if duplicate <> nil then
    Runner.Check('Verify duplicate content', AnsiString(duplicate) = original,
            'Duplicate: ' + AnsiString(duplicate));
end;

procedure TestBufferMemDup;
var
  original: array[0..9] of Byte = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
  duplicate: PByte;
  i: Integer;
  match: Boolean;
begin
  WriteLn;
  WriteLn('=== Memory Duplication ===');

  if not Assigned(BUF_memdup) then
  begin
    WriteLn('SKIPPED (BUF_memdup not available)');
    Exit;
  end;

  duplicate := BUF_memdup(@original[0], SizeOf(original));
  Runner.Check('Duplicate memory', duplicate <> nil);

  if duplicate <> nil then
  begin
    match := True;
    for i := 0 to 9 do
      if duplicate[i] <> original[i] then
      begin
        match := False;
        Break;
      end;

    Runner.Check('Verify duplicate content', match);
  end;
end;

procedure TestBufferReverse;
var
  input: array[0..4] of Byte = (1, 2, 3, 4, 5);
  output: array[0..4] of Byte;
  expected: array[0..4] of Byte = (5, 4, 3, 2, 1);
  i: Integer;
  match: Boolean;
begin
  WriteLn;
  WriteLn('=== Buffer Reverse ===');

  if not Assigned(BUF_reverse) then
  begin
    WriteLn('SKIPPED (BUF_reverse not available)');
    Exit;
  end;

  FillChar(output, SizeOf(output), 0);
  BUF_reverse(@output[0], @input[0], 5);

  match := True;
  for i := 0 to 4 do
    if output[i] <> expected[i] then
    begin
      match := False;
      Break;
    end;

  Runner.Check('Reverse buffer', match, 'Input: 1,2,3,4,5 -> Output: 5,4,3,2,1');
end;

begin
  WriteLn('Buffer Module Integration Test');
  WriteLn('===============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Load Buffer module
    LoadBufferModule(GetCryptoLibHandle);
    if not Assigned(BUF_MEM_new) then
    begin
      WriteLn('ERROR: Could not load Buffer functions');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestBufferCreateDestroy;
    TestBufferGrow;
    TestBufferGrowClean;
    TestBufferWriteData;
    TestBufferStrDup;
    TestBufferMemDup;
    TestBufferReverse;

    Runner.PrintSummary;
    UnloadBufferModule;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
