program test_http_h2_stream;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.stream,
  nextpas.core.http.impl.h2.types,
  nextpas.core.testing;

function BytesToAnsiString(const ABytes: TBytes): AnsiString;
begin
  if Length(ABytes) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@ABytes[0]), Length(ABytes));
end;

function ReadAnsiString(const AReader: IH2BodyReader;
  const ACount: SizeUInt): AnsiString;
begin
  SetLength(Result, ACount);
  if ACount = 0 then
    Exit('');
  SetLength(Result, AReader.Read(Result[1], ACount));
end;

function EncodeHeaders(const AHeaders: array of THPackHeader): AnsiString;
var
  LEncoder: THPackEncoder;
begin
  LEncoder.Init;
  Result := LEncoder.Encode(AHeaders);
end;

procedure CollectHeaders(const AHeaders: IHttpHeaders; out ACollected: string);
var
  LCollected: string;
begin
  LCollected := '';
  Check(AHeaders <> nil, 'headers must not be nil');
  AHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LCollected <> '' then
        LCollected := LCollected + '|';
      LCollected := LCollected + AName + '=' + AValue;
    end);
  ACollected := LCollected;
end;

procedure TestHeadersWithEndStreamDecodeAndTransition;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..3] of THPackHeader;
  LCollected: string;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(1, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LHeaders[1].Name := ':path';
    LHeaders[1].Value := '/';
    LHeaders[2].Name := ':scheme';
    LHeaders[2].Value := 'https';
    LHeaders[3].Name := ':authority';
    LHeaders[3].Value := 'example.com';

    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM,
      EncodeHeaders(LHeaders));

    CheckEqual(Int64(Ord(h2ssHalfClosedRemote)), Int64(Ord(LStream.State)),
      'headers with END_STREAM transition state');
    Check(LStream.EndStreamReceived, 'headers with END_STREAM mark remote end');
    Check(LStream.IsRequestReady, 'request ready after END_HEADERS + END_STREAM');
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=GET|:path=/|:scheme=https|:authority=example.com',
      LCollected, 'decoded headers');
  finally
    LStream.Free;
  end;
end;

procedure TestHeadersAndContinuationAssembleHeaderBlock;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..2] of THPackHeader;
  LBlock: AnsiString;
  LFirstFragment: AnsiString;
  LSecondFragment: AnsiString;
  LHeadersPayload: AnsiString;
  LCollected: string;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(3, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'POST';
    LHeaders[1].Name := 'content-type';
    LHeaders[1].Value := 'application/json';
    LHeaders[2].Name := 'x-trace';
    LHeaders[2].Value := 'stream-test';
    LBlock := EncodeHeaders(LHeaders);
    LFirstFragment := Copy(LBlock, 1, 4);
    LSecondFragment := Copy(LBlock, 5, Length(LBlock) - 4);
    LHeadersPayload := AnsiChar(#1) + AnsiString(#0#0#0#0#5) + LFirstFragment + AnsiChar(#0);

    LStream.OnHeaders(H2_FLAG_HEADERS_PADDED or H2_FLAG_HEADERS_PRIORITY,
      LHeadersPayload);
    CheckEqual(Int64(Ord(h2ssOpen)), Int64(Ord(LStream.State)),
      'headers without END_STREAM open stream');
    Check(not LStream.IsRequestReady, 'headers incomplete before continuation');
    LStream.OnContinuation(H2_FLAG_CONTINUATION_END_HEADERS, LSecondFragment);

    Check(not LStream.EndStreamReceived, 'continuation does not end stream');
    Check(not LStream.IsRequestReady, 'headers only do not make request ready');
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=POST|content-type=application/json|x-trace=stream-test',
      LCollected, 'assembled headers');
  finally
    LStream.Free;
  end;
end;

procedure TestBodyReaderReleasesFlowCreditsAndWindowOverflowResetsStream;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
  LReader: IH2BodyReader;
begin
  LConnectionFlow.Init(8, 4);
  LDecoder.Init;
  LStream := TH2Stream.Create(5, 8, 4, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'POST';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    LStream.OnData(0, 'AB');
    LStream.OnData(0, 'CD');
    CheckEqual(Int64(0), Int64(LConnectionFlow.RecvWindow.AvailableWindow),
      'connection recv window consumed by data');
    LStream.OnData(0, 'E');
    Check(LStream.ResetReceived,
      'data beyond receive window resets stream');
    CheckEqual(Int64(H2_ERR_FLOW_CONTROL_ERROR), Int64(LStream.ResetCode),
      'overflow reset uses FLOW_CONTROL_ERROR');
    CheckEqual('', string(BytesToAnsiString(LStream.BodyBuffer)),
      'overflow reset discards buffered body');

    LReader := LStream.CreateBodyReader;
    CheckEqual(Int64(5), Int64(LReader.StreamID), 'body reader stream id');
    CheckEqual('', string(ReadAnsiString(LReader, 3)),
      'reset stream body reader yields no bytes');
    CheckEqual(Int64(4), Int64(LConnectionFlow.RecvWindow.AvailableWindow),
      'reset stream releases connection flow credits');
  finally
    LReader := nil;
    LStream.Free;
  end;
end;

procedure TestWindowUpdateRestoresWriteCapacityAndLocalEndStreamClosesWriteSide;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
begin
  LConnectionFlow.Init(8, 8);
  LDecoder.Init;
  LStream := TH2Stream.Create(7, 4, 8, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    Check(LStream.CanWriteData, 'stream initially writable');
    LStream.ReserveSendCapacity(4);
    LStream.CommitSend(4);
    Check(not LStream.HasCapacity, 'stream send window exhausted');
    LStream.OnWindowUpdate(2);
    Check(LStream.HasCapacity, 'window update restores capacity');
    LStream.MarkEndStreamSent;
    Check(LStream.EndStreamSent, 'local end stream tracked');
    CheckEqual(Int64(Ord(h2ssHalfClosedLocal)), Int64(Ord(LStream.State)),
      'local END_STREAM transitions to half-closed local');
    Check(not LStream.CanWriteData, 'half-closed local stops writes');
  finally
    LStream.Free;
  end;
end;

procedure TestResetDiscardsPendingBuffersAndReservations;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
begin
  LConnectionFlow.Init(8, 8);
  LDecoder.Init;
  LStream := TH2Stream.Create(9, 4, 4, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'POST';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LStream.ReserveSendCapacity(2);
    LStream.OnData(0, 'abc');

    CheckEqual(Int64(6), Int64(LConnectionFlow.SendWindow.AvailableWindow),
      'reserved send bytes reduce connection send capacity');
    CheckEqual(Int64(5), Int64(LConnectionFlow.RecvWindow.AvailableWindow),
      'received data reduces connection recv capacity');

    LStream.Reset(H2_ERR_CANCEL);

    Check(LStream.ResetReceived, 'reset recorded');
    CheckEqual(Int64(H2_ERR_CANCEL), Int64(LStream.ResetCode),
      'reset code stored');
    CheckEqual(Int64(Ord(h2ssClosed)), Int64(Ord(LStream.State)),
      'reset closes stream');
    CheckEqual(Int64(0), Int64(Length(LStream.BodyBuffer)),
      'reset discards buffered body');
    CheckEqual(Int64(8), Int64(LConnectionFlow.SendWindow.AvailableWindow),
      'reset releases reserved send capacity');
    CheckEqual(Int64(8), Int64(LConnectionFlow.RecvWindow.AvailableWindow),
      'reset releases unread recv capacity');
  finally
    LStream.Free;
  end;
end;

{ -- New state transition tests -- }

procedure TestIdleStreamState;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(11, 4096, 4096, LConnectionFlow, LDecoder);
  try
    CheckEqual(Int64(Ord(h2ssIdle)), Int64(Ord(LStream.State)),
      'fresh stream starts in idle state');
    Check(not LStream.EndStreamReceived, 'idle stream has no end stream');
    Check(not LStream.EndStreamSent, 'idle stream has no end stream sent');
    Check(not LStream.ResetReceived, 'idle stream not reset');
  finally
    LStream.Free;
  end;
end;

procedure TestIdleStreamCannotWriteData;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(13, 4096, 4096, LConnectionFlow, LDecoder);
  try
    Check(not LStream.CanWriteData, 'idle stream cannot write data');
    Check(not LStream.IsRequestReady, 'idle stream is not ready');
  finally
    LStream.Free;
  end;
end;

procedure TestHeadersWithoutEndStreamTransitionsToOpen;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..1] of THPackHeader;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(15, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LHeaders[1].Name := ':path';
    LHeaders[1].Value := '/';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    CheckEqual(Int64(Ord(h2ssOpen)), Int64(Ord(LStream.State)),
      'headers without END_STREAM transitions to open');
    Check(not LStream.EndStreamReceived, 'stream still open for data');
    Check(LStream.Headers <> nil, 'END_HEADERS decodes headers');
  finally
    LStream.Free;
  end;
end;

procedure TestHeadersWithPriorityFlag;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LPayload: AnsiString;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(17, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LPayload := AnsiChar(#0) + AnsiChar(#0) + AnsiChar(#0) + AnsiChar(#0) + AnsiChar(#0) +
      EncodeHeaders(LHeaders);
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_PRIORITY,
      LPayload);
    CheckEqual(Int64(Ord(h2ssOpen)), Int64(Ord(LStream.State)),
      'priority headers stream is open');
    Check(LStream.Headers <> nil, 'priority headers decoded');
  finally
    LStream.Free;
  end;
end;

procedure TestHeadersWithPaddedFlag;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBlock: AnsiString;
  LCollected: string;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(19, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LBlock := EncodeHeaders(LHeaders);
    LBlock := AnsiChar(#3) + LBlock + 'XXX';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_PADDED,
      LBlock);
    CheckEqual(Int64(Ord(h2ssOpen)), Int64(Ord(LStream.State)),
      'padded headers stream is open');
    Check(LStream.Headers <> nil, 'padded headers decoded');
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=GET', LCollected, 'padded headers decoded correctly');
  finally
    LStream.Free;
  end;
end;

procedure TestHeadersZeroPadding;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBlock: AnsiString;
  LCollected: string;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(21, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LBlock := EncodeHeaders(LHeaders);
    LBlock := AnsiChar(#0) + LBlock;
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_PADDED,
      LBlock);
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=GET', LCollected, 'zero padded headers decoded');
  finally
    LStream.Free;
  end;
end;

procedure TestCanWriteDataAfterStateChange;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(23, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LStream.MarkEndStreamSent;
    Check(not LStream.CanWriteData, 'half-closed local cannot write');
  finally
    LStream.Free;
  end;
end;

{ -- Padding tests -- }

procedure TestDataPaddedFlag;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
  LPayload: AnsiString;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(25, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LPayload := AnsiChar(#2) + 'AB' + 'XX';
    LStream.OnData(H2_FLAG_DATA_PADDED, LPayload);
    CheckEqual('AB', string(BytesToAnsiString(LStream.BodyBuffer)),
      'padded data payload decoded');
  finally
    LStream.Free;
  end;
end;

procedure TestDataZeroPadding;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(27, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LStream.OnData(H2_FLAG_DATA_PADDED, AnsiChar(#0) + 'data');
    CheckEqual('data', string(BytesToAnsiString(LStream.BodyBuffer)),
      'zero padding data decoded');
  finally
    LStream.Free;
  end;
end;

{ -- RST_STREAM tests -- }

procedure TestRstStreamOnOpenStream;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(29, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    CheckEqual(Int64(Ord(h2ssOpen)), Int64(Ord(LStream.State)), 'stream is open');

    LStream.OnRstStream(H2_ERR_CANCEL);

    Check(LStream.ResetReceived, 'rst stream recorded');
    CheckEqual(Int64(H2_ERR_CANCEL), Int64(LStream.ResetCode),
      'rst stream error code');
    CheckEqual(Int64(Ord(h2ssClosed)), Int64(Ord(LStream.State)),
      'rst stream closes stream');
    CheckEqual(Int64(0), Int64(Length(LStream.BodyBuffer)),
      'rst stream discards body');
  finally
    LStream.Free;
  end;
end;

procedure TestMultipleContinuationFragments;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..4] of THPackHeader;
  LStream: TH2Stream;
  LBlock: AnsiString;
  LCollected: string;
  LOff: SizeInt;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(33, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LHeaders[1].Name := ':path';
    LHeaders[1].Value := '/test';
    LHeaders[2].Name := 'x-first';
    LHeaders[2].Value := '1';
    LHeaders[3].Name := 'x-second';
    LHeaders[3].Value := '2';
    LHeaders[4].Name := 'x-third';
    LHeaders[4].Value := '3';
    LBlock := EncodeHeaders(LHeaders);

    LOff := 1;
    LStream.OnHeaders(0, Copy(LBlock, LOff, 2));
    Inc(LOff, 2);
    LStream.OnContinuation(0, Copy(LBlock, LOff, 2));
    Inc(LOff, 2);
    LStream.OnContinuation(H2_FLAG_CONTINUATION_END_HEADERS,
      Copy(LBlock, LOff, Length(LBlock) - LOff + 1));

    Check(not LStream.EndStreamReceived, 'multiple continuation no end stream');
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=GET|:path=/test|x-first=1|x-second=2|x-third=3',
      LCollected, 'multiple continuations assemble correctly');
  finally
    LStream.Free;
  end;
end;

procedure TestContinuationWithoutHeaders;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
  LHeaders: array[0..0] of THPackHeader;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(35, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnContinuation(H2_FLAG_CONTINUATION_END_HEADERS,
      EncodeHeaders(LHeaders));
    Check(not LStream.IsRequestReady,
      'continuation without headers does not set request ready');
  finally
    LStream.Free;
  end;
end;

{ -- Flow control tests -- }

procedure TestReserveBeyondStreamCapacity;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBefore: UInt32;
begin
  LConnectionFlow.Init(8, 8);
  LDecoder.Init;
  LStream := TH2Stream.Create(37, 4, 8, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LBefore := LStream.AvailableSendCapacity;
    LStream.ReserveSendCapacity(UInt32(9999));
    CheckEqual(LBefore, LStream.AvailableSendCapacity,
      'reserve beyond capacity does not reduce available capacity');
  finally
    LStream.Free;
  end;
end;

procedure TestCommitSendExceedsReserved;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(39, 1024, 1024, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LStream.CommitSend(1);
    Check(LStream.ResetReceived,
      'commit send without prior reserve resets stream');
  finally
    LStream.Free;
  end;
end;

procedure TestReserveAndReleaseThroughReset;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBefore: UInt32;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(41, 1024, 1024, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LBefore := LStream.AvailableSendCapacity;
    LStream.ReserveSendCapacity(100);
    Check(LStream.AvailableSendCapacity < LBefore,
      'reserve reduced available capacity');
    LStream.Reset(H2_ERR_CANCEL);
    CheckEqual(LBefore, LStream.AvailableSendCapacity,
      'reset releases reserved capacity');
  finally
    LStream.Free;
  end;
end;

{ -- Body reader tests -- }

procedure TestBodyReaderEmpty;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LReader: IH2BodyReader;
  LBuf: Byte;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(45, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    LReader := LStream.CreateBodyReader;
    CheckEqual(Int64(45), Int64(LReader.StreamID), 'body reader stream id');
    CheckEqual(SizeUInt(0), LReader.Read(LBuf, 1),
      'empty body reader yields no bytes');
  finally
    LReader := nil;
    LStream.Free;
  end;
end;

procedure TestDiscardUnreadBody;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LReader: IH2BodyReader;
  LRecvBefore: Int64;
  LBuf: array[0..9] of Byte;
  LRead: SizeUInt;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(47, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));
    LStream.OnData(0, 'hello');

    LReader := LStream.CreateBodyReader;
    LRecvBefore := LConnectionFlow.RecvWindow.AvailableWindow;
    LStream.DiscardUnreadBody;
    LReader := nil;
    CheckEqual(LRecvBefore + 5, LConnectionFlow.RecvWindow.AvailableWindow,
      'discard releases recv window credits');
  finally
    LStream.Free;
  end;
end;

{ -- Trailers tests -- }

procedure TestTrailersStoredSeparately;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..2] of THPackHeader;
  LTrailerHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LCollected: string;
  LTrailerCollected: string;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(49, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'POST';
    LHeaders[1].Name := ':path';
    LHeaders[1].Value := '/upload';
    LHeaders[2].Name := 'content-type';
    LHeaders[2].Value := 'text/plain';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    LTrailerHeaders[0].Name := 'x-trailer';
    LTrailerHeaders[0].Value := 'done';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM,
      EncodeHeaders(LTrailerHeaders));

    Check(LStream.EndStreamReceived,
      'trailers with END_STREAM marks stream end');
    CollectHeaders(LStream.Headers, LCollected);
    CheckEqual(':method=POST|:path=/upload|content-type=text/plain',
      LCollected, 'original headers not overwritten by trailers');
    if LStream.Trailers <> nil then
    begin
      CollectHeaders(LStream.Trailers, LTrailerCollected);
      CheckEqual('x-trailer=done', LTrailerCollected,
        'trailers stored separately');
    end
    else
      Check(False, 'trailers should not be nil');
  finally
    LStream.Free;
  end;
end;

{ -- Pending response body tests -- }

procedure TestPendingResponseBody;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBody: IStream;
  LGotBody: IStream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(51, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    Check(not LStream.HasPendingResponseBody,
      'no pending body initially');

    LBody := CreateBytesStream(256) as IStream;
    LStream.SetPendingResponseBody(LBody);
    Check(LStream.HasPendingResponseBody, 'has pending body after set');

    LGotBody := LStream.GetPendingResponseBody;
    Check(LGotBody <> nil, 'get pending body returns body');
    LStream.ClearPendingResponseBody;
    Check(not LStream.HasPendingResponseBody,
      'no pending body after clear');
  finally
    LStream.Free;
  end;
end;

{ -- Flow credit management tests -- }

procedure TestTakePendingWindowUpdate;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LReader: IH2BodyReader;
  LBuf: Byte;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(53, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    LStream.OnData(0, 'ABCD');
    LReader := LStream.CreateBodyReader;
    LReader.Read(LBuf, 4);
    LReader := nil;

    Check(LStream.TakePendingStreamWindowUpdate >= 4,
      'pending stream window accumulated');
    Check(LStream.TakePendingConnectionWindowUpdate >= 4,
      'pending connection window accumulated');
  finally
    LStream.Free;
  end;
end;

procedure TestApplyPeerInitialWindowSize;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
  LBefore: UInt32;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(55, 1024, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    LBefore := LStream.AvailableSendCapacity;
    LStream.ApplyPeerInitialWindowSize(2048);
    Check(LStream.AvailableSendCapacity > LBefore,
      'increased peer window makes more capacity');
  finally
    LStream.Free;
  end;
end;

{ -- Can write state tests -- }

procedure TestCanWriteDataReflectsState;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(57, 1024, 1024, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS, EncodeHeaders(LHeaders));

    Check(LStream.CanWriteData, 'open stream can write data');
    LStream.MarkEndStreamSent;
    Check(not LStream.CanWriteData, 'half-closed local cannot write data');
  finally
    LStream.Free;
  end;
end;

{ -- IH2StreamControl tests -- }

procedure TestImplementsIH2StreamControl;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(59, 4096, 4096, LConnectionFlow, LDecoder);
  try
    CheckEqual(UInt32(59), LStream.StreamID, 'stream ID via property');
    LStream.Reset(H2_ERR_REFUSED_STREAM);
    Check(LStream.ResetReceived, 'stream reset');
    CheckEqual(Int64(H2_ERR_REFUSED_STREAM), Int64(LStream.ResetCode),
      'reset code correct');
  finally
    LStream.Free;
  end;
end;

procedure TestStreamID;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(61, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM,
      EncodeHeaders(LHeaders));
    CheckEqual(UInt32(61), LStream.StreamID, 'correct stream ID');
  finally
    LStream.Free;
  end;
end;

{ -- Duplicate frame handling -- }

procedure TestDataBeforeHeaders;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(63, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LStream.OnData(0, 'data before headers');
    CheckEqual(Int64(0), Int64(Length(LStream.BodyBuffer)),
      'data without headers is silently dropped');
    CheckEqual(Int64(Ord(h2ssIdle)), Int64(Ord(LStream.State)),
      'data without headers keeps stream idle');
  finally
    LStream.Free;
  end;
end;

procedure TestEmptyHeadersBlock;
var
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LHeaders: array[0..0] of THPackHeader;
  LStream: TH2Stream;
begin
  LConnectionFlow.Init(8192, 8192);
  LDecoder.Init;
  LStream := TH2Stream.Create(65, 4096, 4096, LConnectionFlow, LDecoder);
  try
    LHeaders[0].Name := ':method';
    LHeaders[0].Value := 'GET';
    LStream.OnHeaders(H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, '');
    Check(LStream.IsRequestReady,
      'empty headers block still marks request ready');
    Check(LStream.Headers <> nil, 'empty headers block creates non-nil headers');
  finally
    LStream.Free;
  end;
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.stream') do
  begin
    Run('Headers with END_STREAM decode and transition',
      @TestHeadersWithEndStreamDecodeAndTransition);
    Run('Headers and CONTINUATION assemble header block',
      @TestHeadersAndContinuationAssembleHeaderBlock);
    Run('Body reader releases flow credits and window overflow resets stream',
      @TestBodyReaderReleasesFlowCreditsAndWindowOverflowResetsStream);
    Run('Window update restores write capacity and local END_STREAM closes write side',
      @TestWindowUpdateRestoresWriteCapacityAndLocalEndStreamClosesWriteSide);
    Run('Reset discards pending buffers and reservations',
      @TestResetDiscardsPendingBuffersAndReservations);
    { -- New tests: state transitions -- }
    Run('Idle stream starts with correct state',
      @TestIdleStreamState);
    Run('Cannot send data before headers on idle stream',
      @TestIdleStreamCannotWriteData);
    Run('Headers without END_STREAM creates open stream',
      @TestHeadersWithoutEndStreamTransitionsToOpen);
    Run('Headers with PRIORITY flag parses payload',
      @TestHeadersWithPriorityFlag);
    Run('Headers with PADDED flag parses padding',
      @TestHeadersWithPaddedFlag);
    Run('Headers zero padding is accepted',
      @TestHeadersZeroPadding);
    Run('Cannot send data on half closed local stream',
      @TestCanWriteDataAfterStateChange);
    { -- New tests: padding processing -- }
    Run('DATA with PADDED flag strips padding bytes',
      @TestDataPaddedFlag);
    Run('DATA with zero padding still delivers payload',
      @TestDataZeroPadding);
    { -- New tests: RST_STREAM handling -- }
    Run('RST_STREAM on open stream transitions to closed',
      @TestRstStreamOnOpenStream);
    Run('Multiple CONTINUATION fragments assemble',
      @TestMultipleContinuationFragments);
    Run('CONTINUATION without prior HEADERS is rejected',
      @TestContinuationWithoutHeaders);
    { -- New tests: flow control -- }
    Run('Reserve beyond stream capacity does not reduce capacity',
      @TestReserveBeyondStreamCapacity);
    Run('CommitSend exceeds reserved raises',
      @TestCommitSendExceedsReserved);
    { -- New tests: body reader -- }
    Run('Body reader on empty stream yields no bytes',
      @TestBodyReaderEmpty);
    Run('DiscardUnreadBody releases flow credits',
      @TestDiscardUnreadBody);
    { -- New tests: trailers -- }
    Run('Trailers stored separately from headers',
      @TestTrailersStoredSeparately);
    { -- New tests: pending response body -- }
    Run('Pending response body set and get',
      @TestPendingResponseBody);
    { -- New tests: flow credit management -- }
    Run('TakePendingWindowUpdate returns accumulated credits',
      @TestTakePendingWindowUpdate);
    Run('ApplyPeerInitialWindowSize adjusts stream window',
      @TestApplyPeerInitialWindowSize);
    { -- New tests: CAN_WRITE state -- }
    Run('CanWriteData reflects stream state',
      @TestCanWriteDataReflectsState);
    { -- New tests: IH2StreamControl -- }
    Run('Stream implements IH2StreamControl',
      @TestImplementsIH2StreamControl);
    Run('Stream has correct stream ID',
      @TestStreamID);
    { -- New tests: duplicate frame handling -- }
    Run('OnData before OnHeaders resets stream',
      @TestDataBeforeHeaders);
    Run('Empty HPACK block does not set headers',
      @TestEmptyHeadersBlock);
    Summary;
  end;
end.
