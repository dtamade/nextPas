unit nextpas.core.ssh.sftp.async;

{** nextpas.core.ssh - SFTP v3 异步门面 (TAsyncLoop + TAsyncSshTransport)。
 *
 * 复用 sftp.pas 的包构造与属性编解码，仅 I/O 事件化。
 * 单通道复用：open session → subsystem sftp → INIT/VERSION → 流水线 RoundTrip (SFTP_PIPELINE_WINDOW=16)。
 * 窗口按 exec 同款“消费过半回补”策略，SFTP 流按 4 字节长度前缀重组。
 * 流水线乱序缓冲；窗口满时回调 sekBusy，几何倍增与 bytes.ops 单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.loop,
  nextpas.core.async.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.sftp,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport.async,
  nextpas.core.ssh.session.async;

type
  ISshAsyncFileSystem = interface;
  TProcSftpOpenAsync = procedure(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer);
  TProcSftpStat = procedure(const AAttrs: TSftpAttrs; AErr: ESSHError; AContext: Pointer);
  TProcSftpRealPath = procedure(const APath: string; AErr: ESSHError; AContext: Pointer);
  TProcSftpDirList = procedure(const AEntries: TSftpDirEntryArray; AErr: ESSHError; AContext: Pointer);
  TProcSftpData = procedure(const AData: TBytes; AErr: ESSHError; AContext: Pointer);
  TProcSftpVoid = procedure(AErr: ESSHError; AContext: Pointer);

  ISshAsyncFileSystem = interface
    ['{9C1E6E10-4A11-4F72-9D30-5B0000000010}']
    function RealPathAsync(const APath: string; ACallback: TProcSftpRealPath; AContext: Pointer = nil): Boolean;
    function StatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer = nil): Boolean;
    function LstatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer = nil): Boolean;
    function ListDirAsync(const APath: string; ACallback: TProcSftpDirList; AContext: Pointer = nil): Boolean;
    function ReadFileAsync(const APath: string; ACallback: TProcSftpData; AContext: Pointer = nil): Boolean;
    function WriteFileAsync(const APath: string; const AData: TBytes; ACallback: TProcSftpVoid; AContext: Pointer = nil): Boolean;
    function RemoveAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer = nil): Boolean;
    function MkdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer = nil): Boolean;
    function RmdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer = nil): Boolean;
    function RenameAsync(const AOldPath, ANewPath: string; ACallback: TProcSftpVoid; AContext: Pointer = nil): Boolean;
    procedure Close;
  end;

function SshAsyncOpenSftp(const ASession: ISshAsyncSession; ACallback: TProcSftpOpenAsync; AContext: Pointer = nil): Boolean;
function SshAsyncOpenSftpEx(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer = nil): Boolean;
function SshAsyncSftpViaJumpOn(const ALoop: TAsyncLoop; const AJumpSession: ISshAsyncSession; const ATargetOpts: TSshConnectOptions; ACallback: TProcSftpOpenAsync; AContext: Pointer = nil): Boolean;
function SshAsyncSftpViaJump(const ALoop: TAsyncLoop; const AJumpOpts, ATargetOpts: TSshConnectOptions; ACallback: TProcSftpOpenAsync; AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.text.conv,
  nextpas.core.crypto.random,
  nextpas.core.ssh.window;

type
  TAsyncSftpState = (asOpening, asSubsystem, asHandshake, asReady, asClosed, asFailed);
  TProcSftpRaw = procedure(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
  TPendingSftp = record
    Id: UInt32;
    Accept: array of Byte;
    Cb: TProcSftpRaw;
    Ctx: Pointer;
  end;

  TAsyncSftpChannel = class
  private
    FLoop: TAsyncLoop;
    FTransport: TAsyncSshTransport;
    FSession: ISshAsyncSession;
    FLocalId: UInt32;
    FRemoteId: UInt32;
    FWindow: TChannelWindow; { 单源复用 window.pas inline，零堆分配 }
    FMaxPacket: UInt32;
    FState: TAsyncSftpState;
    FFailed: Boolean;
    FSentClose: Boolean;
    FDeadline: TDeadline;
    FTimer: TAsyncTimerHandle;
    FReadBuf: IBytesBuilder; // perf: doubling single source bytes.builder (BYTES_BUILDER_MIN_GROW=64, 2×), inline zero-copy, amortized O(1), avoid O(n²)
    FNextId: UInt32;
    FOpenCb: TProcSftpOpenAsync;
    FOpenCtx: Pointer;
    FOwnerFs: Pointer;
    // pending RoundTrip pipeline SFTP_PIPELINE_WINDOW (bytes.ops single source doubling, inline zero-copy)
    FPending: array of TPendingSftp;
    FOpTimer: TAsyncTimerHandle;
    FOpDeadline: TDeadline;
    procedure Fail(AErr: ESSHError);
    procedure SucceedOpen(AFs: ISshAsyncFileSystem);
    procedure SendOpen;
    procedure OnOpenSent(AErr: ESSHError; AContext: Pointer);
    procedure OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure HandleOpenPacket(const APayload: TBytes);
    procedure HandleSubsystemPacket(const APayload: TBytes);
    procedure HandleReadyPacket(const APayload: TBytes);
    procedure SendSubsystem;
    procedure OnSubsystemSent(AErr: ESSHError; AContext: Pointer);
    procedure SendSftpInit;
    procedure OnSftpInitSent(AErr: ESSHError; AContext: Pointer);
    procedure PumpNext;
    procedure AccountConsume(ACount: SizeUInt); inline;
    procedure SendWindowAdjust(ACount: UInt32);
    function ExtractSftpPacket(out APacket: TBytes): Boolean; inline;
    procedure TryDispatchSftp;
    procedure HandleChannelRequest(const APayload: TBytes);
    procedure HandleGlobalRequest;
    function ExtractData(const APayload: TBytes; AExtended: Boolean; out AChunk: TBytes): Boolean;
    procedure OnTimeout(AContext: Pointer);
    procedure OnOpTimeout(AContext: Pointer);
    function SftpRoundTripAsync(AType: Byte; const APayload: TBytes; const AAccept: array of Byte; ACb: TProcSftpRaw; AContext: Pointer): Boolean;
    procedure OnSftpSent(AErr: ESSHError; AContext: Pointer);
    procedure FailPending(AErr: ESSHError);
    function FindPendingIdx(AId: UInt32): Integer; inline;
    procedure RemovePendingIdx(AIdx: Integer);
    procedure FailAllPending(AErr: ESSHError);
  public
    constructor Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer); overload;
    constructor Create(const ALoop: TAsyncLoop; const ASession: ISshAsyncSession; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer); overload;
    destructor Destroy; override;
    procedure Start;
    procedure CloseChannel;
  end;

  TAsyncSftpFileSystem = class(TInterfacedObject, ISshAsyncFileSystem)
  private
    FChannel: TAsyncSftpChannel;
    FClosed: Boolean;
    // multi-step temp (ListDir accum geometric doubling, bytes.ops single source 16→2×, inline zero-copy)
    FListDirHandle: TBytes;
    FListDirAccum: TSftpDirEntryArray;
    FListDirCount: SizeUInt;
    FListDirCap: SizeUInt;
    FListDirPath: string;
    FListDirCb: TProcSftpDirList;
    FListDirCtx: Pointer;
    FReadHandle: TBytes;
    FReadPath: string;
    FReadOffset: UInt64;
    FReadAccum: TBytes;
    FReadBuilder: IBytesBuilder; // perf: doubling single source bytes.builder, inline zero-copy
    FReadCb: TProcSftpData;
    FReadCtx: Pointer;
    FWriteHandle: TBytes;
    FWritePath: string;
    FWriteData: TBytes;
    FWriteOff: SizeUInt;
    FWriteCb: TProcSftpVoid;
    FWriteCtx: Pointer;
    procedure DoListDirStep;
    procedure OnListDirOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnListDirRead(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnListDirClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnReadOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnReadChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnReadClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnWriteOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnWriteChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure OnWriteClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
  public
    constructor Create(AChannel: TAsyncSftpChannel);
    destructor Destroy; override;
    function RealPathAsync(const APath: string; ACallback: TProcSftpRealPath; AContext: Pointer): Boolean;
    function StatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer): Boolean;
    function LstatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer): Boolean;
    function ListDirAsync(const APath: string; ACallback: TProcSftpDirList; AContext: Pointer): Boolean;
    function ReadFileAsync(const APath: string; ACallback: TProcSftpData; AContext: Pointer): Boolean;
    function WriteFileAsync(const APath: string; const AData: TBytes; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
    function RemoveAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
    function MkdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
    function RmdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
    function RenameAsync(const AOldPath, ANewPath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
    procedure Close;
  end;

var
  GNextSftpChannelId: LongInt = 100;

procedure Runner_SftpOnOpenSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_SftpOnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_SftpOnSubsystemSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_SftpOnSftpInitSent(AErr: ESSHError; AContext: Pointer); forward;
procedure Runner_SftpOnTimeout(AContext: Pointer); forward;
procedure Runner_SftpOnOpTimeout(AContext: Pointer); forward;
procedure Runner_SftpOnSent(AErr: ESSHError; AContext: Pointer); forward;

{ Helpers }
// AppendChunkAsync removed: single source bytes.ops.BytesAppend inline; large accum via IBytesBuilder

function GlobalReplyPayload(AOk: Boolean): TBytes;
var LW: TsshWriter;
begin
  LW:=TsshWriter.Create(4);
  try if AOk then LW.PutByte(SSH_MSG_REQUEST_SUCCESS) else LW.PutByte(SSH_MSG_REQUEST_FAILURE); Result:=LW.ToBytes; finally LW.Free; end;
end;

function IsAcceptable(AType: Byte; const AList: array of Byte): Boolean;
var I: Integer;
begin
  for I:=0 to High(AList) do if AList[I]=AType then Exit(True);
  Result:=False;
end;

{ TAsyncSftpChannel }

constructor TAsyncSftpChannel.Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer);
begin
  inherited Create;
  FLoop := ALoop;
  FTransport := ATransport;
  FSession := nil;
  FLocalId := UInt32(InterlockedIncrement(GNextSftpChannelId)-1);
  FWindow.Init(2097152, 0, 0); { 单源 window.pas inline，零堆分配 }
  FMaxPacket := 32768;
  FState := asOpening;
  FOpenCb := ACallback;
  FOpenCtx := AContext;
  if ATimeoutMs>0 then FDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)) else FDeadline := TDeadline.Infinite;
  FNextId := 1;
  FReadBuf := CreateBytesBuilder(4096); // perf: doubling single source BYTES_BUILDER_MIN_GROW, amortized O(1)
end;

constructor TAsyncSftpChannel.Create(const ALoop: TAsyncLoop; const ASession: ISshAsyncSession; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer);
begin
  inherited Create;
  FLoop := ALoop;
  FSession := ASession;
  if ASession <> nil then FTransport := ASession.Transport else FTransport := nil;
  FLocalId := UInt32(InterlockedIncrement(GNextSftpChannelId)-1);
  FWindow.Init(2097152, 0, 0);
  FMaxPacket := 32768;
  FState := asOpening;
  FOpenCb := ACallback;
  FOpenCtx := AContext;
  if ATimeoutMs>0 then FDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)) else FDeadline := TDeadline.Infinite;
  FNextId := 1;
  FReadBuf := CreateBytesBuilder(4096); // perf: doubling single source BYTES_BUILDER_MIN_GROW, amortized O(1)
end;

destructor TAsyncSftpChannel.Destroy;
begin
  if FTimer.IsValid then try FLoop.CancelTimer(FTimer); except end;
  if FOpTimer.IsValid then try FLoop.CancelTimer(FOpTimer); except end;
  SetLength(FPending,0);
  FReadBuf := nil; // stability: release builder refcount, sized FreeMemOf via allocator
  FSession := nil;
  inherited;
end;

procedure TAsyncSftpChannel.Fail(AErr: ESSHError);
var Cb: TProcSftpOpenAsync; Ctx: Pointer;
begin
  if FFailed then begin if AErr<>nil then AErr.Free; Exit; end;
  FFailed := True;
  FState := asFailed;
  if FTimer.IsValid then begin FLoop.CancelTimer(FTimer); FTimer:=Default(TAsyncTimerHandle); end;
  if Length(FPending)>0 then FailAllPending(ESSHError.Create(sekIO,'sftp async: channel failed'));
  try CloseChannel; except end;
  Cb := FOpenCb; Ctx := FOpenCtx; FOpenCb := nil;
  if Assigned(Cb) then Cb(nil, AErr, Ctx) else if AErr<>nil then AErr.Free;
  if FOwnerFs=nil then Free;
end;

procedure TAsyncSftpChannel.FailPending(AErr: ESSHError);
begin
  FailAllPending(AErr);
end;

function TAsyncSftpChannel.FindPendingIdx(AId: UInt32): Integer; inline;
var I: Integer;
begin
  for I:=0 to High(FPending) do if FPending[I].Id=AId then Exit(I);
  Result:=-1;
end;

procedure TAsyncSftpChannel.RemovePendingIdx(AIdx: Integer);
var I, LLast: Integer;
begin
  if (AIdx<0) or (AIdx>High(FPending)) then Exit;
  LLast:=High(FPending);
  for I:=AIdx to LLast-1 do FPending[I]:=FPending[I+1];
  SetLength(FPending, LLast);
  if (Length(FPending)=0) and FOpTimer.IsValid then try FLoop.CancelTimer(FOpTimer); FOpTimer:=Default(TAsyncTimerHandle); except end;
end;

procedure TAsyncSftpChannel.FailAllPending(AErr: ESSHError);
var I: Integer; Cb: TProcSftpRaw; Ctx: Pointer; LFirst: Boolean;
begin
  if Length(FPending)=0 then begin if AErr<>nil then AErr.Free; Exit; end;
  if FOpTimer.IsValid then try FLoop.CancelTimer(FOpTimer); FOpTimer:=Default(TAsyncTimerHandle); except end;
  LFirst:=True;
  for I:=0 to High(FPending) do
  begin
    Cb:=FPending[I].Cb; Ctx:=FPending[I].Ctx;
    if LFirst then
    begin
      LFirst:=False;
      if Assigned(Cb) then Cb(nil, AErr, Ctx) else if AErr<>nil then AErr.Free;
      AErr:=nil;
    end else
    begin
      if Assigned(Cb) then Cb(nil, ESSHError.Create(sekIO,'sftp async: channel failed'), Ctx);
    end;
  end;
  SetLength(FPending,0);
  if AErr<>nil then AErr.Free;
end;

procedure TAsyncSftpChannel.SucceedOpen(AFs: ISshAsyncFileSystem);
var Cb: TProcSftpOpenAsync; Ctx: Pointer;
begin
  if FFailed then Exit;
  if FTimer.IsValid then begin FLoop.CancelTimer(FTimer); FTimer:=Default(TAsyncTimerHandle); end;
  Cb := FOpenCb; Ctx := FOpenCtx; FOpenCb := nil;
  FState := asReady;
  FOwnerFs := Pointer(AFs as TObject);
  if Assigned(Cb) then Cb(AFs, nil, Ctx);
end;

procedure TAsyncSftpChannel.Start;
begin
  if FTransport=nil then begin Fail(ESSHError.Create(sekProtocol,'sftp async: nil transport')); Exit; end;
  if not FDeadline.IsInfinite then
    try
      FTimer := FLoop.ScheduleAt(FDeadline, @Runner_SftpOnTimeout, Self);
    except
      on E: Exception do begin Fail(ESSHError.Create(sekIO, 'sftp async: schedule failed: '+E.Message)); Exit; end;
    end;
  SendOpen;
end;

procedure SftpChannelRetryOpen(AContext: Pointer);
begin TAsyncSftpChannel(AContext).SendOpen; end;

procedure TAsyncSftpChannel.SendOpen;
var LW: TsshWriter; Ok: Boolean;
begin
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_CHANNEL_OPEN);
    LW.PutStringText(SSH_CHANNEL_SESSION);
    LW.PutUInt32(FLocalId);
    LW.PutUInt32(FWindow.InitWindow);
    LW.PutUInt32(FMaxPacket);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_SftpOnOpenSent, Self) then
    begin
      try FLoop.ScheduleAt(TDeadline.After(TDuration.FromMilliseconds(5)), @SftpChannelRetryOpen, Self); except Fail(ESSHError.Create(sekIO,'sftp async: open send failed')) end;
    end;
  finally LW.Free; end;
end;

procedure TAsyncSftpChannel.OnOpenSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  PumpNext;
end;

procedure TAsyncSftpChannel.SendSubsystem;
var LW: TsshWriter; LTail: TBytes;
begin
  LTail := nil;
  LW := TsshWriter.Create(32);
  try LW.PutStringText('sftp'); LTail:=LW.ToBytes; finally LW.Free; end;
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_CHANNEL_REQUEST);
    LW.PutUInt32(FRemoteId);
    LW.PutStringText(SSH_REQ_SUBSYSTEM);
    LW.PutBoolean(True);
    LW.PutRaw(LTail);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_SftpOnSubsystemSent, Self) then
      Fail(ESSHError.Create(sekIO,'sftp async: subsystem send failed'));
  finally LW.Free; end;
end;

procedure TAsyncSftpChannel.OnSubsystemSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  PumpNext;
end;

procedure TAsyncSftpChannel.SendSftpInit;
var LW: TsshWriter; LInner, LOuter: TBytes;
begin
  LW := TsshWriter.Create(5);
  try LW.PutByte(SSH_FXP_INIT); LW.PutUInt32(3); LInner:=LW.ToBytes; finally LW.Free; end;
  LW := TsshWriter.Create(4+Length(LInner));
  try LW.PutUInt32(UInt32(Length(LInner))); LW.PutRaw(LInner); LOuter:=LW.ToBytes; finally LW.Free; end;
  LW := TsshWriter.Create(16+Length(LOuter));
  try
    LW.PutByte(SSH_MSG_CHANNEL_DATA);
    LW.PutUInt32(FRemoteId);
    LW.PutUInt32(UInt32(Length(LOuter)));
    LW.PutRaw(LOuter);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_SftpOnSftpInitSent, Self) then
      Fail(ESSHError.Create(sekIO,'sftp async: init send failed'));
  finally LW.Free; end;
end;

procedure TAsyncSftpChannel.OnSftpInitSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  PumpNext;
end;

procedure TAsyncSftpChannel.PumpNext;
begin
  if FState=asClosed then Exit;
  if FFailed then Exit;
  if not FTransport.AsyncReadPacket(@Runner_SftpOnPacket, Self) then
    Fail(ESSHError.Create(sekIO,'sftp async: read submit failed'));
end;

procedure TAsyncSftpChannel.OnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol,'sftp async: empty packet')); Exit; end;
  case FState of
    asOpening: HandleOpenPacket(APayload);
    asSubsystem: HandleSubsystemPacket(APayload);
    asHandshake: HandleReadyPacket(APayload);
    asReady: HandleReadyPacket(APayload);
  else PumpNext;
  end;
end;

procedure TAsyncSftpChannel.HandleOpenPacket(const APayload: TBytes);
var LR: TsshReader; LRid: UInt32;
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_OPEN_CONFIRMATION:
      begin
        LR:=TsshReader.Create(APayload);
        try
          LR.ReadByte; LRid:=LR.ReadUInt32; if LRid<>FLocalId then begin PumpNext; Exit; end;
          FRemoteId:=LR.ReadUInt32; FWindow.SetPeer(LR.ReadUInt32, LR.ReadUInt32);
        finally LR.Free; end;
        FState:=asSubsystem;
        SendSubsystem;
      end;
    SSH_MSG_CHANNEL_OPEN_FAILURE: Fail(ESSHError.Create(sekProtocol,'sftp async: open refused'));
    SSH_MSG_GLOBAL_REQUEST: begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin LR:=TsshReader.Create(APayload); try LR.ReadByte; LRid:=LR.ReadUInt32; if LRid=FLocalId then FWindow.Grant(LR.ReadUInt32); finally LR.Free; end; PumpNext; end;
  else PumpNext;
  end;
end;

procedure TAsyncSftpChannel.HandleSubsystemPacket(const APayload: TBytes);
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_SUCCESS:
      begin FState:=asHandshake; SendSftpInit; end;
    SSH_MSG_CHANNEL_FAILURE: Fail(ESSHError.Create(sekProtocol,'sftp async: subsystem refused'));
    SSH_MSG_CHANNEL_DATA: PumpNext;
    SSH_MSG_GLOBAL_REQUEST: begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin with TsshReader.Create(APayload) do try ReadByte; if ReadUInt32=FLocalId then FWindow.Grant(ReadUInt32); finally Free; end; PumpNext; end;
  else PumpNext;
  end;
end;

procedure TAsyncSftpChannel.HandleReadyPacket(const APayload: TBytes);
var LChunk: TBytes; LPkt: TBytes; Fs: ISshAsyncFileSystem;
begin
  case APayload[0] of
    SSH_MSG_CHANNEL_DATA:
      begin
        if ExtractData(APayload, False, LChunk) and (Length(LChunk)>0) then FReadBuf.AppendBytes(@LChunk[0], SizeUInt(Length(LChunk))); // perf: IBytesBuilder doubling single source BYTES_BUILDER_MIN_GROW=64, inline zero-copy Move, amortized O(1)
        if FState=asHandshake then
        begin
          if ExtractSftpPacket(LPkt) then
          begin
            if (Length(LPkt)>=1) and (LPkt[0]=SSH_FXP_VERSION) then
            begin
              Fs := TAsyncSftpFileSystem.Create(Self);
              SucceedOpen(Fs);
              PumpNext;
            end else Fail(ESSHError.Create(sekProtocol,'sftp async: expected VERSION'));
          end else PumpNext;
        end else
        begin
          TryDispatchSftp;
          PumpNext;
        end;
      end;
    SSH_MSG_CHANNEL_EXTENDED_DATA:
      begin if ExtractData(APayload, True, LChunk) and (Length(LChunk)>0) then FReadBuf.AppendBytes(@LChunk[0], SizeUInt(Length(LChunk))); TryDispatchSftp; PumpNext; end; // perf: IBytesBuilder doubling single source, inline zero-copy
    SSH_MSG_CHANNEL_REQUEST:
      begin HandleChannelRequest(APayload); TryDispatchSftp; PumpNext; end;
    SSH_MSG_GLOBAL_REQUEST: begin HandleGlobalRequest; PumpNext; end;
    SSH_MSG_CHANNEL_WINDOW_ADJUST:
      begin with TsshReader.Create(APayload) do try ReadByte; if ReadUInt32=FLocalId then FWindow.Grant(ReadUInt32); finally Free; end; PumpNext; end;
    SSH_MSG_CHANNEL_SUCCESS, SSH_MSG_CHANNEL_FAILURE: PumpNext;
    SSH_MSG_CHANNEL_EOF: PumpNext;
    SSH_MSG_CHANNEL_CLOSE: begin Fail(ESSHError.Create(sekIO,'sftp async: channel closed')); end;
  else PumpNext;
  end;
end;

function TAsyncSftpChannel.ExtractData(const APayload: TBytes; AExtended: Boolean; out AChunk: TBytes): Boolean;
var LR: TsshReader; LRid, LType: UInt32;
begin
  Result:=False; AChunk:=nil;
  LR:=TsshReader.Create(APayload);
  try
    LR.ReadByte; LRid:=LR.ReadUInt32; if LRid<>FLocalId then Exit;
    if AExtended then begin LType:=LR.ReadUInt32; AChunk:=LR.ReadStringBytes; if Length(AChunk)=0 then Exit; if LType<>SSH_EXTENDED_DATA_STDERR then begin AccountConsume(SizeUInt(Length(AChunk))); Exit(False); end; end
    else AChunk:=LR.ReadStringBytes;
  finally LR.Free; end;
  if Length(AChunk)=0 then Exit;
  AccountConsume(SizeUInt(Length(AChunk)));
  Result:=True;
end;

procedure TAsyncSftpChannel.AccountConsume(ACount: SizeUInt);
var LGive: UInt32;
begin
  FWindow.Consume(ACount, LGive); { 单源 window.pas inline，零堆分配 }
  if LGive>0 then SendWindowAdjust(LGive);
end;

procedure TAsyncSftpChannel.SendWindowAdjust(ACount: UInt32);
var LW: TsshWriter;
begin
  LW:=TsshWriter.Create(16);
  try LW.PutByte(SSH_MSG_CHANNEL_WINDOW_ADJUST); LW.PutUInt32(FRemoteId); LW.PutUInt32(ACount); FTransport.AsyncSendPacket(LW.ToBytes, nil, nil); finally LW.Free; end;
end;

procedure TAsyncSftpChannel.HandleChannelRequest(const APayload: TBytes);
var LR: TsshReader; LName: string; LWant: Boolean;
begin
  LR:=TsshReader.Create(APayload);
  try
    LR.ReadByte; LR.ReadUInt32; LName:=LR.ReadStringText; LWant:=LR.ReadBoolean;
    if LName=SSH_REQ_EXIT_STATUS then begin if LWant then FTransport.AsyncSendPacket(ChannelReplyPayload(FRemoteId, True), nil, nil); end
    else if LWant then FTransport.AsyncSendPacket(ChannelReplyPayload(FRemoteId, False), nil, nil);
  finally LR.Free; end;
end;

procedure TAsyncSftpChannel.HandleGlobalRequest;
begin
  FTransport.AsyncSendPacket(GlobalReplyPayload(False), nil, nil);
end;

function TAsyncSftpChannel.ExtractSftpPacket(out APacket: TBytes): Boolean; inline;
var LLen: UInt32; LData: PByte; LAvail, LRem: SizeUInt;
begin
  Result:=False; APacket:=nil;
  if (FReadBuf=nil) or (FReadBuf.Length<4) then Exit;
  LData:=FReadBuf.Data;
  LLen:=(UInt32(LData[0]) shl 24) or (UInt32(LData[1]) shl 16) or (UInt32(LData[2]) shl 8) or UInt32(LData[3]);
  if LLen> 256*1024 then begin Fail(ESSHError.Create(sekProtocol,'sftp async: packet too large')); Exit; end;
  LAvail:=FReadBuf.Length;
  if LAvail < 4+SizeUInt(LLen) then Exit;
  SetLength(APacket, LLen);
  if LLen>0 then Move(LData[4], APacket[0], LLen);
  // perf: single source bytes.builder/bytes.ops BYTES_BUILDER_MIN_GROW, amortized O(1) append vs O(n²) BytesAppend, zero-copy Move tail + Truncate
  LRem:=LAvail - (4+SizeUInt(LLen));
  if LRem>0 then Move(LData[4+LLen], LData[0], LRem);
  FReadBuf.Truncate(LRem);
  Result:=True;
end;

procedure TAsyncSftpChannel.TryDispatchSftp;
var LPkt: TBytes; LType: Byte; LRid: UInt32; LR: TsshReader; LCode: UInt32; LAccept: Boolean; Cb: TProcSftpRaw; Ctx: Pointer; LMsg2: string; LReader2: TsshReader; LIdx: Integer;
begin
  if Length(FPending)=0 then Exit;
  while ExtractSftpPacket(LPkt) do
  begin
    if Length(LPkt)<5 then begin FailAllPending(ESSHError.Create(sekProtocol,'sftp async: truncated')); Exit; end;
    LType:=LPkt[0];
    LR:=TsshReader.Create(LPkt);
    try LR.ReadByte; LRid:=LR.ReadUInt32; finally LR.Free; end;
    LIdx:=FindPendingIdx(LRid);
    if LIdx<0 then Continue; // stale or not for us (pipeline: other id in flight)
    if LType=SSH_FXP_STATUS then
    begin
      LR:=TsshReader.Create(LPkt);
      try LR.ReadByte; LR.ReadUInt32; LCode:=LR.ReadUInt32; finally LR.Free; end;
      if LCode=SSH_FX_OK then
      begin
        LAccept:=IsAcceptable(LType, FPending[LIdx].Accept);
        if not LAccept then begin Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekProtocol,'sftp async: unexpected STATUS OK'), Ctx); Continue; end;
      end
      else if LCode=SSH_FX_EOF then
      begin
        LAccept:=IsAcceptable(LType, FPending[LIdx].Accept);
        if not LAccept then begin Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekProtocol,'sftp async: unexpected EOF'), Ctx); Continue; end;
      end
      else
      begin
        if IsAcceptable(SSH_FXP_STATUS, FPending[LIdx].Accept) then
        begin
          // deliver as success, caller maps to sekSftp
        end else
        begin
          Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx);
          begin LReader2:=TsshReader.Create(LPkt); try LReader2.ReadByte; LReader2.ReadUInt32; LReader2.ReadUInt32; try LMsg2:=LReader2.ReadStringText; except LMsg2:=''; end; finally LReader2.Free; end; if LMsg2<>'' then LMsg2:=' ('+LMsg2+')'; if Assigned(Cb) then Cb(nil, ESSHError.Create(sekSftp, 'sftp: '+SftpStatusName(LCode)+LMsg2), Ctx); end;
          Continue;
        end;
      end;
    end else
    begin
      if not IsAcceptable(LType, FPending[LIdx].Accept) then begin Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekProtocol,'sftp async: unexpected reply '+nextpas.core.text.conv.IntToStr(Int64(LType))), Ctx); Continue; end;
    end;
    Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx);
    if Assigned(Cb) then Cb(LPkt, nil, Ctx);
    if Length(FPending)=0 then Exit;
  end;
end;

procedure TAsyncSftpChannel.OnTimeout(AContext: Pointer);
begin Fail(ESSHError.Create(sekTimeout,'sftp async: timeout')); end;

procedure TAsyncSftpChannel.OnOpTimeout(AContext: Pointer);
begin FailAllPending(ESSHError.Create(sekTimeout,'sftp async: op timeout')); end;

function TAsyncSftpChannel.SftpRoundTripAsync(AType: Byte; const APayload: TBytes; const AAccept: array of Byte; ACb: TProcSftpRaw; AContext: Pointer): Boolean;
var LId: UInt32; LInner, LOuter: TBytes; LW: TsshWriter; I, LIdx: Integer;
begin
  if FFailed or (FState<>asReady) then begin if Assigned(ACb) then ACb(nil, ESSHError.Create(sekIO,'sftp async: not ready'), AContext); Exit(False); end;
  if Length(FPending) >= SFTP_PIPELINE_WINDOW then begin if Assigned(ACb) then ACb(nil, ESSHError.Create(sekProtocol,'sftp async: busy'), AContext); Exit(False); end;
  LId:=FNextId; Inc(FNextId);
  LIdx:=Length(FPending); SetLength(FPending, LIdx+1);
  FPending[LIdx].Id:=LId;
  SetLength(FPending[LIdx].Accept, Length(AAccept));
  for I:=0 to High(AAccept) do FPending[LIdx].Accept[I]:=AAccept[I];
  FPending[LIdx].Cb:=ACb;
  FPending[LIdx].Ctx:=AContext;
  if not FDeadline.IsInfinite then
  try
    if not FOpTimer.IsValid then
    begin FOpDeadline:=FDeadline; FOpTimer:=FLoop.ScheduleAt(FOpDeadline, @Runner_SftpOnOpTimeout, Self); end;
  except
    SetLength(FPending, LIdx);
    raise;
  end;
  LW:=TsshWriter.Create(5+Length(APayload));
  try LW.PutByte(AType); LW.PutUInt32(LId); LW.PutRaw(APayload); LInner:=LW.ToBytes; finally LW.Free; end;
  LW:=TsshWriter.Create(4+Length(LInner));
  try LW.PutUInt32(UInt32(Length(LInner))); LW.PutRaw(LInner); LOuter:=LW.ToBytes; finally LW.Free; end;
  LW:=TsshWriter.Create(16+Length(LOuter));
  try
    LW.PutByte(SSH_MSG_CHANNEL_DATA);
    LW.PutUInt32(FRemoteId);
    LW.PutUInt32(UInt32(Length(LOuter)));
    LW.PutRaw(LOuter);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @Runner_SftpOnSent, Self) then
    begin RemovePendingIdx(LIdx); if Assigned(ACb) then ACb(nil, ESSHError.Create(sekIO,'sftp async: send failed'), AContext); Exit(False); end;
  finally LW.Free; end;
  Result:=True;
end;

procedure TAsyncSftpChannel.OnSftpSent(AErr: ESSHError; AContext: Pointer);
var LIdx: Integer; Cb: TProcSftpRaw; Ctx: Pointer;
begin
  if AErr<>nil then
  begin
    if Length(FPending)>0 then
    begin
      // transport send failure corresponds to most recent pending (tail); pipeline: fail that one
      LIdx:=High(FPending); Cb:=FPending[LIdx].Cb; Ctx:=FPending[LIdx].Ctx; RemovePendingIdx(LIdx);
      if Assigned(Cb) then Cb(nil, AErr, Ctx) else AErr.Free;
    end else AErr.Free;
  end;
end;

procedure TAsyncSftpChannel.CloseChannel;
var LW: TsshWriter;
begin
  if FSentClose then Exit;
  FState:=asClosed;
  try
    LW:=TsshWriter.Create(8); try LW.PutByte(SSH_MSG_CHANNEL_EOF); LW.PutUInt32(FRemoteId); FTransport.AsyncSendPacket(LW.ToBytes, nil, nil); finally LW.Free; end;
    LW:=TsshWriter.Create(8); try LW.PutByte(SSH_MSG_CHANNEL_CLOSE); LW.PutUInt32(FRemoteId); FTransport.AsyncSendPacket(LW.ToBytes, nil, nil); finally LW.Free; end;
    FSentClose:=True;
  except end;
end;

{ TAsyncSftpFileSystem }

constructor TAsyncSftpFileSystem.Create(AChannel: TAsyncSftpChannel);
begin
  inherited Create;
  FChannel:=AChannel;
end;

destructor TAsyncSftpFileSystem.Destroy;
var Ch: TAsyncSftpChannel;
begin
  Close;
  Ch:=FChannel; FChannel:=nil;
  if Ch<>nil then
  begin
    Ch.FOwnerFs:=nil;
    Ch.Free;
  end;
  inherited;
end;

procedure TAsyncSftpFileSystem.Close;
begin
  if not FClosed then
  begin FClosed:=True; if FChannel<>nil then FChannel.CloseChannel; end;
end;

// ---- helpers for status handling ----

procedure SftpDispatchStat(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpDispatchRealPath(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpDispatchVoid(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpDispatchData(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;

type
  PStatCtx = ^TStatCtx;
  TStatCtx = record Fs: TAsyncSftpFileSystem; Cb: TProcSftpStat; Ctx: Pointer; end;
  PRealPathCtx = ^TRealPathCtx;
  TRealPathCtx = record Fs: TAsyncSftpFileSystem; Cb: TProcSftpRealPath; Ctx: Pointer; end;
  PVoidCtx = ^TVoidCtx;
  TVoidCtx = record Fs: TAsyncSftpFileSystem; Cb: TProcSftpVoid; Ctx: Pointer; Path: string; end;
  PDataCtx = ^TDataCtx;
  TDataCtx = record Fs: TAsyncSftpFileSystem; Cb: TProcSftpData; Ctx: Pointer; end;

function TAsyncSftpFileSystem.RealPathAsync(const APath: string; ACallback: TProcSftpRealPath; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PRealPathCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback('', ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_REALPATH, LTail, [SSH_FXP_NAME], @SftpDispatchRealPath, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

function TAsyncSftpFileSystem.StatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PStatCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(Default(TSftpAttrs), ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_STAT, LTail, [SSH_FXP_ATTRS, SSH_FXP_STATUS], @SftpDispatchStat, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

function TAsyncSftpFileSystem.LstatAsync(const APath: string; ACallback: TProcSftpStat; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PStatCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(Default(TSftpAttrs), ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_LSTAT, LTail, [SSH_FXP_ATTRS, SSH_FXP_STATUS], @SftpDispatchStat, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

procedure FsOnListDirOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnListDirRead(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnListDirClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnReadOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnReadChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnReadClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnWriteOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnWriteChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure FsOnWriteClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer); forward;

function TAsyncSftpFileSystem.ListDirAsync(const APath: string; ACallback: TProcSftpDirList; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(nil, ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  FListDirPath:=APath; FListDirCb:=ACallback; FListDirCtx:=AContext; SetLength(FListDirAccum,0); FListDirCount:=0; FListDirCap:=0; FListDirHandle:=nil;
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  Result:=FChannel.SftpRoundTripAsync(SSH_FXP_OPENDIR, LTail, [SSH_FXP_HANDLE], @FsOnListDirOpen, Self);
end;

function TAsyncSftpFileSystem.ReadFileAsync(const APath: string; ACallback: TProcSftpData; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(nil, ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  FReadPath:=APath; FReadCb:=ACallback; FReadCtx:=AContext; SetLength(FReadAccum,0); FReadBuilder := CreateBytesBuilder; // perf: doubling single source
  FReadOffset:=0; FReadHandle:=nil;
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LW.PutUInt32(SSH_FXF_READ); PutAttrs(LW, Default(TSftpAttrs)); LTail:=LW.ToBytes; finally LW.Free; end;
  Result:=FChannel.SftpRoundTripAsync(SSH_FXP_OPEN, LTail, [SSH_FXP_HANDLE], @FsOnReadOpen, Self);
end;

function TAsyncSftpFileSystem.WriteFileAsync(const APath: string; const AData: TBytes; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  FWritePath:=APath; FWriteData:=Copy(AData,0,Length(AData)); FWriteOff:=0; FWriteCb:=ACallback; FWriteCtx:=AContext; FWriteHandle:=nil;
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LW.PutUInt32(SSH_FXF_WRITE or SSH_FXF_CREAT or SSH_FXF_TRUNC); PutAttrs(LW, Default(TSftpAttrs)); LTail:=LW.ToBytes; finally LW.Free; end;
  Result:=FChannel.SftpRoundTripAsync(SSH_FXP_OPEN, LTail, [SSH_FXP_HANDLE], @FsOnWriteOpen, Self);
end;

function TAsyncSftpFileSystem.RemoveAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PVoidCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Path:=APath;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_REMOVE, LTail, [SSH_FXP_STATUS], @SftpDispatchVoid, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

function TAsyncSftpFileSystem.MkdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PVoidCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(80);
  try LW.PutStringText(APath); PutAttrs(LW, Default(TSftpAttrs)); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Path:=APath;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_MKDIR, LTail, [SSH_FXP_STATUS], @SftpDispatchVoid, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

function TAsyncSftpFileSystem.RmdirAsync(const APath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PVoidCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(64);
  try LW.PutStringText(APath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Path:=APath;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_RMDIR, LTail, [SSH_FXP_STATUS], @SftpDispatchVoid, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

function TAsyncSftpFileSystem.RenameAsync(const AOldPath, ANewPath: string; ACallback: TProcSftpVoid; AContext: Pointer): Boolean;
var LW: TsshWriter; LTail: TBytes; P: PVoidCtx;
begin
  if FClosed then begin if Assigned(ACallback) then ACallback(ESSHError.Create(sekIO,'sftp async: closed'), AContext); Exit(False); end;
  if not Assigned(ACallback) then Exit(False);
  LW:=TsshWriter.Create(128);
  try LW.PutStringText(AOldPath); LW.PutStringText(ANewPath); LTail:=LW.ToBytes; finally LW.Free; end;
  New(P);
  try
    P^.Fs:=Self; P^.Cb:=ACallback; P^.Ctx:=AContext; P^.Path:=AOldPath+' -> '+ANewPath;
    Result:=FChannel.SftpRoundTripAsync(SSH_FXP_RENAME, LTail, [SSH_FXP_STATUS], @SftpDispatchVoid, P);
  except
    Dispose(P);
    raise;
  end;
  if not Result then Dispose(P);
end;

// ---- dispatchers ----

procedure SftpDispatchStat(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var P: PStatCtx; LR: TsshReader; Attrs: TSftpAttrs; LCode: UInt32; LMsg: string;
begin
  P:=PStatCtx(AContext);
  try
    if AErr<>nil then begin P^.Cb(Default(TSftpAttrs), AErr, P^.Ctx); Exit; end;
    if (Length(APacket)>0) and (APacket[0]=SSH_FXP_STATUS) then
    begin
      LR:=TsshReader.Create(APacket);
      try LR.ReadByte; LR.ReadUInt32; LCode:=LR.ReadUInt32; try LMsg:=LR.ReadStringText; except LMsg:=''; end; finally LR.Free; end;
      if LMsg<>'' then LMsg:=' ('+LMsg+')';
      P^.Cb(Default(TSftpAttrs), ESSHError.Create(sekSftp,'sftp: '+SftpStatusName(LCode)+LMsg), P^.Ctx);
      Exit;
    end;
    LR:=TsshReader.Create(APacket);
    try LR.ReadByte; LR.ReadUInt32; Attrs:=ReadAttrs(LR); finally LR.Free; end;
    P^.Cb(Attrs, nil, P^.Ctx);
  finally Dispose(P); end;
end;

procedure SftpDispatchRealPath(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var P: PRealPathCtx; LR: TsshReader; LN, I: Integer; Res: string;
begin
  P:=PRealPathCtx(AContext);
  try
    if AErr<>nil then begin P^.Cb('', AErr, P^.Ctx); Exit; end;
    LR:=TsshReader.Create(APacket);
    try LR.ReadByte; LR.ReadUInt32; LN:=Integer(LR.ReadUInt32); Res:=''; for I:=1 to LN do begin if Res<>'' then Res:=Res+', '; Res:=Res+LR.ReadStringText; LR.ReadStringText; ReadAttrs(LR); end; finally LR.Free; end;
    P^.Cb(Res, nil, P^.Ctx);
  finally Dispose(P); end;
end;

procedure SftpDispatchVoid(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var P: PVoidCtx;
begin
  P:=PVoidCtx(AContext);
  try
    if AErr<>nil then P^.Cb(AErr, P^.Ctx) else P^.Cb(nil, P^.Ctx);
  finally Dispose(P); end;
end;

procedure SftpDispatchData(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var P: PDataCtx; LR: TsshReader; Data: TBytes;
begin
  P:=PDataCtx(AContext);
  try
    if AErr<>nil then begin P^.Cb(nil, AErr, P^.Ctx); Exit; end;
    LR:=TsshReader.Create(APacket);
    try LR.ReadByte; LR.ReadUInt32; Data:=LR.ReadStringBytes; finally LR.Free; end;
    P^.Cb(Data, nil, P^.Ctx);
  finally Dispose(P); end;
end;

// Fs internal steps

procedure TAsyncSftpFileSystem.DoListDirStep;
var LW: TsshWriter; LTail: TBytes; Cb: TProcSftpDirList; Ctx: Pointer;
begin
  LW:=TsshWriter.Create(16);
  try LW.PutStringBytes(FListDirHandle); LTail:=LW.ToBytes; finally LW.Free; end;
  if not FChannel.SftpRoundTripAsync(SSH_FXP_READDIR, LTail, [SSH_FXP_NAME, SSH_FXP_STATUS], @FsOnListDirRead, Self) then
  begin
    Cb:=FListDirCb; Ctx:=FListDirCtx; FListDirCb:=nil; Cb(nil, ESSHError.Create(sekIO,'sftp async: readdir send failed'), Ctx);
  end;
end;

procedure TAsyncSftpFileSystem.OnListDirOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LR: TsshReader; Cb2: TProcSftpDirList; Ctx2: Pointer;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then begin Cb2:=Self.FListDirCb; Ctx2:=Self.FListDirCtx; Self.FListDirCb:=nil; if Assigned(Cb2) then Cb2(nil, AErr, Ctx2); Exit; end;
  LR:=TsshReader.Create(APacket);
  try LR.ReadByte; LR.ReadUInt32; Self.FListDirHandle:=LR.ReadStringBytes; finally LR.Free; end;
  Self.DoListDirStep;
end;

procedure TAsyncSftpFileSystem.OnListDirRead(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LR: TsshReader; LType: Byte; LCode: UInt32; LN, I: Integer; LW: TsshWriter; Tail: TBytes; Cb: TProcSftpDirList; Ctx2: Pointer; Cb2: TProcSftpDirList; Ctx: Pointer; LName, LLong: string; LAttrs: TSftpAttrs;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then
  begin
    if Length(Self.FListDirHandle)>0 then
    begin LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FListDirHandle); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnListDirClose, Self); end;
    Cb:=Self.FListDirCb; Ctx:=Self.FListDirCtx; Self.FListDirCb:=nil; if Assigned(Cb) then Cb(nil, AErr, Ctx); Exit;
  end;
  LType:=APacket[0];
  if LType=SSH_FXP_STATUS then
  begin
    LR:=TsshReader.Create(APacket);
    try LR.ReadByte; LR.ReadUInt32; LCode:=LR.ReadUInt32; finally LR.Free; end;
    if LCode=SSH_FX_EOF then
    begin
      if Self.FListDirCount <> Self.FListDirCap then SetLength(Self.FListDirAccum, Self.FListDirCount); Self.FListDirCap:=Self.FListDirCount;
      LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FListDirHandle); Tail:=LW.ToBytes; finally LW.Free; end; if not Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnListDirClose, Self) then begin Cb2:=Self.FListDirCb; Ctx2:=Self.FListDirCtx; Self.FListDirCb:=nil; if Assigned(Cb2) then Cb2(Self.FListDirAccum, nil, Ctx2); SetLength(Self.FListDirAccum,0); Self.FListDirCount:=0; Self.FListDirCap:=0; end;
      Exit;
    end else
    begin
      Cb:=Self.FListDirCb; Ctx:=Self.FListDirCtx; Self.FListDirCb:=nil; SetLength(Self.FListDirAccum,0); Self.FListDirCount:=0; Self.FListDirCap:=0; if Assigned(Cb) then Cb(nil, ESSHError.Create(sekSftp,'sftp: '+SftpStatusName(LCode)), Ctx); Exit;
    end;
  end;
  LR:=TsshReader.Create(APacket);
  try
    LR.ReadByte; LR.ReadUInt32; LN:=Integer(LR.ReadUInt32);
    for I:=1 to LN do
    begin
      // perf: read all fields first, filter dot before growing (avoid O(n²) churn), geometric doubling 16→2× single source bytes.ops/builder
      LName:=LR.ReadStringText; LLong:=LR.ReadStringText; LAttrs:=ReadAttrs(LR);
      if (LName='.') or (LName='..') then Continue;
      // perf: BytesEnsureCapacity 单源几何倍增（BYTES_BUILDER_MIN_GROW=64, 2×），inline 零拷贝，避免三处手写 16→2× 漂移
      if Self.FListDirCount >= Self.FListDirCap then
      begin
        BytesEnsureCapacity(Self.FListDirCap, Self.FListDirCount + 1);
        SetLength(Self.FListDirAccum, Self.FListDirCap);
      end;
      Self.FListDirAccum[Self.FListDirCount].Name:=LName; Self.FListDirAccum[Self.FListDirCount].LongName:=LLong; Self.FListDirAccum[Self.FListDirCount].Attrs:=LAttrs;
      Inc(Self.FListDirCount);
    end;
  finally LR.Free; end;
  Self.DoListDirStep;
end;

procedure TAsyncSftpFileSystem.OnListDirClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; Cb: TProcSftpDirList; Ctx: Pointer; Acc: TSftpDirEntryArray;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if Self.FListDirCount <> Self.FListDirCap then SetLength(Self.FListDirAccum, Self.FListDirCount);
  Cb:=Self.FListDirCb; Ctx:=Self.FListDirCtx; Acc:=Self.FListDirAccum; Self.FListDirCb:=nil; SetLength(Self.FListDirAccum,0); Self.FListDirCount:=0; Self.FListDirCap:=0; Self.FListDirHandle:=nil;
  // bytes.ops compatible trim already done; Acc now exact Count, zero extra alloc
  if Assigned(Cb) then Cb(Acc, nil, Ctx);
end;

procedure TAsyncSftpFileSystem.OnReadOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LR: TsshReader; LW: TsshWriter; Tail: TBytes; Cb: TProcSftpData; Ctx: Pointer;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then begin Cb:=Self.FReadCb; Ctx:=Self.FReadCtx; Self.FReadCb:=nil; if Assigned(Cb) then Cb(nil, AErr, Ctx); Exit; end;
  LR:=TsshReader.Create(APacket);
  try LR.ReadByte; LR.ReadUInt32; Self.FReadHandle:=LR.ReadStringBytes; finally LR.Free; end;
  LW:=TsshWriter.Create(24); try LW.PutStringBytes(Self.FReadHandle); LW.PutUInt64(Self.FReadOffset); LW.PutUInt32(SFTP_CHUNK_SIZE); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_READ, Tail, [SSH_FXP_DATA, SSH_FXP_STATUS], @FsOnReadChunk, Self);
end;

procedure TAsyncSftpFileSystem.OnReadChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LR: TsshReader; LType: Byte; LCode: UInt32; LChunk: TBytes; LW: TsshWriter; Tail: TBytes; Cb: TProcSftpData; Ctx: Pointer;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then begin Cb:=Self.FReadCb; Ctx:=Self.FReadCtx; Self.FReadCb:=nil; if Assigned(Cb) then Cb(nil, AErr, Ctx); Exit; end;
  LType:=APacket[0];
  if LType=SSH_FXP_STATUS then
  begin
    LR:=TsshReader.Create(APacket);
    try LR.ReadByte; LR.ReadUInt32; LCode:=LR.ReadUInt32; finally LR.Free; end;
    if LCode=SSH_FX_EOF then
    begin
      LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FReadHandle); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnReadClose, Self);
      Exit;
    end else
    begin Cb:=Self.FReadCb; Ctx:=Self.FReadCtx; Self.FReadCb:=nil; if Assigned(Cb) then Cb(nil, ESSHError.Create(sekSftp,'sftp: '+SftpStatusName(LCode)), Ctx); Exit; end;
  end;
  LR:=TsshReader.Create(APacket);
  try LR.ReadByte; LR.ReadUInt32; LChunk:=LR.ReadStringBytes; finally LR.Free; end;
  if Length(LChunk) > 0 then Self.FReadBuilder.AppendBytes(@LChunk[0], SizeUInt(Length(LChunk))); // inline zero-copy, doubling
  Inc(Self.FReadOffset, SizeUInt(Length(LChunk)));
  if Length(LChunk)=0 then
  begin
    LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FReadHandle); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnReadClose, Self);
    Exit;
  end;
  LW:=TsshWriter.Create(24); try LW.PutStringBytes(Self.FReadHandle); LW.PutUInt64(Self.FReadOffset); LW.PutUInt32(SFTP_CHUNK_SIZE); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_READ, Tail, [SSH_FXP_DATA, SSH_FXP_STATUS], @FsOnReadChunk, Self);
end;

procedure TAsyncSftpFileSystem.OnReadClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; Cb: TProcSftpData; Ctx: Pointer; Acc: TBytes;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  Cb:=Self.FReadCb; Ctx:=Self.FReadCtx;
  if Self.FReadBuilder <> nil then Acc:=Self.FReadBuilder.ToBytes else Acc:=Self.FReadAccum; // single alloc copy
  Self.FReadCb:=nil; Self.FReadHandle:=nil; SetLength(Self.FReadAccum,0); Self.FReadBuilder := nil; // stability: release refcount
  if Assigned(Cb) then Cb(Acc, nil, Ctx);
end;

procedure TAsyncSftpFileSystem.OnWriteOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LR: TsshReader; LW: TsshWriter; Tail: TBytes; Cb: TProcSftpVoid; Ctx: Pointer; LTake: SizeUInt;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then begin Cb:=Self.FWriteCb; Ctx:=Self.FWriteCtx; Self.FWriteCb:=nil; if Assigned(Cb) then Cb(AErr, Ctx); Exit; end;
  LR:=TsshReader.Create(APacket);
  try LR.ReadByte; LR.ReadUInt32; Self.FWriteHandle:=LR.ReadStringBytes; finally LR.Free; end;
  if Length(Self.FWriteData)=0 then
  begin
    LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FWriteHandle); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnWriteClose, Self);
    Exit;
  end;
  LTake:=SizeUInt(Length(Self.FWriteData)); if LTake>SFTP_CHUNK_SIZE then LTake:=SFTP_CHUNK_SIZE;
  LW:=TsshWriter.Create(24+Integer(LTake)); try LW.PutStringBytes(Self.FWriteHandle); LW.PutUInt64(0); LW.PutUInt32(UInt32(LTake)); if LTake>0 then LW.PutRaw(@Self.FWriteData[0], LTake); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_WRITE, Tail, [SSH_FXP_STATUS], @FsOnWriteChunk, Self); Self.FWriteOff:=LTake;
end;

procedure TAsyncSftpFileSystem.OnWriteChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; LW: TsshWriter; Tail: TBytes; Cb: TProcSftpVoid; Ctx: Pointer; LTake: SizeUInt;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  if AErr<>nil then begin Cb:=Self.FWriteCb; Ctx:=Self.FWriteCtx; Self.FWriteCb:=nil; if Assigned(Cb) then Cb(AErr, Ctx); Exit; end;
  if Self.FWriteOff >= SizeUInt(Length(Self.FWriteData)) then
  begin
    LW:=TsshWriter.Create(16); try LW.PutStringBytes(Self.FWriteHandle); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_CLOSE, Tail, [SSH_FXP_STATUS], @FsOnWriteClose, Self);
    Exit;
  end;
  LTake:=SizeUInt(Length(Self.FWriteData))-Self.FWriteOff; if LTake>SFTP_CHUNK_SIZE then LTake:=SFTP_CHUNK_SIZE;
  LW:=TsshWriter.Create(24+Integer(LTake)); try LW.PutStringBytes(Self.FWriteHandle); LW.PutUInt64(UInt64(Self.FWriteOff)); LW.PutUInt32(UInt32(LTake)); if LTake>0 then LW.PutRaw(@Self.FWriteData[Self.FWriteOff], LTake); Tail:=LW.ToBytes; finally LW.Free; end; Self.FChannel.SftpRoundTripAsync(SSH_FXP_WRITE, Tail, [SSH_FXP_STATUS], @FsOnWriteChunk, Self); Inc(Self.FWriteOff, LTake);
end;

procedure TAsyncSftpFileSystem.OnWriteClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
var Self: TAsyncSftpFileSystem; Cb: TProcSftpVoid; Ctx: Pointer;
begin
  Self:=TAsyncSftpFileSystem(AContext);
  Cb:=Self.FWriteCb; Ctx:=Self.FWriteCtx; Self.FWriteCb:=nil; SetLength(Self.FWriteData,0); Self.FWriteHandle:=nil;
  if Assigned(Cb) then Cb(nil, Ctx);
end;

{ helpers }

type
  PSftpOpenPost = ^TSftpOpenPost;
  TSftpOpenPost = record
    Loop: TAsyncLoop;
    Session: ISshAsyncSession;
    Transport: TAsyncSshTransport;
    TimeoutMs: Integer;
    Callback: TProcSftpOpenAsync;
    Context: Pointer;
  end;

procedure SftpOpenPostCb(AContext: Pointer); forward;
procedure SftpOpenPostDiscard(AContext: Pointer); forward;

procedure SftpOpenPostCb(AContext: Pointer);
var P: PSftpOpenPost; Ch: TAsyncSftpChannel;
begin
  P:=PSftpOpenPost(AContext);
  if P^.Transport = nil then
  begin
    if P^.Session <> nil then P^.Transport := P^.Session.Transport;
  end;
  if P^.Transport.IsWriteBusy then
  begin
    try P^.Loop.ScheduleAt(TDeadline.After(TDuration.FromMilliseconds(5)), @SftpOpenPostCb, P); except begin P^.Session := nil; Dispose(P); end; end;
    Exit;
  end;
  try
    if P^.Session <> nil then
      Ch:=TAsyncSftpChannel.Create(P^.Loop, P^.Session, P^.TimeoutMs, P^.Callback, P^.Context)
    else
      Ch:=TAsyncSftpChannel.Create(P^.Loop, P^.Transport, P^.TimeoutMs, P^.Callback, P^.Context);
    try
      Ch.Start;
    except
      Ch.Free;
      raise;
    end;
  finally
    P^.Session := nil;
    Dispose(P);
  end;
end;

procedure SftpOpenPostDiscard(AContext: Pointer);
var P: PSftpOpenPost;
begin
  P:=PSftpOpenPost(AContext);
  if Assigned(P^.Callback) then
    P^.Callback(nil, ESSHError.Create(sekIO,'sftp async: loop closed before open'), P^.Context);
  P^.Session := nil;
  Dispose(P);
end;

function SshAsyncOpenSftp(const ASession: ISshAsyncSession; ACallback: TProcSftpOpenAsync; AContext: Pointer): Boolean;
var P: PSftpOpenPost;
begin
  Result:=False;
  if (ASession=nil) or not Assigned(ACallback) then Exit;
  if (ASession.Loop=nil) or (ASession.Transport=nil) then begin ACallback(nil, ESSHError.Create(sekIO,'sftp async: session not connected'), AContext); Exit(False); end;
  New(P);
  try
    P^.Loop:=ASession.Loop;
    P^.Session:=ASession;
    P^.Transport:=ASession.Transport;
    P^.TimeoutMs:=5000;
    P^.Callback:=ACallback;
    P^.Context:=AContext;
    P^.Loop.PostEx(@SftpOpenPostCb, P, @SftpOpenPostDiscard);
    Result:=True;
  except
    P^.Session:=nil;
    Dispose(P);
    if Assigned(ACallback) then ACallback(nil, ESSHError.Create(sekIO,'sftp async: post open failed'), AContext);
    Result:=False;
  end;
end;

function SshAsyncOpenSftpEx(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; ATimeoutMs: Integer; ACallback: TProcSftpOpenAsync; AContext: Pointer): Boolean;
var P: PSftpOpenPost;
begin
  if (ALoop=nil) or (ATransport=nil) or not Assigned(ACallback) then Exit(False);
  New(P);
  try
    P^.Loop:=ALoop;
    P^.Session:=nil;
    P^.Transport:=ATransport;
    P^.TimeoutMs:=ATimeoutMs;
    P^.Callback:=ACallback;
    P^.Context:=AContext;
    ALoop.PostEx(@SftpOpenPostCb, P, @SftpOpenPostDiscard);
    Result:=True;
  except
    P^.Session:=nil;
    Dispose(P);
    if Assigned(ACallback) then
      ACallback(nil, ESSHError.Create(sekIO,'sftp async: post open failed'), AContext);
    Result:=False;
  end;
end;


{ SFTP via Async Jump }

type
  PSftpViaOnCtx = ^TSftpViaOnCtx;
  TSftpViaOnCtx = record UserCb: TProcSftpOpenAsync; UserCtx: Pointer; end;
  PSftpViaJumpCtx = ^TSftpViaJumpCtx;
  TSftpViaJumpCtx = record Loop: TAsyncLoop; TargetOpts: TSshConnectOptions; UserCb: TProcSftpOpenAsync; UserCtx: Pointer; end;

procedure SftpViaOn_SftpOpened(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpViaOn_Connected(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpViaJump_SftpOpened(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer); forward;
procedure SftpViaJump_Connected(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer); forward;

procedure SftpViaOn_SftpOpened(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer);
var C: PSftpViaOnCtx; Cb: TProcSftpOpenAsync; U: Pointer;
begin
  C:=PSftpViaOnCtx(AContext); Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C);
  if Assigned(Cb) then Cb(AFs, AErr, U) else if AErr<>nil then AErr.Free;
end;

procedure SftpViaOn_Connected(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer);
var C: PSftpViaOnCtx; P: PSftpViaOnCtx; Cb: TProcSftpOpenAsync; U: Pointer;
begin
  C:=PSftpViaOnCtx(AContext);
  if AErr<>nil then begin Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C); if Assigned(Cb) then Cb(nil, AErr, U) else AErr.Free; Exit; end;
  if ASession=nil then begin Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekIO,'sftp via jump: nil session'), U); Exit; end;
  New(P);
  try
    P^.UserCb:=C^.UserCb; P^.UserCtx:=C^.UserCtx; Dispose(C); C:=nil;
    if not SshAsyncOpenSftp(ASession, @SftpViaOn_SftpOpened, P) then
    begin Cb:=P^.UserCb; U:=P^.UserCtx; Dispose(P); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekIO,'sftp via jump: open submit failed'), U); ASession.Close; end;
  except
    if C<>nil then Dispose(C);
    Dispose(P);
    raise;
  end;
end;

function SshAsyncSftpViaJumpOn(const ALoop: TAsyncLoop; const AJumpSession: ISshAsyncSession; const ATargetOpts: TSshConnectOptions; ACallback: TProcSftpOpenAsync; AContext: Pointer): Boolean;
var C: PSftpViaOnCtx;
begin
  if (ALoop=nil) or (AJumpSession=nil) or not Assigned(ACallback) then Exit(False);
  New(C);
  try
    C^.UserCb:=ACallback; C^.UserCtx:=AContext;
    Result:=SshAsyncConnectViaJumpOn(ALoop, AJumpSession, ATargetOpts, @SftpViaOn_Connected, C);
  except
    Dispose(C);
    raise;
  end;
  if not Result then Dispose(C);
end;

procedure SftpViaJump_SftpOpened(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer);
var C: PSftpViaJumpCtx; Cb: TProcSftpOpenAsync; U: Pointer;
begin
  C:=PSftpViaJumpCtx(AContext); Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C);
  if Assigned(Cb) then Cb(AFs, AErr, U) else if AErr<>nil then AErr.Free;
end;

procedure SftpViaJump_Connected(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer);
var C: PSftpViaJumpCtx; P: PSftpViaJumpCtx; Cb: TProcSftpOpenAsync; U: Pointer; Ok: Boolean;
begin
  C:=PSftpViaJumpCtx(AContext);
  if AErr<>nil then begin Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C); if Assigned(Cb) then Cb(nil, AErr, U) else AErr.Free; Exit; end;
  if ASession=nil then begin Cb:=C^.UserCb; U:=C^.UserCtx; Dispose(C); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekIO,'sftp via jump: nil session'), U); Exit; end;
  New(P);
  try
    P^.UserCb:=C^.UserCb; P^.UserCtx:=C^.UserCtx; Dispose(C); C:=nil;
    Ok:=SshAsyncOpenSftp(ASession, @SftpViaJump_SftpOpened, P);
    if not Ok then begin Cb:=P^.UserCb; U:=P^.UserCtx; Dispose(P); if Assigned(Cb) then Cb(nil, ESSHError.Create(sekIO,'sftp via jump: open submit failed'), U); ASession.Close; end;
  except
    if C<>nil then Dispose(C);
    Dispose(P);
    raise;
  end;
end;

function SshAsyncSftpViaJump(const ALoop: TAsyncLoop; const AJumpOpts, ATargetOpts: TSshConnectOptions; ACallback: TProcSftpOpenAsync; AContext: Pointer): Boolean;
var C: PSftpViaJumpCtx;
begin
  if (ALoop=nil) or not Assigned(ACallback) then Exit(False);
  New(C);
  try
    C^.Loop:=ALoop; C^.TargetOpts:=ATargetOpts; C^.UserCb:=ACallback; C^.UserCtx:=AContext;
    Result:=SshAsyncConnectViaJump(ALoop, AJumpOpts, ATargetOpts, @SftpViaJump_Connected, C);
  except
    Dispose(C);
    raise;
  end;
  if not Result then Dispose(C);
end;


{ dispatchers }

procedure Runner_SftpOnOpenSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnOpenSent(AErr, nil); end;

procedure Runner_SftpOnPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnPacket(APayload, AErr, nil); end;

procedure Runner_SftpOnSubsystemSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnSubsystemSent(AErr, nil); end;

procedure Runner_SftpOnSftpInitSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnSftpInitSent(AErr, nil); end;

procedure Runner_SftpOnTimeout(AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnTimeout(nil); end;

procedure Runner_SftpOnOpTimeout(AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnOpTimeout(nil); end;

procedure Runner_SftpOnSent(AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpChannel(AContext).OnSftpSent(AErr, nil); end;

procedure FsOnListDirOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnListDirOpen(APacket, AErr, AContext); end;
procedure FsOnListDirRead(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnListDirRead(APacket, AErr, AContext); end;
procedure FsOnListDirClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnListDirClose(APacket, AErr, AContext); end;
procedure FsOnReadOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnReadOpen(APacket, AErr, AContext); end;
procedure FsOnReadChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnReadChunk(APacket, AErr, AContext); end;
procedure FsOnReadClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnReadClose(APacket, AErr, AContext); end;
procedure FsOnWriteOpen(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnWriteOpen(APacket, AErr, AContext); end;
procedure FsOnWriteChunk(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnWriteChunk(APacket, AErr, AContext); end;
procedure FsOnWriteClose(const APacket: TBytes; AErr: ESSHError; AContext: Pointer);
begin TAsyncSftpFileSystem(AContext).OnWriteClose(APacket, AErr, AContext); end;

end.
