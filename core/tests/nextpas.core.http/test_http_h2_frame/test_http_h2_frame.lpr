program test_http_h2_frame;

{**
 * @desc HTTP/2 frame codec tests (RFC 9113 section 4 and 6).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http.base,
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

function NewFrame(const AFrameType: Byte; const AFlags: Byte;
  const AStreamID: UInt32; const APayload: AnsiString): TH2Frame;
begin
  Result := Default(TH2Frame);
  Result.Header.Len := UInt32(Length(APayload));
  Result.Header.FrameType := AFrameType;
  Result.Header.Flags := AFlags;
  Result.Header.StreamID := AStreamID;
  Result.Payload := APayload;
end;

procedure CheckFrameValid(const AFrame: TH2Frame; const AMessage: string);
var
  LErrorCode: UInt32;
begin
  LErrorCode := $FFFFFFFF;
  Check(H2ValidateFrame(AFrame, H2_DEFAULT_MAX_FRAME_SIZE, LErrorCode), AMessage);
  CheckEqual(Int64(H2_ERR_NO_ERROR), Int64(LErrorCode), AMessage + ' error');
end;

procedure CheckFrameInvalid(const AFrame: TH2Frame; const AExpectedError: UInt32;
  const AMessage: string);
var
  LErrorCode: UInt32;
begin
  LErrorCode := H2_ERR_NO_ERROR;
  Check(not H2ValidateFrame(AFrame, H2_DEFAULT_MAX_FRAME_SIZE, LErrorCode),
    AMessage);
  CheckEqual(Int64(AExpectedError), Int64(LErrorCode), AMessage + ' error');
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

procedure TestFrameTypeSpecificValidation;
begin
  CheckFrameValid(NewFrame(H2_FRAME_DATA, 0, 1, 'abc'), 'DATA stream frame');
  CheckFrameInvalid(NewFrame(H2_FRAME_DATA, 0, 0, 'abc'),
    H2_ERR_PROTOCOL_ERROR, 'DATA stream id 0 rejected');
  CheckFrameInvalid(NewFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 0, ''),
    H2_ERR_PROTOCOL_ERROR, 'HEADERS stream id 0 rejected');
  CheckFrameInvalid(NewFrame(H2_FRAME_CONTINUATION,
    H2_FLAG_CONTINUATION_END_HEADERS, 0, ''),
    H2_ERR_PROTOCOL_ERROR, 'CONTINUATION stream id 0 rejected');
  CheckFrameInvalid(NewFrame(H2_FRAME_PRIORITY, 0, 0, #0#0#0#0#0),
    H2_ERR_PROTOCOL_ERROR, 'PRIORITY stream id 0 rejected');
  CheckFrameInvalid(NewFrame(H2_FRAME_PRIORITY, 0, 1, #0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'PRIORITY length must be 5');
  CheckFrameInvalid(NewFrame(H2_FRAME_RST_STREAM, 0, 0,
    H2EncodeRstStream(H2_ERR_CANCEL)),
    H2_ERR_PROTOCOL_ERROR, 'RST_STREAM stream id 0 rejected');
  CheckFrameInvalid(NewFrame(H2_FRAME_RST_STREAM, 0, 1, #0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'RST_STREAM length must be 4');
  CheckFrameValid(NewFrame(H2_FRAME_SETTINGS, 0, 0,
    H2EncodeSettingsPayload(nil)), 'SETTINGS empty payload');
  CheckFrameInvalid(NewFrame(H2_FRAME_SETTINGS, 0, 1, ''),
    H2_ERR_PROTOCOL_ERROR, 'SETTINGS stream id must be 0');
  CheckFrameInvalid(NewFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0,
    #0#1#0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'SETTINGS ACK payload must be empty');
  CheckFrameInvalid(NewFrame(H2_FRAME_SETTINGS, 0, 0, #0#1#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'SETTINGS payload must be multiple of 6');
  CheckFrameValid(NewFrame(H2_FRAME_PING, 0, 0,
    H2EncodePing($0123456789ABCDEF)), 'PING connection frame');
  CheckFrameInvalid(NewFrame(H2_FRAME_PING, 0, 1,
    H2EncodePing($0123456789ABCDEF)),
    H2_ERR_PROTOCOL_ERROR, 'PING stream id must be 0');
  CheckFrameInvalid(NewFrame(H2_FRAME_PING, 0, 0, #0#0#0#0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'PING length must be 8');
  CheckFrameInvalid(NewFrame(H2_FRAME_GOAWAY, 0, 1,
    H2EncodeGoaway(0, H2_ERR_NO_ERROR, '')),
    H2_ERR_PROTOCOL_ERROR, 'GOAWAY stream id must be 0');
  CheckFrameInvalid(NewFrame(H2_FRAME_GOAWAY, 0, 0, #0#0#0#0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'GOAWAY length must be at least 8');
  CheckFrameValid(NewFrame(H2_FRAME_WINDOW_UPDATE, 0, 1,
    H2EncodeWindowUpdate(1)), 'WINDOW_UPDATE stream frame');
  CheckFrameValid(NewFrame(H2_FRAME_WINDOW_UPDATE, 0, 0,
    H2EncodeWindowUpdate(1)), 'WINDOW_UPDATE connection frame');
  CheckFrameInvalid(NewFrame(H2_FRAME_WINDOW_UPDATE, 0, 0, #0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'WINDOW_UPDATE length must be 4');
  CheckFrameInvalid(NewFrame(H2_FRAME_WINDOW_UPDATE, 0, 1,
    H2EncodeWindowUpdate(0)),
    H2_ERR_PROTOCOL_ERROR, 'WINDOW_UPDATE zero increment rejected');
end;

procedure TestFramePaddingValidation;
begin
  CheckFrameInvalid(NewFrame(H2_FRAME_DATA, H2_FLAG_DATA_PADDED, 1, ''),
    H2_ERR_FRAME_SIZE_ERROR, 'DATA padded frame needs pad length byte');
  CheckFrameInvalid(NewFrame(H2_FRAME_DATA, H2_FLAG_DATA_PADDED, 1,
    #3'ab'),
    H2_ERR_FRAME_SIZE_ERROR, 'DATA pad length cannot exceed payload');
  CheckFrameValid(NewFrame(H2_FRAME_DATA, H2_FLAG_DATA_PADDED, 1,
    #2'ab'), 'DATA can carry only padding after pad length');

  CheckFrameInvalid(NewFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_PADDED, 1, ''),
    H2_ERR_FRAME_SIZE_ERROR, 'HEADERS padded frame needs pad length byte');
  CheckFrameInvalid(NewFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_PADDED, 1,
    #1),
    H2_ERR_FRAME_SIZE_ERROR, 'HEADERS pad length cannot consume pad byte');
  CheckFrameInvalid(NewFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_PRIORITY, 1,
    #0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'HEADERS priority flag needs 5 bytes');
  CheckFrameValid(NewFrame(H2_FRAME_HEADERS,
    H2_FLAG_HEADERS_PADDED or H2_FLAG_HEADERS_PRIORITY, 1,
    #0#0#0#0#0#0), 'HEADERS padded priority minimum');

  CheckFrameInvalid(NewFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_PADDED,
    1, #1#0#0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'PUSH_PROMISE pad length cannot consume payload');
  CheckFrameValid(NewFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_PADDED,
    1, #0#0#0#0#2), 'PUSH_PROMISE padded minimum');
end;

procedure TestClientPreface;
begin
  CheckEqual('PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10,
    H2_CLIENT_PREFACE, 'client connection preface');
end;

{ -- Additional validation coverage -- }

procedure TestEncodeFrameEmptyPayload;
var
  LWire: AnsiString;
begin
  LWire := H2EncodeFrame(H2_FRAME_DATA, 0, 1, '');
  CheckEqual(Int64(H2_FRAME_HEADER_SIZE), Int64(Length(LWire)),
    'empty payload frame has header only');
end;

procedure TestEncodeFrameOversizedPayload;
var
  LPayload: AnsiString;
  LCaptured: Boolean;
begin
  SetLength(LPayload, H2_ABSOLUTE_MAX_FRAME_SIZE + 1);
  LCaptured := False;
  try
    H2EncodeFrame(H2_FRAME_DATA, 0, 1, LPayload);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'oversized payload raises EHttpError');
end;

procedure TestFrameTypesComplete;
begin
  CheckEqual('DATA', H2FrameTypeName(H2_FRAME_DATA), 'type 0 name');
  CheckEqual('HEADERS', H2FrameTypeName(H2_FRAME_HEADERS), 'type 1 name');
  CheckEqual('PRIORITY', H2FrameTypeName(H2_FRAME_PRIORITY), 'type 2 name');
  CheckEqual('RST_STREAM', H2FrameTypeName(H2_FRAME_RST_STREAM), 'type 3 name');
  CheckEqual('SETTINGS', H2FrameTypeName(H2_FRAME_SETTINGS), 'type 4 name');
  CheckEqual('PUSH_PROMISE', H2FrameTypeName(H2_FRAME_PUSH_PROMISE), 'type 5 name');
  CheckEqual('PING', H2FrameTypeName(H2_FRAME_PING), 'type 6 name');
  CheckEqual('GOAWAY', H2FrameTypeName(H2_FRAME_GOAWAY), 'type 7 name');
  CheckEqual('WINDOW_UPDATE', H2FrameTypeName(H2_FRAME_WINDOW_UPDATE), 'type 8 name');
  CheckEqual('CONTINUATION', H2FrameTypeName(H2_FRAME_CONTINUATION), 'type 9 name');
end;

procedure TestStreamIDValidation;
begin
  Check(not H2IsValidStreamID(0), 'stream id 0 is not stream-level');
  Check(H2IsValidStreamID(1), 'client-initiated odd stream valid');
  Check(H2IsValidStreamID(2), 'server-initiated even stream valid');
  Check(H2IsValidStreamID($7FFFFFFF), 'max stream id valid');
  Check(not H2IsValidStreamID($80000000), 'stream id with MSB set invalid');
end;

procedure TestPUSH_PROMISEValidation;
begin
  CheckFrameInvalid(NewFrame(H2_FRAME_PUSH_PROMISE, 0, 0, #0#0#0#0#1),
    H2_ERR_PROTOCOL_ERROR, 'PUSH_PROMISE stream id 0 rejects');
  CheckFrameInvalid(NewFrame(H2_FRAME_PUSH_PROMISE, 0, 1, #0#0#0),
    H2_ERR_FRAME_SIZE_ERROR, 'PUSH_PROMISE length must be at least 4');
  CheckFrameValid(NewFrame(H2_FRAME_PUSH_PROMISE, 0, 1, #0#0#0#0),
    'PUSH_PROMISE min valid');
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
    Run('Frame type specific validation',
      @TestFrameTypeSpecificValidation);
    Run('Frame padding validation', @TestFramePaddingValidation);
    Run('Client preface', @TestClientPreface);
    Run('Encode frame empty payload', @TestEncodeFrameEmptyPayload);
    Run('Encode frame oversized payload raises',
      @TestEncodeFrameOversizedPayload);
    Run('Frame type names complete', @TestFrameTypesComplete);
    Run('Stream ID validation', @TestStreamIDValidation);
    Run('PUSH_PROMISE validation', @TestPUSH_PROMISEValidation);
    Summary;
  end;
end.
