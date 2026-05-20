program Pointer_and_nil_pass;

{$mode objfpc}{$H+}

type
  PInteger = ^Integer;
  TNode = record
    Value: Integer;
    Next: PInteger;
  end;

var
  P: PInteger;
  I: Integer;
  Node: TNode;
begin
  New(P);
  P^ := 42;
  I := P^;
  Dispose(P);
  P := nil;

  if P <> nil then
    I := P^;

  if Assigned(P) then
    I := 0;

  Node.Value := 1;
  Node.Next := nil;
end.
