program test_tls12_resume_reject_fallback;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.x509,
  nextpas.core.tls.pem;

type
  TTLS12ServerThread = class(TThread)
  private
    FListenSocket: Longint;
    FPort: Word;
    FConfig: TTLS12ServerConfig;
    FState: TTLS12ServerState;
    FHandshakeOk: Boolean;
    FError: string;
    procedure BindAndListen;
    procedure LoadConfig;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    property Port: Word read FPort;
    property HandshakeOk: Boolean read FHandshakeOk;
    property HandshakeError: string read FError;
    property State: TTLS12ServerState read FState;
  end;

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

function LoadFileBytes(const APath: string): TBytes;
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

function LoadCertificateDER(const APath: string): TBytes;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
begin
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromFile(APath);
    LBlocks := LReader.GetCertificates;
    if Length(LBlocks) = 0 then
      raise Exception.Create('No certificate found in ' + APath);
    Result := LBlocks[0].Data;
  finally
    LReader.Free;
  end;
end;

constructor TTLS12ServerThread.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FListenSocket := -1;
  FillChar(FState, SizeOf(FState), 0);
  FillChar(FConfig, SizeOf(FConfig), 0);
  LoadConfig;
  BindAndListen;
  Start;
end;

destructor TTLS12ServerThread.Destroy;
begin
  if FListenSocket >= 0 then
    CloseSocket(FListenSocket);
  if Assigned(FConfig.Certificate) then
    FConfig.Certificate.Free;
  inherited Destroy;
end;

procedure TTLS12ServerThread.LoadConfig;
begin
  FConfig.CertificateDER := LoadCertificateDER('examples/localhost.crt');
  FConfig.PrivateKeyDER := LoadFileBytes('examples/localhost.key');
  FConfig.Certificate := TX509Certificate.Create;
  FConfig.Certificate.LoadFromDER(FConfig.CertificateDER);
  FConfig.ServerName := 'localhost';
  FConfig.SupportEMS := True;
  SetLength(FConfig.ALPNProtocols, 0);
  FConfig.RequestClientCert := False;
  FConfig.SNICallback := nil;
  SetLength(FConfig.CipherSuites, 0);
  SetLength(FConfig.SessionID, 0);
  FConfig.SessionCacheEnabled := True;
  FConfig.SessionLookup := nil;
end;

procedure TTLS12ServerThread.BindAndListen;
var
  LAddr: TInetSockAddr;
  LOne: Longint;
  LAddrLen: TSockLen;
begin
  FListenSocket := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FListenSocket < 0 then
    raise Exception.Create('socket() failed');

  LOne := 1;
  fpSetSockOpt(FListenSocket, SOL_SOCKET, SO_REUSEADDR, @LOne, SizeOf(LOne));

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(0);
  LAddr.sin_addr.s_addr := HostToNet(Cardinal($7F000001));

  if fpBind(FListenSocket, @LAddr, SizeOf(LAddr)) <> 0 then
    raise Exception.Create('bind() failed');
  if fpListen(FListenSocket, 1) <> 0 then
    raise Exception.Create('listen() failed');

  LAddrLen := SizeOf(LAddr);
  if fpGetSockName(FListenSocket, @LAddr, @LAddrLen) <> 0 then
    raise Exception.Create('getsockname() failed');
  FPort := ntohs(LAddr.sin_port);
end;

procedure TTLS12ServerThread.Execute;
var
  LClientHandle: Longint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
  LStream: TSocketStream;
begin
  LAddrLen := SizeOf(LAddr);
  LClientHandle := fpAccept(FListenSocket, @LAddr, @LAddrLen);
  if LClientHandle < 0 then
  begin
    FError := 'accept() failed';
    Exit;
  end;

  LStream := TSocketStream.Create(LClientHandle);
  try
    FHandshakeOk := TryTLS12ServerHandshake(LStream, FConfig, FState, FError);
  finally
    LStream.Free;
  end;
end;

procedure WaitForServer(AThread: TTLS12ServerThread; const AStep: string);
begin
  AThread.WaitFor;
  Check(AThread.HandshakeOk, AStep + ' server handshake succeeded: ' + AThread.HandshakeError);
end;

procedure TestResumeRejectFallsBackToFullHandshake;
var
  LServer1, LServer2: TTLS12ServerThread;
  LSocket: TInetSocket;
  LState1, LState2: TTLS12ClientState;
  LError: string;
  LProtos: array of string;
  LCache: TTLS12SessionCache;
  LInitialSessionID: TBytes;
begin
  WriteLn('TestResumeRejectFallsBackToFullHandshake');
  SetLength(LProtos, 0);

  LServer1 := TTLS12ServerThread.Create;
  try
    LSocket := TInetSocket.Create('127.0.0.1', LServer1.Port);
    try
      Check(TryTLS12ClientHandshake(LSocket, 'localhost', LProtos, LState1, LError),
        'Initial full handshake succeeds: ' + LError);
      Check(not LState1.Resumed, 'Initial handshake is not resumed');
      Check(Length(LState1.SessionID) > 0, 'Initial handshake receives session ID');
      Check(Length(LState1.PeerCertificatesDER) > 0, 'Initial handshake receives certificate chain');
      LInitialSessionID := Copy(LState1.SessionID);
    finally
      LSocket.Free;
    end;

    WaitForServer(LServer1, 'Initial');
  finally
    LServer1.Free;
  end;

  LCache.SessionID := Copy(LState1.SessionID);
  LCache.MasterSecret := Copy(LState1.MasterSecret);
  LCache.CipherSuite := LState1.CipherSuite;
  LCache.ServerName := 'localhost';

  LServer2 := TTLS12ServerThread.Create;
  try
    LSocket := TInetSocket.Create('127.0.0.1', LServer2.Port);
    try
      Check(TryTLS12ClientHandshakeWithResume(LSocket, 'localhost', LProtos, LCache, LState2, LError),
        'Rejected resumption falls back to full handshake: ' + LError);
      Check(not LState2.Resumed, 'Fallback handshake is marked non-resumed');
      Check(Length(LState2.PeerCertificatesDER) > 0, 'Fallback handshake still reads certificate chain');
      Check(Length(LState2.MasterSecret) = 48, 'Fallback handshake derives full master secret');
      Check(Length(LState2.SessionID) > 0, 'Fallback handshake stores server session ID');
      Check((Length(LInitialSessionID) <> Length(LState2.SessionID)) or
        (not CompareMem(@LInitialSessionID[0], @LState2.SessionID[0], Length(LState2.SessionID))),
        'Fallback handshake accepts a new session ID');
    finally
      LSocket.Free;
    end;

    WaitForServer(LServer2, 'Fallback');
  finally
    LServer2.Free;
  end;

  if Assigned(LState1.PeerCertificate) then
    LState1.PeerCertificate.Free;
  if Assigned(LState2.PeerCertificate) then
    LState2.PeerCertificate.Free;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestResumeRejectFallsBackToFullHandshake;

  WriteLn;
  WriteLn('TLS12 resume reject fallback tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then
    Halt(1);
end.
