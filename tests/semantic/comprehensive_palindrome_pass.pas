{ objfpc}{+}
program comprehensive_palindrome_pass;
function IsPalindrome(const S: string): Boolean;
var I,L: Integer;
begin
  L:=Length(S); IsPalindrome:=True;
  for I:=1 to L div 2 do
    if S[I]<>S[L-I+1] then begin IsPalindrome:=False; Exit; end;
end;
begin
  if not IsPalindrome('radar') then Halt(1);
  if not IsPalindrome('a') then Halt(2);
  if IsPalindrome('hello') then Halt(3);
  if not IsPalindrome('') then Halt(4);
end.
