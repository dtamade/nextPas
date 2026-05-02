unit Stage0Greeter;

interface

procedure SayHello;

implementation

procedure SayHello;
begin
  WriteLn('hello from explicit unit root override');
end;

end.
