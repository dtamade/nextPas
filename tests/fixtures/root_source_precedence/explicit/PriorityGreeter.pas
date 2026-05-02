unit PriorityGreeter;

interface

procedure EmitPriorityGreeting;

implementation

procedure EmitPriorityGreeting;
begin
  WriteLn('hello from explicit unit root');
end;

end.
