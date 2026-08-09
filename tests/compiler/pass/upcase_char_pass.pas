{$mode objfpc}{$H+}
program test_upcase_char_pass;

{ UpCase(char) — the L3 'upcase' branchless-select intrinsic (preprocessor
  EvalMatchStr uses UpCase(S[I]) pairs). Host FPC defines the expected
  results: lowercase shifts by -32, uppercase/digits/punct unchanged. }

var
  S: string;
  C: Char;
  I, Changed: LongInt;
begin
  S := 'aZ_9m';
  Changed := 0;
  for I := 1 to Length(S) do
    if UpCase(S[I]) <> S[I] then
      Inc(Changed);
  { only 'a' and 'm' change }
  if Changed <> 2 then Halt(1);

  C := UpCase('q');
  if C <> 'Q' then Halt(2);

  if UpCase(S[1]) <> 'A' then Halt(3);
  if UpCase(S[2]) <> 'Z' then Halt(4);
  if UpCase(S[3]) <> '_' then Halt(5);
end.
