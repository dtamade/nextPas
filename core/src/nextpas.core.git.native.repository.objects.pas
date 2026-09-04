unit nextpas.core.git.native.repository.objects;

{$I nextpas.core.settings.inc}

{ repository 值对象域: 引用/提交/远端轻量适配类 + 适配器支撑 helpers
  (分支收集/排序/状态映射/行修剪).
  依赖: L0-L1 owner + git.intf/git.base/objmodel + fs/util. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.intf,
  nextpas.core.git.base,
  nextpas.core.git.native.objmodel;

type
  TNativeReference = class(TInterfacedObject, IGitReference)
  private
    FName: string;
    FShort: string;
    FOID: string;
  public
    constructor Create(const AName, AShort, AOIDHex: string);
    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  TNativeCommit = class(TInterfacedObject, IGitCommit)
  private
    FOIDHex: string;
    FInfo: TGitCommitInfo;
  public
    constructor Create(const AOIDHex: string; const AInfo: TGitCommitInfo);
    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;
    function ParentOIDString(AIndex: Integer): string;
  end;

  TNativeRemote = class(TInterfacedObject, IGitRemote)
  private
    FName: string;
    FUrl: string;
  public
    constructor Create(const AName, AUrl: string);
    function Name: string;
    function URL: string;
    function Fetch: Boolean;
  end;

procedure CollectRemoteBranches(const AGitDir: string; var AOut: TStringArray);
procedure SortStrArray(var A: TStringArray);
function MapNativeToFlags(HeadCode, WorkCode: TGitStatusCode): TGitStatusFlags; inline;
function TrimInline(const S: string): string; inline;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.util;

{ TNativeReference }

constructor TNativeReference.Create(const AName, AShort, AOIDHex: string);
begin
  inherited Create;
  FName := AName;
  FShort := AShort;
  FOID := AOIDHex;
end;

function TNativeReference.Name: string;
begin
  Result := FName;
end;

function TNativeReference.ShortName: string;
begin
  Result := FShort;
end;

function TNativeReference.TargetOIDString: string;
begin
  Result := FOID;
end;

function TNativeReference.IsBranch: Boolean;
begin
  Result := Pos('refs/heads/', FName) = 1;
end;

function TNativeReference.IsRemote: Boolean;
begin
  Result := Pos('refs/remotes/', FName) = 1;
end;

function TNativeReference.IsTag: Boolean;
begin
  Result := Pos('refs/tags/', FName) = 1;
end;

{ TNativeCommit }

constructor TNativeCommit.Create(const AOIDHex: string; const AInfo: TGitCommitInfo);
begin
  inherited Create;
  FOIDHex := LowerCase(AOIDHex);
  FInfo := AInfo;
end;

function TNativeCommit.Message: string;
begin
  Result := FInfo.Message;
end;

function TNativeCommit.ShortMessage: string;
var
  P: Integer;
begin
  P := Pos(#10, FInfo.Message);
  if P > 0 then
    Result := Trim(Copy(FInfo.Message, 1, P - 1))
  else
    Result := Trim(FInfo.Message);
end;

function Pad2(AValue: Integer): string; inline;
begin
  if AValue < 10 then
    Result := '0' + IntToStr(AValue)
  else
    Result := IntToStr(AValue);
end;

function FormatSig(const ASig: TGitSignature): string;
var
  Sign: Char;
  AbsM: Integer;
  H, M: Integer;
begin
  AbsM := ASig.TzMinutes;
  if AbsM < 0 then
  begin
    Sign := '-';
    AbsM := -AbsM;
  end
  else
    Sign := '+';
  H := AbsM div 60;
  M := AbsM mod 60;
  Result := ASig.Name + ' <' + ASig.Email + '> ' + IntToStr(ASig.UnixTime) +
    ' ' + Sign + Pad2(H) + Pad2(M);
end;

function TNativeCommit.AuthorString: string;
begin
  Result := FormatSig(FInfo.Author);
end;

function TNativeCommit.CommitterString: string;
begin
  Result := FormatSig(FInfo.Committer);
end;

function TNativeCommit.Time: TDateTime;
begin
  Result := (FInfo.Author.UnixTime / 86400) + 25569;
end;

function TNativeCommit.ParentCount: Integer;
begin
  Result := Length(FInfo.Parents);
end;

function TNativeCommit.OIDString: string;
begin
  Result := FOIDHex;
end;

function TNativeCommit.ParentOIDString(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FInfo.Parents)) then
    Exit('');
  Result := GitOidToHex(FInfo.Parents[AIndex]);
end;

{ TNativeRemote }

constructor TNativeRemote.Create(const AName, AUrl: string);
begin
  inherited Create;
  FName := AName;
  FUrl := AUrl;
end;

function TNativeRemote.Name: string;
begin
  Result := FName;
end;

function TNativeRemote.URL: string;
begin
  Result := FUrl;
end;

function TNativeRemote.Fetch: Boolean;
begin
  Result := False;
end;

procedure CollectRemoteBranches(const AGitDir: string; var AOut: nextpas.core.base.TStringArray);
var
  LCnt: SizeUInt;

  procedure AddUnique(const ARef: string);
  var
    K: Integer;
  begin
    for K := 0 to High(AOut) do
      if AOut[K] = ARef then
        Exit;
    if LCnt >= SizeUInt(Length(AOut)) then
      SetLength(AOut, GrowArrayCapacity(SizeUInt(Length(AOut)), LCnt + 1));
    AOut[LCnt] := ARef;
    Inc(LCnt);
  end;

  procedure Recurse(const ABaseDir, APrefix: string);
  var
    Entries: TDirEntryArray;
    I: Integer;
    Full: string;
  begin
    try
      Entries := ReadDir(ABaseDir);
    except
      Exit;
    end;
    for I := 0 to High(Entries) do
    begin
      Full := PathJoin([ABaseDir, Entries[I].Name]);
      if Entries[I].IsDir then
        Recurse(Full, APrefix + Entries[I].Name + '/')
      else
        AddUnique('refs/remotes/' + APrefix + Entries[I].Name);
    end;
  end;

var
  Lines: TStringArray;
  I, Sp: Integer;
  Line, Name: string;
begin
  LCnt := SizeUInt(Length(AOut));
  try
    Recurse(PathJoin([AGitDir, 'refs', 'remotes']), '');
  except
  end;
  if not FileExists(PathJoin([AGitDir, 'packed-refs'])) then
  begin
    SetLength(AOut, LCnt);
    Exit;
  end;
  try
    Lines := ReadFileLines(PathJoin([AGitDir, 'packed-refs']));
  except
    SetLength(AOut, LCnt);
    Exit;
  end;
  for I := 0 to High(Lines) do
  begin
    Line := Trim(Lines[I]);
    if (Line = '') or (Line[1] = '#') or (Line[1] = '^') then
      Continue;
    Sp := Pos(' ', Line);
    if Sp < 41 then
      Continue;
    Name := Trim(Copy(Line, Sp + 1, MaxInt));
    if Copy(Name, 1, 13) = 'refs/remotes/' then
      AddUnique(Name);
  end;
  SetLength(AOut, LCnt);
end;

procedure SortStrArray(var A: nextpas.core.base.TStringArray);
var
  I, J: Integer;
  T: string;
begin
  for I := 1 to High(A) do
  begin
    J := I;
    while (J > 0) and (A[J - 1] > A[J]) do
    begin
      T := A[J - 1];
      A[J - 1] := A[J];
      A[J] := T;
      Dec(J);
    end;
  end;
end;

function MapNativeToFlags(HeadCode, WorkCode: TGitStatusCode): TGitStatusFlags; inline;
begin
  // single source via base.GitStatusCodesToFlags — inline zero-copy set ops, eliminates dual track mapping
  Result := nextpas.core.git.base.GitStatusCodesToFlags(HeadCode, WorkCode);
end;

function TrimInline(const S: string): string; inline;
begin
  Result := GitTrimSpaces(S);
end;

end.
