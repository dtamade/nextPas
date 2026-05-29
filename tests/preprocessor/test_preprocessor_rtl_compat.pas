program test_preprocessor_rtl_compat;

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
    if PP.OutputTokenAt(I).Lexeme = ALexeme then Exit(True);
  Result := False;
end;

procedure TestObjpasFragment;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  D.Define('UNIX');
  Lexer := TLexerResult.Create(
    'unit objpas;' + LineEnding +
    '{$ifdef CPU16}' + LineEnding +
    '  type Integer = smallint;' + LineEnding +
    '{$else CPU16}' + LineEnding +
    '  type Integer = longint;' + LineEnding +
    '{$endif CPU16}' + LineEnding +
    '{$if FPC_FULLVERSION >= 20701}' + LineEnding +
    '  type TGenEnum = class end;' + LineEnding +
    '{$endif}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'longint'), 'objpas: longint visible (not CPU16)');
  Check(not HasLexeme(PP, 'smallint'), 'objpas: smallint hidden (CPU16)');
  Check(HasLexeme(PP, 'TGenEnum'), 'objpas: TGenEnum visible (>=20701)');
  PP.Free;
  Lexer.Free;
end;

procedure TestVersionElseIf;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  Lexer := TLexerResult.Create(
    'unit u;' + LineEnding +
    '{$if FPC_FULLVERSION < 20600}' + LineEnding +
    '  type TOld = Integer;' + LineEnding +
    '{$elseif FPC_FULLVERSION < 30200}' + LineEnding +
    '  type TMid = Integer;' + LineEnding +
    '{$else}' + LineEnding +
    '  type TNew = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(not HasLexeme(PP, 'TOld'), 'version: TOld hidden (<2.6)');
  Check(not HasLexeme(PP, 'TMid'), 'version: TMid hidden (<3.2)');
  Check(HasLexeme(PP, 'TNew'), 'version: TNew visible (>=3.2)');
  PP.Free;
  Lexer.Free;
end;

procedure TestCompoundPlatform;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  Lexer := TLexerResult.Create(
    'unit u;' + LineEnding +
    '{$if defined(CPUX86_64) and defined(LINUX)}' + LineEnding +
    '  type TLinux64 = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    '{$if defined(CPUX86_64) and defined(MSWINDOWS)}' + LineEnding +
    '  type TWin64 = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'TLinux64'), 'platform: TLinux64 visible');
  Check(not HasLexeme(PP, 'TWin64'), 'platform: TWin64 hidden');
  PP.Free;
  Lexer.Free;
end;

procedure TestFeatureDefines;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  Lexer := TLexerResult.Create(
    'unit u;' + LineEnding +
    '{$ifdef FPC_HAS_FEATURE_ANSISTRINGS}' + LineEnding +
    '  type TAnsi = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    '{$ifdef FPC_HAS_FEATURE_CLASSES}' + LineEnding +
    '  type TClasses = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    '{$ifdef FPC_HAS_FEATURE_COROUTINES}' + LineEnding +
    '  type TCoroutines = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'TAnsi'), 'feature: TAnsi visible');
  Check(HasLexeme(PP, 'TClasses'), 'feature: TClasses visible');
  Check(not HasLexeme(PP, 'TCoroutines'), 'feature: TCoroutines hidden');
  PP.Free;
  Lexer.Free;
end;

procedure TestNestedIfWithElseComment;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  D.Define('HAS_FEATURE');
  Lexer := TLexerResult.Create(
    'unit u;' + LineEnding +
    '{$ifdef LINUX}' + LineEnding +
    '  {$ifdef HAS_FEATURE}' + LineEnding +
    '    type TLinuxFeature = Integer;' + LineEnding +
    '  {$else HAS_FEATURE}' + LineEnding +
    '    type TLinuxNoFeature = Integer;' + LineEnding +
    '  {$endif HAS_FEATURE}' + LineEnding +
    '{$else LINUX}' + LineEnding +
    '  type TOtherOS = Integer;' + LineEnding +
    '{$endif LINUX}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'TLinuxFeature'), 'nested: TLinuxFeature visible');
  Check(not HasLexeme(PP, 'TLinuxNoFeature'), 'nested: TLinuxNoFeature hidden');
  Check(not HasLexeme(PP, 'TOtherOS'), 'nested: TOtherOS hidden');
  PP.Free;
  Lexer.Free;
end;

procedure TestFPCVersionArithmetic;
var
  D: TDefineTable;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.SeedFPCDefines;
  Lexer := TLexerResult.Create(
    'unit u;' + LineEnding +
    '{$if (FPC_VERSION > 2) or ((FPC_VERSION = 2) and (FPC_RELEASE >= 6))}' + LineEnding +
    '  type TModern = Integer;' + LineEnding +
    '{$endif}' + LineEnding +
    'end.', nil, 0);
  PP := TPreprocessor.Create(D, True, nil);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'TModern'), 'arithmetic: TModern visible (FPC 3.3.1 > 2.6)');
  PP.Free;
  Lexer.Free;
end;

begin
  TestObjpasFragment;
  TestVersionElseIf;
  TestCompoundPlatform;
  TestFeatureDefines;
  TestNestedIfWithElseComment;
  TestFPCVersionArithmetic;
  if Failures = 0 then
    WriteLn('preprocessor-rtl-compat-status=pass')
  else
    WriteLn('preprocessor-rtl-compat-status=fail count=', Failures);
  if Failures > 0 then Halt(1);
end.
