program KeywordsCore_pass;
var
  x: Integer;
begin
  x := 0;
  if True then
    x := 1
  else
    x := 2;
  while x < 10 do
  begin
    Inc(x);
    break;
  end;
  for x := 1 to 10 do
    break;
  for x := 10 downto 1 do
    break;
  repeat
    break;
  until True;
end.
