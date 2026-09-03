unit nextpas.core.wallet.base;

{$I nextpas.core.settings.inc}

{** L3 wallet 基础类型：独立钱包域四件套 base 层（base←intf←impl←facade 纯聚合），零依赖；L3 业务域独立 Owner=wallet lane（已脱离 db 寄生家族命名，见 wallet/CONTRACT.md §0）；类型单源 wallet.base，db.wallet.base 已物理删除 2026-09-02，文件已移除，不再计入 src 模块清单；bytes.ops 单源 inline/零拷贝。 *}

interface

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

const
  WALLET_MIGRATION_VERSION = 15;

implementation

end.
