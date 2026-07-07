program enum_type_pass;

type
  TDay = (Mon, Tue, Wed, Thu, Fri, Sat, Sun);

var
  Today, Tomorrow: TDay;
  N: Integer;
begin
  Today := Wed;
  Tomorrow := Thu;
  N := Ord(Today);
  if Today = Wed then
    N := 0;
end.
