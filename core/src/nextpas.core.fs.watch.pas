unit nextpas.core.fs.watch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  TFsWatchEvent = record
    Name: string;
    IsDir: Boolean;
    Modified: Boolean;
    Created: Boolean;
    Deleted: Boolean;
  end;

  IFsWatcher = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-200000000010}']
    procedure Add(const APath: string);
    { True=event; False=timeout. Other errors raise. }
    function Poll(out AEvent: TFsWatchEvent; const ATimeout: TDuration): Boolean;
    procedure Close;
  end;

function NewFsWatcher: IFsWatcher;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.errors,
  nextpas.core.platform.error,
  nextpas.core.platform.watch;

type
  TFsWatcher = class(TInterfacedObject, IFsWatcher)
  private
    FWatcher: TPlatformWatcher;
    FClosed: Boolean;
    procedure EnsureOpen;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const APath: string);
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
  LErr := platform_watch_create(FWatcher);
  if LErr <> 0 then
    RaiseFsError(LErr, 'watch_create', '');
end;

destructor TFsWatcher.Destroy;
begin
  if not FClosed then
    platform_watch_close(FWatcher);
  inherited;
end;

procedure TFsWatcher.EnsureOpen;
begin
  if FClosed then
    raise EInvalidOperationError.Create('fs watcher is closed');
end;

procedure TFsWatcher.Add(const APath: string);
var
  LCode: Int32;
begin
  EnsureOpen;
  if APath = '' then
    raise EArgumentError.Create('watch path must not be empty');
  { L0 returns watch descriptor (>=0) on success. Errno values may collide with
    small wds (e.g. EPERM=1); only reject negative codes. Empty path checked above. }
  LCode := platform_watch_add(FWatcher, PAnsiChar(APath));
  if LCode < 0 then
    RaiseFsError(LCode, 'watch_add', APath);
end;

function TFsWatcher.Poll(out AEvent: TFsWatchEvent; const ATimeout: TDuration): Boolean;
var
  LEvt: TPlatformWatchEvent;
  LErr: Int32;
  LMs: Int64;
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
  { L0 contract: 0 = no event/timeout; 1 = event ready (not errno). }
  if LErr = 0 then
    Exit(False);
  if LErr < 0 then
    RaiseFsError(LErr, 'watch_poll', '');
  AEvent.Name := string(LEvt.NameStr);
  AEvent.IsDir := LEvt.IsDir;
  AEvent.Modified := LEvt.Modified;
  AEvent.Created := LEvt.Created;
  AEvent.Deleted := LEvt.Deleted;
  Result := True;
end;

procedure TFsWatcher.Close;
begin
  if FClosed then
    Exit;
  platform_watch_close(FWatcher);
  FClosed := True;
end;

end.
