unit CycleA;

interface

uses
  CycleB;

procedure PingA;

implementation

procedure PingA;
begin
  PingB;
end;

end.
