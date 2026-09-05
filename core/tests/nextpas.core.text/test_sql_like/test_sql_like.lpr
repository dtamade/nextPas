program test_sql_like;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.sql,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestEmpty;
begin
  CheckEqual('', SqlLikeEscape(''), 'empty passthrough');
end;

procedure TestClean;
begin
  CheckEqual('hello world', SqlLikeEscape('hello world'), 'clean passthrough');
  CheckEqual('alice123', SqlLikeEscape('alice123'), 'alnum passthrough');
end;

procedure TestPercent;
begin
  CheckEqual('100\%', SqlLikeEscape('100%'), 'percent escaped');
end;

procedure TestUnderscore;
begin
  CheckEqual('a\_b', SqlLikeEscape('a_b'), 'underscore escaped');
end;

procedure TestBackslash;
begin
  CheckEqual('a\\b', SqlLikeEscape('a\b'), 'backslash escaped');
end;

procedure TestMixed;
begin
  CheckEqual('100\%\_pas', SqlLikeEscape('100%_pas'), 'production literal from pascn');
end;

procedure TestLongString;
var
  S, E: string;
  I: Integer;
begin
  S := '';
  E := '';
  for I := 1 to 200 do
  begin
    S := S + 'a%b';
    E := E + 'a\%b';
  end;
  CheckEqual(E, SqlLikeEscape(S), '200x(a%b) escaped');
  CheckEqual(Int64(800), Int64(Length(SqlLikeEscape(S))), '200x(a%b) -> 800 chars');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.sql.like');
  T.Test('empty', @TestEmpty);
  T.Test('clean', @TestClean);
  T.Test('percent', @TestPercent);
  T.Test('underscore', @TestUnderscore);
  T.Test('backslash', @TestBackslash);
  T.Test('mixed', @TestMixed);
  T.Test('long string', @TestLongString);
  if not T.Run then Halt(1);
end.
