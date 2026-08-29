unit nextpas.core.git.native.bisect;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk;

type
  TGitBisectCheck = function(const AOid: TGitOid): Boolean;
  TGitBisectResult = record
    Found: Boolean;
    FirstBad: TGitOid;
    Steps: Integer;
    Candidates: Integer;
  end;

function GitBisectCandidates(const AGitDir, AGoodRev, ABadRev: string): TGitOidArray;
function GitBisectFind(const AGitDir: string; const AGoodRev, ABadRev: string; ACheck: TGitBisectCheck): TGitBisectResult;
function GitBisectLinear(const ACandidates: TGitOidArray; ACheck: TGitBisectCheck): TGitBisectResult;

implementation

uses
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revparse;

function GitBisectCandidates(const AGitDir, AGoodRev, ABadRev: string): TGitOidArray;
var GoodOid, BadOid: TGitOid;
    Repo: TNativeRepository;
    Starts, Hides: TGitOidArray;
    Opt: TGitRevOptions;
begin
  Result := nil;
  if AGoodRev = '' then
    raise EGitError.Create('bisect: empty good rev');
  if ABadRev = '' then
    raise EGitError.Create('bisect: empty bad rev');
  GoodOid := GitRevParse(AGitDir, AGoodRev);
  BadOid := GitRevParse(AGitDir, ABadRev);
  if GitOidSame(GoodOid, BadOid) then
    raise EGitError.Create('bisect: good and bad are same');
  Repo := TNativeRepository.Create(AGitDir);
  try
    // verify good is ancestor of bad? optional; if not, candidates still non-empty but bisect may be undefined
    SetLength(Starts, 1);
    Starts[0] := BadOid;
    SetLength(Hides, 1);
    Hides[0] := GoodOid;
    Opt := DefaultGitRevOptions;
    // candidates in topo order (children before parents) gives linear bisect order reversed?
    // For linear history, topo == date order = parents after children.
    // We return topo and will bisect from newest to oldest (index 0 = bad newest)
    Result := GitTopoOrderCommits(Repo, Starts, Hides, Opt, -1);
    // GitTopoOrderCommits with hide includes only commits reachable from Starts excluding Hides and their ancestors.
    // This yields bad..good^ range (good excluded). If good is ancestor, result non-empty.
    if Length(Result) = 0 then
      raise EGitError.Create('bisect: no candidates between good and bad (bad may not descend from good)');
  finally
    Repo.Free;
  end;
end;

function GitBisectLinear(const ACandidates: TGitOidArray; ACheck: TGitBisectCheck): TGitBisectResult;
var Lo, Hi, Mid, Steps: Integer;
    IsBad: Boolean;
begin
  Result.Found := False;
  Result.Steps := 0;
  Result.Candidates := Length(ACandidates);
  if Length(ACandidates) = 0 then Exit;
  if not Assigned(ACheck) then
    raise EGitError.Create('bisect: nil check function');
  // ACandidates[0] is bad newest, last is oldest closest to good.
  // For linear history, first bad is earliest index where check true and all earlier (newer) also true?
  // Actually if bad is newest, then candidates from bad backwards: if bisect linear, the latest bad is at index 0, good excluded.
  // We want first (oldest) bad. So check predicate: Bad = true, Good = false (excluded).
  // Binary search for first true when scanning from oldest to newest? Easier: reverse mental.
  // We'll search for earliest bad: smallest index from oldest side that's bad.
  // Since 0 is newest bad, last is oldest nearest good. The "first bad" is the oldest bad that is still bad (closest to good).
  // If predicate is monotonic (good false, bad true, and if commit is bad then all descendants are bad), then array viewed from oldest to newest is false...false? Wait.
  // For linear chain A(good)-B-C-D(bad): candidates = [D,C,B] (topo: D newest first). Predicate: D=bad true, C=bad? depends, B maybe good false? So array B false would be at end. So first bad from oldest side is after goods.
  // Binary search typical bisect: low=0 (newest bad), high=last (oldest). But need monotonic.
  // We'll do standard binary search for first bad when scanning from oldest to newest ascending index reversed?
  // Simplify: create reversed view where index 0 is oldest (closest to good) and N-1 is newest bad.
  // Then first bad is leftmost true in reversed order.
  // Instead of reversing, just binary search over Lo..Hi where Lo=0, Hi=High, find first bad from left (oldest side) which is high index.
  // Easiest: linear scan for first bad from oldest side if monotonic, but we want O(log n) steps.
  // We'll implement binary search over reversed indices: logical reversed Kandid[iRev] = ACandidates[High - iRev].
  // Then search first true.
  Lo := 0; Hi := High(ACandidates);
  Steps := 0;
  // quick check: newest bad must be bad, else no bad
  if not ACheck(ACandidates[0]) then
    Exit; // bad is not bad -> inconsistent
  // if oldest candidate is bad, then all are bad, first bad is oldest
  if ACheck(ACandidates[High(ACandidates)]) then
  begin
    Result.Found := True;
    Result.FirstBad := ACandidates[High(ACandidates)];
    Result.Steps := 1;
    Exit;
  end;
  // binary search for boundary between bad (newer) and good (older)
  // Invariant: Kandid[Lo] true (bad), Kandid[Hi] false (good) in reversed view? Let's keep reversed mapping.
  // We'll binary search on reversed index
  // Reversed: revIdx = High - origIdx
  // So orig 0 (newest) -> rev High, orig High (oldest) -> rev 0
  // Predicate on reversed: rev 0 (oldest) is false (good), rev High (newest) true.
  // We want first true in reversed order.
  Lo := 0; Hi := High(ACandidates); // reversed indices
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) div 2;
    // mid reversed corresponds to orig = High - Mid
    Inc(Steps);
    IsBad := ACheck(ACandidates[High(ACandidates) - Mid]);
    if IsBad then
      Hi := Mid
    else
      Lo := Mid + 1;
  end;
  // Lo is first bad in reversed
  Inc(Steps);
  if ACheck(ACandidates[High(ACandidates) - Lo]) then
  begin
    Result.Found := True;
    Result.FirstBad := ACandidates[High(ACandidates) - Lo];
    Result.Steps := Steps;
  end;
end;

function GitBisectFind(const AGitDir: string; const AGoodRev, ABadRev: string; ACheck: TGitBisectCheck): TGitBisectResult;
var Cands: TGitOidArray;
begin
  Cands := GitBisectCandidates(AGitDir, AGoodRev, ABadRev);
  Result := GitBisectLinear(Cands, ACheck);
end;

end.
