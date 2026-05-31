program llvm_state_machine;
type
  TState = class
    FId: Integer;
    FTransitions: array of Integer;
    FCount: Integer;
    constructor Create(Id: Integer);
    procedure AddTransition(Target: Integer); virtual;
    function Next(Input: Integer): Integer; virtual;
  end;

constructor TState.Create(Id: Integer);
begin
  FId := Id;
  FCount := 0;
  SetLength(FTransitions, 8);
end;

procedure TState.AddTransition(Target: Integer);
begin
  FTransitions[FCount] := Target;
  FCount := FCount + 1;
end;

function TState.Next(Input: Integer): Integer;
begin
  if Input < FCount then
    Result := FTransitions[Input]
  else
    Result := FId;
end;

var
  States: array of TState;
  Current, I: Integer;
  Inputs: array of Integer;
begin
  SetLength(States, 3);
  States[0] := TState.Create(0);
  States[1] := TState.Create(1);
  States[2] := TState.Create(2);

  States[0].AddTransition(1);
  States[0].AddTransition(2);
  States[1].AddTransition(2);
  States[1].AddTransition(0);
  States[2].AddTransition(0);
  States[2].AddTransition(1);

  SetLength(Inputs, 4);
  Inputs[0] := 0;
  Inputs[1] := 1;
  Inputs[2] := 0;
  Inputs[3] := 1;

  Current := 0;
  for I := 0 to 3 do
    Current := States[Current].Next(Inputs[I]);

  Halt(Current + 42);
end.
