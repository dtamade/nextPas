unit nextpas.core.git.native.wildmatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single source for git wildmatch semantics (wildmatch.c / gitignore(5)).
  Ignore and attributes both delegate here — no duplicated loops.

  - '*' and '?' never cross '/'; '[...]' supports ranges and '^'/'!' negation;
    '\' escapes next pattern character; '**' matches zero or more whole
    directories (consumed per segment by GitSegmentsMatch).
  - Inline hot path, zero-copy via const string params (no allocation, direct
    index scan). PByte+Len view would be identical cost; string is already
    zero-copy when passed by const. Reuses no adler32/bytes.ops loops —
    pure char scan single-sourced here. }

function GitWildSegment(const APattern, AName: string): Boolean; inline;
function GitSegmentsMatch(const APattern, APath: string): Boolean; inline;

implementation

{ splits on '/', dropping empty pieces (leading/trailing/doubled) — inline helper,
  shared single source for segment matching }
function SplitSegments(const AValue: string): TStringArray; inline;
var
  Start, I: Integer;
begin
  Result := nil;
  Start := 1;
  for I := 1 to Length(AValue) do
    if AValue[I] = '/' then
    begin
      if I > Start then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Copy(AValue, Start, I - Start);
      end;
      Start := I + 1;
    end;
  if Length(AValue) >= Start then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Copy(AValue, Start, MaxInt);
  end;
end;

{ true when APos opens a well-formed '[...]': a closing bracket exists
  beyond the optional negation marker — inline, zero-copy scan }
function OpensClass(const AValue: string; APos: Integer): Boolean; inline;
var
  I: Integer;
begin
  Result := False;
  I := APos + 1;
  if (I <= Length(AValue))
    and ((AValue[I] = '!') or (AValue[I] = '^')) then
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

{ single-segment wildcard match: '*', '?' and classes stay inside the
  segment because neither input contains '/' — inline hot path, zero-copy }
function GitWildSegment(const APattern, AName: string): Boolean; inline;
var
  P, S, StarP, StarS: Integer;
  HaveStar, Advanced, Matched: Boolean;

  function ConsumeClass(var APos: Integer; const ACh: Char): Boolean; inline;
  var
    Negate, InFirst: Boolean;
    Lo, Hi: Char;
  begin
    Inc(APos); // past '['
    Negate := False;
    if (APos <= Length(APattern))
      and ((APattern[APos] = '!') or (APattern[APos] = '^')) then
    begin
      Negate := True;
      Inc(APos);
    end;
    Result := False;
    InFirst := True;
    while APos <= Length(APattern) do
    begin
      if (APattern[APos] = ']') and not InFirst then
      begin
        Inc(APos);
        Break;
      end;
      InFirst := False;
      if (APattern[APos] = '\') and (APos < Length(APattern)) then
        Inc(APos);
      if (APos + 2 <= Length(APattern)) and (APattern[APos + 1] = '-')
        and (APattern[APos + 2] <> ']') then
      begin
        Lo := APattern[APos];
        Hi := APattern[APos + 2];
        Inc(APos, 3);
        if (ACh >= Lo) and (ACh <= Hi) then
          Result := True;
      end
      else
      begin
        if ACh = APattern[APos] then
          Result := True;
        Inc(APos);
      end;
    end;
    if Negate then
      Result := not Result;
  end;

begin
  Result := False;
  P := 1;
  S := 1;
  StarP := 0;
  StarS := 0;
  HaveStar := False;
  while S <= Length(AName) do
  begin
    Advanced := False;
    if P <= Length(APattern) then
    begin
      case APattern[P] of
        '\':
          if P < Length(APattern) then
          begin
            Inc(P);
            if APattern[P] = AName[S] then
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
          if OpensClass(APattern, P) then
          begin
            Matched := ConsumeClass(P, AName[S]);
            if Matched then
            begin
              Inc(S);
              Advanced := True;
            end;
          end
          else if AName[S] = '[' then
          begin
            Inc(P);
            Inc(S);
            Advanced := True;
          end;
      else
        if APattern[P] = AName[S] then
        begin
          Inc(P);
          Inc(S);
          Advanced := True;
        end;
      end;
    end;
    if not Advanced then
    begin
      // mismatch: let the pending '*' absorb one more character; the
      // guard allows absorbing up to and including the last one so the
      // "star consumed everything" state is reachable on retry
      if HaveStar and (StarS <= Length(AName)) then
      begin
        Inc(StarS);
        S := StarS;
        P := StarP + 1;
      end
      else
        Exit(False);
    end;
  end;
  while (P <= Length(APattern)) and (APattern[P] = '*') do
    Inc(P);
  Result := P > Length(APattern);
end;

{ anchored match with '**' consuming zero or more whole segments — inline,
  delegates per-segment to GitWildSegment (single source) }
function GitSegmentsMatch(const APattern, APath: string): Boolean; inline;
var
  PSegs, PPathSegs: TStringArray;

  function Rec(AI, AJ: Integer): Boolean; inline;
  var
    J: Integer;
  begin
    Result := False;
    if AI > High(PSegs) then
      Exit(AJ > High(PPathSegs));
    if PSegs[AI] = '**' then
    begin
      for J := AJ to High(PPathSegs) + 1 do
        if Rec(AI + 1, J) then
          Exit(True);
      Exit(False);
    end;
    if AJ > High(PPathSegs) then
      Exit(False);
    if not GitWildSegment(PSegs[AI], PPathSegs[AJ]) then
      Exit(False);
    Result := Rec(AI + 1, AJ + 1);
  end;

begin
  PSegs := SplitSegments(APattern);
  PPathSegs := SplitSegments(APath);
  Result := Rec(0, 0);
end;

end.
