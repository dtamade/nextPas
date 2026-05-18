program Set_constructor_pass;
type
  TDaySet = set of 0..6;
var
  Days: TDaySet;
  Vowels: set of Char;
  I: Integer;
  Found: Boolean;
begin
  Days := [0, 2, 4, 6];
  Vowels := ['a', 'e', 'i', 'o', 'u'];
  Found := 3 in Days;
  Days := [1..5];
  Days := [];
end.
