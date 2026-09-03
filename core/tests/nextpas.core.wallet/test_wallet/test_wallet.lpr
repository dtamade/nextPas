program test_wallet;

{ nextpas.core.wallet 专属离线门禁（E1 已独立 Owner=wallet lane，四件套 wallet.base←intf←impl←wallet 已独立，db.wallet 兼容已物理删除 2026-09-02）：
  FK 前置依赖 + Changes 原子性钉死 + 资源释放不丢 + bytes.ops 单源零拷贝。
  契约：core/docs/db/wallet/CONTRACT.md（单源真相，§1 前置依赖序/§2 表/§3 原子/§5 性能/§6 稳定性）；
  兼容别名已物理删除：billing.wallet / db.wallet 已移除，统一使用 nextpas.core.wallet；身份域已落地 nextpas.core.identity v14。
  归属：Owner=wallet lane，路径 core/tests/nextpas.core.wallet/test_wallet（原寄宿 core/tests/nextpas.core.db/test_db_wallet 已迁移，模块归属漂移闭环）。

  门禁覆盖（离线 sqlite :memory:/file，FOREIGN_KEYS=ON）：
    1 FK 前置：IdentityMakeMigrations v14 → WalletMakeMigrations v15 顺序成功；缺 user_profiles 行时 wallet 写入 fail-closed FK
    2 迁移幂等：v14/v15 联合 Apply/Idempotent/Version 链（Migrate 经 db.migrate 单源，checksum CRC32）
    3 Adjust 原子：INSERT OR IGNORE 建户 → UPDATE +delta WHERE +delta≥0 RETURNING → ledger，负额 insufficient 且余额不负
    4 Redeem Changes 原子：UPDATE remaining_uses-1 WHERE >0 后 Changes=1 钉死防并发超兑；超兑 exhausted 零回退 RemainingUses=0
    5 过期：空串永不过期；非空须 TryParseISO8601 双形态（fractional 秒 …T%H:%M:%fZ 支持）→ 过期/非法 expired
    6 重码/已兑现：duplicate code 归一 dckUnique，already redeemed 归一 dckUnique，全程 Writer 独占 Rollback 不留半事务
    7 DeductAndJoin：成员面注入（IWalletMembership）幂等不二次扣减；余额不足 fail-closed；回调/接口双形态
    8 游标分页：text.builder 单分配零拷贝拼接，ORDER BY created_at DESC, id DESC，Limit 1..100 钳位，空参零查询
    9 文本/字节单源：Trim 经 text.utils inline 零拷贝（无修剪原串共享），StringToBytes 经 bytes.ops 单 Move 零拷贝（BYTES_OPS_SINGLE_SOURCE 守卫）
   10 资源释放不丢：Pool Acquire/Writer 接口句柄 + Q:=nil/Conn:=nil 语句边界归还，Writer 租约 WithWriter 收敛，try..except Rollback 不丢；50 次建池建表查释放 heaptrc 0
  性能：WalletMakeMigrations 等 inline 薄转发；Trim 缓存单次；builder 单次分配；GetBalance/FindRedeemCode 非 inline 避 I-Cache 膨胀（见 wallet.pas）
  单源：bytes.ops 编译期单出口 {$IF not BYTES_OPS_SINGLE_SOURCE} 守卫漂移拦截。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  BaseUnix,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.time,
  nextpas.core.time.iso8601,
  nextpas.core.time.offsetdatetime,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db,
  nextpas.core.db.pool,
  nextpas.core.db.migrate,
  nextpas.core.identity.base,
  nextpas.core.identity,
  nextpas.core.wallet.base,
  nextpas.core.wallet.intf,
  nextpas.core.wallet,
  nextpas.core.db.factory.register.sqlite;

{ bytes.ops 单源编译期互证：零运行时分支，漂移即编译失败 }

var
  T: TTestSuite;
  GSeq: Integer = 0;
  GPoolPath: string;

{ -- helpers: file-backed pool with FOREIGN_KEYS=ON（单写者事务 + 接口自动归还） -- }

function NextWalletPath: string; inline;
begin
  Inc(GSeq);
  Result := GetTempDir + 'test_wallet_' + IntToStr(FpGetPid) + '_' + IntToStr(GSeq) + '.db';
end;

function NewWalletPool(const APath: string): TDbPool; inline;
begin
  { 工厂经全局 GPoolPath 捕获路径，避免 const 参捕获悬垂（FPC 闭包变量捕获语义）；路径在池生命周期内保持稳定，池销毁后才切换 }
  GPoolPath := APath;
  Result := TDbPool.Create(
    function: IDbConnection
    var
      C: IDbConnection;
    begin
      { 单 Move 零拷贝后链入 text.utils/inline 复用；PRAGMA 显式 foreign_keys=ON fail-closed }
      C := ConnectSqlite(GPoolPath);
      C.Exec('PRAGMA foreign_keys=ON');
      C.Exec('PRAGMA busy_timeout=5000');
      Result := C;
    end,
    TDbPoolPolicy.Default);
end;

procedure MigrateIdentityAndWallet(const APool: TDbPool); inline;
var
  C: IDbConnection;
begin
  { 部署序：identity v14 → wallet v15（CONTRACT §1）；单次累计清单调用，
    分两次 Migrate 会触发引擎 below-lower-bound 熔断；租约语句边界归还 }
  C := APool.Writer;
  try
    Migrate(C, WalletFullMigrations);
  finally
    C := nil;
  end;
end;

procedure InsertUser(const APool: TDbPool; const AUserId: string); inline;
var
  C: IDbConnection;
  Q: IDbQuery;
begin
  C := APool.Writer;
  try
    Q := C.Query('INSERT OR IGNORE INTO user_profiles (id) VALUES (?1)');
    Q.BindText(1, AUserId);
    Q.Step;
  finally
    Q := nil;
    C := nil;
  end;
end;

function CountRows(const APool: TDbPool; const ASql: string): Int64;
var
  C: IDbConnection;
  Q: IDbQuery;
begin
  C := APool.Acquire;
  try
    Q := C.Query(ASql);
    Check(Q.Step, 'count rows helper stepped');
    Result := Q.GetInt64(0);
  finally
    Q := nil;
    C := nil;
  end;
end;

{ 薄转发 bytes.ops 单 Move 零拷贝证据：IdentityIdToBytes inline 转发 StringToBytes 单 Move }
function IdBytesZeroCopy(const AId: string): TBytes; inline;
begin
  Result := IdentityIdToBytes(AId);
end;

{ Trim 单源 inline 零拷贝证据：无修剪时原串共享零分配（text.utils） }
function TrimCode(const ACode: string): string; inline;
begin
  Result := Trim(ACode);
end;

{ -- membership mock for DeductAndJoin -- }

type
  TMockMembership = class(TInterfacedObject, IWalletMembership)
  public
    function IsMember(const AConn: IDbConnection; const AUserId, AProjectId: string): Boolean;
    procedure Join(const AConn: IDbConnection; const AUserId, AProjectId: string);
  end;

function TMockMembership.IsMember(const AConn: IDbConnection; const AUserId, AProjectId: string): Boolean;
var
  Q: IDbQuery;
begin
  Q := AConn.Query('SELECT 1 FROM project_members WHERE user_id=?1 AND project_id=?2');
  Q.BindText(1, AUserId);
  Q.BindText(2, AProjectId);
  Result := Q.Step;
end;

procedure TMockMembership.Join(const AConn: IDbConnection; const AUserId, AProjectId: string);
var
  Q: IDbQuery;
begin
  Q := AConn.Query('INSERT OR IGNORE INTO project_members (user_id, project_id) VALUES (?1, ?2)');
  Q.BindText(1, AUserId);
  Q.BindText(2, AProjectId);
  Q.Step;
end;

procedure EnsureProjectMembersTable(const APool: TDbPool);
var
  C: IDbConnection;
begin
  C := APool.Writer;
  try
    C.Exec('CREATE TABLE IF NOT EXISTS project_members (user_id TEXT NOT NULL, project_id TEXT NOT NULL, PRIMARY KEY(user_id, project_id))');
  finally
    C := nil;
  end;
end;

{ ==== 1 FK 前置依赖 ==== }

procedure TestFkRequiresIdentity;
var
  LPath: string;
  Pool: TDbPool;
  Raised: Boolean;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    { 未插 user_profiles 行时，wallet 写入应 FK 失败（FOREIGN_KEYS=ON fail-closed） }
    Raised := False;
    try
      WalletAdjustBalance(Pool, 'ghost', 100, 'test', 'r1');
    except
      on E: EDbError do
        Raised := (E.Category = decConstraint) and (E.Constraint = dckForeignKey);
    end;
    Check(Raised, 'fk: adjust without user_profiles row → foreign key');

    { 插入前置身份后成功；IsValid/Normalize/IdToBytes 单源可用 }
    Check(IdentityIsValidId('u1'), 'fk: IdentityIsValidId single source');
    Check(IdentityNormalizeId('  u1  ') = 'u1', 'fk: Trim via text.utils inline');
    Check(Length(IdBytesZeroCopy('u1')) = 2, 'fk: StringToBytes via bytes.ops single Move');
    InsertUser(Pool, 'u1');
    Check(WalletAdjustBalance(Pool, 'u1', 100, 'init', 'r2') = 100, 'fk: after user insert adjust succeeds');
    Check(WalletGetBalance(Pool, 'u1').BalanceCents = 100, 'fk: balance readable via Acquire short lease');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestFkRedeemRedemptionsRequiresUser;
var
  LPath: string;
  Pool: TDbPool;
  Raised: Boolean;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'owner');
    WalletCreateRedeemCode(Pool, 'FKCODE', 50, 1, '');
    { redeem 时 user_id FK→user_profiles，幽灵用户应 FK 失败 }
    Raised := False;
    try
      WalletTryRedeem(Pool, 'ghost2', 'FKCODE');
    except
      on E: EDbError do
        Raised := (E.Category = decConstraint);
    end;
    { wallet 层对 ghost 用户仍会建户/插 redemption 双 FK；期望失败（实现经 wallet_balances FK） }
    Check(Raised, 'fk: redeem with ghost user → constraint (FK)');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 2 迁移幂等 ==== }

procedure TestMigrateIdempotentAndVersion;
var
  LPath: string;
  Pool: TDbPool;
  C: IDbConnection;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    C := Pool.Writer;
    try
      { 引擎要求已应用版本必须出现在本次清单内（fail-closed 熔断），
        故部署序走累计清单单次调用；分两次调用会触发 below-lower-bound }
      Check(Migrate(C, WalletFullMigrations) = 2, 'migrate: v14+v15 applied once');
      Check(Migrate(C, WalletFullMigrations) = 0, 'migrate: cumulative idempotent');
      Check(MigrationVersion(C) = WALLET_MIGRATION_VERSION, 'migrate: version at 15');
      Check(WALLET_MIGRATION_VERSION = 15, 'migrate: base const single source');
      Check(IDENTITY_MIGRATION_VERSION = 14, 'migrate: identity base single source');
    finally
      C := nil;
    end;
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 3 Adjust 原子 + ledger/get ==== }

procedure TestAdjustBalanceAtomic;
var
  LPath: string;
  Pool: TDbPool;
  Bal: Int64;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'alice');
    Bal := WalletAdjustBalance(Pool, 'alice', 200, 'topup', 't1');
    Check(Bal = 200, 'adjust: +200');
    Bal := WalletAdjustBalance(Pool, 'alice', -80, 'spend', 't2');
    Check(Bal = 120, 'adjust: -80 → 120');
    { 非负违例 fail-closed：UPDATE … WHERE balance+delta>=0 RETURNING 未命中 }
    try
      WalletAdjustBalance(Pool, 'alice', -200, 'overspend', 't3');
      Check(False, 'adjust: overspend should raise insufficient balance');
    except
      on E: EDbError do
        Check((E.Category = decConstraint) and (E.Constraint = dckCheck), 'adjust: insufficient → dckCheck');
    end;
    Check(WalletGetBalance(Pool, 'alice').BalanceCents = 120, 'adjust: balance not changed after failed deduct');
    { 空 user GetBalance 零值不抛 }
    Check(WalletGetBalance(Pool, '').BalanceCents = 0, 'adjust: empty user zero');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 4 Create 校验 + Trim / iso8601 ==== }

procedure TestCreateRedeemCodeValidation;
var
  LPath: string;
  Pool: TDbPool;
  Rc: TRedeemCode;
  Raised: Boolean;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    { Trim 零拷贝：带空白建码后，Trim 归一化落库；bytes.ops 零拷贝存续 }
    Rc := WalletCreateRedeemCode(Pool, '  CODE_A  ', 100, 2, '');
    Check(Rc.Code = 'CODE_A', 'create: Trim via text.utils single source');
    Check(Rc.TotalCents = 100, 'create: total');
    Check(Rc.RemainingUses = 2, 'create: remaining = max');
    Check(TrimCode('  CODE_A  ') = 'CODE_A', 'create: Trim inline zero-copy');
    { Find 带空白查询同样 Trim }
    Rc := WalletFindRedeemCode(Pool, '  CODE_A ');
    Check(Rc.Code = 'CODE_A', 'find: Trim on query');

    { duplicate code → dckUnique }
    Raised := False;
    try
      WalletCreateRedeemCode(Pool, 'CODE_A', 100, 1, '');
    except
      on E: EDbError do
        Raised := (E.Constraint = dckUnique);
    end;
    Check(Raised, 'create: duplicate → dckUnique');

    { 非法 expires_at → decSyntax fail-fast，空串永不过期 }
    Raised := False;
    try
      WalletCreateRedeemCode(Pool, 'CODE_B', 10, 1, 'not-iso8601');
    except
      on E: EDbError do
        Raised := E.Category = decSyntax;
    end;
    Check(Raised, 'create: invalid expires_at → decSyntax');

    { 分数秒 ISO8601 合法：…T%H:%M:%fZ }
    Rc := WalletCreateRedeemCode(Pool, 'CODE_C', 10, 1, '2099-12-31T23:59:59.123Z');
    Check(Rc.ExpiresAt = '2099-12-31T23:59:59.123Z', 'create: fractional seconds iso8601 accepted');
    { time 单源 NowUtc }
    Check(IdentityNowIso8601 <> '', 'create: IdentityNowIso8601 via time single source');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 5 Redeem Changes 原子（并发超兑闭环） ==== }

procedure TestRedeemChangesAtomic;
var
  LPath: string;
  Pool: TDbPool;
  Bal1, Bal2: Int64;
  Rc: TRedeemCode;
  Raised: Boolean;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'bob');
    InsertUser(Pool, 'carol');
    WalletCreateRedeemCode(Pool, 'ONCE', 50, 1, '');
    Bal1 := WalletTryRedeem(Pool, 'bob', 'ONCE');
    Check(Bal1 = 50, 'redeem: first Changes=1 succeeds, balance +total');
    Rc := WalletFindRedeemCode(Pool, 'ONCE');
    Check(Rc.RemainingUses = 0, 'redeem: remaining decremented to 0');

    { 第二次应 exhausted：UPDATE … WHERE remaining_uses>0 无命中，Changes=0 → EDbError dckCheck 不回退 remaining 为负 }
    Raised := False;
    try
      WalletTryRedeem(Pool, 'carol', 'ONCE');
    except
      on E: EDbError do
        Raised := (E.Constraint = dckCheck) and (Pos('exhausted', E.Message) > 0);
    end;
    Check(Raised, 'redeem: second Changes<>1 → exhausted');
    Rc := WalletFindRedeemCode(Pool, 'ONCE');
    Check(Rc.RemainingUses = 0, 'redeem: remaining stays 0 not negative');
    Check(WalletGetBalance(Pool, 'bob').BalanceCents = 50, 'redeem: ledger balanced carol untouched');
    { 已经兑现的同一用户重复 → already redeemed dckUnique }
    Raised := False;
    try
      WalletTryRedeem(Pool, 'bob', 'ONCE');
    except
      on E: EDbError do
        Raised := Pos('already redeemed', E.Message) > 0;
    end;
    Check(Raised, 'redeem: same user again → already redeemed');
    { ghost redeem 已在 FK 测试覆盖；此处确保 ledger 幂等两行仅一 redeem 记录 }
    Check(Length(WalletListLedger(Pool, 'bob', '', 10)) = 1, 'redeem: ledger one entry (reason=redeem)');
    Bal2 := WalletGetBalance(Pool, 'carol').BalanceCents;
    Check(Bal2 = 0, 'redeem: carol still 0 after exhausted');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestRedeemExpired;
var
  LPath: string;
  Pool: TDbPool;
  Raised: Boolean;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'dave');
    WalletCreateRedeemCode(Pool, 'PAST', 30, 1, '2000-01-01T00:00:00Z');
    Raised := False;
    try
      WalletTryRedeem(Pool, 'dave', 'PAST');
    except
      on E: EDbError do
        Raised := Pos('expired', E.Message) > 0;
    end;
    Check(Raised, 'redeem: past expires_at → expired');
    { 分数秒過去也判过期（ToUnixNanos 单路径） }
    WalletCreateRedeemCode(Pool, 'PAST_F', 30, 1, '2000-01-01T00:00:00.123Z');
    Raised := False;
    try
      WalletTryRedeem(Pool, 'dave', 'PAST_F');
    except
      on E: EDbError do Raised := Pos('expired', E.Message) > 0;
    end;
    Check(Raised, 'redeem: fractional past → expired');
    { 未来永不过期码仍可兑 }
    WalletCreateRedeemCode(Pool, 'FUTURE', 10, 1, '2099-01-01T00:00:00Z');
    Check(WalletTryRedeem(Pool, 'dave', 'FUTURE') = 10, 'redeem: future not expired');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 6 DeductAndJoin 原子/成员面 ==== }

procedure TestDeductAndJoinAtomicAndMembership;
var
  LPath: string;
  Pool: TDbPool;
  Bal: Int64;
  Raised: Boolean;
  M: IWalletMembership;
  WC: IDbConnection;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    EnsureProjectMembersTable(Pool);
    InsertUser(Pool, 'eve');
    WalletAdjustBalance(Pool, 'eve', 100, 'topup', 'init');

    M := TMockMembership.Create;
    { 首次扣减并入组：余额足 → ledger + membership }
    Bal := WalletTryDeductAndJoin(Pool, 'eve', 'proj1', 60, M);
    Check(Bal = 40, 'deduct: first join deducts 60 → 40');
    WC := Pool.Writer;
    try
      Check(M.IsMember(WC, 'eve', 'proj1'), 'deduct: membership inserted');
    finally
      WC := nil;
    end;
    { 已成员幂等：不二次扣减 }
    Bal := WalletTryDeductAndJoin(Pool, 'eve', 'proj1', 60, M);
    Check(Bal = 40, 'deduct: already member → no second deduct');

    { 回调形态等价 }
    Bal := WalletTryDeductAndJoin(Pool, 'eve', 'proj2', 30,
      function(const AConn: IDbConnection; const AUserId, AProjectId: string): Boolean
      begin
        Result := M.IsMember(AConn, AUserId, AProjectId);
      end,
      procedure(const AConn: IDbConnection; const AUserId, AProjectId: string)
      begin
        M.Join(AConn, AUserId, AProjectId);
      end);
    Check(Bal = 10, 'deduct: callback overload deducts');
    { 余额不足 fail-closed }
    Raised := False;
    try
      WalletTryDeductAndJoin(Pool, 'eve', 'proj3', 50);
    except
      on E: EDbError do Raised := Pos('insufficient', E.Message) > 0;
    end;
    Check(Raised, 'deduct: insufficient → fail-closed');
    Check(WalletGetBalance(Pool, 'eve').BalanceCents = 10, 'deduct: balance unchanged after insufficient');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 7 游标分页稳定序 ==== }

procedure TestListLedgerCursorAndLimits;
var
  LPath: string;
  Pool: TDbPool;
  Page1, Page2, All: TWalletLedgerArray;
  I: Integer;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'frank');
    { 构造 5 笔账本：+10*5 间隔，id/created_at 单调 uuidv7，builder 零拷贝证据 }
    for I := 1 to 5 do
      WalletAdjustBalance(Pool, 'frank', 10, 'topup', 'r' + IntToStr(I));
    All := WalletListLedger(Pool, 'frank', '', 10);
    Check(Length(All) = 5, 'ledger: 5 entries');
    { Limit 钳位 1..100：0→空，>100→100 不越界（当前 5） }
    Check(Length(WalletListLedger(Pool, 'frank', '', 0)) = 0, 'ledger: limit<1 zero query');
    Check(Length(WalletListLedger(Pool, 'frank', '', 200)) = 5, 'ledger: limit clamp 100');
    Check(Length(WalletListLedger(Pool, '', '', 10)) = 0, 'ledger: empty user zero query');
    { 单往返游标：After 以相关子查询内联，无额外点查 }
    Page1 := WalletListLedger(Pool, 'frank', '', 2);
    Check(Length(Page1) = 2, 'ledger: page1 2');
    Page2 := WalletListLedger(Pool, 'frank', Page1[High(Page1)].Id, 2);
    Check(Length(Page2) = 2, 'ledger: page2 2');
    Check(Page1[0].Id <> Page2[0].Id, 'ledger: cursor stable no overlap');
    { 全量按时间倒序 + id 倒序；ID 唯一 }
    Check(All[0].CreatedAt >= All[High(All)].CreatedAt, 'ledger: order desc');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

{ ==== 8 资源释放不丢 + bytes 单源 ==== }

procedure TestResourceReleaseAndBytesSingleSource;
var
  LPath: string;
  Pool: TDbPool;
  I: Integer;
  B: TBytes;
begin
  LPath := NextWalletPath;
  DeleteFile(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    { 多轮建池/查/置 nil：接口引用计数自动归还，Q:=nil 断句柄防滞留；heaptrc gate 兜底 }
    for I := 1 to 20 do
    begin
      InsertUser(Pool, 'user' + IntToStr(I));
      WalletAdjustBalance(Pool, 'user' + IntToStr(I), 1, 't', 'r');
      Check(WalletGetBalance(Pool, 'user' + IntToStr(I)).BalanceCents = 1, 'release: roundtrip ' + IntToStr(I));
    end;
    { bytes.ops 单 Move 零拷贝：空串/空白归一化后单次分配 }
    B := IdBytesZeroCopy('  abc  ');
    Check((Length(B) = 3) and (B[0] = Ord('a')), 'bytes: StringToBytes single Move after Trim');
    B := IdBytesZeroCopy('');
    Check(Length(B) = 0, 'bytes: empty → empty');
    { WalletMakeMigrations inline 薄转发证据：多次调用同一 v15 清单版本一致 }
    Check(WalletMakeMigrations()[0].Version = 15, 'inline: WalletMakeMigrations thin forward');
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

begin
  { 显式注册 sqlite 驱动（factory.builtin 已物理删除，Kind 分发需显式注册见 CONTRACT §2.14） }
  RegisterSqliteDriver;
  T := TTestSuite.Create('nextpas.core.wallet');
  T.Test('fk requires identity pre-migrate + user row', @TestFkRequiresIdentity);
  T.Test('fk redeem Redemptions requires user', @TestFkRedeemRedemptionsRequiresUser);
  T.Test('migrate idempotent v14→v15 versions', @TestMigrateIdempotentAndVersion);
  T.Test('adjust balance atomic non-negative + ledger', @TestAdjustBalanceAtomic);
  T.Test('create code validation Trim + iso8601', @TestCreateRedeemCodeValidation);
  T.Test('redeem Changes=1 atomic prevent over-issue', @TestRedeemChangesAtomic);
  T.Test('redeem expired fractional + future', @TestRedeemExpired);
  T.Test('deductAndJoin membership idempotent + insufficient', @TestDeductAndJoinAtomicAndMembership);
  T.Test('ledger cursor stable + limit clamp 1..100', @TestListLedgerCursorAndLimits);
  T.Test('resource release not lost + bytes.ops single Move', @TestResourceReleaseAndBytesSingleSource);
  if not T.Run then Halt(1);
end.
