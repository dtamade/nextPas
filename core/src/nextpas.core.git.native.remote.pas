unit nextpas.core.git.native.remote;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.config;

{ Remote list reader built on top of git-config.

  Git stores remotes as config sections `[remote "<name>"]` with keys
  `url`, `pushurl`, `fetch` (and optionally `push`, `mirror` etc).
  `url` and `fetch` may be repeated; `pushurl` is used when present
  otherwise `url` is the push target as well. The reader groups entries
  by subsection name preserving its case, returns insertion-order remotes,
  and surfaces the first url/fetch as convenience. Missing config yields
  empty array; duplicate remote sections are merged. }

type
  TGitRemote = record
    Name: string;
    Url: string;
    Urls: TStringArray;
    PushUrls: TStringArray;
    FetchSpecs: TStringArray;
  end;
  TGitRemoteArray = array of TGitRemote;

function GitRemoteList(const AGitDir: string): TGitRemoteArray;
function GitRemoteFind(const AGitDir: string; const AName: string; out ARemote: TGitRemote): Boolean;
function GitRemoteCount(const AGitDir: string): Integer; inline;
function GitRemoteUrl(const AGitDir: string; const AName: string): string; inline;

implementation

function ToLowerAscii(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

function FindRemote(var AList: TGitRemoteArray; const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if AList[I].Name = AName then
      Exit(I);
  Result := -1;
end;

function GitRemoteList(const AGitDir: string): TGitRemoteArray;
var
  Cfg: TGitConfig;
  I, Idx: Integer;
  Key, Sec, Sub, K: string;
  Dot1, Dot2: Integer;
  RemName: string;
begin
  Result := nil;
  if not FileExists(GitConfigPath(AGitDir)) then
    Exit;
  Cfg := GitReadConfig(AGitDir);
  for I := 0 to High(Cfg.Entries) do
  begin
    Key := Cfg.Entries[I].Key;
    // Key is already normalized: section.subsection.key or section.key
    // Need to extract section/subsection/key using subsection-aware split:
    // section is lowercased, subsection preserved, key lowercased.
    Dot1 := Pos('.', Key);
    if Dot1 = 0 then Continue;
    Sec := Copy(Key, 1, Dot1 - 1);
    if ToLowerAscii(Sec) <> 'remote' then Continue;
    // find last dot for key
    Dot2 := 0;
    for Idx := Length(Key) downto Dot1 + 1 do
      if Key[Idx] = '.' then
      begin
        Dot2 := Idx;
        Break;
      end;
    if Dot2 = 0 then Continue;
    RemName := Copy(Key, Dot1 + 1, Dot2 - Dot1 - 1);
    K := Copy(Key, Dot2 + 1, MaxInt);
    // K is lowercased already
    Idx := FindRemote(Result, RemName);
    if Idx < 0 then
    begin
      Idx := Length(Result);
      SetLength(Result, Idx + 1);
      Result[Idx].Name := RemName;
      Result[Idx].Url := '';
      Result[Idx].Urls := nil;
      Result[Idx].PushUrls := nil;
      Result[Idx].FetchSpecs := nil;
    end;
    if K = 'url' then
    begin
      SetLength(Result[Idx].Urls, Length(Result[Idx].Urls) + 1);
      Result[Idx].Urls[High(Result[Idx].Urls)] := Cfg.Entries[I].Value;
      if Result[Idx].Url = '' then
        Result[Idx].Url := Cfg.Entries[I].Value;
    end
    else if K = 'pushurl' then
    begin
      SetLength(Result[Idx].PushUrls, Length(Result[Idx].PushUrls) + 1);
      Result[Idx].PushUrls[High(Result[Idx].PushUrls)] := Cfg.Entries[I].Value;
    end
    else if K = 'fetch' then
    begin
      SetLength(Result[Idx].FetchSpecs, Length(Result[Idx].FetchSpecs) + 1);
      Result[Idx].FetchSpecs[High(Result[Idx].FetchSpecs)] := Cfg.Entries[I].Value;
    end;
  end;
end;

function GitRemoteFind(const AGitDir: string; const AName: string; out ARemote: TGitRemote): Boolean;
var
  List: TGitRemoteArray;
  I: Integer;
begin
  List := GitRemoteList(AGitDir);
  for I := 0 to High(List) do
    if List[I].Name = AName then
    begin
      ARemote := List[I];
      Exit(True);
    end;
  Result := False;
  ARemote.Name := '';
  ARemote.Url := '';
  ARemote.Urls := nil;
  ARemote.PushUrls := nil;
  ARemote.FetchSpecs := nil;
end;

function GitRemoteCount(const AGitDir: string): Integer;
begin
  Result := Length(GitRemoteList(AGitDir));
end;

function GitRemoteUrl(const AGitDir: string; const AName: string): string;
var
  R: TGitRemote;
begin
  if not GitRemoteFind(AGitDir, AName, R) then
    raise EGitError.CreateFmt('remote "%s" not found', [AName]);
  if R.Url = '' then
    raise EGitError.CreateFmt('remote "%s" has no url', [AName]);
  Result := R.Url;
end;

end.
