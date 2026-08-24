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
 *       The pool is the unified db.pool (G2：v1 TSqlitePool 已退役)。
 *       Writes go through the pool Writer connection (single-writer
 *       semantics); reads via Acquire. Lease release = 置空接口引用
 *       （代理归还，无手工 Release）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.middleware.session,
  nextpas.core.db;

{** @desc Build a sqlite-backed session store. Ensures the session table.
    AMaxAgeMs is the server-side session TTL. ATableName defaults to
    '_sessions' for compatibility with legacy pascn data. }
function NewSqliteSessionStore(APool: TDbPool; const AMaxAgeMs: Int64;
  const ATableName: string = '_sessions'): ISessionStore;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.time;

type
  TSqliteSessionStore = class(TInterfacedObject, ISessionStore)
  private
    FPool: TDbPool;
    FMaxAgeMs: Int64;
    FTableName: string;
    procedure EnsureTable;
  public
    constructor Create(APool: TDbPool; const AMaxAgeMs: Int64;
      const ATableName: string);
    function Load(const AToken: string): TSessionData;
    procedure Save(const AToken: string; AData: TSessionData);
    procedure Delete(const AToken: string);
    procedure CleanupExpired;
  end;

constructor TSqliteSessionStore.Create(APool: TDbPool;
  const AMaxAgeMs: Int64; const ATableName: string);
begin
  inherited Create;
  if APool = nil then
    raise EHttpError.Create(hekArgument, 'nil pool');
  if AMaxAgeMs <= 0 then
    raise EHttpError.Create(hekArgument,
      'AMaxAgeMs must be positive');
  FPool := APool;
  FMaxAgeMs := AMaxAgeMs;
  FTableName := ATableName;
  if FTableName = '' then
    FTableName := '_sessions';
  EnsureTable;
end;

procedure TSqliteSessionStore.EnsureTable;
var
  Conn: IDbConnection;
begin
  Conn := FPool.Writer;
  try
    Conn.Exec(
      'CREATE TABLE IF NOT EXISTS ' + FTableName + ' (' +
      'session_id TEXT PRIMARY KEY, ' +
      'data TEXT NOT NULL, ' +
      'expires_at INTEGER NOT NULL)');
  finally
    Conn := nil;   { 代理归还 = 租约释放 }
  end;
end;

function TSqliteSessionStore.Load(const AToken: string): TSessionData;
var
  Conn: IDbConnection;
  Q: IDbQuery;
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
      Q := nil;
    end;
  finally
    Conn := nil;
  end;
end;

procedure TSqliteSessionStore.Save(const AToken: string; AData: TSessionData);
var
  Conn: IDbConnection;
  Q: IDbQuery;
  ExpiresAt: Int64;
begin
  if AToken = '' then
    Exit;
  ExpiresAt := DateTimeToUnix(DateTimeUtcNow) + (FMaxAgeMs div 1000);
  Conn := FPool.Writer;
  try
    Q := Conn.Query('INSERT OR REPLACE INTO ' + FTableName +
      ' (session_id, data, expires_at) VALUES (?1, ?2, ?3)');
    try
      Q.BindText(1, AToken);
      Q.BindText(2, AData.Serialize);
      Q.BindInt64(3, ExpiresAt);
      Q.Step;
    finally
      Q := nil;
    end;
  finally
    Conn := nil;
  end;
end;

procedure TSqliteSessionStore.Delete(const AToken: string);
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  if AToken = '' then
    Exit;
  Conn := FPool.Writer;
  try
    Q := Conn.Query('DELETE FROM ' + FTableName + ' WHERE session_id = ?1');
    try
      Q.BindText(1, AToken);
      Q.Step;
    finally
      Q := nil;
    end;
  finally
    Conn := nil;
  end;
end;

procedure TSqliteSessionStore.CleanupExpired;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := FPool.Writer;
  try
    Q := Conn.Query('DELETE FROM ' + FTableName + ' WHERE expires_at < ?1');
    try
      Q.BindInt64(1, DateTimeToUnix(DateTimeUtcNow));
      Q.Step;
    finally
      Q := nil;
    end;
  finally
    Conn := nil;
  end;
end;

function NewSqliteSessionStore(APool: TDbPool; const AMaxAgeMs: Int64;
  const ATableName: string): ISessionStore;
begin
  Result := TSqliteSessionStore.Create(APool, AMaxAgeMs, ATableName);
end;

end.
