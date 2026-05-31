program test_gm_proc_simple;

var G: Integer;

generic procedure SetGlobal<T>(V: T);
begin
  G := V;
end;

begin
  G := 0;
  specialize SetGlobal<Integer>(42);
  Halt(G);
end.
