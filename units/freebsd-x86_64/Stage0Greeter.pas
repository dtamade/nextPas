unit Stage0Greeter;

interface

procedure SayHello;

implementation

uses
  Stage0GreeterImpl;

procedure SayHello;
begin
  EmitHello;
end;

end.
