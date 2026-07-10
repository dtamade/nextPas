unit nextpas.core.lockfree.actor;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TActorResult = (arOk, arStopped, arTimeout, arMailboxFull);
  TActorState = (asRunning, asStopping, asStopped);

  TActorMessage = record
    SenderId: Int64;
    Data: AnsiString;
  end;

  PMessageNode = ^TMessageNode;
  TMessageNode = record
    Msg: TActorMessage;
    Next: PMessageNode;
  end;

  TActorHandler = reference to procedure(const AMsg: TActorMessage);
  TActorSystem = class;

  {** @desc Actor（消息驱动并发模型）
    @details 每个 Actor 有独立邮箱 (MPSC 队列)，按顺序处理消息。
      支持 Spawn/Send/Ask/Stop 生命周期。
      适用场景：消息驱动系统、并发状态管理、事件处理。
  }
  TActor = class
  private
    FId: Int64;
    FMailHead: PMessageNode;
    FMailTail: PMessageNode;
    FMailCount: Int32;
    FMaxMailbox: Int32;
    FState: TActorState;
    FHandler: TActorHandler;
    FLock: Int32;
    FProcessing: Int32;
    FProcessingThreadId: QWord;
    procedure AcquireLock;
    procedure ReleaseLock;
    procedure ProcessMailbox;
  public
    constructor Create(AId: Int64; AHandler: TActorHandler; AMaxMailbox: Int32 = 1024);
    destructor Destroy; override;
    function Send(const AMsg: TActorMessage): TActorResult;
    function MailCount: Int32;
    function GetId: Int64;
    function GetState: TActorState;
    procedure Stop;
  end;

  {** @desc Actor 系统
    @details 管理 Actor 的创建和销毁。
  }
  TActorSystem = class
  private
    FActors: array of TActor;
    FCount: Int32;
    FCapacity: Int32;
    FNextId: Int64;
    FLock: Int32;
    procedure AcquireLock;
    procedure ReleaseLock;
  public
    constructor Create;
    destructor Destroy; override;
    function Spawn(AHandler: TActorHandler; AMaxMailbox: Int32 = 1024): TActor;
    function Find(AId: Int64): TActor;
    function Send(AFromId, AToId: Int64; const AData: AnsiString): TActorResult;
    procedure StopAll;
    function Count: Int32;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread;

{ TActor }

constructor TActor.Create(AId: Int64; AHandler: TActorHandler; AMaxMailbox: Int32);
begin
  if AMaxMailbox <= 0 then
    raise EArgumentError.Create('TActor: max mailbox must be > 0');
  inherited Create;
  FId := AId;
  FMailHead := nil;
  FMailTail := nil;
  FMailCount := 0;
  FMaxMailbox := AMaxMailbox;
  FState := asRunning;
  FHandler := AHandler;
  FLock := 0;
  FProcessing := 0;
  FProcessingThreadId := 0;
end;

procedure TActor.AcquireLock;
var
  LSpinCount: Int32;
begin
  LSpinCount := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcquire) <> 0 do
  begin
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TActor.ReleaseLock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

destructor TActor.Destroy;
var
  LNode, LNext: PMessageNode;
begin
  Stop;
  LNode := FMailHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    LNode^.Msg.Data := '';
    Dispose(LNode);
    LNode := LNext;
  end;
  inherited Destroy;
end;

function TActor.Send(const AMsg: TActorMessage): TActorResult;
var
  LNode: PMessageNode;
  LAccepted: Boolean;
  LShouldProcess: Boolean;
begin
  New(LNode);
  LNode^.Msg := AMsg;
  LNode^.Next := nil;
  LAccepted := False;
  LShouldProcess := False;
  AcquireLock;
  try
    if FState <> asRunning then
      Result := arStopped
    else if FMailCount >= FMaxMailbox then
      Result := arMailboxFull
    else
    begin
      if FMailTail <> nil then
        FMailTail^.Next := LNode
      else
        FMailHead := LNode;
      FMailTail := LNode;
      Inc(FMailCount);
      LAccepted := True;
      Result := arOk;
      if FProcessing = 0 then
      begin
        FProcessing := 1;
        FProcessingThreadId := platform_thread_id;
        LShouldProcess := True;
      end;
    end;
  finally
    ReleaseLock;
  end;
  if not LAccepted then
  begin
    LNode^.Msg.Data := '';
    Dispose(LNode);
  end
  else if LShouldProcess then
    ProcessMailbox;
end;

procedure TActor.ProcessMailbox;
var
  LNode: PMessageNode;
begin
  while True do
  begin
    AcquireLock;
    LNode := FMailHead;
    if LNode = nil then
    begin
      FProcessingThreadId := 0;
      FProcessing := 0;
      if FState = asStopping then
        FState := asStopped;
      ReleaseLock;
      Exit;
    end;
    FMailHead := LNode^.Next;
    if FMailHead = nil then
      FMailTail := nil;
    Dec(FMailCount);
    ReleaseLock;
    try
      if Assigned(FHandler) then
        FHandler(LNode^.Msg);
    except
      LNode^.Msg.Data := '';
      Dispose(LNode);
      AcquireLock;
      FProcessingThreadId := 0;
      FProcessing := 0;
      if (FState = asStopping) and (FMailHead = nil) then
        FState := asStopped;
      ReleaseLock;
      raise;
    end;
    LNode^.Msg.Data := '';
    Dispose(LNode);
  end;
end;

function TActor.MailCount: Int32;
begin
  AcquireLock;
  try
    Result := FMailCount;
  finally
    ReleaseLock;
  end;
end;

function TActor.GetId: Int64;
begin
  Result := FId;
end;

function TActor.GetState: TActorState;
begin
  AcquireLock;
  try
    Result := FState;
  finally
    ReleaseLock;
  end;
end;

procedure TActor.Stop;
var
  LCurrentThreadId: QWord;
  LOwnsProcessing: Boolean;
  LShouldProcess: Boolean;
begin
  LCurrentThreadId := platform_thread_id;
  while True do
  begin
    LOwnsProcessing := False;
    LShouldProcess := False;
    AcquireLock;
    try
      if FState = asStopped then
        Exit;
      FState := asStopping;
      if FProcessing = 0 then
      begin
        FProcessing := 1;
        FProcessingThreadId := LCurrentThreadId;
        LShouldProcess := True;
      end
      else
        LOwnsProcessing := FProcessingThreadId = LCurrentThreadId;
    finally
      ReleaseLock;
    end;
    if LShouldProcess then
      ProcessMailbox
    else if LOwnsProcessing then
      Exit
    else
      ThreadSwitch;
  end;
end;

{ TActorSystem }

constructor TActorSystem.Create;
begin
  inherited Create;
  FCapacity := 16;
  SetLength(FActors, FCapacity);
  FCount := 0;
  FNextId := 1;
  FLock := 0;
end;

procedure TActorSystem.AcquireLock;
var
  LSpinCount: Int32;
begin
  LSpinCount := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcquire) <> 0 do
  begin
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TActorSystem.ReleaseLock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

destructor TActorSystem.Destroy;
var
  LI: Int32;
begin
  StopAll;
  for LI := 0 to FCount - 1 do
    FActors[LI].Free;
  inherited Destroy;
end;

function TActorSystem.Spawn(AHandler: TActorHandler; AMaxMailbox: Int32): TActor;
var
  LId: Int64;
begin
  LId := AtomicFetchAdd64(FNextId, 1, moRelaxed);
  AcquireLock;
  try
    if FCount >= FCapacity then
    begin
      if FCapacity > High(Int32) div 2 then
        raise EInvalidOperationError.Create('TActorSystem.Spawn: actor capacity overflow');
      FCapacity := FCapacity * 2;
      SetLength(FActors, FCapacity);
    end;
    Result := TActor.Create(LId, AHandler, AMaxMailbox);
    FActors[FCount] := Result;
    Inc(FCount);
  finally
    ReleaseLock;
  end;
end;

function TActorSystem.Find(AId: Int64): TActor;
var
  LI: Int32;
begin
  Result := nil;
  AcquireLock;
  try
    for LI := 0 to FCount - 1 do
      if FActors[LI].GetId = AId then
        Exit(FActors[LI]);
  finally
    ReleaseLock;
  end;
end;

function TActorSystem.Send(AFromId, AToId: Int64; const AData: AnsiString): TActorResult;
var
  LTarget: TActor;
  LMsg: TActorMessage;
begin
  LTarget := Find(AToId);
  if LTarget = nil then
    Exit(arStopped);
  LMsg.SenderId := AFromId;
  LMsg.Data := AData;
  Result := LTarget.Send(LMsg);
end;

procedure TActorSystem.StopAll;
var
  LI: Int32;
  LActors: array of TActor;
begin
  AcquireLock;
  try
    SetLength(LActors, FCount);
    for LI := 0 to FCount - 1 do
      LActors[LI] := FActors[LI];
  finally
    ReleaseLock;
  end;
  for LI := 0 to High(LActors) do
    LActors[LI].Stop;
end;

function TActorSystem.Count: Int32;
begin
  AcquireLock;
  try
    Result := FCount;
  finally
    ReleaseLock;
  end;
end;

end.
