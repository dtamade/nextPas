program test_http_h2_hpack;

{**
 * @desc HPACK Huffman encode/decode tests (RFC 7541 Appendix B & C).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.http.impl.h2.hpack.huffman;

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

function SpanToString(const ASpan: TH2ByteSpan): AnsiString;
begin
  if (ASpan.Ptr = nil) or (ASpan.Len <= 0) then
    Exit('');
  SetString(Result, ASpan.Ptr, ASpan.Len);
end;

procedure CheckDecoderRejectsBlock(const ABlock: AnsiString;
  const ATableSize: UInt32; const AMessage: string);
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..7] of THPackHeader;
  LViews: array[0..7] of THPackHeaderView;
begin
  LDecoder.Init(ATableSize);
  Check(not LDecoder.Decode(ABlock, LHeaders),
    AMessage + ' (Decode)');
  LDecoder.Init(ATableSize);
  Check(not LDecoder.DecodeView(ABlock, LViews),
    AMessage + ' (DecodeView)');
end;

{ ---------- Roundtrip tests ---------- }

procedure TestSingleByteRoundtrips;
var
  LInput, LEncoded, LDecoded: AnsiString;
  I: Int32;
begin
  for I := 0 to 255 do
  begin
    LInput := AnsiChar(Chr(I));
    LEncoded := H2HuffmanEncode(LInput);
    LDecoded := H2HuffmanDecode(LEncoded);
    CheckEqual(string(LInput), string(LDecoded),
      'Roundtrip failed for byte $' + IntToHex(I, 2));
  end;
end;

procedure TestRfcAppendixCStringVectors;
var
  LEncoded: AnsiString;
begin
  LEncoded := H2HuffmanEncode('www.example.com');
  CheckEqual('F1E3C2E5F23A6BA0AB90F4FF', BytesToHex(LEncoded),
    'RFC 7541 C.4.1 authority value encoding');
  CheckEqual('www.example.com', string(H2HuffmanDecode(HexToBytes(
    'F1E3C2E5F23A6BA0AB90F4FF'))),
    'RFC 7541 C.4.1 authority value decoding');

  CheckEqual('A8EB10649CBF', BytesToHex(H2HuffmanEncode('no-cache')),
    'RFC 7541 C.4.2 cache-control value encoding');
  CheckEqual('no-cache', string(H2HuffmanDecode(HexToBytes('A8EB10649CBF'))),
    'RFC 7541 C.4.2 cache-control value decoding');

  CheckEqual('25A849E95BA97D7F', BytesToHex(H2HuffmanEncode('custom-key')),
    'RFC 7541 C.4.3 custom-key encoding');
  CheckEqual('custom-key', string(H2HuffmanDecode(HexToBytes(
    '25A849E95BA97D7F'))),
    'RFC 7541 C.4.3 custom-key decoding');

  CheckEqual('25A849E95BB8E8B4BF', BytesToHex(H2HuffmanEncode('custom-value')),
    'RFC 7541 C.4.3 custom-value encoding');
  CheckEqual('custom-value', string(H2HuffmanDecode(HexToBytes(
    '25A849E95BB8E8B4BF'))),
    'RFC 7541 C.4.3 custom-value decoding');
end;

procedure TestKnownRoundtrips;
const
  TEST_STRINGS: array[0..15] of string = (
    '',
    'GET',
    'POST',
    'PUT',
    'HEAD',
    'DELETE',
    'OPTIONS',
    'https',
    'http',
    ':authority',
    ':method',
    ':path',
    ':scheme',
    ':status',
    'accept',
    'user-agent'
  );
var
  I: Int32;
  LInput, LEncoded, LDecoded: AnsiString;
begin
  for I := Low(TEST_STRINGS) to High(TEST_STRINGS) do
  begin
    LInput := AnsiString(TEST_STRINGS[I]);
    LEncoded := H2HuffmanEncode(LInput);
    LDecoded := H2HuffmanDecode(LEncoded);
    CheckEqual(TEST_STRINGS[I], string(LDecoded),
      'Roundtrip failed for "' + TEST_STRINGS[I] + '"');
  end;
end;

procedure TestEmptyString;
var
  LEncoded, LDecoded: AnsiString;
begin
  LEncoded := H2HuffmanEncode('');
  CheckEqual(Int64(0), Int64(Length(LEncoded)),
    'Empty string encodes to zero-length output');
  LDecoded := H2HuffmanDecode(LEncoded);
  CheckEqual(Int64(0), Int64(Length(LDecoded)),
    'Empty string decodes to zero-length output');
end;

procedure TestLongString;
var
  LInput: AnsiString;
  I: Int32;
  LEncoded, LDecoded: AnsiString;
begin
  { Long string that crosses many accumulator flush boundaries. }
  SetLength(LInput, 500);
  for I := 1 to 500 do
    LInput[I] := AnsiChar(Chr(65 + (I * 7) mod 26)); { only A-Z }

  LEncoded := H2HuffmanEncode(LInput);
  LDecoded := H2HuffmanDecode(LEncoded);
  CheckEqual(string(LInput), string(LDecoded),
    'Long string roundtrip failed (500 bytes, A-Z only)');
end;

procedure TestCompressionRatio;
var
  LInput, LEncoded: AnsiString;
begin
  LInput := 'www.example.com';
  LEncoded := H2HuffmanEncode(LInput);
  Check(Length(LEncoded) < Length(LInput),
    'Huffman should compress "' + string(LInput) + '" (' +
    IntToStr(Length(LEncoded)) + ' vs ' + IntToStr(Length(LInput)) + ' bytes)');
end;

{ ---------- Decode error handling ---------- }

procedure TestInvalidPaddingRaises;
var
  LBad: AnsiString;
  LRaised: Boolean;
begin
  { A single zero byte can never be valid Huffman padding }
  LBad := #0;
  LRaised := False;
  try
    H2HuffmanDecode(LBad);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'Invalid padding (#0) should raise EHttpError');
end;

procedure TestPartial1sPaddingRaises;
var
  LBad: AnsiString;
  LRaised: Boolean;
begin
  { A byte with mixed padding that doesn't lead to EOS }
  LBad := AnsiChar($F0); { 11110000: last 4 bits are not all 1s }
  LRaised := False;
  try
    H2HuffmanDecode(LBad);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'Non-1 padding should raise EHttpError');
end;

procedure TestLimitedDecode;
var
  LInput, LEncoded, LDecoded: AnsiString;
  LTruncated: Boolean;
begin
  { Use 'GET' which has clean roundtrip }
  LInput := 'GET';
  LEncoded := H2HuffmanEncode(LInput);

  { With a high limit, decode should succeed }
  LDecoded := H2HuffmanDecodeLimited(LEncoded, 100, LTruncated);
  Check(not LTruncated, 'High limit should not truncate');
  CheckEqual(string(LInput), string(LDecoded),
    'High limit decode should match');

  { With a low limit, decode should be truncated }
  LDecoded := H2HuffmanDecodeLimited(LEncoded, 2, LTruncated);
  Check(LTruncated, 'Low limit should truncate');
  CheckEqual(Int64(0), Int64(Length(LDecoded)),
    'Truncated decode should return empty string');
end;

procedure TestDecodeViewRoundtrip;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..4] of THPackHeader;
  LViews: array[0..9] of THPackHeaderView;
  LBlock: AnsiString;
begin
  LHeaders[0].Name := ':method'; LHeaders[0].Value := 'POST';
  LHeaders[1].Name := ':path'; LHeaders[1].Value := '/api/v1/users';
  LHeaders[2].Name := ':authority'; LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := 'content-type'; LHeaders[3].Value := 'application/json';
  LHeaders[4].Name := 'content-length'; LHeaders[4].Value := '42';

  LEncoder.Init;
  LBlock := LEncoder.Encode(LHeaders);
  LDecoder.Init(0);

  Check(LDecoder.DecodeView(LBlock, LViews),
    'DecodeView should decode encoder-produced block');
  CheckEqual(':method', string(SpanToString(LViews[0].Name)),
    'Header[0] name should match');
  CheckEqual('POST', string(SpanToString(LViews[0].Value)),
    'Header[0] value should match');
  CheckEqual('content-type', string(SpanToString(LViews[3].Name)),
    'Header[3] name should match');
  CheckEqual('application/json', string(SpanToString(LViews[3].Value)),
    'Header[3] value should match');
end;

procedure TestDecodeViewRawInlineNameValue;
var
  LDecoder: THPackDecoder;
  LViews: array[0..1] of THPackHeaderView;
  LBlock: AnsiString;
begin
  LBlock := AnsiString(#0#3'foo'#3'bar');
  LDecoder.Init(0);

  Check(LDecoder.DecodeView(LBlock, LViews),
    'DecodeView should decode raw inline name/value literal');
  CheckEqual('foo', string(SpanToString(LViews[0].Name)),
    'Inline raw name should match');
  CheckEqual('bar', string(SpanToString(LViews[0].Value)),
    'Inline raw value should match');

  LBlock := AnsiString(#0#$81#0#0);
  Check(not LDecoder.DecodeView(LBlock, LViews),
    'DecodeView should reject invalid Huffman name padding');
end;

procedure TestDecodeViewDynamicTableReuse;
var
  LDecoder: THPackDecoder;
  LViews: array[0..1] of THPackHeaderView;
  LLiteralBlock: AnsiString;
  LIndexedBlock: AnsiString;
begin
  LLiteralBlock := AnsiString(#64#3'foo'#3'bar');
  LIndexedBlock := AnsiString(#190);
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);

  Check(LDecoder.DecodeView(LLiteralBlock, LViews),
    'DecodeView should accept incremental-indexing literal');
  CheckEqual('foo', string(SpanToString(LViews[0].Name)),
    'Indexed literal name should match');
  CheckEqual('bar', string(SpanToString(LViews[0].Value)),
    'Indexed literal value should match');

  Check(LDecoder.DecodeView(LIndexedBlock, LViews),
    'DecodeView should resolve dynamic-table indexed header');
  CheckEqual('foo', string(SpanToString(LViews[0].Name)),
    'Dynamic-table name should match');
  CheckEqual('bar', string(SpanToString(LViews[0].Value)),
    'Dynamic-table value should match');
end;

procedure TestRejectsDynamicTableSizeUpdateAfterHeaderRepresentation;
begin
  CheckDecoderRejectsBlock(AnsiString(#0#3'foo'#3'bar'#$20),
    HPACK_DEFAULT_DYNAMIC_TABLE_SIZE,
    'Dynamic table size update after header representation must be rejected');
end;

procedure TestRejectsDynamicTableSizeUpdateAboveMax;
begin
  CheckDecoderRejectsBlock(AnsiString(#$3F#$2A), 32,
    'Dynamic table size update above negotiated maximum must be rejected');
end;

procedure TestRejectsDynamicTableSizeUpdateUInt32Overflow;
begin
  CheckDecoderRejectsBlock(AnsiString(#$3F#$80#$80#$80#$80#$10), High(UInt32),
    'Dynamic table size update integer overflow must be rejected');
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.hpack') do
  begin
    { Roundtrip tests }
    Run('RFC Appendix C string vectors', @TestRfcAppendixCStringVectors);
    Run('Known roundtrips', @TestKnownRoundtrips);
    Run('Single byte roundtrips', @TestSingleByteRoundtrips);
    Run('Empty string', @TestEmptyString);
    Run('Long string (500 A-Z)', @TestLongString);
    Run('Compression ratio', @TestCompressionRatio);

    { Error handling }
    Run('Invalid padding raises', @TestInvalidPaddingRaises);
    Run('Partial 1s padding raises', @TestPartial1sPaddingRaises);
    Run('Limited decode truncation', @TestLimitedDecode);
    Run('DecodeView roundtrip', @TestDecodeViewRoundtrip);
    Run('DecodeView raw inline name/value', @TestDecodeViewRawInlineNameValue);
    Run('DecodeView dynamic table reuse', @TestDecodeViewDynamicTableReuse);
    Run('Reject dynamic table size update after header representation',
      @TestRejectsDynamicTableSizeUpdateAfterHeaderRepresentation);
    Run('Reject dynamic table size update above negotiated max',
      @TestRejectsDynamicTableSizeUpdateAboveMax);
    Run('Reject dynamic table size update UInt32 overflow',
      @TestRejectsDynamicTableSizeUpdateUInt32Overflow);

    Summary;
  end;
end.
