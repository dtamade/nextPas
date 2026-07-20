unit nextpas.core.config.watcher;
{**
 * @desc Mutable config file watcher and reload helper.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.config,
  nextpas.core.platform.watch;

type
  TConfigReloadEvent = procedure(ASender: TConfig) of object;

  TConfigWatcher = class
  private
    FConfig: TConfig;
    FFilePath: string;
    FFormat: TConfigFormat;
    FAutoFormat: Boolean;
    FWatcher: TPlatformWatcher;
    FLastMtime: Int64;
    FLastSize: Int64;
    FOnReload: TConfigReloadEvent;
    FActive: Boolean;
    function GetFileMtime: Int64;
    function GetFileStat(out AMtime, ASize: Int64): Boolean;
    procedure DoReload;
    procedure InitWatch(AConfig: TConfig; const AFilePath: string);
  public
    constructor Create(AConfig: TConfig; const AFilePath: string;
      AFormat: TConfigFormat); overload;
    { Extension detect + content sniff on each reload (same as TryLoadFromFile). }
    constructor Create(AConfig: TConfig; const AFilePath: string); overload;
    destructor Destroy; override;
    function CheckReload: Boolean;
    property OnReload: TConfigReloadEvent read FOnReload write FOnReload;
  end;


implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

{ TConfigWatcher }

procedure TConfigWatcher.InitWatch(AConfig: TConfig; const AFilePath: string);
var
  LCanStat: Boolean;
begin
  if AConfig = nil then
    raise ENextPasError.Create('TConfigWatcher requires a config instance');
  if AFilePath = '' then
    raise ENextPasError.Create('TConfigWatcher requires a file path');

  FConfig := AConfig;
  FFilePath := AFilePath;
  FLastMtime := -1;
  FLastSize := -1;
  FillChar(FWatcher, SizeOf(FWatcher), 0);

  LCanStat := GetFileStat(FLastMtime, FLastSize);
  FActive := LCanStat and (platform_watch_create(FWatcher) = 0);
  if FActive then
  begin
    FActive := platform_watch_add(FWatcher, PAnsiChar(FFilePath)) >= 0;
    if not FActive then
      platform_watch_close(FWatcher);
  end;
end;

constructor TConfigWatcher.Create(AConfig: TConfig; const AFilePath: string;
  AFormat: TConfigFormat);
begin
  inherited Create;
  FFormat := AFormat;
  FAutoFormat := False;
  InitWatch(AConfig, AFilePath);
end;

constructor TConfigWatcher.Create(AConfig: TConfig; const AFilePath: string);
begin
  inherited Create;
  FFormat := cfIni;
  FAutoFormat := True;
  InitWatch(AConfig, AFilePath);
end;

destructor TConfigWatcher.Destroy;
begin
  if FActive then
    platform_watch_close(FWatcher);
  inherited Destroy;
end;

function TConfigWatcher.GetFileMtime: Int64;
var
  LSize: Int64;
begin
  if not GetFileStat(Result, LSize) then
    Result := -1;
end;

function TConfigWatcher.GetFileStat(out AMtime, ASize: Int64): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(PAnsiChar(FFilePath), LStat) = 0;
  if Result then
  begin
    AMtime := LStat.ModTime;
    ASize := LStat.Size;
  end
  else
  begin
    AMtime := -1;
    ASize := -1;
  end;
end;

procedure TConfigWatcher.DoReload;
var
  LConfig: TConfig;
  LError: string;
  LOk: Boolean;
begin
  LConfig := TConfig.Create;
  try
    if FAutoFormat then
      LOk := LConfig.TryLoadFromFile(FFilePath, LError)
    else
      LOk := LConfig.TryLoadFromFile(FFilePath, FFormat, LError);
    if not LOk then
      raise EConfigError.Create(LError);
    FConfig.ReplaceFrom(LConfig);
  finally
    LConfig.Free;
  end;
end;

function TConfigWatcher.CheckReload: Boolean;
var
  LEvent: TPlatformWatchEvent;
  LMtime: Int64;
  LSize: Int64;
begin
  Result := False;
  if FActive then
    platform_watch_poll(FWatcher, LEvent, 0);

  if not GetFileStat(LMtime, LSize) then
  begin
    if (FLastMtime >= 0) or (FLastSize >= 0) then
      DoReload;
    Exit;
  end;
  if (LMtime = FLastMtime) and (LSize = FLastSize) then
    Exit;

  DoReload;
  FLastMtime := LMtime;
  FLastSize := LSize;
  if Assigned(FOnReload) then
    FOnReload(FConfig);
  Result := True;
end;


end.
