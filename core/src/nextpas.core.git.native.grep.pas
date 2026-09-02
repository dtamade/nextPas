unit nextpas.core.git.native.grep;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

type
  TGitGrepHit = record
    Path: string;
    LineNo: Integer;
    Line: string;
    BlobOid: TGitOid;
  end;
  TGitGrepHitArray = array of TGitGrepHit;

function GitGrep(const AGitDir, ARev, APattern: string): TGitGrepHitArray; overload;
function GitGrep(const AGitDir, ARev, APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; overload;
function GitGrepTree(const AGitDir: string; const ATreeOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; overload;
function GitGrepCommits(const AGitDir: string; const ACommitOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;

implementation

uses
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.base.utils,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common,
  nextpas.core.git.native.util;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function LocalCompareStr(const A, B: string): Integer; inline;
var
  PA, PB: Pointer;
begin
  // single source: base.utils CompareBytesOrdered (PByte+Len zero-copy, inline) — same source as bytes.ops SpanCompare
  if Length(A) = 0 then PA := nil else PA := @A[1];
  if Length(B) = 0 then PB := nil else PB := @B[1];
  Result := nextpas.core.base.utils.CompareBytesOrdered(PA, PB, SizeUInt(Length(A)), SizeUInt(Length(B)));
end;

{ SortHits: O(n log n) quicksort (median-of-3 + tail recursion).
  Replaces prior insertion O(n²). Zero-copy: swaps records, compares
  via inline LocalCompareStr single source base.utils CompareBytesOrdered (same as bytes.ops SpanCompare) on existing string storage (PByte+Len view, no alloc), inline. }
procedure QuickSortHits(var A: TGitGrepHitArray; L, R: Integer);
var I, J, M: Integer; Pivot: TGitGrepHit; Tmp: TGitGrepHit;
  function CmpHit(const X, Y: TGitGrepHit): Integer; inline;
  var C: Integer;
  begin
    C := LocalCompareStr(X.Path, Y.Path);
    if C <> 0 then Exit(C);
    if X.LineNo < Y.LineNo then Exit(-1);
    if X.LineNo > Y.LineNo then Exit(1);
    Result := 0;
  end;
begin
  while L < R do
  begin
    M := (L + R) shr 1;
    if CmpHit(A[L], A[M]) > 0 then begin Tmp := A[L]; A[L] := A[M]; A[M] := Tmp; end;
    if CmpHit(A[M], A[R]) > 0 then begin Tmp := A[M]; A[M] := A[R]; A[R] := Tmp; end;
    if CmpHit(A[L], A[M]) > 0 then begin Tmp := A[L]; A[L] := A[M]; A[M] := Tmp; end;
    Pivot := A[M];
    I := L; J := R;
    repeat
      while CmpHit(A[I], Pivot) < 0 do Inc(I);
      while CmpHit(A[J], Pivot) > 0 do Dec(J);
      if I <= J then
      begin
        if I <> J then begin Tmp := A[I]; A[I] := A[J]; A[J] := Tmp; end;
        Inc(I); Dec(J);
      end;
    until I > J;
    if (J - L) < (R - I) then
    begin
      if L < J then QuickSortHits(A, L, J);
      L := I;
    end else
    begin
      if I < R then QuickSortHits(A, I, R);
      R := J;
    end;
  end;
end;

procedure SortHits(var A: TGitGrepHitArray); inline;
begin
  if Length(A) < 2 then Exit;
  QuickSortHits(A, 0, High(A));
end;

type
  TFlatBlob = record
    Path: string;
    Oid: TGitOid;
  end;
  TFlatBlobArray = array of TFlatBlob;

{ CollectBlobs: amortized O(n) via bytes.ops GrowArrayCapacity single source.
  Previously SetLength(AOut,Length+1) per entry → O(n²) copies.
  Zero-copy: string assignment is refcounted move, TGitOid 20B inline copy via direct assignment, inline wrapper. }
procedure CollectBlobs(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatBlobArray; var ACount, ACap: Integer); overload;
var Kind: TGitObjectKind;
    Data: TBytes;
    Entries: TGitTreeEntryArray;
    I: Integer;
    Full: string;
begin
  if IsZeroOid(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('grep: object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    Full := APrefix + Entries[I].Name;
    if Entries[I].Mode = $4000 then
      CollectBlobs(ARepo, Entries[I].Oid, Full + '/', AOut, ACount, ACap)
    else if Entries[I].Mode = $E000 then
      Continue // gitlink
    else if Entries[I].Mode = $A000 then
      Continue // symlink blob is link target, skip for text grep
    else
    begin
      // regular blob 100644/100755 - amortized geometric growth single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), inline, O(1) amortized, zero-copy TGitOid Move via direct assignment
      if ACount >= ACap then
      begin
        ACap := Integer(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
        SetLength(AOut, ACap);
      end;
      AOut[ACount].Path := Full;
      AOut[ACount].Oid := Entries[I].Oid;
      Inc(ACount);
    end;
  end;
end;

procedure CollectBlobs(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatBlobArray); overload; inline;
var Cnt, Cap: Integer;
begin
  Cnt := Length(AOut); Cap := Length(AOut);
  CollectBlobs(ARepo, ATreeOid, APrefix, AOut, Cnt, Cap);
  SetLength(AOut, Cnt);
end;

function ContainsFixed(const ALine, APat: string; AIgnoreCase: Boolean): Boolean;
var L, P: string;
begin
  if AIgnoreCase then
  begin
    L := nextpas.core.text.conv.LowerCase(ALine);
    P := nextpas.core.text.conv.LowerCase(APat);
    Result := Pos(P, L) > 0;
  end
  else
    Result := Pos(APat, ALine) > 0;
end;

function SplitLines(const S: string): TStringArray; inline;
var
  Tmp: TStringArray;
  I: Integer;
begin
  // single source: git.native.util GitSplitLines (single-alloc, zero-copy per line via Copy) + GitStripCR (inline zero-copy)
  Tmp := nextpas.core.git.native.util.GitSplitLines(S);
  if (Length(Tmp) > 0) and (Tmp[High(Tmp)] = '') and (Length(S) > 0) and (S[Length(S)] = #10) then
    SetLength(Tmp, Length(Tmp) - 1);
  for I := 0 to High(Tmp) do
    Tmp[I] := nextpas.core.git.native.util.GitStripCR(Tmp[I]);
  Result := Tmp;
end;

// PeelToTree reused from nextpas.core.git.native.common (single source)

function GitGrepTree(const AGitDir: string; const ATreeOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;
var Repo: TNativeRepository;
    Blobs: TFlatBlobArray;
    I, J: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Text: string;
    Lines: TStringArray;
    Hit: TGitGrepHit;
    HasNul: Boolean;
    K: Integer;
begin
  Result := nil;
  if APattern = '' then
    raise EGitError.Create('grep: empty pattern');
  if IsZeroOid(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Blobs := nil;
    CollectBlobs(Repo, ATreeOid, '', Blobs);
    for I := 0 to High(Blobs) do
    begin
      Data := Repo.ReadObject(Blobs[I].Oid, Kind);
      if Kind <> gokBlob then Continue;
      // binary check: NUL byte
      HasNul := False;
      for K := 0 to High(Data) do if Data[K] = 0 then begin HasNul := True; Break; end;
      if HasNul then Continue;
      Text := BytesToString(Data);
      Lines := SplitLines(Text);
      for J := 0 to High(Lines) do
        if ContainsFixed(Lines[J], APattern, AIgnoreCase) then
        begin
          Hit.Path := Blobs[I].Path;
          Hit.LineNo := J + 1;
          Hit.Line := Lines[J];
          Hit.BlobOid := Blobs[I].Oid;
          SetLength(Result, Length(Result)+1);
          Result[High(Result)] := Hit;
        end;
    end;
  finally
    Repo.Free;
  end;
  SortHits(Result);
end;

function GitGrepCommits(const AGitDir: string; const ACommitOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;
var Repo: TNativeRepository;
    Tree: TGitOid;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    Tree := GitPeelToTree(Repo, ACommitOid);
  finally
    Repo.Free;
  end;
  Result := GitGrepTree(AGitDir, Tree, APattern, AIgnoreCase);
end;

function GitGrep(const AGitDir, ARev, APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;
var Oid: TGitOid;
    Repo: TNativeRepository;
    Tree: TGitOid;
begin
  if Trim(APattern) = '' then
    raise EGitError.Create('grep: empty pattern');
  // resolve rev: may be HEAD, branch, tag, commit oid
  try
    Oid := GitRevParse(AGitDir, ARev);
  except
    on E: EGitError do
      raise EGitError.CreateFmt('grep: cannot resolve rev "%s"', [ARev]);
  end;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Tree := GitPeelToTree(Repo, Oid);
  finally
    Repo.Free;
  end;
  Result := GitGrepTree(AGitDir, Tree, APattern, AIgnoreCase);
end;

function GitGrep(const AGitDir, ARev, APattern: string): TGitGrepHitArray;
begin
  Result := GitGrep(AGitDir, ARev, APattern, False);
end;

end.
