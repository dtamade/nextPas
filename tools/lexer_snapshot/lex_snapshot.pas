{
  lex_snapshot — golden-file snapshot tool for the nextPas lexer.

  Usage:
    lex_snapshot [--trivia] <path-to-source.pas>

  Default output (stdout, one line per non-trivia token):
    <offset>:<line>:<col>\t<length>\t<kind-name>\t<lexeme-escaped>

  With --trivia, each non-trivia token line is preceded by zero
  or more leading-trivia lines (prefixed with "L ") and followed
  by zero or more trailing-trivia lines (prefixed with "T "):
    L <offset>\t<length>\t<trivia-kind>
    <token line as above>
    T <offset>\t<length>\t<trivia-kind>

  Where trivia-kind is one of:
    whitespace | line-terminator | line-comment |
    brace-comment | paren-star-comment

  Lexeme is double-quoted with \", \\, \t, \n, \r, and \xNN
  escapes so the output is single-line and ASCII-stable. The EOF
  token is emitted explicitly (offset = file length, len 0).
}
program lex_snapshot;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, np_lexer;

procedure Die(const AMsg: string; const AExitCode: LongInt);
begin
  Writeln(StdErr, 'lex_snapshot: ', AMsg);
  Halt(AExitCode);
end;

function ReadEntireFile(const APath: string): string;
var
  Stream: TFileStream;
  Bytes: TBytes;
  Len: SizeInt;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Len := Stream.Size;
    SetLength(Bytes, Len);
    if Len > 0 then
      Stream.ReadBuffer(Bytes[0], Len);
    SetLength(Result, Len);
    if Len > 0 then
      Move(Bytes[0], Result[1], Len);
  finally
    Stream.Free;
  end;
end;

function EscapeLexeme(const AValue: string): string;
var
  I: SizeInt;
  Ch: Char;
begin
  Result := '"';
  for I := 1 to Length(AValue) do
  begin
    Ch := AValue[I];
    case Ch of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #9:  Result := Result + '\t';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
    else
      if Ord(Ch) < 32 then
        Result := Result + '\x' + LowerCase(IntToHex(Ord(Ch), 2))
      else
        Result := Result + Ch;
    end;
  end;
  Result := Result + '"';
end;

function TriviaKindName(const AKind: TTriviaKind): string;
begin
  case AKind of
    tvkWhitespace: Result := 'whitespace';
    tvkLineTerminator: Result := 'line-terminator';
    tvkLineComment: Result := 'line-comment';
    tvkBraceComment: Result := 'brace-comment';
    tvkParenStarComment: Result := 'paren-star-comment';
  else
    Result := 'unknown-trivia';
  end;
end;

procedure WriteTrivia(const APrefix: string; const APiece: TTriviaPiece);
begin
  Writeln(APrefix, ' ',
    APiece.ByteOffset, #9,
    APiece.Length, #9,
    TriviaKindName(APiece.Kind));
end;

procedure SnapshotFile(const APath: string; const AIncludeTrivia: Boolean);
var
  Source: string;
  Lex: TLexerResult;
  I, J: LongInt;
  Tok: TToken;
  Length_: LongInt;
begin
  Source := ReadEntireFile(APath);
  Lex := TLexerResult.Create(Source);
  try
    for I := 0 to Lex.TokenCount - 1 do
    begin
      Tok := Lex.TokenAt(I);
      if AIncludeTrivia then
        for J := 0 to System.Length(Tok.LeadingTrivia) - 1 do
          WriteTrivia('L', Tok.LeadingTrivia[J]);
      Length_ := System.Length(Tok.Lexeme);
      Writeln(
        Tok.ByteOffset, ':',
        Tok.Line, ':',
        Tok.Column, #9,
        Length_, #9,
        TokenKindName(Tok.Kind), #9,
        EscapeLexeme(Tok.Lexeme)
      );
      if AIncludeTrivia then
        for J := 0 to System.Length(Tok.TrailingTrivia) - 1 do
          WriteTrivia('T', Tok.TrailingTrivia[J]);
    end;
  finally
    Lex.Free;
  end;
end;

var
  IncludeTrivia: Boolean;
  PathArg: string;
begin
  IncludeTrivia := False;
  PathArg := '';
  if ParamCount = 1 then
    PathArg := ParamStr(1)
  else if (ParamCount = 2) and (ParamStr(1) = '--trivia') then
  begin
    IncludeTrivia := True;
    PathArg := ParamStr(2);
  end
  else
    Die('usage: lex_snapshot [--trivia] <path-to-source.pas>', 2);
  if not FileExists(PathArg) then
    Die('file not found: ' + PathArg, 2);
  try
    SnapshotFile(PathArg, IncludeTrivia);
  except
    on E: Exception do
      Die(E.ClassName + ': ' + E.Message, 1);
  end;
end.
