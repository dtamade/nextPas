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

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops;

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
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)), SizeUInt(Length(AText))),
      TByteSpan.Create(PByte(PAnsiChar(AText)), SizeUInt(Length(AText))));
end;

function AppendPart(const ABuf: TBytes; const APart: TBytes): TBytes; inline;
var
  LOld, LNeed, LCap: SizeUInt;
begin
  // perf: amortized geometric growth single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), inline, zero-copy SpanCopy via TByteSpan single source, avoids O(n²) SetLength+Move*2 churn
  LOld := SizeUInt(Length(ABuf));
  if Length(APart) = 0 then
    Exit(ABuf);
  if LOld = 0 then
  begin
    SetLength(Result, Length(APart));
    if Length(APart) > 0 then
      SpanCopy(TByteSpan.Create(PByte(Pointer(Result)), SizeUInt(Length(APart))),
        TByteSpan.Create(PByte(Pointer(APart)), SizeUInt(Length(APart))));
    Exit;
  end;
  LNeed := LOld + SizeUInt(Length(APart));
  LCap := GrowArrayCapacity(LOld, LNeed);
  SetLength(Result, LCap);
  if LOld > 0 then
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)), LOld),
      TByteSpan.Create(PByte(Pointer(ABuf)), LOld));
  SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + LOld, SizeUInt(Length(APart))),
    TByteSpan.Create(PByte(Pointer(APart)), SizeUInt(Length(APart))));
  if LCap <> LNeed then
    SetLength(Result, LNeed);
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
      SpanCopy(TByteSpan.Create(PByte(@Result[Total]), SizeUInt(SegLen)),
        TByteSpan.Create(PByte(PAnsiChar(ModeName)), SizeUInt(SegLen)));
    Result[Total + SegLen] := 0;
    Total := Total + SegLen + 1;
    // perf: single source OID 20B via bytes.ops SpanCopy inline zero-copy TByteSpan, single Move, converges with base SpanEqual/SpanCopy
    SpanCopy(TByteSpan.Create(PByte(@Result[Total]), GitOidRawLen),
      TByteSpan.Create(@AEntries[I].Oid.Bytes[0], GitOidRawLen));
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

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes; inline;
var
  TreeHex, AuthorLine, CommitterLine: string;
  Hex: string;
  Total, Pos: SizeInt;
  I: Integer;
begin
  // perf: single allocation O(n) exact size pass + single fill, avoids O(n²) string+= reallocation per parent (S:=S+'parent '+Hex loop), inline, zero-copy SpanCopy via TByteSpan single source bytes.ops
  TreeHex := GitOidToHex(ABuilder.Tree);
  AuthorLine := SignatureLine('author ', ABuilder.AuthorName, ABuilder.AuthorEmail, ABuilder.AuthorUnixTime, ABuilder.AuthorTzMinutes);
  CommitterLine := SignatureLine('committer ', ABuilder.CommitterName, ABuilder.CommitterEmail, ABuilder.CommitterUnixTime, ABuilder.CommitterTzMinutes);
  Total := Length('tree ') + Length(TreeHex) + 1;
  for I := 0 to High(ABuilder.Parents) do
    Inc(Total, Length('parent ') + GitOidHexLen + 1);
  Inc(Total, Length(AuthorLine) + Length(CommitterLine) + 1 + Length(ABuilder.Message));
  SetLength(Result, Total);
  Pos := 0;
  if Length('tree ') > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length('tree '))),
      TByteSpan.Create(PByte(PAnsiChar('tree ')), SizeUInt(Length('tree '))));
    Inc(Pos, Length('tree '));
  end;
  if Length(TreeHex) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(TreeHex))),
      TByteSpan.Create(PByte(PAnsiChar(TreeHex)), SizeUInt(Length(TreeHex))));
    Inc(Pos, Length(TreeHex));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  for I := 0 to High(ABuilder.Parents) do
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length('parent '))),
      TByteSpan.Create(PByte(PAnsiChar('parent ')), SizeUInt(Length('parent '))));
    Inc(Pos, Length('parent '));
    Hex := GitOidToHex(ABuilder.Parents[I]);
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(Hex))),
      TByteSpan.Create(PByte(PAnsiChar(Hex)), SizeUInt(Length(Hex))));
    Inc(Pos, Length(Hex));
    Result[Pos] := Byte(#10);
    Inc(Pos);
  end;
  if Length(AuthorLine) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(AuthorLine))),
      TByteSpan.Create(PByte(PAnsiChar(AuthorLine)), SizeUInt(Length(AuthorLine))));
    Inc(Pos, Length(AuthorLine));
  end;
  if Length(CommitterLine) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(CommitterLine))),
      TByteSpan.Create(PByte(PAnsiChar(CommitterLine)), SizeUInt(Length(CommitterLine))));
    Inc(Pos, Length(CommitterLine));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  if Length(ABuilder.Message) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(ABuilder.Message))),
      TByteSpan.Create(PByte(PAnsiChar(ABuilder.Message)), SizeUInt(Length(ABuilder.Message))));
    Inc(Pos, Length(ABuilder.Message));
  end;
  // stability: TBytes refcounted, SetLength exception-safe, no header poke, managed strings auto released
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
