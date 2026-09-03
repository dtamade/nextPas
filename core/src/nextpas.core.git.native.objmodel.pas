unit nextpas.core.git.native.objmodel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.util;

{ Parsers for the human-readable git object formats: trees, commits and
  annotated tags. Pure functions over already-decompressed payload bytes. }

type
  TGitTreeEntry = record
    Mode: Cardinal;
    Name: string;
    Oid: TGitOid;
  end;
  TGitTreeEntryArray = array of TGitTreeEntry;

  TGitSignature = record
    Name: string;
    Email: string;
    UnixTime: Int64;
    TzMinutes: Integer;
  end;

  TGitCommitInfo = record
    Tree: TGitOid;
    Parents: array of TGitOid;
    Author: TGitSignature;
    Committer: TGitSignature;
    Message: string;
  end;

  TGitTagInfo = record
    Target: TGitOid;
    TargetKind: TGitObjectKind;
    TagName: string;
    { git tolerates a missing tagger header; the field is then undefined }
    HasTagger: Boolean;
    Tagger: TGitSignature;
    Message: string;
  end;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
function GitParseSignature(const ALine: string): TGitSignature;
function GitParseCommit(const AData: TBytes): TGitCommitInfo;
{ Raises EGitError when any of the mandatory object/type/tag headers is
  absent or carries an invalid value; unknown extra headers are skipped }
function GitParseTag(const AData: TBytes): TGitTagInfo;

implementation

uses
  nextpas.core.bytes.ops;

function ParseOctalText(const AText: string): Cardinal;
var
  I: Integer;
begin
  if AText = '' then
    raise EGitError.Create('empty tree entry mode');
  Result := 0;
  for I := 1 to Length(AText) do
  begin
    case AText[I] of
      '0'..'7': Result := (Result shl 3) or Cardinal(Ord(AText[I]) - Ord('0'));
    else
      raise EGitError.CreateFmt('invalid tree entry mode "%s"', [AText]);
    end;
  end;
end;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
var
  P, Len: SizeInt;
  ModeStart, NameStart: SizeInt;
  EntryCount, Cap: Integer;
begin
  Len := Length(AData);
  P := 0;
  EntryCount := 0;
  Cap := 0;
  SetLength(Result, 0);
  while P < Len do
  begin
    ModeStart := P;
    while (P < Len) and (AData[P] <> Ord(' ')) do
      Inc(P);
    if P >= Len then
      raise EGitError.Create('corrupt tree entry: missing mode terminator');
    Inc(P);
    NameStart := P;
    while (P < Len) and (AData[P] <> 0) do
      Inc(P);
    if P >= Len then
      raise EGitError.Create('corrupt tree entry: missing name terminator');
    Inc(P);
    if P + GitOidRawLen > Len then
      raise EGitError.Create('corrupt tree entry: truncated oid');
    // perf: amortized O(1) doubling (bytes.ops single-source pattern) avoids O(n²) per-entry SetLength churn
    if EntryCount >= Cap then
    begin
      if Cap = 0 then
        Cap := 8
      else if Cap <= High(Integer) div 2 then
        Cap := Cap * 2
      else
        Cap := EntryCount + 1;
      SetLength(Result, Cap);
    end;
    // perf: zero-copy slice via bytes.ops (no intermediate TBytes), inline Slice+BytesSliceToString (single view + single copy)
    Result[EntryCount].Mode := ParseOctalText(
      BytesSliceToString(AData, SizeUInt(ModeStart), SizeUInt(NameStart - ModeStart - 1)));
    Result[EntryCount].Name :=
      BytesSliceToString(AData, SizeUInt(NameStart), SizeUInt(P - NameStart - 1));
    // perf: single source OID copy via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move, no heap), replaces scattered Move 20B
    SpanCopy(TByteSpan.Create(@Result[EntryCount].Oid.Bytes[0], GitOidRawLen),
      TByteSpan.Create(@AData[P], GitOidRawLen));
    Inc(P, GitOidRawLen);
    Inc(EntryCount);
  end;
  if Length(Result) <> EntryCount then
    SetLength(Result, EntryCount);
end;

function GitParseSignature(const ALine: string): TGitSignature;
var
  Lt, Gt, Sp, Code: Integer;
  Tail, TimeStr, TzStr: string;
  Raw: Int64;
begin
  Lt := Pos('<', ALine);
  Gt := Pos('>', ALine);
  if (Lt < 2) or (Gt <= Lt) then
    raise EGitError.CreateFmt('corrupt signature "%s"', [ALine]);
  Result.Name := Trim(Copy(ALine, 1, Lt - 1));
  Result.Email := Copy(ALine, Lt + 1, Gt - Lt - 1);
  Tail := Trim(Copy(ALine, Gt + 1, MaxInt));
  Sp := Pos(' ', Tail);
  if Sp < 2 then
    raise EGitError.CreateFmt('corrupt signature timestamp "%s"', [ALine]);
  TimeStr := Copy(Tail, 1, Sp - 1);
  Val(TimeStr, Raw, Code);
  if Code <> 0 then
    raise EGitError.CreateFmt('corrupt signature time "%s"', [TimeStr]);
  Result.UnixTime := Raw;
  TzStr := Trim(Copy(Tail, Sp + 1, MaxInt));
  // "+HHMM" / "-HHMM"
  if (Length(TzStr) = 5)
    and ((TzStr[1] = '+') or (TzStr[1] = '-'))
    and (TryStrToInt(Copy(TzStr, 2, 2), Sp))
    and (TryStrToInt(Copy(TzStr, 4, 2), Code)) then
  begin
    if TzStr[1] = '-' then
      Result.TzMinutes := -(Sp * 60 + Code)
    else
      Result.TzMinutes := Sp * 60 + Code;
  end
  else
    Result.TzMinutes := 0;
end;

function GitParseCommit(const AData: TBytes): TGitCommitInfo;
var
  Text, Header, Line, Rest: string;
  Lines: TStringArray;
  I, Brk, Sp, ParentCount: Integer;
begin
  Text := BytesToString(AData);
  // headers and message are separated by the first blank line
  Brk := Pos(#10#10, Text);
  if Brk > 0 then
  begin
    Header := Copy(Text, 1, Brk - 1);
    Result.Message := Copy(Text, Brk + 2, MaxInt);
  end
  else
  begin
    Header := Text;
    Result.Message := '';
  end;
  Lines := GitSplitLines(Header);
  ParentCount := 0;
  SetLength(Result.Parents, 0);
  for I := 0 to Length(Lines) - 1 do
  begin
    Line := Lines[I];
    if (Line = '') or (Line[1] = ' ') then
      Continue;
    Sp := Pos(' ', Line);
    if Sp < 2 then
      Continue;
    Rest := Trim(Copy(Line, Sp + 1, MaxInt));
    if Copy(Line, 1, 5) = 'tree ' then
      Result.Tree := GitOidFromHex(Rest)
    else if Copy(Line, 1, 7) = 'parent ' then
    begin
      Inc(ParentCount);
      SetLength(Result.Parents, ParentCount);
      Result.Parents[ParentCount - 1] := GitOidFromHex(Rest);
    end
    else if Copy(Line, 1, 7) = 'author ' then
      Result.Author := GitParseSignature(Rest)
    else if Copy(Line, 1, 10) = 'committer ' then
      Result.Committer := GitParseSignature(Rest);
  end;
end;

function GitParseTag(const AData: TBytes): TGitTagInfo;
var
  Text, Header, Line, Rest: string;
  Lines: TStringArray;
  I, Brk, Sp: Integer;
  HaveObject, HaveType, HaveName: Boolean;
begin
  Text := BytesToString(AData);
  // headers and message are separated by the first blank line
  Brk := Pos(#10#10, Text);
  if Brk > 0 then
  begin
    Header := Copy(Text, 1, Brk - 1);
    Result.Message := Copy(Text, Brk + 2, MaxInt);
  end
  else
  begin
    Header := Text;
    Result.Message := '';
  end;
  Result.HasTagger := False;
  HaveObject := False;
  HaveType := False;
  HaveName := False;
  Lines := GitSplitLines(Header);
  for I := 0 to Length(Lines) - 1 do
  begin
    Line := Lines[I];
    if (Line = '') or (Line[1] = ' ') then
      Continue;
    Sp := Pos(' ', Line);
    if Sp < 2 then
      Continue;
    Rest := Trim(Copy(Line, Sp + 1, MaxInt));
    if Copy(Line, 1, 7) = 'object ' then
    begin
      Result.Target := GitOidFromHex(Rest);
      HaveObject := True;
    end
    else if Copy(Line, 1, 5) = 'type ' then
    begin
      // raises for anything outside commit/tree/blob/tag (nested tags ok)
      Result.TargetKind := GitKindFromString(Rest);
      HaveType := True;
    end
    else if Copy(Line, 1, 4) = 'tag ' then
    begin
      Result.TagName := Rest;
      HaveName := True;
    end
    else if Copy(Line, 1, 7) = 'tagger ' then
    begin
      Result.Tagger := GitParseSignature(Rest);
      Result.HasTagger := True;
    end;
  end;
  if not HaveObject then
    raise EGitError.Create('tag object missing "object" header');
  if not HaveType then
    raise EGitError.Create('tag object missing "type" header');
  if not HaveName then
    raise EGitError.Create('tag object missing "tag" header');
end;

end.
