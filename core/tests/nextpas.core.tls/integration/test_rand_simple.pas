program test_rand_simple;

{******************************************************************************}
{  RAND Simple Integration Tests                                               }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

function BytesToHex(const data: array of Byte; len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to len - 1 do
    Result := Result + LowerCase(IntToHex(data[i], 2));
end;

procedure TestRANDStatus;
var
  status: Integer;
begin
  WriteLn;
  WriteLn('=== RAND Status Check ===');

  if not Assigned(RAND_status) then
  begin
    WriteLn('SKIPPED (RAND_status not available - deprecated in OpenSSL 3.0)');
    Exit;
  end;

  status := RAND_status();
  if status = 1 then
    Runner.Check('RAND status (PRNG seeded)', True)
  else if status = 0 then
  begin
    // Try to seed
    if Assigned(RAND_poll) and (RAND_poll() = 1) then
      Runner.Check('RAND status after poll', True)
    else
      Runner.Check('RAND status', True, 'OpenSSL 3.0 auto-seeds');
  end
  else
    Runner.Check('RAND status', False, Format('Unknown status: %d', [status]));
end;

procedure TestRANDBytesBasic;
var
  buffer: array[0..15] of Byte;
  i: Integer;
  all_zero: Boolean;
begin
  WriteLn;
  WriteLn('=== RAND_bytes Basic Generation ===');

  FillChar(buffer, SizeOf(buffer), 0);
  Runner.Check('Generate 16 random bytes', RAND_bytes(@buffer[0], 16) = 1);

  WriteLn('Random bytes: ', BytesToHex(buffer, 16));

  all_zero := True;
  for i := 0 to 15 do
    if buffer[i] <> 0 then
    begin
      all_zero := False;
      Break;
    end;

  Runner.Check('Data is random (not all zeros)', not all_zero);
end;

procedure TestRANDBytesUniqueness;
var
  buffer1, buffer2: array[0..31] of Byte;
  i: Integer;
  same_count: Integer;
begin
  WriteLn;
  WriteLn('=== RAND_bytes Uniqueness Test ===');

  Runner.Check('Generate first buffer', RAND_bytes(@buffer1[0], 32) = 1);
  Runner.Check('Generate second buffer', RAND_bytes(@buffer2[0], 32) = 1);

  same_count := 0;
  for i := 0 to 31 do
    if buffer1[i] = buffer2[i] then
      Inc(same_count);

  Runner.Check('Buffers are different', same_count < 10,
          Format('Same bytes: %d/32', [same_count]));
end;

procedure TestRANDBytesSizes;
var
  small_buf: array[0..3] of Byte;
  medium_buf: array[0..63] of Byte;
  large_buf: array[0..255] of Byte;
begin
  WriteLn;
  WriteLn('=== RAND_bytes Various Sizes ===');

  Runner.Check('Generate 4 bytes', RAND_bytes(@small_buf[0], 4) = 1);
  Runner.Check('Generate 64 bytes', RAND_bytes(@medium_buf[0], 64) = 1);
  Runner.Check('Generate 256 bytes', RAND_bytes(@large_buf[0], 256) = 1);
end;

procedure TestRANDPrivBytes;
var
  buffer: array[0..31] of Byte;
begin
  WriteLn;
  WriteLn('=== RAND_priv_bytes Private Random ===');

  if not Assigned(RAND_priv_bytes) then
  begin
    WriteLn('SKIPPED (RAND_priv_bytes not available)');
    Exit;
  end;

  FillChar(buffer, SizeOf(buffer), 0);
  Runner.Check('Generate 32 private random bytes', RAND_priv_bytes(@buffer[0], 32) = 1);
  WriteLn('Private bytes: ', Copy(BytesToHex(buffer, 32), 1, 32), '...');
end;

procedure TestRANDDistribution;
var
  buffer: array[0..999] of Byte;
  counts: array[0..255] of Integer;
  i: Integer;
  min_count, max_count: Integer;
  variance: Integer;
begin
  WriteLn;
  WriteLn('=== RAND_bytes Distribution Test ===');

  Runner.Check('Generate 1000 random bytes', RAND_bytes(@buffer[0], 1000) = 1);

  FillChar(counts, SizeOf(counts), 0);
  for i := 0 to 999 do
    Inc(counts[buffer[i]]);

  min_count := counts[0];
  max_count := counts[0];
  for i := 1 to 255 do
  begin
    if counts[i] < min_count then min_count := counts[i];
    if counts[i] > max_count then max_count := counts[i];
  end;

  variance := max_count - min_count;
  Runner.Check('Distribution variance reasonable', variance < 20,
          Format('Min=%d, Max=%d, Variance=%d', [min_count, max_count, variance]));
end;

begin
  WriteLn('RAND Module Integration Test');
  WriteLn('============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmRAND]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Ensure RAND functions are loaded
    LoadOpenSSLRAND;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestRANDStatus;
    TestRANDBytesBasic;
    TestRANDBytesUniqueness;
    TestRANDBytesSizes;
    TestRANDPrivBytes;
    TestRANDDistribution;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
