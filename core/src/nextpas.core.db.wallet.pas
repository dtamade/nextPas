unit nextpas.core.db.wallet;
{** 单一事实源：wallet 业务归属 db 功能域，billing 为薄门面复用此源；inline 转发零拷贝，事务资源释放不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db,
  nextpas.core.db.pool;

type
  TWalletBalance = record
    UserId: string;
    BalanceCents: Int64;
    UpdatedAt: string;
  end;

  TWalletLedgerEntry = record
    Id: string;
    UserId: string;
    DeltaCents: Int64;
    Reason: string;
    RefId: string;
    CreatedAt: string;
  end;
  TWalletLedgerArray = array of TWalletLedgerEntry;

  TRedeemCode = record
    Code: string;
    TotalCents: Int64;
    RemainingUses: Integer;
    MaxUses: Integer;
    ExpiresAt: string;
    CreatedAt: string;
  end;

  TWalletLedgerPage = record
    Entries: TWalletLedgerArray;
    NextCursor: string;
  end;

function WalletMakeMigrations: TDbMigrations;

function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance;
function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64;
function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode;
function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode;
function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64;
function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray;

implementation

uses
  nextpas.core.exception,
  nextpas.core.id.uuid,
  nextpas.core.time,
  nextpas.core.text.utils,
  nextpas.core.text.conv,
  nextpas.core.db.migrate;

function WalletMakeMigrations: TDbMigrations;
begin
  Result := MakeMigrations([
    TDbMigration.Create(15, [
      'create table if not exists wallet_balances ( user_id text primary key references user_profiles(id) on delete cascade, balance_cents integer not null default 0 check (balance_cents >= 0), updated_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')) );',
      'create table if not exists wallet_ledger ( id text primary key, user_id text not null references user_profiles(id) on delete cascade, delta_cents integer not null, reason text not null, ref_id text, created_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')) );',
      'create index if not exists idx_wallet_ledger_user on wallet_ledger(user_id, created_at desc, id desc);',
      'create table if not exists redeem_codes ( code text primary key, total_cents integer not null check (total_cents > 0), remaining_uses integer not null check (remaining_uses >= 0), max_uses integer not null check (max_uses > 0), expires_at text, created_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')) );',
      'create table if not exists redeem_redemptions ( code text not null references redeem_codes(code) on delete cascade, user_id text not null references user_profiles(id) on delete cascade, redeemed_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')), primary key (code, user_id) );'
    ])
  ]);
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
  Q := Conn.Query('SELECT balance_cents, updated_at FROM wallet_balances WHERE user_id = ?1');
  Q.BindText(1, AUserId);
  if Q.Step then
  begin
    Result.BalanceCents := Q.GetInt64(0);
    Result.UpdatedAt := Q.GetText(1);
  end;
end;

function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
  Q: IDbQuery;
  NewBal: Int64;
begin
  Conn := APool.Writer;
  Conn.QueryInterface(IDbTxControl, Tx);
  Tx.BeginTxn(False);
  try
    Q := Conn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
    Q.BindText(1, AUserId);
    Q.Step;
    Q := Conn.Query('UPDATE wallet_balances SET balance_cents = balance_cents + ?2, updated_at = strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'') WHERE user_id = ?1 AND balance_cents + ?2 >= 0 RETURNING balance_cents');
    Q.BindText(1, AUserId);
    Q.BindInt64(2, ADelta);
    if not Q.Step then
      raise Exception.Create('insufficient balance');
    NewBal := Q.GetInt64(0);
    Q := Conn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
    Q.BindText(1, UUIDv7);
    Q.BindText(2, AUserId);
    Q.BindInt64(3, ADelta);
    Q.BindText(4, AReason);
    Q.BindText(5, ARefId);
    Q.Step;
    Tx.CommitTxn;
    Result := NewBal;
  except
    try Tx.RollbackTxn except end;
    raise;
  end;
end;

function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Result := Default(TRedeemCode);
  if Trim(ACode) = '' then Exit;
  Conn := APool.Acquire;
  Q := Conn.Query('SELECT code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at FROM redeem_codes WHERE code = ?1');
  Q.BindText(1, Trim(ACode));
  if Q.Step then
  begin
    Result.Code := Q.GetText(0);
    Result.TotalCents := Q.GetInt64(1);
    Result.RemainingUses := Q.GetInt64(2);
    Result.MaxUses := Q.GetInt64(3);
    Result.ExpiresAt := Q.GetText(4);
    Result.CreatedAt := Q.GetText(5);
  end;
end;

function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Result := Default(TRedeemCode);
  if Trim(ACode) = '' then raise Exception.Create('code required');
  Conn := APool.Writer;
  if AExpiresAt = '' then
  begin
    Q := Conn.Query('INSERT INTO redeem_codes (code, total_cents, remaining_uses, max_uses) VALUES (?1, ?2, ?3, ?4) RETURNING code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at');
    Q.BindText(1, Trim(ACode));
    Q.BindInt64(2, ATotalCents);
    Q.BindInt64(3, AMaxUses);
    Q.BindInt64(4, AMaxUses);
  end
  else
  begin
    Q := Conn.Query('INSERT INTO redeem_codes (code, total_cents, remaining_uses, max_uses, expires_at) VALUES (?1, ?2, ?3, ?4, ?5) RETURNING code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at');
    Q.BindText(1, Trim(ACode));
    Q.BindInt64(2, ATotalCents);
    Q.BindInt64(3, AMaxUses);
    Q.BindInt64(4, AMaxUses);
    Q.BindText(5, AExpiresAt);
  end;
  try
    if not Q.Step then raise Exception.Create('insert failed');
  except
    on E: Exception do
    begin
      if Pos('UNIQUE', UpperCase(E.Message)) > 0 then raise Exception.Create('duplicate code');
      raise;
    end;
  end;
  Result.Code := Q.GetText(0);
  Result.TotalCents := Q.GetInt64(1);
  Result.RemainingUses := Q.GetInt64(2);
  Result.MaxUses := Q.GetInt64(3);
  Result.ExpiresAt := Q.GetText(4);
  Result.CreatedAt := Q.GetText(5);
end;

function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
  Q: IDbQuery;
  Rc: TRedeemCode;
  Already: Boolean;
  NewBal: Int64;
begin
  if Trim(ACode) = '' then raise Exception.Create('code required');
  Conn := APool.Writer;
  Conn.QueryInterface(IDbTxControl, Tx);
  Tx.BeginTxn(False);
  try
    Q := Conn.Query('SELECT 1 FROM redeem_redemptions WHERE code = ?1 AND user_id = ?2');
    Q.BindText(1, Trim(ACode));
    Q.BindText(2, AUserId);
    Already := Q.Step;
    if Already then
      raise Exception.Create('already redeemed');
    Q := Conn.Query('SELECT code, total_cents, remaining_uses, max_uses, coalesce(expires_at,''''), created_at FROM redeem_codes WHERE code = ?1');
    Q.BindText(1, Trim(ACode));
    if not Q.Step then
      raise Exception.Create('not found');
    Rc.Code := Q.GetText(0);
    Rc.TotalCents := Q.GetInt64(1);
    Rc.RemainingUses := Q.GetInt64(2);
    Rc.ExpiresAt := Q.GetText(4);
    if Rc.RemainingUses <= 0 then
      raise Exception.Create('exhausted');
    if (Rc.ExpiresAt <> '') and (Rc.ExpiresAt < FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', DateTimeUtcNow)) then
      raise Exception.Create('expired');
    Q := Conn.Query('UPDATE redeem_codes SET remaining_uses = remaining_uses - 1 WHERE code = ?1 AND remaining_uses > 0');
    Q.BindText(1, Trim(ACode));
    Q.Step;
    Q := Conn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
    Q.BindText(1, AUserId);
    Q.Step;
    Q := Conn.Query('UPDATE wallet_balances SET balance_cents = balance_cents + ?2, updated_at = strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'') WHERE user_id = ?1 RETURNING balance_cents');
    Q.BindText(1, AUserId);
    Q.BindInt64(2, Rc.TotalCents);
    if not Q.Step then
      raise Exception.Create('balance update failed');
    NewBal := Q.GetInt64(0);
    Q := Conn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
    Q.BindText(1, UUIDv7);
    Q.BindText(2, AUserId);
    Q.BindInt64(3, Rc.TotalCents);
    Q.BindText(4, 'redeem');
    Q.BindText(5, Trim(ACode));
    Q.Step;
    Q := Conn.Query('INSERT INTO redeem_redemptions (code, user_id) VALUES (?1, ?2)');
    Q.BindText(1, Trim(ACode));
    Q.BindText(2, AUserId);
    Q.Step;
    Tx.CommitTxn;
    Result := NewBal;
  except
    try Tx.RollbackTxn except end;
    raise;
  end;
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
  Q: IDbQuery;
  NewBal: Int64;
begin
  if APriceCents <= 0 then raise Exception.Create('invalid amount');
  Conn := APool.Writer;
  Conn.QueryInterface(IDbTxControl, Tx);
  Tx.BeginTxn(False);
  try
    Q := Conn.Query('SELECT 1 FROM project_members WHERE project_id = ?1 AND user_id = ?2');
    Q.BindText(1, AProjectId);
    Q.BindText(2, AUserId);
    if Q.Step then
    begin
      Q := Conn.Query('SELECT balance_cents FROM wallet_balances WHERE user_id = ?1');
      Q.BindText(1, AUserId);
      if Q.Step then NewBal := Q.GetInt64(0) else NewBal := 0;
      Tx.CommitTxn;
      Result := NewBal;
      Exit;
    end;
    Q := Conn.Query('INSERT OR IGNORE INTO wallet_balances (user_id, balance_cents) VALUES (?1, 0)');
    Q.BindText(1, AUserId);
    Q.Step;
    Q := Conn.Query('UPDATE wallet_balances SET balance_cents = balance_cents - ?2, updated_at = strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'') WHERE user_id = ?1 AND balance_cents >= ?2 RETURNING balance_cents');
    Q.BindText(1, AUserId);
    Q.BindInt64(2, APriceCents);
    if not Q.Step then
      raise Exception.Create('insufficient balance');
    NewBal := Q.GetInt64(0);
    Q := Conn.Query('INSERT INTO wallet_ledger (id, user_id, delta_cents, reason, ref_id) VALUES (?1, ?2, ?3, ?4, ?5)');
    Q.BindText(1, UUIDv7);
    Q.BindText(2, AUserId);
    Q.BindInt64(3, -APriceCents);
    Q.BindText(4, 'project_join');
    Q.BindText(5, AProjectId);
    Q.Step;
    Q := Conn.Query('INSERT OR IGNORE INTO project_members (project_id, user_id, tier) VALUES (?1, ?2, ''paid'')');
    Q.BindText(1, AProjectId);
    Q.BindText(2, AUserId);
    Q.Step;
    Tx.CommitTxn;
    Result := NewBal;
  except
    try Tx.RollbackTxn except end;
    raise;
  end;
end;

procedure FillLedgerEntry(const Q: IDbQuery; out E: TWalletLedgerEntry);
begin
  E.Id := Q.GetText(0);
  E.UserId := Q.GetText(1);
  E.DeltaCents := Q.GetInt64(2);
  E.Reason := Q.GetText(3);
  E.RefId := Q.GetText(4);
  E.CreatedAt := Q.GetText(5);
end;

function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  SQL, AnchorCreatedAt: string;
  Count, BindIdx: Integer;
begin
  SetLength(Result, 0);
  Count := 0;
  if (AUserId = '') or (ALimit < 1) then Exit;
  if ALimit > 100 then ALimit := 100;
  Conn := APool.Acquire;
  AnchorCreatedAt := '';
  if AAfter <> '' then
  begin
    Q := Conn.Query('SELECT created_at FROM wallet_ledger WHERE id = ?1 AND user_id = ?2');
    Q.BindText(1, AAfter);
    Q.BindText(2, AUserId);
    if Q.Step then AnchorCreatedAt := Q.GetText(0);
    Q := nil;
  end;
  SQL := 'SELECT id, user_id, delta_cents, reason, coalesce(ref_id,''''), created_at FROM wallet_ledger WHERE user_id = ?1';
  BindIdx := 2;
  if AnchorCreatedAt <> '' then
  begin
    SQL := SQL + ' AND (created_at < ?' + IntToStr(BindIdx) + ' OR (created_at = ?' + IntToStr(BindIdx) + ' AND id < ?' + IntToStr(BindIdx+1) + '))';
    Inc(BindIdx, 2);
  end;
  SQL := SQL + ' ORDER BY created_at DESC, id DESC LIMIT ?' + IntToStr(BindIdx);
  Q := Conn.Query(SQL);
  BindIdx := 1;
  Q.BindText(BindIdx, AUserId); Inc(BindIdx);
  if AnchorCreatedAt <> '' then
  begin
    Q.BindText(BindIdx, AnchorCreatedAt); Inc(BindIdx);
    Q.BindText(BindIdx, AAfter); Inc(BindIdx);
  end;
  Q.BindInt64(BindIdx, ALimit);
  while Q.Step do
  begin
    if Count >= Length(Result) then SetLength(Result, Count + 16);
    FillLedgerEntry(Q, Result[Count]);
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

end.
