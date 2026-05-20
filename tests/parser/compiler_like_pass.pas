program Compiler_like_pass;

{$mode objfpc}{$H+}

type
  TTokenKind = (
    tkIdentifier,
    tkInteger,
    tkString,
    tkPlus,
    tkMinus,
    tkSemicolon,
    tkEOF
  );

  TToken = record
    Kind: TTokenKind;
    Lexeme: string;
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TTokenArray = array of TToken;

  TLexer = class
  private
    FSource: string;
    FTokens: TTokenArray;
    FCount: Integer;
    FCapacity: Integer;
    procedure Grow;
    procedure AddToken(AKind: TTokenKind; const ALexeme: string;
      AOffset, ALine, ACol: Integer);
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;
    procedure Tokenize;
    function TokenAt(Index: Integer): TToken;
    function TokenCount: Integer;
  end;

constructor TLexer.Create(const ASource: string);
begin
  FSource := ASource;
  FCount := 0;
  FCapacity := 64;
  SetLength(FTokens, FCapacity);
end;

destructor TLexer.Destroy;
begin
  SetLength(FTokens, 0);
  inherited Destroy;
end;

procedure TLexer.Grow;
begin
  FCapacity := FCapacity * 2;
  SetLength(FTokens, FCapacity);
end;

procedure TLexer.AddToken(AKind: TTokenKind; const ALexeme: string;
  AOffset, ALine, ACol: Integer);
begin
  if FCount >= FCapacity then
    Grow;
  FTokens[FCount].Kind := AKind;
  FTokens[FCount].Lexeme := ALexeme;
  FTokens[FCount].Offset := AOffset;
  FTokens[FCount].Line := ALine;
  FTokens[FCount].Column := ACol;
  Inc(FCount);
end;

procedure TLexer.Tokenize;
var
  I: Integer;
  Ch: Char;
begin
  I := 1;
  while I <= Length(FSource) do
  begin
    Ch := FSource[I];
    case Ch of
      '+': begin AddToken(tkPlus, '+', I, 1, I); Inc(I); end;
      '-': begin AddToken(tkMinus, '-', I, 1, I); Inc(I); end;
      ';': begin AddToken(tkSemicolon, ';', I, 1, I); Inc(I); end;
    else
      Inc(I);
    end;
  end;
  AddToken(tkEOF, '', Length(FSource) + 1, 1, Length(FSource) + 1);
end;

function TLexer.TokenAt(Index: Integer): TToken;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FTokens[Index]
  else
  begin
    Result.Kind := tkEOF;
    Result.Lexeme := '';
    Result.Offset := 0;
    Result.Line := 0;
    Result.Column := 0;
  end;
end;

function TLexer.TokenCount: Integer;
begin
  Result := FCount;
end;

var
  Lex: TLexer;
  T: TToken;
  I: Integer;
begin
  Lex := TLexer.Create('a + b - c;');
  try
    Lex.Tokenize;
    for I := 0 to Lex.TokenCount - 1 do
    begin
      T := Lex.TokenAt(I);
      if T.Kind = tkEOF then
        Break;
    end;
  finally
    Lex.Free;
  end;
end.
