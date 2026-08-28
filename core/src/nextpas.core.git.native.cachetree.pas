unit nextpas.core.git.native.cachetree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ TREE index extension ("cache tree"): caches directory -> tree oid
  mappings derived from the index so write-tree can skip re-walking.
  Pure format unit — parsing and encoding only; deriving the hierarchy
  from index entries lives in nextpas.core.git.native.index (which owns
  the entry vocabulary and depends on this unit one-way).

  Record grammar mirrors cache-tree.c read_one/write_one (verified
  against real git bytes):
    record ::= <name> NUL <decimal entry-count> ' '
               <decimal subtree-nr> LF
               [ raw-oid ]            { present iff count >= 0 }
               record*                { one per subtree }
  Every record carries a name component; the ROOT record's name is the
  empty string (a bare NUL in the byte stream). entry-count < 0 marks
  an invalidated cache (no oid follows). }

type
  { Name is '' for the root record only; nested records carry exactly
    one path component. The self-referential dynamic array keeps the
    hierarchy heap-backed without pointer ownership concerns. }
  TGitCacheTree = record
    Name: string;
    { index entries covered by this subtree; < 0 = invalidated }
    EntryCount: SizeInt;
    { meaningful only when EntryCount >= 0 }
    Oid: TGitOid;
    Children: array of TGitCacheTree;
  end;

{ raises EGitError on truncated or malformed payloads; rejects trailing
  bytes after the root record }
function GitParseCacheTree(const AData: TBytes): TGitCacheTree;

{ two-pass exact-size single-fill encoding, byte-compatible with git }
function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes;

implementation

const
  CDigitZero = Ord('0');

function AsciiPart(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PChar(AText)^, Result[0], Length(AText));
end;

{ minimal decimal rendering including negatives (-1 sentinel) }
function DecimalText(AValue: SizeInt): string;
var
  Negative: Boolean;
  Digits: string;
begin
  if AValue = 0 then
    Exit('0');
  Negative := AValue < 0;
  Digits := '';
  while AValue <> 0 do
  begin
    Digits := Digits + Chr(CDigitZero + Abs(AValue) mod 10);
    AValue := AValue div 10;
  end;
  Result := '';
  while Length(Digits) > 0 do
  begin
    Result := Result + Digits[Length(Digits)];
    Delete(Digits, Length(Digits), 1);
  end;
  if Negative then
    Result := '-' + Result;
end;

procedure Need(const AData: TBytes; APos, ACount: SizeInt);
begin
  if (APos < 0) or (ACount < 0) or (APos + ACount > Length(AData)) then
    raise EGitError.Create('truncated cache-tree extension');
end;

{ signed decimal digits at APos terminated by ADelimiter; advances past
  the delimiter }
function ParseCount(const AData: TBytes; var APos: SizeInt;
  ADelimiter: Byte; const AWhat: string): SizeInt;
var
  Negative: Boolean;
  Value: SizeInt;
begin
  Negative := False;
  Need(AData, APos, 1);
  if AData[APos] = Ord('-') then
  begin
    Negative := True;
    Inc(APos);
  end;
  Need(AData, APos, 1);
  if (AData[APos] < CDigitZero) or (AData[APos] > CDigitZero + 9) then
    raise EGitError.CreateFmt('malformed cache-tree %s', [AWhat]);
  Value := 0;
  while (APos <= High(AData)) and (AData[APos] >= CDigitZero)
    and (AData[APos] <= CDigitZero + 9) do
  begin
    Value := Value * 10 + (AData[APos] - CDigitZero);
    Inc(APos);
  end;
  Need(AData, APos, 1);
  if AData[APos] <> ADelimiter then
    raise EGitError.CreateFmt('malformed cache-tree %s', [AWhat]);
  Inc(APos);
  if Negative then
    Result := -Value
  else
    Result := Value;
end;

{ AWithName is False for the root record (it carries no name in the
  byte stream); every nested record emits its Name plus a NUL first }
procedure ParseRecord(const AData: TBytes; var APos: SizeInt;
  out ATree: TGitCacheTree);
var
  SubtreeNr, I, NameStart: SizeInt;
begin
  ATree := Default(TGitCacheTree);
  // every record starts with its name component; the root's is empty
  NameStart := APos;
  while (APos <= High(AData)) and (AData[APos] <> 0) do
    Inc(APos);
  Need(AData, APos, 1);
  SetLength(ATree.Name, APos - NameStart);
  if APos > NameStart then
    Move(AData[NameStart], ATree.Name[1], APos - NameStart);
  Inc(APos); // the NUL terminator
  ATree.EntryCount := ParseCount(AData, APos, Ord(' '), 'entry count');
  SubtreeNr := ParseCount(AData, APos, 10, 'subtree count');
  if SubtreeNr < 0 then
    raise EGitError.Create('negative cache-tree subtree count');
  if ATree.EntryCount >= 0 then
  begin
    Need(AData, APos, GitOidRawLen);
    Move(AData[APos], ATree.Oid.Bytes[0], GitOidRawLen);
    Inc(APos, GitOidRawLen);
  end;
  SetLength(ATree.Children, SubtreeNr);
  for I := 0 to SubtreeNr - 1 do
    ParseRecord(AData, APos, ATree.Children[I]);
end;

{ ── write side: measure pass then single fill ──────────────────────────── }

{ the root's empty name still emits its bare NUL, matching git }
function EncodedHeadLength(ATree: TGitCacheTree): SizeInt;
begin
  Result := Length(ATree.Name) + 1 { NUL }
    + Length(DecimalText(ATree.EntryCount))
    + 1 { space } + Length(DecimalText(Length(ATree.Children)))
    + 1 { LF };
end;

function RecordEncodedSize(ATree: TGitCacheTree): SizeInt;
var
  I: SizeInt;
begin
  Result := EncodedHeadLength(ATree);
  if ATree.EntryCount >= 0 then
    Inc(Result, GitOidRawLen);
  for I := 0 to High(ATree.Children) do
    Inc(Result, RecordEncodedSize(ATree.Children[I]));
end;

procedure FillRecord(var ABuf: TBytes; var APos: SizeInt;
  const ATree: TGitCacheTree);
var
  Head: TBytes;
  I: SizeInt;
begin
  Head := AsciiPart(ATree.Name + #0);
  Move(Head[0], ABuf[APos], Length(Head));
  Inc(APos, Length(Head));
  Head := AsciiPart(DecimalText(ATree.EntryCount) + ' '
    + DecimalText(Length(ATree.Children)) + #10);
  Move(Head[0], ABuf[APos], Length(Head));
  Inc(APos, Length(Head));
  if ATree.EntryCount >= 0 then
  begin
    Move(ATree.Oid.Bytes[0], ABuf[APos], GitOidRawLen);
    Inc(APos, GitOidRawLen);
  end;
  for I := 0 to High(ATree.Children) do
    FillRecord(ABuf, APos, ATree.Children[I]);
end;

function GitParseCacheTree(const AData: TBytes): TGitCacheTree;
var
  P: SizeInt;
begin
  if Length(AData) = 0 then
    raise EGitError.Create('empty cache-tree extension');
  P := 0;
  ParseRecord(AData, P, Result);
  if P <> Length(AData) then
    raise EGitError.Create('trailing bytes after cache-tree root');
end;

function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes;
var
  Pos_: SizeInt;
begin
  SetLength(Result, RecordEncodedSize(ATree));
  Pos_ := 0;
  FillRecord(Result, Pos_, ATree);
end;

end.
