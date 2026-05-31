program test_tls12_cbc_e2e;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.crypto.tls12record;

var
  LPort: Word;
  LSocket: TInetSocket;
  LState: TTLS12ClientState;
  LError: string;
  LOk: Boolean;
  LProtos: array[0..0] of string;
  LRequest, LEncrypted, LDecrypted, LRecvData: TBytes;
  LContentType: Byte;
  LHeader: TBytes;
  LLen, LRead: Integer;
  LEncError, LDecError: string;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls12_cbc_e2e <port>');
    Halt(2);
  end;

  LPort := StrToInt(ParamStr(1));
  WriteLn('[INFO] Connecting to localhost:', LPort, ' (CBC mode)');

  try
    LSocket := TInetSocket.Create('127.0.0.1', LPort);
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] TCP connect failed: ', E.Message);
      Halt(1);
    end;
  end;

  try
    LProtos[0] := 'http/1.1';
    LOk := TryTLS12ClientHandshake(LSocket, 'localhost', LProtos, LState, LError);

    if not LOk then
    begin
      WriteLn('[FAIL] TLS 1.2 handshake failed: ', LError);
      Halt(1);
    end;

    WriteLn('[PASS] TLS 1.2 handshake completed');
    WriteLn('  Cipher suite: 0x', IntToHex(LState.CipherSuite, 4));

    // Verify it's actually CBC
    if Length(LState.ClientWriteMACKey) = 0 then
    begin
      WriteLn('[FAIL] Not a CBC cipher suite (no MAC key)');
      Halt(1);
    end;

    WriteLn('  MAC key length: ', Length(LState.ClientWriteMACKey));

    // Send HTTP GET using CBC record encryption
    LRequest := TEncoding.ASCII.GetBytes(
      'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10);

    if Length(LState.ClientWriteMACKey) > 32 then
    begin
      if not TLS12CBCEncrypt_SHA384(LState.ClientWriteKey, LState.ClientWriteMACKey,
        LState.ClientSeqNum, 23, LRequest, LEncrypted, LEncError) then
      begin
        WriteLn('[FAIL] CBC encrypt failed: ', LEncError);
        Halt(1);
      end;
    end
    else
    begin
      if not TLS12CBCEncrypt_SHA256(LState.ClientWriteKey, LState.ClientWriteMACKey,
        LState.ClientSeqNum, 23, LRequest, LEncrypted, LEncError) then
      begin
        WriteLn('[FAIL] CBC encrypt failed: ', LEncError);
        Halt(1);
      end;
    end;
    Inc(LState.ClientSeqNum);

    SetLength(LHeader, 5);
    LHeader[0] := 23; LHeader[1] := 3; LHeader[2] := 3;
    LHeader[3] := Byte(Length(LEncrypted) shr 8);
    LHeader[4] := Byte(Length(LEncrypted));
    LSocket.WriteBuffer(LHeader[0], 5);
    LSocket.WriteBuffer(LEncrypted[0], Length(LEncrypted));

    // Read response
    SetLength(LHeader, 5);
    LRead := LSocket.Read(LHeader[0], 5);
    if LRead <> 5 then
    begin
      WriteLn('[FAIL] Failed to read response header');
      Halt(1);
    end;

    LContentType := LHeader[0];
    LLen := (Integer(LHeader[3]) shl 8) or Integer(LHeader[4]);

    if LContentType <> 23 then
    begin
      WriteLn('[FAIL] Expected app data, got type: ', LContentType);
      Halt(1);
    end;

    SetLength(LRecvData, LLen);
    LRead := LSocket.Read(LRecvData[0], LLen);
    if LRead <> LLen then
    begin
      WriteLn('[FAIL] Short read');
      Halt(1);
    end;

    if Length(LState.ServerWriteMACKey) > 32 then
    begin
      if not TLS12CBCDecrypt_SHA384(LState.ServerWriteKey, LState.ServerWriteMACKey,
        LState.ServerSeqNum, 23, LRecvData, LDecrypted, LDecError) then
      begin
        WriteLn('[FAIL] CBC decrypt failed: ', LDecError);
        Halt(1);
      end;
    end
    else
    begin
      if not TLS12CBCDecrypt_SHA256(LState.ServerWriteKey, LState.ServerWriteMACKey,
        LState.ServerSeqNum, 23, LRecvData, LDecrypted, LDecError) then
      begin
        WriteLn('[FAIL] CBC decrypt failed: ', LDecError);
        Halt(1);
      end;
    end;

    WriteLn('[PASS] CBC application data exchange succeeded');
    WriteLn('  Response: ', Length(LDecrypted), ' bytes');
    WriteLn('  First line: ', Copy(TEncoding.ASCII.GetString(LDecrypted), 1, 30));
    Halt(0);
  finally
    LSocket.Free;
  end;
end.
