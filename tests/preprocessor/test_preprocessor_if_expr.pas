program test_preprocessor_if_expr;

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

function HasLexeme(PP: TPreprocessor; const ALexeme: string): Boolean;
var
  I: LongInt;
begin
  for I := 0 to PP.OutputTokenCount - 1 do
    if PP.OutputTokenAt(I).Lexeme = ALexeme then
      Exit(True);
  Result := False;
end;

function PP(const ASource: string; ADefines: TDefineTable): TPreprocessor;
var
  Lexer: TLexerResult;
begin
  Lexer := TLexerResult.Create(ASource, nil, 0);
  Result := TPreprocessor.Create(ADefines, False, nil);
  Result.Process(Lexer);
  Lexer.Free;
end;

procedure TestIfDefined;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('FOO');
  P := PP('program T;' + LineEnding +
    '{$if defined(FOO)}var A: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'A'), '$if defined(FOO): A visible');
  P.Free;
  D.Free;
end;

procedure TestIfNotDefined;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  P := PP('program T;' + LineEnding +
    '{$if defined(BAR)}var A: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(P, 'A'), '$if defined(BAR): A hidden');
  P.Free;
  D.Free;
end;

procedure TestIfVersionCompare;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  P := PP('program T;' + LineEnding +
    '{$if FPC_FULLVERSION >= 30000}var V: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'V'), '$if FPC_FULLVERSION >= 30000: V visible');
  P.Free;
  D.Free;
end;

procedure TestIfVersionTooHigh;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  P := PP('program T;' + LineEnding +
    '{$if FPC_FULLVERSION >= 40000}var V: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(P, 'V'), '$if FPC_FULLVERSION >= 40000: V hidden');
  P.Free;
  D.Free;
end;

procedure TestIfBooleanAnd;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('A');
  D.Define('B');
  P := PP('program T;' + LineEnding +
    '{$if defined(A) and defined(B)}var X: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'X'), '$if A and B: X visible');
  P.Free;
  D.Free;
end;

procedure TestIfBooleanOr;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.Define('A');
  P := PP('program T;' + LineEnding +
    '{$if defined(A) or defined(B)}var X: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'X'), '$if A or B: X visible');
  P.Free;
  D.Free;
end;

procedure TestIfNot;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  P := PP('program T;' + LineEnding +
    '{$if not defined(NOPE)}var X: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'X'), '$if not defined(NOPE): X visible');
  P.Free;
  D.Free;
end;

procedure TestIfArithmetic;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.DefineValue('VER', '5');
  P := PP('program T;' + LineEnding +
    '{$if VER * 2 > 8}var X: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'X'), '$if VER*2>8: X visible (5*2=10>8)');
  P.Free;
  D.Free;
end;

procedure TestIfElseIf;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.DefineValue('MODE', '2');
  P := PP('program T;' + LineEnding +
    '{$if MODE = 1}var A: Integer;' + LineEnding +
    '{$elseif MODE = 2}var B: Integer;' + LineEnding +
    '{$else}var C: Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', D);
  Check(not HasLexeme(P, 'A'), '$if/$elseif: A hidden');
  Check(HasLexeme(P, 'B'), '$if/$elseif: B visible');
  Check(not HasLexeme(P, 'C'), '$if/$elseif: C hidden');
  P.Free;
  D.Free;
end;

procedure TestIfHexLiteral;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.DefineValue('X', '255');
  P := PP('program T;' + LineEnding +
    '{$if X = $FF}var H: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'H'), '$if X=$FF: H visible (255=$FF)');
  P.Free;
  D.Free;
end;

procedure TestSeedDefines;
var
  D: TDefineTable;
  P: TPreprocessor;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  P := PP('program T;' + LineEnding +
    '{$ifdef FPC}var F: Integer;{$endif}' + LineEnding +
    '{$ifdef UNIX}var U: Integer;{$endif}' + LineEnding +
    '{$ifdef CPU64}var C: Integer;{$endif}' + LineEnding +
    'begin end.', D);
  Check(HasLexeme(P, 'F'), 'seed: FPC defined');
  Check(HasLexeme(P, 'U'), 'seed: UNIX defined');
  Check(HasLexeme(P, 'C'), 'seed: CPU64 defined');
  P.Free;
  D.Free;
end;

begin
  TestIfDefined;
  TestIfNotDefined;
  TestIfVersionCompare;
  TestIfVersionTooHigh;
  TestIfBooleanAnd;
  TestIfBooleanOr;
  TestIfNot;
  TestIfArithmetic;
  TestIfElseIf;
  TestIfHexLiteral;
  TestSeedDefines;
  if Failures = 0 then
    WriteLn('preprocessor-if-expr-status=pass')
  else
    WriteLn('preprocessor-if-expr-status=fail count=', Failures);
  if Failures > 0 then Halt(1);
end.
