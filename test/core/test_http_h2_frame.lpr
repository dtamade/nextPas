program test_http_h2_frame;
{
  HTTP/2 Frame Codec — conformance + edge-case tests.
  Verifies:
    - Frame header encode/decode roundtrip
    - SETTINGS encode/decode
    - GOAWAY encode/decode
    - WINDOW_UPDATE encode/decode
    - RST_STREAM encode/decode
    - PING encode/decode
    - Error code names
}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.http.impl.h2.frame;

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

procedure TestFrameHeaderEncodeDecode;
var
  LHdr: TH2FrameHeader;
  LBuf: array[0..8] of AnsiChar;
  LDecoded: TH2FrameHeader;
begin
  GTestName := 'FrameHeaderRoundtrip';
  LHdr.Len := 100;
  LHdr.FrameType := H2_FRAME_DATA;
  LHdr.Flags := H2_FLAG_DATA_END_STREAM;
  LHdr.StreamID := 1;
  H2EncodeFrameHeader(LHdr, @LBuf[0]);
  H2DecodeFrameHeader(@LBuf[0], 9, LDecoded);
  Check(LDecoded.Len = 100, 'len');
  Check(LDecoded.FrameType = H2_FRAME_DATA, 'type');
  Check(LDecoded.Flags = H2_FLAG_DATA_END_STREAM, 'flags');
  Check(LDecoded.StreamID = 1, 'streamid');
end;

procedure TestSettingsEncodeDecode;
var
  LSettings: TH2SettingEntries;
  LEncoded: AnsiString;
  LDecoded: TH2SettingEntries;
begin
  GTestName := 'SettingsRoundtrip';
  SetLength(LSettings, 3);
  LSettings[0].Identifier := H2_SETTINGS_HEADER_TABLE_SIZE;
  LSettings[0].Value := 4096;
  LSettings[1].Identifier := H2_SETTINGS_MAX_FRAME_SIZE;
  LSettings[1].Value := 16384;
  LSettings[2].Identifier := H2_SETTINGS_INITIAL_WINDOW_SIZE;
  LSettings[2].Value := 65535;
  LEncoded := H2EncodeSettingsPayload(LSettings);
  H2DecodeSettingsPayload(LEncoded, LDecoded);
  Check(Length(LDecoded) = 3, 'count');
  Check(LDecoded[0].Identifier = H2_SETTINGS_HEADER_TABLE_SIZE, 'id0');
  Check(LDecoded[0].Value = 4096, 'val0');
  Check(LDecoded[1].Identifier = H2_SETTINGS_MAX_FRAME_SIZE, 'id1');
  Check(LDecoded[1].Value = 16384, 'val1');
  Check(LDecoded[2].Identifier = H2_SETTINGS_INITIAL_WINDOW_SIZE, 'id2');
  Check(LDecoded[2].Value = 65535, 'val2');
end;

procedure TestGoawayEncodeDecode;
var
  LEncoded: AnsiString;
  LLastStream, LErrorCode: UInt32;
  LDebug: AnsiString;
begin
  GTestName := 'GoawayRoundtrip';
  LEncoded := H2EncodeGoaway($3FFFFFFF, H2_ERR_NO_ERROR, 'test debug data');
  H2DecodeGoaway(LEncoded, LLastStream, LErrorCode, LDebug);
  Check(LLastStream = $3FFFFFFF, 'laststream');
  Check(LErrorCode = H2_ERR_NO_ERROR, 'errorcode');
  Check(LDebug = 'test debug data', 'debug');
end;

procedure TestWindowUpdateEncodeDecode;
var
  LEncoded: AnsiString;
  LSize: UInt32;
begin
  GTestName := 'WindowUpdateRoundtrip';
  LEncoded := H2EncodeWindowUpdate(12345);
  H2DecodeWindowUpdate(LEncoded, LSize);
  Check(LSize = 12345, 'size');
end;

procedure TestRstStreamEncodeDecode;
var
  LEncoded: AnsiString;
  LCode: UInt32;
begin
  GTestName := 'RstStreamRoundtrip';
  LEncoded := H2EncodeRstStream(H2_ERR_CANCEL);
  H2DecodeRstStream(LEncoded, LCode);
  Check(LCode = H2_ERR_CANCEL, 'code');
end;

procedure TestPingEncodeDecode;
var
  LEncoded: AnsiString;
  LData: UInt64;
  LDecoded: UInt64;
begin
  GTestName := 'PingRoundtrip';
  LData := $0123456789ABCDEF;
  LEncoded := H2EncodePing(LData);
  H2DecodePing(LEncoded, LDecoded);
  Check(LDecoded = LData, 'data');
end;

procedure TestErrorCodes;
begin
  GTestName := 'ErrorCodeNames';
  Check(H2ErrorCodeName(H2_ERR_NO_ERROR) = 'NO_ERROR', 'NO_ERROR');
  Check(H2ErrorCodeName(H2_ERR_PROTOCOL_ERROR) = 'PROTOCOL_ERROR', 'PROTOCOL_ERROR');
  Check(H2ErrorCodeName(H2_ERR_INTERNAL_ERROR) = 'INTERNAL_ERROR', 'INTERNAL_ERROR');
  Check(H2ErrorCodeName(H2_ERR_FLOW_CONTROL_ERROR) = 'FLOW_CONTROL_ERROR', 'FLOW_CONTROL_ERROR');
  Check(H2ErrorCodeName(99) = 'UNKNOWN(99)', 'UNKNOWN');
end;

procedure TestFrameTypeNames;
begin
  GTestName := 'FrameTypeNames';
  Check(H2FrameTypeName(H2_FRAME_DATA) = 'DATA', 'DATA');
  Check(H2FrameTypeName(H2_FRAME_HEADERS) = 'HEADERS', 'HEADERS');
  Check(H2FrameTypeName(H2_FRAME_SETTINGS) = 'SETTINGS', 'SETTINGS');
  Check(H2FrameTypeName(H2_FRAME_GOAWAY) = 'GOAWAY', 'GOAWAY');
  Check(H2FrameTypeName(99) = 'UNKNOWN(99)', 'UNKNOWN');
end;

procedure TestStreamIDValidation;
begin
  GTestName := 'StreamIDValidation';
  Check(H2IsValidStreamID(0) = False, '0 invalid');
  Check(H2IsValidStreamID(1) = True, '1 valid');
  Check(H2IsValidStreamID($7FFFFFFF) = True, 'max valid');
end;

procedure TestFrameSizeValidation;
begin
  GTestName := 'FrameSizeValidation';
  Check(H2IsValidFrameSize(16384, 16384) = True, 'default ok');
  Check(H2IsValidFrameSize(16385, 16384) = False, 'over default');
  Check(H2IsValidFrameSize(0, 16384) = True, 'zero ok');
end;

procedure TestClientPreface;
begin
  GTestName := 'ClientPreface';
  Check(H2_CLIENT_PREFACE = 'PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10, 'preface matches RFC');
end;

begin
  TestFrameHeaderEncodeDecode;
  TestSettingsEncodeDecode;
  TestGoawayEncodeDecode;
  TestWindowUpdateEncodeDecode;
  TestRstStreamEncodeDecode;
  TestPingEncodeDecode;
  TestErrorCodes;
  TestFrameTypeNames;
  TestStreamIDValidation;
  TestFrameSizeValidation;
  TestClientPreface;

  WriteLn('test_http_h2_frame: ', GTestsPassed, ' passed, ', GTestsFailed, ' failed');
  if GTestsFailed > 0 then
    Halt(1);
end.
