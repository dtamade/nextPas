unit nextpas.core.net.socks5;
{**
 * @desc SOCKS5 客户端（RFC 1928 / RFC 1929）：两层结构。
 *       1) 纯字节编解码层（零 IO，可单测）：Socks5Build*/Socks5Parse*。
 *       2) 同步阻塞拨号层：Socks5Dial，经代理建立到目标的 TCP 隧道。
 *       socks5h（RemoteDNS=true）把域名交给代理解析；socks5（RemoteDNS=false）
 *       本地解析为 IPv4 后再编码。错误一律以结果 Error 返回，不 raise，
 *       便于调用方归类（复用 NetTcpConnect 的 deadline 超时）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.text.conv;

{ SOCKS5 协议常量（RFC 1928 / RFC 1929），唯一事实来源 }
const
  cSocks5Version                = $05;
  cSocks5AuthNoAuth             = $00;
  cSocks5AuthUserPass           = $02;
  cSocks5AuthNoAccept           = $FF;
  cSocks5CmdConnect             = $01;
  cSocks5AtypIpv4               = $01;
  cSocks5AtypDomain             = $03;
  cSocks5AtypIpv6               = $04;
  cSocks5ReplySucceeded         = $00;
  cSocks5ReplyGeneralFailure    = $01;
  cSocks5ReplyNotAllowed        = $02;
  cSocks5ReplyNetworkUnreachable= $03;
  cSocks5ReplyHostUnreachable   = $04;
  cSocks5ReplyConnectionRefused = $05;
  cSocks5ReplyTtlExpired        = $06;
  cSocks5ReplyCmdNotSupported   = $07;
  cSocks5ReplyAddrNotSupported  = $08;
  cSocks5UserPassVer            = $01;

  { 默认拨号超时（毫秒）：覆盖 TCP 连接 + 握手 + 认证 + CONNECT }
  cSocks5DefaultTimeoutMs: Int64 = 30000;

type
  { 拨号选项。Username/Password 均空 = 无认证；服务器若仍要求认证，
    视为拒绝（空凭据在 RFC 1929 下不合法，不自动发送空认证帧）。 }
  TSocks5DialOptions = record
    Username: string;
    Password: string;
    TimeoutMs: Int64;      { <= 0 使用 cSocks5DefaultTimeoutMs }
    RemoteDNS: Boolean;    { true = socks5h（域名交代理解析）；false = 本地解析 }
  end;

  TSocks5DialResult = record
    Stream: ITcpStream;    { 成功时已就绪的隧道（隧道外再包 TLS/HTTP 层） }
    Error: string;         { 空 = 成功 }
    BindAddr: string;      { 代理侧绑点地址（文本形式，仅参考） }
    BindPort: UInt16;      { 代理侧绑点端口 }
  end;

{ ---- 纯字节编解码层（零 IO）---- }

{ 协商帧：有凭据 [05,02,00,02]，无凭据 [05,01,00] }
function Socks5BuildGreeting(const AUsername: string;
  const APassword: string): TBytes;
{ 解析上游选法响应 [VER, METHOD]；成功时 AMethod 为上游选定方法 }
function Socks5ParseGreeting(const AData: TBytes;
  out AMethod: Byte): Boolean;
{ RFC 1929 认证帧 [01,ULEN,USER,PLEN,PASS]；用户名/密码任一超 255 字节
  无法编码，返回 nil（调用方应视为配置错误，避免静默截断） }
function Socks5BuildUserPass(const AUsername: string;
  const APassword: string): TBytes;
{ 认证响应 [VER=01, STATUS=00] 成功 }
function Socks5ParseUserPass(const AData: TBytes): Boolean;
{ CONNECT 请求：点分 IPv4 一律编码为 ATYP=ipv4；其余仅在 ARemoteDNS=true
  （socks5h）时编码为 ATYP=domain；IPv6 字面量不支持编码返回 nil。 }
function Socks5BuildConnect(const AHost: string; APort: UInt16;
  const ARemoteDNS: Boolean): TBytes;
{ CONNECT 响应解析。返回 False 时：ANeedMore=True 表示帧未完整应继续读；
  否则为协议错误（版本不符 / 未知 ATYP / REP!=0，AReplyCode 携带 REP 码）。}
function Socks5ParseConnect(const AData: TBytes; out ABindAddr: string;
  out ABindPort: UInt16; out ANeedMore: Boolean;
  out AReplyCode: Byte): Boolean;
{ REP 码文本（RFC 1928 错误语义），用于错误消息拼装 }
function Socks5ReplyText(ACode: Byte): string;

{ ---- 同步阻塞拨号层 ---- }

{ 经 SOCKS5 代理建立到 ATargetHost:ATargetPort 的 TCP 隧道。
  AOptions.RemoteDNS=false 且目标非点分 IPv4 时本地解析（socks5）；
  解析失败/握手失败/认证失败/代理拒绝均在 Error 中给出带阶段的说明。 }
function Socks5Dial(const AProxyHost: string; const AProxyPort: UInt16;
  const ATargetHost: string; const ATargetPort: UInt16;
  const AOptions: TSocks5DialOptions): TSocks5DialResult;

implementation

uses
  nextpas.core.errors,
  nextpas.core.net.base,
  nextpas.core.net.resolve,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.utf8;

{ 严格点分十进制 IPv4 校验（镜像 proxy888 IsIpv4Host：段 1-3 位、
  无前导零；点号计数，末尾段单独校验） }
function IsIpv4Host(const AHost: string): Boolean;
var
  LSeg: string;
  LVal: Int64;
  LPos, LStart, LDots: Integer;
  LOk: Boolean;
begin
  Result := False;
  if AHost = '' then
    Exit;
  LStart := 1;
  LDots := 0;
  LPos := 1;
  while LPos <= Length(AHost) do
  begin
    if AHost[LPos] = '.' then
    begin
      Inc(LDots);
      LSeg := Copy(AHost, LStart, LPos - LStart);
      if (Length(LSeg) = 0) or (Length(LSeg) > 3) then
        Exit(False);
      { 拒绝前导零（01/010 有八进制歧义，按严格 IPv4 处理） }
      if (Length(LSeg) > 1) and (LSeg[1] = '0') then
        Exit(False);
      LOk := TryStrToInt(LSeg, LVal);
      if (not LOk) or (LVal < 0) or (LVal > 255) then
        Exit(False);
      LStart := LPos + 1;
    end;
    Inc(LPos);
  end;
  { 末尾段 }
  LSeg := Copy(AHost, LStart, LPos - LStart);
  if (Length(LSeg) = 0) or (Length(LSeg) > 3) then
    Exit(False);
  if (Length(LSeg) > 1) and (LSeg[1] = '0') then
    Exit(False);
  LOk := TryStrToInt(LSeg, LVal);
  if (not LOk) or (LVal < 0) or (LVal > 255) then
    Exit(False);
  Result := LDots = 3;
end;

function Socks5BuildGreeting(const AUsername: string;
  const APassword: string): TBytes;
begin
  Result := nil;
  if AUsername <> '' then
  begin
    SetLength(Result, 4);
    Result[0] := cSocks5Version;
    Result[1] := 2;
    Result[2] := cSocks5AuthNoAuth;
    Result[3] := cSocks5AuthUserPass;
    Exit;
  end;
  SetLength(Result, 3);
  Result[0] := cSocks5Version;
  Result[1] := 1;
  Result[2] := cSocks5AuthNoAuth;
end;

function Socks5ParseGreeting(const AData: TBytes;
  out AMethod: Byte): Boolean;
begin
  Result := False;
  AMethod := 0;
  if Length(AData) < 2 then
    Exit;
  if AData[0] <> cSocks5Version then
    Exit;
  AMethod := AData[1];
  Result := AMethod <> cSocks5AuthNoAccept;
end;

function Socks5BuildUserPass(const AUsername: string;
  const APassword: string): TBytes;
var
  LUser, LPass: TBytes;
  LO: Integer;
begin
  Result := nil;
  LUser := UTF8ToBytes(AUsername);
  LPass := UTF8ToBytes(APassword);
  { RFC 1929 用户名/密码各限 255 字节；超长无法编码返回 nil }
  if (Length(LUser) > 255) or (Length(LPass) > 255) then
    Exit;
  SetLength(Result, 1 + 1 + Length(LUser) + 1 + Length(LPass));
  Result[0] := cSocks5UserPassVer;
  Result[1] := Byte(Length(LUser));
  LO := 2;
  if Length(LUser) > 0 then
    Move(LUser[0], Result[LO], Length(LUser));
  LO := 2 + Length(LUser);
  Result[LO] := Byte(Length(LPass));
  if Length(LPass) > 0 then
    Move(LPass[0], Result[LO + 1], Length(LPass));
end;

function Socks5ParseUserPass(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) = 2) and (AData[0] = cSocks5UserPassVer) and
    (AData[1] = 0);
end;

function Socks5BuildConnect(const AHost: string; APort: UInt16;
  const ARemoteDNS: Boolean): TBytes;
var
  LSeg: string;
  LVal: Int64;
  LAddr: TBytes;
  LO, LPos, LStart, LI: Integer;
begin
  Result := nil;
  if IsIpv4Host(AHost) then
  begin
    SetLength(LAddr, 4);
    LStart := 1;
    LPos := 1;
    LI := 0;
    while LPos <= Length(AHost) + 1 do
    begin
      if (LPos > Length(AHost)) or (AHost[LPos] = '.') then
      begin
        LSeg := Copy(AHost, LStart, LPos - LStart);
        if not TryStrToInt(LSeg, LVal) then
          LVal := 0;
        LAddr[LI] := Byte(LVal and $FF);
        LStart := LPos + 1;
        Inc(LI);
      end;
      Inc(LPos);
    end;
    SetLength(Result, 4 + 4 + 2);
    Result[0] := cSocks5Version;
    Result[1] := cSocks5CmdConnect;
    Result[2] := 0;
    Result[3] := cSocks5AtypIpv4;
    for LI := 0 to 3 do
      Result[4 + LI] := LAddr[LI];
    Result[8] := Byte(APort shr 8);
    Result[9] := Byte(APort and $FF);
  end
  else if ARemoteDNS then
  begin
    { socks5h：域名交给代理解析（IPv6 字面量不支持，返回 nil 由调用方报错） }
    if Pos(':', AHost) > 0 then
      Exit;
    LAddr := UTF8ToBytes(AHost);
    SetLength(Result, 5 + Length(LAddr) + 2);
    Result[0] := cSocks5Version;
    Result[1] := cSocks5CmdConnect;
    Result[2] := 0;
    Result[3] := cSocks5AtypDomain;
    Result[4] := Byte(Length(LAddr));
    for LO := 0 to Length(LAddr) - 1 do
      Result[5 + LO] := LAddr[LO];
    Result[5 + Length(LAddr)] := Byte(APort shr 8);
    Result[6 + Length(LAddr)] := Byte(APort and $FF);
  end;
  { 否则（socks5 + 非点分主机）返回 nil：由调用方先本地解析成 IPv4 }
end;

function Socks5ParseConnect(const AData: TBytes; out ABindAddr: string;
  out ABindPort: UInt16; out ANeedMore: Boolean;
  out AReplyCode: Byte): Boolean;
const
  cHex: array[0..15] of Char = '0123456789abcdef';
var
  LNeed, LDomLen, LI, LO: Integer;
  LAt: Byte;
begin
  Result := False;
  ANeedMore := False;
  ABindAddr := '';
  ABindPort := 0;
  AReplyCode := cSocks5ReplyGeneralFailure;
  if Length(AData) < 2 then
  begin
    ANeedMore := True;
    Exit;
  end;
  if AData[0] <> cSocks5Version then
    Exit;                    { 版本不符：协议错误 }
  if Length(AData) < 4 then
  begin
    ANeedMore := True;
    Exit;
  end;
  AReplyCode := AData[1];
  if AReplyCode <> cSocks5ReplySucceeded then
    Exit;                    { 代理拒绝：携带 REP 码 }
  LAt := AData[3];
  case LAt of
    cSocks5AtypIpv4: LNeed := 10;
    cSocks5AtypIpv6: LNeed := 22;
    cSocks5AtypDomain:
      begin
        if Length(AData) < 5 then
        begin
          ANeedMore := True;
          Exit;
        end;
        LNeed := 7 + Integer(AData[4]);
      end;
  else
    AReplyCode := cSocks5ReplyAddrNotSupported;
    Exit;                    { 未知 ATYP：协议错误 }
  end;
  if Length(AData) < LNeed then
  begin
    ANeedMore := True;
    Exit;
  end;
  case LAt of
    cSocks5AtypIpv4:
      begin
        ABindAddr := IntToStr(AData[4]) + '.' + IntToStr(AData[5]) + '.' +
          IntToStr(AData[6]) + '.' + IntToStr(AData[7]);
        ABindPort := (UInt16(AData[8]) shl 8) or AData[9];
      end;
    cSocks5AtypDomain:
      begin
        LDomLen := Integer(AData[4]);
        SetLength(ABindAddr, LDomLen);
        for LI := 0 to LDomLen - 1 do
          ABindAddr[LI + 1] := Char(AData[5 + LI]);
        ABindPort := (UInt16(AData[5 + LDomLen]) shl 8) or AData[5 + LDomLen + 1];
      end;
    cSocks5AtypIpv6:
      begin
        { 文本化 IPv6（8 组 4 位十六进制，无压缩）：仅参考展示 }
        for LI := 0 to 7 do
        begin
          for LO := 0 to 1 do
          begin
            LAt := AData[4 + LI * 2 + LO];
            ABindAddr := ABindAddr + cHex[(LAt shr 4) and $F] + cHex[LAt and $F];
          end;
          if LI < 7 then
            ABindAddr := ABindAddr + ':';
        end;
        ABindPort := (UInt16(AData[20]) shl 8) or AData[21];
      end;
  end;
  Result := True;
end;

function Socks5ReplyText(ACode: Byte): string;
begin
  case ACode of
    cSocks5ReplySucceeded:          Result := 'succeeded';
    cSocks5ReplyGeneralFailure:     Result := 'general SOCKS server failure';
    cSocks5ReplyNotAllowed:         Result := 'connection not allowed by ruleset';
    cSocks5ReplyNetworkUnreachable: Result := 'network unreachable';
    cSocks5ReplyHostUnreachable:    Result := 'host unreachable';
    cSocks5ReplyConnectionRefused:  Result := 'connection refused';
    cSocks5ReplyTtlExpired:         Result := 'TTL expired';
    cSocks5ReplyCmdNotSupported:    Result := 'command not supported';
    cSocks5ReplyAddrNotSupported:   Result := 'address type not supported';
  else
    Result := 'unknown reply code ' + IntToStr(ACode);
  end;
end;

{ 写满 ACount 字节；失败时返回 False }
function Socks5WriteAll(const AStream: ITcpStream; const AData: TBytes): Boolean;
var
  LPos, LW: SizeUInt;
begin
  LPos := 0;
  while LPos < Length(AData) do
  begin
    LW := AStream.Write(AData[LPos], Length(AData) - LPos);
    if LW = 0 then
      Exit(False);
    Inc(LPos, LW);
  end;
  Result := True;
end;

{ 追加读取。返回 False 表示连接关闭或读超时（由调用方结合 deadline 定夺）。 }
function Socks5ReadMore(const AStream: ITcpStream; var AAcc: TBytes): Boolean;
var
  LBuf: array[0..1023] of Byte;
  LN: SizeUInt;
  LBase: Integer;
begin
  LN := AStream.Read(LBuf, SizeOf(LBuf));
  if LN = 0 then
    Exit(False);
  LBase := Length(AAcc);
  SetLength(AAcc, LBase + Integer(LN));
  Move(LBuf, AAcc[LBase], LN);
  Result := True;
end;

function Socks5Dial(const AProxyHost: string; const AProxyPort: UInt16;
  const ATargetHost: string; const ATargetPort: UInt16;
  const AOptions: TSocks5DialOptions): TSocks5DialResult;
var
  LOpts: TSocks5DialOptions;
  LStream: ITcpStream;
  LDeadline: TDeadline;
  LGreet, LData, LConnect: TBytes;
  LMethod, LRep: Byte;
  LNeedMore: Boolean;
  LBindAddr: string;
  LBindPort: UInt16;
  LAddr: TNetAddress;
  LTarget: string;
  LStage: string;

  procedure Fail(const AError: string);
  begin
    Result.Error := AError;
    if LStream <> nil then
      LStream.Close;
    LStream := nil;
  end;

begin
  Result := Default(TSocks5DialResult);
  LStream := nil;
  LOpts := AOptions;
  if LOpts.TimeoutMs <= 0 then
    LOpts.TimeoutMs := cSocks5DefaultTimeoutMs;
  LTarget := ATargetHost;

  { socks5（本地解析）：非点分主机先解析为 IPv4 }
  if (not LOpts.RemoteDNS) and (not IsIpv4Host(LTarget)) then
  begin
    LAddr := NetResolve(LTarget);
    if LAddr.IP = '' then
    begin
      Fail('socks5: DNS resolution failed for target ' + LTarget);
      Exit;
    end;
    if LAddr.IsIPv6 then
    begin
      Fail('socks5: IPv6 target requires RemoteDNS (socks5h), got ' + LTarget);
      Exit;
    end;
    LTarget := LAddr.IP;
  end;

  { 1. TCP 连接代理（core NetTcpConnect 失败时 raise ENetworkError） }
  try
    LStream := NetTcpConnect(AProxyHost, AProxyPort, LOpts.TimeoutMs);
  except
    on E: ENetworkError do
    begin
      Result.Error := 'socks5: TCP connect to proxy ' + AProxyHost + ':' +
        IntToStr(AProxyPort) + ' failed: ' + E.Message;
      Exit;
    end;
  end;
  if LStream = nil then
  begin
    Result.Error := 'socks5: TCP connect to proxy ' + AProxyHost + ':' +
      IntToStr(AProxyPort) + ' failed';
    Exit;
  end;
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(LOpts.TimeoutMs));
  LStream.SetReadDeadline(LDeadline);
  LStream.SetWriteDeadline(LDeadline);

  { 2/3. 协商 + 认证 + CONNECT；core 的 socket 失败（超时/重置/关闭）以
     ETimeoutError / ENetworkError 抛出，统一映射为 Error 字符串 }
  LStage := 'greeting';
  try
    LGreet := Socks5BuildGreeting(LOpts.Username, LOpts.Password);
    if not Socks5WriteAll(LStream, LGreet) then
    begin
      Fail('socks5: write greeting failed');
      Exit;
    end;
    LData := nil;
    repeat
      if not Socks5ReadMore(LStream, LData) then
      begin
        Fail('socks5: connection closed by proxy during ' + LStage);
        Exit;
      end;
    until Length(LData) >= 2;
    if LData[0] <> cSocks5Version then
    begin
      Fail('socks5: malformed greeting response from proxy');
      Exit;
    end;
    if LData[1] = cSocks5AuthNoAccept then
    begin
      Fail('socks5: no acceptable authentication method');
      Exit;
    end;
    LMethod := LData[1];
    if LMethod = cSocks5AuthUserPass then
    begin
      if LOpts.Username = '' then
      begin
        Fail('socks5: proxy requires authentication but no credentials configured');
        Exit;
      end;
      LStage := 'authentication';
      LData := Socks5BuildUserPass(LOpts.Username, LOpts.Password);
      if LData = nil then
      begin
        Fail('socks5: credentials exceed 255-byte RFC 1929 limit');
        Exit;
      end;
      if not Socks5WriteAll(LStream, LData) then
      begin
        Fail('socks5: write authentication failed');
        Exit;
      end;
      LData := nil;
      repeat
        if not Socks5ReadMore(LStream, LData) then
        begin
          Fail('socks5: connection closed by proxy during ' + LStage);
          Exit;
        end;
      until Length(LData) >= 2;
      if not Socks5ParseUserPass(LData) then
      begin
        if LData[1] <> 0 then
          Fail('socks5: authentication rejected by proxy')
        else
          Fail('socks5: malformed authentication response from proxy');
        Exit;
      end;
    end
    else if LMethod <> cSocks5AuthNoAuth then
    begin
      Fail('socks5: no acceptable authentication method (method=' +
        IntToStr(LMethod) + ')');
      Exit;
    end;

    LStage := 'connect';
    LConnect := Socks5BuildConnect(LTarget, ATargetPort, LOpts.RemoteDNS);
    if LConnect = nil then
    begin
      Fail('socks5: cannot encode target ' + LTarget + ':' +
        IntToStr(ATargetPort));
      Exit;
    end;
    if not Socks5WriteAll(LStream, LConnect) then
    begin
      Fail('socks5: write CONNECT failed');
      Exit;
    end;
    LData := nil;
    repeat
      LNeedMore := False;
      if Socks5ParseConnect(LData, LBindAddr, LBindPort, LNeedMore, LRep) then
        Break;                            { 已就绪 }
      if not LNeedMore then
      begin
        if LRep <> cSocks5ReplySucceeded then
          Fail('socks5: proxy rejected connect to ' + LTarget + ':' +
            IntToStr(ATargetPort) + ' (' + Socks5ReplyText(LRep) + ')')
        else
          Fail('socks5: malformed CONNECT response from proxy');
        Exit;
      end;
      if not Socks5ReadMore(LStream, LData) then
      begin
        Fail('socks5: connection closed by proxy during ' + LStage);
        Exit;
      end;
    until False;
  except
    on E: ETimeoutError do
      Fail('socks5: handshake timed out after ' + IntToStr(LOpts.TimeoutMs) +
        ' ms during ' + LStage);
    on E: ENetworkError do
      Fail('socks5: connection error during ' + LStage + ': ' + E.Message);
  end;

  Result.Stream := LStream;
  Result.BindAddr := LBindAddr;
  Result.BindPort := LBindPort;
end;

end.