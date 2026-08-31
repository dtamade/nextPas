unit nextpas.core.git.native.write;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.git.native.base,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.objmodel;

{ Write path: blob storage, tree serialization with the canonical git sort
  order, and commit / annotated-tag construction. Objects land in the loose
  store; pack writing is out of scope. Sort rule mirrors git: byte-compare
  names, and at the tie point a directory entry counts as if its name ended
  with '/'. }

type
  TGitCommitBuilder = record
    Tree: TGitOid;
    Parents: array of TGitOid;
    AuthorName: string;
    AuthorEmail: string;
    AuthorUnixTime: Int64;
    AuthorTzMinutes: Integer;
    CommitterName: string;
    CommitterEmail: string;
    CommitterUnixTime: Int64;
    CommitterTzMinutes: Integer;
    Message: string;
  end;

  TGitTagBuilder = record
    Target: TGitOid;
    TargetKind: TGitObjectKind;
    TagName: string;
    TaggerName: string;
    TaggerEmail: string;
    TaggerUnixTime: Int64;
    TaggerTzMinutes: Integer;
    Message: string;
  end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray);
function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer;
function GitModeToString(AMode: Cardinal): string;
{ Serializes entries in the given order — sort first unless the order is
  already canonical }
function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes;
function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid;
function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid;
function GitBuildCommitBytes(
  const ABuilder: TGitCommitBuilder): TBytes;
function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid;
{ The message must either be empty or end with a newline: git's tag parser
  requires the object's final byte to be LF, so the builder refuses anything
  it could only store as unreadable }
function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes;
function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid;

implementation

const
  CKnownModes: array[0..4] of Cardinal =
    ($4000, $81A4, $81ED, $A000, $E000);

procedure RaiseUnsupportedMode(AMode: Cardinal);
begin
  raise EGitError.CreateFmt('unsupported tree entry mode %o', [AMode]);
end;

procedure CheckKnownMode(AMode: Cardinal);
var
  I: Integer;
begin
  for I := 0 to High(CKnownModes) do
    if CKnownModes[I] = AMode then
      Exit;
  RaiseUnsupportedMode(AMode);
end;

function TwoDigits(AValue: Integer): string;
begin
  if AValue < 10 then
    Exit('0' + IntToStr(AValue));
  Result := IntToStr(AValue);
end;

function OctalOf(AValue: Cardinal): string;
var
  Digits: string;
begin
  if AValue = 0 then
    Exit('0');
  Digits := '';
  while AValue > 0 do
  begin
    Digits := Char(Ord('0') + (AValue and 7)) + Digits;
    AValue := AValue shr 3;
  end;
  Result := Digits;
end;

function GitModeToString(AMode: Cardinal): string;
begin
  CheckKnownMode(AMode);
  Result := OctalOf(AMode);
end;

function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer;
var
  I, MinLen: SizeInt;
  CA, CB: Byte;
begin
  Result := 0;
  if Length(AA.Name) < Length(AB.Name) then
    MinLen := Length(AA.Name)
  else
    MinLen := Length(AB.Name);
  for I := 1 to MinLen do
  begin
    CA := Byte(Ord(AA.Name[I]));
    CB := Byte(Ord(AB.Name[I]));
    if CA < CB then
      Exit(-1);
    if CA > CB then
      Exit(1);
  end;
  if Length(AA.Name) = Length(AB.Name) then
    Exit(0);
  // tie point: shorter side's next byte; a directory acts as if it were '/'
  CA := Ord('/');
  CB := Ord('/');
  if Length(AA.Name) < Length(AB.Name) then
    CB := Byte(Ord(AB.Name[MinLen + 1]))
  else
    CA := Byte(Ord(AA.Name[MinLen + 1]));
  if AA.Mode = $4000 then
    CA := Ord('/');
  if AB.Mode = $4000 then
    CB := Ord('/');
  if CA < CB then
    Exit(-1);
  if CA > CB then
    Exit(1);
end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray);

  procedure MergeSort(var AItems: TGitTreeEntryArray;
    var ATemp: TGitTreeEntryArray; ALo, AHi: Integer);
  var
    Mid, I, J, K: Integer;
  begin
    if ALo >= AHi then
      Exit;
    Mid := (ALo + AHi) div 2;
    MergeSort(AItems, ATemp, ALo, Mid);
    MergeSort(AItems, ATemp, Mid + 1, AHi);
    I := ALo;
    J := Mid + 1;
    for K := ALo to AHi do
    begin
      if (I <= Mid) and ((J > AHi)
        or (GitEntryCompare(AItems[I], AItems[J]) <= 0)) then
      begin
        ATemp[K] := AItems[I];
        Inc(I);
      end
      else
      begin
        ATemp[K] := AItems[J];
        Inc(J);
      end;
    end;
    for K := ALo to AHi do
      AItems[K] := ATemp[K];
  end;

var
  Temp: TGitTreeEntryArray;
begin
  if Length(AEntries) < 2 then
    Exit;
  SetLength(Temp, Length(AEntries));
  MergeSort(AEntries, Temp, 0, Length(AEntries) - 1);
end;

function AsciiBytes(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Result[0], Length(AText));
end;

function AppendPart(const ABuf: TBytes; const APart: TBytes): TBytes;
var
  OldLen: SizeInt;
begin
  OldLen := Length(ABuf);
  SetLength(Result, OldLen + Length(APart));
  if OldLen > 0 then
    Move(ABuf[0], Result[0], OldLen);
  if Length(APart) > 0 then
    Move(APart[0], Result[OldLen], Length(APart));
end;

function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes;
var
  I, Total, SegLen: SizeInt;
  ModeName: string;
begin
  // exact size pass, then a single fill
  Total := 0;
  for I := 0 to High(AEntries) do
  begin
    CheckKnownMode(AEntries[I].Mode);
    ModeName := GitModeToString(AEntries[I].Mode) + ' ' + AEntries[I].Name;
    Total := Total + Length(ModeName) + 1 + GitOidRawLen;
  end;
  SetLength(Result, Total);
  Total := 0;
  for I := 0 to High(AEntries) do
  begin
    ModeName := GitModeToString(AEntries[I].Mode) + ' ' + AEntries[I].Name;
    SegLen := Length(ModeName);
    if SegLen > 0 then
      Move(ModeName[1], Result[Total], SegLen);
    Result[Total + SegLen] := 0;
    Total := Total + SegLen + 1;
    Move(AEntries[I].Oid.Bytes[0], Result[Total], GitOidRawLen);
    Total := Total + GitOidRawLen;
  end;
end;

function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokBlob, AContent);
end;

function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid;
begin
  GitSortTreeEntries(AEntries);
  Result := GitLooseWrite(AGitDir, gokTree, GitSerializeTree(AEntries));
end;

function SignatureLine(const AHeader, AName, AEmail: string;
  AUnixTime: Int64; ATzMinutes: Integer): string;
var
  SignCh: Char;
  AbsMin: Integer;
begin
  if AName = '' then
    raise EGitError.Create('commit signature name must not be empty');
  if AEmail = '' then
    raise EGitError.Create('commit signature email must not be empty');
  if (ATzMinutes < -1500) or (ATzMinutes > 1500) then
    raise EGitError.CreateFmt('implausible timezone offset %d', [ATzMinutes]);
  SignCh := '+';
  AbsMin := ATzMinutes;
  if AbsMin < 0 then
  begin
    SignCh := '-';
    AbsMin := -AbsMin;
  end;
  Result := AHeader + AName + ' <' + AEmail + '> ' + IntToStr(AUnixTime)
    + ' ' + SignCh + TwoDigits(AbsMin div 60) + TwoDigits(AbsMin mod 60)
    + #10;
end;

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes;
var
  S: string;
  I: Integer;
begin
  S := 'tree ' + GitOidToHex(ABuilder.Tree) + #10;
  for I := 0 to High(ABuilder.Parents) do
    S := S + 'parent ' + GitOidToHex(ABuilder.Parents[I]) + #10;
  S := S + SignatureLine('author ', ABuilder.AuthorName,
    ABuilder.AuthorEmail, ABuilder.AuthorUnixTime,
    ABuilder.AuthorTzMinutes);
  S := S + SignatureLine('committer ', ABuilder.CommitterName,
    ABuilder.CommitterEmail, ABuilder.CommitterUnixTime,
    ABuilder.CommitterTzMinutes);
  S := S + #10 + ABuilder.Message;
  Result := AsciiBytes(S);
end;

function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokCommit, GitBuildCommitBytes(ABuilder));
end;

function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes;
var
  I: Integer;
  S: string;
begin
  if ABuilder.TagName = '' then
    raise EGitError.Create('tag name must not be empty');
  for I := 1 to Length(ABuilder.TagName) do
    if ABuilder.TagName[I] in [#10, #13] then
      raise EGitError.Create('tag name must not contain line breaks');
  if (ABuilder.Message <> '')
    and (ABuilder.Message[Length(ABuilder.Message)] <> #10) then
    raise EGitError.Create('tag message must end with a newline');
  // GitKindToString validates the target kind (nested tags allowed)
  S := 'object ' + GitOidToHex(ABuilder.Target) + #10
    + 'type ' + GitKindToString(ABuilder.TargetKind) + #10
    + 'tag ' + ABuilder.TagName + #10
    + SignatureLine('tagger ', ABuilder.TaggerName, ABuilder.TaggerEmail,
        ABuilder.TaggerUnixTime, ABuilder.TaggerTzMinutes)
    + #10 + ABuilder.Message;
  Result := AsciiBytes(S);
end;

function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokTag, GitBuildTagBytes(ABuilder));
end;

end.
