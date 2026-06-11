program test_http_h2_hpack_block;

{**
 * @desc HPACK header-block tests (RFC 7541 Appendix C request examples).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.testing,
  nextpas.core.text.conv;

function HexNibble(const ACh: Char): Byte;
begin
  case ACh of
    '0'..'9':
      Result := Ord(ACh) - Ord('0');
    'a'..'f':
      Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F':
      Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): AnsiString;
var
  LI: SizeInt;
  LOut: SizeInt;
begin
  SetLength(Result, Length(AHex) div 2);
  LOut := 1;
  LI := 1;
  while LI < Length(AHex) do
  begin
    Result[LOut] := AnsiChar((HexNibble(AHex[LI]) shl 4) or
      HexNibble(AHex[LI + 1]));
    Inc(LOut);
    Inc(LI, 2);
  end;
end;

function BytesToHex(const AData: AnsiString): string;
var
  LI: SizeInt;
begin
  Result := '';
  for LI := 1 to Length(AData) do
    Result := Result + IntToHex(Byte(AData[LI]), 2);
end;

procedure CheckFirstRequestHeaders(const AHeaders: array of THPackHeader);
begin
  CheckEqual(':method', string(AHeaders[0].Name), 'header 0 name');
  CheckEqual('GET', string(AHeaders[0].Value), 'header 0 value');
  CheckEqual(':scheme', string(AHeaders[1].Name), 'header 1 name');
  CheckEqual('http', string(AHeaders[1].Value), 'header 1 value');
  CheckEqual(':path', string(AHeaders[2].Name), 'header 2 name');
  CheckEqual('/', string(AHeaders[2].Value), 'header 2 value');
  CheckEqual(':authority', string(AHeaders[3].Name), 'header 3 name');
  CheckEqual('www.example.com', string(AHeaders[3].Value), 'header 3 value');
end;

procedure TestDecodeFirstRequestWithoutHuffman;
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..3] of THPackHeader;
begin
  LDecoder.Init;
  Check(LDecoder.Decode(HexToBytes(
    '828684410F7777772E6578616D706C652E636F6D'), LHeaders),
    'RFC 7541 C.3.1 decode should succeed');
  CheckFirstRequestHeaders(LHeaders);
end;

procedure TestDecodeFirstRequestWithHuffman;
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..3] of THPackHeader;
begin
  LDecoder.Init;
  Check(LDecoder.Decode(HexToBytes(
    '828684418CF1E3C2E5F23A6BA0AB90F4FF'), LHeaders),
    'RFC 7541 C.4.1 decode should succeed');
  CheckFirstRequestHeaders(LHeaders);
end;

procedure TestEncodeFirstRequestWithHuffman;
var
  LEncoder: THPackEncoder;
  LHeaders: array[0..3] of THPackHeader;
  LEncoded: AnsiString;
begin
  LEncoder.Init;
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':scheme';
  LHeaders[1].Value := 'http';
  LHeaders[2].Name := ':path';
  LHeaders[2].Value := '/';
  LHeaders[3].Name := ':authority';
  LHeaders[3].Value := 'www.example.com';
  LEncoded := LEncoder.Encode(LHeaders);
  CheckEqual('828684418CF1E3C2E5F23A6BA0AB90F4FF', BytesToHex(LEncoded),
    'RFC 7541 C.4.1 exact encoded block');
end;

procedure TestDynamicTableCanReferenceDecodedEntry;
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..3] of THPackHeader;
  LIndexed: array[0..0] of THPackHeader;
begin
  LDecoder.Init;
  Check(LDecoder.Decode(HexToBytes(
    '828684418CF1E3C2E5F23A6BA0AB90F4FF'), LHeaders),
    'initial decode should succeed');
  Check(LDecoder.Decode(HexToBytes('BE'), LIndexed),
    'dynamic index 62 should decode');
  CheckEqual(':authority', string(LIndexed[0].Name), 'dynamic name');
  CheckEqual('www.example.com', string(LIndexed[0].Value), 'dynamic value');
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.hpack') do
  begin
    Run('Decode first request without Huffman',
      @TestDecodeFirstRequestWithoutHuffman);
    Run('Decode first request with Huffman',
      @TestDecodeFirstRequestWithHuffman);
    Run('Encode first request with Huffman',
      @TestEncodeFirstRequestWithHuffman);
    Run('Dynamic table can reference decoded entry',
      @TestDynamicTableCanReferenceDecodedEntry);
    Summary;
  end;
end.
