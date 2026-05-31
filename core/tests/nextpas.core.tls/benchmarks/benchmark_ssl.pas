program benchmark_ssl;

{$mode objfpc}{$H+}

{**
 * Performance Baseline for fafafa.ssl
 *
 * Benchmarks security-critical operations:
 * - Base64 encoding/decoding
 * - Hex encoding/decoding
 * - SHA-256 hashing (when OpenSSL available)
 *
 * Run: ./benchmark_ssl [iterations]
 * Default: 1000 iterations per benchmark
 *
 * Output:
 * - Console report with mean, P95, P99, ops/s
 * - JSON baseline file for CI regression detection
 *}

uses
  SysUtils, Classes,
  benchmark_framework;

const
  { Test data sizes }
  SMALL_DATA_SIZE = 64;
  MEDIUM_DATA_SIZE = 1024;
  LARGE_DATA_SIZE = 16384;

  { Base64 alphabet }
  Base64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

var
  { Global test data }
  GSmallData: TBytes;
  GMediumData: TBytes;
  GLargeData: TBytes;
  GBase64Small: AnsiString;
  GBase64Medium: AnsiString;
  GBase64Large: AnsiString;
  GHexSmall: AnsiString;
  GHexMedium: AnsiString;

{ ============================================================================ }
{ Pure Pascal Implementations (No OpenSSL dependency)                          }
{ ============================================================================ }

function Base64Encode(const AData: TBytes): AnsiString;
var
  I, J, Len, OutLen: Integer;
  A, B, C: Byte;
begin
  Len := Length(AData);
  if Len = 0 then
  begin
    Result := '';
    Exit;
  end;

  OutLen := ((Len + 2) div 3) * 4;
  SetLength(Result, OutLen);
  J := 1;
  I := 0;

  while I < Len do
  begin
    A := AData[I];
    Inc(I);

    if I < Len then B := AData[I] else B := 0;
    Inc(I);

    if I < Len then C := AData[I] else C := 0;
    Inc(I);

    Result[J] := Base64Chars[A shr 2];
    Inc(J);
    Result[J] := Base64Chars[((A and $03) shl 4) or (B shr 4)];
    Inc(J);

    if I - 2 < Len then
      Result[J] := Base64Chars[((B and $0F) shl 2) or (C shr 6)]
    else
      Result[J] := '=';
    Inc(J);

    if I - 1 < Len then
      Result[J] := Base64Chars[C and $3F]
    else
      Result[J] := '=';
    Inc(J);
  end;
end;

function Base64Decode(const AInput: AnsiString): TBytes;
var
  I, J, Len, OutLen: Integer;
  A, B, C, D: Integer;
  DecTable: array[0..255] of ShortInt;
  ChVal: Byte;
begin
  SetLength(Result, 0);
  if AInput = '' then Exit;

  for I := 0 to 255 do DecTable[I] := -1;
  for I := 0 to 63 do DecTable[Ord(Base64Chars[I])] := I;
  DecTable[Ord('=')] := 0;

  Len := Length(AInput);
  OutLen := (Len * 3) div 4;
  if (Len > 0) and (AInput[Len] = '=') then Dec(OutLen);
  if (Len > 1) and (AInput[Len - 1] = '=') then Dec(OutLen);
  if OutLen <= 0 then Exit;

  SetLength(Result, OutLen);
  J := 0;
  I := 1;

  while I <= Len do
  begin
    A := 0; B := 0; C := 0; D := 0;

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then A := DecTable[ChVal];
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then B := DecTable[ChVal];
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then C := DecTable[ChVal];
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then D := DecTable[ChVal];
    end;
    Inc(I);

    if J < OutLen then begin Result[J] := Byte((A shl 2) or (B shr 4)); Inc(J); end;
    if J < OutLen then begin Result[J] := Byte((B shl 4) or (C shr 2)); Inc(J); end;
    if J < OutLen then begin Result[J] := Byte((C shl 6) or D); Inc(J); end;
  end;
end;

function BytesToHex(const AData: TBytes): AnsiString;
const
  HexChars: array[0..15] of AnsiChar = '0123456789ABCDEF';
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to High(AData) do
  begin
    Result[I * 2 + 1] := HexChars[AData[I] shr 4];
    Result[I * 2 + 2] := HexChars[AData[I] and $0F];
  end;
end;

function HexToBytes(const AHex: AnsiString): TBytes;
var
  I: Integer;
  Hi, Lo: Byte;
  Ch: AnsiChar;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
  begin
    Ch := AHex[I * 2 + 1];
    case Ch of
      '0'..'9': Hi := Ord(Ch) - Ord('0');
      'A'..'F': Hi := Ord(Ch) - Ord('A') + 10;
      'a'..'f': Hi := Ord(Ch) - Ord('a') + 10;
    else
      Hi := 0;
    end;

    Ch := AHex[I * 2 + 2];
    case Ch of
      '0'..'9': Lo := Ord(Ch) - Ord('0');
      'A'..'F': Lo := Ord(Ch) - Ord('A') + 10;
      'a'..'f': Lo := Ord(Ch) - Ord('a') + 10;
    else
      Lo := 0;
    end;

    Result[I] := (Hi shl 4) or Lo;
  end;
end;

{ ============================================================================ }
{ Benchmark Procedures                                                          }
{ ============================================================================ }

procedure BenchBase64EncodeSmall;
var
  S: AnsiString;
begin
  S := Base64Encode(GSmallData);
end;

procedure BenchBase64EncodeMedium;
var
  S: AnsiString;
begin
  S := Base64Encode(GMediumData);
end;

procedure BenchBase64EncodeLarge;
var
  S: AnsiString;
begin
  S := Base64Encode(GLargeData);
end;

procedure BenchBase64DecodeSmall;
var
  B: TBytes;
begin
  B := Base64Decode(GBase64Small);
end;

procedure BenchBase64DecodeMedium;
var
  B: TBytes;
begin
  B := Base64Decode(GBase64Medium);
end;

procedure BenchBase64DecodeLarge;
var
  B: TBytes;
begin
  B := Base64Decode(GBase64Large);
end;

procedure BenchHexEncodeSmall;
var
  S: AnsiString;
begin
  S := BytesToHex(GSmallData);
end;

procedure BenchHexEncodeMedium;
var
  S: AnsiString;
begin
  S := BytesToHex(GMediumData);
end;

procedure BenchHexDecodeSmall;
var
  B: TBytes;
begin
  B := HexToBytes(GHexSmall);
end;

procedure BenchHexDecodeMedium;
var
  B: TBytes;
begin
  B := HexToBytes(GHexMedium);
end;

{ ============================================================================ }
{ Setup and Main                                                                }
{ ============================================================================ }

procedure SetupTestData;
var
  I: Integer;
begin
  // Generate random test data
  Randomize;

  SetLength(GSmallData, SMALL_DATA_SIZE);
  for I := 0 to SMALL_DATA_SIZE - 1 do
    GSmallData[I] := Random(256);

  SetLength(GMediumData, MEDIUM_DATA_SIZE);
  for I := 0 to MEDIUM_DATA_SIZE - 1 do
    GMediumData[I] := Random(256);

  SetLength(GLargeData, LARGE_DATA_SIZE);
  for I := 0 to LARGE_DATA_SIZE - 1 do
    GLargeData[I] := Random(256);

  // Pre-encode for decode benchmarks
  GBase64Small := Base64Encode(GSmallData);
  GBase64Medium := Base64Encode(GMediumData);
  GBase64Large := Base64Encode(GLargeData);

  GHexSmall := BytesToHex(GSmallData);
  GHexMedium := BytesToHex(GMediumData);
end;

var
  Benchmark: TBenchmark;
  Iterations: Integer;
  BaselineFile: string;

begin
  WriteLn('================================================================');
  WriteLn('         fafafa.ssl Performance Baseline Suite                  ');
  WriteLn('================================================================');
  WriteLn;

  // Parse command line
  if ParamCount >= 1 then
    Iterations := StrToIntDef(ParamStr(1), 1000)
  else
    Iterations := 1000;

  BaselineFile := 'baseline_' + FormatDateTime('yyyymmdd', Now) + '.json';

  // Setup
  WriteLn('Setting up test data...');
  SetupTestData;
  WriteLn('  Small:  ', SMALL_DATA_SIZE, ' bytes');
  WriteLn('  Medium: ', MEDIUM_DATA_SIZE, ' bytes');
  WriteLn('  Large:  ', LARGE_DATA_SIZE, ' bytes');
  WriteLn;

  // Create benchmark
  Benchmark := TBenchmark.Create;
  try
    Benchmark.WarmupIterations := 100;
    Benchmark.RegressionThreshold := 0.15;  // 15% threshold

    // Register benchmarks
    WriteLn('Registering benchmarks...');

    // Base64 encode
    Benchmark.RegisterTest('base64_enc_64B', @BenchBase64EncodeSmall);
    Benchmark.RegisterTest('base64_enc_1KB', @BenchBase64EncodeMedium);
    Benchmark.RegisterTest('base64_enc_16KB', @BenchBase64EncodeLarge);

    // Base64 decode
    Benchmark.RegisterTest('base64_dec_64B', @BenchBase64DecodeSmall);
    Benchmark.RegisterTest('base64_dec_1KB', @BenchBase64DecodeMedium);
    Benchmark.RegisterTest('base64_dec_16KB', @BenchBase64DecodeLarge);

    // Hex encode/decode
    Benchmark.RegisterTest('hex_enc_64B', @BenchHexEncodeSmall);
    Benchmark.RegisterTest('hex_enc_1KB', @BenchHexEncodeMedium);
    Benchmark.RegisterTest('hex_dec_64B', @BenchHexDecodeSmall);
    Benchmark.RegisterTest('hex_dec_1KB', @BenchHexDecodeMedium);

    WriteLn;

    // Run benchmarks
    Benchmark.Run(Iterations);

    // Print detailed results
    Benchmark.PrintResults;

    // Save baseline
    Benchmark.SaveBaseline(BaselineFile);
    WriteLn('Baseline saved to: ', BaselineFile);

  finally
    Benchmark.Free;
  end;

  WriteLn;
  WriteLn('Benchmark complete.');
end.
