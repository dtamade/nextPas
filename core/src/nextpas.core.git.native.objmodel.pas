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

{ Zero-copy span helpers for signature/commit/tag headers: TByteSpan views via
  bytes.ops single source (inline SpanIndexOf/SpanTrim/SpanToString/SpanStartsWith,
  single SetString copy only on materialize); digit loops not inline. }
function SpanHasPrefix(const ALine: TByteSpan; const APrefix: string): Boolean; inline;
begin
  if SizeUInt(Length(APrefix)) > ALine.Len then
    Exit(False);
  Result := SpanStartsWith(ALine, TByteSpan.FromStr(APrefix));
end;

function SpanValueAfter(const ALine: TByteSpan; APrefixLen: SizeUInt): TByteSpan; inline;
begin
  if APrefixLen >= ALine.Len then
    Exit(TByteSpan.Empty);
  Result.Data := ALine.Data + APrefixLen;
  Result.Len := ALine.Len - APrefixLen;
  Result := SpanTrim(Result);
end;

function TryParseDecInt64(const ASpan: TByteSpan; out AValue: Int64): Boolean;
var
  I: SizeUInt;
  Neg: Boolean;
  D: Byte;
  V: Int64;
begin
  AValue := 0;
  if ASpan.Len = 0 then
    Exit(False);
  I := 0;
  Neg := False;
  if (ASpan.Data[0] = Ord('+')) or (ASpan.Data[0] = Ord('-')) then
  begin
    Neg := ASpan.Data[0] = Ord('-');
    I := 1;
    if ASpan.Len = 1 then
      Exit(False);
  end;
  V := 0;
  while I < ASpan.Len do
  begin
    D := ASpan.Data[I];
    if (D < Ord('0')) or (D > Ord('9')) then
      Exit(False);
    if (V > High(Int64) div 10) or
      ((V = High(Int64) div 10) and (Int64(D - Ord('0')) > High(Int64) mod 10)) then
      Exit(False);
    V := V * 10 + Int64(D - Ord('0'));
    Inc(I);
  end;
  if Neg then
    V := -V;
  AValue := V;
  Result := True;
end;

function TryParseTzMinutes(const ASpan: TByteSpan; out AMinutes: Integer): Boolean; inline;
var
  HH, MM: Integer;
begin
  // "+HHMM"/"-HHMM" digit arithmetic, no alloc; out-of-shape falls back to 0
  Result := False;
  if ASpan.Len <> 5 then
    Exit;
  if (ASpan.Data[0] <> Ord('+')) and (ASpan.Data[0] <> Ord('-')) then
    Exit;
  if (ASpan.Data[1] < Ord('0')) or (ASpan.Data[1] > Ord('9')) then
    Exit;
  if (ASpan.Data[2] < Ord('0')) or (ASpan.Data[2] > Ord('9')) then
    Exit;
  if (ASpan.Data[3] < Ord('0')) or (ASpan.Data[3] > Ord('9')) then
    Exit;
  if (ASpan.Data[4] < Ord('0')) or (ASpan.Data[4] > Ord('9')) then
    Exit;
  HH := (Ord(ASpan.Data[1]) - Ord('0')) * 10 + (Ord(ASpan.Data[2]) - Ord('0'));
  MM := (Ord(ASpan.Data[3]) - Ord('0')) * 10 + (Ord(ASpan.Data[4]) - Ord('0'));
  if ASpan.Data[0] = Ord('-') then
    AMinutes := -(HH * 60 + MM)
  else
    AMinutes := HH * 60 + MM;
  Result := True;
end;

function GitParseSignature(const ALine: string): TGitSignature;
var
  LWhole, LName, LMail, LTail, LTime, LTz, LRest: TByteSpan;
  Lt, Gt, Sp: SizeInt;
begin
  // perf: zero-copy views over ALine (inline SpanIndexOf SIMD + SpanTrim single source); only Name/Email materialize, time/tz parsed in place
  LWhole := TByteSpan.FromStr(ALine);
  Lt := SpanIndexOf(LWhole, Byte('<'));
  Gt := SpanIndexOf(LWhole, Byte('>'));
  if (Lt <= 0) or (Gt <= Lt) then
    raise EGitError.CreateFmt('corrupt signature "%s"', [ALine]);
  LName.Data := LWhole.Data;
  LName.Len := SizeUInt(Lt);
  LName := SpanTrim(LName);
  LMail.Data := LWhole.Data + SizeUInt(Lt) + 1;
  LMail.Len := SizeUInt(Gt - Lt - 1);
  if SizeUInt(Gt) + 1 < LWhole.Len then
  begin
    LRest.Data := LWhole.Data + SizeUInt(Gt) + 1;
    LRest.Len := LWhole.Len - SizeUInt(Gt) - 1;
  end
  else
    LRest := TByteSpan.Empty;
  LTail := SpanTrim(LRest);
  Sp := SpanIndexOf(LTail, Byte(' '));
  if Sp <= 0 then
    raise EGitError.CreateFmt('corrupt signature timestamp "%s"', [ALine]);
  LTime.Data := LTail.Data;
  LTime.Len := SizeUInt(Sp);
  LRest.Data := LTail.Data + SizeUInt(Sp) + 1;
  LRest.Len := LTail.Len - SizeUInt(Sp) - 1;
  LTz := SpanTrim(LRest);
  Result.Name := SpanToString(LName);
  Result.Email := SpanToString(LMail);
  if not TryParseDecInt64(LTime, Result.UnixTime) then
    raise EGitError.CreateFmt('corrupt signature time "%s"', [SpanToString(LTime)]);
  if not TryParseTzMinutes(LTz, Result.TzMinutes) then
    Result.TzMinutes := 0;
end;

function GitParseCommit(const AData: TBytes): TGitCommitInfo;
var
  LData, LLine, LVal: TByteSpan;
  LStr: string;
  Sep: SizeInt;
  HeaderLen, MsgOff, Pos, LineEnd: SizeUInt;
  Rel: SizeInt;
  ParentCount: Integer;
begin
  // perf: single TByteSpan view; blank-line split via SpanIndexOfSpan SIMD single source; header lines scanned in place, no SplitLines alloc, only matched values materialize
  LData := TByteSpan.FromBytes(AData);
  Sep := SpanIndexOfSpan(LData, TByteSpan.FromStr(#10#10));
  if Sep >= 0 then
  begin
    HeaderLen := SizeUInt(Sep);
    MsgOff := SizeUInt(Sep) + 2;
  end
  else
  begin
    HeaderLen := LData.Len;
    MsgOff := LData.Len;
  end;
  if MsgOff < LData.Len then
  begin
    LLine.Data := LData.Data + MsgOff;
    LLine.Len := LData.Len - MsgOff;
    Result.Message := SpanToString(LLine);
  end
  else
    Result.Message := '';
  ParentCount := 0;
  SetLength(Result.Parents, 0);
  Pos := 0;
  while Pos < HeaderLen do
  begin
    LLine.Data := LData.Data + Pos;
    LLine.Len := HeaderLen - Pos;
    Rel := SpanIndexOf(LLine, 10);
    if Rel < 0 then
      LineEnd := HeaderLen
    else
      LineEnd := Pos + SizeUInt(Rel);
    LLine.Data := LData.Data + Pos;
    LLine.Len := LineEnd - Pos;
    if Rel < 0 then
      Pos := HeaderLen
    else
      Pos := LineEnd + 1;
    if (LLine.Len = 0) or (LLine.Data[0] = Ord(' ')) then
      Continue;
    if SpanHasPrefix(LLine, 'tree ') then
    begin
      LVal := SpanValueAfter(LLine, 5);
      Result.Tree := GitOidFromHex(SpanToString(LVal));
    end
    else if SpanHasPrefix(LLine, 'parent ') then
    begin
      LVal := SpanValueAfter(LLine, 7);
      LStr := SpanToString(LVal);
      Inc(ParentCount);
      SetLength(Result.Parents, ParentCount);
      Result.Parents[ParentCount - 1] := GitOidFromHex(LStr);
    end
    else if SpanHasPrefix(LLine, 'author ') then
    begin
      LVal := SpanValueAfter(LLine, 7);
      Result.Author := GitParseSignature(SpanToString(LVal));
    end
    else if SpanHasPrefix(LLine, 'committer ') then
    begin
      LVal := SpanValueAfter(LLine, 10);
      Result.Committer := GitParseSignature(SpanToString(LVal));
    end;
  end;
end;

function GitParseTag(const AData: TBytes): TGitTagInfo;
var
  LData, LLine, LVal: TByteSpan;
  Sep: SizeInt;
  HeaderLen, MsgOff, Pos, LineEnd: SizeUInt;
  Rel: SizeInt;
  HaveObject, HaveType, HaveName: Boolean;
begin
  // perf: same zero-copy header scan as GitParseCommit (single view, no SplitLines alloc)
  LData := TByteSpan.FromBytes(AData);
  Sep := SpanIndexOfSpan(LData, TByteSpan.FromStr(#10#10));
  if Sep >= 0 then
  begin
    HeaderLen := SizeUInt(Sep);
    MsgOff := SizeUInt(Sep) + 2;
  end
  else
  begin
    HeaderLen := LData.Len;
    MsgOff := LData.Len;
  end;
  if MsgOff < LData.Len then
  begin
    LLine.Data := LData.Data + MsgOff;
    LLine.Len := LData.Len - MsgOff;
    Result.Message := SpanToString(LLine);
  end
  else
    Result.Message := '';
  Result.HasTagger := False;
  HaveObject := False;
  HaveType := False;
  HaveName := False;
  Pos := 0;
  while Pos < HeaderLen do
  begin
    LLine.Data := LData.Data + Pos;
    LLine.Len := HeaderLen - Pos;
    Rel := SpanIndexOf(LLine, 10);
    if Rel < 0 then
      LineEnd := HeaderLen
    else
      LineEnd := Pos + SizeUInt(Rel);
    LLine.Data := LData.Data + Pos;
    LLine.Len := LineEnd - Pos;
    if Rel < 0 then
      Pos := HeaderLen
    else
      Pos := LineEnd + 1;
    if (LLine.Len = 0) or (LLine.Data[0] = Ord(' ')) then
      Continue;
    if SpanHasPrefix(LLine, 'object ') then
    begin
      LVal := SpanValueAfter(LLine, 7);
      Result.Target := GitOidFromHex(SpanToString(LVal));
      HaveObject := True;
    end
    else if SpanHasPrefix(LLine, 'type ') then
    begin
      // raises for anything outside commit/tree/blob/tag (nested tags ok)
      LVal := SpanValueAfter(LLine, 5);
      Result.TargetKind := GitKindFromString(SpanToString(LVal));
      HaveType := True;
    end
    else if SpanHasPrefix(LLine, 'tag ') then
    begin
      LVal := SpanValueAfter(LLine, 4);
      Result.TagName := SpanToString(LVal);
      HaveName := True;
    end
    else if SpanHasPrefix(LLine, 'tagger ') then
    begin
      LVal := SpanValueAfter(LLine, 7);
      Result.Tagger := GitParseSignature(SpanToString(LVal));
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
