unit nextpas.core.regex;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.regex.base,
  nextpas.core.regex.charclass,
  nextpas.core.regex.parser,
  nextpas.core.regex.compiler,
  nextpas.core.regex.nfa,
  nextpas.core.text.base;

type
  TMatch = nextpas.core.regex.base.TMatch;
  TMatchArray = nextpas.core.regex.base.TMatchArray;
  TGroup = nextpas.core.regex.base.TGroup;
  ERegexError = nextpas.core.regex.base.ERegexError;
  ERegexCompileError = nextpas.core.regex.base.ERegexCompileError;

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
    function GroupByName(const AMatch: TMatch; const AName: string): TGroup;
    function GroupIndexByName(const AName: string): SizeInt;
    function NumCaptures: UInt32;
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
  Result.FProgram.Code := nil;
  Result.FProgram.Classes := nil;
  Result.FProgram.LiteralPrefix := '';
  Result.FProgram.LiteralPrefixLen := 0;
  Result.FProgram.NumSlots := 0;
  Result.FValid := False;
  LAst := nil;
  try
    LAst := RegexParse(APattern, LNumCaptures);
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
      ARegex.FProgram.Code := nil;
      ARegex.FProgram.Classes := nil;
      ARegex.FValid := False;
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TRegex.IsMatch(const AInput: string): Boolean;
begin
  if not FValid then Exit(False);
  Result := NfaIsMatch(FProgram, PAnsiChar(AInput), Length(AInput));
end;

function TRegex.Find(const AInput: string): TMatch;
begin
  if not FValid then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    Exit;
  end;
  if not NfaSearch(FProgram, PAnsiChar(AInput), Length(AInput), False, 0, Result) then
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
  LPos: SizeUInt;
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

function TRegex.GroupIndexByName(const AName: string): SizeInt;
var i: SizeInt;
begin
  for i := 0 to High(FProgram.GroupNames) do
    if FProgram.GroupNames[i].Name = AName then
      Exit(SizeInt(FProgram.GroupNames[i].Index));
  Result := -1;
end;

function TRegex.GroupByName(const AMatch: TMatch; const AName: string): TGroup;
var LIdx: SizeInt;
begin
  LIdx := GroupIndexByName(AName);
  if (LIdx >= 0) and (LIdx < Length(AMatch.Groups)) then
    Result := AMatch.Groups[LIdx]
  else
  begin
    Result.Start := -1;
    Result.Len := 0;
  end;
end;

function TRegex.NumCaptures: UInt32;
begin
  Result := FProgram.NumCaptures;
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
