unit nextpas.core.http.impl.h2.frame;
{**
 * @desc HTTP/2 binary frame codec (RFC 9113 sections 4-6).
 *       Encodes and decodes the common 9-byte frame header, complete
 *       frame byte envelopes, and fixed-size control payloads.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base;

const
  { Frame header size: Length(24) + Type(8) + Flags(8) + Reserved(1) + StreamID(31) }
  H2_FRAME_HEADER_SIZE = 9;

  { Default max frame size (RFC 9113 Section 6.5.2) }
  H2_DEFAULT_MAX_FRAME_SIZE = 16384;
  H2_MIN_MAX_FRAME_SIZE = 16384;
  H2_ABSOLUTE_MAX_FRAME_SIZE = 16777215; { 2^24 - 1 }

  { Default initial window size (RFC 9113 Section 6.5.2) }
  H2_DEFAULT_INITIAL_WINDOW_SIZE = 65535;

  { Max header table size (RFC 9113 Section 6.5.2) }
  H2_DEFAULT_HEADER_TABLE_SIZE = 4096;

  { SETTINGS identifiers (RFC 9113 Section 6.5.2) }
  H2_SETTINGS_HEADER_TABLE_SIZE      = 1;
  H2_SETTINGS_ENABLE_PUSH            = 2;
  H2_SETTINGS_MAX_CONCURRENT_STREAMS = 3;
  H2_SETTINGS_INITIAL_WINDOW_SIZE    = 4;
  H2_SETTINGS_MAX_FRAME_SIZE         = 5;
  H2_SETTINGS_MAX_HEADER_LIST_SIZE   = 6;

  { Frame types (RFC 9113 Section 6) }
  H2_FRAME_DATA          = $00;
  H2_FRAME_HEADERS       = $01;
  H2_FRAME_PRIORITY      = $02;
  H2_FRAME_RST_STREAM    = $03;
  H2_FRAME_SETTINGS      = $04;
  H2_FRAME_PUSH_PROMISE  = $05;
  H2_FRAME_PING          = $06;
  H2_FRAME_GOAWAY        = $07;
  H2_FRAME_WINDOW_UPDATE = $08;
  H2_FRAME_CONTINUATION  = $09;

  { DATA frame flags (RFC 9113 Section 6.1) }
  H2_FLAG_DATA_END_STREAM  = $01;
  H2_FLAG_DATA_PADDED      = $08;

  { HEADERS frame flags (RFC 9113 Section 6.2) }
  H2_FLAG_HEADERS_END_STREAM  = $01;
  H2_FLAG_HEADERS_END_HEADERS = $04;
  H2_FLAG_HEADERS_PADDED      = $08;
  H2_FLAG_HEADERS_PRIORITY    = $20;

  { SETTINGS frame flags (RFC 9113 Section 6.5) }
  H2_FLAG_SETTINGS_ACK = $01;

  { PING frame flags (RFC 9113 Section 6.7) }
  H2_FLAG_PING_ACK = $01;

  { PUSH_PROMISE frame flags (RFC 9113 Section 6.6) }
  H2_FLAG_PUSH_PROMISE_END_HEADERS = $04;
  H2_FLAG_PUSH_PROMISE_PADDED      = $08;

  { CONTINUATION frame flags (RFC 9113 Section 6.10) }
  H2_FLAG_CONTINUATION_END_HEADERS = $04;

  { Error codes (RFC 9113 Section 7) }
  H2_ERR_NO_ERROR            = $00;
  H2_ERR_PROTOCOL_ERROR      = $01;
  H2_ERR_INTERNAL_ERROR      = $02;
  H2_ERR_FLOW_CONTROL_ERROR  = $03;
  H2_ERR_SETTINGS_TIMEOUT    = $04;
  H2_ERR_STREAM_CLOSED       = $05;
  H2_ERR_FRAME_SIZE_ERROR    = $06;
  H2_ERR_REFUSED_STREAM      = $07;
  H2_ERR_CANCEL              = $08;
  H2_ERR_COMPRESSION_ERROR   = $09;
  H2_ERR_CONNECT_ERROR       = $0A;
  H2_ERR_ENHANCE_YOUR_CALM   = $0B;
  H2_ERR_INADEQUATE_SECURITY = $0C;
  H2_ERR_HTTP_1_1_REQUIRED   = $0D;

  { Connection preface client magic (RFC 9113 Section 3.4) }
  H2_CLIENT_PREFACE = 'PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10;

type
  { Raw frame header - 9 bytes }
  TH2FrameHeader = record
    Len: UInt32;       { 24 bits: payload length }
    FrameType: Byte;   { 8 bits: frame type }
    Flags: Byte;       { 8 bits: flags }
    StreamID: UInt32;  { 1 bit reserved + 31 bits: stream identifier }
  end;

  { SETTINGS entry: identifier + value }
  TH2SettingEntry = record
    Identifier: UInt16;
    Value: UInt32;
  end;
  TH2SettingEntries = array of TH2SettingEntry;

  { Decoded frame payload }
  TH2Frame = record
    Header: TH2FrameHeader;
    Payload: AnsiString;
  end;

{ -- Frame header codec -- }

{ Decode a 9-byte frame header. Returns False if buffer too small. }
function H2DecodeFrameHeader(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AHeader: TH2FrameHeader): Boolean;

{ Encode a 9-byte frame header into buffer (must be >= 9 bytes). }
procedure H2EncodeFrameHeader(const AHeader: TH2FrameHeader;
  const ABuf: PAnsiChar);

{ -- Full frame codec -- }

{ Decode a complete frame (header + payload) from buffer.
  Consumed returns total bytes consumed (header + payload).
  Returns False if buffer too small for the declared payload length. }
function H2DecodeFrame(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;

{ Encode a complete frame (header + payload) into a new AnsiString buffer. }
function H2EncodeFrame(const AFrameType: Byte; const AFlags: Byte;
  const AStreamID: UInt32; const APayload: AnsiString): AnsiString;

{ -- SETTINGS frame codec -- }

{ Decode SETTINGS payload into entry array.
  Returns False if payload length is not a multiple of 6. }
function H2DecodeSettingsPayload(const APayload: AnsiString;
  out AEntries: TH2SettingEntries): Boolean;

{ Encode SETTINGS entries into payload bytes. }
function H2EncodeSettingsPayload(const AEntries: TH2SettingEntries): AnsiString;

{ Encode a single SETTINGS entry (6 bytes). }
procedure H2EncodeSettingEntry(const AEntry: TH2SettingEntry;
  const ABuf: PAnsiChar);

{ -- GOAWAY frame codec -- }

{ Decode GOAWAY payload: LastStreamID + ErrorCode + DebugData. }
function H2DecodeGoaway(const APayload: AnsiString;
  out ALastStreamID: UInt32; out AErrorCode: UInt32;
  out ADebugData: AnsiString): Boolean;

{ Encode GOAWAY payload. }
function H2EncodeGoaway(const ALastStreamID: UInt32;
  const AErrorCode: UInt32; const ADebugData: AnsiString): AnsiString;

{ -- WINDOW_UPDATE frame codec -- }

{ Decode WINDOW_UPDATE payload: 1 bit reserved + 31 bit window size increment. }
function H2DecodeWindowUpdate(const APayload: AnsiString;
  out AWindowSizeIncrement: UInt32): Boolean;

{ Encode WINDOW_UPDATE payload. }
function H2EncodeWindowUpdate(const AWindowSizeIncrement: UInt32): AnsiString;

{ -- RST_STREAM frame codec -- }

{ Decode RST_STREAM payload: 4-byte error code. }
function H2DecodeRstStream(const APayload: AnsiString;
  out AErrorCode: UInt32): Boolean;

{ Encode RST_STREAM payload. }
function H2EncodeRstStream(const AErrorCode: UInt32): AnsiString;

{ -- PING frame codec -- }

{ Decode PING payload: 8-byte opaque data. }
function H2DecodePing(const APayload: AnsiString;
  out AData: UInt64): Boolean;

{ Encode PING payload. }
function H2EncodePing(const AData: UInt64): AnsiString;

{ -- Validation helpers -- }

{ Validate stream ID is legal for stream-level frames. }
function H2IsValidStreamID(const AStreamID: UInt32): Boolean; inline;

{ Validate frame size against declared max. }
function H2IsValidFrameSize(const ALen: UInt32;
  const AMaxFrameSize: UInt32): Boolean; inline;

{ Validate SETTINGS identifier. }
function H2IsValidSettingIdentifier(const AId: UInt16): Boolean; inline;

{ Get frame type name for diagnostics. }
function H2FrameTypeName(const AType: Byte): string;

{ Get error code name for diagnostics. }
function H2ErrorCodeName(const ACode: UInt32): string;

implementation

uses
  nextpas.core.text.conv;

{ -- Frame header codec -- }

function H2DecodeFrameHeader(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AHeader: TH2FrameHeader): Boolean;
begin
  AHeader := Default(TH2FrameHeader);
  if (ABuf = nil) or (ALen < H2_FRAME_HEADER_SIZE) then
    Exit(False);
  { Length: 24 bits big-endian }
  AHeader.Len := (UInt32(Byte(ABuf[0])) shl 16) or
                 (UInt32(Byte(ABuf[1])) shl 8) or
                  UInt32(Byte(ABuf[2]));
  { Type: 8 bits }
  AHeader.FrameType := Byte(ABuf[3]);
  { Flags: 8 bits }
  AHeader.Flags := Byte(ABuf[4]);
  { Stream ID: 1 reserved bit + 31 bits big-endian }
  AHeader.StreamID := ((UInt32(Byte(ABuf[5])) and $7F) shl 24) or
                       (UInt32(Byte(ABuf[6])) shl 16) or
                       (UInt32(Byte(ABuf[7])) shl 8) or
                        UInt32(Byte(ABuf[8]));
  Result := True;
end;

procedure H2EncodeFrameHeader(const AHeader: TH2FrameHeader;
  const ABuf: PAnsiChar);
begin
  { Length: 24 bits big-endian }
  ABuf[0] := AnsiChar(Byte(AHeader.Len shr 16));
  ABuf[1] := AnsiChar(Byte(AHeader.Len shr 8));
  ABuf[2] := AnsiChar(Byte(AHeader.Len));
  { Type: 8 bits }
  ABuf[3] := AnsiChar(AHeader.FrameType);
  { Flags: 8 bits }
  ABuf[4] := AnsiChar(AHeader.Flags);
  { Stream ID: reserved bit must be 0, 31 bits big-endian }
  ABuf[5] := AnsiChar(Byte((AHeader.StreamID shr 24) and $7F));
  ABuf[6] := AnsiChar(Byte(AHeader.StreamID shr 16));
  ABuf[7] := AnsiChar(Byte(AHeader.StreamID shr 8));
  ABuf[8] := AnsiChar(Byte(AHeader.StreamID));
end;

{ -- Full frame codec -- }

function H2DecodeFrame(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
var
  LPayloadLen: SizeUInt;
begin
  AConsumed := 0;
  AFrame := Default(TH2Frame);
  if not H2DecodeFrameHeader(ABuf, ALen, AFrame.Header) then
    Exit(False);
  LPayloadLen := SizeUInt(AFrame.Header.Len);
  if LPayloadLen > H2_ABSOLUTE_MAX_FRAME_SIZE then
    Exit(False);
  if SizeUInt(H2_FRAME_HEADER_SIZE) + LPayloadLen > ALen then
    Exit(False);
  if LPayloadLen > 0 then
  begin
    SetLength(AFrame.Payload, SizeInt(LPayloadLen));
    Move(ABuf[H2_FRAME_HEADER_SIZE], AFrame.Payload[1], LPayloadLen);
  end;
  AConsumed := SizeUInt(H2_FRAME_HEADER_SIZE) + LPayloadLen;
  Result := True;
end;

function H2EncodeFrame(const AFrameType: Byte; const AFlags: Byte;
  const AStreamID: UInt32; const APayload: AnsiString): AnsiString;
var
  LHdr: TH2FrameHeader;
  LPayloadLen: SizeUInt;
begin
  LPayloadLen := SizeUInt(Length(APayload));
  if LPayloadLen > H2_ABSOLUTE_MAX_FRAME_SIZE then
    raise EHttpError.Create('HTTP/2 frame payload exceeds 24-bit length limit');
  LHdr.Len := UInt32(LPayloadLen);
  LHdr.FrameType := AFrameType;
  LHdr.Flags := AFlags;
  LHdr.StreamID := AStreamID;
  SetLength(Result, H2_FRAME_HEADER_SIZE + SizeInt(LPayloadLen));
  H2EncodeFrameHeader(LHdr, @Result[1]);
  if LPayloadLen > 0 then
    Move(APayload[1], Result[H2_FRAME_HEADER_SIZE + 1], LPayloadLen);
end;

{ -- SETTINGS frame codec -- }

procedure H2EncodeSettingEntry(const AEntry: TH2SettingEntry;
  const ABuf: PAnsiChar);
begin
  ABuf[0] := AnsiChar(Byte(AEntry.Identifier shr 8));
  ABuf[1] := AnsiChar(Byte(AEntry.Identifier));
  ABuf[2] := AnsiChar(Byte(AEntry.Value shr 24));
  ABuf[3] := AnsiChar(Byte(AEntry.Value shr 16));
  ABuf[4] := AnsiChar(Byte(AEntry.Value shr 8));
  ABuf[5] := AnsiChar(Byte(AEntry.Value));
end;

function H2DecodeSettingsPayload(const APayload: AnsiString;
  out AEntries: TH2SettingEntries): Boolean;
var
  LLen: SizeInt;
  LCount: SizeInt;
  LI: SizeInt;
  LOff: SizeInt;
begin
  LLen := Length(APayload);
  if LLen mod 6 <> 0 then
    Exit(False);
  LCount := LLen div 6;
  SetLength(AEntries, LCount);
  for LI := 0 to LCount - 1 do
  begin
    LOff := LI * 6 + 1;
    AEntries[LI].Identifier :=
      (UInt16(APayload[LOff]) shl 8) or UInt16(APayload[LOff + 1]);
    AEntries[LI].Value :=
      (UInt32(APayload[LOff + 2]) shl 24) or
      (UInt32(APayload[LOff + 3]) shl 16) or
      (UInt32(APayload[LOff + 4]) shl 8) or
       UInt32(APayload[LOff + 5]);
  end;
  Result := True;
end;

function H2EncodeSettingsPayload(const AEntries: TH2SettingEntries): AnsiString;
var
  LI: SizeInt;
begin
  SetLength(Result, Length(AEntries) * 6);
  for LI := 0 to High(AEntries) do
    H2EncodeSettingEntry(AEntries[LI], @Result[LI * 6 + 1]);
end;

{ -- GOAWAY frame codec -- }

function H2DecodeGoaway(const APayload: AnsiString;
  out ALastStreamID: UInt32; out AErrorCode: UInt32;
  out ADebugData: AnsiString): Boolean;
var
  LLen: SizeInt;
begin
  LLen := Length(APayload);
  if LLen < 8 then
    Exit(False);
  ALastStreamID := ((UInt32(APayload[1]) and $7F) shl 24) or
                    (UInt32(APayload[2]) shl 16) or
                    (UInt32(APayload[3]) shl 8) or
                     UInt32(APayload[4]);
  AErrorCode := (UInt32(APayload[5]) shl 24) or
                (UInt32(APayload[6]) shl 16) or
                (UInt32(APayload[7]) shl 8) or
                 UInt32(APayload[8]);
  if LLen > 8 then
  begin
    SetLength(ADebugData, LLen - 8);
    Move(APayload[9], ADebugData[1], LLen - 8);
  end
  else
    ADebugData := '';
  Result := True;
end;

function H2EncodeGoaway(const ALastStreamID: UInt32;
  const AErrorCode: UInt32; const ADebugData: AnsiString): AnsiString;
var
  LDebugLen: SizeInt;
begin
  LDebugLen := Length(ADebugData);
  SetLength(Result, 8 + LDebugLen);
  { Last-Stream-ID: 1 reserved bit + 31 bits }
  Result[1] := AnsiChar((ALastStreamID shr 24) and $7F);
  Result[2] := AnsiChar(ALastStreamID shr 16);
  Result[3] := AnsiChar(ALastStreamID shr 8);
  Result[4] := AnsiChar(ALastStreamID);
  { Error code: 32 bits }
  Result[5] := AnsiChar(AErrorCode shr 24);
  Result[6] := AnsiChar(AErrorCode shr 16);
  Result[7] := AnsiChar(AErrorCode shr 8);
  Result[8] := AnsiChar(AErrorCode);
  if LDebugLen > 0 then
    Move(ADebugData[1], Result[9], LDebugLen);
end;

{ -- WINDOW_UPDATE frame codec -- }

function H2DecodeWindowUpdate(const APayload: AnsiString;
  out AWindowSizeIncrement: UInt32): Boolean;
begin
  if Length(APayload) <> 4 then
    Exit(False);
  AWindowSizeIncrement :=
    ((UInt32(APayload[1]) and $7F) shl 24) or
     (UInt32(APayload[2]) shl 16) or
     (UInt32(APayload[3]) shl 8) or
      UInt32(APayload[4]);
  Result := True;
end;

function H2EncodeWindowUpdate(const AWindowSizeIncrement: UInt32): AnsiString;
begin
  SetLength(Result, 4);
  Result[1] := AnsiChar((AWindowSizeIncrement shr 24) and $7F);
  Result[2] := AnsiChar(AWindowSizeIncrement shr 16);
  Result[3] := AnsiChar(AWindowSizeIncrement shr 8);
  Result[4] := AnsiChar(AWindowSizeIncrement);
end;

{ -- RST_STREAM frame codec -- }

function H2DecodeRstStream(const APayload: AnsiString;
  out AErrorCode: UInt32): Boolean;
begin
  if Length(APayload) <> 4 then
    Exit(False);
  AErrorCode := (UInt32(APayload[1]) shl 24) or
                (UInt32(APayload[2]) shl 16) or
                (UInt32(APayload[3]) shl 8) or
                 UInt32(APayload[4]);
  Result := True;
end;

function H2EncodeRstStream(const AErrorCode: UInt32): AnsiString;
begin
  SetLength(Result, 4);
  Result[1] := AnsiChar(AErrorCode shr 24);
  Result[2] := AnsiChar(AErrorCode shr 16);
  Result[3] := AnsiChar(AErrorCode shr 8);
  Result[4] := AnsiChar(AErrorCode);
end;

{ -- PING frame codec -- }

function H2DecodePing(const APayload: AnsiString;
  out AData: UInt64): Boolean;
begin
  if Length(APayload) <> 8 then
    Exit(False);
  AData := (UInt64(APayload[1]) shl 56) or
           (UInt64(APayload[2]) shl 48) or
           (UInt64(APayload[3]) shl 40) or
           (UInt64(APayload[4]) shl 32) or
           (UInt64(APayload[5]) shl 24) or
           (UInt64(APayload[6]) shl 16) or
           (UInt64(APayload[7]) shl 8) or
            UInt64(APayload[8]);
  Result := True;
end;

function H2EncodePing(const AData: UInt64): AnsiString;
begin
  SetLength(Result, 8);
  Result[1] := AnsiChar(AData shr 56);
  Result[2] := AnsiChar(AData shr 48);
  Result[3] := AnsiChar(AData shr 40);
  Result[4] := AnsiChar(AData shr 32);
  Result[5] := AnsiChar(AData shr 24);
  Result[6] := AnsiChar(AData shr 16);
  Result[7] := AnsiChar(AData shr 8);
  Result[8] := AnsiChar(AData);
end;

{ -- Validation helpers -- }

function H2IsValidStreamID(const AStreamID: UInt32): Boolean; inline;
begin
  { Stream ID 0 is connection-level, >0 is stream-level.
    Client-initiated: odd, server-initiated: even.
    Stream ID 0 is valid only for connection-level frames (SETTINGS, GOAWAY, etc.)
    For stream frames, stream ID must be > 0. }
  Result := (AStreamID > 0) and (AStreamID <= $7FFFFFFF);
end;

function H2IsValidFrameSize(const ALen: UInt32;
  const AMaxFrameSize: UInt32): Boolean; inline;
begin
  Result := ALen <= AMaxFrameSize;
end;

function H2IsValidSettingIdentifier(const AId: UInt16): Boolean; inline;
begin
  Result := (AId >= H2_SETTINGS_HEADER_TABLE_SIZE) and
            (AId <= H2_SETTINGS_MAX_HEADER_LIST_SIZE);
end;

function H2FrameTypeName(const AType: Byte): string;
begin
  case AType of
    H2_FRAME_DATA:          Result := 'DATA';
    H2_FRAME_HEADERS:       Result := 'HEADERS';
    H2_FRAME_PRIORITY:      Result := 'PRIORITY';
    H2_FRAME_RST_STREAM:    Result := 'RST_STREAM';
    H2_FRAME_SETTINGS:      Result := 'SETTINGS';
    H2_FRAME_PUSH_PROMISE:  Result := 'PUSH_PROMISE';
    H2_FRAME_PING:          Result := 'PING';
    H2_FRAME_GOAWAY:        Result := 'GOAWAY';
    H2_FRAME_WINDOW_UPDATE: Result := 'WINDOW_UPDATE';
    H2_FRAME_CONTINUATION:  Result := 'CONTINUATION';
  else
    Result := 'UNKNOWN(' + IntToStr(Int64(AType)) + ')';
  end;
end;

function H2ErrorCodeName(const ACode: UInt32): string;
begin
  case ACode of
    H2_ERR_NO_ERROR:            Result := 'NO_ERROR';
    H2_ERR_PROTOCOL_ERROR:      Result := 'PROTOCOL_ERROR';
    H2_ERR_INTERNAL_ERROR:      Result := 'INTERNAL_ERROR';
    H2_ERR_FLOW_CONTROL_ERROR:  Result := 'FLOW_CONTROL_ERROR';
    H2_ERR_SETTINGS_TIMEOUT:    Result := 'SETTINGS_TIMEOUT';
    H2_ERR_STREAM_CLOSED:       Result := 'STREAM_CLOSED';
    H2_ERR_FRAME_SIZE_ERROR:    Result := 'FRAME_SIZE_ERROR';
    H2_ERR_REFUSED_STREAM:      Result := 'REFUSED_STREAM';
    H2_ERR_CANCEL:              Result := 'CANCEL';
    H2_ERR_COMPRESSION_ERROR:   Result := 'COMPRESSION_ERROR';
    H2_ERR_CONNECT_ERROR:       Result := 'CONNECT_ERROR';
    H2_ERR_ENHANCE_YOUR_CALM:   Result := 'ENHANCE_YOUR_CALM';
    H2_ERR_INADEQUATE_SECURITY: Result := 'INADEQUATE_SECURITY';
    H2_ERR_HTTP_1_1_REQUIRED:   Result := 'HTTP_1_1_REQUIRED';
  else
    Result := 'UNKNOWN(' + IntToStr(Int64(ACode)) + ')';
  end;
end;

end.
