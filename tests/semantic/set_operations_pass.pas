program set_operations_pass;

type
  TCharSet = set of Char;

var
  S: TCharSet;
  C: Char;
  B: Boolean;
begin
  S := ['a', 'b', 'c'];
  Include(S, 'd');
  Exclude(S, 'a');
  C := 'b';
  B := C in S;
end.
