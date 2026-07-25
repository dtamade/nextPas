{ nextpas.core.test.snapshot — L1 snapshot compare (shared by check + expect)
  =========================================================
  Depends on: base, config, diff, fs, platform.env — not on check/expect/output. }

unit nextpas.core.test.snapshot;

{$I nextpas.core.settings.inc}

interface

{ Assert AActual matches snapshot file ASnapshotDir/ASnapshotName.
  Missing file: create (or fail if NEXTPAS_SNAPSHOT_FAIL_ON_CREATE=1).
  Mismatch: fail with ColorDiff unless NEXTPAS_UPDATE_SNAPSHOTS=1. }
procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);

implementation

uses
  nextpas.core.system,
  nextpas.core.platform.env,
  nextpas.core.fs,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.diff;

type
  TSnapReadStatus = (srsFound, srsNotFound, srsReadError);

function SnapRead(const APath: string; out AContents: string;
  out AStatus: TSnapReadStatus): Boolean;
begin
  if not FileExists(APath) then
  begin
    AContents := '';
    AStatus := srsNotFound;
    Exit(False);
  end;
  try
    AContents := ReadFileText(APath);
    AStatus := srsFound;
    Result := True;
  except
    on E: Exception do
    begin
      AContents := '';
      AStatus := srsReadError;
      Result := False;
    end;
  end;
end;

procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);
var
  LPath, LExisting: string;
  LShouldUpdate: Boolean;
  LDirCreated: Boolean;
  LStatus: TSnapReadStatus;
begin
  LPath := ASnapshotDir + DirectorySeparator + ASnapshotName;
  LShouldUpdate := platform_env_get_str('NEXTPAS_UPDATE_SNAPSHOTS') = '1';
  SnapRead(LPath, LExisting, LStatus);
  case LStatus of
    srsFound:
    begin
      if LShouldUpdate then
      begin
        WriteFileText(LPath, AActual);
        Exit;
      end;
      if AActual <> LExisting then
        InternalFail('Snapshot mismatch: ' + LPath +
          ' (set NEXTPAS_UPDATE_SNAPSHOTS=1 to update)' + #10 +
          ColorDiff(LExisting, AActual, DefaultConfig));
    end;
    srsNotFound:
    begin
      if platform_env_get_str('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE') = '1' then
        InternalFail('CheckSnapshot: snapshot does not exist: ' + LPath +
          ' (remove NEXTPAS_SNAPSHOT_FAIL_ON_CREATE to auto-create)');
      LDirCreated := ForceDirectories(ASnapshotDir);
      if not LDirCreated then
        InternalFail('CheckSnapshot: cannot create directory ' + ASnapshotDir);
      WriteFileText(LPath, AActual);
    end;
    srsReadError:
      InternalFail('CheckSnapshot: file exists but cannot be read: ' + LPath);
  end;
end;

end.
