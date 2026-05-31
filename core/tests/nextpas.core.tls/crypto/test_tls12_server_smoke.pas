program test_tls12_server_smoke;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.x509,
  nextpas.core.tls.pem;

function LoadFile(const APath: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

var
  LPort: Word;
  LServerSocket, LClientHandle: Longint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
  LClientStream: TSocketStream;
  LConfig: TTLS12ServerConfig;
  LState: TTLS12ServerState;
  LError: string;
  LOk: Boolean;
  LCertPEM, LKeyPEM: TBytes;
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LOne: Longint;
begin
  if ParamCount < 3 then
  begin
    WriteLn('Usage: test_tls12_server_smoke <port> <cert.pem> <key.pem>');
    Halt(2);
  end;

  LPort := StrToInt(ParamStr(1));

  LCertPEM := LoadFile(ParamStr(2));
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromFile(ParamStr(2));
    LBlocks := LReader.GetCertificates;
    if Length(LBlocks) = 0 then
    begin
      WriteLn('[FAIL] No certificate found in PEM');
      Halt(1);
    end;
    LConfig.CertificateDER := LBlocks[0].Data;
  finally
    LReader.Free;
  end;

  LConfig.Certificate := TX509Certificate.Create;
  LConfig.Certificate.LoadFromDER(LConfig.CertificateDER);

  LKeyPEM := LoadFile(ParamStr(3));
  LConfig.PrivateKeyDER := LKeyPEM;
  LConfig.SupportEMS := True;
  SetLength(LConfig.ALPNProtocols, 2);
  LConfig.ALPNProtocols[0] := 'h2';
  LConfig.ALPNProtocols[1] := 'http/1.1';

  WriteLn('[INFO] Starting TLS 1.2 server on port ', LPort);

  LServerSocket := fpSocket(AF_INET, SOCK_STREAM, 0);
  if LServerSocket < 0 then
  begin
    WriteLn('[FAIL] Cannot create socket');
    Halt(1);
  end;

  fpSetSockOpt(LServerSocket, SOL_SOCKET, SO_REUSEADDR, @LOne, SizeOf(LOne));

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(LPort);
  LAddr.sin_addr.s_addr := 0; // INADDR_ANY

  if fpBind(LServerSocket, @LAddr, SizeOf(LAddr)) <> 0 then
  begin
    WriteLn('[FAIL] Cannot bind to port ', LPort);
    Halt(1);
  end;

  if fpListen(LServerSocket, 1) <> 0 then
  begin
    WriteLn('[FAIL] Cannot listen');
    Halt(1);
  end;

  WriteLn('[INFO] Waiting for client...');
  LAddrLen := SizeOf(LAddr);
  LClientHandle := fpAccept(LServerSocket, @LAddr, @LAddrLen);
  if LClientHandle < 0 then
  begin
    WriteLn('[FAIL] Accept failed');
    Halt(1);
  end;

  LClientStream := TSocketStream.Create(LClientHandle);
  try
    WriteLn('[INFO] Client connected, starting handshake...');
    LOk := TryTLS12ServerHandshake(LClientStream, LConfig, LState, LError);

    if LOk then
    begin
      WriteLn('[PASS] TLS 1.2 server handshake completed');
      WriteLn('  Cipher suite: 0x', IntToHex(LState.CipherSuite, 4));
      WriteLn('  EMS: ', LState.HasEMS);
    end
    else
    begin
      WriteLn('[FAIL] TLS 1.2 server handshake failed: ', LError);
      Halt(1);
    end;
  finally
    LClientStream.Free;
  end;

  CloseSocket(LServerSocket);
  LConfig.Certificate.Free;
end.
