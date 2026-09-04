unit tls_test_sockets;

{ Test-support TCP socket helpers (flat TLS tests).
  Port of the legacy nextpas.core.tls examples/fafafa.examples.tcp unit, rebuilt on
  nextpas.core types only: ISSLConnection / ISSLCertificateVerification come
  from nextpas.core.tls.base, everything else is RTL sockets. Network tests
  use this instead of linking any non-core library. }

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.platform.error,
  nextpas.core.text.conv,
  {$IFDEF MSWINDOWS}
  WinSock2,
  {$ELSE}
  BaseUnix, Unix, Sockets, NetDB,
  {$ENDIF}
  nextpas.core.tls.base;

type
  TSocketHandle = {$IFDEF MSWINDOWS}TSocket{$ELSE}TSocket{$ENDIF};

const
  // FPC's Sockets unit doesn't always provide INVALID_SOCKET; normalize it here.
  INVALID_SOCKET: TSocketHandle = {$IFDEF MSWINDOWS}WinSock2.INVALID_SOCKET{$ELSE}TSocketHandle(-1){$ENDIF};

function InitNetwork(out AError: string): Boolean;
procedure CleanupNetwork;

function ConnectTCP(const AHost: string; APort: Word; ATimeoutSec: Integer = 10): TSocketHandle;
function SetSocketTimeout(ASocket: TSocketHandle; ATimeoutMs: Integer): Boolean;
function ListenTCP(APort: Word; const AAddress: string = '0.0.0.0'): TSocketHandle;
function AcceptConnection(AListenSocket: TSocketHandle): TSocketHandle;
procedure CloseSocket(var ASocket: TSocketHandle);
procedure GetCertificateVerificationInfo(AConnection: ISSLConnection;
  out AVerifyResult: Integer; out AVerifyResultString: string);

implementation

{$IFDEF MSWINDOWS}
function InitNetwork(out AError: string): Boolean;
var
  WSAData: TWSAData;
  Code: Integer;
  LBuf: array[0..255] of AnsiChar;
begin
  Code := WSAStartup($0202, WSAData);
  Result := (Code = 0);
  if Result then
    AError := ''
  else if platform_error_message(Code, @LBuf[0], SizeOf(LBuf)) > 0 then
    AError := string(PAnsiChar(@LBuf[0]))
  else
    AError := 'unknown error ' + IntToStr(Code);
end;

procedure CleanupNetwork;
begin
  WSACleanup;
end;
{$ELSE}
function InitNetwork(out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

procedure CleanupNetwork;
begin
  // no-op on Unix
end;
{$ENDIF}

{$IFDEF MSWINDOWS}
function ConnectTCP(const AHost: string; APort: Word; ATimeoutSec: Integer = 10): TSocketHandle;
var
  Addr: TSockAddr;
  HostEnt: PHostEnt;
begin
  Result := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Result = INVALID_SOCKET then
    raise Exception.Create('Unable to create socket');

  HostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
  if HostEnt = nil then
  begin
    closesocket(Result);
    raise Exception.CreateFmt('Unable to resolve host: %s', [AHost]);
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);
  Addr.sin_addr := PInAddr(HostEnt^.h_addr_list^)^;

  if WinSock2.connect(Result, Addr, SizeOf(Addr)) <> 0 then
  begin
    closesocket(Result);
    raise Exception.CreateFmt('Unable to connect to %s:%d', [AHost, APort]);
  end;
end;

function ListenTCP(APort: Word; const AAddress: string = '0.0.0.0'): TSocketHandle;
var
  Addr: TSockAddr;
  HostEnt: PHostEnt;
  OptVal: Integer;
begin
  Result := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Result = INVALID_SOCKET then
    raise Exception.Create('Unable to create listen socket');

  // Set SO_REUSEADDR
  OptVal := 1;
  if setsockopt(Result, SOL_SOCKET, SO_REUSEADDR, @OptVal, SizeOf(OptVal)) <> 0 then
  begin
    closesocket(Result);
    raise Exception.Create('Unable to set SO_REUSEADDR');
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);

  if AAddress = '0.0.0.0' then
    Addr.sin_addr.S_addr := INADDR_ANY
  else
  begin
    HostEnt := gethostbyname(PAnsiChar(AnsiString(AAddress)));
    if HostEnt = nil then
    begin
      closesocket(Result);
      raise Exception.CreateFmt('Unable to resolve bind address: %s', [AAddress]);
    end;
    Addr.sin_addr := PInAddr(HostEnt^.h_addr_list^)^;
  end;

  if bind(Result, Addr, SizeOf(Addr)) <> 0 then
  begin
    closesocket(Result);
    raise Exception.CreateFmt('Unable to bind to %s:%d', [AAddress, APort]);
  end;

  if listen(Result, SOMAXCONN) <> 0 then
  begin
    closesocket(Result);
    raise Exception.CreateFmt('Unable to listen on port %d', [APort]);
  end;
end;

function AcceptConnection(AListenSocket: TSocketHandle): TSocketHandle;
var
  Addr: TSockAddr;
  AddrLen: Integer;
begin
  AddrLen := SizeOf(Addr);
  Result := accept(AListenSocket, @Addr, @AddrLen);
  if Result = INVALID_SOCKET then
    raise Exception.Create('Accept failed');
end;

procedure CloseSocket(var ASocket: TSocketHandle);
begin
  if ASocket = INVALID_SOCKET then Exit;
  closesocket(ASocket);
  ASocket := INVALID_SOCKET;
end;

function SetSocketTimeout(ASocket: TSocketHandle; ATimeoutMs: Integer): Boolean;
var
  TimeVal: Integer;
begin
  TimeVal := ATimeoutMs;
  Result :=
    (setsockopt(ASocket, SOL_SOCKET, SO_RCVTIMEO, @TimeVal, SizeOf(TimeVal)) = 0) and
    (setsockopt(ASocket, SOL_SOCKET, SO_SNDTIMEO, @TimeVal, SizeOf(TimeVal)) = 0);
end;
{$ELSE}
function SetSocketTimeout(ASocket: TSocketHandle; ATimeoutMs: Integer): Boolean;
var
  TimeVal: TTimeVal;
begin
  // 黑洞/被墙地址的 TLS 握手会无限阻塞:内核收发超时在握手层生效,
  // 使网络测试离线时快速失败而不是挂死
  TimeVal.tv_sec := ATimeoutMs div 1000;
  TimeVal.tv_usec := (ATimeoutMs mod 1000) * 1000;
  Result :=
    (fpSetsockopt(ASocket, SOL_SOCKET, SO_RCVTIMEO, @TimeVal, SizeOf(TimeVal)) = 0) and
    (fpSetsockopt(ASocket, SOL_SOCKET, SO_SNDTIMEO, @TimeVal, SizeOf(TimeVal)) = 0);
end;

// 数字 IPv4 直接经 StrToHostAddr 解析；其余走名字解析。
// 不能只依赖名字解析：hosts/DNS 可能把数字串误解析到非预期地址
// （实测环境曾把 '127.0.0.1' 解析到 10.x 外网地址）。
// 注意 StrToHostAddr 返回主机字节序，sin_addr 需要 htonl 转网络字节序。
function ResolveAddressString(const AAddress: string; out ANetAddr: in_addr): Boolean;
var
  LEntry: THostEntry;
begin
  ANetAddr := StrToHostAddr(AAddress);
  if ANetAddr.s_addr <> 0 then
  begin
    ANetAddr.s_addr := htonl(ANetAddr.s_addr);
    Exit(True);
  end;
  Result := ResolveHostByName(AAddress, LEntry);
  if Result then
    ANetAddr := LEntry.Addr;
end;

function ConnectTCP(const AHost: string; APort: Word; ATimeoutSec: Integer = 10): TSocketHandle;
var
  Sock: cint;
  Addr: TInetSockAddr;
  HostEntry: THostEntry;
  Flags: LongInt;
  Fds: TFDSet;
  TimeVal: TTimeVal;
begin
  Sock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Sock < 0 then
    raise Exception.Create('Unable to create socket');

  // 数字 IPv4 直析，其余走名字解析（见 ResolveAddressString 注释）。
  if not ResolveAddressString(AHost, HostEntry.Addr) then
  begin
    fpClose(Sock);
    raise Exception.CreateFmt('Unable to resolve host: %s', [AHost]);
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);
  Addr.sin_addr := HostEntry.Addr;

  // 非阻塞 connect + select 等待,避免离线环境下阻塞挂死
  Flags := fpFcntl(Sock, F_GETFL, 0);
  fpFcntl(Sock, F_SETFL, Flags or O_NONBLOCK);

  if fpConnect(Sock, @Addr, SizeOf(Addr)) <> 0 then
  begin
    if fpGetErrno <> ESysEINPROGRESS then
    begin
      fpClose(Sock);
      raise Exception.CreateFmt('Unable to connect to %s:%d', [AHost, APort]);
    end;

    fpFD_ZERO(Fds);
    fpFD_SET(Sock, Fds);
    TimeVal.tv_sec := ATimeoutSec;
    TimeVal.tv_usec := 0;
    if fpSelect(Sock + 1, nil, @Fds, nil, @TimeVal) <= 0 then
    begin
      fpClose(Sock);
      raise Exception.CreateFmt('Timeout connecting to %s:%d', [AHost, APort]);
    end;
  end;

  // 恢复阻塞模式
  fpFcntl(Sock, F_SETFL, Flags);

  // 收发超时(内核级):黑洞/被墙地址下 TLS 握手不会响应,
  // 没有该超时 connect 后的握手会无限阻塞
  SetSocketTimeout(Sock, ATimeoutSec * 1000);

  Result := Sock;
end;

function ListenTCP(APort: Word; const AAddress: string = '0.0.0.0'): TSocketHandle;
var
  Sock: cint;
  Addr: TInetSockAddr;
  HostEntry: THostEntry;
  OptVal: cint;
begin
  Sock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Sock < 0 then
    raise Exception.Create('Unable to create listen socket');

  // Set SO_REUSEADDR
  OptVal := 1;
  if fpSetSockOpt(Sock, SOL_SOCKET, SO_REUSEADDR, @OptVal, SizeOf(OptVal)) <> 0 then
  begin
    fpClose(Sock);
    raise Exception.Create('Unable to set SO_REUSEADDR');
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);

  if AAddress = '0.0.0.0' then
    Addr.sin_addr.s_addr := 0  // INADDR_ANY
  else
  begin
    if not ResolveAddressString(AAddress, HostEntry.Addr) then
    begin
      fpClose(Sock);
      raise Exception.CreateFmt('Unable to resolve bind address: %s', [AAddress]);
    end;
    Addr.sin_addr := HostEntry.Addr;
  end;

  if fpBind(Sock, @Addr, SizeOf(Addr)) <> 0 then
  begin
    fpClose(Sock);
    raise Exception.CreateFmt('Unable to bind to %s:%d', [AAddress, APort]);
  end;

  if fpListen(Sock, SOMAXCONN) <> 0 then
  begin
    fpClose(Sock);
    raise Exception.CreateFmt('Unable to listen on port %d', [APort]);
  end;

  Result := Sock;
end;

function AcceptConnection(AListenSocket: TSocketHandle): TSocketHandle;
var
  Addr: TInetSockAddr;
  AddrLen: TSockLen;
begin
  AddrLen := SizeOf(Addr);
  Result := fpAccept(AListenSocket, @Addr, @AddrLen);
  if Result < 0 then
    raise Exception.Create('Accept failed');
end;

procedure CloseSocket(var ASocket: TSocketHandle);
begin
  if ASocket = INVALID_SOCKET then Exit;
  fpClose(ASocket);
  ASocket := INVALID_SOCKET;
end;
{$ENDIF}

procedure GetCertificateVerificationInfo(AConnection: ISSLConnection;
  out AVerifyResult: Integer; out AVerifyResultString: string);
var
  LCertVerify: ISSLCertificateVerification;
begin
  AVerifyResult := -1;
  AVerifyResultString := 'Not verified';

  if AConnection = nil then
    Exit;

  if Supports(AConnection, ISSLCertificateVerification, LCertVerify) then
  begin
    AVerifyResult := LCertVerify.GetVerifyResult;
    AVerifyResultString := LCertVerify.GetVerifyResultString;
  end
  else
  begin
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    AVerifyResult := AConnection.GetVerifyResult;
    AVerifyResultString := AConnection.GetVerifyResultString;
    {$POP}
  end;
end;

end.