unit np_lexer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TTokenKind = (
    tkUnknown,
    tkProgramKeyword,
    tkUnitKeyword,
    tkLibraryKeyword,
    tkPackageKeyword,
    tkUsesKeyword,
    tkInterfaceKeyword,
    tkImplementationKeyword,
    tkProcedureKeyword,
    tkExternalKeyword,
    tkNameKeyword,
    tkCdeclKeyword,
    tkBeginKeyword,
    tkEndKeyword,
    tkIdentifier,
    tkStringLiteral,
    tkSemicolon,
    tkDot,
    tkLParen,
    tkRParen,
    tkComma,
    tkColon,
    tkAssign,
    tkEOF
  );

  TToken = record
    Kind: TTokenKind;
    Lexeme: string;
    ByteOffset: LongInt;
  end;

  TLexerResult = class
  private
    FTokens: array of TToken;
    procedure AddToken(
      const AKind: TTokenKind;
      const ALexeme: string;
      const AByteOffset: LongInt
    );
    procedure LexSource(const ASourceText: string);
  public
    constructor Create(const ASourceText: string);
    function TokenCount: LongInt;
    function TokenAt(const AIndex: LongInt): TToken;
  end;

function TokenKindName(const AKind: TTokenKind): string;

implementation

function IsIdentifierStart(const AChar: Char): Boolean;
begin
  Result := (AChar in ['A'..'Z']) or (AChar in ['a'..'z']) or (AChar = '_');
end;

function IsIdentifierContinue(const AChar: Char): Boolean;
begin
  Result := IsIdentifierStart(AChar) or (AChar in ['0'..'9']);
end;

function ResolveIdentifierKind(const ALexeme: string): TTokenKind;
var
  Lowered: string;
begin
  Lowered := LowerCase(ALexeme);
  if Lowered = 'program' then
    Exit(tkProgramKeyword);
  if Lowered = 'unit' then
    Exit(tkUnitKeyword);
  if Lowered = 'library' then
    Exit(tkLibraryKeyword);
  if Lowered = 'package' then
    Exit(tkPackageKeyword);
  if Lowered = 'uses' then
    Exit(tkUsesKeyword);
  if Lowered = 'interface' then
    Exit(tkInterfaceKeyword);
  if Lowered = 'implementation' then
    Exit(tkImplementationKeyword);
  if Lowered = 'procedure' then
    Exit(tkProcedureKeyword);
  if Lowered = 'external' then
    Exit(tkExternalKeyword);
  if Lowered = 'name' then
    Exit(tkNameKeyword);
  if Lowered = 'cdecl' then
    Exit(tkCdeclKeyword);
  if Lowered = 'begin' then
    Exit(tkBeginKeyword);
  if Lowered = 'end' then
    Exit(tkEndKeyword);

  Result := tkIdentifier;
end;

procedure SkipBraceComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex);
  while (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] <> '}') do
    Inc(AIndex);
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
end;

procedure SkipParenStarComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex, 2);
  while AIndex <= Length(ASourceText) - 1 do
  begin
    if (ASourceText[AIndex] = '*') and (ASourceText[AIndex + 1] = ')') then
    begin
      Inc(AIndex, 2);
      Exit;
    end;
    Inc(AIndex);
  end;

  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
end;

procedure SkipLineComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex, 2);
  while (AIndex <= Length(ASourceText)) and
    not (ASourceText[AIndex] in [#10, #13]) do
    Inc(AIndex);
end;

function ReadStringLiteral(const ASourceText: string; var AIndex: SizeInt): string;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  Inc(AIndex);

  while AIndex <= Length(ASourceText) do
  begin
    if ASourceText[AIndex] = '''' then
    begin
      Inc(AIndex);
      if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '''') then
        Inc(AIndex)
      else
        Break;
    end
    else
      Inc(AIndex);
  end;

  Result := Copy(ASourceText, StartIndex, AIndex - StartIndex);
end;

constructor TLexerResult.Create(const ASourceText: string);
begin
  inherited Create;
  SetLength(FTokens, 0);
  LexSource(ASourceText);
end;

procedure TLexerResult.AddToken(
  const AKind: TTokenKind;
  const ALexeme: string;
  const AByteOffset: LongInt
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTokens);
  SetLength(FTokens, NextIndex + 1);
  FTokens[NextIndex].Kind := AKind;
  FTokens[NextIndex].Lexeme := ALexeme;
  FTokens[NextIndex].ByteOffset := AByteOffset;
end;

procedure TLexerResult.LexSource(const ASourceText: string);
var
  CurrentChar: Char;
  StartIndex: SizeInt;
  Lexeme: string;
begin
  StartIndex := 1;
  while StartIndex <= Length(ASourceText) do
  begin
    CurrentChar := ASourceText[StartIndex];

    if CurrentChar in [#0..#32] then
    begin
      Inc(StartIndex);
      Continue;
    end;

    if CurrentChar = '{' then
    begin
      SkipBraceComment(ASourceText, StartIndex);
      Continue;
    end;

    if (CurrentChar = '(') and
      (StartIndex < Length(ASourceText)) and
      (ASourceText[StartIndex + 1] = '*') then
    begin
      SkipParenStarComment(ASourceText, StartIndex);
      Continue;
    end;

    if (CurrentChar = '/') and
      (StartIndex < Length(ASourceText)) and
      (ASourceText[StartIndex + 1] = '/') then
    begin
      SkipLineComment(ASourceText, StartIndex);
      Continue;
    end;

    if IsIdentifierStart(CurrentChar) then
    begin
      Lexeme := CurrentChar;
      Inc(StartIndex);
      while (StartIndex <= Length(ASourceText)) and
        IsIdentifierContinue(ASourceText[StartIndex]) do
      begin
        Lexeme := Lexeme + ASourceText[StartIndex];
        Inc(StartIndex);
      end;
      AddToken(ResolveIdentifierKind(Lexeme), Lexeme, StartIndex - Length(Lexeme) - 1);
      Continue;
    end;

    if CurrentChar = '''' then
    begin
      Lexeme := ReadStringLiteral(ASourceText, StartIndex);
      AddToken(tkStringLiteral, Lexeme, StartIndex - Length(Lexeme) - 1);
      Continue;
    end;

    case CurrentChar of
      ';':
        AddToken(tkSemicolon, ';', StartIndex - 1);
      '.':
        AddToken(tkDot, '.', StartIndex - 1);
      '(':
        AddToken(tkLParen, '(', StartIndex - 1);
      ')':
        AddToken(tkRParen, ')', StartIndex - 1);
      ',':
        AddToken(tkComma, ',', StartIndex - 1);
      ':':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddToken(tkAssign, ':=', StartIndex - 1);
            Inc(StartIndex);
          end
          else
            AddToken(tkColon, ':', StartIndex - 1);
        end;
    else
      AddToken(tkUnknown, CurrentChar, StartIndex - 1);
    end;

    Inc(StartIndex);
  end;

  AddToken(tkEOF, '', Length(ASourceText));
end;

function TLexerResult.TokenCount: LongInt;
begin
  Result := Length(FTokens);
end;

function TLexerResult.TokenAt(const AIndex: LongInt): TToken;
begin
  if (AIndex < 0) or (AIndex >= Length(FTokens)) then
  begin
    Result.Kind := tkEOF;
    Result.Lexeme := '';
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FTokens[AIndex];
end;

function TokenKindName(const AKind: TTokenKind): string;
begin
  case AKind of
    tkProgramKeyword:
      Result := 'program';
    tkUnitKeyword:
      Result := 'unit';
    tkLibraryKeyword:
      Result := 'library';
    tkPackageKeyword:
      Result := 'package';
    tkUsesKeyword:
      Result := 'uses';
    tkInterfaceKeyword:
      Result := 'interface';
    tkImplementationKeyword:
      Result := 'implementation';
    tkProcedureKeyword:
      Result := 'procedure';
    tkExternalKeyword:
      Result := 'external';
    tkNameKeyword:
      Result := 'name';
    tkCdeclKeyword:
      Result := 'cdecl';
    tkBeginKeyword:
      Result := 'begin';
    tkEndKeyword:
      Result := 'end';
    tkIdentifier:
      Result := 'identifier';
    tkStringLiteral:
      Result := 'string-literal';
    tkSemicolon:
      Result := ';';
    tkDot:
      Result := '.';
    tkLParen:
      Result := '(';
    tkRParen:
      Result := ')';
    tkComma:
      Result := ',';
    tkColon:
      Result := ':';
    tkAssign:
      Result := ':=';
    tkEOF:
      Result := 'end-of-file';
  else
    Result := 'unknown';
  end;
end;

end.
