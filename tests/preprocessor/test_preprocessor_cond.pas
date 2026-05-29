program test_preprocessor_cond;

{$mode objfpc}{$H+}

uses
  np_base_types, np_lexer, np_preprocessor;

var
  Failures: LongInt = 0;

procedure Check(ACond: Boolean; const AMsg: string);
begin
  if not ACond then
  begin
    WriteLn('FAIL: ', AMsg);
    Inc(Failures);
  end;
end;

function PreprocessSource(const ASource: string; ADefines: TDefineTable): TPreprocessor;
var
  Lexer: TLexerResult;
begin
  Lexer := TLexerResult.Create(ASource, nil, 0);
  Result := TPreprocessor.Create(ADefines, False, nil);
  Result.Process(Lexer);
  Lexer.Free;
end;

function CountOutputKind(PP: TPreprocessor; AKind: TTokenKind): LongInt;
var
  I: LongInt;
begin
  Result := 0;
  for I := 0 to PP.OutputTokenCount - 1 do
    if PP.OutputTokenAt(I).Kind = AKind then
      Inc(Result);
end;

function HasLexeme(PP: TPreprocessor; const ALexeme: string): Boolean;
var
  I: LongInt;
begin
  for I := 0 to PP.OutputTokenCount - 1 do
    if PP.OutputTokenAt(I).Lexeme = ALexeme then
      Exit(True);
  Result := False;
end;

procedure TestNoDirectives;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource('program Test; begin end.', D);
  Check(PP.OutputTokenCount > 0, 'no-dir: has tokens');
  Check(HasLexeme(PP, 'program'), 'no-dir: has program');
  Check(HasLexeme(PP, 'Test'), 'no-dir: has Test');
  PP.Free;
  D.Free;
end;

procedure TestIfdefActive;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('FOO');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef FOO}' + LineEnding +
    'var X: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'X'), 'ifdef-active: X visible');
  PP.Free;
  D.Free;
end;

procedure TestIfdefInactive;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef FOO}' + LineEnding +
    'var X: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'X'), 'ifdef-inactive: X hidden');
  PP.Free;
  D.Free;
end;

procedure TestIfndefActive;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifndef BAR}' + LineEnding +
    'var Y: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'Y'), 'ifndef-active: Y visible');
  PP.Free;
  D.Free;
end;

procedure TestIfndefInactive;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('BAR');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifndef BAR}' + LineEnding +
    'var Y: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'Y'), 'ifndef-inactive: Y hidden');
  PP.Free;
  D.Free;
end;

procedure TestElseBranch;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef NOPE}' + LineEnding +
    'var A: Integer;' + LineEnding +
    '{$else}' + LineEnding +
    'var B: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'A'), 'else: A hidden');
  Check(HasLexeme(PP, 'B'), 'else: B visible');
  PP.Free;
  D.Free;
end;

procedure TestElseIfBranch;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('TWO');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef ONE}' + LineEnding +
    'var A: Integer;' + LineEnding +
    '{$elseif defined(TWO)}' + LineEnding +
    'var B: Integer;' + LineEnding +
    '{$else}' + LineEnding +
    'var C: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'A'), 'elseif: A hidden');
  Check(HasLexeme(PP, 'B'), 'elseif: B visible');
  Check(not HasLexeme(PP, 'C'), 'elseif: C hidden');
  PP.Free;
  D.Free;
end;

procedure TestNestedConditions;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('OUTER');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef OUTER}' + LineEnding +
    '{$ifdef INNER}' + LineEnding +
    'var A: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'var B: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'A'), 'nested: A hidden (INNER undef)');
  Check(HasLexeme(PP, 'B'), 'nested: B visible (OUTER active)');
  PP.Free;
  D.Free;
end;

procedure TestDefineInSource;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$define RUNTIME}' + LineEnding +
    '{$ifdef RUNTIME}' + LineEnding +
    'var R: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'R'), 'define-in-source: R visible');
  PP.Free;
  D.Free;
end;

procedure TestUndefInSource;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('KILL');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$undef KILL}' + LineEnding +
    '{$ifdef KILL}' + LineEnding +
    'var K: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'K'), 'undef-in-source: K hidden');
  PP.Free;
  D.Free;
end;

procedure TestDefineInInactiveBranch;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef NOPE}' + LineEnding +
    '{$define GHOST}' + LineEnding +
    '{$endif}' + LineEnding +
    '{$ifdef GHOST}' + LineEnding +
    'var G: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(PP, 'G'), 'define-in-inactive: GHOST not defined');
  PP.Free;
  D.Free;
end;

procedure TestIfendAlias;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('OK');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef OK}' + LineEnding +
    'var V: Integer;' + LineEnding +
    '{$ifend}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'V'), 'ifend: V visible');
  PP.Free;
  D.Free;
end;

procedure TestDirectivesStripped;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('X');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$ifdef X}' + LineEnding +
    'var A: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(CountOutputKind(PP, tkCompilerDirective) = 0,
    'directives-stripped: no directive tokens in output');
  PP.Free;
  D.Free;
end;

procedure TestUnknownDirectivePassthrough;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$H+}' + LineEnding +
    'begin end.', D);
  Check(CountOutputKind(PP, tkCompilerDirective) = 1,
    'unknown-dir: {$H+} passed through');
  PP.Free;
  D.Free;
end;

procedure TestCaseInsensitiveDirective;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('foo');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '{$IFDEF FOO}' + LineEnding +
    'var Z: Integer;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'Z'), 'case-insensitive: Z visible');
  PP.Free;
  D.Free;
end;

procedure TestParenStarDirective;
var
  D: TDefineTable;
  PP: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('PS');
  PP := PreprocessSource(
    'program T;' + LineEnding +
    '(*$ifdef PS*)' + LineEnding +
    'var W: Integer;' + LineEnding +
    '(*$endif*)' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(PP, 'W'), 'paren-star: W visible');
  PP.Free;
  D.Free;
end;

begin
  TestNoDirectives;
  TestIfdefActive;
  TestIfdefInactive;
  TestIfndefActive;
  TestIfndefInactive;
  TestElseBranch;
  TestElseIfBranch;
  TestNestedConditions;
  TestDefineInSource;
  TestUndefInSource;
  TestDefineInInactiveBranch;
  TestIfendAlias;
  TestDirectivesStripped;
  TestUnknownDirectivePassthrough;
  TestCaseInsensitiveDirective;
  TestParenStarDirective;
  if Failures = 0 then
    WriteLn('preprocessor-cond-status=pass')
  else
    WriteLn('preprocessor-cond-status=fail count=', Failures);
  if Failures > 0 then Halt(1);
end.
