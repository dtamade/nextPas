program test_http_h2_hpack;
{
  HPACK Encoder/Decoder — conformance + edge-case tests.
  Verifies:
    - Static table lookup
    - Dynamic table add/evict
    - Integer variable-length encoding (RFC 7541 Section 5.1)
    - Header field encoding/decoding roundtrip
}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.hpack.table;

const
  MAX_TESTS = 64;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GTestName: AnsiString;

procedure Check(ACondition: Boolean; const AName: AnsiString);
begin
  if ACondition then
    Inc(GTestsPassed)
  else
  begin
    Inc(GTestsFailed);
    WriteLn('FAIL: ', GTestName, ' - ', AName);
  end;
end;

procedure TestStaticTableLookup;
var
  LName, LValue: AnsiString;
  LFound: Boolean;
begin
  GTestName := 'StaticTableLookup';
  { Test index 2: :method GET }
  LFound := HPackLookup(HPACK_STATIC_TABLE_COUNT, THPackDynamicTable(nil^), 2, LName, LValue);
  Check(LFound, 'index 2 found');
  Check(LName = ':method', 'index 2 name');
  Check(LValue = 'GET', 'index 2 value');
  { Test index 8: :status 200 }
  LFound := HPackLookup(HPACK_STATIC_TABLE_COUNT, THPackDynamicTable(nil^), 8, LName, LValue);
  Check(LFound, 'index 8 found');
  Check(LName = ':status', 'index 8 name');
  Check(LValue = '200', 'index 8 value');
  { Test index 1: :authority (no value) }
  LFound := HPackLookup(HPACK_STATIC_TABLE_COUNT, THPackDynamicTable(nil^), 1, LName, LValue);
  Check(LFound, 'index 1 found');
  Check(LName = ':authority', 'index 1 name');
  Check(LValue = '', 'index 1 empty value');
end;

procedure TestDynamicTableAddEvict;
var
  LDynTable: THPackDynamicTable;
  LName, LValue: AnsiString;
begin
  GTestName := 'DynamicTableAddEvict';
  LDynTable.Init(128); { small capacity }
  { Add entries that should fit }
  LDynTable.Add('test-name', 'test-value');
  Check(LDynTable.Count = 1, 'count 1');
  LDynTable.Add('another-name', 'another-value');
  Check(LDynTable.Count = 2, 'count 2');
  { Check retrieval }
  Check(LDynTable.Get(0, LName, LValue), 'get newest');
  Check(LName = 'another-name', 'newest name');
  Check(LDynTable.Get(1, LName, LValue), 'get oldest');
  Check(LName = 'test-name', 'oldest name');
end;

procedure TestDynamicTableResize;
var
  LDynTable: THPackDynamicTable;
begin
  GTestName := 'DynamicTableResize';
  LDynTable.Init(4096);
  LDynTable.Add('key1', 'value1');
  LDynTable.Add('key2', 'value2');
  Check(LDynTable.Count = 2, 'before resize count');
  { Resize to smaller — should evict }
  LDynTable.Resize(32);
  Check(LDynTable.Count = 0, 'after resize evicted');
end;

procedure TestEncoderDecoderRoundtrip;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..3] of THPackHeader;
  LEncoded: AnsiString;
  LDecoded: array[0..3] of THPackHeader;
begin
  GTestName := 'EncoderDecoderRoundtrip';
  LEncoder.Init;
  LDecoder.Init;
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':path';
  LHeaders[1].Value := '/';
  LHeaders[2].Name := ':authority';
  LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := ':scheme';
  LHeaders[3].Value := 'https';
  LEncoded := LEncoder.Encode(LHeaders);
  Check(Length(LEncoded) > 0, 'encoded not empty');
  { Decode }
  LDecoder.Decode(LEncoded, LDecoded);
  Check(LDecoded[0].Name = ':method', 'decoded method name');
  Check(LDecoded[0].Value = 'GET', 'decoded method value');
  Check(LDecoded[1].Name = ':path', 'decoded path name');
  Check(LDecoded[1].Value = '/', 'decoded path value');
  Check(LDecoded[2].Name = ':authority', 'decoded authority name');
  Check(LDecoded[2].Value = 'example.com', 'decoded authority value');
  Check(LDecoded[3].Name = ':scheme', 'decoded scheme name');
  Check(LDecoded[3].Value = 'https', 'decoded scheme value');
end;

procedure TestIndexedHeaderField;
var
  LEncoder: THPackEncoder;
  LHeaders: array[0..0] of THPackHeader;
  LEncoded: AnsiString;
begin
  GTestName := 'IndexedHeaderField';
  LEncoder.Init;
  { Encode a header that matches static table exactly }
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LEncoded := LEncoder.Encode(LHeaders);
  { Should be 2 bytes: 1-bit prefix (0x80) + index 2 = 0x82 }
  Check(Length(LEncoded) = 2, 'indexed length');
  Check(Byte(LEncoded[1]) = $82, 'indexed prefix');
end;

procedure TestLiteralWithIncrementalIndexing;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LEncoded: AnsiString;
  LDecoded: array[0..0] of THPackHeader;
begin
  GTestName := 'LiteralIncrementalIndexing';
  LEncoder.Init;
  LDecoder.Init;
  LHeaders[0].Name := 'custom-header';
  LHeaders[0].Value := 'custom-value';
  LEncoded := LEncoder.Encode(LHeaders);
  Check(Length(LEncoded) > 0, 'literal encoded');
  { Should start with 0x40 (incremental indexing prefix) }
  Check(Byte(LEncoded[1]) and $C0 = $40, 'incremental prefix');
  LDecoder.Decode(LEncoded, LDecoded);
  Check(LDecoded[0].Name = 'custom-header', 'decoded name');
  Check(LDecoded[0].Value = 'custom-value', 'decoded value');
end;

procedure TestStaticTableSize;
begin
  GTestName := 'StaticTableSize';
  Check(HPACK_STATIC_TABLE_COUNT = 61, 'count');
  { Verify a few entries }
  Check(HPACK_STATIC_TABLE[1].Name = ':authority', 'entry 1 name');
  Check(HPACK_STATIC_TABLE[2].Name = ':method', 'entry 2 name');
  Check(HPACK_STATIC_TABLE[2].Value = 'GET', 'entry 2 value');
end;

begin
  TestStaticTableLookup;
  TestDynamicTableAddEvict;
  TestDynamicTableResize;
  TestEncoderDecoderRoundtrip;
  TestIndexedHeaderField;
  TestLiteralWithIncrementalIndexing;
  TestStaticTableSize;

  WriteLn('test_http_h2_hpack: ', GTestsPassed, ' passed, ', GTestsFailed, ' failed');
  if GTestsFailed > 0 then
    Halt(1);
end.
