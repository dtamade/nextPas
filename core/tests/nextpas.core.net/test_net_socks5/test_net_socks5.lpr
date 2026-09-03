program test_net_socks5;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net,
  nextpas.core.net.tcp,
  nextpas.core.net.socks5,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.text.utf8, nextpas.core.base, nextpas.core.base.utils, nextpas.core.text;

var
  T: TTestSuite;

{ ---- 伪 SOCKS5 服务器（进程内，验证端到端拨号）---- }

type
  TFakeSocks5Mode = (
    fsmNoAuth,          { 协商选 noauth，CONNECT 成功，之后回显 }
    fsmUserPassOk,      { 协商选 userpass，凭据匹配，CONNECT 成功，回显 }
    fsmUserPassBad,     { 协商选 userpass，固定拒绝 [01,01] }
    fsmNoAccept,        { 协商回复 [05,FF] }
    fsmReplyHostUnreachable, { CONNECT 回复 REP=04 }
    fsmSilent,          { accept 后不响应（测握手超时） }
    fsmClose            { accept 后立即关闭（测连接中断） }
  );

const
  cFakeUser = 'alice';
  cFakePass = 's3cret';

var
  GFakePort: UInt16 = 0;
  GFakeReady: Int32 = 0;
  GFakeMode: TFakeSocks5Mode = fsmNoAuth;
  GFakeThread: TPlatformThreadHandle = nil;

const
  cMaxFrame = 1024;

{ 读满 ACount 字节；连接关闭/超时返回 False }
function ServerReadFully(const AStream: ITcpStream; var ABuf: array of Byte;
  ACount: Integer): Boolean;
var
  LPos: Integer;
  LN: SizeUInt;
begin
  Result := False;
  LPos := 0;
  while LPos < ACount do
  begin
    LN := AStream.Read(ABuf[LPos], ACount - LPos);
    if LN = 0 then
      Exit;
    Inc(LPos, Integer(LN));
  end;
  Result := True;
end;

function FakeSocks5Server(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LFrame: array[0..cMaxFrame - 1] of Byte;
  LN: SizeUInt;
  LAtyp, LNeed: Integer;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GFakePort := LListener.LocalAddr.Port;
  InterlockedExchange(GFakeReady, 1);
  LClient := LListener.Accept;

  if GFakeMode = fsmClose then
  begin
    LClient.Close;
    LListener.Close;
    Exit;
  end;
  if GFakeMode = fsmSilent then
  begin
    platform_thread_sleep_ns(3000000000);   { 3s，远超客户端 300ms 超时 }
    LClient.Close;
    LListener.Close;
    Exit;
  end;

  { 协商帧：读 [VER, NMETHODS, METHODS...] }
  if not ServerReadFully(LClient, LFrame, 2) then
  begin
    LClient.Close;
    LListener.Close;
    Exit;
  end;
  if LFrame[1] > 0 then
    if not ServerReadFully(LClient, LFrame, Integer(LFrame[1])) then
    begin
      LClient.Close;
      LListener.Close;
      Exit;
    end;
  case GFakeMode of
    fsmNoAuth:
      begin
        LFrame[0] := $05;  LFrame[1] := $00;
        LClient.Write(LFrame[0], 2);
      end;
    fsmUserPassOk,
    fsmUserPassBad:
      begin
        LFrame[0] := $05;  LFrame[1] := $02;
        LClient.Write(LFrame[0], 2);
      end;
    fsmNoAccept:
      begin
        LFrame[0] := $05;  LFrame[1] := $FF;
        LClient.Write(LFrame[0], 2);
      end;
  else
    LFrame[0] := $05;  LFrame[1] := $00;
    LClient.Write(LFrame[0], 2);
  end;

  if (GFakeMode = fsmUserPassOk) or (GFakeMode = fsmUserPassBad) then
  begin
    { RFC 1929 认证请求：读 [VER, ULEN, USER, PLEN, PASS] }
    if not ServerReadFully(LClient, LFrame, 2) then
    begin
      LClient.Close;
      LListener.Close;
      Exit;
    end;
    if (LFrame[1] > 0) and (not ServerReadFully(LClient, LFrame, Integer(LFrame[1]))) then
    begin
      LClient.Close;
      LListener.Close;
      Exit;
    end;
    { 读 PLEN（1 字节）+ PASS（PLEN 字节） }
    if not ServerReadFully(LClient, LFrame, 1) then
    begin
      LClient.Close;
      LListener.Close;
      Exit;
    end;
    if LFrame[0] > 0 then
      if not ServerReadFully(LClient, LFrame, Integer(LFrame[0])) then
      begin
        LClient.Close;
        LListener.Close;
        Exit;
      end;
    if (GFakeMode = fsmUserPassBad) then
    begin
      LFrame[0] := $01;  LFrame[1] := $01;
      LClient.Write(LFrame[0], 2);
      LClient.Close;
      LListener.Close;
      Exit;
    end;
    LFrame[0] := $01;  LFrame[1] := $00;
    LClient.Write(LFrame[0], 2);
  end;

  { CONNECT 请求：读 [VER,CMD,RSV,ATYP] + 地址体 }
  if not ServerReadFully(LClient, LFrame, 4) then
  begin
    LClient.Close;
    LListener.Close;
    Exit;
  end;
  LAtyp := Integer(LFrame[3]);
  case LAtyp of
    $01: LNeed := 4 + 2;                       { ipv4 + port }
    $03:
      begin
        if not ServerReadFully(LClient, LFrame, 1) then
        begin
          LClient.Close;
          LListener.Close;
          Exit;
        end;
        LNeed := Integer(LFrame[0]) + 2;       { 域名 + port }
      end;
    $04: LNeed := 16 + 2;                      { ipv6 + port }
  else
    LClient.Close;
    LListener.Close;
    Exit;
  end;
  if not ServerReadFully(LClient, LFrame, LNeed) then
  begin
    LClient.Close;
    LListener.Close;
    Exit;
  end;

  if GFakeMode = fsmReplyHostUnreachable then
  begin
    LFrame[0] := $05;  LFrame[1] := $04;  LFrame[2] := $00;  LFrame[3] := $01;
    LFrame[4] := 127;  LFrame[5] := 0;    LFrame[6] := 0;    LFrame[7] := 1;
    LFrame[8] := 0;    LFrame[9] := 0;
    LClient.Write(LFrame[0], 10);
    LClient.Close;
    LListener.Close;
    Exit;
  end;

  { 成功：绑点 127.0.0.1:443 }
  LFrame[0] := $05;  LFrame[1] := $00;  LFrame[2] := $00;  LFrame[3] := $01;
  LFrame[4] := 127;  LFrame[5] := 0;    LFrame[6] := 0;    LFrame[7] := 1;
  LFrame[8] := $01;  LFrame[9] := $BB;
  if LClient.Write(LFrame[0], 10) = 0 then
  begin
    LClient.Close;
    LListener.Close;
    Exit;
  end;

  { 回显直到客户端关闭 }
  repeat
    LN := LClient.Read(LFrame[0], SizeOf(LFrame));
    if LN = 0 then
      Break;
    if LClient.Write(LFrame[0], LN) = 0 then
      Break;
  until False;
  LClient.Close;
  LListener.Close;
end;

{ 无需凭据匹配的 mode 也要有确定凭据（fsm 在伪造端按 mode 决定）；这里
  fsmUserPassOk 接受任意凭据 —— 客户端凭据由用例各自传入 }
function StartFakeServer(const AMode: TFakeSocks5Mode): UInt16;
begin
  GFakeMode := AMode;
  GFakeReady := 0;
  GFakePort := 0;
  platform_thread_create(GFakeThread, @FakeSocks5Server, nil);
  while InterlockedCompareExchange(GFakeReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  Result := GFakePort;
end;

procedure StopFakeServer;
var
  LRet: Pointer;
begin
  if GFakeThread <> nil then
  begin
    platform_thread_join(GFakeThread, LRet);
    GFakeThread := nil;
  end;
end;

{ 已关闭端口（用于拨号失败用例）：监听后立即关闭，取端口号 }
function ClosedPort: UInt16;
var
  LListener: ITcpListener;
begin
  LListener := TcpListen('127.0.0.1', 0);
  Result := LListener.LocalAddr.Port;
  LListener.Close;
end;

function EchoRoundtrip(const AStream: ITcpStream; const AMsg: string): Boolean;
var
  LBuf: array[0..255] of Byte;
  LPos: Integer;
  LN: SizeUInt;
begin
  Result := False;
  if AStream = nil then
    Exit;
  AStream.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
  if AStream.Write(AMsg[1], Length(AMsg)) = 0 then
    Exit;
  LPos := 0;
  while LPos < Length(AMsg) do
  begin
    LN := AStream.Read(LBuf[LPos], Length(AMsg) - LPos);
    if LN = 0 then
      Exit;
    Inc(LPos, Integer(LN));
  end;
  Result := CompareMem(@LBuf, @AMsg[1], Length(AMsg));
end;

{ ---- 编解码层用例 ---- }

procedure AssertBytes(const AName: string; const AActual: TBytes;
  const AExpected: array of Byte);
var
  LI: Integer;
begin
  Check(Length(AActual) = Length(AExpected), AName + ': length ' +
    IntToStr(Length(AActual)) + ' <> ' + IntToStr(Length(AExpected)));
  for LI := 0 to Length(AExpected) - 1 do
  begin
    if LI >= Length(AActual) then
      Break;
    Check(AActual[LI] = AExpected[LI], AName + ': byte[' + IntToStr(LI) +
      ']=' + IntToStr(AActual[LI]) + ' <> ' + IntToStr(AExpected[LI]));
  end;
end;

procedure TestCodecGreeting;
begin
  AssertBytes('greeting-creds', Socks5BuildGreeting('u', 'p'),
    [$05, $02, $00, $02]);
  AssertBytes('greeting-nocreds', Socks5BuildGreeting('', ''),
    [$05, $01, $00]);
end;

procedure TestCodecParseGreeting;
var
  LMethod: Byte;
  LData: TBytes;
begin
  LData := TBytes.Create($05, $00);
  Check(Socks5ParseGreeting(LData, LMethod) and (LMethod = $00),
    'parse noauth');
  LData := TBytes.Create($05, $02);
  Check(Socks5ParseGreeting(LData, LMethod) and (LMethod = $02),
    'parse userpass');
  LData := TBytes.Create($05, $FF);
  Check(not Socks5ParseGreeting(LData, LMethod), 'parse noaccept rejected');
  LData := TBytes.Create($04, $00);
  Check(not Socks5ParseGreeting(LData, LMethod), 'parse bad version');
  LData := TBytes.Create($05);
  Check(not Socks5ParseGreeting(LData, LMethod), 'parse short frame');
end;

procedure TestCodecUserPass;
var
  LData: TBytes;
  LLong: string;
begin
  AssertBytes('userpass-bytes', Socks5BuildUserPass('hello', 'world'),
    [$01, $05, Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'), $05,
     Ord('w'), Ord('o'), Ord('r'), Ord('l'), Ord('d')]);
  AssertBytes('userpass-empty', Socks5BuildUserPass('', ''),
    [$01, $00, $00]);
  LLong := StringOfChar('x', 256);
  Check(Socks5BuildUserPass(LLong, 'p') = nil, 'user>255 rejected');
  Check(Socks5BuildUserPass('u', LLong) = nil, 'pass>255 rejected');
  LData := TBytes.Create($01, $00);
  Check(Socks5ParseUserPass(LData), 'auth ok');
  LData := TBytes.Create($01, $01);
  Check(not Socks5ParseUserPass(LData), 'auth rejected');
  LData := TBytes.Create($01);
  Check(not Socks5ParseUserPass(LData), 'auth short');
end;

procedure TestCodecConnect;
var
  LData: TBytes;
begin
  LData := Socks5BuildConnect('1.2.3.4', 443, False);
  Check(LData <> nil, 'ipv4 non-nil');
  if LData <> nil then
    AssertBytes('connect-ipv4', LData,
      [$05, $01, $00, $01, 1, 2, 3, 4, $01, $BB]);
  LData := Socks5BuildConnect('1.2.3.4', 80, True);
  Check(LData <> nil, 'ipv4 with remoteDNS non-nil');
  Check((LData <> nil) and (LData[3] = $01), 'ipv4 stays ipv4 under socks5h');
  LData := Socks5BuildConnect('example.com', 443, True);
  Check(LData <> nil, 'domain non-nil');
  if LData <> nil then
    Check((Length(LData) = 5 + 11 + 2) and (LData[3] = $03) and
      (LData[4] = 11), 'domain frame shape');
  LData := Socks5BuildConnect('example.com', 443, False);
  Check(LData = nil, 'socks5 non-ipv4 returns nil (caller resolves)');
  LData := Socks5BuildConnect('2001:db8::1', 443, True);
  Check(LData = nil, 'ipv6 literal unsupported -> nil');
end;

procedure TestCodecParseConnect;
var
  LBindAddr: string;
  LBindPort: UInt16;
  LNeedMore: Boolean;
  LRep: Byte;
  LData: TBytes;
begin
  LData := TBytes.Create($05, $00, $00, $01, 127, 0, 0, 1, $01, $BB);
  Check(Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep) and
    (LBindAddr = '127.0.0.1') and (LBindPort = 443) and (not LNeedMore),
    'parse ipv4 bind');
  LData := TBytes.Create($05, $00, $00, $03, 3, Ord('a'), Ord('b'), Ord('c'),
    $08, $08);
  Check(Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep) and
    (LBindAddr = 'abc') and (LBindPort = $0808), 'parse domain bind');
  LData := TBytes.Create($05, $00, $00, $04,
    $20, $01, $0D, $B8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, $01, $BB);
  Check(Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep) and
    (LBindAddr = '2001:0db8:0000:0000:0000:0000:0000:0001') and
    (LBindPort = 443), 'parse ipv6 bind');
  LData := TBytes.Create($05, $01, $00, $01, 127, 0, 0, 1, 0, 0);
  Check((not Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep))
    and (not LNeedMore) and (LRep = $01), 'rep!=0 rejected with code');
  LData := TBytes.Create($05, $00, $00, $01, 127, 0, 0, 1, $01);
  Check((not Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep))
    and LNeedMore, 'ipv4 short -> need more');
  LData := TBytes.Create($05, $00, $00, $03, 5, Ord('a'));
  Check((not Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep))
    and LNeedMore, 'domain short -> need more');
  LData := TBytes.Create($04, $00, $00, $01, 127, 0, 0, 1, 0, 0);
  Check((not Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep))
    and (not LNeedMore), 'bad version rejected');
  LData := TBytes.Create($05, $00, $00, $09, 1, 2, 3, 4, 0, 0);
  Check((not Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep))
    and (not LNeedMore), 'unknown atyp rejected');
end;

procedure TestCodecReplyText;
begin
  Check(Socks5ReplyText($00) = 'succeeded', 'rep 0 text');
  Check(Pos('unreachable', Socks5ReplyText($04)) > 0, 'rep 4 text');
  Check(Socks5ReplyText($FE) <> '', 'unknown rep text non-empty');
end;

{ ---- 拨号层用例 ---- }

procedure TestDialNoAuth;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmNoAuth);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(LRes.Error = '', 'noauth dial ok: ' + LRes.Error);
    Check(LRes.Stream <> nil, 'noauth stream present');
    if LRes.Stream <> nil then
    begin
      Check(LRes.BindAddr = '127.0.0.1', 'bind addr reported');
      Check(LRes.BindPort = 443, 'bind port reported');
      Check(EchoRoundtrip(LRes.Stream, 'ping'),
        'noauth echo roundtrip');
      LRes.Stream.Close;
    end;
  finally
    StopFakeServer;
  end;
end;

procedure TestDialNoAuthDomain;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmNoAuth);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LOpts.RemoteDNS := True;               { socks5h：域名交给代理解析 }
    LRes := Socks5Dial('127.0.0.1', LPort, 'example.com', 443, LOpts);
    Check(LRes.Error = '', 'socks5h dial ok: ' + LRes.Error);
    if LRes.Stream <> nil then
    begin
      Check(EchoRoundtrip(LRes.Stream, 'abc'), 'socks5h echo roundtrip');
      LRes.Stream.Close;
    end;
  finally
    StopFakeServer;
  end;
end;

procedure TestDialUserPassOk;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmUserPassOk);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LOpts.Username := cFakeUser;
    LOpts.Password := cFakePass;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(LRes.Error = '', 'userpass dial ok: ' + LRes.Error);
    if LRes.Stream <> nil then
    begin
      Check(EchoRoundtrip(LRes.Stream, 'hello'), 'userpass echo');
      LRes.Stream.Close;
    end;
  finally
    StopFakeServer;
  end;
end;

procedure TestDialUserPassRejected;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmUserPassBad);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LOpts.Username := 'x';
    LOpts.Password := 'y';
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(Pos('authentication rejected', LRes.Error) > 0,
      'wrong creds rejected: ' + LRes.Error);
    Check(LRes.Stream = nil, 'no stream on auth failure');
  finally
    StopFakeServer;
  end;
end;

procedure TestDialCredentialsRequired;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmUserPassOk);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(Pos('no credentials configured', LRes.Error) > 0,
      'missing creds reported: ' + LRes.Error);
  finally
    StopFakeServer;
  end;
end;

procedure TestDialNoAccept;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmNoAccept);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(Pos('no acceptable authentication method', LRes.Error) > 0,
      'noaccept reported: ' + LRes.Error);
  finally
    StopFakeServer;
  end;
end;

procedure TestDialHostUnreachable;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmReplyHostUnreachable);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LRes := Socks5Dial('127.0.0.1', LPort, '1.2.3.4', 80, LOpts);
    Check(Pos('host unreachable', LRes.Error) > 0,
      'rep text reported: ' + LRes.Error);
  finally
    StopFakeServer;
  end;
end;

procedure TestDialTcpFail;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := ClosedPort;
  LOpts := Default(TSocks5DialOptions);
  LOpts.TimeoutMs := 2000;
  LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
  Check(Pos('TCP connect to proxy', LRes.Error) > 0,
    'tcp fail reported: ' + LRes.Error);
  Check(LRes.Stream = nil, 'no stream on tcp fail');
end;

procedure TestDialHandshakeTimeout;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmSilent);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 300;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    Check(Pos('timed out', LRes.Error) > 0,
      'timeout reported: ' + LRes.Error);
  finally
    StopFakeServer;
  end;
end;

procedure TestDialConnClosed;
var
  LPort: UInt16;
  LOpts: TSocks5DialOptions;
  LRes: TSocks5DialResult;
begin
  LPort := StartFakeServer(fsmClose);
  try
    LOpts := Default(TSocks5DialOptions);
    LOpts.TimeoutMs := 2000;
    LRes := Socks5Dial('127.0.0.1', LPort, '127.0.0.1', 80, LOpts);
    { 服务器 accept 后立即关闭：客户端可能收到 FIN（echo 清理关闭）
      或 RST（未消费入站数据），两类都算代理侧连接中断 }
    Check((Pos('connection closed by proxy', LRes.Error) > 0) or
      (Pos('connection error during greeting', LRes.Error) > 0),
      'closed reported: ' + LRes.Error);
  finally
    StopFakeServer;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.net.socks5');
  T.Test('codec_greeting_bytes', @TestCodecGreeting);
  T.Test('codec_parse_greeting', @TestCodecParseGreeting);
  T.Test('codec_userpass_bytes', @TestCodecUserPass);
  T.Test('codec_connect_bytes', @TestCodecConnect);
  T.Test('codec_parse_connect', @TestCodecParseConnect);
  T.Test('codec_reply_text', @TestCodecReplyText);
  T.Test('dial_noauth_echo', @TestDialNoAuth);
  T.Test('dial_socks5h_domain', @TestDialNoAuthDomain);
  T.Test('dial_userpass_ok', @TestDialUserPassOk);
  T.Test('dial_userpass_rejected', @TestDialUserPassRejected);
  T.Test('dial_credentials_required', @TestDialCredentialsRequired);
  T.Test('dial_no_accept', @TestDialNoAccept);
  T.Test('dial_host_unreachable', @TestDialHostUnreachable);
  T.Test('dial_tcp_fail', @TestDialTcpFail);
  T.Test('dial_handshake_timeout', @TestDialHandshakeTimeout);
  T.Test('dial_conn_closed', @TestDialConnClosed);
  T.Run;
end.