unit nextpas.core.git.native.trailer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.util;

{ Trailer subfamily: `git interpret-trailers` Key: Value at message tail.

  Parses the trailer block at the end of a commit message (after the last
  blank line, contiguous `Key: Value` lines). `Key` is trimmed, `Value`
  trimmed; lines without `:` are not trailers. Case-insensitive key search
  preserves original casing in output. }

type
  TGitTrailer = record
    Key: string;
    Value: string;
  end;
  TGitTrailerArray = array of TGitTrailer;

function GitParseTrailers(const AMessage: string): TGitTrailerArray;
function GitFindTrailer(const ATrailers: TGitTrailerArray; const AKey: string): string;
function GitHasTrailer(const ATrailers: TGitTrailerArray; const AKey: string): Boolean;
function GitFormatTrailer(const AKey, AValue: string): string;
function GitFormatTrailers(const ATrailers: TGitTrailerArray): string;
function GitAppendTrailer(const AMessage, AKey, AValue: string): string;

implementation

function TrimSpaces(const S: string): string; inline;
begin Result:=GitTrimSpaces(S); end;

function StripCR(const S: string): string; inline;
begin Result:=GitStripCR(S); end;

function IsTrailerLine(const ALine: string; out AKey, AValue: string): Boolean;
var P: Integer; K,V: string;
begin
  AKey:=''; AValue:='';
  // trailer line: Key ':' Value, Key non-empty after trim, may contain [A-Za-z0-9-]
  P:=Pos(':', ALine);
  if P=0 then Exit(False);
  K:=TrimSpaces(Copy(ALine,1,P-1));
  V:=TrimSpaces(Copy(ALine,P+1,MaxInt));
  if K='' then Exit(False);
  // reject if key contains line break or empty value with no key? value may be empty (allowed)
  AKey:=K; AValue:=V;
  Result:=True;
end;

function GitParseTrailers(const AMessage: string): TGitTrailerArray;
var Lines: TStringArray; I, StartIdx, N: Integer; K,V: string; Tmp: TGitTrailerArray;
begin
  Result:=nil;
  if AMessage='' then Exit;
  Lines:=GitSplitLines(AMessage);
  // Strip trailing empty lines at end (message may end with newline)
  N:=Length(Lines);
  while (N>0) and (TrimSpaces(StripCR(Lines[N-1]))='') do Dec(N);
  SetLength(Lines, N);
  if N=0 then Exit;
  // Find trailer block: contiguous trailer lines at end.
  // Walk backwards collecting while trailer line; stop on non-trailer.
  // If we encounter a blank line before trailers, trailers are only those after blank.
  // But if no blank line, trailing trailers still count (git requires blank separator, but we are permissive: trailing contiguous trailers)
  Tmp:=nil;
  for I:=N-1 downto 0 do
  begin
    if TrimSpaces(StripCR(Lines[I]))='' then
    begin
      Break;
    end;
    if IsTrailerLine(StripCR(Lines[I]), K, V) then
    begin SetLength(Tmp, Length(Tmp)+1); Tmp[High(Tmp)].Key:=K; Tmp[High(Tmp)].Value:=V; end
    else Break;
  end;
  // Tmp currently reversed (from bottom up), reverse to preserve original order
  for I:=High(Tmp) downto 0 do
  begin SetLength(Result, Length(Result)+1); Result[High(Result)]:=Tmp[I]; end;
end;

function GitFindTrailer(const ATrailers: TGitTrailerArray; const AKey: string): string;
var I: Integer;
begin
  Result:='';
  for I:=0 to High(ATrailers) do
    if LowerCase(ATrailers[I].Key)=LowerCase(AKey) then Exit(ATrailers[I].Value);
end;

function GitHasTrailer(const ATrailers: TGitTrailerArray; const AKey: string): Boolean;
var I: Integer;
begin
  for I:=0 to High(ATrailers) do if LowerCase(ATrailers[I].Key)=LowerCase(AKey) then Exit(True);
  Result:=False;
end;

function GitFormatTrailer(const AKey, AValue: string): string;
begin
  Result:=TrimSpaces(AKey)+': '+TrimSpaces(AValue);
end;

function GitFormatTrailers(const ATrailers: TGitTrailerArray): string;
var I: Integer;
begin
  Result:='';
  for I:=0 to High(ATrailers) do
  begin
    if I>0 then Result:=Result+#10;
    Result:=Result+GitFormatTrailer(ATrailers[I].Key, ATrailers[I].Value);
  end;
end;

function GitAppendTrailer(const AMessage, AKey, AValue: string): string;
var Msg, Trailer: string; NeedsBlank: Boolean;
begin
  Trailer:=GitFormatTrailer(AKey, AValue);
  Msg:=AMessage;
  // Ensure message ends without trailing blank lines, then add trailer block
  while (Length(Msg)>0) and (Msg[Length(Msg)] in [#10,#13]) do Delete(Msg, Length(Msg),1);
  // Check if message already ends with trailer block or blank separation
  if Msg='' then Exit(Trailer+#10);
  // Need blank line before first trailer if none present
  // Detect if existing message already has trailer block: if last non-empty line is trailer, just append
  // Else need blank + trailer
  // For simplicity: if message contains a trailer block, append directly with newline; else blank line + trailer
  NeedsBlank:=True;
  // If last line is trailer, no extra blank needed beyond single newline
  // Heuristic: if GitParseTrailers finds trailers, we are already in block
  if Length(GitParseTrailers(Msg))>0 then NeedsBlank:=False;
  if NeedsBlank then Result:=Msg+#10#10+Trailer+#10
  else Result:=Msg+#10+Trailer+#10;
end;

end.
