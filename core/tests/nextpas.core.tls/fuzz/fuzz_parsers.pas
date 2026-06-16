program fuzz_parsers;

{$mode objfpc}{$H+}

{**
 * Fuzz Testing for fafafa.ssl Parsers
 *
 * Targets security-critical parsing functions:
 * - Certificate PEM/DER parsing
 * - Distinguished Name parsing
 * - URL parsing
 *
 * Run: ./fuzz_parsers [iterations]
 * Default: 5000 iterations per target
 *}

uses
  SysUtils,
  fuzz_framework,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.utils;

{ ============================================================================ }
{ Fuzz Targets                                                                  }
{ ============================================================================ }

procedure FuzzCertificatePEM(const AInput: TBytes);
var
  InputStr: string;
  Cert: ICertificate;
begin
  if Length(AInput) = 0 then Exit;
  SetString(InputStr, PAnsiChar(@AInput[0]), Length(AInput));

  try
    Cert := TCertificate.ParsePEM(InputStr);
  except
    // Expected for invalid PEM
  end;
end;

procedure FuzzCertificateDER(const AInput: TBytes);
var
  Cert: ICertificate;
begin
  if Length(AInput) = 0 then Exit;

  try
    Cert := TCertificate.ParseDER(AInput);
  except
    // Expected for invalid DER
  end;
end;

procedure FuzzDistinguishedName(const AInput: TBytes);
var
  InputStr: string;
  ParseResult: TSSLStringArray;
begin
  if Length(AInput) = 0 then Exit;
  SetString(InputStr, PAnsiChar(@AInput[0]), Length(AInput));

  try
    ParseResult := TSSLUtils.ParseDistinguishedName(InputStr);
  except
    // Expected for invalid DN
  end;
end;

procedure FuzzURLParsing(const AInput: TBytes);
var
  InputStr: string;
  Protocol, Host, Path: string;
  Port: Integer;
begin
  if Length(AInput) = 0 then Exit;
  SetString(InputStr, PAnsiChar(@AInput[0]), Length(AInput));

  try
    TSSLUtils.ParseURL(InputStr, Protocol, Host, Port, Path);
  except
    // Expected for invalid URL
  end;
end;

{ ============================================================================ }
{ ASN.1 Structure Generators                                                    }
{ ============================================================================ }

function GenerateASN1Sequence(const AContent: TBytes): TBytes;
var
  ContentLen: Integer;
begin
  ContentLen := Length(AContent);
  if ContentLen < 128 then
  begin
    SetLength(Result, 2 + ContentLen);
    Result[0] := $30;  // SEQUENCE tag
    Result[1] := ContentLen;
    if ContentLen > 0 then
      Move(AContent[0], Result[2], ContentLen);
  end
  else
  begin
    SetLength(Result, 4 + ContentLen);
    Result[0] := $30;
    Result[1] := $82;
    Result[2] := (ContentLen shr 8) and $FF;
    Result[3] := ContentLen and $FF;
    if ContentLen > 0 then
      Move(AContent[0], Result[4], ContentLen);
  end;
end;

function GeneratePEMWrapper(const ADERContent: TBytes; const ALabel: string): string;
const
  Base64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, J, Len, OutLen: Integer;
  A, B, C: Byte;
  Base64: string;
begin
  Len := Length(ADERContent);
  if Len = 0 then
  begin
    Result := '-----BEGIN ' + ALabel + '-----' + LineEnding +
              '-----END ' + ALabel + '-----';
    Exit;
  end;

  OutLen := ((Len + 2) div 3) * 4;
  SetLength(Base64, OutLen);
  J := 1;
  I := 0;

  while I < Len do
  begin
    A := ADERContent[I];
    Inc(I);
    if I < Len then B := ADERContent[I] else B := 0;
    Inc(I);
    if I < Len then C := ADERContent[I] else C := 0;
    Inc(I);

    Base64[J] := Base64Chars[A shr 2]; Inc(J);
    Base64[J] := Base64Chars[((A and $03) shl 4) or (B shr 4)]; Inc(J);
    if I - 2 < Len then
      Base64[J] := Base64Chars[((B and $0F) shl 2) or (C shr 6)]
    else
      Base64[J] := '=';
    Inc(J);
    if I - 1 < Len then
      Base64[J] := Base64Chars[C and $3F]
    else
      Base64[J] := '=';
    Inc(J);
  end;

  Result := '-----BEGIN ' + ALabel + '-----' + LineEnding +
            Base64 + LineEnding +
            '-----END ' + ALabel + '-----';
end;

procedure FuzzASN1Certificate(const AInput: TBytes);
var
  DER: TBytes;
  PEM: string;
  Cert: ICertificate;
begin
  if Length(AInput) < 4 then Exit;

  // Wrap random data as ASN.1 SEQUENCE (mimics certificate structure)
  DER := GenerateASN1Sequence(AInput);

  // Try DER parsing
  try
    Cert := TCertificate.ParseDER(DER);
  except
  end;

  // Try PEM parsing
  PEM := GeneratePEMWrapper(DER, 'CERTIFICATE');
  try
    Cert := TCertificate.ParsePEM(PEM);
  except
  end;
end;

{ ============================================================================ }
{ Main Program                                                                  }
{ ============================================================================ }

var
  Fuzzer: TFuzzer;
  Iterations: Integer;

begin
  WriteLn('================================================================');
  WriteLn('       fafafa.ssl Parser Fuzz Testing Suite                     ');
  WriteLn('================================================================');
  WriteLn;

  if ParamCount >= 1 then
    Iterations := StrToIntDef(ParamStr(1), 5000)
  else
    Iterations := 5000;

  Fuzzer := TFuzzer.Create;
  try
    Fuzzer.MaxInputSize := 2048;
    Fuzzer.MinInputSize := 1;
    Fuzzer.Verbose := False;

    WriteLn('Registering fuzz targets...');
    Fuzzer.RegisterTarget('cert_pem', @FuzzCertificatePEM);
    Fuzzer.RegisterTarget('cert_der', @FuzzCertificateDER);
    Fuzzer.RegisterTarget('asn1_cert', @FuzzASN1Certificate);
    Fuzzer.RegisterTarget('dn_parse', @FuzzDistinguishedName);
    Fuzzer.RegisterTarget('url_parse', @FuzzURLParsing);
    WriteLn;

    Fuzzer.Run(Iterations);

    Fuzzer.SaveStatsToFile('fuzz_parsers_results.txt');
    WriteLn('Results saved to: fuzz_parsers_results.txt');

  finally
    Fuzzer.Free;
  end;

  WriteLn;
  WriteLn('Parser fuzz testing complete.');
end.
