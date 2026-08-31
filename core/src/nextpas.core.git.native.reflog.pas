unit nextpas.core.git.native.reflog;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel;

{ Reflog reader for the native git subfamily.

  File layout is the plain text produced by git's reflog.c:
    <old 40> ' ' <new 40> ' ' <Name> ' <' <Email> '>' ' ' <UnixTime> ' ' <TZ> #9 <Message> LF
  The signature part is parsed by GitParseSignature after stripping the
  leading oid pair. Messages may be empty and may contain tabs internally
  only as the first separator; everything after the first TAB belongs to
  the message. Blank trailing lines are ignored. A missing logs/<ref>
  file is not an error — an empty array is returned so callers can
  distinguish "no reflog" from "corrupt reflog" (the latter raises
  EGitError). }

type
  TGitReflogEntry = record
    OldOid: TGitOid;
    NewOid: TGitOid;
    Committer: TGitSignature;
    Message: string;
  end;
  TGitReflog = array of TGitReflogEntry;

function GitReflogPath(const AGitDir, ARefName: string): string;
function GitReflogExists(const AGitDir, ARefName: string): Boolean;
function GitParseReflogLine(const ALine: string): TGitReflogEntry;
function GitParseReflog(const AData: TBytes): TGitReflog;
function GitReadReflog(const AGitDir, ARefName: string): TGitReflog;

implementation

uses
  nextpas.core.git.native.util;

function GitReflogPath(const AGitDir, ARefName: string): string;
var
  Clean: string;
begin
  Clean := ARefName;
  // strip leading slash if caller passed "/refs/heads/main"
  if (Length(Clean) > 0) and (Clean[1] = '/') then
    Delete(Clean, 1, 1);
  Result := PathJoin([AGitDir, 'logs', Clean]);
end;

function GitReflogExists(const AGitDir, ARefName: string): Boolean;
begin
  Result := FileExists(GitReflogPath(AGitDir, ARefName));
end;

function TrimSpaces(const S: string): string; inline;
begin
  Result := GitTrimSpaces(S);
end;

function GitParseReflogLine(const ALine: string): TGitReflogEntry;
var
  OldHex, NewHex, SigStr, Msg: string;
  TabPos: Integer;
begin
  if Length(ALine) < 82 then
    raise EGitError.CreateFmt('reflog line too short "%s"', [ALine]);
  if ALine[41] <> ' ' then
    raise EGitError.CreateFmt('reflog missing sep after old oid "%s"', [ALine]);
  if ALine[82] <> ' ' then
    raise EGitError.CreateFmt('reflog missing sep after new oid "%s"', [ALine]);
  OldHex := Copy(ALine, 1, 40);
  NewHex := Copy(ALine, 42, 40);
  if not GitOidIsValidHex(OldHex) then
    raise EGitError.CreateFmt('reflog bad old oid "%s"', [OldHex]);
  if not GitOidIsValidHex(NewHex) then
    raise EGitError.CreateFmt('reflog bad new oid "%s"', [NewHex]);
  Result.OldOid := GitOidFromHex(OldHex);
  Result.NewOid := GitOidFromHex(NewHex);
  TabPos := Pos(#9, ALine);
  if TabPos > 0 then
  begin
    SigStr := Copy(ALine, 83, TabPos - 83);
    Msg := Copy(ALine, TabPos + 1, MaxInt);
  end
  else
  begin
    SigStr := Copy(ALine, 83, MaxInt);
    Msg := '';
  end;
  SigStr := TrimSpaces(SigStr);
  if SigStr = '' then
    raise EGitError.CreateFmt('reflog missing signature "%s"', [ALine]);
  Result.Committer := GitParseSignature(SigStr);
  Result.Message := Msg;
end;

function GitParseReflog(const AData: TBytes): TGitReflog;
var
  Text: string;
  Start, I, Count: Integer;
  Line: string;
begin
  Result := nil;
  if Length(AData) = 0 then
    Exit;
  Text := GitBytesToString(AData);
  Count := 0;
  Start := 1;
  for I := 1 to Length(Text) do
    if Text[I] = #10 then
    begin
      Line := Copy(Text, Start, I - Start);
      // strip trailing CR for CRLF safety
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line) - 1);
      if Line <> '' then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := GitParseReflogLine(Line);
        Inc(Count);
      end;
      Start := I + 1;
    end;
  if Start <= Length(Text) then
  begin
    Line := Copy(Text, Start, MaxInt);
    if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
      SetLength(Line, Length(Line) - 1);
    if Line <> '' then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := GitParseReflogLine(Line);
    end;
  end;
end;

function GitReadReflog(const AGitDir, ARefName: string): TGitReflog;
var
  Path: string;
  Data: TBytes;
begin
  Result := nil;
  Path := GitReflogPath(AGitDir, ARefName);
  if not FileExists(Path) then
    Exit;
  Data := ReadFile(Path);
  Result := GitParseReflog(Data);
end;

end.
