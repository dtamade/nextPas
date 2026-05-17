{
  lex_snapshot — golden-file snapshot tool for the nextPas lexer.

  Usage:
    lex_snapshot <path-to-source.pas>

  Output (stdout, one line per token):
    <offset>\t<length>\t<kind-name>\t<lexeme-escaped>

  Where:
    offset      0-based byte offset of the token's first byte
    length      byte length of the token's lexeme
    kind-name   stable kind label from TokenKindName
    lexeme      Pascal-escaped lexeme (single-line, ASCII-safe)

  This tool intentionally emits the EOF token as well. Trivia
  (whitespace, comments) are NOT emitted today — that gap is one
  of the things the lexer-spec work will address.
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

procedure SnapshotFile(const APath: string);
var
  Source: string;
  Lex: TLexerResult;
  I: LongInt;
  Tok: TToken;
  Length_: LongInt;
begin
  Source := ReadEntireFile(APath);
  Lex := TLexerResult.Create(Source);
  try
    for I := 0 to Lex.TokenCount - 1 do
    begin
      Tok := Lex.TokenAt(I);
      Length_ := System.Length(Tok.Lexeme);
      Writeln(
        Tok.ByteOffset, #9,
        Length_, #9,
        TokenKindName(Tok.Kind), #9,
        EscapeLexeme(Tok.Lexeme)
      );
    end;
  finally
    Lex.Free;
  end;
end;

begin
  if ParamCount <> 1 then
    Die('usage: lex_snapshot <path-to-source.pas>', 2);
  if not FileExists(ParamStr(1)) then
    Die('file not found: ' + ParamStr(1), 2);
  try
    SnapshotFile(ParamStr(1));
  except
    on E: Exception do
      Die(E.ClassName + ': ' + E.Message, 1);
  end;
end.
