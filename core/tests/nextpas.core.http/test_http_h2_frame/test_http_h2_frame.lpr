program test_http_h2_frame;

{**
 * @desc HTTP/2 frame codec tests (RFC 9113 section 4 and 6).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.frame,
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

procedure TestDecodeFrameHeaderMasksReservedBit;
var
  LWire: AnsiString;
  LHeader: TH2FrameHeader;
begin
  LWire := HexToBytes('000005000180000001');
  Check(H2DecodeFrameHeader(@LWire[1], Length(LWire), LHeader),
    'header should decode');
  CheckEqual(Int64(5), Int64(LHeader.Len), 'payload length');
  CheckEqual(Int64(H2_FRAME_DATA), Int64(LHeader.FrameType), 'frame type');
  CheckEqual(Int64(H2_FLAG_DATA_END_STREAM), Int64(LHeader.Flags), 'flags');
  CheckEqual(Int64(1), Int64(LHeader.StreamID), 'reserved stream bit masked');
end;

procedure TestEncodeFrameHeaderMasksReservedBit;
var
  LHeader: TH2FrameHeader;
  LWire: AnsiString;
begin
  SetLength(LWire, H2_FRAME_HEADER_SIZE);
  LHeader.Len := $010203;
  LHeader.FrameType := H2_FRAME_SETTINGS;
  LHeader.Flags := H2_FLAG_SETTINGS_ACK;
  LHeader.StreamID := $80000001;
  H2EncodeFrameHeader(LHeader, @LWire[1]);
  CheckEqual('010203040100000001', BytesToHex(LWire),
    'encoded 9-byte header');
end;

procedure TestEncodeFramePlacesPayloadAfterNineByteHeader;
var
  LWire: AnsiString;
begin
  LWire := H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, 'abc');
  CheckEqual('000003000100000001616263', BytesToHex(LWire),
    'encoded DATA frame wire bytes');
end;

procedure TestDecodeFrameConsumesHeaderAndPayload;
var
  LWire: AnsiString;
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
begin
  LWire := HexToBytes('000003000100000001616263');
  Check(H2DecodeFrame(@LWire[1], Length(LWire), LFrame, LConsumed),
    'frame should decode');
  CheckEqual(Int64(12), Int64(LConsumed), 'consumed bytes');
  CheckEqual(Int64(3), Int64(LFrame.Header.Len), 'payload length');
  CheckEqual(Int64(1), Int64(LFrame.Header.StreamID), 'stream id');
  CheckEqual('abc', string(LFrame.Payload), 'payload');
end;

procedure TestDecodeFrameWaitsForCompletePayload;
var
  LWire: AnsiString;
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
begin
  LWire := HexToBytes('000004000100000001616263');
  Check(not H2DecodeFrame(@LWire[1], Length(LWire), LFrame, LConsumed),
    'incomplete payload should wait');
  CheckEqual(Int64(0), Int64(LConsumed), 'no bytes consumed');
end;

procedure TestDecodeRejectsNilBuffer;
var
  LHeader: TH2FrameHeader;
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
begin
  Check(not H2DecodeFrameHeader(nil, H2_FRAME_HEADER_SIZE, LHeader),
    'nil header buffer rejected');
  Check(not H2DecodeFrame(nil, H2_FRAME_HEADER_SIZE, LFrame, LConsumed),
    'nil frame buffer rejected');
  CheckEqual(Int64(0), Int64(LConsumed), 'nil frame consumes nothing');
end;

procedure TestSettingsPayloadExactBytes;
var
  LEntries: TH2SettingEntries;
  LDecoded: TH2SettingEntries;
  LWire: AnsiString;
begin
  SetLength(LEntries, 2);
  LEntries[0].Identifier := H2_SETTINGS_HEADER_TABLE_SIZE;
  LEntries[0].Value := 4096;
  LEntries[1].Identifier := H2_SETTINGS_MAX_FRAME_SIZE;
  LEntries[1].Value := 16384;

  LWire := H2EncodeSettingsPayload(LEntries);
  CheckEqual('000100001000000500004000', BytesToHex(LWire),
    'SETTINGS payload wire bytes');
  Check(H2DecodeSettingsPayload(LWire, LDecoded), 'SETTINGS decode');
  CheckEqual(Int64(2), Int64(Length(LDecoded)), 'SETTINGS count');
  CheckEqual(Int64(H2_SETTINGS_HEADER_TABLE_SIZE),
    Int64(LDecoded[0].Identifier), 'setting 0 id');
  CheckEqual(Int64(4096), Int64(LDecoded[0].Value), 'setting 0 value');
  CheckEqual(Int64(H2_SETTINGS_MAX_FRAME_SIZE),
    Int64(LDecoded[1].Identifier), 'setting 1 id');
  CheckEqual(Int64(16384), Int64(LDecoded[1].Value), 'setting 1 value');
end;

procedure TestSettingsRejectsTrailingPartialEntry;
var
  LDecoded: TH2SettingEntries;
begin
  Check(not H2DecodeSettingsPayload(HexToBytes('0001000010'), LDecoded),
    'partial SETTINGS entry rejected');
end;

procedure TestFixedPayloadCodecs;
var
  LLastStreamID: UInt32;
  LErrorCode: UInt32;
  LDebug: AnsiString;
  LWindow: UInt32;
  LRst: UInt32;
  LPing: UInt64;
begin
  Check(H2DecodeGoaway(H2EncodeGoaway($80000007, H2_ERR_NO_ERROR, 'done'),
    LLastStreamID, LErrorCode, LDebug), 'GOAWAY decode');
  CheckEqual(Int64(7), Int64(LLastStreamID), 'GOAWAY reserved bit masked');
  CheckEqual(Int64(H2_ERR_NO_ERROR), Int64(LErrorCode), 'GOAWAY error');
  CheckEqual('done', string(LDebug), 'GOAWAY debug data');

  Check(H2DecodeWindowUpdate(H2EncodeWindowUpdate($80000005), LWindow),
    'WINDOW_UPDATE decode');
  CheckEqual(Int64(5), Int64(LWindow), 'WINDOW_UPDATE reserved bit masked');

  Check(H2DecodeRstStream(H2EncodeRstStream(H2_ERR_CANCEL), LRst),
    'RST_STREAM decode');
  CheckEqual(Int64(H2_ERR_CANCEL), Int64(LRst), 'RST_STREAM error');

  Check(H2DecodePing(H2EncodePing($0123456789ABCDEF), LPing),
    'PING decode');
  CheckEqual(Int64($0123456789ABCDEF), Int64(LPing), 'PING opaque data');
end;

procedure TestNamesAndValidationHelpers;
begin
  CheckEqual('DATA', H2FrameTypeName(H2_FRAME_DATA), 'DATA name');
  CheckEqual('SETTINGS', H2FrameTypeName(H2_FRAME_SETTINGS), 'SETTINGS name');
  CheckEqual('UNKNOWN(99)', H2FrameTypeName(99), 'unknown frame name');
  CheckEqual('NO_ERROR', H2ErrorCodeName(H2_ERR_NO_ERROR), 'NO_ERROR name');
  CheckEqual('UNKNOWN(99)', H2ErrorCodeName(99), 'unknown error name');
  Check(not H2IsValidStreamID(0), 'stream id 0 is not stream-level');
  Check(H2IsValidStreamID($7FFFFFFF), 'max stream id valid');
  Check(H2IsValidFrameSize(0, H2_DEFAULT_MAX_FRAME_SIZE), 'zero frame ok');
  Check(H2IsValidFrameSize(H2_DEFAULT_MAX_FRAME_SIZE,
    H2_DEFAULT_MAX_FRAME_SIZE), 'default max frame ok');
  Check(not H2IsValidFrameSize(H2_DEFAULT_MAX_FRAME_SIZE + 1,
    H2_DEFAULT_MAX_FRAME_SIZE), 'over max frame rejected');
  Check(H2IsValidSettingIdentifier(H2_SETTINGS_HEADER_TABLE_SIZE),
    'known setting id valid');
  Check(not H2IsValidSettingIdentifier(0), 'setting id zero invalid');
end;

procedure TestClientPreface;
begin
  CheckEqual('PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10,
    H2_CLIENT_PREFACE, 'client connection preface');
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.frame') do
  begin
    Run('Decode frame header masks reserved bit',
      @TestDecodeFrameHeaderMasksReservedBit);
    Run('Encode frame header masks reserved bit',
      @TestEncodeFrameHeaderMasksReservedBit);
    Run('Encode frame places payload after 9-byte header',
      @TestEncodeFramePlacesPayloadAfterNineByteHeader);
    Run('Decode frame consumes header and payload',
      @TestDecodeFrameConsumesHeaderAndPayload);
    Run('Decode frame waits for complete payload',
      @TestDecodeFrameWaitsForCompletePayload);
    Run('Decode rejects nil buffer', @TestDecodeRejectsNilBuffer);
    Run('SETTINGS payload exact bytes', @TestSettingsPayloadExactBytes);
    Run('SETTINGS rejects trailing partial entry',
      @TestSettingsRejectsTrailingPartialEntry);
    Run('Fixed payload codecs', @TestFixedPayloadCodecs);
    Run('Names and validation helpers', @TestNamesAndValidationHelpers);
    Run('Client preface', @TestClientPreface);
    Summary;
  end;
end.
