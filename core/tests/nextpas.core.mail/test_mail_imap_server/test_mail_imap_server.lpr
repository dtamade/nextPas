program test_mail_imap_server;

{ 批次 3：IMAP 服务器事件驱动会话（mail.imap.server）集成测试。
  服务器走 epoll readiness 路径（Linux），客户端用裸 TcpConnect 行协议；
  存储为内存 mock（IImapMailboxStore），认证/吊销缝可编程翻转。

  覆盖：问候与能力串、登录三态与 TLS 门控、AUTHENTICATE PLAIN（IR/挑战/
  取消）、LIST/LSUB 黄金向量、SELECT/EXAMINE 全块、STATUS、FETCH 项矩阵
  （BODY[] 置 Seen / PEEK 不置）、SEARCH UNSEEN、STORE 置/清/no-op/只读拒/
  单序号、COPY 三态、APPEND 续行与 LITERAL+/超限、IDLE 四分支、吊销中途
  撤销、未知命令、行超限断开、背压溢出中止；另含序列集解析纯函数表。
  heaptrc 0 unfreed 由 Makefile 断言。 }

{$I nextpas.core.settings.inc}

{$IF not defined(NEXTPAS_LINUX)}
  {$ERROR test_mail_imap_server requires the Linux epoll backend}
{$ENDIF}

uses
  nextpas.core.thread.init,
  Classes,
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.net.server.base,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.mail.imap.base,
  nextpas.core.mail.imap.server,
  nextpas.core.mail;

const
  CR = #13; LF = #10; CRLF = #13#10;

var
  GScratch: string;

{ 计数等待（5ms 步进，最长 3s）：sink 计数由 reactor 线程写，主线程观察 }
function SpinWaitInt(var AValue: Int32; ATarget: Int32): Boolean;
var
  I: Int32;
begin
  Result := False;
  for I := 1 to 600 do
  begin
    if AValue >= ATarget then
      Exit(True);
    platform_thread_sleep_ns(5000000);
  end;
end;

procedure SleepCrossMs(const AMs: Int64);
begin
  platform_thread_sleep_ns(AMs * 1000000);
end;

type
  { ── 内存 mock 存储 ─────────────────────────────────────────── }
  TMemMail = record
    Uid: Int64;
    Seen: Boolean;
    Subject: string;
    FromAddr: string;
    ToAddr: string;
    InternalDate: string;
    Content: TBytes;
  end;

  TMemBox = record
    Name: string;
    Mails: array of TMemMail;
  end;

  TTestImapStore = class(TInterfacedObject, IImapMailboxStore)
  public
    Boxes: array of TMemBox;
    BumpVer: Int64;   { 外部线程可递增（IDLE 推送用；单写者对齐写，测试口径） }
    constructor Create;
    procedure AddBox(const AName: string);
    procedure AddMail(const ABox: string; ASeen: Boolean;
      const ASubject, AFrom, ATo, ADate: string; const AContent: string);
    function FindBox(const AName: string; out AIdx: Integer): Boolean;
    function ListMailboxes(const AUserId: string): TStringArray;
    function OpenMailbox(const AUserId, AName: string;
      out ABox: TImapMailboxSnapshot): Boolean;
    function ListUids(const ABox: TImapMailboxSnapshot): TImapUidArray;
    function LoadRows(const ABox: TImapMailboxSnapshot;
      const AUids: TImapUidArray): TImapMailRowArray;
    function LoadContent(const ABox: TImapMailboxSnapshot;
      AUid: Int64): TBytes;
    procedure SetSeen(const ABox: TImapMailboxSnapshot; AUid: Int64;
      ASeen: Boolean);
    function Search(const ABox: TImapMailboxSnapshot;
      const APred: TImapSearchPred): TImapUidArray;
    function Append(const AUserId, AName: string; const AContent: TBytes;
      AFlagSeen: Boolean; const AInternalDate: string;
      out ANewUid: Int64): Boolean;
    function CopyTo(const ASource: TImapMailboxSnapshot;
      const AUids: TImapUidArray; const ATargetName: string): Boolean;
    function ChangeVersion(const ABox: TImapMailboxSnapshot): Int64;
  end;

  TTestLoginCheck = class(TInterfacedObject, IImapLoginCheck)
  public
    FailMode: TImapAuthResult;
    constructor Create;
    function Verify(const AUsername, APassword: string;
      out AUserId: string): TImapAuthResult;
  end;

  TTestRevocation = class(TInterfacedObject, IImapRevocationCheck)
  public
    Revoked: Boolean;
    constructor Create;
    function Check(const AUserId: string): TImapRevocationStatus;
  end;

  TTestSink = class(TInterfacedObject, IImapServerSink)
  public
    LoginCount: Int32;
    LogoutCount: Int32;
    ClosedCount: Int32;
    OverflowCount: Int32;
    TimeoutCount: Int32;
    LastUser: string;
    procedure OnServerEvent(const AEvent: TMailImapServerEvent;
      const AUserId: string);
  end;

  PServerFixture = ^TServerFixture;
  TServerFixture = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  TTestHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  public
    SinkObj: TTestSink;
    Sink: IImapServerSink;
    Config: TImapServerConfig;
    StoreObj: TTestImapStore;
    Store: IImapMailboxStore;
    constructor Create(const ASink: TTestSink; const AConfig: TImapServerConfig;
      const AStore: TTestImapStore);
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;

{ ── mock 存储 ──────────────────────────────────────────────── }

constructor TTestImapStore.Create;
begin
  inherited Create;
end;

procedure TTestImapStore.AddBox(const AName: string);
var
  LN: Integer;
begin
  LN := Length(Boxes);
  SetLength(Boxes, LN + 1);
  Boxes[LN].Name := AName;
  SetLength(Boxes[LN].Mails, 0);
end;

function TTestImapStore.FindBox(const AName: string; out AIdx: Integer): Boolean;
var
  I: Integer;
begin
  AIdx := -1;
  for I := 0 to Length(Boxes) - 1 do
    if SameText(Boxes[I].Name, AName) or
       ((UpperCase(AName) = 'INBOX') and (Boxes[I].Name = 'INBOX')) then
    begin
      AIdx := I;
      Exit(True);
    end;
  Result := False;
end;

procedure TTestImapStore.AddMail(const ABox: string; ASeen: Boolean;
  const ASubject, AFrom, ATo, ADate: string; const AContent: string);
var
  LIdx, LN: Integer;
  LM: TMemMail;
begin
  if not FindBox(ABox, LIdx) then
    raise EImapError.Create('test store: no box ' + ABox);
  LN := Length(Boxes[LIdx].Mails);
  SetLength(Boxes[LIdx].Mails, LN + 1);
  LM.Uid := LN + 1;
  LM.Seen := ASeen;
  LM.Subject := ASubject;
  LM.FromAddr := AFrom;
  LM.ToAddr := ATo;
  LM.InternalDate := ADate;
  SetLength(LM.Content, Length(AContent));
  if Length(AContent) > 0 then
    Move(AContent[1], LM.Content[0], Length(AContent));
  Boxes[LIdx].Mails[LN] := LM;
end;

function TTestImapStore.ListMailboxes(const AUserId: string): TStringArray;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(Boxes));
  for LI := 0 to Length(Boxes) - 1 do
    Result[LI] := Boxes[LI].Name;
end;

function TTestImapStore.OpenMailbox(const AUserId, AName: string;
  out ABox: TImapMailboxSnapshot): Boolean;
var
  LIdx: Integer;
  LI: Integer;
begin
  if not FindBox(Trim(AName), LIdx) then
    Exit(False);
  ABox := Default(TImapMailboxSnapshot);
  ABox.Name := Boxes[LIdx].Name;
  ABox.Exists := Length(Boxes[LIdx].Mails);
  ABox.UidValidity := 1;
  ABox.UidNext := Length(Boxes[LIdx].Mails) + 1;
  for LI := 0 to Length(Boxes[LIdx].Mails) - 1 do
    if not Boxes[LIdx].Mails[LI].Seen then
      Inc(ABox.Unseen);
  Result := True;
end;

function TTestImapStore.ListUids(const ABox: TImapMailboxSnapshot): TImapUidArray;
var
  LIdx, I: Integer;
begin
  Result := nil;
  if not FindBox(ABox.Name, LIdx) then
    Exit;
  SetLength(Result, Length(Boxes[LIdx].Mails));
  for I := 0 to Length(Boxes[LIdx].Mails) - 1 do
    Result[I] := Boxes[LIdx].Mails[I].Uid;
end;

function TTestImapStore.LoadRows(const ABox: TImapMailboxSnapshot;
  const AUids: TImapUidArray): TImapMailRowArray;
var
  LIdx, I, J, LN: Integer;
begin
  Result := nil;
  if not FindBox(ABox.Name, LIdx) then
    Exit;
  LN := 0;
  for I := 0 to Length(AUids) - 1 do
    for J := 0 to Length(Boxes[LIdx].Mails) - 1 do
      if Boxes[LIdx].Mails[J].Uid = AUids[I] then
      begin
        SetLength(Result, LN + 1);
        Result[LN].Uid := Boxes[LIdx].Mails[J].Uid;
        Result[LN].Seq := J + 1;
        Result[LN].Seen := Boxes[LIdx].Mails[J].Seen;
        Result[LN].Size := Length(Boxes[LIdx].Mails[J].Content);
        Result[LN].Subject := Boxes[LIdx].Mails[J].Subject;
        Result[LN].FromAddr := Boxes[LIdx].Mails[J].FromAddr;
        Result[LN].ToAddr := Boxes[LIdx].Mails[J].ToAddr;
        Result[LN].InternalDate := Boxes[LIdx].Mails[J].InternalDate;
        Inc(LN);
        Break;
      end;
end;

function TTestImapStore.LoadContent(const ABox: TImapMailboxSnapshot;
  AUid: Int64): TBytes;
var
  LIdx, J: Integer;
begin
  Result := nil;
  if not FindBox(ABox.Name, LIdx) then
    Exit;
  for J := 0 to Length(Boxes[LIdx].Mails) - 1 do
    if Boxes[LIdx].Mails[J].Uid = AUid then
      Exit(System.Copy(Boxes[LIdx].Mails[J].Content, 0,
        Length(Boxes[LIdx].Mails[J].Content)));
end;

procedure TTestImapStore.SetSeen(const ABox: TImapMailboxSnapshot;
  AUid: Int64; ASeen: Boolean);
var
  LIdx, J: Integer;
begin
  if not FindBox(ABox.Name, LIdx) then
    Exit;
  for J := 0 to Length(Boxes[LIdx].Mails) - 1 do
    if Boxes[LIdx].Mails[J].Uid = AUid then
    begin
      Boxes[LIdx].Mails[J].Seen := ASeen;
      Inc(BumpVer);
      Exit;
    end;
end;

function TTestImapStore.Search(const ABox: TImapMailboxSnapshot;
  const APred: TImapSearchPred): TImapUidArray;
var
  LIdx, J: Integer;
begin
  Result := nil;
  if not FindBox(ABox.Name, LIdx) then
    Exit;
  for J := 0 to Length(Boxes[LIdx].Mails) - 1 do
    if (not APred.Unseen) or (not Boxes[LIdx].Mails[J].Seen) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Boxes[LIdx].Mails[J].Uid;
    end;
end;

function TTestImapStore.Append(const AUserId, AName: string;
  const AContent: TBytes; AFlagSeen: Boolean; const AInternalDate: string;
  out ANewUid: Int64): Boolean;
var
  LIdx, LN: Integer;
begin
  if not FindBox(AName, LIdx) then
    Exit(False);
  LN := Length(Boxes[LIdx].Mails);
  SetLength(Boxes[LIdx].Mails, LN + 1);
  Boxes[LIdx].Mails[LN].Uid := LN + 1;
  Boxes[LIdx].Mails[LN].Seen := AFlagSeen;
  Boxes[LIdx].Mails[LN].InternalDate := AInternalDate;
  Boxes[LIdx].Mails[LN].Content := System.Copy(AContent, 0, Length(AContent));
  ANewUid := LN + 1;
  Inc(BumpVer);
  Result := True;
end;

function TTestImapStore.CopyTo(const ASource: TImapMailboxSnapshot;
  const AUids: TImapUidArray; const ATargetName: string): Boolean;
var
  LSrc, LDst, I, J, LN: Integer;
begin
  if not FindBox(ATargetName, LDst) then
    Exit(False);
  if not FindBox(ASource.Name, LSrc) then
    Exit(False);
  for I := 0 to Length(AUids) - 1 do
    for J := 0 to Length(Boxes[LSrc].Mails) - 1 do
      if Boxes[LSrc].Mails[J].Uid = AUids[I] then
      begin
        LN := Length(Boxes[LDst].Mails);
        SetLength(Boxes[LDst].Mails, LN + 1);
        Boxes[LDst].Mails[LN] := Boxes[LSrc].Mails[J];
        Boxes[LDst].Mails[LN].Uid := LN + 1;
      end;
  Inc(BumpVer);
  Result := True;
end;

function TTestImapStore.ChangeVersion(
  const ABox: TImapMailboxSnapshot): Int64;
begin
  Result := 1000 + BumpVer;
end;

{ ── 认证 / 吊销 / sink ─────────────────────────────────────── }

constructor TTestLoginCheck.Create;
begin
  inherited Create;
  FailMode := iarOk;
end;

function TTestLoginCheck.Verify(const AUsername, APassword: string;
  out AUserId: string): TImapAuthResult;
begin
  if FailMode <> iarOk then
    Exit(FailMode);
  if (AUsername = 'user@test.example') and (APassword = 'secret') then
  begin
    AUserId := 'uid-1';
    Result := iarOk;
  end
  else
    Result := iarInvalid;
end;

constructor TTestRevocation.Create;
begin
  inherited Create;
  Revoked := False;
end;

function TTestRevocation.Check(const AUserId: string): TImapRevocationStatus;
begin
  if Revoked then
    Result := irsRevoked
  else
    Result := irsActive;
end;

procedure TTestSink.OnServerEvent(const AEvent: TMailImapServerEvent;
  const AUserId: string);
begin
  case AEvent of
    iiseLogin: begin Inc(LoginCount); LastUser := AUserId; end;
    iiseLogout: Inc(LogoutCount);
    iiseClosed: Inc(ClosedCount);
    iiseOverflow: Inc(OverflowCount);
    iiseTimeout: Inc(TimeoutCount);
  end;
end;

{ ── 夹具 ──────────────────────────────────────────────────── }

constructor TTestHandler.Create(const ASink: TTestSink;
  const AConfig: TImapServerConfig; const AStore: TTestImapStore);
begin
  inherited Create;
  SinkObj := ASink;
  Sink := ASink;
  Config := AConfig;
  StoreObj := AStore;
  Store := AStore;
end;

function TTestHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  Result := tscoServer;
end;

function TTestHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := TMailImapServerSession.Create(AConn, Sink, Config, Store);
end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerFixture;
begin
  Result := nil;
  LCtx := PServerFixture(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  finally
    LCtx^.Server := nil;
    LCtx^.Handler := nil;
    Dispose(LCtx);
  end;
end;

procedure StopSmtpServer(var AServer: ITcpServer;
  const AThread: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AThread, LRet);
  AServer := nil;
end;

{ 标准夹具：INBOX(uid1 已读 / uid2、uid3 未读) + alias@example.com(1 封已读) }
procedure MakeStore(AStore: TTestImapStore);
begin
  AStore.AddBox('INBOX');
  AStore.AddMail('INBOX', True, 'first', 'a@x.test', 'inbox@t.test',
    'Mon, 24 Aug 2026 10:00:00 +0000', 'mail one body');
  AStore.AddMail('INBOX', False, 'second', 'b@x.test', 'inbox@t.test',
    'Mon, 24 Aug 2026 11:00:00 +0000', 'mail two body');
  AStore.AddMail('INBOX', False, 'third', 'c@x.test', 'inbox@t.test',
    'Mon, 24 Aug 2026 12:00:00 +0000', 'mail three body');
  AStore.AddBox('alias@example.com');
  AStore.AddMail('alias@example.com', True, 'aliased', 'd@x.test', 'al@t.test',
    'Mon, 24 Aug 2026 13:00:00 +0000', 'alias body');
end;

type
  TFx = record
    StoreObj: TTestImapStore;
    Store: IImapMailboxStore;
    SinkObj: TTestSink;
    Sink: IImapServerSink;
    Handler: TTestHandler;
    HInterface: ITcpServerHandler;
    Server: ITcpServer;
    Thread: TPlatformThreadHandle;
    Port: UInt16;
  end;

function DefaultConfig: TImapServerConfig;
begin
  Result := TImapServerConfig.Default;
  Result.LoginCheck := nil;  { 由各用例注入 }
end;

procedure StartFx(out AFx: TFx; const AConfig: TImapServerConfig);
var
  LCtx: PServerFixture;
  LOptions: TTcpServerOptions;
  LWait: Int32;
begin
  AFx.StoreObj := TTestImapStore.Create;
  AFx.Store := AFx.StoreObj;
  MakeStore(AFx.StoreObj);
  AFx.SinkObj := TTestSink.Create;
  AFx.Sink := AFx.SinkObj;
  AFx.Handler := TTestHandler.Create(AFx.SinkObj, AConfig, AFx.StoreObj);
  AFx.HInterface := AFx.Handler;
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  AFx.Server := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := AFx.Server;
  LCtx^.Handler := AFx.HInterface;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  AFx.Port := 0;
  platform_thread_create(AFx.Thread, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AFx.Server.IsRunning) and (LWait < 600) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AFx.Server.IsRunning, 'imap server should start');
  AFx.Port := AFx.Server.LocalAddr.Port;
  Check(AFx.Port > 0, 'imap server bound port');
end;

procedure StopFx(var AFx: TFx);
begin
  StopSmtpServer(AFx.Server, AFx.Thread);
  AFx.HInterface := nil;
  AFx.Sink := nil;
  AFx.Store := nil;
  AFx.Handler := nil;
end;

{ ── 裸行协议客户端 ────────────────────────────────────────── }

type
  TRawClient = record
    Stream: ITcpStream;
    function Open(const APort: UInt16): Boolean;
    function ReadLine(const ATimeoutMs: Int64; out ALine: string): Boolean;
    function SendLine(const ALine: string): Boolean;
    function SendRaw(const APayload: string): Boolean;
    procedure Close;
  end;

function TRawClient.Open(const APort: UInt16): Boolean;
begin
  try
    Stream := TcpConnect('127.0.0.1', APort, 2000);
    Result := True;
  except
    Result := False;
  end;
end;

function TRawClient.ReadLine(const ATimeoutMs: Int64; out ALine: string): Boolean;
var
  LB: TBytes;
  LCap: Integer;
  LRaw: Byte;
begin
  Result := False;
  ALine := '';
  SetLength(LB, 256);
  LCap := 0;
  try
    if ATimeoutMs > 0 then
      Stream.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)))
    else
      Stream.SetReadDeadline(TDeadline.Infinite);
    while True do
    begin
      LRaw := 0;
      if Stream.Read(LRaw, 1) = 0 then
        Exit;
      if LRaw = 10 then
        Break;
      if LRaw <> 13 then
      begin
        if LCap >= Length(LB) then
          SetLength(LB, LCap * 2);
        LB[LCap] := LRaw;
        Inc(LCap);
      end;
    end;
    SetLength(LB, LCap);
    ALine := ASCIIBytesToString(LB);
    Result := True;
  except
    Result := False;
  end;
end;

function TRawClient.SendLine(const ALine: string): Boolean;
begin
  Result := SendRaw(ALine + CRLF);
end;

function TRawClient.SendRaw(const APayload: string): Boolean;
begin
  try
    Stream.Write(PAnsiChar(APayload)^, Length(APayload));
    Result := True;
  except
    Result := False;
  end;
end;

procedure TRawClient.Close;
begin
  if Stream <> nil then
    try
      Stream.Close;
    except
    end;
  Stream := nil;
end;

procedure ExpectLine(const C: TRawClient; const AExpect, AWhat: string);
var
  LLine: string;
begin
  Check(C.ReadLine(3000, LLine), 'read ' + AWhat);
  Check(LLine = AExpect, AWhat + ': expected "' + AExpect + '", got "' +
    LLine + '"');
end;

procedure ExpectPrefix(const C: TRawClient; const APrefix, AWhat: string);
var
  LLine: string;
begin
  Check(C.ReadLine(3000, LLine), 'read ' + AWhat);
  Check(Copy(LLine, 1, Length(APrefix)) = APrefix,
    AWhat + ': expected prefix "' + APrefix + '", got "' + LLine + '"');
end;

{ 登录到 Selected 态（标准夹具口令） }
procedure LoginAndSelect(const C: TRawClient);
begin
  C.SendLine('a1 LOGIN user@test.example secret');
  ExpectLine(C, 'a1 OK LOGIN completed', 'login ok');
  C.SendLine('a2 SELECT INBOX');
  ExpectLine(C, '* 3 EXISTS', 'select exists');
  ExpectLine(C, '* 0 RECENT', 'select recent');
  ExpectLine(C, '* OK [UNSEEN 2]', 'select unseen');
  ExpectLine(C, '* OK [UIDVALIDITY 1]', 'select uidvalidity');
  ExpectLine(C, '* OK [UIDNEXT 4]', 'select uidnext');
  ExpectLine(C, '* FLAGS (\Seen \Answered \Flagged \Deleted \Draft)',
    'select flags');
  ExpectLine(C, '* OK [PERMANENTFLAGS (\Seen \Answered \Flagged \Deleted \Draft)]',
    'select permflags');
  ExpectLine(C, 'a2 OK [READ-WRITE] SELECT completed', 'select tagged');
end;

{ ── 用例 ──────────────────────────────────────────────────── }

procedure TestPureSequenceSet;
var
  SUids, OutUids: TImapUidArray;
  LOk: Boolean;
begin
  SUids := TImapUidArray.Create(11, 22, 33, 44, 55);

  LOk := ImapResolveSequenceSet('2', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 1) and (OutUids[0] = 22), 'seq single');
  LOk := ImapResolveSequenceSet('2:4', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 3) and (OutUids[0] = 22) and
    (OutUids[2] = 44), 'seq range');
  LOk := ImapResolveSequenceSet('4:2', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 3), 'seq reversed range');
  LOk := ImapResolveSequenceSet('*', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 1) and (OutUids[0] = 55), 'seq star');
  LOk := ImapResolveSequenceSet('1:*', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 5), 'seq all');
  LOk := ImapResolveSequenceSet('1,3,5', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 3) and (OutUids[2] = 55), 'seq list');
  LOk := ImapResolveSequenceSet('1,2:4,*', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 5), 'seq union dedup by mask');
  LOk := ImapResolveSequenceSet('9', SUids, False, OutUids);
  Check(LOk and (Length(OutUids) = 0), 'seq beyond end -> empty ok');
  LOk := ImapResolveSequenceSet('0', SUids, False, OutUids);
  Check(not LOk, 'seq zero invalid');
  LOk := ImapResolveSequenceSet('1:x', SUids, False, OutUids);
  Check(not LOk, 'seq alpha invalid');
  LOk := ImapResolveSequenceSet('', SUids, False, OutUids);
  Check(not LOk, 'empty invalid');

  LOk := ImapResolveSequenceSet('22:44', SUids, True, OutUids);
  Check(LOk and (Length(OutUids) = 3) and (OutUids[0] = 22), 'uid range');
  LOk := ImapResolveSequenceSet('*', SUids, True, OutUids);
  Check(LOk and (Length(OutUids) = 1) and (OutUids[0] = 55), 'uid star');
  LOk := ImapResolveSequenceSet('12', SUids, True, OutUids);
  Check(LOk and (Length(OutUids) = 0), 'uid gap -> empty ok');

  { 空邮箱：合法语法解不出目标 → True 空集 }
  LOk := ImapResolveSequenceSet('1:*', nil, False, OutUids);
  Check(LOk and (Length(OutUids) = 0), 'empty mailbox -> empty ok');
end;

procedure TestPureRequestLine;
var
  LT, LV, LA: string;
  LPos: SizeUInt;
  LNum: Int64;
  LB: Boolean;
begin
  Check(ImapParseRequestLine('A01 CAPABILITY', LT, LV, LA), 'rl parse');
  Check((LT = 'A01') and (LV = 'CAPABILITY') and (LA = ''), 'rl two-token');
  Check(ImapParseRequestLine('a1 select inbox extra args', LT, LV, LA),
    'rl parse lower');
  Check((LV = 'SELECT') and (LA = 'inbox extra args'), 'rl upper verb');
  Check(not ImapParseRequestLine('NOFLAG', LT, LV, LA), 'rl no space');
  Check(not ImapParseRequestLine(' x y', LT, LV, LA), 'rl empty tag');
  Check(not ImapParseRequestLine('tag ', LT, LV, LA), 'rl empty verb');

  { literal 尾标记提取 }
  LPos := 0;
  Check(ImapExtractLiteralTail('a APPEND INBOX {12}', LPos, LNum, LB),
    'literal tail parse');
  Check((LNum = 12) and (not LB), 'literal len 12 no-plus');
  Check(ImapExtractLiteralTail('x {5+}', LPos, LNum, LB) and LB and
    (LNum = 5), 'literal plus form');
  Check(not ImapExtractLiteralTail('plain line', LPos, LNum, LB),
    'no literal tail');
  Check(not ImapExtractLiteralTail('{abc}', LPos, LNum, LB),
    'non-digit marker rejected');
  Check(not ImapExtractLiteralTail('{}', LPos, LNum, LB),
    'empty marker rejected');
end;

procedure TestGreetingAndCapability;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'client open');
    ExpectLine(C,
      '* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR IDLE AUTH=PLAIN] IMAP4rev1 IMAP server ready',
      'greeting');
    C.SendLine('t1 CAPABILITY');
    ExpectLine(C, '* CAPABILITY IMAP4rev1 LITERAL+ SASL-IR IDLE AUTH=PLAIN',
      'capability untagged');
    ExpectLine(C, 't1 OK CAPABILITY completed', 'capability tagged');
    { 未认证态受保护命令 }
    C.SendLine('t2 LIST "" "*"');
    ExpectLine(C, 't2 NO Not authenticated', 'list unauthed');
    C.SendLine('t3 FETCH 1 (FLAGS)');
    ExpectLine(C, 't3 NO No mailbox selected', 'fetch unselected');
    { 未知命令与空行 }
    C.SendLine('t4 FROBNICATE');
    ExpectLine(C, 't4 BAD Unknown command', 'unknown cmd');
    C.SendLine('');
    C.SendLine('t5 NOOP');
    ExpectLine(C, 't5 OK NOOP completed', 'noop after empty line');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestLoginStates;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    { 凭证错误 }
    C.SendLine('l1 LOGIN user@test.example wrong');
    ExpectLine(C, 'l1 NO Authentication failed', 'bad creds');
    { 缺参数 }
    C.SendLine('l2 LOGIN onlyuser');
    ExpectLine(C, 'l2 BAD LOGIN requires username and password', 'missing arg');
    { 成功 }
    C.SendLine('l3 LOGIN user@test.example secret');
    ExpectLine(C, 'l3 OK LOGIN completed', 'login ok');
    Check(SpinWaitInt(AFx.SinkObj.LoginCount, 1), 'sink login');
    { LOGOUT：BYE + tagged OK，随后连接关闭 }
    C.SendLine('l4 LOGOUT');
    ExpectLine(C, '* BYE Logging out', 'bye');
    ExpectLine(C, 'l4 OK LOGOUT completed', 'logout ok');
    Check(SpinWaitInt(AFx.SinkObj.LogoutCount, 1), 'sink logout');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestLoginNilSeamFailClosed;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;  { LoginCheck = nil }
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    C.SendLine('n1 LOGIN user@test.example secret');
    ExpectLine(C, 'n1 NO Authentication temporarily unavailable',
      'nil seam fail-closed');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestLoginTlsGate;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.TlsAvailable := True;   { 宣告 STARTTLS LOGINDISABLED 分支 }
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    ExpectLine(C,
      '* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR IDLE STARTTLS LOGINDISABLED] IMAP4rev1 IMAP server ready',
      'tls greeting');
    C.SendLine('g1 LOGIN user@test.example secret');
    ExpectLine(C, 'g1 NO LOGIN disabled until STARTTLS', 'login gated');
    { TlsAvailable=True 走「OK Begin TLS」分支；无握手缝随即关连
      （CONTRACT §8 偏离表披露），客户端读到 EOF }
    C.SendLine('g2 STARTTLS');
    ExpectLine(C, 'g2 OK Begin TLS negotiation now', 'starttls ok branch');
    Check(not C.ReadLine(3000, GScratch), 'conn closed after starttls ok');
  finally
    StopFx(AFx);
  end;
end;

procedure TestAuthenticatePlain;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    { SASL-IR：authzid NUL authcid NUL passwd 的 base64 }
    C.SendLine('m1 AUTHENTICATE PLAIN AHVzZXJAdGVzdC5leGFtcGxlAHNlY3JldA==');
    ExpectLine(C, 'm1 OK LOGIN completed', 'auth ir ok');
    C.SendLine('m2 AUTHENTICATE CRAM-MD5');
    ExpectLine(C, 'm2 BAD Unsupported authentication mechanism', 'bad mech');
    { 挑战形态：+ 续行后一行 base64；'*' 取消 }
    C.SendLine('m3 AUTHENTICATE PLAIN');
    ExpectLine(C, '+ ', 'sasl challenge');
    C.SendLine('*');
    ExpectLine(C, 'm3 BAD Authentication cancelled', 'sasl cancel');
    C.SendLine('m4 AUTHENTICATE PLAIN');
    ExpectLine(C, '+ ', 'sasl challenge 2');
    C.SendLine('AHVzZXJAdGVzdC5leGFtcGxlAHdyb25n');
    ExpectLine(C, 'm4 NO Authentication failed', 'sasl wrong pass');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestListSelectExamineStatus;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
  LDummy: Integer;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    C.SendLine('a1 LOGIN user@test.example secret');
    C.ReadLine(3000, GScratch);
    { LIST 黄金向量（原版怪癖保持：LSUB 也输出 LIST 且 tagged 为 LIST） }
    C.SendLine('a2 LIST "" "*"');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "INBOX"', 'list inbox');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "INBOX"', 'list dup-inbox-box');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "alias@example.com"',
      'list alias');
    ExpectLine(C, 'a2 OK LIST completed', 'list tagged');
    C.SendLine('a3 LSUB "" "*"');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "INBOX"', 'lsub mirrors inbox');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "INBOX"', 'lsub mirrors dup');
    ExpectLine(C, '* LIST (\HasNoChildren) "/" "alias@example.com"',
      'lsub mirrors alias');
    ExpectLine(C, 'a3 OK LIST completed', 'lsub tagged quirk');
    { SELECT 全块黄金向量 }
    C.SendLine('a4 SELECT INBOX');
    ExpectLine(C, '* 3 EXISTS', 'sel exists');
    ExpectLine(C, '* 0 RECENT', 'sel recent');
    ExpectLine(C, '* OK [UNSEEN 2]', 'sel unseen');
    ExpectLine(C, '* OK [UIDVALIDITY 1]', 'sel uidvalidity');
    ExpectLine(C, '* OK [UIDNEXT 4]', 'sel uidnext');
    ExpectLine(C, '* FLAGS (\Seen \Answered \Flagged \Deleted \Draft)', 'sel flags');
    ExpectLine(C, '* OK [PERMANENTFLAGS (\Seen \Answered \Flagged \Deleted \Draft)]',
      'sel perm');
    ExpectLine(C, 'a4 OK [READ-WRITE] SELECT completed', 'sel tagged');
    { STATUS 固定三元 }
    C.SendLine('a5 STATUS INBOX (MESSAGES UNSEEN)');
    ExpectLine(C, '* STATUS "INBOX" (MESSAGES 3 UNSEEN 2 RECENT 0)',
      'status output');
    ExpectLine(C, 'a5 OK STATUS completed', 'status tagged');
    C.SendLine('a6 STATUS missing@nowhere.test (MESSAGES)');
    ExpectLine(C, 'a6 NO Mailbox not found', 'status missing');
    { EXAMINE 只读 }
    C.SendLine('a7 EXAMINE INBOX');
    ExpectPrefix(C, '* 3 EXISTS', 'examine exists');
    for LDummy := 1 to 6 do
      C.ReadLine(3000, GScratch);
    ExpectLine(C, 'a7 OK [READ-ONLY] SELECT completed', 'examine tagged');
    C.SendLine('a8 STORE 1 +FLAGS (\Seen)');
    ExpectLine(C, 'a8 NO Mailbox is read-only', 'store readonly reject');
    C.SendLine('a9 SELECT missing@nowhere.test');
    ExpectLine(C, 'a9 NO Mailbox not found', 'select missing');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestFetchMatrix;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    LoginAndSelect(C);
    { FLAGS 单封（seq 1 已读） }
    C.SendLine('b1 FETCH 1 (FLAGS)');
    ExpectLine(C, '* 1 FETCH (FLAGS (\Seen))', 'fetch flags seen');
    ExpectLine(C, 'b1 OK FETCH completed', 'fetch flags tagged');
    { UID 显式项 + 未读旗标空括号 }
    C.SendLine('b2 FETCH 2 (UID FLAGS)');
    ExpectLine(C, '* 2 FETCH (UID 2 FLAGS ())', 'fetch uid+flags empty');
    ExpectLine(C, 'b2 OK FETCH completed', 'b2 tagged');
    { BODY[] 置 \Seen（响应内旗标取旧值，原版同序） }
    C.SendLine('b3 FETCH 2 (BODY[] FLAGS)');
    ExpectLine(C, '* 2 FETCH (FLAGS () BODY[] {13}', 'fetch body literal head');
    ExpectLine(C, 'mail two body)', 'body content incl close paren');
    ExpectLine(C, 'b3 OK FETCH completed', 'b3 tagged');
    C.SendLine('b4 FETCH 2 (FLAGS)');
    ExpectLine(C, '* 2 FETCH (FLAGS (\Seen))', 'body marked seen');
    ExpectLine(C, 'b4 OK FETCH completed', 'b4 tagged');
    { BODY.PEEK[] 不置旗标（超越点：原版误置） }
    C.SendLine('b5 FETCH 3 (BODY.PEEK[])');
    ExpectPrefix(C, '* 3 FETCH (BODY.PEEK[] {15}', 'peek literal');
    ExpectLine(C, 'mail three body)', 'peek content incl close paren');
    ExpectLine(C, 'b5 OK FETCH completed', 'b5 tagged');
    C.SendLine('b6 FETCH 3 (FLAGS)');
    ExpectLine(C, '* 3 FETCH (FLAGS ())', 'peek left unseen');
    ExpectLine(C, 'b6 OK FETCH completed', 'b6 tagged');
    { RFC822.SIZE / INTERNALDATE / ENVELOPE }
    C.SendLine('b7 FETCH 1 (RFC822.SIZE INTERNALDATE ENVELOPE)');
    ExpectLine(C,
      '* 1 FETCH (ENVELOPE ("Mon, 24 Aug 2026 10:00:00 +0000" "first" ((NIL NIL "a@x.test" "")) ((NIL NIL "inbox@t.test" "")) NIL NIL NIL NIL) RFC822.SIZE 13 INTERNALDATE "Mon, 24 Aug 2026 10:00:00 +0000")',
      'fetch size+date+envelope');
    ExpectLine(C, 'b7 OK FETCH completed', 'b7 tagged');
    { 未知项兜底 FLAGS（原版口径） }
    C.SendLine('b8 FETCH 1 (MYSTERY)');
    ExpectLine(C, '* 1 FETCH (FLAGS (\Seen))', 'unknown item fallback');
    ExpectLine(C, 'b8 OK FETCH completed', 'b8 tagged');
    { UID 变体等价 }
    C.SendLine('b9 UID FETCH 3 (FLAGS)');
    ExpectLine(C, '* 3 FETCH (UID 3 FLAGS ())', 'uid fetch variant');
    ExpectLine(C, 'b9 OK FETCH completed', 'b9 tagged');
    { 序列集范围 }
    C.SendLine('b10 FETCH 1:2 (UID)');
    ExpectLine(C, '* 1 FETCH (UID 1)', 'range row1');
    ExpectLine(C, '* 2 FETCH (UID 2)', 'range row2');
    ExpectLine(C, 'b10 OK FETCH completed', 'range tagged');
    { 坏序列集 }
    C.SendLine('b11 FETCH x (FLAGS)');
    ExpectLine(C, 'b11 BAD Invalid FETCH sequence-set', 'fetch bad set');
    C.SendLine('b12 FETCH');
    ExpectLine(C, 'b12 BAD Invalid FETCH arguments', 'fetch no args');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestSearchStoreCopy;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    LoginAndSelect(C);
    { SEARCH UNSEEN：uid 2,3 }
    C.SendLine('c1 SEARCH UNSEEN');
    ExpectLine(C, '* SEARCH 2 3', 'search unseen uids');
    ExpectLine(C, 'c1 OK SEARCH completed', 'search tagged');
    { UID SEARCH 输出恒 UID（原版怪癖保持） }
    C.SendLine('c2 UID SEARCH UNSEEN');
    ExpectLine(C, '* SEARCH 2 3', 'uid search quirk');
    ExpectLine(C, 'c2 OK SEARCH completed', 'uid search tagged');
    { STORE +FLAGS/-FLAGS/no-op/range 拒绝 }
    C.SendLine('c3 STORE 2 +FLAGS (\Seen)');
    ExpectLine(C, 'c3 OK STORE completed', 'store set');
    C.SendLine('c4 FETCH 2 (FLAGS)');
    ExpectLine(C, '* 2 FETCH (FLAGS (\Seen))', 'store set verified');
    C.ReadLine(3000, GScratch);
    C.SendLine('c5 STORE 2 -FLAGS (\Seen)');
    ExpectLine(C, 'c5 OK STORE completed', 'store clear');
    C.SendLine('c6 FETCH 2 (FLAGS)');
    ExpectLine(C, '* 2 FETCH (FLAGS ())', 'store clear verified');
    C.ReadLine(3000, GScratch);
    C.SendLine('c7 STORE 1 +FLAGS (\Flagged)');
    ExpectLine(C, 'c7 OK STORE completed (no-op)', 'store noop flag');
    C.SendLine('c8 STORE 1:2 +FLAGS (\Seen)');
    ExpectLine(C, 'c8 BAD Invalid STORE sequence-set', 'store range rejected');
    C.SendLine('c9 UID STORE 3 +FLAGS (\Seen)');
    ExpectLine(C, 'c9 OK STORE completed', 'uid store set');
    C.SendLine('c10 FETCH 3 (FLAGS)');
    ExpectLine(C, '* 3 FETCH (FLAGS (\Seen))', 'uid store verified');
    C.ReadLine(3000, GScratch);
    { COPY 三态 }
    C.SendLine('c11 COPY 1 alias@example.com');
    ExpectLine(C, 'c11 OK COPY completed', 'copy ok');
    C.SendLine('c12 STATUS alias@example.com (MESSAGES)');
    ExpectLine(C, '* STATUS "alias@example.com" (MESSAGES 2 UNSEEN 0 RECENT 0)',
      'copy landed status');
    ExpectLine(C, 'c12 OK STATUS completed', 'status after copy');
    C.SendLine('c13 COPY 1 nowhere@x.test');
    ExpectLine(C, 'c13 NO Mailbox not found', 'copy missing target');
    C.SendLine('c14 COPY zzz alias@example.com');
    ExpectLine(C, 'c14 BAD Invalid COPY sequence-set', 'copy bad set');
    { CLOSE 回认证态 }
    C.SendLine('c15 CLOSE');
    ExpectLine(C, 'c15 OK CLOSE completed', 'close ok');
    C.SendLine('c16 FETCH 1 (FLAGS)');
    ExpectLine(C, 'c16 NO No mailbox selected', 'after close deselect');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestAppendLiterals;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  LCfg.MaxLiteral := 64;   { 小上限驱动超限分支 }
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    C.SendLine('p0 LOGIN user@test.example secret');
    C.ReadLine(3000, GScratch);
    { 普通形态：先收续行提示再推正文 }
    C.SendLine('p1 APPEND INBOX (\Seen) {11}');
    C.SendRaw('hello world' + CRLF);
    ExpectPrefix(C, '+ ', 'append continuation');
    ExpectLine(C, 'p1 OK APPEND completed', 'append ok');
    C.SendLine('p2 STATUS INBOX (MESSAGES UNSEEN)');
    ExpectLine(C, '* STATUS "INBOX" (MESSAGES 4 UNSEEN 2 RECENT 0)',
      'append flagged-seen not unseen');
    ExpectLine(C, 'p2 OK STATUS completed', 'status after append');
    { LITERAL+ 直收无提示 }
    C.SendLine('p3 APPEND INBOX {5+}');
    C.SendRaw('abcde' + CRLF);
    ExpectLine(C, 'p3 OK APPEND completed', 'literal plus ok');
    C.SendLine('p4 STATUS INBOX (MESSAGES)');
    ExpectLine(C, '* STATUS "INBOX" (MESSAGES 5 UNSEEN 3 RECENT 0)',
      'append unflagged unseen');
    ExpectLine(C, 'p4 OK STATUS completed', 'status 2');
    { 超限：tagged BAD + 字节丢弃后会话仍可用 }
    C.SendLine('p5 APPEND INBOX {100}');
    ExpectLine(C, 'p5 BAD Literal too large', 'literal too large');
    C.SendRaw(StringOfChar('x', 100) + CRLF);
    C.SendLine('p6 NOOP');
    ExpectLine(C, 'p6 OK NOOP completed', 'session alive after discard');
    { 无 literal 参数畸形 }
    C.SendLine('p7 APPEND');
    ExpectLine(C, 'p7 BAD Invalid APPEND arguments', 'append bare');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestIdleCycle;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  LCfg.IdlePollMs := 60;
  LCfg.IdleTimeoutMs := 8000;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    LoginAndSelect(C);
    { 进入 IDLE → 版本变更推送未决 EXISTS → DONE 收尾 }
    C.SendLine('i1 IDLE');
    ExpectLine(C, '+ idling', 'idle continue');
    AFx.StoreObj.BumpVer := AFx.StoreObj.BumpVer + 1;  { 模拟他端投递 }
    ExpectLine(C, '* 3 EXISTS', 'idle exists push');
    C.SendLine('DONE');
    ExpectLine(C, 'i1 OK IDLE completed', 'idle done');
    { 非 DONE 行退出 IDLE 并回 Selected 可继续 FETCH }
    C.SendLine('i2 IDLE');
    ExpectLine(C, '+ idling', 'idle again');
    C.SendLine('junk-line');
    ExpectLine(C, 'i2 BAD Expected DONE', 'idle bad line');
    C.SendLine('i3 FETCH 1 (UID)');
    ExpectLine(C, '* 1 FETCH (UID 1)', 'still selected');
    ExpectLine(C, 'i3 OK FETCH completed', 'fetch after idle');
    { 先退出选择再试 IDLE }
    C.SendLine('i5 CLOSE');
    ExpectLine(C, 'i5 OK CLOSE completed', 'close before idle-unselected');
    C.SendLine('i4 IDLE');
    ExpectLine(C, 'i4 NO No mailbox selected', 'idle unselected');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestIdleTimeout;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  LCfg.IdlePollMs := 50;
  LCfg.IdleTimeoutMs := 250;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    LoginAndSelect(C);
    C.SendLine('k1 IDLE');
    ExpectLine(C, '+ idling', 'idle cont');
    ExpectLine(C, '* BYE Idle timeout', 'idle timeout bye');
    C.Close;
    Check(SpinWaitInt(AFx.SinkObj.TimeoutCount, 1), 'sink timeout');
  finally
    StopFx(AFx);
  end;
end;

procedure TestRevocation;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
  LRev: TTestRevocation;
begin
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  LRev := TTestRevocation.Create;
  LCfg.RevocationCheck := LRev;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    C.SendLine('r1 LOGIN user@test.example secret');
    ExpectLine(C, 'r1 OK LOGIN completed', 'revoked-login ok');
    LRev.Revoked := True;
    C.SendLine('r2 LIST "" "*"');
    ExpectLine(C, 'r2 NO Authentication required', 'revoked gate');
    { 态已重置：后续命令按未认证处理 }
    C.SendLine('r3 LIST "" "*"');
    ExpectLine(C, 'r3 NO Not authenticated', 'reset to unauthed');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestOverflowAndLongLine;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
  LBig: string;
begin
  { 背压溢出：极小队列 + 大响应 }
  LCfg := DefaultConfig;
  LCfg.LoginCheck := TTestLoginCheck.Create;
  LCfg.OutboundQueueLimit := 128;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open overflow');
    C.ReadLine(3000, GScratch);
    C.SendLine('o1 LOGIN user@test.example secret');
    C.ReadLine(3000, GScratch);
    C.SendLine('o2 SELECT INBOX');
    repeat
      if not C.ReadLine(3000, GScratch) then
        Break;
    until Pos('SELECT completed', GScratch) > 0;
    C.SendLine('o3 FETCH 1:3 (BODY[])');
    { 队列超限时服务端中止：读侧终将断开 }
    while true do
      if not C.ReadLine(2000, GScratch) then
        Break;
    Check(SpinWaitInt(AFx.SinkObj.OverflowCount, 1), 'overflow sink');
    C.Close;
  finally
    StopFx(AFx);
  end;

  { 行超限：untagged BAD 后断开 }
  LCfg := DefaultConfig;
  LCfg.LineLimit := 128;
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open longline');
    C.ReadLine(3000, GScratch);
    LBig := StringOfChar('A', 512);
    C.SendLine(LBig);
    ExpectLine(C, '* BAD Command line too long', 'long line bad');
    C.Close;
  finally
    StopFx(AFx);
  end;
end;

procedure TestReadIdleTimeout;
var
  AFx: TFx;
  C: TRawClient;
  LCfg: TImapServerConfig;
begin
  LCfg := DefaultConfig;
  LCfg.IdleTimeoutMs := 250;   { 非读空闲复用同一配置字段（读空闲语义） }
  StartFx(AFx, LCfg);
  try
    Check(C.Open(AFx.Port), 'open');
    C.ReadLine(3000, GScratch);
    SleepCrossMs(500);
    { 服务端应已关连：写入或读取触发断开 }
    C.SendLine('z1 NOOP');
    Check(not C.ReadLine(3000, GScratch), 'conn closed by idle timeout');
    C.Close;
    Check(SpinWaitInt(AFx.SinkObj.TimeoutCount, 1), 'sink read timeout');
  finally
    StopFx(AFx);
  end;
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.mail.imap.server');
  T.Test('PureSequenceSet', @TestPureSequenceSet);
  T.Test('PureRequestLine', @TestPureRequestLine);
  T.Test('GreetingAndCapability', @TestGreetingAndCapability);
  T.Test('LoginStates', @TestLoginStates);
  T.Test('LoginNilSeamFailClosed', @TestLoginNilSeamFailClosed);
  T.Test('LoginTlsGate', @TestLoginTlsGate);
  T.Test('AuthenticatePlain', @TestAuthenticatePlain);
  T.Test('ListSelectExamineStatus', @TestListSelectExamineStatus);
  T.Test('FetchMatrix', @TestFetchMatrix);
  T.Test('SearchStoreCopy', @TestSearchStoreCopy);
  T.Test('AppendLiterals', @TestAppendLiterals);
  T.Test('IdleCycle', @TestIdleCycle);
  T.Test('IdleTimeout', @TestIdleTimeout);
  T.Test('Revocation', @TestRevocation);
  T.Test('OverflowAndLongLine', @TestOverflowAndLongLine);
  T.Test('ReadIdleTimeout', @TestReadIdleTimeout);
  if not T.Run then
    Halt(1);
end.
