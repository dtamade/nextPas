program demo_task_completion;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.ext,
  nextpas.core.tui.event;

type
  TAppState = class
  public
    CompletedCount: Integer;
    LastMessage: AnsiString;
  end;

  TTaskScreen = class(TScreen)
  private
    FApp: TApp;        { Constructor-injected app reference; not owned. }
    FInFlight: Boolean;
  public
    constructor Create(AApp: TApp);
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure HandleTaskCompletions(const Slots: array of TCompletionSlot;
      SlotCount: Integer); override;
  end;

function BackgroundWork(const Ctx: TTaskContext): TTaskResult;
var
  I: Integer;
begin
  Result.Status := tsCompleted;
  Result.Data := nil;
  Result.DataSize := 0;
  for I := 1 to 3000000 do
    { simulate cpu work };
end;

{ TTaskScreen }

constructor TTaskScreen.Create(AApp: TApp);
begin
  inherited Create;
  FApp := AApp;
  FInFlight := False;
end;

procedure TTaskScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  S: TAppState;
begin
  S := Self.specialize GetShared<TAppState>;
  ABuffer.SetString(0, 0, '=== Task Completion Demo ===', StyleDefault);
  ABuffer.SetString(0, 2, 'Press "s" to spawn a background task.', StyleDefault);
  ABuffer.SetString(0, 3, 'Press "r" to reset.', StyleDefault);
  if S <> nil then
  begin
    ABuffer.SetString(0, 5, 'Completed: ' + IntToStr(S.CompletedCount), StyleDefault);
    ABuffer.SetString(0, 6, 'Last: ' + S.LastMessage, StyleDefault);
  end;
  ABuffer.SetString(0, 8, 'Shared state updated from HandleTaskCompletions.', StyleDefault);
  ABuffer.SetString(0, 10, 'Press Q or Esc to quit.', StyleDefault);
end;

procedure TTaskScreen.HandleEvent(const Ev: TEvent);
var
  S: TAppState;
begin
  if IsQuit(Ev) then
    Stack.RequestQuit
  else if Ev.Kind = evKey then
  begin
    if Ev.Key.Code = kcChar then
    begin
      case Chr(Ev.Key.Ch) of
        's':
          if not FInFlight then
          begin
            FInFlight := True;
            S := Self.specialize GetShared<TAppState>;
            if S <> nil then S.LastMessage := 'task spawned...';
            if (FApp <> nil) and (FApp.Tasks <> nil) then
              FApp.Tasks.Spawn(MakeSpec(@BackgroundWork, nil, 0, 'demo-task'));
          end;
        'r':
          begin
            FInFlight := False;
            S := Self.specialize GetShared<TAppState>;
            if S <> nil then
            begin
              S.CompletedCount := 0;
              S.LastMessage := '';
            end;
          end;
      end;
    end;
  end;
end;

procedure TTaskScreen.HandleTaskCompletions(const Slots: array of TCompletionSlot;
  SlotCount: Integer);
var
  I: Integer;
  S: TAppState;
begin
  S := Self.specialize GetShared<TAppState>;
  if S = nil then Exit;
  for I := 0 to SlotCount - 1 do
  begin
    S.CompletedCount := S.CompletedCount + 1;
    if Slots[I].Result.Status = tsCompleted then
      S.LastMessage := 'done (#' + IntToStr(Slots[I].Id) + ')'
    else if Slots[I].Result.Status = tsCancelled then
      S.LastMessage := 'cancelled (#' + IntToStr(Slots[I].Id) + ')'
    else
      S.LastMessage := 'failed (#' + IntToStr(Slots[I].Id) + ')';
  end;
  FInFlight := False;
end;

var
  App: TApp;
  State: TAppState;
begin
  App := TApp.Create;
  try
    State := TAppState.Create;
    App.SharedStateObject := State;
    App.Screens.Push(TTaskScreen.Create(App));
    App.Run;
  finally
    App.SharedStateObject.Free;
    App.Free;
  end;
end.