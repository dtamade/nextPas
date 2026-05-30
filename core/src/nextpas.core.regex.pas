unit nextpas.core.regex;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.regex.types,
  nextpas.core.regex.charclass,
  nextpas.core.regex.parser,
  nextpas.core.regex.compiler,
  nextpas.core.regex.nfa,
  nextpas.core.text.base;

type
  TMatch = nextpas.core.regex.types.TMatch;
  TMatchArray = nextpas.core.regex.types.TMatchArray;
  TGroup = nextpas.core.regex.types.TGroup;
  ERegexError = nextpas.core.regex.types.ERegexError;
  ERegexCompileError = nextpas.core.regex.types.ERegexCompileError;

  TRegex = record
  private
    FProgram: TRegexProgram;
    FValid: Boolean;
  public
    class function Compile(const APattern: string): TRegex; static;
    class function TryCompile(const APattern: string; out ARegex: TRegex; out AError: string): Boolean; static;

    function IsMatch(const AInput: string): Boolean;
    function Find(const AInput: string): TMatch;
    function FindAll(const AInput: string): TMatchArray;
    function ReplaceFirst(const AInput, AReplacement: string): string;
    function ReplaceAll(const AInput, AReplacement: string): string;
    function Split(const AInput: string): TStringArray;
  end;

function RegexIsMatch(const APattern, AInput: string): Boolean;
function RegexFind(const APattern, AInput: string): TMatch;
function RegexFindAll(const APattern, AInput: string): TMatchArray;
function RegexReplaceAll(const APattern, AInput, AReplacement: string): string;
function RegexSplit(const APattern, AInput: string): TStringArray;

implementation

{ TRegex }

class function TRegex.Compile(const APattern: string): TRegex;
var
  LAst: PAstNode;
  LNumCaptures: UInt32;
begin
  FillChar(Result, SizeOf(Result), 0);
  LAst := RegexParse(APattern, LNumCaptures);
  try
    Result.FProgram := RegexCompile(LAst, LNumCaptures);
    Result.FValid := True;
  finally
    RegexFreeAst(LAst);
  end;
end;

class function TRegex.TryCompile(const APattern: string; out ARegex: TRegex; out AError: string): Boolean;
begin
  try
    ARegex := TRegex.Compile(APattern);
    AError := '';
    Result := True;
  except
    on E: ERegexCompileError do
    begin
      FillChar(ARegex, SizeOf(ARegex), 0);
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TRegex.IsMatch(const AInput: string): Boolean;
var LMatch: TMatch;
begin
  if not FValid then Exit(False);
  Result := NfaSearch(FProgram, PAnsiChar(AInput), Length(AInput), False, LMatch);
end;

function TRegex.Find(const AInput: string): TMatch;
begin
  if not FValid then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    Exit;
  end;
  if not NfaSearch(FProgram, PAnsiChar(AInput), Length(AInput), False, Result) then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
  end;
end;

function TRegex.FindAll(const AInput: string): TMatchArray;
begin
  if not FValid then begin SetLength(Result, 0); Exit; end;
  Result := NfaFindAll(FProgram, PAnsiChar(AInput), Length(AInput));
end;

function TRegex.ReplaceFirst(const AInput, AReplacement: string): string;
var LMatch: TMatch;
begin
  LMatch := Find(AInput);
  if not LMatch.Found then Exit(AInput);
  Result := Copy(AInput, 1, LMatch.Start) + AReplacement +
            Copy(AInput, LMatch.Start + LMatch.Len + 1, Length(AInput));
end;

function TRegex.ReplaceAll(const AInput, AReplacement: string): string;
var
  LMatches: TMatchArray;
  i: SizeInt;
  LPos: SizeUInt;
begin
  LMatches := FindAll(AInput);
  if Length(LMatches) = 0 then Exit(AInput);

  Result := '';
  LPos := 1;
  for i := 0 to High(LMatches) do
  begin
    Result := Result + Copy(AInput, LPos, SizeUInt(LMatches[i].Start + 1) - LPos);
    Result := Result + AReplacement;
    LPos := SizeUInt(LMatches[i].Start + LMatches[i].Len + 1);
  end;
  Result := Result + Copy(AInput, LPos, Length(AInput) - LPos + 1);
end;

function TRegex.Split(const AInput: string): TStringArray;
var
  LMatches: TMatchArray;
  i: SizeInt;
  LPos, LCount: SizeUInt;
begin
  LMatches := FindAll(AInput);
  if Length(LMatches) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := AInput;
    Exit;
  end;

  SetLength(Result, Length(LMatches) + 1);
  LPos := 1;
  for i := 0 to High(LMatches) do
  begin
    Result[i] := Copy(AInput, LPos, SizeUInt(LMatches[i].Start + 1) - LPos);
    LPos := SizeUInt(LMatches[i].Start + LMatches[i].Len + 1);
  end;
  Result[Length(LMatches)] := Copy(AInput, LPos, Length(AInput) - LPos + 1);
end;

{ Convenience functions }

function RegexIsMatch(const APattern, AInput: string): Boolean;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.IsMatch(AInput);
end;

function RegexFind(const APattern, AInput: string): TMatch;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.Find(AInput);
end;

function RegexFindAll(const APattern, AInput: string): TMatchArray;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.FindAll(AInput);
end;

function RegexReplaceAll(const APattern, AInput, AReplacement: string): string;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.ReplaceAll(AInput, AReplacement);
end;

function RegexSplit(const APattern, AInput: string): TStringArray;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.Split(AInput);
end;

end.
