{ Batch 25: mini Fail shape — const state with string fields + string helper +
  WriteLn(ErrOutput) + Halt(1). Not product entry; not M2-A. }
program fail_mini_state;
type
  TMiniState = record
    CommandName: string;
    SelectorName: string;
  end;

function SelectorOf(const AState: TMiniState): string;
begin
  if AState.SelectorName <> '' then
    Exit(AState.SelectorName);
  if AState.CommandName <> '' then
    Exit(AState.CommandName);
  Result := 'cli';
end;

procedure Fail(const AState: TMiniState; const Message: string);
var
  Sel: string;
begin
  Sel := SelectorOf(AState);
  WriteLn(ErrOutput, 'status=failure');
  WriteLn(ErrOutput, 'command=', AState.CommandName);
  WriteLn(ErrOutput, 'selector=', Sel);
  WriteLn(ErrOutput, 'failure-kind=invalid-arguments');
  WriteLn(ErrOutput, Message);
  Halt(1);
end;

var
  State: TMiniState;
begin
  State.CommandName := 'build';
  State.SelectorName := '';
  Fail(State, 'invalid-arguments');
end.
