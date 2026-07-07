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
  nextpas.core.test,
  nextpas.core.http.impl.h2.hpack.huffman;

var
  T: TTestSuite;

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

{ ---------- Encoder tests ---------- }

procedure TestEncoderBasicRoundtrip;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..3] of THPackHeader;
  LDecoded: array[0..3] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':path';
  LHeaders[1].Value := '/index.html';
  LHeaders[2].Name := ':scheme';
  LHeaders[2].Value := 'https';
  LHeaders[3].Name := ':authority';
  LHeaders[3].Value := 'www.example.com';
  LBlock := LEncoder.Encode(LHeaders);
  Check(Length(LBlock) > 0, 'encoder produces non-empty block');
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  Check(LDecoder.Decode(LBlock, LDecoded), 'decoder accepts encoder block');
  CheckEqual(':method', string(LDecoded[0].Name), 'decoded method name');
  CheckEqual('GET', string(LDecoded[0].Value), 'decoded method value');
  CheckEqual(':path', string(LDecoded[1].Name), 'decoded path name');
  CheckEqual('/index.html', string(LDecoded[1].Value), 'decoded path value');
end;

procedure TestEncoderStaticTableLookup;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LDecoded: array[0..0] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LBlock := LEncoder.Encode(LHeaders);
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  Check(LDecoder.Decode(LBlock, LDecoded), 'static table decode');
  CheckEqual(':method', string(LDecoded[0].Name), 'static table method name');
  CheckEqual('GET', string(LDecoded[0].Value), 'static table method value');
end;

procedure TestEncoderDynamicTableEviction;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LDecoded: array[0..0] of THPackHeader;
  LBlock: AnsiString;
  I: Int32;
begin
  LEncoder.Init(64);
  LDecoder.Init(64);
  for I := 0 to 9 do
  begin
    LHeaders[0].Name := AnsiString('x-custom-' + IntToStr(I));
    LHeaders[0].Value := AnsiString('value-' + IntToStr(I));
    LBlock := LEncoder.Encode(LHeaders);
    Check(LDecoder.Decode(LBlock, LDecoded), 'eviction decode ' + IntToStr(I));
    CheckEqual(string(LHeaders[0].Name), string(LDecoded[0].Name),
      'eviction name ' + IntToStr(I));
    CheckEqual(string(LHeaders[0].Value), string(LDecoded[0].Value),
      'eviction value ' + IntToStr(I));
  end;
end;

procedure TestEncoderSetDynamicTableSize;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LDecoded: array[0..0] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LEncoder.SetDynamicTableSize(256);
  LDecoder.Init(256);
  LHeaders[0].Name := 'x-custom';
  LHeaders[0].Value := 'test';
  LBlock := LEncoder.Encode(LHeaders);
  Check(LDecoder.Decode(LBlock, LDecoded), 'table size update decode');
  CheckEqual('x-custom', string(LDecoded[0].Name), 'table size update name');
  CheckEqual('test', string(LDecoded[0].Value), 'table size update value');
end;

procedure TestEncoderMultipleHeaders;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..4] of THPackHeader;
  LDecoded: array[0..4] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'POST';
  LHeaders[1].Name := ':path';
  LHeaders[1].Value := '/api/data';
  LHeaders[2].Name := 'content-type';
  LHeaders[2].Value := 'application/json';
  LHeaders[3].Name := 'authorization';
  LHeaders[3].Value := 'Bearer token123';
  LHeaders[4].Name := 'x-request-id';
  LHeaders[4].Value := 'abc-123';
  LBlock := LEncoder.Encode(LHeaders);
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  Check(LDecoder.Decode(LBlock, LDecoded), 'multiple headers decode');
  CheckEqual(':method', string(LDecoded[0].Name), 'multiple header 0 name');
  CheckEqual('POST', string(LDecoded[0].Value), 'multiple header 0 value');
  CheckEqual('x-request-id', string(LDecoded[4].Name), 'multiple header 4 name');
  CheckEqual('abc-123', string(LDecoded[4].Value), 'multiple header 4 value');
end;

procedure TestEncoderRepeatedHeaders;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..1] of THPackHeader;
  LDecoded: array[0..1] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LHeaders[0].Name := 'set-cookie';
  LHeaders[0].Value := 'a=1';
  LHeaders[1].Name := 'set-cookie';
  LHeaders[1].Value := 'b=2';
  LBlock := LEncoder.Encode(LHeaders);
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  Check(LDecoder.Decode(LBlock, LDecoded), 'repeated headers decode');
  CheckEqual('set-cookie', string(LDecoded[0].Name), 'repeated header 0 name');
  CheckEqual('a=1', string(LDecoded[0].Value), 'repeated header 0 value');
  CheckEqual('set-cookie', string(LDecoded[1].Name), 'repeated header 1 name');
  CheckEqual('b=2', string(LDecoded[1].Value), 'repeated header 1 value');
end;

procedure TestDynamicTableOperations;
var
  LTable: THPackDynamicTable;
  LName, LValue: AnsiString;
begin
  LTable.Init(256);
  CheckEqual(Int64(256), Int64(LTable.Capacity), 'initial capacity');
  CheckEqual(Int64(0), Int64(LTable.Count), 'initial count');
  CheckEqual(Int64(0), Int64(LTable.TotalSize), 'initial total size');
  LTable.Add('x-custom', 'value1');
  CheckEqual(Int64(1), Int64(LTable.Count), 'count after add');
  Check(LTable.Get(0, LName, LValue), 'get after add');
  CheckEqual('x-custom', string(LName), 'get name');
  CheckEqual('value1', string(LValue), 'get value');
  LTable.Add('x-other', 'value2');
  CheckEqual(Int64(2), Int64(LTable.Count), 'count after second add');
  Check(LTable.Get(0, LName, LValue), 'get index 0 after second add');
  CheckEqual('x-other', string(LName), 'get index 0 name');
  CheckEqual('value2', string(LValue), 'get index 0 value');
  Check(LTable.Get(1, LName, LValue), 'get index 1 after second add');
  CheckEqual('x-custom', string(LName), 'get index 1 name');
  CheckEqual('value1', string(LValue), 'get index 1 value');
end;

procedure TestDynamicTableResize;
var
  LTable: THPackDynamicTable;
begin
  LTable.Init(256);
  LTable.Add('x-custom', 'value1');
  Check(LTable.Count > 0, 'has entries before resize');
  LTable.Resize(0);
  CheckEqual(Int64(0), Int64(LTable.Count), 'count after resize to 0');
  CheckEqual(Int64(0), Int64(LTable.Capacity), 'capacity after resize to 0');
end;

procedure TestDynamicTableGetName;
var
  LTable: THPackDynamicTable;
  LName: AnsiString;
begin
  LTable.Init(256);
  LTable.Add('x-custom', 'value1');
  Check(LTable.GetName(0, LName), 'GetName after add');
  CheckEqual('x-custom', string(LName), 'GetName value');
end;

procedure TestDynamicTableGetInvalidIndex;
var
  LTable: THPackDynamicTable;
  LName, LValue: AnsiString;
begin
  LTable.Init(256);
  Check(not LTable.Get(0, LName, LValue), 'Get on empty table');
  Check(not LTable.GetName(0, LName), 'GetName on empty table');
  LTable.Add('x-custom', 'value1');
  Check(not LTable.Get(1, LName, LValue), 'Get out of bounds');
  Check(not LTable.GetName(1, LName), 'GetName out of bounds');
end;

procedure TestHuffmanEdgeCases;
var
  LEncoded, LDecoded: AnsiString;
begin
  LEncoded := H2HuffmanEncode('');
  CheckEqual(Int64(0), Int64(Length(LEncoded)), 'empty string encode');
  LDecoded := H2HuffmanDecode('');
  CheckEqual('', string(LDecoded), 'empty string decode');
  LEncoded := H2HuffmanEncode(#0);
  LDecoded := H2HuffmanDecode(LEncoded);
  CheckEqual(#0, string(LDecoded), 'null byte roundtrip');
  LEncoded := H2HuffmanEncode(#$FF);
  LDecoded := H2HuffmanDecode(LEncoded);
  CheckEqual(#$FF, string(LDecoded), 'max byte roundtrip');
end;

procedure TestDecoderIndexedHeaderField;
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LBlock: AnsiString;
begin
  LDecoder.Init(HPACK_DEFAULT_DYNAMIC_TABLE_SIZE);
  LBlock := AnsiString(#$82);
  Check(LDecoder.Decode(LBlock, LHeaders), 'indexed header decode');
  CheckEqual(':method', string(LHeaders[0].Name), 'indexed method name');
  CheckEqual('GET', string(LHeaders[0].Value), 'indexed method value');
end;

procedure TestDecoderLiteralHeaderField;
var
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LBlock: AnsiString;
begin
  LDecoder.Init(0);
  LBlock := AnsiString(#0#3'foo'#3'bar');
  Check(LDecoder.Decode(LBlock, LHeaders), 'literal header decode');
  CheckEqual('foo', string(LHeaders[0].Name), 'literal name');
  CheckEqual('bar', string(LHeaders[0].Value), 'literal value');
end;

procedure TestEncoderDecoderLargeTableSize;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LDecoded: array[0..0] of THPackHeader;
  LBlock: AnsiString;
begin
  LEncoder.Init(16384);
  LDecoder.Init(16384);
  LHeaders[0].Name := 'x-large-table';
  LHeaders[0].Value := 'test-value';
  LBlock := LEncoder.Encode(LHeaders);
  Check(LDecoder.Decode(LBlock, LDecoded), 'large table decode');
  CheckEqual('x-large-table', string(LDecoded[0].Name), 'large table name');
  CheckEqual('test-value', string(LDecoded[0].Value), 'large table value');
end;

procedure TestMultiByteIntegerEncoding;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..2] of THPackHeader;
  LDecoded: array[0..2] of THPackHeader;
  LBlock: AnsiString;
begin
  { Test headers with values that trigger multi-byte integer encoding in
    HPACK static table indices. Index 62+ requires multi-byte encoding.
    Also test with custom headers to exercise literal encoding paths. }
  LEncoder.Init;
  LDecoder.Init;
  { :method POST = static index 3 (single byte) }
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'POST';
  { :path /long-path = static index 4 (single byte name, literal value) }
  LHeaders[1].Name := ':path';
  LHeaders[1].Value := '/a-very-long-path-that-exceeds-127-bytes-' +
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' +
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  { Custom header = literal name + literal value }
  LHeaders[2].Name := 'x-custom-multi-byte';
  LHeaders[2].Value := 'test';
  LBlock := LEncoder.Encode(LHeaders);
  Check(Length(LBlock) > 0, 'multi-byte encoding produces output');
  Check(LDecoder.Decode(LBlock, LDecoded), 'multi-byte encoding decodes');
  CheckEqual('POST', string(LDecoded[0].Value), 'static index value');
  Check(LHeaders[1].Value = LDecoded[1].Value, 'long value roundtrips');
  CheckEqual('x-custom-multi-byte', string(LDecoded[2].Name), 'custom name');
  CheckEqual('test', string(LDecoded[2].Value), 'custom value');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.impl.h2.hpack');
  { Roundtrip tests }
  T.Test('RFC Appendix C string vectors', @TestRfcAppendixCStringVectors);
  T.Test('Known roundtrips', @TestKnownRoundtrips);
  T.Test('Single byte roundtrips', @TestSingleByteRoundtrips);
  T.Test('Empty string', @TestEmptyString);
  T.Test('Long string (500 A-Z)', @TestLongString);
  T.Test('Compression ratio', @TestCompressionRatio);

  { Error handling }
  T.Test('Invalid padding raises', @TestInvalidPaddingRaises);
  T.Test('Partial 1s padding raises', @TestPartial1sPaddingRaises);
  T.Test('Limited decode truncation', @TestLimitedDecode);
  T.Test('DecodeView roundtrip', @TestDecodeViewRoundtrip);
  T.Test('DecodeView raw inline name/value', @TestDecodeViewRawInlineNameValue);
  T.Test('DecodeView dynamic table reuse', @TestDecodeViewDynamicTableReuse);
  T.Test('Reject dynamic table size update after header representation',
    @TestRejectsDynamicTableSizeUpdateAfterHeaderRepresentation);
  T.Test('Reject dynamic table size update above negotiated max',
    @TestRejectsDynamicTableSizeUpdateAboveMax);
  T.Test('Reject dynamic table size update UInt32 overflow',
    @TestRejectsDynamicTableSizeUpdateUInt32Overflow);

  { Encoder tests }
  T.Test('Encoder basic roundtrip', @TestEncoderBasicRoundtrip);
  T.Test('Encoder static table lookup', @TestEncoderStaticTableLookup);
  T.Test('Encoder dynamic table eviction', @TestEncoderDynamicTableEviction);
  T.Test('Encoder set dynamic table size', @TestEncoderSetDynamicTableSize);
  T.Test('Encoder multiple headers', @TestEncoderMultipleHeaders);
  T.Test('Encoder repeated headers', @TestEncoderRepeatedHeaders);

  { Dynamic table tests }
  T.Test('Dynamic table operations', @TestDynamicTableOperations);
  T.Test('Dynamic table resize', @TestDynamicTableResize);
  T.Test('Dynamic table GetName', @TestDynamicTableGetName);
  T.Test('Dynamic table Get invalid index', @TestDynamicTableGetInvalidIndex);

  { Huffman edge cases }
  T.Test('Huffman edge cases', @TestHuffmanEdgeCases);

  { Decoder tests }
  T.Test('Decoder indexed header field', @TestDecoderIndexedHeaderField);
  T.Test('Decoder literal header field', @TestDecoderLiteralHeaderField);
  T.Test('Encoder decoder large table size', @TestEncoderDecoderLargeTableSize);
  T.Test('Multi-byte integer encoding', @TestMultiByteIntegerEncoding);

  if not T.Run then Halt(1);
end.
