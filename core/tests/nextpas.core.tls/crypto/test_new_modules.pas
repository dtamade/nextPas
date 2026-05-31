program test_new_modules;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.websocket,
  nextpas.core.tls.quic.crypto,
  nextpas.core.tls.dane.pure,
  nextpas.core.tls.http2.alpn,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.x509;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

procedure TestWebSocketFrameBuilder;
var
  LWS: TWebSocketConnection;
  LStream: TMemoryStream;
  LFrame: TWebSocketFrame;
begin
  WriteLn('Test: WebSocket frame build + read roundtrip');
  LStream := TMemoryStream.Create;
  try
    LWS := TWebSocketConnection.Create(LStream, False);
    try
      LWS.SendText('Hello WebSocket');
      LStream.Position := 0;
      Check(LWS.ReadFrame(LFrame), 'Should read frame');
      Check(LFrame.FIN, 'FIN should be set');
      Check(LFrame.Opcode = wsOpText, 'Opcode should be text');
      Check(not LFrame.Masked, 'Server frames not masked');
      Check(TEncoding.UTF8.GetString(LFrame.Payload) = 'Hello WebSocket', 'Payload match');
    finally
      LWS.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestWebSocketMaskedFrame;
var
  LWS: TWebSocketConnection;
  LStream: TMemoryStream;
  LFrame: TWebSocketFrame;
begin
  WriteLn('Test: WebSocket client masked frame');
  LStream := TMemoryStream.Create;
  try
    LWS := TWebSocketConnection.Create(LStream, True);
    try
      LWS.SendBinary(TEncoding.ASCII.GetBytes('test'));
      LStream.Position := 0;
      Check(LWS.ReadFrame(LFrame), 'Should read masked frame');
      Check(LFrame.Opcode = wsOpBinary, 'Opcode should be binary');
      Check(TEncoding.ASCII.GetString(LFrame.Payload) = 'test', 'Unmasked payload match');
    finally
      LWS.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestWebSocketUpgradeKey;
var
  LWS: TWebSocketConnection;
  LStream: TMemoryStream;
  LKey, LRequest: string;
begin
  WriteLn('Test: WebSocket upgrade request');
  LStream := TMemoryStream.Create;
  try
    LWS := TWebSocketConnection.Create(LStream, True);
    try
      LRequest := LWS.BuildUpgradeRequest('example.com', '/ws', LKey);
      Check(Pos('Upgrade: websocket', LRequest) > 0, 'Has Upgrade header');
      Check(Pos('Sec-WebSocket-Key: ' + LKey, LRequest) > 0, 'Has key');
      Check(Length(LKey) > 0, 'Key not empty');
    finally
      LWS.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestQUICInitialKeys;
var
  LConnID, LSecret: TBytes;
  LKeys: TQUICKeys;
begin
  WriteLn('Test: QUIC initial key derivation');
  SetLength(LConnID, 8);
  FillChar(LConnID[0], 8, $AB);

  LSecret := QUICDeriveInitialSecret(LConnID);
  Check(Length(LSecret) = 32, 'Initial secret = 32 bytes');

  LKeys := QUICDeriveClientInitialKeys(LSecret);
  Check(Length(LKeys.Key) = 16, 'Client key = 16 bytes');
  Check(Length(LKeys.IV) = 12, 'Client IV = 12 bytes');
  Check(Length(LKeys.HP) = 16, 'Client HP = 16 bytes');

  LKeys := QUICDeriveServerInitialKeys(LSecret);
  Check(Length(LKeys.Key) = 16, 'Server key = 16 bytes');
  Check(Length(LKeys.IV) = 12, 'Server IV = 12 bytes');
  Check(Length(LKeys.HP) = 16, 'Server HP = 16 bytes');
end;

procedure TestQUICDeterminism;
var
  LConnID, LSecret1, LSecret2: TBytes;
begin
  WriteLn('Test: QUIC key derivation is deterministic');
  SetLength(LConnID, 4);
  FillChar(LConnID[0], 4, $CD);

  LSecret1 := QUICDeriveInitialSecret(LConnID);
  LSecret2 := QUICDeriveInitialSecret(LConnID);
  Check(CompareMem(@LSecret1[0], @LSecret2[0], 32), 'Same input = same output');
end;

procedure TestDANEVerification;
var
  LRecords: array[0..0] of TTLSARecord;
  LCertDER, LHash: TBytes;
  LError: string;
begin
  WriteLn('Test: DANE TLSA verification');
  LCertDER := TEncoding.ASCII.GetBytes('fake cert data for testing');
  LHash := SHA256(LCertDER);

  LRecords[0] := BuildTLSARecord(3, 0, 1, LHash);
  Check(VerifyDANE(LRecords, LCertDER, LError), 'Matching hash should pass');

  LHash[0] := LHash[0] xor $FF;
  LRecords[0] := BuildTLSARecord(3, 0, 1, LHash);
  Check(not VerifyDANE(LRecords, LCertDER, LError), 'Wrong hash should fail');
end;

procedure TestDANENoRecords;
var
  LRecords: array of TTLSARecord;
  LCertDER: TBytes;
  LError: string;
begin
  WriteLn('Test: DANE with no records');
  SetLength(LRecords, 0);
  LCertDER := TEncoding.ASCII.GetBytes('cert');
  Check(not VerifyDANE(LRecords, LCertDER, LError), 'No records should fail');
  Check(LError = 'No TLSA records provided', 'Correct error message');
end;

procedure TestConnectionPool;
var
  LPool: TSSLConnectionPool;
begin
  WriteLn('Test: Connection pool lifecycle');
  LPool := TSSLConnectionPool.Create(4, 30);
  try
    Check(LPool.ActiveCount = 0, 'Initially no active');
    Check(LPool.IdleCount = 0, 'Initially no idle');
    Check(LPool.Acquire('example.com', 443) = nil, 'No connection to acquire');
  finally
    LPool.Free;
  end;
end;

procedure TestHTTP2ALPNProtocols;
var
  LProtos: TStringArray;
begin
  WriteLn('Test: HTTP/2 ALPN protocols');
  LProtos := GetHTTP2ALPNProtocols;
  Check(Length(LProtos) = 2, 'Should have 2 protocols');
  Check(LProtos[0] = 'h2', 'First should be h2');
  Check(LProtos[1] = 'http/1.1', 'Second should be http/1.1');
end;

begin
  WriteLn('=== New Module Unit Tests ===');
  WriteLn('');

  TestWebSocketFrameBuilder;
  TestWebSocketMaskedFrame;
  TestWebSocketUpgradeKey;
  TestQUICInitialKeys;
  TestQUICDeterminism;
  TestDANEVerification;
  TestDANENoRecords;
  TestConnectionPool;
  TestHTTP2ALPNProtocols;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
