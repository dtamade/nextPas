unit nextpas.core.ssh.channel;

{** nextpas.core.ssh - 连接协议通道（RFC 4254）。
 *
 * 单通道引擎 TSshChannel：open session → exec / subsystem → 双向数据泵 →
 * close；一次性 exec（SshRunExec）与 sftp 子系统共用。窗口流量控制按
 * RFC 4254 §5.2 双向分开记账，接收侧"消费过半即回补"。
 *
 * 本地通道号进程级单调递增、永不复用；所有泵循环统一经 PumpFiltered
 * 丢弃旧通道迟滞帧，并就地入账对端 WINDOW_ADJUST 授予的发送信用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.io.intf,
  nextpas.core.time.stopwatch,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.transport;

type
  { exec 执行结果 }
  TSshExecResult = record
    ExitCode: Integer;
    StdOut: TBytes;
    StdErr: TBytes;

    function StdOutText: string;
    function StdErrText: string;
  end;

  TProcSshExecResult = procedure(const AResult: TSshExecResult; AErr: ESSHError; AContext: Pointer);

{ 在已认证的传输上执行一次性命令并阻塞收集输出。
  ATimeoutMs <= 0 表示无限等待。}
function SshRunExec(ATransport: TSshClientTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer): TSshExecResult;

{ 读下一条"非透明"消息：跳过 IGNORE/DEBUG/UNIMPLEMENTED/EXT_INFO/BANNER；
  DISCONNECT 抛 sekDisconnect 并带描述。公开供 session 层认证流程复用。
  通道族的按-id 过滤在 TSshChannel 内做（需要知道本通道的本地号）。}
function PumpMessage(ATransport: TSshClientTransport): TBytes;

type
  { 可选诊断钩子：非 nil 时泵循环逐帧回调（e2e/互操作排障用；库内默认 nil，
    零开销）。回调方自行保证线程安全——当前一次性 exec 为单线程使用。}
    TSshTraceProc = procedure(const ALine: string);

var
  SshChannelTrace: TSshTraceProc = nil;

type
  { 入站数据信箱条目：发送侧等对端窗口回补时泵到的数据不得丢弃 }
  TSshDataChunk = record
    Data: TBytes;
    Extended: Boolean;
  end;

  { 单通道引擎：open session → exec / subsystem 请求 → 双向数据泵 → close。
    exec（一次性收集）与 sftp（长寿命请求应答）共用本类。

    窗口语义（RFC 4254 §5.2）双向分开记账：
    - 接收方向：信用 = 我方在 CHANNEL_OPEN 里声明的初始窗口；消费过半即
      回补 WINDOW_ADJUST。（此前误用对端声明的窗口做基准，小流量未暴露。）
    - 发送方向：信用 = 对端在 OPEN_CONFIRMATION 里授予的窗口；SendData 按
      对端 MaxPacket 分片，信用不足时泵入站帧等待回补。}
  TSshChannel = class
  private
    FTransport: TSshClientTransport;
    FLocalId: UInt32;            { 本地通道号：进程级单调递增，永不复用 }
    FRemoteId: UInt32;
    FOurWindow: SizeUInt;        { 我方授出的接收信用 }
    FPeerWindow: SizeUInt;       { 对端授给我方的发送信用 }
    FPeerMaxPacket: UInt32;
    FInitWindow: UInt32;
    FMaxPacket: UInt32;
    FExitStatus: Integer;
    FGotClose: Boolean;
    FSentClose: Boolean;
    FDeadlineMs: Integer;
    FWatch: TStopwatch;
    FInbox: array of TSshDataChunk;
    procedure AccountConsume(ACount: SizeUInt);
    procedure SendWindowAdjust(ACount: UInt32);
    procedure SendRequest(const AName: string; const APayloadTail: TBytes);
    procedure HandleChannelRequest(const APayload: TBytes);
    procedure HandleGlobalRequest;
    function TimedOut: Boolean;
    { 泵下一条消息（传输层杂讯已滤）；通道族帧按 FLocalId 过滤迟滞帧，
      本通道的 WINDOW_ADJUST 就地入账发送信用 }
    function PumpFiltered: TBytes;
    { 从 CHANNEL_DATA/EXT_DATA 帧提取载荷并记账；不应投递的返回 False }
    function PumpExtractData(const APayload: TBytes; AExtended: Boolean;
      out AChunk: TBytes): Boolean;
    procedure InboxPush(const AChunk: TBytes; AExtended: Boolean);
    function InboxPop(out AChunk: TBytes; out AExtended: Boolean): Boolean;
    { 泵一条入站消息：DATA/EXT_DATA 返回载荷，其余就地消化，CLOSE 返回 False }
    function PumpRaw(out AData: TBytes; out AExtended: Boolean): Boolean;
  public
    constructor Create(ATransport: TSshClientTransport;
      AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer);
    procedure OpenSession;
    procedure OpenDirectTcpip(const AHost: string; APort: Word;
      const AOriginatorIP: string = '127.0.0.1'; AOriginatorPort: Word = 0);
    procedure ExecCommand(const ACommand: string);
    procedure RequestSubsystem(const AName: string);
    { 发送通道数据：按对端 MaxPacket 与剩余信用分片，必要时泵等回补 }
    procedure SendData(const AData: TBytes);
    { 泵出下一段通道数据；False 表示通道已由任一侧关闭 }
    function PumpData(out AData: TBytes; out AExtended: Boolean): Boolean;
    { 幂等：EOF（未发过）+ CLOSE }
    procedure Close;
    { 清理路径：吞 IO 异常 }
    procedure TryClose;
    destructor Destroy; override;
    property LocalId: UInt32 read FLocalId;
    property RemoteId: UInt32 read FRemoteId;
    property GotClose: Boolean read FGotClose;
    property ExitStatus: Integer read FExitStatus;
  end;

  { 通道承载的双向字节流（用于 ProxyJump 的 direct-tcpip 转发） }
  TChannelStream = class(TInterfacedObject, IReadWriteCloser)
  private
    FChannel: TSshChannel;
    FClosed: Boolean;
    FBuf: TBytes;
    FBufPos: SizeUInt;
  public
    constructor Create(AChannel: TSshChannel);
    destructor Destroy; override;
    function Read(var ABuffer; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuffer; const ACount: SizeUInt): SizeUInt;
    procedure Close; reintroduce;
  end;

{ 常用通道载荷构造（复用点：多路复用通道 slice）}
function EofPayload(ARemoteId: UInt32): TBytes;
function ClosePayload(ARemoteId: UInt32): TBytes;
function ChannelReplyPayload(ARemoteId: UInt32; AOk: Boolean): TBytes;
function GlobalReplyPayload(AOk: Boolean): TBytes;
procedure AppendChunk(var ADst: TBytes; const ASrc: TBytes); inline;

implementation

uses
  nextpas.core.base.utils;

procedure TraceStr(const ALine: string);
begin
  if SshChannelTrace <> nil then
    SshChannelTrace(ALine);
end;

procedure TracePkt(const ATag: string; const APkt: TBytes);
var
  LFirst: UInt32;
begin
  if SshChannelTrace = nil then
    Exit;
  LFirst := 0;
  if Length(APkt) >= 5 then
    LFirst := (UInt32(APkt[1]) shl 24) or (UInt32(APkt[2]) shl 16) or
      (UInt32(APkt[3]) shl 8) or UInt32(APkt[4]);
  SshChannelTrace(ATag + ': type=' + IntToStr(APkt[0]) +
    ' first=' + IntToStr(LFirst) + ' len=' + IntToStr(Length(APkt)));
end;


function TSshExecResult.StdOutText: string;
begin
  Result := SshTextFromBytes(StdOut);
end;

function TSshExecResult.StdErrText: string;
begin
  Result := SshTextFromBytes(StdErr);
end;

const
  WINDOW_LOW_WATER_DIVISOR = 2;  { 消费过半即回补 }
  SSH_CHANNEL_INBOX_MAX = 1024;  { 信箱上限：防对端洪泛 DATA 导致无界内存 }

var
  { 本地通道号进程级单调递增（RFC 4254 §5：号按方向独立命名）。
    恒用常量 0 会与服务端"最低空闲号复用"+ 未完成 GC 的窗口竞态叠加：
    新请求被路由进僵尸会话，输出成倍回流（e2e 实测 twotwo/twotwotwo）。}
  GNextLocalChannelId: UInt32 = 0;

{ ---- 载荷构造 ---- }

procedure AppendChunk(var ADst: TBytes; const ASrc: TBytes); inline;
begin
  BytesAppend(ADst, ASrc);
end;

function SingleIdPayload(AMsg: Byte; ARemoteId: UInt32): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(8);
  try
    LW.PutByte(AMsg);
    LW.PutUInt32(ARemoteId);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function EofPayload(ARemoteId: UInt32): TBytes;
begin
  Result := SingleIdPayload(SSH_MSG_CHANNEL_EOF, ARemoteId);
end;

function ClosePayload(ARemoteId: UInt32): TBytes;
begin
  Result := SingleIdPayload(SSH_MSG_CHANNEL_CLOSE, ARemoteId);
end;

function ChannelReplyPayload(ARemoteId: UInt32; AOk: Boolean): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(8);
  try
    if AOk then
      LW.PutByte(SSH_MSG_CHANNEL_SUCCESS)
    else
      LW.PutByte(SSH_MSG_CHANNEL_FAILURE);
    LW.PutUInt32(ARemoteId);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function GlobalReplyPayload(AOk: Boolean): TBytes;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(4);
  try
    if AOk then
      LW.PutByte(SSH_MSG_REQUEST_SUCCESS)
    else
      LW.PutByte(SSH_MSG_REQUEST_FAILURE);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function PumpMessage(ATransport: TSshClientTransport): TBytes;
var
  LDesc: TBytes;
  LR: TsshReader;
begin
  while True do
  begin
    Result := ATransport.ReadPacket;
    if Length(Result) = 0 then
      raise ESSHError.Create(sekProtocol, 'ssh channel: empty packet');
    TracePkt('rx', Result);
    case Result[0] of
      SSH_MSG_IGNORE, SSH_MSG_DEBUG, SSH_MSG_UNIMPLEMENTED,
      SSH_MSG_EXT_INFO, SSH_MSG_USERAUTH_BANNER:
        Continue;
      SSH_MSG_DISCONNECT:
      begin
        LR := TsshReader.Create(Result);
        try
          LR.ReadByte;
          LR.ReadUInt32;
          LDesc := LR.ReadStringBytes;
        finally
          LR.Free;
        end;
        raise ESSHError.Create(sekDisconnect,
          'ssh: disconnected by peer: ' + SshTextFromBytes(LDesc));
      end;
    end;
    Exit;
  end;
end;

{ ---- 单通道引擎 ---- }

constructor TSshChannel.Create(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer);
begin
  inherited Create;
  FTransport := ATransport;
  FLocalId := GNextLocalChannelId;
  Inc(GNextLocalChannelId);
  FRemoteId := 0;
  FExitStatus := -1;
  FInitWindow := AInitialWindow;
  FMaxPacket := AMaxPacket;
  if FInitWindow = 0 then
    FInitWindow := SSH_DEFAULT_WINDOW_SIZE;
  if FMaxPacket = 0 then
    FMaxPacket := SSH_DEFAULT_MAX_PACKET;
  FDeadlineMs := ATimeoutMs;
  if FDeadlineMs > 0 then
    FWatch := TStopwatch.StartNew;
end;

function TSshChannel.TimedOut: Boolean;
begin
  Result := (FDeadlineMs > 0) and (FWatch.ElapsedMilliseconds > FDeadlineMs);
end;

procedure TSshChannel.OpenSession;
var
  LW: TsshWriter;
  LR: TsshReader;
  LMsg: TBytes;
begin
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_CHANNEL_OPEN);
    LW.PutStringText(SSH_CHANNEL_SESSION);
    LW.PutUInt32(FLocalId);
    LW.PutUInt32(FInitWindow);
    LW.PutUInt32(FMaxPacket);
    TracePkt('tx', LW.ToBytes);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;

  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout opening session');
    LMsg := PumpFiltered;
    case LMsg[0] of
      SSH_MSG_CHANNEL_OPEN_CONFIRMATION:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LR.ReadUInt32;   { recipient：PumpFiltered 已保证 = FLocalId }
            FRemoteId := LR.ReadUInt32;
            { 对端授予的发送信用与其 MaxPacket 上限（此前未读，发送分片缺依据）}
            FPeerWindow := LR.ReadUInt32;
            FPeerMaxPacket := LR.ReadUInt32;
          finally
            LR.Free;
          end;
          FOurWindow := FInitWindow;
          TraceStr('open: confirmed remote=' + IntToStr(FRemoteId) +
            ' peer_window=' + IntToStr(FPeerWindow) +
            ' peer_max=' + IntToStr(FPeerMaxPacket));
          Exit;
        end;
      SSH_MSG_CHANNEL_OPEN_FAILURE:
        raise ESSHError.Create(sekProtocol, 'ssh channel: session open refused');
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshChannel.OpenDirectTcpip(const AHost: string; APort: Word;
  const AOriginatorIP: string; AOriginatorPort: Word);
var
  LW: TsshWriter;
  LR: TsshReader;
  LMsg: TBytes;
begin
  LW := TsshWriter.Create(128);
  try
    LW.PutByte(SSH_MSG_CHANNEL_OPEN);
    LW.PutStringText('direct-tcpip');
    LW.PutUInt32(FLocalId);
    LW.PutUInt32(FInitWindow);
    LW.PutUInt32(FMaxPacket);
    LW.PutStringText(AHost);
    LW.PutUInt32(APort);
    LW.PutStringText(AOriginatorIP);
    LW.PutUInt32(AOriginatorPort);
    TracePkt('tx', LW.ToBytes);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout opening direct-tcpip');
    LMsg := PumpFiltered;
    case LMsg[0] of
      SSH_MSG_CHANNEL_OPEN_CONFIRMATION:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LR.ReadUInt32;
            FRemoteId := LR.ReadUInt32;
            FPeerWindow := LR.ReadUInt32;
            FPeerMaxPacket := LR.ReadUInt32;
          finally
            LR.Free;
          end;
          FOurWindow := FInitWindow;
          TraceStr('direct-tcpip: confirmed remote=' + IntToStr(FRemoteId));
          Exit;
        end;
      SSH_MSG_CHANNEL_OPEN_FAILURE:
        raise ESSHError.Create(sekProtocol, 'ssh channel: direct-tcpip open refused');
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshChannel.ExecCommand(const ACommand: string);
var
  LTail: TsshWriter;
  LMsg: TBytes;
  LChunk: TBytes;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(ACommand);
    SendRequest(SSH_REQ_EXEC, LTail.ToBytes);
  finally
    LTail.Free;
  end;

  { 等 exec 应答；期间混入的数据帧入信箱而非丢弃 }
  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout waiting exec reply');
    LMsg := PumpFiltered;
    case LMsg[0] of
      SSH_MSG_CHANNEL_SUCCESS:
      begin
        TraceStr('exec: success');
        Exit;
      end;
      SSH_MSG_CHANNEL_FAILURE:
        raise ESSHError.Create(sekProtocol, 'ssh channel: exec refused by server');
      SSH_MSG_CHANNEL_DATA:
        if PumpExtractData(LMsg, False, LChunk) then
          InboxPush(LChunk, False);
      SSH_MSG_CHANNEL_EXTENDED_DATA:
        if PumpExtractData(LMsg, True, LChunk) then
          InboxPush(LChunk, True);
      SSH_MSG_CHANNEL_EOF:
        ; { EOF 细节留给收集阶段 }
      SSH_MSG_CHANNEL_CLOSE:
        begin
          TraceStr('exec: close during reply wait');
          Close;
          FGotClose := True;
          Exit;
        end;
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshChannel.RequestSubsystem(const AName: string);
var
  LTail: TsshWriter;
  LMsg: TBytes;
  LChunk: TBytes;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(AName);
    SendRequest(SSH_REQ_SUBSYSTEM, LTail.ToBytes);
  finally
    LTail.Free;
  end;

  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout,
        'ssh channel: timeout waiting subsystem reply');
    LMsg := PumpFiltered;
    case LMsg[0] of
      SSH_MSG_CHANNEL_SUCCESS:
      begin
        TraceStr('subsystem: success');
        Exit;
      end;
      SSH_MSG_CHANNEL_FAILURE:
        raise ESSHError.Create(sekProtocol,
          'ssh channel: subsystem refused by server: ' + AName);
      SSH_MSG_CHANNEL_DATA:
        if PumpExtractData(LMsg, False, LChunk) then
          InboxPush(LChunk, False);
      SSH_MSG_CHANNEL_EXTENDED_DATA:
        if PumpExtractData(LMsg, True, LChunk) then
          InboxPush(LChunk, True);
      SSH_MSG_CHANNEL_EOF:
        ;
      SSH_MSG_CHANNEL_CLOSE:
        begin
          Close;
          FGotClose := True;
          Exit;
        end;
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshChannel.SendRequest(const AName: string; const APayloadTail: TBytes);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(64 + SizeUInt(Length(APayloadTail)));
  try
    LW.PutByte(SSH_MSG_CHANNEL_REQUEST);
    LW.PutUInt32(FRemoteId);
    LW.PutStringText(AName);
    LW.PutBoolean(True);   { want_reply }
    LW.PutRaw(APayloadTail);
    TracePkt('tx', LW.ToBytes);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

procedure TSshChannel.SendWindowAdjust(ACount: UInt32);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(16);
  try
    LW.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST);
    LW.PutUInt32(FRemoteId);
    LW.PutUInt32(ACount);
    TracePkt('tx', LW.ToBytes);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

procedure TSshChannel.AccountConsume(ACount: SizeUInt);
var
  LGiveBack: SizeUInt;
begin
  { 防御：单帧消费超过剩余信用（对端违约）时按全部剩余回补，不取负 }
  if ACount > FOurWindow then
  begin
    LGiveBack := FOurWindow;
    FOurWindow := 0;
  end
  else
  begin
    Dec(FOurWindow, ACount);
    LGiveBack := 0;
  end;
  { 消费过半（含耗尽）即整批回补，服务端永不停摆 }
  if FOurWindow <= SizeUInt(FInitWindow) div WINDOW_LOW_WATER_DIVISOR then
  begin
    Inc(LGiveBack, SizeUInt(FInitWindow) - FOurWindow);
    FOurWindow := FInitWindow;
  end;
  while LGiveBack > High(UInt32) do
  begin
    SendWindowAdjust(High(UInt32));
    Dec(LGiveBack, High(UInt32));
  end;
  if LGiveBack > 0 then
    SendWindowAdjust(UInt32(LGiveBack));
end;

procedure TSshChannel.HandleChannelRequest(const APayload: TBytes);
var
  LR: TsshReader;
  LReqName: string;
  LWantReply: Boolean;
begin
  LR := TsshReader.Create(APayload);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    LReqName := LR.ReadStringText;
    LWantReply := LR.ReadBoolean;
    if LReqName = SSH_REQ_EXIT_STATUS then
    begin
      FExitStatus := Integer(LR.ReadUInt32);
      TraceStr('chan: exit-status=' + IntToStr(FExitStatus));
      if LWantReply then
        FTransport.SendPacket(ChannelReplyPayload(FRemoteId, True));
    end
    else if LWantReply then
      FTransport.SendPacket(ChannelReplyPayload(FRemoteId, False));
  finally
    LR.Free;
  end;
end;

procedure TSshChannel.HandleGlobalRequest;
begin
  { want_reply 的未知全局请求必须回应 FAILURE（RFC 4254 §4）}
  FTransport.SendPacket(GlobalReplyPayload(False));
end;

function TSshChannel.PumpFiltered: TBytes;
var
  LR: TsshReader;
  LRid: UInt32;
  LAdd: UInt32;
  LNew: SizeUInt;
begin
  while True do
  begin
    Result := PumpMessage(FTransport);
    if (Result[0] < SSH_MSG_CHANNEL_OPEN_CONFIRMATION) or
       (Result[0] > SSH_MSG_CHANNEL_FAILURE) then
      Exit;   { 非通道族：原样上交 }
    { 通道族帧首 uint32 均为 recipient（我方通道号）；旧通道迟滞帧丢弃，
      否则会被当成当前会话的数据（e2e 实测输出成倍回流）}
    LR := TsshReader.Create(Result);
    try
      LR.ReadByte;
      LRid := LR.ReadUInt32;
    finally
      LR.Free;
    end;
    if LRid <> FLocalId then
    begin
      TraceStr('rx: stale chan frame id=' + IntToStr(LRid) +
        ' mine=' + IntToStr(FLocalId) + ' dropped');
      Continue;
    end;
    if Result[0] = SSH_MSG_CHANNEL_WINDOW_ADJUST then
    begin
      { RFC 4254 §5.2：ADJUST 入账我方发送信用。实测 OpenSSH 对客户端
        session 通道确认初始窗口 0 后以此帧补足；任何等待循环绕过这里
        都会丢信用，表现为首个 SendData 永久挂起。}
      LR := TsshReader.Create(Result);
      try
        LR.ReadByte;
        LR.ReadUInt32;
        LAdd := LR.ReadUInt32;
        if not TryAddSizeUInt(FPeerWindow, SizeUInt(LAdd), LNew) then
          raise ESSHError.Create(sekProtocol, 'ssh channel: peer window overflow');
        FPeerWindow := LNew;
      finally
        LR.Free;
      end;
      Continue;
    end;
    Exit;
  end;
end;

function TSshChannel.PumpExtractData(const APayload: TBytes;
  AExtended: Boolean; out AChunk: TBytes): Boolean;
var
  LR: TsshReader;
  LRid, LDataType: UInt32;
begin
  Result := False;
  AChunk := nil;
  LDataType := 0;
  LR := TsshReader.Create(APayload);
  try
    LR.ReadByte;
    { recipient 字段是我方（声明方为客户端）的通道号，不是服务端号；
      与 FRemoteId 比对是语义错位，服务端非 0 号分配时数据被误丢 }
    LRid := LR.ReadUInt32;
    if LRid <> FLocalId then
      Exit;
    if AExtended then
    begin
      LDataType := LR.ReadUInt32;
      AChunk := LR.ReadStringBytes;
    end
    else
      AChunk := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
  { 仅 stderr 走扩展通道；未知扩展类型计入窗口但不投递 }
  if Length(AChunk) = 0 then
    Exit;
  AccountConsume(SizeUInt(Length(AChunk)));
  if AExtended then
    Result := LDataType = SSH_EXTENDED_DATA_STDERR
  else
    Result := True;
end;

procedure TSshChannel.InboxPush(const AChunk: TBytes; AExtended: Boolean);
var
  LN: Integer;
begin
  if Length(FInbox) >= SSH_CHANNEL_INBOX_MAX then
    raise ESSHError.Create(sekProtocol, 'ssh channel: inbox overflow');
  LN := Length(FInbox);
  SetLength(FInbox, LN + 1);
  FInbox[LN].Data := AChunk;
  FInbox[LN].Extended := AExtended;
end;

function TSshChannel.InboxPop(out AChunk: TBytes; out AExtended: Boolean): Boolean;
var
  I: Integer;
begin
  Result := Length(FInbox) > 0;
  if not Result then
    Exit;
  AChunk := FInbox[0].Data;
  AExtended := FInbox[0].Extended;
  for I := 1 to High(FInbox) do
    FInbox[I - 1] := FInbox[I];
  SetLength(FInbox, Length(FInbox) - 1);
end;

function TSshChannel.PumpRaw(out AData: TBytes; out AExtended: Boolean): Boolean;
var
  LMsg: TBytes;
  LChunk: TBytes;
begin
  Result := False;
  AData := nil;
  AExtended := False;
  while True do
  begin
    if FGotClose then
      Exit;
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout pumping frames');
    LMsg := PumpFiltered;
    case LMsg[0] of
      SSH_MSG_CHANNEL_DATA:
        if PumpExtractData(LMsg, False, LChunk) then
        begin
          AData := LChunk;
          Exit(True);
        end;
      SSH_MSG_CHANNEL_EXTENDED_DATA:
        if PumpExtractData(LMsg, True, LChunk) then
        begin
          AData := LChunk;
          AExtended := True;
          Exit(True);
        end;
      SSH_MSG_CHANNEL_REQUEST:
        HandleChannelRequest(LMsg);
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
      SSH_MSG_CHANNEL_SUCCESS, SSH_MSG_CHANNEL_FAILURE, SSH_MSG_CHANNEL_EOF:
        ; { 请求应答已在等待循环消费；EOF 仅标记 }
      SSH_MSG_CHANNEL_CLOSE:
        begin
          TraceStr('chan: rx close -> done');
          Close;
          FGotClose := True;
          Exit;
        end;
    end;
  end;
end;

procedure TSshChannel.SendData(const AData: TBytes);
var
  LOff, LTake: SizeUInt;
  LW: TsshWriter;
  LChunk: TBytes;
  LDummyData: TBytes;
  LDummyExt: Boolean;
begin
  LOff := 0;
  while LOff < SizeUInt(Length(AData)) do
  begin
    { 发送信用耗尽：泵入站帧等回补；泵到的数据入信箱不丢 }
    while (FPeerWindow = 0) and not FGotClose do
    begin
      if TimedOut then
        raise ESSHError.Create(sekTimeout,
          'ssh channel: timeout waiting peer window credit');
      PumpRaw(LDummyData, LDummyExt);
    end;
    if FGotClose then
      raise ESSHError.Create(sekIO, 'ssh channel: closed by peer during send');
    LTake := SizeUInt(Length(AData)) - LOff;
    if LTake > SizeUInt(FPeerMaxPacket) then
      LTake := FPeerMaxPacket;
    if LTake > SizeUInt(FPeerWindow) then
      LTake := SizeUInt(FPeerWindow);
    LChunk := Copy(AData, LOff, LTake);
    LW := TsshWriter.Create(16 + Integer(LTake));
    try
      LW.PutByte(SSH_MSG_CHANNEL_DATA);
      LW.PutUInt32(FRemoteId);
      { RFC 4254 §6.1：data 是 string，必须带 4 字节长度前缀。
        此前缺失导致对端把我们的首 4 字节当串头吞掉（SFTP 首包即毁）}
      LW.PutUInt32(UInt32(LTake));
      LW.PutRaw(LChunk);
      TracePkt('tx', LW.ToBytes);
      FTransport.SendPacket(LW.ToBytes);
    finally
      LW.Free;
    end;
    Inc(LOff, LTake);
    Dec(FPeerWindow, LTake);
  end;
end;

function TSshChannel.PumpData(out AData: TBytes; out AExtended: Boolean): Boolean;
begin
  if InboxPop(AData, AExtended) then
    Exit(True);
  while not FGotClose do
  begin
    if PumpRaw(AData, AExtended) then
      Exit(True);
  end;
  Result := False;
end;

procedure TSshChannel.Close;
begin
  if FSentClose then
    Exit;
  try
    FTransport.SendPacket(EofPayload(FRemoteId));
    TracePkt('tx', ClosePayload(FRemoteId));
    FTransport.SendPacket(ClosePayload(FRemoteId));
    FSentClose := True;
  except
    { 清理路径：对端可能已消失 }
  end;
end;

procedure TSshChannel.TryClose;
begin
  Close;
end;

destructor TSshChannel.Destroy;
begin
  TryClose;
  inherited Destroy;
end;

{ TChannelStream }

constructor TChannelStream.Create(AChannel: TSshChannel);
begin
  inherited Create;
  if AChannel = nil then
    raise ESSHError.Create(sekProtocol, 'ChannelStream: nil channel');
  FChannel := AChannel;
end;

destructor TChannelStream.Destroy;
begin
  try Close; except end;
  FChannel.Free;
  inherited;
end;

function TChannelStream.Read(var ABuffer; const ACount: SizeUInt): SizeUInt;
var
  LData: TBytes;
  LExt: Boolean;
  LAvail, LCopy: SizeUInt;
begin
  if FClosed then Exit(0);
  if ACount = 0 then Exit(0);
  if (FBuf <> nil) and (FBufPos < SizeUInt(Length(FBuf))) then
  begin
    LAvail := SizeUInt(Length(FBuf)) - FBufPos;
    LCopy := LAvail;
    if LCopy > ACount then LCopy := ACount;
    Move(FBuf[FBufPos], ABuffer, LCopy);
    Inc(FBufPos, LCopy);
    if FBufPos >= SizeUInt(Length(FBuf)) then
    begin
      SetLength(FBuf, 0);
      FBufPos := 0;
    end;
    Result := LCopy;
    Exit;
  end;
  SetLength(FBuf, 0);
  FBufPos := 0;
  if not FChannel.PumpData(LData, LExt) then Exit(0);
  if LExt then Exit(0);
  if Length(LData) = 0 then Exit(0);
  if SizeUInt(Length(LData)) <= ACount then
  begin
    Move(LData[0], ABuffer, SizeUInt(Length(LData)));
    Result := SizeUInt(Length(LData));
    Exit;
  end;
  Move(LData[0], ABuffer, ACount);
  FBuf := Copy(LData, ACount, Length(LData) - Integer(ACount));
  FBufPos := 0;
  Result := ACount;
end;

function TChannelStream.Write(const ABuffer; const ACount: SizeUInt): SizeUInt;
var
  LBytes: TBytes;
begin
  if FClosed then
    raise ESSHError.Create(sekIO, 'ChannelStream: closed');
  if ACount = 0 then Exit(0);
  SetLength(LBytes, ACount);
  Move(ABuffer, LBytes[0], ACount);
  FChannel.SendData(LBytes);
  Result := ACount;
end;

procedure TChannelStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    try FChannel.Close; except end;
  end;
end;

{ ---- 高层入口 ---- }

function SshRunExec(ATransport: TSshClientTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer): TSshExecResult;
var
  LChan: TSshChannel;
  LChunk: TBytes;
  LExt: Boolean;
begin
  { 函数结果缓冲可能被调用方循环复用并残留上次的托管字段
    （实测：复用目标变量连续 Exec 时 StdOut 残留导致输出成倍累积），
    必须整体清零后再追加 }
  Result := Default(TSshExecResult);
  Result.ExitCode := -1;
  LChan := TSshChannel.Create(ATransport, AInitialWindow, AMaxPacket, ATimeoutMs);
  try
    try
      LChan.OpenSession;
      LChan.ExecCommand(ACommand);
      while LChan.PumpData(LChunk, LExt) do
        if LExt then
          AppendChunk(Result.StdErr, LChunk)
        else
          AppendChunk(Result.StdOut, LChunk);
      Result.ExitCode := LChan.ExitStatus;
    except
      { 通道异常时尽力互关，不掩盖原始错误 }
      on LE: ESSHError do
      begin
        LChan.TryClose;
        raise;
      end;
    end;
  finally
    LChan.Free;
  end;
end;

end.
