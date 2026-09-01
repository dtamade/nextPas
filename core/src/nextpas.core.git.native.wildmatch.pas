unit nextpas.core.git.native.wildmatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single-source wildmatch for gitignore / gitattributes.

  - '*'  matches any sequence except '/'
  - '?'  matches one char except '/'
  - '**' as whole segment matches zero or more whole directories
  - '[...]' supports ranges and '!'/'^' negation; '\' escapes next char
  - '\' escapes next pattern char

  Zero SysUtils, zero libgit2, inline hot path, zero-copy range scan. }

function GitWildSegment(const APattern, AName: string): Boolean; inline;
function GitWildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline;
function GitSegmentsMatch(const APattern, APath: string): Boolean;
function GitHasUnescapedSlash(const AValue: string): Boolean; inline;

implementation

function OpensClass(const AValue: string; APos: Integer): Boolean; inline;
var
  I: Integer;
begin
  Result := False;
  I := APos + 1;
  if (I <= Length(AValue)) and ((AValue[I] = '!') or (AValue[I] = '^')) then
    Inc(I);
  while I <= Length(AValue) do
  begin
    if AValue[I] = ']' then
      Exit(True);
    if AValue[I] = '\' then
      Inc(I);
    Inc(I);
  end;
end;

function GitHasUnescapedSlash(const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := 1;
  while I <= Length(AValue) do
  begin
    if AValue[I] = '\' then
      Inc(I, 2)
    else
    begin
      if AValue[I] = '/' then
        Exit(True);
      Inc(I);
    end;
  end;
end;

function GitWildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline;
var
  P, S, StarP, StarS: Integer;
  PEnd, SEnd: Integer;
  HaveStar, Advanced, Matched: Boolean;

  function PatChar(AIdx: Integer): Char; inline;
  begin
    Result := APattern[AIdx];
  end;

  function NameChar(AIdx: Integer): Char; inline;
  begin
    Result := AName[AIdx];
  end;

  function ConsumeClass(var APos: Integer; const ACh: Char): Boolean;
  var
    Negate, InFirst: Boolean;
    Lo, Hi: Char;
  begin
    Inc(APos);
    Negate := False;
    if (APos <= PEnd) and ((PatChar(APos) = '!') or (PatChar(APos) = '^')) then
    begin
      Negate := True;
      Inc(APos);
    end;
    Result := False;
    InFirst := True;
    while APos <= PEnd do
    begin
      if (PatChar(APos) = ']') and not InFirst then
      begin
        Inc(APos);
        Break;
      end;
      InFirst := False;
      if (PatChar(APos) = '\') and (APos < PEnd) then
        Inc(APos);
      if (APos + 2 <= PEnd) and (PatChar(APos + 1) = '-') and (PatChar(APos + 2) <> ']') then
      begin
        Lo := PatChar(APos);
        Hi := PatChar(APos + 2);
        Inc(APos, 3);
        if (ACh >= Lo) and (ACh <= Hi) then
          Result := True;
      end
      else
      begin
        if ACh = PatChar(APos) then
          Result := True;
        Inc(APos);
      end;
    end;
    if Negate then
      Result := not Result;
  end;

  function OpensClassRange(APos: Integer): Boolean; inline;
  var
    I: Integer;
  begin
    Result := False;
    I := APos + 1;
    if (I <= PEnd) and ((PatChar(I) = '!') or (PatChar(I) = '^')) then
      Inc(I);
    while I <= PEnd do
    begin
      if PatChar(I) = ']' then
        Exit(True);
      if PatChar(I) = '\' then
        Inc(I);
      Inc(I);
    end;
  end;

begin
  Result := False;
  PEnd := APatPos + APatLen - 1;
  SEnd := ANamePos + ANameLen - 1;
  if (APatLen = 0) and (ANameLen = 0) then
    Exit(True);
  if (APatLen = 0) or (ANameLen = 0) and (APatLen <> 0) then
  begin
    { let loop handle star cases; empty name vs non-empty pattern }
  end;
  P := APatPos;
  S := ANamePos;
  StarP := 0;
  StarS := 0;
  HaveStar := False;
  while S <= SEnd do
  begin
    Advanced := False;
    if P <= PEnd then
    begin
      case PatChar(P) of
        '\':
          if P < PEnd then
          begin
            Inc(P);
            if PatChar(P) = NameChar(S) then
            begin
              Inc(P);
              Inc(S);
              Advanced := True;
            end;
          end;
        '?':
          begin
            Inc(P);
            Inc(S);
            Advanced := True;
          end;
        '*':
          begin
            HaveStar := True;
            StarP := P;
            StarS := S;
            Inc(P);
            Advanced := True;
          end;
        '[':
          if OpensClassRange(P) then
          begin
            Matched := ConsumeClass(P, NameChar(S));
            if Matched then
            begin
              Inc(S);
              Advanced := True;
            end;
          end
          else if NameChar(S) = '[' then
          begin
            Inc(P);
            Inc(S);
            Advanced := True;
          end;
      else
        if PatChar(P) = NameChar(S) then
        begin
          Inc(P);
          Inc(S);
          Advanced := True;
        end;
      end;
    end;
    if not Advanced then
    begin
      if HaveStar and (StarS <= SEnd) then
      begin
        Inc(StarS);
        S := StarS;
        P := StarP + 1;
      end
      else
        Exit(False);
    end;
  end;
  while (P <= PEnd) and (PatChar(P) = '*') do
    Inc(P);
  Result := P > PEnd;
end;

function GitWildSegment(const APattern, AName: string): Boolean;
begin
  Result := GitWildSegmentRange(APattern, 1, Length(APattern), AName, 1, Length(AName));
end;

function GitSegmentsMatch(const APattern, APath: string): Boolean;

  function SkipSlashes(const S: string; Pos: Integer): Integer; inline;
  begin
    Result := Pos;
    while (Result <= Length(S)) and (S[Result] = '/') do
      Inc(Result);
  end;

  function NextSegEnd(const S: string; Start: Integer): Integer; inline;
  begin
    Result := Start;
    while (Result <= Length(S)) and (S[Result] <> '/') do
      Inc(Result);
    Dec(Result);
  end;

  function Rec(PPat, PStr: Integer): Boolean;
  var
    PatEnd, StrEnd: Integer;
    J: Integer;
  begin
    PPat := SkipSlashes(APattern, PPat);
    PStr := SkipSlashes(APath, PStr);
    if PPat > Length(APattern) then
      Exit(PStr > Length(APath));
    PatEnd := NextSegEnd(APattern, PPat);
    if (PatEnd - PPat = 1) and (APattern[PPat] = '*') and (APattern[PPat + 1] = '*') then
    begin
      if Rec(PatEnd + 2, PStr) then
        Exit(True);
      J := PStr;
      while J <= Length(APath) do
      begin
        StrEnd := NextSegEnd(APath, J);
        J := StrEnd + 2;
        J := SkipSlashes(APath, J);
        if Rec(PatEnd + 2, J) then
          Exit(True);
        if J > Length(APath) then
          Break;
      end;
      Exit(False);
    end;
    if PStr > Length(APath) then
      Exit(False);
    StrEnd := NextSegEnd(APath, PStr);
    if not GitWildSegmentRange(APattern, PPat, PatEnd - PPat + 1, APath, PStr, StrEnd - PStr + 1) then
      Exit(False);
    Result := Rec(PatEnd + 2, StrEnd + 2);
  end;

begin
  if (APattern = '') and (APath = '') then
    Exit(True);
  if APattern = '' then
    Exit(False);
  Result := Rec(1, 1);
end;

end.
