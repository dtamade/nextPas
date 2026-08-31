unit nextpas.compiler.syntax.lexer;

{$mode objfpc}{$H+}

interface

uses
  np_lexer;

type
  TTokenKind = np_lexer.TTokenKind;
  TTriviaKind = np_lexer.TTriviaKind;
  TTriviaPiece = np_lexer.TTriviaPiece;
  TTriviaPieceVec = np_lexer.TTriviaPieceVec;
  TToken = np_lexer.TToken;
  PToken = np_lexer.PToken;
  TTokenVec = np_lexer.TTokenVec;
  TLexerResult = np_lexer.TLexerResult;

function CloneTriviaPieceVec(const ASrc: TTriviaPieceVec; AAllocator: IAllocator = nil): TTriviaPieceVec; inline;
function CloneTokenWithTrivia(const ASrc: TToken; AAllocator: IAllocator = nil): TToken; inline;
procedure FreeTokenNestedTrivia(var AToken: TToken); inline;
procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec); inline;
function TokenKindName(const AKind: TTokenKind): string; inline;

implementation

function CloneTriviaPieceVec(const ASrc: TTriviaPieceVec; AAllocator: IAllocator): TTriviaPieceVec; inline;
begin
  Result := np_lexer.CloneTriviaPieceVec(ASrc, AAllocator);
end;

function CloneTokenWithTrivia(const ASrc: TToken; AAllocator: IAllocator): TToken; inline;
begin
  Result := np_lexer.CloneTokenWithTrivia(ASrc, AAllocator);
end;

procedure FreeTokenNestedTrivia(var AToken: TToken); inline;
begin
  np_lexer.FreeTokenNestedTrivia(AToken);
end;

procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec); inline;
begin
  np_lexer.FreeTokenVecNestedTrivia(ATokens);
end;

function TokenKindName(const AKind: TTokenKind): string; inline;
begin
  Result := np_lexer.TokenKindName(AKind);
end;

end.
