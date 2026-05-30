unit nextpas.core.coroutine;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.coroutine.base,
  nextpas.core.coroutine.intf;

type
  TCoroutineID = nextpas.core.coroutine.base.TCoroutineID;
  TCoroutineState = nextpas.core.coroutine.base.TCoroutineState;
  TYieldKind = nextpas.core.coroutine.base.TYieldKind;
  TCoroStep = nextpas.core.coroutine.base.TCoroStep;
  TCoroStepKind = nextpas.core.coroutine.base.TCoroStepKind;
  TCoroutineProc = nextpas.core.coroutine.base.TCoroutineProc;
  TCoroutineCondition = nextpas.core.coroutine.base.TCoroutineCondition;
  TCoroStepAction = nextpas.core.coroutine.base.TCoroStepAction;
  ICoroutineManager = nextpas.core.coroutine.intf.ICoroutineManager;

{** 创建协程管理器实例 *}
function CreateCoroutineManager: ICoroutineManager;

{** 构建步骤的便利函数 *}
function CoroAction(AAction: TCoroStepAction): TCoroStep; inline;
function CoroWaitSeconds(ASeconds: Single): TCoroStep; inline;
function CoroWaitFrames(AFrames: Integer): TCoroStep; inline;
function CoroWaitUntil(ACondition: TCoroutineCondition; AData: Pointer = nil): TCoroStep; inline;
function CoroEnd: TCoroStep; inline;

implementation

type
  TYieldInfo = record
    Kind: TYieldKind;
    FramesLeft: Integer;
    SecondsLeft: Single;
    Condition: TCoroutineCondition;
    ConditionData: Pointer;
    WaitCoroID: TCoroutineID;
  end;

  TCoroutineEntry = record
    ID: TCoroutineID;
    State: TCoroutineState;
    Proc: TCoroutineProc;
    UserData: Pointer;
    Yield: TYieldInfo;
    Tag: Integer;
    Active: Boolean;
    Steps: PCoroStep;
    StepCount: Integer;
    StepIndex: Integer;
  end;

  TCoroutineManager = class(TInterfacedObject, ICoroutineManager)
  private
    FEntries: array[0..COROUTINE_MAX_ACTIVE - 1] of TCoroutineEntry;
    FActiveCount: Integer;
    FNextID: TCoroutineID;
    function FindEntry(AID: TCoroutineID): Integer;
    procedure RunSequenceStep(AIdx: Integer);
  public
    constructor Create;
    function Start(AProc: TCoroutineProc; AUserData: Pointer = nil;
      ATag: Integer = 0): TCoroutineID;
    function StartSequence(ASteps: PCoroStep; AStepCount: Integer;
      AUserData: Pointer = nil; ATag: Integer = 0): TCoroutineID;
    procedure Stop(AID: TCoroutineID);
    procedure StopByTag(ATag: Integer);
    procedure StopAll;
    procedure YieldFrames(AID: TCoroutineID; AFrames: Integer);
    procedure YieldSeconds(AID: TCoroutineID; ASeconds: Single);
    procedure YieldUntil(AID: TCoroutineID; ACondition: TCoroutineCondition;
      AConditionData: Pointer = nil);
    procedure YieldCoroutine(AID: TCoroutineID; AWaitFor: TCoroutineID);
    procedure Update(ADeltaTime: Single);
    function GetState(AID: TCoroutineID): TCoroutineState;
    function GetActiveCount: Integer;
  end;

{ TCoroutineManager }

constructor TCoroutineManager.Create;
var
  LIdx: Integer;
begin
  inherited Create;
  FActiveCount := 0;
  FNextID := 1;
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    FEntries[LIdx].Active := False;
end;

function TCoroutineManager.FindEntry(AID: TCoroutineID): Integer;
var
  LIdx: Integer;
begin
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    if FEntries[LIdx].Active and (FEntries[LIdx].ID = AID) then
      Exit(LIdx);
  Result := -1;
end;

function TCoroutineManager.Start(AProc: TCoroutineProc; AUserData: Pointer;
  ATag: Integer): TCoroutineID;
var
  LIdx: Integer;
begin
  if FActiveCount >= COROUTINE_MAX_ACTIVE then
    Exit(COROUTINE_INVALID_ID);

  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    if not FEntries[LIdx].Active then
    begin
      FEntries[LIdx].ID := FNextID;
      FEntries[LIdx].State := csRunning;
      FEntries[LIdx].Proc := AProc;
      FEntries[LIdx].UserData := AUserData;
      FEntries[LIdx].Tag := ATag;
      FEntries[LIdx].Active := True;
      FEntries[LIdx].Steps := nil;
      FEntries[LIdx].StepCount := 0;
      FEntries[LIdx].StepIndex := 0;
      FEntries[LIdx].Yield.Kind := ykNone;
      Inc(FActiveCount);
      Result := FNextID;
      Inc(FNextID);
      Exit;
    end;
  Result := COROUTINE_INVALID_ID;
end;

function TCoroutineManager.StartSequence(ASteps: PCoroStep; AStepCount: Integer;
  AUserData: Pointer; ATag: Integer): TCoroutineID;
var
  LIdx: Integer;
begin
  if FActiveCount >= COROUTINE_MAX_ACTIVE then
    Exit(COROUTINE_INVALID_ID);

  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    if not FEntries[LIdx].Active then
    begin
      FEntries[LIdx].ID := FNextID;
      FEntries[LIdx].State := csRunning;
      FEntries[LIdx].Proc := nil;
      FEntries[LIdx].UserData := AUserData;
      FEntries[LIdx].Tag := ATag;
      FEntries[LIdx].Active := True;
      FEntries[LIdx].Steps := ASteps;
      FEntries[LIdx].StepCount := AStepCount;
      FEntries[LIdx].StepIndex := 0;
      FEntries[LIdx].Yield.Kind := ykNone;
      Inc(FActiveCount);
      Result := FNextID;
      Inc(FNextID);
      RunSequenceStep(LIdx);
      Exit;
    end;
  Result := COROUTINE_INVALID_ID;
end;

procedure TCoroutineManager.Stop(AID: TCoroutineID);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].Active := False;
    FEntries[LIdx].State := csFinished;
    Dec(FActiveCount);
  end;
end;

procedure TCoroutineManager.StopByTag(ATag: Integer);
var
  LIdx: Integer;
begin
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    if FEntries[LIdx].Active and (FEntries[LIdx].Tag = ATag) then
    begin
      FEntries[LIdx].Active := False;
      FEntries[LIdx].State := csFinished;
      Dec(FActiveCount);
    end;
end;

procedure TCoroutineManager.StopAll;
var
  LIdx: Integer;
begin
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    if FEntries[LIdx].Active then
    begin
      FEntries[LIdx].Active := False;
      FEntries[LIdx].State := csFinished;
    end;
  FActiveCount := 0;
end;

procedure TCoroutineManager.YieldFrames(AID: TCoroutineID; AFrames: Integer);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].State := csSuspended;
    FEntries[LIdx].Yield.Kind := ykFrames;
    FEntries[LIdx].Yield.FramesLeft := AFrames;
  end;
end;

procedure TCoroutineManager.YieldSeconds(AID: TCoroutineID; ASeconds: Single);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].State := csSuspended;
    FEntries[LIdx].Yield.Kind := ykSeconds;
    FEntries[LIdx].Yield.SecondsLeft := ASeconds;
  end;
end;

procedure TCoroutineManager.YieldUntil(AID: TCoroutineID;
  ACondition: TCoroutineCondition; AConditionData: Pointer);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].State := csSuspended;
    FEntries[LIdx].Yield.Kind := ykUntil;
    FEntries[LIdx].Yield.Condition := ACondition;
    FEntries[LIdx].Yield.ConditionData := AConditionData;
  end;
end;

procedure TCoroutineManager.YieldCoroutine(AID: TCoroutineID; AWaitFor: TCoroutineID);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].State := csSuspended;
    FEntries[LIdx].Yield.Kind := ykCoroutine;
    FEntries[LIdx].Yield.WaitCoroID := AWaitFor;
  end;
end;

procedure TCoroutineManager.RunSequenceStep(AIdx: Integer);
var
  LStep: PCoroStep;
begin
  while FEntries[AIdx].Active and (FEntries[AIdx].StepIndex < FEntries[AIdx].StepCount) do
  begin
    LStep := FEntries[AIdx].Steps + FEntries[AIdx].StepIndex;
    case LStep^.Kind of
      cskAction:
      begin
        if Assigned(LStep^.Action) then
          LStep^.Action(FEntries[AIdx].UserData);
        Inc(FEntries[AIdx].StepIndex);
      end;
      cskWaitSeconds:
      begin
        FEntries[AIdx].State := csSuspended;
        FEntries[AIdx].Yield.Kind := ykSeconds;
        FEntries[AIdx].Yield.SecondsLeft := LStep^.Seconds;
        Inc(FEntries[AIdx].StepIndex);
        Exit;
      end;
      cskWaitFrames:
      begin
        FEntries[AIdx].State := csSuspended;
        FEntries[AIdx].Yield.Kind := ykFrames;
        FEntries[AIdx].Yield.FramesLeft := LStep^.Frames;
        Inc(FEntries[AIdx].StepIndex);
        Exit;
      end;
      cskWaitUntil:
      begin
        FEntries[AIdx].State := csSuspended;
        FEntries[AIdx].Yield.Kind := ykUntil;
        FEntries[AIdx].Yield.Condition := LStep^.Condition;
        FEntries[AIdx].Yield.ConditionData := LStep^.ConditionData;
        Inc(FEntries[AIdx].StepIndex);
        Exit;
      end;
      cskEnd:
      begin
        FEntries[AIdx].State := csFinished;
        FEntries[AIdx].Active := False;
        Dec(FActiveCount);
        Exit;
      end;
    end;
  end;
  if FEntries[AIdx].StepIndex >= FEntries[AIdx].StepCount then
  begin
    FEntries[AIdx].State := csFinished;
    FEntries[AIdx].Active := False;
    Dec(FActiveCount);
  end;
end;

procedure TCoroutineManager.Update(ADeltaTime: Single);
var
  LIdx: Integer;
  LResumed: Boolean;
begin
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
  begin
    if not FEntries[LIdx].Active then Continue;

    if FEntries[LIdx].State = csSuspended then
    begin
      LResumed := False;
      case FEntries[LIdx].Yield.Kind of
        ykFrames:
        begin
          Dec(FEntries[LIdx].Yield.FramesLeft);
          if FEntries[LIdx].Yield.FramesLeft <= 0 then
            LResumed := True;
        end;
        ykSeconds:
        begin
          FEntries[LIdx].Yield.SecondsLeft :=
            FEntries[LIdx].Yield.SecondsLeft - ADeltaTime;
          if FEntries[LIdx].Yield.SecondsLeft <= 0 then
            LResumed := True;
        end;
        ykUntil:
        begin
          if Assigned(FEntries[LIdx].Yield.Condition) and
             FEntries[LIdx].Yield.Condition(FEntries[LIdx].Yield.ConditionData) then
            LResumed := True;
        end;
        ykCoroutine:
        begin
          if FindEntry(FEntries[LIdx].Yield.WaitCoroID) < 0 then
            LResumed := True;
        end;
      end;

      if LResumed then
      begin
        FEntries[LIdx].State := csRunning;
        FEntries[LIdx].Yield.Kind := ykNone;
        if FEntries[LIdx].Steps <> nil then
          RunSequenceStep(LIdx);
      end;
    end;
  end;
end;

function TCoroutineManager.GetState(AID: TCoroutineID): TCoroutineState;
var
  LIdx: Integer;
begin
  LIdx := FindEntry(AID);
  if LIdx >= 0 then
    Result := FEntries[LIdx].State
  else
    Result := csFinished;
end;

function TCoroutineManager.GetActiveCount: Integer;
begin
  Result := FActiveCount;
end;

{ Factory }

function CreateCoroutineManager: ICoroutineManager;
begin
  Result := TCoroutineManager.Create;
end;

{ Step builders }

function CoroAction(AAction: TCoroStepAction): TCoroStep;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := cskAction;
  Result.Action := AAction;
end;

function CoroWaitSeconds(ASeconds: Single): TCoroStep;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := cskWaitSeconds;
  Result.Seconds := ASeconds;
end;

function CoroWaitFrames(AFrames: Integer): TCoroStep;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := cskWaitFrames;
  Result.Frames := AFrames;
end;

function CoroWaitUntil(ACondition: TCoroutineCondition; AData: Pointer): TCoroStep;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := cskWaitUntil;
  Result.Condition := ACondition;
  Result.ConditionData := AData;
end;

function CoroEnd: TCoroStep;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := cskEnd;
end;

end.
