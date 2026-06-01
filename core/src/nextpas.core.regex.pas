unit nextpas.core.regex;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.regex.base,
  nextpas.core.regex.charclass,
  nextpas.core.regex.parser,
  nextpas.core.regex.compiler,
  nextpas.core.regex.nfa,
  nextpas.core.regex.dfa,
  nextpas.core.regex.teddy,
  nextpas.core.text.base,
  nextpas.core.text.scan;

type
  TRegexFlags = nextpas.core.regex.base.TRegexFlags;
  TMatch = nextpas.core.regex.base.TMatch;
  TMatchArray = nextpas.core.regex.base.TMatchArray;
  TGroup = nextpas.core.regex.base.TGroup;
  TReplaceFunc = nextpas.core.regex.base.TReplaceFunc;
  ERegexError = nextpas.core.regex.base.ERegexError;
  ERegexCompileError = nextpas.core.regex.base.ERegexCompileError;
  PRegexProgram = nextpas.core.regex.base.PRegexProgram;

  TRegexIter = record
  private
    FProgram: PRegexProgram;
    FInput: string;
    FPos: SizeUInt;
    FDone: Boolean;
  public
    function Next(out AMatch: TMatch): Boolean;
  end;

  TRegex = record
  private
    FProgram: TRegexProgram;
    FTeddy: TTeddyMatcher;
    FValid: Boolean;
  public
    class function Compile(const APattern: string): TRegex; static;
    class function Compile(const APattern: string; AFlags: TRegexFlags): TRegex; static;
    class function TryCompile(const APattern: string; out ARegex: TRegex; out AError: string): Boolean; static;

    function IsMatch(const AInput: string): Boolean;
    function Find(const AInput: string): TMatch;
    function FindAt(const AInput: string; AStartPos: SizeUInt): TMatch;
    function FindAll(const AInput: string; AMaxMatches: SizeInt = -1): TMatchArray;
    function FindIter(const AInput: string): TRegexIter;
    function IsFullMatch(const AInput: string): Boolean;
    function ReplaceFirst(const AInput, AReplacement: string): string;
    function ReplaceAll(const AInput, AReplacement: string): string;
    function ReplaceFirstFunc(const AInput: string; AFunc: TReplaceFunc): string;
    function ReplaceAllFunc(const AInput: string; AFunc: TReplaceFunc): string;
    function ReplaceAllExpand(const AInput, ATemplate: string): string;
    function Split(const AInput: string; AMaxSplits: SizeInt = -1): TStringArray;
    function GroupByName(const AMatch: TMatch; const AName: string): TGroup;
    function GroupIndexByName(const AName: string): SizeInt;
    function SubexpNames: TStringArray;
    function NumCaptures: UInt32;
  end;

function RegexIsMatch(const APattern, AInput: string): Boolean;
function RegexFind(const APattern, AInput: string): TMatch;
function RegexFindAll(const APattern, AInput: string; AMaxMatches: SizeInt = -1): TMatchArray;
function RegexReplaceAll(const APattern, AInput, AReplacement: string): string;
function RegexSplit(const APattern, AInput: string): TStringArray;
function RegexQuoteMeta(const AStr: string): string;

implementation

{ TRegex }

class function TRegex.Compile(const APattern: string): TRegex;
var
  LAst: PAstNode;
  LNumCaptures: UInt32;
  LFlags: TRegexFlags;
begin
  Result.FProgram.Code := nil;
  Result.FProgram.Classes := nil;
  Result.FProgram.LiteralPrefix := '';
  Result.FProgram.LiteralPrefixLen := 0;
  Result.FProgram.NumSlots := 0;
  Result.FValid := False;
  Result.FTeddy.PatternCount := 0;
  LAst := nil;
  try
    LAst := RegexParse(APattern, LNumCaptures, LFlags);
    Result.FProgram := RegexCompile(LAst, LNumCaptures, LFlags);
    Result.FValid := True;
    if Result.FProgram.IsLiteralAlt and
       (Length(Result.FProgram.LiteralAltPatterns) <= 8) then
      Result.FTeddy := TeddyBuild(Result.FProgram.LiteralAltPatterns,
        Length(Result.FProgram.LiteralAltPatterns));
  finally
    RegexFreeAst(LAst);
  end;
end;

class function TRegex.Compile(const APattern: string; AFlags: TRegexFlags): TRegex;
var
  LAst: PAstNode;
  LNumCaptures: UInt32;
  LFlags: TRegexFlags;
begin
  Result.FProgram.Code := nil;
  Result.FProgram.Classes := nil;
  Result.FProgram.LiteralPrefix := '';
  Result.FProgram.LiteralPrefixLen := 0;
  Result.FProgram.NumSlots := 0;
  Result.FValid := False;
  Result.FTeddy.PatternCount := 0;
  LAst := nil;
  try
    LAst := RegexParse(APattern, LNumCaptures, LFlags);
    LFlags := LFlags + AFlags;
    Result.FProgram := RegexCompile(LAst, LNumCaptures, LFlags);
    Result.FValid := True;
    if Result.FProgram.IsLiteralAlt and
       (Length(Result.FProgram.LiteralAltPatterns) <= 8) then
      Result.FTeddy := TeddyBuild(Result.FProgram.LiteralAltPatterns,
        Length(Result.FProgram.LiteralAltPatterns));
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
var i: Integer;
    LPos: SizeUInt;
    LNeedleLen: SizeUInt;
    LNeedle: PAnsiChar;
    LInputLen: SizeUInt;
    LData: PAnsiChar;
    LMatch: Boolean;
    k: SizeUInt;
    LCh: Byte;
    LLower: array of AnsiChar;
begin
  if not FValid then Exit(False);
  if FProgram.IsPureLiteral then
  begin
    if FProgram.LiteralPrefixLen = 0 then
      Exit(True);
    Exit(ScanFindSubstring(PAnsiChar(AInput), Length(AInput),
      PAnsiChar(FProgram.LiteralPrefix), FProgram.LiteralPrefixLen) >= 0);
  end;
  if FProgram.IsLiteralAlt then
  begin
    if FTeddy.PatternCount > 0 then
      Exit(TeddyIsMatch(FTeddy, PAnsiChar(AInput), Length(AInput)));
    for i := 0 to High(FProgram.LiteralAltPatterns) do
      if ScanFindSubstring(PAnsiChar(AInput), Length(AInput),
           PAnsiChar(FProgram.LiteralAltPatterns[i]),
           Length(FProgram.LiteralAltPatterns[i])) >= 0 then
        Exit(True);
    Exit(False);
  end;
  if FProgram.IsCaseFoldLiteral then
  begin
    LNeedle := PAnsiChar(FProgram.CaseFoldLiteral);
    LNeedleLen := Length(FProgram.CaseFoldLiteral);
    LData := PAnsiChar(AInput);
    LInputLen := Length(AInput);
    if LNeedleLen > LInputLen then Exit(False);
    // SIMD case-insensitive: search first+last byte (both cases) then verify
    LPos := 0;
    while LPos + LNeedleLen <= LInputLen do
    begin
      i := ScanFindSubstringCI(@LData[LPos], LInputLen - LPos, LNeedle, LNeedleLen);
      if i < 0 then Exit(False);
      Exit(True);
    end;
    Exit(False);
  end;
  Result := DfaIsMatch(FProgram, PAnsiChar(AInput), Length(AInput));
end;

function TRegex.Find(const AInput: string): TMatch;
var LPos: SizeInt;
begin
  if not FValid then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    Exit;
  end;
  if FProgram.IsPureLiteral then
  begin
    if FProgram.LiteralPrefixLen = 0 then
    begin
      Result.Start := 0; Result.Len := 0; Result.Groups := nil;
      Exit;
    end;
    LPos := ScanFindSubstring(PAnsiChar(AInput), Length(AInput),
      PAnsiChar(FProgram.LiteralPrefix), FProgram.LiteralPrefixLen);
    if LPos >= 0 then
    begin
      Result.Start := LPos;
      Result.Len := SizeInt(FProgram.LiteralPrefixLen);
      Result.Groups := nil;
    end
    else
    begin
      Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    end;
    Exit;
  end;
  if not NfaSearch(FProgram, PAnsiChar(AInput), Length(AInput), False, 0, Result) then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
  end;
end;

function TRegex.FindAt(const AInput: string; AStartPos: SizeUInt): TMatch;
var LPos: SizeInt;
begin
  if not FValid then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    Exit;
  end;
  if FProgram.IsPureLiteral then
  begin
    if AStartPos > SizeUInt(Length(AInput)) then
    begin
      Result.Start := -1; Result.Len := 0; Result.Groups := nil;
      Exit;
    end;
    if FProgram.LiteralPrefixLen = 0 then
    begin
      Result.Start := SizeInt(AStartPos); Result.Len := 0; Result.Groups := nil;
      Exit;
    end;
    LPos := ScanFindSubstring(PAnsiChar(AInput) + AStartPos,
              SizeUInt(Length(AInput)) - AStartPos,
              PAnsiChar(FProgram.LiteralPrefix), FProgram.LiteralPrefixLen);
    if LPos >= 0 then
    begin
      Result.Start := SizeInt(AStartPos) + LPos;
      Result.Len := SizeInt(FProgram.LiteralPrefixLen);
      Result.Groups := nil;
    end else begin
      Result.Start := -1; Result.Len := 0; Result.Groups := nil;
    end;
    Exit;
  end;
  if not NfaSearch(FProgram, PAnsiChar(AInput), Length(AInput), False, AStartPos, Result) then
  begin
    Result.Start := -1; Result.Len := 0; Result.Groups := nil;
  end;
end;

function TRegex.IsFullMatch(const AInput: string): Boolean;
begin
  if not FValid then Exit(False);
  if FProgram.IsPureLiteral then
    Exit(AInput = FProgram.LiteralPrefix);
  // DFA handles all patterns; falls back to NFA on overflow
  Result := DfaIsFullMatch(FProgram, PAnsiChar(AInput), Length(AInput));
end;

function TRegex.FindAll(const AInput: string; AMaxMatches: SizeInt): TMatchArray;
var
  LPos, LStart: SizeInt;
  LCount: SizeUInt;
  LPrefixLen: SizeInt;
  LFound: PtrInt;
begin
  Result := nil;
  if not FValid then begin SetLength(Result, 0); Exit; end;
  if AMaxMatches = 0 then begin SetLength(Result, 0); Exit; end;
  if FProgram.IsPureLiteral then
  begin
    LPrefixLen := SizeInt(FProgram.LiteralPrefixLen);
    if LPrefixLen = 0 then
    begin
      if (AMaxMatches > 0) and (AMaxMatches < SizeInt(Length(AInput)) + 1) then
        SetLength(Result, AMaxMatches)
      else
        SetLength(Result, Length(AInput) + 1);
      for LPos := 0 to High(Result) do
      begin
        Result[LPos].Start := LPos;
        Result[LPos].Len := 0;
        Result[LPos].Groups := nil;
      end;
      Exit;
    end;
    SetLength(Result, 0);
    LCount := 0;
    LStart := 0;
    while LStart <= SizeInt(Length(AInput)) - LPrefixLen do
    begin
      if (AMaxMatches > 0) and (SizeInt(LCount) >= AMaxMatches) then Break;
      LFound := ScanFindSubstring(@PAnsiChar(AInput)[LStart],
        SizeUInt(Length(AInput)) - SizeUInt(LStart),
        PAnsiChar(FProgram.LiteralPrefix), SizeUInt(LPrefixLen));
      if LFound < 0 then Break;
      if LCount >= SizeUInt(Length(Result)) then
        SetLength(Result, LCount + 32);
      Result[LCount].Start := LStart + SizeInt(LFound);
      Result[LCount].Len := LPrefixLen;
      Result[LCount].Groups := nil;
      Inc(LCount);
      LStart := LStart + SizeInt(LFound) + LPrefixLen;
    end;
    SetLength(Result, LCount);
    Exit;
  end;
  if FProgram.NumCaptures = 0 then
  begin
    Result := DfaFindAll(FProgram, PAnsiChar(AInput), Length(AInput), AMaxMatches);
    Exit;
  end;
  Result := NfaFindAll(FProgram, PAnsiChar(AInput), Length(AInput), AMaxMatches);
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
  Result := Result + Copy(AInput, LPos, Length(AInput) - SizeInt(LPos) + 1);
end;

function TRegex.ReplaceFirstFunc(const AInput: string; AFunc: TReplaceFunc): string;
var LMatch: TMatch;
begin
  LMatch := Find(AInput);
  if not LMatch.Found then Exit(AInput);
  Result := Copy(AInput, 1, LMatch.Start) + AFunc(AInput, LMatch) +
            Copy(AInput, LMatch.Start + LMatch.Len + 1, Length(AInput));
end;

function TRegex.ReplaceAllFunc(const AInput: string; AFunc: TReplaceFunc): string;
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
    Result := Result + AFunc(AInput, LMatches[i]);
    LPos := SizeUInt(LMatches[i].Start + LMatches[i].Len + 1);
  end;
  Result := Result + Copy(AInput, LPos, Length(AInput) - SizeInt(LPos) + 1);
end;

function TRegex.ReplaceAllExpand(const AInput, ATemplate: string): string;
var
  LMatches: TMatchArray;
  i: SizeInt;
  LPos: SizeUInt;

  function ExpandTemplate(const AMatch: TMatch): string;
  var
    j: SizeInt;
    LTplLen: SizeInt;
    LIdx: SizeInt;
    LName: string;
  begin
    Result := '';
    LTplLen := Length(ATemplate);
    j := 1;
    while j <= LTplLen do
    begin
      if (ATemplate[j] = '$') and (j < LTplLen) then
      begin
        Inc(j);
        if ATemplate[j] = '$' then
        begin
          Result := Result + '$';
          Inc(j);
        end
        else if ATemplate[j] = '0' then
        begin
          Result := Result + AMatch.Value(AInput);
          Inc(j);
        end
        else if (ATemplate[j] >= '1') and (ATemplate[j] <= '9') then
        begin
          LIdx := Ord(ATemplate[j]) - Ord('1');
          if (LIdx >= 0) and (LIdx < Length(AMatch.Groups)) and AMatch.Groups[LIdx].Found then
            Result := Result + AMatch.Groups[LIdx].Value(AInput);
          Inc(j);
        end
        else if (ATemplate[j] = '{') then
        begin
          Inc(j);
          LName := '';
          while (j <= LTplLen) and (ATemplate[j] <> '}') do
          begin
            LName := LName + ATemplate[j];
            Inc(j);
          end;
          if (j <= LTplLen) and (ATemplate[j] = '}') then
          begin
            Inc(j);
            LIdx := GroupIndexByName(LName);
            if (LIdx >= 0) and (LIdx < Length(AMatch.Groups)) and AMatch.Groups[LIdx].Found then
              Result := Result + AMatch.Groups[LIdx].Value(AInput);
          end
          else
            Result := Result + '${' + LName;
        end
        else
        begin
          Result := Result + '$' + ATemplate[j];
          Inc(j);
        end;
      end
      else
      begin
        Result := Result + ATemplate[j];
        Inc(j);
      end;
    end;
  end;

begin
  LMatches := FindAll(AInput);
  if Length(LMatches) = 0 then Exit(AInput);

  Result := '';
  LPos := 1;
  for i := 0 to High(LMatches) do
  begin
    Result := Result + Copy(AInput, LPos, SizeUInt(LMatches[i].Start + 1) - LPos);
    Result := Result + ExpandTemplate(LMatches[i]);
    LPos := SizeUInt(LMatches[i].Start + LMatches[i].Len + 1);
  end;
  Result := Result + Copy(AInput, LPos, Length(AInput) - SizeInt(LPos) + 1);
end;

function TRegex.Split(const AInput: string; AMaxSplits: SizeInt = -1): TStringArray;
var
  LMatches: TMatchArray;
  i: SizeInt;
  LPos: SizeUInt;
  LCount: SizeInt;
  LLimit: SizeInt;
begin
  Result := nil;
  LMatches := FindAll(AInput);
  if (Length(LMatches) = 0) or (AMaxSplits = 0) then
  begin
    SetLength(Result, 1);
    Result[0] := AInput;
    Exit;
  end;

  if AMaxSplits > 0 then
    LLimit := AMaxSplits
  else
    LLimit := Length(LMatches);

  if LLimit > Length(LMatches) then
    LLimit := Length(LMatches);

  SetLength(Result, LLimit + 1);
  LPos := 1;
  LCount := 0;
  for i := 0 to LLimit - 1 do
  begin
    Result[LCount] := Copy(AInput, LPos, SizeUInt(LMatches[i].Start + 1) - LPos);
    LPos := SizeUInt(LMatches[i].Start + LMatches[i].Len + 1);
    Inc(LCount);
  end;
  Result[LCount] := Copy(AInput, LPos, Length(AInput) - SizeInt(LPos) + 1);
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

function TRegex.FindIter(const AInput: string): TRegexIter;
begin
  Result.FProgram := @FProgram;
  Result.FInput := AInput;
  Result.FPos := 0;
  Result.FDone := not FValid;
end;

function TRegex.SubexpNames: TStringArray;
var LI: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(FProgram.GroupNames));
  for LI := 0 to High(FProgram.GroupNames) do
    Result[LI] := FProgram.GroupNames[LI].Name;
end;

{ TRegexIter }

function TRegexIter.Next(out AMatch: TMatch): Boolean;
var LLen: SizeUInt;
begin
  if FDone then
  begin
    AMatch.Start := -1; AMatch.Len := 0; AMatch.Groups := nil;
    Exit(False);
  end;
  LLen := SizeUInt(Length(FInput));
  if not NfaSearch(FProgram^, PAnsiChar(FInput), LLen, False, FPos, AMatch) then
  begin
    AMatch.Start := -1; AMatch.Len := 0; AMatch.Groups := nil;
    FDone := True;
    Exit(False);
  end;
  if AMatch.Len = 0 then
  begin
    if FPos >= LLen then begin FDone := True; Exit(True); end;
    FPos := SizeUInt(AMatch.Start) + 1;
  end
  else
    FPos := SizeUInt(AMatch.Start) + SizeUInt(AMatch.Len);
  Result := True;
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

function RegexFindAll(const APattern, AInput: string; AMaxMatches: SizeInt = -1): TMatchArray;
var R: TRegex;
begin
  R := TRegex.Compile(APattern);
  Result := R.FindAll(AInput, AMaxMatches);
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

function RegexQuoteMeta(const AStr: string): string;
const
  MetaChars = '\.+*?()[]{}|^$';
var
  i: SizeInt;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(AStr) do
  begin
    ch := AStr[i];
    if Pos(ch, MetaChars) > 0 then
      Result := Result + '\';
    Result := Result + ch;
  end;
end;

end.
