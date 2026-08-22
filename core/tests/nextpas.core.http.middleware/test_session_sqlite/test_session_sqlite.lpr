program test_session_sqlite;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.db.sqlite,
  nextpas.core.db.sqlite.pool,
  nextpas.core.time,
  nextpas.core.http.middleware.session,
  nextpas.core.http.middleware.session.sqlite;

var
  T: TTestSuite;
  GDbPath: string;

function TempDbPath: string;
begin
  Result := GDbPath;
end;

{ ==== tests ==== }

procedure TestFactoryValidation;
var
  LRaised: Boolean;
  LPool: TSqlitePool;
begin
  LRaised := False;
  try
    NewSqliteSessionStore(nil, 60000);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil pool raises');

  LPool := TSqlitePool.Create(TempDbPath, 1);
  LRaised := False;
  try
    NewSqliteSessionStore(LPool, 0);
  except
    on E: Exception do
      LRaised := True;
  end;
  LPool.Free;
  Check(LRaised, 'non-positive MaxAgeMs raises');
end;

procedure TestTableEnsured;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  Conn: TSqliteDb;
  Q: TSqliteQuery;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    CheckNotNil(LStore, 'factory builds store');
    Conn := LPool.Acquire;
    try
      Q := Conn.Query(
        'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name=''_sessions''');
      try
        Check(Q.Step, 'sqlite_master query steps');
        CheckEqual(Int64(1), Q.GetInt64(0), '_sessions table ensured');
      finally
        Q.Free;
      end;
    finally
      LPool.Release(Conn);
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestSaveLoadRoundTrip;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  LData, LLoaded: TSessionData;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    LData := TSessionData.Create('k-1');
    LData.Put('user_id', 'u-1');
    LData.Put('handle', 'alice');
    LStore.Save('k-1', LData);
    LData.Free;

    LLoaded := LStore.Load('k-1');
    CheckNotNil(LLoaded, 'saved session loads');
    CheckEqual('u-1', LLoaded.Get('user_id'), 'user_id round-trips');
    CheckEqual('alice', LLoaded.Get('handle'), 'second value round-trips');
    CheckEqual('k-1', LLoaded.TokenHash, 'store key preserved on load');
    LLoaded.Free;
  finally
    LPool.Free;
  end;
end;

procedure TestLoadMissingNil;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    Check(LStore.Load('no-such-key') = nil, 'missing key loads nil');
    Check(LStore.Load('') = nil, 'empty key loads nil');
  finally
    LPool.Free;
  end;
end;

procedure TestLoadExpiredNil;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  Conn: TSqliteDb;
  Q: TSqliteQuery;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    Conn := LPool.Writer;
    Q := Conn.Query(
      'INSERT INTO _sessions (session_id, data, expires_at) VALUES (?1, ?2, ?3)');
    try
      Q.BindText(1, 'k-expired');
      Q.BindText(2, '{user_id=u-old}');
      Q.BindInt64(3, DateTimeToUnix(DateTimeUtcNow) - 100);
      Q.Step;
    finally
      Q.Free;
    end;
    Check(LStore.Load('k-expired') = nil,
      'expired row treated as absent');
  finally
    LPool.Free;
  end;
end;

procedure TestCleanupExpired;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  Conn: TSqliteDb;
  Q: TSqliteQuery;
  LData, LLoaded: TSessionData;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    LData := TSessionData.Create('k-valid');
    LData.Put('user_id', 'u-v');
    LStore.Save('k-valid', LData);
    LData.Free;

    Conn := LPool.Writer;
    Q := Conn.Query(
      'INSERT INTO _sessions (session_id, data, expires_at) VALUES (?1, ?2, ?3)');
    try
      Q.BindText(1, 'k-stale');
      Q.BindText(2, '{user_id=u-stale}');
      Q.BindInt64(3, DateTimeToUnix(DateTimeUtcNow) - 100);
      Q.Step;
    finally
      Q.Free;
    end;

    LStore.CleanupExpired;
    Check(LStore.Load('k-stale') = nil, 'expired row reaped');
    LLoaded := LStore.Load('k-valid');
    CheckNotNil(LLoaded, 'valid row survives cleanup');
    CheckEqual('u-v', LLoaded.Get('user_id'), 'valid value intact');
    LLoaded.Free;
  finally
    LPool.Free;
  end;
end;

procedure TestDelete;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  LData, LLoaded: TSessionData;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    LData := TSessionData.Create('k-del');
    LData.Put('user_id', 'u-d');
    LStore.Save('k-del', LData);
    LData.Free;

    LLoaded := LStore.Load('k-del');
    CheckNotNil(LLoaded, 'saved before delete');
    LLoaded.Free;

    LStore.Delete('k-del');
    LLoaded := LStore.Load('k-del');
    Check(LLoaded = nil, 'deleted loads nil');
    LStore.Delete('k-del');
    LStore.Delete('');
    Check(True, 'idempotent delete / empty-key delete do not raise');
  finally
    LPool.Free;
  end;
end;

procedure TestLegacyFormatCompatible;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  Conn: TSqliteDb;
  Q: TSqliteQuery;
  LLoaded: TSessionData;
begin
  { Legacy pascn '_sessions.data' wire format '{k=v\n...}'. }
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000);
    Conn := LPool.Writer;
    Q := Conn.Query(
      'INSERT INTO _sessions (session_id, data, expires_at) VALUES (?1, ?2, ?3)');
    try
      Q.BindText(1, 'k-legacy');
      Q.BindText(2, '{user_id=u-legacy'#10'oauth_state=state-1}');
      Q.BindInt64(3, DateTimeToUnix(DateTimeUtcNow) + 600);
      Q.Step;
    finally
      Q.Free;
    end;
    LLoaded := LStore.Load('k-legacy');
    CheckNotNil(LLoaded, 'legacy row loads');
    CheckEqual('u-legacy', LLoaded.Get('user_id'),
      'legacy user_id parsed');
    CheckEqual('state-1', LLoaded.Get('oauth_state'),
      'legacy oauth_state parsed');
    LLoaded.Free;
  finally
    LPool.Free;
  end;
end;

procedure TestCustomTableName;
var
  LPool: TSqlitePool;
  LStore: ISessionStore;
  Conn: TSqliteDb;
  Q: TSqliteQuery;
begin
  LPool := TSqlitePool.Create(TempDbPath, 1);
  try
    LStore := NewSqliteSessionStore(LPool, 60000, 'my_sessions');
    Conn := LPool.Acquire;
    try
      Q := Conn.Query(
        'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name=''my_sessions''');
      try
        Check(Q.Step, 'sqlite_master query steps');
        CheckEqual(Int64(1), Q.GetInt64(0), 'custom table name used');
      finally
        Q.Free;
      end;
    finally
      LPool.Release(Conn);
    end;
  finally
    LPool.Free;
  end;
end;

begin
  GDbPath := GetTempDir + 'pp888_session_sqlite_test' +
    IntToStr(GetProcessID) + '.db';
  DeleteFile(GDbPath);
  T := TTestSuite.Create('nextpas.core.http.middleware.session.sqlite');
  T.Test('factory validation', @TestFactoryValidation);
  T.Test('table ensured', @TestTableEnsured);
  T.Test('save/load round trip', @TestSaveLoadRoundTrip);
  T.Test('missing key loads nil', @TestLoadMissingNil);
  T.Test('expired row treated as absent', @TestLoadExpiredNil);
  T.Test('CleanupExpired reaps stale rows', @TestCleanupExpired);
  T.Test('delete', @TestDelete);
  T.Test('legacy wire format compatible', @TestLegacyFormatCompatible);
  T.Test('custom table name', @TestCustomTableName);
  if not T.Run then
    Halt(1);
  DeleteFile(GDbPath);
end.
