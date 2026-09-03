unit nextpas.core.wallet.intf;

{$I nextpas.core.settings.inc}

{** L3 wallet 接口抽象：独立钱包域四件套 intf 层，隔离可抽身份域与跨域 project_members。
    base←intf 单向（四件套 L3：base←intf←impl←facade）；L3 业务域独立 Owner=wallet lane（已脱离 db 寄生家族，见 wallet/CONTRACT.md §0），db.wallet.intf 已物理删除 2026-09-02，文件已移除，不再计入 src 模块清单；缺能力先反哺 owner。 *}

interface

uses
  nextpas.core.db.intf,
  nextpas.core.wallet.base;

type
  { 身份域只读探针：wallet 仅需判定 user 已存在性，写入归 identity Owner。 }
  IWalletIdentity = interface
    ['{A1B2C3D4-1111-4B2E-9F00-AAAABBBBCCCC}']
    function UserExists(const AConn: IDbConnection; const AUserId: string): Boolean;
  end;

  { 项目成员跨域注入：wallet 不拥有 project_members，扣减并入组经此面委托。 }
  IWalletMembership = interface
    ['{A1B2C3D4-2222-4B2E-9F00-AAAABBBBCCCC}']
    function IsMember(const AConn: IDbConnection; const AUserId, AProjectId: string): Boolean;
    procedure Join(const AConn: IDbConnection; const AUserId, AProjectId: string);
  end;

  { 便捷回调形态：与接口等价，消费方可选其一。 }
  TWalletMembershipCheck = reference to function(const AConn: IDbConnection; const AUserId, AProjectId: string): Boolean;
  TWalletMembershipJoin = reference to procedure(const AConn: IDbConnection; const AUserId, AProjectId: string);

implementation

end.
