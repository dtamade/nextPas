program bench_aesgcm;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, DateUtils, nextpas.core.tls.crypto.aesgcm, nextpas.core.tls.crypto.aesni;

const
  ITERATIONS = 10000;
  DATA_SIZE = 1400; // typical TLS record payload

var
  LKey128, LKey256, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag, LDecrypted: TBytes;
  LStart: TDateTime;
  LElapsed: Int64;
  I: Integer;
begin
  WriteLn('=== AES-GCM Benchmark ===');
  WriteLn('AES-NI available: ', IsAESNIAvailable);
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Payload: ', DATA_SIZE, ' bytes');
  WriteLn;

  SetLength(LKey128, 16);
  SetLength(LIV, 12);
  SetLength(LPlaintext, DATA_SIZE);
  SetLength(LAAD, 13);
  for I := 0 to 15 do LKey128[I] := Byte(I);
  for I := 0 to 11 do LIV[I] := Byte(I + $10);
  for I := 0 to DATA_SIZE - 1 do LPlaintext[I] := Byte(I mod 256);
  for I := 0 to 12 do LAAD[I] := Byte(I + $20);

  // Warmup
  PurePascalAESGCMEncrypt(LKey128, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  PurePascalAESGCMDecrypt(LKey128, LIV, LCiphertext, LTag, LAAD, LDecrypted);

  // Benchmark AES-128 encrypt (uses AES-NI if available)
  LStart := Now;
  for I := 1 to ITERATIONS do
    PurePascalAESGCMEncrypt(LKey128, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  LElapsed := MilliSecondsBetween(Now, LStart);
  WriteLn('AES-128-GCM Encrypt (AES-NI): ', LElapsed, ' ms / ', ITERATIONS, ' ops');
  if LElapsed > 0 then
    WriteLn('  Throughput: ', (Int64(ITERATIONS) * DATA_SIZE * 1000) div (LElapsed * 1024 * 1024), ' MB/s');

  // Benchmark AES-256 encrypt (always pure Pascal AES)
  SetLength(LKey256, 32);
  for I := 0 to 31 do LKey256[I] := Byte(I);
  LStart := Now;
  for I := 1 to ITERATIONS do
    PurePascalAESGCMEncrypt(LKey256, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  LElapsed := MilliSecondsBetween(Now, LStart);
  WriteLn('AES-256-GCM Encrypt (Pascal):  ', LElapsed, ' ms / ', ITERATIONS, ' ops');
  if LElapsed > 0 then
    WriteLn('  Throughput: ', (Int64(ITERATIONS) * DATA_SIZE * 1000) div (LElapsed * 1024 * 1024), ' MB/s');

  // Benchmark AES-128 decrypt
  PurePascalAESGCMEncrypt(LKey128, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  LStart := Now;
  for I := 1 to ITERATIONS do
    PurePascalAESGCMDecrypt(LKey128, LIV, LCiphertext, LTag, LAAD, LDecrypted);
  LElapsed := MilliSecondsBetween(Now, LStart);
  WriteLn('AES-128-GCM Decrypt (AES-NI): ', LElapsed, ' ms / ', ITERATIONS, ' ops');
  if LElapsed > 0 then
    WriteLn('  Throughput: ', (Int64(ITERATIONS) * DATA_SIZE * 1000) div (LElapsed * 1024 * 1024), ' MB/s');

  WriteLn;
  WriteLn('Done.');
end.
