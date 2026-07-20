unit nextpas.core.fs.watch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  TFsWatchEvent = record
    Name: string;  { path-qualified when Wd known (watch base + name) }
    IsDir: Boolean;
    Modified: Boolean;
    Created: Boolean;
    Deleted: Boolean;
  end;

  IFsWatcher = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-200000000010}']
    {** Single path (file or directory); non-recursive. *}
    procedure Add(const APath: string);
    {** Recursive directory tree (Unix; Win may raise UNSUPPORTED via L0).
     *  Does not follow symlink directories. Auto-adds new subdirs under tree. *}
    procedure AddTree(const ARoot: string);
    {** Stop watching a path previously Add/AddTree'd (Go fsnotify.Remove).
     *  Path not watched: no-op. *}
    procedure Remove(const APath: string);
    { True=event; False=timeout. Other errors raise. }
    function Poll(out AEvent: TFsWatchEvent; const ATimeout: TDuration): Boolean;
    procedure Close;
  end;

function NewFsWatcher: IFsWatcher;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.errors,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.platform.error,
  nextpas.core.platform.watch;

type
  TWatchEntry = record
    Wd: Int32;
    Path: string;
    Recursive: Boolean;
  end;

  TWatchEntryArray = array of TWatchEntry;

  TFsWatcher = class(TInterfacedObject, IFsWatcher)
  private
    FWatcher: TPlatformWatcher;
    FClosed: Boolean;
    FEntries: TWatchEntryArray;
    procedure EnsureOpen;
    procedure RegisterWatch(const APath: string; const ARecursive: Boolean);
    function FindByWd(const AWd: Int32; out AIndex: Integer): Boolean;
    function FindByPath(const APath: string; out AIndex: Integer): Boolean;
    procedure QualifyName(const AWd: Int32; const ABaseName: string;
      out AFull: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const APath: string);
    procedure AddTree(const ARoot: string);
    procedure Remove(const APath: string);
    function Poll(out AEvent: TFsWatchEvent; const ATimeout: TDuration): Boolean;
    procedure Close;
  end;

function NewFsWatcher: IFsWatcher;
begin
  Result := TFsWatcher.Create;
end;

constructor TFsWatcher.Create;
var
  LErr: Int32;
begin
  inherited Create;
  FClosed := False;
  SetLength(FEntries, 0);
  LErr := platform_watch_create(FWatcher);
  if LErr <> 0 then
    RaiseFsError(LErr, 'watch_create', '');
end;

destructor TFsWatcher.Destroy;
begin
  if not FClosed then
    platform_watch_close(FWatcher);
  SetLength(FEntries, 0);
  inherited;
end;

procedure TFsWatcher.EnsureOpen;
begin
  if FClosed then
    raise EInvalidOperationError.Create('fs watcher is closed');
end;

function TFsWatcher.FindByWd(const AWd: Int32; out AIndex: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Wd = AWd then
    begin
      AIndex := I;
      Exit(True);
    end;
  AIndex := -1;
  Result := False;
end;

function TFsWatcher.FindByPath(const APath: string;
  out AIndex: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Path = APath then
    begin
      AIndex := I;
      Exit(True);
    end;
  AIndex := -1;
  Result := False;
end;

procedure TFsWatcher.RegisterWatch(const APath: string;
  const ARecursive: Boolean);
var
  LCode: Int32;
  LIdx: Integer;
  LUnused: Integer;
begin
  if FindByPath(APath, LUnused) then
    Exit;
  LCode := platform_watch_add(FWatcher, PAnsiChar(APath));
  if LCode < 0 then
    RaiseFsError(LCode, 'watch_add', APath);
  LIdx := Length(FEntries);
  SetLength(FEntries, LIdx + 1);
  FEntries[LIdx].Wd := LCode;
  FEntries[LIdx].Path := APath;
  FEntries[LIdx].Recursive := ARecursive;
end;

procedure TFsWatcher.QualifyName(const AWd: Int32; const ABaseName: string;
  out AFull: string);
var
  LIdx: Integer;
  LBase: string;
begin
  if FindByWd(AWd, LIdx) then
    LBase := FEntries[LIdx].Path
  else
    LBase := '';
  if ABaseName = '' then
    AFull := LBase
  else if LBase = '' then
    AFull := ABaseName
  else
    AFull := FsPathJoin([LBase, ABaseName]);
end;

procedure TFsWatcher.Add(const APath: string);
begin
  EnsureOpen;
  if APath = '' then
    raise EArgumentError.Create('watch path must not be empty');
  RegisterWatch(APath, False);
end;

procedure TFsWatcher.AddTree(const ARoot: string);
var
  LStack: array of string;
  LTop: Integer;
  LCur, LChild: string;
  LEntries: TDirEntryArray;
  I: Integer;
begin
  EnsureOpen;
  if ARoot = '' then
    raise EArgumentError.Create('watch path must not be empty');
  if not FsIsDir(ARoot) then
    raise EArgumentError.Create('AddTree requires an existing directory: ' + ARoot);

  { Iterative DFS: do not follow symlink directories. }
  SetLength(LStack, 1);
  LStack[0] := ARoot;
  LTop := 0;
  while LTop >= 0 do
  begin
    LCur := LStack[LTop];
    Dec(LTop);
    RegisterWatch(LCur, True);
    LEntries := FsReadDir(LCur);
    for I := 0 to High(LEntries) do
    begin
      if LEntries[I].Name = '.' then
        Continue;
      if LEntries[I].Name = '..' then
        Continue;
      if not LEntries[I].IsDir then
        Continue;
      LChild := FsPathJoin([LCur, LEntries[I].Name]);
      if FsIsSymlink(LChild) then
        Continue;
      Inc(LTop);
      if LTop > High(LStack) then
        SetLength(LStack, Length(LStack) * 2 + 8);
      LStack[LTop] := LChild;
    end;
  end;
end;

procedure TFsWatcher.Remove(const APath: string);
var
  LIdx, I: Integer;
  LErr: Int32;
begin
  EnsureOpen;
  if APath = '' then
    raise EArgumentError.Create('watch path must not be empty');
  if not FindByPath(APath, LIdx) then
    Exit; { not watched — no-op, align fsnotify soft remove }
  LErr := platform_watch_remove(FWatcher, FEntries[LIdx].Wd);
  if LErr <> 0 then
    RaiseFsError(LErr, 'watch_remove', APath);
  for I := LIdx to High(FEntries) - 1 do
    FEntries[I] := FEntries[I + 1];
  SetLength(FEntries, Length(FEntries) - 1);
end;

function TFsWatcher.Poll(out AEvent: TFsWatchEvent;
  const ATimeout: TDuration): Boolean;
var
  LEvt: TPlatformWatchEvent;
  LErr: Int32;
  LMs: Int64;
  LIdx: Integer;
  LChild: string;
  LBaseName: string;
begin
  EnsureOpen;
  AEvent.Name := '';
  AEvent.IsDir := False;
  AEvent.Modified := False;
  AEvent.Created := False;
  AEvent.Deleted := False;
  if ATimeout.IsZero or ATimeout.IsNegative then
    LMs := 0
  else
    LMs := ATimeout.AsMilliseconds;
  LErr := platform_watch_poll(FWatcher, LEvt, LMs);
  if LErr = 0 then
    Exit(False);
  if LErr < 0 then
    RaiseFsError(LErr, 'watch_poll', '');
  LBaseName := string(LEvt.NameStr);
  QualifyName(LEvt.Wd, LBaseName, AEvent.Name);
  AEvent.IsDir := LEvt.IsDir;
  AEvent.Modified := LEvt.Modified;
  AEvent.Created := LEvt.Created;
  AEvent.Deleted := LEvt.Deleted;
  Result := True;

  if AEvent.Created and AEvent.IsDir and FindByWd(LEvt.Wd, LIdx) and
     FEntries[LIdx].Recursive then
  begin
    LChild := AEvent.Name;
    if (LChild <> '') and FsIsDir(LChild) and (not FsIsSymlink(LChild)) then
      RegisterWatch(LChild, True);
  end;
end;

procedure TFsWatcher.Close;
begin
  if FClosed then
    Exit;
  platform_watch_close(FWatcher);
  SetLength(FEntries, 0);
  FClosed := True;
end;

end.
