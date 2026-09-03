unit nextpas.core.fs.object_store;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.path;

type
  TFsObjectStore = class
  private
    FRoot: string;
    function Resolve(const AKey: string): string;
    procedure AssertSafeKey(const AKey: string);
    function RealMkdirPath(const APath: string): string;
  public
    constructor Create(const ARoot: string);
    procedure EnsureRoot;
    procedure Put(const AKey: string; const AData: string); virtual;
    function Get(const AKey: string): string; virtual;
    procedure Delete(const AKey: string); virtual;
    function Exists(const AKey: string): Boolean; virtual;
  end;

implementation

function TFsObjectStore.Resolve(const AKey: string): string;
begin
  Result := FRoot;
  if Result <> '' then
    Result := Result + '/';
  Result := Result + AKey;
end;

procedure TFsObjectStore.AssertSafeKey(const AKey: string);
var
  I: Integer;
  C: Char;
begin
  if (AKey = '') or (Pos('..', AKey) > 0) or (AKey[1] = '/') then
    raise ENextPasError.Create('unsafe storage key');
  for I := 1 to Length(AKey) do
  begin
    C := AKey[I];
    if not (((C >= 'a') and (C <= 'z')) or
      ((C >= '0') and (C <= '9')) or
      (C = '-') or (C = '_') or (C = '/')) then
      raise ENextPasError.Create('unsafe storage key');
  end;
end;

constructor TFsObjectStore.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := ARoot;
end;

function TFsObjectStore.RealMkdirPath(const APath: string): string;
var
  TmpReal: string;
begin
  if (APath = '/tmp') or (Pos('/tmp/', APath) = 1) then
  begin
    try
      TmpReal := nextpas.core.fs.PathRealPath('/tmp');
    except
      TmpReal := '/tmp';
    end;
    if APath = '/tmp' then
      Result := TmpReal
    else
      Result := TmpReal + Copy(APath, 5, MaxInt);
  end
  else
    Result := APath;
end;

procedure TFsObjectStore.EnsureRoot;
var
  LReal: string;
begin
  if nextpas.core.fs.DirectoryExists(FRoot) then Exit;
  LReal := RealMkdirPath(FRoot);
  if (LReal <> FRoot) and nextpas.core.fs.DirectoryExists(LReal) then Exit;
  if LReal <> FRoot then
    nextpas.core.fs.ForceDirectories(LReal)
  else
    nextpas.core.fs.ForceDirectories(FRoot);
end;

procedure TFsObjectStore.Put(const AKey: string; const AData: string);
var
  FullPath: string;
  LDir, LReal: string;
begin
  AssertSafeKey(AKey);
  FullPath := Resolve(AKey);
  LDir := nextpas.core.path.ExtractFilePath(FullPath);
  if (LDir <> '') and (not nextpas.core.fs.DirectoryExists(LDir)) then
  begin
    LReal := RealMkdirPath(LDir);
    if (LReal <> LDir) and nextpas.core.fs.DirectoryExists(LReal) then
      { real target already exists via symlink }
    else if LReal <> LDir then
      nextpas.core.fs.ForceDirectories(LReal)
    else
      nextpas.core.fs.ForceDirectories(LDir);
  end;
  WriteFileText(FullPath, AData);
end;

function TFsObjectStore.Get(const AKey: string): string;
begin
  AssertSafeKey(AKey);
  Result := ReadFileText(Resolve(AKey));
end;

procedure TFsObjectStore.Delete(const AKey: string);
begin
  AssertSafeKey(AKey);
  nextpas.core.fs.DeleteFile(Resolve(AKey));
end;

function TFsObjectStore.Exists(const AKey: string): Boolean;
begin
  AssertSafeKey(AKey);
  Result := nextpas.core.fs.FileExists(Resolve(AKey));
end;

end.
