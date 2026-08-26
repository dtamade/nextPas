unit nextpas.core.mail.imap.server;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail IMAP 服务器会话（L3，mail 家族，事件驱动）。
 *
 * 镜像 nextpas.core.mail.smtp.server 的接线模型：实现 net.server 的
 * poll-driven 会话契约（epoll/kqueue/iocp readiness 路径），一条连接一个
 * 会话，由 reactor 逐事件推进——可读喂字节解析，可写冲刷出站回复队列；
 * 读空闲/IDLE 轮询经 WakeDeadline 由 reactor 唤醒。不提供
 * per-connection-thread 阻塞降级（Run 显式拒绝）。
 *
 * 相对 SMTP 会话的三处协议特有形态：
 * ① literal 字节收集：行尾 literal 标记命中后进入计数收态，正文进独立
 *    缓冲（二进制安全），加号形态免续行提示，普通形态先发「+ 续行」；
 *    超长 literal 立即回 tagged BAD 并按计数丢弃字节；每命令至多一个
 *    literal（务实子集，CONTRACT §限制表）；
 * ② IDLE：进入后以 WakeDeadline 双截止（轮询周期 / 总时长）驱动，
 *    轮询查吊销缝与存储 ChangeVersion，变更即发未决 EXISTS；
 * ③ AUTHENTICATE PLAIN 挑战态：无初始应答时回「+ 空串」收一行。
 *
 * 存储与认证经 IImapMailboxStore/IImapLoginCheck/IImapRevocationCheck
 * 注入（见 imap.base）；回调在 reactor 线程同步执行，实现须短、非阻塞。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.platform.io.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.mail.imap.base;

type
  { 会话生命周期事件（应用记账用） }
  TMailImapServerEvent = (
    iiseLogin,     { 认证成功，AUserId 有效 }
    iiseLogout,    { 客户端 LOGOUT 完成 }
    iiseClosed,    { 传输终止；不再有后续事件 }
    iiseOverflow,  { 出站回复队列溢出；会话随即断开 }
    iiseTimeout    { 读空闲或 IDLE 总时长超时；会话随即断开 }
  );

  IImapServerSink = interface
    procedure OnServerEvent(const AEvent: TMailImapServerEvent;
      const AUserId: string);
  end;

  { 事件驱动的 IMAP 服务器会话 }
  TMailImapServerSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private type
    TSessState = (
      ssClosed,
      ssLine,        { 扫描命令行 / literal / SASL 续行 }
      ssFlushing     { 冲刷出站队列；完成后回 FResumeState }
    );
  var
    FConn: ITcpStream;
    FConnRuntime: ITcpStreamRuntime;
    FSink: IImapServerSink;
    FStore: IImapMailboxStore;
    FConfig: TImapServerConfig;
    FState: TSessState;
    FResumeState: TSessState;
    FDeadline: TDeadline;
    FReadBuf: array[0..4095] of Byte;
    FReadPos: SizeUInt;
    FReadAvail: SizeUInt;
    FLineBuf: array of Byte;       { 命令行累积（含 CR，二进制安全） }
    FLineLen: SizeUInt;
    FLiteralRemain: Int64;         { 待收集 literal 字节数；>0 即字面量收态 }
    FLiteralSkip: Int64;           { 超长 literal 丢弃计数（已回 BAD） }
    FLineHasLiteral: Boolean;      { 本逻辑行已收过 literal（终结时不再复检标记） }
    FLitBuf: TBytes;               { 本命令 literal 正文 }
    FLitLen: SizeUInt;
    FPendingHeader: string;        { literal 收集期的命令头行（含标记） }
    FOutbound: array of TBytes;
    FOutHead: SizeUInt;
    FOutCount: SizeUInt;
    FOutBytes: SizeUInt;
    FHeadPos: SizeUInt;
    FPhase: TImapSessionPhase;
    FUserId: string;
    FBox: TImapMailboxSnapshot;
    FBoxOpen: Boolean;
    FAwaitingSasl: Boolean;
    FTagPending: string;
    FInIdle: Boolean;
    FTagInIdle: string;
    FIdleBaseVer: Int64;
    FIdlePollDeadline: TDeadline;
    FIdleEndDeadline: TDeadline;
    function BuildLine: string;
    procedure RefreshDeadline;
    { 升序 uid 表二分定位(0 基); 未命中 -1 }
    class function UidPosition(const AUids: TImapUidArray;
      AUid: Int64): Int64; static;
    { 首个未读的序号(RFC 3501 UNSEEN 响应码语义);
      无未读返回 0(整行省略)。经 SEARCH 谓词下推 + ListUids 定位。 }
    function FirstUnseenOrdinal: Int64;
    function EffectiveIdlePollMs: Int64;
    function EffectiveIdleTimeoutMs: Int64;
    procedure NotifySink(const AEvent: TMailImapServerEvent);
    procedure AbortSession;
    procedure EnqueueStr(const AValue: string);
    procedure BeginFlush(const AResume: TSessState);
    procedure Reply(const ALine: string);
    procedure DrainReadable;
    procedure FlushOutbound;
    procedure FinishLine(AHadCR: Boolean);
    procedure StartLiteral(ALen: Int64; APlus: Boolean);
    procedure ProcessCommandLine(const ALine: string; const ALiteral: TBytes);
    procedure HandleSaslLine(const ALine: string);
    procedure VerifyCredentials(const ATag, AUser, APass: string);
    procedure EnterIdle(const ATag: string);
    procedure FinishIdle(const ATag: string; const AFinalLine: string);
    procedure PollIdleTick;
    procedure CmdCapability(const ATag: string);
    procedure CmdNoop(const ATag: string);
    procedure CmdLogout(const ATag: string);
    procedure CmdStartTls(const ATag: string);
    procedure CmdLogin(const ATag, AArgs: string);
    procedure CmdAuthenticate(const ATag, AArgs: string);
    procedure CmdListLike(const ATag, AVerb: string);
    procedure CmdSelectExamine(const ATag, AVerb, AArgs: string);
    procedure CmdStatus(const ATag, AArgs: string);
    procedure CmdAppend(const ATag, AArgs: string; const ALiteral: TBytes);
    procedure CmdClose(const ATag: string);
    procedure CmdFetch(const ATag, AArgs: string; AUidMode: Boolean);
    procedure CmdSearch(const ATag, AArgs: string);
    procedure CmdStore(const ATag, AArgs: string; AUidMode: Boolean);
    procedure CmdCopy(const ATag, AArgs: string; AUidMode: Boolean);
    function RequireSelected(const ATag: string): Boolean;
    function TryRevocationGate(const ATag: string): Boolean;
    procedure ResetAuthState;
  public
    constructor Create(const AConn: ITcpStream; const ASink: IImapServerSink;
      const AConfig: TImapServerConfig;
      const AStore: IImapMailboxStore);
    destructor Destroy; override;
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;
  end;

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.text.builder,
  nextpas.core.text.char,
  nextpas.core.text.conv;

const
  { 原版固定旗标面（SELECT FLAGS / PERMANENTFLAGS 输出逐字） }
  IMAP_FLAGS_LINE = '\Seen \Answered \Flagged \Deleted \Draft';

procedure AppendEnvelopeAddr(var AB: TBufStringBuilder; const AAddr: string);
begin
  AB.AppendStr('((NIL NIL "');
  AB.AppendStr(AAddr);
  AB.AppendStr('" ""))');
end;

{ FETCH 项列表词法展平：括号与逗号归一为空格，便于 token 精确匹配 }
{ ── 会话主体 ────────────────────────────────────────────────── }

constructor TMailImapServerSession.Create(const AConn: ITcpStream;
  const ASink: IImapServerSink; const AConfig: TImapServerConfig;
  const AStore: IImapMailboxStore);
var
  LCaps: string;
begin
  inherited Create;
  if AConn = nil then
    raise EArgumentError.Create('imap server session conn must not be nil');
  if AStore = nil then
    raise EArgumentError.Create('imap server session store must not be nil');
  FConn := AConn;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise EArgumentError.Create('imap server session requires stream runtime seam');
  FSink := ASink;
  FStore := AStore;
  FConfig := AConfig;
  if FConfig.MaxLiteral <= 0 then
    FConfig.MaxLiteral := MAIL_IMAP_DEFAULT_MAX_LITERAL;
  if FConfig.LineLimit = 0 then
    FConfig.LineLimit := MAIL_IMAP_LINE_LIMIT;
  if FConfig.OutboundQueueLimit = 0 then
    FConfig.OutboundQueueLimit := MAIL_IMAP_OUTBOUND_DEFAULT_LIMIT;
  FPhase := ispNotAuthenticated;
  FState := ssLine;
  FResumeState := ssLine;
  LCaps := ImapCapabilityString(FConfig.TlsAvailable, FConfig.TlsActive);
  EnqueueStr('* OK [CAPABILITY ' + LCaps + '] ' + FConfig.ServerName +
    ' IMAP server ready' + #13#10);
  BeginFlush(ssLine);
  RefreshDeadline;
end;

destructor TMailImapServerSession.Destroy;
begin
  NotifySink(iiseClosed);
  FConnRuntime := nil;
  FConn := nil;
  FSink := nil;
  FStore := nil;
  inherited Destroy;
end;

class function TMailImapServerSession.UidPosition(
  const AUids: TImapUidArray; AUid: Int64): Int64;
var
  LLo, LHi, LMid: Integer;
begin
  Result := -1;
  LLo := 0;
  LHi := Length(AUids) - 1;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) div 2;
    if AUids[LMid] = AUid then
      Exit(LMid)
    else if AUids[LMid] < AUid then
      LLo := LMid + 1
    else
      LHi := LMid - 1;
  end;
end;

function TMailImapServerSession.FirstUnseenOrdinal: Int64;
var
  LUnseen: TImapUidArray;
  LUids: TImapUidArray;
  LPos: Int64;
begin
  Result := 0;
  LUnseen := FStore.Search(FBox, TImapSearchPred.UnseenOnly);
  if Length(LUnseen) = 0 then
    Exit;
  LUids := FStore.ListUids(FBox);
  LPos := UidPosition(LUids, LUnseen[0]);
  if LPos >= 0 then
    Result := LPos + 1;
end;

function TMailImapServerSession.EffectiveIdlePollMs: Int64;
begin
  if FConfig.IdlePollMs > 0 then
    Result := FConfig.IdlePollMs
  else
    Result := MAIL_IMAP_DEFAULT_IDLE_POLL_MS;
end;

function TMailImapServerSession.EffectiveIdleTimeoutMs: Int64;
begin
  if FConfig.IdleTimeoutMs > 0 then
    Result := FConfig.IdleTimeoutMs
  else
    Result := MAIL_IMAP_DEFAULT_IDLE_TIMEOUT_MS;
end;

function TMailImapServerSession.BuildLine: string;
begin
  SetLength(Result, FLineLen);
  if FLineLen > 0 then
    Move(FLineBuf[0], Result[1], FLineLen);
end;

procedure TMailImapServerSession.RefreshDeadline;
begin
  if FState = ssClosed then
    Exit;
  if FInIdle then
  begin
    FDeadline := TDeadline.Min(FIdleEndDeadline, FIdlePollDeadline);
  end
  else if FConfig.IdleTimeoutMs > 0 then
    FDeadline := TDeadline.After(TDuration.FromMilliseconds(
      EffectiveIdleTimeoutMs))
  else
    FDeadline := TDeadline.Infinite;
end;

procedure TMailImapServerSession.NotifySink(const AEvent: TMailImapServerEvent);
begin
  if FSink <> nil then
    FSink.OnServerEvent(AEvent, FUserId);
end;

procedure TMailImapServerSession.AbortSession;
begin
  if FState = ssClosed then
    Exit;
  FState := ssClosed;
  FOutbound := nil;
  FOutHead := 0;
  FOutCount := 0;
  FOutBytes := 0;
  FHeadPos := 0;
  { 到期 deadline：构造期即中止的会话也能被 reactor 超时路径回收 }
  FDeadline := TDeadline.After(TDuration.FromMilliseconds(0));
end;

procedure TMailImapServerSession.EnqueueStr(const AValue: string);
var
  LB: TBytes;
  LTail, LCap: SizeUInt;
begin
  if FOutBytes + SizeUInt(Length(AValue)) > FConfig.OutboundQueueLimit then
  begin
    NotifySink(iiseOverflow);
    AbortSession;
    Exit;
  end;
  SetLength(LB, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], LB[0], Length(AValue));
  LCap := SizeUInt(Length(FOutbound));
  LTail := FOutHead + FOutCount;
  if LTail >= LCap then
  begin
    { 存活区搬到数组头，均摊 O(1)；随后必有空位或扩容 }
    if FOutHead > 0 then
    begin
      if FOutCount > 0 then
        Move(FOutbound[FOutHead], FOutbound[0], FOutCount * SizeOf(TBytes));
    end;
    FOutHead := 0;
    LTail := FOutCount;
    if LTail >= LCap then
      SetLength(FOutbound, LTail + 16);
    LCap := SizeUInt(Length(FOutbound));
  end;
  FOutbound[LTail] := LB;
  Inc(FOutCount);
  Inc(FOutBytes, SizeUInt(Length(LB)));
end;

procedure TMailImapServerSession.BeginFlush(const AResume: TSessState);
begin
  FResumeState := AResume;
  if FState = ssClosed then
    Exit;
  FState := ssFlushing;
end;

procedure TMailImapServerSession.Reply(const ALine: string);
begin
  EnqueueStr(ALine);
  if FState = ssClosed then
    Exit;
  if FState <> ssFlushing then
    BeginFlush(ssLine);
end;

procedure TMailImapServerSession.ResetAuthState;
begin
  FPhase := ispNotAuthenticated;
  FUserId := '';
  FBoxOpen := False;
  FBox := Default(TImapMailboxSnapshot);
end;

function TMailImapServerSession.TryRevocationGate(const ATag: string): Boolean;
var
  LSt: TImapRevocationStatus;
begin
  Result := True;
  if (FConfig.RevocationCheck = nil) or (FUserId = '') then
    Exit;
  LSt := FConfig.RevocationCheck.Check(FUserId);
  case LSt of
    irsActive:
      Exit(True);
    irsRevoked:
      begin
        ResetAuthState;
        Reply(ATag + ' NO Authentication required' + #13#10);
      end;
  else
    Reply(ATag + ' NO Temporary server error' + #13#10);
  end;
  Result := False;
end;

function TMailImapServerSession.RequireSelected(const ATag: string): Boolean;
begin
  if FPhase <> ispSelected then
  begin
    Reply(ATag + ' NO No mailbox selected' + #13#10);
    Result := False;
  end
  else
    Result := True;
end;

procedure TMailImapServerSession.StartLiteral(ALen: Int64; APlus: Boolean);
begin
  FLiteralRemain := ALen;
  FLineHasLiteral := True;
  SetLength(FLitBuf, 0);
  FLitLen := 0;
  if not APlus then
  begin
    EnqueueStr('+ Ready for literal data' + #13#10);
    BeginFlush(ssLine);   { 先送续行提示再收字节 }
  end;
end;

{ 一行终结：去结尾 CR → literal 标记分流（本行未收过才检查）→ 分发 }
procedure TMailImapServerSession.FinishLine(AHadCR: Boolean);
var
  LMarkerEnd: SizeUInt;
  LLen: Int64;
  LPlus: Boolean;
  LTag: string;
  LSp: Integer;
  LLine: string;
  LLit: TBytes;
begin
  if AHadCR and (FLineLen > 0) and (FLineBuf[FLineLen - 1] = 13) then
  begin
    Dec(FLineLen);
    FLineBuf[FLineLen] := 0;
  end;
  if (not FLineHasLiteral) and
     ImapExtractLiteralTail(BuildLine, LMarkerEnd, LLen, LPlus) then
  begin
    if LLen > FConfig.MaxLiteral then
    begin
      LLine := BuildLine;
      LSp := Pos(' ', LLine);
      if LSp > 1 then
        LTag := Copy(LLine, 1, LSp - 1)
      else
        LTag := '*';
      Reply(LTag + ' BAD Literal too large' + #13#10);
      FLiteralSkip := LLen;
      FLineLen := 0;
      Exit;
    end;
    FPendingHeader := BuildLine;
    FLineLen := 0;
    StartLiteral(LLen, LPlus);
    Exit;
  end;
  LLit := nil;
  if FLineHasLiteral then
  begin
    { literal 已收毕：派发保存的命令头行（单 literal 务实子集） }
    if FLitLen > 0 then
      LLit := Copy(FLitBuf, 0, FLitLen);
    LLine := FPendingHeader;
  end
  else
    LLine := BuildLine;
  FLineLen := 0;
  FPendingHeader := '';
  FLineHasLiteral := False;
  FLitLen := 0;
  SetLength(FLitBuf, 0);
  ProcessCommandLine(LLine, LLit);
end;

procedure TMailImapServerSession.DrainReadable;
var
  LRead: SizeUInt;
  LRes: TTcpStreamIOResult;
  B: Byte;
label
  Rescan;
begin
  if FConnRuntime = nil then
    Exit;
  while (FState = ssLine) or (FState = ssFlushing) do
  begin
    Rescan:
    while (FReadPos < FReadAvail) and (FState in [ssLine, ssFlushing]) do
    begin
      { Flushing 中只放行 literal 收集/丢弃字节（续行提示已发出，
        客户端随即推正文）；其余输入等冲刷完成后处理 }
      if (FState = ssFlushing) and (FLiteralRemain <= 0) and
         (FLiteralSkip <= 0) then
        Break;
      B := FReadBuf[FReadPos];
      Inc(FReadPos);

      if FLiteralSkip > 0 then
      begin
        Dec(FLiteralSkip);
        Continue;
      end;
      if FLiteralRemain > 0 then
      begin
        if FLitLen >= SizeUInt(Length(FLitBuf)) then
          SetLength(FLitBuf, FLitLen * 2 + 1024);
        FLitBuf[FLitLen] := B;
        Inc(FLitLen);
        Dec(FLiteralRemain);
        Continue;
      end;
      if FState <> ssLine then
        Break;

      if B = 10 then
      begin
        if FAwaitingSasl then
        begin
          HandleSaslLine(BuildLine);
          FLineLen := 0;
          if FState = ssLine then
            Continue
          else
            Break;
        end;
        if FInIdle then
        begin
          if (FLineLen > 0) and (FLineBuf[FLineLen - 1] = 13) then
            Dec(FLineLen);
          FinishIdle(FTagInIdle, BuildLine);
          FLineLen := 0;
          if FState = ssLine then
            Continue
          else
            Break;
        end;
        FinishLine(FLineLen > 0);
        if FState = ssFlushing then
          Break;
        Continue;
      end
      else
      begin
        if FLineLen >= FConfig.LineLimit then
        begin
          { framing 已不可信：untagged BAD 后断开 }
          EnqueueStr('* BAD Command line too long' + #13#10);
          FLineLen := 0;
          BeginFlush(ssClosed);
          Break;
        end;
        if FLineLen >= SizeUInt(Length(FLineBuf)) then
          SetLength(FLineBuf, FLineLen * 2 + 256);
        FLineBuf[FLineLen] := B;
        Inc(FLineLen);
      end;
    end;

    if (FState = ssFlushing) and (FLiteralRemain <= 0) and
       (FLiteralSkip <= 0) then
      Break;   { 等可写事件 }
    if not (FState in [ssLine, ssFlushing]) then
      Break;
    { 缓冲未消费完（冲刷断点保留的字节）时前移压实，绝不丢弃；
      仅在已耗尽时归零。literal 正文与续行提示同批到达的场景
      （普通 literal 形态先转 Flushing 再收字节）依赖本纪律 }
    if FReadPos < FReadAvail then
    begin
      if FReadPos > 0 then
      begin
        Move(FReadBuf[FReadPos], FReadBuf[0], FReadAvail - FReadPos);
        Dec(FReadAvail, FReadPos);
        FReadPos := 0;
      end;
    end
    else
    begin
      FReadPos := 0;
      FReadAvail := 0;
    end;
    LRes := FConnRuntime.TryRead(FReadBuf[FReadAvail],
      SizeOf(FReadBuf) - SizeUInt(FReadAvail), LRead);
    case LRes of
      tsiorOk:
        begin
          if LRead = 0 then
          begin
            FState := ssClosed;
            Exit;
          end;
          Inc(FReadAvail, LRead);
          goto Rescan;
        end;
      tsiorWouldBlock:
        Break;
      tsiorClosed, tsiorTimeout:
        begin
          FState := ssClosed;
          Break;
        end;
    end;
  end;
end;

procedure TMailImapServerSession.FlushOutbound;
var
  LHead: TBytes;
  LWritten: SizeUInt;
  LRes: TTcpStreamIOResult;
begin
  if FConnRuntime = nil then
    Exit;
  while (FOutCount > 0) and (FState = ssFlushing) do
  begin
    LHead := FOutbound[FOutHead];
    while FHeadPos < SizeUInt(Length(LHead)) do
    begin
      LRes := FConnRuntime.TryWrite(LHead[FHeadPos],
        SizeUInt(Length(LHead)) - FHeadPos, LWritten);
      case LRes of
        tsiorOk:
          begin
            if LWritten = 0 then
            begin
              FState := ssClosed;
              Exit;
            end;
            Inc(FHeadPos, LWritten);
          end;
        tsiorWouldBlock:
          Exit;
      else
        FState := ssClosed;
        Exit;
      end;
    end;
    Dec(FOutBytes, SizeUInt(Length(LHead)));
    FOutbound[FOutHead] := nil;
    Inc(FOutHead);
    Dec(FOutCount);
    FHeadPos := 0;
  end;
  if FOutCount = 0 then
  begin
    FOutbound := nil;
    FOutHead := 0;
    if FState = ssFlushing then
    begin
      FState := FResumeState;
      RefreshDeadline;
      if FState = ssClosed then
        Exit;
      if FReadAvail > FReadPos then
      begin
        { 冲刷完成缓冲仍有字节（如 literal 正文随续行提示同批到达）：
          立即续处理，不等可读事件——内核可能已无新数据 }
        DrainReadable;
      end;
    end;
  end;
end;

{ ── 命令分发 ────────────────────────────────────────────────── }

procedure TMailImapServerSession.ProcessCommandLine(const ALine: string;
  const ALiteral: TBytes);
var
  LTag, LVerb, LArgs, LSub: string;
begin
  try
    if Trim(ALine) = '' then
      Exit;
    if not ImapParseRequestLine(ALine, LTag, LVerb, LArgs) then
    begin
      Reply('* BAD Invalid command' + #13#10);
      Exit;
    end;
    FTagPending := LTag;

    { 吊销门控：已认证会话每命令前查（LOGOUT/CAPABILITY 免检：
      登出不需活跃态，能力查询无害） }
    if (FPhase <> ispNotAuthenticated) and (LVerb <> 'LOGOUT') and
       (LVerb <> 'CAPABILITY') then
      if not TryRevocationGate(LTag) then
        Exit;

    if LVerb = 'CAPABILITY' then
      CmdCapability(LTag)
    else if LVerb = 'NOOP' then
      CmdNoop(LTag)
    else if LVerb = 'LOGOUT' then
      CmdLogout(LTag)
    else if LVerb = 'STARTTLS' then
      CmdStartTls(LTag)
    else if LVerb = 'LOGIN' then
      CmdLogin(LTag, LArgs)
    else if LVerb = 'AUTHENTICATE' then
      CmdAuthenticate(LTag, LArgs)
    else if (LVerb = 'LIST') or (LVerb = 'LSUB') then
    begin
      if FPhase = ispNotAuthenticated then
        Reply(LTag + ' NO Not authenticated' + #13#10)
      else
        CmdListLike(LTag, LVerb);
    end
    else if (LVerb = 'SELECT') or (LVerb = 'EXAMINE') then
    begin
      if FPhase = ispNotAuthenticated then
        Reply(LTag + ' NO Not authenticated' + #13#10)
      else
        CmdSelectExamine(LTag, LVerb, LArgs);
    end
    else if LVerb = 'STATUS' then
    begin
      if FPhase = ispNotAuthenticated then
        Reply(LTag + ' NO Not authenticated' + #13#10)
      else
        CmdStatus(LTag, LArgs);
    end
    else if LVerb = 'APPEND' then
    begin
      if FPhase = ispNotAuthenticated then
        Reply(LTag + ' NO Not authenticated' + #13#10)
      else
        CmdAppend(LTag, LArgs, ALiteral);
    end
    else if LVerb = 'CLOSE' then
    begin
      if FPhase = ispNotAuthenticated then
        Reply(LTag + ' NO Not authenticated' + #13#10)
      else
        CmdClose(LTag);
    end
    else if LVerb = 'IDLE' then
    begin
      if not RequireSelected(LTag) then
        Exit;
      EnterIdle(LTag);
    end
    else if LVerb = 'FETCH' then
    begin
      if RequireSelected(LTag) then
        CmdFetch(LTag, LArgs, False);
    end
    else if LVerb = 'SEARCH' then
    begin
      if RequireSelected(LTag) then
        CmdSearch(LTag, LArgs);
    end
    else if LVerb = 'STORE' then
    begin
      if RequireSelected(LTag) then
        CmdStore(LTag, LArgs, False);
    end
    else if LVerb = 'COPY' then
    begin
      if RequireSelected(LTag) then
        CmdCopy(LTag, LArgs, False);
    end
    else if LVerb = 'UID' then
    begin
      ImapSplitVerbToken(LArgs, LSub);
      if LSub = 'FETCH' then
      begin
        if RequireSelected(LTag) then
          CmdFetch(LTag, LArgs, True);
      end
      else if LSub = 'SEARCH' then
      begin
        if RequireSelected(LTag) then
          CmdSearch(LTag, LArgs);
      end
      else if LSub = 'STORE' then
      begin
        if RequireSelected(LTag) then
          CmdStore(LTag, LArgs, True);
      end
      else if LSub = 'COPY' then
      begin
        if RequireSelected(LTag) then
          CmdCopy(LTag, LArgs, True);
      end
      else
        Reply(LTag + ' BAD Unknown UID command' + #13#10);
    end
    else
      Reply(LTag + ' BAD Unknown command' + #13#10);
  except
    { 协议层吞掉一切异常转临时错误（fail-closed），绝不带崩 reactor；
      EImapTempError 与意外异常同文案（原版 imap_temp_error 单一形态） }
    on E: Exception do
      Reply(FTagPending + ' NO Temporary server error' + #13#10);
  end;
end;

{ ── 各命令处理器 ────────────────────────────────────────────── }

procedure TMailImapServerSession.CmdCapability(const ATag: string);
begin
  Reply('* CAPABILITY ' +
    ImapCapabilityString(FConfig.TlsAvailable, FConfig.TlsActive) +
    #13#10 + ATag + ' OK CAPABILITY completed' + #13#10);
end;

procedure TMailImapServerSession.CmdNoop(const ATag: string);
begin
  Reply(ATag + ' OK NOOP completed' + #13#10);
end;

procedure TMailImapServerSession.CmdLogout(const ATag: string);
begin
  EnqueueStr('* BYE Logging out' + #13#10 + ATag +
    ' OK LOGOUT completed' + #13#10);
  NotifySink(iiseLogout);
  BeginFlush(ssClosed);
end;

procedure TMailImapServerSession.CmdStartTls(const ATag: string);
begin
  if FConfig.TlsActive then
    Reply(ATag + ' BAD TLS already active' + #13#10)
  else if not FConfig.TlsAvailable then
    Reply(ATag + ' BAD STARTTLS unavailable' + #13#10)
  else if FPhase <> ispNotAuthenticated then
    Reply(ATag + ' BAD STARTTLS not permitted in this state' + #13#10)
  else
  begin
    { 本批无 TLS 升级缝：按原版文案应答后关闭连接（握手属 tls 批次，
      CONTRACT §限制表披露）。默认配置走 unavailable 分支不会到达此处。 }
    Reply(ATag + ' OK Begin TLS negotiation now' + #13#10);
    FResumeState := ssClosed;
    FState := ssFlushing;
  end;
end;

procedure TMailImapServerSession.VerifyCredentials(const ATag, AUser,
  APass: string);
var
  LUid: string;
  LRes: TImapAuthResult;
begin
  if FConfig.LoginCheck = nil then
    LRes := iarUnavailable
  else
    LRes := FConfig.LoginCheck.Verify(AUser, APass, LUid);
  case LRes of
    iarOk:
      begin
        ResetAuthState;
        FPhase := ispAuthenticated;
        FUserId := LUid;
        NotifySink(iiseLogin);
        Reply(ATag + ' OK LOGIN completed' + #13#10);
      end;
    iarInvalid:
      Reply(ATag + ' NO Authentication failed' + #13#10);
  else
    Reply(ATag + ' NO Authentication temporarily unavailable' + #13#10);
  end;
end;

procedure TMailImapServerSession.CmdLogin(const ATag, AArgs: string);
var
  LUser, LPass, LRest: string;
begin
  if not ImapLoginAllowed(FConfig.TlsAvailable, FConfig.TlsActive) then
  begin
    Reply(ATag + ' NO LOGIN disabled until STARTTLS' + #13#10);
    Exit;
  end;
  LUser := ImapUnquoteArg(ImapFirstAtom(AArgs, LRest));
  LPass := ImapUnquoteArg(TrimLeft(LRest));
  if (LUser = '') or (LPass = '') then
  begin
    Reply(ATag + ' BAD LOGIN requires username and password' + #13#10);
    Exit;
  end;
  VerifyCredentials(ATag, LUser, LPass);
end;

procedure TMailImapServerSession.CmdAuthenticate(const ATag, AArgs: string);
var
  LMech, LInitial, LArgsCopy: string;
  LDecoded: TBytes;
  I, LNul1, LNul2: Integer;
  LAuthcid, LPasswd: string;
begin
  LArgsCopy := AArgs;
  ImapSplitVerbToken(LArgsCopy, LMech);
  if LMech <> 'PLAIN' then
  begin
    Reply(ATag + ' BAD Unsupported authentication mechanism' + #13#10);
    Exit;
  end;
  LInitial := Trim(LArgsCopy);
  if LInitial <> '' then
  begin
    { SASL-IR：base64 解码 → authzid NUL authcid NUL passwd }
    try
      LDecoded := Base64Decode(LInitial);
    except
      Reply(ATag + ' BAD Invalid base64 in initial response' + #13#10);
      Exit;
    end;
    LNul1 := -1;
    LNul2 := -1;
    for I := 0 to Length(LDecoded) - 1 do
      if LDecoded[I] = 0 then
      begin
        if LNul1 < 0 then
          LNul1 := I
        else if LNul2 < 0 then
        begin
          LNul2 := I;
          Break;
        end;
      end;
    if (LNul1 < 0) or (LNul2 < 0) or (LNul2 <= LNul1 + 1) then
    begin
      Reply(ATag + ' NO Authentication failed' + #13#10);
      Exit;
    end;
    SetLength(LAuthcid, LNul2 - LNul1 - 1);
    if LNul2 - LNul1 - 1 > 0 then
      Move(LDecoded[LNul1 + 1], LAuthcid[1], LNul2 - LNul1 - 1);
    SetLength(LPasswd, Length(LDecoded) - LNul2 - 1);
    if Length(LDecoded) - LNul2 - 1 > 0 then
      Move(LDecoded[LNul2 + 1], LPasswd[1], Length(LDecoded) - LNul2 - 1);
    VerifyCredentials(ATag, LAuthcid, LPasswd);
    Exit;
  end;
  { 无初始应答：挑战一行 }
  FAwaitingSasl := True;
  FTagPending := ATag;
  EnqueueStr('+ ' + #13#10);
  BeginFlush(ssLine);
end;

procedure TMailImapServerSession.HandleSaslLine(const ALine: string);
var
  LB64, LAuthcid, LPasswd: string;
  LDecoded: TBytes;
  I, LNul1, LNul2: Integer;
begin
  FAwaitingSasl := False;
  LB64 := Trim(ALine);
  if LB64 = '*' then
  begin
    Reply(FTagPending + ' BAD Authentication cancelled' + #13#10);
    Exit;
  end;
  if LB64 = '=' then
    LB64 := '';
  try
    LDecoded := Base64Decode(LB64);
  except
    Reply(FTagPending + ' BAD Invalid base64 response' + #13#10);
    Exit;
  end;
  LNul1 := -1;
  LNul2 := -1;
  for I := 0 to Length(LDecoded) - 1 do
    if LDecoded[I] = 0 then
    begin
      if LNul1 < 0 then
        LNul1 := I
      else if LNul2 < 0 then
      begin
        LNul2 := I;
        Break;
      end;
    end;
  if (LNul1 < 0) or (LNul2 < 0) or (LNul2 <= LNul1 + 1) then
  begin
    Reply(FTagPending + ' NO Authentication failed' + #13#10);
    Exit;
  end;
  SetLength(LAuthcid, LNul2 - LNul1 - 1);
  if LNul2 - LNul1 - 1 > 0 then
    Move(LDecoded[LNul1 + 1], LAuthcid[1], LNul2 - LNul1 - 1);
  SetLength(LPasswd, Length(LDecoded) - LNul2 - 1);
  if Length(LDecoded) - LNul2 - 1 > 0 then
    Move(LDecoded[LNul2 + 1], LPasswd[1], Length(LDecoded) - LNul2 - 1);
  VerifyCredentials(FTagPending, LAuthcid, LPasswd);
end;

procedure TMailImapServerSession.CmdListLike(const ATag, AVerb: string);
var
  LNames: TStringArray;
  I: Integer;
  LB: TBufStringBuilder;
begin
  { 原版 LIST/LSUB 同一处理器且 tagged 行恒为 LIST completed（怪癖保持） }
  LNames := FStore.ListMailboxes(FUserId);
  LB.Init(256 + Length(LNames) * 48);
  try
    LB.AppendStr('* LIST (\HasNoChildren) "/" "INBOX"' + #13#10);
    for I := 0 to Length(LNames) - 1 do
    begin
      LB.AppendStr('* LIST (\HasNoChildren) "/" "');
      LB.AppendStr(ImapEscapeQuoted(LNames[I]));
      LB.AppendStr('"' + #13#10);
    end;
    LB.AppendStr(ATag + ' OK LIST completed' + #13#10);
    Reply(LB.ToString);
  finally
    LB.Done;
  end;
end;

procedure TMailImapServerSession.CmdSelectExamine(const ATag, AVerb,
  AArgs: string);
var
  LName: string;
  LBox: TImapMailboxSnapshot;
  LB: TBufStringBuilder;
  LFirstUnseen: Int64;
begin
  LName := ImapUnquoteArg(Trim(AArgs));
  if not FStore.OpenMailbox(FUserId, LName, LBox) then
  begin
    Reply(ATag + ' NO Mailbox not found' + #13#10);
    Exit;
  end;
  LBox.ReadOnly := LBox.ReadOnly or (AVerb = 'EXAMINE');
  FBox := LBox;
  FBoxOpen := True;
  FPhase := ispSelected;
  LB.Init(512);
  try
    LB.AppendStr('* ');
    LB.AppendInt(FBox.Exists);
    LB.AppendStr(' EXISTS' + #13#10);
    LB.AppendStr('* 0 RECENT' + #13#10);
    LFirstUnseen := FirstUnseenOrdinal;
    if LFirstUnseen > 0 then
    begin
      LB.AppendStr('* OK [UNSEEN ');
      LB.AppendInt(LFirstUnseen);
      LB.AppendStr(']' + #13#10);
    end;
    LB.AppendStr('* OK [UIDVALIDITY ');
    LB.AppendInt(Int64(FBox.UidValidity));
    LB.AppendStr(']' + #13#10);
    LB.AppendStr('* OK [UIDNEXT ');
    LB.AppendInt(FBox.UidNext);
    LB.AppendStr(']' + #13#10);
    LB.AppendStr('* FLAGS (' + IMAP_FLAGS_LINE + ')' + #13#10);
    LB.AppendStr('* OK [PERMANENTFLAGS (' + IMAP_FLAGS_LINE + ')]' + #13#10);
    if FBox.ReadOnly then
      LB.AppendStr(ATag + ' OK [READ-ONLY] ')
    else
      LB.AppendStr(ATag + ' OK [READ-WRITE] ');
    { 原版 verb 硬编码 SELECT（EXAMINE 同文案，怪癖保持） }
    LB.AppendStr('SELECT completed' + #13#10);
    Reply(LB.ToString);
  finally
    LB.Done;
  end;
end;

procedure TMailImapServerSession.CmdStatus(const ATag, AArgs: string);
var
  LName, LDummy: string;
  LBox: TImapMailboxSnapshot;
  LB: TBufStringBuilder;
begin
  { items 参数原版整体忽略，固定回报 MESSAGES/UNSEEN/RECENT 三元 }
  LName := ImapUnquoteArg(Trim(ImapFirstAtom(AArgs, LDummy)));
  if not FStore.OpenMailbox(FUserId, LName, LBox) then
  begin
    Reply(ATag + ' NO Mailbox not found' + #13#10);
    Exit;
  end;
  LB.Init(192);
  try
    LB.AppendStr('* STATUS "' + ImapEscapeQuoted(LBox.Name) +
      '" (MESSAGES ');
    LB.AppendInt(LBox.Exists);
    LB.AppendStr(' UNSEEN ');
    LB.AppendInt(LBox.Unseen);
    LB.AppendStr(' RECENT 0)' + #13#10);
    LB.AppendStr(ATag + ' OK STATUS completed' + #13#10);
    Reply(LB.ToString);
  finally
    LB.Done;
  end;
end;

procedure TMailImapServerSession.CmdAppend(const ATag, AArgs: string;
  const ALiteral: TBytes);
var
  LName, LRest, LParen, LDateTok, LTmpArgs: string;
  LMarkerEnd: SizeUInt;
  LLen: Int64;
  LPlus: Boolean;
  LFlagSeen: Boolean;
  LNewUid: Int64;
begin
  LName := ImapFirstAtom(AArgs, LRest);
  if LName = '' then
  begin
    Reply(ATag + ' BAD Invalid APPEND arguments' + #13#10);
    Exit;
  end;
  LFlagSeen := False;
  LDateTok := '';
  LTmpArgs := LRest;   { out 参数不得与源同变量（调用点先行清空） }
  if ImapTryParenSegment(LTmpArgs, LParen, LRest) then
    LFlagSeen := ImapContainsCI(LParen, '\Seen');
  LDateTok := Trim(TrimLeft(LRest));
  { 日期原子若存在则剥除（存储侧透传由内容决定，core 不解析日期） }
  if (LDateTok <> '') and (LDateTok[1] <> '{') then
    LDateTok := ImapFirstAtom(LDateTok, LRest)
  else
    LDateTok := '';
  if ALiteral = nil then
  begin
    { 无 literal 正文到达：参数畸形（标记缺失） }
    if not ImapExtractLiteralTail(AArgs, LMarkerEnd, LLen, LPlus) then
      Reply(ATag + ' BAD Invalid APPEND arguments' + #13#10)
    else
      Reply(ATag + ' NO Temporary server error' + #13#10);
    Exit;
  end;
  if not FStore.Append(FUserId, ImapUnquoteArg(LName), ALiteral, LFlagSeen,
    LDateTok, LNewUid) then
  begin
    Reply(ATag + ' NO Mailbox not found' + #13#10);
    Exit;
  end;
  Reply(ATag + ' OK APPEND completed' + #13#10);
end;

procedure TMailImapServerSession.CmdClose(const ATag: string);
begin
  FBoxOpen := False;
  FPhase := ispAuthenticated;
  Reply(ATag + ' OK CLOSE completed' + #13#10);
end;

procedure TMailImapServerSession.EnterIdle(const ATag: string);
begin
  FInIdle := True;
  FTagInIdle := ATag;
  FIdleBaseVer := FStore.ChangeVersion(FBox);
  FIdlePollDeadline := TDeadline.After(
    TDuration.FromMilliseconds(EffectiveIdlePollMs));
  FIdleEndDeadline := TDeadline.After(
    TDuration.FromMilliseconds(EffectiveIdleTimeoutMs));
  EnqueueStr('+ idling' + #13#10);
  BeginFlush(ssLine);
  RefreshDeadline;
end;

procedure TMailImapServerSession.FinishIdle(const ATag, AFinalLine: string);
begin
  FInIdle := False;
  if ImapAsciiUpper(Trim(AFinalLine)) = 'DONE' then
    Reply(ATag + ' OK IDLE completed' + #13#10)
  else
  begin
    Reply(ATag + ' BAD Expected DONE' + #13#10);
    RefreshDeadline;
  end;
end;

procedure TMailImapServerSession.PollIdleTick;
var
  LVer: Int64;
  LBox: TImapMailboxSnapshot;
begin
  { 吊销优先（对齐原版 IDLE 内 BYE Session revoked 分支） }
  if (FConfig.RevocationCheck <> nil) and
     (FConfig.RevocationCheck.Check(FUserId) <> irsActive) then
  begin
    EnqueueStr('* BYE Session revoked' + #13#10);
    FInIdle := False;
    BeginFlush(ssClosed);
    Exit;
  end;
  LVer := FStore.ChangeVersion(FBox);
  if LVer <> FIdleBaseVer then
  begin
    FIdleBaseVer := LVer;
    if FStore.OpenMailbox(FUserId, FBox.Name, LBox) then
    begin
      FBox.Exists := LBox.Exists;
      FBox.Unseen := LBox.Unseen;
      FBox.UidNext := LBox.UidNext;
    end;
    EnqueueStr('* ' + IntToStr(FBox.Exists) + ' EXISTS' + #13#10);
    BeginFlush(ssLine);   { 回到 IDLE 等待（Resume=ssLine 且 FInIdle 仍真） }
  end;
end;

procedure TMailImapServerSession.CmdFetch(const ATag, AArgs: string;
  AUidMode: Boolean);
var
  LSetPart, LItemsRaw, LItemsUp, LRest: string;
  LUids, LOurUids: TImapUidArray;
  LRows: TImapMailRowArray;
  LB: TBufStringBuilder;
  LI, LJ: Integer;
  LWantsUid, LWantsFlags, LWantsEnv, LWantsSize, LWantsDate: Boolean;
  LWantsBody, LPeek: Boolean;
  LAnyKnown: Boolean;
  LContent: TBytes;
  LSeenUids: TImapUidArray;
begin
  LSetPart := ImapFirstAtom(AArgs, LRest);
  LItemsRaw := TrimLeft(LRest);
  if (LSetPart = '') or (LItemsRaw = '') then
  begin
    Reply(ATag + ' BAD Invalid FETCH arguments' + #13#10);
    Exit;
  end;
  LUids := FStore.ListUids(FBox);
  if not ImapResolveSequenceSet(LSetPart, LUids, AUidMode, LOurUids) then
  begin
    Reply(ATag + ' BAD Invalid FETCH sequence-set' + #13#10);
    Exit;
  end;
  { FETCH 项词法：token 化精确匹配（超越点：原版子串包含误判
    BODY.PEEK 为 BODY——此处 PEEK 不置 Seen）。括号展平为空格。 }
  LItemsUp := ' ' + ImapAsciiUpper(ImapFlattenItems(LItemsRaw)) + ' ';
  LWantsUid := Pos(' UID ', LItemsUp) > 0;
  LWantsFlags := Pos(' FLAGS ', LItemsUp) > 0;
  LWantsEnv := Pos(' ENVELOPE ', LItemsUp) > 0;
  LWantsSize := Pos(' RFC822.SIZE ', LItemsUp) > 0;
  LWantsDate := Pos(' INTERNALDATE ', LItemsUp) > 0;
  LPeek := Pos(' BODY.PEEK[] ', LItemsUp) > 0;
  LWantsBody := (Pos(' BODY[] ', LItemsUp) > 0) or
    (Pos(' RFC822 ', LItemsUp) > 0);
  LAnyKnown := LWantsUid or LWantsFlags or LWantsEnv or LWantsSize or
    LWantsDate or LPeek or LWantsBody;
  if (not LAnyKnown) and (Pos(' RFC822.HEADER ', LItemsUp) > 0) then
  begin
    { 头部-only 视作 body 形态的只读变体（不置旗标） }
    LPeek := True;
    LWantsBody := True;
    LAnyKnown := True;
  end;
  if not LAnyKnown then
  begin
    { 全未知项：原版兜底 FLAGS(+UID uid 模式) }
    LWantsFlags := True;
    LWantsUid := AUidMode;
  end;
  if LWantsBody and (not LPeek) and (not FBox.ReadOnly) then
  begin
    { BODY[] 非 PEEK 置 \Seen（原版行为）；先收集后置，响应内 FLAGS
      保持取行时旧值（原版同序） }
    SetLength(LSeenUids, 0);
  end
  else
    SetLength(LSeenUids, 0);

  LRows := FStore.LoadRows(FBox, LOurUids);
  { 序号以本命令 ListUids 位置为准(1 基)——SPI 契约「会话按下标回填」
    的会话侧兑现; 存储提供的 Seq 值不信任(首批真实消费方暴露:
    存储侧 seq 语义各异, 全局自增列非邮箱内序号)。 }
  for LI := 0 to Length(LRows) - 1 do
  begin
    LRows[LI].Seq := UidPosition(LUids, LRows[LI].Uid) + 1;
  end;
  LB.Init(512 + Length(LRows) * 96);
  try
    for LI := 0 to Length(LRows) - 1 do
    begin
      LB.AppendStr('* ');
      LB.AppendInt(LRows[LI].Seq);
      LB.AppendStr(' FETCH (');
      LJ := 0;
      if LWantsUid or AUidMode then
      begin
        LB.AppendStr('UID ');
        LB.AppendInt(LRows[LI].Uid);
        Inc(LJ);
      end;
      if LWantsFlags then
      begin
        if LJ > 0 then LB.AppendChar(' ');
        if LRows[LI].Seen then
          LB.AppendStr('FLAGS (\Seen)')
        else
          LB.AppendStr('FLAGS ()');
        Inc(LJ);
      end;
      if LWantsEnv then
      begin
        if LJ > 0 then LB.AppendChar(' ');
        LB.AppendStr('ENVELOPE ("');
        LB.AppendStr(LRows[LI].InternalDate);
        LB.AppendStr('" "');
        if LRows[LI].Subject = '' then
          LB.AppendStr('(no subject)')
        else
          LB.AppendStr(ImapEscapeQuoted(LRows[LI].Subject));
        LB.AppendStr('" ');
        AppendEnvelopeAddr(LB, LRows[LI].FromAddr);
        LB.AppendChar(' ');
        AppendEnvelopeAddr(LB, LRows[LI].ToAddr);
        LB.AppendStr(' NIL NIL NIL NIL)');
        Inc(LJ);
      end;
      if LWantsSize then
      begin
        if LJ > 0 then LB.AppendChar(' ');
        LB.AppendStr('RFC822.SIZE ');
        LB.AppendInt(LRows[LI].Size);
        Inc(LJ);
      end;
      if LWantsDate then
      begin
        if LJ > 0 then LB.AppendChar(' ');
        LB.AppendStr('INTERNALDATE "' + LRows[LI].InternalDate + '"');
        Inc(LJ);
      end;
      if LWantsBody or LPeek then
      begin
        if LJ > 0 then LB.AppendChar(' ');
        LContent := FStore.LoadContent(FBox, LRows[LI].Uid);
        if LPeek then
          LB.AppendStr('BODY.PEEK[] {')
        else
          LB.AppendStr('BODY[] {');
        LB.AppendInt(SizeUInt(Length(LContent)));
        LB.AppendStr('}' + #13#10);
        LB.AppendBytes(PAnsiChar(LContent), SizeUInt(Length(LContent)));
        if (not LPeek) and (not FBox.ReadOnly) then
        begin
          SetLength(LSeenUids, Length(LSeenUids) + 1);
          LSeenUids[High(LSeenUids)] := LRows[LI].Uid;
        end;
        Inc(LJ);
      end;
      if LJ = 0 then
      begin
        LB.AppendStr('FLAGS ()');
      end;
      LB.AppendStr(')' + #13#10);
    end;
    LB.AppendStr(ATag + ' OK FETCH completed' + #13#10);
    Reply(LB.ToString);
  finally
    LB.Done;
  end;
  for LI := 0 to Length(LSeenUids) - 1 do
    FStore.SetSeen(FBox, LSeenUids[LI], True);
end;

procedure TMailImapServerSession.CmdSearch(const ATag, AArgs: string);
var
  LPred: TImapSearchPred;
  LUids: TImapUidArray;
  LB: TBufStringBuilder;
  LI: Integer;
begin
  { 原版仅 UNSEEN 键（contains 判定），其余键忽略；uid_mode 不影响输出 }
  if ImapContainsCI(AArgs, 'UNSEEN') then
    LPred := TImapSearchPred.UnseenOnly
  else
  begin
    LPred := Default(TImapSearchPred);
  end;
  LUids := FStore.Search(FBox, LPred);
  LB.Init(64 + Length(LUids) * 12);
  try
    LB.AppendStr('* SEARCH');
    for LI := 0 to Length(LUids) - 1 do
    begin
      LB.AppendChar(' ');
      LB.AppendInt(LUids[LI]);
    end;
    LB.AppendStr(#13#10 + ATag + ' OK SEARCH completed' + #13#10);
    Reply(LB.ToString);
  finally
    LB.Done;
  end;
end;

procedure TMailImapServerSession.CmdStore(const ATag, AArgs: string;
  AUidMode: Boolean);
var
  LSetPart, LAction, LFlags, LRest, LTmp: string;
  LUids, LOurUids: TImapUidArray;
  LSeq: Int64;
  LNeg: Boolean;
  LX, LY: Integer;
begin
  if FBox.ReadOnly then
  begin
    Reply(ATag + ' NO Mailbox is read-only' + #13#10);
    Exit;
  end;
  { 注意 out 参数与源不得同变量别名（FPC 调用点先行清空 out 管理类型） }
  LSetPart := ImapFirstAtom(AArgs, LRest);
  LTmp := TrimLeft(LRest);
  LAction := ImapAsciiUpper(ImapFirstAtom(LTmp, LRest));
  LFlags := ImapAsciiUpper(TrimLeft(LRest));
  if (LSetPart = '') or (LAction = '') or (LFlags = '') then
  begin
    Reply(ATag + ' BAD Invalid STORE arguments' + #13#10);
    Exit;
  end;
  if not ImapContainsCI(LFlags, '\Seen') then
  begin
    { 仅支持 \Seen 旗标（原版口径）：其余为 no-op 成功 }
    Reply(ATag + ' OK STORE completed (no-op)' + #13#10);
    Exit;
  end;
  { 原版仅单序号（range 解析拒绝） }
  LSeq := 0;
  if (LSetPart = '') or (Length(LSetPart) > 18) then
  begin
    Reply(ATag + ' BAD Invalid STORE sequence-set' + #13#10);
    Exit;
  end;
  for LX := 1 to Length(LSetPart) do
    if not IsDigit(Byte(LSetPart[LX])) then
    begin
      Reply(ATag + ' BAD Invalid STORE sequence-set' + #13#10);
      Exit;
    end;
  LSeq := StrToInt64Def(LSetPart, 0);
  if LSeq < 1 then
  begin
    Reply(ATag + ' BAD Invalid STORE sequence-set' + #13#10);
    Exit;
  end;
  LNeg := Pos('-FLAGS', LAction) > 0;
  if (Pos('+FLAGS', LAction) = 0) and (not LNeg) then
  begin
    Reply(ATag + ' BAD Invalid STORE arguments' + #13#10);
    Exit;
  end;
  LUids := FStore.ListUids(FBox);
  if Pos(':', LSetPart) > 0 then
  begin
    Reply(ATag + ' BAD Invalid STORE sequence-set' + #13#10);
    Exit;
  end;
  if AUidMode then
  begin
    if not ImapResolveSequenceSet(LSetPart, LUids, True, LOurUids) then
    begin
      Reply(ATag + ' BAD Invalid STORE sequence-set' + #13#10);
      Exit;
    end;
  end
  else
  begin
    if LSeq > Length(LUids) then
    begin
      { 越界：原版空成功 }
      Reply(ATag + ' OK STORE completed' + #13#10);
      Exit;
    end;
    SetLength(LOurUids, 1);
    LOurUids[0] := LUids[LSeq - 1];
  end;
  for LY := 0 to Length(LOurUids) - 1 do
    FStore.SetSeen(FBox, LOurUids[LY], not LNeg);
  Reply(ATag + ' OK STORE completed' + #13#10);
end;

procedure TMailImapServerSession.CmdCopy(const ATag, AArgs: string;
  AUidMode: Boolean);
var
  LSetPart, LTarget, LRest: string;
  LUids, LOurUids: TImapUidArray;
  LTargetBox: TImapMailboxSnapshot;
begin
  LSetPart := ImapFirstAtom(AArgs, LRest);
  LTarget := ImapUnquoteArg(TrimLeft(LRest));
  if (LSetPart = '') or (LTarget = '') then
  begin
    Reply(ATag + ' BAD Invalid COPY arguments' + #13#10);
    Exit;
  end;
  if not FStore.OpenMailbox(FUserId, LTarget, LTargetBox) then
  begin
    Reply(ATag + ' NO Mailbox not found' + #13#10);
    Exit;
  end;
  LUids := FStore.ListUids(FBox);
  if not ImapResolveSequenceSet(LSetPart, LUids, AUidMode, LOurUids) then
  begin
    Reply(ATag + ' BAD Invalid COPY sequence-set' + #13#10);
    Exit;
  end;
  if not FStore.CopyTo(FBox, LOurUids, LTargetBox.Name) then
  begin
    Reply(ATag + ' NO Mailbox not found' + #13#10);
    Exit;
  end;
  Reply(ATag + ' OK COPY completed' + #13#10);
end;

{ ── poll-driven 会话契约 ────────────────────────────────────── }

function TMailImapServerSession.Run: TTcpServerConnOwnership;
begin
  Result := tscoServer;
  raise ENotSupportedError.Create(
    'imap server session requires an evented tcp server backend');
end;

function TMailImapServerSession.PollEvents: TPlatformPollEvents;
begin
  case FState of
    ssFlushing: Result := [peWritable];
    ssClosed: Result := [];
  else
    Result := [peReadable];
  end;
end;

function TMailImapServerSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;
  ANextEvents := [];
  if FState = ssClosed then
    Exit(tsprDone);

  if AEvents <> [] then
  begin
    if FState in [ssLine, ssFlushing] then
      DrainReadable;
    if FState = ssFlushing then
      FlushOutbound;
  end;

  if FState = ssClosed then
    Exit(tsprDone);

  { 空事件集 = 截止唤醒 }
  if AEvents = [] then
  begin
    if FInIdle and FIdleEndDeadline.IsExpired then
    begin
      NotifySink(iiseTimeout);
      EnqueueStr('* BYE Idle timeout' + #13#10);
      FInIdle := False;
      BeginFlush(ssClosed);
    end
    else if FInIdle and FIdlePollDeadline.IsExpired then
    begin
      FIdlePollDeadline := TDeadline.After(
        TDuration.FromMilliseconds(EffectiveIdlePollMs));
      PollIdleTick;
    end
    else if (not FInIdle) and FDeadline.IsExpired and
            (FConfig.IdleTimeoutMs > 0) and (FState in [ssLine]) then
    begin
      NotifySink(iiseTimeout);
      FState := ssClosed;
      Exit(tsprDone);
    end;
  end;

  if FState = ssClosed then
    Exit(tsprDone);

  case FState of
    ssFlushing:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    RefreshDeadline;
    ANextEvents := [peReadable];
    Exit(tsprWait);
  end;
end;

function TMailImapServerSession.WakeDeadline: TDeadline;
begin
  Result := FDeadline;
end;

end.
