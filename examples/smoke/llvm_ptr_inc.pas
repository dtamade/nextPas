program test_ptr_inc;

procedure IncBy(P: ^Integer; Amount: Integer);
begin
  P^ := P^ + Amount;
end;

var X: Integer;
begin
  X := 30;
  IncBy(@X, 12);
  Halt(X);
end.
