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
  nextpas.core.text.conv,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function LocalCompareStr(const A, B: string): Integer;
var I, L: Integer;
begin
  L := Length(A);
  if Length(B) < L then L := Length(B);
  for I := 1 to L do
    if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

procedure SortHits(var A: TGitGrepHitArray);
var I, J: Integer; T: TGitGrepHit;
begin
  for I := 1 to High(A) do
  begin
    J := I;
    while J > 0 do
    begin
      if LocalCompareStr(A[J-1].Path, A[J].Path) < 0 then Break;
      if (LocalCompareStr(A[J-1].Path, A[J].Path) = 0) and (A[J-1].LineNo <= A[J].LineNo) then Break;
      T := A[J-1]; A[J-1] := A[J]; A[J] := T;
      Dec(J);
    end;
  end;
end;

type
  TFlatBlob = record
    Path: string;
    Oid: TGitOid;
  end;
  TFlatBlobArray = array of TFlatBlob;

procedure CollectBlobs(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatBlobArray);
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
      CollectBlobs(ARepo, Entries[I].Oid, Full + '/', AOut)
    else if Entries[I].Mode = $E000 then
      Continue // gitlink
    else if Entries[I].Mode = $A000 then
      Continue // symlink blob is link target, skip for text grep
    else
    begin
      // regular blob 100644/100755
      SetLength(AOut, Length(AOut)+1);
      AOut[High(AOut)].Path := Full;
      AOut[High(AOut)].Oid := Entries[I].Oid;
    end;
  end;
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

function SplitLines(const S: string): TStringArray;
var I, Start, Cnt: Integer;
    Line: string;
begin
  Result := nil;
  Start := 1; Cnt := 0;
  for I := 1 to Length(S) do
    if S[I] = #10 then
    begin
      Line := Copy(S, Start, I - Start);
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line)-1);
      SetLength(Result, Cnt+1);
      Result[Cnt] := Line;
      Inc(Cnt);
      Start := I + 1;
    end;
  Line := Copy(S, Start, MaxInt);
  if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
    SetLength(Line, Length(Line)-1);
  // include last line even if empty? git grep ignores final empty? keep if not empty or if file ends with newline we would have trailing empty; skip empty trailing?
  if (Line <> '') or (Length(Result) = 0) then
  begin
    // avoid duplicate empty when S ends with #10 (then last copy is '')
    if not ((Line = '') and (Length(S) > 0) and (S[Length(S)] = #10)) then
    begin
      SetLength(Result, Cnt+1);
      Result[Cnt] := Line;
    end;
  end;
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
      Text := GitBytesToString(Data);
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
