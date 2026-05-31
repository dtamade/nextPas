program test_tls12_fragmented_clienthello;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls12.clienthello,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.x509;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure AppendBytes(var ADest: TBytes; const ASrc: TBytes);
var
  LOldLen: Integer;
begin
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + Length(ASrc));
  Move(ASrc[0], ADest[LOldLen], Length(ASrc));
end;

function BuildRecord(AContentType: Byte; const APayload: TBytes): TBytes;
begin
  Result := TLS12BuildRecordHeader(AContentType, Length(APayload));
  AppendBytes(Result, APayload);
end;

procedure WriteBytes(AStream: TStream; const AData: TBytes);
begin
  if Length(AData) > 0 then
    AStream.WriteBuffer(AData[0], Length(AData));
end;

function CopyBytes(const AData: TBytes; AOffset, ACount: Integer): TBytes;
begin
  Result := Copy(AData, AOffset, ACount);
end;

function BuildClientHello: TBytes;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  I: Integer;
begin
  LOptions.ServerName := 'fragment.test';
  SetLength(LOptions.ALPNProtocols, 0);
  LOptions.SupportEMS := True;
  SetLength(LOptions.SessionID, 0);
  SetLength(LOptions.SessionTicket, 0);

  SetLength(LRandom, 32);
  for I := 0 to High(LRandom) do
    LRandom[I] := Byte($A0 + I);

  Result := BuildTLS12ClientHello(LOptions, LRandom);
end;

procedure WriteFragmentedClientHello(AStream: TStream; const AClientHello: TBytes);
var
  LFirstLen, LSecondLen: Integer;
  LCCS: TBytes;
begin
  LFirstLen := 8;
  LSecondLen := 13;

  WriteBytes(AStream, BuildRecord(TLS12_CONTENT_HANDSHAKE, CopyBytes(AClientHello, 0, LFirstLen)));

  SetLength(LCCS, 1);
  LCCS[0] := 1;
  WriteBytes(AStream, BuildRecord(TLS12_CONTENT_CHANGE_CIPHER_SPEC, LCCS));

  WriteBytes(AStream, BuildRecord(TLS12_CONTENT_HANDSHAKE, CopyBytes(AClientHello, LFirstLen, LSecondLen)));
  WriteBytes(AStream, BuildRecord(TLS12_CONTENT_HANDSHAKE,
    CopyBytes(AClientHello, LFirstLen + LSecondLen, Length(AClientHello) - LFirstLen - LSecondLen)));

  AStream.Position := 0;
end;

procedure TestServerReadsFragmentedClientHello;
var
  LStream: TMemoryStream;
  LClientHello: TBytes;
  LConfig: TTLS12ServerConfig;
  LState: TTLS12ServerState;
  LError: string;
begin
  WriteLn('TestServerReadsFragmentedClientHello');
  LClientHello := BuildClientHello;

  LStream := TMemoryStream.Create;
  LConfig.Certificate := TX509Certificate.Create;
  try
    WriteFragmentedClientHello(LStream, LClientHello);

    LConfig.CertificateDER := TBytes.Create($30);
    SetLength(LConfig.PrivateKeyDER, 0);
    LConfig.ServerName := 'fragment.test';
    LConfig.SupportEMS := True;
    SetLength(LConfig.ALPNProtocols, 0);
    LConfig.RequestClientCert := False;
    LConfig.SNICallback := nil;

    Check(not TryTLS12ServerHandshake(LStream, LConfig, LState, LError),
      'Handshake fails later because the test key is intentionally missing');
    Check(Pos('SKE signature failed', LError) > 0,
      'Server consumed complete fragmented ClientHello before failing later');
  finally
    LConfig.Certificate.Free;
    LStream.Free;
  end;
end;

procedure TestReadHandshakeMessageSkipsCCSAndReassembles;
var
  LStream: TMemoryStream;
  LClientHello, LBody, LFull: TBytes;
  LType: Byte;
  LError: string;
begin
  WriteLn('TestReadHandshakeMessageSkipsCCSAndReassembles');
  LClientHello := BuildClientHello;

  LStream := TMemoryStream.Create;
  try
    WriteFragmentedClientHello(LStream, LClientHello);

    Check(TLS12ReadHandshakeMessage(LStream, LType, LBody, LFull, LError),
      'Fragmented ClientHello is reassembled');
    Check(LType = TLS12_HANDSHAKE_CLIENT_HELLO, 'Handshake type is ClientHello');
    Check(Length(LFull) = Length(LClientHello), 'Full message length preserved');
    Check(Length(LBody) = Length(LClientHello) - 4, 'Body length excludes handshake header');
    Check((Length(LBody) >= 34) and (LBody[0] = TLS12_VERSION_MAJOR) and (LBody[1] = TLS12_VERSION_MINOR),
      'Body starts at ClientHello version');
  finally
    LStream.Free;
  end;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestReadHandshakeMessageSkipsCCSAndReassembles;
  TestServerReadsFragmentedClientHello;

  WriteLn;
  WriteLn('TLS12 fragmented ClientHello tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
