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
  nextpas.core.atomic;

{ TActor }

constructor TActor.Create(AId: Int64; AHandler: TActorHandler; AMaxMailbox: Int32);
begin
  inherited Create;
  FId := AId;
  FMailHead := nil;
  FMailTail := nil;
  FMailCount := 0;
  FMaxMailbox := AMaxMailbox;
  FState := asRunning;
  FHandler := AHandler;
  FLock := 0;
end;

destructor TActor.Destroy;
var
  LNode, LNext: PMessageNode;
begin
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
begin
  if FState <> asRunning then
    Exit(arStopped);
  if FMailCount >= FMaxMailbox then
    Exit(arMailboxFull);
  New(LNode);
  LNode^.Msg := AMsg;
  LNode^.Next := nil;
  while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
    CpuPause;
  if FMailTail <> nil then
    FMailTail^.Next := LNode
  else
    FMailHead := LNode;
  FMailTail := LNode;
  Inc(FMailCount);
  AtomicStore32(FLock, 0, moRelease);
  ProcessMailbox;
  Result := arOk;
end;

procedure TActor.ProcessMailbox;
var
  LNode: PMessageNode;
begin
  while True do
  begin
    while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
      CpuPause;
    LNode := FMailHead;
    if LNode <> nil then
    begin
      FMailHead := LNode^.Next;
      if FMailHead = nil then
        FMailTail := nil;
      Dec(FMailCount);
      AtomicStore32(FLock, 0, moRelease);
      try
        if Assigned(FHandler) then
          FHandler(LNode^.Msg);
      finally
        LNode^.Msg.Data := '';
        Dispose(LNode);
      end;
    end
    else
    begin
      AtomicStore32(FLock, 0, moRelease);
      Break;
    end;
  end;
end;

function TActor.MailCount: Int32;
begin
  Result := AtomicLoad32(FMailCount, moAcquire);
end;

function TActor.GetId: Int64;
begin
  Result := FId;
end;

function TActor.GetState: TActorState;
begin
  Result := FState;
end;

procedure TActor.Stop;
begin
  FState := asStopping;
  ProcessMailbox;
  FState := asStopped;
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
  while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
    CpuPause;
  if FCount >= FCapacity then
  begin
    FCapacity := FCapacity * 2;
    SetLength(FActors, FCapacity);
  end;
  Result := TActor.Create(LId, AHandler, AMaxMailbox);
  FActors[FCount] := Result;
  Inc(FCount);
  AtomicStore32(FLock, 0, moRelease);
end;

function TActorSystem.Find(AId: Int64): TActor;
var
  LI: Int32;
begin
  Result := nil;
  for LI := 0 to FCount - 1 do
    if FActors[LI].GetId = AId then
      Exit(FActors[LI]);
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
begin
  for LI := 0 to FCount - 1 do
    FActors[LI].Stop;
end;

function TActorSystem.Count: Int32;
begin
  Result := FCount;
end;

end.
