unit nextpas.core.http.middleware.session.sqlite;

{**
 * @desc SQLite-backed ISessionStore for nextpas.core.http.middleware.session.
 *
 *       Schema (compatible with the legacy '_sessions' table used by pascn):
 *         CREATE TABLE <table> (
 *           session_id TEXT PRIMARY KEY,   -- store key (hashed token)
 *           data       TEXT NOT NULL,      -- TSessionData.Serialize wire format
 *           expires_at INTEGER NOT NULL    -- unix seconds
 *         )
 *
 *       The table is ensured (CREATE TABLE IF NOT EXISTS) by the factory, so
 *       an invalid pool fails fast at wiring time. Expired rows are treated
 *       as absent by Load and reaped by CleanupExpired (application
 *       maintenance loop).
 *
 *       Usage:
 *         LOpts.Store := NewSqliteSessionStore(FPool, 30 * 60 * 1000);
 *       Writes go through the pool Writer connection (single-writer
 *       semantics); reads via Acquire/Release.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.middleware.session,
  nextpas.core.db.sqlite.pool;

{** @desc Build a sqlite-backed session store. Ensures the session table.
   AMaxAgeMs is the server-side session TTL. ATableName defaults to
   '_sessions' for compatibility with legacy pascn data. }
function NewSqliteSessionStore(APool: TSqlitePool; const AMaxAgeMs: Int64;
  const ATableName: string = '_sessions'): ISessionStore;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.db.sqlite,
  nextpas.core.time;

type
  TSqliteSessionStore = class(TInterfacedObject, ISessionStore)
  private
    FPool: TSqlitePool;
    FMaxAgeMs: Int64;
    FTableName: string;
    procedure EnsureTable;
  public
    constructor Create(APool: TSqlitePool; const AMaxAgeMs: Int64;
      const ATableName: string);
    function Load(const AToken: string): TSessionData;
    procedure Save(const AToken: string; AData: TSessionData);
    procedure Delete(const AToken: string);
    procedure CleanupExpired;
  end;

constructor TSqliteSessionStore.Create(APool: TSqlitePool;
  const AMaxAgeMs: Int64; const ATableName: string);
begin
  inherited Create;
  FPool := APool;
  FMaxAgeMs := AMaxAgeMs;
  FTableName := ATableName;
  if FTableName = '' then
    FTableName := '_sessions';
  EnsureTable;
end;

procedure TSqliteSessionStore.EnsureTable;
var
  Conn: TSqliteDb;
begin
  Conn := FPool.Writer;
  Conn.Exec(
    'CREATE TABLE IF NOT EXISTS ' + FTableName + ' (' +
    'session_id TEXT PRIMARY KEY, ' +
    'data TEXT NOT NULL, ' +
    'expires_at INTEGER NOT NULL)');
end;

function TSqliteSessionStore.Load(const AToken: string): TSessionData;
var
  Conn: TSqliteDb;
  Q: TSqliteQuery;
  DataText: string;
  ExpiresAt: Int64;
begin
  Result := nil;
  if AToken = '' then
    Exit;
  Conn := FPool.Acquire;
  try
    Q := Conn.Query('SELECT data, expires_at FROM ' + FTableName +
      ' WHERE session_id = ?1');
    try
      Q.BindText(1, AToken);
      if Q.Step then
      begin
        DataText := Q.GetText(0);
        ExpiresAt := Q.GetInt64(1);
        if ExpiresAt <= 0 then
          Exit;
        if DateTimeToUnix(DateTimeUtcNow) >= ExpiresAt then
          Exit;
        Result := TSessionData.Deserialize(DataText, AToken);
      end;
    finally
      Q.Free;
    end;
  finally
    FPool.Release(Conn);
  end;
end;

procedure TSqliteSessionStore.Save(const AToken: string; AData: TSessionData);
var
  Conn: TSqliteDb;
  Q: TSqliteQuery;
  ExpiresAt: Int64;
begin
  if AToken = '' then
    Exit;
  ExpiresAt := DateTimeToUnix(DateTimeUtcNow) + (FMaxAgeMs div 1000);
  Conn := FPool.Writer;
  Q := Conn.Query('INSERT OR REPLACE INTO ' + FTableName +
    ' (session_id, data, expires_at) VALUES (?1, ?2, ?3)');
  try
    Q.BindText(1, AToken);
    Q.BindText(2, AData.Serialize);
    Q.BindInt64(3, ExpiresAt);
    Q.Step;
  finally
    Q.Free;
  end;
end;

procedure TSqliteSessionStore.Delete(const AToken: string);
var
  Conn: TSqliteDb;
  Q: TSqliteQuery;
begin
  if AToken = '' then
    Exit;
  Conn := FPool.Writer;
  Q := Conn.Query('DELETE FROM ' + FTableName + ' WHERE session_id = ?1');
  try
    Q.BindText(1, AToken);
    Q.Step;
  finally
    Q.Free;
  end;
end;

procedure TSqliteSessionStore.CleanupExpired;
var
  Conn: TSqliteDb;
  Q: TSqliteQuery;
begin
  Conn := FPool.Writer;
  Q := Conn.Query('DELETE FROM ' + FTableName + ' WHERE expires_at < ?1');
  try
    Q.BindInt64(1, DateTimeToUnix(DateTimeUtcNow));
    Q.Step;
  finally
    Q.Free;
  end;
end;

function NewSqliteSessionStore(APool: TSqlitePool; const AMaxAgeMs: Int64;
  const ATableName: string): ISessionStore;
begin
  if APool = nil then
    raise EHttpError.Create(hekArgument,
      'sqlite session store requires a pool');
  if AMaxAgeMs <= 0 then
    raise EHttpError.Create(hekArgument,
      'sqlite session store requires MaxAgeMs > 0');
  Result := TSqliteSessionStore.Create(APool, AMaxAgeMs, ATableName);
end;

end.
