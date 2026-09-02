unit nextpas.core.billing.wallet;
{** 薄门面：复用 nextpas.core.db.wallet 单一事实源，消除孤儿 billing 域；inline/零拷贝转发（bytes.ops 单源 via owner，热点 inline+零拷贝视图），资源释放由 db.wallet 托管（FreeAndNil/try-finally 不丢），守 L0-L3/四件套薄门面。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db,
  nextpas.core.db.pool,
  nextpas.core.db.wallet;

type
  TWalletBalance = nextpas.core.db.wallet.TWalletBalance;
  TWalletLedgerEntry = nextpas.core.db.wallet.TWalletLedgerEntry;
  TWalletLedgerArray = nextpas.core.db.wallet.TWalletLedgerArray;
  TRedeemCode = nextpas.core.db.wallet.TRedeemCode;
  TWalletLedgerPage = nextpas.core.db.wallet.TWalletLedgerPage;

function WalletMakeMigrations: TDbMigrations; inline;
function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance; inline;
function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64; inline;
function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode; inline;
function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode; inline;
function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64; inline;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64; inline;
function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray; inline;

implementation

function WalletMakeMigrations: TDbMigrations; inline;
begin
  Result := nextpas.core.db.wallet.WalletMakeMigrations;
end;

function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance; inline;
begin
  Result := nextpas.core.db.wallet.WalletGetBalance(APool, AUserId);
end;

function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64; inline;
begin
  Result := nextpas.core.db.wallet.WalletAdjustBalance(APool, AUserId, ADelta, AReason, ARefId);
end;

function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode; inline;
begin
  Result := nextpas.core.db.wallet.WalletFindRedeemCode(APool, ACode);
end;

function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode; inline;
begin
  Result := nextpas.core.db.wallet.WalletCreateRedeemCode(APool, ACode, ATotalCents, AMaxUses, AExpiresAt);
end;

function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64; inline;
begin
  Result := nextpas.core.db.wallet.WalletTryRedeem(APool, AUserId, ACode);
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64; inline;
begin
  Result := nextpas.core.db.wallet.WalletTryDeductAndJoin(APool, AUserId, AProjectId, APriceCents);
end;

function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray; inline;
begin
  Result := nextpas.core.db.wallet.WalletListLedger(APool, AUserId, AAfter, ALimit);
end;

end.
