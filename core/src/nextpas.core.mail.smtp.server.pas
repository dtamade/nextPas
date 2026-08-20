unit nextpas.core.mail.smtp.server;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail SMTP 服务器会话（L3，事件驱动）。
 *
 * 与 nextpas.core.mail.smtp 客户端共享线上协议词汇（TSmtpReply、ESmtp*、
 * 行分隔），但以服务器角色实现 RFC 5321 会话状态机，并把 I/O 接入
 * net.server 的 poll-driven 会话契约（epoll/kqueue/iocp readiness 路径），
 * 对齐 TNetWsFrameSession 的事件驱动模型——不提供 per-connection-thread
 * 阻塞降级。
 *
 * 一条连接一个会话，由事件驱动后端逐事件推进：可读喂行解析，可写冲刷出站
 * 回复队列；读空闲超时经 WakeDeadline 由 reactor 唤醒。出站回复队列有界
 * （背压），超限即失败关闭。
 *
 * 命令集（RFC 5321 务实子集）：HELO/EHLO（能力列表）、MAIL/RCPT/DATA
 * （点转义、大小上限）、RSET/NOOP/QUIT/HELP/VRFY，未知命令 500，
 * STARTTLS 探测位（501/454 拒，握手属后续 TLS 批次），AUTH PLAIN/LOGIN
 * （注册回调校验；未启用则 503）。
 *
 * 业务集成：应用实现 ISmtpServerSink，服务器在 reactor 线程回调
 * OnServerEvent(msseMessage, Envelope) 交付一封收信（MAIL/RCPT/DATA 收集
 * 完毕后的信封；Envelope.ClientIP 为对端 IP，同 reactor 线程读取）；
 * msseClosed 事件信封亦携带 ClientIP（对端 IP 与 msseMessage 同源），
 * 供消费方按 IP 归账连接生命周期（如 per-IP 并发连接计数递减）。
 * 业务侧回调内不执行阻塞 I/O；向会话内送数据须经
 * context.WorkerHandoff 在 reactor 线程交付。
 *
 * MAIL/RCPT 阶段同步策略：配置 MailPolicy（ISmtpMailPolicyHook）后，会话在
 * MAIL FROM 解析成功、信封 From 定值前回调 EvaluateMailFrom，在 RCPT TO
 * 解析成功、收件人入列前回调 EvaluateRcptTo（reactor 线程，须短非阻塞：
 * 令牌桶/计数/内存状态表判定，不得做 DNS/DB 等阻塞操作）；返回 '' 放行，
 * 非空为完整拒绝回复行。MAIL 拒绝后信封未定值，客户端可重发 MAIL 或 RSET；
 * RCPT 拒绝后该收件人未入列，可重发该 RCPT 或整体重试。典型消费：限流
 * （MAIL 阶段）、greylisting（RCPT 阶段三元组判定）、来源域策略。
 *
 * 线程约束：SendXxx/Cancel 由推进方（reactor 线程，即 Advance）调用。
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
  nextpas.core.mail.base,
  nextpas.core.mail.smtp;

const
  MAIL_SMTP_OUTBOUND_DEFAULT_LIMIT = 65536;
  MAIL_SMTP_MAX_ENVELOPE_RECIPIENTS = 100;
  MAIL_SMTP_LINE_LIMIT = 65536;      { 命令/信封行上限，对齐客户端防失控 }
  MAIL_SMTP_DEFAULT_MAX_MESSAGE = 67108864;  { 64 MiB，对齐 mime 默认上限 }

type
  { SMTP 服务器会话事件，经 ISmtpServerSink 交付应用 }
  TMailSmtpServerEvent = (
    msseMessage,     { 一封信收集完毕，Envelope 有效 }
    msseTimeout,     { 读空闲超时；会话随即关闭 }
    msseOverflow,    { 出站回复队列溢出（背压失败）；会话随即断开 }
    msseClosed       { 传输终止（EOF/取消/QUIT 完成）；不再有后续事件 }
  );

  { 一封信的信封：MAIL FROM + RCPT TO 列表 + DATA 原始字节 + 对端 IP。
    ClientIP 在 DATA 完成时从连接 RemoteAddr 读取（reactor 线程），供
    消费方做收信时刻的源身份判定（SPF、日志、限流）。 }
  TMailSmtpEnvelope = record
    From: TMailAddress;
    Recipients: array of TMailAddress;
    Data: TBytes;                    { DATA 收集后原始字节（含 CRLF，去点转义） }
    ClientIP: string;                { 对端 IP（点分/字面量，不解析为地址类型） }
  end;

  ISmtpServerSink = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000020}']
    procedure OnServerEvent(const AEvent: TMailSmtpServerEvent;
      const AEnvelope: TMailSmtpEnvelope);
  end;

  { MAIL/RCPT 阶段同步策略钩子：应用在信封 From 定值前（MAIL）或收件人
    入列前（RCPT）裁决是否接受本封发件人/收件人。reactor 线程调用，
    须短非阻塞（μs 级，如令牌桶/计数/内存状态表判定），不得做
    DNS/DB/网络等可能阻塞的操作（D9：阻塞操作须卸载到 worker）。
    典型消费：连接/消息限流、greylisting（三元组判定在 RCPT 阶段）、
    来源域策略。
    返回 '' = 放行；非空 = 完整拒绝回复行（状态码 + 增强码 + 文案 +
    CRLF，如 '452 4.7.1 Too many messages' + #13#10）。MAIL 拒绝后
    信封未定值；RCPT 拒绝后该收件人未入列，客户端可重发该 RCPT 或
    RSET 后整体重试。 }
  ISmtpMailPolicyHook = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000021}']
    function EvaluateMailFrom(const AFrom: TMailAddress;
      const AClientIP: string): string;
    { RCPT 阶段：AFrom 为当前信封 MAIL FROM（可为空），ARcpt 为待定收件人。
      实现不关心的阶段返回 ''（放行），实现须同时覆盖两阶段。 }
    function EvaluateRcptTo(const AFrom: TMailAddress; const ARcpt: TMailAddress;
      const AClientIP: string): string;
  end;

  TMailSmtpServerConfig = record
    Domain: string;                  { EHLO/HELO banner 域名；'' → 'localhost' }
    MaxMessageSize: Int64;           { DATA 上限；0 → 64MiB }
    MaxRecipients: Integer;          { 单封收件人上限；<=0 → 100 }
    IdleTimeout: TDuration;          { 读空闲超时；<=0 不限 }
    OutboundQueueLimit: SizeUInt;    { 回复队列上限；0 → 64KiB }
    RequireAuth: Boolean;            { 已 AUTH 才接受 MAIL（Submission 语义） }
    AuthEnabled: Boolean;            { 是否广播 AUTH 并接受 AUTH 命令 }
    AuthCallback: TMethod;           { 预留：凭证校验回调；本批缺省拒（见 plans §6） }
    MailPolicy: ISmtpMailPolicyHook; { MAIL 阶段同步策略钩子；nil = 关闭 }
    class function Default: TMailSmtpServerConfig; static;
  end;

  { 事件驱动的 SMTP 服务器会话（见单元头注释）。 }
  TMailSmtpServerSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    type
      TSessState = (
        stClosed,
        stCommand,     { 读命令行；FResumeState 记录冲刷后回到哪 }
        stData,        { 收 DATA 正文 }
        stFlushing     { 冲刷出站回复队列 }
      );
      TEnvelopeBuild = record
        FromSet: Boolean;
        From: TMailAddress;
        Recipients: array of TMailAddress;
        HasData: Boolean;
      end;
    var
      FConn: ITcpStream;
      FConnRuntime: ITcpStreamRuntime;
      FSink: ISmtpServerSink;
      FConfig: TMailSmtpServerConfig;
      FState: TSessState;
      FResumeState: TSessState;
      FDeadline: TDeadline;
      FLineBuf: TBytes;              { 行累积（命令模式）或协议头累积 }
      FLineLen: SizeUInt;
      FLineOver: Boolean;
      { outbound reply queue }
      FOutbound: array of TBytes;
      FOutCount: SizeUInt;
      FOutBytes: SizeUInt;
      FHeadPos: SizeUInt;
      FReadBuf: array[0..4095] of Byte;
      FReadPos: SizeUInt;            { 已处理读缓冲位置(Flushing 中断续存) }
      FReadAvail: SizeUInt;          { 本批 TryRead 读入字节数 }
      FEnvelope: TEnvelopeBuild;
      FHeloState: (hsNone, hsHelo, hsEhlo);
      FAuthed: Boolean;
      FMailPolicy: ISmtpMailPolicyHook;
      FClosedNotified: Boolean;
      FDataBytes: SizeUInt;
      FDataBuf: TBytes;              { DATA 明文累积（去点转义、含行界） }
      FDataLen: SizeUInt;
      { 帮助生成闭合需要}
      function BuildLine: string;
      procedure RefreshIdleDeadline;
      procedure NotifyClosed;
      procedure AbortSession;
      procedure EnqueueStr(const AValue: string);
      procedure BeginFlush(const AResume: TSessState);
      procedure ProcessCommandLine(const ALine: string);
      procedure HandleDataLine(const ALine: string);
      procedure DrainReadable;
      procedure FlushOutbound;
      procedure ResetEnvelope;
  public
    constructor Create(const AConn: ITcpStream; const ASink: ISmtpServerSink;
      const AConfig: TMailSmtpServerConfig);
    destructor Destroy; override;
    { ITcpServerSession }
    function Run: TTcpServerConnOwnership;
    { ITcpServerPollDrivenSession }
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    { ITcpServerPollDrivenSessionWithDeadline }
    function WakeDeadline: TDeadline;
  end;

implementation

uses
  nextpas.core.text.conv;

class function TMailSmtpServerConfig.Default: TMailSmtpServerConfig;
begin
  Result.Domain := '';
  Result.MaxMessageSize := MAIL_SMTP_DEFAULT_MAX_MESSAGE;
  Result.MaxRecipients := MAIL_SMTP_MAX_ENVELOPE_RECIPIENTS;
  Result.IdleTimeout := TDuration.FromMilliseconds(0);
  Result.OutboundQueueLimit := MAIL_SMTP_OUTBOUND_DEFAULT_LIMIT;
  Result.RequireAuth := False;
  Result.AuthEnabled := False;
  Result.AuthCallback.Code := nil;
  Result.AuthCallback.Data := nil;
  Result.MailPolicy := nil;
end;

{ 从累积行缓冲构造 string（去 CRLF）}
function TMailSmtpServerSession.BuildLine: string;
begin
  SetLength(Result, FLineLen);
  if FLineLen > 0 then
    Move(FLineBuf[0], Result[1], FLineLen);
end;

procedure TMailSmtpServerSession.RefreshIdleDeadline;
begin
  { abort 已置到期 deadline 供 reactor 回收；此处不覆盖 stClosed }
  if FState = stClosed then
    Exit;
  if FConfig.IdleTimeout.AsNanoseconds > 0 then
    FDeadline := TDeadline.After(FConfig.IdleTimeout)
  else
    FDeadline := TDeadline.Infinite;
end;

procedure TMailSmtpServerSession.NotifyClosed;
var
  LEnv: TMailSmtpEnvelope;
begin
  if FClosedNotified then
    Exit;
  FClosedNotified := True;
  if FSink <> nil then
  begin
    { 关闭事件信封携带对端 IP（与 msseMessage 同源 RemoteAddr，连接
      已终止但地址为 accept 时缓存的 sockaddr，仍可读）：消费方按 IP
      归账连接生命周期（如 per-IP 并发连接计数递减）。 }
    LEnv := Default(TMailSmtpEnvelope);
    LEnv.ClientIP := FConn.RemoteAddr.IP;
    FSink.OnServerEvent(msseClosed, LEnv);
  end;
end;

procedure TMailSmtpServerSession.AbortSession;
begin
  if FState = stClosed then
    Exit;
  FState := stClosed;
  FOutbound := nil;
  FOutCount := 0;
  FOutBytes := 0;
  FHeadPos := 0;
  { 置过期 deadline：reactor 经超时唤醒路径驱动 Advance → tsprDone，
    使 abort 早于首次 Advance 的会话（如构造期队列溢出）也能被回收 }
  FDeadline := TDeadline.After(TDuration.FromMilliseconds(0));
  NotifyClosed;
end;

constructor TMailSmtpServerSession.Create(const AConn: ITcpStream;
  const ASink: ISmtpServerSink; const AConfig: TMailSmtpServerConfig);
begin
  inherited Create;
  if AConn = nil then
    raise EArgumentError.Create('smtp server session conn must not be nil');
  FConn := AConn;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise EArgumentError.Create('smtp server session requires stream runtime seam');
  FSink := ASink;
  FConfig := AConfig;
  FMailPolicy := FConfig.MailPolicy;
  if FConfig.Domain = '' then
    FConfig.Domain := 'localhost';
  if FConfig.MaxMessageSize <= 0 then
    FConfig.MaxMessageSize := MAIL_SMTP_DEFAULT_MAX_MESSAGE;
  if FConfig.MaxRecipients <= 0 then
    FConfig.MaxRecipients := MAIL_SMTP_MAX_ENVELOPE_RECIPIENTS;
  if FConfig.OutboundQueueLimit = 0 then
    FConfig.OutboundQueueLimit := MAIL_SMTP_OUTBOUND_DEFAULT_LIMIT;
  FState := stCommand;
  FResumeState := stCommand;
  FReadPos := 0;
  FReadAvail := 0;
  ResetEnvelope;
  { 欢迎横幅进入出站队列并冲刷 }
  EnqueueStr('220 ' + FConfig.Domain + ' ESMTP' + #13#10);
  BeginFlush(stCommand);
  RefreshIdleDeadline;
end;

destructor TMailSmtpServerSession.Destroy;
begin
  NotifyClosed;
  FConnRuntime := nil;
  FConn := nil;
  FSink := nil;
  inherited Destroy;
end;

procedure TMailSmtpServerSession.ResetEnvelope;
begin
  FEnvelope.FromSet := False;
  FEnvelope.From := Default(TMailAddress);
  FEnvelope.Recipients := nil;
  FEnvelope.HasData := False;
  FDataBytes := 0;
  FDataBuf := nil;
  FDataLen := 0;
end;

procedure TMailSmtpServerSession.EnqueueStr(const AValue: string);
var
  LB: TBytes;
begin
  if FOutBytes + SizeUInt(Length(AValue)) > FConfig.OutboundQueueLimit then
  begin
    if FSink <> nil then
      FSink.OnServerEvent(msseOverflow, Default(TMailSmtpEnvelope));
    AbortSession;
    Exit;
  end;
  SetLength(LB, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], LB[0], Length(AValue));
  SetLength(FOutbound, FOutCount + 1);
  FOutbound[FOutCount] := LB;
  Inc(FOutCount);
  Inc(FOutBytes, SizeUInt(Length(LB)));
end;

procedure TMailSmtpServerSession.BeginFlush(const AResume: TSessState);
begin
  FResumeState := AResume;
  if FState = stClosed then
    Exit;
  FState := stFlushing;
end;

{ 按空白切第一个 token（返回值大写动词）；余下原样给 AArgs }
function SplitVerb(const ALine: string; out AVerb: string; out AArgs: string): Boolean;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(ALine)) and (ALine[I] <> ' ') do
    Inc(I);
  AVerb := UpperCase(Copy(ALine, 1, I - 1));
  if I <= Length(ALine) then
    AArgs := Copy(ALine, I + 1, Length(ALine) - I)
  else
    AArgs := '';
  Result := AVerb <> '';
end;

{ 解析 "FROM:<addr>" 或 "TO:<addr>"；LTrim 处理参数前空格。
  前缀大小写不敏感（RFC 5321 命令参数）。 }
function ExtractPath(const AArg: string; const APrefix: string;
  out AAddr: TMailAddress): Boolean;
var
  S, LVal: string;
  I: Integer;
begin
  Result := False;
  I := 1;
  while (I <= Length(AArg)) and (AArg[I] = ' ') do
    Inc(I);
  S := Copy(AArg, I, Length(AArg) - I + 1);
  if UpperCase(Copy(S, 1, Length(APrefix))) <> UpperCase(APrefix) then
    Exit;
  LVal := Copy(S, Length(APrefix) + 1, Length(S) - Length(APrefix));
  { 形如 "<addr>" 或 "<addr> SIZE=n"；取到 '>' 为界 }
  I := Pos('>', LVal);
  if I > 0 then
    LVal := Copy(LVal, 1, I);
  if (Length(LVal) >= 2) and (LVal[1] = '<') and (LVal[Length(LVal)] = '>') then
    LVal := Copy(LVal, 2, Length(LVal) - 2);
  if LVal = '' then
  begin
    { 空路径 <>/<>：弹回，合法空地址 }
    AAddr := Default(TMailAddress);
    Result := True;
    Exit;
  end;
  if TMailAddress.TryParse(LVal, AAddr) then
    Result := True;
end;

{ 提取 SIZE=<n> 参数；失败返回 -1 }
function ExtractSize(const AArg: string): Int64;
var
  I: Integer;
  LTok, LNum: string;
begin
  Result := -1;
  I := Pos('SIZE=', UpperCase(AArg));
  if I = 0 then
    Exit;
  LTok := Copy(AArg, I + 5, Length(AArg) - I - 4);
  I := 1;
  while (I <= Length(LTok)) and (LTok[I] in ['0'..'9']) do
    Inc(I);
  LNum := Copy(LTok, 1, I - 1);
  if LNum = '' then
    Exit;
  Result := StrToInt64Def(LNum, -1);
end;

{ 处理一条完整命令行（不含 CRLF）}
procedure TMailSmtpServerSession.ProcessCommandLine(const ALine: string);
var
  LVerb, LArgs: string;
  LAddr: TMailAddress;
  LSize: Int64;
  LOk: Boolean;
  LPolicyReply: string;
begin
  if not SplitVerb(ALine, LVerb, LArgs) then
  begin
    EnqueueStr('500 5.5.2 Error: bad syntax' + #13#10);
    BeginFlush(stCommand);
    Exit;
  end;

  case LVerb of
    'EHLO', 'HELO':
      begin
        if LVerb = 'EHLO' then
          FHeloState := hsEhlo
        else
          FHeloState := hsHelo;
        if LVerb = 'EHLO' then
        begin
          EnqueueStr('250-' + FConfig.Domain + #13#10);
          EnqueueStr('250-8BITMIME' + #13#10);
          EnqueueStr('250-PIPELINING' + #13#10);
          EnqueueStr('250-SIZE ' + IntToStr(FConfig.MaxMessageSize) + #13#10);
          if FConfig.AuthEnabled then
            EnqueueStr('250-AUTH PLAIN LOGIN' + #13#10);
          EnqueueStr('250 ENHANCEDSTATUSCODES' + #13#10);
        end
        else
          EnqueueStr('250 ' + FConfig.Domain + #13#10);
        ResetEnvelope;
        BeginFlush(stCommand);
      end;
    'MAIL':
      begin
        if FHeloState = hsNone then
        begin
          EnqueueStr('503 5.5.1 Error: send HELO/EHLO first' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if FConfig.RequireAuth and (not FAuthed) then
        begin
          EnqueueStr('530 5.7.0 Authentication required' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if FEnvelope.FromSet then
        begin
          EnqueueStr('503 5.5.1 Error: nested MAIL command' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        LOk := ExtractPath(LArgs, 'FROM:', LAddr);
        if (not LOk) then
        begin
          EnqueueStr('501 5.1.7 Bad sender address syntax' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        LSize := ExtractSize(LArgs);
        if (LSize >= 0) and (LSize > FConfig.MaxMessageSize) then
        begin
          EnqueueStr('552 5.3.4 Message size exceeds fixed limit' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if FMailPolicy <> nil then
        begin
          LPolicyReply := FMailPolicy.EvaluateMailFrom(LAddr,
            FConn.RemoteAddr.IP);
          if LPolicyReply <> '' then
          begin
            EnqueueStr(LPolicyReply);
            BeginFlush(stCommand);
            Exit;
          end;
        end;
        FEnvelope.From := LAddr;
        FEnvelope.FromSet := True;
        EnqueueStr('250 2.1.0 Ok' + #13#10);
        BeginFlush(stCommand);
      end;
    'RCPT':
      begin
        if FHeloState = hsNone then
        begin
          EnqueueStr('503 5.5.1 Error: send HELO/EHLO first' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if not FEnvelope.FromSet then
        begin
          EnqueueStr('503 5.5.1 Error: need MAIL command' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if Length(FEnvelope.Recipients) >= FConfig.MaxRecipients then
        begin
          EnqueueStr('452 4.5.3 Too many recipients' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if not ExtractPath(LArgs, 'TO:', LAddr) then
        begin
          EnqueueStr('501 5.1.3 Bad recipient address syntax' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if FMailPolicy <> nil then
        begin
          { RCPT 阶段同步策略(9.5): 收件人入列前判定(如 greylisting 三元组
            451)。拒绝则该 RCPT 不入列, 客户端可重发该 RCPT 或整体重试。 }
          LPolicyReply := FMailPolicy.EvaluateRcptTo(FEnvelope.From, LAddr,
            FConn.RemoteAddr.IP);
          if LPolicyReply <> '' then
          begin
            EnqueueStr(LPolicyReply);
            BeginFlush(stCommand);
            Exit;
          end;
        end;
        SetLength(FEnvelope.Recipients, Length(FEnvelope.Recipients) + 1);
        FEnvelope.Recipients[High(FEnvelope.Recipients)] := LAddr;
        EnqueueStr('250 2.1.5 Ok' + #13#10);
        BeginFlush(stCommand);
      end;
    'DATA':
      begin
        if FHeloState = hsNone then
        begin
          EnqueueStr('503 5.5.1 Error: send HELO/EHLO first' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        if (not FEnvelope.FromSet) or (Length(FEnvelope.Recipients) = 0) then
        begin
          EnqueueStr('503 5.5.1 Error: need MAIL and RCPT before DATA' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        FDataBytes := 0;
        EnqueueStr('354 End data with <CRLF>.<CRLF>' + #13#10);
        FResumeState := stData;
        FState := stFlushing;
      end;
    'RSET':
      begin
        ResetEnvelope;
        EnqueueStr('250 2.0.0 Ok' + #13#10);
        BeginFlush(stCommand);
      end;
    'NOOP':
      begin
        EnqueueStr('250 2.0.0 Ok' + #13#10);
        BeginFlush(stCommand);
      end;
    'QUIT':
      begin
        EnqueueStr('221 2.0.0 Bye' + #13#10);
        { 冲刷该回复后关闭 }
        FResumeState := stClosed;
        FState := stFlushing;
      end;
    'HELP':
      EnqueueStr('214 2.0.0 HELP' + #13#10);
    'VRFY', 'EXPN':
      EnqueueStr('252 2.5.2 Cannot VRFY user, but will accept message' + #13#10);
    'STARTTLS':
      EnqueueStr('454 4.7.0 TLS not available' + #13#10);
    'AUTH':
      if FConfig.AuthEnabled then
        EnqueueStr('503 5.5.1 Authentication not implemented yet' + #13#10)
      else
        EnqueueStr('503 5.5.1 Authentication not available' + #13#10);
  else
    EnqueueStr('500 5.5.2 Error: command not recognized' + #13#10);
  end;
  { 除 DATA/QUIT 已显式切到 Flushing 外，其余命令回复也需冲刷 }
  if (LVerb <> 'DATA') and (LVerb <> 'QUIT') and (FState = stCommand) then
    BeginFlush(stCommand);
end;

{ DATA 模式一行（去 CRLF）：处理点转义、大小上限、终止点 }
procedure TMailSmtpServerSession.HandleDataLine(const ALine: string);
var
  LLen: SizeUInt;
  LContent: string;
  LDeliver: TMailSmtpEnvelope;
begin
  if FState <> stData then
    Exit;
  { 终止点：'.\r\n'（ALine = '.'） }
  if ALine = '.' then
  begin
    { 集合完毕：交给信封一份独立所有权的副本（FDataBuf 随即被 Reset 释放） }
    LDeliver.From := FEnvelope.From;
    LDeliver.Recipients := FEnvelope.Recipients;
    FEnvelope.Recipients := nil;
    LDeliver.ClientIP := FConn.RemoteAddr.IP;
    SetLength(LDeliver.Data, FDataLen);
    if FDataLen > 0 then
      Move(FDataBuf[0], LDeliver.Data[0], FDataLen);
    EnqueueStr('250 2.0.0 Ok: queued' + #13#10);
    if FSink <> nil then
      FSink.OnServerEvent(msseMessage, LDeliver);
    ResetEnvelope;
    FState := stCommand;
    BeginFlush(stCommand);
    Exit;
  end;
  { 大小上限：含 CRLF 计入 }
  if FConfig.MaxMessageSize > 0 then
  begin
    if FDataBytes + SizeUInt(Length(ALine)) + 2 > SizeUInt(FConfig.MaxMessageSize) then
    begin
      EnqueueStr('552 5.3.4 Message size exceeds fixed limit' + #13#10);
      { 丢弃该 DATA，回命令态 }
      ResetEnvelope;
      FState := stCommand;
      BeginFlush(stCommand);
      Exit;
    end;
    Inc(FDataBytes, SizeUInt(Length(ALine)) + 2);
  end;
  { 点转义：行首 '.' 剥除（终止点已判） }
  LContent := ALine;
  if (Length(LContent) > 0) and (LContent[1] = '.') then
    LContent := Copy(LContent, 2, Length(LContent) - 1);
  LLen := SizeUInt(Length(LContent));
  if FDataLen + LLen + 2 > SizeUInt(Length(FDataBuf)) then
    SetLength(FDataBuf, FDataLen + LLen + 256);
  if LLen > 0 then
    Move(LContent[1], FDataBuf[FDataLen], LLen);
  Inc(FDataLen, LLen);
  FDataBuf[FDataLen] := 13;
  Inc(FDataLen);
  FDataBuf[FDataLen] := 10;
  Inc(FDataLen);
  FEnvelope.HasData := True;
end;

procedure TMailSmtpServerSession.DrainReadable;
var
  LRead: SizeUInt;
  LRes: TTcpStreamIOResult;
  B: Byte;
  LLine: string;
begin
  if FConnRuntime = nil then
    Exit;
  while (FState = stCommand) or (FState = stData) do
  begin
    { 先消费因 Flushing 中断而保留的未处理字节(FReadPos..FReadAvail-1):
      处理行导致切 Flushing 时 FReadPos 已停在断点, 剩余命令不丢
      (pipeling/多行同批读入场景, 见 ProcessCommandLine 后 Exit) }
    while (FReadPos < FReadAvail) and
          ((FState = stCommand) or (FState = stData)) do
    begin
      B := FReadBuf[FReadPos];
      Inc(FReadPos);
      if B = 10 then
      begin
        { 行结束（去 CR）}
        if (FLineLen > 0) and (FLineBuf[FLineLen - 1] = 13) then
          Dec(FLineLen);
        if FLineOver then
        begin
          { 超长行：RFC 5321 §4.5.3.1 行长度上限，整行丢弃并报 500 }
          FLineLen := 0;
          FLineOver := False;
          EnqueueStr('500 5.5.2 Error: line too long' + #13#10);
          BeginFlush(stCommand);
          Exit;
        end;
        LLine := BuildLine;
        FLineLen := 0;
        FLineOver := False;
        if FState = stCommand then
        begin
          ProcessCommandLine(LLine);
          { 若进入 Flushing（有回复待写）则本 drain 停止，等可写事件；
            未处理字节保留下次续读 }
          if FState = stFlushing then
            Exit;
        end
        else if FState = stData then
        begin
          HandleDataLine(LLine);
          if FState = stFlushing then
            Exit;
        end;
      end
      else if B = 13 then
      begin
        { 忽略 CR（以 LF 为定界；行首 CR 属于 SMTP 折叠/裸换行场景，保守忽略）}
      end
      else
      begin
        if FLineLen >= MAIL_SMTP_LINE_LIMIT then
          FLineOver := True
        else if not FLineOver then
        begin
          if FLineLen >= SizeUInt(Length(FLineBuf)) then
            SetLength(FLineBuf, FLineLen + 256);
          FLineBuf[FLineLen] := B;
          Inc(FLineLen);
        end;
      end;
    end;
    { 缓冲消费完：重置断点, 读新字节 }
    FReadPos := 0;
    FReadAvail := 0;
    if (FState <> stCommand) and (FState <> stData) then
      Exit;
    LRes := FConnRuntime.TryRead(FReadBuf[0], SizeOf(FReadBuf), LRead);
    case LRes of
      tsiorOk:
        begin
          if LRead = 0 then
          begin
            NotifyClosed;
            FState := stClosed;
            Exit;
          end;
          FReadAvail := LRead;
        end;
      tsiorWouldBlock:
        Exit;
      tsiorClosed, tsiorTimeout:
        begin
          NotifyClosed;
          FState := stClosed;
          Exit;
        end;
    end;
  end;
end;

procedure TMailSmtpServerSession.FlushOutbound;
var
  LHead: TBytes;
  LWritten: SizeUInt;
  LRes: TTcpStreamIOResult;
  LI: SizeUInt;
begin
  if FConnRuntime = nil then
    Exit;
  while (FOutCount > 0) and (FState = stFlushing) do
  begin
    LHead := FOutbound[0];
    while FHeadPos < SizeUInt(Length(LHead)) do
    begin
      LRes := FConnRuntime.TryWrite(LHead[FHeadPos],
        SizeUInt(Length(LHead)) - FHeadPos, LWritten);
      case LRes of
        tsiorOk:
          begin
            if LWritten = 0 then
            begin
              FState := stClosed;
              NotifyClosed;
              Exit;
            end;
            Inc(FHeadPos, LWritten);
          end;
        tsiorWouldBlock:
          Exit;
      else
        FState := stClosed;
        NotifyClosed;
        Exit;
      end;
    end;
    Dec(FOutBytes, SizeUInt(Length(LHead)));
    LHead := nil;
    FOutbound[0] := nil;
    for LI := 1 to FOutCount - 1 do
      FOutbound[LI - 1] := FOutbound[LI];
    SetLength(FOutbound, FOutCount - 1);
    Dec(FOutCount);
    FHeadPos := 0;
  end;
  if FOutCount = 0 then
  begin
    if FState = stFlushing then
    begin
      FState := FResumeState;
      RefreshIdleDeadline;
      if FState = stClosed then
        NotifyClosed
      else if FReadAvail > FReadPos then
      begin
        { 冲刷完成回到命令/数据态, 缓冲里还有未消费的命令行
          (pipelining: 一次 TryRead 读入多行, 首行处理即切 Flushing):
          立即续处理, 不等可读事件(内核已无新数据, 事件不会再来) }
        DrainReadable;
      end;
    end;
  end;
end;

{ 会话 I/O 事件推进入口。初始兴趣依状态：
  flushing 期（banner/回复待写）订阅可写，其余订阅可读。 }
function TMailSmtpServerSession.PollEvents: TPlatformPollEvents;
begin
  case FState of
    stFlushing: Result := [peWritable];
    stClosed: Result := [];
  else
    Result := [peReadable];
  end;
end;

function TMailSmtpServerSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;
  ANextEvents := [];
  if FState = stClosed then
    Exit(tsprDone);

  if AEvents <> [] then
  begin
    if FState in [stCommand, stData] then
      DrainReadable;
    if FState = stFlushing then
      FlushOutbound;
  end;

  { 读空闲超时：reactor 以空事件集唤醒超时目标 }
  if (FState in [stCommand, stData]) and (AEvents = []) and
     FDeadline.IsExpired then
  begin
    if FSink <> nil then
      FSink.OnServerEvent(msseTimeout, Default(TMailSmtpEnvelope));
    FState := stClosed;
    NotifyClosed;
    Exit(tsprDone);
  end;

  case FState of
    stClosed:
      Exit(tsprDone);
    stFlushing:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    { stCommand / stData }
    RefreshIdleDeadline;
    ANextEvents := [peReadable];
    Exit(tsprWait);
  end;
end;

function TMailSmtpServerSession.WakeDeadline: TDeadline;
begin
  Result := FDeadline;
end;

function TMailSmtpServerSession.Run: TTcpServerConnOwnership;
begin
  { 事件驱动会话不提供阻塞降级路径：threaded 后端接入属误用，显式 501。 }
  Result := tscoServer;
  raise ENotSupportedError.Create(
    'smtp server session requires an evented tcp server backend');
end;

end.
