unit nextpas.core.wallet;
{**
 * @desc wallet 独立业务门面（Owner=wallet lane，四件套纯聚合，物理 wallet.impl 单源）
 * 逻辑 Owner = nextpas.core.wallet（L3 业务域独立，脱离 db 寄生家族命名分裂）；四件套 wallet.base←wallet.intf←wallet.impl←wallet 已独立，类型/接口单源 wallet.base/intf，业务以 wallet/CONTRACT.md 为准；
 * 物理实现已迁至 nextpas.core.wallet.impl 单一事实源（原 L3→L3 受控例外已彻底消除——pool/migrate 下沉 L2 基础设施，见 db/CONTRACT.md §1/§2.22 与 wallet/CONTRACT.md §0，infra 仅 L0-L2 单向；原寄生 db.wallet.impl 已物理删除 2026-09-02，文件已移除），本单元为唯一真源纯聚合门面；
 * 兼容层已物理删除(2026-09-02)：`nextpas.core.db.wallet` / `billing.wallet` / `db.wallet.impl` 薄别名已物理删除，文件已移除，不再计入 src 模块清单，统一使用本真源；通用计费请用 `nextpas.core.billing` 独立家族；
 * 单源复用：bytes.ops 单 Move 零拷贝（BYTES_OPS_SINGLE_SOURCE 守卫）、text.utils Trim inline 零拷贝、text.builder 单分配、time iso8601 单源；
 * 性能：全入口 inline 薄转发至 impl 单源，零自有SQL/表/状态，无额外分配（ledger 视图由 Owner 返回，Migrations 非 inline 避 I-Cache 膨胀）；
 * 稳定性：零自有句柄，IDbConnection/IDbTxControl 接口托管，事务 try Rollback 不丢，Owner 单遍状态机零泄漏，Q:=nil/Conn:=nil 语句边界归还，业务以 CONTRACT 为准，缺能力先反哺 owner。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.intf,
  nextpas.core.db.migrate,
  nextpas.core.db.pool,
  nextpas.core.wallet.base,
  nextpas.core.wallet.intf;

type
  TWalletBalance = nextpas.core.wallet.base.TWalletBalance;
  TWalletLedgerEntry = nextpas.core.wallet.base.TWalletLedgerEntry;
  TWalletLedgerArray = nextpas.core.wallet.base.TWalletLedgerArray;
  TRedeemCode = nextpas.core.wallet.base.TRedeemCode;
  TWalletLedgerPage = nextpas.core.wallet.base.TWalletLedgerPage;

function WalletMakeMigrations: TDbMigrations; inline;
function WalletFullMigrations: TDbMigrations; inline;
function WalletMigrateAll(const AConn: IDbConnection): Integer; inline; overload;
function WalletMigrateAll(const APool: TDbPool): Integer; inline; overload;
function WalletIsIdentityReady(const AConn: IDbConnection): Boolean; inline; overload;
function WalletIsIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity): Boolean; inline; overload;
procedure WalletRequireIdentityReady(const AConn: IDbConnection); inline; overload;
procedure WalletRequireIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity); inline; overload;
function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance; inline;
function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64; inline;
function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode; inline;
function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode; inline;
function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64; inline;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64; inline; overload;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AMembership: IWalletMembership): Int64; inline; overload;
function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AIsMember: TWalletMembershipCheck; const AJoin: TWalletMembershipJoin): Int64; inline; overload;
function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.wallet.impl;

{ bytes.ops 单源编译期互证：零运行时分支，漂移即编译失败 }

function WalletMakeMigrations: TDbMigrations; inline;
begin
  Result := nextpas.core.wallet.impl.WalletMakeMigrations;
end;

function WalletFullMigrations: TDbMigrations; inline;
begin
  Result := nextpas.core.wallet.impl.WalletFullMigrations;
end;

function WalletMigrateAll(const AConn: IDbConnection): Integer; inline;
begin
  Result := nextpas.core.wallet.impl.WalletMigrateAll(AConn);
end;

function WalletMigrateAll(const APool: TDbPool): Integer; inline;
begin
  Result := nextpas.core.wallet.impl.WalletMigrateAll(APool);
end;

function WalletIsIdentityReady(const AConn: IDbConnection): Boolean; inline;
begin
  Result := nextpas.core.wallet.impl.WalletIsIdentityReady(AConn);
end;

function WalletIsIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity): Boolean; inline;
begin
  Result := nextpas.core.wallet.impl.WalletIsIdentityReady(AConn, AIdentity);
end;

procedure WalletRequireIdentityReady(const AConn: IDbConnection); inline;
begin
  nextpas.core.wallet.impl.WalletRequireIdentityReady(AConn);
end;

procedure WalletRequireIdentityReady(const AConn: IDbConnection; const AIdentity: IWalletIdentity); inline;
begin
  nextpas.core.wallet.impl.WalletRequireIdentityReady(AConn, AIdentity);
end;

function WalletGetBalance(const APool: TDbPool; const AUserId: string): TWalletBalance; inline;
begin
  Result := nextpas.core.wallet.impl.WalletGetBalance(APool, AUserId);
end;

function WalletAdjustBalance(const APool: TDbPool; const AUserId: string; ADelta: Int64; const AReason, ARefId: string): Int64; inline;
begin
  Result := nextpas.core.wallet.impl.WalletAdjustBalance(APool, AUserId, ADelta, AReason, ARefId);
end;

function WalletFindRedeemCode(const APool: TDbPool; const ACode: string): TRedeemCode; inline;
begin
  Result := nextpas.core.wallet.impl.WalletFindRedeemCode(APool, ACode);
end;

function WalletCreateRedeemCode(const APool: TDbPool; const ACode: string; ATotalCents: Int64; AMaxUses: Integer; const AExpiresAt: string): TRedeemCode; inline;
begin
  Result := nextpas.core.wallet.impl.WalletCreateRedeemCode(APool, ACode, ATotalCents, AMaxUses, AExpiresAt);
end;

function WalletTryRedeem(const APool: TDbPool; const AUserId, ACode: string): Int64; inline;
begin
  Result := nextpas.core.wallet.impl.WalletTryRedeem(APool, AUserId, ACode);
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64): Int64; inline;
begin
  Result := nextpas.core.wallet.impl.WalletTryDeductAndJoin(APool, AUserId, AProjectId, APriceCents);
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AMembership: IWalletMembership): Int64; inline;
begin
  Result := nextpas.core.wallet.impl.WalletTryDeductAndJoin(APool, AUserId, AProjectId, APriceCents, AMembership);
end;

function WalletTryDeductAndJoin(const APool: TDbPool; const AUserId, AProjectId: string; APriceCents: Int64; const AIsMember: TWalletMembershipCheck; const AJoin: TWalletMembershipJoin): Int64; inline;
begin
  Result := nextpas.core.wallet.impl.WalletTryDeductAndJoin(APool, AUserId, AProjectId, APriceCents, AIsMember, AJoin);
end;

function WalletListLedger(const APool: TDbPool; const AUserId, AAfter: string; ALimit: Integer): TWalletLedgerArray; inline;
begin
  Result := nextpas.core.wallet.impl.WalletListLedger(APool, AUserId, AAfter, ALimit);
end;

end.
