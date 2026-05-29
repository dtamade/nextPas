program test_preprocessor_include;

{$mode objfpc}{$H+}

uses
  np_base_types, np_lexer, np_preprocessor;

var
  Failures: LongInt = 0;

type
  TFakeIncludeResolver = class(TInterfacedObject, IIncludeResolver)
  private
    FFiles: array of record
      Name: string;
      Content: string;
    end;
    FCount: LongInt;
  public
    procedure AddFile(const AName, AContent: string);
    function ResolveInclude(const AName: string;
      const AFromFileId: TCoreId;
      out APath: string; out AContent: string): Boolean;
  end;

procedure TFakeIncludeResolver.AddFile(const AName, AContent: string);
begin
  if FCount >= Length(FFiles) then
    SetLength(FFiles, FCount + 8);
  FFiles[FCount].Name := AName;
  FFiles[FCount].Content := AContent;
  Inc(FCount);
end;

function TFakeIncludeResolver.ResolveInclude(const AName: string;
  const AFromFileId: TCoreId;
  out APath: string; out AContent: string): Boolean;
var
  I: LongInt;
begin
  APath := '';
  AContent := '';
  for I := 0 to FCount - 1 do
    if FFiles[I].Name = AName then
    begin
      APath := '/fake/' + AName;
      AContent := FFiles[I].Content;
      Exit(True);
    end;
  Result := False;
end;

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

procedure TestBasicInclude;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  R.AddFile('helper.inc', 'var Included: Integer;');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$i helper.inc}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'Included'), 'basic-include: Included visible');
  PP.Free;
  Lexer.Free;
end;

procedure TestIncludeWithCondition;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  D.Define('WANT_IT');
  R := TFakeIncludeResolver.Create;
  R.AddFile('cond.inc',
    '{$ifdef WANT_IT}' + LineEnding +
    'var Yes: Integer;' + LineEnding +
    '{$else}' + LineEnding +
    'var No: Integer;' + LineEnding +
    '{$endif}');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$include cond.inc}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'Yes'), 'include-cond: Yes visible');
  Check(not HasLexeme(PP, 'No'), 'include-cond: No hidden');
  PP.Free;
  Lexer.Free;
end;

procedure TestNestedInclude;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  R.AddFile('outer.inc', '{$i inner.inc}' + LineEnding + 'var Outer: Integer;');
  R.AddFile('inner.inc', 'var Inner: Integer;');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$i outer.inc}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'Inner'), 'nested-include: Inner visible');
  Check(HasLexeme(PP, 'Outer'), 'nested-include: Outer visible');
  PP.Free;
  Lexer.Free;
end;

procedure TestIncludeInInactiveBranch;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  R.AddFile('skip.inc', 'var Skipped: Integer;');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$ifdef NOPE}' + LineEnding +
    '{$i skip.inc}' + LineEnding +
    '{$endif}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(not HasLexeme(PP, 'Skipped'), 'include-inactive: Skipped hidden');
  PP.Free;
  Lexer.Free;
end;

procedure TestMissingInclude;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$i nonexistent.inc}' + LineEnding +
    'var After: Integer;' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'After'), 'missing-include: continues after');
  PP.Free;
  Lexer.Free;
end;

procedure TestIncludeQuotedFilename;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  R.AddFile('quoted.inc', 'var Quoted: Integer;');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$i ''quoted.inc''}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  Check(HasLexeme(PP, 'Quoted'), 'quoted-include: Quoted visible');
  PP.Free;
  Lexer.Free;
end;

procedure TestIncludeFileId;
var
  D: TDefineTable;
  R: TFakeIncludeResolver;
  PP: TPreprocessor;
  Lexer: TLexerResult;
  I: LongInt;
  FoundIncFileId: Boolean;
begin
  D := TDefineTable.Create;
  R := TFakeIncludeResolver.Create;
  R.AddFile('origin.inc', 'var FromInc: Integer;');
  Lexer := TLexerResult.Create(
    'program T;' + LineEnding +
    '{$i origin.inc}' + LineEnding +
    'begin end.', nil, 1);
  PP := TPreprocessor.Create(D, True, R);
  PP.Process(Lexer);
  FoundIncFileId := False;
  for I := 0 to PP.OutputTokenCount - 1 do
    if (PP.OutputTokenAt(I).Lexeme = 'FromInc') and
       (PP.OutputTokenAt(I).FileId <> 1) and
       (PP.OutputTokenAt(I).FileId <> 0) then
      FoundIncFileId := True;
  Check(FoundIncFileId, 'include-fileid: token from include has different FileId');
  PP.Free;
  Lexer.Free;
end;

begin
  TestBasicInclude;
  TestIncludeWithCondition;
  TestNestedInclude;
  TestIncludeInInactiveBranch;
  TestMissingInclude;
  TestIncludeQuotedFilename;
  TestIncludeFileId;
  if Failures = 0 then
    WriteLn('preprocessor-include-status=pass')
  else
    WriteLn('preprocessor-include-status=fail count=', Failures);
  if Failures > 0 then Halt(1);
end.
