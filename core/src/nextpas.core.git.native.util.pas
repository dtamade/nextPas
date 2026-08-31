unit nextpas.core.git.native.util;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Shared string/path helpers for the native git subfamily.
  Single source for StripCR / TrimSpaces / SplitLines / EndsWith /
  WorktreeDir — avoids 3+ copies (trailer/attributes/mailmap etc).
  Inline where hot (StripCR/Trim/EndsWith/IsZero) to keep call site
  zero-copy when no allocation is needed. Reuses bytes.ops single
  source indirectly via GitBytesToString / GitStringToBytes (no adler32
  duplication here). }

function GitStripCR(const S: string): string; inline;
function GitTrimSpaces(const S: string): string; inline;
function GitLocalEndsWith(const S, Suffix: string): Boolean; inline;
function GitSplitLines(const S: string): TStringArray; inline;
function GitWorktreeDir(const AGitDir: string): string; inline;
function GitIsZeroOidInline(const AOid: TGitOid): Boolean; inline;

implementation

function GitStripCR(const S: string): string; inline;
begin
  if (Length(S) > 0) and (S[Length(S)] = #13) then
    Result := Copy(S, 1, Length(S) - 1)
  else
    Result := S;
end;

function GitTrimSpaces(const S: string): string; inline;
var
  A, B: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] in [' ', #9, #10, #13]) do
    Inc(A);
  while (B >= A) and (S[B] in [' ', #9, #10, #13]) do
    Dec(B);
  if B < A then
    Exit('');
  Result := Copy(S, A, B - A + 1);
end;

function GitLocalEndsWith(const S, Suffix: string): Boolean; inline;
begin Result:=GitEndsWith(S, Suffix); end;

function GitSplitLines(const S: string): TStringArray; inline;
var
  Cnt, P, Start, Fill: Integer;
begin
  // single-alloc, zero-copy per line via Copy; inline hot path
  if Length(S) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := '';
    Exit;
  end;
  Cnt := 0;
  for P := 1 to Length(S) do
    if S[P] = #10 then Inc(Cnt);
  SetLength(Result, Cnt + 1);
  Start := 1;
  Fill := 0;
  for P := 1 to Length(S) do
    if S[P] = #10 then
    begin
      Result[Fill] := Copy(S, Start, P - Start);
      Inc(Fill);
      Start := P + 1;
    end;
  Result[Fill] := Copy(S, Start, Length(S) - Start + 1);
end;

function GitWorktreeDir(const AGitDir: string): string; inline;
begin Result:=nextpas.core.git.native.base.GitWorktreeDir(AGitDir); end;

function GitIsZeroOidInline(const AOid: TGitOid): Boolean; inline;
begin
  Result := GitOidIsZero(AOid);
end;

end.
