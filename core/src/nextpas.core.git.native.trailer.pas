unit nextpas.core.git.native.trailer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

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

uses
  nextpas.core.bytes.ops,
  nextpas.core.git.native.util;

function IsTrailerLine(const ALine: string; out AKey, AValue: string): Boolean; inline;
var P: Integer; K,V: string;
begin
  AKey:=''; AValue:='';
  // trailer line: Key ':' Value, Key non-empty after trim, may contain [A-Za-z0-9-]
  P:=Pos(':', ALine);
  if P=0 then Exit(False);
  K:=GitTrimSpaces(Copy(ALine,1,P-1));
  V:=GitTrimSpaces(Copy(ALine,P+1,MaxInt));
  if K='' then Exit(False);
  // reject if key contains line break or empty value with no key? value may be empty (allowed)
  AKey:=K; AValue:=V;
  Result:=True;
end;

function GitParseTrailers(const AMessage: string): TGitTrailerArray;
var Lines: TStringArray; I, N: Integer; K,V: string;
  LCnt, LCap, LNewCap: SizeUInt;
  LTmp: TGitTrailer;
  J: Integer;
begin
  Result:=nil;
  if AMessage='' then Exit;
  Lines:=GitSplitLines(AMessage);
  // Strip trailing empty lines at end (message may end with newline)
  N:=Length(Lines);
  while (N>0) and (GitTrimSpaces(GitStripCR(Lines[N-1]))='') do Dec(N);
  SetLength(Lines, N);
  if N=0 then Exit;
  // Find trailer block: contiguous trailer lines at end.
  // Walk backwards collecting while trailer line; stop on non-trailer.
  // If we encounter a blank line before trailers, trailers are only those after blank.
  // But if no blank line, trailing trailers still count (git requires blank separator, but we are permissive: trailing contiguous trailers)
  // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), O(1) amortized, zero-copy Move, single shrink; reverse in-place avoids second allocation
  LCnt:=0; LCap:=0;
  SetLength(Result, 0);
  // use local Tmp then move to Result to keep reverse zero-copy; reuse Result as Tmp buffer to avoid extra variable
  // we grow Result directly as Tmp
  for I:=N-1 downto 0 do
  begin
    if GitTrimSpaces(GitStripCR(Lines[I]))='' then
      Break;
    if IsTrailerLine(GitStripCR(Lines[I]), K, V) then
    begin
      if LCnt >= LCap then
      begin
        LNewCap:=GrowArrayCapacity(LCap, LCnt+1);
        SetLength(Result, LNewCap);
        LCap:=LNewCap;
      end;
      Result[LCnt].Key:=K; Result[LCnt].Value:=V;
      Inc(LCnt);
    end
    else Break;
  end;
  if LCnt=0 then
  begin
    Result:=nil;
    Exit;
  end;
  SetLength(Result, LCnt);
  // Tmp currently reversed (from bottom up), reverse in-place zero-copy swap (no second array)
  for J:=0 to Integer(LCnt div 2)-1 do
  begin
    LTmp:=Result[J];
    Result[J]:=Result[Integer(LCnt)-1-J];
    Result[Integer(LCnt)-1-J]:=LTmp;
  end;
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

function GitFormatTrailer(const AKey, AValue: string): string; inline;
var L1,R1,L2,R2, LKeyLen, LValLen: Integer; LTotal: SizeUInt; LPos: SizeUInt;
begin
  // perf: single allocation zero-copy via PAnsiChar^ Move (bytes.ops single source, inline-safe: no indexed var for Move untyped param), inline kept small (trim loops + single alloc) avoids I-Cache bloat
  L1:=1; R1:=Length(AKey);
  while (L1<=R1) and (AKey[L1] <= ' ') do Inc(L1);
  while (R1>=L1) and (AKey[R1] <= ' ') do Dec(R1);
  L2:=1; R2:=Length(AValue);
  while (L2<=R2) and (AValue[L2] <= ' ') do Inc(L2);
  while (R2>=L2) and (AValue[R2] <= ' ') do Dec(R2);
  if L1>R1 then LKeyLen:=0 else LKeyLen:=R1-L1+1;
  if L2>R2 then LValLen:=0 else LValLen:=R2-L2+1;
  LTotal:=SizeUInt(LKeyLen) + 2 + SizeUInt(LValLen);
  SetLength(Result, LTotal);
  if LTotal=0 then Exit;
  LPos:=1;
  if LKeyLen>0 then begin Move((PAnsiChar(Pointer(AKey)) + L1 - 1)^, (PAnsiChar(Pointer(Result)) + LPos - 1)^, SizeUInt(LKeyLen)); Inc(LPos, SizeUInt(LKeyLen)); end;
  Result[LPos]:=':'; Inc(LPos);
  Result[LPos]:=' '; Inc(LPos);
  if LValLen>0 then Move((PAnsiChar(Pointer(AValue)) + L2 - 1)^, (PAnsiChar(Pointer(Result)) + LPos - 1)^, SizeUInt(LValLen));
end;

function GitFormatTrailers(const ATrailers: TGitTrailerArray): string;
var I: Integer; LTotal, LPos: SizeUInt; L1,R1,L2,R2, LKeyLen, LValLen: Integer;
begin
  if Length(ATrailers)=0 then Exit('');
  // perf: single allocation for entire trailer block, zero-copy Move of trimmed slices, inline trims; avoids O(n²) Result+ #10 reallocation
  LTotal:=0;
  for I:=0 to High(ATrailers) do
  begin
    L1:=1; R1:=Length(ATrailers[I].Key);
    while (L1<=R1) and (ATrailers[I].Key[L1] <= ' ') do Inc(L1);
    while (R1>=L1) and (ATrailers[I].Key[R1] <= ' ') do Dec(R1);
    L2:=1; R2:=Length(ATrailers[I].Value);
    while (L2<=R2) and (ATrailers[I].Value[L2] <= ' ') do Inc(L2);
    while (R2>=L2) and (ATrailers[I].Value[R2] <= ' ') do Dec(R2);
    if L1>R1 then LKeyLen:=0 else LKeyLen:=R1-L1+1;
    if L2>R2 then LValLen:=0 else LValLen:=R2-L2+1;
    Inc(LTotal, SizeUInt(LKeyLen) + 2 + SizeUInt(LValLen));
  end;
  if Length(ATrailers)>1 then Inc(LTotal, SizeUInt(Length(ATrailers)-1));
  SetLength(Result, LTotal);
  if LTotal=0 then Exit;
  LPos:=1;
  for I:=0 to High(ATrailers) do
  begin
    if I>0 then begin Result[LPos]:=#10; Inc(LPos); end;
    L1:=1; R1:=Length(ATrailers[I].Key);
    while (L1<=R1) and (ATrailers[I].Key[L1] <= ' ') do Inc(L1);
    while (R1>=L1) and (ATrailers[I].Key[R1] <= ' ') do Dec(R1);
    L2:=1; R2:=Length(ATrailers[I].Value);
    while (L2<=R2) and (ATrailers[I].Value[L2] <= ' ') do Inc(L2);
    while (R2>=L2) and (ATrailers[I].Value[R2] <= ' ') do Dec(R2);
    if L1>R1 then LKeyLen:=0 else LKeyLen:=R1-L1+1;
    if L2>R2 then LValLen:=0 else LValLen:=R2-L2+1;
    if LKeyLen>0 then begin Move(ATrailers[I].Key[L1], Result[LPos], LKeyLen); Inc(LPos, SizeUInt(LKeyLen)); end;
    Result[LPos]:=':'; Inc(LPos);
    Result[LPos]:=' '; Inc(LPos);
    if LValLen>0 then begin Move(ATrailers[I].Value[L2], Result[LPos], LValLen); Inc(LPos, SizeUInt(LValLen)); end;
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
