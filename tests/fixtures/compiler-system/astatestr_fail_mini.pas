{ Batch 26: AState-like multi-string record + const sret + multi-arg WriteLn.
  Mirrors stage0 Fail shape without intermediate Sel assign:
    WriteLn(ErrOutput, 'selector=', EnvelopeSelectorName(AState));
    WriteLn(ErrOutput, 'human-summary=', Message);
  Host-free; not product entry; not M2-A. }
program astatestr_fail_mini;
type
  TState = record
    CommandName: string;
    SelectorName: string;
  end;

function EnvelopeSelectorName(const AState: TState): string;
begin
  if AState.SelectorName <> '' then
    Exit(AState.SelectorName);
  if AState.CommandName <> '' then
    Exit(AState.CommandName);
  Result := 'cli';
end;

procedure Fail(const AState: TState; const Message: string);
begin
  WriteLn(ErrOutput, 'status=failure');
  WriteLn(ErrOutput, 'command=', AState.CommandName);
  { multi-arg WriteLn with inline string sret — historical sret/clobber path }
  WriteLn(ErrOutput, 'selector=', EnvelopeSelectorName(AState));
  { AState still live after sret (field multi-arg again) }
  WriteLn(ErrOutput, 'command2=', AState.CommandName);
  WriteLn(ErrOutput, 'human-summary=', Message);
  WriteLn(ErrOutput, 'failure-kind=invalid-arguments');
  Halt(1);
end;

var
  State: TState;
begin
  State.CommandName := 'build';
  State.SelectorName := '';
  Fail(State, 'invalid-arguments');
end.