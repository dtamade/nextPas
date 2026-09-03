unit nextpas.core.wallet.impl;

{ L3 wallet impl: base←intf←impl←facade, Owner=wallet lane; single source wallet.impl (see wallet/CONTRACT.md §0). State converged to wallet.state (FK Raw cache+lock), stream converged to wallet.stream (ledger iterator reuse). Infra via L0-L2 strict (pool/migrate L2, no L3→L3). bytes.ops single source inline/zero-copy. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db.migrate,
  nextpas.core.db.pool,
  nextpas.core.wallet.base,
  nextpas.core.wallet.intf;

function WalletMakeMigrations: TDbMigrations;
function WalletFullMigrations: TDbMigrations;
function WalletMigrateAll(const AConn: IDbConnection): Integer; overload;
function WalletMigrateAll(const APool: TDbPool): Integer; overload;

function WalletIsIdentityReady(const AConn: IDbConnection): Boolean; overload;
function WalletIsIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity): Boolean; overload;
procedure WalletRequireIdentityReady(const AConn: IDbConnection); overload;
procedure WalletRequireIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity); overload;

function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance;
function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64;
function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode;
function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode;
function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64; overload;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AMembership: IWalletMembership): Int64; overload;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AIsMember: TWalletMembershipCheck; const AJoin: TWalletMembershipJoin): Int64; overload;
function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.id.uuid,
  nextpas.core.time,
  nextpas.core.time.iso8601,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.timezone,
  nextpas.core.text.utils,
  nextpas.core.text.conv,
  nextpas.core.db.intf,
  nextpas.core.identity,
  nextpas.core.identity.base,
  nextpas.core.wallet.state,
  nextpas.core.wallet.stream;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: wallet must reuse bytes.ops'}
{$IFEND}

type
  TWalletTxnBody = procedure(const AConn: IDbConnection; AData: Pointer);

procedure WalletWithWriterTxn(const APool: TDbPool; const ABody: TWalletTxnBody; AData: Pointer);
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
begin
  if not Assigned(ABody) then
    raise EDbError.CreateSimple(dbkUnknown, 'wallet: nil txn body');
  Conn := APool.Writer;
  WalletEnsureForeignKeysOn(Conn);
  WalletRequireIdentityReady(Conn);
  Conn.QueryInterface(IDbTxControl, Tx);
  Tx.BeginTxn(False);
  try
    try
      ABody(Conn, AData);
      Tx.CommitTxn;
    except
      try Tx.RollbackTxn; except end;
      raise;
    end;
  finally
    Tx := nil;
    Conn := nil;
  end;
end;

function TryISO8601ToUnixNanos(const AStr: string; out ANanos: Int64): Boolean; inline;
var
  LOff: TOffsetDateTime;
  LNaive: TNaiveDateTime;
begin
  if TryParseISO8601DateTimeOffset(AStr, LOff) then
  begin
    ANanos := LOff.ToUnixNanos;
    Exit(True);
  end;
  if TryParseISO8601DateTime(AStr, LNaive) then
  begin
    ANanos := TOffsetDateTime.Create(LNaive, TUtcOffset.UTC).ToUnixNanos;
    Exit(True);
  end;
  Result := False;
end;

function IsISO8601Expired(const AExpiresAt: string): Boolean; inline;
var
  LNs: Int64;
begin
  if AExpiresAt = '' then Exit(False);
  if TryISO8601ToUnixNanos(AExpiresAt, LNs) then
    Exit(LNs < TOffsetDateTime.NowUtc.ToUnixNanos);
  Result := True;
end;

const
  WALLET_SQLITE_NOW_EXPR = 'strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')';
  WALLET_DDL_BALANCES = 'create table if not exists wallet_balances ( user_id text primary key references ' + IDENTITY_USER_PROFILES_TABLE + '(id) on delete cascade, balance_cents integer not null default 0 check (balance_cents >= 0), updated_at text not null default (' + WALLET_SQLITE_NOW_EXPR + ') );';
  WALLET_DDL_LEDGER = 'create table if not exists wallet_ledger ( id text primary key, user_id text not null references ' + IDENTITY_USER_PROFILES_TABLE + '(id) on delete cascade, delta_cents integer not null, reason text not null, ref_id text, created_at text not null default (' + WALLET_SQLITE_NOW_EXPR + ') );';
  WALLET_DDL_LEDGER_IDX = 'create index if not exists idx_wallet_ledger_user on wallet_ledger(user_id, created_at desc, id desc);';
  WALLET_DDL_REDEEM_CODES = 'create table if not exists redeem_codes ( code text primary key, total_cents integer not null check (total_cents > 0), remaining_uses integer not null check (remaining_uses >= 0), max_uses integer not null check (max_uses > 0), expires_at text, created_at text not null default (' + WALLET_SQLITE_NOW_EXPR + ') );';
  WALLET_DDL_REDEEM_REDEMPTIONS = 'create table if not exists redeem_redemptions ( code text not null references redeem_codes(code) on delete cascade, user_id text not null references ' + IDENTITY_USER_PROFILES_TABLE + '(id) on delete cascade, redeemed_at text not null default (' + WALLET_SQLITE_NOW_EXPR + '), primary key (code, user_id) );';
  WALLET_LIST_SQL = 'SELECT id, user_id, delta_cents, reason, coalesce(ref_id,''''), created_at FROM wallet_ledger WHERE user_id = ?1 ORDER BY created_at DESC, id DESC LIMIT ?2';
  WALLET_LIST_SQL_CURSOR = 'SELECT id, user_id, delta_cents, reason, coalesce(ref_id,''''), created_at FROM wallet_ledger WHERE user_id = ?1 AND ((SELECT created_at FROM wallet_ledger WHERE id = ?2 AND user_id = ?1) IS NULL OR (created_at, id) < (SELECT created_at, id FROM wallet_ledger WHERE id = ?2 AND user_id = ?1)) ORDER BY created_at DESC, id DESC LIMIT ?3';

function WalletMakeMigrations: TDbMigrations;
begin
  {$IF IDENTITY_USER_PROFILES_TABLE <> 'user_profiles'}
    {$FATAL 'identity table drift: wallet FK must follow identity.base'}
  {$IFEND}
  Result := MakeMigrations([
    TDbMigration.Create(WALLET_MIGRATION_VERSION, [
      WALLET_DDL_BALANCES,
      WALLET_DDL_LEDGER,
      WALLET_DDL_LEDGER_IDX,
      WALLET_DDL_REDEEM_CODES,
      WALLET_DDL_REDEEM_REDEMPTIONS
    ])
  ]);
end;

function WalletFullMigrations: TDbMigrations;
var
  IM, WM: TDbMigrations;
  I: Integer;
begin
  IM := IdentityMakeMigrations;
  WM := WalletMakeMigrations;
  SetLength(Result, Length(IM) + Length(WM));
  for I := 0 to High(IM) do Result[I] := IM[I];
  for I := 0 to High(WM) do Result[Length(IM) + I] := WM[I];
end;

function WalletMigrateAll(const AConn: IDbConnection): Integer;
begin
  WalletEnsureForeignKeysOn(AConn);
  Result := 0;
  Result := Result + Migrate(AConn, IdentityMakeMigrations);
  Result := Result + Migrate(AConn, WalletMakeMigrations);
end;

function WalletMigrateAll(const APool: TDbPool): Integer;
var
  Conn: IDbConnection;
begin
  Conn := APool.Writer;
  try
    WalletEnsureForeignKeysOn(Conn);
    Result := WalletMigrateAll(Conn);
  finally
    Conn := nil;
  end;
end;

type
  TDefaultWalletIdentity = class(TInterfacedObject, IWalletIdentity)
  public
    function IsReady(const AConn: IDbConnection): Boolean;
    function UserExists(const AConn: IDbConnection; const AUserId: string): Boolean;
  end;

function TDefaultWalletIdentity.IsReady(const AConn: IDbConnection): Boolean;
var
  Q: IDbQuery;
begin
  Result := False;
  if AConn = nil then Exit;
  try
    Q := AConn.Query('SELECT 1 FROM ' + IDENTITY_USER_PROFILES_TABLE + ' LIMIT 1');
    Result := True;
    Q := nil;
  except
    on E: EDbError do
      if E.Category = decSyntax then Result := False else raise;
  end;
end;

function TDefaultWalletIdentity.UserExists(const AConn: IDbConnection; const AUserId: string): Boolean;
var
  Q: IDbQuery;
begin
  Result := False;
  if (AConn = nil) or (AUserId = '') then Exit;
  try
    Q := AConn.Query('SELECT 1 FROM ' + IDENTITY_USER_PROFILES_TABLE + ' WHERE id = ?1 LIMIT 1');
    Q.BindText(1, AUserId);
    Result := Q.Step;
  except
    on E: EDbError do
      if E.Category = decSyntax then Result := False else raise;
  end;
end;

function WalletIsIdentityReady(const AConn: IDbConnection): Boolean;
var
  LProbe: IWalletIdentity;
begin
  LProbe := TDefaultWalletIdentity.Create;
  Result := LProbe.IsReady(AConn);
end;

function WalletIsIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity): Boolean;
begin
  if AIdentity <> nil then
    Result := AIdentity.IsReady(AConn)
  else
    Result := WalletIsIdentityReady(AConn);
end;

procedure WalletRequireIdentityReady(const AConn: IDbConnection);
begin
  if not WalletIsIdentityReady(AConn) then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckForeignKey,
      'identity migration required: ' + IDENTITY_USER_PROFILES_TABLE + ' missing; deploy IdentityMakeMigrations v14 before WalletMakeMigrations v15');
end;

procedure WalletRequireIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity);
begin
  if not WalletIsIdentityReady(AConn, AIdentity) then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckForeignKey,
      'identity migration required: ' + IDENTITY_USER_PROFILES_TABLE + ' missing; deploy IdentityMakeMigrations v14 before WalletMakeMigrations v15');
end;

function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Result := Default(TWalletBalance);
  Result.UserId := AUserId;
  Result.BalanceCents := 0;
  if AUserId = '' then Exit;
  Conn := APool.Acquire;
  WalletRequireIdentityReady(Conn);
  try
    Q := Conn.Query('SELECT balance_cents, updated_at FROM wallet_balances WHERE user_id = ?1');
    Q.BindText(1, AUserId);
    if Q.Step then
    begin
      Result.BalanceCents := Q.GetInt64(0);
      Result.UpdatedAt := Q.GetText(1);
    end;
  finally
    Q := nil;
    Conn := nil;
  end;
end;

type
  PWalletAdjustCtx = ^TWalletAdjustCtx;
  TWalletAdjustCtx = record
    UserId: string;
    Delta: Int64;
    Reason: string;
    RefId: string;
    NewBal: PInt64;
  end;

procedure WalletAdjustBody(const AConn: IDbConnection; AData: Pointer);
var
  Ctx: PWalletAdjustCtx;
  Q: IDbQuery;
begin
  Ctx := PWalletAdjustCtx(AData);
  Q := AConn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
  Q.BindText(1, Ctx.UserId);
  Q.Step;
  Q := AConn.Query('UPDATE wallet_balances SET balance_cents = balance_cents + ?2, updated_at = ' + WALLET_SQLITE_NOW_EXPR + ' WHERE user_id = ?1 AND balance_cents + ?2 >= 0 RETURNING balance_cents');
  Q.BindText(1, Ctx.UserId);
  Q.BindInt64(2, Ctx.Delta);
  if not Q.Step then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'insufficient balance');
  Ctx.NewBal^ := Q.GetInt64(0);
  Q := AConn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
  Q.BindText(1, UUIDv7);
  Q.BindText(2, Ctx.UserId);
  Q.BindInt64(3, Ctx.Delta);
  Q.BindText(4, Ctx.Reason);
  Q.BindText(5, Ctx.RefId);
  Q.Step;
end;

function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64;
var
  NewBal: Int64;
  Ctx: TWalletAdjustCtx;
begin
  NewBal := 0;
  Ctx.UserId := AUserId;
  Ctx.Delta := ADelta;
  Ctx.Reason := AReason;
  Ctx.RefId := ARefId;
  Ctx.NewBal := @NewBal;
  WalletWithWriterTxn(APool, @WalletAdjustBody, @Ctx);
  Result := NewBal;
end;

function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  LCode: string;
begin
  Result := Default(TRedeemCode);
  LCode := Trim(ACode);
  if LCode = '' then Exit;
  Conn := APool.Acquire;
  try
    Q := Conn.Query('SELECT code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at FROM redeem_codes WHERE code = ?1');
    Q.BindText(1, LCode);
    if Q.Step then
    begin
      Result.Code := Q.GetText(0);
      Result.TotalCents := Q.GetInt64(1);
      Result.RemainingUses := Q.GetInt64(2);
      Result.MaxUses := Q.GetInt64(3);
      Result.ExpiresAt := Q.GetText(4);
      Result.CreatedAt := Q.GetText(5);
    end;
  finally
    Q := nil;
    Conn := nil;
  end;
end;

function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  LCode: string;
  LNs: Int64;
begin
  Result := Default(TRedeemCode);
  LCode := Trim(ACode);
  if LCode = '' then raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckNotNull, 'code required');
  if AExpiresAt <> '' then
  begin
    if not TryISO8601ToUnixNanos(AExpiresAt, LNs) then
      raise EDbError.CreateWithCategory(dbkUnknown, decSyntax, dckNone, 'invalid expires_at');
  end;
  Conn := APool.Writer;
  WalletEnsureForeignKeysOn(Conn);
  try
    if AExpiresAt = '' then
    begin
      Q := Conn.Query('INSERT INTO redeem_codes (code, total_cents, remaining_uses, max_uses) VALUES (?1, ?2, ?3, ?4) RETURNING code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at');
      Q.BindText(1, LCode);
      Q.BindInt64(2, ATotalCents);
      Q.BindInt64(3, AMaxUses);
      Q.BindInt64(4, AMaxUses);
    end
    else
    begin
      Q := Conn.Query('INSERT INTO redeem_codes (code, total_cents, remaining_uses, max_uses, expires_at) VALUES (?1, ?2, ?3, ?4, ?5) RETURNING code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at');
      Q.BindText(1, LCode);
      Q.BindInt64(2, ATotalCents);
      Q.BindInt64(3, AMaxUses);
      Q.BindInt64(4, AMaxUses);
      Q.BindText(5, AExpiresAt);
    end;
    try
      if not Q.Step then raise EDbError.CreateWithCategory(dbkUnknown, decUnknown, dckNone, 'insert failed');
    except
      on E: EDbError do
      begin
        if (E.Category = decConstraint) and (E.Constraint in [dckUnique, dckPrimaryKey]) then
        begin
          case E.Backend of
            dbkSqlite: raise NewDbErrorSqlite(E.BackendCode, E.ExtendedCode, decConstraint, dckUnique, 'duplicate code');
            dbkPostgres: raise NewDbErrorPgEx(E.SqlState, E.Severity, E.Detail, 'duplicate code', decConstraint, dckUnique, E.SchemaName, E.TableName, E.ColumnName);
            dbkMysql: raise NewDbErrorMy(E.BackendCode, E.SqlState, 'duplicate code', decConstraint, dckUnique);
            dbkOdbc: raise NewDbErrorOdbc(E.BackendCode, E.SqlState, 'duplicate code', decConstraint, dckUnique);
            dbkRedis: raise NewDbErrorRedis(E.SqlState, 'duplicate code', decConstraint, dckUnique);
            dbkDm: raise NewDbErrorDm(E.BackendCode, E.SqlState, 'duplicate code', decConstraint, dckUnique);
          else
            raise EDbError.CreateWithCategory(E.Backend, decConstraint, dckUnique, 'duplicate code');
          end;
        end;
        raise;
      end;
    end;
    Result.Code := Q.GetText(0);
    Result.TotalCents := Q.GetInt64(1);
    Result.RemainingUses := Q.GetInt64(2);
    Result.MaxUses := Q.GetInt64(3);
    Result.ExpiresAt := Q.GetText(4);
    Result.CreatedAt := Q.GetText(5);
  finally
    Q := nil;
    Conn := nil;
  end;
end;

type
  PWalletRedeemCtx = ^TWalletRedeemCtx;
  TWalletRedeemCtx = record
    UserId: string;
    Code: string;
    NewBal: PInt64;
  end;

procedure WalletRedeemBody(const AConn: IDbConnection; AData: Pointer);
var
  Ctx: PWalletRedeemCtx;
  Q: IDbQuery;
  Rc: TRedeemCode;
  Already: Boolean;
begin
  Ctx := PWalletRedeemCtx(AData);
  Q := AConn.Query('SELECT 1 FROM redeem_redemptions WHERE code = ?1 AND user_id = ?2');
  Q.BindText(1, Ctx.Code);
  Q.BindText(2, Ctx.UserId);
  Already := Q.Step;
  if Already then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckUnique, 'already redeemed');
  Q := AConn.Query('SELECT code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at FROM redeem_codes WHERE code = ?1');
  Q.BindText(1, Ctx.Code);
  if not Q.Step then
    raise EDbError.CreateWithCategory(dbkUnknown, decUnknown, dckNone, 'not found');
  Rc.Code := Q.GetText(0);
  Rc.TotalCents := Q.GetInt64(1);
  Rc.RemainingUses := Q.GetInt64(2);
  Rc.ExpiresAt := Q.GetText(4);
  if Rc.RemainingUses <= 0 then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'exhausted');
  if IsISO8601Expired(Rc.ExpiresAt) then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'expired');
  Q := AConn.Query('UPDATE redeem_codes SET remaining_uses = remaining_uses - 1 WHERE code = ?1 AND remaining_uses > 0');
  Q.BindText(1, Ctx.Code);
  Q.Step;
  if AConn.Changes <> 1 then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'exhausted');
  Q := AConn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
  Q.BindText(1, Ctx.UserId);
  Q.Step;
  Q := AConn.Query('UPDATE wallet_balances SET balance_cents = balance_cents + ?2, updated_at = ' + WALLET_SQLITE_NOW_EXPR + ' WHERE user_id = ?1 RETURNING balance_cents');
  Q.BindText(1, Ctx.UserId);
  Q.BindInt64(2, Rc.TotalCents);
  if not Q.Step then
    raise EDbError.CreateWithCategory(dbkUnknown, decUnknown, dckNone, 'balance update failed');
  Ctx.NewBal^ := Q.GetInt64(0);
  Q := AConn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
  Q.BindText(1, UUIDv7);
  Q.BindText(2, Ctx.UserId);
  Q.BindInt64(3, Rc.TotalCents);
  Q.BindText(4, 'redeem');
  Q.BindText(5, Ctx.Code);
  Q.Step;
  Q := AConn.Query('INSERT INTO redeem_redemptions (code, user_id) VALUES (?1, ?2)');
  Q.BindText(1, Ctx.Code);
  Q.BindText(2, Ctx.UserId);
  Q.Step;
end;

function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64;
var
  LCode: string;
  NewBal: Int64;
  Ctx: TWalletRedeemCtx;
begin
  LCode := Trim(ACode);
  if LCode = '' then raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckNotNull, 'code required');
  NewBal := 0;
  Ctx.UserId := AUserId;
  Ctx.Code := LCode;
  Ctx.NewBal := @NewBal;
  WalletWithWriterTxn(APool, @WalletRedeemBody, @Ctx);
  Result := NewBal;
end;

procedure WalletDeductAndJoinCore(const AConn: IDbConnection; const AUserId, AProjectId: string; APriceCents: Int64; const AIsMember: TWalletMembershipCheck; const AJoin: TWalletMembershipJoin; const AMembership: IWalletMembership; var ANewBal: Int64);
var
  Q: IDbQuery;
  IsMember: Boolean;
begin
  IsMember := False;
  if AMembership <> nil then
    IsMember := AMembership.IsMember(AConn, AUserId, AProjectId)
  else if Assigned(AIsMember) then
    IsMember := AIsMember(AConn, AUserId, AProjectId);
  if IsMember then
  begin
    Q := AConn.Query('SELECT balance_cents FROM wallet_balances WHERE user_id = ?1');
    Q.BindText(1, AUserId);
    if Q.Step then ANewBal := Q.GetInt64(0) else ANewBal := 0;
    Exit;
  end;
  Q := AConn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
  Q.BindText(1, AUserId);
  Q.Step;
  Q := AConn.Query('UPDATE wallet_balances SET balance_cents = balance_cents - ?2, updated_at = ' + WALLET_SQLITE_NOW_EXPR + ' WHERE user_id = ?1 AND balance_cents >= ?2 RETURNING balance_cents');
  Q.BindText(1, AUserId);
  Q.BindInt64(2, APriceCents);
  if not Q.Step then
    raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'insufficient balance');
  ANewBal := Q.GetInt64(0);
  Q := AConn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
  Q.BindText(1, UUIDv7);
  Q.BindText(2, AUserId);
  Q.BindInt64(3, -APriceCents);
  Q.BindText(4, 'project_join');
  Q.BindText(5, AProjectId);
  Q.Step;
  if AMembership <> nil then
    AMembership.Join(AConn, AUserId, AProjectId)
  else if Assigned(AJoin) then
    AJoin(AConn, AUserId, AProjectId);
end;

type
  PWalletDeductCtx = ^TWalletDeductCtx;
  TWalletDeductCtx = record
    UserId: string;
    ProjectId: string;
    Price: Int64;
    IsMember: TWalletMembershipCheck;
    Join: TWalletMembershipJoin;
    Membership: IWalletMembership;
    NewBal: PInt64;
  end;

procedure WalletDeductBody(const AConn: IDbConnection; AData: Pointer);
var
  Ctx: PWalletDeductCtx;
begin
  Ctx := PWalletDeductCtx(AData);
  WalletDeductAndJoinCore(AConn, Ctx.UserId, Ctx.ProjectId, Ctx.Price, Ctx.IsMember, Ctx.Join, Ctx.Membership, Ctx.NewBal^);
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64;
begin
  Result := WalletTryDeductAndJoin(APool, AUserId, AProjectId, APriceCents, IWalletMembership(nil));
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AMembership: IWalletMembership): Int64;
var
  NewBal: Int64;
  Ctx: TWalletDeductCtx;
begin
  if APriceCents <= 0 then raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'invalid amount');
  NewBal := 0;
  Ctx.UserId := AUserId;
  Ctx.ProjectId := AProjectId;
  Ctx.Price := APriceCents;
  Ctx.IsMember := nil;
  Ctx.Join := nil;
  Ctx.Membership := AMembership;
  Ctx.NewBal := @NewBal;
  WalletWithWriterTxn(APool, @WalletDeductBody, @Ctx);
  Result := NewBal;
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AIsMember: TWalletMembershipCheck; const AJoin: TWalletMembershipJoin): Int64;
var
  NewBal: Int64;
  Ctx: TWalletDeductCtx;
begin
  if APriceCents <= 0 then raise EDbError.CreateWithCategory(dbkUnknown, decConstraint, dckCheck, 'invalid amount');
  NewBal := 0;
  Ctx.UserId := AUserId;
  Ctx.ProjectId := AProjectId;
  Ctx.Price := APriceCents;
  Ctx.IsMember := AIsMember;
  Ctx.Join := AJoin;
  Ctx.Membership := nil;
  Ctx.NewBal := @NewBal;
  WalletWithWriterTxn(APool, @WalletDeductBody, @Ctx);
  Result := NewBal;
end;

function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  SetLength(Result, 0);
  if (AUserId = '') or (ALimit < 1) then Exit;
  if ALimit > 100 then ALimit := 100;
  Conn := APool.Acquire;
  WalletRequireIdentityReady(Conn);
  try
    if AAfter <> '' then
      Q := Conn.Query(WALLET_LIST_SQL_CURSOR)
    else
      Q := Conn.Query(WALLET_LIST_SQL);
    Q.BindText(1, AUserId);
    if AAfter <> '' then
    begin
      Q.BindText(2, AAfter);
      Q.BindInt64(3, ALimit);
    end
    else
      Q.BindInt64(2, ALimit);
    Result := WalletLedgerCollect(Q, ALimit);
  finally
    Q := nil;
    Conn := nil;
  end;
end;

end.
