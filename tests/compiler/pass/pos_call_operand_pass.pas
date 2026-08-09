{$mode objfpc}{$H+}
program test_pos_call_operand_pass;

{ Pos() with string-returning calls as needle/haystack — the L3 $pos_ndl /
  $pos_hay materialization path (Pos(LowerCase(a), LowerCase(b)) in the
  Toml manifest helper). Host FPC defines the expected 1-based results. }

function TailOf(const S: string): string;
begin
  Result := Copy(S, 2, Length(S) - 1);
end;

var
  FieldName, Line: string;
begin
  FieldName := 'NAME';
  Line := 'key NaMe = "v"';

  { call needle x call haystack }
  if Pos(LowerCase(FieldName), LowerCase(Line)) <> 5 then Halt(1);

  { literal needle x call haystack }
  if Pos('=', TailOf(Line)) <> 9 then Halt(2);

  { call needle x plain var haystack }
  if Pos(LowerCase(FieldName), Line) <> 0 then Halt(3);

  { no-match path through the materialized temps }
  if Pos(LowerCase('zz'), LowerCase(Line)) <> 0 then Halt(4);
end.
