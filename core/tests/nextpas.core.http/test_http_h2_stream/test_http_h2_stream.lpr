program test_http_h2_stream;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http.intf,
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
    Summary;
  end;
end.
