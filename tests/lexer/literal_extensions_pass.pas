program LiteralExtensions_pass;
var
  hex, oct, bin: Integer;
  c: Char;
begin
  hex := $1A;
  oct := &77;
  bin := %1010;
  c := ^A;
  c := ^M;
  c := ^@;
end.
