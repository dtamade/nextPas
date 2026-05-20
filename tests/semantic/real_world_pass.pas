program Real_world_pass;

{$mode objfpc}{$H+}

type
  TTokenKind = (
    tkNone, tkIdent, tkNumber, tkString,
    tkPlus, tkMinus, tkStar, tkSlash,
    tkLParen, tkRParen, tkSemicolon, tkDot,
    tkAssign, tkColon, tkComma, tkEOF
  );

  TToken = record
    Kind: TTokenKind;
    Text: string;
    Line: Integer;
    Col: Integer;
  end;

  TTokenList = class
  private
    FItems: array of TToken;
    FCount: Integer;
    FCapacity: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(AKind: TTokenKind; const AText: string; ALine, ACol: Integer);
    function Get(Index: Integer): TToken;
    function Count: Integer;
    procedure Clear;
  end;

  TLexerState = (lsNormal, lsInString, lsInComment);

  TSimpleLexer = class
  private
    FSource: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FState: TLexerState;
    FTokens: TTokenList;
    function CurrentChar: Char;
    function PeekChar: Char;
    procedure Advance;
    procedure SkipWhitespace;
    function ReadIdentifier: string;
    function ReadNumber: string;
    function ReadString: string;
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;
    procedure Tokenize;
    function TokenCount: Integer;
    function TokenAt(Index: Integer): TToken;
  end;

constructor TTokenList.Create;
begin
  FCount := 0;
  FCapacity := 32;
  SetLength(FItems, FCapacity);
end;

destructor TTokenList.Destroy;
begin
  SetLength(FItems, 0);
  inherited Destroy;
end;

procedure TTokenList.Add(AKind: TTokenKind; const AText: string;
  ALine, ACol: Integer);
begin
  if FCount >= FCapacity then
  begin
    FCapacity := FCapacity * 2;
    SetLength(FItems, FCapacity);
  end;
  FItems[FCount].Kind := AKind;
  FItems[FCount].Text := AText;
  FItems[FCount].Line := ALine;
  FItems[FCount].Col := ACol;
  Inc(FCount);
end;

function TTokenList.Get(Index: Integer): TToken;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FItems[Index]
  else
  begin
    Result.Kind := tkEOF;
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TTokenList.Count: Integer;
begin
  Result := FCount;
end;

procedure TTokenList.Clear;
begin
  FCount := 0;
end;

constructor TSimpleLexer.Create(const ASource: string);
begin
  FSource := ASource;
  FPos := 1;
  FLine := 1;
  FCol := 1;
  FState := lsNormal;
  FTokens := TTokenList.Create;
end;

destructor TSimpleLexer.Destroy;
begin
  FTokens.Free;
  inherited Destroy;
end;

function TSimpleLexer.CurrentChar: Char;
begin
  if FPos <= Length(FSource) then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TSimpleLexer.PeekChar: Char;
begin
  if FPos + 1 <= Length(FSource) then
    Result := FSource[FPos + 1]
  else
    Result := #0;
end;

procedure TSimpleLexer.Advance;
begin
  if FPos <= Length(FSource) then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
    Inc(FPos);
  end;
end;

procedure TSimpleLexer.SkipWhitespace;
begin
  while (FPos <= Length(FSource)) and (FSource[FPos] in [' ', #9, #10, #13]) do
    Advance;
end;

function TSimpleLexer.ReadIdentifier: string;
begin
  Result := '';
  while (FPos <= Length(FSource)) and
    (FSource[FPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
  begin
    Result := Result + FSource[FPos];
    Advance;
  end;
end;

function TSimpleLexer.ReadNumber: string;
begin
  Result := '';
  while (FPos <= Length(FSource)) and (FSource[FPos] in ['0'..'9']) do
  begin
    Result := Result + FSource[FPos];
    Advance;
  end;
end;

function TSimpleLexer.ReadString: string;
begin
  Result := '';
  Advance;
  while (FPos <= Length(FSource)) and (FSource[FPos] <> '''') do
  begin
    Result := Result + FSource[FPos];
    Advance;
  end;
  if FPos <= Length(FSource) then
    Advance;
end;

procedure TSimpleLexer.Tokenize;
var
  Ch: Char;
  StartLine, StartCol: Integer;
begin
  while FPos <= Length(FSource) do
  begin
    SkipWhitespace;
    if FPos > Length(FSource) then
      Break;
    Ch := CurrentChar;
    StartLine := FLine;
    StartCol := FCol;
    case Ch of
      'A'..'Z', 'a'..'z', '_':
        FTokens.Add(tkIdent, ReadIdentifier, StartLine, StartCol);
      '0'..'9':
        FTokens.Add(tkNumber, ReadNumber, StartLine, StartCol);
      '''':
        FTokens.Add(tkString, ReadString, StartLine, StartCol);
      '+': begin FTokens.Add(tkPlus, '+', StartLine, StartCol); Advance; end;
      '-': begin FTokens.Add(tkMinus, '-', StartLine, StartCol); Advance; end;
      '*': begin FTokens.Add(tkStar, '*', StartLine, StartCol); Advance; end;
      '/': begin FTokens.Add(tkSlash, '/', StartLine, StartCol); Advance; end;
      '(': begin FTokens.Add(tkLParen, '(', StartLine, StartCol); Advance; end;
      ')': begin FTokens.Add(tkRParen, ')', StartLine, StartCol); Advance; end;
      ';': begin FTokens.Add(tkSemicolon, ';', StartLine, StartCol); Advance; end;
      '.': begin FTokens.Add(tkDot, '.', StartLine, StartCol); Advance; end;
      ',': begin FTokens.Add(tkComma, ',', StartLine, StartCol); Advance; end;
      ':':
        begin
          if PeekChar = '=' then
          begin
            FTokens.Add(tkAssign, ':=', StartLine, StartCol);
            Advance;
            Advance;
          end
          else
          begin
            FTokens.Add(tkColon, ':', StartLine, StartCol);
            Advance;
          end;
        end;
    else
      Advance;
    end;
  end;
  FTokens.Add(tkEOF, '', FLine, FCol);
end;

function TSimpleLexer.TokenCount: Integer;
begin
  Result := FTokens.Count;
end;

function TSimpleLexer.TokenAt(Index: Integer): TToken;
begin
  Result := FTokens.Get(Index);
end;

var
  Lex: TSimpleLexer;
  I: Integer;
  T: TToken;
begin
  Lex := TSimpleLexer.Create('X := 42 + Y;');
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
