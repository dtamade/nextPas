program test_tui_widget_syntax;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.modifier,
  nextpas.core.tui.widget.syntax,
  nextpas.core.test;

type
  TLineProvider = class
  private
    FLines: array of AnsiString;
    FLineCount: Integer;
  public
    constructor Create(const ALines: array of AnsiString);
    procedure GetLine(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
  end;

constructor TLineProvider.Create(const ALines: array of AnsiString);
var
  I: Integer;
begin
  inherited Create;
  FLineCount := Length(ALines);
  SetLength(FLines, FLineCount);
  for I := 0 to FLineCount - 1 do
    FLines[I] := ALines[I];
end;

procedure TLineProvider.GetLine(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
begin
  if (LineIndex >= 0) and (LineIndex < FLineCount) then
  begin
    P := PAnsiChar(FLines[LineIndex]);
    Len := Length(FLines[LineIndex]);
  end
  else
  begin
    P := nil;
    Len := 0;
  end;
end;

var
  T: TTestSuite;

procedure TestTokenKindEnum;
begin
  Check(Ord(tkNormal) = 0, 'tkNormal should be 0');
  Check(Ord(tkKeyword) = 1, 'tkKeyword should be 1');
  Check(Ord(tkString) = 2, 'tkString should be 2');
  Check(Ord(tkComment) = 3, 'tkComment should be 3');
  Check(Ord(tkNumber) = 4, 'tkNumber should be 4');
  Check(Ord(tkDirective) = 5, 'tkDirective should be 5');
  Check(Ord(tkSymbol) = 6, 'tkSymbol should be 6');
end;

procedure TestTokenRecord;
var
  LToken: TToken;
begin
  LToken.Start := 0;
  LToken.Len := 5;
  LToken.Kind := tkKeyword;
  Check(LToken.Start = 0, 'Token.Start should be 0');
  Check(LToken.Len = 5, 'Token.Len should be 5');
  Check(LToken.Kind = tkKeyword, 'Token.Kind should be tkKeyword');
end;

procedure TestLineStateRecord;
var
  LState: TLineState;
begin
  LState.InBlockComment := False;
  LState.InString := False;
  LState.NestDepth := 0;
  LState.Reserved := 0;
  Check(not LState.InBlockComment, 'InBlockComment should be False');
  Check(not LState.InString, 'InString should be False');
  Check(LState.NestDepth = 0, 'NestDepth should be 0');
end;

procedure TestIsPascalKeyword;
begin
  Check(IsPascalKeyword('begin'), 'begin should be a keyword');
  Check(IsPascalKeyword('end'), 'end should be a keyword');
  Check(IsPascalKeyword('if'), 'if should be a keyword');
  Check(IsPascalKeyword('then'), 'then should be a keyword');
  Check(IsPascalKeyword('procedure'), 'procedure should be a keyword');
  Check(IsPascalKeyword('function'), 'function should be a keyword');
  Check(IsPascalKeyword('var'), 'var should be a keyword');
  Check(IsPascalKeyword('const'), 'const should be a keyword');
  Check(IsPascalKeyword('type'), 'type should be a keyword');
  Check(IsPascalKeyword('class'), 'class should be a keyword');
  Check(not IsPascalKeyword('hello'), 'hello should not be a keyword');
  Check(not IsPascalKeyword('myvar'), 'myvar should not be a keyword');
  Check(not IsPascalKeyword('beginx'), 'beginx should not be a keyword');
end;

procedure TestIsPascalKeywordP;
var
  LS: AnsiString;
begin
  LS := 'begin';
  Check(IsPascalKeywordP(PAnsiChar(LS), Length(LS)), 'begin should be a keyword (P version)');
  LS := 'end';
  Check(IsPascalKeywordP(PAnsiChar(LS), Length(LS)), 'end should be a keyword (P version)');
  LS := 'hello';
  Check(not IsPascalKeywordP(PAnsiChar(LS), Length(LS)), 'hello should not be a keyword (P version)');
end;

procedure TestTokenizePascalEmpty;
var
  LTokens: TTokenArray;
begin
  LTokens := TokenizePascal('');
  Check(Length(LTokens) = 0, 'Empty line should produce no tokens');
end;

procedure TestTokenizePascalSimple;
var
  LTokens: TTokenArray;
begin
  LTokens := TokenizePascal('begin');
  Check(Length(LTokens) = 1, 'Single keyword should produce 1 token');
  Check(LTokens[0].Kind = tkKeyword, 'begin should be tkKeyword');
  Check(LTokens[0].Start = 1, 'Token should start at 1 (1-based)');
  Check(LTokens[0].Len = 5, 'Token length should be 5');
end;

procedure TestTokenizePascalMultiple;
var
  LTokens: TTokenArray;
begin
  LTokens := TokenizePascal('var x: Integer;');
  Check(Length(LTokens) > 0, 'Should produce tokens');
  Check(LTokens[0].Kind = tkKeyword, 'var should be tkKeyword');
end;

procedure TestTokenizePascalString;
var
  LTokens: TTokenArray;
  I: Integer;
  LFoundString: Boolean;
begin
  LTokens := TokenizePascal('''hello world''');
  LFoundString := False;
  for I := 0 to High(LTokens) do
    if LTokens[I].Kind = tkString then
    begin
      LFoundString := True;
      Break;
    end;
  Check(LFoundString, 'Should find string token');
end;

procedure TestTokenizePascalComment;
var
  LTokens: TTokenArray;
  I: Integer;
  LFoundComment: Boolean;
begin
  LTokens := TokenizePascal('{ this is a comment }');
  LFoundComment := False;
  for I := 0 to High(LTokens) do
    if LTokens[I].Kind = tkComment then
    begin
      LFoundComment := True;
      Break;
    end;
  Check(LFoundComment, 'Should find comment token');
end;

procedure TestTokenizePascalNumber;
var
  LTokens: TTokenArray;
  I: Integer;
  LFoundNumber: Boolean;
begin
  LTokens := TokenizePascal('42');
  LFoundNumber := False;
  for I := 0 to High(LTokens) do
    if LTokens[I].Kind = tkNumber then
    begin
      LFoundNumber := True;
      Break;
    end;
  Check(LFoundNumber, 'Should find number token');
end;

procedure TestTokenizePascalStateful;
var
  LStateIn, LStateOut: TLineState;
  LTokens: TTokenArray;
begin
  LStateIn.InBlockComment := False;
  LStateIn.InString := False;
  LStateIn.NestDepth := 0;
  LStateIn.Reserved := 0;

  LTokens := TokenizePascalStateful('begin', LStateIn, LStateOut);
  Check(Length(LTokens) > 0, 'Should produce tokens');
  Check(not LStateOut.InBlockComment, 'Should not be in block comment after begin');
  Check(not LStateOut.InString, 'Should not be in string after begin');
end;

procedure TestTokenizePascalStatefulBlockComment;
var
  LStateIn, LStateOut: TLineState;
  LTokens: TTokenArray;
begin
  LStateIn.InBlockComment := False;
  LStateIn.InString := False;
  LStateIn.NestDepth := 0;
  LStateIn.Reserved := 0;

  LTokens := TokenizePascalStateful('{ comment', LStateIn, LStateOut);
  Check(LStateOut.InBlockComment, 'Should be in block comment after unclosed {');
end;

procedure TestTokenizePascalStatefulString;
var
  LStateIn, LStateOut: TLineState;
  LTokens: TTokenArray;
begin
  LStateIn.InBlockComment := False;
  LStateIn.InString := False;
  LStateIn.NestDepth := 0;
  LStateIn.Reserved := 0;

  LTokens := TokenizePascalStateful('''unclosed string', LStateIn, LStateOut);
  Check(not LStateOut.InString, 'TokenizePascalStateful does not track string state');
  Check(Length(LTokens) > 0, 'Should produce tokens for unclosed string');
  Check(LTokens[0].Kind = tkString, 'Unclosed string should be tkString');
end;

procedure TestSyntaxThemeDefault;
var
  LTheme: TSyntaxTheme;
begin
  LTheme := TSyntaxTheme.Default;
  Check(LTheme.StyleFor(tkKeyword).Fg.Kind <> ckUnset, 'Default theme should have style for tkKeyword');
  Check(LTheme.StyleFor(tkString).Fg.Kind <> ckUnset, 'Default theme should have style for tkString');
  Check(LTheme.StyleFor(tkComment).Fg.Kind <> ckUnset, 'Default theme should have style for tkComment');
  Check(LTheme.StyleFor(tkNumber).Fg.Kind <> ckUnset, 'Default theme should have style for tkNumber');
  Check(LTheme.StyleFor(tkDirective).Fg.Kind <> ckUnset, 'Default theme should have style for tkDirective');
  Check(LTheme.StyleFor(tkSymbol).Fg.Kind <> ckUnset, 'Default theme should have style for tkSymbol');
end;

procedure TestSyntaxThemeNord;
var
  LTheme: TSyntaxTheme;
begin
  LTheme := TSyntaxTheme.Nord;
  Check(LTheme.StyleFor(tkNormal).Fg.Kind <> ckUnset, 'Nord theme should have style for tkNormal');
  Check(LTheme.StyleFor(tkKeyword).Fg.Kind <> ckUnset, 'Nord theme should have style for tkKeyword');
  Check(LTheme.StyleFor(tkString).Fg.Kind <> ckUnset, 'Nord theme should have style for tkString');
  Check(LTheme.StyleFor(tkComment).Fg.Kind <> ckUnset, 'Nord theme should have style for tkComment');
end;

procedure TestSyntaxDocCreate;
var
  LHighlighter: IHighlighter;
  LDoc: TSyntaxDoc;
  LProvider: TLineProvider;
begin
  LHighlighter := TPascalHighlighter.Create;
  LProvider := TLineProvider.Create(['program test;', 'begin', 'end.']);
  try
    LDoc := TSyntaxDoc.Create(LHighlighter, 3, @LProvider.GetLine);
    try
      Check(LDoc.LineCount = 3, 'LineCount should be 3');
    finally
      LDoc.Free;
    end;
  finally
    LProvider.Free;
  end;
end;

procedure TestSyntaxDocSetLineCount;
var
  LHighlighter: IHighlighter;
  LDoc: TSyntaxDoc;
  LProvider: TLineProvider;
begin
  LHighlighter := TPascalHighlighter.Create;
  LProvider := TLineProvider.Create(['line1']);
  try
    LDoc := TSyntaxDoc.Create(LHighlighter, 1, @LProvider.GetLine);
    try
      Check(LDoc.LineCount = 1, 'Initial LineCount should be 1');
      LDoc.SetLineCount(5);
      Check(LDoc.LineCount = 5, 'LineCount should be 5 after SetLineCount');
    finally
      LDoc.Free;
    end;
  finally
    LProvider.Free;
  end;
end;

procedure TestSyntaxDocInvalidate;
var
  LHighlighter: IHighlighter;
  LDoc: TSyntaxDoc;
  LProvider: TLineProvider;
begin
  LHighlighter := TPascalHighlighter.Create;
  LProvider := TLineProvider.Create(['line1', 'line2', 'line3', 'line4', 'line5',
    'line6', 'line7', 'line8', 'line9', 'line10']);
  try
    LDoc := TSyntaxDoc.Create(LHighlighter, 10, @LProvider.GetLine);
    try
      LDoc.Invalidate(5);
      Check(True, 'Invalidate should not raise exception');
    finally
      LDoc.Free;
    end;
  finally
    LProvider.Free;
  end;
end;

procedure TestSyntaxDocNotifyInsertDelete;
var
  LHighlighter: IHighlighter;
  LDoc: TSyntaxDoc;
  LProvider: TLineProvider;
begin
  LHighlighter := TPascalHighlighter.Create;
  LProvider := TLineProvider.Create(['line1', 'line2', 'line3', 'line4', 'line5',
    'line6', 'line7', 'line8', 'line9', 'line10']);
  try
    LDoc := TSyntaxDoc.Create(LHighlighter, 10, @LProvider.GetLine);
    try
      Check(LDoc.LineCount = 10, 'Initial LineCount should be 10');
      LDoc.NotifyInsert(5, 3);
      Check(LDoc.LineCount = 13, 'LineCount should be 13 after insert');
      LDoc.NotifyDelete(2, 2);
      Check(LDoc.LineCount = 11, 'LineCount should be 11 after delete');
    finally
      LDoc.Free;
    end;
  finally
    LProvider.Free;
  end;
end;

procedure TestPascalHighlighterLangId;
var
  LHighlighter: TPascalHighlighter;
begin
  LHighlighter := TPascalHighlighter.Create;
  try
    Check(LHighlighter.LangId = 'pascal', 'LangId should be pascal');
  finally
    LHighlighter.Free;
  end;
end;

procedure TestPascalHighlighterTokenize;
var
  LHighlighter: TPascalHighlighter;
  LStateIn, LStateOut: TLineState;
  LTokens: array[0..9] of TToken;
  LCount: Integer;
  LS: AnsiString;
begin
  LHighlighter := TPascalHighlighter.Create;
  try
    LStateIn.InBlockComment := False;
    LStateIn.InString := False;
    LStateIn.NestDepth := 0;
    LStateIn.Reserved := 0;

    LS := 'begin';
    LCount := LHighlighter.TokenizeLine(PAnsiChar(LS), Length(LS), LStateIn, LStateOut, @LTokens[0], 10);
    Check(LCount > 0, 'Should tokenize begin');
    Check(LTokens[0].Kind = tkKeyword, 'begin should be tkKeyword');
  finally
    LHighlighter.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.syntax');
  T.Test('TTokenKind enum values', @TestTokenKindEnum);
  T.Test('TToken record', @TestTokenRecord);
  T.Test('TLineState record', @TestLineStateRecord);
  T.Test('IsPascalKeyword', @TestIsPascalKeyword);
  T.Test('IsPascalKeywordP', @TestIsPascalKeywordP);
  T.Test('TokenizePascal empty', @TestTokenizePascalEmpty);
  T.Test('TokenizePascal simple keyword', @TestTokenizePascalSimple);
  T.Test('TokenizePascal multiple tokens', @TestTokenizePascalMultiple);
  T.Test('TokenizePascal string', @TestTokenizePascalString);
  T.Test('TokenizePascal comment', @TestTokenizePascalComment);
  T.Test('TokenizePascal number', @TestTokenizePascalNumber);
  T.Test('TokenizePascalStateful simple', @TestTokenizePascalStateful);
  T.Test('TokenizePascalStateful block comment', @TestTokenizePascalStatefulBlockComment);
  T.Test('TokenizePascalStateful string', @TestTokenizePascalStatefulString);
  T.Test('TSyntaxTheme.Default', @TestSyntaxThemeDefault);
  T.Test('TSyntaxTheme.Nord', @TestSyntaxThemeNord);
  T.Test('TSyntaxDoc.Create', @TestSyntaxDocCreate);
  T.Test('TSyntaxDoc.SetLineCount', @TestSyntaxDocSetLineCount);
  T.Test('TSyntaxDoc.Invalidate', @TestSyntaxDocInvalidate);
  T.Test('TSyntaxDoc.NotifyInsert/Delete', @TestSyntaxDocNotifyInsertDelete);
  T.Test('TPascalHighlighter.LangId', @TestPascalHighlighterLangId);
  T.Test('TPascalHighlighter.TokenizeLine', @TestPascalHighlighterTokenize);
  if not T.Run then Halt(1);
end.
