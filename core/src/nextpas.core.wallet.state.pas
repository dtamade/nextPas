unit nextpas.core.wallet.state;

{ L3 wallet FK state: single source for WalletEnsureForeignKeysOn global Raw cache + lock (state candidate converging impl volume). L1 sync IMutex single lock, per-conn interior mark via IDbForeignKeysControl, Raw=nil single Exec. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.intf;

procedure WalletEnsureForeignKeysOn(const AConn: IDbConnection); inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.base,
  nextpas.core.sync;


var
  GWalletFKRaw: Pointer = nil;
  GWalletFKOn: Boolean = False;
  GWalletFKLock: IMutex = nil;

procedure WalletEnsureForeignKeysOn(const AConn: IDbConnection); inline;
var
  LCtrl: IDbForeignKeysControl;
  LRaw: Pointer;
  LHit: Boolean;
begin
  if (AConn = nil) or (AConn.Kind <> dbkSqlite) then Exit;
  LRaw := AConn.Raw;
  if LRaw = nil then
  begin
    AConn.Exec('PRAGMA foreign_keys = ON');
    Exit;
  end;
  GWalletFKLock.Acquire;
  try
    LHit := (LRaw = GWalletFKRaw) and GWalletFKOn;
  finally
    GWalletFKLock.Release;
  end;
  if LHit then Exit;
  if AConn.QueryInterface(IDbForeignKeysControl, LCtrl) = 0 then
  begin
    if LCtrl.ForeignKeysOn then
    begin
      GWalletFKLock.Acquire;
      try
        GWalletFKRaw := LRaw;
        GWalletFKOn := True;
      finally
        GWalletFKLock.Release;
      end;
      Exit;
    end;
    AConn.Exec('PRAGMA foreign_keys = ON');
    LCtrl.SetForeignKeysOn(True);
    GWalletFKLock.Acquire;
    try
      GWalletFKRaw := LRaw;
      GWalletFKOn := True;
    finally
      GWalletFKLock.Release;
    end;
    Exit;
  end;
  AConn.Exec('PRAGMA foreign_keys = ON');
end;

initialization
  GWalletFKLock := Mutex;

finalization
  GWalletFKLock := nil;

end.
