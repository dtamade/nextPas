program test_dns_resolve;
{**
 * 查询对跑: 内嵌 mock DNS 服务器(线程 + UDP), 验证查询/应答归属、
 * 超时、缓存命中、NXDOMAIN、MX 排序(契约 INV-3/4/5/7/8/10)。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.udp,
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.dns.base,
  nextpas.core.dns.intf,
  nextpas.core.dns;

type
  TB = array of Byte;

{ ── wire 助手(与 test_dns_wire 同构) ────────────────────────────── }

function S2B(const AStr: string): TB;
var
  I: Integer;
begin
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    Result[I - 1] := Byte(AStr[I]);
end;

function Concat(const A, B: TB): TB;
var
  L0: Integer;
begin
  L0 := Length(A);
  SetLength(Result, L0 + Length(B));
  if L0 > 0 then
    Move(A[0], Result[0], L0);
  if Length(B) > 0 then
    Move(B[0], Result[L0], Length(B));
end;

function Hex8(const A: Byte): TB;
begin
  SetLength(Result, 1);
  Result[0] := A;
end;

function B16(const A: UInt16): TB;
begin
  SetLength(Result, 2);
  Result[0] := Byte(A shr 8);
  Result[1] := Byte(A and $FF);
end;

function B32(const A: UInt32): TB;
begin
  SetLength(Result, 4);
  Result[0] := Byte(A shr 24);
  Result[1] := Byte((A shr 16) and $FF);
  Result[2] := Byte((A shr 8) and $FF);
  Result[3] := Byte(A and $FF);
end;

function WireName(const AName: string): TB;
var
  LP, LStart: Integer;
begin
  Result := nil;
  LP := 1;
  while LP <= Length(AName) do
  begin
    LStart := LP;
    while (LP <= Length(AName)) and (AName[LP] <> '.') do
      Inc(LP);
    Result := Concat(Result, Hex8(LP - LStart));
    Result := Concat(Result, S2B(Copy(AName, LStart, LP - LStart)));
    Inc(LP);
  end;
  Result := Concat(Result, Hex8(0));
end;

function RRWire(const AName: TB; const AType: UInt16; const ATTL: UInt32;
  const ARData: TB): TB;
begin
  Result := AName;
  Result := Concat(Result, B16(AType));
  Result := Concat(Result, B16(1));
  Result := Concat(Result, B32(ATTL));
  Result := Concat(Result, B16(Length(ARData)));
  Result := Concat(Result, ARData);
end;

{ 解析查询的 name 与 qtype(从偏移 12 起) }
function ParseQuery(const AQ: TB; out AName: string; out AType: UInt16): Boolean;
var
  LPos, LLabelLen, LI: Integer;
begin
  Result := False;
  if Length(AQ) < 12 then
    Exit;
  LPos := 12;
  AName := '';
  while True do
  begin
    if LPos >= Length(AQ) then
      Exit;
    LLabelLen := AQ[LPos];
    if LLabelLen = 0 then
      Break;
    if (LLabelLen > 63) or (LPos + 1 + LLabelLen > Length(AQ)) then
      Exit;
    if Length(AName) > 0 then
      AName := AName + '.';
    for LI := 0 to LLabelLen - 1 do
      AName := AName + Chr(AQ[LPos + 1 + LI]);
    Inc(LPos, 1 + LLabelLen);
  end;
  Inc(LPos);
  if LPos + 4 > Length(AQ) then
    Exit;
  AType := (UInt16(AQ[LPos]) shl 8) or AQ[LPos + 1];
  Result := True;
end;

{ ── mock DNS 服务器 ─────────────────────────────────────────────── }

type
  PMockDnsServer = ^TMockDnsServer;
  TMockDnsServer = record
    Sock: IUdpSocket;
    Port: UInt16;
    QueryCount: Integer;
    Respond: Boolean;                 { False: 收到即丢弃(测超时) }
    WrongIdFirst: Boolean;            { 先回一个错误 ID 应答 }
    Thread: TPlatformThreadRecord;
    Terminated: Int32;
  end;

procedure MockDnsExecute(ACtx: PMockDnsServer); forward;

function MockDnsServerWorker(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  MockDnsExecute(PMockDnsServer(AArg));
end;

procedure MockDnsServerInit(var ACtx: TMockDnsServer;
  const ARespond: Boolean; const AWrongIdFirst: Boolean);
begin
  ACtx.Sock := nil;
  ACtx.Port := 0;
  ACtx.QueryCount := 0;
  ACtx.Respond := ARespond;
  ACtx.WrongIdFirst := AWrongIdFirst;
  ACtx.Terminated := 0;
  Check(platform_thread_spawn(ACtx.Thread, @MockDnsServerWorker, @ACtx) = 0,
    'spawn mock DNS server');
end;

procedure MockDnsServerStop(var ACtx: TMockDnsServer);
begin
  atomic_store(ACtx.Terminated, 1, mo_seq_cst);
  Check(platform_thread_wait(ACtx.Thread) = 0, 'join mock DNS server');
  ACtx.Sock := nil;
end;

{ 固件 answers; 未知 (name,qtype) → False(NXDOMAIN) }
function MockAnswers(const AName: string; const AType: UInt16;
  out AAnswers: TB; out ACount: Integer): Boolean;
begin
  AAnswers := nil;
  ACount := 0;
  Result := False;
  if (AName = 'example.com') and (AType = 16) then
  begin
    AAnswers := RRWire(WireName('example.com'), 16, 300,
      Concat(Hex8(28), S2B('v=spf1 -all ip4:192.0.2.0/24')));
    ACount := 1;
    Result := True;
  end
  else if (AName = 'example.com') and (AType = 15) then
  begin
    AAnswers := RRWire(WireName('example.com'), 15, 300,
      Concat(B16(10), WireName('mx1.example.com')));
    AAnswers := Concat(AAnswers, RRWire(WireName('example.com'), 15, 300,
      Concat(B16(5), WireName('mx2.example.com'))));
    ACount := 2;
    Result := True;
  end;
end;

procedure MockDnsExecute(ACtx: PMockDnsServer);
var
  LBuf, LQ, LReply, LAnswers: TB;
  LFrom: TNetAddress;
  LID: UInt16;
  LName: string;
  LType: UInt16;
  LCount: Integer;
  LRuntime: IUdpSocketRuntime;
  LSockT: TPlatformSocket;
  LRevents, LRes: Int32;
  LQuestion: TB;
  LN: SizeUInt;
  LSock: IUdpSocket;
begin
  LSock := NetUdpBind('127.0.0.1', 0);
  ACtx^.Sock := LSock;
  ACtx^.Port := LSock.LocalAddr.Port;
  LRuntime := LSock as IUdpSocketRuntime;
{$IFDEF NEXTPAS_WINDOWS}
  LSockT.Value := LRuntime.NativeSocketHandle;
{$ELSE}
  LSockT.Value := Int32(LRuntime.NativeSocketHandle);
{$ENDIF}
  SetLength(LBuf, 2048);
  while atomic_load(ACtx^.Terminated, mo_seq_cst) = 0 do
  begin
    LRevents := 0;
    LRes := platform_socket_poll(LSockT, PLATFORM_POLL_IN, 100, LRevents);
    if LRes <= 0 then
      Continue;
    LFrom := TNetAddress.Create('127.0.0.1', 0);
    LN := LSock.RecvFrom(LBuf[0], Length(LBuf), LFrom);
    if LN < 12 then
      Continue;
    Inc(ACtx^.QueryCount);
    if not ACtx^.Respond then
      Continue;
    SetLength(LQ, LN);
    Move(LBuf[0], LQ[0], LN);
    if not ParseQuery(LQ, LName, LType) then
      Continue;
    LQuestion := Copy(LQ, 12, SizeInt(Length(LQ) - 12));
    LID := (UInt16(LQ[0]) shl 8) or LQ[1];
    if ACtx^.WrongIdFirst then
    begin
      { 先回一个 ID 错误的 header-only 包(INV-3: 解析器须丢弃) }
      LReply := nil;
      LReply := Concat(LReply, B16(LID + 1));
      LReply := Concat(LReply, B16($8180));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LSock.SendTo(LReply[0], Length(LReply), LFrom);
    end;
    if MockAnswers(LName, LType, LAnswers, LCount) then
    begin
      LReply := nil;
      LReply := Concat(LReply, B16(LID));
      LReply := Concat(LReply, B16($8180));
      LReply := Concat(LReply, B16(1));
      LReply := Concat(LReply, B16(LCount));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, LQuestion);
      LReply := Concat(LReply, LAnswers);
      LSock.SendTo(LReply[0], Length(LReply), LFrom);
    end
    else
    begin
      { NXDOMAIN }
      LReply := nil;
      LReply := Concat(LReply, B16(LID));
      LReply := Concat(LReply, B16($8183));
      LReply := Concat(LReply, B16(1));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, B16(0));
      LReply := Concat(LReply, LQuestion);
      LSock.SendTo(LReply[0], Length(LReply), LFrom);
    end;
  end;
  LSock.Close;
  ACtx^.Sock := nil;
end;

{ ── 主 mock 生命周期助手 ────────────────────────────────────────── }

var
  GMainMock: TMockDnsServer;

function NewMainResolver: IDnsResolver;
begin
  Result := DnsResolver('127.0.0.1', 256, GMainMock.Port);
end;

{ 新建一次性 mock(用例内自建互不干扰), 调用方负责 StopMock }
procedure SpawnMock(var AMock: TMockDnsServer;
  const ARespond: Boolean; const AWrongIdFirst: Boolean);
begin
  MockDnsServerInit(AMock, ARespond, AWrongIdFirst);
  while AMock.Port = 0 do
    SleepMs(2);
end;

procedure StopMock(var AMock: TMockDnsServer);
begin
  MockDnsServerStop(AMock);
end;

{ ── 用例 ────────────────────────────────────────────────────────── }

procedure TestQueryTxt;
var
  R: IDnsResolver;
  LTexts: TDnsStringArray;
  LErr: string;
begin
  R := NewMainResolver;
  Check(R.QueryTXT('example.com', 1000, LTexts, LErr), 'txt query ok');
  Check(Length(LTexts) = 1, 'one txt record');
  Check(LTexts[0] = 'v=spf1 -all ip4:192.0.2.0/24', 'txt payload');
end;

procedure TestQueryMxSorted;
var
  R: IDnsResolver;
  LHosts: TDnsStringArray;
  LErr: string;
begin
  R := NewMainResolver;
  Check(R.QueryMX('example.com', 1000, LHosts, LErr), 'mx query ok');
  Check(Length(LHosts) = 2, 'two mx');
  Check(LHosts[0] = 'mx2.example.com', 'pref 5 first');
  Check(LHosts[1] = 'mx1.example.com', 'pref 10 second');
end;

procedure TestNxdomain;
var
  R: IDnsResolver;
  LRecs: TDnsRecordArray;
  LErr: string;
begin
  R := NewMainResolver;
  Check(not R.Query('nx.example.com', dqTXT, 1000, LRecs, LErr), 'nxdomain false');
  Check(Pos('nxdomain', LErr) > 0, 'error nxdomain');
end;

procedure TestCacheHit;
var
  R: IDnsResolver;
  LTexts: TDnsStringArray;
  LErr: string;
  LBefore: Integer;
begin
  R := NewMainResolver;
  GMainMock.QueryCount := 0;
  Check(R.QueryTXT('example.com', 1000, LTexts, LErr), 'first query');
  LBefore := GMainMock.QueryCount;
  Check(LBefore >= 1, 'first hits wire');
  Check(R.QueryTXT('example.com', 1000, LTexts, LErr), 'second query');
  Check(GMainMock.QueryCount = LBefore, 'cache hit, no new wire query');
end;

procedure TestWrongIdIgnored;
var
  R: IDnsResolver;
  LTexts: TDnsStringArray;
  LErr: string;
  LMock: TMockDnsServer;
begin
  SpawnMock(LMock, True, True);
  R := DnsResolver('127.0.0.1', 256, LMock.Port);
  Check(R.QueryTXT('example.com', 1000, LTexts, LErr), 'wrong id discarded');
  Check(Length(LTexts) = 1, 'still resolves');
  Check(LTexts[0] = 'v=spf1 -all ip4:192.0.2.0/24', 'payload right');
  StopMock(LMock);
end;

procedure TestTimeOut;
var
  R: IDnsResolver;
  LRecs: TDnsRecordArray;
  LErr: string;
  LMock: TMockDnsServer;
begin
  SpawnMock(LMock, False, False);   { 收到即丢 → poll 超时 }
  R := DnsResolver('127.0.0.1', 256, LMock.Port);
  Check(not R.Query('timeout.example.com', dqTXT, 300, LRecs, LErr),
    'timeout false');
  Check(Pos('timed out', LErr) > 0, 'error timed out');
  StopMock(LMock);
end;

var
  T: TTestSuite;

begin
  SpawnMock(GMainMock, True, False);

  T := TTestSuite.Create('nextpas.core.dns.resolve');
  T.Test('QueryTxt', @TestQueryTxt);
  T.Test('QueryMxSorted', @TestQueryMxSorted);
  T.Test('Nxdomain', @TestNxdomain);
  T.Test('CacheHit', @TestCacheHit);
  T.Test('WrongIdIgnored', @TestWrongIdIgnored);
  T.Test('TimeOut', @TestTimeOut);
  try
    if not T.Run then
      Halt(1);
  finally
    StopMock(GMainMock);
  end;
end.