unit nextpas.core.ssh.channel.async;

{** nextpas.core.ssh - 异步单通道引擎 (exec)。
 *
 * 事件化重放 `channel.TSshChannel` 的 `OpenSession → Exec → PumpData → Close`
 * 链，复用同套载荷构造与窗口记账，仅 I/O 经 `TAsyncSshTransport` 事件化。
 * 单通道所有回调均在 `TAsyncLoop` 线程，`FWriteBuf` 保活与序列号与同步一致。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.loop,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport.async;

function SshAsyncRunExec(const ATransport: TAsyncSshTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer;
  ACallback: TProcSshExecResult; AContext: Pointer = nil): Boolean;

implementation

uses
  SysUtils,
  nextpas.core.async.base,
  nextpas.core.ssh.buffer;

const
  WINDOW_LOW_WATER_DIVISOR = 2;

var
  GNextAsyncChannelId: LongInt = 0;

type
  TExecState = (esOpening, esExecing, esPumping, esDone);

  TAsyncExecRunner = class
  private
    FTransport: TAsyncSshTransport;
    FLoop: TAsyncLoop;
    FCommand: string;
    FLocalId: UInt32;
    FRemoteId: UInt32;
    FInitWindow: UInt32;
    FMaxPacket: UInt32;
    FOurWindow: SizeUInt;
    FPeerWindow: SizeUInt;
    FPeerMaxPacket: UInt32;
    FExitStatus: Integer;
    FGotClose: Boolean;
    FSentClose: Boolean;
    FResult: TSshExecResult;
    FCallback: TProcSshExecResult;
    FCallbackCtx: Pointer;
    FState: TExecState;
    FDeadline: TDeadline;
    FTimer: TAsyncTimerHandle;
    FFailed: Boolean;
    procedure Fail(AErr: ESSHError);
    procedure Succeed;
    procedure SendOpen;
    procedure OnOpenSent(AErr: ESSHError; AContext: Pointer);
    procedure OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure HandleOpenPacket(const APayload: TBytes);
    procedure HandleExecPacket(const APayload: TBytes);
    procedure HandlePumpPacket(const APayload: TBytes);
    procedure SendExec;
    procedure OnExecSent(AErr: ESSHError; AContext: Pointer);
    procedure PumpNext;
    procedure AccountConsume(ACount: SizeUInt);
    procedure SendWindowAdjust(ACount: UInt32);
    procedure HandleChannelRequest(const APayload: TBytes);
    procedure HandleGlobalRequest;
    function ExtractData(const APayload: TBytes; AExtended: Boolean; out AChunk: TBytes): Boolean;
    procedure TryCloseChannel;
    procedure OnTimeout(AContext: Pointer);
  public
    constructor Create(const ATransport: TAsyncSshTransport; const ACommand: string;
      AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer;
      ACallback: TProcSshExecResult; AContext: Pointer);
    procedure Start;
  end;

procedure Runner_OnOpenSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_OnExecSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_OnTimeout(AContext: Pointer); forward;

{ Helpers }

procedure AppendChunkAsync(var ADst: TBytes; const ASrc: TBytes);
var LOld: SizeUInt;
begin
  if Length(ASrc)=0 then Exit;
  LOld := SizeUInt(Length(ADst));
  SetLength(ADst, LOld + SizeUInt(Length(ASrc)));
  Move(ASrc[0], ADst[LOld], SizeUInt(Length(ASrc)));
end;

constructor TAsyncExecRunner.Create(const ATransport: TAsyncSshTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer;
  ACallback: TProcSshExecResult; AContext: Pointer);
begin
  inherited Create;
  FTransport := ATransport;
  if FTransport <> nil then
    FLoop := FTransport.Loop;
  FCommand := ACommand;
  FCallback := ACallback;
  FCallbackCtx := AContext;
  FLocalId := UInt32(InterlockedIncrement(GNextAsyncChannelId) - 1);
  FInitWindow := AInitialWindow;
  if FInitWindow=0 then FInitWindow := SSH_DEFAULT_WINDOW_SIZE;
  FMaxPacket := AMaxPacket;
  if FMaxPacket=0 then FMaxPacket := SSH_DEFAULT_MAX_PACKET;
  FOurWindow := FInitWindow;
  FPeerWindow := 0;
  FPeerMaxPacket := 0;
  FExitStatus := -1;
  FResult := Default(TSshExecResult);
  FResult.ExitCode := -1;
  FState := esOpening;
  if ATimeoutMs > 0 then
    FDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    FDeadline := TDeadline.Infinite;
  FTimer := Default(TAsyncTimerHandle);
end;

procedure TAsyncExecRunner.Start;
begin
  if FTransport=nil then begin Fail(ESSHError.Create(sekProtocol,'async channel: nil transport')); Exit; end;
  if not FDeadline.IsInfinite then
    FTimer := FLoop.ScheduleAt(FDeadline, @Runner_OnTimeout, Self);
  SendOpen;
end;

procedure TAsyncExecRunner.Fail(AErr: ESSHError);
var Cb: TProcSshExecResult; Ctx: Pointer; Res: TSshExecResult;
begin
  if FFailed then begin if AErr<>nil then AErr.Free; Exit; end;
  FFailed := True;
  if FTimer.IsValid then begin FLoop.CancelTimer(FTimer); FTimer:=Default(TAsyncTimerHandle); end;
  try TryCloseChannel; except end;
  Cb := FCallback; Ctx := FCallbackCtx; Res := FResult;
  FCallback := nil;
  if Assigned(Cb) then Cb(Res, AErr, Ctx) else if AErr<>nil then AErr.Free;
  Free;
end;

procedure TAsyncExecRunner.Succeed;
var Cb: TProcSshExecResult; Ctx: Pointer;
begin
  if FFailed then Exit;
  FFailed := True;
  if FTimer.IsValid then begin FLoop.CancelTimer(FTimer); FTimer:=Default(TAsyncTimerHandle); end;
  FResult.ExitCode := FExitStatus;
  Cb := FCallback; Ctx := FCallbackCtx;
  FCallback := nil;
  if Assigned(Cb) then Cb(FResult, nil, Ctx);
  Free;
end;

procedure TAsyncExecRunner.SendOpen;
var LW: TsshWriter;
begin
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_CHANNEL_OPEN);
    LW.PutStringText(SSH_CHANNEL_SESSION);
    LW.PutUInt32(FLocalId);
    LW.PutUInt32(FInitWindow);
    LW.PutUInt32(FMaxPacket);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_OnOpenSent, Self) then
      Fail(ESSHError.Create(sekIO,'async channel: open send failed'));
  finally LW.Free; end;
end;

procedure TAsyncExecRunner.OnOpenSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  PumpNext;
end;

procedure TAsyncExecRunner.SendExec;
var LW: TsshWriter; LTail: TBytes;
begin
  LTail := nil;
  LW := TsshWriter.Create(64);
  try
    LW.PutStringText(FCommand);
    LTail := LW.ToBytes;
  finally LW.Free; end;
  LW := TsshWriter.Create(64 + Length(LTail));
  try
    LW.PutByte(SSH_MSG_CHANNEL_REQUEST);
    LW.PutUInt32(FRemoteId);
    LW.PutStringText(SSH_REQ_EXEC);
    LW.PutBoolean(True);
    LW.PutRaw(LTail);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_OnExecSent, Self) then
      Fail(ESSHError.Create(sekIO,'async channel: exec send failed'));
  finally LW.Free; end;
end;

procedure TAsyncExecRunner.OnExecSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  PumpNext;
end;

procedure TAsyncExecRunner.PumpNext;
begin
  if FState=esDone then Exit;
  if not FTransport.AsyncReadPacket(@Runner_OnPacket, Self) then
    Fail(ESSHError.Create(sekIO,'async channel: read submit failed'));
end;

procedure TAsyncExecRunner.OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol,'async channel: empty packet')); Exit; end;
  case FState of
    esOpening: HandleOpenPacket(APayload);
    esExecing: HandleExecPacket(APayload);
    esPumping: HandlePumpPacket(APayload);
  else
    PumpNext;
  end;
end;

procedure TAsyncExecRunner.HandleOpenPacket(const APayload: TBytes);
var LR: TsshReader; LRid: UInt32; LChunk: TBytes; IsExt: Boolean;
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_OPEN_CONFIRMATION:
      begin
        LR := TsshReader.Create(APayload);
        try
          LR.ReadByte;
          LRid := LR.ReadUInt32;
          if LRid<>FLocalId then begin PumpNext; Exit; end;
          FRemoteId := LR.ReadUInt32;
          FPeerWindow := LR.ReadUInt32;
          FPeerMaxPacket := LR.ReadUInt32;
        finally LR.Free; end;
        FOurWindow := FInitWindow;
        FState := esExecing;
        SendExec;
      end;
    SSH_MSG_CHANNEL_OPEN_FAILURE:
      Fail(ESSHError.Create(sekProtocol,'async channel: open refused'));
    SSH_MSG_GLOBAL_REQUEST:
      begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin
        LR := TsshReader.Create(APayload);
        try
          LR.ReadByte; LRid:=LR.ReadUInt32;
          if LRid=FLocalId then
            FPeerWindow := FPeerWindow + LR.ReadUInt32();
        finally LR.Free; end;
        PumpNext;
      end;
    SSH_MSG_CHANNEL_DATA, SSH_MSG_CHANNEL_EXTENDED_DATA:
      begin
        IsExt := APayload[0]=SSH_MSG_CHANNEL_EXTENDED_DATA;
        if ExtractData(APayload, IsExt, LChunk) then
        begin
          if IsExt then AppendChunkAsync(FResult.StdErr, LChunk)
          else AppendChunkAsync(FResult.StdOut, LChunk);
        end;
        PumpNext;
      end;
  else
    // stale or transparent → ignore and continue
    PumpNext;
  end;
end;

procedure TAsyncExecRunner.HandleExecPacket(const APayload: TBytes);
var LChunk: TBytes;
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_SUCCESS:
      begin
        FState := esPumping;
        // drain inbox if any – already appended to result during HandleOpen?
        PumpNext;
      end;
    SSH_MSG_CHANNEL_FAILURE:
      Fail(ESSHError.Create(sekProtocol,'async channel: exec refused'));
    SSH_MSG_CHANNEL_DATA:
      begin
        if ExtractData(APayload, False, LChunk) then
          AppendChunkAsync(FResult.StdOut, LChunk);
        PumpNext;
      end;
    SSH_MSG_CHANNEL_EXTENDED_DATA:
      begin
        if ExtractData(APayload, True, LChunk) then
          AppendChunkAsync(FResult.StdErr, LChunk);
        PumpNext;
      end;
    SSH_MSG_CHANNEL_REQUEST:
      begin HandleChannelRequest(APayload); PumpNext; end;
    SSH_MSG_GLOBAL_REQUEST:
      begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin
        // update peer window
        with TsshReader.Create(APayload) do
        try
          ReadByte; if ReadUInt32=FLocalId then FPeerWindow:=FPeerWindow+ReadUInt32();
        finally Free; end;
        PumpNext;
      end;
    SSH_MSG_CHANNEL_EOF, SSH_MSG_CHANNEL_CLOSE:
      begin
        // server closed before exec reply – treat as done
        FGotClose := True;
        TryCloseChannel;
        Succeed;
      end;
  else
    PumpNext;
  end;
end;

procedure TAsyncExecRunner.HandlePumpPacket(const APayload: TBytes);
var LChunk: TBytes;
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_DATA:
      begin
        if ExtractData(APayload, False, LChunk) then
          AppendChunkAsync(FResult.StdOut, LChunk);
        PumpNext;
      end;
    SSH_MSG_CHANNEL_EXTENDED_DATA:
      begin
        if ExtractData(APayload, True, LChunk) then
          AppendChunkAsync(FResult.StdErr, LChunk);
        PumpNext;
      end;
    SSH_MSG_CHANNEL_REQUEST:
      begin HandleChannelRequest(APayload); PumpNext; end;
    SSH_MSG_GLOBAL_REQUEST:
      begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin
        with TsshReader.Create(APayload) do
        try
          ReadByte; if ReadUInt32=FLocalId then FPeerWindow:=FPeerWindow+ReadUInt32();
        finally Free; end;
        PumpNext;
      end;
    SSH_MSG_CHANNEL_EOF:
      PumpNext;
    SSH_MSG_CHANNEL_CLOSE:
      begin
        FGotClose := True;
        TryCloseChannel;
        Succeed;
      end;
    SSH_MSG_CHANNEL_SUCCESS, SSH_MSG_CHANNEL_FAILURE:
      PumpNext;
  else
    PumpNext;
  end;
end;

function TAsyncExecRunner.ExtractData(const APayload: TBytes; AExtended: Boolean; out AChunk: TBytes): Boolean;
var LR: TsshReader; LRid, LType: UInt32;
begin
  Result := False; AChunk := nil;
  LR := TsshReader.Create(APayload);
  try
    LR.ReadByte;
    LRid := LR.ReadUInt32;
    if LRid<>FLocalId then Exit;
    if AExtended then
    begin
      LType := LR.ReadUInt32;
      AChunk := LR.ReadStringBytes;
      if Length(AChunk)=0 then Exit;
      if LType<>SSH_EXTENDED_DATA_STDERR then
      begin AccountConsume(SizeUInt(Length(AChunk))); Exit(False); end;
    end
    else
      AChunk := LR.ReadStringBytes;
  finally LR.Free; end;
  if Length(AChunk)=0 then Exit;
  AccountConsume(SizeUInt(Length(AChunk)));
  Result := True;
end;

procedure TAsyncExecRunner.AccountConsume(ACount: SizeUInt);
var LGive: SizeUInt;
begin
  if ACount > FOurWindow then
  begin LGive := FOurWindow; FOurWindow:=0; end
  else begin Dec(FOurWindow, ACount); LGive:=0; end;
  if FOurWindow <= SizeUInt(FInitWindow) div WINDOW_LOW_WATER_DIVISOR then
  begin Inc(LGive, SizeUInt(FInitWindow)-FOurWindow); FOurWindow:=FInitWindow; end;
  if LGive>0 then SendWindowAdjust(UInt32(LGive));
end;

procedure TAsyncExecRunner.SendWindowAdjust(ACount: UInt32);
var LW: TsshWriter;
begin
  LW := TsshWriter.Create(16);
  try
    LW.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST);
    LW.PutUInt32(FRemoteId);
    LW.PutUInt32(ACount);
    FTransport.AsyncSendPacket(LW.ToBytes, nil, nil);
  finally LW.Free; end;
end;

procedure TAsyncExecRunner.HandleChannelRequest(const APayload: TBytes);
var LR: TsshReader; LName: string; LWant: Boolean;
begin
  LR := TsshReader.Create(APayload);
  try
    LR.ReadByte; LR.ReadUInt32; LName:=LR.ReadStringText; LWant:=LR.ReadBoolean;
    if LName=SSH_REQ_EXIT_STATUS then
    begin
      FExitStatus := Integer(LR.ReadUInt32);
      if LWant then
        FTransport.AsyncSendPacket(ChannelReplyPayload(FRemoteId, True), nil, nil);
    end
    else if LWant then
      FTransport.AsyncSendPacket(ChannelReplyPayload(FRemoteId, False), nil, nil);
  finally LR.Free; end;
end;

procedure TAsyncExecRunner.HandleGlobalRequest;
begin
  FTransport.AsyncSendPacket(GlobalReplyPayload(False), nil, nil);
end;

procedure TAsyncExecRunner.TryCloseChannel;
begin
  if FSentClose then Exit;
  try
    FTransport.AsyncSendPacket(EofPayload(FRemoteId), nil, nil);
    FTransport.AsyncSendPacket(ClosePayload(FRemoteId), nil, nil);
    FSentClose := True;
  except end;
end;

procedure TAsyncExecRunner.OnTimeout(AContext: Pointer);
begin
  Fail(ESSHError.Create(sekTimeout,'async channel: exec timeout'));
end;

{ Runner free dispatchers }

procedure Runner_OnOpenSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncExecRunner(AContext).OnOpenSent(AErr, nil); end;

procedure Runner_OnExecSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncExecRunner(AContext).OnExecSent(AErr, nil); end;

procedure Runner_OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncExecRunner(AContext).OnPacket(APayload, AErr, nil); end;

procedure Runner_OnTimeout(AContext: Pointer);
begin TAsyncExecRunner(AContext).OnTimeout(nil); end;

{ Public }

function SshAsyncRunExec(const ATransport: TAsyncSshTransport; const ACommand: string;
  AInitialWindow, AMaxPacket: UInt32; ATimeoutMs: Integer;
  ACallback: TProcSshExecResult; AContext: Pointer): Boolean;
var R: TAsyncExecRunner;
begin
  if (ATransport=nil) or (ACommand='') or not Assigned(ACallback) then Exit(False);
  R := TAsyncExecRunner.Create(ATransport, ACommand, AInitialWindow, AMaxPacket, ATimeoutMs, ACallback, AContext);
  R.Start;
  Result := True;
end;

end.
