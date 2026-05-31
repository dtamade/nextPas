program bench_protocols;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.cookie,
  nextpas.core.sse,
  nextpas.core.sse.parser,
  nextpas.core.sse.base,
  nextpas.core.multipart,
  nextpas.core.websocket,
  nextpas.core.websocket.base;

var
  B: TBenchRunner;

{ ===== Cookie benchmarks ===== }

procedure BenchParseCookieHeader(aIters: Int64);
var
  it: Int64;
  LResult: TCookieArray;
begin
  for it := 1 to aIters do
    LResult := ParseCookieHeader('a=1; b=2; c=3; d=4; e=5');
end;

procedure BenchBuildSetCookie(aIters: Int64);
var
  it: Int64;
  LCookie: TSetCookie;
  LResult: string;
begin
  LCookie := Default(TSetCookie);
  LCookie.Name := 'session';
  LCookie.Value := 'abc123def456ghi789';
  LCookie.Domain := '.example.com';
  LCookie.Path := '/app';
  LCookie.MaxAge := 86400;
  LCookie.HasMaxAge := True;
  LCookie.Secure := True;
  LCookie.HttpOnly := True;
  LCookie.SameSite := TCookieSameSite.cssLax;
  for it := 1 to aIters do
    LResult := BuildSetCookieHeader(LCookie);
end;

procedure BenchParseCookieHeader10(aIters: Int64);
var
  it: Int64;
  LResult: TCookieArray;
begin
  for it := 1 to aIters do
    LResult := ParseCookieHeader('a=1; b=2; c=3; d=4; e=5; f=6; g=7; h=8; i=9; j=10');
end;

{ ===== SSE benchmarks ===== }

procedure BenchSseParseEvent(aIters: Int64);
var
  it: Int64;
  LEvents: TSseEventArray;
begin
  for it := 1 to aIters do
    LEvents := SseParseAll('data: hello' + #10 + #10);
end;

procedure BenchSseParseStream(aIters: Int64);
var
  it: Int64;
  LStream: string;
  LEvents: TSseEventArray;
  i: Integer;
begin
  LStream := '';
  for i := 1 to 100 do
    LStream := LStream + 'event: msg' + #10 + 'data: payload-' + IntToStr(i) + #10 + #10;
  for it := 1 to aIters do
    LEvents := SseParseAll(LStream);
end;

procedure BenchSseFeed(aIters: Int64);
var
  it: Int64;
  LChunks: array[0..9] of string;
  LParser: TSseParser;
  LEvent: TSseEvent;
  i: Integer;
  LBase: string;
begin
  { Build 10KB stream split into 10 chunks }
  LBase := '';
  for i := 1 to 100 do
    LBase := LBase + 'data: ' + StringOfChar('x', 90) + #10 + #10;
  for i := 0 to 9 do
    LChunks[i] := Copy(LBase, i * (Length(LBase) div 10) + 1, Length(LBase) div 10);

  for it := 1 to aIters do
  begin
    LParser := TSseParser.Create;
    for i := 0 to 9 do
      LParser.Feed(LChunks[i]);
    LParser.Finish;
    while LParser.TryReadEvent(LEvent) do
      { drain };
  end;
end;

{ ===== Multipart benchmarks ===== }

var
  GMultipartBody3: TBytes;
  GMultipartBoundary3: string;
  GMultipartBodyLarge: TBytes;
  GMultipartBoundaryLarge: string;

procedure InitMultipartData;
var
  LBody: string;
  LFileData: string;
begin
  GMultipartBoundary3 := '----WebKitFormBoundary7MA4YWxkTrZu0gW';
  LBody :=
    '------WebKitFormBoundary7MA4YWxkTrZu0gW' + #13#10 +
    'Content-Disposition: form-data; name="field1"' + #13#10 +
    #13#10 +
    'value1' + #13#10 +
    '------WebKitFormBoundary7MA4YWxkTrZu0gW' + #13#10 +
    'Content-Disposition: form-data; name="field2"' + #13#10 +
    #13#10 +
    'value2' + #13#10 +
    '------WebKitFormBoundary7MA4YWxkTrZu0gW' + #13#10 +
    'Content-Disposition: form-data; name="file"; filename="test.bin"' + #13#10 +
    'Content-Type: application/octet-stream' + #13#10 +
    #13#10 +
    StringOfChar('A', 1024) + #13#10 +
    '------WebKitFormBoundary7MA4YWxkTrZu0gW--' + #13#10;
  SetLength(GMultipartBody3, Length(LBody));
  Move(LBody[1], GMultipartBody3[0], Length(LBody));

  { Large: 10KB file }
  GMultipartBoundaryLarge := '----Boundary10K';
  LFileData := StringOfChar('B', 10240);
  LBody :=
    '------Boundary10K' + #13#10 +
    'Content-Disposition: form-data; name="bigfile"; filename="big.dat"' + #13#10 +
    'Content-Type: application/octet-stream' + #13#10 +
    #13#10 +
    LFileData + #13#10 +
    '------Boundary10K--' + #13#10;
  SetLength(GMultipartBodyLarge, Length(LBody));
  Move(LBody[1], GMultipartBodyLarge[0], Length(LBody));
end;

procedure BenchMultipartParse(aIters: Int64);
var
  it: Int64;
  LParts: TMultipartPartArray;
begin
  for it := 1 to aIters do
    LParts := ParseMultipart(GMultipartBody3, GMultipartBoundary3);
end;

procedure BenchMultipartExtractBoundary(aIters: Int64);
var
  it: Int64;
  LResult: string;
begin
  for it := 1 to aIters do
    LResult := MultipartExtractBoundary('multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW');
end;

procedure BenchMultipartLarge(aIters: Int64);
var
  it: Int64;
  LParts: TMultipartPartArray;
begin
  for it := 1 to aIters do
    LParts := ParseMultipart(GMultipartBodyLarge, GMultipartBoundaryLarge);
end;

{ ===== WebSocket benchmarks ===== }

var
  GWsPayload64: TBytes;
  GWsPayload4K: TBytes;
  GWsEncoded64Client: TBytes;
  GWsEncoded64Server: TBytes;

procedure InitWsData;
var
  LFrame: TWebSocketFrame;
  i: Integer;
begin
  SetLength(GWsPayload64, 64);
  for i := 0 to 63 do
    GWsPayload64[i] := Byte(i mod 256);

  SetLength(GWsPayload4K, 4096);
  for i := 0 to 4095 do
    GWsPayload4K[i] := Byte((i * 7) mod 256);

  { Pre-encode for decode benchmarks }
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  LFrame.Payload := GWsPayload64;
  GWsEncoded64Client := WebSocketEncodeFrame(LFrame, wsrClient);

  LFrame.Payload := GWsPayload64;
  GWsEncoded64Server := WebSocketEncodeFrame(LFrame, wsrServer);
end;

procedure BenchWsEncodeSmall(aIters: Int64);
var
  it: Int64;
  LFrame: TWebSocketFrame;
  LResult: TBytes;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  LFrame.Payload := GWsPayload64;
  for it := 1 to aIters do
    LResult := WebSocketEncodeFrame(LFrame, wsrClient);
end;

procedure BenchWsDecodeSmall(aIters: Int64);
var
  it: Int64;
  LFrame: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  for it := 1 to aIters do
    TryWebSocketDecodeFrame(GWsEncoded64Client, 0, wsrServer, LFrame, LConsumed);
end;

procedure BenchWsEncodeLarge(aIters: Int64);
var
  it: Int64;
  LFrame: TWebSocketFrame;
  LResult: TBytes;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_BINARY;
  LFrame.Payload := GWsPayload4K;
  for it := 1 to aIters do
    LResult := WebSocketEncodeFrame(LFrame, wsrClient);
end;

procedure BenchWsMask(aIters: Int64);
var
  it: Int64;
  LData: TBytes;
  LMaskKey: array[0..3] of Byte;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;
  for it := 1 to aIters do
  begin
    LData := Copy(GWsPayload4K);
    WebSocketMask(LData, LMaskKey);
  end;
end;

procedure BenchWsAcceptKey(aIters: Int64);
var
  it: Int64;
  LResult: string;
begin
  for it := 1 to aIters do
    LResult := WebSocketAcceptKey('dGhlIHNhbXBsZSBub25jZQ==');
end;

procedure BenchWsEncodeSmallServer(aIters: Int64);
var
  it: Int64;
  LFrame: TWebSocketFrame;
  LResult: TBytes;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  LFrame.Payload := GWsPayload64;
  for it := 1 to aIters do
    LResult := WebSocketEncodeFrame(LFrame, wsrServer);
end;

procedure BenchWsDecodeSmallServer(aIters: Int64);
var
  it: Int64;
  LFrame: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  for it := 1 to aIters do
    TryWebSocketDecodeFrame(GWsEncoded64Server, 0, wsrClient, LFrame, LConsumed);
end;

{ ===== Main ===== }

begin
  B := TBenchRunner.Create;
  try
    InitMultipartData;
    InitWsData;

    WriteLn('=== nextpas.core.http.protocols benchmark ===');
    WriteLn;

    WriteLn('--- Cookie ---');
    B.Run('ParseCookieHeader (5 cookies)', @BenchParseCookieHeader);
    B.Run('BuildSetCookie (all attrs)', @BenchBuildSetCookie);
    B.Run('ParseCookieHeader (10 cookies)', @BenchParseCookieHeader10);
    WriteLn;

    WriteLn('--- SSE ---');
    B.Run('SseParseEvent (single)', @BenchSseParseEvent);
    B.Run('SseParseStream (100 events)', @BenchSseParseStream);
    B.Run('SseFeed (10KB incremental)', @BenchSseFeed);
    WriteLn;

    WriteLn('--- Multipart ---');
    B.Run('MultipartParse (3 fields, 1KB)', @BenchMultipartParse);
    B.Run('MultipartExtractBoundary', @BenchMultipartExtractBoundary);
    B.Run('MultipartLarge (10KB file)', @BenchMultipartLarge);
    WriteLn;

    WriteLn('--- WebSocket (client/masked) ---');
    B.Run('WsEncodeSmall (64B, masked)', @BenchWsEncodeSmall);
    B.Run('WsDecodeSmall (64B, masked)', @BenchWsDecodeSmall);
    B.Run('WsEncodeLarge (4KB, masked)', @BenchWsEncodeLarge);
    B.Run('WsMask (4KB payload)', @BenchWsMask);
    B.Run('WsAcceptKey (SHA1+Base64)', @BenchWsAcceptKey);
    WriteLn;

    WriteLn('--- WebSocket (server/unmasked) ---');
    B.Run('WsEncodeSmall (64B, unmasked)', @BenchWsEncodeSmallServer);
    B.Run('WsDecodeSmall (64B, unmasked)', @BenchWsDecodeSmallServer);
    WriteLn;

    B.Summary;
  finally
    B.Free;
  end;
end.
