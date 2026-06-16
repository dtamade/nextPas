program test_tui_syntax;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.style,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.widget.syntax,
  nextpas.core.testing;

var T: TTestRunner;

type
  TSyntaxTestHelper = class
  public
    Lines: array of AnsiString;
    procedure GetLine(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
  end;

var Helper: TSyntaxTestHelper;

procedure TSyntaxTestHelper.GetLine(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
begin
  if (LineIndex >= 0) and (LineIndex < Length(Lines)) then
  begin
    P := @Lines[LineIndex][1];
    Len := Length(Lines[LineIndex]);
  end
  else
  begin
    P := nil;
    Len := 0;
  end;
end;

{ === IsPascalKeyword === }

procedure TestKeywordBegin;
begin
  Check(IsPascalKeyword('begin'), 'begin is keyword');
end;

procedure TestKeywordEnd;
begin
  Check(IsPascalKeyword('end'), 'end is keyword');
end;

procedure TestKeywordIfThen;
begin
  Check(IsPascalKeyword('if'), 'if is keyword');
  Check(IsPascalKeyword('then'), 'then is keyword');
end;

procedure TestKeywordFunction;
begin
  Check(IsPascalKeyword('function'), 'function is keyword');
  Check(IsPascalKeyword('procedure'), 'procedure is keyword');
end;

procedure TestKeywordClass;
begin
  Check(IsPascalKeyword('class'), 'class is keyword');
  Check(IsPascalKeyword('object'), 'object is keyword');
  Check(IsPascalKeyword('record'), 'record is keyword');
end;

procedure TestKeywordOperators;
begin
  Check(IsPascalKeyword('and'), 'and is keyword');
  Check(IsPascalKeyword('or'), 'or is keyword');
  Check(IsPascalKeyword('not'), 'not is keyword');
  Check(IsPascalKeyword('xor'), 'xor is keyword');
  Check(IsPascalKeyword('div'), 'div is keyword');
  Check(IsPascalKeyword('mod'), 'mod is keyword');
  Check(IsPascalKeyword('shl'), 'shl is keyword');
  Check(IsPascalKeyword('shr'), 'shr is keyword');
end;

procedure TestKeywordControl;
begin
  Check(IsPascalKeyword('while'), 'while is keyword');
  Check(IsPascalKeyword('for'), 'for is keyword');
  Check(IsPascalKeyword('repeat'), 'repeat is keyword');
  Check(IsPascalKeyword('until'), 'until is keyword');
  Check(IsPascalKeyword('case'), 'case is keyword');
  Check(IsPascalKeyword('with'), 'with is keyword');
  Check(IsPascalKeyword('goto'), 'goto is keyword');
  Check(IsPascalKeyword('raise'), 'raise is keyword');
  Check(IsPascalKeyword('try'), 'try is keyword');
  Check(IsPascalKeyword('finally'), 'finally is keyword');
  Check(IsPascalKeyword('except'), 'except is keyword');
end;

procedure TestKeywordOther;
begin
  Check(IsPascalKeyword('unit'), 'unit is keyword');
  Check(IsPascalKeyword('program'), 'program is keyword');
  Check(IsPascalKeyword('uses'), 'uses is keyword');
  Check(IsPascalKeyword('interface'), 'interface is keyword');
  Check(IsPascalKeyword('implementation'), 'implementation is keyword');
  Check(IsPascalKeyword('type'), 'type is keyword');
  Check(IsPascalKeyword('var'), 'var is keyword');
  Check(IsPascalKeyword('const'), 'const is keyword');
  Check(IsPascalKeyword('nil'), 'nil is keyword');
  Check(IsPascalKeyword('in'), 'in is keyword');
  Check(IsPascalKeyword('is'), 'is is keyword');
  Check(IsPascalKeyword('as'), 'as is keyword');
  Check(IsPascalKeyword('of'), 'of is keyword');
  Check(IsPascalKeyword('array'), 'array is keyword');
  Check(IsPascalKeyword('set'), 'set is keyword');
  Check(IsPascalKeyword('packed'), 'packed is keyword');
  Check(IsPascalKeyword('file'), 'file is keyword');
  Check(IsPascalKeyword('label'), 'label is keyword');
  Check(IsPascalKeyword('inline'), 'inline is keyword');
  Check(IsPascalKeyword('asm'), 'asm is keyword');
  Check(IsPascalKeyword('property'), 'property is keyword');
  Check(IsPascalKeyword('constructor'), 'constructor is keyword');
  Check(IsPascalKeyword('destructor'), 'destructor is keyword');
  Check(IsPascalKeyword('initialization'), 'initialization is keyword');
  Check(IsPascalKeyword('finalization'), 'finalization is keyword');
  Check(IsPascalKeyword('library'), 'library is keyword');
  Check(IsPascalKeyword('exports'), 'exports is keyword');
  Check(IsPascalKeyword('operator'), 'operator is keyword');
  Check(IsPascalKeyword('inherited'), 'inherited is keyword');
  Check(IsPascalKeyword('to'), 'to is keyword');
  Check(IsPascalKeyword('downto'), 'downto is keyword');
  Check(IsPascalKeyword('do'), 'do is keyword');
  Check(IsPascalKeyword('result'), 'result is keyword');
end;

procedure TestNonKeyword;
begin
  Check(not IsPascalKeyword('MyVar'), 'MyVar is not keyword');
  Check(not IsPascalKeyword('Foo'), 'Foo is not keyword');
  Check(not IsPascalKeyword('x'), 'x is not keyword (too short)');
  Check(not IsPascalKeyword('beginx'), 'beginx is not keyword');
  Check(not IsPascalKeyword(''), 'empty is not keyword');
end;

{ === IsPascalKeywordP === }

procedure TestKeywordP;
var W: AnsiString;
begin
  W := 'begin';
  Check(IsPascalKeywordP(@W[1], Length(W)), 'IsPascalKeywordP begin');
  W := 'function';
  Check(IsPascalKeywordP(@W[1], Length(W)), 'IsPascalKeywordP function');
end;

procedure TestNonKeywordP;
var W: AnsiString;
begin
  W := 'hello';
  Check(not IsPascalKeywordP(@W[1], Length(W)), 'IsPascalKeywordP hello');
end;

{ === TPascalHighlighter === }

procedure TestHighlighterLangId;
var H: IHighlighter;
begin
  H := TPascalHighlighter.Create;
  Check(H.LangId = 'pascal', 'LangId returns pascal');
end;

procedure TestHighlighterTokenizeLine;
var
  H: IHighlighter;
  Line: AnsiString;
  Tokens: array[0..15] of TToken;
  StateIn, StateOut: TLineState;
  Count: Integer;
begin
  H := TPascalHighlighter.Create;
  FillChar(StateIn, SizeOf(StateIn), 0);
  Line := 'begin';
  Count := H.TokenizeLine(@Line[1], Length(Line), StateIn, StateOut, @Tokens[0], 16);
  Check(Count = 1, 'single keyword = 1 token');
  Check(Tokens[0].Kind = tkKeyword, 'begin is tkKeyword');
  Check(Tokens[0].Start = 1, 'token starts at 1');
  Check(Tokens[0].Len = 5, 'token len is 5');
end;

{ === TokenizePascal === }

procedure TestTokenizeKeyword;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('begin');
  Check(Length(Tokens) = 1, 'single keyword');
  Check(Tokens[0].Kind = tkKeyword, 'begin is tkKeyword');
end;

procedure TestTokenizeIdentifier;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('MyVar');
  Check(Length(Tokens) = 1, 'single identifier');
  Check(Tokens[0].Kind = tkNormal, 'MyVar is tkNormal');
end;

procedure TestTokenizeNumber;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('42');
  Check(Length(Tokens) = 1, 'single number');
  Check(Tokens[0].Kind = tkNumber, '42 is tkNumber');
end;

procedure TestTokenizeHexNumber;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('$FF');
  Check(Length(Tokens) = 1, 'hex number');
  Check(Tokens[0].Kind = tkNumber, '$FF is tkNumber');
end;

procedure TestTokenizeString;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('''hello''');
  Check(Length(Tokens) = 1, 'string literal');
  Check(Tokens[0].Kind = tkString, 'string is tkString');
  Check(Tokens[0].Start = 1, 'string starts at 1');
  Check(Tokens[0].Len = 7, 'string len includes quotes');
end;

procedure TestTokenizeBlockComment;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('{ comment }');
  Check(Length(Tokens) = 1, 'block comment');
  Check(Tokens[0].Kind = tkComment, 'block comment is tkComment');
end;

procedure TestTokenizeLineComment;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('// comment');
  Check(Length(Tokens) = 1, 'line comment');
  Check(Tokens[0].Kind = tkComment, 'line comment is tkComment');
end;

procedure TestTokenizeParenComment;
var Tokens: TTokenArray; StateIn, StateOut: TLineState;
begin
  FillChar(StateIn, SizeOf(StateIn), 0);
  Tokens := TokenizePascalStateful('(* comment *)', StateIn, StateOut);
  Check(Length(Tokens) = 1, 'paren comment via stateful');
  Check(Tokens[0].Kind = tkComment, 'paren comment is tkComment');
end;

procedure TestTokenizeDirective;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('{$mode objfpc}');
  Check(Length(Tokens) = 1, 'directive');
  Check(Tokens[0].Kind = tkDirective, 'directive is tkDirective');
end;

procedure TestTokenizeSymbols;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('+');
  Check(Length(Tokens) = 1, 'plus symbol');
  Check(Tokens[0].Kind = tkSymbol, 'plus is tkSymbol');
  Tokens := TokenizePascal(';');
  Check(Length(Tokens) = 1, 'semicolon symbol');
  Check(Tokens[0].Kind = tkSymbol, 'semicolon is tkSymbol');
end;

procedure TestTokenizeEmptyLine;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('');
  Check(Length(Tokens) = 0, 'empty line has no tokens');
end;

procedure TestTokenizeMixedLine;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('function Foo: Integer;');
  Check(Length(Tokens) >= 4, 'mixed line has multiple tokens');
  Check(Tokens[0].Kind = tkKeyword, 'function is keyword');
  Check(Tokens[1].Kind = tkNormal, 'Foo is normal');
end;

procedure TestTokenizeMixedWithComment;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('x := 42; { set x }');
  Check(Length(Tokens) >= 4, 'mixed with comment');
  Check(Tokens[High(Tokens)].Kind = tkComment, 'last token is comment');
end;

procedure TestTokenizeNegativeNumber;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('-42');
  Check(Length(Tokens) >= 2, 'negative number has minus + number');
end;

procedure TestTokenizeFloat;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('3.14');
  Check(Length(Tokens) >= 1, 'float number');
  Check(Tokens[0].Kind = tkNumber, '3.14 is tkNumber');
end;

{ === TokenizePascalStateful === }

procedure TestStatefulNormalLine;
var
  StateIn, StateOut: TLineState;
  Tokens: TTokenArray;
begin
  FillChar(StateIn, SizeOf(StateIn), 0);
  Tokens := TokenizePascalStateful('begin', StateIn, StateOut);
  Check(Length(Tokens) = 1, 'stateful normal line');
  Check(not StateOut.InBlockComment, 'not in block comment after begin');
end;

procedure TestStatefulBlockCommentSpan;
var
  StateIn, StateOut1, StateOut2: TLineState;
  Tokens1, Tokens2: TTokenArray;
begin
  FillChar(StateIn, SizeOf(StateIn), 0);
  Tokens1 := TokenizePascalStateful('{ comment', StateIn, StateOut1);
  Check(StateOut1.InBlockComment, 'in block comment after unclosed {');
  Check(Length(Tokens1) = 1, 'first line has comment token');
  Check(Tokens1[0].Kind = tkComment, 'first line token is comment');

  Tokens2 := TokenizePascalStateful('still comment}', StateOut1, StateOut2);
  Check(not StateOut2.InBlockComment, 'block comment closed');
  Check(Length(Tokens2) = 1, 'second line has comment token');
end;

procedure TestStatefulCodeAfterComment;
var
  StateIn, StateOut: TLineState;
  Tokens: TTokenArray;
begin
  FillChar(StateIn, SizeOf(StateIn), 0);
  Tokens := TokenizePascalStateful('{ comment } x := 1;', StateIn, StateOut);
  Check(not StateOut.InBlockComment, 'not in block comment');
  Check(Length(Tokens) >= 2, 'comment + code tokens');
  Check(Tokens[0].Kind = tkComment, 'first is comment');
end;

{ === TSyntaxDoc === }

procedure TestSyntaxDocCreate;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 3);
  Helper.Lines[0] := 'program Test;';
  Helper.Lines[1] := 'begin';
  Helper.Lines[2] := 'end';
  Doc := TSyntaxDoc.Create(HL, 3, @Helper.GetLine);
  Check(Doc.LineCount = 3, 'LineCount is 3');
end;

procedure TestSyntaxDocGetTokens;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
  Ptr: PToken;
  Count: Integer;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 2);
  Helper.Lines[0] := 'begin';
  Helper.Lines[1] := 'end';
  Doc := TSyntaxDoc.Create(HL, 2, @Helper.GetLine);
  Doc.GetTokens(0, Ptr, Count);
  Check(Count >= 1, 'line 0 has tokens');
  Check(Ptr^.Kind = tkKeyword, 'line 0 first token is keyword');

  Doc.Invalidate(1);
  Doc.GetTokens(1, Ptr, Count);
  Check(Count >= 1, 'line 1 has tokens');
  Check(Ptr^.Kind = tkKeyword, 'line 1 first token is keyword');
end;

procedure TestSyntaxDocSetLineCount;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 2);
  Helper.Lines[0] := 'begin';
  Helper.Lines[1] := 'end.';
  Doc := TSyntaxDoc.Create(HL, 2, @Helper.GetLine);
  Check(Doc.LineCount = 2, 'initial LineCount is 2');
  SetLength(Helper.Lines, 4);
  Helper.Lines[2] := 'x := 1;';
  Helper.Lines[3] := 'y := 2;';
  Doc.SetLineCount(4);
  Check(Doc.LineCount = 4, 'LineCount is 4 after SetLineCount');
end;

procedure TestSyntaxDocInvalidate;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
  Ptr: PToken;
  Count: Integer;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 2);
  Helper.Lines[0] := 'begin';
  Helper.Lines[1] := 'end.';
  Doc := TSyntaxDoc.Create(HL, 2, @Helper.GetLine);
  Doc.GetTokens(0, Ptr, Count);
  Check(Count >= 1, 'has tokens before invalidate');
  Doc.Invalidate(0);
  Doc.GetTokens(0, Ptr, Count);
  Check(Count >= 1, 'has tokens after invalidate + re-tokenize');
end;

procedure TestSyntaxDocNotifyInsert;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
  Ptr: PToken;
  Count: Integer;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 2);
  Helper.Lines[0] := 'begin';
  Helper.Lines[1] := 'end.';
  Doc := TSyntaxDoc.Create(HL, 2, @Helper.GetLine);
  SetLength(Helper.Lines, 3);
  Helper.Lines[1] := 'x := 1;';
  Helper.Lines[2] := 'end.';
  Doc.NotifyInsert(1, 1);
  Check(Doc.LineCount = 3, 'LineCount is 3 after insert');
  Doc.GetTokens(1, Ptr, Count);
  Check(Count >= 1, 'inserted line has tokens');
end;

procedure TestSyntaxDocNotifyDelete;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 3);
  Helper.Lines[0] := 'begin';
  Helper.Lines[1] := 'x := 1;';
  Helper.Lines[2] := 'end.';
  Doc := TSyntaxDoc.Create(HL, 3, @Helper.GetLine);
  SetLength(Helper.Lines, 2);
  Helper.Lines[1] := 'end.';
  Doc.NotifyDelete(1, 1);
  Check(Doc.LineCount = 2, 'LineCount is 2 after delete');
end;

procedure TestSyntaxDocEnsureCleanTo;
var
  HL: IHighlighter;
  Doc: TSyntaxDoc;
  Ptr: PToken;
  Count: Integer;
begin
  HL := TPascalHighlighter.Create;
  SetLength(Helper.Lines, 5);
  Helper.Lines[0] := 'program Test;';
  Helper.Lines[1] := 'begin';
  Helper.Lines[2] := '  x := 1;';
  Helper.Lines[3] := '  y := 2;';
  Helper.Lines[4] := 'end.';
  Doc := TSyntaxDoc.Create(HL, 5, @Helper.GetLine);
  Doc.EnsureCleanTo(2, 10);
  Doc.GetTokens(2, Ptr, Count);
  Check(Count >= 1, 'EnsureCleanTo tokenizes up to line 2');
end;

{ === TSyntaxTheme === }

procedure TestSyntaxThemeDefault;
var Theme: TSyntaxTheme;
begin
  Theme := TSyntaxTheme.Default;
  Check(Theme.StyleFor(tkKeyword).Fg.Kind <> ckUnset, 'default theme keyword has fg');
  Check(Theme.StyleFor(tkString).Fg.Kind <> ckUnset, 'default theme string has fg');
  Check(Theme.StyleFor(tkComment).Fg.Kind <> ckUnset, 'default theme comment has fg');
  Check(Theme.StyleFor(tkNumber).Fg.Kind <> ckUnset, 'default theme number has fg');
  Check(Theme.StyleFor(tkDirective).Fg.Kind <> ckUnset, 'default theme directive has fg');
  Check(Theme.StyleFor(tkSymbol).Fg.Kind <> ckUnset, 'default theme symbol has fg');
end;

procedure TestSyntaxThemeNord;
var Theme: TSyntaxTheme;
begin
  Theme := TSyntaxTheme.Nord;
  Check(Theme.StyleFor(tkKeyword).Fg.Kind <> ckUnset, 'nord theme keyword has fg');
  Check(Theme.StyleFor(tkComment).Fg.Kind <> ckUnset, 'nord theme comment has fg');
end;

procedure TestSyntaxThemeStyleForDiffers;
var Theme: TSyntaxTheme;
begin
  Theme := TSyntaxTheme.Default;
  Check(not ColorEquals(Theme.StyleFor(tkKeyword).Fg, Theme.StyleFor(tkComment).Fg),
    'keyword and comment have different colors in default theme');
end;

begin
  T := TTestRunner.Create('test_tui_syntax');
  Helper := TSyntaxTestHelper.Create;
  try
    { IsPascalKeyword }
    T.Run('keyword begin', @TestKeywordBegin);
    T.Run('keyword end', @TestKeywordEnd);
    T.Run('keyword if then', @TestKeywordIfThen);
    T.Run('keyword function', @TestKeywordFunction);
    T.Run('keyword class', @TestKeywordClass);
    T.Run('keyword operators', @TestKeywordOperators);
    T.Run('keyword control', @TestKeywordControl);
    T.Run('keyword other', @TestKeywordOther);
    T.Run('non keyword', @TestNonKeyword);

    { IsPascalKeywordP }
    T.Run('keyword P variant', @TestKeywordP);
    T.Run('non keyword P variant', @TestNonKeywordP);

    { TPascalHighlighter }
    T.Run('highlighter LangId', @TestHighlighterLangId);
    T.Run('highlighter TokenizeLine', @TestHighlighterTokenizeLine);

    { TokenizePascal }
    T.Run('tokenize keyword', @TestTokenizeKeyword);
    T.Run('tokenize identifier', @TestTokenizeIdentifier);
    T.Run('tokenize number', @TestTokenizeNumber);
    T.Run('tokenize hex number', @TestTokenizeHexNumber);
    T.Run('tokenize string', @TestTokenizeString);
    T.Run('tokenize block comment', @TestTokenizeBlockComment);
    T.Run('tokenize line comment', @TestTokenizeLineComment);
    T.Run('tokenize paren comment', @TestTokenizeParenComment);
    T.Run('tokenize directive', @TestTokenizeDirective);
    T.Run('tokenize symbols', @TestTokenizeSymbols);
    T.Run('tokenize empty line', @TestTokenizeEmptyLine);
    T.Run('tokenize mixed line', @TestTokenizeMixedLine);
    T.Run('tokenize mixed with comment', @TestTokenizeMixedWithComment);
    T.Run('tokenize negative number', @TestTokenizeNegativeNumber);
    T.Run('tokenize float', @TestTokenizeFloat);

    { TokenizePascalStateful }
    T.Run('stateful normal line', @TestStatefulNormalLine);
    T.Run('stateful block comment span', @TestStatefulBlockCommentSpan);
    T.Run('stateful code after comment', @TestStatefulCodeAfterComment);

    { TSyntaxDoc }
    T.Run('syntax doc create', @TestSyntaxDocCreate);
    T.Run('syntax doc GetTokens', @TestSyntaxDocGetTokens);
    T.Run('syntax doc SetLineCount', @TestSyntaxDocSetLineCount);
    T.Run('syntax doc Invalidate', @TestSyntaxDocInvalidate);
    T.Run('syntax doc NotifyInsert', @TestSyntaxDocNotifyInsert);
    T.Run('syntax doc NotifyDelete', @TestSyntaxDocNotifyDelete);
    T.Run('syntax doc EnsureCleanTo', @TestSyntaxDocEnsureCleanTo);

    { TSyntaxTheme }
    T.Run('syntax theme default', @TestSyntaxThemeDefault);
    T.Run('syntax theme nord', @TestSyntaxThemeNord);
    T.Run('syntax theme styles differ', @TestSyntaxThemeStyleForDiffers);

    WriteLn;
    T.Summary;
  finally
    Helper.Destroy;
  end;
end.
