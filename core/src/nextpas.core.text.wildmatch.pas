unit nextpas.core.text.wildmatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single-source wildmatch for generic use (gitignore / gitattributes / fs / http / tui).

  - '*'  matches any sequence except '/'
  - '?'  matches one char except '/'
  - '**' as whole segment matches zero or more whole directories
  - '[...]' supports ranges and '!'/'^' negation; '\' escapes next char
  - '\' escapes next pattern char

  Owner: L1 text (re-usable via bytes.ops single source, inline hot path, zero-copy range scan).
  Former git shim `nextpas.core.git.native.wildmatch` has been removed; this L1 owner
  is the single source (WildSegment/WildSegmentRange/WildSegmentsMatch/HasUnescapedSlash
  via bytes.ops GrowArrayCapacity, inline, zero-copy range scan, no alloc). }

function WildSegment(const APattern, AName: string): Boolean; inline;
function WildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline;
function WildSegmentsMatch(const APattern, APath: string): Boolean;
function HasUnescapedSlash(const AValue: string): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

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

function HasUnescapedSlash(const AValue: string): Boolean;
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

function WildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
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

function WildSegment(const APattern, AName: string): Boolean;
begin
  Result := WildSegmentRange(APattern, 1, Length(APattern), AName, 1, Length(AName));
end;

function WildSegmentsMatch(const APattern, APath: string): Boolean;

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

var
  PatStarts, PatLens: array of Integer;
  PatIsStar: array of Boolean;
  PathStarts, PathLens: array of Integer;
  P, Q, PLen: Integer;
  PatCnt, PathCnt: Integer;
  PatCap, PathCap: SizeUInt;
  LNewCap: SizeUInt;
  I, J, StarIdx, MatchIdx, Iter: Integer;
  Guard: Int64;
begin
  if (APattern = '') and (APath = '') then
    Exit(True);
  if APattern = '' then
    Exit(False);
  // zero-copy segment scan: build start/len views, inline helpers, no segment string alloc
  PatCnt := 0;
  PathCnt := 0;
  PatCap := 0;
  PathCap := 0;
  SetLength(PatStarts, 0);
  SetLength(PatLens, 0);
  SetLength(PatIsStar, 0);
  SetLength(PathStarts, 0);
  SetLength(PathLens, 0);
  P := 1;
  while True do
  begin
    P := SkipSlashes(APattern, P);
    if P > Length(APattern) then
      Break;
    Q := NextSegEnd(APattern, P);
    PLen := Q - P + 1;
    // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), inline, O(1) amortized per segment, avoids O(n²) SetLength(Length+1) churn, zero-copy start/len views
    if SizeUInt(PatCnt) >= PatCap then
    begin
      LNewCap := GrowArrayCapacity(PatCap, SizeUInt(PatCnt + 1));
      PatCap := LNewCap;
      SetLength(PatStarts, PatCap);
      SetLength(PatLens, PatCap);
      SetLength(PatIsStar, PatCap);
    end;
    PatStarts[PatCnt] := P;
    PatLens[PatCnt] := PLen;
    PatIsStar[PatCnt] := (PLen = 2) and (APattern[P] = '*') and (APattern[P + 1] = '*');
    Inc(PatCnt);
    P := Q + 1;
  end;
  // single shrink to exact after geometric growth (bytes.ops discipline)
  if SizeUInt(Length(PatStarts)) <> SizeUInt(PatCnt) then
  begin
    SetLength(PatStarts, PatCnt);
    SetLength(PatLens, PatCnt);
    SetLength(PatIsStar, PatCnt);
  end;
  P := 1;
  while True do
  begin
    P := SkipSlashes(APath, P);
    if P > Length(APath) then
      Break;
    Q := NextSegEnd(APath, P);
    PLen := Q - P + 1;
    // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source, O(1) amortized per segment, zero-copy views
    if SizeUInt(PathCnt) >= PathCap then
    begin
      LNewCap := GrowArrayCapacity(PathCap, SizeUInt(PathCnt + 1));
      PathCap := LNewCap;
      SetLength(PathStarts, PathCap);
      SetLength(PathLens, PathCap);
    end;
    PathStarts[PathCnt] := P;
    PathLens[PathCnt] := PLen;
    Inc(PathCnt);
    P := Q + 1;
  end;
  if SizeUInt(Length(PathStarts)) <> SizeUInt(PathCnt) then
  begin
    SetLength(PathStarts, PathCnt);
    SetLength(PathLens, PathCnt);
  end;
  // linear star backtracking: ** matches zero or more whole segments, O(n*m) bounded, no recursion
  I := 0;
  J := 0;
  StarIdx := -1;
  MatchIdx := 0;
  Guard := Int64(PatCnt + 1) * Int64(PathCnt + 1) * 4 + 16;
  Iter := 0;
  while J < PathCnt do
  begin
    Inc(Iter);
    if Iter > Guard then
      Exit(False);
    if (I < PatCnt) and PatIsStar[I] then
    begin
      StarIdx := I;
      MatchIdx := J;
      Inc(I);
    end
    else if (I < PatCnt) and WildSegmentRange(APattern, PatStarts[I], PatLens[I], APath, PathStarts[J], PathLens[J]) then
    begin
      Inc(I);
      Inc(J);
    end
    else if StarIdx <> -1 then
    begin
      Inc(MatchIdx);
      if MatchIdx > PathCnt then
        Exit(False);
      J := MatchIdx;
      I := StarIdx + 1;
    end
    else
      Exit(False);
  end;
  while (I < PatCnt) and PatIsStar[I] do
    Inc(I);
  Result := I = PatCnt;
end;

end.
