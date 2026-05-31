program benchmark_base64_performance;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.encoding;

var
  LData: TBytes;
  LEncoded: string;
  LDecoded: TBytes;
  LStartTime, LEndTime: TDateTime;
  LEncodeTime, LDecodeTime: Int64;
  LDataSize: Integer;
  I, LIterations: Integer;
  LEncodeMBps, LDecodeMBps: Double;

begin
  WriteLn('=== Base64 Performance Benchmark ===');
  WriteLn;

  // Initialize
  TCryptoUtils.EnsureInitialized;

  // Test with 1MB of data
  LDataSize := 1024 * 1024; // 1MB
  LIterations := 10;

  WriteLn('Test Configuration:');
  WriteLn('  Data Size: ', LDataSize div 1024, ' KB');
  WriteLn('  Iterations: ', LIterations);
  WriteLn;

  // Prepare test data
  SetLength(LData, LDataSize);
  for I := 0 to LDataSize - 1 do
    LData[I] := Byte(I mod 256);

  // Benchmark Encode
  WriteLn('[1] Benchmarking Base64 Encode...');
  LStartTime := Now;
  for I := 1 to LIterations do
    LEncoded := TEncodingUtils.Base64Encode(LData);
  LEndTime := Now;
  LEncodeTime := MilliSecondsBetween(LEndTime, LStartTime);
  LEncodeMBps := (LDataSize * LIterations / 1024 / 1024) / (LEncodeTime / 1000);

  WriteLn('  Time: ', LEncodeTime, ' ms');
  WriteLn('  Speed: ', LEncodeMBps:0:2, ' MB/s');
  WriteLn('  Encoded Size: ', Length(LEncoded), ' bytes');
  WriteLn;

  // Benchmark Decode
  WriteLn('[2] Benchmarking Base64 Decode (Optimized)...');
  LStartTime := Now;
  for I := 1 to LIterations do
    LDecoded := TEncodingUtils.Base64Decode(LEncoded);
  LEndTime := Now;
  LDecodeTime := MilliSecondsBetween(LEndTime, LStartTime);
  LDecodeMBps := (LDataSize * LIterations / 1024 / 1024) / (LDecodeTime / 1000);

  WriteLn('  Time: ', LDecodeTime, ' ms');
  WriteLn('  Speed: ', LDecodeMBps:0:2, ' MB/s');
  WriteLn('  Decoded Size: ', Length(LDecoded), ' bytes');
  WriteLn;

  // Verify correctness
  WriteLn('[3] Verifying Correctness...');
  if Length(LDecoded) = Length(LData) then
  begin
    WriteLn('  ✓ Length matches: ', Length(LDecoded), ' bytes');
    if CompareMem(@LData[0], @LDecoded[0], Length(LData)) then
      WriteLn('  ✓ Content matches perfectly')
    else
      WriteLn('  ✗ Content mismatch!');
  end
  else
    WriteLn('  ✗ Length mismatch! Expected ', Length(LData), ', got ', Length(LDecoded));

  WriteLn;
  WriteLn('========================================');
  WriteLn('Performance Summary:');
  WriteLn('  Encode: ', LEncodeMBps:0:2, ' MB/s');
  WriteLn('  Decode: ', LDecodeMBps:0:2, ' MB/s');
  WriteLn('  Ratio (Decode/Encode): ', (LDecodeMBps / LEncodeMBps * 100):0:1, '%');
  WriteLn('========================================');
  WriteLn;

  // Performance assessment
  if LDecodeMBps > 50 then
  begin
    WriteLn('🎉 Excellent! Decode performance > 50 MB/s');
    WriteLn('   Optimization successful!');
  end
  else if LDecodeMBps > 20 then
  begin
    WriteLn('✓ Good! Decode performance > 20 MB/s');
    WriteLn('  Acceptable for production use');
  end
  else
  begin
    WriteLn('⚠️  Warning: Decode performance < 20 MB/s');
    WriteLn('   May need further optimization');
  end;
end.
