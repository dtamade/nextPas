program test_tls12_openssl_smoke;

{$mode objfpc}{$H+}

uses
  nextpas.core.tls.socket_stream,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.ciphersuite,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.tls12.chacha20record, nextpas.core.base, nextpas.core.exception, nextpas.core.io.intf, nextpas.core.text.conv,
  nextpas.core.net.sync, nextpas.core.net.intf;

var
  LPort: Word;
  LTcp: ITcpStream;
  LStream: IStream;
  LState: TTLS12ClientState;
  LError: string;
  LOk: Boolean;
  LProtos: array[0..0] of string;
  LRequest, LEncrypted, LDecrypted, LRecvData: TBytes;
  LContentType: Byte;
  LHeader: TBytes;
  LLen, LRead: Integer;
  LSuiteInfo: TTLS12CipherSuiteInfo;

procedure WriteAll(const AStream: ITcpStream; const AData: TBytes);
var
  LOff, LWrote: SizeUInt;
begin
  LOff := 0;
  while LOff < SizeUInt(Length(AData)) do
  begin
    LWrote := AStream.Write(AData[LOff], SizeUInt(Length(AData)) - LOff);
    if LWrote = 0 then
    begin
      WriteLn('[FAIL] socket write returned 0');
      Halt(1);
    end;
    Inc(LOff, LWrote);
  end;
end;

begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls12_openssl_smoke <port>');
    Halt(2);
  end;

  LPort := StrToInt(ParamStr(1));
  WriteLn('[INFO] Connecting to localhost:', LPort);

  try
    LTcp := TcpConnect('127.0.0.1', LPort);
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] TCP connect failed: ', E.Message);
      Halt(1);
    end;
  end;

  try
    LProtos[0] := 'http/1.1';
    LStream := SocketHandleAsIStream(THandle((LTcp as ITcpSocketRuntime).NativeSocketHandle));
    LOk := TryTLS12ClientHandshake(LStream, 'localhost', LProtos, LState, LError);

    if not LOk then
    begin
      WriteLn('[FAIL] TLS 1.2 handshake failed: ', LError);
      Halt(1);
    end;

    WriteLn('[PASS] TLS 1.2 handshake completed');
    WriteLn('  Cipher suite: 0x', IntToHex(LState.CipherSuite, 4));
    WriteLn('  EMS: ', LState.HasEMS);

    LRequest := StringToUTF8Bytes('GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10);

    TLS12GetCipherSuiteInfo(LState.CipherSuite, LSuiteInfo);
    LOk := False;
    case LSuiteInfo.RecordMode of
      rmChaCha20Poly1305:
        LOk := TLS12ChaCha20Poly1305EncryptRecord(LState.ClientWriteKey, LState.ClientWriteIV,
          LState.ClientSeqNum, 23, LRequest, LEncrypted, LError);
    else
      LOk := TLS12GCMEncryptRecord(LState.ClientWriteKey, LState.ClientWriteIV,
        LState.ClientSeqNum, 23, LRequest, LEncrypted, LError);
    end;
    if not LOk then
    begin
      WriteLn('[FAIL] Encrypt app data failed: ', LError);
      Halt(1);
    end;
    Inc(LState.ClientSeqNum);

    SetLength(LHeader, 5);
    LHeader[0] := 23;
    LHeader[1] := 3;
    LHeader[2] := 3;
    LHeader[3] := Byte(Length(LEncrypted) shr 8);
    LHeader[4] := Byte(Length(LEncrypted));
    WriteAll(LTcp, LHeader);
    WriteAll(LTcp, LEncrypted);

    SetLength(LHeader, 5);
    LRead := Integer(LTcp.Read(LHeader[0], 5));
    if LRead <> 5 then
    begin
      WriteLn('[FAIL] Failed to read response record header');
      Halt(1);
    end;

    LContentType := LHeader[0];
    LLen := (Integer(LHeader[3]) shl 8) or Integer(LHeader[4]);

    if LContentType <> 23 then
    begin
      WriteLn('[FAIL] Expected application data (23), got: ', LContentType);
      Halt(1);
    end;

    SetLength(LRecvData, LLen);
    LRead := Integer(LTcp.Read(LRecvData[0], LLen));
    if LRead <> LLen then
    begin
      WriteLn('[FAIL] Short read on response data');
      Halt(1);
    end;

    LOk := False;
    case LSuiteInfo.RecordMode of
      rmChaCha20Poly1305:
        LOk := TLS12ChaCha20Poly1305DecryptRecord(LState.ServerWriteKey, LState.ServerWriteIV,
          LState.ServerSeqNum, 23, LRecvData, LDecrypted, LError);
    else
      LOk := TLS12GCMDecryptRecord(LState.ServerWriteKey, LState.ServerWriteIV,
        LState.ServerSeqNum, 23, LRecvData, LDecrypted, LError);
    end;
    if not LOk then
    begin
      WriteLn('[FAIL] Decrypt response failed: ', LError);
      Halt(1);
    end;

    WriteLn('[PASS] Application data exchange succeeded');
    WriteLn('  Response length: ', Length(LDecrypted), ' bytes');
    WriteLn('  First line: ', Copy(UTF8BytesToString(LDecrypted), 1, 40));
    Halt(0);
  finally
    LTcp := nil;
  end;
end.
