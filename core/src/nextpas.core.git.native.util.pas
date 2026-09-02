unit nextpas.core.git.native.util;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo;

function GitIsZeroOid(const AOid: TGitOid): Boolean; inline;
// shared string helpers (single source for Trim/EndsWith/SplitLines/StripCR)
function GitTrimSpaces(const S: string): string; inline;
function GitEndsWith(const S, Suffix: string): Boolean; inline;
function GitSplitLines(const S: string): TStringArray; inline;
function GitStripCR(const S: string): string; inline;
function GitWorktreeDir(const AGitDir: string): string; inline;
function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean; inline;
function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.utils,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.common;

function GitIsZeroOid(const AOid: TGitOid): Boolean; inline;
begin
  // single source via base.GitOidIsZero -> bytes.ops IsZeroBytes (zero-copy TByteSpan, inline), base owns primitive (common delegates to base)
  Result := nextpas.core.git.native.common.GitOidIsZero(AOid);
end;

function GitTrimSpaces(const S: string): string; inline;
begin
  Result := Trim(S);
end;

function GitEndsWith(const S, Suffix: string): Boolean; inline;
begin
  Result := (Length(S) >= Length(Suffix)) and (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);
end;

function GitStripCR(const S: string): string; inline;
begin
  if (Length(S) > 0) and (S[Length(S)] = #13) then
    Result := Copy(S, 1, Length(S) - 1)
  else
    Result := S;
end;

function GitSplitLines(const S: string): TStringArray; inline;
var I, Start, Idx, Cnt: Integer;
begin
  if S = '' then
  begin
    SetLength(Result, 1);
    Result[0] := '';
    Exit;
  end;
  Cnt := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Cnt);
  SetLength(Result, Cnt);
  Start := 1;
  Idx := 0;
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = #10) then
    begin
      Result[Idx] := Copy(S, Start, I - Start);
      Inc(Idx);
      Start := I + 1;
    end;
end;

function GitWorktreeDir(const AGitDir: string): string; inline;
var P: Integer;
begin
  if GitEndsWith(AGitDir, '/.git') then
    Result := Copy(AGitDir, 1, Length(AGitDir) - 5)
  else if GitEndsWith(AGitDir, '.git') then
  begin
    P := Length(AGitDir);
    while (P > 0) and (AGitDir[P] <> '/') do Dec(P);
    if P > 0 then Result := Copy(AGitDir, 1, P - 1) else Result := '.';
  end
  else
    Result := AGitDir;
end;

function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.common.GitFindBlobInTree(ARepo, ATreeOid, AName, AOid);
end;

function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.common.GitPeelToTree(ARepo, AOid);
end;

end.
