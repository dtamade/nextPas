program string_ops_pass;

var
  S, T, U: string;
begin
  S := 'hello';
  T := 'world';
  U := S + ' ' + T;
  S := '';
  S := U;
end.
