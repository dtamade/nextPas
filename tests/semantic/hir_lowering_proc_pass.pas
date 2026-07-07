{$mode objfpc}{$H+}
program hir_lowering_proc_pass;

{ HIR lowering：过程调用和副作用 }

var
  G: Integer;

procedure SetGlobal(V: Integer);
begin
  G := V;
end;

procedure IncGlobal;
begin
  G := G + 1;
end;

begin
  G := 0;
  SetGlobal(10);
  if G <> 10 then Halt(1);

  IncGlobal;
  if G <> 11 then Halt(2);

  IncGlobal;
  IncGlobal;
  if G <> 13 then Halt(3);
end.
