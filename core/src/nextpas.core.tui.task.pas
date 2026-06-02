unit nextpas.core.tui.task;
{$I nextpas.core.settings.inc}

interface
uses
  SysUtils{$IF FPC_FULLVERSION >= 30300}, Classes{$ENDIF};
const
  TASK_QUEUE_CAPACITY = 32;
  MAX_CONCURRENT_TASKS = 8;
type
  TTaskId = UInt32;
  TTaskStatus = (tsQueued, tsRunning, tsCompleted, tsFailed, tsCancelled);
  PCancelToken = ^TCancelToken;
  TCancelToken = record
    FCancelled: LongInt;
  end;
  PTaskContext = ^TTaskContext;
  TTaskContext = record
    Param: Pointer;
    ParamSize: UInt32;
    Cancel: PCancelToken;
  end;
  TTaskResult = record
    Data: Pointer;
    DataSize: UInt32;
    Error: ShortString;
    Status: TTaskStatus;
  end;
  TTaskFunc = function(const Ctx: TTaskContext): TTaskResult;
  TTaskSpec = record
    Func: TTaskFunc;
    Param: Pointer;
    ParamSize: UInt32;
    Name: ShortString;
  end;
  TCompletionSlot = record
    Id: TTaskId;
    Result: TTaskResult;
  end;
  TTaskManager = class;
{$IF FPC_FULLVERSION >= 30300}
  TTaskThread = class(TThread)
  private
    FId: TTaskId;
    FFunc: TTaskFunc;
    FContext: TTaskContext;
    FManager: TTaskManager;
    FName: ShortString;
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TTaskManager; AId: TTaskId;
                       AFunc: TTaskFunc; const ACtx: TTaskContext;
                       const AName: ShortString);
  end;
{$ENDIF}
  TActiveTask = record
    Id: TTaskId;
  {$IF FPC_FULLVERSION >= 30300}
    Thread: TTaskThread;
  {$ENDIF}
    Cancel: TCancelToken;
    Status: TTaskStatus;
    Done: Boolean;
    Name: ShortString;
  end;
  TPendingTask = record
    Id: TTaskId;
    Func: TTaskFunc;
    ParamCopy: Pointer;
    ParamSize: UInt32;
    Name: ShortString;
  end;
  TTaskManager = class
  private
    FLock: TRTLCriticalSection;
    FCompletions: array[0..TASK_QUEUE_CAPACITY - 1] of TCompletionSlot;
    FCompHead: Integer;
    FCompTail: Integer;
    FCompCount: Integer;
    FOverflow: array of TCompletionSlot;
    FOverflowHead: Integer;
    FOverflowTail: Integer;
    FOverflowCount: Integer;
    FActive: array[0..MAX_CONCURRENT_TASKS - 1] of TActiveTask;
    FActiveCount: Integer;
    FPending: array[0..TASK_QUEUE_CAPACITY - 1] of TPendingTask;
    FPendHead: Integer;
    FPendTail: Integer;
    FPendCount: Integer;
    FNextId: LongInt;
    FShuttingDown: Boolean;
    procedure ScheduleNext;
    function FindFreeSlot: Integer;
    function FindActiveById(Id: TTaskId): Integer;
    function FindPendingById(Id: TTaskId): Integer;
    procedure GrowOverflowQueue;
    procedure PromoteOverflowCompletions;
    procedure EnqueueCompletion(Id: TTaskId; const Res: TTaskResult;
                                const Name: ShortString);
    procedure RemoveCompletionAt(Index: Integer);
    procedure RemoveOverflowAt(Index: Integer);
    procedure RemovePendingAt(Index: Integer);
  {$IF FPC_FULLVERSION >= 30300}
    procedure ReapFinished;
  {$ELSE}
    procedure RunSync(Slot: Integer; Id: TTaskId; Func: TTaskFunc;
                      Param: Pointer; ParamSize: UInt32;
                      const Name: ShortString);
  {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    function Spawn(const Spec: TTaskSpec): TTaskId;
    function Poll(Id: TTaskId; out Res: TTaskResult): Boolean;
    function DrainCompleted(out Slots: array of TCompletionSlot;
                            MaxCount: Integer): Integer;
    procedure Cancel(Id: TTaskId);
    procedure ShutdownAndWait;
    function IsThreaded: Boolean; inline;
    function ActiveCount: Integer; inline;
    function PendingCount: Integer; inline;
    function CompletionCount: Integer; inline;
    procedure OnThreadComplete(Id: TTaskId; const Res: TTaskResult);
  end;
function IsCancelled(const Ctx: TTaskContext): Boolean; inline;
function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
                  const Name: ShortString): TTaskSpec;
implementation
function PrefixTaskError(const Name, Msg: ShortString): ShortString;
begin
  if Name = '' then
    Result := Msg
  else
    Result := Name + ': ' + Msg;
end;

function IsCancelled(const Ctx: TTaskContext): Boolean;
begin
  Result := InterlockedCompareExchange(Ctx.Cancel^.FCancelled, 0, 0) = 1;
end;
function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
                  const Name: ShortString): TTaskSpec;
begin
  Result.Func := Func;
  Result.Param := Param;
  Result.ParamSize := ParamSize;
  Result.Name := Name;
end;
{$IF FPC_FULLVERSION >= 30300}
constructor TTaskThread.Create(AManager: TTaskManager; AId: TTaskId;
                               AFunc: TTaskFunc; const ACtx: TTaskContext;
                               const AName: ShortString);
begin
  FManager := AManager;
  FId := AId;
  FFunc := AFunc;
  FContext := ACtx;
  FName := AName;
  inherited Create(False);
end;
procedure TTaskThread.Execute;
var
  Res: TTaskResult;
begin
  try
    Res := FFunc(FContext);
  except
    on E: Exception do
    begin
      Res.Status := tsFailed;
      Res.Data := nil;
      Res.DataSize := 0;
      Res.Error := PrefixTaskError(FName, E.Message);
    end;
  end;
  if InterlockedCompareExchange(FContext.Cancel^.FCancelled, 0, 0) = 1 then
    Res.Status := tsCancelled;
  FManager.OnThreadComplete(FId, Res);
  if FContext.Param <> nil then
    FreeMem(FContext.Param);
end;
{$ENDIF}
constructor TTaskManager.Create;
var
  I: Integer;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FCompHead := 0;
  FCompTail := 0;
  FCompCount := 0;
  FOverflowHead := 0;
  FOverflowTail := 0;
  FOverflowCount := 0;
  FActiveCount := 0;
  FPendHead := 0;
  FPendTail := 0;
  FPendCount := 0;
  FNextId := 0;
  FShuttingDown := False;
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
  begin
    FActive[I].Id := 0;
  {$IF FPC_FULLVERSION >= 30300}
    FActive[I].Thread := nil;
  {$ENDIF}
    FActive[I].Status := tsQueued;
    FActive[I].Done := True;
    FActive[I].Name := '';
  end;
end;
destructor TTaskManager.Destroy;
begin
  ShutdownAndWait;
  DoneCriticalSection(FLock);
  inherited;
end;
function TTaskManager.FindFreeSlot: Integer;
var
  I: Integer;
begin
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    if FActive[I].Done then
      Exit(I);
  Result := -1;
end;
function TTaskManager.FindActiveById(Id: TTaskId): Integer;
var
  I: Integer;
begin
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    if (not FActive[I].Done) and (FActive[I].Id = Id) then
      Exit(I);
  Result := -1;
end;
function TTaskManager.FindPendingById(Id: TTaskId): Integer;
var
  I, J: Integer;
begin
  J := FPendHead;
  for I := 0 to FPendCount - 1 do
  begin
    if FPending[J].Id = Id then
      Exit(J);
    J := (J + 1) mod TASK_QUEUE_CAPACITY;
  end;
  Result := -1;
end;
procedure TTaskManager.GrowOverflowQueue;
var
  NewOverflow: array of TCompletionSlot;
  OldCapacity, NewCapacity, I, ReadPos: Integer;
begin
  OldCapacity := Length(FOverflow);
  if OldCapacity = 0 then
    NewCapacity := TASK_QUEUE_CAPACITY
  else
    NewCapacity := OldCapacity * 2;
  SetLength(NewOverflow, NewCapacity);
  ReadPos := FOverflowHead;
  for I := 0 to FOverflowCount - 1 do
  begin
    NewOverflow[I] := FOverflow[ReadPos];
    if OldCapacity > 0 then
      ReadPos := (ReadPos + 1) mod OldCapacity;
  end;
  FOverflow := NewOverflow;
  FOverflowHead := 0;
  FOverflowTail := FOverflowCount;
end;
procedure TTaskManager.PromoteOverflowCompletions;
begin
  while (FOverflowCount > 0) and (FCompCount < TASK_QUEUE_CAPACITY) do
  begin
    FCompletions[FCompTail] := FOverflow[FOverflowHead];
    FCompTail := (FCompTail + 1) mod TASK_QUEUE_CAPACITY;
    Inc(FCompCount);
    FOverflowHead := (FOverflowHead + 1) mod Length(FOverflow);
    Dec(FOverflowCount);
  end;
end;
procedure TTaskManager.EnqueueCompletion(Id: TTaskId; const Res: TTaskResult;
                                         const Name: ShortString);
begin
  PromoteOverflowCompletions;
  if FCompCount < TASK_QUEUE_CAPACITY then
  begin
    FCompletions[FCompTail].Id := Id;
    FCompletions[FCompTail].Result := Res;
    FCompTail := (FCompTail + 1) mod TASK_QUEUE_CAPACITY;
    Inc(FCompCount);
  end
  else
  begin
    if Res.Data <> nil then
      FreeMem(Res.Data);
    if FOverflowCount >= Length(FOverflow) then
      GrowOverflowQueue;
    FOverflow[FOverflowTail].Id := Id;
    FOverflow[FOverflowTail].Result.Data := nil;
    FOverflow[FOverflowTail].Result.DataSize := 0;
    FOverflow[FOverflowTail].Result.Error :=
      PrefixTaskError(Name, 'completion queue overflow');
    FOverflow[FOverflowTail].Result.Status := tsFailed;
    FOverflowTail := (FOverflowTail + 1) mod Length(FOverflow);
    Inc(FOverflowCount);
  end;
end;
procedure TTaskManager.RemoveCompletionAt(Index: Integer);
var
  ReadPos, WritePos, I: Integer;
begin
  ReadPos := FCompHead;
  WritePos := FCompHead;
  for I := 0 to FCompCount - 1 do
  begin
    if ReadPos <> Index then
    begin
      if WritePos <> ReadPos then
        FCompletions[WritePos] := FCompletions[ReadPos];
      WritePos := (WritePos + 1) mod TASK_QUEUE_CAPACITY;
    end;
    ReadPos := (ReadPos + 1) mod TASK_QUEUE_CAPACITY;
  end;
  FCompTail := WritePos;
  Dec(FCompCount);
end;
procedure TTaskManager.RemoveOverflowAt(Index: Integer);
var
  ReadPos, WritePos, I, Capacity: Integer;
begin
  Capacity := Length(FOverflow);
  ReadPos := FOverflowHead;
  WritePos := FOverflowHead;
  for I := 0 to FOverflowCount - 1 do
  begin
    if ReadPos <> Index then
    begin
      if WritePos <> ReadPos then
        FOverflow[WritePos] := FOverflow[ReadPos];
      WritePos := (WritePos + 1) mod Capacity;
    end;
    ReadPos := (ReadPos + 1) mod Capacity;
  end;
  FOverflowTail := WritePos;
  Dec(FOverflowCount);
end;
procedure TTaskManager.RemovePendingAt(Index: Integer);
var
  ReadPos, WritePos, I: Integer;
begin
  ReadPos := FPendHead;
  WritePos := FPendHead;
  for I := 0 to FPendCount - 1 do
  begin
    if ReadPos <> Index then
    begin
      if WritePos <> ReadPos then
        FPending[WritePos] := FPending[ReadPos];
      WritePos := (WritePos + 1) mod TASK_QUEUE_CAPACITY;
    end;
    ReadPos := (ReadPos + 1) mod TASK_QUEUE_CAPACITY;
  end;
  FPendTail := WritePos;
  Dec(FPendCount);
end;
{$IF FPC_FULLVERSION >= 30300}
procedure TTaskManager.ReapFinished;
var
  I: Integer;
  T: TTaskThread;
  Threads: array[0..MAX_CONCURRENT_TASKS - 1] of TTaskThread;
  ThreadCount: Integer;
begin
  ThreadCount := 0;
  EnterCriticalSection(FLock);
  try
    for I := 0 to MAX_CONCURRENT_TASKS - 1 do
      if (FActive[I].Thread <> nil) and FActive[I].Done then
      begin
        Threads[ThreadCount] := FActive[I].Thread;
        FActive[I].Thread := nil;
        Inc(ThreadCount);
      end;
  finally
    LeaveCriticalSection(FLock);
  end;
  for I := 0 to ThreadCount - 1 do
  begin
    T := Threads[I];
    T.WaitFor;
    T.Free;
  end;
end;
{$ELSE}
procedure TTaskManager.RunSync(Slot: Integer; Id: TTaskId; Func: TTaskFunc;
                               Param: Pointer; ParamSize: UInt32;
                               const Name: ShortString);
var
  Ctx: TTaskContext;
  Res: TTaskResult;
begin
  FActive[Slot].Id := Id;
  FActive[Slot].Cancel.FCancelled := 0;
  FActive[Slot].Status := tsRunning;
  FActive[Slot].Done := False;
  FActive[Slot].Name := Name;
  Inc(FActiveCount);
  Ctx.Param := Param;
  Ctx.ParamSize := ParamSize;
  Ctx.Cancel := @FActive[Slot].Cancel;
  try
    Res := Func(Ctx);
  except
    on E: Exception do
    begin
      Res.Status := tsFailed;
      Res.Data := nil;
      Res.DataSize := 0;
      Res.Error := PrefixTaskError(Name, E.Message);
    end;
  end;
  if InterlockedCompareExchange(FActive[Slot].Cancel.FCancelled, 0, 0) = 1 then
    Res.Status := tsCancelled;
  FActive[Slot].Status := Res.Status;
  FActive[Slot].Done := True;
  Dec(FActiveCount);
  EnqueueCompletion(Id, Res, Name);
  if Param <> nil then
    FreeMem(Param);
end;
{$ENDIF}
procedure TTaskManager.ScheduleNext;
var
  Slot, I, LaunchCount: Integer;
  P: TPendingTask;
{$IF FPC_FULLVERSION >= 30300}
  Ctx: TTaskContext;
{$ENDIF}
  ToLaunch: array[0..MAX_CONCURRENT_TASKS - 1] of record
    Slot: Integer;
    Id: TTaskId;
    Func: TTaskFunc;
    Param: Pointer;
    ParamSize: UInt32;
    Name: ShortString;
  end;
begin
  LaunchCount := 0;
{$IF FPC_FULLVERSION >= 30300}
  ReapFinished;
{$ENDIF}
  EnterCriticalSection(FLock);
  try
    while (FPendCount > 0) and (FActiveCount < MAX_CONCURRENT_TASKS) do
    begin
      Slot := FindFreeSlot;
      if Slot < 0 then Break;
      P := FPending[FPendHead];
      FPendHead := (FPendHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FPendCount);
      FActive[Slot].Id := P.Id;
      FActive[Slot].Cancel.FCancelled := 0;
      FActive[Slot].Status := tsRunning;
      FActive[Slot].Done := False;
      FActive[Slot].Name := P.Name;
    {$IF FPC_FULLVERSION >= 30300}
      FActive[Slot].Thread := nil;
    {$ENDIF}
      Inc(FActiveCount);
      ToLaunch[LaunchCount].Slot := Slot;
      ToLaunch[LaunchCount].Id := P.Id;
      ToLaunch[LaunchCount].Func := P.Func;
      ToLaunch[LaunchCount].Param := P.ParamCopy;
      ToLaunch[LaunchCount].ParamSize := P.ParamSize;
      ToLaunch[LaunchCount].Name := P.Name;
      Inc(LaunchCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  for I := 0 to LaunchCount - 1 do
  begin
  {$IF FPC_FULLVERSION >= 30300}
    Ctx.Param := ToLaunch[I].Param;
    Ctx.ParamSize := ToLaunch[I].ParamSize;
    Ctx.Cancel := @FActive[ToLaunch[I].Slot].Cancel;
    FActive[ToLaunch[I].Slot].Thread := TTaskThread.Create(
      Self, ToLaunch[I].Id, ToLaunch[I].Func, Ctx, ToLaunch[I].Name);
  {$ELSE}
    RunSync(ToLaunch[I].Slot, ToLaunch[I].Id, ToLaunch[I].Func,
            ToLaunch[I].Param, ToLaunch[I].ParamSize, ToLaunch[I].Name);
  {$ENDIF}
  end;
end;
function TTaskManager.Spawn(const Spec: TTaskSpec): TTaskId;
var
  Id: TTaskId;
  ParamCopy: Pointer;
  Slot: Integer;
  ShouldLaunch: Boolean;
{$IF FPC_FULLVERSION >= 30300}
  Ctx: TTaskContext;
{$ENDIF}
begin
  Id := TTaskId(InterlockedIncrement(FNextId));
  ParamCopy := nil;
  if (Spec.Param <> nil) and (Spec.ParamSize > 0) then
  begin
    GetMem(ParamCopy, Spec.ParamSize);
    Move(Spec.Param^, ParamCopy^, Spec.ParamSize);
  end;
  ShouldLaunch := False;
  Slot := -1;
{$IF FPC_FULLVERSION >= 30300}
  ReapFinished;
{$ENDIF}
  EnterCriticalSection(FLock);
  try
    if FShuttingDown then
    begin
      if ParamCopy <> nil then FreeMem(ParamCopy);
      Result := 0;
      Exit;
    end;
    Slot := FindFreeSlot;
    if (Slot >= 0) and (FActiveCount < MAX_CONCURRENT_TASKS) then
    begin
      FActive[Slot].Id := Id;
      FActive[Slot].Cancel.FCancelled := 0;
      FActive[Slot].Status := tsRunning;
      FActive[Slot].Done := False;
      FActive[Slot].Name := Spec.Name;
    {$IF FPC_FULLVERSION >= 30300}
      FActive[Slot].Thread := nil;
    {$ENDIF}
      Inc(FActiveCount);
      ShouldLaunch := True;
    end
    else
    begin
      if FPendCount >= TASK_QUEUE_CAPACITY then
      begin
        if ParamCopy <> nil then FreeMem(ParamCopy);
        Result := 0;
        Exit;
      end;
      FPending[FPendTail].Id := Id;
      FPending[FPendTail].Func := Spec.Func;
      FPending[FPendTail].ParamCopy := ParamCopy;
      FPending[FPendTail].ParamSize := Spec.ParamSize;
      FPending[FPendTail].Name := Spec.Name;
      FPendTail := (FPendTail + 1) mod TASK_QUEUE_CAPACITY;
      Inc(FPendCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if ShouldLaunch then
  begin
  {$IF FPC_FULLVERSION >= 30300}
    Ctx.Param := ParamCopy;
    Ctx.ParamSize := Spec.ParamSize;
    Ctx.Cancel := @FActive[Slot].Cancel;
    FActive[Slot].Thread := TTaskThread.Create(Self, Id, Spec.Func, Ctx, Spec.Name);
  {$ELSE}
    RunSync(Slot, Id, Spec.Func, ParamCopy, Spec.ParamSize, Spec.Name);
  {$ENDIF}
  end;
  Result := Id;
end;
procedure TTaskManager.OnThreadComplete(Id: TTaskId; const Res: TTaskResult);
var
  I: Integer;
  Name: ShortString;
begin
  Name := '';
  EnterCriticalSection(FLock);
  try
    I := FindActiveById(Id);
    if I >= 0 then
    begin
      Name := FActive[I].Name;
      FActive[I].Status := Res.Status;
      FActive[I].Done := True;
      Dec(FActiveCount);
    end;
    EnqueueCompletion(Id, Res, Name);
  finally
    LeaveCriticalSection(FLock);
  end;
end;
function TTaskManager.Poll(Id: TTaskId; out Res: TTaskResult): Boolean;
var
  I, J: Integer;
  ShouldSchedule: Boolean;
begin
  Result := False;
  ShouldSchedule := False;
  EnterCriticalSection(FLock);
  try
    PromoteOverflowCompletions;
    J := FCompHead;
    for I := 0 to FCompCount - 1 do
    begin
      if FCompletions[J].Id = Id then
      begin
        Res := FCompletions[J].Result;
        RemoveCompletionAt(J);
        PromoteOverflowCompletions;
        Result := True;
        ShouldSchedule := True;
        Break;
      end;
      J := (J + 1) mod TASK_QUEUE_CAPACITY;
    end;
    if not Result then
    begin
      J := FOverflowHead;
      for I := 0 to FOverflowCount - 1 do
      begin
        if FOverflow[J].Id = Id then
        begin
          Res := FOverflow[J].Result;
          RemoveOverflowAt(J);
          PromoteOverflowCompletions;
          Result := True;
          ShouldSchedule := True;
          Break;
        end;
        J := (J + 1) mod Length(FOverflow);
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if ShouldSchedule then
    ScheduleNext;
end;
function TTaskManager.DrainCompleted(out Slots: array of TCompletionSlot;
                                      MaxCount: Integer): Integer;
var
  Count: Integer;
begin
  Count := 0;
{$IF FPC_FULLVERSION >= 30300}
  ReapFinished;
{$ENDIF}
  EnterCriticalSection(FLock);
  try
    PromoteOverflowCompletions;
    while (FCompCount > 0) and (Count < MaxCount) do
    begin
      Slots[Count] := FCompletions[FCompHead];
      FCompHead := (FCompHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FCompCount);
      Inc(Count);
      PromoteOverflowCompletions;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Count > 0 then
    ScheduleNext;
  Result := Count;
end;
procedure TTaskManager.Cancel(Id: TTaskId);
var
  I: Integer;
  Pending: TPendingTask;
  Res: TTaskResult;
  ShouldSchedule: Boolean;
begin
  ShouldSchedule := False;
  EnterCriticalSection(FLock);
  try
    I := FindActiveById(Id);
    if I >= 0 then
    begin
      InterlockedExchange(FActive[I].Cancel.FCancelled, 1);
      ShouldSchedule := not FShuttingDown;
    end
    else
    begin
      I := FindPendingById(Id);
      if I >= 0 then
      begin
        Pending := FPending[I];
        RemovePendingAt(I);
        if Pending.ParamCopy <> nil then
          FreeMem(Pending.ParamCopy);
        Res.Data := nil;
        Res.DataSize := 0;
        Res.Error := '';
        Res.Status := tsCancelled;
        EnqueueCompletion(Id, Res, Pending.Name);
        ShouldSchedule := not FShuttingDown;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if ShouldSchedule then
    ScheduleNext;
end;
procedure TTaskManager.ShutdownAndWait;
var
  I: Integer;
{$IF FPC_FULLVERSION >= 30300}
  Threads: array[0..MAX_CONCURRENT_TASKS - 1] of TTaskThread;
  ThreadCount: Integer;
{$ENDIF}
begin
{$IF FPC_FULLVERSION >= 30300}
  ThreadCount := 0;
  EnterCriticalSection(FLock);
  try
    FShuttingDown := True;
    for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    begin
      if FActive[I].Thread <> nil then
      begin
        InterlockedExchange(FActive[I].Cancel.FCancelled, 1);
        Threads[ThreadCount] := FActive[I].Thread;
        FActive[I].Thread := nil;
        Inc(ThreadCount);
      end;
    end;
    for I := 0 to FPendCount - 1 do
      if FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy <> nil then
        FreeMem(FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy);
    FPendCount := 0;
  finally
    LeaveCriticalSection(FLock);
  end;
  for I := 0 to ThreadCount - 1 do
  begin
    Threads[I].WaitFor;
    Threads[I].Free;
  end;
  EnterCriticalSection(FLock);
  try
    FActiveCount := 0;
    while FCompCount > 0 do
    begin
      if FCompletions[FCompHead].Result.Data <> nil then
        FreeMem(FCompletions[FCompHead].Result.Data);
      FCompHead := (FCompHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FCompCount);
    end;
    while FOverflowCount > 0 do
    begin
      if FOverflow[FOverflowHead].Result.Data <> nil then
        FreeMem(FOverflow[FOverflowHead].Result.Data);
      FOverflowHead := (FOverflowHead + 1) mod Length(FOverflow);
      Dec(FOverflowCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
{$ELSE}
  EnterCriticalSection(FLock);
  try
    FShuttingDown := True;
    for I := 0 to FPendCount - 1 do
      if FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy <> nil then
        FreeMem(FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy);
    FPendCount := 0;
    FActiveCount := 0;
    while FCompCount > 0 do
    begin
      if FCompletions[FCompHead].Result.Data <> nil then
        FreeMem(FCompletions[FCompHead].Result.Data);
      FCompHead := (FCompHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FCompCount);
    end;
    while FOverflowCount > 0 do
    begin
      if FOverflow[FOverflowHead].Result.Data <> nil then
        FreeMem(FOverflow[FOverflowHead].Result.Data);
      FOverflowHead := (FOverflowHead + 1) mod Length(FOverflow);
      Dec(FOverflowCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
{$ENDIF}
end;
function TTaskManager.IsThreaded: Boolean;
begin
{$IF FPC_FULLVERSION >= 30300}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
end;
function TTaskManager.ActiveCount: Integer;
begin
{$IF FPC_FULLVERSION >= 30300}
  ReapFinished;
{$ENDIF}
  EnterCriticalSection(FLock);
  try
    Result := FActiveCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;
function TTaskManager.PendingCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FPendCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;
function TTaskManager.CompletionCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    PromoteOverflowCompletions;
    Result := FCompCount + FOverflowCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;
end.
