unit nextpas.core.ssh.channel;

{** nextpas.core.ssh - 连接协议通道（RFC 4254）。
 *
 * 当前提供一次性 exec 的高层封装 SshRunExec：
 *   open session → exec request → 收集 stdout/stderr/exit-status → close。
 * 窗口流量控制按 RFC 4254 §5.2 做"消费过半即回补"。
 *
 * 多路复用通道与交互式 pty 属后续 slice；届时在 PumpMessage 消息泵之上抽
 * TSshChannel 对象，本单元的载荷构造函数直接复用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
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

{ 在已认证的传输上执行一次性命令并阻塞收集输出。
  ATimeoutMs <= 0 表示无限等待。}
function SshRunExec(ATransport: TSshClientTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer): TSshExecResult;

{ 读下一条"非透明"消息：跳过 IGNORE/DEBUG/UNIMPLEMENTED/EXT_INFO/BANNER；
  DISCONNECT 抛 sekDisconnect 并带描述。公开供 session 层认证流程复用。}
function PumpMessage(ATransport: TSshClientTransport): TBytes;

{ 常用通道载荷构造（复用点：多路复用通道 slice）}
function EofPayload(ARemoteId: UInt32): TBytes;
function ClosePayload(ARemoteId: UInt32): TBytes;
function ChannelReplyPayload(ARemoteId: UInt32; AOk: Boolean): TBytes;
function GlobalReplyPayload(AOk: Boolean): TBytes;
procedure AppendChunk(var ADst: TBytes; const ASrc: TBytes);

implementation

uses
  nextpas.core.time.stopwatch;

function TSshExecResult.StdOutText: string;
begin
  Result := SshTextFromBytes(StdOut);
end;

function TSshExecResult.StdErrText: string;
begin
  Result := SshTextFromBytes(StdErr);
end;

const
  LOCAL_CHANNEL_ID = 0;          { 一次性会话只用一个本地通道号 }
  WINDOW_LOW_WATER_DIVISOR = 2;  { 消费过半即回补 }

{ ---- 载荷构造 ---- }

procedure AppendChunk(var ADst: TBytes; const ASrc: TBytes);
var
  LOld: SizeUInt;
begin
  if Length(ASrc) = 0 then
    Exit;
  LOld := SizeUInt(Length(ADst));
  SetLength(ADst, LOld + SizeUInt(Length(ASrc)));
  Move(ASrc[0], ADst[LOld], SizeUInt(Length(ASrc)));
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
  LR: TsshReader;
  LDesc: TBytes;
begin
  while True do
  begin
    Result := ATransport.ReadPacket;
    if Length(Result) = 0 then
      raise ESSHError.Create(sekProtocol, 'ssh channel: empty packet');
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

{ ---- exec 状态机 ---- }

type
  TSshExecRun = class
  private
    FTransport: TSshClientTransport;
    FRemoteId: UInt32;
    FRemoteWindow: UInt32;       { 服务方声明的接收窗口 }
    FConsumed: SizeUInt;         { 已消费未回补字节 }
    FGotExitStatus: Boolean;
    FSentClose: Boolean;
    FDone: Boolean;
    FExitCode: Integer;
    FStdOut: TBytes;
    FStdErr: TBytes;
    FDeadlineMs: Integer;
    FWatch: TStopwatch;
    FInitWindow: UInt32;
    FMaxPacket: UInt32;
    procedure SendChannelRequest(const AName: string; const APayloadTail: TBytes);
    procedure SendWindowAdjust(ACount: UInt32);
    procedure AccountConsume(ACount: SizeUInt);
    procedure HandleData(AExtended: Boolean; const APayload: TBytes);
    procedure HandleChannelRequest(const APayload: TBytes);
    procedure HandleGlobalRequest;
    function TimedOut: Boolean;
  public
    constructor Create(ATransport: TSshClientTransport;
      AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer);

    procedure OpenSession;
    procedure ExecCommand(const ACommand: string);
    procedure PumpUntilDone;
    function BuildResult: TSshExecResult;
    { 尽力互关（异常清理路径，吞 IO 异常）}
    procedure TryClose;
  end;

constructor TSshExecRun.Create(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer);
begin
  inherited Create;
  FTransport := ATransport;
  FRemoteId := 0;
  FRemoteWindow := 0;
  FExitCode := -1;
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

function TSshExecRun.TimedOut: Boolean;
begin
  Result := (FDeadlineMs > 0) and (FWatch.ElapsedMilliseconds > FDeadlineMs);
end;

procedure TSshExecRun.OpenSession;
var
  LW: TsshWriter;
  LR: TsshReader;
  LMsg: TBytes;
  LLc: UInt32;
begin
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_CHANNEL_OPEN);
    LW.PutStringText(SSH_CHANNEL_SESSION);
    LW.PutUInt32(LOCAL_CHANNEL_ID);
    LW.PutUInt32(FInitWindow);
    LW.PutUInt32(FMaxPacket);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;

  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout opening session');
    LMsg := PumpMessage(FTransport);
    case LMsg[0] of
      SSH_MSG_CHANNEL_OPEN_CONFIRMATION:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LLc := LR.ReadUInt32;
            if LLc <> LOCAL_CHANNEL_ID then
              Continue;
            FRemoteId := LR.ReadUInt32;
            FRemoteWindow := LR.ReadUInt32;
          finally
            LR.Free;
          end;
          Exit;
        end;
      SSH_MSG_CHANNEL_OPEN_FAILURE:
        raise ESSHError.Create(sekProtocol, 'ssh channel: session open refused');
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshExecRun.SendChannelRequest(const AName: string;
  const APayloadTail: TBytes);
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
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

procedure TSshExecRun.ExecCommand(const ACommand: string);
var
  LTail: TsshWriter;
  LMsg: TBytes;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(ACommand);
    SendChannelRequest(SSH_REQ_EXEC, LTail.ToBytes);
  finally
    LTail.Free;
  end;

  { 等 exec 应答；期间混入的数据帧交给 HandleData 缓存而非丢弃 }
  while True do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout waiting exec reply');
    LMsg := PumpMessage(FTransport);
    case LMsg[0] of
      SSH_MSG_CHANNEL_SUCCESS:
        Exit;
      SSH_MSG_CHANNEL_FAILURE:
        raise ESSHError.Create(sekProtocol, 'ssh channel: exec refused by server');
      SSH_MSG_CHANNEL_DATA:
        HandleData(False, LMsg);
      SSH_MSG_CHANNEL_EXTENDED_DATA:
        HandleData(True, LMsg);
      SSH_MSG_CHANNEL_EOF:
        ; { EOF 细节留给收集阶段 }
      SSH_MSG_CHANNEL_CLOSE:
        begin
          FTransport.SendPacket(ClosePayload(FRemoteId));
          FSentClose := True;
          FDone := True;
          Exit;
        end;
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
    end;
  end;
end;

procedure TSshExecRun.SendWindowAdjust(ACount: UInt32);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(16);
  try
    LW.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST);
    LW.PutUInt32(FRemoteId);
    LW.PutUInt32(ACount);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

procedure TSshExecRun.AccountConsume(ACount: SizeUInt);
var
  LGiveBack: UInt32;
begin
  Inc(FConsumed, ACount);
  if (FRemoteWindow <> 0)
    and (FConsumed >= SizeUInt(FRemoteWindow) div WINDOW_LOW_WATER_DIVISOR) then
  begin
    LGiveBack := UInt32(FConsumed);
    FConsumed := 0;
    SendWindowAdjust(LGiveBack);
  end;
end;

procedure TSshExecRun.HandleData(AExtended: Boolean; const APayload: TBytes);
var
  LR: TsshReader;
  LRid, LDataType: UInt32;
  LChunk: TBytes;
begin
  LDataType := 0;
  LR := TsshReader.Create(APayload);
  try
    LR.ReadByte;
    LRid := LR.ReadUInt32;
    if LRid <> FRemoteId then
      Exit;
    if AExtended then
    begin
      LDataType := LR.ReadUInt32;
      LChunk := LR.ReadStringBytes;
    end
    else
      LChunk := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
  { 仅 stderr 走扩展通道；未知扩展类型丢弃但计入窗口 }
  if Length(LChunk) = 0 then
    Exit;
  if AExtended and (LDataType = SSH_EXTENDED_DATA_STDERR) then
    AppendChunk(FStdErr, LChunk)
  else if not AExtended then
    AppendChunk(FStdOut, LChunk);
  AccountConsume(SizeUInt(Length(LChunk)));
end;

procedure TSshExecRun.HandleChannelRequest(const APayload: TBytes);
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
      FExitCode := Integer(LR.ReadUInt32);
      FGotExitStatus := True;
      if LWantReply then
        FTransport.SendPacket(ChannelReplyPayload(FRemoteId, True));
    end
    else if LWantReply then
      FTransport.SendPacket(ChannelReplyPayload(FRemoteId, False));
  finally
    LR.Free;
  end;
end;

procedure TSshExecRun.HandleGlobalRequest;
begin
  { want_reply 的未知全局请求必须回应 FAILURE（RFC 4254 §4）}
  FTransport.SendPacket(GlobalReplyPayload(False));
end;

procedure TSshExecRun.PumpUntilDone;
var
  LMsg: TBytes;
begin
  while not FDone do
  begin
    if TimedOut then
      raise ESSHError.Create(sekTimeout, 'ssh channel: timeout collecting output');
    LMsg := PumpMessage(FTransport);
    case LMsg[0] of
      SSH_MSG_CHANNEL_DATA:
        HandleData(False, LMsg);
      SSH_MSG_CHANNEL_EXTENDED_DATA:
        HandleData(True, LMsg);
      SSH_MSG_CHANNEL_EOF:
        ; { 等 CLOSE 或 exit-status 收尾 }
      SSH_MSG_CHANNEL_WINDOW_ADJUST:
        ; { 我方几乎不发送，忽略对端回补帧 }
      SSH_MSG_CHANNEL_REQUEST:
        HandleChannelRequest(LMsg);
      SSH_MSG_GLOBAL_REQUEST:
        HandleGlobalRequest;
      SSH_MSG_CHANNEL_CLOSE:
        begin
          if not FSentClose then
          begin
            FTransport.SendPacket(ClosePayload(FRemoteId));
            FSentClose := True;
          end;
          FDone := True;
        end;
    end;
  end;

  { 礼貌性 EOF + 关闭（若尚未互关）}
  if not FSentClose then
  begin
    FTransport.SendPacket(EofPayload(FRemoteId));
    FTransport.SendPacket(ClosePayload(FRemoteId));
    FSentClose := True;
  end;
end;

function TSshExecRun.BuildResult: TSshExecResult;
begin
  Result.ExitCode := FExitCode;
  Result.StdOut := FStdOut;
  Result.StdErr := FStdErr;
end;

procedure TSshExecRun.TryClose;
begin
  if FSentClose then
    Exit;
  try
    FTransport.SendPacket(EofPayload(FRemoteId));
    FTransport.SendPacket(ClosePayload(FRemoteId));
    FSentClose := True;
  except
    { 清理路径：对端可能已消失 }
  end;
end;

{ ---- 高层入口 ---- }

function SshRunExec(ATransport: TSshClientTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer): TSshExecResult;
var
  LRun: TSshExecRun;
begin
  LRun := TSshExecRun.Create(ATransport, AInitialWindow, AMaxPacket, ATimeoutMs);
  try
    LRun.OpenSession;
    try
      LRun.ExecCommand(ACommand);
      LRun.PumpUntilDone;
    except
      { 通道异常时尽力互关，不掩盖原始错误 }
      on LE: ESSHError do
      begin
        LRun.TryClose;
        raise;
      end;
    end;
    Result := LRun.BuildResult;
  finally
    LRun.Free;
  end;
end;

end.
